import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        TabView {
            HomeView().tabItem { Label("首页", systemImage: "house") }
            Group {
                if auth.ent.canUseVideo { EyesView() }
                else { PaywallView(need: "SVIP", feature: "养眼视频") }
            }.tabItem { Label("养眼", systemImage: "play.rectangle") }
            Group {
                if auth.ent.canPlayMusic { PlayerView() }
                else { PaywallView(need: "VIP", feature: "在线听歌") }
            }.tabItem { Label("播放器", systemImage: "headphones") }
            MineView().tabItem { Label("我的", systemImage: "person") }
        }
        .tint(Color(red: 1, green: 0.37, blue: 0.62))
    }
}

struct PaywallView: View {
    let need: String
    let feature: String
    @EnvironmentObject var auth: AuthStore
    @State private var code = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "crown.fill").font(.system(size: 42))
                    .foregroundColor(Color(red: 1, green: 0.82, blue: 0.25))
                Text("\(need) 才能使用\(feature)").font(.system(size: 20, weight: .bold))
                Text("当前账号：\(auth.user?.account ?? "-")")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                HStack(spacing: 8) {
                    TextField("MT-XXXXXXXXXXXX", text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled(true)
                        .padding(12).background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("兑换") { Task { await auth.redeem(code.trimmingCharacters(in: .whitespaces)) } }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color(red: 1, green: 0.24, blue: 0.47)).foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.padding(.top, 8)
                if let e = auth.error { Text(e).font(.system(size: 12)).foregroundColor(.pink) }
            }.padding(24)
        }
    }
}

/// 我的：极简四块（会员卡 → 快捷三键 → 四宫格 → 设置）
struct MineView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var showRedeem = false
    @State private var code = ""

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    vipCard
                    quickThree
                    gridFour
                    settingsRow
                    Button { auth.logout() } label: {
                        Text("退出登录").font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 1, green: 0.35, blue: 0.55))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    Text("屿声音乐 \(Config.version)")
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.2))
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showRedeem) {
            VStack(spacing: 16) {
                Text("卡密兑换").font(.headline).padding(.top, 24)
                TextField("MT-XXXXXXXXXXXX", text: $code)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled(true)
                    .padding(12).background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 24)
                Button("确认兑换") {
                    Task { await auth.redeem(code.trimmingCharacters(in: .whitespaces)); showRedeem = false }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Color(red: 1, green: 0.24, blue: 0.47)).foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 13)).padding(.horizontal, 24)
                Spacer()
            }
        }
    }

    // 1) 会员卡
    private var vipCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.25),
                                              Color(red: 1, green: 0.37, blue: 0.62)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(Text(String((auth.user?.nickname ?? "I").prefix(1)))
                            .font(.system(size: 20, weight: .bold)).foregroundColor(.white))
                .overlay(Circle().stroke(Color(red: 1, green: 0.82, blue: 0.25).opacity(0.55), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(auth.user?.nickname ?? "-").font(.system(size: 17, weight: .heavy))
                    Text((auth.user?.role ?? "free").uppercased())
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.14, green: 0.06, blue: 0))
                        .foregroundColor(Color(red: 1, green: 0.84, blue: 0.43))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                Text("账号 \(auth.user?.account ?? "-")　积分 \(auth.user?.points ?? 0)")
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17)).foregroundColor(.white.opacity(0.75))
                    .padding(8).background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.12, blue: 0.10),
                                          Color(red: 0.07, green: 0.06, blue: 0.09)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(Color(red: 1, green: 0.82, blue: 0.25).opacity(0.35), lineWidth: 1))
    }

    // 2) 三键：卡密 / 签到 / 邀请
    private var quickThree: some View {
        HStack(spacing: 9) {
            Button { showRedeem = true } label: {
                pill(icon: "ticket", text: "卡密", tint: Color(red: 1, green: 0.62, blue: 0.25))
            }
            NavigationLink(destination: CheckinView()) {
                pill(icon: "calendar", text: "签到", tint: Color(red: 0.48, green: 0.36, blue: 1))
            }
            NavigationLink(destination: InviteView()) {
                pill(icon: "person.2", text: "邀请", tint: Color(red: 0, green: 0.88, blue: 0.64))
            }
        }
    }

    private func pill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(tint)
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // 3) 四宫格：收藏 / 歌单 / 云同步 / 设备
    private var gridFour: some View {
        HStack(spacing: 9) {
            NavigationLink(destination: LibraryView()) {
                tile(icon: "heart.fill", text: "收藏\n与歌单", tint: Color(red: 1, green: 0.37, blue: 0.62))
            }
            NavigationLink(destination: CloudSyncView()) {
                tile(icon: "icloud.fill", text: "云\n同步", tint: Color(red: 0.4, green: 0.6, blue: 1))
            }
            NavigationLink(destination: LyricsView()) {
                tile(icon: "text.quote", text: "全屏\n歌词", tint: Color(red: 0.7, green: 0.5, blue: 1))
            }
            NavigationLink(destination: DeviceManageView()) {
                tile(icon: "iphone", text: "设备\n管理", tint: Color(red: 0.48, green: 0.36, blue: 1))
            }
        }
    }

    private func tile(icon: String, text: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 17)).foregroundColor(tint)
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // 4) 设置入口
    private var settingsRow: some View {
        NavigationLink(destination: SettingsView()) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.10)).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "gearshape.fill")
                                .font(.system(size: 15)).foregroundColor(.white.opacity(0.7)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("设置").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Text("音源 · 视频源 · 精确跳转 · 外观 · 关于")
                        .font(.system(size: 10.5)).foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
