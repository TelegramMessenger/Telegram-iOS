import Foundation
import UIKit
import TelegramCore
import TelegramUIPreferences

enum QrStudioClock {
    private static let epoch = CACurrentMediaTime()

    static var now: Double {
        return CACurrentMediaTime() - self.epoch
    }
}

extension QrStudioColor {
    var uiColor: UIColor {
        return UIColor(red: self.r, green: self.g, blue: self.b, alpha: 1.0)
    }
}

struct QrStudioEmojiItem: Equatable {
    let file: TelegramMediaFile
    let unicode: String?

    var id: Int64 {
        return self.file.fileId.id
    }

    var isTemplate: Bool {
        return self.file.isCustomTemplateEmoji
    }

    var setting: QrStudioLookSettings.Emoji {
        if let unicode = self.unicode {
            return .unicode(unicode)
        }
        return .custom(self.id)
    }

    static func ==(lhs: QrStudioEmojiItem, rhs: QrStudioEmojiItem) -> Bool {
        return lhs.id == rhs.id && lhs.unicode == rhs.unicode
    }
}

struct QrStudioGift: Equatable {
    let id: Int64
    let gift: StarGift.UniqueGift
    let model: TelegramMediaFile
    let pattern: TelegramMediaFile
    let inner: QrStudioColor
    let outer: QrStudioColor
    let patternColor: QrStudioColor
    let text: QrStudioColor

    static func ==(lhs: QrStudioGift, rhs: QrStudioGift) -> Bool {
        return lhs.id == rhs.id
    }
}

struct QrStudioTheme: Equatable {
    static let defaultId = "🏠"

    let id: String
    let reference: PresentationThemeReference
    let wallpaper: TelegramWallpaper
    let colors: [QrStudioColor]

    var isLight: Bool {
        guard !self.colors.isEmpty else {
            return true
        }
        let luminance = self.colors.reduce(0.0) { $0 + $1.luminance } / CGFloat(self.colors.count)
        return luminance > 0.45
    }

    var ink: QrStudioColor {
        guard let first = self.colors.first, let last = self.colors.last else {
            return QrStudioColor(rgb: 0x3E88F7).ink
        }
        return QrStudioColor.ink(center: first, edge: last)
    }

    static func ==(lhs: QrStudioTheme, rhs: QrStudioTheme) -> Bool {
        return lhs.id == rhs.id && lhs.colors == rhs.colors
    }
}

func qrStudioWallpaperColors(_ wallpaper: TelegramWallpaper) -> [QrStudioColor] {
    switch wallpaper {
    case let .color(color):
        return [QrStudioColor(rgb: color)]
    case let .gradient(gradient):
        return gradient.colors.map { QrStudioColor(rgb: $0) }
    case let .file(file):
        return file.settings.colors.map { QrStudioColor(rgb: $0) }
    default:
        return []
    }
}

enum QrStudioBackdrop: Equatable {
    case color(QrStudioPalette)
    case theme(QrStudioTheme)
    case emoji([QrStudioEmojiItem], isDark: Bool)
    case gift(QrStudioGift)

    var key: String {
        switch self {
        case let .color(palette):
            return "color-\(palette.name)"
        case .emoji:
            return "emoji"
        case let .gift(gift):
            return "gift-\(gift.id)"
        case let .theme(theme):
            return "theme-\(theme.id)"
        }
    }

    var cardSignature: String {
        if case let .emoji(items, _) = self {
            return "emoji-" + items.map { "\($0.id)" }.joined(separator: ",")
        }
        return self.key
    }

    var signature: String {
        if case let .emoji(items, isDark) = self {
            return (isDark ? "emoji-dark-" : "emoji-") + items.map { "\($0.id)" }.joined(separator: ",")
        }
        return self.key
    }

    var baseColor: QrStudioColor {
        switch self {
        case let .color(palette):
            return palette.colors.count > 4 ? palette.colors[4] : (palette.colors.first ?? QrStudioColor(1.0, 1.0, 1.0))
        case let .emoji(_, isDark):
            return isDark ? QrStudioColor(0.0, 0.0, 0.0) : QrStudioColor(1.0, 1.0, 1.0)
        case let .gift(gift):
            return gift.outer
        case let .theme(theme):
            return theme.colors.first ?? QrStudioColor(1.0, 1.0, 1.0)
        }
    }

    var isLight: Bool {
        switch self {
        case let .emoji(_, isDark):
            return !isDark
        case .theme:
            return true
        default:
            return false
        }
    }

    static func ==(lhs: QrStudioBackdrop, rhs: QrStudioBackdrop) -> Bool {
        return lhs.signature == rhs.signature
    }
}

struct QrStudioLook: Equatable {
    enum Kind: Int32, CaseIterable {
        case color = 0
        case emoji = 1
        case gift = 2
    }

    static let maxEmoji = 6

    var kind: Kind = .color
    var palettes: [QrStudioPalette] = []
    var colorId: Int32?
    var emoji: [QrStudioEmojiItem] = []
    var gifts: [QrStudioGift] = []
    var giftId: Int64?
    var themes: [QrStudioTheme] = []
    var themeId: String?
    var emojiDark = false

    var selectedTheme: QrStudioTheme? {
        guard let themeId = self.themeId else {
            return nil
        }
        return self.themes.first(where: { $0.id == themeId })
    }

    private var colorBackdrop: QrStudioBackdrop {
        if let theme = self.selectedTheme {
            return .theme(theme)
        }
        return .color(self.palette)
    }
    var emojiInk: QrStudioColor?

    var palette: QrStudioPalette {
        if let colorId = self.colorId, let palette = self.palettes.first(where: { $0.id == colorId }) {
            return palette
        }
        return self.palettes.first ?? QrStudioPalette.fallback
    }

    var selectedGift: QrStudioGift? {
        guard let giftId = self.giftId else {
            return nil
        }
        return self.gifts.first(where: { $0.id == giftId })
    }

    var backdrop: QrStudioBackdrop {
        switch self.kind {
        case .color:
            return self.colorBackdrop
        case .emoji:
            if !self.emoji.isEmpty {
                return .emoji(self.emoji, isDark: self.emojiDark)
            }
            return self.colorBackdrop
        case .gift:
            if let gift = self.selectedGift {
                return .gift(gift)
            }
            return self.colorBackdrop
        }
    }

    var inkEmoji: QrStudioEmojiItem? {
        return self.emoji.first(where: { !$0.isTemplate })
    }

    var ink: QrStudioColor {
        switch self.backdrop {
        case let .color(palette):
            return palette.ink
        case .emoji:
            return self.emojiInk ?? QrStudioColor(rgb: 0x9662D4).ink
        case let .gift(gift):
            return QrStudioColor.ink(center: gift.inner, edge: gift.outer)
        case let .theme(theme):
            return theme.ink
        }
    }

    var availableKinds: [Kind] {
        var result: [Kind] = [.color, .emoji]
        if !self.gifts.isEmpty {
            result.append(.gift)
        }
        return result
    }

    var settings: QrStudioLookSettings {
        return QrStudioLookSettings(kind: self.kind.rawValue, colorId: self.colorId, emoji: self.kind == .emoji ? self.emoji.map { $0.setting } : [], giftId: self.giftId, themeId: self.themeId)
    }

    mutating func select(_ kind: Kind) {
        guard self.availableKinds.contains(kind) else {
            return
        }
        self.kind = kind
        if kind == .gift && self.selectedGift == nil {
            self.giftId = self.gifts.first?.id
        }
    }

    mutating func selectPalette(id: Int32) {
        self.colorId = id
        self.themeId = nil
        self.kind = .color
    }

    mutating func selectTheme(id: String) {
        self.themeId = id
        self.kind = .color
    }

    mutating func selectGift(id: Int64) {
        guard self.gifts.contains(where: { $0.id == id }) else {
            return
        }
        self.giftId = id
        self.kind = .gift
    }

    mutating func toggleEmoji(_ item: QrStudioEmojiItem) -> Bool {
        var ids = self.emoji.map { $0.id }
        guard qrStudioToggle(&ids, item.id, limit: QrStudioLook.maxEmoji) else {
            return false
        }
        if ids.contains(item.id) {
            self.emoji.append(item)
        } else {
            self.emoji.removeAll(where: { $0.id == item.id })
        }
        self.kind = .emoji
        return true
    }

    mutating func gifts(_ gifts: [QrStudioGift]) {
        self.gifts = gifts
        if let giftId = self.giftId, !gifts.contains(where: { $0.id == giftId }) {
            self.giftId = nil
        }
        if self.kind == .gift && self.giftId == nil {
            self.kind = .color
        }
    }

    static func ==(lhs: QrStudioLook, rhs: QrStudioLook) -> Bool {
        return lhs.kind == rhs.kind && lhs.palettes == rhs.palettes && lhs.colorId == rhs.colorId && lhs.emoji == rhs.emoji && lhs.gifts == rhs.gifts && lhs.giftId == rhs.giftId && lhs.emojiInk == rhs.emojiInk && lhs.themes == rhs.themes && lhs.themeId == rhs.themeId && lhs.emojiDark == rhs.emojiDark
    }
}
