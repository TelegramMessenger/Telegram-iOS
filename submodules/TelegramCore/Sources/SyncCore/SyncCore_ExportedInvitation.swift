import Postbox

public struct ExportedInvitation: Codable, Equatable {
    public let link: String
    public let title: String?
    public let isPermanent: Bool
    public let requestApproval: Bool
    public let isRevoked: Bool
    public let adminId: PeerId
    public let date: Int32
    public let startDate: Int32?
    public let expireDate: Int32?
    public let usageLimit: Int32?
    public let count: Int32?
    public let requestedCount: Int32?
    
    public init(link: String, title: String?, isPermanent: Bool, requestApproval: Bool, isRevoked: Bool, adminId: PeerId, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, count: Int32?, requestedCount: Int32?) {
        self.link = link
        self.title = title
        self.isPermanent = isPermanent
        self.requestApproval = requestApproval
        self.isRevoked = isRevoked
        self.adminId = adminId
        self.date = date
        self.startDate = startDate
        self.expireDate = expireDate
        self.usageLimit = usageLimit
        self.count = count
        self.requestedCount = requestedCount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.link = try container.decode(String.self, forKey: "l")
        self.title = try container.decodeIfPresent(String.self, forKey: "title")
        self.isPermanent = try container.decode(Bool.self, forKey: "permanent")
        self.requestApproval = try container.decodeIfPresent(Bool.self, forKey: "requestApproval") ?? false
        self.isRevoked = try container.decode(Bool.self, forKey: "revoked")
        self.adminId = PeerId(try container.decode(Int64.self, forKey: "adminId"))
        self.date = try container.decode(Int32.self, forKey: "date")
        self.startDate = try container.decodeIfPresent(Int32.self, forKey: "startDate")
        self.expireDate = try container.decodeIfPresent(Int32.self, forKey: "expireDate")
        self.usageLimit = try container.decodeIfPresent(Int32.self, forKey: "usageLimit")
        self.count = try container.decodeIfPresent(Int32.self, forKey: "count")
        self.requestedCount = try? container.decodeIfPresent(Int32.self, forKey: "requestedCount")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.link, forKey: "l")
        try container.encodeIfPresent(self.title, forKey: "title")
        try container.encode(self.isPermanent, forKey: "permanent")
        try container.encode(self.requestApproval, forKey: "requestApproval")
        try container.encode(self.isRevoked, forKey: "revoked")
        try container.encode(self.adminId.toInt64(), forKey: "adminId")
        try container.encode(self.date, forKey: "date")
        try container.encodeIfPresent(self.startDate, forKey: "startDate")
        try container.encodeIfPresent(self.expireDate, forKey: "expireDate")
        try container.encodeIfPresent(self.usageLimit, forKey: "usageLimit")
        try container.encodeIfPresent(self.count, forKey: "count")
        try container.encodeIfPresent(self.requestedCount, forKey: "requestedCount")
    }
    
    public static func ==(lhs: ExportedInvitation, rhs: ExportedInvitation) -> Bool {
        return lhs.link == rhs.link && lhs.title == rhs.title && lhs.isPermanent == rhs.isPermanent && lhs.requestApproval == rhs.requestApproval && lhs.isRevoked == rhs.isRevoked && lhs.adminId == rhs.adminId && lhs.date == rhs.date && lhs.startDate == rhs.startDate && lhs.expireDate == rhs.expireDate && lhs.usageLimit == rhs.usageLimit && lhs.count == rhs.count && lhs.requestedCount == rhs.requestedCount
    }
    
    public func withUpdated(isRevoked: Bool) -> ExportedInvitation {
        return ExportedInvitation(link: self.link, title: self.title, isPermanent: self.isPermanent, requestApproval: self.requestApproval, isRevoked: isRevoked, adminId: self.adminId, date: self.date, startDate: self.startDate, expireDate: self.expireDate, usageLimit: self.usageLimit, count: self.count, requestedCount: self.requestedCount)
    }
}
