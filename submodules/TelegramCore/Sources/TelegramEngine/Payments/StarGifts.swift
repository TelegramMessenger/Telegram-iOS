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
        }
        
        enum CodingKeys: String, CodingKey {
            case id
            case file
            case price
            case convertStars
            case availability
            case soldOut
            case flags
            case upgradeStars
        }
        
        public struct Availability: Equatable, Codable, PostboxCoding {
            enum CodingKeys: String, CodingKey {
                case remains
                case total
            }

            public let remains: Int32
            public let total: Int32
            
            public init(remains: Int32, total: Int32) {
                self.remains = remains
                self.total = total
            }
            
            public init(decoder: PostboxDecoder) {
                self.remains = decoder.decodeInt32ForKey(CodingKeys.remains.rawValue, orElse: 0)
                self.total = decoder.decodeInt32ForKey(CodingKeys.total.rawValue, orElse: 0)
            }
            
            public func encode(_ encoder: PostboxEncoder) {
                encoder.encodeInt32(self.remains, forKey: CodingKeys.remains.rawValue)
                encoder.encodeInt32(self.total, forKey: CodingKeys.total.rawValue)
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
        
        public enum DecodingError: Error {
            case generic
        }
        
        public let id: Int64
        public let file: TelegramMediaFile
        public let price: Int64
        public let convertStars: Int64
        public let availability: Availability?
        public let soldOut: SoldOut?
        public let flags: Flags
        public let upgradeStars: Int64?
        
        public init(id: Int64, file: TelegramMediaFile, price: Int64, convertStars: Int64, availability: Availability?, soldOut: SoldOut?, flags: Flags, upgradeStars: Int64?) {
            self.id = id
            self.file = file
            self.price = price
            self.convertStars = convertStars
            self.availability = availability
            self.soldOut = soldOut
            self.flags = flags
            self.upgradeStars = upgradeStars
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(Int64.self, forKey: .id)
            
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
        }
        
        public init(decoder: PostboxDecoder) {
            self.id = decoder.decodeInt64ForKey(CodingKeys.id.rawValue, orElse: 0)
            self.file = decoder.decodeObjectForKey(CodingKeys.file.rawValue) as! TelegramMediaFile
            self.price = decoder.decodeInt64ForKey(CodingKeys.price.rawValue, orElse: 0)
            self.convertStars = decoder.decodeInt64ForKey(CodingKeys.convertStars.rawValue, orElse: 0)
            self.availability = decoder.decodeObjectForKey(CodingKeys.availability.rawValue, decoder: { StarGift.Gift.Availability(decoder: $0) }) as? StarGift.Gift.Availability
            self.soldOut = decoder.decodeObjectForKey(CodingKeys.soldOut.rawValue, decoder: { StarGift.Gift.SoldOut(decoder: $0) }) as? StarGift.Gift.SoldOut
            self.flags = Flags(rawValue: decoder.decodeInt32ForKey(CodingKeys.flags.rawValue, orElse: 0))
            self.upgradeStars = decoder.decodeOptionalInt64ForKey(CodingKeys.upgradeStars.rawValue)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
        
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
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.id, forKey: CodingKeys.id.rawValue)
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
        }
    }
    
    public struct UniqueGift: Equatable, Codable, PostboxCoding {
        enum CodingKeys: String, CodingKey {
            case id
            case title
            case number
            case slug
            case ownerPeerId
            case ownerName
            case ownerAddress
            case attributes
            case availability
            case giftAddress
        }
        
        public enum Attribute: Equatable, Codable, PostboxCoding {
            enum CodingKeys: String, CodingKey {
                case type
                case name
                case file
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
            case backdrop(name: String, innerColor: Int32, outerColor: Int32, patternColor: Int32, textColor: Int32, rarity: Int32)
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
                case let .backdrop(name, innerColor, outerColor, patternColor, textColor, rarity):
                    try container.encode(Int32(2), forKey: .type)
                    try container.encode(name, forKey: .name)
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
                case let .backdrop(name, innerColor, outerColor, patternColor, textColor, rarity):
                    encoder.encodeInt32(2, forKey: CodingKeys.type.rawValue)
                    encoder.encodeString(name, forKey: CodingKeys.name.rawValue)
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
        }
                
        public enum DecodingError: Error {
            case generic
        }
        
        public let id: Int64
        public let title: String
        public let number: Int32
        public let slug: String
        public let owner: Owner
        public let attributes: [Attribute]
        public let availability: Availability
        public let giftAddress: String?
        
        public init(id: Int64, title: String, number: Int32, slug: String, owner: Owner, attributes: [Attribute], availability: Availability, giftAddress: String?) {
            self.id = id
            self.title = title
            self.number = number
            self.slug = slug
            self.owner = owner
            self.attributes = attributes
            self.availability = availability
            self.giftAddress = giftAddress
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(Int64.self, forKey: .id)
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
        }
        
        public init(decoder: PostboxDecoder) {
            self.id = decoder.decodeInt64ForKey(CodingKeys.id.rawValue, orElse: 0)
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
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
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
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.id, forKey: CodingKeys.id.rawValue)
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

extension StarGift {
    init?(apiStarGift: Api.StarGift) {
        switch apiStarGift {
        case let .starGift(apiFlags, id, sticker, stars, availabilityRemains, availabilityTotal, convertStars, firstSale, lastSale, upgradeStars):
            var flags = StarGift.Gift.Flags()
            if (apiFlags & (1 << 2)) != 0 {
                flags.insert(.isBirthdayGift)
            }
            
            var availability: StarGift.Gift.Availability?
            if let availabilityRemains, let availabilityTotal {
                availability = StarGift.Gift.Availability(remains: availabilityRemains, total: availabilityTotal)
            }
            var soldOut: StarGift.Gift.SoldOut?
            if let firstSale, let lastSale {
                soldOut = StarGift.Gift.SoldOut(firstSale: firstSale, lastSale: lastSale)
            }
            guard let file = telegramMediaFileFromApiDocument(sticker, altDocuments: nil) else {
                return nil
            }
            self = .generic(StarGift.Gift(id: id, file: file, price: stars, convertStars: convertStars, availability: availability, soldOut: soldOut, flags: flags, upgradeStars: upgradeStars))
        case let .starGiftUnique(_, id, title, slug, num, ownerPeerId, ownerName, ownerAddress, attributes, availabilityIssued, availabilityTotal, giftAddress):
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
            self = .unique(StarGift.UniqueGift(id: id, title: title, number: num, slug: slug, owner: owner, attributes: attributes.compactMap { UniqueGift.Attribute(apiAttribute: $0) }, availability: UniqueGift.Availability(issued: availabilityIssued, total: availabilityTotal), giftAddress: giftAddress))
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

func _internal_keepCachedStarGiftsUpdated(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let updateSignal = _internal_cachedStarGifts(postbox: postbox)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        return network.request(Api.functions.payments.getStarGifts(hash: 0))
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
                case let .starGifts(hash, gifts):
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

func managedStarGiftsUpdates(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = _internal_keepCachedStarGiftsUpdated(postbox: postbox, network: network)
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
            |> mapError { _ -> TransferStarGiftError in
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

public enum UpgradeStarGiftError {
    case generic
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
                                if let action = media as? TelegramMediaAction, case let .starGiftUnique(gift, _, _, savedToProfile, canExportDate, transferStars, _, peerId, _, savedId) = action.action, case let .Id(messageId) = message.id {
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
                                        transferStars: transferStars
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

func _internal_starGiftUpgradePreview(account: Account, giftId: Int64) -> Signal<[StarGift.UniqueGift.Attribute], NoError> {
    return account.network.request(Api.functions.payments.getStarGiftUpgradePreview(giftId: giftId))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.payments.StarGiftUpgradePreview?, NoError> in
        return .single(nil)
    }
    |> map { result in
        guard let result else {
            return []
        }
        switch result {
        case let .starGiftUpgradePreview(sampleAttributes):
            return sampleAttributes.compactMap { StarGift.UniqueGift.Attribute(apiAttribute: $0) }
        }
    }
}

private final class CachedProfileGifts: Codable {
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

private func entryId(peerId: EnginePeer.Id) -> ItemCacheEntryId {
    let cacheKey = ValueBoxKey(length: 8)
    cacheKey.setInt64(0, value: peerId.toInt64())
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedProfileGifts, key: cacheKey)
}

private final class ProfileGiftsContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    
    private let disposable = MetaDisposable()
    private let cacheDisposable = MetaDisposable()
    private let actionDisposable = MetaDisposable()
    
    private var sorting: ProfileGiftsContext.Sorting = .date
    private var filter: ProfileGiftsContext.Filters = ProfileGiftsContext.Filters.All
    
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
    
    init(queue: Queue, account: Account, peerId: EnginePeer.Id) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        
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
        let accountPeerId = self.account.peerId
        let network = self.account.network
        let postbox = self.account.postbox
        let filter = self.filter
        let sorting = self.sorting
        
        let isFiltered = self.filter != .All || self.sorting != .date
        if !isFiltered {
            self.filteredGifts = []
            self.filteredCount = nil
        }
        let dataState = isFiltered ? self.filteredDataState : self.dataState
        
        if case let .ready(true, initialNextOffset) = dataState {
            if !isFiltered, self.gifts.isEmpty, initialNextOffset == nil, !reload {
                self.cacheDisposable.set((self.account.postbox.transaction { transaction -> CachedProfileGifts? in
                    let cachedGifts = transaction.retrieveItemCacheEntry(id: entryId(peerId: peerId))?.get(CachedProfileGifts.self)
                    cachedGifts?.render(transaction: transaction)
                    return cachedGifts
                } |> deliverOn(self.queue)).start(next: { [weak self] cachedGifts in
                    guard let self, let cachedGifts else {
                        return
                    }
                    if case .loading = self.dataState {
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
                if case .value = sorting {
                    flags |= (1 << 5)
                }
                if !filter.contains(.hidden) {
                    flags |= (1 << 0)
                }
                if !filter.contains(.displayed) {
                    flags |= (1 << 1)
                }
                if !filter.contains(.unlimited) {
                    flags |= (1 << 2)
                }
                if !filter.contains(.limited) {
                    flags |= (1 << 3)
                }
                if !filter.contains(.unique) {
                    flags |= (1 << 4)
                }
                return network.request(Api.functions.payments.getSavedStarGifts(flags: flags, peer: inputPeer, offset: initialNextOffset ?? "", limit: 32))
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
                        for gift in gifts {
                            self.filteredGifts.append(gift)
                        }
                    }
                    
                    let updatedCount = max(Int32(self.filteredGifts.count), count)
                    self.filteredCount = updatedCount
                    self.filteredDataState = .ready(canLoadMore: count != 0 && updatedCount > self.filteredGifts.count && nextOffset != nil, nextOffset: nextOffset)
                } else {
                    if initialNextOffset == nil || reload {
                        self.gifts = gifts
                        self.cacheDisposable.set(self.account.postbox.transaction { transaction in
                            if let entry = CodableEntry(CachedProfileGifts(gifts: gifts, count: count, notificationsEnabled: notificationsEnabled)) {
                                transaction.putItemCacheEntry(id: entryId(peerId: peerId), entry: entry)
                            }
                        }.start())
                    } else {
                        for gift in gifts {
                            self.gifts.append(gift)
                        }
                    }
                    
                    let updatedCount = max(Int32(self.gifts.count), count)
                    self.count = updatedCount
                    self.dataState = .ready(canLoadMore: count != 0 && updatedCount > self.gifts.count && nextOffset != nil, nextOffset: nextOffset)
                }
                
                self.notificationsEnabled = notificationsEnabled
                self.pushState()
            }))
        }
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
    
    func transferStarGift(prepaid: Bool, reference: StarGiftReference, peerId: EnginePeer.Id) {
        self.actionDisposable.set(
            _internal_transferStarGift(account: self.account, prepaid: prepaid, reference: reference, peerId: peerId).startStrict()
        )
        if let count = self.count {
            self.count = max(0, count - 1)
        }
        self.gifts.removeAll(where: { $0.reference == reference })
        self.filteredGifts.removeAll(where: { $0.reference == reference })
        self.pushState()
    }
    
    func upgradeStarGift(formId: Int64?, reference: StarGiftReference, keepOriginalInfo: Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            let disposable = MetaDisposable()
            disposable.set(
                _internal_upgradeStarGift(account: self.account, formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo).startStrict(next: { [weak self] result in
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
        public static let limited = Filters(rawValue: 1 << 1)
        public static let unique = Filters(rawValue: 1 << 2)
        public static let displayed = Filters(rawValue: 1 << 3)
        public static let hidden = Filters(rawValue: 1 << 4)
        
        public static var All: Filters {
            return [.unlimited, .limited, .unique, .displayed, .hidden]
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
                transferStars: Int64?
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
                    transferStars: self.transferStars
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
                    transferStars: self.transferStars
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
                    transferStars: self.transferStars
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
    
    public init(account: Account, peerId: EnginePeer.Id) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ProfileGiftsContextImpl(queue: queue, account: account, peerId: peerId)
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
    
    public func convertStarGift(reference: StarGiftReference) {
        self.impl.with { impl in
            impl.convertStarGift(reference: reference)
        }
    }
    
    public func transferStarGift(prepaid: Bool, reference: StarGiftReference, peerId: EnginePeer.Id) {
        self.impl.with { impl in
            impl.transferStarGift(prepaid: prepaid, reference: reference, peerId: peerId)
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
        case let .savedStarGift(flags, fromId, date, apiGift, message, msgId, savedId, convertStars, upgradeStars, canExportDate, transferStars):
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
        case let .starGiftAttributeBackdrop(name, centerColor, edgeColor, patternColor, textColor, rarityPermille):
            self = .backdrop(name: name, innerColor: centerColor, outerColor: edgeColor, patternColor: patternColor, textColor: textColor, rarity: rarityPermille)
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
            case let .uniqueStarGift(gift, users):
                return account.postbox.transaction { transaction in
                    let parsedPeers = AccumulatedPeers(users: users)
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

public enum StarGiftReference: Equatable, Hashable, Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case messageId
        case peerId
        case id
    }
    
    case message(messageId: EngineMessage.Id)
    case peer(peerId: EnginePeer.Id, id: Int64)
    
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
