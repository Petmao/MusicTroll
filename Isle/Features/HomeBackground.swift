import SwiftUI
import UIKit

/// 首页背景：已关闭网络图，改为纯深色渐变 + 网格（稳定、不耗流量）
@MainActor
final class HomeBackground: ObservableObject {
    static let shared = HomeBackground()
    @Published var image: UIImage?

    func refresh() async {
        // 网络背景已停用
    }

    func clear() {
        image = nil
    }
}

struct HomeBackgroundView: View {
    @ObservedObject private var bg = HomeBackground.shared

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.055, green: 0.07, blue: 0.11),
                                    Color(red: 0.02, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)

            // 顶部青光雾
            RadialGradient(colors: [Color(red: 0, green: 0.72, blue: 1).opacity(0.16), .clear],
                           center: UnitPoint(x: 0.18, y: 0.05),
                           startRadius: 10, endRadius: 320)
            // 底部紫光雾
            RadialGradient(colors: [Color(red: 0.55, green: 0.31, blue: 1).opacity(0.14), .clear],
                           center: UnitPoint(x: 0.88, y: 0.92),
                           startRadius: 10, endRadius: 300)

            // 网格
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
                .stroke(Color(red: 0, green: 0.84, blue: 1).opacity(0.055), lineWidth: 0.5)
                .mask(LinearGradient(colors: [.clear, .black, .black],
                                     startPoint: .top, endPoint: .bottom))
            }
        }
        .ignoresSafeArea()
    }
}
