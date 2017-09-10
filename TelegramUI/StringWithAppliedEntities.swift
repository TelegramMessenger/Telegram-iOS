import Foundation
import TelegramCore

func stringWithAppliedEntities(_ text: String, entities: [MessageTextEntity], baseColor: UIColor, linkColor: UIColor, baseFont: UIFont, boldFont: UIFont, fixedFont: UIFont) -> NSAttributedString {
    var nsString: NSString?
    let string = NSMutableAttributedString(string: text, attributes: [NSAttributedStringKey.font: baseFont, NSAttributedStringKey.foregroundColor: baseColor])
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
            case .Url:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TextNode.UrlAttribute), value: nsString!.substring(with: range), range: range)
            case .Email:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TextNode.UrlAttribute), value: "mailto:\(nsString!.substring(with: range))", range: range)
            case let .TextUrl(url):
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TextNode.UrlAttribute), value: url, range: range)
            case .Bold:
                string.addAttribute(NSAttributedStringKey.font, value: boldFont, range: range)
            case .Mention:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TextNode.TelegramPeerTextMentionAttribute), value: nsString!.substring(with: range), range: range)
            case let .TextMention(peerId):
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                let mention = nsString!.substring(with: range)
                string.addAttribute(NSAttributedStringKey(rawValue: TextNode.TelegramPeerMentionAttribute), value: TelegramPeerMention(peerId: peerId, mention: mention), range: range)
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
                            string.addAttribute(NSAttributedStringKey(rawValue: TextNode.TelegramHashtagAttribute), value: TelegramHashtag(peerName: peerName, hashtag: hashtag), range: combinedRange)
                        }
                    }
                }
                if !skipEntity {
                    string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                    string.addAttribute(NSAttributedStringKey(rawValue: TextNode.TelegramHashtagAttribute), value: TelegramHashtag(peerName: nil, hashtag: hashtag), range: range)
                }
            case .BotCommand:
                string.addAttribute(NSAttributedStringKey.foregroundColor, value: linkColor, range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(NSAttributedStringKey(rawValue: TextNode.TelegramBotCommandAttribute), value: nsString!.substring(with: range), range: range)
            case .Code, .Pre:
                string.addAttribute(NSAttributedStringKey.font, value: fixedFont, range: range)
            default:
                break
        }
    }
    return string
}
