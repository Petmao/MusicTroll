import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        TabView {
            Placeholder(title: "首页", note: "抖音热歌 · 榜单流行 · 伤感歌词条")
                .tabItem { Label("首页", systemImage: "house") }

            Group {
                if auth.ent.canUseVideo { Placeholder(title: "养眼", note: "纯全屏刷视频，上下滑切换") }
                else { PaywallView(need: "SVIP", feature: "养眼视频") }
            }.tabItem { Label("养眼", systemImage: "play.rectangle") }

            Group {
                if auth.ent.canPlayMusic { Placeholder(title: "播放器", note: "黑胶 · 跑马灯光环 · 逐字歌词") }
                else { PaywallView(need: "VIP", feature: "在线听歌") }
            }.tabItem { Label("播放器", systemImage: "headphones") }

            MineView().tabItem { Label("我的", systemImage: "person") }
        }
        .tint(Color(red: 1, green: 0.37, blue: 0.62))
    }
}

struct Placeholder: View {
    let title: String
    let note: String
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Text(title).font(.system(size: 24, weight: .heavy))
                Text(note).font(.footnote).foregroundStyle(Color.white.opacity(0.45))
                Text("界面开发中").font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.25)).padding(.top, 6)
            }
        }
    }
}

struct PaywallView: View {
    let need: String
    let feature: String
    @EnvironmentObject var auth: AuthStore
    @State private var code = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "crown.fill").font(.system(size: 42))
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.25))
                Text("\(need) 才能使用\(feature)").font(.system(size: 20, weight: .bold))
                Text("当前账号：\(auth.user?.account ?? "-")")
                    .font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.45))

                HStack(spacing: 8) {
                    TextField("MT-XXXXXXXXXXXX", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("兑换") {
                        let c = code.trimmingCharacters(in: .whitespaces)
                        Task { await auth.redeem(c) }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(red: 1, green: 0.24, blue: 0.47))
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)

                if let e = auth.error {
                    Text(e).font(.system(size: 12)).foregroundStyle(Color.pink)
                }
            }
            .padding(24)
        }
    }
}

struct MineView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var showRedeem = false
    @State private var code = ""

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("账号")) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(LinearGradient(colors: [Color.orange, Color.pink], startPoint: .top, endPoint: .bottom))
                            .frame(width: 46, height: 46)
                            .overlay(Text(String((auth.user?.nickname ?? "I").prefix(1))).font(.headline))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(auth.user?.nickname ?? "-").font(.headline)
                                Text((auth.user?.role ?? "free").uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundStyle(Color.yellow)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            Text("账号 \(auth.user?.account ?? "-") · 积分 \(auth.user?.points ?? 0)")
                                .font(.system(size: 11)).foregroundStyle(Color.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("会员")) {
                    Button("卡密兑换") { showRedeem = true }
                    Button("签到") { Task { _ = try? await APIClient.shared.checkin() } }
                }

                Section(header: Text("设备")) {
                    Button("设备管理") { Task { _ = try? await APIClient.shared.deviceList(DeviceKey.deviceId) } }
                }

                Section {
                    Button("退出登录") { auth.logout() }
                        .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.55))
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("我的")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showRedeem) {
            VStack(spacing: 16) {
                Text("卡密兑换").font(.headline).padding(.top, 24)
                TextField("MT-XXXXXXXXXXXX", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                Button("确认兑换") {
                    let c = code.trimmingCharacters(in: .whitespaces)
                    Task { await auth.redeem(c); showRedeem = false }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(red: 1, green: 0.24, blue: 0.47))
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
}
