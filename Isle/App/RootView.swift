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

struct MineView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var showRedeem = false
    @State private var code = ""

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    vipCard
                    quickGrid
                    sectionTitle("我的歌单")
                    NavigationLink(destination: LibraryView()) {
                        entry(icon: "music.note.list", color: Color(red: 1, green: 0.18, blue: 0.47),
                              title: "收藏与歌单", sub: "收藏歌曲 · 自建歌单")
                    }
                    sectionTitle("会员")
                    Button { showRedeem = true } label: {
                        entry(icon: "ticket", color: Color(red: 1, green: 0.62, blue: 0.25),
                              title: "卡密兑换", sub: "输入卡密开通 VIP / SVIP")
                    }
                    NavigationLink(destination: CheckinView()) {
                        entry(icon: "calendar", color: Color(red: 0.48, green: 0.36, blue: 1),
                              title: "签到与积分", sub: "连签拿积分，积分换会员")
                    }
                    NavigationLink(destination: InviteView()) {
                        entry(icon: "person.2", color: Color(red: 0, green: 0.88, blue: 0.64),
                              title: "邀请好友", sub: "双方各得 7 天 VIP")
                    }
                    sectionTitle("内容与设置")
                    NavigationLink(destination: SearchView()) {
                        entry(icon: "magnifyingglass", color: Color(red: 1, green: 0.37, blue: 0.62),
                              title: "搜索", sub: "全网歌曲")
                    }
                    NavigationLink(destination: SourcesView(kind: "music")) {
                        entry(icon: "waveform", color: Color(red: 1, green: 0.48, blue: 0.18),
                              title: "音乐音源", sub: "后台配置的源")
                    }
                    NavigationLink(destination: SourcesView(kind: "video")) {
                        entry(icon: "play.rectangle", color: Color(red: 0, green: 0.64, blue: 1),
                              title: "视频源", sub: "养眼用")
                    }
                    NavigationLink(destination: CloudSyncView()) {
                        entry(icon: "icloud", color: Color(red: 0.4, green: 0.6, blue: 1),
                              title: "云同步", sub: "歌单与进度")
                    }
                    NavigationLink(destination: LyricsView()) {
                        entry(icon: "text.quote", color: Color(red: 0.7, green: 0.5, blue: 1),
                              title: "全屏歌词", sub: "居中、点行跳转")
                    }
                    NavigationLink(destination: SettingsView()) {
                        entry(icon: "gearshape", color: .gray,
                              title: "设置", sub: "外观 / 精确跳转 / 缓存")
                    }
                    NavigationLink(destination: DeviceManageView()) {
                        entry(icon: "iphone", color: Color(red: 0.48, green: 0.36, blue: 1),
                              title: "设备管理", sub: "绑定与解绑")
                    }

                    Button { auth.logout() } label: {
                        Text("退出登录").font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 1, green: 0.35, blue: 0.55))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .padding(.top, 4)

                    Text("屿声音乐 \(Config.version)")
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.2))
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
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

    private var vipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.25),
                                                  Color(red: 1, green: 0.37, blue: 0.62)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(Text(String((auth.user?.nickname ?? "I").prefix(1)))
                                .font(.system(size: 20, weight: .bold)).foregroundColor(.white))
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
                    Text("账号 \(auth.user?.account ?? "-") · 积分 \(auth.user?.points ?? 0)")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.12, blue: 0.10),
                                          Color(red: 0.07, green: 0.06, blue: 0.09)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(Color(red: 1, green: 0.82, blue: 0.25).opacity(0.35), lineWidth: 1))
        .padding(.top, 12)
    }

    private var quickGrid: some View {
        HStack(spacing: 9) {
            quick(icon: "heart", tint: Color(red: 1, green: 0.37, blue: 0.62), title: "收藏", value: "0")
            quick(icon: "music.note.list", tint: Color(red: 0.48, green: 0.36, blue: 1), title: "歌单", value: "3")
            quick(icon: "arrow.down.circle", tint: Color(red: 0, green: 0.88, blue: 0.64), title: "已缓存", value: "0")
            quick(icon: "iphone", tint: Color(red: 1, green: 0.62, blue: 0.25), title: "设备", value: "—")
        }
    }

    private func quick(icon: String, tint: Color, title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(tint)
            Text(value).font(.system(size: 15, weight: .bold))
            Text(title).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
    }

    private func entry(icon: String, color: Color, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.28)).frame(width: 34, height: 34)
                .overlay(Image(systemName: icon).font(.system(size: 15)).foregroundColor(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                Text(sub).font(.system(size: 10.5)).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.secondary)
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
