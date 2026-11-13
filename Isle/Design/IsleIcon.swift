import SwiftUI

struct IsleIcon: View {
    enum Scale: Double {
        case xs = 11, sm = 13, md = 16, lg = 20, xl = 26, hero = 34
    }

    let symbol: String
    var scale: Scale
    var weight: Font.Weight
    var tint: Color?
    var box: CGFloat?

    init(_ symbol: String, scale: Scale = .md, weight: Font.Weight = .semibold, tint: Color? = nil, box: CGFloat? = nil) {
        self.symbol = symbol
        self.scale = scale
        self.weight = weight
        self.tint = tint
        self.box = box
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: CGFloat(scale.rawValue), weight: weight))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint ?? Color.primary)
            .frame(width: box, height: box)
            .accessibilityHidden(true)
    }
}

enum IsleSymbol {
    static let home = "house.fill"
    static let search = "magnifyingglass"
    static let video = "play.rectangle.on.rectangle.fill"
    static let me = "person.crop.circle"
    static let play = "play.fill"
    static let pause = "pause.fill"
    static let prev = "backward.fill"
    static let next = "forward.fill"
    static let shuffle = "shuffle"
    static let loop = "repeat"
    static let heart = "heart"
    static let heartFill = "heart.fill"
    static let lyric = "text.alignleft"
    static let download = "arrow.down.circle"
    static let addToPlaylist = "text.badge.plus"
    static let share = "square.and.arrow.up"
    static let cloud = "icloud"
    static let sync = "arrow.triangle.2.circlepath"
    static let device = "iphone"
    static let tablet = "ipad"
    static let desktop = "desktopcomputer"
    static let lock = "lock.fill"
    static let crown = "crown.fill"
    static let gift = "gift"
    static let star = "star.fill"
    static let check = "checkmark"
    static let clock = "clock"
    static let settings = "gearshape"
    static let palette = "paintpalette"
    static let language = "character.book.closed"
    static let trash = "trash"
    static let music = "music.note.list"
    static let back = "chevron.left"
    static let more = "ellipsis"
    static let collapse = "chevron.down"
    static let arrowRight = "chevron.right"
    static let plus = "plus"
    static let wallet = "creditcard"
    static let mail = "envelope"
    static let power = "power"
}
