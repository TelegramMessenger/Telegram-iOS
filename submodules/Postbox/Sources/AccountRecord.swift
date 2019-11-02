import Foundation

public protocol AccountRecordAttribute: class, PostboxCoding {
    func isEqual(to: AccountRecordAttribute) -> Bool
}

public struct AccountRecordId: Comparable, Hashable, Codable {
    let rawValue: Int64
    
    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }
    
    public var int64: Int64 {
        return self.rawValue
    }
    
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
    
    public static func ==(lhs: AccountRecordId, rhs: AccountRecordId) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public static func <(lhs: AccountRecordId, rhs: AccountRecordId) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public func generateAccountRecordId() -> AccountRecordId {
    var id: Int64 = 0
    arc4random_buf(&id, 8)
    return AccountRecordId(rawValue: id)
}

public final class AccountRecord: PostboxCoding, Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case temporarySessionId
    }
    
    public let id: AccountRecordId
    public let attributes: [AccountRecordAttribute]
    public let temporarySessionId: Int64?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = try? container.decode(String.self, forKey: .id), let idValue = Int64(idString) {
            self.id = AccountRecordId(rawValue: idValue)
        } else {
            self.id = try container.decode(AccountRecordId.self, forKey: .id)
        }
        
        let attributesData = try container.decode(Array<Data>.self, forKey: .attributes)
        var attributes: [AccountRecordAttribute] = []
        for data in attributesData {
            if let object = PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? AccountRecordAttribute {
                attributes.append(object)
            }
        }
        self.attributes = attributes
        
        if let temporarySessionIdString = try container.decodeIfPresent(String.self, forKey: .temporarySessionId), let temporarySessionIdValue = Int64(temporarySessionIdString) {
            self.temporarySessionId = temporarySessionIdValue
        } else {
            self.temporarySessionId = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String("\(self.id.rawValue)"), forKey: .id)
        let attributesData: [Data] = self.attributes.map { attribute in
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(attribute)
            return encoder.makeData()
        }
        try container.encode(attributesData, forKey: .attributes)
        let temporarySessionIdString: String? = self.temporarySessionId.flatMap({ "\($0)" })
        try container.encodeIfPresent(temporarySessionIdString, forKey: .temporarySessionId)
    }
    
    public init(id: AccountRecordId, attributes: [AccountRecordAttribute], temporarySessionId: Int64?) {
        self.id = id
        self.attributes = attributes
        self.temporarySessionId = temporarySessionId
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = AccountRecordId(rawValue: decoder.decodeInt64ForKey("id", orElse: 0))
        self.attributes = (decoder.decodeObjectArrayForKey("attributes") as [PostboxCoding]).map { $0 as! AccountRecordAttribute }
        self.temporarySessionId = decoder.decodeOptionalInt64ForKey("temporarySessionId")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id.int64, forKey: "id")
        let attributes: [PostboxCoding] = self.attributes.map { $0 }
        encoder.encodeGenericObjectArray(attributes, forKey: "attributes")
        if let temporarySessionId = self.temporarySessionId {
            encoder.encodeInt64(temporarySessionId, forKey: "temporarySessionId")
        } else {
            encoder.encodeNil(forKey: "temporarySessionId")
        }
    }
    
    public static func ==(lhs: AccountRecord, rhs: AccountRecord) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.attributes.count != rhs.attributes.count {
            return false
        }
        for i in 0 ..< lhs.attributes.count {
            if !lhs.attributes[i].isEqual(to: rhs.attributes[i]) {
                return false
            }
        }
        if lhs.temporarySessionId != rhs.temporarySessionId {
            return false
        }
        return true
    }
}
