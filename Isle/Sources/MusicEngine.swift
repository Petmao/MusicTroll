import Foundation
import AVFoundation
import Combine

struct MusicTrack: Equatable {
    let title: String
    let artist: String
    let playURL: URL
    var cover: String? = nil
}

/// 音乐引擎：直连 api.irepo.cn/api/wxmusic，带超时/重试
@MainActor
final class MusicEngine: ObservableObject {
    static let shared = MusicEngine()

    @Published var current: MusicTrack?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var status: String = "就绪"

    private var player: AVPlayer?
    private var ticker: Timer?
    private let apiBase = "https://api.irepo.cn/api/wxmusic"

    enum EngineError: Error, LocalizedError {
        case noResult
        case noUrl
        case timeout
        case offline
        case api(String)
        var errorDescription: String? {
            switch self {
            case .noResult: return "没搜到这首歌，换个关键词试试"
            case .noUrl: return "接口没返回播放地址"
            case .timeout: return "接口超时了，再点一次试试"
            case .offline: return "网络连不上，检查一下网络"
            case .api(let m): return "接口错误：\(m)"
            }
        }
    }

    // MARK: - 搜索（带重试）
    func search(_ keyword: String) async throws -> [[String: Any]] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { throw EngineError.noResult }

        var lastError: Error = EngineError.timeout
        for attempt in 0..<2 {
            do {
                return try await requestOnce(kw)
            } catch {
                lastError = error
                if attempt == 0 { try? await Task.sleep(nanoseconds: 800_000_000) }
            }
        }
        throw lastError
    }

    private func requestOnce(_ keyword: String) async throws -> [[String: Any]] {
        guard var comps = URLComponents(string: apiBase) else { throw EngineError.api("bad_url") }
        comps.queryItems = [
            URLQueryItem(name: "source", value: "third"),
            URLQueryItem(name: "keyword", value: keyword)
        ]
        guard let url = comps.url else { throw EngineError.api("bad_url") }

        var req = URLRequest(url: url, timeoutInterval: 40)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            switch e.code {
            case .timedOut: throw EngineError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw EngineError.offline
            default: throw EngineError.api(e.localizedDescription)
            }
        }

        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw EngineError.api("HTTP \(http.statusCode)")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EngineError.api("返回不是 JSON")
        }

        let code = (obj["code"] as? Int) ?? 0
        let title = (obj["title"] as? String) ?? ""
        let singer = (obj["singer"] as? String) ?? ""
        let musicURL = (obj["music_url"] as? String) ?? (obj["link"] as? String) ?? ""
        let cover = (obj["cover"] as? String) ?? ""

        guard !musicURL.isEmpty else {
            if code == 200 { throw EngineError.noUrl }
            let msg = (obj["msg"] as? String) ?? (obj["message"] as? String) ?? "code \(code)"
            throw EngineError.api(msg)
        }

        return [[
            "title": title.isEmpty ? keyword : title,
            "artist": singer.isEmpty ? "未知歌手" : singer,
            "url": musicURL,
            "cover": cover
        ]]
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
        let title = (item["title"] as? String) ?? keyword
        let artist = (item["artist"] as? String) ?? "未知歌手"
        guard let raw = item["url"] as? String, let up = URL(string: raw) else {
            throw EngineError.noUrl
        }

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
        current = MusicTrack(title: title, artist: artist, playURL: signed,
                             cover: item["cover"] as? String)
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
