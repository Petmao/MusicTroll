import SwiftUI

struct SourcesView: View {
    let kind: String
    @EnvironmentObject var auth: AuthStore
    @State private var rows: [SourceItem] = []
    @State private var loading = true
    @State private var loadError: String?

    private var pageTitle: String { kind == "music" ? "音乐音源" : "视频源" }

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    headerCard

                    if loading {
                        HStack(spacing: 8) {
                            ProgressView().tint(IsleColor.pinkLight)
                            Text("正在拉取…").font(.system(size: 12)).foregroundStyle(IsleColor.textSub)
                            Spacer()
                        }
                        .padding(16)
                    } else if let msg = loadError {
                        IsleCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(msg).font(.system(size: 12)).foregroundStyle(IsleColor.pinkLight)
                                Button { Task { await load() } } label: {
                                    Text("重试")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 18).padding(.vertical, 9)
                                        .background(IsleColor.accent)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if rows.isEmpty {
                        IsleCard {
                            Text("后台还没有配置\(pageTitle)，请到管理后台添加")
                                .font(.system(size: 12))
                                .foregroundStyle(IsleColor.textSub)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(rows) { s in
                            card(s)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await load() } } label: {
                    IsleIcon(IsleSymbol.sync, scale: .md, tint: .white)
                }
            }
        }
        .task { await load() }
    }

    private var headerCard: some View {
        HStack(spacing: 10) {
            IsleIcon(IsleSymbol.music, scale: .lg, tint: IsleColor.pinkLight)
            VStack(alignment: .leading, spacing: 3) {
                Text(kind == "music" ? "音源优先级" : "视频源")
                    .font(.system(size: 14, weight: .bold))
                Text("列表靠上的音源优先匹配，失败自动向下回退")
                    .font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [IsleColor.pink.opacity(0.26),
                                    IsleColor.lilac.opacity(0.14),
                                    Color.white.opacity(0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.pink.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func card(_ s: SourceItem) -> some View {
        IsleCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    Circle().fill(dotColor(s)).frame(width: 8, height: 8)
                    Text(s.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 6)
                    if let ms = s.lastMs, ms > 0 {
                        Text("\(ms)ms")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(IsleColor.mint.opacity(0.9))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(IsleColor.mint.opacity(0.12)))
                    }
                }
                Text(s.url)
                    .font(.system(size: 10))
                    .foregroundStyle(IsleColor.textFaint)
                    .lineLimit(1)
                if let n = s.note, !n.isEmpty {
                    Text(n).font(.system(size: 10)).foregroundStyle(IsleColor.textSub.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dotColor(_ s: SourceItem) -> Color {
        guard let ok = s.healthy else { return Color(white: 0.5) }
        return ok ? IsleColor.mint : Color(red: 1, green: 0.45, blue: 0.45)
    }

    private func load() async {
        loading = true
        loadError = nil
        do {
            rows = try await APIClient.shared.sources(kind: kind)
        } catch let APIError.http(code) {
            switch code {
            case "need_svip": loadError = "需要 SVIP 才能使用视频源"
            case "need_vip": loadError = "需要 VIP 才能使用音源"
            default: loadError = "拉取失败：\(code)"
            }
        } catch {
            loadError = "网络异常，检查服务器是否可达"
        }
        loading = false
    }
}
