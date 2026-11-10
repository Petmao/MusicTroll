import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var isRegister = false
    @State private var account = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var phone = ""
    @State private var invite = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.24, green: 0.06, blue: 0.28),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    icon
                    Text(Config.appName).font(.system(size: 26, weight: .heavy))
                    Text(Config.tagline).font(.caption).foregroundStyle(.white.opacity(0.45))

                    HStack(spacing: 4) {
                        seg("登录", 0); seg("注册", 1)
                    }
                    .padding(4)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.top, 6)

                    if isRegister { field("昵称", $nickname, "person") }
                    field("账号（字母开头，4–16 位）", $account, "at")
                    field("密码（至少 8 位）", $password, "lock", secure: true)
                    if isRegister {
                        field("手机号（选填）", $phone, "phone")
                        field("邀请码（选填）", $invite, "gift")
                    }

                    if let e = auth.error {
                        Text(e).font(.caption).foregroundStyle(Color(red: 1, green: 0.45, blue: 0.6))
                    }

                    Button(action: submit) {
                        HStack {
                            if auth.loading { ProgressView().tint(.white) }
                            Text(isRegister ? "注册并登录" : "登录").font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(LinearGradient(colors: [Color(red: 1, green: 0.24, blue: 0.47),
                                                            Color(red: 1, green: 0.48, blue: 0.18)],
                                                   startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(auth.loading || account.isEmpty || password.count < 8)
                    .opacity(account.isEmpty || password.count < 8 ? 0.55 : 1)

                    Text("登录后可使用音源与视频源；听歌需 VIP，养眼需 SVIP\n接口：\(Config.apiBaseURL.host ?? "")")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
                .padding(24)
            }
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.24, blue: 0.47),
                                              Color(red: 1, green: 0.62, blue: 0.2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 96, height: 96)
                .shadow(color: Color(red: 1, green: 0.24, blue: 0.47).opacity(0.45), radius: 22, y: 10)
            Image(systemName: "music.note")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.top, 40)
    }

    private func seg(_ title: String, _ index: Int) -> some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { isRegister = index == 1; auth.error = nil } } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle((isRegister ? 1 : 0) == index ? .white : .white.opacity(0.45))
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background((isRegister ? 1 : 0) == index
                            ? AnyView(LinearGradient(colors: [Color(red: 1, green: 0.24, blue: 0.47),
                                                              Color(red: 1, green: 0.48, blue: 0.18)],
                                                     startPoint: .leading, endPoint: .trailing))
                            : AnyView(Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    private func field(_ title: String, _ binding: Binding<String>, _ symbol: String, secure: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(.white.opacity(0.4)).frame(width: 20)
            if secure {
                SecureField(title, text: binding).textInputAutocapitalization(.never)
            } else {
                TextField(title, text: binding).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        }
        .font(.system(size: 15))
        .padding(.horizontal, 15).padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    private func submit() {
        Task {
            if isRegister {
                await auth.register(account: account, nickname: nickname.isEmpty ? account : nickname,
                                    password: password, phone: phone.isEmpty ? nil : phone,
                                    invite: invite.isEmpty ? nil : invite)
            } else {
                await auth.login(account, password)
            }
        }
    }
}
