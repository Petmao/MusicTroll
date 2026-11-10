import AVFoundation
import MediaPlayer
import Combine

final class Player: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var tracks: [URL] = []
    @Published var current: URL?
    @Published var isPlaying = false
    private var ap: AVAudioPlayer?

    override init() {
        super.init()
        reload()
        setupRemote()
    }

    func reload() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exts: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "opus", "alac"]
        let all = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        tracks = all.filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func play(_ url: URL) {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [])
        try? s.setActive(true)
        ap = try? AVAudioPlayer(contentsOf: url)
        ap?.delegate = self
        ap?.play()
        current = url
        isPlaying = ap?.isPlaying ?? false
        nowPlaying()
    }

    func toggle() {
        guard let ap = ap else { return }
        if ap.isPlaying { ap.pause() } else { ap.play() }
        isPlaying = ap.isPlaying
        nowPlaying()
    }

    func stop() {
        ap?.stop()
        isPlaying = false
        nowPlaying()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        if let c = current, let i = tracks.firstIndex(of: c), i + 1 < tracks.count {
            play(tracks[i + 1])
        }
    }

    private func nowPlaying() {
        var info: [String: Any] = [:]
        if let c = current {
            info[MPMediaItemPropertyTitle] = c.deletingPathExtension().lastPathComponent
            info[MPMediaItemPropertyArtist] = "MusicTroll"
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPMediaItemPropertyPlaybackDuration] = ap?.duration ?? 0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = ap?.currentTime ?? 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemote() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in
            self?.ap?.play()
            self?.isPlaying = true
            self?.nowPlaying()
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.ap?.pause()
            self?.isPlaying = false
            self?.nowPlaying()
            return .success
        }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggle()
            return .success
        }
        cc.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self, let c = self.current,
                  let i = self.tracks.firstIndex(of: c), i + 1 < self.tracks.count else {
                return .noSuchContent
            }
            self.play(self.tracks[i + 1])
            return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self, let c = self.current,
                  let i = self.tracks.firstIndex(of: c), i > 0 else {
                return .noSuchContent
            }
            self.play(self.tracks[i - 1])
            return .success
        }
    }
}
