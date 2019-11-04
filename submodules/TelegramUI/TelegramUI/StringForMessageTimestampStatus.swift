import Foundation
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import LocalizedPeerData

enum MessageTimestampStatusFormat {
    case regular
    case minimal
}

func stringForMessageTimestampStatus(accountPeerId: PeerId, message: Message, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, strings: PresentationStrings, format: MessageTimestampStatusFormat = .regular, reactionCount: Int) -> String {
    let timestamp: Int32
    if let scheduleTime = message.scheduleTime {
        timestamp = scheduleTime
    } else {
        timestamp = message.timestamp
    }
    var dateText = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)
    if timestamp == scheduleWhenOnlineTimestamp {
        dateText = "         "
    }
    
    var authorTitle: String?
    if let author = message.author as? TelegramUser {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            authorTitle = author.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
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
        
        if message.id.peerId != accountPeerId {
            for attribute in message.attributes {
                if let attribute = attribute as? SourceReferenceMessageAttribute {
                    if let forwardInfo = message.forwardInfo {
                        if forwardInfo.author?.id == attribute.messageId.peerId {
                            if authorTitle == nil {
                                authorTitle = forwardInfo.authorSignature
                            }
                        }
                    }
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
