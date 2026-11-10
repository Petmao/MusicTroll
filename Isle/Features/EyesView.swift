import SwiftUI
import AVFoundation

/// 养眼：纯全屏，上下滑切换，无图标
struct EyesView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var sources: [SourceItem] = []
    @State private var index = 0
    @State private var loading = true
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if loading {
                ProgressView().tint(.white)
            } else if sources.isEmpty {
                emptyState
            } else {
                videoLayer
            }
        }
        .task { await load() }
    }

    // MARK: 空状态
    private var emptyState: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 1, green: 0.37, blue: 0.62).opacity(0.35), .clear],
                           center: .center, startRadius: 10, endRadius: 260)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Text("请到设置里面设置视频源")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Text("开启新视界哟")
                    .font(.system(size: 24, weight: .heavy)).tracking(1)
                    .foregroundColor(Color(red: 1, green: 0.62, blue: 0.72))
                Capsule()
                    .fill(LinearGradient(colors: [.clear, Color(red: 1, green: 0.37, blue: 0.62), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 34, height: 2).padding(.vertical, 8)
                NavigationLink(destination: SourcesView(kind: "video")) {
                    Text("去设置")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 22).padding(.vertical, 11)
                        .background(Color.white.opacity(0.10))
                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
                Text("我的 → 视频源 → 添加").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.3)).padding(.top, 6)
            }
        }
        .wrapInNavigation()
    }

    // MARK: 播放层
    private var videoLayer: some View {
        ZStack {
            if let player = player {
                VideoSurface(player: player).ignoresSafeArea()
            } else {
                // 源不是直链视频时的占位
                VStack(spacing: 8) {
                    Image(systemName: "film").font(.system(size: 34)).foregroundColor(.white.opacity(0.4))
                    Text(sources[min(index, sources.count - 1)].name)
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                    Text("该源不是直链视频").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.35))
                }
            }

            // 页码提示（极淡）
            VStack {
                Spacer()
                Text("\(index + 1) / \(sources.count)　上滑下一个")
                    .font(.system(size: 10)).tracking(1)
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { v in
                    if v.translation.height < -60 { next() }
                    else if v.translation.height > 60 { prev() }
                }
        )
        .onTapGesture { toggle() }
    }

    // MARK: 逻辑
    private func load() async {
        loading = true
        sources = (try? await APIClient.shared.sources(kind: "video")) ?? []
        loading = false
        if !sources.isEmpty { prepare(0) }
    }

    private func prepare(_ i: Int) {
        guard !sources.isEmpty else { return }
        index = max(0, min(i, sources.count - 1))
        guard let url = URL(string: sources[index].url),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            player = nil; return
        }
        let p = AVPlayer(url: url)
        player = p
        p.play()
    }

    private func next() { prepare(index + 1) }
    private func prev() { prepare(index - 1) }
    private func toggle() { player?.timeControlStatus == .playing ? player?.pause() : player?.play() }
}

/// AVPlayerLayer 包装
struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.backgroundColor = .black
        v.playerLayer.videoGravity = .resizeAspect
        v.playerLayer.player = player
        return v
    }
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

extension View {
    /// 给空状态包一层 NavigationView，保证 NavigationLink 能用
    func wrapInNavigation() -> some View {
        NavigationView { self }.navigationViewStyle(StackNavigationViewStyle())
    }
}
