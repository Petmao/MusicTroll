import Foundation

struct IsleUser: Codable, Identifiable {
    let id: Int
    let account: String
    let nickname: String
    let avatar: String?
    let role: String
    let roleExpireAt: Int?
    let phoneMasked: String?
    let status: String
    let inviteCode: String?
    let points: Int?
}

struct Entitlements: Codable {
    let canPlayMusic: Bool
    let canUseVideo: Bool
    let canManageSources: Bool
    static let none = Entitlements(canPlayMusic: false, canUseVideo: false, canManageSources: false)
}

struct AuthPayload: Codable { let token: String; let user: IsleUser; let entitlements: Entitlements }

enum APIError: Error, LocalizedError {
    case http(String)
    var errorDescription: String? { if case .http(let m) = self { return m }; return nil }
}

/// 统一网络层：baseURL 来自 Config.apiBaseURL（默认 https://ys.irepo.cn）
final class APIClient {
    static let shared = APIClient()
    var baseURL: URL { Config.apiBaseURL }

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        c.waitsForConnectivity = true
        return URLSession(configuration: c)
    }()

    /// 关键：query 必须原样保留，不能走 appendingPathComponent（会把 ? 转成 %3F 导致 404）
    private func buildURL(_ path: String) -> URL? {
        let p = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: p, relativeTo: baseURL)?.absoluteURL
    }

    private func raw(_ path: String, method: String = "GET", body: Any? = nil) async throws -> Data {
        guard let url = buildURL(path) else { throw APIError.http("地址无效") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = Keychain.get("token") { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.http("no_response") }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "\(http.statusCode)"
            throw APIError.http(msg)
        }
        return data
    }

    func get<T: Decodable>(_ path: String) async throws -> T { try JSONDecoder().decode(T.self, from: await raw(path)) }
    func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try JSONDecoder().decode(T.self, from: await raw(path, method: "POST", body: body))
    }
    func put<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try JSONDecoder().decode(T.self, from: await raw(path, method: "PUT", body: body))
    }
    func delete(_ path: String) async throws { _ = try await raw(path, method: "DELETE") }

    // MARK: - 账号
    func register(account: String, nickname: String, password: String, phone: String?, inviteCode: String?) async throws -> AuthPayload {
        var b: [String: Any] = ["account": account, "nickname": nickname, "password": password]
        if let phone, !phone.isEmpty { b["phone"] = phone }
        if let inviteCode, !inviteCode.isEmpty { b["inviteCode"] = inviteCode }
        return try await post("/api/auth/register", body: b)
    }
    func login(account: String, password: String) async throws -> AuthPayload {
        try await post("/api/auth/login", body: ["account": account, "password": password])
    }
    func me() async throws -> (IsleUser, Entitlements) {
        struct R: Decodable { let user: IsleUser; let entitlements: Entitlements }
        let r: R = try await get("/api/auth/me")
        return (r.user, r.entitlements)
    }
    func checkAccount(_ a: String) async throws -> Bool {
        struct R: Decodable { let ok: Bool }
        let q = a.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? a
        let r: R = try await get("/api/auth/check-account?account=\(q)")
        return r.ok
    }
    func changePassword(old: String, new: String) async throws {
        struct R: Decodable { let ok: Bool }
        let _: R = try await post("/api/auth/password", body: ["oldPassword": old, "newPassword": new])
    }

    // MARK: - 会员 / 卡密 / 积分 / 邀请
    func redeem(_ code: String) async throws -> (IsleUser, Entitlements) {
        struct R: Decodable { let user: IsleUser; let entitlements: Entitlements }
        let r: R = try await post("/api/redeem", body: ["code": code])
        return (r.user, r.entitlements)
    }
    func checkinStatus() async throws -> CheckinStatus { try await get("/api/checkin/status") }
    func checkin() async throws -> CheckinResult { try await post("/api/checkin", body: [:]) }
    func pointsGoods() async throws -> GoodsBundle { try await get("/api/points/goods") }
    func exchange(goods: String) async throws -> (IsleUser, Entitlements) {
        struct R: Decodable { let user: IsleUser; let entitlements: Entitlements }
        let r: R = try await post("/api/points/exchange", body: ["goods": goods])
        return (r.user, r.entitlements)
    }
    func invite() async throws -> InviteInfo { try await get("/api/invite/me") }

    // MARK: - 头像 / 设备
    func uploadAvatar(_ jpeg: Data) async throws -> String {
        struct R: Decodable { let avatar: String }
        let r: R = try await post("/api/user/avatar", body: ["image": jpeg.base64EncodedString()])
        return r.avatar
    }
    func resetAvatar() async throws { try await delete("/api/user/avatar") }
    func registerDevice(_ id: String, name: String) async throws -> DeviceKeyResp {
        try await post("/api/device/register", body: ["deviceId": id, "name": name])
    }
    func deviceList(_ id: String) async throws -> DeviceListResp {
        let q = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return try await get("/api/device/list?deviceId=\(q)")
    }
    func unbindDevice(_ id: String) async throws {
        struct R: Decodable { let graceUntil: Int? }
        let _: R = try await post("/api/device/unbind", body: ["deviceId": id, "reason": "user"])
    }

    // MARK: - 播放
    func playTicket(url: String, kind: String) async throws -> Ticket {
        try await post("/api/play/ticket", body: ["url": url, "kind": kind])
    }
    func localPermit(fileId: String, name: String) async throws -> LocalPermit {
        try await post("/api/play/permit", body: ["fileId": fileId, "name": name])
    }
    func checkPermit(fileId: String, permit: String) async throws -> PermitCheck {
        try await post("/api/play/permit/check", body: ["fileId": fileId, "permit": permit])
    }

    // MARK: - 云同步
    func cloudPlaylists() async throws -> [CloudPlaylist] {
        let r: CloudListResp = try await get("/api/cloud/playlists")
        return r.rows
    }
    func savePlaylist(pid: String, name: String, songs: [String], rev: Int?) async throws -> Int {
        var b: [String: Any] = ["name": name, "songs": songs]
        if let rev { b["rev"] = rev }
        let r: SaveRev = try await put("/api/cloud/playlists/\(pid)", body: b)
        return r.rev
    }
    func deletePlaylist(pid: String) async throws { try await delete("/api/cloud/playlists/\(pid)") }
    func saveProgress(trackKey: String, positionMs: Int, durationMs: Int) async throws {
        struct R: Decodable { let ok: Bool? }
        let _: R = try await post("/api/cloud/progress", body: ["trackKey": trackKey, "positionMs": positionMs, "durationMs": durationMs])
    }
    func progress(trackKey: String) async throws -> ProgressResp? {
        let q = trackKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackKey
        return try? await get("/api/cloud/progress/\(q)")
    }
}

// MARK: - 传输类型
struct Ticket: Codable { let path: String; let exp: Int; let ttl: Int }
struct LocalPermit: Codable { let permit: String; let exp: Int; let ttl: Int; let heartbeat: Int }
struct PermitCheck: Codable { let ok: Bool?; let permit: String?; let exp: Int? }
struct DeviceKeyResp: Codable { let keyId: Int; let key: String }
struct DeviceDTO: Codable, Identifiable {
    var id: String { deviceId }
    let deviceId: String; let name: String; let status: String
    let graceUntil: Int?; let lastSeenAt: Int?; let isCurrent: Bool
}
struct DeviceListResp: Codable { let limit: Int; let used: Int; let unbindCooldownLeftMs: Int; let graceHours: Int; let devices: [DeviceDTO] }
struct CheckinStatus: Codable { let todaySigned: Bool; let streak: Int; let balance: Int; let rewards: [Int] }
struct CheckinResult: Codable { let streak: Int; let points: Int; let balance: Int; let bonus: String? }
struct Goods: Codable { let role: String; let days: Int; let cost: Int }
struct GoodsBundle: Codable { let balance: Int; let goods: [String: Goods] }
struct InviteItem: Codable { let status: String; let nickname: String? }
struct InviteInfo: Codable { let code: String; let count: Int; let redeemed: Int; let list: [InviteItem] }
struct CloudPlaylist: Codable { let pid: String; let name: String; let cover: String?; let songs: [String]; let rev: Int }
struct CloudListResp: Codable { let rows: [CloudPlaylist] }
struct SaveRev: Codable { let rev: Int }
struct ProgressResp: Codable { let positionMs: Int; let durationMs: Int }
