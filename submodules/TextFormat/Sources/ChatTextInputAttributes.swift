import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import TelegramPresentationData
import Emoji

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
    public static let customEmoji = NSAttributedString.Key(rawValue: "Attribute__CustomEmoji")
    public static let block = NSAttributedString.Key(rawValue: "Attribute__Blockquote")
    public static let collapsedBlock = NSAttributedString.Key(rawValue: "Attribute__CollapsedBlockquote")
    
    public static let allAttributes = [ChatTextInputAttributes.bold, ChatTextInputAttributes.italic, ChatTextInputAttributes.monospace, ChatTextInputAttributes.strikethrough, ChatTextInputAttributes.underline, ChatTextInputAttributes.textMention, ChatTextInputAttributes.textUrl, ChatTextInputAttributes.spoiler, ChatTextInputAttributes.customEmoji, ChatTextInputAttributes.block, ChatTextInputAttributes.collapsedBlock]
}

public let originalTextAttributeKey = NSAttributedString.Key(rawValue: "Attribute__OriginalText")
public final class OriginalTextAttribute: NSObject {
    public let id: Int
    public let string: String
    
    public init(id: Int, string: String) {
        self.id = id
        self.string = string
    }
}

public final class ChatInputTextCollapsedQuoteAttributes: Equatable {
    public let context: AnyObject
    public let fontSize: CGFloat
    public let textColor: UIColor
    public let accentTextColor: UIColor
    
    public init(
        context: AnyObject,
        fontSize: CGFloat,
        textColor: UIColor,
        accentTextColor: UIColor
    ) {
        self.context = context
        self.fontSize = fontSize
        self.textColor = textColor
        self.accentTextColor = accentTextColor
    }
    
    public static func ==(lhs: ChatInputTextCollapsedQuoteAttributes, rhs: ChatInputTextCollapsedQuoteAttributes) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if !lhs.textColor.isEqual(rhs.textColor) {
            return false
        }
        if !lhs.accentTextColor.isEqual(rhs.accentTextColor) {
            return false
        }
        
        return true
    }
}

public protocol ChatInputTextCollapsedQuoteAttachment: NSTextAttachment {
    var text: NSAttributedString { get }
}

public func expandedInputStateAttributedString(_ text: NSAttributedString) -> NSAttributedString {
    let sourceString = NSMutableAttributedString(attributedString: text)
    while true {
        var found = false
        let fullRange = NSRange(sourceString.string.startIndex ..< sourceString.string.endIndex, in: sourceString.string)
        sourceString.enumerateAttribute(ChatTextInputAttributes.collapsedBlock, in: fullRange, options: [.longestEffectiveRangeNotRequired], using: { value, range, stop in
            if let value = value as? NSAttributedString {
                let updatedBlockString = NSMutableAttributedString(attributedString: value)
                updatedBlockString.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: true), range: NSRange(location: 0, length: updatedBlockString.length))
                sourceString.replaceCharacters(in: range, with: updatedBlockString)
                stop.pointee = true
                found = true
            }
        })
        if !found {
            break
        }
    }
    return sourceString
}

public func stateAttributedStringForText(_ text: NSAttributedString) -> NSAttributedString {
    let sourceString = NSMutableAttributedString(attributedString: text)
    while true {
        var found = false
        let fullRange = NSRange(sourceString.string.startIndex ..< sourceString.string.endIndex, in: sourceString.string)
        sourceString.enumerateAttribute(NSAttributedString.Key.attachment, in: fullRange, options: [.longestEffectiveRangeNotRequired], using: { value, range, stop in
            if let value = value as? EmojiTextAttachment {
                sourceString.replaceCharacters(in: range, with: NSAttributedString(string: value.text, attributes: [ChatTextInputAttributes.customEmoji: value.emoji]))
                stop.pointee = true
                found = true
            } else if let value = value as? ChatInputTextCollapsedQuoteAttachment {
                sourceString.replaceCharacters(in: range, with: NSAttributedString(string: " ", attributes: [ChatTextInputAttributes.collapsedBlock: value.text]))
                stop.pointee = true
                found = true
            }
        })
        if !found {
            break
        }
    }
    
    let result = NSMutableAttributedString(string: sourceString.string)
    let fullRange = NSRange(location: 0, length: result.length)
    
    sourceString.enumerateAttributes(in: fullRange, options: [], using: { attributes, range, _ in
        for (key, value) in attributes {
            var matchAttribute = false
            if ChatTextInputAttributes.allAttributes.contains(key) {
                matchAttribute = true
            } else if key == NSAttributedString.Key.attachment {
                if value is EmojiTextAttachment {
                    matchAttribute = true
                }
            }
            if matchAttribute {
                result.addAttribute(key, value: value, range: range)
            }
        }
    })
    return result
}

public struct ChatTextFontAttributes: OptionSet, Hashable, Sequence {
    public var rawValue: UInt32 = 0
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let bold = ChatTextFontAttributes(rawValue: 1 << 0)
    public static let italic = ChatTextFontAttributes(rawValue: 1 << 1)
    public static let monospace = ChatTextFontAttributes(rawValue: 1 << 2)
    public static let blockQuote = ChatTextFontAttributes(rawValue: 1 << 3)
    public static let smaller = ChatTextFontAttributes(rawValue: 1 << 4)
    
    public func makeIterator() -> AnyIterator<ChatTextFontAttributes> {
        var index = 0
        return AnyIterator { () -> ChatTextFontAttributes? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = ChatTextFontAttributes(rawValue: 1 << UInt32(index))
                index += 1
                if currentTags == 0 {
                    break
                }
                
                if (currentTags & 1) != 0 {
                    return tag
                }
            }
            return nil
        }
    }
}

public func textAttributedStringForStateText(context: AnyObject, stateText: NSAttributedString, fontSize: CGFloat, textColor: UIColor, accentTextColor: UIColor, writingDirection: NSWritingDirection?, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?, makeCollapsedQuoteAttachment: ((NSAttributedString, ChatInputTextCollapsedQuoteAttributes) -> ChatInputTextCollapsedQuoteAttachment)?) -> NSAttributedString {
    let quoteAttributes = ChatInputTextCollapsedQuoteAttributes(
        context: context,
        fontSize: round(fontSize * 0.8235294117647058),
        textColor: textColor,
        accentTextColor: accentTextColor
    )
    
    let stateText = NSMutableAttributedString(attributedString: stateText)
    
    /*while true {
        var found = false
        stateText.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: stateText.length), options: [.longestEffectiveRangeNotRequired], using: { value, range, stop in
            if let value = value as? ChatTextInputTextQuoteAttribute {
                if value.isCollapsed, let makeCollapsedQuoteAttachment {
                    found = true
                    stop.pointee = true
                    
                    let quoteText = stateText.attributedSubstring(from: range)
                    stateText.replaceCharacters(in: range, with: "")
                    stateText.insert(NSAttributedString(attachment: makeCollapsedQuoteAttachment(quoteText, quoteAttributes)), at: range.lowerBound)
                }
            }
        })
        if !found {
            break
        }
    }*/
    while true {
        var found = false
        stateText.enumerateAttribute(ChatTextInputAttributes.collapsedBlock, in: NSRange(location: 0, length: stateText.length), options: [.longestEffectiveRangeNotRequired], using: { value, range, stop in
            if let value = value as? NSAttributedString {
                if let makeCollapsedQuoteAttachment {
                    found = true
                    stop.pointee = true
                    
                    stateText.replaceCharacters(in: range, with: "")
                    stateText.insert(NSAttributedString(attachment: makeCollapsedQuoteAttachment(value, quoteAttributes)), at: range.lowerBound)
                }
            }
        })
        if !found {
            break
        }
    }
    
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
            } else if key == ChatTextInputAttributes.customEmoji {
                result.addAttribute(key, value: value, range: range)
                result.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: range)
            } else if key == ChatTextInputAttributes.block, let value = value as? ChatTextInputTextQuoteAttribute {
                switch value.kind {
                case .quote:
                    fontAttributes.insert(.blockQuote)
                case .code:
                    fontAttributes.insert(.monospace)
                }
                result.addAttribute(key, value: value, range: range)
            } else if key == .attachment, value is ChatInputTextCollapsedQuoteAttachment {
                result.addAttribute(key, value: value, range: range)
            }
        }
            
        if !fontAttributes.isEmpty {
            var font: UIFont?
            var fontSize = fontSize
            if fontAttributes.contains(.blockQuote) {
                fontAttributes.remove(.blockQuote)
                fontSize = round(fontSize * 0.8235294117647058)
            }
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
            } else {
                font = Font.regular(fontSize)
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

public final class ChatTextInputTextQuoteAttribute: NSObject {
    public enum Kind: Equatable {
        case quote
        case code(language: String?)
    }
    
    public let kind: Kind
    public let isCollapsed: Bool
    
    public init(kind: Kind, isCollapsed: Bool) {
        self.kind = kind
        self.isCollapsed = isCollapsed
        
        super.init()
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ChatTextInputTextQuoteAttribute else {
            return false
        }
        
        if self.kind != other.kind {
            return false
        }
        if self.isCollapsed != other.isCollapsed {
            return false
        }
        
        return true
    }
}

public final class ChatTextInputTextCustomEmojiAttribute: NSObject, Codable {
    private enum CodingKeys: String, CodingKey {
        case interactivelySelectedFromPackId
        case fileId
        case file
        case topicId
        case topicInfo
        case enableAnimation
    }
    
    public enum Custom: Codable {
        case topic(id: Int64, info: EngineMessageHistoryThread.Info)
        case nameColors([UInt32])
        case stars(tinted: Bool)
        case ton(tinted: Bool)
        case animation(name: String)
        case verification
    }
    
    public let interactivelySelectedFromPackId: ItemCollectionId?
    public let fileId: Int64
    public let file: TelegramMediaFile?
    public let custom: Custom?
    public let enableAnimation: Bool
    
    public init(interactivelySelectedFromPackId: ItemCollectionId?, fileId: Int64, file: TelegramMediaFile?, custom: Custom? = nil, enableAnimation: Bool = true) {
        self.interactivelySelectedFromPackId = interactivelySelectedFromPackId
        self.fileId = fileId
        self.file = file
        self.custom = custom
        self.enableAnimation = enableAnimation
        
        super.init()
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.interactivelySelectedFromPackId = try container.decodeIfPresent(ItemCollectionId.self, forKey: .interactivelySelectedFromPackId)
        self.fileId = try container.decode(Int64.self, forKey: .fileId)
        self.file = try container.decodeIfPresent(TelegramMediaFile.self, forKey: .file)
        self.custom = nil
        self.enableAnimation = try container.decodeIfPresent(Bool.self, forKey: .enableAnimation) ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.interactivelySelectedFromPackId, forKey: .interactivelySelectedFromPackId)
        try container.encode(self.fileId, forKey: .fileId)
        try container.encodeIfPresent(self.file, forKey: .file)
        try container.encode(self.enableAnimation, forKey: .enableAnimation)
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        if let other = object as? ChatTextInputTextCustomEmojiAttribute {
            return self === other
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

private let textUrlEdgeCharacters: CharacterSet = {
    var set: CharacterSet = .alphanumerics
    set.formUnion(.symbols)
    set.formUnion(.punctuationCharacters)
    return set
}()

private let textUrlCharacters: CharacterSet = {
    var set: CharacterSet = textUrlEdgeCharacters
    set.formUnion(.whitespacesAndNewlines)
    return set
}()

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
                if textUrlCharacters.contains(c) {
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
                if textUrlCharacters.contains(c) {
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
                if textUrlEdgeCharacters.contains(c) {
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
                if textUrlEdgeCharacters.contains(c) {
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
                        if textUrlCharacters.contains(c) {
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

private func quoteRangesEqual(_ lhs: [(NSRange, ChatTextInputTextQuoteAttribute)], _ rhs: [(NSRange, ChatTextInputTextQuoteAttribute)]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if lhs[i].0 != rhs[i].0 || !lhs[i].1.isEqual(rhs[i].1) {
            return false
        }
    }
    return true
}

private func refreshBlockQuotes(text: NSString, initialAttributedText: NSAttributedString, attributedText: NSMutableAttributedString, fullRange: NSRange) {
    var quoteRanges: [(NSRange, ChatTextInputTextQuoteAttribute)] = []
    initialAttributedText.enumerateAttributes(in: fullRange, using: { dict, range, _ in
        if let value = dict[ChatTextInputAttributes.block] as? ChatTextInputTextQuoteAttribute {
            quoteRanges.append((range, value))
        }
    })
    quoteRanges.sort(by: { $0.0.location < $1.0.location })
    let initialQuoteRanges = quoteRanges
    quoteRanges = quoteRanges.filter({ $0.0.length > 0 })
    
    for i in 0 ..< quoteRanges.count {
        var backIndex = quoteRanges[i].0.lowerBound
        innerBack: while backIndex >= 0 {
            let character = text.character(at: backIndex)
            if character == 0x0a {
                backIndex += 1
                break innerBack
            }
            backIndex -= 1
        }
        backIndex = max(backIndex, 0)
        
        if backIndex < quoteRanges[i].0.lowerBound {
            quoteRanges[i].0 = NSRange(location: backIndex, length: quoteRanges[i].0.upperBound - backIndex)
        }
        
        var forwardIndex = quoteRanges[i].0.upperBound
        innerForward: while forwardIndex < text.length {
            let character = text.character(at: forwardIndex)
            if character == 0x0a {
                forwardIndex -= 1
                break innerForward
            }
            forwardIndex += 1
        }
        forwardIndex = min(forwardIndex, text.length - 1)
        
        if forwardIndex > quoteRanges[i].0.upperBound - 1 {
            quoteRanges[i].0 = NSRange(location: quoteRanges[i].0.lowerBound, length: forwardIndex + 1 - quoteRanges[i].0.lowerBound)
        }
    }
    
    for i in (0 ..< quoteRanges.count).reversed() {
        inner: for mergeIndex in (i + 1 ..< quoteRanges.count).reversed() {
            if quoteRanges[mergeIndex].1 === quoteRanges[i].1 || quoteRanges[mergeIndex].0.intersection(quoteRanges[i].0) != nil {
                quoteRanges[i].0 = NSRange(location: quoteRanges[i].0.location, length: quoteRanges[mergeIndex].0.location + quoteRanges[mergeIndex].0.length - quoteRanges[i].0.location)
                quoteRanges.removeSubrange((i + 1) ..< (mergeIndex + 1))
                break inner
            }
        }
    }
    
    if !quoteRangesEqual(quoteRanges, initialQuoteRanges) {
        attributedText.removeAttribute(ChatTextInputAttributes.block, range: fullRange)
        for (range, attribute) in quoteRanges {
            attributedText.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: attribute.kind, isCollapsed: attribute.isCollapsed), range: range)
        }
    }
}

public func refreshChatTextInputAttributes(context: AnyObject, textView: UITextView, theme: PresentationTheme, baseFontSize: CGFloat, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?, makeCollapsedQuoteAttachment: ((NSAttributedString, ChatInputTextCollapsedQuoteAttributes) -> ChatInputTextCollapsedQuoteAttachment)?) {
    refreshChatTextInputAttributes(context: context, textView: textView, primaryTextColor: theme.chat.inputPanel.primaryTextColor, accentTextColor: theme.chat.inputPanel.panelControlAccentColor, baseFontSize: baseFontSize, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: makeCollapsedQuoteAttachment)
}

public func refreshChatTextInputAttributes(context: AnyObject, textView: UITextView, primaryTextColor: UIColor, accentTextColor: UIColor, baseFontSize: CGFloat, spoilersRevealed: Bool, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?, makeCollapsedQuoteAttachment: ((NSAttributedString, ChatInputTextCollapsedQuoteAttributes) -> ChatInputTextCollapsedQuoteAttachment)?) {
    guard let initialAttributedText = textView.attributedText, initialAttributedText.length != 0 else {
        return
    }
    
    textView.textStorage.beginEditing()
    
    var writingDirection: NSWritingDirection?
    if let style = initialAttributedText.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
        writingDirection = style.baseWritingDirection
    }
    
    var text: NSString = initialAttributedText.string as NSString
    var fullRange = NSRange(location: 0, length: initialAttributedText.length)
    var attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(initialAttributedText))
    refreshTextMentions(text: text, initialAttributedText: initialAttributedText, attributedText: attributedText, fullRange: fullRange)
    
    var resultAttributedText = textAttributedStringForStateText(context: context, stateText: attributedText, fontSize: baseFontSize, textColor: primaryTextColor, accentTextColor: accentTextColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: makeCollapsedQuoteAttachment)
    
    text = resultAttributedText.string as NSString
    fullRange = NSRange(location: 0, length: text.length)
    attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(resultAttributedText))
    refreshTextUrls(text: text, initialAttributedText: resultAttributedText, attributedText: attributedText, fullRange: fullRange)
    
    resultAttributedText = textAttributedStringForStateText(context: context, stateText: attributedText, fontSize: baseFontSize, textColor: primaryTextColor, accentTextColor: accentTextColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: makeCollapsedQuoteAttachment)
    
    text = resultAttributedText.string as NSString
    fullRange = NSRange(location: 0, length: text.length)
    attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(resultAttributedText))
    refreshBlockQuotes(text: text, initialAttributedText: resultAttributedText, attributedText: attributedText, fullRange: fullRange)
    
    resultAttributedText = textAttributedStringForStateText(context: context, stateText: attributedText, fontSize: baseFontSize, textColor: primaryTextColor, accentTextColor: accentTextColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: makeCollapsedQuoteAttachment)
    
    if !resultAttributedText.isEqual(to: initialAttributedText) {
        fullRange = NSRange(location: 0, length: textView.textStorage.length)
        
        textView.textStorage.removeAttribute(NSAttributedString.Key.font, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.foregroundColor, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.backgroundColor, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.underlineStyle, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.strikethroughStyle, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.textMention, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.textUrl, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.spoiler, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.customEmoji, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.block, range: fullRange)
        
        textView.textStorage.addAttribute(NSAttributedString.Key.font, value: Font.regular(baseFontSize), range: fullRange)
        textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: primaryTextColor, range: fullRange)
        
        let replaceRanges: [(NSRange, EmojiTextAttachment)] = []
        
        //var emojiIndex = 0
        attributedText.enumerateAttributes(in: fullRange, options: [], using: { attributes, range, _ in
            var fontAttributes: ChatTextFontAttributes = []
            
            for (key, value) in attributes {
                if key == ChatTextInputAttributes.textMention || key == ChatTextInputAttributes.textUrl {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: accentTextColor, range: range)
                    
                    if accentTextColor.isEqual(primaryTextColor) {
                        textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                    }
                } else if key == ChatTextInputAttributes.bold {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.bold)
                } else if key == ChatTextInputAttributes.italic {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.italic)
                } else if key == ChatTextInputAttributes.monospace {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.monospace)
                } else if key == ChatTextInputAttributes.strikethrough {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    textView.textStorage.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.underline {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.spoiler {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    if spoilersRevealed {
                        textView.textStorage.addAttribute(NSAttributedString.Key.backgroundColor, value: primaryTextColor.withAlphaComponent(0.15), range: range)
                    } else {
                        textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: range)
                    }
                } else if key == ChatTextInputAttributes.customEmoji, let value = value as? ChatTextInputTextCustomEmojiAttribute {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: range)
                } else if key == ChatTextInputAttributes.block, let value = value as? ChatTextInputTextQuoteAttribute {
                    if !value.isCollapsed {
                        switch value.kind {
                        case .quote:
                            fontAttributes.insert(.blockQuote)
                        case .code:
                            fontAttributes.insert(.monospace)
                        }
                        textView.textStorage.addAttribute(key, value: value, range: range)
                    }
                }
            }
                
            if !fontAttributes.isEmpty {
                var font: UIFont?
                var baseFontSize = baseFontSize
                if fontAttributes.contains(.blockQuote) {
                    fontAttributes.remove(.blockQuote)
                    baseFontSize = round(baseFontSize * 0.8235294117647058)
                }
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
                } else {
                    font = Font.regular(baseFontSize)
                }
                
                if let font = font {
                    textView.textStorage.addAttribute(NSAttributedString.Key.font, value: font, range: range)
                }
            }
        })
        
        for (range, attachment) in replaceRanges.sorted(by: { $0.0.location > $1.0.location }) {
            textView.textStorage.replaceCharacters(in: range, with: NSAttributedString(attachment: attachment))
        }
    }
    
    textView.textStorage.endEditing()
}

public func refreshGenericTextInputAttributes(context: AnyObject, textView: UITextView, theme: PresentationTheme, baseFontSize: CGFloat, availableEmojis: Set<String>, emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?, makeCollapsedQuoteAttachment: ((NSAttributedString, ChatInputTextCollapsedQuoteAttributes) -> ChatInputTextCollapsedQuoteAttachment)?, spoilersRevealed: Bool = false) {
    guard let initialAttributedText = textView.attributedText, initialAttributedText.length != 0 else {
        return
    }
    
    var writingDirection: NSWritingDirection?
    if let style = initialAttributedText.attribute(NSAttributedString.Key.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
        writingDirection = style.baseWritingDirection
    }
    
    var text: NSString = initialAttributedText.string as NSString
    var fullRange = NSRange(location: 0, length: initialAttributedText.length)
    var attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(initialAttributedText))
    var resultAttributedText = textAttributedStringForStateText(context: context, stateText: attributedText, fontSize: baseFontSize, textColor: theme.chat.inputPanel.primaryTextColor, accentTextColor: theme.chat.inputPanel.panelControlAccentColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: makeCollapsedQuoteAttachment)
    
    text = resultAttributedText.string as NSString
    fullRange = NSRange(location: 0, length: initialAttributedText.length)
    attributedText = NSMutableAttributedString(attributedString: stateAttributedStringForText(resultAttributedText))
    refreshTextUrls(text: text, initialAttributedText: resultAttributedText, attributedText: attributedText, fullRange: fullRange)
    
    resultAttributedText = textAttributedStringForStateText(context: context, stateText: attributedText, fontSize: baseFontSize, textColor: theme.chat.inputPanel.primaryTextColor, accentTextColor: theme.chat.inputPanel.panelControlAccentColor, writingDirection: writingDirection, spoilersRevealed: spoilersRevealed, availableEmojis: availableEmojis, emojiViewProvider: emojiViewProvider, makeCollapsedQuoteAttachment: makeCollapsedQuoteAttachment)
    
    if !resultAttributedText.isEqual(to: initialAttributedText) {
        textView.textStorage.removeAttribute(NSAttributedString.Key.font, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.foregroundColor, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.backgroundColor, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.underlineStyle, range: fullRange)
        textView.textStorage.removeAttribute(NSAttributedString.Key.strikethroughStyle, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.textMention, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.textUrl, range: fullRange)
        textView.textStorage.removeAttribute(ChatTextInputAttributes.spoiler, range: fullRange)
        
        textView.textStorage.addAttribute(NSAttributedString.Key.font, value: Font.regular(baseFontSize), range: fullRange)
        textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.chat.inputPanel.primaryTextColor, range: fullRange)
        
        attributedText.enumerateAttributes(in: fullRange, options: [], using: { attributes, range, _ in
            var fontAttributes: ChatTextFontAttributes = []
            
            for (key, value) in attributes {
                if key == ChatTextInputAttributes.textMention || key == ChatTextInputAttributes.textUrl {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.chat.inputPanel.panelControlAccentColor, range: range)
                    
                    if theme.chat.inputPanel.panelControlAccentColor.isEqual(theme.chat.inputPanel.primaryTextColor) {
                        textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                    }
                } else if key == ChatTextInputAttributes.bold {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.bold)
                } else if key == ChatTextInputAttributes.italic {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.italic)
                } else if key == ChatTextInputAttributes.monospace {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    fontAttributes.insert(.monospace)
                } else if key == ChatTextInputAttributes.strikethrough {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    textView.textStorage.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.underline {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    textView.textStorage.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                } else if key == ChatTextInputAttributes.spoiler {
                    textView.textStorage.addAttribute(key, value: value, range: range)
                    if spoilersRevealed {
                        textView.textStorage.addAttribute(NSAttributedString.Key.backgroundColor, value: theme.chat.inputPanel.primaryTextColor.withAlphaComponent(0.15), range: range)
                    } else {
                        textView.textStorage.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.clear, range: range)
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
                    textView.textStorage.addAttribute(NSAttributedString.Key.font, value: font, range: range)
                }
            }
        })
    }
}

public func refreshChatTextInputTypingAttributes(_ textView: UITextView, textColor: UIColor, baseFontSize: CGFloat) {
    var filteredAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: Font.regular(baseFontSize),
        NSAttributedString.Key.foregroundColor: textColor
    ]
    let style = NSMutableParagraphStyle()
    style.baseWritingDirection = .natural
    filteredAttributes[NSAttributedString.Key.paragraphStyle] = style
    if let attributedText = textView.attributedText, attributedText.length != 0 {
        let attributes = attributedText.attributes(at: max(0, min(textView.selectedRange.location - 1, attributedText.length - 1)), effectiveRange: nil)
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
    textView.typingAttributes = filteredAttributes
}

public func refreshChatTextInputTypingAttributes(_ textView: UITextView, theme: PresentationTheme, baseFontSize: CGFloat) {
    var filteredAttributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key.font: Font.regular(baseFontSize),
        NSAttributedString.Key.foregroundColor: theme.chat.inputPanel.primaryTextColor
    ]
    let style = NSMutableParagraphStyle()
    style.baseWritingDirection = .natural
    filteredAttributes[NSAttributedString.Key.paragraphStyle] = style
    if let attributedText = textView.attributedText, attributedText.length != 0 {
        let attributes = attributedText.attributes(at: max(0, min(textView.selectedRange.location - 1, attributedText.length - 1)), effectiveRange: nil)
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
    textView.typingAttributes = filteredAttributes
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
                    
                    var substring = (string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines) + text + string.substring(with: match.range(at: 5))) as NSString
                    
                    var language: String?
                    let newlineRange = substring.range(of: "\n")
                    if newlineRange.location != NSNotFound {
                        if newlineRange.location != 0 {
                            language = substring.substring(with: NSRange(location: 0, length: newlineRange.location))
                        }
                        substring = substring.substring(with: NSRange(location: newlineRange.upperBound, length: substring.length - newlineRange.upperBound)) as NSString
                    }
                    if substring.hasSuffix("\n") {
                        substring = substring.substring(with: NSRange(location: 0, length: substring.length - 1)) as NSString
                    }
                    
                    result.append(NSAttributedString(string: substring as String, attributes: [ChatTextInputAttributes.block: ChatTextInputTextQuoteAttribute(kind: .code(language: language), isCollapsed: false)]))
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
                    
                    var entity = string.substring(with: match.range(at: 7))
                    var substring = string.substring(with: match.range(at: 6)) + text + string.substring(with: match.range(at: 9))
                    
                    if entity == "`" && substring.hasPrefix("``") && substring.hasSuffix("``") {
                        entity = "```"
                        substring = String(substring[substring.index(substring.startIndex, offsetBy: 2) ..< substring.index(substring.endIndex, offsetBy: -2)])
                    }
                    
                    let textInputAttribute: NSAttributedString.Key?
                    switch entity {
                        case "`":
                            textInputAttribute = ChatTextInputAttributes.monospace
                        case "```":
                            textInputAttribute = ChatTextInputAttributes.block
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

private final class EmojiTextAttachment: NSTextAttachment {
    let text: String
    let emoji: ChatTextInputTextCustomEmojiAttribute
    let viewProvider: (ChatTextInputTextCustomEmojiAttribute) -> UIView
    
    init(index: Int, text: String, emoji: ChatTextInputTextCustomEmojiAttribute, viewProvider: @escaping (ChatTextInputTextCustomEmojiAttribute) -> UIView) {
        self.text = text
        self.emoji = emoji
        self.viewProvider = viewProvider
        
        super.init(data: "\(emoji):\(index)".data(using: .utf8)!, ofType: "public.data")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 15, *)
private final class CustomTextAttachmentViewProvider: NSTextAttachmentViewProvider {
    static let ensureRegistered: Bool = {
        NSTextAttachment.registerViewProviderClass(CustomTextAttachmentViewProvider.self, forFileType: "public.data")
        
        return true
    }()
    
    override func loadView() {
        super.loadView()
        
        if let attachment = self.textAttachment as? EmojiTextAttachment {
            self.view = attachment.viewProvider(attachment.emoji)
        } else {
            self.view = UIView()
            self.view!.backgroundColor = .clear
        }
    }
}
