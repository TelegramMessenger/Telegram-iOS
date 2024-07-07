import Foundation
import UIKit
import Postbox
import TelegramCore
import Display
import libprisma
import SwiftSignalKit

public func chatInputStateStringWithAppliedEntities(_ text: String, entities: [MessageTextEntity]) -> NSAttributedString {
    var nsString: NSString?
    let string = NSMutableAttributedString(string: text)
    var skipEntity = false
    let stringLength = string.length
    for i in 0 ..< entities.count {
        if skipEntity {
            skipEntity = false
            continue
        }
        let entity = entities[i]
        var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
        if nsString == nil {
            nsString = text as NSString
        }
        if range.location >= stringLength {
            continue
        }
        if range.location + range.length > stringLength {
            range.length = stringLength - range.location
        }
        switch entity.type {
        case .Url, .Email, .PhoneNumber, .Mention, .Hashtag, .BotCommand:
            break
        case .Bold:
            string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: range)
        case .Italic:
            string.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: range)
        case let .TextMention(peerId):
            string.addAttribute(ChatTextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: peerId), range: range)
        case let .TextUrl(url):
            string.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: range)
        case .Code:
            string.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: range)
        case .Strikethrough:
            string.addAttribute(ChatTextInputAttributes.strikethrough, value: true as NSNumber, range: range)
        case .Underline:
            string.addAttribute(ChatTextInputAttributes.underline, value: true as NSNumber, range: range)
        case .Spoiler:
            string.addAttribute(ChatTextInputAttributes.spoiler, value: true as NSNumber, range: range)
        case let .CustomEmoji(_, fileId):
            string.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: nil), range: range)
        case let .Pre(language):
            string.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .code(language: language), isCollapsed: false), range: range)
        case let .BlockQuote(isCollapsed):
            string.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: isCollapsed), range: range)
            default:
                break
        }
    }
    
    while true {
        var found = false
        string.enumerateAttribute(ChatTextInputAttributes.block, in: NSRange(location: 0, length: string.length), using: { value, range, stop in
            if let value = value as? ChatTextInputTextQuoteAttribute, value.isCollapsed {
                found = true
                let blockString = string.attributedSubstring(from: range)
                string.replaceCharacters(in: range, with: "")
                string.insert(NSAttributedString(string: " ", attributes: [
                    ChatTextInputAttributes.collapsedBlock: blockString
                ]), at: range.lowerBound)
                stop.pointee = true
            }
        })
        if !found {
            break
        }
    }
    
    return string
}

private let syntaxHighlighter = Syntaxer()

public func stringWithAppliedEntities(_ text: String, entities: [MessageTextEntity], baseColor: UIColor, linkColor: UIColor, baseQuoteTintColor: UIColor? = nil, baseQuoteSecondaryTintColor: UIColor? = nil, baseQuoteTertiaryTintColor: UIColor? = nil, codeBlockTitleColor: UIColor? = nil, codeBlockAccentColor: UIColor? = nil, codeBlockBackgroundColor: UIColor? = nil, baseFont: UIFont, linkFont: UIFont, boldFont: UIFont, italicFont: UIFont, boldItalicFont: UIFont, fixedFont: UIFont, blockQuoteFont: UIFont, underlineLinks: Bool = true, external: Bool = false, message: Message?, entityFiles: [MediaId: TelegramMediaFile] = [:], adjustQuoteFontSize: Bool = false, cachedMessageSyntaxHighlight: CachedMessageSyntaxHighlight? = nil) -> NSAttributedString {
    let baseQuoteTintColor = baseQuoteTintColor ?? baseColor
    
    var nsString: NSString?
    let string = NSMutableAttributedString(string: text, attributes: [NSAttributedString.Key.font: baseFont, NSAttributedString.Key.foregroundColor: baseColor])
    var skipEntity = false
    var underlineAllLinks = false
    if linkColor.argb == baseColor.argb {
        underlineAllLinks = true
    }
    
    var fontAttributeMask: [ChatTextFontAttributes] = Array(repeating: [], count: string.length)
    let addFontAttributes: (NSRange, ChatTextFontAttributes) -> Void = { range, attributes in
        for i in range.lowerBound ..< range.upperBound {
            fontAttributeMask[i].formUnion(attributes)
        }
    }
    
    for i in 0 ..< entities.count {
        if skipEntity {
            skipEntity = false
            continue
        }
        let stringLength = string.length
        let entity = entities[i]
        var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
        if nsString == nil {
            nsString = text as NSString
        }
        if range.location > stringLength {
            continue
        } else if range.location + range.length > stringLength {
            range.length = stringLength - range.location
        }
        switch entity.type {
            case .Url:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: nsString!.substring(with: range), range: range)
            case .Email:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: "mailto:\(nsString!.substring(with: range))", range: range)
            case .PhoneNumber:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: "tel:\(nsString!.substring(with: range))", range: range)
            case let .TextUrl(url):
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                if external {
                    string.addAttribute(NSAttributedString.Key.link, value: url, range: range)
                } else {
                    string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: url, range: range)
                }
            case .Bold:
                addFontAttributes(range, .bold)
            case .Italic:
                addFontAttributes(range, .italic)
            case .Mention:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                if linkFont !== baseFont {
                    string.addAttribute(NSAttributedString.Key.font, value: linkFont, range: range)
                }
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention), value: nsString!.substring(with: range), range: range)
            case .Strikethrough:
                string.addAttribute(NSAttributedString.Key.strikethroughStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
            case .Underline:
                string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
            case let .TextMention(peerId):
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                if linkFont !== baseFont {
                    string.addAttribute(NSAttributedString.Key.font, value: linkFont, range: range)
                }
                let mention = nsString!.substring(with: range)
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: peerId, mention: mention), range: range)
            case .Hashtag:
                if nsString == nil {
                    nsString = text as NSString
                }
                let hashtag = nsString!.substring(with: range)
                if i + 1 != entities.count {
                    if case .Mention = entities[i + 1].type {
                        let nextRange = NSRange(location: entities[i + 1].range.lowerBound, length: entities[i + 1].range.upperBound - entities[i + 1].range.lowerBound)
                        if nextRange.location == range.location + range.length + 1 && nsString!.character(at: range.location + range.length) == 43 {
                            skipEntity = true
                            if nextRange.length > 0 {
                                let peerName: String = nsString!.substring(with: NSRange(location: nextRange.location + 1, length: nextRange.length - 1))
                                
                                let combinedRange = NSRange(location: range.location, length: nextRange.location + nextRange.length - range.location)
                                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: combinedRange)
                                if linkColor.isEqual(baseColor) {
                                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: combinedRange)
                                }
                                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag), value: TelegramHashtag(peerName: peerName, hashtag: hashtag), range: combinedRange)
                            }
                        }
                    }
                }
                if !skipEntity {
                    string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                    if underlineLinks && underlineAllLinks {
                        string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                    }
                    string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag), value: TelegramHashtag(peerName: nil, hashtag: hashtag), range: range)
                }
            case .BotCommand:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand), value: nsString!.substring(with: range), range: range)
            case .Code:
                addFontAttributes(range, .monospace)
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Code), value: nsString!.substring(with: range), range: range)
            case let .Pre(language):
                addFontAttributes(range, .monospace)
                addFontAttributes(range, .blockQuote)
                if nsString == nil {
                    nsString = text as NSString
                }
                if let codeBlockTitleColor, let codeBlockAccentColor, let codeBlockBackgroundColor {
                    var title: NSAttributedString?
                    if let language, !language.isEmpty {
                        title = NSAttributedString(string: language.capitalized, font: boldFont.withSize(round(boldFont.pointSize * 0.8235294117647058)), textColor: codeBlockTitleColor)
                    }
                    string.addAttribute(NSAttributedString.Key(rawValue: "Attribute__Blockquote"), value: TextNodeBlockQuoteData(kind: .code(language: language), title: title, color: codeBlockAccentColor, secondaryColor: nil, tertiaryColor: nil, backgroundColor: codeBlockBackgroundColor, isCollapsible: false), range: range)
                }
            case let .BlockQuote(isCollapsed):
                addFontAttributes(range, .blockQuote)
                
                string.addAttribute(NSAttributedString.Key(rawValue: "Attribute__Blockquote"), value: TextNodeBlockQuoteData(kind: .quote, title: nil, color: baseQuoteTintColor, secondaryColor: baseQuoteSecondaryTintColor, tertiaryColor: baseQuoteTertiaryTintColor, backgroundColor: baseQuoteTintColor.withMultipliedAlpha(0.1), isCollapsible: isCollapsed), range: range)
            case .BankCard:
                string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                }
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.BankCard), value: nsString!.substring(with: range), range: range)
            case .Spoiler:
                if external {
                    string.addAttribute(NSAttributedString.Key.backgroundColor, value: UIColor.gray, range: range)
                } else {
                    string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), value: true as NSNumber, range: range)
                }
            case let .Custom(type):
                if type == ApplicationSpecificEntityType.Timecode {
                    string.addAttribute(NSAttributedString.Key.foregroundColor, value: linkColor, range: range)
                    if underlineLinks && underlineAllLinks {
                        string.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: range)
                    }
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    let text = nsString!.substring(with: range)
                    if let time = parseTimecodeString(text) {
                        string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Timecode), value: TelegramTimecode(time: time, text: text), range: range)
                    }
                } else if type == ApplicationSpecificEntityType.Button {
                    string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Button), value: true as NSNumber, range: range)
                    addFontAttributes(range, .smaller)
                }
            case let .CustomEmoji(_, fileId):
                let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                var emojiFile: TelegramMediaFile?
                if let file = message?.associatedMedia[mediaId] as? TelegramMediaFile {
                    emojiFile = file
                } else {
                    emojiFile = entityFiles[mediaId]
                }
                string.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: emojiFile), range: range)
            default:
                break
        }
        
        func setFont(range: NSRange, fontAttributes: ChatTextFontAttributes) {
            var font: UIFont
            
            var isQuote = false
            var fontAttributes = fontAttributes
            if fontAttributes.contains(.blockQuote) {
                fontAttributes.remove(.blockQuote)
                isQuote = true
            }
            if fontAttributes == [.bold, .italic] {
                font = boldItalicFont
            } else if fontAttributes == [.bold] {
                font = boldFont
            } else if fontAttributes == [.italic] {
                font = italicFont
            } else if fontAttributes == [.monospace] {
                font = fixedFont
            } else if fontAttributes == [.smaller] {
                font = baseFont.withSize(floor(baseFont.pointSize * 0.9))
            } else {
                font = baseFont
            }
            
            if adjustQuoteFontSize, isQuote {
                font = font.withSize(round(font.pointSize * 0.8235294117647058))
            }
            
            string.addAttribute(.font, value: font, range: range)
        }
        
        var currentAttributeSpan: (startIndex: Int, attributes: ChatTextFontAttributes)?
        for i in 0 ..< fontAttributeMask.count {
            if fontAttributeMask[i] != currentAttributeSpan?.attributes {
                if let currentAttributeSpan {
                    setFont(range: NSRange(location: currentAttributeSpan.startIndex, length: i - currentAttributeSpan.startIndex), fontAttributes: currentAttributeSpan.attributes)
                }
                currentAttributeSpan = (i, fontAttributeMask[i])
            }
        }
        if let currentAttributeSpan {
            setFont(range: NSRange(location: currentAttributeSpan.startIndex, length: fontAttributeMask.count - currentAttributeSpan.startIndex), fontAttributes: currentAttributeSpan.attributes)
        }
    }
    
    string.enumerateAttribute(NSAttributedString.Key("Attribute__Blockquote"), in: NSRange(location: 0, length: string.length), using: { value, range, _ in
        guard let value = value as? TextNodeBlockQuoteData, case let .code(language) = value.kind, let language, !language.isEmpty else {
            return
        }
        
        let codeText = (string.string as NSString).substring(with: range)
        if let cachedMessageSyntaxHighlight, let entry = cachedMessageSyntaxHighlight.values[CachedMessageSyntaxHighlight.Spec(language: language, text: codeText)] {
            for entity in entry.entities {
                string.addAttribute(.foregroundColor, value: UIColor(rgb: UInt32(bitPattern: entity.color)), range: NSRange(location: range.location + entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
            }
        }
    })
    
    return string
}

public final class MessageSyntaxHighlight: Codable, Equatable {
    public struct Entity: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case color = "c"
            case rangeLow = "r"
            case rangeLength = "rl"
        }
        
        public var color: Int32
        public var range: Range<Int>
        
        public init(color: Int32, range: Range<Int>) {
            self.color = color
            self.range = range
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.color = try container.decode(Int32.self, forKey: .color)
            let rangeLow = Int(try container.decode(Int32.self, forKey: .rangeLow))
            let rangeLength = Int(try container.decode(Int32.self, forKey: .rangeLength))
            self.range = rangeLow ..< (rangeLow + rangeLength)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.color, forKey: .color)
            try container.encode(Int32(self.range.lowerBound), forKey: .rangeLow)
            try container.encode(Int32(self.range.upperBound - self.range.lowerBound), forKey: .rangeLength)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case entities = "e"
    }
    
    public let entities: [Entity]
    
    public init(entities: [Entity]) {
        self.entities = entities
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.entities = try container.decode([Entity].self, forKey: .entities)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.entities, forKey: .entities)
    }
    
    public static func ==(lhs: MessageSyntaxHighlight, rhs: MessageSyntaxHighlight) -> Bool {
        if lhs.entities != rhs.entities {
            return false
        }
        return true
    }
}

public final class CachedMessageSyntaxHighlight: Codable, Equatable {
    public struct Spec: Hashable, Codable {
        private enum CodingKeys: String, CodingKey {
            case language = "l"
            case text = "t"
        }
        
        public var language: String
        public var text: String
        
        public init(language: String, text: String) {
            self.language = language
            self.text = text
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case values = "v"
    }
    
    private struct CodingValueEntry: Codable {
        private enum CodingKeys: String, CodingKey {
            case key = "k"
            case value = "v"
        }
        
        let key: Spec
        let value: MessageSyntaxHighlight
        
        init(key: Spec, value: MessageSyntaxHighlight) {
            self.key = key
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.key = try container.decode(Spec.self, forKey: .key)
            self.value = try container.decode(MessageSyntaxHighlight.self, forKey: .value)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.key, forKey: .key)
            try container.encode(self.value, forKey: .value)
        }
    }
    
    public let values: [Spec: MessageSyntaxHighlight]
    
    public init(values: [Spec: MessageSyntaxHighlight]) {
        self.values = values
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let valueEntries = try container.decode([CodingValueEntry].self, forKey: .values)
        var values: [Spec: MessageSyntaxHighlight] = [:]
        for entry in valueEntries {
            values[entry.key] = entry.value
        }
        self.values = values
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let valueEntries = self.values.map { CodingValueEntry(key: $0.key, value: $0.value) }
        try container.encode(valueEntries, forKey: .values)
    }
    
    public static func ==(lhs: CachedMessageSyntaxHighlight, rhs: CachedMessageSyntaxHighlight) -> Bool {
        if lhs.values != rhs.values {
            return false
        }
        return true
    }
}

private let messageSyntaxHighlightQueue = Queue(name: "MessageSyntaxHighlight")

public func extractMessageSyntaxHighlightSpecs(text: String, entities: [MessageTextEntity]) -> [CachedMessageSyntaxHighlight.Spec] {
    if entities.isEmpty {
        return []
    }
    var result: [CachedMessageSyntaxHighlight.Spec] = []
    let nsString = text as NSString
    for entity in entities {
        if case let .Pre(language) = entity.type, let language, !language.isEmpty {
            var range = entity.range
            if range.lowerBound < 0 {
                range = 0 ..< range.upperBound
            }
            if range.upperBound > nsString.length {
                range = range.lowerBound ..< nsString.length
            }
            if range.upperBound != range.lowerBound {
                result.append(CachedMessageSyntaxHighlight.Spec(language: language, text: nsString.substring(with: NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound))))
            }
        }
    }
    
    return result
}

private let internalFixedCodeFont = Font.regular(17.0)

public func asyncUpdateMessageSyntaxHighlight(engine: TelegramEngine, messageId: EngineMessage.Id, current: CachedMessageSyntaxHighlight?, specs: [CachedMessageSyntaxHighlight.Spec]) -> Signal<Never, NoError> {
    if let current, !specs.contains(where: { current.values[$0] == nil }) {
        return .complete()
    }
    
    return Signal { subscriber in
        var updated: [CachedMessageSyntaxHighlight.Spec: MessageSyntaxHighlight] = [:]
        
        let theme = SyntaxterTheme(dark: false, textColor: .black, textFont: internalFixedCodeFont, italicFont: internalFixedCodeFont, mediumFont: internalFixedCodeFont)
        
        for spec in specs {
            if let value = current?.values[spec] {
                updated[spec] = value
            } else {
                var entities: [MessageSyntaxHighlight.Entity] = []
                
                if let syntaxHighlighter {
                    if let highlightedString = syntaxHighlighter.syntax(spec.text, language: spec.language, theme: theme) {
                        highlightedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: highlightedString.length), using: { value, subRange, _ in
                            if let value = value as? UIColor, value != .black {
                                entities.append(MessageSyntaxHighlight.Entity(color: Int32(bitPattern: value.rgb), range: subRange.lowerBound ..< subRange.upperBound))
                            }
                        })
                    }
                }
                
                updated[spec] = MessageSyntaxHighlight(entities: entities)
            }
        }
        
        if let entry = CodableEntry(CachedMessageSyntaxHighlight(values: updated)) {
            return engine.messages.storeLocallyDerivedData(messageId: messageId, data: ["code": entry]).start(completed: {
                subscriber.putCompletion()
            })
        } else {
            return EmptyDisposable
        }
    }
    |> runOn(messageSyntaxHighlightQueue)
}

public func asyncStanaloneSyntaxHighlight(current: CachedMessageSyntaxHighlight?, specs: [CachedMessageSyntaxHighlight.Spec]) -> Signal<CachedMessageSyntaxHighlight, NoError> {
    if let current, !specs.contains(where: { current.values[$0] == nil }) {
        return .single(current)
    }
    
    return Signal { subscriber in
        var updated: [CachedMessageSyntaxHighlight.Spec: MessageSyntaxHighlight] = [:]
        
        let theme = SyntaxterTheme(dark: false, textColor: .black, textFont: internalFixedCodeFont, italicFont: internalFixedCodeFont, mediumFont: internalFixedCodeFont)
        
        for spec in specs {
            if let value = current?.values[spec] {
                updated[spec] = value
            } else {
                var entities: [MessageSyntaxHighlight.Entity] = []
                
                if let syntaxHighlighter {
                    if let highlightedString = syntaxHighlighter.syntax(spec.text, language: spec.language, theme: theme) {
                        highlightedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: highlightedString.length), using: { value, subRange, _ in
                            if let value = value as? UIColor, value != .black {
                                entities.append(MessageSyntaxHighlight.Entity(color: Int32(bitPattern: value.rgb), range: subRange.lowerBound ..< subRange.upperBound))
                            }
                        })
                    }
                }
                
                updated[spec] = MessageSyntaxHighlight(entities: entities)
            }
        }
        
        subscriber.putNext(CachedMessageSyntaxHighlight(values: updated))
        subscriber.putCompletion()
        
        return EmptyDisposable
    }
    |> runOn(messageSyntaxHighlightQueue)
}
