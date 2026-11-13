import SwiftUI

struct InviteView: View {
    @State private var info: InviteInfo?
    @State private var copied = false

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    codeCard
                    statCard
                    rulesCard
                    recordsCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 26)
            }
        }
        .navigationTitle("邀请好友")
        .navigationBarTitleDisplayMode(.inline)
        .task { info = try? await APIClient.shared.invite() }
    }

    private var codeCard: some View {
        VStack(spacing: 12) {
            Text("我的邀请码")
                .font(.system(size: 11))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.62))

            Text(info?.code ?? "————")
                .font(.system(size: 30, weight: .heavy))
                .tracking(6)
                .foregroundStyle(
                    LinearGradient(colors: [IsleColor.pinkLight, IsleColor.lilac],
                                   startPoint: .leading, endPoint: .trailing)
                )

            Button {
                UIPasteboard.general.string = info?.code ?? ""
                copied = true
            } label: {
                Text(copied ? "已复制" : "复制邀请码")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(IsleColor.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(IsleColor.pink.opacity(0.16))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(IsleColor.pink.opacity(0.28), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statCard: some View {
        IsleCard {
            VStack(spacing: 10) {
                row("已邀请", "\(info?.count ?? 0) 人", nil)
                Divider().background(IsleColor.line)
                row("已完成兑换", "\(info?.redeemed ?? 0) 人", nil)
            }
        }
    }

    private func row(_ title: String, _ value: String, _ tint: Color?) -> some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint ?? Color.white)
        }
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                IsleIcon(IsleSymbol.gift, scale: .sm, tint: IsleColor.gold)
                Text("规则").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(IsleColor.gold.opacity(0.9))
            }
            Text("好友注册时填写你的邀请码，并在 App 里兑换任意卡密后，你和他各得 7 天 VIP。同一设备不能互相邀请。")
                .font(.system(size: 10.5))
                .lineSpacing(2)
                .foregroundStyle(Color.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.03))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var recordsCard: some View {
        if let list = info?.list, !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("邀请记录").font(.system(size: 16, weight: .heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(list.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.nickname ?? "（未填昵称）")
                            .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.85))
                        Spacer()
                        Text(item.status == "redeemed" ? "已兑换" : "待兑换")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(item.status == "redeemed" ? IsleColor.mint : IsleColor.textFaint)
                    }
                    .padding(12)
                    .background(IsleColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

struct CloudSyncView: View {
    @State private var rows: [CloudPlaylist] = []
    @State private var loading = true

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if loading {
                        HStack(spacing: 8) {
                            ProgressView().tint(IsleColor.pinkLight)
                            Text("同步中…").font(.system(size: 12)).foregroundStyle(IsleColor.textSub)
                            Spacer()
                        }
                        .padding(16)
                    } else if rows.isEmpty {
                        IsleCard {
                            Text("云端还没有歌单")
                                .font(.system(size: 12)).foregroundStyle(IsleColor.textSub)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(rows, id: \.pid) { p in
                            playlistRow(p)
                        }
                    }

                    Button { Task { await load() } } label: {
                        Text("立即同步")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(IsleColor.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Text("歌单与播放进度存在你自己的服务器上，换设备登录同一账号即可恢复。")
                        .font(.system(size: 10))
                        .foregroundStyle(IsleColor.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 26)
            }
        }
        .navigationTitle("云同步")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func playlistRow(_ p: CloudPlaylist) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(IsleColor.pink.opacity(0.18))
                    .frame(width: 40, height: 40)
                IsleIcon(IsleSymbol.music, scale: .md, tint: IsleColor.pinkLight)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                Text("\(p.songs.count) 首 · 版本 \(p.rev)")
                    .font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub)
            }
            Spacer(minLength: 6)
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    quotaCard
                    devicesCard
                    tipLine
                    Text("解绑后该设备有一段时间无法播放加密音乐，换绑需要等 30 天。")
                        .font(.system(size: 10))
                        .foregroundStyle(IsleColor.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 26)
            }
        }
        .navigationTitle("设备管理")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var quotaCard: some View {
        if let i = info {
            IsleCard {
                VStack(spacing: 10) {
                    HStack {
                        Text("在线额度").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.8))
                        Spacer()
                        Text("\(i.used) / \(i.limit)")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(IsleColor.pinkLight)
                    }
                    if i.unbindCooldownLeftMs > 0 {
                        HStack(spacing: 6) {
                            IsleIcon(IsleSymbol.clock, scale: .sm, tint: IsleColor.gold)
                            Text("自助解绑冷却中，还剩 \(i.unbindCooldownLeftMs / 86400000) 天")
                                .font(.system(size: 10.5)).foregroundStyle(IsleColor.gold.opacity(0.85))
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var devicesCard: some View {
        if let i = info {
            VStack(spacing: 10) {
                ForEach(i.devices) { d in
                    deviceRow(d)
                }
            }
        } else {
            HStack(spacing: 8) {
                ProgressView().tint(IsleColor.pinkLight)
                Text("读取中…").font(.system(size: 12)).foregroundStyle(IsleColor.textSub)
                Spacer()
            }
            .padding(16)
        }
    }

    private func deviceRow(_ d: DeviceDTO) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(d.isCurrent ? IsleColor.pink.opacity(0.20) : IsleColor.surfaceHi)
                    .frame(width: 40, height: 40)
                IsleIcon(IsleSymbol.device, scale: .md,
                         tint: d.isCurrent ? IsleColor.pinkLight : Color.white.opacity(0.7))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(d.name.isEmpty ? String(d.deviceId.prefix(8)) : d.name)
                        .font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                    if d.isCurrent {
                        Text("本机")
                            .font(.system(size: 8.5, weight: .heavy))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(IsleColor.pink.opacity(0.22))
                            .foregroundStyle(IsleColor.pinkLight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(statusText(d)).font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub)
            }
            Spacer(minLength: 6)
            if !d.isCurrent && d.status == "active" {
                Button { Task { await unbind(d.deviceId) } } label: {
                    Text("解绑")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.48, blue: 0.60))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(d.isCurrent ? IsleColor.pink.opacity(0.35) : IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var tipLine: some View {
        if let tip {
            Text(tip)
                .font(.system(size: 11))
                .foregroundStyle(IsleColor.pinkLight)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        do {
            try await APIClient.shared.unbindDevice(id)
            await load()
        } catch APIError.http(let c) {
            tip = c == "cooldown" ? "还在冷却期，不能解绑" : "解绑失败：\(c)"
        } catch {
            tip = "网络异常"
        }
    }
}
