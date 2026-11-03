import Foundation
import UIKit
import TelegramStringFormatting
import TextFormat

func chatListRichTextPreview(_ preview: NSAttributedString, font: UIFont, italicFont: UIFont, textColor: UIColor, additionalSpoilers: [NSRange]) -> NSAttributedString {
    let result = NSMutableAttributedString(attributedString: styleInstantPagePreview(preview, font: font, italicFont: italicFont, textColor: textColor))
    for range in additionalSpoilers {
        guard range.location >= 0, range.location <= result.length, range.length > 0, range.length <= result.length - range.location else { continue }
        result.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), value: true, range: range)
    }
    return renderInstantPagePreviewIcons(result, font: font, textColor: textColor)
}
