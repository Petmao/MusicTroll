import Foundation
import AVFoundation
import Combine

struct MusicTrack: Equatable {
    let title: String
    let artist: String
    let playURL: URL
}

/// 音乐引擎：拉音源脚本 → 搜索 → 取播放地址 → 走服务端签名流播放
@MainActor
final class MusicEngine: ObservableObject {
    static let shared = MusicEngine()

    @Published var current: MusicTrack?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var status: String = "就绪"

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var ticker: Timer?
    private var runners: [Int: ScriptRunner] = [:]

    enum EngineError: Error, LocalizedError {
        case noSource, badSource, noResult, noUrl
        var errorDescription: String? {
            switch self {
            case .noSource: return "后台还没配置音乐音源"
            case .badSource: return "音源地址无效"
            case .noResult: return "搜索无结果"
            case .noUrl: return "没取到播放地址"
            }
        }
    }

    // MARK: - 脚本加载
    func loadSources() async -> [SourceItem] {
        (try? await APIClient.shared.sources(kind: "music")) ?? []
    }

    private func runner(for src: SourceItem) async throws -> ScriptRunner {
        if let r = runners[src.id] { return r }
        guard let url = URL(string: src.url) else { throw EngineError.badSource }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else { throw EngineError.badSource }
        let r = try ScriptRunner(script: text, name: src.name)
        runners[src.id] = r
        return r
    }

    // MARK: - 搜索
    func search(_ keyword: String) async throws -> [[String: Any]] {
        let sources = await loadSources()
        guard let src = sources.first else { throw EngineError.noSource }
        let r = try await runner(for: src)
        let raw = try r.call("search", [keyword])
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let list = obj as? [[String: Any]] else { throw EngineError.noResult }
        return list
    }

    // MARK: - 播放
    func play(keyword: String) async {
        status = "搜索中…"
        do {
            let list = try await search(keyword)
            guard let first = list.first else { throw EngineError.noResult }
            let title = first["title"] as? String ?? keyword
            let artist = first["artist"] as? String ?? ""

            var rawUrl = first["url"] as? String
            if rawUrl == nil || rawUrl!.isEmpty {
                let sources = await loadSources()
                if let src = sources.first {
                    let r = try await runner(for: src)
                    let json = String(data: try JSONSerialization.data(withJSONObject: first), encoding: .utf8) ?? "{}"
                    rawUrl = try r.call("getUrl", [json])
                }
            }
            guard let s = rawUrl, let up = URL(string: s) else { throw EngineError.noUrl }

            // 走服务端签名流：会员校验在这里发生
            status = "取播放票据…"
            let ticket = try await APIClient.shared.playTicket(url: up.absoluteString, kind: "audio")
            guard let signed = URL(string: ticket.path, relativeTo: APIClient.shared.baseURL)?.absoluteURL else {
                throw EngineError.noUrl
            }

            let p = AVPlayer(url: signed)
            player = p
            current = MusicTrack(title: title, artist: artist, playURL: signed)
            p.play()
            isPlaying = true
            status = "正在播放"
            startTick()
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? "播放失败：\(error)"
            isPlaying = false
        }
    }

    func toggle() {
        guard let p = player else { return }
        if isPlaying { p.pause() } else { p.play() }
        isPlaying.toggle()
    }

    func seek(to ratio: Double) {
        guard let p = player, let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
        p.seek(to: CMTime(seconds: d * ratio, preferredTimescale: 600))
        progress = ratio
    }

    private func startTick() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let p = self.player else { return }
                let t = p.currentTime().seconds
                let d = p.currentItem?.duration.seconds ?? 0
                if d.isFinite, d > 0 { self.progress = min(1, max(0, t / d)) }
                if p.timeControlStatus != .playing { self.isPlaying = false } else { self.isPlaying = true }
            }
        }
    }
}
