import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum ChatContextResultMessageDecodingError: Error {
    case generic
}

public enum ChatContextResultMessage: PostboxCoding, Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case data
    }
    
    case auto(caption: String, entities: TextEntitiesMessageAttribute?, replyMarkup: ReplyMarkupMessageAttribute?)
    case text(text: String, entities: TextEntitiesMessageAttribute?, disableUrlPreview: Bool, replyMarkup: ReplyMarkupMessageAttribute?)
    case mapLocation(media: TelegramMediaMap, replyMarkup: ReplyMarkupMessageAttribute?)
    case contact(media: TelegramMediaContact, replyMarkup: ReplyMarkupMessageAttribute?)
    case invoice(media: TelegramMediaInvoice, replyMarkup: ReplyMarkupMessageAttribute?)
    
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
            case 4:
                self = .invoice(media: decoder.decodeObjectForKey("i") as! TelegramMediaInvoice, replyMarkup: decoder.decodeObjectForKey("m") as? ReplyMarkupMessageAttribute)
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
            case let .invoice(media: media, replyMarkup):
                encoder.encodeInt32(4, forKey: "_v")
                encoder.encodeObject(media, forKey: "i")
                if let replyMarkup = replyMarkup {
                    encoder.encodeObject(replyMarkup, forKey: "m")
                } else {
                    encoder.encodeNil(forKey: "m")
                }
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .data)
        let postboxDecoder = PostboxDecoder(buffer: MemoryBuffer(data: data))
        self = ChatContextResultMessage(decoder: postboxDecoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        let postboxEncoder = PostboxEncoder()
        self.encode(postboxEncoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postboxEncoder.makeData(), forKey: .data)
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
            case let .invoice(lhsMedia, lhsReplyMarkup):
                if case let .invoice(rhsMedia, rhsReplyMarkup) = rhs {
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

public enum ChatContextResultDecodingError: Error {
    case generic
}

public enum ChatContextResult: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case externalReference
        case internalReference
    }
    
    public struct ExternalReference: Equatable, Codable {
        public let queryId: Int64
        public let id: String
        public let type: String
        public let title: String?
        public let description: String?
        public let url: String?
        public let content: TelegramMediaWebFile?
        public let thumbnail: TelegramMediaWebFile?
        public let message: ChatContextResultMessage
        
        public init(
            queryId: Int64,
            id: String,
            type: String,
            title: String?,
            description: String?,
            url: String?,
            content: TelegramMediaWebFile?,
            thumbnail: TelegramMediaWebFile?,
            message: ChatContextResultMessage
        ) {
            self.queryId = queryId
            self.id = id
            self.type = type
            self.title = title
            self.description = description
            self.url = url
            self.content = content
            self.thumbnail = thumbnail
            self.message = message
        }
    }
    
    public struct InternalReference: Equatable, Codable {
        public let queryId: Int64
        public let id: String
        public let type: String
        public let title: String?
        public let description: String?
        public let image: TelegramMediaImage?
        public let file: TelegramMediaFile?
        public let message: ChatContextResultMessage
        
        public init(
            queryId: Int64,
            id: String,
            type: String,
            title: String?,
            description: String?,
            image: TelegramMediaImage?,
            file: TelegramMediaFile?,
            message: ChatContextResultMessage
        ) {
            self.queryId = queryId
            self.id = id
            self.type = type
            self.title = title
            self.description = description
            self.image = image
            self.file = file
            self.message = message
        }
    }
    
    case externalReference(ExternalReference)
    case internalReference(InternalReference)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let externalReference = try? container.decode(ExternalReference.self, forKey: .externalReference) {
            self = .externalReference(externalReference)
        } else if let internalReference = try? container.decode(InternalReference.self, forKey: .internalReference) {
            self = .internalReference(internalReference)
        } else {
            throw ChatContextResultDecodingError.generic
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .internalReference(internalReference):
            try container.encode(internalReference, forKey: .internalReference)
        case let .externalReference(externalReference):
            try container.encode(externalReference, forKey: .externalReference)
        }
    }

    public var queryId: Int64 {
        switch self {
            case let .externalReference(externalReference):
                return externalReference.queryId
            case let .internalReference(internalReference):
                return internalReference.queryId
        }
    }
    
    public var id: String {
        switch self {
            case let .externalReference(externalReference):
                return externalReference.id
            case let .internalReference(internalReference):
                return internalReference.id
        }
    }
    
    public var type: String {
        switch self {
            case let .externalReference(externalReference):
                return externalReference.type
            case let .internalReference(internalReference):
                return internalReference.type
        }
    }
    
    public var title: String? {
        switch self {
            case let .externalReference(externalReference):
                return externalReference.title
            case let .internalReference(internalReference):
                return internalReference.title
        }
    }
    
    public var description: String? {
        switch self {
            case let .externalReference(externalReference):
                return externalReference.description
            case let .internalReference(internalReference):
                return internalReference.description
        }
    }
    
    public var message: ChatContextResultMessage {
        switch self {
            case let .externalReference(externalReference):
                return externalReference.message
            case let .internalReference(internalReference):
                return internalReference.message
        }
    }
}

public enum ChatContextResultCollectionPresentation: Int32, Codable {
    case media
    case list
}

public struct ChatContextResultSwitchPeer: Equatable, Codable {
    public let text: String
    public let startParam: String
    
    public static func ==(lhs: ChatContextResultSwitchPeer, rhs: ChatContextResultSwitchPeer) -> Bool {
        return lhs.text == rhs.text && lhs.startParam == rhs.startParam
    }
}

public final class ChatContextResultCollection: Equatable, Codable {
    public struct GeoPoint: Equatable, Codable {
        public let latitude: Double
        public let longitude: Double
        
        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }
    
    public let botId: PeerId
    public let peerId: PeerId
    public let query: String
    public let geoPoint: ChatContextResultCollection.GeoPoint?
    public let queryId: Int64
    public let nextOffset: String?
    public let presentation: ChatContextResultCollectionPresentation
    public let switchPeer: ChatContextResultSwitchPeer?
    public let results: [ChatContextResult]
    public let cacheTimeout: Int32
    
    public init(botId: PeerId, peerId: PeerId, query: String, geoPoint: ChatContextResultCollection.GeoPoint?, queryId: Int64, nextOffset: String?, presentation: ChatContextResultCollectionPresentation, switchPeer: ChatContextResultSwitchPeer?, results: [ChatContextResult], cacheTimeout: Int32) {
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
        if lhs.geoPoint != rhs.geoPoint {
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
            case let .botInlineMessageMediaGeo(_, geo, heading, period, proximityNotificationRadius, replyMarkup):
                let media = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: period, liveProximityNotificationRadius: proximityNotificationRadius, heading: heading)
                var parsedReplyMarkup: ReplyMarkupMessageAttribute?
                if let replyMarkup = replyMarkup {
                    parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                }
                self = .mapLocation(media: media, replyMarkup: parsedReplyMarkup)
            case let .botInlineMessageMediaVenue(_, geo, title, address, provider, venueId, venueType, replyMarkup):
                let media = telegramMediaMapFromApiGeoPoint(geo, title: title, address: address, provider: provider, venueId: venueId, venueType: venueType, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil, heading: nil)
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
            case let .botInlineMessageMediaInvoice(flags, title, description, photo, currency, totalAmount, replyMarkup):
                var parsedFlags = TelegramMediaInvoiceFlags()
                if (flags & (1 << 3)) != 0 {
                    parsedFlags.insert(.isTest)
                }
                if (flags & (1 << 1)) != 0 {
                    parsedFlags.insert(.shippingAddressRequested)
                }
                var parsedReplyMarkup: ReplyMarkupMessageAttribute?
                if let replyMarkup = replyMarkup {
                    parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                }
                self = .invoice(media: TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: nil, currency: currency, totalAmount: totalAmount, startParam: "", flags: parsedFlags), replyMarkup: parsedReplyMarkup)
        }
    }
}

extension ChatContextResult {
    init(apiResult: Api.BotInlineResult, queryId: Int64) {
        switch apiResult {
            case let .botInlineResult(_, id, type, title, description, url, thumb, content, sendMessage):
                self = .externalReference(ChatContextResult.ExternalReference(queryId: queryId, id: id, type: type, title: title, description: description, url: url, content: content.flatMap(TelegramMediaWebFile.init), thumbnail: thumb.flatMap(TelegramMediaWebFile.init), message: ChatContextResultMessage(apiMessage: sendMessage)))
            case let .botInlineMediaResult(_, id, type, photo, document, title, description, sendMessage):
                var image: TelegramMediaImage?
                var file: TelegramMediaFile?
                if let photo = photo, let parsedImage = telegramMediaImageFromApiPhoto(photo) {
                    image = parsedImage
                }
                if let document = document, let parsedFile = telegramMediaFileFromApiDocument(document) {
                    file = parsedFile
                }
                self = .internalReference(ChatContextResult.InternalReference(queryId: queryId, id: id, type: type, title: title, description: description, image: image, file: file, message: ChatContextResultMessage(apiMessage: sendMessage)))
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
                let mappedGeoPoint = geoPoint.flatMap { geoPoint -> ChatContextResultCollection.GeoPoint in
                    return ChatContextResultCollection.GeoPoint(latitude: geoPoint.0, longitude: geoPoint.1)
                }
                self.init(botId: botId, peerId: peerId, query: query, geoPoint: mappedGeoPoint, queryId: queryId, nextOffset: nextOffset, presentation: (flags & (1 << 0) != 0) ? .media : .list, switchPeer: switchPeer, results: parsedResults, cacheTimeout: cacheTime)
        }
    }
}
