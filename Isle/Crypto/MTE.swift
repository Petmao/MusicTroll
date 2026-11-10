import Foundation
import CryptoKit
import AVFoundation

/// .mte 加密容器：分块 AES-256-GCM，随机访问解密后喂给 AVFoundation，明文不落盘
enum MTE {
    static let magic = Data("MTE1".utf8)
    static let headerSize = 52
    static let tagLen = 16
    static let mimeMP3: UInt8 = 0, mimeM4A: UInt8 = 1, mimeFLAC: UInt8 = 2, mimeWAV: UInt8 = 3, mimeMP4: UInt8 = 4

    static func nonce(_ base: Data, _ index: UInt32) throws -> AES.GCM.Nonce {
        var d = base
        withUnsafeBytes(of: index.littleEndian) { d.append(contentsOf: $0) }
        return try AES.GCM.Nonce(data: d)
    }
    static func aad(_ prefix: Data, _ index: UInt32) -> Data {
        var d = prefix
        withUnsafeBytes(of: index.littleEndian) { d.append(contentsOf: $0) }
        return d
    }
    static func uti(_ mime: UInt8) -> String {
        switch mime {
        case mimeMP3: return "public.mp3"
        case mimeM4A: return "public.mpeg-4-audio"
        case mimeFLAC: return "org.xiph.flac"
        case mimeWAV: return "com.microsoft.waveform-audio"
        default: return "public.mpeg-4"
        }
    }
}

struct MTEHeader {
    let chunkSize: UInt32
    let nonceBase: Data
    let mime: UInt8
    let plainSize: UInt64
    let chunkCount: UInt32
    let prefix: Data

    static func parse(_ fh: FileHandle, key: SymmetricKey) throws -> MTEHeader {
        try fh.seek(toOffset: 0)
        guard let head = try fh.read(upToCount: MTE.headerSize), head.count == MTE.headerSize, head.prefix(4) == MTE.magic
        else { throw Err.badFile }
        let prefix = head.prefix(36)
        let nonceBase = head.subdata(in: 12..<20)
        let tag = head.subdata(in: 36..<52)
        var ff = nonceBase; ff.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])
        let box = try AES.GCM.SealedBox(nonce: try AES.GCM.Nonce(data: ff), ciphertext: Data(), tag: tag)
        _ = try AES.GCM.open(box, using: key, authenticating: prefix)
        func u32(_ o: Int) -> UInt32 { head.subdata(in: o..<(o+4)).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian }
        func u64(_ o: Int) -> UInt64 { head.subdata(in: o..<(o+8)).withUnsafeBytes { $0.load(as: UInt64.self) }.littleEndian }
        return MTEHeader(chunkSize: u32(8), nonceBase: nonceBase, mime: head[20], plainSize: u64(24), chunkCount: u32(32), prefix: prefix)
    }
    func offset(of i: Int) -> UInt64 { UInt64(MTE.headerSize) + UInt64(i) * (UInt64(chunkSize) + UInt64(MTE.tagLen)) }
    func length(of i: Int) -> Int { Int(min(UInt64(chunkSize), plainSize - UInt64(i) * UInt64(chunkSize))) }
    enum Err: Error { case badFile }
}

enum MTEWriter {
    enum Err: Error { case ioError }

    static func encrypt(source: URL, dest: URL, key: SymmetricKey, mime: UInt8) throws {
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        guard let out = try? FileHandle(forWritingTo: dest), let input = try? FileHandle(forReadingFrom: source)
        else { throw Err.ioError }
        let size = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? UInt64) ?? 0
        let chunk = UInt64(Config.mteChunkSize)
        let count = UInt32((size + chunk - 1) / chunk)
        let nonceBase = Data((0..<8).map { _ in UInt8.random(in: 0...255) })

        var head = Data(MTE.magic)
        head.append(1); head.append(0); head.append(contentsOf: [0, 0])
        head.append(u32(UInt32(chunk)))
        head.append(nonceBase)
        head.append(mime)
        head.append(contentsOf: [0, 0, 0])
        head.append(u64(size))
        head.append(u32(count))
        head.append(Data(count: MTE.tagLen))
        out.write(head)
        let prefix = head.prefix(36)

        for i in 0..<Int(count) {
            let len = Int(min(chunk, size - UInt64(i) * chunk))
            guard let plain = try input.read(upToCount: len), plain.count == len else { throw Err.ioError }
            let box = try AES.GCM.seal(plain, using: key, nonce: try MTE.nonce(nonceBase, UInt32(i)), authenticating: MTE.aad(prefix, UInt32(i)))
            out.write(box.ciphertext)
            out.write(box.tag)
        }
        var ff = nonceBase; ff.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])
        let htag = try AES.GCM.seal(Data(), using: key, nonce: try AES.GCM.Nonce(data: ff), authenticating: prefix).tag
        try out.seek(toOffset: 36); out.write(htag)
        try out.close(); try input.close()
    }
    static func u32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    static func u64(_ v: UInt64) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
}

/// 自定义 mte:// 协议，供 AVPlayer 按 Range 分块解密
final class MTEAssetSource: NSObject, AVAssetResourceLoaderDelegate {
    static let scheme = "mte"
    private let key: SymmetricKey
    private let fh: FileHandle
    private let header: MTEHeader
    private let lock = NSLock()
    private var cache: [Int: Data] = [:]
    private var order: [Int] = []
    private let cacheLimit = 64

    init(fileURL: URL, key: SymmetricKey) throws {
        self.key = key
        self.fh = try FileHandle(forReadingFrom: fileURL)
        self.header = try MTEHeader.parse(self.fh, key: key)
        super.init()
    }

    static func makeAsset(fileURL: URL, key: SymmetricKey) throws -> AVURLAsset {
        var c = URLComponents(url: fileURL, resolvingAgainstBaseURL: false)!
        c.scheme = scheme
        let asset = AVURLAsset(url: c.url!)
        let src = try MTEAssetSource(fileURL: fileURL, key: key)
        asset.resourceLoader.setDelegate(src, queue: DispatchQueue(label: "mte.loader"))
        objc_setAssociatedObject(asset, Unmanaged.passUnretained(asset).toOpaque(), src, .OBJC_ASSOCIATION_RETAIN)
        return asset
    }

    func resourceLoader(_ rl: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource req: AVAssetResourceLoadingRequest) -> Bool {
        do {
            if let info = req.contentInformationRequest {
                info.contentType = MTE.uti(header.mime)
                info.contentLength = Int64(header.plainSize)
                info.isByteRangeAccessSupported = true
            }
            guard let dr = req.dataRequest else { return true }
            var offset = dr.requestedOffset
            var length = dr.requestedLength
            if dr.requestsAllDataToEndOfResource || length == 0 { length = Int(header.plainSize) - offset }
            length = max(0, min(length, Int(header.plainSize) - offset))
            if length > 0 { dr.respond(with: try decrypt(range: offset..<(offset + length))) }
            req.finishLoading()
            return true
        } catch {
            req.finishLoading(with: error)
            return true
        }
    }

    private func decrypt(range: Range<Int>) throws -> Data {
        let cs = Int(header.chunkSize)
        let first = range.lowerBound / cs
        let last = (range.upperBound - 1) / cs
        var out = Data(capacity: range.count)
        for i in first...last {
            let c = try chunk(i)
            let start = i * cs
            let lo = max(range.lowerBound, start) - start
            let hi = min(range.upperBound, start + c.count) - start
            out.append(c[lo..<hi])
        }
        return out
    }

    private func chunk(_ index: Int) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        if let c = cache[index] { return c }
        let len = header.length(of: index)
        try fh.seek(toOffset: header.offset(of: index))
        guard let blob = try fh.read(upToCount: len + MTE.tagLen), blob.count == len + MTE.tagLen else { throw Err.readFail }
        let box = try AES.GCM.SealedBox(nonce: try MTE.nonce(header.nonceBase, UInt32(index)),
                                        ciphertext: blob.prefix(len), tag: blob.suffix(MTE.tagLen))
        let plain = try AES.GCM.open(box, using: key, authenticating: MTE.aad(header.prefix, UInt32(index)))
        cache[index] = plain; order.append(index)
        if order.count > cacheLimit { cache.removeValue(forKey: order.removeFirst()) }
        return plain
    }
    enum Err: Error { case readFail }
}
