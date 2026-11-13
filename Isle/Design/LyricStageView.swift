import SwiftUI

/// 歌词态：就地展开，歌手名 + 版权行 + 时间轴歌词 + 动作条
struct LyricStageView: View {
    var lines: [LyricLine]
    var currentIndex: Int
    var artist: String
    var stateText: String
    var liked: Bool
    var expanded: Bool
    var onSeek: (Double) -> Void
    var onMore: () -> Void
    var onLike: () -> Void
    var onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(artist.isEmpty ? " " : artist)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.48))
                .padding(.top, 8)

            if lines.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    IsleIcon(IsleSymbol.lyric, scale: .hero, tint: Color.white.opacity(0.18))
                    Text(stateText.isEmpty ? "还没有歌词" : stateText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.34))
                }
                Spacer()
            } else {
                lyricScroll
            }

            actionBar
        }
    }

    private var lyricScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 19) {
                    creditBlock
                        .opacity(expanded ? 1 : 0)
                        .offset(y: expanded ? 0 : 14)
                        .animation(.easeOut(duration: 0.32), value: expanded)
                        .id(-1)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                        lyricRow(i, line)
                    }
                }
                .padding(.vertical, 130)
            }
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.24),
                    .init(color: .black, location: 0.76),
                    .init(color: .clear, location: 1.0)
                ], startPoint: .top, endPoint: .bottom)
            )
            .onChange(of: currentIndex) { idx in
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
            .onAppear {
                if currentIndex > 0 {
                    proxy.scrollTo(currentIndex, anchor: .center)
                }
            }
        }
    }

    private var creditBlock: some View {
        VStack(spacing: 4) {
            creditLine("作词：")
            creditLine("作曲：")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
    }

    private func creditLine(_ label: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.32))
            Text("—")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private func lyricRow(_ i: Int, _ line: LyricLine) -> some View {
        let active = i == currentIndex
        let delay = min(Double(i), 18) * 0.055

        return Button {
            onSeek(line.time)
        } label: {
            Text(line.text)
                .font(.system(size: active ? 18 : 14, weight: active ? .heavy : .regular))
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.32))
                .shadow(color: active ? Color.white.opacity(0.85) : .clear, radius: 11)
                .shadow(color: active ? Color(red: 1, green: 0.62, blue: 0.78).opacity(0.55) : .clear, radius: 22)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .opacity(expanded ? 1 : 0)
                .offset(y: expanded ? 0 : 14)
                .animation(.easeOut(duration: 0.32).delay(delay), value: expanded)
                .id(i)
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        HStack(spacing: 0) {
            Button(action: onMore) {
                ZStack {
                    Circle()
                        .stroke(PlayerTheme.ringStroke, lineWidth: 1)
                        .frame(width: 30, height: 30)
                    IsleIcon(IsleSymbol.more, scale: .sm, tint: Color.white.opacity(0.62))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 12) {
                Button(action: onLike) {
                    ZStack {
                        Circle()
                            .fill(liked ? PlayerTheme.like.opacity(0.08) : Color.clear)
                        Circle()
                            .stroke(liked ? PlayerTheme.like.opacity(0.55) : PlayerTheme.ringStroke,
                                    lineWidth: 1)
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundStyle(liked ? PlayerTheme.like : Color.white.opacity(0.62))
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)

                Button(action: onCollapse) {
                    ZStack {
                        Circle().stroke(PlayerTheme.ringStroke, lineWidth: 1)
                        IsleIcon(IsleSymbol.lyric, scale: .sm, tint: Color.white.opacity(0.62))
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
    }
}
