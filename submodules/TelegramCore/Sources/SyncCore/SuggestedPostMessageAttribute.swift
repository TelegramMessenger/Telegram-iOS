import Foundation
import Postbox
import TelegramApi

public final class SuggestedPostMessageAttribute: Equatable, MessageAttribute {
    public enum State: Int32 {
        case accepted = 0
        case rejected = 1
    }

    public let amount: CurrencyAmount?
    public let timestamp: Int32?
    public let state: State?
    
    public init(amount: CurrencyAmount?, timestamp: Int32?, state: State?) {
        self.amount = amount
        self.timestamp = timestamp
        self.state = state
    }
    
    required public init(decoder: PostboxDecoder) {
        self.amount = decoder.decodeCodable(CurrencyAmount.self, forKey: "amt")
        self.timestamp = decoder.decodeOptionalInt32ForKey("ts")
        self.state = decoder.decodeOptionalInt32ForKey("st").flatMap(State.init(rawValue:))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let amount = self.amount {
            encoder.encodeCodable(amount, forKey: "amt")
        } else {
            encoder.encodeNil(forKey: "amt")
        }
        if let timestamp = self.timestamp {
            encoder.encodeInt32(timestamp, forKey: "ts")
        } else {
            encoder.encodeNil(forKey: "ts")
        }
        if let state = self.state {
            encoder.encodeInt32(state.rawValue, forKey: "st")
        } else {
            encoder.encodeNil(forKey: "st")
        }
    }
    
    public static func ==(lhs: SuggestedPostMessageAttribute, rhs: SuggestedPostMessageAttribute) -> Bool {
        if lhs.amount != rhs.amount {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        return true
    }
}

extension SuggestedPostMessageAttribute {
    convenience init(apiSuggestedPost: Api.SuggestedPost) {
        switch apiSuggestedPost {
        case let .suggestedPost(flags, starsAmount, scheduleDate):
            var state: State?
            if (flags & (1 << 1)) != 0 {
                state = .accepted
            } else if (flags & (1 << 2)) != 0 {
                state = .rejected
            }
            self.init(amount: starsAmount.flatMap(CurrencyAmount.init(apiAmount:)), timestamp: scheduleDate, state: state)
        }
    }
    
    func apiSuggestedPost(fixMinTime: Int32?) -> Api.SuggestedPost {
        var flags: Int32 = 0
        if let state = self.state {
            switch state {
            case .accepted:
                flags |= 1 << 1
            case .rejected:
                flags |= 1 << 2
            }
        }
        var timestamp = self.timestamp
        if let timestampValue = timestamp, let fixMinTime {
            if timestampValue < fixMinTime {
                timestamp = fixMinTime
            }
        }
        
        if timestamp != nil {
            flags |= 1 << 0
        }
        var price: Api.StarsAmount?
        if let amount = self.amount {
            flags |= 1 << 3
            price = amount.apiAmount
        }
        return .suggestedPost(flags: flags, price: price, scheduleDate: timestamp)
    }
}

public final class PublishedSuggestedPostMessageAttribute: Equatable, MessageAttribute {
    public let currency: CurrencyAmount.Currency
    
    public init(currency: CurrencyAmount.Currency) {
        self.currency = currency
    }
    
    public init(decoder: PostboxDecoder) {
        self.currency = CurrencyAmount.Currency(rawValue: decoder.decodeInt32ForKey("c", orElse: 0)) ?? .stars
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.currency.rawValue, forKey: "c")
    }
    
    public static func == (lhs: PublishedSuggestedPostMessageAttribute, rhs: PublishedSuggestedPostMessageAttribute) -> Bool {
        if lhs.currency != rhs.currency {
            return false
        }
        return true
    }
}
