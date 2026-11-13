import SwiftUI

/// 进度条：2 pt 轨道 + 缓冲段 + 7 pt 播放头 + 5 pt 缓冲点 + 三分时间行
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
