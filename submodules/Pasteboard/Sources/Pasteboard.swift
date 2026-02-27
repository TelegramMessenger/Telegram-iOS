import Foundation
import UIKit
import Display
import TelegramCore
import MobileCoreServices
import TextFormat

private func rtfStringWithAppliedEntities(_ text: String, entities: [MessageTextEntity]) -> String {
    let sourceString = stringWithAppliedEntities(text, entities: entities, baseColor: .black, linkColor: .black, baseFont: Font.regular(14.0), linkFont: Font.regular(14.0), boldFont: Font.semibold(14.0), italicFont: Font.italic(14.0), boldItalicFont: Font.semiboldItalic(14.0), fixedFont: Font.monospace(14.0), blockQuoteFont: Font.regular(14.0), underlineLinks: false, external: true, message: nil)
    let test = NSMutableAttributedString(attributedString: sourceString)
    
    var index = 0
    test.enumerateAttribute(ChatTextInputAttributes.customEmoji, in: NSRange(location: 0, length: sourceString.length), using: { value, range, _ in
        if let value = value as? ChatTextInputTextCustomEmojiAttribute {
            test.addAttribute(NSAttributedString.Key.link, value: URL(string: "tg://emoji?id=\(value.fileId)&t=\(index)")!, range: range)
            index += 1
        }
    })
    test.removeAttribute(ChatTextInputAttributes.customEmoji, range: NSRange(location: 0, length: test.length))

    if let data = try? test.data(from: NSRange(location: 0, length: test.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf]) {
        if var rtf = String(data: data, encoding: .windowsCP1252) {
            rtf = rtf.replacingOccurrences(of: "\\fs28", with: "")
            rtf = rtf.replacingOccurrences(of: "\n{\\colortbl;\\red255\\green255\\blue255;}", with: "")
            rtf = rtf.replacingOccurrences(of: "\n{\\*\\expandedcolortbl;;}", with: "")
            rtf = rtf.replacingOccurrences(of: "\n\\pard\\tx560\\tx1120\\tx1680\\tx2240\\tx2800\\tx3360\\tx3920\\tx4480\\tx5040\\tx5600\\tx6160\\tx6720\\pardirnatural\\partightenfactor0\n", with: "")
            return rtf
        } else {
            return text
        }
    } else {
        return text
    }
}

struct AppSpecificPasteboardString: Codable {
    var text: String
    var entities: [MessageTextEntity]
}

private func appSpecificStringWithAppliedEntities(_ text: String, entities: [MessageTextEntity]) -> Data {
    guard let data = try? JSONEncoder().encode(AppSpecificPasteboardString(text: text, entities: entities)) else {
        return Data()
    }
    return data
}

private func preprocessLists(attributedString: NSAttributedString) -> NSAttributedString {
    let result = NSMutableAttributedString()
    var listCounters: [NSTextList: Int] = [:]
    
    let string = attributedString.string
    var currentIndex = 0
    
    while currentIndex < string.count {
        let nsRange = NSRange(location: currentIndex, length: 1)
        let attributes = attributedString.attributes(at: currentIndex, effectiveRange: nil)
        
        if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle,
           !paragraphStyle.textLists.isEmpty {
            let listItemRange = findListItemRange(in: attributedString, startingAt: currentIndex)
            let listItemSubstring = attributedString.attributedSubstring(from: listItemRange)
            
            let listMarker = generateListMarker(for: paragraphStyle, counters: &listCounters)
            
            let newAttributedString = NSMutableAttributedString()
            
            let markerString = NSMutableAttributedString(string: listMarker)
            if let firstCharFont = attributes[.font] {
                markerString.addAttribute(.font, value: firstCharFont, range: NSRange(location: 0, length: listMarker.count))
            }
            
            let newParagraphStyle = NSMutableParagraphStyle()
            newParagraphStyle.alignment = paragraphStyle.alignment
            newParagraphStyle.lineSpacing = paragraphStyle.lineSpacing
            newParagraphStyle.paragraphSpacing = paragraphStyle.paragraphSpacing
            newParagraphStyle.paragraphSpacingBefore = paragraphStyle.paragraphSpacingBefore
            newParagraphStyle.headIndent = 0
            newParagraphStyle.tailIndent = paragraphStyle.tailIndent
            newParagraphStyle.firstLineHeadIndent = 0
            newParagraphStyle.lineBreakMode = paragraphStyle.lineBreakMode
            newParagraphStyle.minimumLineHeight = paragraphStyle.minimumLineHeight
            newParagraphStyle.maximumLineHeight = paragraphStyle.maximumLineHeight
            newParagraphStyle.baseWritingDirection = paragraphStyle.baseWritingDirection
            newParagraphStyle.lineHeightMultiple = paragraphStyle.lineHeightMultiple
            newParagraphStyle.hyphenationFactor = paragraphStyle.hyphenationFactor
            newParagraphStyle.tabStops = paragraphStyle.tabStops
            newParagraphStyle.defaultTabInterval = paragraphStyle.defaultTabInterval
            newParagraphStyle.allowsDefaultTighteningForTruncation = paragraphStyle.allowsDefaultTighteningForTruncation
            
            markerString.addAttribute(.paragraphStyle, value: newParagraphStyle, range: NSRange(location: 0, length: listMarker.count))
            newAttributedString.append(markerString)
            
            let cleanedListItem = NSMutableAttributedString()
            listItemSubstring.enumerateAttributes(in: NSRange(location: 0, length: listItemSubstring.length), options: []) { itemAttributes, itemRange, _ in
                let itemSubstring = listItemSubstring.attributedSubstring(from: itemRange)
                let cleanedItemString = NSMutableAttributedString(attributedString: itemSubstring)
                
                if let itemParagraphStyle = itemAttributes[.paragraphStyle] as? NSParagraphStyle,
                   !itemParagraphStyle.textLists.isEmpty {
                    cleanedItemString.addAttribute(.paragraphStyle, value: newParagraphStyle, range: NSRange(location: 0, length: cleanedItemString.length))
                }
                
                cleanedListItem.append(cleanedItemString)
            }
            newAttributedString.append(cleanedListItem)
            result.append(newAttributedString)
            currentIndex = listItemRange.location + listItemRange.length
        } else {
            let charSubstring = attributedString.attributedSubstring(from: nsRange)
            result.append(charSubstring)
            currentIndex += 1
        }
    }
    
    return result
}

private func findListItemRange(in attributedString: NSAttributedString, startingAt index: Int) -> NSRange {
    let string = attributedString.string
    let startIndex = string.index(string.startIndex, offsetBy: index)
    
    var endIndex = startIndex
    while endIndex < string.endIndex {
        let character = string[endIndex]
        if character == "\n" {
            endIndex = string.index(after: endIndex)
            break
        }
        endIndex = string.index(after: endIndex)
    }
    
    let length = string.distance(from: startIndex, to: endIndex)
    return NSRange(location: index, length: length)
}

private func generateListMarker(for paragraphStyle: NSParagraphStyle, counters: inout [NSTextList: Int]) -> String {
    guard let textList = paragraphStyle.textLists.first else { return "" }
    
    if counters[textList] == nil {
        counters[textList] = 0
    }
    counters[textList]! += 1
    
    let currentIndex = counters[textList]!
    let format = textList.markerFormat
    
    let marker = generateMarkerText(format: format.rawValue, index: currentIndex)
    
    return marker + " "
}

private func generateMarkerText(format: String, index: Int) -> String {
    switch format {
    case "{decimal}":
        return "\(index)."
    case "{lower-alpha}":
        return "\(indexToLowerAlpha(index))."
    case "{upper-alpha}":
        return "\(indexToUpperAlpha(index))."
    case "{lower-roman}":
        return "\(indexToRoman(index))."
    case "{upper-roman}":
        return "\(indexToRoman(index).uppercased())."
    case "{disc}":
        return "•"
    case "{circle}":
        return "◦"
    case "{square}":
        return "▪"
    case "{hyphen}":
        return "-"
    case "{\"":
        return "-"
    default:
        if format.contains("decimal") {
            return "\(index)."
        } else if format.contains("alpha") {
            return "\(indexToLowerAlpha(index))."
        } else if format.contains("roman") {
            return "\(indexToRoman(index))."
        } else {
            return "•"
        }
    }
}

private func indexToLowerAlpha(_ index: Int) -> String {
    let alphabet = "abcdefghijklmnopqrstuvwxyz"
    let alphabetArray = Array(alphabet)
    
    if index <= 26 {
        return String(alphabetArray[index - 1])
    } else {
        let letterIndex = (index - 1) % 26
        let repeatCount = (index - 1) / 26 + 1
        return String(repeating: String(alphabetArray[letterIndex]), count: repeatCount)
    }
}

private func indexToUpperAlpha(_ index: Int) -> String {
    return indexToLowerAlpha(index).uppercased()
}

private func indexToRoman(_ index: Int) -> String {
    let romanNumerals = [
        (1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
        (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
        (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")
    ]
    var result = ""
    var number = index
    for (value, numeral) in romanNumerals {
        while number >= value {
            result += numeral
            number -= value
        }
    }
    return result
}

private func chatInputStateString(attributedString: NSAttributedString) -> NSAttributedString? {
    //let preprocessedString = preprocessLists(attributedString: attributedString)
        
    let string = NSMutableAttributedString(string: attributedString.string)
    attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: [], using: { attributes, range, _ in
        if let value = attributes[.link], let url = (value as? URL)?.absoluteString {
            string.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: range)
        }
        if let value = attributes[.font], let font = value as? UIFont {
            let fontName = font.fontName.lowercased()
            if fontName.hasPrefix(".sfui") {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitMonoSpace) {
                    string.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: range)
                } else {
                    if traits.contains(.traitBold) {
                        string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: range)
                    }
                    if traits.contains(.traitItalic) {
                        string.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: range)
                    }
                }
            } else {
                if fontName.contains("bolditalic") {
                    string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: range)
                    string.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: range)
                } else if fontName.contains("bold") {
                    string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: range)
                } else if fontName.contains("italic") {
                    string.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: range)
                } else if fontName.contains("menlo") || fontName.contains("courier") || fontName.contains("sfmono") {
                    string.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: range)
                }
            }
        }
        if let value = attributes[.backgroundColor] as? UIColor, value.rgb == UIColor.gray.rgb  {
            string.addAttribute(ChatTextInputAttributes.spoiler, value: true as NSNumber, range: range)
        }
        if let _ = attributes[.strikethroughStyle] {
            string.addAttribute(ChatTextInputAttributes.strikethrough, value: true as NSNumber, range: range)
        }
        if let _ = attributes[.underlineStyle] {
            string.addAttribute(ChatTextInputAttributes.underline, value: true as NSNumber, range: range)
        }
        if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
            string.addAttribute(ChatTextInputAttributes.customEmoji, value: value, range: range)
        }
        if let value = attributes[ChatTextInputAttributes.block] as? ChatTextInputTextQuoteAttribute {
            string.addAttribute(ChatTextInputAttributes.block, value: value, range: range)
        }
    })
    return string
}

public func chatInputStateStringFromRTF(_ data: Data, type: NSAttributedString.DocumentType) -> NSAttributedString? {
    if let attributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: type], documentAttributes: nil) {
        let updatedString = NSMutableAttributedString(attributedString: attributedString)
        updatedString.enumerateAttribute(NSAttributedString.Key.link, in: NSRange(location: 0, length: attributedString.length), using: { value, range, _ in
            if let url = value as? URL, url.scheme == "tg", url.host == "emoji" {
                var emojiId: Int64?
                if let queryItems = URLComponents(string: url.absoluteString)?.queryItems {
                    for item in queryItems {
                        if item.name == "id" {
                            emojiId = item.value.flatMap(Int64.init)
                        }
                    }
                }
                if let emojiId = emojiId {
                    updatedString.removeAttribute(NSAttributedString.Key.link, range: range)
                    updatedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiId, file: nil), range: range)
                }
            }
        })
        return chatInputStateString(attributedString: updatedString)
    }
    return nil
}

public func chatInputStateStringFromAppSpecificString(data: Data) -> NSAttributedString? {
    guard let string = try? JSONDecoder().decode(AppSpecificPasteboardString.self, from: data) else {
        return nil
    }
    return chatInputStateStringWithAppliedEntities(string.text, entities: string.entities)
}

public func storeMessageTextInPasteboard(_ text: String, entities: [MessageTextEntity]?) {
    var items: [String: Any] = [:]
    items[kUTTypeUTF8PlainText as String] = text
    
    if let entities = entities {
        items[kUTTypeRTF as String] = rtfStringWithAppliedEntities(text, entities: entities)
        items["private.telegramtext"] = appSpecificStringWithAppliedEntities(text, entities: entities)
    }
    UIPasteboard.general.items = [items]
}

public func storeAttributedTextInPasteboard(_ text: NSAttributedString) {
    if let inputText = chatInputStateString(attributedString: text) {
        let entities = generateChatInputTextEntities(inputText)
        storeMessageTextInPasteboard(inputText.string, entities: entities)
    }
}

public func storeInputTextInPasteboard(_ text: NSAttributedString) {
    let entities = generateChatInputTextEntities(text)
    storeMessageTextInPasteboard(text.string, entities: entities)
}
