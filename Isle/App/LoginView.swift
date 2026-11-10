import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore

    @State private var isRegister = false
    @State private var account = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var phone = ""
    @State private var invite = ""

    private enum Field: Hashable { case nickname, account, password, phone, invite }
    @FocusState private var focused: Field?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.24, green: 0.06, blue: 0.28),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header.padding(.top, 32)
                    switcher.padding(.top, 22)

                    VStack(spacing: 0) {
                        row("昵称", $nickname, "person", .nickname, secure: false, visible: isRegister)
                        row("账号（字母开头，4–16 位）", $account, "at", .account, secure: false, visible: true)
                        row("密码（至少 8 位）", $password, "lock", .password, secure: true, visible: true)
                        row("手机号（选填）", $phone, "phone", .phone, secure: false, visible: isRegister)
                        row("邀请码（选填）", $invite, "gift", .invite, secure: false, visible: isRegister)
                    }
                    .padding(.top, 16)

                    if let e = auth.error {
                        Text(e)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.top, 10)
                    }

                    submitButton.padding(.top, 18)
                    featureList.padding(.top, 26)
                    disclaimer.padding(.top, 20)

                    Text("v\(Config.version)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.18))
                        .padding(.top, 14)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 24)
            }
            .onTapGesture { focused = nil }
        }
    }

    // MARK: - 头部
    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.24, blue: 0.47),
                                                  Color(red: 1, green: 0.62, blue: 0.2)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 92, height: 92)
                    .shadow(color: Color(red: 1, green: 0.24, blue: 0.47).opacity(0.45), radius: 24, y: 10)
                Image(systemName: "music.note")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            Text(Config.appName).font(.system(size: 26, weight: .heavy))
            Text(Config.appNameEn.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(4)
                .foregroundStyle(Color.white.opacity(0.35))
            Text(Config.tagline)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.top, 2)
        }
    }

    // MARK: - 切换
    private var switcher: some View {
        HStack(spacing: 4) {
            seg("登录", 0)
            seg("注册", 1)
        }
        .padding(4)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func seg(_ title: String, _ index: Int) -> some View {
        let active = (isRegister ? 1 : 0) == index
        return Button {
            focused = nil
            isRegister = (index == 1)
            auth.error = nil
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(active
                            ? LinearGradient(colors: [Color(red: 1, green: 0.24, blue: 0.47),
                                                      Color(red: 1, green: 0.48, blue: 0.18)],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.clear, Color.clear],
                                             startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 输入行（始终在视图树里，只切显示，避免 iOS 15 焦点重建崩溃）
    @ViewBuilder
    private func row(_ title: String, _ binding: Binding<String>, _ symbol: String,
                     _ id: Field, secure: Bool, visible: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 20)

            if secure {
                SecureField(title, text: binding)
                    .focused($focused, equals: id)
                    .submitLabel(.done)
            } else {
                TextField(title, text: binding)
                    .focused($focused, equals: id)
                    .keyboardType(id == .phone ? .numberPad : .default)
                    .submitLabel(id == .password ? .done : .next)
            }
        }
        .font(.system(size: 15))
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .padding(.bottom, visible ? 10 : 0)
        .frame(height: visible ? nil : 0)
        .opacity(visible ? 1 : 0)
        .clipped()
        .allowsHitTesting(visible)
    }

    // MARK: - 主按钮
    private var submitButton: some View {
        let ready = !account.isEmpty && password.count >= 8 && !auth.loading
        return Button(action: submit) {
            HStack(spacing: 8) {
                if auth.loading { ProgressView().tint(Color.white) }
                Text(isRegister ? "注册并登录" : "登录")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(LinearGradient(colors: [Color(red: 1, green: 0.24, blue: 0.47),
                                                Color(red: 1, green: 0.48, blue: 0.18)],
                                       startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(red: 1, green: 0.24, blue: 0.47).opacity(0.35), radius: 16, y: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!ready)
        .opacity(ready ? 1 : 0.55)
    }

    // MARK: - 卖点
    private var featureList: some View {
        VStack(spacing: 12) {
            feature("square.stack.3d.up", "多源并发", "一次搜索同时问 5 个音源，先到先出")
            feature("waveform", "无损音质", "FLAC 24bit / 逐字歌词 / 后台播放")
            feature("lock.shield", "本地加密", "导入的音乐用设备密钥加密存储")
        }
        .padding(.horizontal, 2)
    }

    private func feature(_ symbol: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.62))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(desc).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 免责声明
    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
                Text("免责声明")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            Text(Config.disclaimer)
                .font(.system(size: 10))
                .lineSpacing(3)
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func submit() {
        focused = nil
        Task {
            if isRegister {
                await auth.register(account: account,
                                    nickname: nickname.isEmpty ? account : nickname,
                                    password: password,
                                    phone: phone.isEmpty ? nil : phone,
                                    invite: invite.isEmpty ? nil : invite)
            } else {
                await auth.login(account, password)
            }
        }
    }
}
