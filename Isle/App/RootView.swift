import SwiftUI

final class MineRouter: ObservableObject {
    @Published var settings = false
    @Published var card = false
    @Published var checkin = false
    @Published var invite = false
    @Published var fav = false
    @Published var cloud = false
    @Published var lyric = false
    @Published var device = false
}

struct RootView: View {
    @State private var tab = 0
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case 0: HomeView()
                    case 1: VideoFeedView()
                    case 2: PlayerView()
                    default: MineView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                tabBar
            }
        }
        .preferredColorScheme(.dark)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            item(0, "house", "首页")
            item(1, "play.rectangle", "养眼")
            item(2, "headphones", "播放器")
            item(3, "person", "我的")
        }
        .padding(.top, 9)
        .padding(.bottom, 6)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .overlay(Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5), alignment: .top)
    }

    private func item(_ idx: Int, _ icon: String, _ title: String) -> some View {
        Button { tab = idx } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).font(.system(size: 9.5))
            }
            .foregroundColor(tab == idx ? Color(red: 1, green: 0.37, blue: 0.62) : Color(white: 0.38))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MinePlaylist: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let count: Int
}

struct MineView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var engine = MusicEngine.shared
    @StateObject private var r = MineRouter()

    private let playlists = [
        MinePlaylist(name: "我喜欢的音乐", subtitle: "收藏 · 每天更新", count: 128),
        MinePlaylist(name: "夜跑 DJ 循环", subtitle: "自定义 · 3.2 小时", count: 46)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        memberCard
                        quickRow.padding(.top, 11)
                        recentRow.padding(.top, 14)
                        gridRow.padding(.top, 14)
                        playlistRow.padding(.top, 14)
                        settingsRow.padding(.top, 14)
                        Text("屿声音乐 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.9.2")")
                            .font(.system(size: 9.5)).foregroundColor(.white.opacity(0.2))
                            .padding(.top, 14).padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarHidden(true)
            .background(links)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var links: some View {
        VStack {
            NavigationLink(destination: SettingsView(), isActive: $r.settings) { EmptyView() }
            NavigationLink(destination: CardRedeemView(), isActive: $r.card) { EmptyView() }
            NavigationLink(destination: CheckinView(), isActive: $r.checkin) { EmptyView() }
            NavigationLink(destination: InviteView(), isActive: $r.invite) { EmptyView() }
            NavigationLink(destination: LibraryView(), isActive: $r.fav) { EmptyView() }
            NavigationLink(destination: CloudSyncView(), isActive: $r.cloud) { EmptyView() }
            NavigationLink(destination: LyricsView(), isActive: $r.lyric) { EmptyView() }
            NavigationLink(destination: DeviceView(), isActive: $r.device) { EmptyView() }
        }
        .hidden()
    }

    private var memberCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Text(String((auth.user?.nickname ?? "猫").prefix(1)))
                    .font(.system(size: 18, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.70, blue: 0.28),
                                                                     Color(red: 1, green: 0.37, blue: 0.62)],
                                                            startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Circle().stroke(Color(red: 1, green: 0.82, blue: 0.44).opacity(0.6), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(auth.user?.nickname ?? "未登录").font(.system(size: 16, weight: .heavy))
                        Text((auth.user?.vipLevel ?? "SVIP").uppercased())
                            .font(.system(size: 8.5, weight: .black))
                            .foregroundColor(Color(red: 1, green: 0.85, blue: 0.44))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 1, green: 0.82, blue: 0.44).opacity(0.18)))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 1, green: 0.82, blue: 0.44).opacity(0.5), lineWidth: 0.7))
                    }
                    Text("账号 \(auth.user?.username ?? "—")").font(.system(size: 11)).foregroundColor(.gray)
                }
                Spacer(minLength: 8)
                Button { r.settings = true } label: {
                    Image(systemName: "gearshape.fill").font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }

            HStack {
                Text("本月会员进度").font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
                Spacer()
                Text("还剩 27 天").font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 1, green: 0.85, blue: 0.44))
            }
            .padding(.top, 11)

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.44),
                                                            Color(red: 1, green: 0.69, blue: 0.12)],
                                                   startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * 0.62)
                }
            }
            .frame(height: 4).padding(.top, 5)

            HStack(spacing: 7) {
                stat("收藏", "\(engine.recent.count)")
                stat("歌单", "\(playlists.count)")
                stat("积分", "\(auth.user?.points ?? 0)")
                stat("缓存", "0M")
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.13, blue: 0.10),
                                          Color(red: 0.07, green: 0.06, blue: 0.09)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(Color(red: 1, green: 0.82, blue: 0.44).opacity(0.34), lineWidth: 1))
        .padding(.top, 8)
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 3) {
            Text(t).font(.system(size: 9)).foregroundColor(.white.opacity(0.45))
            Text(v).font(.system(size: 14, weight: .heavy))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(red: 1, green: 0.82, blue: 0.44).opacity(0.14), lineWidth: 0.6))
    }

    private var quickRow: some View {
        HStack(spacing: 8) {
            pill("ticket.fill", "卡密", .orange) { r.card = true }
            pill("calendar", "签到", Color(red: 0.72, green: 0.65, blue: 1)) { r.checkin = true }
            pill("person.2.fill", "邀请", Color(red: 0.30, green: 0.90, blue: 0.66)) { r.invite = true }
        }
    }

    private func pill(_ icon: String, _ title: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var recentRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("最近播放").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.62))
                Spacer()
                Text("清空").font(.system(size: 11)).foregroundColor(.gray)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(engine.recent.prefix(8)) { s in
                        Button { engine.play(song: s) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                                  Color(red: 1, green: 0.54, blue: 0)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 70, height: 70)
                                Text(s.name).font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1).frame(width: 70, alignment: .leading)
                                Text(s.singer).font(.system(size: 8.5)).foregroundColor(.gray)
                                    .lineLimit(1).frame(width: 70, alignment: .leading)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    private var gridRow: some View {
        HStack(spacing: 8) {
            tile("heart.fill", "收藏\n与歌单", Color(red: 1, green: 0.37, blue: 0.62)) { r.fav = true }
            tile("icloud.fill", "云\n同步", Color(red: 0.49, green: 0.65, blue: 1)) { r.cloud = true }
            tile("quote.bubble", "全屏\n歌词", Color(red: 0.79, green: 0.65, blue: 1)) { r.lyric = true }
            tile("iphone", "设备\n管理", Color(red: 0.61, green: 0.55, blue: 1)) { r.device = true }
        }
    }

    private func tile(_ icon: String, _ title: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                Text(title).font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var playlistRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("我的歌单").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.62))
                Spacer()
                Button { r.fav = true } label: {
                    Text("＋ 新建").font(.system(size: 11)).foregroundColor(Color(red: 1, green: 0.56, blue: 0.71))
                }
            }
            HStack(spacing: 9) {
                ForEach(playlists) { p in
                    Button { r.fav = true } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            RoundedRectangle(cornerRadius: 13)
                                .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.36, blue: 1),
                                                              Color(red: 0, green: 0.83, blue: 1)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 86)
                                .overlay(Text("\(p.count) 首").font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Capsule().fill(Color.black.opacity(0.35))),
                                         alignment: .bottomTrailing)
                            Text(p.name).font(.system(size: 11.5, weight: .bold)).lineLimit(1)
                            Text(p.subtitle).font(.system(size: 9)).foregroundColor(.gray).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var settingsRow: some View {
        Button { r.settings = true } label: {
            HStack(spacing: 11) {
                Image(systemName: "gearshape.fill").font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.10)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("设置").font(.system(size: 13, weight: .semibold))
                    Text("音源 · 视频源 · 精确跳转 · 退出登录").font(.system(size: 11)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 9).padding(.horizontal, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
