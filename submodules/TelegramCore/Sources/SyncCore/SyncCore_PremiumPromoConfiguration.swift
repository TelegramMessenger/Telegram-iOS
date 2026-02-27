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
        enum CodingKeys: String, CodingKey {
            case isCurrent
            case months
            case currency
            case amount
            case botUrl
            case transactionId
            case availableForUpgrade
            case storeProductId
        }
        
        public let isCurrent: Bool
        public let months: Int32
        public let currency: String
        public let amount: Int64
        public let botUrl: String
        public let transactionId: String?
        public let availableForUpgrade: Bool
        public let storeProductId: String?
        
        public init(isCurrent: Bool, months: Int32, currency: String, amount: Int64, botUrl: String, transactionId: String?, availableForUpgrade: Bool, storeProductId: String?) {
            self.isCurrent = isCurrent
            self.months = months
            self.currency = currency
            self.amount = amount
            self.botUrl = botUrl
            self.transactionId = transactionId
            self.availableForUpgrade = availableForUpgrade
            self.storeProductId = storeProductId
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.isCurrent = try container.decode(Bool.self, forKey: .isCurrent)
            self.months = try container.decode(Int32.self, forKey: .months)
            self.currency = try container.decode(String.self, forKey: .currency)
            self.amount = try container.decode(Int64.self, forKey: .amount)
            self.botUrl = try container.decode(String.self, forKey: .botUrl)
            self.transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId)
            self.availableForUpgrade = try container.decode(Bool.self, forKey: .availableForUpgrade)
            self.storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.isCurrent, forKey: .isCurrent)
            try container.encode(self.months, forKey: .months)
            try container.encode(self.currency, forKey: .currency)
            try container.encode(self.amount, forKey: .amount)
            try container.encode(self.botUrl, forKey: .botUrl)
            try container.encodeIfPresent(self.transactionId, forKey: .transactionId)
            try container.encode(self.availableForUpgrade, forKey: .availableForUpgrade)
            try container.encodeIfPresent(self.storeProductId, forKey: .storeProductId)
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
