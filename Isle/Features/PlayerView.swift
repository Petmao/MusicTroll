import SwiftUI

/// 播放器：黑胶唱片 + 跑马灯光环 + QQ 式操作区
struct PlayerView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var playing = false
    @State private var isFav = false
    @State private var progress: Double = 0.38

    private let title = "坠落星空（女版）"
    private let artist = "阿YueYue"
    private let lyrics = ["把耳机调到最大声", "我坠落在这片星空里", "找不到你来过的痕迹"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.05, blue: 0.22),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                vinyl.padding(.top, 6)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.system(size: 20, weight: .heavy)).foregroundColor(.white).lineLimit(1)
                        Text(artist).font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Button { isFav.toggle() } label: {
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(isFav ? Color(red: 1, green: 0.37, blue: 0.62) : .white.opacity(0.85))
                    }
                    Button { } label: {
                        Image(systemName: "arrow.down.to.line").font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 22)

                VStack(spacing: 4) {
                    Text(lyrics[1]).font(.system(size: 14.5, weight: .bold)).foregroundColor(.white)
                    Text("点歌词看全部 46 行").font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
                }
                .padding(.top, 12)

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.white).frame(width: g.size.width * progress)
                        Circle().fill(Color.white).frame(width: 12, height: 12)
                            .shadow(color: .white.opacity(0.7), radius: 5)
                            .offset(x: max(0, g.size.width * progress - 6))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 22).padding(.top, 16)

                HStack {
                    Text("1:32"); Spacer(); Text("4:01")
                }
                .font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 22).padding(.top, 7)

                Spacer(minLength: 8)
                controls.padding(.horizontal, 18)
                Spacer(minLength: 20)
            }
        }
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
            }
            .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 22).padding(.top, 14)
    }

    private var vinyl: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let discAngle = playing ? (t.truncatingRemainder(dividingBy: 9) / 9) * 360 : 0
            let ringAngle = playing ? (t.truncatingRemainder(dividingBy: 3.2) / 3.2) * 360 : 0

            ZStack {
                // 外层辉光
                Circle()
                    .fill(AngularGradient(gradient: Gradient(colors: [
                        Color(red: 1, green: 0.48, blue: 0.24),
                        Color(red: 1, green: 0.18, blue: 0.47),
                        Color(red: 0.75, green: 0.25, blue: 0.48),
                        Color(red: 0.48, green: 0.36, blue: 1),
                        Color(red: 1, green: 0.48, blue: 0.24)]), center: .center))
                    .frame(width: 292, height: 292)
                    .blur(radius: 18).opacity(0.62)
                    .rotationEffect(.degrees(ringAngle * 0.5))

                // 跑马灯环
                Circle()
                    .stroke(AngularGradient(gradient: Gradient(colors: [
                        .clear, Color(red: 1, green: 0.48, blue: 0.24),
                        Color(red: 1, green: 0.18, blue: 0.47),
                        Color(red: 0.48, green: 0.36, blue: 1), .clear]), center: .center),
                            lineWidth: 5)
                    .frame(width: 268, height: 268)
                    .rotationEffect(.degrees(ringAngle))
                    .shadow(color: Color(red: 1, green: 0.18, blue: 0.47).opacity(0.6), radius: 8)

                // 灯头亮点
                Circle().fill(Color.white).frame(width: 8, height: 8)
                    .offset(y: -134)
                    .shadow(color: .white.opacity(0.8), radius: 6)
                    .rotationEffect(.degrees(ringAngle))

                // 黑胶碟
                ZStack {
                    Circle()
                        .fill(RadialGradient(gradient: Gradient(colors: [
                            Color(red: 0.10, green: 0.10, blue: 0.12),
                            Color(red: 0.04, green: 0.04, blue: 0.05)]),
                                             center: .center, startRadius: 20, endRadius: 130))
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
                                .scaleEffect(0.96)
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.04), lineWidth: 1)
                                .scaleEffect(0.88)
                        )
                    // 碟心歌手图
                    Circle()
                        .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.35),
                                                      Color(red: 0.76, green: 0.25, blue: 0.45),
                                                      Color(red: 0.23, green: 0.10, blue: 0.32)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 104, height: 104)
                        .overlay(Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 44)).foregroundColor(.white.opacity(0.55)))
                    Circle().fill(Color.black.opacity(0.9)).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                }
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(discAngle))
                .shadow(color: .black.opacity(0.6), radius: 22, y: 14)

                // 唱臂
                VStack(spacing: 0) {
                    Circle().fill(LinearGradient(colors: [.white, Color(white: 0.6)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 5, height: 66)
                }
                .rotationEffect(.degrees(22), anchor: .top)
                .offset(x: 108, y: -104)
            }
            .frame(height: 300)
        }
    }

    private var controls: some View {
        HStack {
            Image(systemName: "shuffle").font(.system(size: 18)).foregroundColor(.white.opacity(0.65))
            Spacer()
            Button { progress = max(0, progress - 0.05) } label: {
                Image(systemName: "backward.fill").font(.system(size: 24)).foregroundColor(.white)
            }
            Spacer()
            Button { playing.toggle() } label: {
                Circle().fill(Color.white).frame(width: 62, height: 62)
                    .overlay(Image(systemName: playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(red: 0.07, green: 0.06, blue: 0.09)))
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
            }
            Spacer()
            Button { progress = min(1, progress + 0.05) } label: {
                Image(systemName: "forward.fill").font(.system(size: 24)).foregroundColor(.white)
            }
            Spacer()
            Image(systemName: "list.bullet").font(.system(size: 18)).foregroundColor(.white.opacity(0.65))
        }
        .padding(.horizontal, 8)
    }
}
