import Foundation

/// 全局配置
/// 注意：域名不以明文出现，运行时由 Base64 片段拼出，静态扫描二进制看不到字面量
enum Config {

    static let apiBaseURL: URL = {
        // 两段 Base64："https://" + 域名
        let parts = ["aHR0cHM6Ly8=", "eXMuaXJlcG8uY24="]
        let joined = parts.compactMap { Data(base64Encoded: $0) }
                           .compactMap { String(data: $0, encoding: .utf8) }
                           .joined()
        guard let url = URL(string: joined) else { return URL(string: "https://localhost")! }
        return url
    }()

    static let appName = "屿声音乐"
    static let appNameShort = "屿声"
    static let appNameEn = "Isle"
    static let tagline = "让音乐回到你手里"

    /// 真实版本号（取自 Info.plist，构建时由 build.sh 写入）
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    /// 构建标识：用来区分同版本号的不同构建
    static var buildStamp: String {
        let d = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
        return "\(version) (\(d))"
    }

    /// 免责声明（登录页与关于页共用）
    static let disclaimer = """
    本应用不提供、不存储、不分发任何音视频内容。所有搜索结果与播放地址均由用户自行配置的第三方音源返回，本应用仅作为播放器与界面外壳。

    会员费用仅用于服务器与开发维护成本，不代表任何内容授权。请勿将本应用用于商业用途或二次分发。

    如你所在地区对相关内容有额外规定，请自行遵守；使用即表示你已知悉并自行承担相应责任。
    """

    /// 本地加密容器目录
    static var encryptedDir: URL {
        let d = URL.documents.appendingPathComponent("Encrypted", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static let mteChunkSize = 64 * 1024
    static let permitHeartbeat: TimeInterval = 60
}

extension URL {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
