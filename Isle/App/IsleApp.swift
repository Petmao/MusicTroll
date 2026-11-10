import SwiftUI

@main
struct IsleApp: App {
    @StateObject private var auth = AuthStore()

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
