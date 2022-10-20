import Foundation
import Postbox

public struct PremiumPromoConfiguration: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case status
        case statusEntities
        case videos
        case premiumProductOptions
    }
    
    private struct DictionaryPair: Codable {
        var key: String
        var value: TelegramMediaFile
        
        init(_ key: String, value: TelegramMediaFile) {
            self.key = key
            self.value = value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.key = try container.decode(String.self, forKey: "k")
            self.value = try container.decode(TelegramMediaFile.self, forKey: "v")
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.key, forKey: "k")
            try container.encode(self.value, forKey: "v")
        }
    }
    
    public struct PremiumProductOption: Codable, Equatable {
        public let months: Int32
        public let currency: String
        public let amount: Int64
        public let botUrl: String
        public let storeProductId: String?
        
        public init(months: Int32, currency: String, amount: Int64, botUrl: String, storeProductId: String?) {
            self.months = months
            self.currency = currency
            self.amount = amount
            self.botUrl = botUrl
            self.storeProductId = storeProductId
        }
        
        public init(decoder: PostboxDecoder) {
            self.months = decoder.decodeInt32ForKey("months", orElse: 0)
            self.currency = decoder.decodeStringForKey("currency", orElse: "")
            self.amount = decoder.decodeInt64ForKey("amount", orElse: 0)
            self.botUrl = decoder.decodeStringForKey("botUrl", orElse: "")
            self.storeProductId = decoder.decodeOptionalStringForKey("storeProductId")
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt32(self.months, forKey: "months")
            encoder.encodeString(self.currency, forKey: "currency")
            encoder.encodeInt64(self.amount, forKey: "amount")
            encoder.encodeString(self.botUrl, forKey: "botUrl")
            if let storeProductId = self.storeProductId {
                encoder.encodeString(storeProductId, forKey: "storeProductId")
            } else {
                encoder.encodeNil(forKey: "storeProductId")
            }
        }
    }
    
    public var status: String
    public var statusEntities: [MessageTextEntity]
    public var videos: [String: TelegramMediaFile]
    public var premiumProductOptions: [PremiumProductOption]
    
    public static var defaultValue: PremiumPromoConfiguration {
        return PremiumPromoConfiguration(status: "", statusEntities: [], videos: [:], premiumProductOptions: [])
    }
    
    init(status: String, statusEntities: [MessageTextEntity], videos: [String: TelegramMediaFile], premiumProductOptions: [PremiumProductOption]) {
        self.status = status
        self.statusEntities = statusEntities
        self.videos = videos
        self.premiumProductOptions = premiumProductOptions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.status = try container.decode(String.self, forKey: .status)
        self.statusEntities = try container.decode([MessageTextEntity].self, forKey: .statusEntities)
        
        var videos: [String: TelegramMediaFile] = [:]
        let pairs = try container.decode([DictionaryPair].self, forKey: .videos)
        for pair in pairs {
            videos[pair.key] = pair.value
        }
        self.videos = videos
        
        self.premiumProductOptions = try container.decode([PremiumProductOption].self, forKey: .premiumProductOptions)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.status, forKey: .status)
        try container.encode(self.statusEntities, forKey: .statusEntities)
    
        var pairs: [DictionaryPair] = []
        for (key, file) in self.videos {
            pairs.append(DictionaryPair(key, value: file))
        }
        try container.encode(pairs, forKey: .videos)
        
        try container.encode(self.premiumProductOptions, forKey: .premiumProductOptions)
    }
}
