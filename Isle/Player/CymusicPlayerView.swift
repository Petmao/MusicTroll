import SwiftUI
import UIKit
import AVFoundation
import MediaPlayer

final class PlayerPresenter: ObservableObject {
    static let shared = PlayerPresenter()
    @Published var show = false
    func present() {
        if Thread.isMainThread {
            show = true
        } else {
            DispatchQueue.main.async { self.show = true }
        }
    }
}

final class SystemVolume: ObservableObject {
    static let shared = SystemVolume()

    @Published fileprivate(set) var value: Float = 0.5
    private var obs: NSKeyValueObservation?
    private weak var slider: UISlider?

    private init() {
        let session = AVAudioSession.sharedInstance()
        value = session.outputVolume
        obs = session.observe(\.outputVolume, options: [.new]) { [weak self] _, c in
            guard let v = c.newValue else { return }
            DispatchQueue.main.async { self?.value = v }
        }
    }

    fileprivate func attach(_ s: UISlider) { slider = s }

    func set(_ v: Float) {
        let clamped = max(0, min(1, v))
        value = clamped
        slider?.setValue(clamped, animated: false)
        slider?.sendActions(for: .touchUpInside)
    }
}

private struct VolumeBridge: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let v = MPVolumeView(frame: .zero)
        v.showsRouteButton = false
        v.alpha = 0.001
        return v
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        DispatchQueue.main.async {
            if let s = uiView.subviews.compactMap({ $0 as? UISlider }).first {
                SystemVolume.shared.attach(s)
            }
        }
    }
}

struct CymusicPlayerView: View {
    @ObservedObject private var engine = MusicEngine.shared
    @ObservedObject private var palette = CymusicPalette.shared
    @ObservedObject private var fav = FavoritesStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics = false
    @State private var artworkScale: CGFloat = 1
    @State private var artworkTranslateX: CGFloat = 0
    @State private var artworkCrossfade: Double = 1
    @State private var prevArtworkKey = ""
    @State private var sheetDrag: CGFloat = 0
    @State private var dragAxis: DragAxis = .undecided
    @State private var scrubbing = false
    @State private var scrubRatio: Double = 0
    @State private var lyricScale = 1
    @State private var lyricDelay: Double = 0
    @State private var showQueue = false

    private enum DragAxis { case undecided, horizontal, vertical }

    private var base: PaletteColor { palette.value(for: engine.current?.cover) }
    private var title: String { engine.current?.title ?? "未选择歌曲" }
    private var artist: String { engine.current?.artist ?? "" }
    private var compact: Bool { UIScreen.main.bounds.height < 700 }

    private var liveSeconds: Double {
        scrubbing ? scrubRatio * engine.duration : engine.progress * engine.duration
    }

    var body: some View {
        GeometryReader { geo in
            let top = geo.safeAreaInsets.top
            let bottom = geo.safeAreaInsets.bottom
            let height = geo.size.height

            ZStack(alignment: .top) {
                Color.black.opacity(0.55 * min(1, sheetDrag / max(1, height * 0.5)))
                    .ignoresSafeArea()

                base.color.ignoresSafeArea()

                if showLyrics {
                    lyricsStage(top: top, bottom: bottom)
                } else {
                    VStack(spacing: 0) {
                        artworkRegion(top: top)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        controlsPanel(bottom: bottom)
                    }
                    .ignoresSafeArea(edges: [.top, .bottom])
                }

                dismissHandle(top: top)
            }
            .offset(y: sheetDrag)
            .gesture(playerGesture(width: geo.size.width, height: height))
            .onAppear { palette.prime(engine.current?.cover) }
            .onChange(of: engine.current?.cover) { c in
                palette.prime(c)
                let key = c ?? ""
                guard key != prevArtworkKey else { return }
                prevArtworkKey = key
                artworkCrossfade = 0
                withAnimation(.easeInOut(duration: 0.42)) { artworkCrossfade = 1 }
            }
            .onChange(of: engine.isPlaying) { playing in
                if playing {
                    withAnimation(.interpolatingSpring(mass: 1,
                                                       stiffness: 180,
                                                       damping: 9,
                                                       initialVelocity: 0)) {
                        artworkScale = 1
                    }
                } else {
                    withAnimation(.linear(duration: 0.3)) { artworkScale = 0.7 }
                }
            }
        }
        .background(base.color.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .sheet(isPresented: $showQueue) { PlaylistSheet() }
    }

    private func artworkRegion(top: CGFloat) -> some View {
        ZStack {
            cover
                .frame(minWidth: 0, maxWidth: .infinity,
                       minHeight: 0, maxHeight: .infinity)

            LinearGradient(
                stops: [
                    .init(color: base.alpha(0), location: 0),
                    .init(color: base.alpha(0), location: 0.48),
                    .init(color: base.alpha(0x3d / 255.0), location: 0.68),
                    .init(color: base.alpha(0xb8 / 255.0), location: 0.86),
                    .init(color: base.alpha(1), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.6), location: 0),
                        .init(color: Color.black.opacity(0.4), location: 0.55),
                        .init(color: Color.black.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: top + 100)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)
        }
        .clipped()
        .contentShape(Rectangle())
        .scaleEffect(artworkScale)
        .offset(x: artworkTranslateX)
        .opacity(artworkCrossfade)
        .onTapGesture { toggleLyrics() }
    }

    @ViewBuilder private var cover: some View {
        if let s = engine.current?.cover, let url = URL(string: s) {
            AsyncImage(url: url,
                       transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    coverPlaceholder
                }
            }
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            base.color
            Image(systemName: "music.note")
                .font(.system(size: 46, weight: .thin))
                .foregroundStyle(Color.white.opacity(0.16))
        }
    }

    private func dismissHandle(top: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.7))
                .frame(width: 44, height: 5)
                .padding(.top, top + 8)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    private func playerGesture(width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                if dragAxis == .undecided {
                    let dx = abs(v.translation.width)
                    let dy = abs(v.translation.height)
                    guard max(dx, dy) >= 6 else { return }
                    dragAxis = dx > dy ? .horizontal : .vertical
                }
                switch dragAxis {
                case .horizontal:
                    artworkTranslateX = v.translation.width * 0.5
                case .vertical:
                    sheetDrag = max(0, v.translation.height)
                case .undecided:
                    break
                }
            }
            .onEnded { v in
                let axis = dragAxis
                dragAxis = .undecided

                if axis == .horizontal {
                    if v.translation.width < -width * 0.25 {
                        artworkTranslateX = -width * 0.3
                        artworkCrossfade = 0
                        skipNext()
                    } else if v.translation.width > width * 0.25 {
                        artworkTranslateX = width * 0.3
                        artworkCrossfade = 0
                        skipPrevious()
                    }
                    withAnimation(.interpolatingSpring(mass: 1,
                                                       stiffness: 150,
                                                       damping: 15,
                                                       initialVelocity: 0)) {
                        artworkTranslateX = 0
                    }
                    withAnimation(.easeInOut(duration: 0.42)) { artworkCrossfade = 1 }
                    return
                }

                guard axis == .vertical else { return }

                let dy = v.translation.height
                let predicted = v.predictedEndTranslation.height - dy
                if dy > height * 0.25 || predicted > 800 {
                    withAnimation(.easeIn(duration: 0.4)) { sheetDrag = height }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dismiss() }
                } else {
                    withAnimation(.interpolatingSpring(mass: 1,
                                                       stiffness: 180,
                                                       damping: 20,
                                                       initialVelocity: 0)) {
                        sheetDrag = 0
                    }
                }
            }
    }

    private func skipNext() { engine.nextTrack() }
    private func skipPrevious() { engine.previousTrack() }

    private func controlsPanel(bottom: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 0) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 16)
                    HStack(spacing: 8) {
                        likeButton
                        songMenu
                    }
                }
                if !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 60, alignment: .topLeading)
            .padding(.top, 6)

            progressBlock.padding(.top, compact ? 18 : 24)
            transportBlock.padding(.top, compact ? 20 : 28)
            volumeBlock
                .padding(.top, compact ? 24 : 40)
                .padding(.bottom, compact ? 18 : 28)
            footerBlock
        }
        .padding(.horizontal, 24)
        .padding(.bottom, max(bottom, 16))
    }

    private var likeButton: some View {
        let t = engine.current?.title ?? ""
        let a = engine.current?.artist ?? ""
        let liked = fav.contains(t, a)
        return Button {
            guard !t.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                _ = fav.toggle(title: t, artist: a)
            }
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(liked ? Color(red: 1, green: 0.373, blue: 0.620)
                                       : Color.white.opacity(0.72))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(liked ? 0.15 : 0.10))
                .clipShape(Circle())
                .scaleEffect(liked ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var songMenu: some View {
        Menu {
            Button {
                if let t = engine.current?.title, let a = engine.current?.artist {
                    FavoritesStore.shared.toggle(title: t, artist: a)
                }
            } label: { Label("喜欢 / 取消喜欢", systemImage: "heart") }
            Button { toggleLyrics() } label: { Label("歌词", systemImage: "text.quote") }
            Button { engine.toggleShuffle() } label: {
                Label(engine.shuffleOn ? "关闭随机播放" : "随机播放", systemImage: "shuffle")
            }
            Button { showQueue = true } label: { Label("播放列表", systemImage: "list.bullet") }
            if #available(iOS 16.0, *) {
                if let t = engine.current?.title {
                    ShareLink(item: "\(t) - \(artist)") {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                }
            } else {
                Button {
                    if let t = engine.current?.title {
                        UIPasteboard.general.string = "\(t) - \(artist)"
                    }
                } label: {
                    Label("复制歌曲信息", systemImage: "doc.on.doc")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private var progressBlock: some View {
        VStack(spacing: 0) {
            CymusicSlider(
                value: scrubbing ? scrubRatio : engine.progress,
                onScrub: { r in scrubbing = true; scrubRatio = r },
                onCommit: { r in engine.seek(to: r); scrubbing = false }
            )
            HStack(alignment: .firstTextBaseline) {
                Text(timeText(liveSeconds)).kerning(0.7)
                Spacer(minLength: 0)
                Text("- " + timeText(max(0, engine.duration - liveSeconds))).kerning(0.7)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.75))
            .padding(.top, 20)
        }
    }

    private var transportBlock: some View {
        HStack(spacing: 0) {
            Button(action: skipPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity)

            Button { engine.toggle() } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white)
                    .frame(width: 48, height: 48)
            }
            .frame(maxWidth: .infinity)

            Button(action: skipNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var volumeBlock: some View {
        HStack(spacing: 0) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 20)
            CymusicSlider(value: Double(engine.volume),
                          onScrub: { engine.setVolume(Float($0)) },
                          onCommit: { engine.setVolume(Float($0)) })
                .padding(.horizontal, 10)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 20)
        }
    }

    private var footerBlock: some View {
        HStack(spacing: 0) {
            Button { toggleLyrics() } label: {
                Image(systemName: showLyrics ? "chevron.down.circle" : "text.bubble")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { engine.toggleRepeat() } label: {
                Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 26))
                    .foregroundStyle(engine.repeatMode == .off ? Color.white.opacity(0.45) : Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Button { showQueue = true } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func lyricsStage(top: CGFloat, bottom: CGFloat) -> some View {
        VStack(spacing: 0) {
            CymusicLyricsView(
                lines: engine.lyrics,
                currentIndex: engine.currentLyricIndex(),
                activeOffset: lyricDelay,
                scale: lyricScale,
                onSeek: { engine.seek(toSeconds: $0) }
            )

            HStack(spacing: 0) {
                lyricTool("chevron.down.circle", size: 24, active: false) { toggleLyrics() }
                lyricTool("textformat.size.smaller", size: 26, active: lyricScale > 0) {
                    lyricScale = max(0, lyricScale - 1)
                }
                lyricTool("textformat.size.larger", size: 26, active: lyricScale < 3) {
                    lyricScale = min(3, lyricScale + 1)
                }
                lyricTool("timer", size: 23, active: lyricDelay != 0) { stepDelay() }
            }
            .padding(.top, 10)
        }
        .padding(.top, top + 40)
        .padding(.horizontal, 24)
        .padding(.bottom, max(bottom, 16))
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }

    private func lyricTool(_ symbol: String,
                           size: CGFloat,
                           active: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.55))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func stepDelay() {
        lyricDelay += 0.5
        if lyricDelay > 15 { lyricDelay = -15 }
    }

    private func toggleLyrics() {
        withAnimation(.easeInOut(duration: 0.3)) { showLyrics.toggle() }
    }

    private func timeText(_ s: Double) -> String {
        guard s.isFinite, s > 0 else { return "00:00" }
        let t = Int(s)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
}

struct CymusicSlider: View {
    var value: Double
    var trackHeight: CGFloat = 8
    var onScrub: (Double) -> Void
    var onCommit: (Double) -> Void

    @State private var dragging = false
    @State private var local: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let ratio = max(0, min(1, dragging ? local : value))
            let knob: CGFloat = dragging ? 24 : 12

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: w, height: trackHeight)
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: w * ratio, height: trackHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .offset(x: max(0, w * ratio - knob / 2))
            }
            .frame(width: w, height: 24, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        dragging = true
                        local = max(0, min(1, v.location.x / w))
                        onScrub(local)
                    }
                    .onEnded { v in
                        let r = max(0, min(1, v.location.x / w))
                        local = r
                        dragging = false
                        onCommit(r)
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragging)
        }
        .frame(height: 24)
    }
}

struct CymusicLyricsView: View {
    let lines: [LyricLine]
    let currentIndex: Int
    let activeOffset: Double
    let scale: Int
    let onSeek: (Double) -> Void

    private var baseSize: CGFloat { 15 + CGFloat(scale) * 2 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 17) {
                    if lines.isEmpty {
                        Text("暂时没有歌词")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.32))
                            .padding(.vertical, 40)
                    } else {
                        ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                            Text(line.text)
                                .font(.system(size: i == currentIndex ? baseSize + 4 : baseSize,
                                              weight: i == currentIndex ? .bold : .regular))
                                .foregroundStyle(i == currentIndex
                                                 ? Color.white
                                                 : Color.white.opacity(0.32))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .id(line.id)
                                .onTapGesture { onSeek(max(0, line.time + activeOffset)) }
                        }
                    }
                }
                .padding(.vertical, 44)
            }
            .onChange(of: currentIndex) { idx in
                guard idx >= 0, idx < lines.count else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(lines[idx].id, anchor: .center)
                }
            }
        }
    }
}

struct PlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = MusicEngine.shared
    @ObservedObject private var fav = FavoritesStore.shared

    var body: some View {
        NavigationView {
            ZStack {
                IsleBackground()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button {
                            engine.addToQueue(fav.items.map { $0.title })
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                Text("添加收藏").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(IsleColor.pink.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            engine.queue = []
                            engine.queueIndex = -1
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trash").font(.system(size: 11))
                                Text("清空").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color.white.opacity(0.72))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(IsleColor.surface)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("\(engine.queue.count) 首")
                            .font(.system(size: 11))
                            .foregroundStyle(IsleColor.textSub)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            if engine.queue.isEmpty {
                                Text("队列是空的，从首页或搜索结果点一首开始")
                                    .font(.system(size: 12))
                                    .foregroundStyle(IsleColor.textSub)
                                    .padding(.top, 44)
                            } else {
                                ForEach(Array(engine.queue.enumerated()), id: \.offset) { i, t in
                                    row(i, t)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ i: Int, _ t: String) -> some View {
        let on = i == engine.queueIndex
        return Button {
            engine.jumpTo(i)
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", i + 1))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(on ? Color(red: 1, green: 0.561, blue: 0.749)
                                        : Color.white.opacity(0.3))
                    .frame(width: 22)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(on ? IsleColor.pink.opacity(0.85) : Color.white.opacity(0.08))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: on ? "waveform" : "music.note")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.85))
                    )

                Text(t)
                    .font(.system(size: 13.5, weight: on ? .semibold : .regular))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(IsleColor.surface)
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(on ? IsleColor.pink.opacity(0.35) : Color.clear, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
