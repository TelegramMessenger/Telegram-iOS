import Foundation
import Postbox

public struct PremiumPromoConfiguration: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case status
        case currency
        case monthlyAmount
        case statusEntities
        case videos
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
    
    public var status: String
    public var statusEntities: [MessageTextEntity]
    public var videos: [String: TelegramMediaFile]
    
    public var currency: String
    public var monthlyAmount: Int64
    
    public static var defaultValue: PremiumPromoConfiguration {
        return PremiumPromoConfiguration(status: "", statusEntities: [], videos: [:], currency: "", monthlyAmount: 0)
    }
    
    init(status: String, statusEntities: [MessageTextEntity], videos: [String: TelegramMediaFile], currency: String, monthlyAmount: Int64) {
        self.status = status
        self.currency = currency
        self.monthlyAmount = monthlyAmount
        self.statusEntities = statusEntities
        self.videos = videos
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
        
        self.currency = try container.decode(String.self, forKey: .currency)
        self.monthlyAmount = try container.decode(Int64.self, forKey: .monthlyAmount)

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.status, forKey: .status)
        try container.encode(self.statusEntities, forKey: .statusEntities)
        try container.encode(self.currency, forKey: .currency)
        try container.encode(self.monthlyAmount, forKey: .monthlyAmount)
        
        var pairs: [DictionaryPair] = []
        for (key, file) in self.videos {
            pairs.append(DictionaryPair(key, value: file))
        }
        try container.encode(pairs, forKey: .videos)
    }
}
