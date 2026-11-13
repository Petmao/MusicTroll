import SwiftUI

struct SearchView: View {
    @StateObject private var engine = MusicEngine.shared
    @State private var keyword = ""
    @State private var results: [[String: Any]] = []
    @State private var searching = false
    @State private var tip: String?
    @State private var tab = 0

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
                resultsList
            }
        }
        .navigationTitle("搜索全网")
        .navigationBarTitleDisplayMode(.inline)
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

        return Button { Task { await engine.play(keyword: title) } } label: {
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

                IsleIcon(IsleSymbol.more, scale: .sm, tint: Color.white.opacity(0.35))
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

    private func run() async {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        searching = true
        tip = nil
        do {
            results = try await engine.search(k)
            if results.isEmpty { tip = "没有搜到结果，换个关键词或检查后台音源" }
        } catch let e as LocalizedError {
            tip = e.errorDescription
        } catch {
            tip = "搜索失败：\(error)"
        }
        searching = false
    }
}
