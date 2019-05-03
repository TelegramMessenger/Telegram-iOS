import Foundation
import UIKit
import Display
import TelegramCore
import MobileCoreServices

private func rtfStringWithAppliedEntities(_ text: String, entities: [MessageTextEntity]) -> String {
    var string: String = #"""
    {\rtf1\ansi\ansicpg1252{\fonttbl\f0\fnil\fcharset0 .SFUIText;\f1\fnil\fcharset0 .SFUIText-Semibold;\f2\fnil\fcharset0 .SFUIText-Italic;\f3\fnil\fcharset0 Menlo-Regular;}
    """#
    
    string.append("\\f0 ")
    
    let nsString = text as NSString
    
    var remainingRange = NSMakeRange(0, text.count)
    for i in 0 ..< entities.count {
        let entity = entities[i]
        var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
        if range.location + range.length > text.count {
            range.location = max(0, text.count - range.length)
            range.length = text.count - range.location
        }
        
        if range.location != remainingRange.location {
            string.append(nsString.substring(with: NSMakeRange(remainingRange.location, range.location - remainingRange.location)))
            remainingRange = NSMakeRange(range.location, remainingRange.location + remainingRange.length - range.location)
        }
        
        switch entity.type {
//            case .Url:
//                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
//                if underlineLinks {
//                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
//                }
//                if nsString == nil {
//                    nsString = text as NSString
//                }
//                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), value: nsString!.substring(with: range), range: range)
//        case .Email:
//            string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
//            if nsString == nil {
//                nsString = text as NSString
//            }
//            if underlineLinks && underlineAllLinks {
//                string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
//            }
//            string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), value: "mailto:\(nsString!.substring(with: range))", range: range)
//        case let .TextUrl(url):
//            string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
//            if nsString == nil {
//                nsString = text as NSString
//            }
//            if underlineLinks && underlineAllLinks {
//                string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
//            }
//            string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), value: url, range: range)
        case .Bold:
            string.append("\\f1\\b ")
            string.append(nsString.substring(with: range))
            string.append("\\b0\\f0 ")
        case .Italic:
            string.append("\\f2\\i ")
            string.append(nsString.substring(with: range))
            string.append("\\i0\\f0 ")
        case .Code, .Pre:
            string.append("\\f3 ")
            string.append(nsString.substring(with: range))
            string.append("\\f0 ")
        default:
            string.append(nsString.substring(with: range))
            break
        }
        remainingRange = NSMakeRange(range.location + range.length, remainingRange.location + remainingRange.length - (range.location + range.length))
    }
    
    if remainingRange.length > 0 {
        string.append(nsString.substring(with: NSMakeRange(remainingRange.location, remainingRange.length)))
    }
    
    string.append("}")
    
    string = string.replacingOccurrences(of: "\n", with: "\\line")
    
    return string
}

func chatInputStateStringFromRTF(_ data: Data, type: NSAttributedString.DocumentType) -> NSAttributedString? {
    if let attributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: type], documentAttributes: nil) {
        
        let string = NSMutableAttributedString(string: attributedString.string)
        attributedString.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedString.length), options: [], using: { value, range, _ in
            if let font = value as? UIFont {
                let fontName = font.fontName.lowercased()
                if fontName.contains("bold") {
                    string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: range)
                } else if fontName.contains("italic") {
                    string.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: range)
                } else if fontName.contains("menlo") {
                    string.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: range)
                }
            }
        })
        return string
    }
    return nil
}

func storeMessageTextInPasteboard(_ text: String, entities: [MessageTextEntity]?) {
    var items: [String: Any] = [:]
    items[kUTTypeUTF8PlainText as String] = text
    
    if let entities = entities {
        items[kUTTypeRTF as String] = rtfStringWithAppliedEntities(text, entities: entities)
    }
    UIPasteboard.general.items = [items]
}

func storeInputTextInPasteboard(_ text: NSAttributedString) {
    let entities = generateChatInputTextEntities(text)
    storeMessageTextInPasteboard(text.string, entities: entities)
}
