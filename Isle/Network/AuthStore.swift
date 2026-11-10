import Foundation
import SwiftUI

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
        do {
            let (u, e) = try await APIClient.shared.me()
            self.user = u; self.ent = e
        } catch {
            Keychain.del("token")
        }
    }

    func login(_ account: String, _ password: String) async {
        self.loading = true; self.error = nil
        do {
            let r = try await APIClient.shared.login(account: account, password: password)
            Keychain.set("token", r.token)
            self.user = r.user; self.ent = r.entitlements
        } catch { self.error = Self.friendly(error) }
        self.loading = false
    }

    func register(account: String, nickname: String, password: String, phone: String?, invite: String?) async {
        self.loading = true; self.error = nil
        do {
            let r = try await APIClient.shared.register(account: account, nickname: nickname,
                                                       password: password, phone: phone, inviteCode: invite)
            Keychain.set("token", r.token)
            self.user = r.user; self.ent = r.entitlements
        } catch { self.error = Self.friendly(error) }
        self.loading = false
    }

    func redeem(_ code: String) async {
        guard !code.isEmpty else { return }
        self.error = nil
        do {
            let (u, e) = try await APIClient.shared.redeem(code)
            self.user = u; self.ent = e
        } catch { self.error = Self.friendly(error) }
    }

    func exchange(goods: String) async {
        do {
            let (u, e) = try await APIClient.shared.exchange(goods: goods)
            self.user = u; self.ent = e
        } catch { self.error = Self.friendly(error) }
    }

    func refresh() async {
        if let (u, e) = try? await APIClient.shared.me() { self.user = u; self.ent = e }
    }

    func uploadAvatar(_ jpeg: Data) async {
        do {
            _ = try await APIClient.shared.uploadAvatar(jpeg)
            await self.refresh()
        } catch { self.error = "头像上传失败" }
    }

    func resetAvatar() async {
        try? await APIClient.shared.resetAvatar()
        await self.refresh()
    }

    func logout() {
        Keychain.del("token")
        Keychain.del("contentKey")
        self.user = nil
        self.ent = .none
    }

    private static func friendly(_ e: Error) -> String {
        guard case APIError.http(let code) = e else { return "网络异常，请检查服务器是否可达" }
        switch code {
        case "bad_credentials": return "账号或密码不对"
        case "account_taken": return "这个账号已被占用"
        case "bad_account": return "账号需字母开头、4–16 位字母或数字"
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
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key,
                                kSecReturnData as String: true]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func del(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}
