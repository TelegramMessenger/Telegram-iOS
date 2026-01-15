import Foundation
import Postbox

public final class TelegramMediaDice: Media, Equatable {
    public struct GameOutcome: Equatable {
        let seed: Data
        public let tonAmount: Int64
    }
    
    public let emoji: String
    public let tonAmount: Int64?
    public let value: Int32?
    public let gameOutcome: GameOutcome?
    
    public let id: MediaId? = nil
    public let peerIds: [PeerId] = []
    
    public init(emoji: String, tonAmount: Int64? = nil, value: Int32? = nil, gameOutcome: GameOutcome? = nil) {
        self.emoji = emoji
        self.tonAmount = tonAmount
        self.value = value
        self.gameOutcome = gameOutcome
    }
    
    public init(decoder: PostboxDecoder) {
        self.emoji = decoder.decodeStringForKey("e", orElse: "🎲")
        self.tonAmount = decoder.decodeOptionalInt64ForKey("ta")
        self.value = decoder.decodeOptionalInt32ForKey("v")
        if let seed = decoder.decodeDataForKey("gos"), let tonAmount = decoder.decodeOptionalInt64ForKey("goa") {
            self.gameOutcome = GameOutcome(seed: seed, tonAmount: tonAmount)
        } else {
            self.gameOutcome = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.emoji, forKey: "e")
        if let tonAmount = self.tonAmount {
            encoder.encodeInt64(tonAmount, forKey: "ta")
        } else {
            encoder.encodeNil(forKey: "ta")
        }
        if let value = self.value {
            encoder.encodeInt32(value, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
        if let gameOutcome = self.gameOutcome {
            encoder.encodeData(gameOutcome.seed, forKey: "gos")
            encoder.encodeInt64(gameOutcome.tonAmount, forKey: "goa")
        } else {
            encoder.encodeNil(forKey: "gos")
            encoder.encodeNil(forKey: "goa")
        }
    }
    
    public static func ==(lhs: TelegramMediaDice, rhs: TelegramMediaDice) -> Bool {
        return lhs.isEqual(to: rhs)
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaDice {
            if self.emoji != other.emoji {
                return false
            }
            if self.tonAmount != other.tonAmount {
                return false
            }
            if self.value != other.value {
                return false
            }
            if self.gameOutcome != other.gameOutcome {
                return false
            }
            return true
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
