#!/usr/bin/env python3
import io
import re
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

s = sub(s, "    @ObservedObject private var volume = SystemVolume.shared\n",
    "    @ObservedObject private var fav = FavoritesStore.shared\n", 'player 收藏状态')

s = sub(s, "                dismissHandle(top: top)\n                VolumeBridge().frame(width: 1, height: 1).opacity(0.01)\n",
    "                dismissHandle(top: top)\n", 'player 移除系统音量桥')

s = sub(s, """                    songMenu
                }""",
    """                    HStack(spacing: 8) {
                        likeButton
                        songMenu
                    }
                }""", 'player 标题行加喜欢')

s = sub(s, """    private var songMenu: some View {""",
    """    private var likeButton: some View {
        let t = engine.current?.title ?? ""
        let a = engine.current?.artist ?? ""
        let liked = fav.contains(t, a)
        return Button {
            guard !t.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                _ = fav.toggle(title: t, artist: a)
            }
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(liked ? Color(red: 1, green: 0.373, blue: 0.620)
                                       : Color.white.opacity(0.72))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(liked ? 0.15 : 0.10))
                .clipShape(Circle())
                .scaleEffect(liked ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var songMenu: some View {""", 'player 喜欢按钮')

s = sub(s, """            CymusicSlider(value: Double(volume.value),
                          onScrub: { volume.set(Float($0)) },
                          onCommit: { volume.set(Float($0)) })
                .padding(.horizontal, 10)""",
    """            CymusicSlider(value: Double(engine.volume),
                          onScrub: { engine.setVolume(Float($0)) },
                          onCommit: { engine.setVolume(Float($0)) })
                .padding(.horizontal, 10)""", 'player 音量条接引擎')

NEW_SHEET = '''struct PlaylistSheet: View {
    @Environment(\\.dismiss) private var dismiss
    @ObservedObject private var engine = MusicEngine.shared
    @ObservedObject private var fav = FavoritesStore.shared

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button {
                            engine.addToQueue(fav.items.map { $0.title })
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text("添加收藏").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(IsleColor.pink.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            engine.queue = []
                            engine.queueIndex = -1
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trash").font(.system(size: 11))
                                Text("清空").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.white.opacity(0.72))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(IsleColor.surface)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("\\(engine.queue.count) 首")
                            .font(.system(size: 11))
                            .foregroundStyle(IsleColor.textSub)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            if engine.queue.isEmpty {
                                Text("队列是空的，从首页或搜索结果点一首开始")
                                    .font(.system(size: 12))
                                    .foregroundStyle(IsleColor.textSub)
                                    .padding(.top, 44)
                            } else {
                                ForEach(Array(engine.queue.enumerated()), id: \\.offset) { i, t in
                                    row(i, t)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ i: Int, _ t: String) -> some View {
        let on = i == engine.queueIndex
        return Button {
            engine.jumpTo(i)
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", i + 1))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(on ? Color(red: 1, green: 0.561, blue: 0.749)
                                        : Color.white.opacity(0.3))
                    .frame(width: 22)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(on ? IsleColor.pink.opacity(0.85) : Color.white.opacity(0.08))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: on ? "waveform" : "music.note")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.85))
                    )

                Text(t)
                    .font(.system(size: 13.5, weight: on ? .semibold : .regular))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(IsleColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(on ? IsleColor.pink.opacity(0.35) : Color.clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
'''

rx = re.compile(r'struct PlaylistSheet: View \{.*\Z', re.S)
if not rx.search(s):
    print('MISS player PlaylistSheet')
    sys.exit(1)
s = rx.sub(lambda m: NEW_SHEET, s)
print('OK   player PlaylistSheet')

save(p, s)
print('CymusicPlayerView done')
