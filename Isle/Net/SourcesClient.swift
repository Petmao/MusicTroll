import Foundation

enum SourceFetchError: LocalizedError {
    case unauthorized
    case notConfigured
    case emptyAddress
    case timeout
    case certificate
    case server(Int)
    case badPayload

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "登录已过期，请重新登录后再试"
        case .notConfigured: return "后台还没有配置视频源"
        case .emptyAddress: return "后台视频源地址为空"
        case .timeout: return "网络或服务器无响应，请稍后重试"
        case .certificate: return "HTTPS 证书校验失败，请更换地址"
        case let .server(code): return "服务器返回 \(code)"
        case .badPayload: return "返回内容不是有效脚本"
        }
    }
}

final class SourcesClient {
    static let shared = SourcesClient()
    private let base = "https://ys.irepo.cn"

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "auth.token") }
        set { UserDefaults.standard.set(newValue, forKey: "auth.token") }
    }

    func fetch(kind: String = "video", retryOn401: Bool = true) async throws -> [String: Any] {
        guard let url = URL(string: "\(base)/api/sources?kind=\(kind)") else { throw SourceFetchError.notConfigured }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let t = token, !t.isEmpty { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            switch e.code {
            case .timedOut: throw SourceFetchError.timeout
            case .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot, .secureConnectionFailed:
                throw SourceFetchError.certificate
            default: throw SourceFetchError.timeout
            }
        }

        guard let http = resp as? HTTPURLResponse else { throw SourceFetchError.timeout }

        if http.statusCode == 401 {
            if retryOn401, await relogin() { return try await fetch(kind: kind, retryOn401: false) }
            throw SourceFetchError.unauthorized
        }
        if http.statusCode == 404 { throw SourceFetchError.notConfigured }
        guard (200..<300).contains(http.statusCode) else { throw SourceFetchError.server(http.statusCode) }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SourceFetchError.badPayload
        }
        let addr = (obj["url"] as? String) ?? (obj["address"] as? String) ?? ""
        if addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SourceFetchError.emptyAddress
        }
        return obj
    }

    private func relogin() async -> Bool {
        let d = UserDefaults.standard
        guard let u = d.string(forKey: "auth.username"),
              let p = d.string(forKey: "auth.password"),
              let url = URL(string: "\(base)/api/auth/login") else { return false }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["username": u, "password": p])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = obj["token"] as? String else { return false }
        token = newToken
        return true
    }
}
