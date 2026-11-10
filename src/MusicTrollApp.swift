import SwiftUI

@main
struct MusicTrollApp: App {
    @StateObject private var player = Player()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(player) }
    }
}
