import SwiftUI

/// 社交区：空心心形 24 pt + 气泡 23 pt，数字 9 pt
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
