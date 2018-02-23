import Foundation
import Postbox
import TelegramCore

func stringForMessageTimestampStatus(message: Message, timeFormat: PresentationTimeFormat, strings: PresentationStrings) -> String {
    var dateText = stringForMessageTimestamp(timestamp: message.timestamp, timeFormat: timeFormat)
    
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
    
    if let authorTitle = authorTitle, !authorTitle.isEmpty {
        dateText = "\(authorTitle), \(dateText)"
    }
    
    return dateText
}
