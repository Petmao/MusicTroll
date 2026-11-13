import SwiftUI

struct IsleBrandMark: View {
    @State private var flow = false
    @State private var float = false
    @State private var flick = false

    private let pink = Color(red: 1.000, green: 0.373, blue: 0.620)
    private let lilac = Color(red: 0.769, green: 0.651, blue: 1.000)

    private var rainbow: [Color] {
        [Color(red: 1.00, green: 0.184, blue: 0.494),
         Color(red: 1.00, green: 0.561, blue: 0.749),
         Color(red: 1.00, green: 0.820, blue: 0.400),
         Color(red: 0.616, green: 1.00, blue: 0.561),
         Color(red: 0.263, green: 0.878, blue: 0.816),
         Color(red: 0.388, green: 0.643, blue: 1.00),
         lilac,
         Color(red: 1.00, green: 0.184, blue: 0.494)]
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [pink.opacity(0.22), .clear],
                                         center: .center, startRadius: 2, endRadius: 46))
                    .frame(width: 108, height: 108)

                IsleMark()
                    .frame(width: 64, height: 64)
                    .offset(y: float ? -3 : 0)
                    .scaleEffect(float ? 1.03 : 1.0)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: float)
            }
            .frame(height: 92)

            nameText.padding(.top, 20)

            HStack(spacing: 9) {
                hairline(fadeLeading: true)
                Text("ISLE")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(Color(red: 1, green: 0.816, blue: 0.886))
                hairline(fadeLeading: false)
            }
            .padding(.top, 11)

            Text(Config.tagline)
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .onAppear { flow = true; float = true; flick = true }
    }

    private var nameText: some View {
        let base = Text("屿声音乐")
            .font(.system(size: 36, weight: .black))
            .tracking(2)

        return base
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: rainbow, startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 3)
                        .offset(x: flow ? -geo.size.width * 2 : 0)
                        .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: flow)
                }
                .mask(base)
            }
            .opacity(flick ? 1.0 : 0.45)
            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: flick)
    }

    private func hairline(fadeLeading: Bool) -> some View {
        LinearGradient(colors: fadeLeading
                       ? [.clear, .white.opacity(0.55)]
                       : [.white.opacity(0.55), .clear],
                       startPoint: .leading, endPoint: .trailing)
            .frame(width: 26, height: 1)
    }
}

struct IsleMark: View {
    private var mainGrad: LinearGradient {
        LinearGradient(colors: [.white,
                                Color(red: 1, green: 0.816, blue: 0.886),
                                Color(red: 1, green: 0.373, blue: 0.620),
                                Color(red: 0.769, green: 0.651, blue: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var waveGrad: LinearGradient {
        LinearGradient(colors: [Color(red: 0.263, green: 0.878, blue: 0.816),
                                Color(red: 1, green: 0.561, blue: 0.749),
                                Color(red: 0.769, green: 0.651, blue: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        ZStack {
            IslandPath().stroke(mainGrad, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            WavePath().stroke(waveGrad, style: StrokeStyle(lineWidth: 2, lineCap: .round)).opacity(0.85)
            WavePath()
                .stroke(waveGrad, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .scaleEffect(0.86, anchor: .center)
                .offset(y: 6)
                .opacity(0.38)
            NotePath().stroke(mainGrad, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            NoteHead().offset(x: -4.6, y: 4.0).foregroundStyle(mainGrad)
            NoteHead().offset(x: 6.4, y: 1.3).foregroundStyle(mainGrad)
        }
        .shadow(color: Color(red: 1, green: 0.561, blue: 0.749).opacity(0.6), radius: 9)
        .shadow(color: Color(red: 1, green: 0.184, blue: 0.494).opacity(0.28), radius: 22)
    }
}

private struct IslandPath: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 64
        var p = Path()
        p.move(to: CGPoint(x: 10 * s, y: 44 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 28 * s), control: CGPoint(x: 19 * s, y: 31 * s))
        p.addQuadCurve(to: CGPoint(x: 54 * s, y: 44 * s), control: CGPoint(x: 45 * s, y: 31 * s))
        return p
    }
}

private struct WavePath: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 64
        var p = Path()
        p.move(to: CGPoint(x: 8 * s, y: 51 * s))
        for i in 0..<4 {
            let x = (8 + CGFloat(i) * 13) * s
            p.addQuadCurve(to: CGPoint(x: x + 13 * s, y: 51 * s), control: CGPoint(x: x + 6.5 * s, y: 45.5 * s))
        }
        return p
    }
}

private struct NotePath: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 64
        var p = Path()
        p.move(to: CGPoint(x: 30.5 * s, y: 37 * s))
        p.addLine(to: CGPoint(x: 30.5 * s, y: 17.5 * s))
        p.addLine(to: CGPoint(x: 41.5 * s, y: 14.7 * s))
        p.addLine(to: CGPoint(x: 41.5 * s, y: 34 * s))
        return p
    }
}

private struct NoteHead: View {
    var body: some View {
        Ellipse()
            .frame(width: 7.2, height: 6.2)
            .rotationEffect(.degrees(-14))
    }
}
