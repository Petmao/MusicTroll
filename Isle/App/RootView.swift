import SwiftUI

final class MineRouter: ObservableObject {
    @Published var settings = false
    @Published var checkin = false
    @Published var invite = false
    @Published var fav = false
    @Published var cloud = false
    @Published var device = false
    @Published var importing = false
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
                TabBarView(tab: $tab)
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
            if auth.ent.canPlayMusic { PlayerView() } else { PaywallView(need: "VIP", feature: "在线听歌") }
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
    @State private var recent: [String] = ["夜航星", "坠落星空（女版）", "慢冷", "晚风"]
    @State private var importSource: MusicPlatform?

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            MineMemberCard(nickname: auth.user?.nickname ?? "未登录") { r.settings = true }
                            MineQuickRow(checkin: $r.checkin, invite: $r.invite, fav: $r.fav)
                                .padding(.top, 10)
                            MineImportRow { platform in importSource = platform }
                                .padding(.top, 12)
                            MineRecentRow(names: recent) { recent = [] }
                                .padding(.top, 12)
                            MineGrid(fav: $r.fav, cloud: $r.cloud, device: $r.device, settings: $r.settings)
                                .padding(.top, 12)
                            MinePlaylists { r.fav = true }
                                .padding(.top, 12)
                        }
                        .padding(.horizontal, 12)
                    }
                    MineSettingsRow { r.settings = true }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                }
            }
            .navigationBarHidden(true)
            .background(links)
            .sheet(item: $importSource) { p in
                PlaylistImportView(platform: p)
            }
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

enum MusicPlatform: String, Identifiable, CaseIterable {
    case netease, qq, kugou, kuwo
    var id: String { rawValue }

    var title: String {
        switch self {
        case .netease: return "网易云"
        case .qq: return "QQ 音乐"
        case .kugou: return "酷狗"
        case .kuwo: return "酷我"
        }
    }

    var icon: String {
        switch self {
        case .netease: return "cloud.fill"
        case .qq: return "music.note.list"
        case .kugou: return "waveform.circle.fill"
        case .kuwo: return "dot.radiowaves.left.and.right"
        }
    }

    var c1: Color {
        switch self {
        case .netease: return Color(red: 0.90, green: 0.16, blue: 0.20)
        case .qq: return Color(red: 0.19, green: 0.72, blue: 0.35)
        case .kugou: return Color(red: 0.13, green: 0.55, blue: 1.00)
        case .kuwo: return Color(red: 1.00, green: 0.62, blue: 0.10)
        }
    }

    var c2: Color {
        switch self {
        case .netease: return Color(red: 1.00, green: 0.45, blue: 0.30)
        case .qq: return Color(red: 0.12, green: 0.52, blue: 0.95)
        case .kugou: return Color(red: 0.36, green: 0.85, blue: 1.00)
        case .kuwo: return Color(red: 1.00, green: 0.35, blue: 0.35)
        }
    }
}

struct MineImportRow: View {
    let onPick: (MusicPlatform) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("导入歌单").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.62))
                Spacer()
                Text("粘贴链接即可").font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            HStack(spacing: 8) {
                ForEach(MusicPlatform.allCases) { p in
                    Button { onPick(p) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: p.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.white)
                            Text(p.title)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.92))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [p.c1, p.c2],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct PlaylistImportView: View {
    let platform: MusicPlatform
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PlaylistStore.shared
    @State private var link = ""
    @State private var loading = false
    @State private var message: String?
    @State private var ok = false

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: platform.icon).font(.system(size: 15))
                            .foregroundStyle(Color.white)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: [platform.c1, platform.c2],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("导入 \(platform.title) 歌单").font(.system(size: 14, weight: .bold))
                            Text("粘贴歌单分享链接或 ID").font(.system(size: 10.5))
                                .foregroundStyle(IsleColor.textSub)
                        }
                        Spacer()
                    }

                    TextField("https://… 或歌单 ID", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(IsleColor.surfaceHi)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.system(size: 12))

                    Button {
                        Task { await runImport() }
                    } label: {
                        HStack(spacing: 6) {
                            if loading { ProgressView().scaleEffect(0.7) }
                            Text(loading ? "解析中…" : "开始导入")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(IsleColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .disabled(loading)

                    if let message {
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(message).font(.system(size: 11))
                            Spacer()
                        }
                        .foregroundStyle(ok ? IsleColor.mint : IsleColor.gold)
                        .padding(11)
                        .background(IsleColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Text("导入后歌单会出现在「我的 → 收藏与歌单 → 歌单」，可继续用本 App 播放。")
                        .font(.system(size: 9.5)).foregroundStyle(Color.white.opacity(0.3))
                    Text("说明：跨平台歌单解析需要服务端 /api/import/playlist 接口；未开通时只会建一个占位歌单。")
                        .font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.22))
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("导入歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }

    private func runImport() async {
        let id = Self.extractID(link)
        guard !id.isEmpty else { message = "链接里没找到歌单 ID"; ok = false; return }
        loading = true
        defer { loading = false }

        if let rows = try? await APIClient.shared.importPlaylist(source: platform.rawValue, id: id),
           !rows.isEmpty {
            store.lists.append(IslePlaylist(name: "\(platform.title)导入 \(rows.count) 首", songs: rows))
            ok = true
            message = "成功导入 \(rows.count) 首"
            return
        }

        store.add("\(platform.title)歌单 \(id.suffix(6))")
        ok = false
        message = "已创建歌单（\(id)），但服务端未开通解析接口，曲目为空"
    }

    static func extractID(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("id=") {
            return t.components(separatedBy: "id=").last?
                .components(separatedBy: "&").first ?? ""
        }
        if t.contains("playlist/") {
            return t.components(separatedBy: "playlist/").last?
                .components(separatedBy: "?").first ?? ""
        }
        return t.allSatisfy { $0.isLetter || $0.isNumber } ? t : ""
    }
}

struct MineMemberCard: View {
    let nickname: String
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Text(String(nickname.prefix(1)))
                    .font(.system(size: 18, weight: .heavy)).foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(LinearGradient(colors: [IsleColor.gold, IsleColor.pink],
                                                            startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Circle().stroke(IsleColor.gold.opacity(0.6), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(nickname).font(.system(size: 16, weight: .heavy))
                        Text("SVIP")
                            .font(.system(size: 8.5, weight: .black))
                            .foregroundStyle(IsleColor.gold)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4)
                                .fill(IsleColor.gold.opacity(0.18)))
                    }
                    Text("屿声音乐会员").font(.system(size: 11))
                        .foregroundStyle(IsleColor.textSub)
                }
                Spacer(minLength: 8)
                Button(action: onSettings) {
                    IsleIcon(IsleSymbol.settings, scale: .sm, tint: Color.white.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("本月会员进度").font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer()
                Text("还剩 27 天").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(IsleColor.gold)
            }
            .padding(.top, 10)

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [IsleColor.gold, Color(red: 1, green: 0.69, blue: 0.12)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * 0.62)
                }
            }
            .frame(height: 4)
            .padding(.top, 5)

            HStack(spacing: 7) {
                MineStatCell(title: "收藏", value: "12")
                MineStatCell(title: "歌单", value: "2")
                MineStatCell(title: "积分", value: "1280")
                MineStatCell(title: "缓存", value: "0M")
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(red: 0.165, green: 0.110, blue: 0.063),
                                    Color(red: 0.070, green: 0.031, blue: 0.050)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(IsleColor.gold.opacity(0.34), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, 8)
    }
}

struct MineStatCell: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.45))
            Text(value).font(.system(size: 14, weight: .heavy))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.05)))
    }
}

struct MineQuickRow: View {
    @Binding var checkin: Bool
    @Binding var invite: Bool
    @Binding var fav: Bool
    var body: some View {
        HStack(spacing: 8) {
            MinePill(icon: IsleSymbol.heartFill, title: "收藏", color: IsleColor.pink) { fav = true }
            MinePill(icon: IsleSymbol.check, title: "签到", color: IsleColor.lilac) { checkin = true }
            MinePill(icon: IsleSymbol.gift, title: "邀请", color: IsleColor.mint) { invite = true }
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
                IsleIcon(icon, scale: .sm, tint: color)
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(color)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MineRecentRow: View {
    let names: [String]
    let onClear: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("最近播放").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.62))
                Spacer()
                Button(action: onClear) {
                    Text("清空").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(IsleColor.pink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
            }
            if names.isEmpty {
                Text("还没有播放记录").font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                            VStack(alignment: .leading, spacing: 5) {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(LinearGradient(colors: [IsleColor.pinkDeep, IsleColor.pink],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 70, height: 70)
                                Text(name).font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1).frame(width: 70, alignment: .leading)
                            }
                        }
                    }
                }
            }
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
            VStack(spacing: 5) {
                IsleIcon(icon, scale: .md, tint: color)
                Text(title).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
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
                Text("我的歌单").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.62))
                Spacer()
                Button(action: onTap) {
                    Text("＋ 新建").font(.system(size: 11)).foregroundStyle(IsleColor.pinkLight)
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
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [IsleColor.lilac, IsleColor.mint],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 86)
                Text(name).font(.system(size: 11.5, weight: .bold)).lineLimit(1)
                Text(subtitle).font(.system(size: 9)).foregroundStyle(IsleColor.textSub).lineLimit(1)
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
                IsleIcon(IsleSymbol.settings, scale: .sm, tint: Color.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.10)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("设置").font(.system(size: 13, weight: .semibold))
                    Text("音源 · 视频源 · 精确跳转 · 退出登录")
                        .font(.system(size: 11)).foregroundStyle(IsleColor.textSub)
                }
                Spacer()
                IsleIcon(IsleSymbol.arrowRight, scale: .sm, tint: Color.white.opacity(0.3))
            }
            .padding(.vertical, 9).padding(.horizontal, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
