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
    
    public static var defaultSettings: StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: .all, suggestAnimatedEmoji: true)
    }
    
    init(emojiStickerSuggestionMode: EmojiStickerSuggestionMode, suggestAnimatedEmoji: Bool) {
        self.emojiStickerSuggestionMode = emojiStickerSuggestionMode
        self.suggestAnimatedEmoji = suggestAnimatedEmoji
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.emojiStickerSuggestionMode = EmojiStickerSuggestionMode(rawValue: try container.decode(Int32.self, forKey: "emojiStickerSuggestionMode"))!
        self.suggestAnimatedEmoji = try container.decodeIfPresent(Bool.self, forKey: "suggestAnimatedEmoji") ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.emojiStickerSuggestionMode.rawValue, forKey: "emojiStickerSuggestionMode")
        try container.encode(self.suggestAnimatedEmoji, forKey: "suggestAnimatedEmoji")
    }
    
    public static func ==(lhs: StickerSettings, rhs: StickerSettings) -> Bool {
        return lhs.emojiStickerSuggestionMode == rhs.emojiStickerSuggestionMode && lhs.suggestAnimatedEmoji == rhs.suggestAnimatedEmoji
    }
    
    public func withUpdatedEmojiStickerSuggestionMode(_ emojiStickerSuggestionMode: EmojiStickerSuggestionMode) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: emojiStickerSuggestionMode, suggestAnimatedEmoji: self.suggestAnimatedEmoji)
    }
    
    public func withUpdatedLoopAnimatedStickers(_ loopAnimatedStickers: Bool) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: self.emojiStickerSuggestionMode, suggestAnimatedEmoji: self.suggestAnimatedEmoji)
    }
    
    public func withUpdatedSuggestAnimatedEmoji(_ suggestAnimatedEmoji: Bool) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: self.emojiStickerSuggestionMode, suggestAnimatedEmoji: suggestAnimatedEmoji)
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
