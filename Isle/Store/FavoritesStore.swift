import Foundation
import Combine

struct FavoriteSong: Codable, Identifiable, Equatable {
    var id: String { title + "|" + artist }
    var title: String
    var artist: String
}

/// 收藏存储（UserDefaults，后续可同步到云端接口）
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    private let key = "isle.favorites"

    @Published private(set) var items: [FavoriteSong] = []

    init() { load() }

    func contains(_ title: String, _ artist: String) -> Bool {
        items.contains { $0.title == title && $0.artist == artist }
    }

    @discardableResult
    func toggle(title: String, artist: String) -> Bool {
        if let idx = items.firstIndex(where: { $0.title == title && $0.artist == artist }) {
            items.remove(at: idx); save(); return false
        }
        items.insert(FavoriteSong(title: title, artist: artist), at: 0)
        save(); return true
    }

    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets); save() }

    private func save() {
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: key) }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([FavoriteSong].self, from: d) else { return }
        items = list
    }
}
