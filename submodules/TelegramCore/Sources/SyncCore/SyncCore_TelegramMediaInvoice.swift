import Foundation
import Postbox

public struct TelegramMediaInvoiceFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let isTest = TelegramMediaInvoiceFlags(rawValue: 1 << 0)
    public static let shippingAddressRequested = TelegramMediaInvoiceFlags(rawValue: 1 << 1)
}

public enum TelegramExtendedMedia: PostboxCoding, Equatable {
    public static func ==(lhs: TelegramExtendedMedia, rhs: TelegramExtendedMedia) -> Bool {
        switch lhs {
            case let .preview(lhsDimensions, lhsImmediateThumbnailData, lhsVideoDuration):
                if case let .preview(rhsDimensions, rhsImmediateThumbnailData, rhsVideoDuration) = rhs, lhsDimensions == rhsDimensions, lhsImmediateThumbnailData == rhsImmediateThumbnailData, lhsVideoDuration == rhsVideoDuration {
                    return true
                } else {
                    return false
                }
            case let .full(lhsMedia):
                if case let .full(rhsMedia) = rhs, lhsMedia.isEqual(to: rhsMedia) {
                    return true
                } else {
                    return false
                }
        }
    }
    
    case preview(dimensions: PixelDimensions?, immediateThumbnailData: Data?, videoDuration: Int32?)
    case full(media: Media)
    
    public init(decoder: PostboxDecoder) {
        let type = decoder.decodeInt32ForKey("t", orElse: 0)
        switch type {
            case 0:
                let width = decoder.decodeOptionalInt32ForKey("width")
                let height = decoder.decodeOptionalInt32ForKey("height")
                var dimensions: PixelDimensions?
                if let width = width, let height = height {
                    dimensions = PixelDimensions(width: width, height: height)
                }
                let immediateThumbnailData = decoder.decodeDataForKey("thumb")
                let videoDuration = decoder.decodeOptionalInt32ForKey("duration")
                self = .preview(dimensions: dimensions, immediateThumbnailData: immediateThumbnailData, videoDuration: videoDuration)
            case 1:
                let media = decoder.decodeObjectForKey("media") as! Media
                self = .full(media: media)
            default:
                self = .preview(dimensions: nil, immediateThumbnailData: nil, videoDuration: nil)
                fatalError()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .preview(dimensions, immediateThumbnailData, videoDuration):
                encoder.encodeInt32(0, forKey: "t")
                if let dimensions = dimensions {
                    encoder.encodeInt32(dimensions.width, forKey: "width")
                    encoder.encodeInt32(dimensions.height, forKey: "height")
                } else {
                    encoder.encodeNil(forKey: "width")
                    encoder.encodeNil(forKey: "height")
                }
                if let immediateThumbnailData = immediateThumbnailData {
                    encoder.encodeData(immediateThumbnailData, forKey: "thumb")
                } else {
                    encoder.encodeNil(forKey: "thumb")
                }
                if let videoDuration = videoDuration {
                    encoder.encodeInt32(videoDuration, forKey: "duration")
                } else {
                    encoder.encodeNil(forKey: "duration")
                }
            case let .full(media):
                encoder.encodeInt32(1, forKey: "t")
                encoder.encodeObject(media, forKey: "media")
        }
    }
}

public final class TelegramMediaInvoice: Media {
    public static let lastVersion: Int32 = 1

    public var peerIds: [PeerId] = []

    public var id: MediaId? = nil

    public let title: String
    public let description: String
    public let receiptMessageId: MessageId?
    public let currency: String
    public let totalAmount: Int64
    public let startParam: String
    public let photo: TelegramMediaWebFile?
    public let flags: TelegramMediaInvoiceFlags
    public let extendedMedia: TelegramExtendedMedia?
    
    public let version: Int32
    
    public init(title: String, description: String, photo: TelegramMediaWebFile?, receiptMessageId: MessageId?, currency: String, totalAmount: Int64, startParam: String, extendedMedia: TelegramExtendedMedia?, flags: TelegramMediaInvoiceFlags, version: Int32) {
        self.title = title
        self.description = description
        self.photo = photo
        self.receiptMessageId = receiptMessageId
        self.currency = currency
        self.totalAmount = totalAmount
        self.startParam = startParam
        self.flags = flags
        self.extendedMedia = extendedMedia
        self.version = version
    }
    
    public init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.description = decoder.decodeStringForKey("d", orElse: "")
        self.currency = decoder.decodeStringForKey("c", orElse: "")
        self.totalAmount = decoder.decodeInt64ForKey("ta", orElse: 0)
        self.startParam = decoder.decodeStringForKey("sp", orElse: "")
        self.photo = decoder.decodeObjectForKey("p") as? TelegramMediaWebFile
        self.flags = TelegramMediaInvoiceFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.extendedMedia = decoder.decodeObjectForKey("m", decoder: { TelegramExtendedMedia(decoder: $0) }) as? TelegramExtendedMedia
        
        if let receiptMessageIdPeerId = decoder.decodeOptionalInt64ForKey("r.p") as Int64?, let receiptMessageIdNamespace = decoder.decodeOptionalInt32ForKey("r.n") as Int32?, let receiptMessageIdId = decoder.decodeOptionalInt32ForKey("r.i") as Int32? {
            self.receiptMessageId = MessageId(peerId: PeerId(receiptMessageIdPeerId), namespace: receiptMessageIdNamespace, id: receiptMessageIdId)
        } else {
            self.receiptMessageId = nil
        }
        
        self.version = decoder.decodeInt32ForKey("vrs", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.description, forKey: "d")
        encoder.encodeString(self.currency, forKey: "c")
        encoder.encodeInt64(self.totalAmount, forKey: "ta")
        encoder.encodeString(self.startParam, forKey: "sp")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")

        if let photo = self.photo {
            encoder.encodeObject(photo, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }

        if let extendedMedia = self.extendedMedia {
            encoder.encodeObject(extendedMedia, forKey: "m")
        } else {
            encoder.encodeNil(forKey: "m")
        }
        
        if let receiptMessageId = self.receiptMessageId {
            encoder.encodeInt64(receiptMessageId.peerId.toInt64(), forKey: "r.p")
            encoder.encodeInt32(receiptMessageId.namespace, forKey: "r.n")
            encoder.encodeInt32(receiptMessageId.id, forKey: "r.i")
        } else {
            encoder.encodeNil(forKey: "r.p")
            encoder.encodeNil(forKey: "r.n")
            encoder.encodeNil(forKey: "r.i")
        }
        
        encoder.encodeInt32(self.version, forKey: "vrs")
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaInvoice else {
            return false
        }
        
        if self.title != other.title {
            return false
        }
        
        if self.description != other.description {
            return false
        }
        
        if self.currency != other.currency {
            return false
        }
        
        if self.totalAmount != other.totalAmount {
            return false
        }
        
        if self.startParam != other.startParam {
            return false
        }
        
        if self.receiptMessageId != other.receiptMessageId {
            return false
        }
        
        if self.flags != other.flags {
            return false
        }
    
        if self.extendedMedia != other.extendedMedia {
            return false
        }
        
        if self.version != other.version {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
    
    public func withUpdatedExtendedMedia(_ extendedMedia: TelegramExtendedMedia) -> TelegramMediaInvoice {
        return TelegramMediaInvoice(
            title: self.title,
            description: self.description,
            photo: self.photo,
            receiptMessageId: self.receiptMessageId,
            currency: self.currency,
            totalAmount: self.totalAmount,
            startParam: self.startParam,
            extendedMedia: extendedMedia,
            flags: self.flags,
            version: self.version
        )
    }
}
