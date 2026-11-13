import SwiftUI

struct CheckinView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var status: CheckinStatus?
    @State private var goods: GoodsBundle?
    @State private var tip: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            IsleBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pointsCard
                    streakCard

                    if let g = goods, !g.goods.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("积分兑换").font(.system(size: 16, weight: .heavy))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(g.goods.keys.sorted(), id: \.self) { key in
                                if let item = g.goods[key] {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(IsleColor.gold.opacity(0.14))
                                                .frame(width: 38, height: 38)
                                            IsleIcon(IsleSymbol.crown, scale: .md, tint: IsleColor.gold)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(label(key)).font(.system(size: 13.5, weight: .semibold))
                                            Text("\(item.cost) 积分 · \(item.days) 天 \(item.role.uppercased())")
                                                .font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub)
                                        }
                                        Spacer(minLength: 6)
                                        Button { Task { await redeem(key, cost: item.cost) } } label: {
                                            Text("兑换")
                                                .font(.system(size: 11.5, weight: .semibold))
                                                .foregroundStyle(g.balance >= item.cost ? .white : IsleColor.textFaint)
                                                .padding(.horizontal, 13).padding(.vertical, 7)
                                                .background(g.balance >= item.cost ? IsleColor.accent : IsleColor.surface)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(g.balance < item.cost)
                                    }
                                    .padding(14)
                                    .background(IsleColor.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(IsleColor.line, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }

                    if let tip {
                        Text(tip)
                            .font(.system(size: 11))
                            .foregroundStyle(IsleColor.pinkLight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(IsleColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("签到与积分")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("我的积分").font(.system(size: 11)).tracking(1)
                .foregroundStyle(Color.white.opacity(0.62))
            Text("\(status?.balance ?? 0)")
                .font(.system(size: 40, weight: .heavy)).tracking(-1)
            Text("已连签 \(status?.streak ?? 0) 天 · 明天可得 \(nextReward) 积分")
                .font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.55))

            Button { Task { await sign() } } label: {
                HStack(spacing: 6) {
                    if busy { ProgressView().tint(.white).scaleEffect(0.75) }
                    Text(status?.todaySigned == true ? "今天已签到" : "今日签到")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(
                    Group {
                        if status?.todaySigned == true { Color.white.opacity(0.14) }
                        else { IsleColor.accent }
                    }
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(busy || status?.todaySigned == true)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(colors: [IsleColor.pink.opacity(0.26),
                                    IsleColor.lilac.opacity(0.14),
                                    Color.white.opacity(0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(IsleColor.pink.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("连续签到 \(status?.streak ?? 0) 天")
                    .font(.system(size: 13.5, weight: .bold))
                Spacer()
                Text(status?.todaySigned == true ? "今天已完成" : "今日待签")
                    .font(.system(size: 10.5)).foregroundStyle(IsleColor.textSub)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(i < (status?.streak ?? 0)
                                      ? IsleColor.pink.opacity(0.9)
                                      : Color.white.opacity(0.05))
                                .frame(width: 32, height: 32)
                            if i < (status?.streak ?? 0) {
                                IsleIcon(IsleSymbol.check, scale: .sm, tint: .white)
                            } else if i == 6 {
                                IsleIcon(IsleSymbol.star, scale: .sm, tint: IsleColor.gold)
                            } else {
                                Text("\(i + 1)").font(.system(size: 10))
                                    .foregroundStyle(IsleColor.textFaint)
                            }
                        }
                        Text("\(i + 1)").font(.system(size: 9))
                            .foregroundStyle(IsleColor.textFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(IsleColor.surface)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(IsleColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var nextReward: Int {
        guard let s = status, !s.rewards.isEmpty else { return 0 }
        let idx = min(s.rewards.count - 1, max(0, s.streak))
        return s.rewards[idx]
    }

    private func label(_ key: String) -> String {
        switch key {
        case "vip_1d": return "VIP 1 天"
        case "vip_7d": return "VIP 7 天"
        case "svip_1d": return "SVIP 1 天"
        case "svip_7d": return "SVIP 7 天"
        default: return key
        }
    }

    private func load() async {
        status = try? await APIClient.shared.checkinStatus()
        goods = try? await APIClient.shared.pointsGoods()
    }

    private func sign() async {
        busy = true; tip = nil
        do {
            let r = try await APIClient.shared.checkin()
            tip = "签到成功 +\(r.points) 积分" + (r.bonus != nil ? "，额外获得 \(r.bonus!.uppercased())" : "")
            await load(); await auth.refresh()
        } catch APIError.http(let c) {
            tip = c == "already_signed" ? "今天已经签过了" : "签到失败：\(c)"
        } catch { tip = "网络异常" }
        busy = false
    }

    private func redeem(_ key: String, cost: Int) async {
        tip = nil
        do {
            try await APIClient.shared.exchange(goods: key)
            await auth.refresh(); await load()
            tip = "兑换成功"
        } catch APIError.http(let c) {
            tip = c == "not_enough_points" ? "积分不够" : "兑换失败：\(c)"
        } catch { tip = "网络异常" }
    }
}
