import Foundation
import Postbox
import TelegramApi


extension ExportedInvitation {
    init(apiExportedInvite: Api.ExportedChatInvite) {
        switch apiExportedInvite {
            case let .chatInviteExported(flags, link, adminId, date, startDate, expireDate, usageLimit, usage, requested, title):
                self = .link(link: link, title: title, isPermanent: (flags & (1 << 5)) != 0, requestApproval: (flags & (1 << 6)) != 0, isRevoked: (flags & (1 << 0)) != 0, adminId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(adminId)), date: date, startDate: startDate, expireDate: expireDate, usageLimit: usageLimit, count: usage, requestedCount: requested)
/*            case .chatInvitePublicJoinRequests:
                self = .publicJoinRequest
*/
        }
    }
}

public extension ExportedInvitation {
    var link: String? {
        switch self {
            case let .link(link, _, _, _, _, _, _, _, _, _, _, _):
                return link
            case .publicJoinRequest:
                return nil
        }
    }
    
    var date: Int32? {
        switch self {
            case let .link(_, _, _, _, _, _, _, date, _, _, _, _):
                return date
            case .publicJoinRequest:
                return nil
        }
    }
    
    var isPermanent: Bool {
        switch self {
            case let .link(_, _, isPermanent, _, _, _, _, _, _, _, _, _):
                return isPermanent
            case .publicJoinRequest:
                return false
        }
    }
    
    var isRevoked: Bool {
        switch self {
            case let .link(_, _, _, _, isRevoked, _, _, _, _, _, _, _):
                return isRevoked
            case .publicJoinRequest:
                return false
        }
    }
}
