import SwiftUI

struct DeviceView: View {
    var body: some View {
        DeviceManageView()
    }
}

struct PaywallView: View {
    let need: String
    let feature: String
    var onClose: (() -> Void)? = nil

    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var tip: String?
    @State private var ok = false
    @State private var busy = false

    private var roleLabel: String {
        auth.ent.canUseVideo ? "SVIP" : (auth.ent.canPlayMusic ? "VIP" : "")
    }

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    hero
                    goldCard
                    redeemBlock
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("会员")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topBar: some View {
        HStack {
            Button(action: close) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("返回").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.88))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [IsleColor.gold.opacity(0.28),
                                                  IsleColor.pink.opacity(0.20)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 68, height: 68)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(IsleColor.gold.opacity(0.40), lineWidth: 1)
                    .frame(width: 68, height: 68)
                IsleIcon(ok ? IsleSymbol.check : IsleSymbol.lock,
                         scale: .hero,
                         weight: .regular,
                         tint: ok ? IsleColor.mint : IsleColor.gold)
            }

            Text(ok ? "已开通 \(roleLabel.isEmpty ? "会员" : roleLabel)"
                    : "\(need) 才能使用\(feature)")
                .font(.system(size: 20, weight: .heavy))

            Text(ok ? "权限已刷新，相关功能同步解锁"
                    : "输入卡密兑换会员，或用积分在签到页兑换")
                .font(.system(size: 12))
                .foregroundStyle(IsleColor.textSub)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var goldCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ok ? "会员权益 · 已解锁" : "会员权益")
                .font(.system(size: 11)).tracking(2)
                .foregroundStyle(IsleColor.gold.opacity(0.85))
            benefit("无损音质 FLAC / 母带")
            benefit("无限下载与离线播放")
            benefit("5 台设备同时在线")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(colors: [Color(red: 0.165, green: 0.110, blue: 0.063),
                                    Color(red: 0.141, green: 0.078, blue: 0.031)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(IsleColor.gold.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 9) {
            IsleIcon(IsleSymbol.check, scale: .sm, weight: .bold, tint: IsleColor.gold)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(IsleColor.gold.opacity(0.92))
            Spacer(minLength: 0)
        }
    }

    private var redeemBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("卡密兑换")
                .font(.system(size: 11)).tracking(2)
                .foregroundStyle(IsleColor.textFaint)

            HStack(spacing: 8) {
                TextField("MT-XXXXXXXXXXXX", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(13)
                    .background(IsleColor.surfaceHi)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(IsleColor.pink.opacity(0.45), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(busy)

                Button(action: doRedeem) {
                    HStack(spacing: 6) {
                        if busy { ProgressView().scaleEffect(0.7).tint(Color.white) }
                        Text(busy ? "兑换中" : "兑换")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(IsleColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(busy)
                .opacity(busy ? 0.6 : 1)
            }

            if let tip {
                HStack(spacing: 6) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                    Text(tip).font(.system(size: 11))
                }
                .foregroundStyle(ok ? IsleColor.mint : IsleColor.pinkLight)
            }
        }
        .padding(.top, 4)
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func doRedeem() {
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !c.isEmpty else { ok = false; tip = "请输入卡密"; return }
        guard !busy else { return }
        busy = true
        ok = false
        tip = nil

        Task { @MainActor in
            await auth.redeem(c)
            busy = false
            if let e = auth.error {
                ok = false
                tip = e
            } else {
                ok = true
                code = ""
                tip = "兑换成功：\(roleLabel.isEmpty ? "会员已生效" : roleLabel)"
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if let onClose { onClose() }
            }
        }
    }
}
