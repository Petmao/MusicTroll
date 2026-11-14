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


# ============ 1) 搜索带 “ - 歌手” 搜不到时退化成只搜歌名 ============
p = 'Isle/Sources/MusicEngine.swift'
s = load(p)

s = sub(s, '''    func search(_ keyword: String) async throws -> [[String: Any]] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { throw EngineError.noResult }
        var last: Error = EngineError.timeout
        for i in 0..<2 {
            do { return try await requestOnce(kw) }
            catch {
                last = error
                if i == 0 { try? await Task.sleep(nanoseconds: 700_000_000) }
            }
        }
        throw last
    }''',
    '''    func search(_ keyword: String) async throws -> [[String: Any]] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { throw EngineError.noResult }

        var last: Error = EngineError.timeout
        for i in 0..<2 {
            do { return try await requestOnce(kw) }
            catch {
                last = error
                if i == 0 { try? await Task.sleep(nanoseconds: 700_000_000) }
            }
        }

        // 歌单里存的是 “歌名 - 歌手”，整串搜不到时退化成只搜歌名
        let short = kw.components(separatedBy: " - ").first ?? kw
        if short != kw, !short.isEmpty {
            for i in 0..<2 {
                do { return try await requestOnce(short) }
                catch {
                    last = error
                    if i == 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
                }
            }
        }

        throw last
    }''', '搜索降级歌名')

save(p, s)
print('MusicEngine done')

# ============ 2) 歌单详情行加触感与播放图标 ============
p = 'Isle/Features/LibraryView.swift'
s = load(p)

s = sub(s, '''                                Button {
                                    Task { await engine.playQueue(playlist.songs, startAt: i) }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(String(format: "%02d", i + 1))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.3))
                                            .frame(width: 22)
                                        Text(s)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.white)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                        if engine.current?.title == s {
                                            IsleIcon("waveform", scale: .sm, tint: IsleColor.pinkLight)
                                        }
                                    }
                                    .padding(12)
                                    .background(IsleColor.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)''',
    '''                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    Task { await engine.playQueue(playlist.songs, startAt: i) }
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(String(format: "%02d", i + 1))
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.3))
                                            .frame(width: 22)

                                        IsleIcon(IsleSymbol.play, scale: .xs,
                                                 tint: Color.white.opacity(0.55))
                                            .frame(width: 16)

                                        Text(s)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.white)
                                            .lineLimit(1)

                                        Spacer(minLength: 0)

                                        if engine.current?.title == s {
                                            IsleIcon("waveform", scale: .sm, tint: IsleColor.pinkLight)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(12)
                                    .background(IsleColor.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)''', '歌单详情行反馈')

save(p, s)
print('LibraryView done')
print('PATCH31 DONE')
