import SwiftUI
import UIKit

/// 首页背景：纯深色渐变 + 网格（已停止使用网络图）
@MainActor
final class HomeBackground: ObservableObject {
    static let shared = HomeBackground()
    @Published var image: UIImage?

    func refresh() async { }

    func clear() {
        image = nil
    }
}

struct HomeBackgroundView: View {
    @ObservedObject private var bg = HomeBackground.shared

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.106, green: 0.039, blue: 0.090),
                                    Color(red: 0.039, green: 0.020, blue: 0.039),
                                    Color(red: 0.031, green: 0.016, blue: 0.031)],
                           startPoint: .top, endPoint: .bottom)

            RadialGradient(colors: [IsleColor.pink.opacity(0.26), .clear],
                           center: UnitPoint(x: 0.18, y: 0.05),
                           startRadius: 10, endRadius: 320)

            RadialGradient(colors: [IsleColor.lilac.opacity(0.16), .clear],
                           center: UnitPoint(x: 0.88, y: 0.92),
                           startRadius: 10, endRadius: 300)

            GeometryReader { g in
                Path { p in
                    let step: CGFloat = 26
                    var x: CGFloat = 0
                    while x < g.size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: g.size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < g.size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: g.size.width, y: y))
                        y += step
                    }
                }
                .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }
}
