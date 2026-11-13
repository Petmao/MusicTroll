import Foundation

/// 纯 Swift 的音频磁盘缓存，替代 KTVHTTPCache。
/// 命中时把远程 URL 换成本地 file URL 交给 AVPlayer，边听边把完整文件落到 Caches/IsleAudio。
final class PlaybackCache {
    static let shared = PlaybackCache()

    private let dir: URL
    private let maxBytes: Int64 = 512 * 1024 * 1024
    private let lock = NSLock()
    private var downloading = Set<String>()

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("IsleAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - 查询

    func cachedURL(for remote: URL) -> URL? {
        let f = fileURL(for: remote)
        guard FileManager.default.fileExists(atPath: f.path) else { return nil }
        guard fileSize(f) > 4096 else { return nil }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: f.path)
        return f
    }

    /// 命中返回本地，未命中返回原地址
    func url(for remote: URL) -> URL {
        cachedURL(for: remote) ?? remote
    }

    func isCached(_ remote: URL) -> Bool {
        cachedURL(for: remote) != nil
    }

    // MARK: - 下载

    func download(_ remote: URL, completion: (() -> Void)? = nil) {
        let key = remote.absoluteString
        lock.lock()
        if downloading.contains(key) {
            lock.unlock()
            return
        }
        downloading.insert(key)
        lock.unlock()

        let dest = fileURL(for: remote)

        let task = URLSession.shared.downloadTask(with: remote) { [weak self] tmp, _, err in
            guard let self = self else { return }

            var done = false
            defer {
                self.lock.lock()
                self.downloading.remove(key)
                self.lock.unlock()
                if done {
                    DispatchQueue.main.async { completion?() }
                }
            }

            guard err == nil, let tmp = tmp else { return }
            guard self.fileSize(tmp) > 4096 else { return }

            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: tmp, to: dest)
                done = true
            } catch {
                return
            }
            self.trim()
        }
        task.resume()
    }

    // MARK: - 容量

    func totalSize() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        var sum: Int64 = 0
        for f in files {
            sum += fileSize(f)
        }
        return sum
    }

    func prettySize() -> String {
        let b = totalSize()
        if b <= 0 { return "0 MB" }
        let mb = Double(b) / 1024.0 / 1024.0
        if mb < 1024 { return String(format: "%.0f MB", mb) }
        return String(format: "%.2f GB", mb / 1024.0)
    }

    func clear() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - 私有

    private func fileSize(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func fileURL(for remote: URL) -> URL {
        var hash: UInt64 = 1469598103934665603
        for b in Array(remote.absoluteString.utf8) {
            hash ^= UInt64(b)
            hash = hash &* 1099511628211
        }
        var ext = remote.pathExtension.lowercased()
        if ext.isEmpty || ext.count > 5 { ext = "audio" }
        return dir.appendingPathComponent(String(hash, radix: 16) + "." + ext)
    }

    private func trim() {
        var files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        var total = totalSize()
        guard total > maxBytes else { return }

        files.sort { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date.distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date.distantPast
            return da < db
        }

        for f in files {
            if total <= maxBytes { break }
            let s = fileSize(f)
            try? FileManager.default.removeItem(at: f)
            total -= s
        }
    }
}
