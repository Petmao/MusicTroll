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


# ---------- MusicEngine：先弹播放器再加载 ----------
p = 'Isle/Sources/MusicEngine.swift'
s = load(p)

s = sub(s, '''    func playQueue(_ titles: [String], startAt index: Int, present: Bool = true) async {
        guard !titles.isEmpty else { return }
        queue = titles
        queueIndex = max(0, min(index, titles.count - 1))
        await loadQueueItem(present: present)
    }''',
    '''    func playQueue(_ titles: [String], startAt index: Int, present: Bool = true) async {
        guard !titles.isEmpty else { return }
        queue = titles
        queueIndex = max(0, min(index, titles.count - 1))

        // 先把播放器弹出来，UI 立刻有反应，URL 在后台慢慢取
        if present {
            status = "加载中…"
            PlayerPresenter.shared.present()
        }

        await loadQueueItem(present: false)
    }''', 'engine 先弹播放器')

save(p, s)
print('MusicEngine done')

# ---------- CymusicPlayerView：无 current 时用队列标题 + 加载指示 ----------
p = 'Isle/Player/CymusicPlayerView.swift'
s = load(p)

s = sub(s, '    private var title: String { engine.current?.title ?? "未选择歌曲" }',
    '''    private var title: String {
        if let t = engine.current?.title, !t.isEmpty { return t }
        if engine.queueIndex >= 0, engine.queueIndex < engine.queue.count {
            return engine.queue[engine.queueIndex]
        }
        return "未选择歌曲"
    }''', 'player 标题兜底')

s = sub(s, '''    private var coverPlaceholder: some View {
        ZStack {
            base.color
            Image(systemName: "music.note")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(Color.white.opacity(0.16))
        }
    }''',
    '''    private var coverPlaceholder: some View {
        ZStack {
            base.color
            if engine.current == nil {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(Color.white.opacity(0.85))
                        .scaleEffect(1.3)
                    Text(engine.status.isEmpty ? "加载中…" : engine.status)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 46, weight: .thin))
                    .foregroundStyle(Color.white.opacity(0.16))
            }
        }
    }''', 'player 加载指示')

save(p, s)
print('CymusicPlayerView done')
print('PATCH29 DONE')
