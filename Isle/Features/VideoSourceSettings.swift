import SwiftUI

struct VideoSourceSettingsView: View {
    @State private var rows: [SourceItem] = []
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            MineTheme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 9) {
                    if loading {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("正在拉取…").font(.system(size: 12)).foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    if let errorText {
                        HStack(spacing: 7) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
                            Text(errorText).font(.system(size: 11.5))
                            Spacer()
                        }
                        .foregroundColor(Color(red: 1, green: 0.62, blue: 0.35))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.35, green: 0.18, blue: 0.10).opacity(0.35)))
                    }
                    if rows.isEmpty && errorText == nil && !loading {
                        Text("后台还没有配置视频源")
                            .font(.system(size: 12)).foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    ForEach(rows) { s in row(s) }
                    Button { Task { await load() } } label: {
                        Text(loading ? "拉取中…" : "重新拉取")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                              Color(red: 1, green: 0.48, blue: 0.18)],
                                                     startPoint: .leading, endPoint: .trailing)))
                    }
                    .disabled(loading)
                    Text("视频源由后台 /admin.html → 视频源 配置，App 只负责拉取与播放。")
                        .font(.system(size: 9.5)).foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
        }
        .navigationTitle("视频源")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func row(_ s: SourceItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dot(s))
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name).font(.system(size: 13, weight: .semibold))
                Text(s.url).font(.system(size: 10)).foregroundColor(.gray).lineLimit(2)
                if let note = s.note, !note.isEmpty {
                    Text(note).font(.system(size: 9.5)).foregroundColor(.white.opacity(0.35))
                }
            }
            Spacer(minLength: 6)
            if let ms = s.lastMs {
                Text("\(ms)ms").font(.system(size: 9.5)).foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
    }

    private func dot(_ s: SourceItem) -> Color {
        switch s.healthy {
        case .some(true): return Color(red: 0.30, green: 0.90, blue: 0.66)
        case .some(false): return Color(red: 1, green: 0.45, blue: 0.35)
        case .none: return Color(white: 0.45)
        }
    }

    private func load() async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            rows = try await APIClient.shared.sources(kind: "video")
            if rows.isEmpty { errorText = nil }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            rows = []
        }
    }
}

struct MusicSourceSettingsView: View {
    @State private var rows: [SourceItem] = []
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            MineTheme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    if let errorText {
                        Text(errorText).font(.system(size: 11.5))
                            .foregroundColor(Color(red: 1, green: 0.62, blue: 0.35))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }
                    ForEach(rows) { s in
                        HStack(spacing: 10) {
                            Circle().fill(Color(red: 0.30, green: 0.90, blue: 0.66))
                                .frame(width: 7, height: 7)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(.system(size: 13, weight: .semibold))
                                Text(s.url).font(.system(size: 10)).foregroundColor(.gray).lineLimit(2)
                            }
                            Spacer()
                            if let ms = s.lastMs {
                                Text("\(ms)ms").font(.system(size: 9.5)).foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
                    }
                    Button { Task { await load() } } label: {
                        Text(loading ? "拉取中…" : "重新拉取")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                    }
                    .disabled(loading)
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
        }
        .navigationTitle("音乐音源")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            rows = try await APIClient.shared.sources(kind: "music")
            if rows.isEmpty { errorText = "后台未配置音乐源" }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            rows = []
        }
    }
}
