import SwiftUI

/// 唱臂：148 × 105 pt，白色弯杆 7 pt，高光 3 pt，唱头 29 × 14 pt，默认旋转 10°
struct TonearmView: View {
    var lifted: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 转轴底座
            Circle()
                .fill(LinearGradient(colors: [PlayerTheme.armBody, Color(white: 0.62)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 23, height: 23)
                .overlay(Circle().stroke(Color.black.opacity(0.22), lineWidth: 0.8))
                .offset(x: -45, y: 0)

            // 杆身
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(PlayerTheme.armBody)
                .frame(width: 7, height: 92)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(PlayerTheme.armHi)
                        .frame(width: 3, height: 86)
                        .offset(x: 1.4, y: -2)
                }
                .offset(x: -52, y: 10)

            // 唱头
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(LinearGradient(colors: [PlayerTheme.armBody, Color(white: 0.70)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 29, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Color.black.opacity(0.18), lineWidth: 0.6))
                .offset(x: -54, y: 96)
        }
        .frame(width: 148, height: 105, alignment: .topTrailing)
        .shadow(color: Color.black.opacity(0.26), radius: 2, x: 1, y: 2)
        .rotationEffect(.degrees(lifted ? 22 : 10), anchor: .topTrailing)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: lifted)
    }
}
