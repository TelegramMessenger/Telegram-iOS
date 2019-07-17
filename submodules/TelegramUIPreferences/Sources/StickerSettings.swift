import Foundation
import Postbox
import SwiftSignalKit

public enum EmojiStickerSuggestionMode: Int32 {
    case none
    case all
    case installed
}

public struct StickerSettings: PreferencesEntry, Equatable {
    public var emojiStickerSuggestionMode: EmojiStickerSuggestionMode
    public var loopAnimatedStickers: Bool
    
    public static var defaultSettings: StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: .all, loopAnimatedStickers: true)
    }
    
    init(emojiStickerSuggestionMode: EmojiStickerSuggestionMode, loopAnimatedStickers: Bool) {
        self.emojiStickerSuggestionMode = emojiStickerSuggestionMode
        self.loopAnimatedStickers = loopAnimatedStickers
    }
    
    public init(decoder: PostboxDecoder) {
        self.emojiStickerSuggestionMode = EmojiStickerSuggestionMode(rawValue: decoder.decodeInt32ForKey("emojiStickerSuggestionMode", orElse: 0))!
        self.loopAnimatedStickers = decoder.decodeBoolForKey("loopAnimatedStickers", orElse: true)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.emojiStickerSuggestionMode.rawValue, forKey: "emojiStickerSuggestionMode")
        encoder.encodeBool(self.loopAnimatedStickers, forKey: "loopAnimatedStickers")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? StickerSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: StickerSettings, rhs: StickerSettings) -> Bool {
        return lhs.emojiStickerSuggestionMode == rhs.emojiStickerSuggestionMode && lhs.loopAnimatedStickers == rhs.loopAnimatedStickers
    }
    
    public func withUpdatedEmojiStickerSuggestionMode(_ emojiStickerSuggestionMode: EmojiStickerSuggestionMode) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: emojiStickerSuggestionMode, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    
    public func withUpdatedLoopAnimatedStickers(_ loopAnimatedStickers: Bool) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: self.emojiStickerSuggestionMode, loopAnimatedStickers: loopAnimatedStickers)
    }
}

public func updateStickerSettingsInteractively(accountManager: AccountManager, _ f: @escaping (StickerSettings) -> StickerSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.stickerSettings, { entry in
            let currentSettings: StickerSettings
            if let entry = entry as? StickerSettings {
                currentSettings = entry
            } else {
                currentSettings = StickerSettings.defaultSettings
            }
            return f(currentSettings)
        })
    }
}
