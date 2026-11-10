import SwiftUI

struct Song: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artist: String
    var artistPic: String? = nil
}

enum DemoData {
    static let hot: [Song] = [
        Song(title: "夜航星", artist: "Lummy"),
        Song(title: "坠落星空（女版）", artist: "阿YueYue"),
        Song(title: "Bones（Remix）", artist: "DJ 小鹿"),
        Song(title: "若把你", artist: "小阿七"),
        Song(title: "乌梅子酱", artist: "李荣浩"),
        Song(title: "晚风（Live）", artist: "陈壹千")
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
              c1: Color(red: 1, green: 0.18, blue: 0.47), c2: Color(red: 1, green: 0.54, blue: 0)),
        Chart(name: "热歌榜", songs: ["若把你", "乌梅子酱", "就让这大雨全都落下", "罗生门", "晚风"],
              c1: Color(red: 0.48, green: 0.36, blue: 1), c2: Color(red: 0, green: 0.83, blue: 1)),
        Chart(name: "新歌榜", songs: ["晚风 Live", "月亮代表谁的心", "孤勇者", "就这样"],
              c1: Color(red: 0, green: 0.88, blue: 0.64), c2: Color(red: 0, green: 0.64, blue: 1)),
        Chart(name: "DJ 专区", songs: ["Bones Remix", "车载慢摇", "蹦迪电音", "夜店串烧"],
              c1: Color(red: 1, green: 0.82, blue: 0.25), c2: Color(red: 1, green: 0.18, blue: 0.47))
    ]
}

/// 从音源返回的结果里尽量捞一张歌手图
private func pickPic(_ dict: [String: Any]) -> String? {
    let keys = ["pic", "img", "cover", "artwork", "artistPic", "singerImg", "avatar", "image"]
    for k in keys {
        if let s = dict[k] as? String, s.hasPrefix("http") { return s }
    }
    return nil
}

struct SingleLineLyric: View {
    let text: String
    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    private var needScroll: Bool { textWidth > boxWidth - 6 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                label.opacity(needScroll ? 0 : 1)
                    .frame(width: geo.size.width, alignment: .center)
                if needScroll {
                    TimelineView(.animation) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        let distance = textWidth + 44
                        let offset = -CGFloat((t * 34).truncatingRemainder(dividingBy: max(1, Double(distance))))
                        HStack(spacing: 44) { label; label }
                            .offset(x: offset)
                            .frame(width: geo.size.width, alignment: .leading)
                            .clipped()
                    }
                }
            }
            .mask(LinearGradient(colors: [.clear, .black, .black, .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .onAppear { boxWidth = geo.size.width }
            .onChange(of: geo.size.width) { boxWidth = $0 }
        }
        .frame(height: 24)
    }

    private var label: some View {
        Text(text)
            .font(.system(size: 15.5, weight: .bold))
            .fixedSize()
            .foregroundStyle(LinearGradient(colors: [.white,
                                                     Color(red: 1, green: 0.84, blue: 0.90),
                                                     Color(red: 1, green: 0.79, blue: 0.64)],
                                            startPoint: .leading, endPoint: .trailing))
            .background(GeometryReader { g in
                Color.clear.onAppear { textWidth = g.size.width }
            })
    }
}

struct HomeView: View {
    @EnvironmentObject var auth: AuthStore
    @ObservedObject private var engine = MusicEngine.shared
    @State private var lyricIndex = 0
    @State private var hotBatch: [Song] = Array(DemoData.hot.prefix(3))
    @State private var pics: [String: String] = [:]
    @State private var toast: String?
    @State private var busy = false

    private let lyrics: [(String, String, String)] = [
        ("我把所有的委屈都咽下去，只为了在你面前笑得像个没事人", "慢冷", "梁静茹"),
        ("你走后，我把每首歌都听成了你", "坠落星空", "阿YueYue"),
        ("后来我们什么都有了，却没有了我们", "后来", "刘若英"),
        ("我开始习惯一个人，习惯在人群里假装热闹", "孤独患者", "陈奕迅"),
        ("都怪我，把爱想得太简单", "说谎", "林宥嘉")
    ]

    private var lyric: (String, String, String) { lyrics[lyricIndex % lyrics.count] }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                MineTheme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        lyricBlock
                        hotCard.padding(.top, 14)
                        chartsSection.padding(.top, 16)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 90)
                }
                if let toast {
                    Text(toast)
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.6))
                        .padding(.bottom, 18)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { roll() }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeOut(duration: 0.4)) { lyricIndex += 1 }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(greeting).font(.system(size: 13)).foregroundColor(Color(white: 0.55))
            Spacer(minLength: 12)
            HStack(spacing: 20) {
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "magnifyingglass").font(.system(size: 19))
                        .foregroundColor(Color(white: 0.62))
                }
                NavigationLink(destination: CheckinView()) {
                    Image(systemName: "bell").font(.system(size: 19))
                        .foregroundColor(Color(white: 0.62))
                }
            }
        }
        .frame(height: 44)
        .padding(.top, 4)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let name = auth.user?.nickname ?? "欢迎"
        if h < 6 { return "夜深了，注意休息" }
        if h < 12 { return "早上好，\(name)" }
        if h < 18 { return "下午好，\(name)" }
        return "晚上好，\(name)"
    }

    private var lyricBlock: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeOut(duration: 0.4)) { lyricIndex += 1 } } label: {
                SingleLineLyric(text: lyric.0)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            .id(lyricIndex)

            HStack(spacing: 6) {
                Image(systemName: "music.note").font(.system(size: 9))
                Text(lyric.1).font(.system(size: 10.5, weight: .semibold))
                Text("·").font(.system(size: 10.5))
                Text(lyric.2).font(.system(size: 10.5))
            }
            .foregroundColor(Color(white: 0.42))
            .padding(.top, 8)

            LinearGradient(colors: [.clear, MineTheme.pink, .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 40, height: 2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private var hotCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundColor(.orange)
                Text("抖音热歌 · 每小时更新").font(.system(size: 13, weight: .bold))
                Spacer()
                Button { roll() } label: {
                    Text("换一批").font(.system(size: 9.5)).foregroundColor(Color(white: 0.55))
                }
            }
            ForEach(hotBatch) { s in
                Button { play(s.title) } label: {
                    HStack(spacing: 10) {
                        ArtistAvatar(name: s.artist, urlString: pics[s.title], size: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .lineLimit(1)
                            Text(s.artist).font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if busy && engine.current?.title == s.title {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11)).foregroundColor(MineTheme.pink)
                        }
                    }
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47).opacity(0.30),
                                          Color(red: 1, green: 0.54, blue: 0).opacity(0.12),
                                          Color.white.opacity(0.03)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("榜单流行").font(.system(size: 13, weight: .bold)).foregroundColor(Color(white: 0.6))
                Spacer()
                NavigationLink(destination: ChartsView()) {
                    HStack(spacing: 3) {
                        Text("更多").font(.system(size: 11))
                        Image(systemName: "chevron.right").font(.system(size: 9))
                    }
                    .foregroundColor(MineTheme.pink)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(DemoData.charts) { c in chartCard(c) }
            }
        }
    }

    private func chartCard(_ c: DemoData.Chart) -> some View {
        NavigationLink(destination: ChartDetailView(chart: c)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(c.name).font(.system(size: 12, weight: .heavy))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(.white.opacity(0.6))
                }
                ForEach(Array(c.songs.prefix(3)), id: \.self) { name in
                    Text(name)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .frame(height: 112, alignment: .top)
            .background(LinearGradient(colors: [c.c1, c.c2], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func roll() {
        hotBatch = Array(DemoData.hot.shuffled().prefix(3))
        Task { await loadPics() }
    }

    private func loadPics() async {
        for s in hotBatch where pics[s.title] == nil {
            if let list = try? await engine.search(s.title), let first = list.first,
               let p = pickPic(first) {
                await MainActor.run { pics[s.title] = p }
            }
        }
    }

    private func play(_ keyword: String) {
        busy = true
        toast = "正在搜索「\(keyword)」…"
        Task {
            await engine.play(keyword: keyword)
            await MainActor.run {
                busy = false
                toast = engine.isPlaying ? "正在播放：\(engine.current?.title ?? keyword)" : engine.status
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

struct ChartsView: View {
    var body: some View {
        ZStack {
            MineTheme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(DemoData.charts) { c in
                        NavigationLink(destination: ChartDetailView(chart: c)) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [c.c1, c.c2],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 54, height: 54)
                                    .overlay(Image(systemName: "chart.bar.fill")
                                                .font(.system(size: 18)).foregroundColor(.white.opacity(0.9)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(c.name).font(.system(size: 14, weight: .bold))
                                    Text(c.songs.prefix(2).joined(separator: " · "))
                                        .font(.system(size: 10.5)).foregroundColor(.gray).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                            }
                            .padding(11)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(14)
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
            MineTheme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(colors: [chart.c1, chart.c2],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 120)
                        .overlay(VStack(spacing: 4) {
                            Text(chart.name).font(.system(size: 20, weight: .heavy))
                            Text("\(chart.songs.count) 首 · 每小时更新").font(.system(size: 10.5)).opacity(0.8)
                        }.foregroundColor(.white))
                        .padding(.bottom, 6)

                    ForEach(Array(chart.songs.enumerated()), id: \.offset) { i, name in
                        Button {
                            Task { await engine.play(keyword: name) }
                        } label: {
                            HStack(spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(i < 3 ? MineTheme.pink : .white.opacity(0.35))
                                    .frame(width: 20)
                                Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                Spacer()
                                if engine.current?.title == name {
                                    Image(systemName: "waveform").font(.system(size: 11)).foregroundColor(MineTheme.pink)
                                } else {
                                    Image(systemName: "play.fill").font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
                                }
                            }
                            .padding(.vertical, 10).padding(.horizontal, 11)
                            .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(14)
            }
        }
        .navigationTitle(chart.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
