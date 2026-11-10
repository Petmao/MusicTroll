import SwiftUI

struct CheckinView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var status: CheckinStatus?
    @State private var goods: GoodsBundle?
    @State private var tip: String?
    @State private var busy = false

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已连签 \(status?.streak ?? 0) 天").font(.headline)
                        Text("明天签到可得 \(nextReward) 积分").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(status?.balance ?? 0)").font(.system(size: 20, weight: .bold))
                        Text("积分").font(.caption2).foregroundColor(.secondary)
                    }
                }
                Button {
                    Task { await sign() }
                } label: {
                    HStack {
                        if busy { ProgressView().padding(.trailing, 4) }
                        Text(status?.todaySigned == true ? "今天已签到" : "今日签到")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(busy || status?.todaySigned == true)
                .foregroundColor(status?.todaySigned == true ? .gray : Color(red: 1, green: 0.35, blue: 0.55))
            }

            if let g = goods {
                Section(header: Text("积分兑换")) {
                    ForEach(g.goods.keys.sorted(), id: \.self) { key in
                        if let item = g.goods[key] {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(label(key)).font(.system(size: 14, weight: .semibold))
                                    Text("\(item.cost) 积分 · \(item.days) 天 \(item.role.uppercased())")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("兑换") { Task { await redeem(key, cost: item.cost) } }
                                    .font(.system(size: 13, weight: .semibold))
                                    .disabled((g.balance) < item.cost)
                            }
                        }
                    }
                }
            }

            if let tip = tip {
                Section { Text(tip).font(.footnote).foregroundColor(.secondary) }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("签到")
        .task { await load() }
    }

    private var nextReward: Int {
        guard let s = status else { return 0 }
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
            tip = "签到成功 +\\(r.points) 积分" + (r.bonus != nil ? "，额外获得 \(r.bonus!.uppercased())" : "")
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
