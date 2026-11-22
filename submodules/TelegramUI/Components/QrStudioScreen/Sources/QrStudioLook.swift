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
    let reference: StarGiftReference?
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
    case emoji([QrStudioEmojiItem], palette: QrStudioPalette)
    case gift(QrStudioGift)

    var key: String {
        switch self {
        case let .color(palette):
            return "color-\(palette.name)"
        case let .emoji(_, palette):
            return "emoji-\(palette.name)"
        case let .gift(gift):
            return "gift-\(gift.id)"
        case let .theme(theme):
            return "theme-\(theme.id)"
        }
    }

    var cardSignature: String {
        if case let .emoji(items, palette) = self {
            return "emoji-\(palette.name)-" + items.map { "\($0.id)" }.joined(separator: ",")
        }
        return self.key
    }

    var signature: String {
        if case let .emoji(items, palette) = self {
            return "emoji-\(palette.name)-" + items.map { "\($0.id)" }.joined(separator: ",")
        }
        return self.key
    }

    var baseColor: QrStudioColor {
        switch self {
        case let .color(palette):
            return palette.colors.count > 4 ? palette.colors[4] : (palette.colors.first ?? QrStudioColor(1.0, 1.0, 1.0))
        case let .emoji(_, palette):
            return palette.colors.count > 4 ? palette.colors[4] : (palette.colors.first ?? QrStudioColor(0.0, 0.0, 0.0))
        case let .gift(gift):
            return gift.outer
        case let .theme(theme):
            return theme.colors.first ?? QrStudioColor(1.0, 1.0, 1.0)
        }
    }

    var isLight: Bool {
        switch self {
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
    var backdrops: [QrStudioPalette] = []
    var colorId: Int32?
    var backdropId: Int32?
    var emoji: [QrStudioEmojiItem] = []
    var gifts: [QrStudioGift] = []
    var giftId: Int64?
    var themes: [QrStudioTheme] = []
    var themeId: String?

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

    var palette: QrStudioPalette {
        if let backdropId = self.backdropId, let palette = self.backdrops.first(where: { $0.id == .backdrop(backdropId) }) {
            return palette
        }
        if let colorId = self.colorId, let palette = self.palettes.first(where: { $0.id == .color(colorId) }) {
            return palette
        }
        return self.backdrops.first(where: { $0.id == QrStudioPalette.fallback.id }) ?? QrStudioPalette.fallback
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
                return .emoji(self.emoji, palette: self.palette)
            }
            return self.colorBackdrop
        case .gift:
            if let gift = self.selectedGift {
                return .gift(gift)
            }
            return self.colorBackdrop
        }
    }

    var ink: QrStudioColor {
        switch self.backdrop {
        case let .color(palette):
            return palette.ink
        case let .emoji(_, palette):
            return palette.ink
        case let .gift(gift):
            return QrStudioColor.ink(center: gift.inner, edge: gift.outer)
        case let .theme(theme):
            return theme.ink
        }
    }

    var availableKinds: [Kind] {
        return [.color, .emoji, .gift]
    }

    var settings: QrStudioLookSettings {
        var settings = QrStudioLookSettings(kind: self.kind.rawValue, colorId: self.colorId, emoji: self.emoji.map { $0.setting }, giftId: self.giftId, themeId: self.themeId, backdropId: self.backdropId)
        if let gift = self.selectedGift {
            settings.gift = gift.gift
            settings.giftReference = gift.reference
        }
        return settings
    }

    mutating func select(_ kind: Kind) {
        guard self.availableKinds.contains(kind), kind != .gift || !self.gifts.isEmpty else {
            return
        }
        self.kind = kind
        if kind == .gift && self.selectedGift == nil {
            self.giftId = self.gifts.first?.id
        }
    }

    mutating func selectPalette(id: QrStudioPaletteId) {
        switch id {
        case let .color(colorId):
            self.colorId = colorId
            self.backdropId = nil
        case let .backdrop(backdropId):
            self.backdropId = backdropId
        }
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
        let current = self.emoji
        self.emoji = ids.compactMap { id in
            id == item.id ? item : current.first(where: { $0.id == id })
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
        return lhs.kind == rhs.kind && lhs.palettes == rhs.palettes && lhs.backdrops == rhs.backdrops && lhs.colorId == rhs.colorId && lhs.backdropId == rhs.backdropId && lhs.emoji == rhs.emoji && lhs.gifts == rhs.gifts && lhs.giftId == rhs.giftId && lhs.themes == rhs.themes && lhs.themeId == rhs.themeId
    }
}
