import SwiftUI

struct Song: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artist: String
    var artistPic: String? = nil
}

struct PlaylistCard: Identifiable {
    let id = UUID()
    let name: String
    let count: String
    let first: String
    let c1: Color
    let c2: Color
}

enum DemoData {
    static let newSongs: [Song] = [
        Song(title: "夜航星", artist: "Lummy"),
        Song(title: "坠落星空（女版）", artist: "阿YueYue"),
        Song(title: "Bones（Remix）", artist: "DJ 小鹿"),
        Song(title: "若把你", artist: "小阿七"),
        Song(title: "乌梅子酱", artist: "李荣浩"),
        Song(title: "晚风（Live）", artist: "陈壹千")
    ]

    static var hot: [Song] { newSongs }

    static let playlists: [PlaylistCard] = [
        PlaylistCard(name: "深夜emo｜把心事都交给耳机", count: "128万", first: "慢冷",
                     c1: Color(red: 0.16, green: 0.04, blue: 0.14), c2: IsleColor.pink),
        PlaylistCard(name: "通勤路上 · 一秒清醒", count: "86万", first: "若把你",
                     c1: Color(red: 0.10, green: 0.05, blue: 0.20), c2: IsleColor.lilac),
        PlaylistCard(name: "华语热歌｜循环到天亮", count: "43万", first: "坠落星空",
                     c1: Color(red: 0.18, green: 0.03, blue: 0.12), c2: IsleColor.pinkLight),
        PlaylistCard(name: "纯音乐｜写字楼的午后", count: "31万", first: "晚风",
                     c1: Color(red: 0.07, green: 0.23, blue: 0.36), c2: IsleColor.mint),
        PlaylistCard(name: "抖音热门｜一秒上头", count: "22万", first: "Bones",
                     c1: Color(red: 0, green: 0.23, blue: 0.30), c2: IsleColor.mint),
        PlaylistCard(name: "粤语老歌｜时光机", count: "17万", first: "喜帖街",
                     c1: Color(red: 0.23, green: 0.06, blue: 0.31), c2: IsleColor.pink)
    ]

    struct Chart: Identifiable {
        let id = UUID()
        let name: String
        let songs: [String]
        let c1: Color
        let c2: Color
    }

    static let charts: [Chart] = [
        Chart(name: "飙升榜", songs: ["夜航星", "坠落星空", "把回忆拼好给你", "若把你", "慢冷"],
              c1: Color(red: 0.16, green: 0.04, blue: 0.14), c2: IsleColor.pink),
        Chart(name: "热歌榜", songs: ["若把你", "乌梅子酱", "就让这大雨全都落下", "罗生门", "晚风"],
              c1: Color(red: 0.10, green: 0.05, blue: 0.20), c2: IsleColor.lilac),
        Chart(name: "新歌榜", songs: ["晚风 Live", "月亮代表谁的心", "孤勇者", "就这样"],
              c1: Color(red: 0, green: 0.22, blue: 0.18), c2: IsleColor.mint),
        Chart(name: "DJ 专区", songs: ["Bones Remix", "车载慢摇", "蹦迪电音", "夜店串烧"],
              c1: Color(red: 0.27, green: 0.04, blue: 0.14), c2: IsleColor.pinkDeep)
    ]
}

struct SingleLineLyric: View {
    let text: String
    @State private var tw: CGFloat = 0
    @State private var bw: CGFloat = 0
    private var scroll: Bool { tw > bw - 6 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                label.opacity(scroll ? 0 : 1).frame(width: geo.size.width, alignment: .center)
                if scroll {
                    TimelineView(.animation) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        let d = tw + 44
                        let off = -CGFloat((t * 34).truncatingRemainder(dividingBy: max(1, Double(d))))
                        HStack(spacing: 44) { label; label }
                            .offset(x: off)
                            .frame(width: geo.size.width, alignment: .leading)
                            .clipped()
                    }
                }
            }
            .mask(LinearGradient(colors: [.clear, .black, .black, .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .onAppear { bw = geo.size.width }
        }
        .frame(height: 22)
    }

    private var label: some View {
        Text(text)
            .font(.system(size: 14.5, weight: .semibold))
            .fixedSize()
            .foregroundStyle(LinearGradient(colors: [Color.white.opacity(0.92), IsleColor.pinkLight],
                                            startPoint: .leading, endPoint: .trailing))
            .background(GeometryReader { g in Color.clear.onAppear { tw = g.size.width } })
    }
}

struct HomeView: View {
    @ObservedObject private var engine = MusicEngine.shared
    @State private var lyricIndex = 0
    @State private var toast: String?
    @State private var busy = false

    private let lyrics: [(String, String)] = [
        ("我把所有的委屈都咽下去，只为了在你面前笑得像个没事人", "慢冷 · 梁静茹"),
        ("你走后，我把每首歌都听成了你", "坠落星空 · 阿YueYue"),
        ("后来我们什么都有了，却没有了我们", "后来 · 刘若英"),
        ("都怪我，把爱想得太简单", "说谎 · 林宥嘉"),
        ("我开始习惯一个人，习惯在人群里假装热闹", "孤独患者 · 陈奕迅"),
        ("如果光也会怕黑，那我陪你一起暗", "夜航星 · Lummy")
    ]
    private var lyric: (String, String) { lyrics[lyricIndex % lyrics.count] }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                IsleBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        topBar
                        lyricRow
                        banner.padding(.top, 12)
                        playlistSection.padding(.top, 18)
                        newMusicSection.padding(.top, 18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }
                if let toast {
                    Text(toast)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(Color.black.opacity(0.72)))
                        .overlay(Capsule().stroke(IsleColor.pink.opacity(0.30), lineWidth: 0.6))
                        .padding(.bottom, 18)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(Timer.publish(every: 12, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeOut(duration: 0.35)) { lyricIndex += 1 }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: SearchView()) {
                HStack(spacing: 7) {
                    IsleIcon(IsleSymbol.search, scale: .sm, tint: Color.white.opacity(0.55))
                    Text("搜索歌曲、歌手、歌单").font(.system(size: 12.5))
                    Spacer()
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().stroke(IsleColor.pink.opacity(0.22), lineWidth: 0.8))
            }
            NavigationLink(destination: CheckinView()) {
                IsleIcon(IsleSymbol.clock, scale: .md, tint: Color.white.opacity(0.88))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                    .overlay(Circle().stroke(IsleColor.pink.opacity(0.22), lineWidth: 0.8))
            }
        }
        .frame(height: 50)
    }

    private var lyricRow: some View {
        Button {
            withAnimation(.easeOut(duration: 0.35)) { lyricIndex += 1 }
        } label: {
            VStack(spacing: 5) {
                SingleLineLyric(text: lyric.0).frame(maxWidth: 320)
                Text(lyric.1).font(.system(size: 9.5)).foregroundStyle(Color.white.opacity(0.42))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
        .id(lyricIndex)
    }

    private var banner: some View {
        Button { play("每日推荐") } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [IsleColor.pinkDeep.opacity(0.55),
                                                  IsleColor.pink.opacity(0.35),
                                                  IsleColor.lilac.opacity(0.30)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 126)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(IsleColor.pink.opacity(0.28), lineWidth: 0.8))

                VStack(alignment: .leading, spacing: 5) {
                    Text("每日推荐").font(.system(size: 17, weight: .heavy))
                    Text("根据你的口味生成 · 每次都不一样")
                        .font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.62))
                    Text("30 首")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(IsleColor.pinkLight)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(IsleColor.pink.opacity(0.18)))
                }
                .padding(14)

                HStack {
                    Spacer()
                    ZStack {
                        Circle().fill(AngularGradient(colors: [Color(red: 0.06, green: 0.02, blue: 0.05),
                                                               IsleColor.pinkDeep.opacity(0.8),
                                                               Color(red: 0.06, green: 0.02, blue: 0.05)],
                                                      center: .center))
                            .frame(width: 96, height: 96)
                        Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                            .frame(width: 96, height: 96)
                        Circle()
                            .fill(IsleColor.accent)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(IsleColor.pinkLight.opacity(0.6), lineWidth: 0.8))
                    }
                    .offset(x: 24)
                }
                .padding(.trailing, 10)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("推荐歌单").font(.system(size: 16, weight: .heavy))
                Spacer()
                NavigationLink(destination: ChartsView()) {
                    HStack(spacing: 2) {
                        Text("更多").font(.system(size: 11))
                        IsleIcon(IsleSymbol.arrowRight, scale: .xs, tint: IsleColor.pinkLight)
                    }
                    .foregroundStyle(IsleColor.pinkLight)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 12) {
                ForEach(DemoData.playlists) { p in
                    Button { play(p.first) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: [p.c1, p.c2],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(alignment: .topTrailing) {
                                    HStack(spacing: 2) {
                                        IsleIcon("headphones", scale: .xs, tint: Color.white.opacity(0.92))
                                        Text(p.count).font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color.white.opacity(0.92))
                                    }
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.black.opacity(0.42)))
                                    .padding(5)
                                }
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(IsleColor.pink.opacity(0.16), lineWidth: 0.7))
                            Text(p.name)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.86))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var newMusicSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("最新音乐").font(.system(size: 16, weight: .heavy))
                Spacer()
                Button { play("新歌") } label: {
                    HStack(spacing: 2) {
                        Text("播放全部").font(.system(size: 11))
                        IsleIcon(IsleSymbol.arrowRight, scale: .xs, tint: IsleColor.pinkLight)
                    }
                    .foregroundStyle(IsleColor.pinkLight)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(DemoData.newSongs.enumerated()), id: \.element.id) { i, s in
                    newSongRow(i, s)
                    if i < DemoData.newSongs.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5).padding(.leading, 70)
                    }
                }
            }
        }
    }

    private func newSongRow(_ i: Int, _ s: Song) -> some View {
        Button { play(s.title) } label: {
            HStack(spacing: 10) {
                Text(String(format: "%02d", i + 1))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .frame(width: 18)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(colors: [IsleColor.pinkDeep.opacity(0.7), IsleColor.pink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                    Text(s.artist)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if busy && engine.current?.title == s.title {
                    ProgressView().scaleEffect(0.6)
                } else {
                    IsleIcon(IsleSymbol.more, scale: .sm, tint: Color.white.opacity(0.3))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func play(_ kw: String) {
        busy = true
        toast = "正在搜索「\(kw)」…"
        Task {
            await engine.play(keyword: kw)
            await MainActor.run {
                busy = false
                toast = engine.isPlaying ? "正在播放：\(engine.current?.title ?? kw)" : engine.status
            }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

struct ChartsView: View {
    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(DemoData.charts) { c in
                        NavigationLink(destination: ChartDetailView(chart: c)) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient(colors: [c.c1, c.c2],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 54, height: 54)
                                    .overlay(IsleIcon("chart.bar.fill", scale: .md, tint: Color.white.opacity(0.9)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(c.name).font(.system(size: 14, weight: .bold))
                                    Text(c.songs.prefix(2).joined(separator: " · "))
                                        .font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub).lineLimit(1)
                                }
                                Spacer()
                                IsleIcon(IsleSymbol.arrowRight, scale: .sm, tint: Color.white.opacity(0.3))
                            }
                            .padding(11)
                            .background(IsleColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("全部榜单")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChartDetailView: View {
    let chart: DemoData.Chart
    @ObservedObject private var engine = MusicEngine.shared

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [chart.c1, chart.c2],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 120)
                        .overlay(
                            VStack(spacing: 4) {
                                Text(chart.name).font(.system(size: 20, weight: .heavy))
                                Text("\(chart.songs.count) 首").font(.system(size: 10.5)).opacity(0.8)
                            }
                            .foregroundStyle(Color.white)
                        )
                        .padding(.bottom, 6)

                    ForEach(Array(chart.songs.enumerated()), id: \.offset) { i, n in
                        chartRow(i, n)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(chart.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chartRow(_ i: Int, _ name: String) -> some View {
        Button { Task { await engine.play(keyword: name) } } label: {
            HStack(spacing: 10) {
                Text("\(i + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(i < 3 ? IsleColor.pink : Color.white.opacity(0.35))
                    .frame(width: 20)
                Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer()
                if engine.current?.title == name {
                    IsleIcon("waveform", scale: .sm, tint: IsleColor.pink)
                } else {
                    IsleIcon(IsleSymbol.play, scale: .xs, tint: Color.white.opacity(0.35))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 11)
            .background(IsleColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
