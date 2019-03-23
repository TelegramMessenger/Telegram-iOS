import Foundation
import TelegramCore

func chatInputStateStringWithAppliedEntities(_ text: String, entities: [MessageTextEntity]) -> NSAttributedString {
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
        if range.location + range.length > stringLength {
            range.location = max(0, stringLength - range.length)
            range.length = stringLength - range.location
        }
        switch entity.type {
            case .Url, .Email, .PhoneNumber, .TextUrl, .Mention, .Hashtag, .BotCommand:
                break
            case .Bold:
                string.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: range)
            case .Italic:
                string.addAttribute(ChatTextInputAttributes.italic, value: true as NSNumber, range: range)
            case let .TextMention(peerId):
                string.addAttribute(ChatTextInputAttributes.textMention, value: ChatTextInputTextMentionAttribute(peerId: peerId), range: range)
            case .Code, .Pre:
                string.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: range)
            default:
                break
        }
    }
    return string
}


func stringWithAppliedEntities(_ text: String, entities: [MessageTextEntity], baseColor: UIColor, linkColor: UIColor, baseFont: UIFont, linkFont: UIFont, boldFont: UIFont, italicFont: UIFont, fixedFont: UIFont, underlineLinks: Bool = true) -> NSAttributedString {
    var nsString: NSString?
    let string = NSMutableAttributedString(string: text, attributes: [NSAttributedStringKey.font: baseFont, NSAttributedStringKey.foregroundColor: baseColor])
    var skipEntity = false
    let stringLength = string.length
    var underlineAllLinks = false
    if linkColor.isEqual(baseColor) {
        underlineAllLinks = true
    }
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
        if range.location + range.length > stringLength {
            range.location = max(0, stringLength - range.length)
            range.length = stringLength - range.location
        }
        switch entity.type {
            case .Url:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if underlineLinks {
                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                }
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), value: nsString!.substring(with: range), range: range)
            case .Email:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), value: "mailto:\(nsString!.substring(with: range))", range: range)
            case .PhoneNumber:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), value: "tel:\(nsString!.substring(with: range))", range: range)
            case let .TextUrl(url):
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.URL), value: url, range: range)
            case .Bold:
                string.addAttribute(NSAttributedStringKey.font, value: boldFont, range: range)
            case .Italic:
                string.addAttribute(NSAttributedStringKey.font, value: italicFont, range: range)
            case .Mention:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                }
                if linkFont !== baseFont {
                    string.addAttribute(NSAttributedStringKey.font, value: linkFont, range: range)
                }
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention), value: nsString!.substring(with: range), range: range)
            case let .TextMention(peerId):
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                }
                if linkFont !== baseFont {
                    string.addAttribute(NSAttributedStringKey.font, value: linkFont, range: range)
                }
                let mention = nsString!.substring(with: range)
                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: peerId, mention: mention), range: range)
            case .Hashtag:
                if nsString == nil {
                    nsString = text as NSString
                }
                let hashtag = nsString!.substring(with: range)
                if i + 1 != entities.count {
                    if case .Mention = entities[i + 1].type {
                        let nextRange = NSRange(location: entities[i + 1].range.lowerBound, length: entities[i + 1].range.upperBound - entities[i + 1].range.lowerBound)
                        if nextRange.location == range.location + range.length + 1 && nsString!.character(at: range.location + range.length) == 43 {
                            let peerName: String = nsString!.substring(with: NSRange(location: nextRange.location + 1, length: nextRange.length - 1))
                            
                            skipEntity = true
                            let combinedRange = NSRange(location: range.location, length: nextRange.location + nextRange.length - range.location)
                            string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: combinedRange)
                            if linkColor.isEqual(baseColor) {
                                string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: combinedRange)
                            }
                            string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.Hashtag), value: TelegramHashtag(peerName: peerName, hashtag: hashtag), range: combinedRange)
                        }
                    }
                }
                if !skipEntity {
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if underlineLinks && underlineAllLinks {
                        string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                    }
                    string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.Hashtag), value: TelegramHashtag(peerName: nil, hashtag: hashtag), range: range)
                }
            case .BotCommand:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if underlineLinks && underlineAllLinks {
                    string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                }
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.BotCommand), value: nsString!.substring(with: range), range: range)
            case .Code, .Pre:
                string.addAttribute(NSAttributedStringKey.font, value: fixedFont, range: range)
            case let .Custom(type):
                if type == ApplicationSpecificEntityType.Timecode {
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    if underlineLinks && underlineAllLinks {
                        string.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: range)
                    }
                    if nsString == nil {
                        nsString = text as NSString
                    }
                    let text = nsString!.substring(with: range)
                    if let time = parseTimecodeString(text) {
                        string.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.Timecode), value: TelegramTimecode(time: time, text: text), range: range)
                    }
                }
            default:
                break
        }
    }
    return string
}
