import SwiftUI

/// 音源 / 视频源列表：内容由后台配置，App 只负责拉取与展示
struct SourcesView: View {
    let kind: String          // "music" / "video"
    @EnvironmentObject var auth: AuthStore
    @State private var rows: [SourceItem] = []
    @State private var loading = true
    @State private var error: String?

    private var title: String { kind == "music" ? "音乐音源" : "视频源" }

    var body: some View {
        List {
            if loading {
                HStack { ProgressView(); Text("正在拉取…").foregroundColor(.secondary) }
            } else if let error = error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).foregroundColor(.pink)
                    Button("重试") { Task { await load() } }
                }
            } else if rows.isEmpty {
                Text("后台还没有配置\(title)，请到管理后台添加").foregroundColor(.secondary)
            } else {
                ForEach(rows) { s in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(dotColor(s))
                            .frame(width: 7, height: 7)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.name).font(.system(size: 14, weight: .semibold))
                            Text(s.url).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                            if let n = s.note, !n.isEmpty {
                                Text(n).font(.system(size: 10)).foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                        Spacer()
                        if let ms = s.lastMs, ms > 0 {
                            Text("\(ms)ms").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(title)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
            Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
        } }
        .task { await load() }
    }

    private func dotColor(_ s: SourceItem) -> Color {
        guard let ok = s.healthy else { return .gray }
        return ok ? Color(red: 0.31, green: 0.90, blue: 0.66) : Color(red: 1, green: 0.56, blue: 0.28)
    }

    private func load() async {
        loading = true; error = nil
        do { rows = try await APIClient.shared.sources(kind: kind) }
        catch APIError.http(let code) {
            error = code == "need_svip" ? "需要 SVIP 才能使用视频源"
                  : code == "need_vip"  ? "需要 VIP 才能使用音源"
                  : "拉取失败：\(code)"
        }
        catch { error = "网络异常" }
        loading = false
    }
}
