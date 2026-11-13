import SwiftUI

struct PlayerProgressView: View {
    var progress: Double
    var buffer: Double
    var elapsed: String
    var total: String
    var quality: String
    var onScrub: (Double) -> Void

    @State private var dragging: Double?

    private var value: Double { dragging ?? progress }

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { g in
                let w = max(1, g.size.width)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PlayerTheme.track)
                        .frame(height: 2)

                    Capsule()
                        .fill(PlayerTheme.buffer)
                        .frame(width: w * min(1, max(0, buffer)), height: 2)

                    Capsule()
                        .fill(PlayerTheme.knob)
                        .frame(width: w * min(1, max(0, value)), height: 2)

                    Circle()
                        .fill(PlayerTheme.bufferDot)
                        .frame(width: 5, height: 5)
                        .offset(x: w * min(1, max(0, buffer)) - 2.5)

                    Circle()
                        .fill(PlayerTheme.knob)
                        .frame(width: 7, height: 7)
                        .shadow(color: Color.black.opacity(0.32), radius: 1, y: 0.5)
                        .offset(x: w * min(1, max(0, value)) - 3.5)
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            dragging = min(1, max(0, v.location.x / w))
                        }
                        .onEnded { v in
                            let r = min(1, max(0, v.location.x / w))
                            dragging = nil
                            onScrub(r)
                        }
                )
            }
            .frame(height: 14)

            HStack {
                Text(elapsed)
                    .font(.system(size: 9))
                    .foregroundStyle(PlayerTheme.textLow)
                Spacer()
                Text(quality)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PlayerTheme.quality)
                Spacer()
                Text(total)
                    .font(.system(size: 9))
                    .foregroundStyle(PlayerTheme.textLow)
            }
        }
        .padding(.horizontal, 23)
    }
}

struct PlayerSocialView: View {
    var likes: Int
    var comments: Int
    var liked: Bool
    var onLike: () -> Void
    var onComment: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            VStack(spacing: 2) {
                Button(action: onLike) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(liked ? PlayerTheme.like : PlayerTheme.social)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)

                Text("\(likes)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PlayerTheme.socialNum)
            }

            VStack(spacing: 2) {
                Button(action: onComment) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundStyle(PlayerTheme.social)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)

                Text("\(comments)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PlayerTheme.socialNum)
            }
        }
    }
}

struct PlayerControlsView: View {
    var isPlaying: Bool
    var onShuffle: () -> Void
    var onPrev: () -> Void
    var onPlayPause: () -> Void
    var onNext: () -> Void
    var onQueue: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onShuffle) {
                IsleIcon(IsleSymbol.shuffle, scale: .lg, tint: PlayerTheme.ctrlMid)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button(action: onPrev) {
                IsleIcon(IsleSymbol.prev, scale: .xl, tint: PlayerTheme.textHi)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button(action: onPlayPause) {
                playGlyph
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                IsleIcon(IsleSymbol.next, scale: .xl, tint: PlayerTheme.textHi)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Button(action: onQueue) {
                IsleIcon("list.bullet", scale: .lg, tint: PlayerTheme.ctrlMid)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 45)
        .padding(.horizontal, 23)
    }

    @ViewBuilder
    private var playGlyph: some View {
        if isPlaying {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(PlayerTheme.playTri)
                    .frame(width: 6, height: 28)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(PlayerTheme.playTri)
                    .frame(width: 6, height: 28)
            }
            .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
        } else {
            PlayTriangle()
                .fill(PlayerTheme.playTri)
                .frame(width: 22, height: 28)
                .offset(x: 4)
                .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
        }
    }
}

struct PlayTriangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: r.width, y: r.height / 2))
        p.addLine(to: CGPoint(x: 0, y: r.height))
        p.closeSubpath()
        return p
    }
}
