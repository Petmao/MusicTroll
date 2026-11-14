#!/usr/bin/env python3
import io
import sys


def load(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()


def save(p, s):
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def sub(s, old, new, label):
    if old not in s:
        if new and new in s:
            print('SKIP ' + label)
            return s
        print('MISS ' + label)
        sys.exit(1)
    print('OK   ' + label)
    return s.replace(old, new, 1)


# ============ 1) 播放器传输键：按压态 + 触感 ============
p = 'Isle/Player/CymusicPlayerView.swift'
s = load(p)

s = sub(s, '''    private var transportBlock: some View {
        HStack(spacing: 0) {
            Button(action: skipPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity)

            Button { engine.toggle() } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
            }
            .frame(maxWidth: .infinity)

            Button(action: skipNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }''',
    '''    private var transportBlock: some View {
        HStack(spacing: 0) {
            Button {
                tapLight()
                skipPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white)
                    .frame(width: 46, height: 46)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)

            Button {
                tapLight()
                engine.toggle()
            } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white)
                    .frame(width: 58, height: 58)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)

            Button {
                tapLight()
                skipNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white)
                    .frame(width: 46, height: 46)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TransportButtonStyle())
    }

    private func tapLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }''', '播放器触感与按压域')

if 'struct TransportButtonStyle' not in s:
    s += '''

/// 按下时缩小 + 变淡，给「按到了」的即时反馈
struct TransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.84 : 1)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
'''
    print('OK   播放器 TransportButtonStyle')
else:
    print('SKIP 播放器 TransportButtonStyle')

save(p, s)
print('CymusicPlayerView done')

# ============ 2) 搜索结果点击弹选择 ============
p = 'Isle/Features/SearchView.swift'
s = load(p)

s = sub(s, '''    @State private var addTarget = ""
    @State private var showAdd = false''',
    '''    @State private var addTarget = ""
    @State private var showAdd = false
    @State private var actionIdx = 0
    @State private var actionTitle = ""
    @State private var showActions = false''', 'Search 动作状态')

s = sub(s, '''        .sheet(isPresented: $showAdd) {
            AddToPlaylistSheet(title: addTarget)
        }
    }''',
    '''        .sheet(isPresented: $showAdd) {
            AddToPlaylistSheet(title: addTarget)
        }
        .confirmationDialog(actionTitle, isPresented: $showActions, titleVisibility: .visible) {
            Button("立即播放") {
                Task { await playAt(actionIdx) }
            }
            Button("加入歌单") {
                addTarget = actionTitle
                showAdd = true
            }
            Button("加入我喜欢的音乐") {
                let id = PlaylistStore.shared.favoritePlaylistID()
                PlaylistStore.shared.addSong(actionTitle, to: id)
            }
            Button("取消", role: .cancel) {}
        }
    }''', 'Search 动作弹窗')

s = sub(s, '        return Button { Task { await playAt(idx) } } label: {',
    '''        return Button {
            actionIdx = idx
            actionTitle = title
            showActions = true
        } label: {''', 'Search 结果行改为弹选择')

save(p, s)
print('SearchView done')

# ============ 3) 养眼 tab 隐藏迷你播放条 ============
p = 'Isle/App/RootView.swift'
s = load(p)

s = sub(s, '''                content
                MiniPlayerBar()
                TabBarView(tab: $tab)''',
    '''                content
                if tab != 2 {
                    MiniPlayerBar()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                TabBarView(tab: $tab)''', 'Root 养眼页隐藏迷你条')

s = sub(s, '''            VStack(spacing: 0) {
                content''',
    '''            VStack(spacing: 0) {
                content''', 'Root 定位')

save(p, s)
print('RootView done')

# ============ 4) 设置里去掉音源/视频源入口 ============
p = 'Isle/Features/SettingsView.swift'
s = load(p)

s = sub(s, '''            NavigationLink(destination: MusicSourceSettingsView()) {
                navRow("音乐音源", musicURL.isEmpty ? (loadingSources ? "读取中…" : "未配置，点此添加") : musicURL)
            }
            Divider().background(Color.white.opacity(0.06))
            NavigationLink(destination: VideoSourceSettingsView()) {
                navRow("视频源", videoURL.isEmpty ? (loadingSources ? "读取中…" : "未配置，点此添加") : videoURL)
            }
            Divider().background(Color.white.opacity(0.06))
            NavigationLink(destination: DeviceView()) {
                navRow("设备管理", "查看已绑定设备 / 解绑")
            }''',
    '''            NavigationLink(destination: DeviceView()) {
                navRow("设备管理", "查看已绑定设备 / 解绑")
            }
            Divider().background(Color.white.opacity(0.06))
            navRow("音乐与视频源", "由后台 admin.html 统一配置")''', 'Settings 删源入口')

s = sub(s, '''            HStack(spacing: 6) {
                sectionLabel("源地址")
                Text("仅管理员可见")
                    .font(.system(size: 9))
                    .foregroundStyle(IsleColor.gold.opacity(0.8))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(IsleColor.gold.opacity(0.15)))
            }
            .padding(.bottom, 6)
''',
    '''            sectionLabel("账号与设备")
                .padding(.bottom, 6)
''', 'Settings 标题改设备')

save(p, s)
print('SettingsView done')

print('PATCH19 DONE')
