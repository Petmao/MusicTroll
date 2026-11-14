#!/usr/bin/env python3
import io
import sys


def load(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()


def save(p, s):
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def sub(s, old, new, label):
    if old not in s:
        if new and new in s:
            print('SKIP ' + label)
            return s
        print('MISS ' + label)
        sys.exit(1)
    print('OK   ' + label)
    return s.replace(old, new, 1)


# ---------------- MusicEngine ----------------
p = 'Isle/Sources/MusicEngine.swift'
s = load(p)

s = sub(s, """    @Published var lyrics: [LyricLine] = []
    @Published var lyricState: String = ""

    private var player: AVPlayer?""", """    @Published var lyrics: [LyricLine] = []
    @Published var lyricState: String = ""

    enum RepeatMode: String { case off, all, one }

    @Published var queue: [String] = []
    @Published var queueIndex: Int = -1
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleOn = false

    private var endObs: NSObjectProtocol?
    private var endGuard = false

    private var player: AVPlayer?""", 'engine 队列字段')

s = sub(s, """    func play(keyword: String) async {
        status = "搜索中…"
        do {
            let list = try await search(keyword)
            guard let first = list.first else { throw EngineError.noResult }
            try await playItem(first, keyword: keyword)
            PlayerPresenter.shared.present()
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? "播放失败：\\(error)"
            isPlaying = false
        }
    }""", """    func play(keyword: String) async {
        await playQueue([keyword], startAt: 0, present: true)
    }""", 'engine play 转队列')

s = sub(s, """    func playItem(_ item: [String: Any], keyword: String) async throws {
        let title = (item["title"] as? String) ?? keyword""", """    func playItem(_ item: [String: Any], keyword: String) async throws {
        endGuard = false
        let title = (item["title"] as? String) ?? keyword""", 'engine playItem 复位')

s = sub(s, """        p.play()
        isPlaying = true
        status = "正在播放"
        startTick()

        if cached == nil {""", """        p.play()
        isPlaying = true
        status = "正在播放"
        startTick()
        observeEnd(of: it)

        if cached == nil {""", 'engine 结束监听')

s = sub(s, """                if self.usingFX {
                    let t = AudioFX.shared.currentTime
                    let d = AudioFX.shared.duration
                    if d > 0 {
                        self.duration = d
                        self.progress = min(1, max(0, t / d))
                    }
                    self.isPlaying = AudioFX.shared.isPlaying
                    return
                }""", """                if self.usingFX {
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
                }""", 'engine 本地结束兜底')

s = sub(s, """    private func startTick() {""", """    // MARK: - 队列 / 循环 / 随机

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
            status = (error as? LocalizedError)?.errorDescription ?? "播放失败：\\(error)"
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

    private func startTick() {""", 'engine 队列方法')

save(p, s)
print('MusicEngine done')
