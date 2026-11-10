import SwiftUI

/// 设置页（按设计稿：深色卡片、琥珀色提示、分段控件）
struct SettingsView: View {
    @EnvironmentObject var auth: AuthStore
    @AppStorage("theme") private var theme = "dark"
    @AppStorage("lang") private var lang = "zh"
    @AppStorage("preciseSeek") private var preciseSeek = false
    @AppStorage("autoCache") private var autoCache = true

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.04, blue: 0.19),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            label("外观与语言")
                            Text("主题").font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                            segRow([("深色", "dark"), ("浅色", "light"), ("跟随系统", "auto")],
                                   selection: $theme)
                            Text("语言 / Language").font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                                .padding(.top, 4)
                            segRow([("中文", "zh"), ("English", "en")], selection: $lang)
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            label("音频设置")
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("精确跳转").font(.system(size: 13.5, weight: .semibold))
                                    Text("改善 FLAC 快进后音画不同步")
                                        .font(.system(size: 10.5)).foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                Toggle("", isOn: $preciseSeek).labelsHidden()
                            }
                            Text("部分 FLAC 在快进后可能出现音频与歌词不同步，可在 设置 → 音频设置 → 精确跳转 中开启改善。该开关默认关闭，记住选择并在切换歌曲后生效；开启后部分音频可能需要完整加载，播放前等待更久。")
                                .font(.system(size: 10))
                                .lineSpacing(3)
                                .foregroundColor(Color(red: 1, green: 0.75, blue: 0.45).opacity(0.85))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(red: 1, green: 0.72, blue: 0.28).opacity(0.09))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 1, green: 0.72, blue: 0.28).opacity(0.22), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            label("本地与缓存")
                            row("自动缓存歌曲", "播过的自动存一份") {
                                Toggle("", isOn: $autoCache).labelsHidden()
                            }
                            Divider().background(Color.white.opacity(0.06))
                            row("缓存占用", "0 MB") {
                                Text("清理").font(.system(size: 11))
                                    .padding(.horizontal, 11).padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08)).clipShape(Capsule())
                            }
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 0) {
                            label("源与同步").padding(.bottom, 6)
                            navRow("音乐音源", "后台配置的 JS 源") { SourcesView(kind: "music") }
                            navRow("视频源", "养眼使用") { SourcesView(kind: "video") }
                            navRow("云同步", "歌单与播放进度") { CloudSyncView() }
                            navRow("设备管理", "绑定 / 解绑") { DeviceManageView() }
                        }
                    }

                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            label("账号")
                            row("登录账号", auth.user?.account ?? "-") { EmptyView() }
                            Divider().background(Color.white.opacity(0.06))
                            Button { auth.logout() } label: {
                                Text("退出登录").font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 1, green: 0.35, blue: 0.55))
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                        }
                    }

                    Text("屿声音乐 \(Config.version)\n\(Config.disclaimer)")
                        .font(.system(size: 9.5))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.horizontal, 10).padding(.bottom, 24)
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(_ t: String) -> some View {
        Text(t).font(.system(size: 11.5, weight: .bold)).tracking(1)
            .foregroundColor(.white.opacity(0.5))
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func segRow(_ items: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.1) { item in
                Button { selection.wrappedValue = item.1 } label: {
                    Text(item.0).font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(selection.wrappedValue == item.1
                                    ? AnyView(LinearGradient(colors: [Color(red: 0.48, green: 0.36, blue: 1),
                                                                      Color(red: 0, green: 0.66, blue: 1)],
                                                             startPoint: .leading, endPoint: .trailing))
                                    : AnyView(Color.clear))
                        .foregroundColor(selection.wrappedValue == item.1 ? .white : .white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(4).background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func row<T: View>(_ title: String, _ sub: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(sub).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            trailing()
        }
    }

    private func navRow<D: View>(_ title: String, _ sub: String, @ViewBuilder dest: () -> D) -> some View {
        NavigationLink(destination: dest()) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundColor(.white)
                    Text(sub).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 9)
        }
    }
}
