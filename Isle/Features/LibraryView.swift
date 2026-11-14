import SwiftUI

struct IslePlaylist: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var songs: [String] = []
}

final class PlaylistStore: ObservableObject {
    static let shared = PlaylistStore()
    private let key = "isle.playlists"
    @Published var lists: [IslePlaylist] = []

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([IslePlaylist].self, from: d) {
            lists = v
        } else {
            lists = [IslePlaylist(name: "我喜欢的音乐"), IslePlaylist(name: "夜跑 DJ 循环")]
        }
    }

    func add(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        lists.insert(IslePlaylist(name: n), at: 0)
        save()
    }

    func remove(at offsets: IndexSet) {
        lists.remove(atOffsets: offsets)
        save()
    }

    func addSong(_ title: String, to id: UUID) {
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
    }

    private func save() {
        if let d = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}

struct LibraryView: View {
    @ObservedObject private var fav = FavoritesStore.shared
    @ObservedObject private var store = PlaylistStore.shared
    @State private var tab = 0
    @State private var showNew = false
    @State private var openList: IslePlaylist?

    private let tabs = ["收藏", "歌单", "本地"]
    private let covers: [LinearGradient] = [
        LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47), Color(red: 1, green: 0.54, blue: 0)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.48, green: 0.36, blue: 1), Color(red: 0, green: 0.83, blue: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.25), Color(red: 1, green: 0.42, blue: 0)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    ]

    var body: some View {
        ZStack {
            IsleBackground()
            VStack(spacing: 0) {
                header
                content
            }
        }
        .navigationTitle("收藏与歌单")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNew) {
            NewPlaylistSheet { name in store.add(name) }
        }
        .sheet(item: $openList) { p in
            PlaylistDetailView(playlist: p)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                Button { tab = i } label: {
                    IslePill(text: t, active: tab == i)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if tab == 1 {
                Button { showNew = true } label: {
                    HStack(spacing: 4) {
                        IsleIcon(IsleSymbol.plus, scale: .sm, weight: .bold, tint: IsleColor.pink)
                        Text("新建")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(IsleColor.pink)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case 0: favList
        case 1: playlistGrid
        default: emptyHint("还没有本地音乐", "下载完成的歌曲会出现在这里")
        }
    }

    @ViewBuilder
    private var favList: some View {
        if fav.items.isEmpty {
            emptyHint("还没有收藏的歌曲", "在播放器点收藏就会出现在这里")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(fav.items) { s in
                        favRow(s.title, s.artist)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 22)
            }
        }
    }

    private func favRow(_ title: String, _ artist: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(covers[0])
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(artist).font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub).lineLimit(1)
            }
            Spacer(minLength: 6)
            Button { fav.toggle(title: title, artist: artist) } label: {
                IsleIcon(IsleSymbol.heartFill, scale: .md, tint: IsleColor.pink)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var playlistGrid: some View {
        if store.lists.isEmpty {
            emptyHint("还没有歌单", "点右上角「新建」建一个")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 12) {
                    ForEach(Array(store.lists.enumerated()), id: \.element.id) { i, p in
                        Button { openList = p } label: {
                            VStack(alignment: .leading, spacing: 7) {
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 22)
            }
        }
    }

    private func emptyHint(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            IsleIcon(IsleSymbol.music, scale: .hero, tint: Color.white.opacity(0.20))
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.7))
            Text(sub).font(.system(size: 11)).foregroundStyle(IsleColor.textFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct NewPlaylistSheet: View {
    let onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var ready: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                VStack(spacing: 14) {
                    TextField("歌单名称", text: $name)
                        .font(.system(size: 15))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(14)
                        .background(IsleColor.surfaceHi)
                        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(IsleColor.pink.opacity(0.35), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Button {
                        onCreate(name)
                        dismiss()
                    } label: {
                        Text("创建")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(IsleColor.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!ready)
                    .opacity(ready ? 1 : 0.5)

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("新建歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct PlaylistDetailView: View {
    let playlist: IslePlaylist
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = MusicEngine.shared

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        if playlist.songs.isEmpty {
                            VStack(spacing: 6) {
                                IsleIcon(IsleSymbol.music, scale: .xl, tint: Color.white.opacity(0.25))
                                Text("这个歌单还是空的")
                                    .font(.system(size: 12)).foregroundStyle(IsleColor.textSub)
                                Text("在搜索或播放器里长按歌曲可加入")
                                    .font(.system(size: 10)).foregroundStyle(IsleColor.textFaint)
                            }
                            .padding(.top, 60)
                        } else {
                            Button {
                                Task { await engine.playQueue(playlist.songs, startAt: 0) }
                            } label: {
                                HStack(spacing: 6) {
                                    IsleIcon(IsleSymbol.play, scale: .sm, weight: .bold, tint: Color.white)
                                    Text("播放全部 · \(playlist.songs.count) 首")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(IsleColor.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 6)

                            ForEach(Array(playlist.songs.enumerated()), id: \.offset) { i, s in
                                Button {
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
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }
}


struct AddToPlaylistSheet: View {
    let title: String
    @ObservedObject private var store = PlaylistStore.shared
    @Environment(\.dismiss) private var dismiss
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
                                            Text("\(p.songs.count) 首")
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
