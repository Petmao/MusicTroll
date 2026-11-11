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
        case noSource, badSource, noResult, noUrl, scriptMissing(String)
        var errorDescription: String? {
            switch self {
            case .noSource: return "后台还没配置音乐音源"
            case .badSource: return "音源地址无效或不是 JS"
            case .noResult: return "搜索无结果"
            case .noUrl: return "没取到播放地址"
            case .scriptMissing(let f): return "音源脚本缺少函数 \(f)"
            }
        }
    }

    // MARK: - 源
    func loadSources() async -> [SourceItem] {
        (try? await APIClient.shared.sources(kind: "music")) ?? []
    }

    private func runner(for src: SourceItem) async throws -> ScriptRunner {
        if let r = runners[src.id] { return r }
        guard let url = URL(string: src.url) else { throw EngineError.badSource }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw EngineError.badSource
        }
        guard let text = String(data: data, encoding: .utf8) else { throw EngineError.badSource }
        let r = try ScriptRunner(script: text, name: src.name)
        runners[src.id] = r
        return r
    }

    // MARK: - 解析（宽容）
    private func parseList(_ raw: String) -> [[String: Any]]? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("\"") { // 二次编码的 JSON 字符串
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
                    let mapped = arr.compactMap { $0 as? [String: Any] }
                    if !mapped.isEmpty { return mapped }
                }
            }
        }
        return nil
    }

    private func pickURL(_ item: [String: Any]) -> String? {
        for k in ["url", "playUrl", "play_url", "src", "link", "musicUrl"] {
            if let v = item[k] as? String, !v.isEmpty, v.hasPrefix("http") { return v }
        }
        return nil
    }

    private func titleOf(_ item: [String: Any], fallback: String) -> String {
        for k in ["title", "name", "songname", "songName"] {
            if let v = item[k] as? String, !v.isEmpty { return v }
        }
        return fallback
    }

    private func artistOf(_ item: [String: Any]) -> String {
        for k in ["artist", "singer", "singername", "author"] {
            if let v = item[k] as? String, !v.isEmpty { return v }
        }
        if let arr = item["artists"] as? [[String: Any]] {
            return arr.compactMap { $0["name"] as? String }.joined(separator: "/")
        }
        return "未知歌手"
    }

    // MARK: - 搜索
    func search(_ keyword: String) async throws -> [[String: Any]] {
        let sources = await loadSources()
        guard let src = sources.first else { throw EngineError.noSource }
        let r = try await runner(for: src)

        // 兼容多种函数名
        var lastError: Error = EngineError.scriptMissing("search")
        for fn in ["search", "musicSearch", "searchMusic", "getSearch"] {
            do {
                let raw = try r.call(fn, [keyword])
                if let list = parseList(raw), !list.isEmpty { return list }
                // 返回为空，继续试下一个
            } catch ScriptError.noFunction {
                continue
            } catch {
                lastError = error
            }
        }
        throw (lastError is ScriptError) ? EngineError.noResult : lastError
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
        let title = titleOf(item, fallback: keyword)
        let artist = artistOf(item)
        var rawUrl = pickURL(item)

        if rawUrl == nil {
            status = "取播放地址…"
            let sources = await loadSources()
            if let src = sources.first {
                let r = try await runner(for: src)
                let json = String(data: (try? JSONSerialization.data(withJSONObject: item)) ?? Data("{}".utf8),
                                  encoding: .utf8) ?? "{}"
                for fn in ["getUrl", "getMusicUrl", "getPlayUrl"] {
                    if let s = try? r.call(fn, [json]), s.hasPrefix("http") { rawUrl = s; break }
                }
            }
        }
        guard let s = rawUrl, let up = URL(string: s) else { throw EngineError.noUrl }

        status = "取播放票据…"
        let ticket = try await APIClient.shared.playTicket(url: up.absoluteString, kind: "audio")
        guard let signed = URL(string: ticket.path, relativeTo: APIClient.shared.baseURL)?.absoluteURL else {
            throw EngineError.noUrl
        }

        // 精确跳转开启时使用完整缓冲
        let precise = UserDefaults.standard.bool(forKey: "preciseSeek")
        let item0 = AVPlayerItem(url: signed)
        item0.preferredForwardBufferDuration = precise ? 0 : 3
        let p = AVPlayer(playerItem: item0)
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
