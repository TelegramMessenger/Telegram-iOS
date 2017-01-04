import Foundation
import TelegramCore

func stringWithAppliedEntities(_ text: String, entities: [MessageTextEntity], baseFont: UIFont, boldFont: UIFont, fixedFont: UIFont) -> NSAttributedString {
    var nsString: NSString?
    let string = NSMutableAttributedString(string: text, attributes: [NSFontAttributeName: baseFont, NSForegroundColorAttributeName: UIColor.black])
    var skipEntity = false
    for i in 0 ..< entities.count {
        if skipEntity {
            skipEntity = false
            continue
        }
        let entity = entities[i]
        let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
        switch entity.type {
            case .Url:
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: range)
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(TextNode.UrlAttribute, value: nsString!.substring(with: range), range: range)
            case .Email:
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(TextNode.UrlAttribute, value: "mailto:\(nsString!.substring(with: range))", range: range)
            case let .TextUrl(url):
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(TextNode.UrlAttribute, value: url, range: range)
            case .Bold:
                string.addAttribute(NSFontAttributeName, value: boldFont, range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
            case .Mention:
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(TextNode.TelegramPeerTextMentionAttribute, value: nsString!.substring(with: range), range: range)
            case let .TextMention(peerId):
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                string.addAttribute(TextNode.TelegramPeerMentionAttribute, value: peerId.toInt64() as NSNumber, range: range)
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
                            string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: combinedRange)
                            string.addAttribute(TextNode.TelegramHashtagAttribute, value: TelegramHashtag(peerName: peerName, hashtag: hashtag), range: combinedRange)
                        }
                    }
                }
                if !skipEntity {
                    string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: range)
                    string.addAttribute(TextNode.TelegramHashtagAttribute, value: TelegramHashtag(peerName: nil, hashtag: hashtag), range: range)
                }
            case .BotCommand:
                string.addAttribute(NSForegroundColorAttributeName, value: UIColor(0x004bad), range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
                if nsString == nil {
                    nsString = text as NSString
                }
                string.addAttribute(TextNode.TelegramBotCommandAttribute, value: nsString!.substring(with: range), range: range)
            case .Code, .Pre:
                string.addAttribute(NSFontAttributeName, value: fixedFont, range: NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound))
            default:
                break
        }
    }
    return string
}
