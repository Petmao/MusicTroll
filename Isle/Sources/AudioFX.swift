import Foundation
import AVFoundation

/// 本地文件播放的音效链：player → 十段 EQ → 变速变调 → mixer。
/// 只处理已经落盘的本地文件；远程流仍走 AVPlayer。
final class AudioFX {
    static let shared = AudioFX()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 10)
    private let pitch = AVAudioUnitTimePitch()

    private var wired = false
    private var file: AVAudioFile?

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
        guard !wired else { return }
        engine.attach(player)
        engine.attach(eq)
        engine.attach(pitch)
        engine.connect(player, to: eq, format: format)
        engine.connect(eq, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)
        wired = true
    }

    // MARK: - 加载与播放

    func load(_ url: URL) -> Bool {
        guard let f = try? AVAudioFile(forReading: url) else { return false }
        if let old = file, wired {
            player.stop()
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: eq, format: f.processingFormat)
            _ = old
        }
        file = f
        wire(format: f.processingFormat)

        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        player.stop()
        player.scheduleFile(f, at: nil, completionHandler: nil)
        return true
    }

    func play() {
        guard file != nil else { return }
        if !engine.isRunning { try? engine.start() }
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.stop()
        file = nil
    }

    var isPlaying: Bool { player.isPlaying }

    // MARK: - 音效

    func setGain(_ gain: Float, band index: Int) {
        guard index >= 0, index < eq.bands.count else { return }
        eq.bands[index].gain = max(-24, min(24, gain))
    }

    func setBypass(_ bypass: Bool) {
        eq.bypass = bypass
    }

    func setFlat() {
        for band in eq.bands { band.gain = 0 }
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
