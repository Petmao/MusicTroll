import Foundation
import AVFoundation
import Combine

struct MusicTrack: Equatable {
    let title: String
    let artist: String
    let playURL: URL
    var cover: String? = nil
}

/// 音乐引擎：本地文件走 AudioFX（EQ/变速），远程流走 AVPlayer，歌词来自 lrclib.net
@MainActor
final class MusicEngine: ObservableObject {
    static let shared = MusicEngine()

    @Published var current: MusicTrack?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var status: String = "就绪"
    @Published var lyrics: [LyricLine] = []
    @Published var lyricState: String = ""

    enum RepeatMode: String { case off, all, one }

    @Published var queue: [String] = []
    @Published var queueIndex: Int = -1
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleOn = false
    @Published var volume: Float = 1.0

    private var endObs: NSObjectProtocol?
    private var endGuard = false

    private var player: AVPlayer?
    private var ticker: Timer?
    private var itemObs: NSKeyValueObservation?
    private var usingFX = false
    private var lyricCache: [String: [LyricLine]] = [:]
    /// 音源入口统一从 Config.apiBaseURL 派生，改域名只改 Config.swift 一处
    private var apiBase: String {
        Config.apiBaseURL.appendingPathComponent("api/wxmusic").absoluteString
    }

    enum EngineError: Error, LocalizedError {
        case noResult, noUrl, timeout, offline
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

    private func configureSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
        try? s.setActive(true)
    }

    // MARK: - 搜索

    func search(_ keyword: String) async throws -> [[String: Any]] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { throw EngineError.noResult }
        var last: Error = EngineError.timeout
        for i in 0..<2 {
            do { return try await requestOnce(kw) }
            catch {
                last = error
                if i == 0 { try? await Task.sleep(nanoseconds: 700_000_000) }
            }
        }
        throw last
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

        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: req) }
        catch let e as URLError {
            switch e.code {
            case .timedOut: throw EngineError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw EngineError.offline
            default: throw EngineError.api(e.localizedDescription)
            }
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
            throw EngineError.api((obj["msg"] as? String) ?? "code \(code)")
        }
        return [["title": title.isEmpty ? keyword : title,
                 "artist": singer.isEmpty ? "未知歌手" : singer,
                 "url": musicURL,
                 "cover": cover]]
    }

    // MARK: - 播放

    func play(keyword: String) async {
        var titles = [keyword]
        for item in DemoData.hot where !titles.contains(item.title) {
            titles.append(item.title)
        }
        await playQueue(titles, startAt: 0, present: true)
    }

    func playItem(_ item: [String: Any], keyword: String) async throws {
        endGuard = false
        let title = (item["title"] as? String) ?? keyword
        let artist = (item["artist"] as? String) ?? "未知歌手"
        guard let raw = item["url"] as? String, let up = URL(string: raw) else {
            throw EngineError.noUrl
        }

        configureSession()

        status = "取播放地址…"
        var playURL = up
        if let ticket = try? await APIClient.shared.playTicket(url: up.absoluteString, kind: "audio"),
           let signed = URL(string: ticket.path, relativeTo: APIClient.shared.baseURL)?.absoluteURL {
            playURL = signed
        }

        let precise = UserDefaults.standard.bool(forKey: "preciseSeek")
        let cached = PlaybackCache.shared.cachedURL(for: playURL)
        let cover = item["cover"] as? String

        // 歌词异步拉取，不阻塞播放
        lyrics = []
        lyricState = "正在找歌词…"
        Task { [weak self] in
            await self?.loadLyrics(title: title, artist: artist)
        }

        if let local = cached, AudioFX.shared.load(local) {
            usingFX = true
            player?.pause()
            player = nil
            itemObs = nil

            current = MusicTrack(title: title, artist: artist, playURL: local, cover: cover)
            duration = AudioFX.shared.duration
            progress = 0
            AudioFX.shared.play()
            isPlaying = true
            status = "正在播放（本地·音效）"
            startTick()
            if (cover ?? "").isEmpty {
                Task { await self.fillCover(title: title, artist: artist) }
            }
            return
        }

        usingFX = false
        AudioFX.shared.stop()

        let source = playURL
        let asset = AVURLAsset(url: source, options: [AVURLAssetPreferPreciseDurationAndTimingKey: precise])
        let it = AVPlayerItem(asset: asset)
        it.preferredForwardBufferDuration = precise ? 0 : 3
        let p = AVPlayer(playerItem: it)
        p.automaticallyWaitsToMinimizeStalling = !precise

        itemObs = it.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch item.status {
                case .failed:
                    self.status = "播放失败：\(item.error?.localizedDescription ?? "未知")"
                    self.isPlaying = false
                case .readyToPlay:
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    if self.status.hasPrefix("取播放") || self.status == "就绪" {
                        self.status = "正在播放"
                    }
                default: break
                }
            }
        }

        player = p
        current = MusicTrack(title: title, artist: artist, playURL: source, cover: cover)
        p.volume = volume
        p.play()
        isPlaying = true
        status = "正在播放"
        startTick()
        observeEnd(of: it)

        if cached == nil {
            PlaybackCache.shared.download(playURL)
        }
        if (cover ?? "").isEmpty {
            Task { await self.fillCover(title: title, artist: artist) }
        }
    }

    // MARK: - 歌词

    func loadLyrics(title: String, artist: String) async {
        let key = title + "|" + artist
        if let hit = lyricCache[key], !hit.isEmpty {
            lyrics = hit
            lyricState = ""
            return
        }

        let lines = await LyricService.fetch(title: title, artist: artist)
        guard current?.title == title else { return }

        lyrics = lines
        if lines.isEmpty {
            lyricState = "没找到这首歌的歌词"
        } else {
            lyricState = "歌词来自 lrclib"
            lyricCache[key] = lines
        }
    }

    func currentLyricIndex() -> Int {
        let t = currentSeconds()
        return LyricParser.currentIndex(lyrics, at: t)
    }

    func currentSeconds() -> Double {
        if usingFX { return AudioFX.shared.currentTime }
        return player?.currentTime().seconds ?? 0
    }

    func seek(toSeconds seconds: Double) {
        if usingFX {
            AudioFX.shared.seek(to: seconds)
            if duration > 0 { progress = min(1, max(0, seconds / duration)) }
            if isPlaying { AudioFX.shared.play() }
            return
        }
        guard let p = player else { return }
        let wasPlaying = isPlaying
        p.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        if duration > 0 { progress = min(1, max(0, seconds / duration)) }
        if wasPlaying { p.play(); isPlaying = true }
    }

    // MARK: - 传输

    func toggle() {
        if usingFX {
            if AudioFX.shared.isPlaying {
                AudioFX.shared.pause()
            } else {
                AudioFX.shared.play()
            }
            isPlaying = AudioFX.shared.isPlaying
            status = isPlaying ? "正在播放（本地·音效）" : "已暂停"
            return
        }

        guard let p = player else { return }
        if isPlaying { p.pause() } else { p.play() }
        isPlaying.toggle()
    }

    func seek(to ratio: Double) {
        if usingFX {
            let d = AudioFX.shared.duration
            guard d > 0 else { return }
            let target = min(1, max(0, ratio))
            AudioFX.shared.seek(to: d * target)
            progress = target
            if isPlaying { AudioFX.shared.play() }
            return
        }

        guard let p = player, let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
        let wasPlaying = isPlaying
        p.seek(to: CMTime(seconds: d * ratio, preferredTimescale: 600))
        progress = ratio
        if wasPlaying { p.play(); isPlaying = true }
    }

    func setVolume(_ v: Float) {
        let clamped = max(0, min(1, v))
        volume = clamped
        player?.volume = clamped
        AudioFX.shared.volume = clamped
    }

    func jumpTo(_ index: Int) {
        guard index >= 0, index < queue.count else { return }
        queueIndex = index
        Task { await loadQueueItem(present: false) }
    }

    func addToQueue(_ titles: [String]) {
        for t in titles where !queue.contains(t) {
            queue.append(t)
        }
        if queueIndex < 0, !queue.isEmpty { queueIndex = 0 }
    }

    private func fillCover(title: String, artist: String) async {
        guard let url = await CoverResolver.albumArt(title: title, artist: artist) else { return }
        guard current?.title == title else { return }
        if var t = current {
            t.cover = url
            current = t
        }
    }

    // MARK: - 队列 / 循环 / 随机

    func playQueue(_ titles: [String], startAt index: Int, present: Bool = true) async {
        guard !titles.isEmpty else { return }
        queue = titles
        queueIndex = max(0, min(index, titles.count - 1))
        await loadQueueItem(present: present)
    }

    func loadQueueItem(present: Bool) async {
        guard queueIndex >= 0, queueIndex < queue.count else { return }
        let kw = queue[queueIndex]
        status = "搜索中…"
        do {
            let list = try await search(kw)
            guard let first = list.first else { throw EngineError.noResult }
            try await playItem(first, keyword: kw)
            if present { PlayerPresenter.shared.present() }
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? "播放失败：\(error)"
            isPlaying = false
            if queueIndex < queue.count - 1 { nextTrack() }
        }
    }

    func nextTrack(auto: Bool = false) {
        guard !queue.isEmpty else { return }
        if auto, repeatMode == .one {
            seek(toSeconds: 0)
            if !isPlaying { toggle() }
            return
        }
        if shuffleOn, queue.count > 1 {
            var n = Int.random(in: 0..<queue.count)
            if n == queueIndex { n = (n + 1) % queue.count }
            queueIndex = n
        } else {
            queueIndex += 1
            if queueIndex >= queue.count {
                if repeatMode == .all {
                    queueIndex = 0
                } else {
                    queueIndex = queue.count - 1
                    status = "播放完毕"
                    return
                }
            }
        }
        Task { await loadQueueItem(present: false) }
    }

    func previousTrack() {
        guard !queue.isEmpty else { return }
        if currentSeconds() > 3 {
            seek(toSeconds: 0)
            return
        }
        queueIndex -= 1
        if queueIndex < 0 {
            queueIndex = repeatMode == .all ? queue.count - 1 : 0
        }
        Task { await loadQueueItem(present: false) }
    }

    func toggleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func toggleShuffle() { shuffleOn.toggle() }

    private func observeEnd(of item: AVPlayerItem) {
        if let o = endObs { NotificationCenter.default.removeObserver(o) }
        endObs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.nextTrack(auto: true)
            }
        }
    }

    private func startTick() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                if self.usingFX {
                    let t = AudioFX.shared.currentTime
                    let d = AudioFX.shared.duration
                    if d > 0 {
                        self.duration = d
                        self.progress = min(1, max(0, t / d))
                    }
                    self.isPlaying = AudioFX.shared.isPlaying
                    if d > 0, t >= d - 0.4, !self.endGuard {
                        self.endGuard = true
                        self.nextTrack(auto: true)
                    }
                    if t < d - 1 { self.endGuard = false }
                    return
                }

                guard let p = self.player else { return }
                let t = p.currentTime().seconds
                let d = p.currentItem?.duration.seconds ?? 0
                if d.isFinite, d > 0 {
                    self.duration = d
                    self.progress = min(1, max(0, t / d))
                }
                self.isPlaying = (p.rate > 0 || p.timeControlStatus == .waitingToPlayAtSpecifiedRate)
                if self.isPlaying && self.status != "正在播放" && self.status != "正在播放（本地·音效）" {
                    self.status = "正在播放"
                }
            }
        }
    }
}
