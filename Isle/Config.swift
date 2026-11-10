import Foundation

/// 全局配置：改域名只改这一处
enum Config {
    /// 服务端地址（末尾不要加斜杠）
    static let apiBaseURL = URL(string: "https://ys.irepo.cn")!

    static let appName = "屿声音乐"
    static let appNameShort = "屿声"
    static let appNameEn = "Isle"
    static let tagline = "让音乐回到你手里"

    /// 本地加密容器目录
    static var encryptedDir: URL {
        let d = URL.documents.appendingPathComponent("Encrypted", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// 分块大小（与 .mte 容器一致）
    static let mteChunkSize = 64 * 1024

    /// 本地播放通行证续签间隔（秒），服务端会返回更精确的值
    static let permitHeartbeat: TimeInterval = 60
}

extension URL {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
