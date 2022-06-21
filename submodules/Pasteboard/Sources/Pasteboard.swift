import Foundation
import UIKit
import Display
import TelegramCore
import MobileCoreServices
import TextFormat

private func rtfStringWithAppliedEntities(_ text: String, entities: [MessageTextEntity]) -> String {
    let test = stringWithAppliedEntities(text, entities: entities, baseColor: .black, linkColor: .black, baseFont: Font.regular(14.0), linkFont: Font.regular(14.0), boldFont: Font.semibold(14.0), italicFont: Font.italic(14.0), boldItalicFont: Font.semiboldItalic(14.0), fixedFont: Font.monospace(14.0), blockQuoteFont: Font.regular(14.0), underlineLinks: false, external: true)

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

private func chatInputStateString(attributedString: NSAttributedString) -> NSAttributedString? {
    let string = NSMutableAttributedString(string: attributedString.string)
    attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: [], using: { attributes, range, _ in
        if let value = attributes[.link], let url = (value as? URL)?.absoluteString {
            string.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: range)
        }
        if let value = attributes[.font], let font = value as? UIFont {
            let fontName = font.fontName.lowercased()
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
        if let value = attributes[.backgroundColor] as? UIColor, value.rgb == UIColor.gray.rgb  {
            string.addAttribute(ChatTextInputAttributes.spoiler, value: true as NSNumber, range: range)
        }
        if let _ = attributes[.strikethroughStyle] {
            string.addAttribute(ChatTextInputAttributes.strikethrough, value: true as NSNumber, range: range)
        }
        if let _ = attributes[.underlineStyle] {
            string.addAttribute(ChatTextInputAttributes.underline, value: true as NSNumber, range: range)
        }
    })
    return string
}

public func chatInputStateStringFromRTF(_ data: Data, type: NSAttributedString.DocumentType) -> NSAttributedString? {
    if let attributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: type], documentAttributes: nil) {
        return chatInputStateString(attributedString: attributedString)
    }
    return nil
}

public func storeMessageTextInPasteboard(_ text: String, entities: [MessageTextEntity]?) {
    var items: [String: Any] = [:]
    items[kUTTypeUTF8PlainText as String] = text
    
    if let entities = entities {
        items[kUTTypeRTF as String] = rtfStringWithAppliedEntities(text, entities: entities)
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
