import Foundation
import UIKit
import TelegramCore
import TelegramPresentationData

/// The entities a chat list preview keeps: spoilers, custom emoji, formatted dates and the inline styles.
/// Links, mentions, hashtags, code, quotes and the rest are dropped. The News feed's rows use it too.
public func chatListPreviewTextEntities(_ entities: [MessageTextEntity]) -> [MessageTextEntity] {
    return entities.filter { entity in
        switch entity.type {
        case .Spoiler, .CustomEmoji, .FormattedDate:
            return true
        case .Strikethrough, .Underline, .Italic, .Bold:
            return true
        default:
            return false
        }
    }
}

/// A preview's text as the chat list draws it, from entities already narrowed to a preview's: bold in the
/// regular face and links in the text colour, so of the styles only italic (in `italicFont`), strikethrough
/// and underline show.
public func chatListPreviewAttributedString(_ text: String, entities: [MessageTextEntity], strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, font: UIFont, italicFont: UIFont, textColor: UIColor, message: EngineRawMessage?) -> NSAttributedString {
    return stringWithAppliedEntities(text, entities: entities, strings: strings, dateTimeFormat: dateTimeFormat, baseColor: textColor, linkColor: textColor, baseFont: font, linkFont: font, boldFont: font, italicFont: italicFont, boldItalicFont: font, fixedFont: font, blockQuoteFont: font, underlineLinks: false, message: message)
}
