import SwiftUI

/// 播放器专用色板（按 1:1 设计稿）
enum PlayerTheme {
    // 背景三段
    static let bgTop    = Color(red: 0.286, green: 0.282, blue: 0.231)   // #49483B
    static let bgMid    = Color(red: 0.204, green: 0.212, blue: 0.173)   // #34362C
    static let bgOuter  = Color(red: 0.098, green: 0.106, blue: 0.086)   // #191B16

    // 文字三级
    static let textHi   = Color(red: 0.878, green: 0.882, blue: 0.855)   // #E0E1DA
    static let textMid  = Color(red: 0.529, green: 0.545, blue: 0.502)   // #878B80
    static let textLow  = Color(red: 0.443, green: 0.463, blue: 0.416)   // #71766A

    // 辅助
    static let faint    = Color(red: 0.573, green: 0.584, blue: 0.545)   // #92958B
    static let quality  = Color(red: 0.573, green: 0.588, blue: 0.541)   // #92968A
    static let badgeBg  = Color.white.opacity(0.09)
    static let badgeText = Color(red: 0.596, green: 0.608, blue: 0.565)  // #989B90

    // 进度
    static let track    = Color(red: 0.282, green: 0.294, blue: 0.259)   // #484B42
    static let buffer   = Color(red: 0.384, green: 0.400, blue: 0.353)   // #62665A
    static let knob     = Color(red: 0.898, green: 0.902, blue: 0.875)   // #E5E6DF
    static let bufferDot = Color(red: 0.843, green: 0.851, blue: 0.812)  // #D7D9CF

    // 控制
    static let playTri  = Color(red: 0.694, green: 0.706, blue: 0.667)   // #B1B4AA
    static let ctrlMid  = Color(red: 0.663, green: 0.675, blue: 0.635)
    static let social   = Color(red: 0.663, green: 0.675, blue: 0.635)   // #A9ACA1
    static let socialNum = Color(red: 0.667, green: 0.678, blue: 0.635)  // #AAADA2

    // 唱片
    static let discBase = Color(red: 0.231, green: 0.239, blue: 0.220)   // #3B3D38
    static let groove1  = Color(red: 0.071, green: 0.078, blue: 0.067)   // #121411
    static let groove2  = Color(red: 0.102, green: 0.110, blue: 0.094)   // #1A1C18

    // 唱臂
    static let armBody  = Color(red: 0.902, green: 0.906, blue: 0.875)   // #E6E7DF
    static let armHi    = Color.white.opacity(0.85)

    // 封面
    static let coverWarm = Color(red: 0.827, green: 0.588, blue: 0.333)  // #D39655
    static let coverText = Color(red: 1.000, green: 0.957, blue: 0.855)  // #FFF4DA

    // Home 指示条
    static let homeBar  = Color(red: 0.871, green: 0.875, blue: 0.847)   // #DEDFD8

    // 收藏红
    static let like     = Color(red: 1.0, green: 0.20, blue: 0.333)      // #FF3355

    static let bg = LinearGradient(colors: [bgTop, bgMid, bgOuter],
                                   startPoint: .top, endPoint: .bottom)

    static let ringStroke = Color.white.opacity(0.22)
}

struct PlayerBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [PlayerTheme.bgTop,
                                    PlayerTheme.bgMid,
                                    PlayerTheme.bgOuter],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.639, green: 0.561, blue: 0.376).opacity(0.08), .clear],
                           center: UnitPoint(x: 0.5, y: 0.36),
                           startRadius: 20, endRadius: 300)
        }
        .ignoresSafeArea()
    }
}
