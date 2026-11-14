import SwiftUI

@main
struct IsleApp: App {
    @StateObject private var auth = AuthStore()

    init() {
        // 只做 dlopen，纯 C 调用，App.init 阶段安全。
        // 图形相关的预热在下面 .task 里做，App.init 阶段碰 Metal 会崩在启动。
        LinkFix.load()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.user == nil { LoginView() } else { RootView() }
            }
            .environmentObject(auth)
            .preferredColorScheme(.dark)
            .task {
                LinkFix.warmUp()
                await auth.bootstrap()
            }
        }
    }
}
