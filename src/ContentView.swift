import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var player: Player
    @State private var importing = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    ForEach(player.tracks, id: \.self) { url in
                        Button {
                            player.play(url)
                        } label: {
                            HStack {
                                Text(url.deletingPathExtension().lastPathComponent).lineLimit(1)
                                Spacer()
                                if player.current == url && player.isPlaying {
                                    Image(systemName: "speaker.wave.2.fill").font(.caption)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)

                if let c = player.current {
                    VStack(spacing: 8) {
                        Text(c.deletingPathExtension().lastPathComponent)
                            .font(.footnote).lineLimit(1)
                        HStack(spacing: 28) {
                            Button {
                                player.toggle()
                            } label: {
                                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 40))
                            }
                            Button {
                                player.stop()
                            } label: {
                                Image(systemName: "stop.circle").font(.system(size: 28))
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.secondarySystemBackground))
                }
            }
            .navigationTitle("音乐")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        player.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        importing = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.audio, .data],
                          allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                for u in urls {
                    let dst = docs.appendingPathComponent(u.lastPathComponent)
                    if u.startAccessingSecurityScopedResource() {
                        try? FileManager.default.copyItem(at: u, to: dst)
                        u.stopAccessingSecurityScopedResource()
                    }
                }
                player.reload()
            }
        }
        .navigationViewStyle(.stack)
    }
}
