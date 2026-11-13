import SwiftUI

struct PlayerView: View {
    var onClose: () -> Void = {}

    @ObservedObject private var engine = MusicEngine.shared
    @State private var angle: Double = 0
    @State private var showLyric = false
    @State private var showQueue = false
    @State private var likes = 0
    @State private var comments = 0
    @State private var dragStart: Date?

    private var title: String { engine.current?.title ?? "未选择歌曲" }
    private var artist: String { engine.current?.artist ?? "去搜索或点一首歌" }
    private var liked: Bool {
        FavoritesStore.shared.contains(engine.current?.title ?? "", engine.current?.artist ?? "")
    }

    var body: some View {
        ZStack {
            PlayerBackground()
            GeometryReader { geo in
                let discSize = min(302, geo.size.width - 58)
                VStack(spacing: 0) {
                    topBar

                    if showLyric {
                        lyricStage(discSize)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        defaultStage(discSize)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 0)

                    PlayerProgressView(
                        progress: engine.progress,
                        buffer: bufferRatio,
                        elapsed: timeText(engine.progress * engine.duration),
                        total: timeText(engine.duration),
                        quality: "极高音质",
                        onScrub: { engine.seek(to: $0) }
                    )
                    .padding(.bottom, 14)

                    PlayerControlsView(
                        isPlaying: engine.isPlaying,
                        onShuffle: { showQueue = true },
                        onPrev: { engine.seek(to: max(0, engine.progress - 0.05)) },
                        onPlayPause: {
                            engine.toggle()
                            if engine.isPlaying { startSpin() }
                        },
                        onNext: { engine.seek(to: min(1, engine.progress + 0.05)) },
                        onQueue: { showQueue = true }
                    )

                    homeBar
                        .padding(.top, showLyric ? 12 : 18)
                }
                .padding(.top, 42)
            }
        }
        .sheet(isPresented: $showQueue) { PlaylistSheet() }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { v in
                    if v.translation.height > 70, showLyric {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                            showLyric = false
                        }
                    }
                }
        )
        .onChange(of: engine.isPlaying) { playing in
            if playing { startSpin() }
        }
        .onAppear { if engine.isPlaying { startSpin() } }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            Button {
                if showLyric {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                        showLyric = false
                    }
                } else {
                    onClose()
                }
            } label: {
                IsleIcon(IsleSymbol.collapse, scale: .md, tint: PlayerTheme.faint)
                    .frame(width: 40, height: 45)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("搜索")
                .font(.system(size: 14, weight: .semibold))
                .tracking(1)
                .foregroundStyle(PlayerTheme.faint)

            Spacer()

            Button { } label: {
                IsleIcon(IsleSymbol.share, scale: .md, tint: PlayerTheme.faint)
                    .frame(width: 40, height: 45)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 45)
    }

    // MARK: - 默认态

    private func defaultStage(_ size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VinylDiscView(angle: angle, title: title, size: size)
                TonearmView(lifted: !engine.isPlaying)
                    .offset(x: 6, y: -14)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(PlayerTheme.textHi)
                            .lineLimit(1)
                        Text("VIP")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PlayerTheme.badgeText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(PlayerTheme.badgeBg)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    Text(artist)
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(PlayerTheme.textMid)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                PlayerSocialView(
                    likes: likes,
                    comments: comments,
                    liked: liked,
                    onLike: { toggleLike() },
                    onComment: { }
                )
            }
            .padding(.horizontal, 23)
            .padding(.top, 18)
        }
    }

    // MARK: - 歌词态

    private func lyricStage(_ size: CGFloat) -> some View {
        VStack(spacing: 0) {
            VinylDiscView(angle: angle, title: title, size: size * 0.46)
                .padding(.top, 4)

            LyricStageView(
                lines: engine.lyrics,
                currentIndex: engine.currentLyricIndex(),
                artist: artist,
                stateText: engine.lyricState,
                liked: liked,
                onSeek: { engine.seek(toSeconds: $0) },
                onMore: { showQueue = true },
                onLike: { toggleLike() },
                onCollapse: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                        showLyric = false
                    }
                }
            )
        }
    }

    // MARK: - 其余

    private var homeBar: some View {
        Capsule()
            .fill(PlayerTheme.homeBar)
            .frame(width: 126, height: 3)
            .padding(.bottom, 7)
    }

    private var bufferRatio: Double {
        min(1, max(engine.progress, 0.26))
    }

    private func timeText(_ s: Double) -> String {
        guard s.isFinite, s > 0 else { return "00:00" }
        let t = Int(s)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    private func toggleLike() {
        if let t = engine.current?.title, let a = engine.current?.artist {
            FavoritesStore.shared.toggle(title: t, artist: a)
            likes = liked ? max(0, likes - 1) : likes + 1
        }
    }

    private func startSpin() {
        angle = 0
        withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }
}

struct PlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = MusicEngine.shared
    private let list = DemoData.hot

    var body: some View {
        NavigationView {
            ZStack {
                PlayerBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(list) { s in
                            Button {
                                dismiss()
                                Task { await engine.play(keyword: s.title) }
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(IsleColor.accent)
                                        .frame(width: 42, height: 42)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(s.title).font(.system(size: 14, weight: .semibold))
                                            .lineLimit(1)
                                        Text(s.artist).font(.system(size: 11))
                                            .foregroundStyle(PlayerTheme.textMid).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if engine.current?.title == s.title {
                                        IsleIcon(IsleSymbol.music, scale: .md, tint: PlayerTheme.coverWarm)
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
