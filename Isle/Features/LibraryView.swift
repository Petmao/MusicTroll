import SwiftUI

/// 收藏与歌单（按设计稿：深色、彩色封面行、批量管理）
struct LibraryView: View {
    @ObservedObject private var fav = FavoritesStore.shared
    @State private var playlists: [String] = ["我喜欢的音乐", "夜跑 DJ 循环", "通勤白噪"]
    @State private var newName = ""
    @State private var showNew = false
    @State private var tab = 0

    private let tabs = ["收藏", "歌单", "本地"]
    private let covers: [LinearGradient] = [
        LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47), Color(red: 1, green: 0.54, blue: 0)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.48, green: 0.36, blue: 1), Color(red: 0, green: 0.83, blue: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.25), Color(red: 1, green: 0.42, blue: 0)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0, green: 0.88, blue: 0.64), Color(red: 0, green: 0.64, blue: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.04, blue: 0.19),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(0..<tabs.count, id: \.self) { i in
                            Button { tab = i } label: {
                                Text(tabs[i])
                                    .font(.system(size: 12, weight: tab == i ? .bold : .regular))
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(tab == i
                                                ? AnyView(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                                                  Color(red: 1, green: 0.48, blue: 0.18)],
                                                                         startPoint: .leading, endPoint: .trailing))
                                                : AnyView(Color.white.opacity(0.06)))
                                    .clipShape(Capsule())
                                    .foregroundColor(tab == i ? .white : .white.opacity(0.6))
                            }
                        }
                        Spacer()
                    }

                    sectionHeader("收藏歌曲 · \(fav.items.count) 首")
                    if fav.items.isEmpty {
                        Text("还没有收藏。播放器里点 ♡ 就会出现在这里")
                            .font(.system(size: 11.5)).foregroundColor(.white.opacity(0.35))
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(fav.items.enumerated()), id: \.offset) { idx, s in
                                HStack(spacing: 11) {
                                    RoundedRectangle(cornerRadius: 11)
                                        .fill(covers[idx % covers.count])
                                        .frame(width: 40, height: 40)
                                        .overlay(Image(systemName: "music.note")
                                                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.85)))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(s.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                                        Text(s.artist).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 14)).foregroundColor(Color(red: 1, green: 0.37, blue: 0.62))
                                }
                                .padding(.vertical, 9)
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }

                    sectionHeader("我的歌单")
                    VStack(spacing: 0) {
                        ForEach(Array(playlists.enumerated()), id: \.offset) { idx, name in
                            HStack(spacing: 11) {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(covers[(idx + 1) % covers.count])
                                    .frame(width: 40, height: 40)
                                    .overlay(Image(systemName: "music.note.list")
                                                .font(.system(size: 14)).foregroundColor(.white.opacity(0.9)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(name).font(.system(size: 13.5, weight: .semibold))
                                    Text("可同步到云端").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.4))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.vertical, 9)
                            Divider().background(Color.white.opacity(0.05))
                        }
                        Button { showNew = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                Text("新建歌单")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 1, green: 0.45, blue: 0.65))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                        }
                    }

                    Text("批量管理（全选 / 移出 / 加入其他歌单）会在下个版本加上。")
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.25))
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16).padding(.top, 10)
            }
        }
        .navigationTitle("收藏与歌单")
        .navigationBarTitleDisplayMode(.inline)
        .alert("新建歌单", isPresented: $showNew) {
            TextField("歌单名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") {
                let n = newName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { playlists.append(n) }
                newName = ""
            }
        }
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t).font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.55))
    }
}

/// 全屏歌词（按设计稿：顶部小封面、居中高亮、底部工具栏）
struct LyricsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = MusicEngine.shared
    @State private var current = 3
    @State private var fontSize: CGFloat = 20

    private let lines = [
        "街角的路灯还亮着", "风把从前吹回来", "把耳机调到最大声",
        "我坠落在这片星空里", "找不到你来过的痕迹", "如果光也会怕黑",
        "那就让我替你失眠", "这段路我走了很久", "还是没有走到你身边"
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.05, blue: 0.22),
                                    Color(red: 0.07, green: 0.04, blue: 0.12),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 17)).foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.62),
                                                          Color(red: 0.48, green: 0.36, blue: 1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(engine.current?.title ?? "未播放")
                                .font(.system(size: 11, weight: .semibold)).lineLimit(1)
                            Text(engine.current?.artist ?? "-")
                                .font(.system(size: 9)).foregroundColor(.white.opacity(0.45))
                        }
                    }
                    Spacer()
                    Menu {
                        Button("字号变大") { fontSize = min(28, fontSize + 1) }
                        Button("字号变小") { fontSize = max(15, fontSize - 1) }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 16)).foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 22).padding(.top, 14)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                                HStack(spacing: 10) {
                                    if idx == current {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                                          Color(red: 1, green: 0.70, blue: 0.28)],
                                                                 startPoint: .top, endPoint: .bottom))
                                            .frame(width: 3, height: fontSize + 6)
                                    }
                                    Text(line)
                                        .font(.system(size: idx == current ? fontSize : fontSize - 5,
                                                      weight: idx == current ? .heavy : .semibold))
                                        .foregroundColor(idx == current
                                                         ? Color(red: 1, green: 0.55, blue: 0.72)
                                                         : .white.opacity(abs(idx - current) <= 1 ? 0.45 : 0.2))
                                        .id(idx)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        current = idx
                                        proxy.scrollTo(idx, anchor: .center)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24).padding(.vertical, 210)
                    }
                }

                VStack(spacing: 10) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.16))
                            Capsule()
                                .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                              Color(red: 1, green: 0.70, blue: 0.28)],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * CGFloat(engine.progress))
                        }
                    }
                    .frame(height: 3)

                    HStack {
                        Text("点任意一行跳到该句")
                            .font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                        Spacer()
                        Button { engine.toggle() } label: {
                            Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16)).foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 22)
            }
        }
    }
}
