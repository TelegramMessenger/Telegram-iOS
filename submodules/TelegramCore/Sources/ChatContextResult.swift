import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public enum ChatContextResultMessage: PostboxCoding, Equatable {
    case auto(caption: String, entities: TextEntitiesMessageAttribute?, replyMarkup: ReplyMarkupMessageAttribute?)
    case text(text: String, entities: TextEntitiesMessageAttribute?, disableUrlPreview: Bool, replyMarkup: ReplyMarkupMessageAttribute?)
    case mapLocation(media: TelegramMediaMap, replyMarkup: ReplyMarkupMessageAttribute?)
    case contact(media: TelegramMediaContact, replyMarkup: ReplyMarkupMessageAttribute?)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .auto(caption: decoder.decodeStringForKey("c", orElse: ""), entities: decoder.decodeObjectForKey("e") as? TextEntitiesMessageAttribute, replyMarkup: decoder.decodeObjectForKey("m") as? ReplyMarkupMessageAttribute)
            case 1:
                self = .text(text: decoder.decodeStringForKey("t", orElse: ""), entities: decoder.decodeObjectForKey("e") as? TextEntitiesMessageAttribute, disableUrlPreview: decoder.decodeInt32ForKey("du", orElse: 0) != 0, replyMarkup: decoder.decodeObjectForKey("m") as? ReplyMarkupMessageAttribute)
            case 2:
                self = .mapLocation(media: decoder.decodeObjectForKey("l") as! TelegramMediaMap, replyMarkup: decoder.decodeObjectForKey("m") as? ReplyMarkupMessageAttribute)
            case 3:
                self = .contact(media: decoder.decodeObjectForKey("c") as! TelegramMediaContact, replyMarkup: decoder.decodeObjectForKey("m") as? ReplyMarkupMessageAttribute)
            default:
                self = .auto(caption: "", entities: nil, replyMarkup: nil)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .auto(caption, entities, replyMarkup):
                encoder.encodeInt32(0, forKey: "_v")
                encoder.encodeString(caption, forKey: "c")
                if let entities = entities {
                    encoder.encodeObject(entities, forKey: "e")
                } else {
                    encoder.encodeNil(forKey: "e")
                }
                if let replyMarkup = replyMarkup {
                    encoder.encodeObject(replyMarkup, forKey: "m")
                } else {
                    encoder.encodeNil(forKey: "m")
                }
            case let .text(text, entities, disableUrlPreview, replyMarkup):
                encoder.encodeInt32(1, forKey: "_v")
                encoder.encodeString(text, forKey: "t")
                if let entities = entities {
                    encoder.encodeObject(entities, forKey: "e")
                } else {
                    encoder.encodeNil(forKey: "e")
                }
                encoder.encodeInt32(disableUrlPreview ? 1 : 0, forKey: "du")
                if let replyMarkup = replyMarkup {
                    encoder.encodeObject(replyMarkup, forKey: "m")
                } else {
                    encoder.encodeNil(forKey: "m")
                }
            case let .mapLocation(media, replyMarkup):
                encoder.encodeInt32(2, forKey: "_v")
                encoder.encodeObject(media, forKey: "l")
                if let replyMarkup = replyMarkup {
                    encoder.encodeObject(replyMarkup, forKey: "m")
                } else {
                    encoder.encodeNil(forKey: "m")
                }
            case let .contact(media, replyMarkup):
                encoder.encodeInt32(3, forKey: "_v")
                encoder.encodeObject(media, forKey: "c")
                if let replyMarkup = replyMarkup {
                    encoder.encodeObject(replyMarkup, forKey: "m")
                } else {
                    encoder.encodeNil(forKey: "m")
                }
        }
    }
    
    public static func ==(lhs: ChatContextResultMessage, rhs: ChatContextResultMessage) -> Bool {
        switch lhs {
            case let .auto(lhsCaption, lhsEntities, lhsReplyMarkup):
                if case let .auto(rhsCaption, rhsEntities, rhsReplyMarkup) = rhs {
                    if lhsCaption != rhsCaption {
                        return false
                    }
                    if lhsEntities != rhsEntities {
                        return false
                    }
                    if lhsReplyMarkup != rhsReplyMarkup {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .text(lhsText, lhsEntities, lhsDisableUrlPreview, lhsReplyMarkup):
                if case let .text(rhsText, rhsEntities, rhsDisableUrlPreview, rhsReplyMarkup) = rhs {
                    if lhsText != rhsText {
                        return false
                    }
                    if lhsEntities != rhsEntities {
                        return false
                    }
                    if lhsDisableUrlPreview != rhsDisableUrlPreview {
                        return false
                    }
                    if lhsReplyMarkup != rhsReplyMarkup {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .mapLocation(lhsMedia, lhsReplyMarkup):
                if case let .mapLocation(rhsMedia, rhsReplyMarkup) = rhs {
                    if !lhsMedia.isEqual(to: rhsMedia) {
                        return false
                    }
                    if lhsReplyMarkup != rhsReplyMarkup {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .contact(lhsMedia, lhsReplyMarkup):
                if case let .contact(rhsMedia, rhsReplyMarkup) = rhs {
                    if !lhsMedia.isEqual(to: rhsMedia) {
                        return false
                    }
                    if lhsReplyMarkup != rhsReplyMarkup {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum ChatContextResult: Equatable {
    case externalReference(queryId: Int64, id: String, type: String, title: String?, description: String?, url: String?, content: TelegramMediaWebFile?, thumbnail: TelegramMediaWebFile?, message: ChatContextResultMessage)
    case internalReference(queryId: Int64, id: String, type: String, title: String?, description: String?, image: TelegramMediaImage?, file: TelegramMediaFile?, message: ChatContextResultMessage)

    public var queryId: Int64 {
        switch self {
            case let .externalReference(queryId, _, _, _, _, _, _, _, _):
                return queryId
            case let .internalReference(queryId, _, _, _, _, _, _, _):
                return queryId
        }
    }
    
    public var id: String {
        switch self {
            case let .externalReference(_, id, _, _, _, _, _, _, _):
                return id
            case let .internalReference(_, id, _, _, _, _, _, _):
                return id
        }
    }
    
    public var type: String {
        switch self {
            case let .externalReference(_, _, type, _, _, _, _, _, _):
                return type
            case let .internalReference(_, _, type, _, _, _, _, _):
                return type
        }
    }
    
    public var title: String? {
        switch self {
            case let .externalReference(_, _, _, title, _, _, _, _, _):
                return title
            case let .internalReference(_, _, _, title, _, _, _, _):
                return title
        }
    }
    
    public var description: String? {
        switch self {
            case let .externalReference(_, _, _, _, description, _, _, _, _):
                return description
            case let .internalReference(_, _, _, _, description, _, _, _):
                return description
        }
    }
    
    public var message: ChatContextResultMessage {
        switch self {
            case let .externalReference(_, _, _, _, _, _, _, _, message):
                return message
            case let .internalReference(_, _, _, _, _, _, _, message):
                return message
        }
    }
    
    public static func ==(lhs: ChatContextResult, rhs: ChatContextResult) -> Bool {
        switch lhs {
            //id: String, type: String, title: String?, description: String?, url: String?, content: TelegramMediaWebFile?, thumbnail: TelegramMediaWebFile?, message: ChatContextResultMessage
            case let .externalReference(lhsQueryId, lhsId, lhsType, lhsTitle, lhsDescription, lhsUrl, lhsContent, lhsThumbnail, lhsMessage):
                if case let .externalReference(rhsQueryId, rhsId, rhsType, rhsTitle, rhsDescription, rhsUrl, rhsContent, rhsThumbnail, rhsMessage) = rhs {
                    if lhsQueryId != rhsQueryId {
                        return false
                    }
                    if lhsId != rhsId {
                        return false
                    }
                    if lhsType != rhsType {
                        return false
                    }
                    if lhsTitle != rhsTitle {
                        return false
                    }
                    if lhsDescription != rhsDescription {
                        return false
                    }
                    if lhsUrl != rhsUrl {
                        return false
                    }
                    if let lhsContent = lhsContent, let rhsContent = rhsContent {
                        if !lhsContent.isEqual(to: rhsContent) {
                            return false
                        }
                    } else if (lhsContent != nil) != (rhsContent != nil) {
                        return false
                    }
                    if let lhsThumbnail = lhsThumbnail, let rhsThumbnail = rhsThumbnail {
                        if !lhsThumbnail.isEqual(to: rhsThumbnail) {
                            return false
                        }
                    } else if (lhsThumbnail != nil) != (rhsThumbnail != nil) {
                        return false
                    }
                    if lhsMessage != rhsMessage {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .internalReference(lhsQueryId, lhsId, lhsType, lhsTitle, lhsDescription, lhsImage, lhsFile, lhsMessage):
                if case let .internalReference(rhsQueryId, rhsId, rhsType, rhsTitle, rhsDescription, rhsImage, rhsFile, rhsMessage) = rhs {
                    if lhsQueryId != rhsQueryId {
                        return false
                    }
                    if lhsId != rhsId {
                        return false
                    }
                    if lhsType != rhsType {
                        return false
                    }
                    if lhsTitle != rhsTitle {
                        return false
                    }
                    if lhsDescription != rhsDescription {
                        return false
                    }
                    if let lhsImage = lhsImage, let rhsImage = rhsImage {
                        if !lhsImage.isEqual(to: rhsImage) {
                            return false
                        }
                    } else if (lhsImage != nil) != (rhsImage != nil) {
                        return false
                    }
                    if let lhsFile = lhsFile, let rhsFile = rhsFile {
                        if !lhsFile.isEqual(to: rhsFile) {
                            return false
                        }
                    } else if (lhsFile != nil) != (rhsFile != nil) {
                        return false
                    }
                    if lhsMessage != rhsMessage {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum ChatContextResultCollectionPresentation {
    case media
    case list
}

public struct ChatContextResultSwitchPeer: Equatable {
    public let text: String
    public let startParam: String
    
    public static func ==(lhs: ChatContextResultSwitchPeer, rhs: ChatContextResultSwitchPeer) -> Bool {
        return lhs.text == rhs.text && lhs.startParam == rhs.startParam
    }
}

public final class ChatContextResultCollection: Equatable {
    public let botId: PeerId
    public let peerId: PeerId
    public let query: String
    public let geoPoint: (Double, Double)?
    public let queryId: Int64
    public let nextOffset: String?
    public let presentation: ChatContextResultCollectionPresentation
    public let switchPeer: ChatContextResultSwitchPeer?
    public let results: [ChatContextResult]
    public let cacheTimeout: Int32
    
    public init(botId: PeerId, peerId: PeerId, query: String, geoPoint: (Double, Double)?, queryId: Int64, nextOffset: String?, presentation: ChatContextResultCollectionPresentation, switchPeer: ChatContextResultSwitchPeer?, results: [ChatContextResult], cacheTimeout: Int32) {
        self.botId = botId
        self.peerId = peerId
        self.query = query
        self.geoPoint = geoPoint
        self.queryId = queryId
        self.nextOffset = nextOffset
        self.presentation = presentation
        self.switchPeer = switchPeer
        self.results = results
        self.cacheTimeout = cacheTimeout
    }
    
    public static func ==(lhs: ChatContextResultCollection, rhs: ChatContextResultCollection) -> Bool {
        if lhs.botId != rhs.botId {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.queryId != rhs.queryId {
            return false
        }
        if lhs.query != rhs.query {
            return false
        }
        if lhs.geoPoint?.0 != rhs.geoPoint?.0 || lhs.geoPoint?.1 != rhs.geoPoint?.1 {
            return false
        }
        if lhs.nextOffset != rhs.nextOffset {
            return false
        }
        if lhs.presentation != rhs.presentation {
            return false
        }
        if lhs.switchPeer != rhs.switchPeer {
            return false
        }
        if lhs.results != rhs.results {
            return false
        }
        if lhs.cacheTimeout != rhs.cacheTimeout {
            return false
        }
        return true
    }
}

extension ChatContextResultMessage {
    init(apiMessage: Api.BotInlineMessage) {
        switch apiMessage {
            case let .botInlineMessageMediaAuto(_, message, entities, replyMarkup):
                var parsedEntities: TextEntitiesMessageAttribute?
                if let entities = entities, !entities.isEmpty {
                    parsedEntities = TextEntitiesMessageAttribute(entities: messageTextEntitiesFromApiEntities(entities))
                }
                var parsedReplyMarkup: ReplyMarkupMessageAttribute?
                if let replyMarkup = replyMarkup {
                    parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                }
                self = .auto(caption: message, entities: parsedEntities, replyMarkup: parsedReplyMarkup)
            case let .botInlineMessageText(flags, message, entities, replyMarkup):
                var parsedEntities: TextEntitiesMessageAttribute?
                if let entities = entities, !entities.isEmpty {
                    parsedEntities = TextEntitiesMessageAttribute(entities: messageTextEntitiesFromApiEntities(entities))
                }
                var parsedReplyMarkup: ReplyMarkupMessageAttribute?
                if let replyMarkup = replyMarkup {
                    parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                }
                self = .text(text: message, entities: parsedEntities, disableUrlPreview: (flags & (1 << 0)) != 0, replyMarkup: parsedReplyMarkup)
            case let .botInlineMessageMediaGeo(_, geo, replyMarkup):
                let media = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: nil)
                var parsedReplyMarkup: ReplyMarkupMessageAttribute?
                if let replyMarkup = replyMarkup {
                    parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                }
                self = .mapLocation(media: media, replyMarkup: parsedReplyMarkup)
            case let .botInlineMessageMediaVenue(_, geo, title, address, provider, venueId, venueType, replyMarkup):
                let media = telegramMediaMapFromApiGeoPoint(geo, title: title, address: address, provider: provider, venueId: venueId, venueType: venueType, liveBroadcastingTimeout: nil)
                var parsedReplyMarkup: ReplyMarkupMessageAttribute?
                if let replyMarkup = replyMarkup {
                    parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                }
                self = .mapLocation(media: media, replyMarkup: parsedReplyMarkup)
            case let .botInlineMessageMediaContact(_, phoneNumber, firstName, lastName, vcard, replyMarkup):
                let media = TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: nil, vCardData: vcard.isEmpty ? nil : vcard)
                var parsedReplyMarkup: ReplyMarkupMessageAttribute?
                if let replyMarkup = replyMarkup {
                    parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                }
                self = .contact(media: media, replyMarkup: parsedReplyMarkup)
        }
    }
}

extension ChatContextResult {
    init(apiResult: Api.BotInlineResult, queryId: Int64) {
        switch apiResult {
            case let .botInlineResult(_, id, type, title, description, url, thumb, content, sendMessage):
                self = .externalReference(queryId: queryId, id: id, type: type, title: title, description: description, url: url, content: content.flatMap(TelegramMediaWebFile.init), thumbnail: thumb.flatMap(TelegramMediaWebFile.init), message: ChatContextResultMessage(apiMessage: sendMessage))
            case let .botInlineMediaResult(_, id, type, photo, document, title, description, sendMessage):
                var image: TelegramMediaImage?
                var file: TelegramMediaFile?
                if let photo = photo, let parsedImage = telegramMediaImageFromApiPhoto(photo) {
                    image = parsedImage
                }
                if let document = document, let parsedFile = telegramMediaFileFromApiDocument(document) {
                    file = parsedFile
                }
                self = .internalReference(queryId: queryId, id: id, type: type, title: title, description: description, image: image, file: file, message: ChatContextResultMessage(apiMessage: sendMessage))
        }
    }
}

extension ChatContextResultSwitchPeer {
    init(apiSwitchPeer: Api.InlineBotSwitchPM) {
        switch apiSwitchPeer {
            case let .inlineBotSwitchPM(text, startParam):
                self.init(text: text, startParam: startParam)
        }
    }
}

extension ChatContextResultCollection {
    convenience init(apiResults: Api.messages.BotResults, botId: PeerId, peerId: PeerId, query: String, geoPoint: (Double, Double)?) {
        switch apiResults {
            case let .botResults(flags, queryId, nextOffset, switchPm, results, cacheTime, _):
                var switchPeer: ChatContextResultSwitchPeer?
                if let switchPm = switchPm {
                    switchPeer = ChatContextResultSwitchPeer(apiSwitchPeer: switchPm)
                }
                let parsedResults = results.map({ ChatContextResult(apiResult: $0, queryId: queryId) })
                /*.filter({ result in
                    switch result {
                        case .internalReference:
                            return false
                        default:
                            return true
                    }
                })*/
                self.init(botId: botId, peerId: peerId, query: query, geoPoint: geoPoint, queryId: queryId, nextOffset: nextOffset, presentation: (flags & (1 << 0) != 0) ? .media : .list, switchPeer: switchPeer, results: parsedResults, cacheTimeout: cacheTime)
        }
    }
}
