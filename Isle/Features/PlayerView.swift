import SwiftUI

struct PlayerView: View {
    @ObservedObject private var engine = MusicEngine.shared
    @State private var angle: Double = 0
    @State private var showLyrics = false
    @State private var showList = false
    @State private var dragRatio: Double?

    private var ratio: Double { dragRatio ?? engine.progress }

    var body: some View {
        GeometryReader { geo in
            let disc = min(geo.size.width - 60, 300)
            ZStack {
                MineTheme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                    discView(disc)
                    Spacer(minLength: 0)
                    infoRow
                    statusLine.padding(.top, 8)
                    lyricEntry.padding(.top, 10)
                    progressBlock.padding(.top, 14)
                    controls.padding(.top, 18)
                    homeBar.padding(.top, 16)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $showLyrics) { PlayerLyricSheet() }
        .sheet(isPresented: $showList) { PlaylistSheet() }
        .onChange(of: engine.isPlaying) { playing in
            if playing { startSpin() }
        }
        .onAppear { if engine.isPlaying { startSpin() } }
    }

    private var topBar: some View {
        HStack {
            Image(systemName: "chevron.down")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(white: 0.62))
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
                .fill(Color(red: 0.06, green: 0.06, blue: 0.09))
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
                Text(engine.current?.title ?? "未选择歌曲")
                    .font(.system(size: 20, weight: .heavy)).lineLimit(1)
                Text(engine.current?.artist ?? "去搜索或点一首歌")
                    .font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
            }
            Spacer(minLength: 12)
            HStack(spacing: 16) {
                Button {
                    if let t = engine.current?.title, let a = engine.current?.artist {
                        FavoritesStore.shared.toggle(title: t, artist: a)
                    }
                } label: {
                    let liked = FavoritesStore.shared.contains(engine.current?.title ?? "",
                                                               engine.current?.artist ?? "")
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundColor(liked ? MineTheme.pink : .white.opacity(0.85))
                }
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 17)).foregroundColor(.white.opacity(0.85))
            }
        }
    }

    private var statusLine: some View {
        HStack {
            Text(engine.status)
                .font(.system(size: 10)).foregroundColor(.white.opacity(0.4)).lineLimit(1)
            Spacer()
        }
    }

    private var lyricEntry: some View {
        Button { showLyrics = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble").font(.system(size: 12))
                Text("点这里看全部歌词").font(.system(size: 13, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var progressBlock: some View {
        VStack(spacing: 7) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 3)
                    Capsule().fill(MineTheme.pink).frame(width: max(0, g.size.width * ratio), height: 3)
                    Circle().fill(Color.white).frame(width: 11, height: 11)
                        .offset(x: max(0, g.size.width * ratio - 5.5))
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            dragRatio = min(1, max(0, v.location.x / max(1, g.size.width)))
                        }
                        .onEnded { v in
                            let r = min(1, max(0, v.location.x / max(1, g.size.width)))
                            dragRatio = nil
                            engine.seek(to: r)
                        }
                )
            }
            .frame(height: 16)
            HStack {
                Text("\(Int(ratio * 100))%").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55))
                Spacer()
                Text(engine.isPlaying ? "播放中" : "已暂停")
                    .font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55))
            }
        }
    }

    private var controls: some View {
        HStack {
            Button { showLyrics = true } label: {
                Image(systemName: "shuffle").font(.system(size: 17)).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: "backward.fill").font(.system(size: 21)).foregroundColor(.white.opacity(0.45))
            Spacer()
            Button {
                engine.toggle()
                if engine.isPlaying { startSpin() }
            } label: {
                ZStack {
                    Circle().fill(Color.white).frame(width: 64, height: 64)
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22)).foregroundColor(.black)
                        .offset(x: engine.isPlaying ? 0 : 2)
                }
            }
            Spacer()
            Image(systemName: "forward.fill").font(.system(size: 21)).foregroundColor(.white.opacity(0.45))
            Spacer()
            Button { showList = true } label: {
                Image(systemName: "list.bullet").font(.system(size: 17)).foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var homeBar: some View {
        Capsule().fill(Color.white.opacity(0.22)).frame(width: 120, height: 4).padding(.bottom, 2)
    }

    private func startSpin() {
        angle = 0
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }
}

struct PlayerLyricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = MusicEngine.shared
    private let lines = ["街角的路灯还亮着", "风把从前吹回来", "把耳机调到最大声",
                         "我坠落在这片星空里", "找不到你来过的痕迹", "如果光也会怕黑"]
    @State private var current = 3

    var body: some View {
        ZStack {
            MineTheme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(engine.current?.title ?? "歌词").font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button("关闭") { dismiss() }.font(.system(size: 12))
                }
                .padding(.horizontal, 18).padding(.top, 14)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            Button { current = i } label: {
                                Text(line)
                                    .font(.system(size: i == current ? 18 : 14,
                                                  weight: i == current ? .heavy : .semibold))
                                    .foregroundColor(i == current
                                                     ? Color(red: 1, green: 0.56, blue: 0.71)
                                                     : .white.opacity(0.35))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 40)
                }
                Text("点任意一行跳到该句")
                    .font(.system(size: 9.5)).foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 18)
            }
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
                MineTheme.bg.ignoresSafeArea()
                List {
                    ForEach(list) { s in
                        Button {
                            dismiss()
                            Task { await engine.play(keyword: s.title) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.title).font(.system(size: 14, weight: .semibold))
                                    Text(s.artist).font(.system(size: 11)).foregroundColor(.gray)
                                }
                                Spacer()
                                if engine.current?.title == s.title {
                                    Image(systemName: "waveform")
                                        .foregroundColor(MineTheme.pink)
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
