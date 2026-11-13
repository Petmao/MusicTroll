import SwiftUI

final class MineRouter: ObservableObject {
    @Published var settings = false
    @Published var checkin = false
    @Published var invite = false
    @Published var fav = false
    @Published var cloud = false
    @Published var device = false
    @Published var musicSource = false
    @Published var videoSource = false
    @Published var redeem = false
}

struct MineTheme {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let pink = Color(red: 1, green: 0.37, blue: 0.62)
    static let gold = Color(red: 1, green: 0.82, blue: 0.44)
}

struct RootView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var tab = 0

    var body: some View {
        ZStack {
            IsleBackground()
            VStack(spacing: 0) {
                content
                if tab != 2 {
                    TabBarView(tab: $tab)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        if tab == 0 {
            HomeView()
        } else if tab == 1 {
            NavigationView { SearchView() }
                .navigationViewStyle(StackNavigationViewStyle())
        } else if tab == 2 {
            if auth.ent.canPlayMusic {
                PlayerView(onClose: { tab = 0 })
            } else {
                PaywallView(need: "VIP", feature: "在线听歌")
            }
        } else if tab == 3 {
            if auth.ent.canUseVideo { EyesView() } else { PaywallView(need: "SVIP", feature: "养眼视频") }
        } else {
            MineView()
        }
    }
}

struct TabBarView: View {
    @Binding var tab: Int

    var body: some View {
        HStack(spacing: 0) {
            cell(IsleSymbol.home, "首页", 0)
            cell(IsleSymbol.search, "搜索", 1)
            playButton
            cell(IsleSymbol.video, "养眼", 3)
            cell(IsleSymbol.me, "我的", 4)
        }
        .padding(.horizontal, 4)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.07, green: 0.03, blue: 0.06).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func cell(_ symbol: String, _ title: String, _ index: Int) -> some View {
        Button { tab = index } label: {
            VStack(spacing: 4) {
                IsleIcon(symbol, scale: .lg,
                         tint: tab == index ? IsleColor.pinkLight : Color.white.opacity(0.38))
                Text(title)
                    .font(.system(size: 9.5))
                    .foregroundStyle(tab == index ? IsleColor.pinkLight : Color.white.opacity(0.38))
            }
            .padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var playButton: some View {
        Button { tab = 2 } label: {
            ZStack {
                Circle()
                    .fill(IsleColor.accent)
                    .frame(width: 46, height: 46)
                    .shadow(color: IsleColor.pinkDeep.opacity(0.48), radius: 11, y: 8)
                IsleIcon(tab == 2 ? IsleSymbol.pause : IsleSymbol.play,
                         scale: .md, weight: .bold, tint: Color.white)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
                IsleIcon(icon, scale: .lg, tint: on ? IsleColor.pink : Color(white: 0.38))
                Text(title).font(.system(size: 9.5))
                    .foregroundStyle(on ? IsleColor.pink : Color(white: 0.38))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MineView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var r = MineRouter()
    @State private var points = 0
    @State private var pointsLoaded = false

    private var nickname: String { auth.user?.nickname ?? "未登录" }
    private var uid: String {
        let base = abs(nickname.hashValue) % 900000
        return String(base + 100000)
    }

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        MineHeader(nickname: nickname, uid: uid, points: points, loaded: pointsLoaded)
                        MineMemberCard(nickname: nickname) { r.redeem = true }
                        MineGrid(fav: $r.fav, cloud: $r.cloud, device: $r.device, settings: $r.settings)
                        MineSectionList(router: r)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
            }
            .navigationBarHidden(true)
            .background(links)
            .task { await loadPoints() }
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
            NavigationLink(destination: MusicSourceSettingsView(), isActive: $r.musicSource) { EmptyView() }
            NavigationLink(destination: VideoSourceSettingsView(), isActive: $r.videoSource) { EmptyView() }
            NavigationLink(destination: PaywallView(need: "会员", feature: "卡密兑换"), isActive: $r.redeem) { EmptyView() }
        }
        .hidden()
    }

    private func loadPoints() async {
        let s = try? await APIClient.shared.checkinStatus()
        points = s?.balance ?? 0
        pointsLoaded = true
    }
}

struct MineHeader: View {
    let nickname: String
    let uid: String
    let points: Int
    let loaded: Bool

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [IsleColor.pink, IsleColor.pinkDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                Circle()
                    .strokeBorder(IsleColor.pink.opacity(0.6), lineWidth: 2)
                    .frame(width: 58, height: 58)
                Text(String(nickname.prefix(1)))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(nickname)
                    .font(.system(size: 17, weight: .heavy))
                    .lineLimit(1)
                Text("ID \(uid)")
                    .font(.system(size: 11))
                    .foregroundStyle(IsleColor.textSub)
            }

            Spacer(minLength: 6)

            VStack(spacing: 2) {
                Text(loaded ? "\(points)" : "--")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(IsleColor.pinkLight)
                Text("积分")
                    .font(.system(size: 9.5))
                    .foregroundStyle(IsleColor.textFaint)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct MineMemberCard: View {
    let nickname: String
    let onRedeem: () -> Void

    private let gold = Color(red: 0.94, green: 0.80, blue: 0.55)
    private let goldDeep = Color(red: 0.84, green: 0.62, blue: 0.32)

    private var goldText: LinearGradient {
        LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.82),
                                gold,
                                Color(red: 0.96, green: 0.86, blue: 0.64)],
                       startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ISLE 会员")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(goldText)

                    Text("尊享无损 · 无限下载")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(goldText)

                    Text("未开通 · 兑换卡密即可开通")
                        .font(.system(size: 10))
                        .foregroundStyle(gold.opacity(0.68))
                        .padding(.top, 2)
                }

                Spacer(minLength: 6)

                Button(action: onRedeem) {
                    Text("卡密兑换")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Color(red: 0.23, green: 0.15, blue: 0.07))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(colors: [Color(red: 0.97, green: 0.89, blue: 0.71), goldDeep],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                benefit("无损 FLAC")
                benefit("无限下载")
                benefit("5 台设备")
                Spacer(minLength: 0)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(colors: [Color(red: 0.165, green: 0.110, blue: 0.063),
                                        Color(red: 0.086, green: 0.039, blue: 0.055),
                                        Color(red: 0.145, green: 0.086, blue: 0.047)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [gold.opacity(0.18), .clear],
                               center: UnitPoint(x: 0.9, y: 0.05),
                               startRadius: 4, endRadius: 150)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [gold.opacity(0.95),
                                            gold.opacity(0.28),
                                            goldDeep.opacity(0.85)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(gold.opacity(0.45), lineWidth: 7)
                .blur(radius: 9)
                .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 5) {
            IsleIcon(IsleSymbol.check, scale: .xs, tint: gold)
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(gold.opacity(0.9))
        }
    }
}

struct MineGrid: View {
    @Binding var fav: Bool
    @Binding var cloud: Bool
    @Binding var device: Bool
    @Binding var settings: Bool

    var body: some View {
        HStack(spacing: 8) {
            MineTile(icon: IsleSymbol.heartFill, title: "收藏\n与歌单", color: IsleColor.pink) { fav = true }
            MineTile(icon: IsleSymbol.cloud, title: "云\n同步", color: Color(red: 0.49, green: 0.65, blue: 1)) { cloud = true }
            MineTile(icon: IsleSymbol.device, title: "设备\n管理", color: IsleColor.lilac) { device = true }
            MineTile(icon: IsleSymbol.settings, title: "设置\n中心", color: Color(red: 0.79, green: 0.65, blue: 1)) { settings = true }
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
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(width: 32, height: 32)
                    IsleIcon(icon, scale: .sm, tint: color)
                }
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(IsleColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(IsleColor.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MineSectionList: View {
    @ObservedObject var router: MineRouter

    var body: some View {
        VStack(spacing: 0) {
            MineSectionRow(icon: IsleSymbol.check, title: "签到积分",
                           detail: "每日签到 · 兑换会员", tint: IsleColor.gold) { router.checkin = true }
            divider
            MineSectionRow(icon: IsleSymbol.gift, title: "邀请好友",
                           detail: "每人 +200 积分", tint: IsleColor.mint) { router.invite = true }
            divider
            MineSectionRow(icon: IsleSymbol.cloud, title: "云同步",
                           detail: "歌单与进度", tint: Color(red: 0.49, green: 0.65, blue: 1)) { router.cloud = true }
            divider
            MineSectionRow(icon: IsleSymbol.device, title: "设备管理",
                           detail: "已绑定设备 · 解绑", tint: IsleColor.lilac) { router.device = true }
            divider
            MineSectionRow(icon: IsleSymbol.music, title: "音乐音源",
                           detail: "优先级与延迟测试", tint: IsleColor.pink) { router.musicSource = true }
            divider
            MineSectionRow(icon: IsleSymbol.video, title: "视频源",
                           detail: "养眼页播放源", tint: Color(red: 0.95, green: 0.55, blue: 0.38)) { router.videoSource = true }
        }
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 56)
    }
}

struct MineSectionRow: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 32, height: 32)
                    IsleIcon(icon, scale: .sm, tint: tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(IsleColor.textSub)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)
                IsleIcon(IsleSymbol.arrowRight, scale: .sm, tint: Color.white.opacity(0.28))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
