import Postbox

public enum ExportedInvitation: Codable, Equatable {
    case link(link: String, title: String?, isPermanent: Bool, requestApproval: Bool, isRevoked: Bool, adminId: PeerId, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, count: Int32?, requestedCount: Int32?)
    case publicJoinRequest
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let type = try container.decodeIfPresent(Int32.self, forKey: "t") ?? 0
        if type == 0 {
            let link = try container.decode(String.self, forKey: "l")
            let title = try container.decodeIfPresent(String.self, forKey: "title")
            let isPermanent = try container.decode(Bool.self, forKey: "permanent")
            let requestApproval = try container.decodeIfPresent(Bool.self, forKey: "requestApproval") ?? false
            let isRevoked = try container.decode(Bool.self, forKey: "revoked")
            let adminId = PeerId(try container.decode(Int64.self, forKey: "adminId"))
            let date = try container.decode(Int32.self, forKey: "date")
            let startDate = try container.decodeIfPresent(Int32.self, forKey: "startDate")
            let expireDate = try container.decodeIfPresent(Int32.self, forKey: "expireDate")
            let usageLimit = try container.decodeIfPresent(Int32.self, forKey: "usageLimit")
            let count = try container.decodeIfPresent(Int32.self, forKey: "count")
            let requestedCount = try? container.decodeIfPresent(Int32.self, forKey: "requestedCount")
            
            self = .link(link: link, title: title, isPermanent: isPermanent, requestApproval: requestApproval, isRevoked: isRevoked, adminId: adminId, date: date, startDate: startDate, expireDate: expireDate, usageLimit: usageLimit, count: count, requestedCount: requestedCount)
        } else {
            self = .publicJoinRequest
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
            case let .link(link, title, isPermanent, requestApproval, isRevoked, adminId, date, startDate, expireDate, usageLimit, count, requestedCount):
                let type: Int32 = 0
                try container.encode(type, forKey: "t")
                try container.encode(link, forKey: "l")
                try container.encodeIfPresent(title, forKey: "title")
                try container.encode(isPermanent, forKey: "permanent")
                try container.encode(requestApproval, forKey: "requestApproval")
                try container.encode(isRevoked, forKey: "revoked")
                try container.encode(adminId.toInt64(), forKey: "adminId")
                try container.encode(date, forKey: "date")
                try container.encodeIfPresent(startDate, forKey: "startDate")
                try container.encodeIfPresent(expireDate, forKey: "expireDate")
                try container.encodeIfPresent(usageLimit, forKey: "usageLimit")
                try container.encodeIfPresent(count, forKey: "count")
                try container.encodeIfPresent(requestedCount, forKey: "requestedCount")
            case .publicJoinRequest:
                let type: Int32 = 1
                try container.encode(type, forKey: "t")
        }
    }
    
    public static func ==(lhs: ExportedInvitation, rhs: ExportedInvitation) -> Bool {
        switch lhs {
            case let .link(link, title, isPermanent, requestApproval, isRevoked, adminId, date, startDate, expireDate, usageLimit, count, requestedCount):
                if case .link(link, title, isPermanent, requestApproval, isRevoked, adminId, date, startDate, expireDate, usageLimit, count, requestedCount) = rhs {
                    return true
                } else {
                    return false
                }
            case .publicJoinRequest:
                if case .publicJoinRequest = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public func withUpdated(isRevoked: Bool) -> ExportedInvitation {
        switch self {
            case let .link(link, title, isPermanent, requestApproval, _, adminId, date, startDate, expireDate, usageLimit, count, requestedCount):
                return .link(link: link, title: title, isPermanent: isPermanent, requestApproval: requestApproval, isRevoked: isRevoked, adminId: adminId, date: date, startDate: startDate, expireDate: expireDate, usageLimit: usageLimit, count: count, requestedCount: requestedCount)
            case .publicJoinRequest:
                return .publicJoinRequest
        }
    }
}
