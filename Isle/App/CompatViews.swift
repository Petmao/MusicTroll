import SwiftUI

/// 设备管理入口（实际实现是 DeviceManageView）
struct DeviceView: View {
    var body: some View {
        DeviceManageView()
    }
}

/// 会员拦截页
struct PaywallView: View {
    let need: String
    let feature: String
    @EnvironmentObject var auth: AuthStore
    @State private var code = ""
    @State private var tip: String?

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 1, green: 0.82, blue: 0.44))
                    .padding(.top, 40)
                Text("\(need) 才能使用\(feature)")
                    .font(.system(size: 16, weight: .heavy))
                Text("输入卡密兑换会员，或用积分在签到页兑换")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                HStack(spacing: 8) {
                    TextField("MT-XXXXXXXXXXXX", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .padding(11)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .font(.system(size: 12))
                    Button("兑换") {
                        Task {
                            if code.isEmpty { tip = "请输入卡密"; return }
                            tip = "已提交兑换"
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color(red: 1, green: 0.18, blue: 0.47))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)

                if let tip {
                    Text(tip).font(.system(size: 11)).foregroundColor(.orange)
                }
                Spacer()
            }
        }
    }
}
