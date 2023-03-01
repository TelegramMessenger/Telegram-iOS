import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum EmojiStickerSuggestionMode: Int32 {
    case none
    case all
    case installed
}

public struct StickerSettings: Codable, Equatable {
    public var emojiStickerSuggestionMode: EmojiStickerSuggestionMode
    public var suggestAnimatedEmoji: Bool
    public var dynamicPackOrder: Bool
    
    public static var defaultSettings: StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: .all, suggestAnimatedEmoji: true, dynamicPackOrder: true)
    }
    
    init(emojiStickerSuggestionMode: EmojiStickerSuggestionMode, suggestAnimatedEmoji: Bool, dynamicPackOrder: Bool) {
        self.emojiStickerSuggestionMode = emojiStickerSuggestionMode
        self.suggestAnimatedEmoji = suggestAnimatedEmoji
        self.dynamicPackOrder = dynamicPackOrder
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.emojiStickerSuggestionMode = EmojiStickerSuggestionMode(rawValue: try container.decode(Int32.self, forKey: "emojiStickerSuggestionMode"))!
        self.suggestAnimatedEmoji = try container.decodeIfPresent(Bool.self, forKey: "suggestAnimatedEmoji") ?? true
        self.dynamicPackOrder = try container.decodeIfPresent(Bool.self, forKey: "dynamicPackOrder") ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.emojiStickerSuggestionMode.rawValue, forKey: "emojiStickerSuggestionMode")
        try container.encode(self.suggestAnimatedEmoji, forKey: "suggestAnimatedEmoji")
        try container.encode(self.dynamicPackOrder, forKey: "dynamicPackOrder")
    }
    
    public static func ==(lhs: StickerSettings, rhs: StickerSettings) -> Bool {
        return lhs.emojiStickerSuggestionMode == rhs.emojiStickerSuggestionMode && lhs.suggestAnimatedEmoji == rhs.suggestAnimatedEmoji && lhs.dynamicPackOrder == rhs.dynamicPackOrder
    }
    
    public func withUpdatedEmojiStickerSuggestionMode(_ emojiStickerSuggestionMode: EmojiStickerSuggestionMode) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: emojiStickerSuggestionMode, suggestAnimatedEmoji: self.suggestAnimatedEmoji, dynamicPackOrder: self.dynamicPackOrder)
    }
    
    public func withUpdatedLoopAnimatedStickers(_ loopAnimatedStickers: Bool) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: self.emojiStickerSuggestionMode, suggestAnimatedEmoji: self.suggestAnimatedEmoji, dynamicPackOrder: self.dynamicPackOrder)
    }
    
    public func withUpdatedSuggestAnimatedEmoji(_ suggestAnimatedEmoji: Bool) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: self.emojiStickerSuggestionMode, suggestAnimatedEmoji: suggestAnimatedEmoji, dynamicPackOrder: self.dynamicPackOrder)
    }
    
    public func withUpdatedDynamicPackOrder(_ dynamicPackOrder: Bool) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: self.emojiStickerSuggestionMode, suggestAnimatedEmoji: self.suggestAnimatedEmoji, dynamicPackOrder: dynamicPackOrder)
    }
}

public func updateStickerSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (StickerSettings) -> StickerSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.stickerSettings, { entry in
            let currentSettings: StickerSettings
            if let entry = entry?.get(StickerSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = StickerSettings.defaultSettings
            }
            return PreferencesEntry(f(currentSettings))
        })
    }
}
