import Postbox

public struct ExportedInvitation: PostboxCoding, Equatable {
    public let link: String
    public let revoked: Bool
    public let adminId: PeerId
    public let date: Int32
    public let expireDate: Int32?
    public let usageLimit: Int32?
    public let count: Int32?
    
    public init(link: String, revoked: Bool, adminId: PeerId, date: Int32, expireDate: Int32?, usageLimit: Int32?, count: Int32?) {
        self.link = link
        self.revoked = revoked
        self.adminId = adminId
        self.date = date
        self.expireDate = expireDate
        self.usageLimit = usageLimit
        self.count = count
    }
    
    public init(decoder: PostboxDecoder) {
        self.link = decoder.decodeStringForKey("l", orElse: "")
        self.revoked = decoder.decodeBoolForKey("revoked", orElse: false)
        self.adminId = PeerId(decoder.decodeInt64ForKey("adminId", orElse: 0))
        self.date = decoder.decodeInt32ForKey("date", orElse: 0)
        self.expireDate = decoder.decodeOptionalInt32ForKey("expireDate")
        self.usageLimit = decoder.decodeOptionalInt32ForKey("usageLimit")
        self.count = decoder.decodeOptionalInt32ForKey("count")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.link, forKey: "l")
        encoder.encodeBool(self.revoked, forKey: "revoked")
        encoder.encodeInt64(self.adminId.toInt64(), forKey: "adminId")
        encoder.encodeInt32(self.date, forKey: "date")
        if let expireDate = self.expireDate {
            encoder.encodeInt32(expireDate, forKey: "expireDate")
        } else {
            encoder.encodeNil(forKey: "expireDate")
        }
        if let usageLimit = self.usageLimit {
            encoder.encodeInt32(usageLimit, forKey: "usageLimit")
        } else {
            encoder.encodeNil(forKey: "usageLimit")
        }
        if let count = self.count {
            encoder.encodeInt32(count, forKey: "count")
        } else {
            encoder.encodeNil(forKey: "count")
        }
    }
    
    public static func ==(lhs: ExportedInvitation, rhs: ExportedInvitation) -> Bool {
        return lhs.link == rhs.link && lhs.revoked == rhs.revoked && lhs.adminId == rhs.adminId && lhs.date == rhs.date && lhs.expireDate == rhs.expireDate && lhs.usageLimit == rhs.usageLimit && lhs.count == rhs.count
    }
}
