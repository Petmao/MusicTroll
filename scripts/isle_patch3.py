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


p = 'Isle/Player/CymusicPlayerView.swift'
s = load(p)

s = sub(s, """    private func skipNext() { engine.seek(to: min(1, engine.progress + 0.05)) }
    private func skipPrevious() { engine.seek(to: max(0, engine.progress - 0.05)) }""",
    """    private func skipNext() { engine.nextTrack() }
    private func skipPrevious() { engine.previousTrack() }""", 'player 上下曲接队列')

s = sub(s, """            Button { showQueue = true } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)""",
    """            Button { engine.toggleRepeat() } label: {
                Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 26))
                    .foregroundStyle(engine.repeatMode == .off ? Color.white.opacity(0.45) : Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)""", 'player 循环按钮')

s = sub(s, """            Button { toggleLyrics() } label: { Label("歌词", systemImage: "text.quote") }
            Button { showQueue = true } label: { Label("播放列表", systemImage: "list.bullet") }""",
    """            Button { toggleLyrics() } label: { Label("歌词", systemImage: "text.quote") }
            Button { engine.toggleShuffle() } label: {
                Label(engine.shuffleOn ? "关闭随机播放" : "随机播放", systemImage: "shuffle")
            }
            Button { showQueue = true } label: { Label("播放列表", systemImage: "list.bullet") }""", 'player 随机播放菜单')

save(p, s)
print('CymusicPlayerView done')

p = 'Isle/App/RootView.swift'
s = load(p)

s = sub(s, """                content
                TabBarView(tab: $tab)""",
    """                content
                MiniPlayerBar()
                TabBarView(tab: $tab)""", 'root 迷你播放条')

save(p, s)
print('RootView done')

p = 'Isle/Features/HomeView.swift'
s = load(p)

s = sub(s, """    private func newSongRow(_ i: Int, _ s: Song) -> some View {
        Button { play(s.title) } label: {""",
    """    private func newSongRow(_ i: Int, _ s: Song) -> some View {
        Button { playFrom(i) } label: {""", 'home 列表点歌')

s = sub(s, """    private func play(_ kw: String) {""",
    """    private func playFrom(_ i: Int) {
        guard i >= 0, i < DemoData.newSongs.count else { return }
        busy = true
        toast = "正在搜索「\\(DemoData.newSongs[i].title)」…"
        Task {
            await engine.playQueue(DemoData.newSongs.map { $0.title }, startAt: i)
            await MainActor.run {
                busy = false
                toast = engine.isPlaying ? "正在播放：\\(engine.current?.title ?? "") " : engine.status
            }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run { withAnimation { toast = nil } }
        }
    }

    private func play(_ kw: String) {""", 'home playFrom')

save(p, s)
print('HomeView done')
