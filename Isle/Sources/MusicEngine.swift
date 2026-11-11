import Foundation
import AVFoundation
import Combine

struct MusicTrack: Equatable {
    let title: String
    let artist: String
    let playURL: URL
}

/// 音乐引擎：优先用脚本 → 脚本没有 search 时走内置搜索兜底
@MainActor
final class MusicEngine: ObservableObject {
    static let shared = MusicEngine()

    @Published var current: MusicTrack?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var status: String = "就绪"

    private var player: AVPlayer?
    private var ticker: Timer?
    private var runners: [Int: ScriptRunner] = [:]

    enum EngineError: Error, LocalizedError {
        case noResult, noUrl, builtinFailed
        var errorDescription: String? {
            switch self {
            case .noResult: return "搜索无结果"
            case .noUrl: return "没取到播放地址"
            case .builtinFailed: return "内置搜索也失败，请检查网络"
            }
        }
    }

    func loadSources() async -> [SourceItem] {
        (try? await APIClient.shared.sources(kind: "music")) ?? []
    }

    private func runner(for src: SourceItem) async throws -> ScriptRunner {
        if let r = runners[src.id] { return r }
        guard let url = URL(string: src.url) else { throw EngineError.builtinFailed }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let text = String(data: data, encoding: .utf8) else { throw EngineError.builtinFailed }
        let r = try ScriptRunner(script: text, name: src.name)
        runners[src.id] = r
        return r
    }

    // MARK: - 解析脚本返回
    private func parseList(_ raw: String) -> [[String: Any]]? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("\"") {
            if let unwrapped = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? String {
                s = unwrapped.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let arr = obj as? [[String: Any]] { return arr }
        if let dict = obj as? [String: Any] {
            for key in ["data", "list", "songs", "result", "items", "results"] {
                if let arr = dict[key] as? [[String: Any]] { return arr }
                if let arr = dict[key] as? [Any] {
                    let m = arr.compactMap { $0 as? [String: Any] }
                    if !m.isEmpty { return m }
                }
            }
        }
        return nil
    }

    // MARK: - 搜索
    func search(_ keyword: String) async throws -> [[String: Any]] {
        let sources = await loadSources()

        if let src = sources.first,
           let r = try? await runner(for: src) {
            for fn in ["search", "musicSearch", "searchMusic", "getSearch"] {
                if let raw = try? r.call(fn, [keyword]), let list = parseList(raw), !list.isEmpty {
                    return list
                }
            }
        }

        // 脚本不支持搜索（LX 格式）→ 内置搜索
        status = "内置搜索…"
        if let list = try? await builtinSearch(keyword), !list.isEmpty { return list }
        throw EngineError.noResult
    }

    /// 内置搜索：网易云公开搜索接口
    private func builtinSearch(_ keyword: String) async throws -> [[String: Any]] {
        var comps = URLComponents(string: "https://music.163.com/api/search/get/web")!
        comps.queryItems = [
            URLQueryItem(name: "s", value: keyword),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "0")
        ]
        guard let url = comps.url else { throw EngineError.builtinFailed }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = obj["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            throw EngineError.builtinFailed
        }

        return songs.compactMap { s -> [String: Any]? in
            guard let id = s["id"] as? Int, let name = s["name"] as? String else { return nil }
            let artists = (s["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
            return [
                "title": name,
                "artist": artists.joined(separator: "/"),
                "id": String(id),
                "url": "https://music.163.com/song/media/outer/url?id=\(id).mp3"
            ]
        }
    }

    // MARK: - 播放
    func play(keyword: String) async {
        status = "搜索中…"
        do {
            let list = try await search(keyword)
            guard let first = list.first else { throw EngineError.noResult }
            try await playItem(first, keyword: keyword)
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? "播放失败：\(error)"
            isPlaying = false
        }
    }

    func playItem(_ item: [String: Any], keyword: String) async throws {
        let title = (item["title"] as? String) ?? (item["name"] as? String) ?? keyword
        var artist = (item["artist"] as? String) ?? (item["singer"] as? String) ?? ""
        if artist.isEmpty, let arr = item["artists"] as? [[String: Any]] {
            artist = arr.compactMap { $0["name"] as? String }.joined(separator: "/")
        }
        if artist.isEmpty { artist = "未知歌手" }

        var rawUrl: String?
        for k in ["url", "playUrl", "play_url", "src", "link"] {
            if let v = item[k] as? String, v.hasPrefix("http") { rawUrl = v; break }
        }

        // 脚本取地址（LX 格式）：先试 getUrl 系列
        if rawUrl == nil, let src = (await loadSources()).first,
           let r = try? await runner(for: src) {
            let json = String(data: (try? JSONSerialization.data(withJSONObject: item)) ?? Data("{}".utf8),
                              encoding: .utf8) ?? "{}"
            for fn in ["getUrl", "getMusicUrl", "getPlayUrl"] {
                if let s = try? r.call(fn, [json]), s.hasPrefix("http") { rawUrl = s; break }
            }
        }

        // 兜底：网易云外链
        if rawUrl == nil, let id = item["id"] as? String {
            rawUrl = "https://music.163.com/song/media/outer/url?id=\(id).mp3"
        }

        guard let s = rawUrl, let up = URL(string: s) else { throw EngineError.noUrl }

        status = "取播放票据…"
        let ticket = try await APIClient.shared.playTicket(url: up.absoluteString, kind: "audio")
        guard let signed = URL(string: ticket.path, relativeTo: APIClient.shared.baseURL)?.absoluteURL else {
            throw EngineError.noUrl
        }

        let precise = UserDefaults.standard.bool(forKey: "preciseSeek")
        let it = AVPlayerItem(url: signed)
        it.preferredForwardBufferDuration = precise ? 0 : 3
        let p = AVPlayer(playerItem: it)
        p.automaticallyWaitsToMinimizeStalling = !precise
        player = p
        current = MusicTrack(title: title, artist: artist, playURL: signed)
        p.play()
        isPlaying = true
        status = "正在播放"
        startTick()
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
                self.isPlaying = (p.timeControlStatus == .playing)
            }
        }
    }
}
