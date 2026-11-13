import SwiftUI

enum IsleColor {
    static let pink       = Color(red: 1.000, green: 0.373, blue: 0.620)
    static let pinkLight  = Color(red: 1.000, green: 0.561, blue: 0.749)
    static let pinkDeep   = Color(red: 1.000, green: 0.184, blue: 0.494)
    static let lilac      = Color(red: 0.769, green: 0.651, blue: 1.000)
    static let mint       = Color(red: 0.263, green: 0.878, blue: 0.816)
    static let gold       = Color(red: 0.941, green: 0.804, blue: 0.553)
    static let goldDeep   = Color(red: 0.835, green: 0.643, blue: 0.365)

    static let surface    = Color.white.opacity(0.055)
    static let surfaceHi  = Color.white.opacity(0.075)
    static let line       = Color.white.opacity(0.10)
    static let textSub    = Color.white.opacity(0.55)
    static let textFaint  = Color.white.opacity(0.35)

    static let bg = LinearGradient(
        colors: [Color(red: 0.106, green: 0.039, blue: 0.090),
                 Color(red: 0.039, green: 0.020, blue: 0.039),
                 Color(red: 0.031, green: 0.016, blue: 0.031)],
        startPoint: .top, endPoint: .bottom)

    static let accent = LinearGradient(
        colors: [pinkLight, pink, pinkDeep],
        startPoint: .leading, endPoint: .trailing)
}

struct IsleBackground: View {
    var body: some View {
        ZStack {
            IsleColor.bg
            RadialGradient(colors: [IsleColor.pink.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.82, y: 0.02),
                           startRadius: 4, endRadius: 320)
            RadialGradient(colors: [IsleColor.lilac.opacity(0.12), .clear],
                           center: UnitPoint(x: 0.05, y: 0.10),
                           startRadius: 4, endRadius: 260)
        }
        .ignoresSafeArea()
    }
}

struct IsleCard<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(IsleColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(IsleColor.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct IslePill: View {
    let text: String
    var active: Bool = false
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? Color.white : (tint ?? IsleColor.textSub))
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                Group {
                    if active { IsleColor.accent }
                    else { IsleColor.surface }
                }
            )
            .clipShape(Capsule())
    }
}

struct IslePageTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 22, weight: .heavy))
            if let subtitle {
                Text(subtitle).font(.system(size: 12)).foregroundStyle(IsleColor.textSub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
