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
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        lists.append(IslePlaylist(name: name))
        save()
    }

    func remove(at offsets: IndexSet) {
        lists.remove(atOffsets: offsets)
        save()
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
    @State private var newName = ""
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
        .alert("新建歌单", isPresented: $showNew) {
            TextField("歌单名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") { store.add(newName); newName = "" }
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
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08)).frame(width: 30, height: 30)
                        IsleIcon(IsleSymbol.plus, scale: .sm, weight: .bold, tint: IsleColor.pink)
                    }
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
            emptyHint("还没有歌单", "点右上角加号新建一个")
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

struct PlaylistDetailView: View {
    let playlist: IslePlaylist
    @Environment(\.dismiss) private var dismiss

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
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(playlist.songs, id: \.self) { s in
                                Text(s)
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(IsleColor.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
