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


# ================= LibraryView: favoritePlaylistID + AddToPlaylistSheet =================
p = 'Isle/Features/LibraryView.swift'
s = load(p)

s = sub(s, '''    func addSong(_ title: String, to id: UUID) {
        guard let i = lists.firstIndex(where: { $0.id == id }) else { return }
        guard !lists[i].songs.contains(title) else { return }
        lists[i].songs.append(title)
        save()
    }''',
    '''    func addSong(_ title: String, to id: UUID) {
        guard let i = lists.firstIndex(where: { $0.id == id }) else { return }
        guard !lists[i].songs.contains(title) else { return }
        lists[i].songs.append(title)
        save()
    }

    /// 「我喜欢的音乐」歌单 id，没有就建一个
    func favoritePlaylistID() -> UUID {
        if let p = lists.first(where: { $0.name == "我喜欢的音乐" }) { return p.id }
        let p = IslePlaylist(name: "我喜欢的音乐")
        lists.insert(p, at: 0)
        save()
        return p.id
    }''', 'LibraryView favoritePlaylistID')

if 'struct AddToPlaylistSheet' not in s:
    s += '''

struct AddToPlaylistSheet: View {
    let title: String
    @ObservedObject private var store = PlaylistStore.shared
    @Environment(\\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        TextField("新建歌单名", text: $newName)
                            .font(.system(size: 13))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(11)
                            .background(IsleColor.surfaceHi)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                        Button {
                            let n = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !n.isEmpty else { return }
                            store.add(n)
                            if let id = store.favoritePlaylistID() as UUID? {
                                _ = id
                            }
                            if let first = store.lists.first {
                                store.addSong(title, to: first.id)
                            }
                            dismiss()
                        } label: {
                            Text("新建并加入")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(IsleColor.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(store.lists) { p in
                                Button {
                                    store.addSong(title, to: p.id)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .fill(IsleColor.pink.opacity(0.18))
                                                .frame(width: 34, height: 34)
                                            IsleIcon(IsleSymbol.music, scale: .sm, tint: IsleColor.pinkLight)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(Color.white)
                                                .lineLimit(1)
                                            Text("\\(p.songs.count) 首")
                                                .font(.system(size: 10))
                                                .foregroundStyle(IsleColor.textSub)
                                        }
                                        Spacer(minLength: 0)
                                        if p.songs.contains(title) {
                                            Text("已在其中")
                                                .font(.system(size: 10))
                                                .foregroundStyle(IsleColor.mint)
                                        } else {
                                            IsleIcon(IsleSymbol.plus, scale: .sm, tint: Color.white.opacity(0.4))
                                        }
                                    }
                                    .padding(11)
                                    .background(IsleColor.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(IsleColor.line, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("加入歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
'''
    print('OK   LibraryView AddToPlaylistSheet')
else:
    print('SKIP LibraryView AddToPlaylistSheet')

save(p, s)
print('LibraryView done')

# ================= SearchView: 每行加菜单 =================
p = 'Isle/Features/SearchView.swift'
s = load(p)

s = sub(s, "    @State private var tab = 0",
    """    @State private var tab = 0
    @State private var addTarget = ""
    @State private var showAdd = false""", 'SearchView 状态')

s = sub(s, """        .navigationTitle("搜索全网")
        .navigationBarTitleDisplayMode(.inline)
    }""",
    """        .navigationTitle("搜索全网")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddToPlaylistSheet(title: addTarget)
        }
    }""", 'SearchView sheet')

s = sub(s, '''                Spacer(minLength: 6)

                IsleIcon(IsleSymbol.more, scale: .sm, tint: Color.white.opacity(0.35))
            }''',
    '''                Spacer(minLength: 6)

                Menu {
                    Button {
                        Task { await playAt(idx) }
                    } label: {
                        Label("播放", systemImage: "play.fill")
                    }

                    Button {
                        addTarget = title
                        showAdd = true
                    } label: {
                        Label("加入歌单", systemImage: "text.badge.plus")
                    }

                    Button {
                        let id = PlaylistStore.shared.favoritePlaylistID()
                        PlaylistStore.shared.addSong(title, to: id)
                    } label: {
                        Label("加入我喜欢的音乐", systemImage: "heart")
                    }
                } label: {
                    IsleIcon(IsleSymbol.more, scale: .sm, tint: Color.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }''', 'SearchView 行菜单')

save(p, s)
print('SearchView done')

# ================= 播放器喜欢同步进歌单 =================
p = 'Isle/Player/CymusicPlayerView.swift'
s = load(p)

s = sub(s, '''            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                _ = fav.toggle(title: t, artist: a)
            }''',
    '''            let likedNow = fav.toggle(title: t, artist: a)
            if likedNow {
                let pid = PlaylistStore.shared.favoritePlaylistID()
                PlaylistStore.shared.addSong(t, to: pid)
            }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {}''', '播放器喜欢同步歌单')

save(p, s)
print('CymusicPlayerView done')

print('PATCH12 DONE')
