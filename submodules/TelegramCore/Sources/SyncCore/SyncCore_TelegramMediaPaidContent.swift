import Foundation
import Postbox

public final class TelegramMediaPaidContent: Media, Equatable {
    public var peerIds: [PeerId] = []

    public var id: MediaId? {
        return nil
    }

    public let amount: Int64
    public let extendedMedia: [TelegramExtendedMedia]
        
    public init(amount: Int64, extendedMedia: [TelegramExtendedMedia]) {
        self.amount = amount
        self.extendedMedia = extendedMedia
    }
    
    public init(decoder: PostboxDecoder) {
        self.amount = decoder.decodeInt64ForKey("a", orElse: 0)
        self.extendedMedia = (try? decoder.decodeObjectArrayWithCustomDecoderForKey("m", decoder: { TelegramExtendedMedia(decoder: $0) })) ?? []
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.amount, forKey: "a")
        encoder.encodeObjectArray(self.extendedMedia, forKey: "m")
    }
    
    public static func ==(lhs: TelegramMediaPaidContent, rhs: TelegramMediaPaidContent) -> Bool {
        return lhs.isEqual(to: rhs)
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaPaidContent else {
            return false
        }
        
        if self.amount != other.amount {
            return false
        }
        
        if self.extendedMedia != other.extendedMedia {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
    
    public func withUpdatedExtendedMedia(_ extendedMedia: [TelegramExtendedMedia]) -> TelegramMediaPaidContent {
        return TelegramMediaPaidContent(
            amount: self.amount,
            extendedMedia: extendedMedia
        )
    }
}
