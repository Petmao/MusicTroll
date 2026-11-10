import SwiftUI
import AVFoundation

/// 养眼：全屏占满，不滑动，单条循环播放
struct EyesView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var sources: [SourceItem] = []
    @State private var loading = true
    @State private var queuePlayer: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else if sources.isEmpty {
                emptyState
            } else if let qp = queuePlayer {
                VideoSurface(player: qp)
                    .ignoresSafeArea()
            } else {
                notDirectLink
            }
        }
        .task { await load() }
        .onDisappear {
            queuePlayer?.pause()
            looper = nil
            queuePlayer = nil
        }
    }

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
                NavigationLink(destination: VideoSourceSettingsView()) {
                    Text("去设置")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 22).padding(.vertical, 11)
                        .background(Color.white.opacity(0.10))
                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
                Text("我的 → 设置 → 视频源").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.3)).padding(.top, 6)
            }
        }
        .wrapInNavigation()
    }

    private var notDirectLink: some View {
        VStack(spacing: 8) {
            Image(systemName: "film").font(.system(size: 34)).foregroundColor(.white.opacity(0.4))
            Text(sources.first?.name ?? "视频源").font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            Text("该源不是直链视频").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.35))
        }
    }

    private func load() async {
        loading = true
        sources = (try? await APIClient.shared.sources(kind: "video")) ?? []
        loading = false
        prepare()
    }

    /// 单条循环：AVQueuePlayer + AVPlayerLooper，无滑动、无缝续播
    private func prepare() {
        guard let first = sources.first,
              let url = URL(string: first.url),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            queuePlayer = nil
            return
        }
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 3
        let qp = AVQueuePlayer()
        qp.automaticallyWaitsToMinimizeStalling = false
        qp.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: qp, templateItem: item)
        queuePlayer = qp
        qp.play()
    }
}

/// AVPlayerLayer 包装（铺满，不拉伸变形）
struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.backgroundColor = .black
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.player = player
        return v
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.videoGravity = .resizeAspectFill
        uiView.playerLayer.player = player
    }
}

final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

extension View {
    func wrapInNavigation() -> some View {
        NavigationView { self }.navigationViewStyle(StackNavigationViewStyle())
    }
}
