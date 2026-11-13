import SwiftUI

/// 控制区：五项均分，播放键是纯三角 22 × 28，无白圆底无描边
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
                IsleIcon(IsleSymbol.shuffle, scale: .md, tint: PlayerTheme.ctrlMid)
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
                IsleIcon("list.bullet", scale: .md, tint: PlayerTheme.ctrlMid)
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
