import SwiftUI

// MARK: - 示例数据（音源脚本接入后替换）
struct Song: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artist: String
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
        let sub: String
        let c1: Color
        let c2: Color
    }

    static let charts: [Chart] = [
        Chart(name: "飙升榜", songs: ["夜航星", "坠落星空", "把回忆拼好给你", "若把你", "慢冷"],
              sub: "+128% 播放",
              c1: Color(red: 1, green: 0.18, blue: 0.47), c2: Color(red: 1, green: 0.54, blue: 0)),
        Chart(name: "热歌榜", songs: ["若把你", "乌梅子酱", "就让这大雨全都落下", "罗生门", "晚风"],
              sub: "每日 12:00 更新",
              c1: Color(red: 0.48, green: 0.36, blue: 1), c2: Color(red: 0, green: 0.83, blue: 1)),
        Chart(name: "新歌榜", songs: ["晚风 Live", "月亮代表谁的心", "罗生门", "孤勇者", "就这样"],
              sub: "本周 40 首",
              c1: Color(red: 0, green: 0.88, blue: 0.64), c2: Color(red: 0, green: 0.64, blue: 1)),
        Chart(name: "DJ 专区", songs: ["Bones Remix", "车载慢摇", "蹦迪电音", "夜店串烧", "抖腿神曲"],
              sub: "电音 / 慢摇",
              c1: Color(red: 1, green: 0.82, blue: 0.25), c2: Color(red: 1, green: 0.18, blue: 0.47))
    ]

    struct LyricLine {
        let text: String
        let song: String
        let artist: String
    }

    static let sadLyrics: [LyricLine] = [
        LyricLine(text: "我把所有的委屈都咽下去，只为了在你面前笑得像个没事人", song: "慢冷", artist: "梁静茹"),
        LyricLine(text: "你走后，我把每首歌都听成了你", song: "坠落星空", artist: "阿YueYue"),
        LyricLine(text: "后来我们什么都有了，却没有了我们", song: "后来", artist: "刘若英"),
        LyricLine(text: "我开始习惯一个人，习惯在人群里假装热闹", song: "孤独患者", artist: "陈奕迅"),
        LyricLine(text: "都怪我，把爱想得太简单", song: "说谎", artist: "林宥嘉"),
        LyricLine(text: "最好的报复是美丽，最美的盛开是反击", song: "起风了", artist: "买辣椒也用券")
    ]
}

// MARK: - 首页
struct HomeView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var lyricIndex = 0
    @State private var hotBatch: [Song] = Array(DemoData.hot.shuffled().prefix(3))
    @State private var chartSongs: [String: [String]] = [:]

    private var lyric: DemoData.LyricLine {
        DemoData.sadLyrics[lyricIndex % DemoData.sadLyrics.count]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.04, blue: 0.19),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    lyricBar
                    hotCard.padding(.top, 18)
                    chartsSection.padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .onAppear { roll() }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            withAnimation(.easeOut(duration: 0.45)) { lyricIndex += 1 }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting).font(.system(size: 12)).foregroundColor(.gray)
                Text("发现").font(.system(size: 25, weight: .heavy)).foregroundColor(.white)
            }
            Spacer()
            HStack(spacing: 18) {
                Image(systemName: "magnifyingglass").font(.system(size: 18))
                Image(systemName: "bell").font(.system(size: 18))
            }
            .foregroundColor(.gray).padding(.top, 8)
        }
        .padding(.top, 18)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let name = auth.user?.nickname ?? "欢迎"
        if h < 6 { return "夜深了，注意休息" }
        if h < 12 { return "早上好，\(name)" }
        if h < 18 { return "下午好，\(name)" }
        return "晚上好，\(name)"
    }

    private var lyricBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeOut(duration: 0.45)) { lyricIndex += 1 } } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lyric.text)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        Image(systemName: "music.note").font(.system(size: 9))
                        Text(lyric.song).font(.system(size: 10.5, weight: .semibold))
                        Rectangle().frame(width: 9, height: 1)
                        Text(lyric.artist).font(.system(size: 10.5))
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .id(lyricIndex)
            .transition(.opacity.combined(with: .offset(y: 12)))

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                       Color(red: 1, green: 0.70, blue: 0.28)],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: 180)
            }
            .frame(height: 1.5)
            .padding(.top, 12)
        }
        .padding(.top, 14)
    }

    private var hotCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").font(.system(size: 12)).foregroundColor(.orange)
                Text("抖音热歌 · 每小时更新").font(.system(size: 13.5, weight: .bold))
                Spacer()
                Button { hotBatch = Array(DemoData.hot.shuffled().prefix(3)) } label: {
                    Text("换一批").font(.system(size: 9.5))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.white.opacity(0.13)).clipShape(Capsule())
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            ForEach(hotBatch) { s in
                HStack(spacing: 11) {
                    Circle()
                        .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.35),
                                                      Color(red: 0.76, green: 0.25, blue: 0.45)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.65)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.title).font(.system(size: 13, weight: .semibold))
                        Text(s.artist).font(.system(size: 10.5)).foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "play.fill").font(.system(size: 11))
                        .foregroundColor(Color(red: 1, green: 0.37, blue: 0.62))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47).opacity(0.28),
                                          Color(red: 1, green: 0.54, blue: 0).opacity(0.10)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("榜单流行").font(.system(size: 16, weight: .bold))
                Spacer()
                Text("更多 ›").font(.system(size: 12)).foregroundColor(.gray)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 11), GridItem(.flexible(), spacing: 11)], spacing: 11) {
                ForEach(DemoData.charts) { c in chartCard(c) }
            }
        }
    }

    private func chartCard(_ c: DemoData.Chart) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(c.name).font(.system(size: 12.5, weight: .heavy))
                Spacer()
                Button { roll(c) } label: {
                    Text("换").font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.black.opacity(0.2)).clipShape(Capsule())
                }
                .foregroundColor(.white)
            }
            ForEach(shown(c), id: \.self) { name in
                Text(name).font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Text(c.sub).font(.system(size: 9)).foregroundColor(.white.opacity(0.6))
        }
        .padding(11)
        .frame(height: 132, alignment: .top)
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
