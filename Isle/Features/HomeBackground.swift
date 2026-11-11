import SwiftUI
import UIKit

/// 首页随机背景图：二次元/清新随机壁纸，本地缓存
@MainActor
final class HomeBackground: ObservableObject {
    static let shared = HomeBackground()

    @Published var image: UIImage?
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("home-bg.jpg")
    }()

    private let sources = [
        "https://www.loliapi.com/acg/pc/",
        "https://api.btstu.cn/sjbz/api.php?lx=dongman&format=images",
        "https://api.btstu.cn/sjbz/api.php?lx=meizi&format=images"
    ]

    init() { loadCache() }

    private func loadCache() {
        if let d = try? Data(contentsOf: fileURL), let img = UIImage(data: d) {
            image = img
        }
    }

    /// 随机换一张（失败保留旧图）
    func refresh() async {
        for base in sources.shuffled() {
            var urlString = base
            if urlString.contains("?") { urlString += "&t=\(Int(Date().timeIntervalSince1970))" }
            else { urlString += "?t=\(Int(Date().timeIntervalSince1970))" }
            guard let url = URL(string: urlString) else { continue }

            var req = URLRequest(url: url, timeoutInterval: 18)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let img = UIImage(data: data), data.count > 20_000 else { continue }

            image = img
            try? data.write(to: fileURL)
            return
        }
    }
}

/// 铺满屏幕的背景 + 暗纱 + 网格
struct HomeBackgroundView: View {
    @ObservedObject private var bg = HomeBackground.shared

    var body: some View {
        ZStack {
            if let img = bg.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 1.2)
                    .overlay(Color.black.opacity(0.42))
            } else {
                LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.10),
                                        Color(red: 0.02, green: 0.03, blue: 0.05)],
                               startPoint: .top, endPoint: .bottom)
            }

            // 上下暗纱：上重下重、中间透，保证文字可读
            LinearGradient(stops: [
                .init(color: .black.opacity(0.80), location: 0.0),
                .init(color: .black.opacity(0.48), location: 0.28),
                .init(color: .black.opacity(0.66), location: 0.62),
                .init(color: Color(red: 0.02, green: 0.02, blue: 0.03).opacity(0.96), location: 1.0)
            ], startPoint: .top, endPoint: .bottom)

            // 网格
            GeometryReader { g in
                Path { p in
                    let step: CGFloat = 26
                    var x: CGFloat = 0
                    while x < g.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: g.size.height)); x += step }
                    var y: CGFloat = 0
                    while y < g.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y)); y += step }
                }
                .stroke(Color(red: 0, green: 0.84, blue: 1).opacity(0.05), lineWidth: 0.5)
                .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            }
        }
        .ignoresSafeArea()
        .task {
            if bg.image == nil { await bg.refresh() }
        }
    }
}
