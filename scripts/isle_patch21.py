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


# ============ LibraryView：歌单封面 ============
p = 'Isle/Features/LibraryView.swift'
s = load(p)

s = sub(s, '''struct IslePlaylist: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var songs: [String] = []
}''',
    '''struct IslePlaylist: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var songs: [String] = []
    /// 本地封面文件名，存在 Documents/covers 下
    var cover: String? = nil
}''', 'Playlist 加 cover')

s = sub(s, '''    /// 「我喜欢的音乐」歌单 id，没有就建一个''',
    '''    func coverURL(_ p: IslePlaylist) -> URL? {
        guard let c = p.cover, !c.isEmpty else { return nil }
        let u = URL.documents.appendingPathComponent("covers", isDirectory: true)
            .appendingPathComponent(c)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func setCover(_ data: Data, for id: UUID) {
        let dir = URL.documents.appendingPathComponent("covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = id.uuidString + ".jpg"
        try? data.write(to: dir.appendingPathComponent(name))
        guard let i = lists.firstIndex(where: { $0.id == id }) else { return }
        lists[i].cover = name
        save()
    }

    /// 「我喜欢的音乐」歌单 id，没有就建一个''', 'Playlist 封面方法')

s = sub(s, '''    @State private var showNew = false
    @State private var openList: IslePlaylist?''',
    '''    @State private var showNew = false
    @State private var openList: IslePlaylist?
    @State private var coverTarget: UUID?
    @State private var showCoverPicker = false''', 'Library 封面状态')

s = sub(s, '''        .sheet(isPresented: $showNew) {
            NewPlaylistSheet { name in store.add(name) }
        }''',
    '''        .sheet(isPresented: $showNew) {
            NewPlaylistSheet { name in store.add(name) }
        }
        .sheet(isPresented: $showCoverPicker) {
            PhotoPicker { data in
                if let id = coverTarget { store.setCover(data, for: id) }
            }
        }''', 'Library 封面临片')

s = sub(s, '''                            VStack(alignment: .leading, spacing: 7) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(covers[i % covers.count])
                                    .frame(height: 100)
                                    .overlay(
                                        Text("\(p.songs.count) 首")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .padding(.horizontal, 7).padding(.vertical, 3)
                                            .background(Capsule().fill(Color.black.opacity(0.35))),
                                        alignment: .bottomTrailing
                                    )
                                Text(p.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)''',
    '''                            VStack(alignment: .leading, spacing: 7) {
                                ZStack {
                                    if let u = store.coverURL(p), let img = UIImage(contentsOfFile: u.path) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(covers[i % covers.count])
                                    }
                                }
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    Text("\(p.songs.count) 首")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Capsule().fill(Color.black.opacity(0.35)))
                                        .padding(6),
                                    alignment: .bottomTrailing
                                )

                                Text(p.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                coverTarget = p.id
                                showCoverPicker = true
                            } label: {
                                Label("更换封面", systemImage: "photo")
                            }
                            if p.cover != nil {
                                Button(role: .destructive) {
                                    coverTarget = p.id
                                    if let idx = store.lists.firstIndex(where: { $0.id == p.id }) {
                                        store.lists[idx].cover = nil
                                    }
                                } label: {
                                    Label("恢复默认封面", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }''', 'Library 歌单封面渲染')

save(p, s)
print('LibraryView done')

# ============ RootView：头像 ============
p = 'Isle/App/RootView.swift'
s = load(p)

s = sub(s, '''struct MineHeader: View {
    let nickname: String
    let uid: String
    let points: Int
    let loaded: Bool

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [IsleColor.pink, IsleColor.pinkDeep],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                Circle()
                    .strokeBorder(IsleColor.pink.opacity(0.6), lineWidth: 2)
                    .frame(width: 58, height: 58)
                Text(String(nickname.prefix(1)))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color.white)
            }''',
    '''struct MineHeader: View {
    let nickname: String
    let uid: String
    let points: Int
    let loaded: Bool

    @EnvironmentObject private var auth: AuthStore
    @State private var showPicker = false

    private var avatarURL: URL? {
        guard let a = auth.user?.avatar, !a.isEmpty else { return nil }
        if a.hasPrefix("http") { return URL(string: a) }
        return URL(string: a, relativeTo: APIClient.shared.baseURL)?.absoluteURL
    }

    var body: some View {
        HStack(spacing: 13) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [IsleColor.pink, IsleColor.pinkDeep],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)

                    if let u = avatarURL {
                        AsyncImage(url: u) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                    } else {
                        Text(String(nickname.prefix(1)))
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Color.white)
                    }

                    Circle()
                        .strokeBorder(IsleColor.pink.opacity(0.6), lineWidth: 2)
                        .frame(width: 58, height: 58)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPicker) {
                PhotoPicker { data in
                    Task { await auth.uploadAvatar(data) }
                }
            }
            .contextMenu {
                Button {
                    showPicker = true
                } label: {
                    Label("更换头像", systemImage: "photo")
                }
                if auth.user?.avatar != nil {
                    Button(role: .destructive) {
                        Task { await auth.resetAvatar() }
                    } label: {
                        Label("恢复默认头像", systemImage: "arrow.counterclockwise")
                    }
                }
            }''', 'MineHeader 头像')

save(p, s)
print('RootView done')

# ============ SettingsView：删掉源与设备 ============
p = 'Isle/Features/SettingsView.swift'
s = load(p)

s = sub(s, '''                    banner
                    if isAdmin { sourcesCard }
                    appearanceCard''',
    '''                    banner
                    appearanceCard''', 'Settings 删调用')

rx = re.compile(r'    private var sourcesCard: some View \{.*?\n    \}\n\n    private func navRow', re.S)
if not rx.search(s):
    print('MISS Settings sourcesCard')
    sys.exit(1)
s = rx.sub('    private func navRow', s, count=1)
print('OK   Settings 删 sourcesCard')

s = sub(s, '''        .task {
            refreshCache()
            if isAdmin { await loadSources() }
        }''',
    '''        .task {
            refreshCache()
        }''', 'Settings 删 loadSources 调用')

if 'UIImage(contentsOfFile' in s and 'import SwiftUI' in s:
    pass

save(p, s)
print('SettingsView done')

print('PATCH21 DONE')
