import SwiftUI

/// 搜索历史，UserDefaults 持久化，上限 20 条，重复项提到最前
final class SearchHistory: ObservableObject {
    static let shared = SearchHistory()

    @Published private(set) var items: [String] = []

    private let key = "isle.search.history"
    private let limit = 20

    private init() {
        items = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ k: String) {
        let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.removeAll { $0 == t }
        items.insert(t, at: 0)
        if items.count > limit { items = Array(items.prefix(limit)) }
        flush()
    }

    func remove(_ k: String) {
        items.removeAll { $0 == k }
        flush()
    }

    func clear() {
        items = []
        flush()
    }

    private func flush() {
        UserDefaults.standard.set(items, forKey: key)
    }
}

/// 底部迷你播放条，对应 Cymusic 的 FloatingPlayer：
/// 圆角 14、毛玻璃底、封面 36×36 圆角 8、右侧 播放/暂停 22 + 下一首 20、底部 2pt 进度条。
/// 点整条重新拉起全屏播放器。
struct MiniPlayerBar: View {
    @ObservedObject private var engine = MusicEngine.shared
    @ObservedObject private var palette = CymusicPalette.shared
    @ObservedObject private var presenter = PlayerPresenter.shared

    var body: some View {
        if engine.current != nil {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            Button { presenter.present() } label: {
                HStack(spacing: 10) {
                    artwork
                    VStack(alignment: .leading, spacing: 1) {
                        Text(engine.current?.title ?? "")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                        if let a = engine.current?.artist, !a.isEmpty {
                            Text(a)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                }
            }
            .buttonStyle(.plain)

            Button { engine.toggle() } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Button { engine.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.08, green: 0.04, blue: 0.07).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .bottom) { progress }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private var artwork: some View {
        ZStack {
            palette.color(for: engine.current?.cover)
            if let s = engine.current?.cover, let u = URL(string: s) {
                AsyncImage(url: u) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.clear
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var progress: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Color.white.opacity(0.10)
                Color.white.opacity(0.55)
                    .frame(width: g.size.width * max(0, min(1, engine.progress)))
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 8)
        .padding(.bottom, 1)
    }
}
