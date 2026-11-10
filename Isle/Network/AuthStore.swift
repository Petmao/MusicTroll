import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published var user: IsleUser?
    @Published var ent: Entitlements = .none
    @Published var loading = false
    @Published var error: String?

    var isLoggedIn: Bool { user != nil }
    var isVIP: Bool { ent.canPlayMusic }
    var isSVIP: Bool { ent.canUseVideo }

    func bootstrap() async {
        guard Keychain.get("token") != nil else { return }
        do { let (u, e) = try await APIClient.shared.me(); user = u; ent = e }
        catch { Keychain.del("token") }
    }

    func login(_ account: String, _ password: String) async {
        await run {
            let r = try await APIClient.shared.login(account: account, password: password)
            Keychain.set("token", r.token); user = r.user; ent = r.entitlements
        }
    }

    func register(account: String, nickname: String, password: String, phone: String?, invite: String?) async {
        await run {
            let r = try await APIClient.shared.register(account: account, nickname: nickname, password: password, phone: phone, inviteCode: invite)
            Keychain.set("token", r.token); user = r.user; ent = r.entitlements
        }
    }

    func redeem(_ code: String) async {
        await run {
            let (u, e) = try await APIClient.shared.redeem(code); user = u; ent = e
        }
    }

    func exchange(goods: String) async {
        await run {
            let (u, e) = try await APIClient.shared.exchange(goods: goods); user = u; ent = e
        }
    }

    func refresh() async {
        if let (u, e) = try? await APIClient.shared.me() { user = u; ent = e }
    }

    func uploadAvatar(_ jpeg: Data) async {
        do {
            let path = try await APIClient.shared.uploadAvatar(jpeg)
            if let u = user { user = IsleUser(id: u.id, account: u.account, nickname: u.nickname, avatar: path, role: u.role, roleExpireAt: u.roleExpireAt, phoneMasked: u.phoneMasked, status: u.status, inviteCode: u.inviteCode, points: u.points) }
        } catch { self.error = "头像上传失败" }
    }

    func resetAvatar() async {
        try? await APIClient.shared.resetAvatar()
        await refresh()
    }

    func logout() {
        Keychain.del("token")
        Keychain.del("contentKey")
        user = nil
        ent = .none
    }

    private func run(_ block: @escaping () async throws -> Void) async {
        loading = true; error = nil
        do { try await block() }
        catch APIError.http(let m) { error = friendly(m) }
        catch { error = "网络异常，请检查 ys.irepo.cn 是否可达" }
        loading = false
    }

    private func friendly(_ code: String) -> String {
        switch code {
        case "bad_credentials": return "账号或密码不对"
        case "account_taken": return "这个账号已被占用"
        case "need_vip": return "需要 VIP 会员"
        case "need_svip": return "需要 SVIP 会员"
        case "device_limit": return "设备数已满，请先解绑"
        case "code_used": return "这张卡密已经被用过了"
        case "code_not_found": return "卡密不存在"
        case "not_enough_points": return "积分不够"
        case "already_signed": return "今天已经签到过了"
        case "password_too_short": return "密码至少 8 位"
        case "too_many_requests": return "操作太频繁，稍后再试"
        default: return code
        }
    }
}

/// Keychain 极简封装
enum Keychain {
    static func set(_ key: String, _ value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecReturnData as String: true]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func del(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}
