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
            let disc = min(geo.size.width - 64, 300)
            ZStack {
                IsleBackground()
                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 6)
                    discView(disc)
                    Spacer(minLength: 6)
                    titleBlock
                    progressBlock.padding(.top, 18)
                    controls.padding(.top, 14)
                    actionRow.padding(.top, 18)
                    homeBar.padding(.top, 12)
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
                .padding(.bottom, 8)
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
            IsleIcon(IsleSymbol.collapse, scale: .md, tint: Color.white.opacity(0.62))
            Spacer()
            Text("正在播放").font(.system(size: 11, weight: .semibold)).tracking(2)
                .foregroundStyle(IsleColor.textSub)
            Spacer()
            Button { showList = true } label: {
                IsleIcon(IsleSymbol.more, scale: .md, tint: Color.white.opacity(0.62))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 44)
    }

    private func discView(_ size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(AngularGradient(
                    gradient: Gradient(colors: [.clear, IsleColor.pinkLight, IsleColor.pinkDeep, IsleColor.lilac, .clear]),
                    center: .center), lineWidth: 3)
                .frame(width: size + 18, height: size + 18)
                .blur(radius: 6)
                .opacity(0.9)

            Circle()
                .fill(Color(red: 0.05, green: 0.05, blue: 0.07))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.55), radius: 22, y: 12)

            Circle()
                .fill(IsleColor.accent)
                .frame(width: size * 0.44, height: size * 0.44)
                .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 7))
                .overlay(
                    Text("ISLE")
                        .font(.system(size: max(9, size * 0.052), weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.92))
                )
                .rotationEffect(.degrees(angle))

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 5, height: size * 0.52)
                .offset(x: size * 0.42, y: -size * 0.30)
                .rotationEffect(.degrees(24), anchor: .top)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
        }
        .frame(width: size + 18, height: size + 18)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(engine.current?.title ?? "未选择歌曲")
                .font(.system(size: 20, weight: .heavy))
                .lineLimit(1)
            Text(engine.current?.artist ?? "去搜索或点一首歌")
                .font(.system(size: 12))
                .foregroundStyle(IsleColor.textSub)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressBlock: some View {
        VStack(spacing: 8) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16)).frame(height: 3)
                    Capsule().fill(IsleColor.accent)
                        .frame(width: max(0, g.size.width * ratio), height: 3)
                    Circle().fill(Color.white).frame(width: 11, height: 11)
                        .shadow(color: IsleColor.pink.opacity(0.9), radius: 5)
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
                Text("\(Int(ratio * 100))%").font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub)
                Spacer()
                Text(engine.status).font(.system(size: 10.5)).foregroundStyle(IsleColor.textFaint).lineLimit(1)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button { showLyrics = true } label: {
                IsleIcon(IsleSymbol.shuffle, scale: .md, tint: Color.white.opacity(0.5))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Spacer()

            IsleIcon(IsleSymbol.prev, scale: .lg, tint: Color.white.opacity(0.85))

            Spacer()

            Button {
                engine.toggle()
                if engine.isPlaying { startSpin() }
            } label: {
                ZStack {
                    Circle().fill(Color.white).frame(width: 62, height: 62)
                        .shadow(color: IsleColor.pink.opacity(0.45), radius: 16, y: 8)
                    IsleIcon(engine.isPlaying ? IsleSymbol.pause : IsleSymbol.play,
                             scale: .xl,
                             weight: .bold,
                             tint: IsleColor.pinkDeep)
                        .offset(x: engine.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            IsleIcon(IsleSymbol.next, scale: .lg, tint: Color.white.opacity(0.85))

            Spacer()

            Button { showList = true } label: {
                IsleIcon(IsleSymbol.loop, scale: .md, tint: Color.white.opacity(0.5))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
    }

    private var actionRow: some View {
        HStack {
            actionItem(IsleSymbol.heartFill, "收藏", active: isLiked) {
                if let t = engine.current?.title, let a = engine.current?.artist {
                    FavoritesStore.shared.toggle(title: t, artist: a)
                }
            }
            actionItem(IsleSymbol.lyric, "歌词", active: false) { showLyrics = true }
            actionItem(IsleSymbol.download, "下载", active: false) { }
            actionItem(IsleSymbol.addToPlaylist, "歌单", active: false) { showList = true }
            actionItem(IsleSymbol.share, "分享", active: false) { }
        }
        .padding(.horizontal, 2)
    }

    private var isLiked: Bool {
        FavoritesStore.shared.contains(engine.current?.title ?? "", engine.current?.artist ?? "")
    }

    private func actionItem(_ symbol: String, _ title: String,
                            active: Bool, act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 7) {
                IsleIcon(symbol, scale: .md, weight: .semibold,
                         tint: active ? IsleColor.pink : Color.white.opacity(0.5))
                Text(title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(active ? IsleColor.pink : Color.white.opacity(0.5))
            }
            .frame(width: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var homeBar: some View {
        Capsule().fill(Color.white.opacity(0.18)).frame(width: 120, height: 4).padding(.bottom, 2)
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
            IsleBackground()
            VStack(spacing: 0) {
                HStack {
                    Text(engine.current?.title ?? "歌词").font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button("关闭") { dismiss() }.font(.system(size: 12))
                }
                .padding(.horizontal, 18).padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            Button { current = i } label: {
                                Text(line)
                                    .font(.system(size: i == current ? 20 : 15,
                                                  weight: i == current ? .heavy : .semibold))
                                    .foregroundStyle(i == current
                                                     ? IsleColor.pinkLight
                                                     : Color.white.opacity(0.34))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 44)
                }

                Text("点任意一行跳到该句")
                    .font(.system(size: 9.5)).foregroundStyle(Color.white.opacity(0.3))
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
                IsleBackground()
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
                                            .foregroundStyle(IsleColor.textSub).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if engine.current?.title == s.title {
                                        IsleIcon(IsleSymbol.music, scale: .md, tint: IsleColor.pink)
                                    }
                                }
                                .padding(12)
                                .background(IsleColor.surface)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(IsleColor.line, lineWidth: 1))
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
