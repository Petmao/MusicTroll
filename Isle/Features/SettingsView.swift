import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthStore
    @AppStorage("theme") private var theme = "dark"
    @AppStorage("lang") private var lang = "zh"
    @AppStorage("preciseSeek") private var preciseSeek = false
    @AppStorage("autoCache") private var autoCache = true

    var body: some View {
        List {
            Section(header: Text("外观与语言")) {
                Picker("主题", selection: $theme) {
                    Text("深色").tag("dark")
                    Text("浅色").tag("light")
                    Text("跟随系统").tag("auto")
                }
                .pickerStyle(SegmentedPickerStyle())
                Picker("语言", selection: $lang) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section(header: Text("音频设置"),
                    footer: Text("部分 FLAC 在快进后可能出现音频与歌词不同步，开启本项可改善。默认关闭，记住选择并在切换歌曲后生效；开启后部分音频可能需要完整加载，播放前等待更久。")) {
                Toggle("精确跳转", isOn: $preciseSeek)
            }

            Section(header: Text("本地与缓存")) {
                Toggle("自动缓存歌曲", isOn: $autoCache)
                HStack {
                    Text("缓存占用")
                    Spacer()
                    Text("0 MB").foregroundColor(.secondary)
                }
            }

            Section(header: Text("源")) {
                NavigationLink("音乐音源") { SourcesView(kind: "music") }
                NavigationLink("视频源") { SourcesView(kind: "video") }
                NavigationLink("云同步") { CloudSyncView() }
            }

            Section(header: Text("账号")) {
                HStack { Text("账号"); Spacer(); Text(auth.user?.account ?? "-").foregroundColor(.secondary) }
                NavigationLink("设备管理") { DeviceManageView() }
                Button("退出登录") { auth.logout() }
                    .foregroundColor(Color(red: 1, green: 0.35, blue: 0.55))
            }

            Section(header: Text("关于"), footer: Text(Config.disclaimer)) {
                HStack { Text("版本"); Spacer(); Text(Config.version).foregroundColor(.secondary) }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("设置")
    }
}
