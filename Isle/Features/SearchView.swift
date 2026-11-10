import SwiftUI

/// 搜索页（按设计稿：深色、玻璃搜索框、彩色结果行）
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
            LinearGradient(colors: [Color(red: 0.13, green: 0.04, blue: 0.19),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                searchBar.padding(.horizontal, 16).padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<tabs.count, id: \.self) { i in
                            Button { tab = i } label: {
                                Text(tabs[i])
                                    .font(.system(size: 12, weight: tab == i ? .bold : .regular))
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(tab == i
                                                ? AnyView(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                                                  Color(red: 1, green: 0.48, blue: 0.18)],
                                                                         startPoint: .leading, endPoint: .trailing))
                                                : AnyView(Color.white.opacity(0.06)))
                                    .clipShape(Capsule())
                                    .foregroundColor(tab == i ? .white : .white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)

                if let t = tip {
                    Text(t).font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.top, 10)
                }

                if searching {
                    HStack(spacing: 8) { ProgressView().tint(.white); Text("搜索中…").foregroundColor(.white.opacity(0.5)) }
                        .padding(.top, 24)
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.offset) { idx, item in
                            let title = item["title"] as? String ?? "未知"
                            let artist = item["artist"] as? String ?? ""
                            Button { Task { await engine.play(keyword: title) } } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient(colors: [covers[idx % covers.count],
                                                                      covers[(idx + 1) % covers.count]],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 44, height: 44)
                                        .overlay(Image(systemName: "music.note")
                                                    .font(.system(size: 15)).foregroundColor(.white.opacity(0.8)))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(title).font(.system(size: 13.5, weight: .semibold))
                                            .foregroundColor(.white).lineLimit(1)
                                        HStack(spacing: 6) {
                                            Text("音源").font(.system(size: 8.5, weight: .heavy))
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(Color(red: 1, green: 0.18, blue: 0.47).opacity(0.25))
                                                .foregroundColor(Color(red: 1, green: 0.55, blue: 0.72))
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            Text(artist).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.45))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "ellipsis").font(.system(size: 14)).foregroundColor(.white.opacity(0.35))
                                }
                                .padding(.horizontal, 20).padding(.vertical, 9)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider().background(Color.white.opacity(0.05)).padding(.leading, 76)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("搜索全网")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundColor(.white.opacity(0.4))
            TextField("搜索全网歌曲、歌手、歌单", text: $keyword)
                .font(.system(size: 13.5)).foregroundColor(.white)
                .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit { Task { await run() } }
            if !keyword.isEmpty {
                Button { keyword = ""; results = []; tip = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.white.opacity(0.35))
                }
            } else {
                Button { Task { await run() } } label: {
                    Text("搜索").font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 1, green: 0.45, blue: 0.65))
                }
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(Color.white.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func run() async {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        searching = true; tip = nil
        do {
            results = try await engine.search(k)
            if results.isEmpty { tip = "没有搜到结果，换个关键词或检查后台音源" }
        } catch let e as LocalizedError { tip = e.errorDescription }
        catch { tip = "搜索失败：\(error)" }
        searching = false
    }
}
