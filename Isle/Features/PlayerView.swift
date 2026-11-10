import SwiftUI
import AVFoundation

struct PlayerView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var engine = MusicEngine.shared
    @ObservedObject private var fav = FavoritesStore.shared
    @State private var keyword = "坠落星空"
    @State private var showLyrics = false

    private var title: String { engine.current?.title ?? "还没播放" }
    private var artist: String { engine.current?.artist ?? "下面搜索框找歌" }
    private var isFav: Bool { fav.contains(title, artist) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.05, blue: 0.22),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    vinyl.padding(.top, 4)
                    infoRow.padding(.top, 14)
                    lyricButton.padding(.top, 12)
                    progressBar.padding(.top, 12)
                    controls.padding(.top, 10)
                    searchRow.padding(.top, 16).padding(.bottom, 24)
                }
                .padding(.horizontal, 22)
            }
        }
        .sheet(isPresented: $showLyrics) { LyricsView() }
    }

    private var topBar: some View {
        HStack {
            Image(systemName: "chevron.down").font(.system(size: 17)).foregroundColor(.white.opacity(0.75))
            Spacer()
            Text("正在播放").font(.system(size: 11.5)).tracking(2).foregroundColor(.white.opacity(0.55))
            Spacer()
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 15))
                Image(systemName: "ellipsis").font(.system(size: 15))
            }.foregroundColor(.white.opacity(0.75))
        }
        .padding(.top, 14)
    }

    private var vinyl: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let discAngle = engine.isPlaying ? (t.truncatingRemainder(dividingBy: 9) / 9) * 360 : 0
            let ringAngle = engine.isPlaying ? (t.truncatingRemainder(dividingBy: 3.2) / 3.2) * 360 : 0
            ZStack {
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: [
                        Color(red: 1, green: 0.48, blue: 0.24), Color(red: 1, green: 0.18, blue: 0.47),
                        Color(red: 0.75, green: 0.25, blue: 0.48), Color(red: 0.48, green: 0.36, blue: 1),
                        Color(red: 1, green: 0.48, blue: 0.24)]), center: .center))
                    .frame(width: 288, height: 288).blur(radius: 18).opacity(0.6)
                    .rotationEffect(.degrees(ringAngle * 0.5))

                Circle()
                    .stroke(AngularGradient(gradient: Gradient(colors: [
                        .clear, Color(red: 1, green: 0.48, blue: 0.24), Color(red: 1, green: 0.18, blue: 0.47),
                        Color(red: 0.48, green: 0.36, blue: 1), .clear]), center: .center), lineWidth: 5)
                    .frame(width: 264, height: 264)
                    .rotationEffect(.degrees(ringAngle))
                    .shadow(color: Color(red: 1, green: 0.18, blue: 0.47).opacity(0.6), radius: 8)

                Circle().fill(Color.white).frame(width: 8, height: 8)
                    .offset(y: -132)
                    .shadow(color: .white.opacity(0.8), radius: 6)
                    .rotationEffect(.degrees(ringAngle))

                ZStack {
                    Circle()
                        .fill(RadialGradient(gradient: Gradient(colors: [
                            Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.05)]),
                                             center: .center, startRadius: 20, endRadius: 130))
                        .overlay(Circle().stroke(Color.white.opacity(0.05), lineWidth: 1).scaleEffect(0.94))
                        .overlay(Circle().stroke(Color.white.opacity(0.04), lineWidth: 1).scaleEffect(0.86))
                    Circle()
                        .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.35),
                                                      Color(red: 0.76, green: 0.25, blue: 0.45),
                                                      Color(red: 0.23, green: 0.10, blue: 0.32)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .overlay(Image(systemName: engine.isPlaying ? "waveform" : "music.note")
                                    .font(.system(size: 32)).foregroundColor(.white.opacity(0.65)))
                    Circle().fill(Color.black.opacity(0.9)).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                }
                .frame(width: 232, height: 232)
                .rotationEffect(.degrees(discAngle))
                .shadow(color: .black.opacity(0.6), radius: 22, y: 14)

                VStack(spacing: 0) {
                    Circle().fill(LinearGradient(colors: [.white, Color(white: 0.6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 5, height: 62)
                }
                .rotationEffect(.degrees(22), anchor: .top)
                .offset(x: 102, y: -100)
            }
            .frame(height: 292)
        }
    }

    private var infoRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 20, weight: .heavy)).lineLimit(1)
                Text(artist).font(.system(size: 12)).foregroundColor(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer()
            Button {
                fav.toggle(title: title, artist: artist)
            } label: {
                Image(systemName: isFav ? "heart.fill" : "heart").font(.system(size: 20))
                    .foregroundColor(isFav ? Color(red: 1, green: 0.37, blue: 0.62) : .white.opacity(0.85))
            }
            Image(systemName: "arrow.down.to.line").font(.system(size: 18)).foregroundColor(.white.opacity(0.85))
        }
    }

    private var lyricButton: some View {
        Button { showLyrics = true } label: {
            VStack(spacing: 4) {
                Text(engine.status).font(.system(size: 14.5, weight: .bold)).foregroundColor(.white)
                Text("点这里看全部歌词").font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var progressBar: some View {
        VStack(spacing: 7) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18))
                    Capsule().fill(Color.white).frame(width: g.size.width * CGFloat(engine.progress))
                    Circle().fill(Color.white).frame(width: 12, height: 12)
                        .shadow(color: .white.opacity(0.7), radius: 5)
                        .offset(x: max(0, g.size.width * CGFloat(engine.progress) - 6))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                    engine.seek(to: Double(max(0, min(1, v.location.x / g.size.width))))
                })
            }.frame(height: 14)
            HStack {
                Text(fmt(engine.progress * 240)); Spacer(); Text("4:00")
            }.font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55))
        }
    }

    private var controls: some View {
        HStack {
            Image(systemName: "shuffle").font(.system(size: 18)).foregroundColor(.white.opacity(0.65))
            Spacer()
            Button { engine.seek(to: max(0, engine.progress - 0.05)) } label: {
                Image(systemName: "backward.fill").font(.system(size: 24)).foregroundColor(.white)
            }
            Spacer()
            Button {
                if engine.current == nil { Task { await engine.play(keyword: keyword) } }
                else { engine.toggle() }
            } label: {
                ZStack {
                    Circle().fill(Color.white).frame(width: 62, height: 62)
                        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                    if engine.status == "搜索中…" || engine.status == "取播放票据…" {
                        ProgressView().tint(Color(red: 0.07, green: 0.06, blue: 0.09))
                    } else {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 0.07, green: 0.06, blue: 0.09))
                    }
                }
            }
            Spacer()
            Button { engine.seek(to: min(1, engine.progress + 0.05)) } label: {
                Image(systemName: "forward.fill").font(.system(size: 24)).foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "list.bullet").font(.system(size: 18)).foregroundColor(.white.opacity(0.65))
        }
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundColor(.white.opacity(0.4))
            TextField("搜歌名 / 歌手，回车播放", text: $keyword)
                .font(.system(size: 13)).foregroundColor(.white)
                .submitLabel(.search)
                .onSubmit { Task { await engine.play(keyword: keyword) } }
            Button { Task { await engine.play(keyword: keyword) } } label: {
                Text("播放").font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(LinearGradient(colors: [Color(red: 1, green: 0.24, blue: 0.47),
                                                        Color(red: 1, green: 0.48, blue: 0.18)],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func fmt(_ sec: Double) -> String {
        let s = Int(max(0, sec))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
