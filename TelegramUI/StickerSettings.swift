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
    
    public static var defaultSettings: StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: .all)
    }
    
    init(emojiStickerSuggestionMode: EmojiStickerSuggestionMode) {
        self.emojiStickerSuggestionMode = emojiStickerSuggestionMode
    }
    
    public init(decoder: PostboxDecoder) {
        self.emojiStickerSuggestionMode = EmojiStickerSuggestionMode(rawValue: decoder.decodeInt32ForKey("emojiStickerSuggestionMode", orElse: 0))!
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.emojiStickerSuggestionMode.rawValue, forKey: "emojiStickerSuggestionMode")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? StickerSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: StickerSettings, rhs: StickerSettings) -> Bool {
        return lhs.emojiStickerSuggestionMode == rhs.emojiStickerSuggestionMode
    }
    
    func withUpdatedEmojiStickerSuggestionMode(_ emojiStickerSuggestionMode: EmojiStickerSuggestionMode) -> StickerSettings {
        return StickerSettings(emojiStickerSuggestionMode: emojiStickerSuggestionMode)
    }
}

func updateStickerSettingsInteractively(postbox: Postbox, _ f: @escaping (StickerSettings) -> StickerSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.stickerSettings, { entry in
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
