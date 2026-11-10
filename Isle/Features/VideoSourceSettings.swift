import SwiftUI

struct VideoSourceSettingsView: View {
    @State private var address = ""
    @State private var raw: [String: Any] = [:]
    @State private var loading = false
    @State private var message: String?
    @State private var ok = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    card
                    if let message { banner(message) }
                    Button { Task { await load() } } label: {
                        HStack(spacing: 6) {
                            if loading { ProgressView().scaleEffect(0.7) }
                            Text(loading ? "正在拉取…" : "重新拉取")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [Color(red: 1, green: 0.18, blue: 0.47),
                                                          Color(red: 1, green: 0.48, blue: 0.18)],
                                                 startPoint: .leading, endPoint: .trailing)))
                    }
                    .disabled(loading)
                    Text("视频源由后台 /admin.html → 视频源 配置，App 只负责拉取与播放。")
                        .font(.system(size: 9.5)).foregroundColor(.white.opacity(0.3))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
        }
        .navigationTitle("视频源")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前地址").font(.system(size: 10, weight: .bold)).tracking(1)
                .foregroundColor(.white.opacity(0.45))
            Text(address.isEmpty ? "（空）" : address)
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
                .lineLimit(3).truncationMode(.middle)
            ForEach(raw.keys.sorted(), id: \.self) { k in
                if k != "url" {
                    HStack {
                        Text(k).font(.system(size: 10)).foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("\(raw[k] ?? "")").font(.system(size: 10)).foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text(text).font(.system(size: 11)).lineLimit(4)
            Spacer()
        }
        .foregroundColor(ok ? Color(red: 0.30, green: 0.90, blue: 0.66) : Color(red: 1, green: 0.62, blue: 0.35))
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill((ok ? Color(red: 0.10, green: 0.35, blue: 0.25) : Color(red: 0.35, green: 0.18, blue: 0.10)).opacity(0.25)))
    }

    private func load() async {
        loading = true; message = nil
        defer { loading = false }
        do {
            let obj = try await SourcesClient.shared.fetch(kind: "video")
            raw = obj
            address = (obj["url"] as? String) ?? (obj["address"] as? String) ?? ""
            ok = true
            message = "拉取成功"
        } catch {
            ok = false
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            address = ""
        }
    }
}

struct MusicSourceSettingsView: View {
    @State private var items: [[String: Any]] = []
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    if let message {
                        Text(message).font(.system(size: 11))
                            .foregroundColor(Color(red: 1, green: 0.62, blue: 0.35))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                        HStack(spacing: 10) {
                            Circle().fill(Color(red: 0.30, green: 0.90, blue: 0.66)).frame(width: 7, height: 7)
                            VStack(alignment: .leading, spacing: 2) {
                                Text((it["name"] as? String) ?? "未命名源")
                                    .font(.system(size: 13, weight: .semibold))
                                Text((it["url"] as? String) ?? "")
                                    .font(.system(size: 10)).foregroundColor(.gray).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
                    }
                    Button { Task { await load() } } label: {
                        Text(loading ? "正在拉取…" : "重新拉取")
                            .font(.system(size: 12.5, weight: .bold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                    }
                    .disabled(loading)
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
        }
        .navigationTitle("音乐音源")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true; message = nil
        defer { loading = false }
        do {
            let obj = try await SourcesClient.shared.fetch(kind: "music")
            if let arr = obj["sources"] as? [[String: Any]] { items = arr }
            else if obj["url"] != nil { items = [obj] }
            if items.isEmpty { message = "后台未配置音乐源" }
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
