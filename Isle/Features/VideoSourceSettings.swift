import SwiftUI

struct VideoSourceSettingsView: View {
    @State private var rows: [SourceItem] = []
    @State private var loading = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 9) {
                    if loading {
                        HStack(spacing: 8) {
                            ProgressView().tint(IsleColor.pinkLight)
                            Text("正在拉取…").font(.system(size: 12)).foregroundStyle(IsleColor.textSub)
                            Spacer()
                        }
                        .padding(14)
                    }

                    if let errorText {
                        HStack(spacing: 7) {
                            IsleIcon(IsleSymbol.lock, scale: .sm, tint: IsleColor.gold)
                            Text(errorText).font(.system(size: 11.5))
                            Spacer()
                        }
                        .foregroundStyle(IsleColor.gold.opacity(0.9))
                        .padding(12)
                        .background(IsleColor.gold.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if rows.isEmpty && errorText == nil && !loading {
                        Text("后台还没有配置视频源")
                            .font(.system(size: 12))
                            .foregroundStyle(IsleColor.textSub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }

                    ForEach(rows) { s in
                        row(s)
                    }

                    reloadButton

                    Text("视频源由后台 /admin.html → 视频源 配置，App 只负责拉取与播放。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(IsleColor.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("视频源")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var reloadButton: some View {
        Button { Task { await load() } } label: {
            Text(loading ? "拉取中…" : "重新拉取")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(IsleColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    private func row(_ s: SourceItem) -> some View {
        HStack(spacing: 10) {
            Circle().fill(dot(s)).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.name).font(.system(size: 13, weight: .semibold))
                Text(s.url)
                    .font(.system(size: 10))
                    .foregroundStyle(IsleColor.textFaint)
                    .lineLimit(2)
                if let note = s.note, !note.isEmpty {
                    Text(note).font(.system(size: 9.5)).foregroundStyle(IsleColor.textSub)
                }
            }
            Spacer(minLength: 6)
            if let ms = s.lastMs {
                Text("\(ms)ms")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(IsleColor.mint.opacity(0.9))
            }
        }
        .padding(12)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dot(_ s: SourceItem) -> Color {
        switch s.healthy {
        case .some(true): return IsleColor.mint
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
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 11.5))
                            .foregroundStyle(IsleColor.gold.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }

                    ForEach(rows) { s in
                        musicRow(s)
                    }

                    Button { Task { await load() } } label: {
                        Text(loading ? "拉取中…" : "重新拉取")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(IsleColor.surfaceHi)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(loading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("音乐音源")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func musicRow(_ s: SourceItem) -> some View {
        HStack(spacing: 10) {
            Circle().fill(IsleColor.mint).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name).font(.system(size: 13, weight: .semibold))
                Text(s.url)
                    .font(.system(size: 10))
                    .foregroundStyle(IsleColor.textFaint)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            if let ms = s.lastMs {
                Text("\(ms)ms").font(.system(size: 9.5)).foregroundStyle(IsleColor.textSub)
            }
        }
        .padding(12)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
