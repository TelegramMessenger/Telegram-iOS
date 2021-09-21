import Foundation
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import LocalizedPeerData

enum MessageTimestampStatusFormat {
    case regular
    case minimal
}

private func dateStringForDay(strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, timestamp: Int32) -> String {
    var t: time_t = time_t(timestamp)
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    let timestampNow = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(timestampNow)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    if timeinfo.tm_year != timeinfoNow.tm_year {
        return "\(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, year: timeinfo.tm_year, dateTimeFormat: dateTimeFormat))"
    } else {
        return "\(stringForTimestamp(day: timeinfo.tm_mday, month: timeinfo.tm_mon + 1, dateTimeFormat: dateTimeFormat))"
    }
}

func stringForMessageTimestampStatus(accountPeerId: PeerId, message: Message, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, strings: PresentationStrings, format: MessageTimestampStatusFormat = .regular) -> String {
    if message.adAttribute != nil {
        return strings.Message_SponsoredLabel
    }

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
    
    if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported) {
        dateText = strings.Message_ImportedDateFormat(dateStringForDay(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: forwardInfo.date), stringForMessageTimestamp(timestamp: forwardInfo.date, dateTimeFormat: dateTimeFormat), dateText).string
    }
    
    var authorTitle: String?
    if let author = message.author as? TelegramUser {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            authorTitle = EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
        } else if let forwardInfo = message.forwardInfo, forwardInfo.sourceMessageId?.peerId.namespace == Namespaces.Peer.CloudChannel {
            authorTitle = forwardInfo.authorSignature
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
