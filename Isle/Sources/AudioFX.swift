import Foundation
import AVFoundation

/// 本地文件的音效链：player → 十段 EQ → 变速变调 → mixer。
/// 远程流仍由 AVPlayer 负责；只有已落盘的文件走这里。
final class AudioFX {
    static let shared = AudioFX()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 10)
    private let pitch = AVAudioUnitTimePitch()

    private var wired = false
    private var file: AVAudioFile?
    private var wiredFormat: AVAudioFormat?

    private var offsetSeconds: Double = 0
    private var startedAt: Date?

    private init() {
        setupBands()
    }

    // MARK: - 配置

    private func setupBands() {
        let freqs: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for (i, band) in eq.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = i < freqs.count ? freqs[i] : 1000
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }
    }

    private func wire(format: AVAudioFormat) {
        if !wired {
            engine.attach(player)
            engine.attach(eq)
            engine.attach(pitch)
            engine.connect(player, to: eq, format: format)
            engine.connect(eq, to: pitch, format: format)
            engine.connect(pitch, to: engine.mainMixerNode, format: format)
            wired = true
            wiredFormat = format
            return
        }

        // 采样率/声道数变化时重建连接
        if let old = wiredFormat,
           old.sampleRate != format.sampleRate || old.channelCount != format.channelCount {
            player.stop()
            engine.disconnectNodeOutput(player)
            engine.disconnectNodeOutput(eq)
            engine.disconnectNodeOutput(pitch)
            engine.connect(player, to: eq, format: format)
            engine.connect(eq, to: pitch, format: format)
            engine.connect(pitch, to: engine.mainMixerNode, format: format)
            wiredFormat = format
        }
    }

    // MARK: - 加载

    func load(_ url: URL) -> Bool {
        guard let f = try? AVAudioFile(forReading: url) else { return false }
        file = f
        wire(format: f.processingFormat)

        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }

        player.stop()
        offsetSeconds = 0
        startedAt = nil
        player.scheduleFile(f, at: nil, completionHandler: nil)
        return true
    }

    // MARK: - 传输控制

    func play() {
        guard file != nil else { return }
        if !engine.isRunning { try? engine.start() }
        player.play()
        startedAt = Date()
    }

    func pause() {
        if let s = startedAt {
            offsetSeconds += Date().timeIntervalSince(s) * Double(playbackRate)
            startedAt = nil
        }
        player.pause()
    }

    func stop() {
        player.stop()
        file = nil
        offsetSeconds = 0
        startedAt = nil
    }

    var isPlaying: Bool { player.isPlaying }

    var duration: Double {
        guard let f = file else { return 0 }
        let sr = f.processingFormat.sampleRate
        guard sr > 0 else { return 0 }
        return Double(f.length) / sr
    }

    var currentTime: Double {
        guard let s = startedAt else { return offsetSeconds }
        let value = offsetSeconds + Date().timeIntervalSince(s) * Double(playbackRate)
        return min(duration, max(0, value))
    }

    func seek(to seconds: Double) {
        guard let f = file else { return }
        let sr = f.processingFormat.sampleRate
        guard sr > 0 else { return }

        let clamped = min(duration, max(0, seconds))
        let frame = AVAudioFramePosition(clamped * sr)
        let remaining = f.length - frame

        player.stop()
        if remaining > 0 {
            player.scheduleSegment(f, startingFrame: frame,
                                   frameCount: AVAudioFrameCount(remaining),
                                   at: nil, completionHandler: nil)
        }
        offsetSeconds = clamped
        startedAt = player.isPlaying ? Date() : nil
    }

    // MARK: - 音效

    func setGain(_ gain: Float, band index: Int) {
        guard index >= 0, index < eq.bands.count else { return }
        eq.bands[index].gain = max(-24, min(24, gain))
    }

    func gain(band index: Int) -> Float {
        guard index >= 0, index < eq.bands.count else { return 0 }
        return eq.bands[index].gain
    }

    func setBypass(_ bypass: Bool) {
        eq.bypass = bypass
    }

    func setFlat() {
        for band in eq.bands { band.gain = 0 }
    }

    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = max(0, min(1, newValue)) }
    }

    var playbackRate: Float {
        get { pitch.rate }
        set { pitch.rate = min(2.0, max(0.5, newValue)) }
    }

    var pitchCents: Float {
        get { pitch.pitch }
        set { pitch.pitch = min(1200, max(-1200, newValue)) }
    }

    deinit {
        player.stop()
        engine.stop()
    }
}
