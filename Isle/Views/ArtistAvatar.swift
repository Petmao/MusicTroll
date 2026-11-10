import SwiftUI
import UIKit

/// 歌手头像：网络图 → 骨架加载 → 首字母渐变兜底
struct ArtistAvatar: View {
    let name: String
    var urlString: String? = nil
    var size: CGFloat = 42

    @State private var image: UIImage?
    @State private var loading = false

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img).resizable().scaledToFill()
            } else if loading {
                LinearGradient(colors: [Color(white: 0.11), Color(white: 0.18), Color(white: 0.11)],
                               startPoint: .leading, endPoint: .trailing)
            } else {
                gradient
                    .overlay(Text(String(name.prefix(1)))
                                .font(.system(size: size * 0.4, weight: .heavy))
                                .foregroundColor(.white))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .task(id: urlString) { await load() }
    }

    private var gradient: some ShapeStyle {
        let i = abs(name.hashValue) % 4
        let pairs: [[Color]] = [
            [Color(red: 1, green: 0.62, blue: 0.35), Color(red: 0.76, green: 0.25, blue: 0.45)],
            [Color(red: 0.48, green: 0.36, blue: 1), Color(red: 0, green: 0.83, blue: 1)],
            [Color(red: 0, green: 0.88, blue: 0.64), Color(red: 0, green: 0.64, blue: 1)],
            [Color(red: 1, green: 0.82, blue: 0.25), Color(red: 1, green: 0.18, blue: 0.47)]
        ]
        return LinearGradient(colors: pairs[i], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func load() async {
        guard let s = urlString, let url = URL(string: s), !s.isEmpty else { image = nil; return }
        if let cached = Self.cache.object(forKey: s as NSString) { image = cached; return }
        loading = true
        defer { loading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                Self.cache.setObject(img, forKey: s as NSString)
                image = img
            }
        } catch { image = nil }
    }
}
