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


p = 'Isle/Sources/AudioFX.swift'
s = load(p)

s = sub(s, """    var playbackRate: Float {""",
    """    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = max(0, min(1, newValue)) }
    }

    var playbackRate: Float {""", 'fx 主音量')

save(p, s)
print('AudioFX done')

p = 'Isle/Sources/MusicEngine.swift'
s = load(p)

s = sub(s, """    @Published var shuffleOn = false""",
    """    @Published var shuffleOn = false
    @Published var volume: Float = 1.0""", 'engine 音量字段')

s = sub(s, """    func play(keyword: String) async {
        await playQueue([keyword], startAt: 0, present: true)
    }""",
    """    func play(keyword: String) async {
        var titles = [keyword]
        for item in DemoData.hot where !titles.contains(item.title) {
            titles.append(item.title)
        }
        await playQueue(titles, startAt: 0, present: true)
    }""", 'engine 单曲补队列')

s = sub(s, """    func seek(toSeconds seconds: Double) {
        if usingFX {
            AudioFX.shared.seek(to: seconds)
            if duration > 0 { progress = min(1, max(0, seconds / duration)) }
            return
        }
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        if duration > 0 { progress = min(1, max(0, seconds / duration)) }
    }""",
    """    func seek(toSeconds seconds: Double) {
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
    }""", 'engine seek 秒保持播放')

s = sub(s, """        guard let p = player, let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
        p.seek(to: CMTime(seconds: d * ratio, preferredTimescale: 600))
        progress = ratio
    }""",
    """        guard let p = player, let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 else { return }
        let wasPlaying = isPlaying
        p.seek(to: CMTime(seconds: d * ratio, preferredTimescale: 600))
        progress = ratio
        if wasPlaying { p.play(); isPlaying = true }
    }""", 'engine seek 比例保持播放')

s = sub(s, """            let target = min(1, max(0, ratio))
            AudioFX.shared.seek(to: d * target)
            progress = target
            return""",
    """            let target = min(1, max(0, ratio))
            AudioFX.shared.seek(to: d * target)
            progress = target
            if isPlaying { AudioFX.shared.play() }
            return""", 'engine 本地 seek 保持播放')

s = sub(s, """                self.isPlaying = (p.timeControlStatus == .playing)""",
    """                self.isPlaying = (p.rate > 0 || p.timeControlStatus == .waitingToPlayAtSpecifiedRate)""", 'engine 播放态判定')

s = sub(s, """            status = "正在播放（本地·音效）"
            startTick()
            return""",
    """            status = "正在播放（本地·音效）"
            startTick()
            if (cover ?? "").isEmpty {
                Task { await self.fillCover(title: title, artist: artist) }
            }
            return""", 'engine 本地分支取封面')

s = sub(s, """        if cached == nil {
            PlaybackCache.shared.download(playURL)
        }
    }""",
    """        if cached == nil {
            PlaybackCache.shared.download(playURL)
        }
        if (cover ?? "").isEmpty {
            Task { await self.fillCover(title: title, artist: artist) }
        }
    }""", 'engine 远程分支取封面')

s = sub(s, '''        p.play()
        isPlaying = true
        status = "正在播放"''',
    '''        p.volume = volume
        p.play()
        isPlaying = true
        status = "正在播放"''', 'engine 应用音量')

s = sub(s, """    // MARK: - 队列 / 循环 / 随机""",
    """    func setVolume(_ v: Float) {
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

    // MARK: - 队列 / 循环 / 随机""", 'engine 音量与队列操作')

save(p, s)
print('MusicEngine done')
