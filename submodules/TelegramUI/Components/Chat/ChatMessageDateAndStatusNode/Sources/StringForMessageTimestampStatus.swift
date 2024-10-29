import Foundation
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import LocalizedPeerData
import AccountContext

public enum MessageTimestampStatusFormat {
    case full
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

private func monthAtIndex(_ index: Int, strings: PresentationStrings) -> String {
    switch index {
    case 0:
        return strings.Month_ShortJanuary
    case 1:
        return strings.Month_ShortFebruary
    case 2:
        return strings.Month_ShortMarch
    case 3:
        return strings.Month_ShortApril
    case 4:
        return strings.Month_ShortMay
    case 5:
        return strings.Month_ShortJune
    case 6:
        return strings.Month_ShortJuly
    case 7:
        return strings.Month_ShortAugust
    case 8:
        return strings.Month_ShortSeptember
    case 9:
        return strings.Month_ShortOctober
    case 10:
        return strings.Month_ShortNovember
    case 11:
        return strings.Month_ShortDecember
    default:
        return ""
    }
}

public func stringForMessageTimestampStatus(accountPeerId: PeerId, message: Message, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, strings: PresentationStrings, format: MessageTimestampStatusFormat = .regular, associatedData: ChatMessageItemAssociatedData, ignoreAuthor: Bool = false) -> String {
    if let adAttribute = message.adAttribute {
        switch adAttribute.messageType {
        case .sponsored:
            return strings.Message_SponsoredLabel
        case .recommended:
            return strings.Message_RecommendedLabel
        }
    }
    
    var timestamp: Int32
    if let scheduleTime = message.scheduleTime {
        timestamp = scheduleTime
    } else {
        timestamp = message.timestamp
    }
    
    var displayFullDate = false
    if case .full = format, timestamp > 100000 {
        displayFullDate = true
    } else if let forwardInfo = message.forwardInfo, message.id.peerId == accountPeerId {
        displayFullDate = true
        timestamp = forwardInfo.date
    }
    
    if let sourceAuthorInfo = message.sourceAuthorInfo, let orignalDate = sourceAuthorInfo.orignalDate {
        timestamp = orignalDate
    }
    
    var dateText = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)
    if timestamp == scheduleWhenOnlineTimestamp {
        dateText = "         "
    }
    
    if message.id.namespace == Namespaces.Message.ScheduledCloud, let _ = message.pendingProcessingAttribute {
        return "appx. \(dateText)"
    }
    
    if displayFullDate {
        let dayText: String
        
        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        var t: time_t = time_t(timestamp)
        var timeinfo: tm = tm()
        localtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(nowTimestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        if timeinfo.tm_year == timeinfoNow.tm_year {
            if format != .full, timeinfo.tm_yday == timeinfoNow.tm_yday {
                dayText = strings.Weekday_Today
            } else {
                dayText = strings.Date_ChatDateHeader(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)").string
            }
        } else {
            dayText = strings.Date_ChatDateHeaderYear(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)", "\(1900 + timeinfo.tm_year)").string
        }
        dateText = strings.Message_FullDateFormat(dayText, stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)).string
    }
    else if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported) {
        dateText = strings.Message_ImportedDateFormat(dateStringForDay(strings: strings, dateTimeFormat: dateTimeFormat, timestamp: forwardInfo.date), stringForMessageTimestamp(timestamp: forwardInfo.date, dateTimeFormat: dateTimeFormat), dateText).string
    }
    
    var authorTitle: String?
    if let author = message.author as? TelegramUser {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            if let channel = message.peers[message.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info, message.author?.id != channel.id, info.flags.contains(.messagesShouldHaveProfiles) {
            } else {
                authorTitle = EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
            }
        } else if let forwardInfo = message.forwardInfo, forwardInfo.sourceMessageId?.peerId.namespace == Namespaces.Peer.CloudChannel {
            authorTitle = forwardInfo.authorSignature
        }
    } else {
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
            if let channel = message.peers[message.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info, message.author?.id != channel.id, info.flags.contains(.messagesShouldHaveProfiles) {
            } else {
                for attribute in message.attributes {
                    if let attribute = attribute as? AuthorSignatureMessageAttribute {
                        authorTitle = attribute.signature
                        break
                    }
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
    
    if authorTitle == nil {
        for attribute in message.attributes {
            if let attribute = attribute as? InlineBusinessBotMessageAttribute {
                if let title = attribute.title {
                    authorTitle = title
                } else if let peerId = attribute.peerId, let peer = message.peers[peerId] {
                    authorTitle = peer.debugDisplayTitle
                }
            }
        }
    }
    
    if let subject = associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
        authorTitle = nil
    }
    if ignoreAuthor {
        authorTitle = nil
    }
    
    if case .minimal = format {
        
    } else {
        if let authorTitle = authorTitle, !authorTitle.isEmpty {
            dateText = "\(authorTitle), \(dateText)"
        }
    }
    
    return dateText
}
