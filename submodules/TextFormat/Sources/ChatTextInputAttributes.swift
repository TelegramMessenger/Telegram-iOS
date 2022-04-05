import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramPresentationData

private let alphanumericCharacters = CharacterSet.alphanumerics

public struct ChatTextInputAttributes {
    public static let bold = NSAttributedString.Key(rawValue: "Attribute__Bold")
    public static let italic = NSAttributedString.Key(rawValue: "Attribute__Italic")
    public static let monospace = NSAttributedString.Key(rawValue: "Attribute__Monospace")
    public static let strikethrough = NSAttributedString.Key(rawValue: "Attribute__Strikethrough")
    public static let underline = NSAttributedString.Key(rawValue: "Attribute__Underline")
    public static let textMention = NSAttributedString.Key(rawValue: "Attribute__TextMention")
    public static let textUrl = NSAttributedString.Key(rawValue: "Attribute__TextUrl")
    public static let spoiler = NSAttributedString.Key(rawValue: "Attribute__Spoiler")
    
    public static let allAttributes = [ChatTextInputAttributes.bold, ChatTextInputAttributes.italic, ChatTextInputAttributes.monospace, ChatTextInputAttributes.strikethrough, ChatTextInputAttributes.underline, ChatTextInputAttributes.textMention, ChatTextInputAttributes.textUrl, ChatTextInputAttributes.spoiler]
}

public func stateAttributedStringForText(_ text: NSAttributedString) -> NSAttributedString {
    let result = NSMutableAttributedString(string: text.string)
    let fullRange = NSRange(location: 0, length: result.length)
    
    text.enumerateAttributes(in: fullRange, options: [], using: { attributes, range, _ in
        for (key, value) in attributes {
            if ChatTextInputAttributes.allAttributes.contains(key) {
                result.addAttribute(key, value: value, range: range)
            }
        }
    })
    return result
}

public struct ChatTextFontAttributes: OptionSet {
    public var rawValue: Int32 = 0
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let bold = ChatTextFontAttributes(rawValue: 1 << 0)
    public static let italic = ChatTextFontAttributes(rawValue: 1 << 1)
    public static let monospace = ChatTextFontAttributes(rawValue: 1 << 2)
    public static let blockQuote = ChatTextFontAttributes(rawValue: 1 << 3)
}

public func textAttributedStringForStateText(_ stateText: NSAttributedString, fontSize: CGFloat, textColor: UIColor, accentTextColor: UIColor, writingDirection: NSWritingDirection?, spoilersRevealed: Bool) -> NSAttributedString {
    let result = NSMutableAttributedString(string: stateText.string)
    let fullRange = NSRange(location: 0, length: result.length)
    
    result.addAttribute(NSAttributedString.Key.font, value: Font.regular(fontSize), range: fullRange)
    result.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: fullRange)
    let style = NSMutableParagraphStyle()
    if let writingDirection = writingDirection {
        style.baseWritingDirection = writingDirection
    }
    result.addAttribute(NSAttributedString.Key.paragraphStyle, value: style, range: fullRange)
    
    stateText.enumerateAttributes(in: fullRange, options: [], using: { attributes, range, _ in
        var fontAttributes: ChatTextFontAttributes = []
        
        for (key, value) in attributes {
            if key == ChatTextInputAttributes.textMention || key == ChatTextInputAttributes.textUrl {
                result.addAttribute(key, value: value, range: range)
                result.addAttribute(NSAttributedString.Key.foregroundColor, value: accentTextColor, range: range)
                if accentTextColor.isEqual(textColor) {
                    result.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
            } else if key == ChatTextInputAttributes.bold {
                result.addAttribute(key, value: value, range: range)
                fontAttributes.insert(.bold)
            } else if key == ChatTextInputAttributes.italic {
                result.addAttribute(key, value: value, range: range)
                fontAttributes.insert(.italic)
            } else if key == ChatTextInputAttributes.monospace {
                result.addAttribute(key, value: value, range: range)
                fontAttributes.insert(.monospace)
            } else if key == ChatTextInputAttributes.strikethrough {
                result.addAttribute(key, value: value, range: range)
                result.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
            } else if key == ChatTextInputAttributes.underline {
                result.addAttribute(key, value: value, range: range)
                result.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
            } else if key == ChatTextInputAttributes.spoiler {
                result.addAttribute(key, value: value, range: range)
                if spoilersRevealed {
                    result.addAttribute(NSAttributedString.Key.backgroundColor, value: textColor.withAlphaComponent(0.15), range: range)
                } else {
                    result.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: range)
                }
            }
        }
            
        if !fontAttributes.isEmpty {
            var font: UIFont?
            if fontAttributes == [.bold, .italic, .monospace] {
                font = Font.semiboldItalicMonospace(fontSize)
            } else if fontAttributes == [.bold, .monospace] {
                font = Font.semiboldMonospace(fontSize)
            } else if fontAttributes == [.italic, .monospace] {
                font = Font.italicMonospace(fontSize)
            } else if fontAttributes == [.bold, .italic] {
                font = Font.semiboldItalic(fontSize)
            } else if fontAttributes == [.bold] {
                font = Font.semibold(fontSize)
            } else if fontAttributes == [.italic] {
                font = Font.italic(fontSize)
            } else if fontAttributes == [.monospace] {
                font = Font.monospace(fontSize)
            }
            
            if let font = font {
                result.addAttribute(NSAttributedString.Key.font, value: font, range: range)
            }
        }
    })
    return result
}

public final class ChatTextInputTextMentionAttribute: NSObject {
    public let peerId: PeerId
    
    public init(peerId: PeerId) {
        self.peerId = peerId
        
        super.init()
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        if let other = object as? ChatTextInputTextMentionAttribute {
            return self.peerId == other.peerId
        } else {
            return false
        }
    }
}

private func textMentionRangesEqual(_ lhs: [(NSRange, ChatTextInputTextMentionAttribute)], _ rhs: [(NSRange, ChatTextInputTextMentionAttribute)]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if lhs[i].0 != rhs[i].0 || lhs[i].1.peerId != rhs[i].1.peerId {
            return false
        }
    }
    return true
}

public final class ChatTextInputTextUrlAttribute: NSObject {
    public let url: String
    
    public init(url: String) {
        self.url = url
        
        super.init()
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        if let other = object as? ChatTextInputTextUrlAttribute {
            return self.url == other.url
        } else {
            return false
        }
    }
}

private func textUrlRangesEqual(_ lhs: [(NSRange, ChatTextInputTextUrlAttribute)], _ rhs: [(NSRange, ChatTextInputTextUrlAttribute)]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if lhs[i].0 != rhs[i].0 || lhs[i].1.url != rhs[i].1.url {
            return false
        }
    }
    return true
}

private func refreshTextMentions(text: NSString, initialAttributedText: NSAttributedString, attributedText: NSMutableAttributedString, fullRange: NSRange) {
    var textMentionRanges: [(NSRange, ChatTextInputTextMentionAttribute)] = []
    initialAttributedText.enumerateAttribute(ChatTextInputAttributes.textMention, in: fullRange, options: [], using: { value, range, _ in
        if let value = value as? ChatTextInputTextMentionAttribute {
            textMentionRanges.append((range, value))
        }
    })
    textMentionRanges.sort(by: { $0.0.location < $1.0.location })
    let initialTextMentionRanges = textMentionRanges
    
    for i in 0 ..< textMentionRanges.count {
        let range = textMentionRanges[i].0
        
        var validLower = range.lowerBound
        inner1: for i in range.lowerBound ..< range.upperBound {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) || c == " " as UnicodeScalar {
                    validLower = i
                    break inner1
                }
            } else {
                break inner1
            }
        }
        var validUpper = range.upperBound
        inner2: for i in (validLower ..< range.upperBound).reversed() {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) || c == " " as UnicodeScalar {
                    validUpper = i + 1
                    break inner2
                }
            } else {
                break inner2
            }
        }
        
        let minLower = (i == 0) ? fullRange.lowerBound : textMentionRanges[i - 1].0.upperBound
        inner3: for i in (minLower ..< validLower).reversed() {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) {
                    validLower = i
                } else {
                    break inner3
                }
            } else {
                break inner3
            }
        }
        
        let maxUpper = (i == textMentionRanges.count - 1) ? fullRange.upperBound : textMentionRanges[i + 1].0.lowerBound
        inner3: for i in validUpper ..< maxUpper {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) {
                    validUpper = i + 1
                } else {
                    break inner3
                }
            } else {
                break inner3
            }
        }
        
        textMentionRanges[i] = (NSRange(location: validLower, length: validUpper - validLower), textMentionRanges[i].1)
    }
    
    textMentionRanges = textMentionRanges.filter({ $0.0.length > 0 })
    
    while textMentionRanges.count > 1 {
        var hadReductions = false
        outer: for i in 0 ..< textMentionRanges.count - 1 {
            if textMentionRanges[i].1 === textMentionRanges[i + 1].1 {
                var combine = true
                inner: for j in textMentionRanges[i].0.upperBound ..< textMentionRanges[i + 1].0.lowerBound {
                    if let c = UnicodeScalar(text.character(at: j)) {
                        if alphanumericCharacters.contains(c) || c == " " as UnicodeScalar {
                        } else {
                            combine = false
                            break inner
                        }
                    } else {
                        combine = false
                        break inner
                    }
                }
                if combine {
                    hadReductions = true
                    textMentionRanges[i] = (NSRange(location: textMentionRanges[i].0.lowerBound, length: textMentionRanges[i + 1].0.upperBound - textMentionRanges[i].0.lowerBound), textMentionRanges[i].1)
                    textMentionRanges.remove(at: i + 1)
                    break outer
                }
            }
        }
        if !hadReductions {
            break
        }
    }
    
    if textMentionRanges.count > 1 {
        outer: for i in (1 ..< textMentionRanges.count).reversed() {
            for j in 0 ..< i {
                if textMentionRanges[j].1 === textMentionRanges[i].1 {
                    textMentionRanges.remove(at: i)
                    continue outer
                }
            }
        }
    }
    
    if !textMentionRangesEqual(textMentionRanges, initialTextMentionRanges) {
        attributedText.removeAttribute(ChatTextInputAttributes.textMention, range: fullRange)
        for (range, attribute) in textMentionRanges {
            attributedText.addAttribute(ChatTextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: attribute.peerId), range: range)
        }
    }
}

private func refreshTextUrls(text: NSString, initialAttributedText: NSAttributedString, attributedText: NSMutableAttributedString, fullRange: NSRange) {
    var textUrlRanges: [(NSRange, ChatTextInputTextUrlAttribute)] = []
    initialAttributedText.enumerateAttribute(ChatTextInputAttributes.textUrl, in: fullRange, options: [], using: { value, range, _ in
        if let value = value as? ChatTextInputTextUrlAttribute {
            textUrlRanges.append((range, value))
        }
    })
    textUrlRanges.sort(by: { $0.0.location < $1.0.location })
    let initialTextUrlRanges = textUrlRanges
    
    for i in 0 ..< textUrlRanges.count {
        let range = textUrlRanges[i].0
        
        var validLower = range.lowerBound
        inner1: for i in range.lowerBound ..< range.upperBound {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) || c == " " as UnicodeScalar {
                    validLower = i
                    break inner1
                }
            } else {
                break inner1
            }
        }
        var validUpper = range.upperBound
        inner2: for i in (validLower ..< range.upperBound).reversed() {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) || c == " " as UnicodeScalar {
                    validUpper = i + 1
                    break inner2
                }
            } else {
                break inner2
            }
        }
        
        let minLower = (i == 0) ? fullRange.lowerBound : textUrlRanges[i - 1].0.upperBound
        inner3: for i in (minLower ..< validLower).reversed() {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) {
                    validLower = i
                } else {
                    break inner3
                }
            } else {
                break inner3
            }
        }
        
        let maxUpper = (i == textUrlRanges.count - 1) ? fullRange.upperBound : textUrlRanges[i + 1].0.lowerBound
        inner3: for i in validUpper ..< maxUpper {
            if let c = UnicodeScalar(text.character(at: i)) {
                if alphanumericCharacters.contains(c) {
                    validUpper = i + 1
                } else {
                    break inner3
                }
            } else {
                break inner3
            }
        }
        
        textUrlRanges[i] = (NSRange(location: validLower, length: validUpper - validLower), textUrlRanges[i].1)
    }
    
    textUrlRanges = textUrlRanges.filter({ $0.0.length > 0 })
    
    while textUrlRanges.count > 1 {
        var hadReductions = false
        outer: for i in 0 ..< textUrlRanges.count - 1 {
            if textUrlRanges[i].1 === textUrlRanges[i + 1].1 {
                var combine = true
                inner: for j in textUrlRanges[i].0.upperBound ..< textUrlRanges[i + 1].0.lowerBound {
                    if let c = UnicodeScalar(text.character(at: j)) {
                        if alphanumericCharacters.contains(c) || c == " " as UnicodeScalar {
                        } else {
                            combine = false
                            break inner
                        }
                    } else {
                        combine = false
                        break inner
                    }
                }
                if combine {
                    hadReductions = true
                    textUrlRanges[i] = (NSRange(location: textUrlRanges[i].0.lowerBound, length: textUrlRanges[i + 1].0.upperBound - textUrlRanges[i].0.lowerBound), textUrlRanges[i].1)
                    textUrlRanges.remove(at: i + 1)
                    break outer
                }
            }
        }
        if !hadReductions {
            break
        }
    }
    
    if textUrlRanges.count > 1 {
        outer: for i in (1 ..< textUrlRanges.count).reversed() {
            for j in 0 ..< i {
                if textUrlRanges[j].1 === textUrlRanges[i].1 {
                    textUrlRanges.remove(at: i)
                    continue outer
                }
            }
        }
    }
    
    if !textUrlRangesEqual(textUrlRanges, initialTextUrlRanges) {
        attributedText.removeAttribute(ChatTextInputAttributes.textUrl, range: fullRange)
        for (range, attribute) in textUrlRanges {
            attributedText.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: attribute.url), range: range)
        }
    }
}

public func refreshChatTextInputAttributes(_ textNode: ASEditableTextNode, theme: PresentationTheme, baseFontSize: CGFloat, spoilersRevealed: Bool) {
    guard let initialAttributedText = textNode.attributedText, initialAttributedText.length != 0 else {
        return
    }
    
    var writingDirection: NSWritingDirection?
    if let style = initialAttributedText.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
        writingDirection = style.baseWritingDirection
    }
    
    var text: NSString = initialAttributedText.string as NSString
    var fullRange = NSRange(location: 0, length: initialAttributedText.length)
    var attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(initialAttributedText))
    refreshTextMentions(text: text, initialAttributedText: initialAttributedText, attributedText: attributedText, fullRange: fullRange)
    
    var resultAttributedText = textAttributedStringForStateText(attributedText, fontSize: baseFontSize, textColor: theme.chat.inputPanel.primaryTextColor, accentTextColor: theme.chat.inputPanel.panelControlAccentColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed)
    
    text = resultAttributedText.string as NSString
    fullRange = NSRange(location: 0, length: initialAttributedText.length)
    attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(resultAttributedText))
    refreshTextUrls(text: text, initialAttributedText: resultAttributedText, attributedText: attributedText, fullRange: fullRange)
    
    resultAttributedText = textAttributedStringForStateText(attributedText, fontSize: baseFontSize, textColor: theme.chat.inputPanel.primaryTextColor, accentTextColor: theme.chat.inputPanel.panelControlAccentColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed)
    
    if !resultAttributedText.isEqual(to: initialAttributedText) {
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.font, range: fullRange)
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.foregroundColor, range: fullRange)
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.underlineStyle, range: fullRange)
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.strikethroughStyle, range: fullRange)
        textNode.textView.textStorage.removeAttribute(ChatTextInputAttributes.textMention, range: fullRange)
        textNode.textView.textStorage.removeAttribute(ChatTextInputAttributes.textUrl, range: fullRange)
        textNode.textView.textStorage.removeAttribute(ChatTextInputAttributes.spoiler, range: fullRange)
        
        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.font, value: Font.regular(baseFontSize), range: fullRange)
        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.chat.inputPanel.primaryTextColor, range: fullRange)
        
        attributedText.enumerateAttributes(in: fullRange, options: [], using: { attributes, range, _ in
            var fontAttributes: ChatTextFontAttributes = []
            
            for (key, value) in attributes {
                if key == ChatTextInputAttributes.textMention || key == ChatTextInputAttributes.textUrl {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.chat.inputPanel.panelControlAccentColor, range: range)
                    
                    if theme.chat.inputPanel.panelControlAccentColor.isEqual(theme.chat.inputPanel.primaryTextColor) {
                        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                    }
                } else if key == ChatTextInputAttributes.bold {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.bold)
                } else if key == ChatTextInputAttributes.italic {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.italic)
                } else if key == ChatTextInputAttributes.monospace {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.monospace)
                } else if key == ChatTextInputAttributes.strikethrough {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.underline {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.spoiler {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    if spoilersRevealed {
                        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.backgroundColor, value: theme.chat.inputPanel.primaryTextColor.withAlphaComponent(0.15), range: range)
                    } else {
                        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: range)
                    }
                }
            }
                
            if !fontAttributes.isEmpty {
                var font: UIFont?
                if fontAttributes == [.bold, .italic, .monospace] {
                    font = Font.semiboldItalicMonospace(baseFontSize)
                } else if fontAttributes == [.bold, .italic] {
                    font = Font.semiboldItalic(baseFontSize)
                } else if fontAttributes == [.bold, .monospace] {
                    font = Font.semiboldMonospace(baseFontSize)
                } else if fontAttributes == [.italic, .monospace] {
                    font = Font.italicMonospace(baseFontSize)
                } else if fontAttributes == [.bold] {
                    font = Font.semibold(baseFontSize)
                } else if fontAttributes == [.italic] {
                    font = Font.italic(baseFontSize)
                } else if fontAttributes == [.monospace] {
                    font = Font.monospace(baseFontSize)
                }
                
                if let font = font {
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.font, value: font, range: range)
                }
            }
        })
    }
}

public func refreshGenericTextInputAttributes(_ textNode: ASEditableTextNode, theme: PresentationTheme, baseFontSize: CGFloat, spoilersRevealed: Bool = false) {
    guard let initialAttributedText = textNode.attributedText, initialAttributedText.length != 0 else {
        return
    }
    
    var writingDirection: NSWritingDirection?
    if let style = initialAttributedText.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
        writingDirection = style.baseWritingDirection
    }
    
    var text: NSString = initialAttributedText.string as NSString
    var fullRange = NSRange(location: 0, length: initialAttributedText.length)
    var attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(initialAttributedText))
    var resultAttributedText = textAttributedStringForStateText(attributedText, fontSize: baseFontSize, textColor: theme.chat.inputPanel.primaryTextColor, accentTextColor: theme.chat.inputPanel.panelControlAccentColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed)
    
    text = resultAttributedText.string as NSString
    fullRange = NSRange(location: 0, length: initialAttributedText.length)
    attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(resultAttributedText))
    refreshTextUrls(text: text, initialAttributedText: resultAttributedText, attributedText: attributedText, fullRange: fullRange)
    
    resultAttributedText = textAttributedStringForStateText(attributedText, fontSize: baseFontSize, textColor: theme.chat.inputPanel.primaryTextColor, accentTextColor: theme.chat.inputPanel.panelControlAccentColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed)
    
    if !resultAttributedText.isEqual(to: initialAttributedText) {
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.font, range: fullRange)
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.foregroundColor, range: fullRange)
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.underlineStyle, range: fullRange)
        textNode.textView.textStorage.removeAttribute(NSAttributedString.Key.strikethroughStyle, range: fullRange)
        textNode.textView.textStorage.removeAttribute(ChatTextInputAttributes.textMention, range: fullRange)
        textNode.textView.textStorage.removeAttribute(ChatTextInputAttributes.textUrl, range: fullRange)
        textNode.textView.textStorage.removeAttribute(ChatTextInputAttributes.spoiler, range: fullRange)
        
        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.font, value: Font.regular(baseFontSize), range: fullRange)
        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.chat.inputPanel.primaryTextColor, range: fullRange)
        
        attributedText.enumerateAttributes(in: fullRange, options: [], using: { attributes, range, _ in
            var fontAttributes: ChatTextFontAttributes = []
            
            for (key, value) in attributes {
                if key == ChatTextInputAttributes.textMention || key == ChatTextInputAttributes.textUrl {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.chat.inputPanel.panelControlAccentColor, range: range)
                    
                    if theme.chat.inputPanel.panelControlAccentColor.isEqual(theme.chat.inputPanel.primaryTextColor) {
                        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                    }
                } else if key == ChatTextInputAttributes.bold {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.bold)
                } else if key == ChatTextInputAttributes.italic {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.italic)
                } else if key == ChatTextInputAttributes.monospace {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.monospace)
                } else if key == ChatTextInputAttributes.strikethrough {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.underline {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.spoiler {
                    textNode.textView.textStorage.addAttribute(key, value: value, range: range)
                    if spoilersRevealed {
                        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.backgroundColor, value: theme.chat.inputPanel.primaryTextColor.withAlphaComponent(0.15), range: range)
                    } else {
                        textNode.textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: range)
                    }
                }
            }
                
            if !fontAttributes.isEmpty {
                var font: UIFont?
                if fontAttributes == [.bold, .italic, .monospace] {
                    font = Font.semiboldItalicMonospace(baseFontSize)
                } else if fontAttributes == [.bold, .italic] {
                    font = Font.semiboldItalic(baseFontSize)
                } else if fontAttributes == [.bold, .monospace] {
                    font = Font.semiboldMonospace(baseFontSize)
                } else if fontAttributes == [.italic, .monospace] {
                    font = Font.italicMonospace(baseFontSize)
                } else if fontAttributes == [.bold] {
                    font = Font.semibold(baseFontSize)
                } else if fontAttributes == [.italic] {
                    font = Font.italic(baseFontSize)
                } else if fontAttributes == [.monospace] {
                    font = Font.monospace(baseFontSize)
                }
                
                if let font = font {
                    textNode.textView.textStorage.addAttribute(NSAttributedString.Key.font, value: font, range: range)
                }
            }
        })
    }
}

public func refreshChatTextInputTypingAttributes(_ textNode: ASEditableTextNode, theme: PresentationTheme, baseFontSize: CGFloat) {
    var filteredAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: Font.regular(baseFontSize),
        NSAttributedString.Key.foregroundColor: theme.chat.inputPanel.primaryTextColor
    ]
    let style = NSMutableParagraphStyle()
    style.baseWritingDirection = .natural
    filteredAttributes[NSAttributedString.Key.paragraphStyle] = style
    if let attributedText = textNode.attributedText, attributedText.length != 0 {
        let attributes = attributedText.attributes(at: max(0, min(textNode.selectedRange.location - 1, attributedText.length - 1)), effectiveRange: nil)
        for (key, value) in attributes {
            if key == ChatTextInputAttributes.bold {
                filteredAttributes[key] = value
            } else if key == ChatTextInputAttributes.italic {
                filteredAttributes[key] = value
            } else if key == ChatTextInputAttributes.monospace {
                filteredAttributes[key] = value
            } else if key == NSAttributedString.Key.font {
                filteredAttributes[key] = value
            }
        }
    }
    textNode.textView.typingAttributes = filteredAttributes
}

private func trimRangesForChatInputText(_ text: NSAttributedString) -> (Int, Int) {
    var lower = 0
    var upper = 0
    
    let trimmedCharacters: [UnicodeScalar] = [" ", "\t", "\n", "\u{200C}"]
    
    let nsString: NSString = text.string as NSString
    
    for i in 0 ..< nsString.length {
        if let c = UnicodeScalar(nsString.character(at: i)) {
            if trimmedCharacters.contains(c) {
                lower += 1
            } else {
                break
            }
        } else {
            break
        }
    }
    
    if lower != nsString.length {
        for i in (lower ..< nsString.length).reversed() {
            if let c = UnicodeScalar(nsString.character(at: i)) {
                if trimmedCharacters.contains(c) {
                    upper += 1
                } else {
                    break
                }
            } else {
                break
            }
        }
    }
    
    return (lower, upper)
}

public func trimChatInputText(_ text: NSAttributedString) -> NSAttributedString {
    let (lower, upper) = trimRangesForChatInputText(text)
    if lower == 0 && upper == 0 {
        return text
    }
    
    let result = NSMutableAttributedString(attributedString: text)
    if upper != 0 {
        result.replaceCharacters(in: NSRange(location: result.length - upper, length: upper), with: "")
    }
    if lower != 0 {
        result.replaceCharacters(in: NSRange(location: 0, length: lower), with: "")
    }
    return result
}

public func breakChatInputText(_ text: NSAttributedString) -> [NSAttributedString] {
    if text.length <= 4096 {
        return [text]
    } else {
        let rawText: NSString = text.string as NSString
        var result: [NSAttributedString] = []
        var offset = 0
        while offset < text.length {
            var range = NSRange(location: offset, length: min(text.length - offset, 4096))
            if range.upperBound < text.length {
                inner: for i in (range.lowerBound ..< range.upperBound).reversed() {
                    let c = rawText.character(at: i)
                    let uc = UnicodeScalar(c)
                    if uc == "\n" as UnicodeScalar || uc == "." as UnicodeScalar {
                        range.length = i + 1 - range.location
                        break inner
                    }
                }
            }
            result.append(trimChatInputText(text.attributedSubstring(from: range)))
            offset = range.upperBound
        }
        return result
    }
}

private let markdownRegexFormat = "(^|\\s|\\n)(````?)([\\s\\S]+?)(````?)([\\s\\n\\.,:?!;]|$)|(^|\\s)(`|\\*\\*|__|~~|\\|\\|)([^\\n]+?)\\7([\\s\\.,:?!;]|$)|@(\\d+)\\s*\\((.+?)\\)"
private let markdownRegex = try? NSRegularExpression(pattern: markdownRegexFormat, options: [.caseInsensitive, .anchorsMatchLines])

public func convertMarkdownToAttributes(_ text: NSAttributedString) -> NSAttributedString {
    var string = text.string as NSString
    
    var offsetRanges:[(NSRange, Int)] = []
    if let regex = markdownRegex {
        var stringOffset = 0
        let result = NSMutableAttributedString()
        
        while let match = regex.firstMatch(in: string as String, range: NSMakeRange(0, string.length)) {
            let matchIndex = stringOffset + match.range.location
            
            result.append(text.attributedSubstring(from: NSMakeRange(text.length - string.length, match.range.location)))
            
            var pre = match.range(at: 3)
            if pre.location != NSNotFound {
                var intersectsWithEntities = false
                text.enumerateAttributes(in: pre, options: [], using: { attributes, _, _ in
                    for (key, _) in attributes {
                        if key.rawValue.hasPrefix("Attribute__") {
                            intersectsWithEntities = true
                        }
                    }
                })
                if intersectsWithEntities {
                    result.append(text.attributedSubstring(from: match.range(at: 0)))
                } else {
                    let text = string.substring(with: pre)
                    
                    stringOffset -= match.range(at: 2).length + match.range(at: 4).length
                    
                    let substring = string.substring(with: match.range(at: 1)) + text + string.substring(with: match.range(at: 5))
                    result.append(NSAttributedString(string: substring, attributes: [ChatTextInputAttributes.monospace: true as NSNumber]))
                    offsetRanges.append((NSMakeRange(matchIndex + match.range(at: 1).length, text.count), 6))
                }
            }
            
            pre = match.range(at: 8)
            if pre.location != NSNotFound {
                var intersectsWithEntities = false
                text.enumerateAttributes(in: pre, options: [], using: { attributes, _, _ in
                    for (key, _) in attributes {
                        if key.rawValue.hasPrefix("Attribute__") {
                            intersectsWithEntities = true
                        }
                    }
                })
                if intersectsWithEntities {
                    result.append(text.attributedSubstring(from: match.range(at: 0)))
                } else {
                    let text = string.substring(with: pre)
                    
                    let entity = string.substring(with: match.range(at: 7))
                    let substring = string.substring(with: match.range(at: 6)) + text + string.substring(with: match.range(at: 9))
                    
                    let textInputAttribute: NSAttributedString.Key?
                    switch entity {
                        case "`":
                            textInputAttribute = ChatTextInputAttributes.monospace
                        case "**":
                            textInputAttribute = ChatTextInputAttributes.bold
                        case "__":
                            textInputAttribute = ChatTextInputAttributes.italic
                        case "~~":
                            textInputAttribute = ChatTextInputAttributes.strikethrough
                        case "||":
                            textInputAttribute = ChatTextInputAttributes.spoiler
                        default:
                            textInputAttribute = nil
                    }
                    
                    if let textInputAttribute = textInputAttribute {
                        result.append(NSAttributedString(string: substring, attributes: [textInputAttribute: true as NSNumber]))
                        offsetRanges.append((NSMakeRange(matchIndex + match.range(at: 6).length, text.count), match.range(at: 6).length * 2))
                    }
                    
                    stringOffset -= match.range(at: 7).length * 2
                }
            }
            
            string = string.substring(from: match.range.location + match.range(at: 0).length) as NSString
            stringOffset += match.range.location + match.range(at: 0).length
        }
        
        if string.length > 0 {
            result.append(text.attributedSubstring(from: NSMakeRange(text.length - string.length, string.length)))
        }
            
        return result
    }
    
    return text
}
