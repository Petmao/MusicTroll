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
        Chart(name: "新歌榜", songs: ["晚风 Live", "月亮代表谁的心", "罗生门", "孤勇者", "就这样"],
              c1: Color(red: 0, green: 0.88, blue: 0.64), c2: Color(red: 0, green: 0.64, blue: 1)),
        Chart(name: "DJ 专区", songs: ["Bones Remix", "车载慢摇", "蹦迪电音", "夜店串烧", "抖腿神曲"],
              c1: Color(red: 1, green: 0.82, blue: 0.25), c2: Color(red: 1, green: 0.18, blue: 0.47))
    ]

    struct LyricLine { let text: String; let song: String; let artist: String }

    static let sadLyrics: [LyricLine] = [
        LyricLine(text: "我把所有的委屈都咽下去，只为了在你面前笑得像个没事人", song: "慢冷", artist: "梁静茹"),
        LyricLine(text: "你走后，我把每首歌都听成了你", song: "坠落星空", artist: "阿YueYue"),
        LyricLine(text: "后来我们什么都有了，却没有了我们", song: "后来", artist: "刘若英"),
        LyricLine(text: "我开始习惯一个人，习惯在人群里假装热闹", song: "孤独患者", artist: "陈奕迅"),
        LyricLine(text: "都怪我，把爱想得太简单", song: "说谎", artist: "林宥嘉"),
        LyricLine(text: "最好的报复是美丽，最美的盛开是反击", song: "起风了", artist: "买辣椒也用券")
    ]
}

/// 单排歌词：字宽没超过就居中静置，超了才左右滚
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
                        HStack(spacing: 44) {
                            label
                            label
                        }
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
    @StateObject private var engine = MusicEngine.shared
    @State private var lyricIndex = 0
    @State private var hotBatch: [Song] = Array(DemoData.hot.shuffled().prefix(3))
    @State private var chartSongs: [String: [String]] = [:]

    private var lyric: DemoData.LyricLine { DemoData.sadLyrics[lyricIndex % DemoData.sadLyrics.count] }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        lyricBlock
                        hotCard.padding(.top, 14)
                        chartsSection.padding(.top, 16)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 26)
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

    // 顶栏：图标 20×20，与文字垂直居中
    private var header: some View {
        HStack(spacing: 0) {
            Text(greeting)
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.55))
            Spacer(minLength: 12)
            HStack(spacing: 20) {
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundColor(Color(white: 0.62))
                }
                NavigationLink(destination: CheckinView()) {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .regular))
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
            Button {
                withAnimation(.easeOut(duration: 0.4)) { lyricIndex += 1 }
                Task { await engine.play(keyword: lyric.song) }
            } label: {
                SingleLineLyric(text: lyric.text)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())
            .id(lyricIndex)

            HStack(spacing: 6) {
                Image(systemName: "music.note").font(.system(size: 9))
                Text(lyric.song).font(.system(size: 10.5, weight: .semibold))
                Text("·").font(.system(size: 10.5))
                Text(lyric.artist).font(.system(size: 10.5))
            }
            .foregroundColor(Color(white: 0.42))
            .padding(.top, 8)

            LinearGradient(colors: [.clear, Color(red: 1, green: 0.37, blue: 0.62), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 40, height: 2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var hotCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundColor(.orange)
                Text("抖音热歌 · 每小时更新").font(.system(size: 13, weight: .bold))
                Spacer()
                Button { hotBatch = Array(DemoData.hot.shuffled().prefix(3)) } label: {
                    Text("换一批").font(.system(size: 9.5)).foregroundColor(Color(white: 0.55))
                }
            }

            ForEach(hotBatch) { s in
                Button { Task { await engine.play(keyword: s.title) } } label: {
                    HStack(spacing: 10) {
                        ArtistAvatar(name: s.artist, urlString: s.artistPic, size: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .lineLimit(1)
                            Text(s.artist).font(.system(size: 11)).foregroundColor(.gray).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 1, green: 0.37, blue: 0.62))
                    }
                    .padding(.vertical, 7)
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
                Text("更多 ›").font(.system(size: 11)).foregroundColor(.gray)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(DemoData.charts) { c in chartCard(c) }
            }
        }
    }

    private func chartCard(_ c: DemoData.Chart) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(c.name).font(.system(size: 12, weight: .heavy))
                Spacer()
                Button { roll(c) } label: {
                    Text("换").font(.system(size: 9)).foregroundColor(.white.opacity(0.85))
                }
            }
            ForEach(shown(c), id: \.self) { name in
                Button { Task { await engine.play(keyword: name) } } label: {
                    Text(name)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(height: 112, alignment: .top)
        .background(LinearGradient(colors: [c.c1, c.c2], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func shown(_ c: DemoData.Chart) -> [String] {
        Array((chartSongs[c.name] ?? Array(c.songs.prefix(3))).prefix(3))
    }

    private func roll(_ c: DemoData.Chart? = nil) {
        if let c = c { chartSongs[c.name] = Array(c.songs.shuffled().prefix(3)) }
        else { for c in DemoData.charts { chartSongs[c.name] = Array(c.songs.shuffled().prefix(3)) } }
    }
}
