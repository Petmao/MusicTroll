import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthStore
    @AppStorage("theme") private var theme = "dark"
    @AppStorage("lang") private var lang = "zh"
    @AppStorage("preciseSeek") private var preciseSeek = false
    @State private var showLogout = false
    @State private var musicURL = ""
    @State private var videoURL = ""
    @State private var loadingSources = true
    @State private var cacheText = "0 MB"

    private var isAdmin: Bool { auth.ent.canManageSources }

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    banner
                    if isAdmin { sourcesCard }
                    appearanceCard
                    audioCard
                    cacheCard
                    infoCard
                    logoutCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            refreshCache()
            if isAdmin { await loadSources() }
        }
        .alert("退出登录", isPresented: $showLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { auth.logout() }
        } message: {
            Text("退出后需重新登录，本地加密音乐保留。")
        }
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [IsleColor.pink,
                                              IsleColor.pinkDeep,
                                              IsleColor.lilac],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 92)

            LinearGradient(colors: [Color.white.opacity(0.26), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(height: 92)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("屿声音乐").font(.system(size: 17, weight: .heavy)).foregroundStyle(Color.white)
                    Text("设置 · 音源 · 播放").font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer()
                Text(Config.version)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.25)))
            }
            .padding(14)
        }
    }

    private func sectionLabel(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 11, weight: .bold))
            .tracking(1)
            .foregroundStyle(Color.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                sectionLabel("源地址")
                Text("仅管理员可见")
                    .font(.system(size: 9))
                    .foregroundStyle(IsleColor.gold.opacity(0.8))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(IsleColor.gold.opacity(0.15)))
            }
            .padding(.bottom, 6)

            NavigationLink(destination: MusicSourceSettingsView()) {
                navRow("音乐音源", musicURL.isEmpty ? (loadingSources ? "读取中…" : "未配置，点此添加") : musicURL)
            }
            Divider().background(Color.white.opacity(0.06))
            NavigationLink(destination: VideoSourceSettingsView()) {
                navRow("视频源", videoURL.isEmpty ? (loadingSources ? "读取中…" : "未配置，点此添加") : videoURL)
            }
            Divider().background(Color.white.opacity(0.06))
            NavigationLink(destination: DeviceView()) {
                navRow("设备管理", "查看已绑定设备 / 解绑")
            }
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.gold.opacity(0.18), lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func navRow(_ title: String, _ sub: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white)
                Text(sub)
                    .font(.system(size: 10.5))
                    .foregroundStyle(sub.hasPrefix("http") ? IsleColor.mint : IsleColor.textSub)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 6)
            IsleIcon(IsleSymbol.arrowRight, scale: .sm, tint: Color.white.opacity(0.3))
        }
        .padding(.vertical, 10)
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("外观与语言")
            seg(options: [("dark", "深色"), ("light", "浅色"), ("auto", "跟随系统")], sel: $theme)
            seg(options: [("zh", "中文"), ("en", "English")], sel: $lang)
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func seg(options: [(String, String)], sel: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { key, title in
                Button { sel.wrappedValue = key } label: {
                    Text(title)
                        .font(.system(size: 11.5, weight: sel.wrappedValue == key ? .semibold : .regular))
                        .foregroundStyle(sel.wrappedValue == key ? Color.white : Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(segBackground(active: sel.wrappedValue == key))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func segBackground(active: Bool) -> LinearGradient {
        active
            ? LinearGradient(colors: [IsleColor.lilac, IsleColor.mint],
                             startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color.clear, Color.clear],
                             startPoint: .leading, endPoint: .trailing)
    }

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("音频设置")
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("精确跳转").font(.system(size: 13, weight: .semibold))
                    Text("改善 FLAC 快进后音画不同步")
                        .font(.system(size: 11)).foregroundStyle(IsleColor.textSub)
                }
                Spacer()
                Toggle("", isOn: $preciseSeek)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: IsleColor.pink))
            }

            Text("部分 FLAC 在快进后可能出现音频与歌词不同步，可在这里开启改善。默认关闭，切换歌曲后生效；开启后部分音频需完整加载，播放前等待更久。")
                .font(.system(size: 9.5))
                .lineSpacing(3)
                .foregroundStyle(IsleColor.gold.opacity(0.85))
                .padding(9)
                .background(IsleColor.gold.opacity(0.09))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(IsleColor.gold.opacity(0.22), lineWidth: 0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cacheCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionLabel("播放缓存")
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(IsleColor.pink.opacity(0.16))
                        .frame(width: 40, height: 40)
                    IsleIcon(IsleSymbol.download, scale: .md, tint: IsleColor.pinkLight)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("已缓存 \(cacheText)")
                        .font(.system(size: 13, weight: .semibold))
                    Text("上限 512 MB · 超出后按最久未用清理")
                        .font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub)
                }

                Spacer(minLength: 6)

                Button {
                    PlaybackCache.shared.clear()
                    refreshCache()
                } label: {
                    Text("清理")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(IsleColor.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Text("听到的歌会自动存到本地，下次播放同一首直接读文件，不再走网络。")
                .font(.system(size: 9.5))
                .foregroundStyle(IsleColor.textFaint)
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("关于")
            infoRow("音乐与视频内容", "由管理员统一配置，App 仅做解析与播放")
            infoRow("本地缓存", "AES-256-GCM 设备密钥加密")
            infoRow("账号", auth.user?.nickname ?? "—")
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoRow(_ t: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(t)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.white.opacity(0.6))
                .frame(width: 92, alignment: .leading)
            Text(v)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.42))
            Spacer(minLength: 0)
        }
    }

    private var logoutCard: some View {
        Button { showLogout = true } label: {
            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    IsleIcon(IsleSymbol.power, scale: .sm, tint: IsleColor.pink)
                    Text("退出登录").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(IsleColor.pink)
                }
                Text("退出后需重新登录，本地加密音乐保留")
                    .font(.system(size: 9.5)).foregroundStyle(Color.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(IsleColor.pink.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(IsleColor.pink.opacity(0.28), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func refreshCache() {
        cacheText = PlaybackCache.shared.prettySize()
    }

    private func loadSources() async {
        loadingSources = true
        defer { loadingSources = false }
        if let m = try? await APIClient.shared.sources(kind: "music"), let f = m.first {
            musicURL = f.url
        }
        if let v = try? await APIClient.shared.sources(kind: "video"), let f = v.first {
            videoURL = f.url
        }
    }
}
