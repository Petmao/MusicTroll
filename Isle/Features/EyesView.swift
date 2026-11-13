import SwiftUI
import AVFoundation

struct EyesView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var sources: [SourceItem] = []
    @State private var loading = true
    @State private var index = 0
    @State private var queuePlayer: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else if sources.isEmpty {
                emptyState
            } else if queuePlayer != nil {
                VideoSurface(player: queuePlayer!)
                    .ignoresSafeArea()
                    .offset(y: dragOffset)
            } else {
                notDirectLink
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { v in
                    dragOffset = v.translation.height * 0.35
                }
                .onEnded { v in
                    withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    if v.translation.height < -60 { step(1) }
                    else if v.translation.height > 60 { step(-1) }
                }
        )
        .onTapGesture {
            guard let p = queuePlayer else { return }
            p.timeControlStatus == .playing ? p.pause() : p.play()
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
            IsleColor.bg.ignoresSafeArea()
            RadialGradient(colors: [IsleColor.pink.opacity(0.32), .clear],
                           center: .center, startRadius: 10, endRadius: 260)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [IsleColor.pink.opacity(0.22), .clear],
                                             center: .center, startRadius: 2, endRadius: 62))
                        .frame(width: 132, height: 132)
                    IsleIcon(IsleSymbol.video, scale: .hero, tint: IsleColor.pinkLight)
                }

                Text("请到设置里面设置视频源")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .padding(.top, 4)

                Text("开启新视界哟")
                    .font(.system(size: 24, weight: .heavy)).tracking(1)
                    .foregroundStyle(
                        LinearGradient(colors: [IsleColor.pinkLight, IsleColor.lilac],
                                       startPoint: .leading, endPoint: .trailing)
                    )

                Capsule()
                    .fill(LinearGradient(colors: [.clear, IsleColor.pink, .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 34, height: 2).padding(.vertical, 8)

                if auth.ent.canManageSources {
                    NavigationLink(destination: VideoSourceSettingsView()) {
                        Text("去设置")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 22).padding(.vertical, 11)
                            .background(Color.white.opacity(0.10))
                            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                } else {
                    Text("暂无可用视频，稍后再试")
                        .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.4))
                }
            }
        }
        .wrapInNavigation()
    }

    private var notDirectLink: some View {
        VStack(spacing: 10) {
            IsleIcon(IsleSymbol.video, scale: .hero, tint: Color.white.opacity(0.4))
            Text(sources[min(index, sources.count - 1)].name)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.8))
            Text("该源不是直链视频").font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.35))
        }
    }

    private func load() async {
        loading = true
        sources = (try? await APIClient.shared.sources(kind: "video")) ?? []
        loading = false
        prepare(0)
    }

    private func step(_ delta: Int) {
        guard !sources.isEmpty else { return }
        let next = (index + delta + sources.count) % sources.count
        prepare(next)
    }

    private func prepare(_ i: Int) {
        guard !sources.isEmpty else { return }
        index = max(0, min(i, sources.count - 1))
        let src = sources[index]
        queuePlayer?.pause()
        looper = nil
        queuePlayer = nil

        guard let url = URL(string: src.url),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else { return }

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
