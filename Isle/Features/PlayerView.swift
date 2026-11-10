import SwiftUI

struct PlayerView: View {
    @StateObject private var engine = MusicEngine.shared
    @State private var angle: Double = 0
    @State private var showLyrics = false
    @State private var showList = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let disc = min(geo.size.width - 60, 300)
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    discView(disc)
                    Spacer(minLength: 0)
                    infoRow
                    lyricEntry.padding(.top, 14)
                    progressBlock.padding(.top, 16)
                    controls.padding(.top, 20)
                    homeBar.padding(.top, 18)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $showLyrics) { LyricsView() }
        .sheet(isPresented: $showList) { PlaylistSheet() }
        .onReceive(engine.$isPlaying) { playing in
            if playing { startSpin() } else { withAnimation(.linear(duration: 0.4)) { } }
        }
    }

    private var topBar: some View {
        HStack {
            Button { } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(white: 0.62))
            }
            Spacer()
            Text("正在播放").font(.system(size: 11)).tracking(2).foregroundColor(Color(white: 0.55))
            Spacer()
            Button { showList = true } label: {
                Image(systemName: "list.bullet").font(.system(size: 17)).foregroundColor(Color(white: 0.62))
            }
        }
        .frame(height: 44)
    }

    private func discView(_ size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(AngularGradient(gradient: Gradient(colors: [.clear,
                                                                   Color(red: 1, green: 0.48, blue: 0.24),
                                                                   Color(red: 1, green: 0.18, blue: 0.47),
                                                                   Color(red: 0.48, green: 0.36, blue: 1),
                                                                   .clear]),
                                        center: .center),
                        lineWidth: 5)
                .frame(width: size, height: size)
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.11),
                                              Color(red: 0.03, green: 0.03, blue: 0.05)],
                                     center: .center, startRadius: size * 0.15, endRadius: size * 0.5))
                .frame(width: size - 12, height: size - 12)
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.60, blue: 0.39),
                                              Color(red: 0.76, green: 0.25, blue: 0.48),
                                              Color(red: 0.23, green: 0.11, blue: 0.32)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.40, height: size * 0.40)
                .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 8))
                .overlay(Image(systemName: "music.note")
                            .font(.system(size: size * 0.12))
                            .foregroundColor(.white.opacity(0.75)))
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
    }

    private var infoRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(engine.currentSong?.name ?? "未在播放")
                    .font(.system(size: 20, weight: .heavy))
                    .lineLimit(1)
                Text(engine.currentSong?.singer ?? "去搜索或点一首歌")
                    .font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
            }
            Spacer(minLength: 12)
            HStack(spacing: 16) {
                Button { engine.toggleFav() } label: {
                    Image(systemName: engine.isFav ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundColor(engine.isFav ? Color(red: 1, green: 0.37, blue: 0.62) : .white.opacity(0.85))
                }
                Button { engine.downloadCurrent() } label: {
                    Image(systemName: "arrow.down.to.line").font(.system(size: 17)).foregroundColor(.white.opacity(0.85))
                }
            }
        }
    }

    private var lyricEntry: some View {
        Button { showLyrics = true } label: {
            VStack(spacing: 3) {
                Text(engine.currentLyricLine.isEmpty ? "暂无歌词" : engine.currentLyricLine)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Text("点这里看全部歌词").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var progressBlock: some View {
        VStack(spacing: 7) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 3)
                    Capsule().fill(Color.white)
                        .frame(width: max(0, g.size.width * engine.progress), height: 3)
                    Circle().fill(Color.white).frame(width: 11, height: 11)
                        .offset(x: max(0, g.size.width * engine.progress - 5.5))
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    dragging = true
                    engine.seek(to: min(1, max(0, v.location.x / g.size.width)))
                }.onEnded { _ in dragging = false })
            }
            .frame(height: 14)

            HStack {
                Text(engine.timeText(engine.position)).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55))
                Spacer()
                Text(engine.timeText(engine.duration)).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55))
            }
        }
    }

    private var controls: some View {
        HStack {
            Button { engine.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 17))
                    .foregroundColor(engine.shuffle ? Color(red: 1, green: 0.37, blue: 0.62) : .white.opacity(0.6))
            }
            Spacer()
            Button { engine.prev() } label: {
                Image(systemName: "backward.fill").font(.system(size: 21)).foregroundColor(.white)
            }
            Spacer()
            Button { engine.toggle() } label: {
                ZStack {
                    Circle().fill(Color.white).frame(width: 64, height: 64)
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22)).foregroundColor(.black)
                        .offset(x: engine.isPlaying ? 0 : 2)
                }
            }
            Spacer()
            Button { engine.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 21)).foregroundColor(.white)
            }
            Spacer()
            Button { showList = true } label: {
                Image(systemName: "list.bullet").font(.system(size: 17)).foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var homeBar: some View {
        Capsule().fill(Color.white.opacity(0.22))
            .frame(width: 120, height: 4)
            .padding(.bottom, 2)
    }

    private func startSpin() {
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }
}

struct PlaylistSheet: View {
    @StateObject private var engine = MusicEngine.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(engine.queue) { s in
                    Button { engine.play(song: s) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).font(.system(size: 14, weight: .semibold))
                                Text(s.singer).font(.system(size: 11)).foregroundColor(.gray)
                            }
                            Spacer()
                            if engine.currentSong?.id == s.id {
                                Image(systemName: "waveform").foregroundColor(Color(red: 1, green: 0.37, blue: 0.62))
                            }
                        }
                    }
                }
            }
            .navigationTitle("播放队列")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
