import TelegramCore
import Foundation

struct ProfileInfoBody: Encodable {
    let id: Int64
    let type: ProfileTypeDTO
    let inviteLinks: [InviteLinkDTO]
    let icon: String?
    @Stringified var payload: AnyProfilePayload
}

protocol ProfilePayload: Encodable {}
struct AnyProfilePayload: ProfilePayload {
    let wrapped: ProfilePayload
    
    func encode(to encoder: Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}

struct GroupPayload: ProfilePayload {
    let deactivated: Bool
    let title: String
    let participantsCount: Int
    let date: Int32
    let migratedTo: Int64?
    let photo: ProfileImageDTO?
    let lastMessageLang: String?
    let about: String?
}

struct ChannelPayload: ProfilePayload {
    let verified: Bool
    let scam: Bool
    let hasGeo: Bool
    let fake: Bool
    let gigagroup: Bool
    let title: String
    let username: String?
    let date: Int32
    let restrictions: [RestrictionRuleDTO]
    let participantsCount: Int32?
    let photo: ProfileImageDTO?
    let lastMessageLang: String?
    let about: String?
    let geoLocation: GeoLocationDTO?
}

enum ProfileTypeDTO: String, Encodable {
    case channel
    case group
}

struct ProfileImageDTO: Encodable {
    let mediaResourceId: String
    let datacenterId: Int
    let photoId: Int64?
    let volumeId: Int64?
    let localId: Int32?
    let sizeSpec: Int32
}

struct RestrictionRuleDTO: Encodable {
    let platform: String
    let reason: String
    let text: String
}

struct GeoLocationDTO: Encodable {
    let latitude: Double
    let longitude: Double
    let address: String
}

struct InviteLinkDTO: Encodable {
    let link: String
    let title: String?
    let isPermanent: Bool
    let requestApproval: Bool
    let isRevoked: Bool
    let adminId: Int64
    let date: Int32
    let startDate: Int32?
    let expireDate: Int32?
    let usageLimit: Int32?
    let count: Int32?
    let requestedCount: Int32?
}

@propertyWrapper
struct Stringified<T: Encodable>: Encodable {
    
    var wrappedValue: T
    
    init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        let data = try JSONEncoder().encode(wrappedValue)
        let string = String(data: data, encoding: .utf8)
        try container.encode(string)
    }
}

//  MARK: - Mapping

extension ProfileImageDTO {
    init(cloudPeerPhotoSizeMediaResource resource: CloudPeerPhotoSizeMediaResource) {
        self.init(mediaResourceId: resource.id.stringRepresentation, datacenterId: resource.datacenterId, photoId: resource.photoId, volumeId: resource.volumeId, localId: resource.localId, sizeSpec: resource.sizeSpec.rawValue)
    }
}

extension RestrictionRuleDTO {
    init(restrictionRule rule: RestrictionRule) {
        self.init(platform: rule.platform, reason: rule.reason, text: rule.text)
    }
}

extension GeoLocationDTO {
    init(peerGeoLocation geo: PeerGeoLocation) {
        self.init(latitude: geo.latitude, longitude: geo.longitude, address: geo.address)
    }
}

extension InviteLinkDTO {
    init?(exportedInvitation: ExportedInvitation) {
        switch exportedInvitation {
        case let .link(link, title, isPermanent, requestApproval, isRevoked, adminId, date, startDate, expireDate, usageLimit, count, requestedCount):
            self.init(link: link, title: title, isPermanent: isPermanent, requestApproval: requestApproval, isRevoked: isRevoked, adminId: adminId.id._internalGetInt64Value(), date: date, startDate: startDate, expireDate: expireDate, usageLimit: usageLimit, count: count, requestedCount: requestedCount)
        case .publicJoinRequest:
            return nil
        }
    }
}
