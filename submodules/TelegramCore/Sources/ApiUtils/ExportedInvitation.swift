import Foundation
import Postbox
import TelegramApi


extension ExportedInvitation {
    init(apiExportedInvite: Api.ExportedChatInvite) {
        switch apiExportedInvite {
        case let .chatInviteExported(flags, link, adminId, date, startDate, expireDate, usageLimit, usage, requested, title):
            self = ExportedInvitation(link: link, title: title, isPermanent: (flags & (1 << 5)) != 0, requestApproval: (flags & (1 << 6)) != 0, isRevoked: (flags & (1 << 0)) != 0, adminId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(adminId)), date: date, startDate: startDate, expireDate: expireDate, usageLimit: usageLimit, count: usage, requestedCount: requested)
        }
    }
}
