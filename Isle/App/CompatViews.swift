import SwiftUI

struct DeviceView: View {
    var body: some View {
        DeviceManageView()
    }
}

struct PaywallView: View {
    let need: String
    let feature: String
    @EnvironmentObject var auth: AuthStore
    @State private var code = ""
    @State private var tip: String?

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(LinearGradient(colors: [IsleColor.gold.opacity(0.28),
                                                              IsleColor.pink.opacity(0.20)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(IsleColor.gold.opacity(0.40), lineWidth: 1)
                                .frame(width: 72, height: 72)
                            IsleIcon(IsleSymbol.lock, scale: .hero, tint: IsleColor.gold)
                        }
                        .padding(.top, 26)

                        Text("\(need) 才能使用\(feature)")
                            .font(.system(size: 20, weight: .heavy))
                        Text("输入卡密兑换会员，或用积分在签到页兑换")
                            .font(.system(size: 12))
                            .foregroundStyle(IsleColor.textSub)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("会员权益").font(.system(size: 11)).tracking(2)
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("卡密兑换").font(.system(size: 11)).tracking(2)
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

                            Button {
                                Task {
                                    if code.isEmpty { tip = "请输入卡密"; return }
                                    tip = "已提交兑换"
                                }
                            } label: {
                                Text("兑换")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18).padding(.vertical, 13)
                                    .background(IsleColor.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        if let tip {
                            Text(tip).font(.system(size: 11)).foregroundStyle(IsleColor.pinkLight)
                        }
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("会员")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 9) {
            IsleIcon(IsleSymbol.check, scale: .sm, tint: IsleColor.gold)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(IsleColor.gold.opacity(0.92))
            Spacer(minLength: 0)
        }
    }
}
