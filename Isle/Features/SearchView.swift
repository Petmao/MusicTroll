import SwiftUI

struct SearchView: View {
    @StateObject private var engine = MusicEngine.shared
    @ObservedObject private var history = SearchHistory.shared
    @State private var keyword = ""
    @State private var results: [[String: Any]] = []
    @State private var searching = false
    @State private var tip: String?
    @State private var tab = 0
    @State private var addTarget = ""
    @State private var showAdd = false

    private let tabs = ["综合", "单曲", "歌单", "歌手", "专辑"]
    private let covers: [Color] = [
        Color(red: 1, green: 0.55, blue: 0.35),
        Color(red: 0.48, green: 0.36, blue: 1),
        Color(red: 1, green: 0.82, blue: 0.25),
        Color(red: 0, green: 0.88, blue: 0.64)
    ]

    var body: some View {
        ZStack {
            IsleBackground()
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                tabRow
                tipLine
                searchingLine

                if results.isEmpty && !searching && !history.items.isEmpty {
                    historySection
                } else {
                    resultsList
                }
            }
        }
        .navigationTitle("搜索全网")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            AddToPlaylistSheet(title: addTarget)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            IsleIcon(IsleSymbol.search, scale: .sm, tint: Color.white.opacity(0.4))
            TextField("搜索全网歌曲、歌手、歌单", text: $keyword)
                .font(.system(size: 13.5))
                .foregroundStyle(Color.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit { Task { await run() } }
            if keyword.isEmpty {
                Button { Task { await run() } } label: {
                    Text("搜索")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(IsleColor.pinkLight)
                }
            } else {
                Button { keyword = ""; results = []; tip = nil } label: {
                    IsleIcon(IsleSymbol.plus, scale: .sm, tint: Color.white.opacity(0.35))
                        .rotationEffect(.degrees(45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(IsleColor.surfaceHi)
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(Color.white.opacity(0.10), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var tabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { i in
                    Button { tab = i } label: {
                        IslePill(text: tabs[i], active: tab == i)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var tipLine: some View {
        if let t = tip {
            Text(t)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private var searchingLine: some View {
        if searching {
            HStack(spacing: 8) {
                ProgressView().tint(Color.white)
                Text("搜索中…").font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
    }

    private var historySection: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("搜索历史")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                    Button { history.clear() } label: {
                        Text("清空")
                            .font(.system(size: 11))
                            .foregroundStyle(IsleColor.pinkLight)
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                          alignment: .leading,
                          spacing: 8) {
                    ForEach(history.items, id: \.self) { h in
                        Button {
                            keyword = h
                            Task { await run() }
                        } label: {
                            Text(h)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color.white.opacity(0.78))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .frame(maxWidth: .infinity)
                                .background(IsleColor.surface)
                                .overlay(Capsule().stroke(IsleColor.line, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)

                Text("点历史里的词直接重搜，跑过的关键词会自动留在这里")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
        }
    }

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(Array(results.enumerated()), id: \.offset) { idx, item in
                    resultRow(idx: idx, item: item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private func resultRow(idx: Int, item: [String: Any]) -> some View {
        let title = item["title"] as? String ?? "未知"
        let artist = item["artist"] as? String ?? ""
        let c1 = covers[idx % covers.count]
        let c2 = covers[(idx + 1) % covers.count]

        return Button { Task { await playAt(idx) } } label: {
            HStack(spacing: 12) {
                coverBlock(c1: c1, c2: c2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("音源")
                            .font(.system(size: 8.5, weight: .heavy))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(IsleColor.pink.opacity(0.25))
                            .foregroundStyle(IsleColor.pinkLight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text(artist)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

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
            }
            .padding(12)
            .background(IsleColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(IsleColor.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func coverBlock(c1: Color, c2: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 44, height: 44)
            .overlay(
                IsleIcon(IsleSymbol.music, scale: .md, tint: Color.white.opacity(0.8))
            )
    }

    private func playAt(_ idx: Int) async {
        let titles = results.compactMap { $0["title"] as? String }
        guard !titles.isEmpty else { return }
        await engine.playQueue(titles, startAt: min(idx, titles.count - 1))
    }

    private func run() async {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        searching = true
        tip = nil
        do {
            results = try await engine.search(k)
            SearchHistory.shared.add(k)
            if results.isEmpty { tip = "没有搜到结果，换个关键词或检查后台音源" }
        } catch let e as LocalizedError {
            tip = e.errorDescription
        } catch {
            tip = "搜索失败：\(error)"
        }
        searching = false
    }
}
