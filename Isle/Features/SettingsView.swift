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

    private var isAdmin: Bool { auth.ent.canManageSources }

    var body: some View {
        ZStack {
            MineTheme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    gradientBanner
                    if isAdmin { sources }
                    appearance
                    audio
                    infoCard
                    logoutCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { if isAdmin { await loadSources() } }
        .alert("退出登录", isPresented: $showLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { auth.logout() }
        } message: {
            Text("退出后需重新登录，本地加密音乐保留。")
        }
    }

    private var gradientBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                              Color(red: 1, green: 0.48, blue: 0.18),
                                              Color(red: 0.48, green: 0.36, blue: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 92)
            LinearGradient(colors: [.white.opacity(0.30), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .frame(height: 92)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("屿声音乐").font(.system(size: 17, weight: .heavy)).foregroundColor(.white)
                    Text("设置 · 音源 · 播放").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                Text(Config.version)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.25)))
            }
            .padding(14)
        }
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .bold)).tracking(1)
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                label("源地址")
                Text("仅管理员可见").font(.system(size: 9)).foregroundColor(MineTheme.gold.opacity(0.8))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(MineTheme.gold.opacity(0.15)))
            }
            .padding(.bottom, 6)
            NavigationLink(destination: MusicSourceSettingsView()) {
                row("音乐音源", musicURL.isEmpty ? (loadingSources ? "读取中…" : "未配置，点此添加") : musicURL)
            }
            Divider().background(Color.white.opacity(0.06))
            NavigationLink(destination: VideoSourceSettingsView()) {
                row("视频源", videoURL.isEmpty ? (loadingSources ? "读取中…" : "未配置，点此添加") : videoURL)
            }
            Divider().background(Color.white.opacity(0.06))
            NavigationLink(destination: DeviceView()) {
                row("设备管理", "查看已绑定设备 / 解绑")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MineTheme.gold.opacity(0.18), lineWidth: 0.8))
    }

    private func row(_ title: String, _ sub: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                Text(sub)
                    .font(.system(size: 10.5))
                    .foregroundColor(sub.hasPrefix("http") ? Color(red: 0.55, green: 0.85, blue: 1) : .gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 9)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 9) {
            label("外观与语言")
            seg(options: [("dark", "深色"), ("light", "浅色"), ("auto", "跟随系统")], sel: $theme)
            seg(options: [("zh", "中文"), ("en", "English")], sel: $lang)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
    }

    private func seg(options: [(String, String)], sel: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { key, title in
                Button { sel.wrappedValue = key } label: {
                    Text(title)
                        .font(.system(size: 11.5, weight: sel.wrappedValue == key ? .semibold : .regular))
                        .foregroundColor(sel.wrappedValue == key ? .white : Color(white: 0.6))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(sel.wrappedValue == key
                                  ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.48, green: 0.36, blue: 1),
                                                                          Color(red: 0, green: 0.83, blue: 1)],
                                                                 startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.clear)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.07)))
    }

    private var audio: some View {
        VStack(alignment: .leading, spacing: 9) {
            label("音频设置")
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("精确跳转").font(.system(size: 13, weight: .semibold))
                    Text("改善 FLAC 快进后音画不同步").font(.system(size: 11)).foregroundColor(.gray)
                }
                Spacer()
                Toggle("", isOn: $preciseSeek).labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: MineTheme.pink))
            }
            Text("部分 FLAC 在快进后可能出现音频与歌词不同步，可在 设置 → 音频设置 → 精确跳转 中开启改善。默认关闭，切换歌曲后生效；开启后部分音频需完整加载，播放前等待更久。")
                .font(.system(size: 9.5)).lineSpacing(3)
                .foregroundColor(Color(red: 1, green: 0.84, blue: 0.59).opacity(0.85))
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 1, green: 0.72, blue: 0.28).opacity(0.09)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 1, green: 0.72, blue: 0.28).opacity(0.22), lineWidth: 0.7))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("关于")
            infoRow("音乐与视频内容", "由管理员统一配置，App 仅做解析与播放")
            infoRow("本地缓存", "AES-256-GCM 设备密钥加密")
            infoRow("账号", auth.user?.nickname ?? "—")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
    }

    private func infoRow(_ t: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(t).font(.system(size: 11.5)).foregroundColor(.white.opacity(0.6)).frame(width: 92, alignment: .leading)
            Text(v).font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
            Spacer()
        }
    }

    private var logoutCard: some View {
        Button { showLogout = true } label: {
            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 13))
                    Text("退出登录").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(MineTheme.pink)
                Text("退出后需重新登录，本地加密音乐保留")
                    .font(.system(size: 9.5)).foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(red: 1, green: 0.18, blue: 0.47).opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(MineTheme.pink.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 4)
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
