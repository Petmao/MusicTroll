import SwiftUI

final class MineRouter: ObservableObject {
    @Published var settings = false
    @Published var checkin = false
    @Published var invite = false
    @Published var fav = false
    @Published var cloud = false
    @Published var device = false
}

struct RootView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var tab = 0

    var body: some View {
        ZStack {
            MineTheme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                content
                TabBarView(tab: $tab)
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        if tab == 0 {
            HomeView()
        } else if tab == 1 {
            if auth.ent.canUseVideo { EyesView() }
            else { PaywallView(need: "SVIP", feature: "养眼视频") }
        } else if tab == 2 {
            if auth.ent.canPlayMusic { PlayerView() }
            else { PaywallView(need: "VIP", feature: "在线听歌") }
        } else {
            MineView()
        }
    }
}

struct MineTheme {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let pink = Color(red: 1, green: 0.37, blue: 0.62)
    static let gold = Color(red: 1, green: 0.82, blue: 0.44)
}

struct TabBarView: View {
    @Binding var tab: Int
    var body: some View {
        HStack(spacing: 0) {
            TabItemView(icon: "house", title: "首页", on: tab == 0) { tab = 0 }
            TabItemView(icon: "play.rectangle", title: "养眼", on: tab == 1) { tab = 1 }
            TabItemView(icon: "headphones", title: "播放器", on: tab == 2) { tab = 2 }
            TabItemView(icon: "person", title: "我的", on: tab == 3) { tab = 3 }
        }
        .padding(.top, 9)
        .padding(.bottom, 6)
        .background(MineTheme.bg)
        .overlay(Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.5), alignment: .top)
    }
}

struct TabItemView: View {
    let icon: String
    let title: String
    let on: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).font(.system(size: 9.5))
            }
            .foregroundColor(on ? MineTheme.pink : Color(white: 0.38))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MineView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var r = MineRouter()

    var body: some View {
        NavigationView {
            ZStack {
                MineTheme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        MineMemberCard(nickname: auth.user?.nickname ?? "未登录") { r.settings = true }
                        MineQuickRow(checkin: $r.checkin, invite: $r.invite, fav: $r.fav).padding(.top, 11)
                        MineRecentRow(engine: MusicEngine.shared).padding(.top, 14)
                        MineGrid(fav: $r.fav, cloud: $r.cloud, device: $r.device, settings: $r.settings).padding(.top, 14)
                        MinePlaylists { r.fav = true }.padding(.top, 14)
                        MineSettingsRow { r.settings = true }.padding(.top, 14)
                        Text("屿声音乐 " + Config.version)
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
            NavigationLink(destination: CheckinView(), isActive: $r.checkin) { EmptyView() }
            NavigationLink(destination: InviteView(), isActive: $r.invite) { EmptyView() }
            NavigationLink(destination: LibraryView(), isActive: $r.fav) { EmptyView() }
            NavigationLink(destination: CloudSyncView(), isActive: $r.cloud) { EmptyView() }
            NavigationLink(destination: DeviceView(), isActive: $r.device) { EmptyView() }
        }
        .hidden()
    }
}

struct MineMemberCard: View {
    let nickname: String
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topRow
            progressText
            progressBar
            statsRow
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.13, blue: 0.10),
                                          Color(red: 0.07, green: 0.06, blue: 0.09)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(MineTheme.gold.opacity(0.34), lineWidth: 1))
        .padding(.top, 8)
    }

    private var topRow: some View {
        HStack(spacing: 11) {
            Text(String(nickname.prefix(1)))
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Circle().fill(LinearGradient(colors: [MineTheme.gold, MineTheme.pink],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(Circle().stroke(MineTheme.gold.opacity(0.6), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nickname).font(.system(size: 16, weight: .heavy))
                    Text("SVIP")
                        .font(.system(size: 8.5, weight: .black))
                        .foregroundColor(MineTheme.gold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(MineTheme.gold.opacity(0.18)))
                }
                Text("屿声音乐会员").font(.system(size: 11)).foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
    }

    private var progressText: some View {
        HStack {
            Text("本月会员进度").font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
            Spacer()
            Text("还剩 27 天").font(.system(size: 10, weight: .bold)).foregroundColor(MineTheme.gold)
        }
        .padding(.top, 11)
    }

    private var progressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: [MineTheme.gold, Color(red: 1, green: 0.69, blue: 0.12)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: g.size.width * 0.62)
            }
        }
        .frame(height: 4)
        .padding(.top, 5)
    }

    private var statsRow: some View {
        HStack(spacing: 7) {
            MineStatCell(title: "收藏", value: "12")
            MineStatCell(title: "歌单", value: "2")
            MineStatCell(title: "积分", value: "1280")
            MineStatCell(title: "缓存", value: "0M")
        }
        .padding(.top, 10)
    }
}

struct MineStatCell: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 9)).foregroundColor(.white.opacity(0.45))
            Text(value).font(.system(size: 14, weight: .heavy))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.05)))
    }
}

struct MineQuickRow: View {
    @Binding var checkin: Bool
    @Binding var invite: Bool
    @Binding var fav: Bool

    var body: some View {
        HStack(spacing: 8) {
            MinePill(icon: "heart.fill", title: "收藏", color: MineTheme.pink) { fav = true }
            MinePill(icon: "calendar", title: "签到", color: Color(red: 0.72, green: 0.65, blue: 1)) { checkin = true }
            MinePill(icon: "person.2.fill", title: "邀请", color: Color(red: 0.30, green: 0.90, blue: 0.66)) { invite = true }
        }
    }
}

struct MinePill: View {
    let icon: String
    let title: String
    let color: Color
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MineRecentRow: View {
    @ObservedObject var engine: MusicEngine
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("最近播放").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.62))
                Spacer()
                Text("清空").font(.system(size: 11)).foregroundColor(.gray)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(Array(engine.recent.prefix(8)), id: \.id) { s in
                        MineRecentCell(name: s.name, singer: s.singer) {
                            engine.play(keyword: s.name)
                        }
                    }
                }
            }
        }
    }
}

struct MineRecentCell: View {
    let name: String
    let singer: String
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                  Color(red: 1, green: 0.54, blue: 0)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 70, height: 70)
                Text(name).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                    .frame(width: 70, alignment: .leading)
                Text(singer).font(.system(size: 8.5)).foregroundColor(.gray).lineLimit(1)
                    .frame(width: 70, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MineGrid: View {
    @Binding var fav: Bool
    @Binding var cloud: Bool
    @Binding var device: Bool
    @Binding var settings: Bool

    var body: some View {
        HStack(spacing: 8) {
            MineTile(icon: "heart.fill", title: "收藏\n与歌单", color: MineTheme.pink) { fav = true }
            MineTile(icon: "icloud.fill", title: "云\n同步", color: Color(red: 0.49, green: 0.65, blue: 1)) { cloud = true }
            MineTile(icon: "iphone", title: "设备\n管理", color: Color(red: 0.61, green: 0.55, blue: 1)) { device = true }
            MineTile(icon: "gearshape.fill", title: "设置\n中心", color: Color(red: 0.79, green: 0.65, blue: 1)) { settings = true }
        }
    }
}

struct MineTile: View {
    let icon: String
    let title: String
    let color: Color
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MinePlaylists: View {
    let onTap: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("我的歌单").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.62))
                Spacer()
                Button(action: onTap) {
                    Text("＋ 新建").font(.system(size: 11)).foregroundColor(Color(red: 1, green: 0.56, blue: 0.71))
                }
            }
            HStack(spacing: 9) {
                MinePlaylistCell(name: "我喜欢的音乐", subtitle: "收藏 · 每天更新", onTap: onTap)
                MinePlaylistCell(name: "夜跑 DJ 循环", subtitle: "自定义 · 3.2 小时", onTap: onTap)
            }
        }
    }
}

struct MinePlaylistCell: View {
    let name: String
    let subtitle: String
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [Color(red: 0.48, green: 0.36, blue: 1),
                                                  Color(red: 0, green: 0.83, blue: 1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 86)
                Text(name).font(.system(size: 11.5, weight: .bold)).lineLimit(1)
                Text(subtitle).font(.system(size: 9)).foregroundColor(.gray).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MineSettingsRow: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.10)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("设置").font(.system(size: 13, weight: .semibold))
                    Text("音源 · 视频源 · 精确跳转 · 退出登录")
                        .font(.system(size: 11)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
