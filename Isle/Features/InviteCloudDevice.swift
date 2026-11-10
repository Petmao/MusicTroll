import SwiftUI

struct InviteView: View {
    @State private var info: InviteInfo?
    @State private var copied = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text("我的邀请码").font(.caption).foregroundColor(.secondary)
                    Text(info?.code ?? "————")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(3)
                        .foregroundColor(Color(red: 1, green: 0.35, blue: 0.55))
                    Button(copied ? "已复制" : "复制邀请码") {
                        UIPasteboard.general.string = info?.code ?? ""
                        copied = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Section(header: Text("邀请统计")) {
                HStack { Text("已邀请"); Spacer(); Text("\(info?.count ?? 0) 人") }
                HStack { Text("已完成兑换"); Spacer(); Text("\(info?.redeemed ?? 0) 人") }
            }

            Section(header: Text("规则"), footer: Text("好友注册时填写你的邀请码，并在 App 里兑换任意卡密后，你和他各得 7 天 VIP。同一设备不能互相邀请。")) {
                EmptyView()
            }

            if let list = info?.list, !list.isEmpty {
                Section(header: Text("邀请记录")) {
                    ForEach(Array(list.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.nickname ?? "（未填昵称）")
                            Spacer()
                            Text(item.status == "redeemed" ? "已兑换" : "待兑换")
                                .font(.caption)
                                .foregroundColor(item.status == "redeemed" ? Color(red: 0.31, green: 0.90, blue: 0.66) : .secondary)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("邀请好友")
        .task { info = try? await APIClient.shared.invite() }
    }
}

struct CloudSyncView: View {
    @State private var rows: [CloudPlaylist] = []
    @State private var loading = true

    var body: some View {
        List {
            Section(header: Text("云端歌单"), footer: Text("歌单与播放进度存在你自己的服务器上，换设备登录同一账号即可恢复。")) {
                if loading {
                    HStack { ProgressView(); Text("同步中…").foregroundColor(.secondary) }
                } else if rows.isEmpty {
                    Text("云端还没有歌单").foregroundColor(.secondary)
                } else {
                    ForEach(rows, id: \.pid) { p in
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundColor(Color(red: 1, green: 0.35, blue: 0.55))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.system(size: 14, weight: .semibold))
                                Text("\(p.songs.count) 首 · 版本 \(p.rev)").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            Section {
                Button("立即同步") { Task { await load() } }
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("云同步")
        .task { await load() }
    }

    private func load() async {
        loading = true
        rows = (try? await APIClient.shared.cloudPlaylists()) ?? []
        loading = false
    }
}

struct DeviceManageView: View {
    @State private var info: DeviceListResp?
    @State private var tip: String?

    var body: some View {
        List {
            if let i = info {
                Section(header: Text("额度")) {
                    HStack { Text("已用"); Spacer(); Text("\(i.used) / \(i.limit)") }
                    if i.unbindCooldownLeftMs > 0 {
                        Text("自助解绑冷却中，还剩 \(i.unbindCooldownLeftMs / 86400000) 天")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Section(header: Text("设备")) {
                    ForEach(i.devices) { d in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(d.name.isEmpty ? String(d.deviceId.prefix(8)) : d.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(statusText(d)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if d.isCurrent { Text("本机").font(.caption).foregroundColor(Color(red: 1, green: 0.35, blue: 0.55)) }
                        }
                        .swipeActions {
                            if !d.isCurrent && d.status == "active" {
                                Button("解绑") { Task { await unbind(d.deviceId) } }.tint(.red)
                            }
                        }
                    }
                }
                Section(footer: Text("解绑后该设备 \(i.graceHours) 小时后无法播放加密音乐，且换绑要等 30 天。")) { EmptyView() }
            } else {
                HStack { ProgressView(); Text("读取中…").foregroundColor(.secondary) }
            }
            if let tip = tip { Section { Text(tip).font(.footnote).foregroundColor(.secondary) } }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("设备管理")
        .task { await load() }
    }

    private func statusText(_ d: DeviceDTO) -> String {
        switch d.status {
        case "active": return "使用中"
        case "cooldown": return "已解绑，宽限中"
        default: return "已失效"
        }
    }

    private func load() async {
        info = try? await APIClient.shared.deviceList(DeviceKey.deviceId)
    }

    private func unbind(_ id: String) async {
        do { try await APIClient.shared.unbindDevice(id); await load() }
        catch APIError.http(let c) { tip = c == "cooldown" ? "还在冷却期，不能解绑" : "解绑失败：\(c)" }
        catch { tip = "网络异常" }
    }
}
