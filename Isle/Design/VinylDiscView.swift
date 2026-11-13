import SwiftUI

/// 唱片：302 × 302 圆盘，内嵌 280 黑胶，同心纹理 1pt / 1.5pt 交替，封面 192 圆，9 秒一圈
struct VinylDiscView: View {
    var angle: Double
    var title: String
    var size: CGFloat = 302

    private var discSize: CGFloat { size - 22 }
    private var coverSize: CGFloat { size * 0.636 }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [PlayerTheme.discBase,
                                              PlayerTheme.discBase.opacity(0.75),
                                              PlayerTheme.bgOuter],
                                     center: UnitPoint(x: 0.38, y: 0.30),
                                     startRadius: 6, endRadius: size * 0.62))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.05), lineWidth: 1))

            ZStack {
                Circle()
                    .fill(PlayerTheme.groove1)
                    .frame(width: discSize, height: discSize)

                ForEach(0..<66, id: \.self) { i in
                    let scale = 1.0 - CGFloat(i) * 0.0070
                    Circle()
                        .stroke(i % 2 == 0 ? PlayerTheme.groove1 : PlayerTheme.groove2,
                                lineWidth: i % 3 == 0 ? 1.5 : 1.0)
                        .frame(width: discSize * scale, height: discSize * scale)
                }

                cover
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.92), lineWidth: 1))
                    .rotationEffect(.degrees(angle))

                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 7, height: 7)
            }
            .frame(width: discSize, height: discSize)
            .clipShape(Circle())
        }
        .frame(width: size, height: size)
    }

    // 自绘街景封面：暖色渐变 + 楼宇剪影 + 标题
    private var cover: some View {
        ZStack {
            LinearGradient(colors: [PlayerTheme.coverWarm.opacity(0.95),
                                    Color(red: 0.62, green: 0.38, blue: 0.20),
                                    Color(red: 0.36, green: 0.20, blue: 0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            GeometryReader { g in
                let w = g.size.width
                let h = g.size.height
                ZStack(alignment: .bottom) {
                    // 天空光斑
                    Circle()
                        .fill(Color(red: 1, green: 0.96, blue: 0.86).opacity(0.35))
                        .frame(width: w * 0.30, height: w * 0.30)
                        .position(x: w * 0.30, y: h * 0.32)
                        .blur(radius: 8)

                    // 楼群
                    HStack(alignment: .bottom, spacing: w * 0.02) {
                        bar(w: w * 0.16, h: h * 0.34)
                        bar(w: w * 0.12, h: h * 0.48)
                        bar(w: w * 0.18, h: h * 0.28)
                        bar(w: w * 0.10, h: h * 0.40)
                        bar(w: w * 0.14, h: h * 0.22)
                    }
                    .padding(.bottom, h * 0.18)

                    // 地面
                    Rectangle()
                        .fill(Color(red: 0.24, green: 0.13, blue: 0.08).opacity(0.85))
                        .frame(height: h * 0.20)
                }
            }

            Text(title)
                .font(.system(size: coverSize * 0.13, weight: .heavy))
                .tracking(2)
                .foregroundStyle(PlayerTheme.coverText)
                .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
        }
    }

    private func bar(w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color(red: 0.20, green: 0.11, blue: 0.07).opacity(0.78))
            .frame(width: w, height: h)
    }
}
