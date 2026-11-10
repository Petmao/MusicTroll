import SwiftUI

/// 搜索页：全网（当前配置的音源）搜歌
struct SearchView: View {
    @StateObject private var engine = MusicEngine.shared
    @State private var keyword = ""
    @State private var results: [[String: Any]] = []
    @State private var searching = false
    @State private var tip: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15)).foregroundColor(.gray)
                TextField("搜索全网歌曲、歌手", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .onSubmit { Task { await run() } }
                if !keyword.isEmpty {
                    Button { keyword = ""; results = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
                Button { Task { await run() } } label: {
                    Text("搜索").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 1, green: 0.37, blue: 0.62))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16).padding(.top, 10)

            if searching {
                HStack(spacing: 8) { ProgressView(); Text("搜索中…").foregroundColor(.secondary) }
                    .padding(.top, 20)
            }

            if let t = tip {
                Text(t).font(.footnote).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 12)
            }

            List {
                ForEach(Array(results.enumerated()), id: \.offset) { idx, item in
                    let title = item["title"] as? String ?? "未知"
                    let artist = item["artist"] as? String ?? ""
                    Button {
                        Task { await engine.play(keyword: title) }
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.35),
                                                              Color(red: 0.48, green: 0.36, blue: 1)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40)
                                .overlay(Text("\(idx + 1)").font(.system(size: 12, weight: .bold)).foregroundColor(.white))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                                Text(artist).font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.fill").font(.system(size: 12))
                                .foregroundColor(Color(red: 1, green: 0.37, blue: 0.62))
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func run() async {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return }
        searching = true; tip = nil
        do {
            results = try await engine.search(k)
            if results.isEmpty { tip = "没有搜到结果，换个关键词" }
        } catch let e as LocalizedError {
            tip = e.errorDescription ?? "搜索失败"
        } catch {
            tip = "搜索失败：\(error)"
        }
        searching = false
    }
}
