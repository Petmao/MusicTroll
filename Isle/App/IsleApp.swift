import SwiftUI

@main
struct IsleApp: App {
    @StateObject private var auth = AuthStore()

    init() {
        // 必须最先执行：补上 OpenGLES / CoreImage，否则键盘渲染会跳空指针
        LinkFix.load()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.user == nil { LoginView() } else { RootView() }
            }
            .environmentObject(auth)
            .preferredColorScheme(.dark)
            .task { await auth.bootstrap() }
        }
    }
}
