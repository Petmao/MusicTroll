import SwiftUI
import CoreImage
import UIKit

/// 封面取色，规则对齐 Cymusic（gyc-12/Cymusic, Apache-2.0）
/// src/hooks/usePlayerBackground.tsx：亮度上限 0.1、hex 六位、失败回落 #191b20、LRU 50。
struct PaletteColor: Equatable {
    let r: Double
    let g: Double
    let b: Double

    static let fallback = PaletteColor(r: 0x19 / 255.0,
                                      g: 0x1b / 255.0,
                                      b: 0x20 / 255.0)

    var color: Color { Color(red: r, green: g, blue: b) }

    func alpha(_ a: Double) -> Color { Color(red: r, green: g, blue: b, opacity: a) }

    var hex: String {
        String(format: "#%02x%02x%02x",
               Int((r * 255).rounded()),
               Int((g * 255).rounded()),
               Int((b * 255).rounded()))
    }
}

@MainActor
final class CymusicPalette: ObservableObject {
    static let shared = CymusicPalette()

    static let maxLuminance: Double = 0.1
    static let cacheLimit = 50

    @Published private var table: [String: PaletteColor] = [:]
    private var order: [String] = []
    private var running: Set<String> = []

    func color(for uri: String?) -> Color { value(for: uri).color }

    func value(for uri: String?) -> PaletteColor {
        guard let uri, !uri.isEmpty else { return .fallback }
        return table[uri] ?? .fallback
    }

    func prime(_ uri: String?) {
        guard let uri, !uri.isEmpty else { return }
        if table[uri] != nil { bump(uri); return }
        guard !running.contains(uri) else { return }
        running.insert(uri)

        Task { [weak self] in
            let parsed = await Self.extract(uri)
            guard let self else { return }
            await MainActor.run {
                self.store(uri, parsed)
                self.running.remove(uri)
            }
        }
    }

    private func store(_ uri: String, _ c: PaletteColor) {
        table[uri] = c
        bump(uri)
        while order.count > Self.cacheLimit, let oldest = order.first {
            order.removeFirst()
            table.removeValue(forKey: oldest)
        }
    }

    private func bump(_ uri: String) {
        order.removeAll { $0 == uri }
        order.append(uri)
    }

    private static func extract(_ uri: String) async -> PaletteColor {
        guard let url = URL(string: uri),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = CIImage(data: data),
              image.extent.width > 0, image.extent.height > 0 else {
            return .fallback
        }
        return average(of: image)
    }

    private static func average(of image: CIImage) -> PaletteColor {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return .fallback }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
        guard let out = filter.outputImage else { return .fallback }

        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CIContext(options: [.workingColorSpace: NSNull()])
        ctx.render(out,
                   toBitmap: &px,
                   rowBytes: 4,
                   bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: nil)
        return normalize(Double(px[0]), Double(px[1]), Double(px[2]))
    }

    static func normalize(_ r: Double, _ g: Double, _ b: Double) -> PaletteColor {
        func linear(_ c: Double) -> Double {
            let v = c / 255.0
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        func luminance(scaledBy k: Double) -> Double {
            linear(r * k) * 0.2126 + linear(g * k) * 0.7152 + linear(b * k) * 0.0722
        }

        var scale = 1.0
        if luminance(scaledBy: 1) > maxLuminance {
            var lower = 0.0
            var upper = 1.0
            for _ in 0..<12 {
                let mid = (lower + upper) / 2
                if luminance(scaledBy: mid) > maxLuminance { upper = mid } else { lower = mid }
            }
            scale = lower
        }

        return PaletteColor(r: floor(r * scale) / 255.0,
                            g: floor(g * scale) / 255.0,
                            b: floor(b * scale) / 255.0)
    }
}
