import Foundation
import Postbox
import TelegramCore

enum MessageTimestampStatusFormat {
    case regular
    case minimal
}

func stringForMessageTimestampStatus(message: Message, dateTimeFormat: PresentationDateTimeFormat, strings: PresentationStrings, format: MessageTimestampStatusFormat = .regular) -> String {
    var dateText = stringForMessageTimestamp(timestamp: message.timestamp, dateTimeFormat: dateTimeFormat)
    
    var authorTitle: String?
    if let author = message.author as? TelegramUser {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            authorTitle = author.displayTitle
        }
    } else {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            for attribute in message.attributes {
                if let attribute = attribute as? AuthorSignatureMessageAttribute {
                    authorTitle = attribute.signature
                    break
                }
            }
        }
    }
    
    if case .regular = format {
        if let authorTitle = authorTitle, !authorTitle.isEmpty {
            dateText = "\(authorTitle), \(dateText)"
        }
    }
    
    return dateText
}
