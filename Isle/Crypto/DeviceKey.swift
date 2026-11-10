import Foundation

/// 每设备内容密钥：登录 VIP 后向服务端领取，存 Keychain（本机专属，不随备份迁移）
enum DeviceKey {
    static var deviceId: String {
        if let s = Keychain.get("deviceId") { return s }
        let s = UUID().uuidString
        Keychain.set("deviceId", s)
        return s
    }

    static func contentKey() async throws -> SymmetricKey {
        if let b64 = Keychain.get("contentKey"), let d = Data(base64Encoded: b64) {
            return SymmetricKey(data: d)
        }
        let r: DeviceKeyResp = try await APIClient.shared.registerDevice(deviceId, name: deviceModel())
        guard let d = Data(base64Encoded: r.key) else { throw APIError.http("bad_key") }
        Keychain.set("contentKey", r.key)
        return SymmetricKey(data: d)
    }

    static func clear() { Keychain.del("contentKey") }

    static func deviceModel() -> String {
        var sys = utsname()
        uname(&sys)
        let machine = withUnsafeBytes(of: &sys.machine) { Array($0) }
        return String(decoding: machine.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
}

/// 本地导入：加密后立即删除明文
enum LocalImport {
    static func encrypt(_ src: URL) async throws -> URL {
        let key = try await DeviceKey.contentKey()
        let dest = Config.encryptedDir.appendingPathComponent(UUID().uuidString + ".mte")
        try MTEWriter.encrypt(source: src, dest: dest, key: key, mime: mime(of: src))
        return dest
    }

    static func mime(of url: URL) -> UInt8 {
        switch url.pathExtension.lowercased() {
        case "m4a", "aac": return MTE.mimeM4A
        case "flac": return MTE.mimeFLAC
        case "wav": return MTE.mimeWAV
        case "mp4", "mov": return MTE.mimeMP4
        default: return MTE.mimeMP3
        }
    }
}
