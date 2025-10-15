import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public final class StarGiftsList: Codable, Equatable {
    public let items: [StarGift]
    public let hashValue: Int32

    public init(items: [StarGift], hashValue: Int32) {
        self.items = items
        self.hashValue = hashValue
    }

    public static func ==(lhs: StarGiftsList, rhs: StarGiftsList) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.hashValue != rhs.hashValue {
            return false
        }
        return true
    }
}

public enum StarGift: Equatable, Codable, PostboxCoding {
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }
    
    public struct Gift: Equatable, Codable, PostboxCoding {
        public struct Flags: OptionSet {
            public var rawValue: Int32
            
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public static let isBirthdayGift = Flags(rawValue: 1 << 0)
            public static let requiresPremium = Flags(rawValue: 1 << 1)
            public static let peerColorAvailable = Flags(rawValue: 1 << 2)
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case file
            case price
            case convertStars
            case availability
            case soldOut
            case flags
            case upgradeStars
            case releasedBy
            case perUserLimit
            case lockedUntilDate
        }
        
        public struct Availability: Equatable, Codable, PostboxCoding {
            enum CodingKeys: String, CodingKey {
                case remains
                case total
                case resale
                case minResaleStars
            }

            public let remains: Int32
            public let total: Int32
            public let resale: Int64
            public let minResaleStars: Int64?
            
            public init(remains: Int32, total: Int32, resale: Int64, minResaleStars: Int64?) {
                self.remains = remains
                self.total = total
                self.resale = resale
                self.minResaleStars = minResaleStars
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.remains = try container.decode(Int32.self, forKey: .remains)
                self.total = try container.decode(Int32.self, forKey: .total)
                self.resale = (try? container.decodeIfPresent(Int64.self, forKey: .resale)) ?? 0
                self.minResaleStars = try? container.decodeIfPresent(Int64.self, forKey: .minResaleStars)
            }
            
            public init(decoder: PostboxDecoder) {
                self.remains = decoder.decodeInt32ForKey(CodingKeys.remains.rawValue, orElse: 0)
                self.total = decoder.decodeInt32ForKey(CodingKeys.total.rawValue, orElse: 0)
                self.resale = decoder.decodeInt64ForKey(CodingKeys.resale.rawValue, orElse: 0)
                self.minResaleStars = decoder.decodeInt64ForKey(CodingKeys.minResaleStars.rawValue, orElse: 0)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(self.remains, forKey: .remains)
                try container.encode(self.total, forKey: .total)
                try container.encode(self.resale, forKey: .resale)
                try container.encodeIfPresent(self.minResaleStars, forKey: .minResaleStars)
            }
            
            public func encode(_ encoder: PostboxEncoder) {
                encoder.encodeInt32(self.remains, forKey: CodingKeys.remains.rawValue)
                encoder.encodeInt32(self.total, forKey: CodingKeys.total.rawValue)
                encoder.encodeInt64(self.resale, forKey: CodingKeys.resale.rawValue)
                if let minResaleStars = self.minResaleStars {
                    encoder.encodeInt64(minResaleStars, forKey: CodingKeys.minResaleStars.rawValue)
                } else {
                    encoder.encodeNil(forKey: CodingKeys.minResaleStars.rawValue)
                }
            }
        }
        
        public struct SoldOut: Equatable, Codable, PostboxCoding {
            enum CodingKeys: String, CodingKey {
                case firstSale
                case lastSale
            }

            public let firstSale: Int32
            public let lastSale: Int32
            
            public init(firstSale: Int32, lastSale: Int32) {
                self.firstSale = firstSale
                self.lastSale = lastSale
            }
            
            public init(decoder: PostboxDecoder) {
                self.firstSale = decoder.decodeInt32ForKey(CodingKeys.firstSale.rawValue, orElse: 0)
                self.lastSale = decoder.decodeInt32ForKey(CodingKeys.lastSale.rawValue, orElse: 0)
            }
            
            public func encode(_ encoder: PostboxEncoder) {
                encoder.encodeInt32(self.firstSale, forKey: CodingKeys.firstSale.rawValue)
                encoder.encodeInt32(self.lastSale, forKey: CodingKeys.lastSale.rawValue)
            }
        }
        
        public struct PerUserLimit: Equatable, Codable, PostboxCoding {
            enum CodingKeys: String, CodingKey {
                case total
                case remains
            }

            public let total: Int32
            public let remains: Int32
            
            public init(total: Int32, remains: Int32) {
                self.total = total
                self.remains = remains
            }
            
            public init(decoder: PostboxDecoder) {
                self.total = decoder.decodeInt32ForKey(CodingKeys.total.rawValue, orElse: 0)
                self.remains = decoder.decodeInt32ForKey(CodingKeys.remains.rawValue, orElse: 0)
            }
            
            public func encode(_ encoder: PostboxEncoder) {
                encoder.encodeInt32(self.total, forKey: CodingKeys.total.rawValue)
                encoder.encodeInt32(self.remains, forKey: CodingKeys.remains.rawValue)
            }
        }
        
        public enum DecodingError: Error {
            case generic
        }
        
        public let id: Int64
        public let title: String?
        public let file: TelegramMediaFile
        public let price: Int64
        public let convertStars: Int64
        public let availability: Availability?
        public let soldOut: SoldOut?
        public let flags: Flags
        public let upgradeStars: Int64?
        public let releasedBy: EnginePeer.Id?
        public let perUserLimit: PerUserLimit?
        public let lockedUntilDate: Int32?
        
        public init(id: Int64, title: String?, file: TelegramMediaFile, price: Int64, convertStars: Int64, availability: Availability?, soldOut: SoldOut?, flags: Flags, upgradeStars: Int64?, releasedBy: EnginePeer.Id?, perUserLimit: PerUserLimit?, lockedUntilDate: Int32?) {
            self.id = id
            self.title = title
            self.file = file
            self.price = price
            self.convertStars = convertStars
            self.availability = availability
            self.soldOut = soldOut
            self.flags = flags
            self.upgradeStars = upgradeStars
            self.releasedBy = releasedBy
            self.perUserLimit = perUserLimit
            self.lockedUntilDate = lockedUntilDate
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(Int64.self, forKey: .id)
            self.title = try container.decodeIfPresent(String.self, forKey: .title)
            
            if let fileData = try container.decodeIfPresent(Data.self, forKey: .file), let file = PostboxDecoder(buffer: MemoryBuffer(data: fileData)).decodeRootObject() as? TelegramMediaFile {
                self.file = file
            } else {
                throw DecodingError.generic
            }
            
            self.price = try container.decode(Int64.self, forKey: .price)
            self.convertStars = try container.decodeIfPresent(Int64.self, forKey: .convertStars) ?? 0
            self.availability = try container.decodeIfPresent(Availability.self, forKey: .availability)
            self.soldOut = try container.decodeIfPresent(SoldOut.self, forKey: .soldOut)
            self.flags = Flags(rawValue: try container .decodeIfPresent(Int32.self, forKey: .flags) ?? 0)
            self.upgradeStars = try container.decodeIfPresent(Int64.self, forKey: .upgradeStars)
            self.releasedBy = try container.decodeIfPresent(EnginePeer.Id.self, forKey: .releasedBy)
            self.perUserLimit = try container.decodeIfPresent(PerUserLimit.self, forKey: .perUserLimit)
            self.lockedUntilDate = try container.decodeIfPresent(Int32.self, forKey: .lockedUntilDate)
        }
        
        public init(decoder: PostboxDecoder) {
            self.id = decoder.decodeInt64ForKey(CodingKeys.id.rawValue, orElse: 0)
            self.title = decoder.decodeOptionalStringForKey(CodingKeys.title.rawValue)
            self.file = decoder.decodeObjectForKey(CodingKeys.file.rawValue) as! TelegramMediaFile
            self.price = decoder.decodeInt64ForKey(CodingKeys.price.rawValue, orElse: 0)
            self.convertStars = decoder.decodeInt64ForKey(CodingKeys.convertStars.rawValue, orElse: 0)
            self.availability = decoder.decodeObjectForKey(CodingKeys.availability.rawValue, decoder: { StarGift.Gift.Availability(decoder: $0) }) as? StarGift.Gift.Availability
            self.soldOut = decoder.decodeObjectForKey(CodingKeys.soldOut.rawValue, decoder: { StarGift.Gift.SoldOut(decoder: $0) }) as? StarGift.Gift.SoldOut
            self.flags = Flags(rawValue: decoder.decodeInt32ForKey(CodingKeys.flags.rawValue, orElse: 0))
            self.upgradeStars = decoder.decodeOptionalInt64ForKey(CodingKeys.upgradeStars.rawValue)
            self.releasedBy = decoder.decodeOptionalInt64ForKey(CodingKeys.releasedBy.rawValue).flatMap { EnginePeer.Id($0) }
            self.perUserLimit = decoder.decodeObjectForKey(CodingKeys.perUserLimit.rawValue, decoder: { StarGift.Gift.PerUserLimit(decoder: $0) }) as? StarGift.Gift.PerUserLimit
            self.lockedUntilDate = decoder.decodeOptionalInt32ForKey(CodingKeys.lockedUntilDate.rawValue)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
            try container.encodeIfPresent(self.title, forKey: .title)
        
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(self.file)
            let fileData = encoder.makeData()
            try container.encode(fileData, forKey: .file)
            
            try container.encode(self.price, forKey: .price)
            try container.encode(self.convertStars, forKey: .convertStars)
            try container.encodeIfPresent(self.availability, forKey: .availability)
            try container.encodeIfPresent(self.soldOut, forKey: .soldOut)
            try container.encode(self.flags.rawValue, forKey: .flags)
            try container.encodeIfPresent(self.upgradeStars, forKey: .upgradeStars)
            try container.encodeIfPresent(self.releasedBy, forKey: .releasedBy)
            try container.encodeIfPresent(self.perUserLimit, forKey: .perUserLimit)
            try container.encodeIfPresent(self.lockedUntilDate, forKey: .lockedUntilDate)
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.id, forKey: CodingKeys.id.rawValue)
            if let title = self.title {
                encoder.encodeString(title, forKey: CodingKeys.title.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.title.rawValue)
            }
            encoder.encodeObject(self.file, forKey: CodingKeys.file.rawValue)
            encoder.encodeInt64(self.price, forKey: CodingKeys.price.rawValue)
            encoder.encodeInt64(self.convertStars, forKey: CodingKeys.convertStars.rawValue)
            if let availability = self.availability {
                encoder.encodeObject(availability, forKey: CodingKeys.availability.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.availability.rawValue)
            }
            if let soldOut = self.soldOut {
                encoder.encodeObject(soldOut, forKey: CodingKeys.soldOut.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.soldOut.rawValue)
            }
            encoder.encodeInt32(self.flags.rawValue, forKey: CodingKeys.flags.rawValue)
            if let upgradeStars = self.upgradeStars {
                encoder.encodeInt64(upgradeStars, forKey: CodingKeys.upgradeStars.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.upgradeStars.rawValue)
            }
            if let releasedBy = self.releasedBy {
                encoder.encodeInt64(releasedBy.toInt64(), forKey: CodingKeys.releasedBy.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.releasedBy.rawValue)
            }
            if let perUserLimit = self.perUserLimit {
                encoder.encodeObject(perUserLimit, forKey: CodingKeys.perUserLimit.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.perUserLimit.rawValue)
            }
            if let lockedUntilDate = self.lockedUntilDate {
                encoder.encodeInt32(lockedUntilDate, forKey: CodingKeys.lockedUntilDate.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.lockedUntilDate.rawValue)
            }
        }
    }
    
    public struct UniqueGift: Equatable, Codable, PostboxCoding {
        enum CodingKeys: String, CodingKey {
            case id
            case giftId
            case title
            case number
            case slug
            case ownerPeerId
            case ownerName
            case ownerAddress
            case attributes
            case availability
            case giftAddress
            case resellStars
            case resellAmounts
            case resellForTonOnly
            case releasedBy
            case valueAmount
            case valueCurrency
            case flags
            case themePeerId
            case peerColor
            case hostPeerId
        }
        
        public struct Flags: OptionSet {
            public var rawValue: Int32
            
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public static let isThemeAvailable = Flags(rawValue: 1 << 0)
        }
        
        public enum Attribute: Equatable, Codable, PostboxCoding {
            enum CodingKeys: String, CodingKey {
                case type
                case name
                case file
                case id
                case innerColor
                case outerColor
                case patternColor
                case textColor
                case sendPeerId
                case recipientPeerId
                case date
                case text
                case entities
                case rarity
            }
            
            public enum AttributeType {
                case model
                case pattern
                case backdrop
                case originalInfo
            }
            
            case model(name: String, file: TelegramMediaFile, rarity: Int32)
            case pattern(name: String, file: TelegramMediaFile, rarity: Int32)
            case backdrop(name: String, id: Int32, innerColor: Int32, outerColor: Int32, patternColor: Int32, textColor: Int32, rarity: Int32)
            case originalInfo(senderPeerId: EnginePeer.Id?, recipientPeerId: EnginePeer.Id, date: Int32, text: String?, entities: [MessageTextEntity]?)
            
            public var attributeType: AttributeType {
                switch self {
                case .model:
                    return .model
                case .pattern:
                    return .pattern
                case .backdrop:
                    return .backdrop
                case .originalInfo:
                    return .originalInfo
                }
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                let type = try container.decode(Int32.self, forKey: .type)
                switch type {
                case 0:
                    self = .model(
                        name: try container.decode(String.self, forKey: .name),
                        file: try container.decode(TelegramMediaFile.self, forKey: .file),
                        rarity: try container.decode(Int32.self, forKey: .rarity)
                    )
                case 1:
                    self = .pattern(
                        name: try container.decode(String.self, forKey: .name),
                        file: try container.decode(TelegramMediaFile.self, forKey: .file),
                        rarity: try container.decode(Int32.self, forKey: .rarity)
                    )
                case 2:
                    self = .backdrop(
                        name: try container.decode(String.self, forKey: .name),
                        id: try container.decodeIfPresent(Int32.self, forKey: .id) ?? 0,
                        innerColor: try container.decode(Int32.self, forKey: .innerColor),
                        outerColor: try container.decode(Int32.self, forKey: .outerColor),
                        patternColor: try container.decode(Int32.self, forKey: .patternColor),
                        textColor: try container.decode(Int32.self, forKey: .textColor),
                        rarity: try container.decode(Int32.self, forKey: .rarity)
                    )
                case 3:
                    self = .originalInfo(
                        senderPeerId: try container.decodeIfPresent(Int64.self, forKey: .sendPeerId).flatMap { EnginePeer.Id($0) },
                        recipientPeerId: EnginePeer.Id(try container.decode(Int64.self, forKey: .recipientPeerId)),
                        date: try container.decode(Int32.self, forKey: .date),
                        text: try container.decodeIfPresent(String.self, forKey: .text),
                        entities: try container.decodeIfPresent([MessageTextEntity].self, forKey: .entities)
                    )
                default:
                    throw DecodingError.generic
                }
            }
            
            public init(decoder: PostboxDecoder) {
                let type = decoder.decodeInt32ForKey(CodingKeys.type.rawValue, orElse: 0)
                
                switch type {
                case 0:
                    self = .model(
                        name: decoder.decodeStringForKey(CodingKeys.name.rawValue, orElse: ""),
                        file: decoder.decodeObjectForKey(CodingKeys.file.rawValue) as! TelegramMediaFile,
                        rarity: decoder.decodeInt32ForKey(CodingKeys.rarity.rawValue, orElse: 0)
                    )
                case 1:
                    self = .pattern(
                        name: decoder.decodeStringForKey(CodingKeys.name.rawValue, orElse: ""),
                        file: decoder.decodeObjectForKey(CodingKeys.file.rawValue) as! TelegramMediaFile,
                        rarity: decoder.decodeInt32ForKey(CodingKeys.rarity.rawValue, orElse: 0)
                    )
                case 2:
                    self = .backdrop(
                        name: decoder.decodeStringForKey(CodingKeys.name.rawValue, orElse: ""),
                        id: decoder.decodeInt32ForKey(CodingKeys.id.rawValue, orElse: 0),
                        innerColor: decoder.decodeInt32ForKey(CodingKeys.innerColor.rawValue, orElse: 0),
                        outerColor: decoder.decodeInt32ForKey(CodingKeys.outerColor.rawValue, orElse: 0),
                        patternColor: decoder.decodeInt32ForKey(CodingKeys.patternColor.rawValue, orElse: 0),
                        textColor: decoder.decodeInt32ForKey(CodingKeys.textColor.rawValue, orElse: 0),
                        rarity: decoder.decodeInt32ForKey(CodingKeys.rarity.rawValue, orElse: 0)
                    )
                case 3:
                    self = .originalInfo(
                        senderPeerId: decoder.decodeOptionalInt64ForKey(CodingKeys.sendPeerId.rawValue).flatMap { EnginePeer.Id($0) },
                        recipientPeerId: EnginePeer.Id(decoder.decodeInt64ForKey(CodingKeys.recipientPeerId.rawValue, orElse: 0)),
                        date: decoder.decodeInt32ForKey(CodingKeys.date.rawValue, orElse: 0),
                        text: decoder.decodeOptionalStringForKey(CodingKeys.text.rawValue),
                        entities: decoder.decodeObjectArrayWithDecoderForKey(CodingKeys.entities.rawValue)
                    )
                default:
                    fatalError()
                }
            }
        
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                switch self {
                case let .model(name, file, rarity):
                    try container.encode(Int32(0), forKey: .type)
                    try container.encode(name, forKey: .name)
                    try container.encode(file, forKey: .file)
                    try container.encode(rarity, forKey: .rarity)
                case let .pattern(name, file, rarity):
                    try container.encode(Int32(1), forKey: .type)
                    try container.encode(name, forKey: .name)
                    try container.encode(file, forKey: .file)
                    try container.encode(rarity, forKey: .rarity)
                case let .backdrop(name, id, innerColor, outerColor, patternColor, textColor, rarity):
                    try container.encode(Int32(2), forKey: .type)
                    try container.encode(name, forKey: .name)
                    try container.encode(id, forKey: .id)
                    try container.encode(innerColor, forKey: .innerColor)
                    try container.encode(outerColor, forKey: .outerColor)
                    try container.encode(patternColor, forKey: .patternColor)
                    try container.encode(textColor, forKey: .textColor)
                    try container.encode(rarity, forKey: .rarity)
                case let .originalInfo(senderPeerId, recipientPeerId, date, text, entities):
                    try container.encode(Int32(3), forKey: .type)
                    try container.encodeIfPresent(senderPeerId?.toInt64(), forKey: .sendPeerId)
                    try container.encode(recipientPeerId.toInt64(), forKey: .recipientPeerId)
                    try container.encode(date, forKey: .date)
                    try container.encodeIfPresent(text, forKey: .text)
                    try container.encodeIfPresent(entities, forKey: .entities)
                }
            }
            
            public func encode(_ encoder: PostboxEncoder) {
                switch self {
                case let .model(name, file, rarity):
                    encoder.encodeInt32(0, forKey: CodingKeys.type.rawValue)
                    encoder.encodeString(name, forKey: CodingKeys.name.rawValue)
                    encoder.encodeObject(file, forKey: CodingKeys.file.rawValue)
                    encoder.encodeInt32(rarity, forKey: CodingKeys.rarity.rawValue)
                case let .pattern(name, file, rarity):
                    encoder.encodeInt32(1, forKey: CodingKeys.type.rawValue)
                    encoder.encodeString(name, forKey: CodingKeys.name.rawValue)
                    encoder.encodeObject(file, forKey: CodingKeys.file.rawValue)
                    encoder.encodeInt32(rarity, forKey: CodingKeys.rarity.rawValue)
                case let .backdrop(name, id, innerColor, outerColor, patternColor, textColor, rarity):
                    encoder.encodeInt32(2, forKey: CodingKeys.type.rawValue)
                    encoder.encodeString(name, forKey: CodingKeys.name.rawValue)
                    encoder.encodeInt32(id, forKey: CodingKeys.id.rawValue)
                    encoder.encodeInt32(innerColor, forKey: CodingKeys.innerColor.rawValue)
                    encoder.encodeInt32(outerColor, forKey: CodingKeys.outerColor.rawValue)
                    encoder.encodeInt32(patternColor, forKey: CodingKeys.patternColor.rawValue)
                    encoder.encodeInt32(textColor, forKey: CodingKeys.textColor.rawValue)
                    encoder.encodeInt32(rarity, forKey: CodingKeys.rarity.rawValue)
                case let .originalInfo(senderPeerId, recipientPeerId, date, text, entities):
                    encoder.encodeInt32(3, forKey: CodingKeys.type.rawValue)
                    if let senderPeerId {
                        encoder.encodeInt64(senderPeerId.toInt64(), forKey: CodingKeys.sendPeerId.rawValue)
                    } else {
                        encoder.encodeNil(forKey: CodingKeys.sendPeerId.rawValue)
                    }
                    encoder.encodeInt64(recipientPeerId.toInt64(), forKey: CodingKeys.recipientPeerId.rawValue)
                    encoder.encodeInt32(date, forKey: CodingKeys.date.rawValue)
                    if let text {
                        encoder.encodeString(text, forKey: CodingKeys.text.rawValue)
                        if let entities {
                            encoder.encodeObjectArray(entities, forKey: CodingKeys.entities.rawValue)
                        } else {
                            encoder.encodeNil(forKey: CodingKeys.entities.rawValue)
                        }
                    } else {
                        encoder.encodeNil(forKey: CodingKeys.text.rawValue)
                        encoder.encodeNil(forKey: CodingKeys.entities.rawValue)
                    }
                }
            }
        }
        
        public struct Availability: Equatable, Codable, PostboxCoding {
            enum CodingKeys: String, CodingKey {
                case issued
                case total
            }

            public let issued: Int32
            public let total: Int32
            
            public init(issued: Int32, total: Int32) {
                self.issued = issued
                self.total = total
            }
            
            public init(decoder: PostboxDecoder) {
                self.issued = decoder.decodeInt32ForKey(CodingKeys.issued.rawValue, orElse: 0)
                self.total = decoder.decodeInt32ForKey(CodingKeys.total.rawValue, orElse: 0)
            }
            
            public func encode(_ encoder: PostboxEncoder) {
                encoder.encodeInt32(self.issued, forKey: CodingKeys.issued.rawValue)
                encoder.encodeInt32(self.total, forKey: CodingKeys.total.rawValue)
            }
        }
        
        public enum Owner: Equatable {
            case peerId(EnginePeer.Id)
            case name(String)
            case address(String)
            
            public var peerId: EnginePeer.Id? {
                if case let .peerId(peerId) = self {
                    return peerId
                }
                return nil
            }
        }
        
        public struct ValueInfo: Equatable {
            public let isLastSaleOnFragment: Bool
            public let valueIsAverage: Bool
            public let value: Int64
            public let currency: String
            public let initialSaleDate: Int32
            public let initialSaleStars: Int64
            public let initialSalePrice: Int64
            public let lastSaleDate: Int32?
            public let lastSalePrice: Int64?
            public let floorPrice: Int64?
            public let averagePrice: Int64?
            public let listedCount: Int32?
            public let fragmentListedCount: Int32?
            public let fragmentListedUrl: String?
        }
                
        public enum DecodingError: Error {
            case generic
        }
        
        public let id: Int64
        public let giftId: Int64
        public let title: String
        public let number: Int32
        public let slug: String
        public let owner: Owner
        public let attributes: [Attribute]
        public let availability: Availability
        public let giftAddress: String?
        public let resellAmounts: [CurrencyAmount]?
        public let resellForTonOnly: Bool
        public let releasedBy: EnginePeer.Id?
        public let valueAmount: Int64?
        public let valueCurrency: String?
        public let flags: Flags
        public let themePeerId: EnginePeer.Id?
        public let peerColor: PeerCollectibleColor?
        public let hostPeerId: EnginePeer.Id?
        
        public init(id: Int64, giftId: Int64, title: String, number: Int32, slug: String, owner: Owner, attributes: [Attribute], availability: Availability, giftAddress: String?, resellAmounts: [CurrencyAmount]?, resellForTonOnly: Bool, releasedBy: EnginePeer.Id?, valueAmount: Int64?, valueCurrency: String?, flags: Flags, themePeerId: EnginePeer.Id?, peerColor: PeerCollectibleColor?, hostPeerId: EnginePeer.Id?) {
            self.id = id
            self.giftId = giftId
            self.title = title
            self.number = number
            self.slug = slug
            self.owner = owner
            self.attributes = attributes
            self.availability = availability
            self.giftAddress = giftAddress
            self.resellAmounts = resellAmounts
            self.resellForTonOnly = resellForTonOnly
            self.releasedBy = releasedBy
            self.valueAmount = valueAmount
            self.valueCurrency = valueCurrency
            self.flags = flags
            self.themePeerId = themePeerId
            self.peerColor = peerColor
            self.hostPeerId = hostPeerId
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(Int64.self, forKey: .id)
            self.giftId = try container.decode(Int64.self, forKey: .giftId)
            self.title = try container.decode(String.self, forKey: .title)
            self.number = try container.decode(Int32.self, forKey: .number)
            self.slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
            if let ownerId = try container.decodeIfPresent(Int64.self, forKey: .ownerPeerId) {
                self.owner = .peerId(EnginePeer.Id(ownerId))
            } else if let ownerAddress = try container.decodeIfPresent(String.self, forKey: .ownerAddress) {
                self.owner = .address(ownerAddress)
            } else if let ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName) {
                self.owner = .name(ownerName)
            } else {
                self.owner = .name("Unknown")
            }
            self.attributes = try container.decode([UniqueGift.Attribute].self, forKey: .attributes)
            self.availability = try container.decode(UniqueGift.Availability.self, forKey: .availability)
            self.giftAddress = try container.decodeIfPresent(String.self, forKey: .giftAddress)
            if let resellAmounts = try container.decodeIfPresent([CurrencyAmount].self, forKey: .resellAmounts) {
                self.resellAmounts = resellAmounts
            } else if let resellStars = try container.decodeIfPresent(Int64.self, forKey: .resellStars) {
                self.resellAmounts = [CurrencyAmount(amount: StarsAmount(value: resellStars, nanos: 0), currency: .stars)]
            } else {
                self.resellAmounts = []
            }
            self.resellForTonOnly = try container.decodeIfPresent(Bool.self, forKey: .resellForTonOnly) ?? false
            self.releasedBy = try container.decodeIfPresent(EnginePeer.Id.self, forKey: .releasedBy)
            self.valueAmount = try container.decodeIfPresent(Int64.self, forKey: .valueAmount)
            self.valueCurrency = try container.decodeIfPresent(String.self, forKey: .valueCurrency)
            self.flags = try container.decodeIfPresent(Int32.self, forKey: .flags).flatMap { Flags(rawValue: $0) } ?? []
            self.themePeerId = try container.decodeIfPresent(Int64.self, forKey: .themePeerId).flatMap { EnginePeer.Id($0) }
            self.peerColor = try container.decodeIfPresent(PeerCollectibleColor.self, forKey: .peerColor)
            self.hostPeerId = try container.decodeIfPresent(Int64.self, forKey: .hostPeerId).flatMap { EnginePeer.Id($0) }
        }
        
        public init(decoder: PostboxDecoder) {
            self.id = decoder.decodeInt64ForKey(CodingKeys.id.rawValue, orElse: 0)
            self.giftId = decoder.decodeInt64ForKey(CodingKeys.giftId.rawValue, orElse: 0)
            self.title = decoder.decodeStringForKey(CodingKeys.title.rawValue, orElse: "")
            self.number = decoder.decodeInt32ForKey(CodingKeys.number.rawValue, orElse: 0)
            self.slug = decoder.decodeStringForKey(CodingKeys.slug.rawValue, orElse: "")
            if let ownerId = decoder.decodeOptionalInt64ForKey(CodingKeys.ownerPeerId.rawValue) {
                self.owner = .peerId(EnginePeer.Id(ownerId))
            } else if let ownerAddress = decoder.decodeOptionalStringForKey(CodingKeys.ownerAddress.rawValue) {
                self.owner = .address(ownerAddress)
            } else if let ownerName = decoder.decodeOptionalStringForKey(CodingKeys.ownerName.rawValue) {
                self.owner = .name(ownerName)
            } else {
                self.owner = .name("Unknown")
            }
            self.attributes = (try? decoder.decodeObjectArrayWithCustomDecoderForKey(CodingKeys.attributes.rawValue, decoder: { UniqueGift.Attribute(decoder: $0) })) ?? []
            self.availability = decoder.decodeObjectForKey(CodingKeys.availability.rawValue, decoder: { UniqueGift.Availability(decoder: $0) }) as! UniqueGift.Availability
            self.giftAddress = decoder.decodeOptionalStringForKey(CodingKeys.giftAddress.rawValue)
            if let resellAmounts = decoder.decodeCodable([CurrencyAmount].self, forKey: CodingKeys.resellAmounts.rawValue) {
                self.resellAmounts = resellAmounts
            } else if let resellStars = decoder.decodeOptionalInt64ForKey(CodingKeys.resellStars.rawValue) {
                self.resellAmounts = [CurrencyAmount(amount: StarsAmount(value: resellStars, nanos: 0), currency: .stars)]
            } else {
                self.resellAmounts = nil
            }
            self.resellForTonOnly = decoder.decodeBoolForKey(CodingKeys.resellForTonOnly.rawValue, orElse: false)
            self.releasedBy = decoder.decodeOptionalInt64ForKey(CodingKeys.releasedBy.rawValue).flatMap { EnginePeer.Id($0) }
            self.valueAmount = decoder.decodeOptionalInt64ForKey(CodingKeys.valueAmount.rawValue)
            self.valueCurrency = decoder.decodeOptionalStringForKey(CodingKeys.valueCurrency.rawValue)
            self.flags = decoder.decodeOptionalInt32ForKey(CodingKeys.flags.rawValue).flatMap { Flags(rawValue: $0) } ?? []
            self.themePeerId = decoder.decodeOptionalInt64ForKey(CodingKeys.themePeerId.rawValue).flatMap { EnginePeer.Id($0) }
            self.peerColor = decoder.decodeCodable(PeerCollectibleColor.self, forKey: CodingKeys.peerColor.rawValue)
            self.hostPeerId = decoder.decodeOptionalInt64ForKey(CodingKeys.hostPeerId.rawValue).flatMap { EnginePeer.Id($0) }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
            try container.encode(self.giftId, forKey: .giftId)
            try container.encode(self.title, forKey: .title)
            try container.encode(self.number, forKey: .number)
            try container.encode(self.slug, forKey: .slug)
            switch self.owner {
            case let .peerId(peerId):
                try container.encode(peerId.toInt64(), forKey: .ownerPeerId)
            case let .name(name):
                try container.encode(name, forKey: .ownerName)
            case let .address(address):
                try container.encode(address, forKey: .ownerAddress)
            }
            try container.encode(self.attributes, forKey: .attributes)
            try container.encode(self.availability, forKey: .availability)
            try container.encodeIfPresent(self.giftAddress, forKey: .giftAddress)
            try container.encodeIfPresent(self.resellAmounts, forKey: .resellAmounts)
            try container.encode(self.resellForTonOnly, forKey: .resellForTonOnly)
            try container.encodeIfPresent(self.releasedBy, forKey: .releasedBy)
            try container.encodeIfPresent(self.valueAmount, forKey: .valueAmount)
            try container.encodeIfPresent(self.valueCurrency, forKey: .valueCurrency)
            try container.encode(self.flags.rawValue, forKey: .flags)
            try container.encodeIfPresent(self.themePeerId?.toInt64(), forKey: .themePeerId)
            try container.encodeIfPresent(self.peerColor, forKey: .peerColor)
            try container.encodeIfPresent(self.hostPeerId?.toInt64(), forKey: .hostPeerId)
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.id, forKey: CodingKeys.id.rawValue)
            encoder.encodeInt64(self.giftId, forKey: CodingKeys.giftId.rawValue)
            encoder.encodeString(self.title, forKey: CodingKeys.title.rawValue)
            encoder.encodeInt32(self.number, forKey: CodingKeys.number.rawValue)
            encoder.encodeString(self.slug, forKey: CodingKeys.slug.rawValue)
            switch self.owner {
            case let .peerId(peerId):
                encoder.encodeInt64(peerId.toInt64(), forKey: CodingKeys.ownerPeerId.rawValue)
            case let .name(name):
                encoder.encodeString(name, forKey: CodingKeys.ownerName.rawValue)
            case let .address(address):
                encoder.encodeString(address, forKey: CodingKeys.ownerAddress.rawValue)
            }
            encoder.encodeObjectArray(self.attributes, forKey: CodingKeys.attributes.rawValue)
            encoder.encodeObject(self.availability, forKey: CodingKeys.availability.rawValue)
            if let giftAddress = self.giftAddress {
                encoder.encodeString(giftAddress, forKey: CodingKeys.giftAddress.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.giftAddress.rawValue)
            }
            if let resellAmounts = self.resellAmounts {
                encoder.encodeCodable(resellAmounts, forKey: CodingKeys.resellAmounts.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.resellAmounts.rawValue)
            }
            encoder.encodeBool(self.resellForTonOnly, forKey: CodingKeys.resellForTonOnly.rawValue)
            if let releasedBy = self.releasedBy {
                encoder.encodeInt64(releasedBy.toInt64(), forKey: CodingKeys.releasedBy.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.releasedBy.rawValue)
            }
            if let valueAmount = self.valueAmount, let valueCurrency = self.valueCurrency {
                encoder.encodeInt64(valueAmount, forKey: CodingKeys.valueAmount.rawValue)
                encoder.encodeString(valueCurrency, forKey: CodingKeys.valueCurrency.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.valueAmount.rawValue)
                encoder.encodeNil(forKey: CodingKeys.valueCurrency.rawValue)
            }
            encoder.encodeInt32(self.flags.rawValue, forKey: CodingKeys.flags.rawValue)
            if let themePeerId = self.themePeerId {
                encoder.encodeInt64(themePeerId.toInt64(), forKey: CodingKeys.themePeerId.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.themePeerId.rawValue)
            }
            if let peerColor = self.peerColor {
                encoder.encodeCodable(peerColor, forKey: CodingKeys.peerColor.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.peerColor.rawValue)
            }
            if let hostPeerId = self.hostPeerId {
                encoder.encodeInt64(hostPeerId.toInt64(), forKey: CodingKeys.hostPeerId.rawValue)
            } else {
                encoder.encodeNil(forKey: CodingKeys.hostPeerId.rawValue)
            }
        }
        
        public func withResellAmounts(_ resellAmounts: [CurrencyAmount]?) -> UniqueGift {
            return UniqueGift(
                id: self.id,
                giftId: self.giftId,
                title: self.title,
                number: self.number,
                slug: self.slug,
                owner: self.owner,
                attributes: self.attributes,
                availability: self.availability,
                giftAddress: self.giftAddress,
                resellAmounts: resellAmounts,
                resellForTonOnly: self.resellForTonOnly,
                releasedBy: self.releasedBy,
                valueAmount: self.valueAmount,
                valueCurrency: self.valueCurrency,
                flags: self.flags,
                themePeerId: self.themePeerId,
                peerColor: self.peerColor,
                hostPeerId: self.hostPeerId
            )
        }
        
        public func withResellForTonOnly(_ resellForTonOnly: Bool) -> UniqueGift {
            return UniqueGift(
                id: self.id,
                giftId: self.giftId,
                title: self.title,
                number: self.number,
                slug: self.slug,
                owner: self.owner,
                attributes: self.attributes,
                availability: self.availability,
                giftAddress: self.giftAddress,
                resellAmounts: self.resellAmounts,
                resellForTonOnly: resellForTonOnly,
                releasedBy: self.releasedBy,
                valueAmount: self.valueAmount,
                valueCurrency: self.valueCurrency,
                flags: self.flags,
                themePeerId: self.themePeerId,
                peerColor: self.peerColor,
                hostPeerId: self.hostPeerId
            )
        }
        
        public func withThemePeerId(_ themePeerId: EnginePeer.Id?) -> UniqueGift {
            return UniqueGift(
                id: self.id,
                giftId: self.giftId,
                title: self.title,
                number: self.number,
                slug: self.slug,
                owner: self.owner,
                attributes: self.attributes,
                availability: self.availability,
                giftAddress: self.giftAddress,
                resellAmounts: self.resellAmounts,
                resellForTonOnly: self.resellForTonOnly,
                releasedBy: self.releasedBy,
                valueAmount: self.valueAmount,
                valueCurrency: self.valueCurrency,
                flags: self.flags,
                themePeerId: themePeerId,
                peerColor: self.peerColor,
                hostPeerId: self.hostPeerId
            )
        }
        
        public func withAttributes(_ attributes: [Attribute]) -> UniqueGift {
            return UniqueGift(
                id: self.id,
                giftId: self.giftId,
                title: self.title,
                number: self.number,
                slug: self.slug,
                owner: self.owner,
                attributes: attributes,
                availability: self.availability,
                giftAddress: self.giftAddress,
                resellAmounts: self.resellAmounts,
                resellForTonOnly: self.resellForTonOnly,
                releasedBy: self.releasedBy,
                valueAmount: self.valueAmount,
                valueCurrency: self.valueCurrency,
                flags: self.flags,
                themePeerId: self.themePeerId,
                peerColor: self.peerColor,
                hostPeerId: self.hostPeerId
            )
        }
    }
    
    public enum DecodingError: Error {
        case generic
    }
    
    case generic(StarGift.Gift)
    case unique(StarGift.UniqueGift)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(Int32.self, forKey: .type)
        switch type {
        case 0:
            self = .generic(try container.decode(StarGift.Gift.self, forKey: .value))
        case 1:
            self = .unique(try container.decode(StarGift.UniqueGift.self, forKey: .value))
        default:
            throw DecodingError.generic
        }
    }
    
    public init(decoder: PostboxDecoder) {
        let type = decoder.decodeInt32ForKey(CodingKeys.type.rawValue, orElse: -1)
        
        switch type {
        case -1:
            self = .generic(Gift(decoder: decoder))
        case 0:
            self = .generic(decoder.decodeObjectForKey(CodingKeys.value.rawValue, decoder: { StarGift.Gift(decoder: $0) }) as! StarGift.Gift)
        case 1:
            self = .unique(decoder.decodeObjectForKey(CodingKeys.value.rawValue, decoder: { StarGift.UniqueGift(decoder: $0) }) as! StarGift.UniqueGift)
        default:
            fatalError()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .generic(gift):
            try container.encode(Int32(0), forKey: .type)
            try container.encode(gift, forKey: .value)
        case let .unique(uniqueGift):
            try container.encode(Int32(1), forKey: .type)
            try container.encode(uniqueGift, forKey: .value)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case let .generic(gift):
            encoder.encodeInt32(0, forKey: CodingKeys.type.rawValue)
            encoder.encodeObject(gift, forKey: CodingKeys.value.rawValue)
        case let .unique(uniqueGift):
            encoder.encodeInt32(1, forKey: CodingKeys.type.rawValue)
            encoder.encodeObject(uniqueGift, forKey: CodingKeys.value.rawValue)
        }
    }
}

public extension StarGift {
    var releasedBy: EnginePeer.Id? {
        switch self {
        case let .generic(gift):
            return gift.releasedBy
        case let .unique(gift):
            return gift.releasedBy
        }
    }
}

extension StarGift {
    init?(apiStarGift: Api.StarGift) {
        switch apiStarGift {
        case let .starGift(apiFlags, id, sticker, stars, availabilityRemains, availabilityTotal, availabilityResale, convertStars, firstSale, lastSale, upgradeStars, minResaleStars, title, releasedBy, perUserTotal, perUserRemains, lockedUntilDate):
            var flags = StarGift.Gift.Flags()
            if (apiFlags & (1 << 2)) != 0 {
                flags.insert(.isBirthdayGift)
            }
            if (apiFlags & (1 << 7)) != 0 {
                flags.insert(.requiresPremium)
            }
            if (apiFlags & (1 << 10)) != 0 {
                flags.insert(.peerColorAvailable)
            }
            
            var availability: StarGift.Gift.Availability?
            if let availabilityRemains, let availabilityTotal {
                availability = StarGift.Gift.Availability(
                    remains: availabilityRemains,
                    total: availabilityTotal,
                    resale: availabilityResale ?? 0,
                    minResaleStars: minResaleStars
                )
            }
            var soldOut: StarGift.Gift.SoldOut?
            if let firstSale, let lastSale {
                soldOut = StarGift.Gift.SoldOut(firstSale: firstSale, lastSale: lastSale)
            }
            var perUserLimit: StarGift.Gift.PerUserLimit?
            if let perUserTotal, let perUserRemains {
                perUserLimit = StarGift.Gift.PerUserLimit(total: perUserTotal, remains: perUserRemains)
            }
            guard let file = telegramMediaFileFromApiDocument(sticker, altDocuments: nil) else {
                return nil
            }
            self = .generic(StarGift.Gift(id: id, title: title, file: file, price: stars, convertStars: convertStars, availability: availability, soldOut: soldOut, flags: flags, upgradeStars: upgradeStars, releasedBy: releasedBy?.peerId, perUserLimit: perUserLimit, lockedUntilDate: lockedUntilDate))
        case let .starGiftUnique(apiFlags, id, giftId, title, slug, num, ownerPeerId, ownerName, ownerAddress, attributes, availabilityIssued, availabilityTotal, giftAddress, resellAmounts, releasedBy, valueAmount, valueCurrency, themePeer, peerColor, hostPeerId):
            let owner: StarGift.UniqueGift.Owner
            if let ownerAddress {
                owner = .address(ownerAddress)
            } else if let ownerId = ownerPeerId?.peerId {
                owner = .peerId(ownerId)
            } else if let ownerName {
                owner = .name(ownerName)
            } else {
                return nil
            }
            let resellAmounts = resellAmounts?.compactMap { CurrencyAmount(apiAmount: $0) }
            var flags = StarGift.UniqueGift.Flags()
            if (apiFlags & (1 << 9)) != 0 {
                flags.insert(.isThemeAvailable)
            }
            var peerCollectibleColor: PeerCollectibleColor?
            switch peerColor {
            case let .peerColorCollectible(_, collectibleId, giftEmojiId, backgroundEmojiId, accentColor, colors, darkAccentColor, darkColors):
                peerCollectibleColor = PeerCollectibleColor(
                    collectibleId: collectibleId,
                    giftEmojiFileId: giftEmojiId,
                    backgroundEmojiId: backgroundEmojiId,
                    accentColor: UInt32(bitPattern: accentColor),
                    colors: colors.map { UInt32(bitPattern: $0) },
                    darkAccentColor: darkAccentColor.flatMap { UInt32(bitPattern: $0) },
                    darkColors: darkColors.flatMap { $0.map { UInt32(bitPattern: $0) } }
                )
            default:
                break
            }
            
            self = .unique(StarGift.UniqueGift(id: id, giftId: giftId, title: title, number: num, slug: slug, owner: owner, attributes: attributes.compactMap { UniqueGift.Attribute(apiAttribute: $0) }, availability: UniqueGift.Availability(issued: availabilityIssued, total: availabilityTotal), giftAddress: giftAddress, resellAmounts: resellAmounts, resellForTonOnly: (apiFlags & (1 << 7)) != 0, releasedBy: releasedBy?.peerId, valueAmount: valueAmount, valueCurrency: valueCurrency, flags: flags, themePeerId: themePeer?.peerId, peerColor: peerCollectibleColor, hostPeerId: hostPeerId?.peerId))
        }
    }
}

func _internal_cachedStarGifts(postbox: Postbox) -> Signal<StarGiftsList?, NoError> {
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.starGifts()]))
    return postbox.combinedView(keys: [viewKey])
    |> map { views -> StarGiftsList? in
        guard let view = views.views[viewKey] as? PreferencesView else {
            return nil
        }
        guard let value = view.values[PreferencesKeys.starGifts()]?.get(StarGiftsList.self) else {
            return nil
        }
        return value
    }
}

func _internal_keepCachedStarGiftsUpdated(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id) -> Signal<Never, NoError> {
    let updateSignal = _internal_cachedStarGifts(postbox: postbox)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        return network.request(Api.functions.payments.getStarGifts(hash: list?.hashValue ?? 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.StarGifts?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            
            return postbox.transaction { transaction in
                switch result {
                case let .starGifts(hash, gifts, chats, users):
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    
                    let starGiftsLists = StarGiftsList(items: gifts.compactMap { StarGift(apiStarGift: $0) }, hashValue: hash)
                    transaction.setPreferencesEntry(key: PreferencesKeys.starGifts(), value: PreferencesEntry(starGiftsLists))
                case .starGiftsNotModified:
                    break
                }
            }
            |> ignoreValues
        }
    }
    
    return updateSignal
}

func managedStarGiftsUpdates(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id) -> Signal<Never, NoError> {
    let poll = _internal_keepCachedStarGiftsUpdated(postbox: postbox, network: network, accountPeerId: accountPeerId)
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func _internal_convertStarGift(account: Account, reference: StarGiftReference) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction in
        return reference.apiStarGiftReference(transaction: transaction)
    }
    |> mapToSignal { starGift in
        guard let starGift else {
            return .complete()
        }
        return account.network.request(Api.functions.payments.convertStarGift(stargift: starGift))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result in
            if let result, case .boolTrue = result {
                return account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, cachedData -> CachedPeerData? in
                        if let cachedData = cachedData as? CachedUserData, let starGiftsCount = cachedData.starGiftsCount {
                            var updatedData = cachedData
                            updatedData = updatedData.withUpdatedStarGiftsCount(max(0, starGiftsCount - 1))
                            return updatedData
                        } else {
                            return cachedData
                        }
                    })
                }
            }
            return .complete()
        }
        |> ignoreValues
    }
}

func _internal_updateStarGiftAddedToProfile(account: Account, reference: StarGiftReference, added: Bool) -> Signal<Never, NoError> {
    var flags: Int32 = 0
    if !added {
        flags |= (1 << 0)
    }
    return account.postbox.transaction { transaction in
        return reference.apiStarGiftReference(transaction: transaction)
    }
    |> mapToSignal { starGift in
        guard let starGift else {
            return .complete()
        }
        return account.network.request(Api.functions.payments.saveStarGift(flags: flags, stargift: starGift))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> ignoreValues
    }
}

func _internal_updateStarGiftsPinnedToTop(account: Account, peerId: EnginePeer.Id, references: [StarGiftReference]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction in
        let peer = transaction.getPeer(peerId)
        let starGifts = references.compactMap { $0.apiStarGiftReference(transaction: transaction) }
        return (peer, starGifts)
    }
    |> mapToSignal { peer, starGifts in
        guard let inputPeer = peer.flatMap(apiInputPeer) else {
            return .complete()
        }
        return account.network.request(Api.functions.payments.toggleStarGiftsPinnedToTop(peer: inputPeer, stargift: starGifts))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> ignoreValues
    }
}

public enum TransferStarGiftError {
    case generic
    case disallowedStarGift
}

public enum BuyStarGiftError {
    case generic
    case priceChanged(CurrencyAmount)
    case starGiftResellTooEarly(Int32)
    case serverProvided(String)
}

public enum UpdateStarGiftPriceError {
    case generic
    case starGiftResellTooEarly(Int32)
}

public enum UpgradeStarGiftError {
    case generic
}

func _internal_buyStarGift(account: Account, slug: String, peerId: EnginePeer.Id, price: CurrencyAmount?) -> Signal<Never, BuyStarGiftError> {
    let source: BotPaymentInvoiceSource = .starGiftResale(slug: slug, toPeerId: peerId, ton: price?.currency == .ton)
    return _internal_fetchBotPaymentForm(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, source: source, themeParams: nil)
    |> map(Optional.init)
    |> `catch` { error -> Signal<BotPaymentForm?, BuyStarGiftError> in
        if case let .starGiftResellTooEarly(timestamp) = error {
            return .fail(.starGiftResellTooEarly(timestamp))
        }
        return .fail(.generic)
    }
    |> mapToSignal { paymentForm in
        if let paymentForm {
            if let paymentPrice = paymentForm.invoice.prices.first?.amount, let price, paymentPrice > price.amount.value {
                let currencyAmount: CurrencyAmount
                if paymentForm.invoice.currency == "TON" {
                    currencyAmount = CurrencyAmount(amount: StarsAmount(value: paymentPrice, nanos: 0), currency: .ton)
                } else {
                    currencyAmount = CurrencyAmount(amount: StarsAmount(value: paymentPrice, nanos: 0), currency: .stars)
                }
                return .fail(.priceChanged(currencyAmount))
            }
            return _internal_sendStarsPaymentForm(account: account, formId: paymentForm.id, source: source)
            |> mapError { error -> BuyStarGiftError in
                if case let .serverProvided(text) = error {
                    return .serverProvided(text)
                } else {
                    return .generic
                }
            }
            |> ignoreValues
        } else {
            return .fail(.generic)
        }
    }
}

public enum DropStarGiftOriginalDetailsError {
    case generic
}

func _internal_dropStarGiftOriginalDetails(account: Account, reference: StarGiftReference) -> Signal<Never, DropStarGiftOriginalDetailsError> {
    let source: BotPaymentInvoiceSource = .starGiftDropOriginalDetails(reference: reference)
    return _internal_fetchBotPaymentForm(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, source: source, themeParams: nil)
    |> `catch` { error -> Signal<BotPaymentForm, DropStarGiftOriginalDetailsError> in
        return .fail(.generic)
    }
    |> mapToSignal { paymentForm in
        return _internal_sendStarsPaymentForm(account: account, formId: paymentForm.id, source: source)
        |> mapError { _ -> DropStarGiftOriginalDetailsError in
            return .generic
        }
        |> mapToSignal { result in
            if case .done = result, case let .message(messageId) = reference {
                return account.postbox.transaction { transaction in
                    transaction.updateMessage(messageId, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        var media = currentMessage.media
                        if let action = media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .starGiftUnique(gift, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, isRefunded, isPrepaidUpgrade, peerId, senderId, savedId, resaleAmount, canTransferDate, canResaleDate, _, assigned) = action.action, case let .unique(uniqueGift) = gift {
                            let updatedAttributes = uniqueGift.attributes.filter { $0.attributeType != .originalInfo }
                            media = [
                                TelegramMediaAction(
                                    action: .starGiftUnique(
                                        gift: .unique(uniqueGift.withAttributes(updatedAttributes)),
                                        isUpgrade: isUpgrade,
                                        isTransferred: isTransferred,
                                        savedToProfile: savedToProfile,
                                        canExportDate: canExportDate,
                                        transferStars: transferStars,
                                        isRefunded: isRefunded,
                                        isPrepaidUpgrade: isPrepaidUpgrade,
                                        peerId: peerId,
                                        senderId: senderId,
                                        savedId: savedId,
                                        resaleAmount: resaleAmount,
                                        canTransferDate: canTransferDate,
                                        canResaleDate: canResaleDate,
                                        dropOriginalDetailsStars: nil,
                                        assigned: assigned)
                                )
                            ]
                        }
                        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: media))
                    })
                }
                |> castError(DropStarGiftOriginalDetailsError.self)
            }
            return .complete()
        }
        |> ignoreValues
    }
}

func _internal_transferStarGift(account: Account, prepaid: Bool, reference: StarGiftReference, peerId: EnginePeer.Id) -> Signal<Never, TransferStarGiftError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputSavedStarGift)? in
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer), let starGift = reference.apiStarGiftReference(transaction: transaction) else {
            return nil
        }
        return (inputPeer, starGift)
    }
    |> castError(TransferStarGiftError.self)
    |> mapToSignal { inputPeerAndStarGift -> Signal<Never, TransferStarGiftError> in
        guard let (inputPeer, starGift) = inputPeerAndStarGift else {
            return .complete()
        }
        if prepaid {
            return account.network.request(Api.functions.payments.transferStarGift(stargift: starGift, toId: inputPeer))
            |> mapError { error -> TransferStarGiftError in
                if error.errorDescription == "USER_DISALLOWED_STARGIFTS" {
                    return .disallowedStarGift
                }
                return .generic
            }
            |> mapToSignal { updates -> Signal<Void, TransferStarGiftError> in
                account.stateManager.addUpdates(updates)
                return .complete()
            }
            |> ignoreValues
        } else {
            let source: BotPaymentInvoiceSource = .starGiftTransfer(reference: reference, toPeerId: peerId)
            return _internal_fetchBotPaymentForm(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, source: source, themeParams: nil)
            |> map(Optional.init)
            |> `catch` { error -> Signal<BotPaymentForm?, TransferStarGiftError> in
                if case .noPaymentNeeded = error {
                    return .single(nil)
                } else if case .disallowedStarGift = error {
                    return .fail(.disallowedStarGift)
                }
                return .fail(.generic)
            }
            |> mapToSignal { paymentForm in
                if let paymentForm {
                    return _internal_sendStarsPaymentForm(account: account, formId: paymentForm.id, source: source)
                    |> mapError { _ -> TransferStarGiftError in
                        return .generic
                    }
                    |> ignoreValues
                } else {
                    return _internal_transferStarGift(account: account, prepaid: true, reference: reference, peerId: peerId)
                }
            }
        }
    }
}

func _internal_upgradeStarGift(account: Account, formId: Int64?, reference: StarGiftReference, keepOriginalInfo: Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> {
    if let formId {
        let source: BotPaymentInvoiceSource = .starGiftUpgrade(keepOriginalInfo: keepOriginalInfo, reference: reference)
        return _internal_sendStarsPaymentForm(account: account, formId: formId, source: source)
        |> mapError { _ -> UpgradeStarGiftError in
            return .generic
        }
        |> mapToSignal { result in
            if case let .done(_, _, gift) = result, let gift {
                return .single(gift)
            } else {
                return .complete()
            }
        }
    } else {
        var flags: Int32 = 0
        if keepOriginalInfo {
            flags |= (1 << 0)
        }
        return account.postbox.transaction { transaction in
            return reference.apiStarGiftReference(transaction: transaction)
        }
        |> castError(UpgradeStarGiftError.self)
        |> mapToSignal { starGift in
            guard let starGift else {
                return .fail(.generic)
            }
            return account.network.request(Api.functions.payments.upgradeStarGift(flags: flags, stargift: starGift))
            |> mapError { _ -> UpgradeStarGiftError in
                return .generic
            }
            |> mapToSignal { updates in
                account.stateManager.addUpdates(updates)
                for update in updates.allUpdates {
                    switch update {
                    case let .updateNewMessage(message, _, _):
                        if let message = StoreMessage(apiMessage: message, accountPeerId: account.peerId, peerIsForum: false) {
                            for media in message.media {
                                if let action = media as? TelegramMediaAction, case let .starGiftUnique(gift, _, _, savedToProfile, canExportDate, transferStars, _, _, peerId, _, savedId, _, canTransferDate, canResaleDate, dropOriginalDetailsStars, _) = action.action, case let .Id(messageId) = message.id {
                                    let reference: StarGiftReference
                                    if let peerId, let savedId {
                                        reference = .peer(peerId: peerId, id: savedId)
                                    } else {
                                        reference = .message(messageId: messageId)
                                    }
                                    return .single(ProfileGiftsContext.State.StarGift(
                                        gift: gift,
                                        reference: reference,
                                        fromPeer: nil,
                                        date: message.timestamp,
                                        text: nil,
                                        entities: nil,
                                        nameHidden: false,
                                        savedToProfile: savedToProfile,
                                        pinnedToTop: false,
                                        convertStars: nil,
                                        canUpgrade: false,
                                        canExportDate: canExportDate,
                                        upgradeStars: nil,
                                        transferStars: transferStars,
                                        canTransferDate: canTransferDate,
                                        canResaleDate: canResaleDate,
                                        collectionIds: nil,
                                        prepaidUpgradeHash: nil,
                                        upgradeSeparate: false,
                                        dropOriginalDetailsStars:  dropOriginalDetailsStars
                                    ))
                                }
                            }
                        }
                    default:
                        break
                    }
                }
                return .fail(.generic)
            }
        }
    }
}

public struct StarGiftUpgradePreview: Equatable {
    public struct Price: Equatable {
        public let stars: Int64
        public let date: Int32
    }
    public let attributes: [StarGift.UniqueGift.Attribute]
    public let prices: [Price]
    public let nextPrices: [Price]
    
    public init(attributes: [StarGift.UniqueGift.Attribute], prices: [Price], nextPrices: [Price]) {
        self.attributes = attributes
        self.prices = prices
        self.nextPrices = nextPrices
    }
    
    public func withAttributes(_ attributes: [StarGift.UniqueGift.Attribute]) -> StarGiftUpgradePreview {
        return StarGiftUpgradePreview(attributes: attributes, prices: self.prices, nextPrices: self.nextPrices)
    }
}

func _internal_starGiftUpgradePreview(account: Account, giftId: Int64) -> Signal<StarGiftUpgradePreview?, NoError> {
    return account.network.request(Api.functions.payments.getStarGiftUpgradePreview(giftId: giftId))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.StarGiftUpgradePreview?, NoError> in
        return .single(nil)
    }
    |> map { result in
        guard let result else {
            return nil
        }
        switch result {
        case let .starGiftUpgradePreview(apiSampleAttributes, apiPrices, apiNextPrices):
            let attributes = apiSampleAttributes.compactMap { StarGift.UniqueGift.Attribute(apiAttribute: $0) }
            var prices: [StarGiftUpgradePreview.Price] = []
            var nextPrices: [StarGiftUpgradePreview.Price] = []
            for price in apiPrices {
                switch price {
                case let .starGiftUpgradePrice(date, upgradeStars):
                    prices.append(StarGiftUpgradePreview.Price(stars: upgradeStars, date: date))
                }
            }
            for price in apiNextPrices {
                switch price {
                case let .starGiftUpgradePrice(date, upgradeStars):
                    nextPrices.append(StarGiftUpgradePreview.Price(stars: upgradeStars, date: date))
                }
            }
            return StarGiftUpgradePreview(attributes: attributes, prices: prices, nextPrices: nextPrices)
        }
    }
}

public enum CanSendGiftResult {
    case available
    case unavailable(text: String, entities: [MessageTextEntity])
    case failed
}

func _internal_checkCanSendStarGift(account: Account, giftId: Int64) -> Signal<CanSendGiftResult, NoError> {
    return account.network.request(Api.functions.payments.checkCanSendGift(giftId: giftId))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.CheckCanSendGiftResult?, NoError> in
        return .single(nil)
    }
    |> map { result in
        guard let result else {
            return .unavailable(text: "", entities: [])
        }
        switch result {
        case .checkCanSendGiftResultOk:
            return .available
        case let .checkCanSendGiftResultFail(reason):
            switch reason {
            case let .textWithEntities(text, entities):
                return .unavailable(text: text, entities: messageTextEntitiesFromApiEntities(entities))
            }
        }
    }
}

final class CachedProfileGifts: Codable {
    enum CodingKeys: String, CodingKey {
        case gifts
        case count
        case notificationsEnabled
    }
    
    var gifts: [ProfileGiftsContext.State.StarGift]
    let count: Int32
    let notificationsEnabled: Bool?
    
    init(gifts: [ProfileGiftsContext.State.StarGift], count: Int32, notificationsEnabled: Bool?) {
        self.gifts = gifts
        self.count = count
        self.notificationsEnabled = notificationsEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.gifts = try container.decode([ProfileGiftsContext.State.StarGift].self, forKey: .gifts)
        self.count = try container.decode(Int32.self, forKey: .count)
        self.notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.gifts, forKey: .gifts)
        try container.encode(self.count, forKey: .count)
        try container.encodeIfPresent(self.notificationsEnabled, forKey: .notificationsEnabled)
    }
    
    func render(transaction: Transaction) {
        for i in 0 ..< self.gifts.count {
            let gift = self.gifts[i]
            if gift.fromPeer == nil, let fromPeerId = gift._fromPeerId, let peer = transaction.getPeer(fromPeerId) {
                self.gifts[i] = gift.withFromPeer(EnginePeer(peer))
            }
        }
    }
}

func giftsEntryId(peerId: EnginePeer.Id, collectionId: Int32?) -> ItemCacheEntryId {
    let cacheKey: ValueBoxKey
    if let collectionId {
        cacheKey = ValueBoxKey(length: 8 + 4)
        cacheKey.setInt64(0, value: peerId.toInt64())
        cacheKey.setInt32(8, value: collectionId)
    } else {
        cacheKey = ValueBoxKey(length: 8)
        cacheKey.setInt64(0, value: peerId.toInt64())
    }
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedProfileGifts, key: cacheKey)
}

private final class ProfileGiftsContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let collectionId: Int32?
    
    private let disposable = MetaDisposable()
    private let cacheDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
    private var sorting: ProfileGiftsContext.Sorting
    private var filter: ProfileGiftsContext.Filters
    private var limit: Int32
    
    private var gifts: [ProfileGiftsContext.State.StarGift] = []
    private var count: Int32?
    private var dataState: ProfileGiftsContext.State.DataState = .ready(canLoadMore: true, nextOffset: nil)
    
    private var filteredGifts: [ProfileGiftsContext.State.StarGift] = []
    private var filteredCount: Int32?
    private var filteredDataState: ProfileGiftsContext.State.DataState = .ready(canLoadMore: true, nextOffset: nil)
    
    private var notificationsEnabled: Bool?
    
    var _state: ProfileGiftsContext.State?
    private let stateValue = Promise<ProfileGiftsContext.State>()
    var state: Signal<ProfileGiftsContext.State, NoError> {
        return self.stateValue.get()
    }
    
    init(
        queue: Queue,
        account: Account,
        peerId: EnginePeer.Id,
        collectionId: Int32?,
        sorting: ProfileGiftsContext.Sorting,
        filter: ProfileGiftsContext.Filters,
        limit: Int32
    ) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        self.collectionId = collectionId
        self.sorting = sorting
        self.filter = filter
        self.limit = limit
        
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
        self.cacheDisposable.dispose()
        self.actionDisposable.dispose()
    }
    
    func reload() {
        self.gifts = []
        self.dataState = .ready(canLoadMore: true, nextOffset: nil)
        self.loadMore(reload: true)
    }
    
    func loadMore(reload: Bool = false) {
        let peerId = self.peerId
        let collectionId = self.collectionId
        let accountPeerId = self.account.peerId
        let network = self.account.network
        let postbox = self.account.postbox
        let filter = self.filter
        let sorting = self.sorting
        let limit = self.limit
        
        let isFiltered = self.filter != .All || self.sorting != .date
        if !isFiltered {
            self.filteredGifts = []
            self.filteredCount = nil
        }
        let isUniqueOnlyFilter = self.filter == [.unique, .displayed, .hidden]
        let isPeerColorFilter = self.filter == .peerColor
        
        let dataState = isFiltered ? self.filteredDataState : self.dataState
        
        guard case let .ready(true, initialNextOffset) = dataState else {
            return
        }
        if !isFiltered || isUniqueOnlyFilter || isPeerColorFilter, self.gifts.isEmpty, initialNextOffset == nil, !reload {
            self.cacheDisposable.set((self.account.postbox.transaction { transaction -> CachedProfileGifts? in
                let cachedGifts = transaction.retrieveItemCacheEntry(id: giftsEntryId(peerId: peerId, collectionId: collectionId))?.get(CachedProfileGifts.self)
                cachedGifts?.render(transaction: transaction)
                return cachedGifts
            } |> deliverOn(self.queue)).start(next: { [weak self] cachedGifts in
                guard let self, let cachedGifts else {
                    return
                }
                if isPeerColorFilter, case .loading = self.filteredDataState {
                    let gifts = cachedGifts.gifts.filter({ gift in
                        if case let .unique(uniqueGift) = gift.gift, let _ = uniqueGift.peerColor {
                            return true
                        } else {
                            return false
                        }
                    })
                    self.gifts = gifts
                    self.count = cachedGifts.count
                    self.notificationsEnabled = cachedGifts.notificationsEnabled
                    self.pushState()
                } else if isUniqueOnlyFilter, case .loading = self.filteredDataState {
                    let gifts = cachedGifts.gifts.filter({ gift in
                        if case .unique = gift.gift {
                            return true
                        } else {
                            return false
                        }
                    })
                    self.gifts = gifts
                    self.count = cachedGifts.count
                    self.notificationsEnabled = cachedGifts.notificationsEnabled
                    self.pushState()
                } else if case .loading = self.dataState {
                    self.gifts = cachedGifts.gifts
                    self.count = cachedGifts.count
                    self.notificationsEnabled = cachedGifts.notificationsEnabled
                    self.pushState()
                }
            }))
        }
        
        if isFiltered {
            self.filteredDataState = .loading
        } else {
            self.dataState = .loading
        }
        if !reload {
            self.pushState()
        }
        
        let signal: Signal<([ProfileGiftsContext.State.StarGift], Int32, String?, Bool?), NoError> = self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<([ProfileGiftsContext.State.StarGift], Int32, String?, Bool?), NoError> in
            guard let inputPeer else {
                return .single(([], 0, nil, nil))
            }
            var flags: Int32 = 0
            if let _ = collectionId {
                flags |= (1 << 6)
            }
            if case .value = sorting {
                flags |= (1 << 5)
            }
            if filter.contains(.peerColor) {
                flags |= (1 << 9)
            } else {
                if !filter.contains(.hidden) {
                    flags |= (1 << 0)
                }
                if !filter.contains(.displayed) {
                    flags |= (1 << 1)
                }
                if !filter.contains(.unlimited) {
                    flags |= (1 << 2)
                }
                if !filter.contains(.limitedUpgradable) {
                    flags |= (1 << 7)
                }
                if !filter.contains(.limitedNonUpgradable) {
                    flags |= (1 << 8)
                }
                if !filter.contains(.unique) {
                    flags |= (1 << 4)
                }
            }
            return network.request(Api.functions.payments.getSavedStarGifts(flags: flags, peer: inputPeer, collectionId: collectionId, offset: initialNextOffset ?? "", limit: limit))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.payments.SavedStarGifts?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<([ProfileGiftsContext.State.StarGift], Int32, String?, Bool?), NoError> in
                guard let result else {
                    return .single(([], 0, nil, nil))
                }
                return postbox.transaction { transaction -> ([ProfileGiftsContext.State.StarGift], Int32, String?, Bool?) in
                    switch result {
                    case let .savedStarGifts(_, count, apiNotificationsEnabled, apiGifts, nextOffset, chats, users):
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        
                        var notificationsEnabled: Bool?
                        if let apiNotificationsEnabled {
                            if case .boolTrue = apiNotificationsEnabled {
                                notificationsEnabled = true
                            } else {
                                notificationsEnabled = false
                            }
                        }
                        
                        let gifts = apiGifts.compactMap { ProfileGiftsContext.State.StarGift(apiSavedStarGift: $0, peerId: peerId, transaction: transaction) }
                        return (gifts, count, nextOffset, notificationsEnabled)
                    }
                }
            }
        }
        
        self.disposable.set((signal
        |> deliverOn(self.queue)).start(next: { [weak self] (gifts, count, nextOffset, notificationsEnabled) in
            guard let self else {
                return
            }
            if isFiltered {
                if initialNextOffset == nil || reload {
                    self.filteredGifts = gifts
                } else {
                    self.filteredGifts.append(contentsOf: gifts)
                }
                
                let updatedCount = max(Int32(self.filteredGifts.count), count)
                self.filteredCount = updatedCount
                self.filteredDataState = .ready(canLoadMore: count != 0 && updatedCount > self.filteredGifts.count && nextOffset != nil, nextOffset: nextOffset)
            } else {
                if initialNextOffset == nil || reload {
                    self.gifts = gifts
                    self.cacheDisposable.set(self.account.postbox.transaction { transaction in
                        if let entry = CodableEntry(CachedProfileGifts(gifts: gifts, count: count, notificationsEnabled: notificationsEnabled)) {
                            transaction.putItemCacheEntry(id: giftsEntryId(peerId: peerId, collectionId: collectionId), entry: entry)
                        }
                    }.start())
                } else {
                    self.gifts.append(contentsOf: gifts)
                }
                
                let updatedCount = max(Int32(self.gifts.count), count)
                self.count = updatedCount
                self.dataState = .ready(canLoadMore: count != 0 && updatedCount > self.gifts.count && nextOffset != nil, nextOffset: nextOffset)
            }
            
            self.notificationsEnabled = notificationsEnabled
            self.pushState()
        }))
    }
    
    func updateStarGiftAddedToProfile(reference: StarGiftReference, added: Bool) {
        self.actionDisposable.set(
            _internal_updateStarGiftAddedToProfile(account: self.account, reference: reference, added: added).startStrict()
        )
        
        if let index = self.gifts.firstIndex(where: { $0.reference == reference }) {
            if !added && self.gifts[index].pinnedToTop {
                let pinnedGifts = self.gifts.filter { $0.pinnedToTop && $0.reference != reference }
                let existingGifts = Set(pinnedGifts.compactMap { $0.reference })
                
                var updatedGifts: [ProfileGiftsContext.State.StarGift] = []
                for gift in self.gifts {
                    if let reference = gift.reference, existingGifts.contains(reference) {
                        continue
                    }
                    var gift = gift
                    if gift.reference == reference {
                        gift = gift.withPinnedToTop(false).withSavedToProfile(false)
                    }
                    updatedGifts.append(gift)
                }
                updatedGifts.sort { lhs, rhs in
                    lhs.date > rhs.date
                }
                updatedGifts.insert(contentsOf: pinnedGifts, at: 0)
                self.gifts = updatedGifts
            } else {
                self.gifts[index] = self.gifts[index].withSavedToProfile(added)
            }
        }
        
        if let index = self.filteredGifts.firstIndex(where: { $0.reference == reference }) {
            self.filteredGifts[index] = self.filteredGifts[index].withSavedToProfile(added)
            if !self.filter.contains(.hidden) && !added {
                self.filteredGifts.remove(at: index)
            }
        }
        self.pushState()
    }
    
    func updateStarGiftPinnedToTop(reference: StarGiftReference, pinnedToTop: Bool) {
        var pinnedGifts = self.gifts.filter { $0.pinnedToTop }
        var saveToProfile = false
        if var gift = self.gifts.first(where: { $0.reference == reference }) {
            gift = gift.withPinnedToTop(pinnedToTop)
            if pinnedToTop {
                if !gift.savedToProfile {
                    gift = gift.withSavedToProfile(true)
                    saveToProfile = true
                }
                pinnedGifts.append(gift)
            } else {
                pinnedGifts.removeAll(where: { $0.reference == reference })
            }
        }
        let existingGifts = Set(pinnedGifts.compactMap { $0.reference })
        var updatedGifts: [ProfileGiftsContext.State.StarGift] = []
        for gift in self.gifts {
            if let reference = gift.reference, existingGifts.contains(reference) {
                continue
            }
            var gift = gift
            if gift.reference == reference {
                gift = gift.withPinnedToTop(pinnedToTop)
            }
            updatedGifts.append(gift)
        }
        updatedGifts.sort { lhs, rhs in
            lhs.date > rhs.date
        }
        updatedGifts.insert(contentsOf: pinnedGifts, at: 0)
        self.gifts = updatedGifts
        
        var effectiveReferences = pinnedGifts.compactMap { $0.reference }
        if !self.filteredGifts.isEmpty {
            var filteredPinnedGifts = self.filteredGifts.filter { $0.pinnedToTop }
            if var gift = self.filteredGifts.first(where: { $0.reference == reference }) {
                gift = gift.withPinnedToTop(pinnedToTop)
                if pinnedToTop {
                    if !gift.savedToProfile {
                        gift = gift.withSavedToProfile(true)
                    }
                    filteredPinnedGifts.append(gift)
                } else {
                    filteredPinnedGifts.removeAll(where: { $0.reference == reference })
                }
            }
            let existingFilteredGifts = Set(filteredPinnedGifts.compactMap { $0.reference })
            var updatedFilteredGifts: [ProfileGiftsContext.State.StarGift] = []
            for gift in self.filteredGifts {
                if let reference = gift.reference, existingFilteredGifts.contains(reference) {
                    continue
                }
                var gift = gift
                if gift.reference == reference {
                    gift = gift.withPinnedToTop(pinnedToTop)
                }
                updatedFilteredGifts.append(gift)
            }
            updatedFilteredGifts.sort { lhs, rhs in
                lhs.date > rhs.date
            }
            updatedFilteredGifts.insert(contentsOf: filteredPinnedGifts, at: 0)
            self.filteredGifts = updatedFilteredGifts
            
            effectiveReferences = filteredPinnedGifts.compactMap { $0.reference }
        }

        self.pushState()
        
        var signal = _internal_updateStarGiftsPinnedToTop(account: self.account, peerId: self.peerId, references: effectiveReferences)
        if saveToProfile {
            signal = _internal_updateStarGiftAddedToProfile(account: self.account, reference: reference, added: true)
            |> then(signal)
        }
        self.actionDisposable.set(
            (signal |> deliverOn(self.queue)).startStrict(completed: { [weak self] in
                self?.reload()
            })
        )
    }
    
    public func updatePinnedToTopStarGifts(references: [StarGiftReference]) {
        let existingGifts = Set(references)
        var saveSignals: [Signal<Never, NoError>] = []
        let currentPinnedGifts = self.gifts.filter { gift in
            if let reference = gift.reference {
                return existingGifts.contains(reference)
            } else {
                return false
            }
        }.map { gift in
            if !gift.savedToProfile, let reference = gift.reference {
                saveSignals.append(_internal_updateStarGiftAddedToProfile(account: self.account, reference: reference, added: true))
            }
            return gift.withPinnedToTop(true).withSavedToProfile(true)
        }
        
        var updatedGifts: [ProfileGiftsContext.State.StarGift] = []
        for gift in self.gifts {
            if let reference = gift.reference, existingGifts.contains(reference) {
                continue
            }
            updatedGifts.append(gift.withPinnedToTop(false))
        }
        updatedGifts.sort { lhs, rhs in
            lhs.date > rhs.date
        }
        
        var pinnedGifts: [ProfileGiftsContext.State.StarGift] = []
        for reference in references {
            if let gift = currentPinnedGifts.first(where: { $0.reference == reference }) {
                pinnedGifts.append(gift)
            }
        }
        updatedGifts.insert(contentsOf: pinnedGifts, at: 0)
        self.gifts = updatedGifts
        
        self.pushState()
        
        var signal = _internal_updateStarGiftsPinnedToTop(account: self.account, peerId: self.peerId, references: pinnedGifts.compactMap { $0.reference })
        if !saveSignals.isEmpty {
            signal = combineLatest(saveSignals)
            |> ignoreValues
            |> then(signal)
        }
        self.actionDisposable.set(
            (signal |> deliverOn(self.queue)).startStrict(completed: { [weak self] in
                self?.reload()
            })
        )
    }
    
    public func dropOriginalDetails(reference: StarGiftReference) -> Signal<Never, DropStarGiftOriginalDetailsError> {
        if let index = self.gifts.firstIndex(where: { $0.reference == reference }), case let .unique(uniqueGift) = self.gifts[index].gift {
            let updatedUniqueGift = uniqueGift.withAttributes(uniqueGift.attributes.filter { $0.attributeType != .originalInfo })
            self.gifts[index] = self.gifts[index].withGift(.unique(updatedUniqueGift))
        }
        if let index = self.filteredGifts.firstIndex(where: { $0.reference == reference }), case let .unique(uniqueGift) = self.filteredGifts[index].gift {
            let updatedUniqueGift = uniqueGift.withAttributes(uniqueGift.attributes.filter { $0.attributeType != .originalInfo })
            self.filteredGifts[index] = self.filteredGifts[index].withGift(.unique(updatedUniqueGift))
        }

        self.pushState()
        
        return _internal_dropStarGiftOriginalDetails(account: self.account, reference: reference)
    }
        
    func convertStarGift(reference: StarGiftReference) {
        self.actionDisposable.set(
            _internal_convertStarGift(account: self.account, reference: reference).startStrict()
        )
        if let count = self.count {
            self.count = max(0, count - 1)
        }
        self.gifts.removeAll(where: { $0.reference == reference })
        self.filteredGifts.removeAll(where: { $0.reference == reference })
        self.pushState()
    }
    
    func transferStarGift(prepaid: Bool, reference: StarGiftReference, peerId: EnginePeer.Id) -> Signal<Never, TransferStarGiftError> {
        if let count = self.count {
            self.count = max(0, count - 1)
        }
        self.gifts.removeAll(where: { $0.reference == reference })
        self.filteredGifts.removeAll(where: { $0.reference == reference })
        self.pushState()
        
        return _internal_transferStarGift(account: self.account, prepaid: prepaid, reference: reference, peerId: peerId)
    }
    
    func buyStarGift(slug: String, peerId: EnginePeer.Id, price: CurrencyAmount?) -> Signal<Never, BuyStarGiftError> {
        var listingPrice: CurrencyAmount?
        if let gift = self.gifts.first(where: { gift in
            if case let .unique(uniqueGift) = gift.gift, uniqueGift.slug == slug {
                return true
            }
            return false
        }), case let .unique(uniqueGift) = gift.gift {
            listingPrice = uniqueGift.resellAmounts?.first(where: { $0.currency == .stars })
        }
        
        if listingPrice == nil {
            if let gift = self.filteredGifts.first(where: { gift in
                if case let .unique(uniqueGift) = gift.gift, uniqueGift.slug == slug {
                    return true
                }
                return false
            }), case let .unique(uniqueGift) = gift.gift {
                listingPrice = uniqueGift.resellAmounts?.first(where: { $0.currency == .stars })
            }
        }
                
        return _internal_buyStarGift(account: self.account, slug: slug, peerId: peerId, price: price ?? listingPrice)
        |> afterCompleted { [weak self] in
            guard let self else {
                return
            }
            self.queue.async {
                if let count = self.count {
                    self.count = max(0, count - 1)
                }
                self.gifts.removeAll(where: { gift in
                    if case let .unique(uniqueGift) = gift.gift, uniqueGift.slug == slug {
                        return true
                    }
                    return false
                })
                self.filteredGifts.removeAll(where: { gift in
                    if case let .unique(uniqueGift) = gift.gift, uniqueGift.slug == slug {
                        return true
                    }
                    return false
                })

                self.pushState()
            }
        }
    }
    
    func removeStarGift(gift: TelegramCore.StarGift) {
        self.gifts.removeAll(where: { $0.gift == gift })
        self.filteredGifts.removeAll(where: { $0.gift == gift })
        self.pushState()
    }
    
    func insertStarGifts(gifts: [ProfileGiftsContext.State.StarGift]) {
        self.gifts.insert(contentsOf: gifts, at: 0)
        self.pushState()
        
        let peerId = self.peerId
        let collectionId = self.collectionId
        self.cacheDisposable.set(self.account.postbox.transaction { transaction in
            var updatedGifts: [ProfileGiftsContext.State.StarGift] = []
            var updatedCount: Int32 = 0
            if let cachedGifts = transaction.retrieveItemCacheEntry(id: giftsEntryId(peerId: peerId, collectionId: collectionId))?.get(CachedProfileGifts.self) {
                updatedGifts = cachedGifts.gifts
                updatedCount = cachedGifts.count
            } else {
                updatedGifts = []
            }
            updatedGifts.insert(contentsOf: gifts, at: 0)
            updatedCount += Int32(gifts.count)
            if let entry = CodableEntry(CachedProfileGifts(gifts: updatedGifts, count: updatedCount, notificationsEnabled: nil)) {
                transaction.putItemCacheEntry(id: giftsEntryId(peerId: peerId, collectionId: collectionId), entry: entry)
            }
        }.start())
    }
    
    func removeStarGifts(references: [StarGiftReference]) {
        self.gifts.removeAll(where: {
            if let reference = $0.reference {
                return references.contains(reference)
            } else {
                return false
            }
        })
        self.pushState()
        
        let peerId = self.peerId
        let collectionId = self.collectionId
        self.cacheDisposable.set(self.account.postbox.transaction { transaction in
            var updatedGifts: [ProfileGiftsContext.State.StarGift] = []
            var updatedCount: Int32 = 0
            if let cachedGifts = transaction.retrieveItemCacheEntry(id: giftsEntryId(peerId: peerId, collectionId: collectionId))?.get(CachedProfileGifts.self) {
                updatedGifts = cachedGifts.gifts
                updatedCount = cachedGifts.count
            } else {
                updatedGifts = []
            }
            updatedGifts = updatedGifts.filter { gift in
                if let reference = gift.reference {
                    return !references.contains(reference)
                } else {
                    return true
                }
            }
            updatedCount -= Int32(references.count)
            if let entry = CodableEntry(CachedProfileGifts(gifts: updatedGifts, count: updatedCount, notificationsEnabled: nil)) {
                transaction.putItemCacheEntry(id: giftsEntryId(peerId: peerId, collectionId: collectionId), entry: entry)
            }
        }.start())
    }
    
    func reorderStarGifts(references: [StarGiftReference]) {
        let giftsSet = Set(references)
        var giftsMap: [StarGiftReference: ProfileGiftsContext.State.StarGift] = [:]
        for gift in self.gifts {
            if let reference = gift.reference {
                giftsMap[reference] = gift
            }
        }
        var updatedGifts: [ProfileGiftsContext.State.StarGift] = []
        for reference in references {
            if let gift = giftsMap[reference] {
                updatedGifts.append(gift)
            }
        }
        for gift in self.gifts {
            if let reference = gift.reference, giftsSet.contains(reference) {
                continue
            }
            updatedGifts.append(gift)
        }
        self.gifts = updatedGifts
        self.pushState()
        
        let updatedCount = self.count ?? 0
        
        let peerId = self.peerId
        let collectionId = self.collectionId
        self.cacheDisposable.set(self.account.postbox.transaction { transaction in
            if let entry = CodableEntry(CachedProfileGifts(gifts: updatedGifts, count: updatedCount, notificationsEnabled: nil)) {
                transaction.putItemCacheEntry(id: giftsEntryId(peerId: peerId, collectionId: collectionId), entry: entry)
            }
        }.start())
    }
    
    func upgradeStarGift(formId: Int64?, reference: StarGiftReference, keepOriginalInfo: Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            let disposable = MetaDisposable()
            disposable.set(
                (_internal_upgradeStarGift(
                    account: self.account,
                    formId: formId,
                    reference: reference,
                    keepOriginalInfo: keepOriginalInfo
                )
                |> deliverOn(self.queue)).startStrict(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    if let index = self.gifts.firstIndex(where: { $0.reference == reference }) {
                        self.gifts[index] = result
                    }
                    if let index = self.filteredGifts.firstIndex(where: { $0.reference == reference }) {
                        self.filteredGifts[index] = result
                    }
                    self.pushState()
                    subscriber.putNext(result)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                })
            )
            return disposable
        }
    }
    
    func updateStarGiftResellPrice(reference: StarGiftReference, price: CurrencyAmount?, id: Int64?) -> Signal<Never, UpdateStarGiftPriceError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            
            let signal = _internal_updateStarGiftResalePrice(account: self.account, reference: reference, price: price)
            let disposable = MetaDisposable()
            disposable.set(
                (signal
                |> deliverOn(self.queue)).startStrict(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    if let index = self.gifts.firstIndex(where: { gift in
                        if gift.reference == reference {
                            return true
                        }
                        switch gift.gift {
                        case let .generic(gift):
                            if gift.id == id {
                                return true
                            }
                        case let .unique(uniqueGift):
                            if uniqueGift.id == id {
                                return true
                            }
                        }
                        return false
                    }) {
                        if case let .unique(uniqueGift) = self.gifts[index].gift {
                            let updatedUniqueGift = uniqueGift.withResellAmounts(price.flatMap { [$0] }).withResellForTonOnly(price?.currency == .ton)
                            let updatedGift = self.gifts[index].withGift(.unique(updatedUniqueGift))
                            self.gifts[index] = updatedGift
                        }
                    }
                    
                    if let index = self.filteredGifts.firstIndex(where: { gift in
                        if gift.reference == reference {
                            return true
                        }
                        switch gift.gift {
                        case let .generic(gift):
                            if gift.id == id {
                                return true
                            }
                        case let .unique(uniqueGift):
                            if uniqueGift.id == id {
                                return true
                            }
                        }
                        return false
                    }) {
                        if case let .unique(uniqueGift) = self.filteredGifts[index].gift {
                            let updatedUniqueGift = uniqueGift.withResellAmounts(price.flatMap { [$0] }).withResellForTonOnly(price?.currency == .ton)
                            let updatedGift = self.filteredGifts[index].withGift(.unique(updatedUniqueGift))
                            self.filteredGifts[index] = updatedGift
                        }
                    }
                    
                    self.pushState()
                    
                    subscriber.putCompletion()
                })
            )
            return disposable
        }
    }
    
    func toggleStarGiftsNotifications(enabled: Bool) {
        self.actionDisposable.set(
            _internal_toggleStarGiftsNotifications(account: self.account, peerId: self.peerId, enabled: enabled).startStrict()
        )
        self.notificationsEnabled = enabled
        self.pushState()
    }
    
    func updateFilter(_ filter: ProfileGiftsContext.Filters) {
        guard self.filter != filter else {
            return
        }
        self.filter = filter
        self.filteredDataState = .ready(canLoadMore: true, nextOffset: nil)
        self.pushState()
        
        self.loadMore()
    }
    
    func updateSorting(_ sorting: ProfileGiftsContext.Sorting) {
        guard self.sorting != sorting else {
            return
        }
        self.sorting = sorting
        self.filteredDataState = .ready(canLoadMore: true, nextOffset: nil)
        self.pushState()
        
        self.loadMore()
    }
        
    private func pushState() {
        let useMainData = (self.filter == .All && self.sorting == .date) || self.filteredCount == nil
        
        let effectiveGifts = useMainData ? self.gifts : self.filteredGifts
        let effectiveCount = useMainData ? self.count : self.filteredCount
        let effectiveDataState = useMainData ? self.dataState : self.filteredDataState
        
        let state = ProfileGiftsContext.State(
            filter: self.filter,
            sorting: self.sorting,
            gifts: self.gifts,
            filteredGifts: effectiveGifts,
            count: effectiveCount,
            dataState: effectiveDataState,
            notificationsEnabled: self.notificationsEnabled
        )
        self._state = state
        self.stateValue.set(.single(state))
    }
}

public final class ProfileGiftsContext {
    public struct Filters: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let unlimited = Filters(rawValue: 1 << 0)
        public static let limitedUpgradable = Filters(rawValue: 1 << 1)
        public static let limitedNonUpgradable = Filters(rawValue: 1 << 2)
        public static let unique = Filters(rawValue: 1 << 3)
        public static let displayed = Filters(rawValue: 1 << 4)
        public static let hidden = Filters(rawValue: 1 << 5)
        public static let peerColor = Filters(rawValue: 1 << 6)
        
        public static var All: Filters {
            return [.unlimited, .limitedUpgradable, .limitedNonUpgradable, .unique, .displayed, .hidden]
        }
    }
    
    public enum Sorting: Equatable {
        case date
        case value
    }
    
    public struct State: Equatable {
        public struct StarGift: Equatable, Codable {
            enum CodingKeys: String, CodingKey {
                case gift
                case reference
                case fromPeerId
                case date
                case text
                case entities
                case messageId
                case nameHidden
                case savedToProfile
                case pinnedToTop
                case convertStars
                case canUpgrade
                case canExportDate
                case upgradeStars
                case transferStars
                case giftAddress
                case canTransferDate
                case canResaleDate
                case collectionIds
                case prepaidUpgradeHash
                case upgradeSeparate
                case dropOriginalDetailsStars
            }
            
            public let gift: TelegramCore.StarGift
            public let reference: StarGiftReference?
            public let fromPeer: EnginePeer?
            public let date: Int32
            public let text: String?
            public let entities: [MessageTextEntity]?
            public let nameHidden: Bool
            public let savedToProfile: Bool
            public let pinnedToTop: Bool
            public let convertStars: Int64?
            public let canUpgrade: Bool
            public let canExportDate: Int32?
            public let upgradeStars: Int64?
            public let transferStars: Int64?
            public let canTransferDate: Int32?
            public let canResaleDate: Int32?
            public let collectionIds: [Int32]?
            public let prepaidUpgradeHash: String?
            public let upgradeSeparate: Bool
            public let dropOriginalDetailsStars: Int64?

            fileprivate let _fromPeerId: EnginePeer.Id?
            
            public enum DecodingError: Error {
                case generic
            }
            
            public init (
                gift: TelegramCore.StarGift,
                reference: StarGiftReference?,
                fromPeer: EnginePeer?,
                date: Int32,
                text: String?,
                entities: [MessageTextEntity]?,
                nameHidden: Bool,
                savedToProfile: Bool,
                pinnedToTop: Bool,
                convertStars: Int64?,
                canUpgrade: Bool,
                canExportDate: Int32?,
                upgradeStars: Int64?,
                transferStars: Int64?,
                canTransferDate: Int32?,
                canResaleDate: Int32?,
                collectionIds: [Int32]?,
                prepaidUpgradeHash: String?,
                upgradeSeparate: Bool,
                dropOriginalDetailsStars: Int64?
            ) {
                self.gift = gift
                self.reference = reference
                self.fromPeer = fromPeer
                self._fromPeerId = fromPeer?.id
                self.date = date
                self.text = text
                self.entities = entities
                self.nameHidden = nameHidden
                self.savedToProfile = savedToProfile
                self.pinnedToTop = pinnedToTop
                self.convertStars = convertStars
                self.canUpgrade = canUpgrade
                self.canExportDate = canExportDate
                self.upgradeStars = upgradeStars
                self.transferStars = transferStars
                self.canTransferDate = canTransferDate
                self.canResaleDate = canResaleDate
                self.collectionIds = collectionIds
                self.prepaidUpgradeHash = prepaidUpgradeHash
                self.upgradeSeparate = upgradeSeparate
                self.dropOriginalDetailsStars = dropOriginalDetailsStars
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.gift = try container.decode(TelegramCore.StarGift.self, forKey: .gift)
                if let reference = try container.decodeIfPresent(StarGiftReference.self, forKey: .reference) {
                    self.reference = reference
                } else if let messageId = try container.decodeIfPresent(EngineMessage.Id.self, forKey: .messageId) {
                    self.reference = .message(messageId: messageId)
                } else {
                    self.reference = nil
                }
                self.fromPeer = nil
                self._fromPeerId = try container.decodeIfPresent(EnginePeer.Id.self, forKey: .fromPeerId)
                self.date = try container.decode(Int32.self, forKey: .date)
                self.text = try container.decodeIfPresent(String.self, forKey: .text)
                self.entities = try container.decodeIfPresent([MessageTextEntity].self, forKey: .entities)
                self.nameHidden = try container.decode(Bool.self, forKey: .nameHidden)
                self.savedToProfile = try container.decode(Bool.self, forKey: .savedToProfile)
                self.pinnedToTop = try container.decodeIfPresent(Bool.self, forKey: .pinnedToTop) ?? false
                self.convertStars = try container.decodeIfPresent(Int64.self, forKey: .convertStars)
                self.canUpgrade = try container.decode(Bool.self, forKey: .canUpgrade)
                self.canExportDate = try container.decodeIfPresent(Int32.self, forKey: .canExportDate)
                self.upgradeStars = try container.decodeIfPresent(Int64.self, forKey: .upgradeStars)
                self.transferStars = try container.decodeIfPresent(Int64.self, forKey: .transferStars)
                self.canTransferDate = try container.decodeIfPresent(Int32.self, forKey: .canTransferDate)
                self.canResaleDate = try container.decodeIfPresent(Int32.self, forKey: .canResaleDate)
                self.collectionIds = try container.decodeIfPresent([Int32].self, forKey: .collectionIds)
                self.prepaidUpgradeHash = try container.decodeIfPresent(String.self, forKey: .prepaidUpgradeHash)
                self.upgradeSeparate = try container.decodeIfPresent(Bool.self, forKey: .upgradeSeparate) ?? false
                self.dropOriginalDetailsStars = try container.decodeIfPresent(Int64.self, forKey: .dropOriginalDetailsStars)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(self.gift, forKey: .gift)
                try container.encodeIfPresent(self.reference, forKey: .reference)
                try container.encodeIfPresent(self.fromPeer?.id, forKey: .fromPeerId)
                try container.encode(self.date, forKey: .date)
                try container.encodeIfPresent(self.text, forKey: .text)
                try container.encodeIfPresent(self.entities, forKey: .entities)
                try container.encode(self.nameHidden, forKey: .nameHidden)
                try container.encode(self.savedToProfile, forKey: .savedToProfile)
                try container.encode(self.pinnedToTop, forKey: .pinnedToTop)
                try container.encodeIfPresent(self.convertStars, forKey: .convertStars)
                try container.encode(self.canUpgrade, forKey: .canUpgrade)
                try container.encodeIfPresent(self.canExportDate, forKey: .canExportDate)
                try container.encodeIfPresent(self.upgradeStars, forKey: .upgradeStars)
                try container.encodeIfPresent(self.transferStars, forKey: .transferStars)
                try container.encodeIfPresent(self.canTransferDate, forKey: .canTransferDate)
                try container.encodeIfPresent(self.canResaleDate, forKey: .canResaleDate)
                try container.encodeIfPresent(self.collectionIds, forKey: .collectionIds)
                try container.encodeIfPresent(self.prepaidUpgradeHash, forKey: .prepaidUpgradeHash)
                try container.encode(self.upgradeSeparate, forKey: .upgradeSeparate)
                try container.encodeIfPresent(self.dropOriginalDetailsStars, forKey: .dropOriginalDetailsStars)
            }
            
            public func withGift(_ gift: TelegramCore.StarGift) -> StarGift {
                return StarGift(
                    gift: gift,
                    reference: self.reference,
                    fromPeer: self.fromPeer,
                    date: self.date,
                    text: self.text,
                    entities: self.entities,
                    nameHidden: self.nameHidden,
                    savedToProfile: self.savedToProfile,
                    pinnedToTop: self.pinnedToTop,
                    convertStars: self.convertStars,
                    canUpgrade: self.canUpgrade,
                    canExportDate: self.canExportDate,
                    upgradeStars: self.upgradeStars,
                    transferStars: self.transferStars,
                    canTransferDate: self.canTransferDate,
                    canResaleDate: self.canResaleDate,
                    collectionIds: self.collectionIds,
                    prepaidUpgradeHash: self.prepaidUpgradeHash,
                    upgradeSeparate: self.upgradeSeparate,
                    dropOriginalDetailsStars: self.dropOriginalDetailsStars
                )
            }
            
            public func withSavedToProfile(_ savedToProfile: Bool) -> StarGift {
                return StarGift(
                    gift: self.gift,
                    reference: self.reference,
                    fromPeer: self.fromPeer,
                    date: self.date,
                    text: self.text,
                    entities: self.entities,
                    nameHidden: self.nameHidden,
                    savedToProfile: savedToProfile,
                    pinnedToTop: self.pinnedToTop,
                    convertStars: self.convertStars,
                    canUpgrade: self.canUpgrade,
                    canExportDate: self.canExportDate,
                    upgradeStars: self.upgradeStars,
                    transferStars: self.transferStars,
                    canTransferDate: self.canTransferDate,
                    canResaleDate: self.canResaleDate,
                    collectionIds: self.collectionIds,
                    prepaidUpgradeHash: self.prepaidUpgradeHash,
                    upgradeSeparate: self.upgradeSeparate,
                    dropOriginalDetailsStars: self.dropOriginalDetailsStars
                )
            }
            
            public func withPinnedToTop(_ pinnedToTop: Bool) -> StarGift {
                return StarGift(
                    gift: self.gift,
                    reference: self.reference,
                    fromPeer: self.fromPeer,
                    date: self.date,
                    text: self.text,
                    entities: self.entities,
                    nameHidden: self.nameHidden,
                    savedToProfile: self.savedToProfile,
                    pinnedToTop: pinnedToTop,
                    convertStars: self.convertStars,
                    canUpgrade: self.canUpgrade,
                    canExportDate: self.canExportDate,
                    upgradeStars: self.upgradeStars,
                    transferStars: self.transferStars,
                    canTransferDate: self.canTransferDate,
                    canResaleDate: self.canResaleDate,
                    collectionIds: self.collectionIds,
                    prepaidUpgradeHash: self.prepaidUpgradeHash,
                    upgradeSeparate: self.upgradeSeparate,
                    dropOriginalDetailsStars: self.dropOriginalDetailsStars
                )
            }
            fileprivate func withFromPeer(_ fromPeer: EnginePeer?) -> StarGift {
                return StarGift(
                    gift: self.gift,
                    reference: self.reference,
                    fromPeer: fromPeer,
                    date: self.date,
                    text: self.text,
                    entities: self.entities,
                    nameHidden: self.nameHidden,
                    savedToProfile: self.savedToProfile,
                    pinnedToTop: self.pinnedToTop,
                    convertStars: self.convertStars,
                    canUpgrade: self.canUpgrade,
                    canExportDate: self.canExportDate,
                    upgradeStars: self.upgradeStars,
                    transferStars: self.transferStars,
                    canTransferDate: self.canTransferDate,
                    canResaleDate: self.canResaleDate,
                    collectionIds: self.collectionIds,
                    prepaidUpgradeHash: self.prepaidUpgradeHash,
                    upgradeSeparate: self.upgradeSeparate,
                    dropOriginalDetailsStars: self.dropOriginalDetailsStars
                )
            }
            
            public func withCollectionIds(_ collectionIds: [Int32]?) -> StarGift {
                return StarGift(
                    gift: self.gift,
                    reference: self.reference,
                    fromPeer: self.fromPeer,
                    date: self.date,
                    text: self.text,
                    entities: self.entities,
                    nameHidden: self.nameHidden,
                    savedToProfile: self.savedToProfile,
                    pinnedToTop: self.pinnedToTop,
                    convertStars: self.convertStars,
                    canUpgrade: self.canUpgrade,
                    canExportDate: self.canExportDate,
                    upgradeStars: self.upgradeStars,
                    transferStars: self.transferStars,
                    canTransferDate: self.canTransferDate,
                    canResaleDate: self.canResaleDate,
                    collectionIds: collectionIds,
                    prepaidUpgradeHash: self.prepaidUpgradeHash,
                    upgradeSeparate: self.upgradeSeparate,
                    dropOriginalDetailsStars: self.dropOriginalDetailsStars
                )
            }
        }
        
        public enum DataState: Equatable {
            case loading
            case ready(canLoadMore: Bool, nextOffset: String?)
        }
        
        public var filter: Filters
        public var sorting: Sorting
        public var gifts: [ProfileGiftsContext.State.StarGift]
        public var filteredGifts: [ProfileGiftsContext.State.StarGift]
        public var count: Int32?
        public var dataState: ProfileGiftsContext.State.DataState
        public var notificationsEnabled: Bool?
    }
    
    private let queue: Queue = .mainQueue()
    private let impl: QueueLocalObject<ProfileGiftsContextImpl>
    
    public var state: Signal<ProfileGiftsContext.State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            
            return disposable
        }
    }
    
    public let peerId: EnginePeer.Id
    public let collectionId: Int32?
    
    public init(
        account: Account,
        peerId: EnginePeer.Id,
        collectionId: Int32? = nil,
        sorting: ProfileGiftsContext.Sorting = .date,
        filter: ProfileGiftsContext.Filters = .All,
        limit: Int32 = 36
    ) {
        self.peerId = peerId
        self.collectionId = collectionId
        
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ProfileGiftsContextImpl(queue: queue, account: account, peerId: peerId, collectionId: collectionId, sorting: sorting, filter: filter, limit: limit)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    public func reload() {
        self.impl.with { impl in
            impl.reload()
        }
    }
    
    public func updateStarGiftAddedToProfile(reference: StarGiftReference, added: Bool) {
        self.impl.with { impl in
            impl.updateStarGiftAddedToProfile(reference: reference, added: added)
        }
    }
    
    public func updateStarGiftPinnedToTop(reference: StarGiftReference, pinnedToTop: Bool) {
        self.impl.with { impl in
            impl.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: pinnedToTop)
        }
    }
    
    public func updatePinnedToTopStarGifts(references: [StarGiftReference]) {
        self.impl.with { impl in
            impl.updatePinnedToTopStarGifts(references: references)
        }
    }
    
    public func dropOriginalDetails(reference: StarGiftReference) -> Signal<Never, DropStarGiftOriginalDetailsError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.dropOriginalDetails(reference: reference).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func convertStarGift(reference: StarGiftReference) {
        self.impl.with { impl in
            impl.convertStarGift(reference: reference)
        }
    }
    
    public func buyStarGift(slug: String, peerId: EnginePeer.Id, price: CurrencyAmount? = nil) -> Signal<Never, BuyStarGiftError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.buyStarGift(slug: slug, peerId: peerId, price: price).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func removeStarGift(gift: TelegramCore.StarGift) {
        self.impl.with { impl in
            impl.removeStarGift(gift: gift)
        }
    }
    
    public func insertStarGifts(gifts: [ProfileGiftsContext.State.StarGift]) {
        self.impl.with { impl in
            impl.insertStarGifts(gifts: gifts)
        }
    }
    
    public func removeStarGifts(references: [StarGiftReference]) {
        self.impl.with { impl in
            impl.removeStarGifts(references: references)
        }
    }
    
    public func reorderStarGifts(references: [StarGiftReference]) {
        self.impl.with { impl in
            impl.reorderStarGifts(references: references)
        }
    }

    public func transferStarGift(prepaid: Bool, reference: StarGiftReference, peerId: EnginePeer.Id) -> Signal<Never, TransferStarGiftError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.transferStarGift(prepaid: prepaid, reference: reference, peerId: peerId).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }

    public func upgradeStarGift(formId: Int64?, reference: StarGiftReference, keepOriginalInfo: Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.upgradeStarGift(formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo).start(next: { value in
                    subscriber.putNext(value)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func updateStarGiftResellPrice(reference: StarGiftReference, price: CurrencyAmount?, id: Int64? = nil) -> Signal<Never, UpdateStarGiftPriceError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.updateStarGiftResellPrice(reference: reference, price: price, id: id).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func toggleStarGiftsNotifications(enabled: Bool) {
        self.impl.with { impl in
            impl.toggleStarGiftsNotifications(enabled: enabled)
        }
    }
    
    public func updateFilter(_ filter: ProfileGiftsContext.Filters) {
        self.impl.with { impl in
            impl.updateFilter(filter)
        }
    }
    
    public func updateSorting(_ sorting: ProfileGiftsContext.Sorting) {
        self.impl.with { impl in
            impl.updateSorting(sorting)
        }
    }
    
    public var currentState: ProfileGiftsContext.State? {
        var state: ProfileGiftsContext.State?
        self.impl.syncWith { impl in
            state = impl._state
        }
        return state
    }
}

extension ProfileGiftsContext.State.StarGift {
    init?(apiSavedStarGift: Api.SavedStarGift, peerId: EnginePeer.Id, transaction: Transaction) {
        switch apiSavedStarGift {
        case let .savedStarGift(flags, fromId, date, apiGift, message, msgId, savedId, convertStars, upgradeStars, canExportDate, transferStars, canTransferAt, canResaleAt, collectionIds, prepaidUpgradeHash, dropOriginalDetailsStars):
            guard let gift = StarGift(apiStarGift: apiGift) else {
                return nil
            }
            self.gift = gift
            if let fromPeerId = fromId?.peerId {
                self.fromPeer = transaction.getPeer(fromPeerId).flatMap(EnginePeer.init)
            } else {
                self.fromPeer = nil
            }
            self._fromPeerId = self.fromPeer?.id
            self.date = date

            if let message {
                switch message {
                case let .textWithEntities(text, entities):
                    self.text = text
                    self.entities = messageTextEntitiesFromApiEntities(entities)
                }
            } else {
                self.text = nil
                self.entities = nil
            }
            if let savedId {
                self.reference = .peer(peerId: peerId, id: savedId)
            } else if let msgId {
                if let fromPeer = self.fromPeer {
                    self.reference = .message(messageId: EngineMessage.Id(peerId: fromPeer.id, namespace: Namespaces.Message.Cloud, id: msgId))
                } else if case .unique = gift {
                    self.reference = .message(messageId: EngineMessage.Id(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: msgId))
                } else {
                    self.reference = nil
                }
            } else {
                self.reference = nil
            }
            self.nameHidden = (flags & (1 << 0)) != 0
            self.savedToProfile = (flags & (1 << 5)) == 0
            self.pinnedToTop = (flags & (1 << 12)) != 0
            self.convertStars = convertStars
            self.canUpgrade = (flags & (1 << 10)) != 0
            self.canExportDate = canExportDate
            self.upgradeStars = upgradeStars
            self.transferStars = transferStars
            self.canTransferDate = canTransferAt
            self.canResaleDate = canResaleAt
            self.collectionIds = collectionIds
            self.prepaidUpgradeHash = prepaidUpgradeHash
            self.upgradeSeparate = (flags & (1 << 17)) != 0
            self.dropOriginalDetailsStars = dropOriginalDetailsStars
        }
    }
}

extension StarGift.UniqueGift.Attribute {
    init?(apiAttribute: Api.StarGiftAttribute) {
        switch apiAttribute {
        case let .starGiftAttributeModel(name, document, rarityPermille):
            guard let file = telegramMediaFileFromApiDocument(document, altDocuments: nil) else {
                return nil
            }
            self = .model(name: name, file: file, rarity: rarityPermille)
        case let .starGiftAttributePattern(name, document, rarityPermille):
            guard let file = telegramMediaFileFromApiDocument(document, altDocuments: nil) else {
                return nil
            }
            self = .pattern(name: name, file: file, rarity: rarityPermille)
        case let .starGiftAttributeBackdrop(name, id, centerColor, edgeColor, patternColor, textColor, rarityPermille):
            self = .backdrop(name: name, id: id, innerColor: centerColor, outerColor: edgeColor, patternColor: patternColor, textColor: textColor, rarity: rarityPermille)
        case let .starGiftAttributeOriginalDetails(_, sender, recipient, date, message):
            var text: String?
            var entities: [MessageTextEntity]?
            if case let .textWithEntities(textValue, entitiesValue) = message {
                text = textValue
                entities = messageTextEntitiesFromApiEntities(entitiesValue)
            }
            self = .originalInfo(senderPeerId: sender?.peerId, recipientPeerId: recipient.peerId, date: date, text: text, entities: entities)
        }
    }
}


func _internal_getUniqueStarGift(account: Account, slug: String) -> Signal<StarGift.UniqueGift?, NoError> {
    return account.network.request(Api.functions.payments.getUniqueStarGift(slug: slug))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.UniqueStarGift?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<StarGift.UniqueGift?, NoError> in
        if let result = result {
            switch result {
            case let .uniqueStarGift(gift, chats, users):
                return account.postbox.transaction { transaction in
                    let parsedPeers = AccumulatedPeers(chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                    guard case let .unique(uniqueGift) = StarGift(apiStarGift: gift) else {
                        return nil
                    }
                    return uniqueGift
                }
            }
        } else {
            return .single(nil)
        }
    }
}

func _internal_getUniqueStarGiftValueInfo(account: Account, slug: String) -> Signal<StarGift.UniqueGift.ValueInfo?, NoError> {
    return account.network.request(Api.functions.payments.getUniqueStarGiftValueInfo(slug: slug))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.UniqueStarGiftValueInfo?, NoError> in
        return .single(nil)
    }
    |> map { result -> StarGift.UniqueGift.ValueInfo? in
        if let result {
            switch result {
            case let .uniqueStarGiftValueInfo(flags, currency, value, initialSaleDate, initialSaleStars, initialSalePrice, lastSaleDate, lastSalePrice, floorPrice, averagePrice, listedCount, fragmentListedCount, fragmentListedUrl):
                let _ = listedCount
                let _ = fragmentListedCount
                return StarGift.UniqueGift.ValueInfo(
                    isLastSaleOnFragment: flags & (1 << 1) != 0,
                    valueIsAverage: flags & (1 << 6) != 0,
                    value: value,
                    currency: currency,
                    initialSaleDate: initialSaleDate,
                    initialSaleStars: initialSaleStars,
                    initialSalePrice: initialSalePrice,
                    lastSaleDate: lastSaleDate,
                    lastSalePrice: lastSalePrice,
                    floorPrice: floorPrice,
                    averagePrice: averagePrice,
                    listedCount: listedCount,
                    fragmentListedCount: fragmentListedCount,
                    fragmentListedUrl: fragmentListedUrl
                )
            }
        } else {
            return nil
        }
    }
}

public enum StarGiftReference: Equatable, Hashable, Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case messageId
        case peerId
        case id
        case slug
    }
    
    case message(messageId: EngineMessage.Id)
    case peer(peerId: EnginePeer.Id, id: Int64)
    case slug(slug: String)
    
    public enum DecodingError: Error {
        case generic
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(Int32.self, forKey: .type)
        switch type {
        case 0:
            self = .message(messageId: try container.decode(EngineMessage.Id.self, forKey: .messageId))
        case 1:
            self = .peer(peerId: try container.decode(EnginePeer.Id.self, forKey: .peerId), id: try container.decode(Int64.self, forKey: .id))
        case 2:
            self = .slug(slug: try container.decode(String.self, forKey: .slug))
        default:
            throw DecodingError.generic
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .message(messageId):
            try container.encode(0 as Int32, forKey: .type)
            try container.encode(messageId, forKey: .messageId)
        case let .peer(peerId, id):
            try container.encode(1 as Int32, forKey: .type)
            try container.encode(peerId, forKey: .peerId)
            try container.encode(id, forKey: .id)
        case let .slug(slug):
            try container.encode(2 as Int32, forKey: .type)
            try container.encode(slug, forKey: .slug)
        }
    }
}

extension StarGiftReference {
    func apiStarGiftReference(transaction: Transaction) -> Api.InputSavedStarGift? {
        switch self {
        case let .message(messageId):
            return .inputSavedStarGiftUser(msgId: messageId.id)
        case let .peer(peerId, id):
            guard let inputPeer = transaction.getPeer(peerId).flatMap({ apiInputPeer($0) }) else {
                return nil
            }
            return .inputSavedStarGiftChat(peer: inputPeer, savedId: id)
        case let .slug(slug):
            return .inputSavedStarGiftSlug(slug: slug)
        }
    }
}


public enum RequestStarGiftWithdrawalError : Equatable {
    case generic
    case twoStepAuthMissing
    case twoStepAuthTooFresh(Int32)
    case authSessionTooFresh(Int32)
    case limitExceeded
    case requestPassword
    case invalidPassword
    case serverProvided(text: String)
}

func _internal_checkStarGiftWithdrawalAvailability(account: Account, reference: StarGiftReference) -> Signal<Never, RequestStarGiftWithdrawalError> {
    return account.postbox.transaction { transaction in
        return reference.apiStarGiftReference(transaction: transaction)
    }
    |> castError(RequestStarGiftWithdrawalError.self)
    |> mapToSignal { starGift in
        guard let starGift else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.payments.getStarGiftWithdrawalUrl(stargift: starGift, password: .inputCheckPasswordEmpty))
        |> mapError { error -> RequestStarGiftWithdrawalError in
            if error.errorDescription == "PASSWORD_HASH_INVALID" {
                return .requestPassword
            } else if error.errorDescription == "PASSWORD_MISSING" {
                return .twoStepAuthMissing
            } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                if let value = Int32(timeout) {
                    return .twoStepAuthTooFresh(value)
                }
            } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                if let value = Int32(timeout) {
                    return .authSessionTooFresh(value)
                }
            }
            return .generic
        }
        |> ignoreValues
    }
}

func _internal_requestStarGiftWithdrawalUrl(account: Account, reference: StarGiftReference, password: String) -> Signal<String, RequestStarGiftWithdrawalError> {
    guard !password.isEmpty else {
        return .fail(.invalidPassword)
    }
    
    return account.postbox.transaction { transaction -> Signal<String, RequestStarGiftWithdrawalError> in
        guard let starGift = reference.apiStarGiftReference(transaction: transaction) else {
            return .fail(.generic)
        }
            
        let checkPassword = _internal_twoStepAuthData(account.network)
        |> mapError { error -> RequestStarGiftWithdrawalError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .limitExceeded
            } else {
                return .generic
            }
        }
        |> mapToSignal { authData -> Signal<Api.InputCheckPasswordSRP, RequestStarGiftWithdrawalError> in
            if let currentPasswordDerivation = authData.currentPasswordDerivation, let srpSessionData = authData.srpSessionData {
                guard let kdfResult = passwordKDF(encryptionProvider: account.network.encryptionProvider, password: password, derivation: currentPasswordDerivation, srpSessionData: srpSessionData) else {
                    return .fail(.generic)
                }
                return .single(.inputCheckPasswordSRP(srpId: kdfResult.id, A: Buffer(data: kdfResult.A), M1: Buffer(data: kdfResult.M1)))
            } else {
                return .fail(.twoStepAuthMissing)
            }
        }
        
        return checkPassword
        |> mapToSignal { password -> Signal<String, RequestStarGiftWithdrawalError> in
            return account.network.request(Api.functions.payments.getStarGiftWithdrawalUrl(stargift: starGift, password: password), automaticFloodWait: false)
            |> mapError { error -> RequestStarGiftWithdrawalError in
                if error.errorCode == 406 {
                    return .serverProvided(text: error.errorDescription)
                } else if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .limitExceeded
                } else if error.errorDescription == "PASSWORD_HASH_INVALID" {
                    return .invalidPassword
                } else if error.errorDescription == "PASSWORD_MISSING" {
                    return .twoStepAuthMissing
                } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .twoStepAuthTooFresh(value)
                    }
                } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .authSessionTooFresh(value)
                    }
                }
                return .generic
            }
            |> map { result -> String in
                switch result {
                case let .starGiftWithdrawalUrl(url):
                    return url
                }
            }
        }
    }
    |> mapError { _ -> RequestStarGiftWithdrawalError in }
    |> switchToLatest
}

func _internal_toggleStarGiftsNotifications(account: Account, peerId: EnginePeer.Id, enabled: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer in
        guard let inputPeer else {
            return .complete()
        }
        var flags: Int32 = 0
        if enabled {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.payments.toggleChatStarGiftNotifications(flags: flags, peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> ignoreValues
    }
}

func _internal_updateStarGiftResalePrice(account: Account, reference: StarGiftReference, price: CurrencyAmount?) -> Signal<Never, UpdateStarGiftPriceError> {
    return account.postbox.transaction { transaction in
        return reference.apiStarGiftReference(transaction: transaction)
    }
    |> castError(UpdateStarGiftPriceError.self)
    |> mapToSignal { starGift in
        guard let starGift else {
            return .complete()
        }
        let apiAmount = (price ?? CurrencyAmount(amount: .zero, currency: .stars)).apiAmount
        return account.network.request(Api.functions.payments.updateStarGiftPrice(stargift: starGift, resellAmount: apiAmount))
        |> mapError { error -> UpdateStarGiftPriceError in
            if error.errorDescription.hasPrefix("STARGIFT_RESELL_TOO_EARLY_") {
                let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "STARGIFT_RESELL_TOO_EARLY_".count)...])
                if let value = Int32(timeout) {
                    return .starGiftResellTooEarly(value)
                }
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<Void, UpdateStarGiftPriceError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
        |> ignoreValues
    }
}

public extension StarGift.UniqueGift {
    var itemFile: TelegramMediaFile? {
        for attribute in self.attributes {
            if case let .model(_, file, _) = attribute {
                return file
            }
        }
        return nil
    }
}

private final class ResaleGiftsContextImpl {
    private let queue: Queue
    private let account: Account
    private let giftId: Int64
    
    private let disposable = MetaDisposable()
    
    private var sorting: ResaleGiftsContext.Sorting = .value
    private var filterAttributes: [ResaleGiftsContext.Attribute] = []
    
    private var gifts: [StarGift] = []
    private var attributes: [StarGift.UniqueGift.Attribute] = []
    private var attributeCount: [ResaleGiftsContext.Attribute: Int32] = [:]
    private var attributesHash: Int64?
 
    private var count: Int32?
    private var dataState: ResaleGiftsContext.State.DataState = .ready(canLoadMore: true, nextOffset: nil)
        
    var _state: ResaleGiftsContext.State?
    private let stateValue = Promise<ResaleGiftsContext.State>()
    var state: Signal<ResaleGiftsContext.State, NoError> {
        return self.stateValue.get()
    }
    
    init(
        queue: Queue,
        account: Account,
        giftId: Int64
    ) {
        self.queue = queue
        self.account = account
        self.giftId = giftId
        
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func reload() {
        self.gifts = []
        self.dataState = .ready(canLoadMore: true, nextOffset: nil)
        self.loadMore(reload: true)
    }
    
    func loadMore(reload: Bool = false) {
        let giftId = self.giftId
        let accountPeerId = self.account.peerId
        let network = self.account.network
        let postbox = self.account.postbox
        let sorting = self.sorting
        let filterAttributes = self.filterAttributes
        let currentAttributesHash = self.attributesHash
        
        let dataState = self.dataState
        
        if case let .ready(true, initialNextOffset) = dataState {
            self.dataState = .loading
            if !reload {
                self.pushState()
            }
            
            var flags: Int32 = 0
            switch sorting {
            case .date:
                break
            case .value:
                flags |= (1 << 1)
            case .number:
                flags |= (1 << 2)
            }
          
            var apiAttributes: [Api.StarGiftAttributeId]?
            if !filterAttributes.isEmpty {
                flags |= (1 << 3)
                apiAttributes = filterAttributes.map {
                    switch $0 {
                    case let .model(id):
                        return .starGiftAttributeIdModel(documentId: id)
                    case let .pattern(id):
                        return .starGiftAttributeIdPattern(documentId: id)
                    case let .backdrop(id):
                        return .starGiftAttributeIdBackdrop(backdropId: id)
                    }
                }
            }
                        
            let attributesHash = currentAttributesHash ?? 0
            flags |= (1 << 0)
            
            let signal = network.request(Api.functions.payments.getResaleStarGifts(flags: flags, attributesHash: attributesHash, giftId: giftId, attributes: apiAttributes, offset: initialNextOffset ?? "", limit: 36))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.payments.ResaleStarGifts?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<([StarGift], [StarGift.UniqueGift.Attribute]?, [ResaleGiftsContext.Attribute: Int32]?, Int64?, Int32, String?), NoError> in
                guard let result else {
                    return .single(([], nil, nil, nil, 0, nil))
                }
                return postbox.transaction { transaction -> ([StarGift], [StarGift.UniqueGift.Attribute]?, [ResaleGiftsContext.Attribute: Int32]?, Int64?, Int32, String?) in
                    switch result {
                    case let .resaleStarGifts(_, count, gifts, nextOffset, attributes, attributesHash, chats, counters, users):
                        let _ = attributesHash

                        var resultAttributes: [StarGift.UniqueGift.Attribute]?
                        if let attributes {
                            resultAttributes = attributes.compactMap { StarGift.UniqueGift.Attribute(apiAttribute: $0) }
                        }
                        
                        var attributeCount: [ResaleGiftsContext.Attribute: Int32]?
                        if let counters {
                            var attributeCountValue: [ResaleGiftsContext.Attribute: Int32] = [:]
                            for counter in counters {
                                switch counter {
                                case let .starGiftAttributeCounter(attribute, count):
                                    switch attribute {
                                    case let .starGiftAttributeIdModel(documentId):
                                        attributeCountValue[.model(documentId)] = count
                                    case let .starGiftAttributeIdPattern(documentId):
                                        attributeCountValue[.pattern(documentId)] = count
                                    case let .starGiftAttributeIdBackdrop(backdropId):
                                        attributeCountValue[.backdrop(backdropId)] = count
                                    }
                                }
                            }
                            attributeCount = attributeCountValue
                        }
                        
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        
                        var mappedGifts: [StarGift] = []
                        for gift in gifts {
                            if let mappedGift = StarGift(apiStarGift: gift), case let .unique(uniqueGift) = mappedGift, let resellAmount = uniqueGift.resellAmounts?.first, resellAmount.amount.value > 0 {
                                mappedGifts.append(mappedGift)
                            }
                        }

                        return (mappedGifts, resultAttributes, attributeCount, attributesHash, count, nextOffset)
                    }
                }
            }
        
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] (gifts, attributes, attributeCount, attributesHash, count, nextOffset) in
                guard let self else {
                    return 
                }
                if initialNextOffset == nil || reload {
                    self.gifts = gifts
                } else {
                    self.gifts.append(contentsOf: gifts)
                }
                
                let updatedCount = max(Int32(self.gifts.count), count)
                self.count = updatedCount
                
                if let attributes, let attributeCount, let attributesHash {
                    self.attributes = attributes
                    self.attributeCount = attributeCount
                    self.attributesHash = attributesHash
                }
                
                self.dataState = .ready(canLoadMore: count != 0 && updatedCount > self.gifts.count && nextOffset != nil, nextOffset: nextOffset)
            
                self.pushState()
            }))
        }
    }
    
    func updateFilterAttributes(_ filterAttributes: [ResaleGiftsContext.Attribute]) {
        guard self.filterAttributes != filterAttributes else {
            return
        }
        self.filterAttributes = filterAttributes
        self.dataState = .ready(canLoadMore: true, nextOffset: nil)
        self.pushState()
        
        self.loadMore()
    }
    
    func removeStarGift(gift: TelegramCore.StarGift) {
        self.gifts.removeAll(where: { $0 == gift })
        self.pushState()
    }
    
    func updateSorting(_ sorting: ResaleGiftsContext.Sorting) {
        guard self.sorting != sorting else {
            return
        }
        self.sorting = sorting
        self.dataState = .ready(canLoadMore: true, nextOffset: nil)
        self.pushState()
        
        self.loadMore()
    }
    
    func buyStarGift(slug: String, peerId: EnginePeer.Id, price: CurrencyAmount?) -> Signal<Never, BuyStarGiftError> {
        var listingPrice: CurrencyAmount?
        if let gift = self.gifts.first(where: { gift in
            if case let .unique(uniqueGift) = gift, uniqueGift.slug == slug {
                return true
            }
            return false
        }), case let .unique(uniqueGift) = gift {
            listingPrice = uniqueGift.resellAmounts?.first(where: { $0.currency == .stars })
        }
        
        return _internal_buyStarGift(account: self.account, slug: slug, peerId: peerId, price: price ?? listingPrice)
        |> afterCompleted { [weak self] in
            guard let self else {
                return
            }
            self.queue.async {
                if let count = self.count {
                    self.count = max(0, count - 1)
                }
                self.gifts.removeAll(where: { gift in
                    if case let .unique(uniqueGift) = gift, uniqueGift.slug == slug {
                        return true
                    }
                    return false
                })
                self.pushState()
            }
        }
    }
    
    func updateStarGiftResellPrice(slug: String, price: CurrencyAmount?) -> Signal<Never, UpdateStarGiftPriceError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            let disposable = MetaDisposable()
            disposable.set(
                (_internal_updateStarGiftResalePrice(
                    account: self.account,
                    reference: .slug(slug: slug),
                    price: price
                )
                |> deliverOn(self.queue)).startStrict(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    if let index = self.gifts.firstIndex(where: { gift in
                        if case let .unique(uniqueGift) = gift, uniqueGift.slug == slug {
                            return true
                        }
                        return false
                    }) {
                        if let price {
                            if case let .unique(uniqueGift) = self.gifts[index] {
                                self.gifts[index] = .unique(uniqueGift.withResellAmounts([price]).withResellForTonOnly(price.currency == .ton))
                            }
                        } else {
                            self.gifts.remove(at: index)
                        }
                    }
                    
                    self.pushState()
                    
                    subscriber.putCompletion()
                })
            )
            return disposable
        }
    }
        
    private func pushState() {
        let state = ResaleGiftsContext.State(
            sorting: self.sorting,
            filterAttributes: self.filterAttributes,
            gifts: self.gifts,
            attributes: self.attributes,
            attributeCount: self.attributeCount,
            count: self.count,
            dataState: self.dataState
        )
        self._state = state
        self.stateValue.set(.single(state))
    }
}

public final class ResaleGiftsContext {
    public enum Sorting: Equatable {
        case date
        case value
        case number
    }
    
    public enum Attribute: Equatable, Hashable {
        case model(Int64)
        case pattern(Int64)
        case backdrop(Int32)
    }
    
    public struct State: Equatable {
        public enum DataState: Equatable {
            case loading
            case ready(canLoadMore: Bool, nextOffset: String?)
        }
        
        public var sorting: Sorting
        public var filterAttributes: [Attribute]
        public var gifts: [StarGift]
        public var attributes: [StarGift.UniqueGift.Attribute]
        public var attributeCount: [Attribute: Int32]
        public var count: Int32?
        public var dataState: ResaleGiftsContext.State.DataState
    }
    
    private let queue: Queue = .mainQueue()
    private let impl: QueueLocalObject<ResaleGiftsContextImpl>
    
    public var state: Signal<ResaleGiftsContext.State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            
            return disposable
        }
    }
    
    public init(
        account: Account,
        giftId: Int64
    ) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ResaleGiftsContextImpl(queue: queue, account: account, giftId: giftId)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    public func updateSorting(_ sorting: ResaleGiftsContext.Sorting) {
        self.impl.with { impl in
            impl.updateSorting(sorting)
        }
    }
    
    public func updateFilterAttributes(_ attributes: [ResaleGiftsContext.Attribute]) {
        self.impl.with { impl in
            impl.updateFilterAttributes(attributes)
        }
    }
    
    public func buyStarGift(slug: String, peerId: EnginePeer.Id, price: CurrencyAmount? = nil) -> Signal<Never, BuyStarGiftError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.buyStarGift(slug: slug, peerId: peerId, price: price).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func updateStarGiftResellPrice(slug: String, price: CurrencyAmount?) -> Signal<Never, UpdateStarGiftPriceError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.updateStarGiftResellPrice(slug: slug, price: price).start(error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func removeStarGift(gift: TelegramCore.StarGift) {
        self.impl.with { impl in
            impl.removeStarGift(gift: gift)
        }
    }
  

    public var currentState: ResaleGiftsContext.State? {
        var state: ResaleGiftsContext.State?
        self.impl.syncWith { impl in
            state = impl._state
        }
        return state
    }
}
