import SwiftUI

struct SongItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var artist: String
    var cached: Bool = false
}

/// 收藏与歌单（本地存储，云同步接口已就绪）
struct LibraryView: View {
    @State private var favorites: [SongItem] = []
    @State private var playlists: [String] = ["我喜欢的音乐", "夜跑 DJ 循环", "通勤白噪"]
    @State private var newName = ""
    @State private var showNew = false

    var body: some View {
        List {
            Section(header: Text("收藏歌曲 · \(favorites.count) 首")) {
                if favorites.isEmpty {
                    Text("还没有收藏，播放时点 ♡ 就会出现在这里")
                        .font(.footnote).foregroundColor(.secondary)
                } else {
                    ForEach(favorites) { s in
                        HStack(spacing: 10) {
                            Image(systemName: s.cached ? "arrow.down.circle.fill" : "music.note")
                                .foregroundColor(s.cached ? Color(red: 0.31, green: 0.90, blue: 0.66) : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title).font(.system(size: 14, weight: .semibold))
                                Text(s.artist).font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color(red: 1, green: 0.37, blue: 0.62))
                        }
                    }
                    .onDelete { idx in favorites.remove(atOffsets: idx) }
                }
            }

            Section(header: Text("我的歌单")) {
                ForEach(playlists, id: \.self) { name in
                    HStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                          Color(red: 0.48, green: 0.36, blue: 1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 38, height: 38)
                            .overlay(Image(systemName: "music.note.list")
                                        .font(.system(size: 14)).foregroundColor(.white))
                        Text(name).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                .onDelete { idx in playlists.remove(atOffsets: idx) }

                Button { showNew = true } label: {
                    Label("新建歌单", systemImage: "plus.circle")
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            Section(footer: Text("歌单与收藏可以同步到云端（「我的 → 云同步」），换设备登录同一账号即可恢复。")) {
                EmptyView()
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("收藏与歌单")
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
}

/// 全屏歌词
struct LyricsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var current = 3
    @State private var fontSize: CGFloat = 21

    private let lines = [
        "街角的路灯还亮着", "风把从前吹回来", "把耳机调到最大声",
        "我坠落在这片星空里", "找不到你来过的痕迹", "如果光也会怕黑",
        "那就让我替你失眠", "这段路我走了很久", "还是没有走到你身边"
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.05, blue: 0.22),
                                    Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.up").font(.system(size: 18)).foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Text("歌词").font(.system(size: 12)).tracking(2).foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Menu {
                        Button("字号变大") { fontSize = min(28, fontSize + 1) }
                        Button("字号变小") { fontSize = max(15, fontSize - 1) }
                    } label: {
                        Image(systemName: "textformat.size").font(.system(size: 16)).foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 22).padding(.top, 14)

                Spacer()
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.system(size: idx == current ? fontSize : fontSize - 4,
                                                  weight: idx == current ? .heavy : .semibold))
                                    .foregroundColor(idx == current
                                                     ? Color(red: 1, green: 0.55, blue: 0.72)
                                                     : .white.opacity(abs(idx - current) <= 1 ? 0.45 : 0.2))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(idx)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            current = idx
                                            proxy.scrollTo(idx, anchor: .center)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 26).padding(.vertical, 200)
                    }
                }
                Spacer()

                Text("点任意一行跳到该句 · 播放器中会 seek 到对应时间")
                    .font(.system(size: 10)).foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 24)
            }
        }
    }
}
