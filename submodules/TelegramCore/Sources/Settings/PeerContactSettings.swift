import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

extension PeerStatusSettings {
    init(apiSettings: Api.PeerSettings) {
        switch apiSettings {
            case let .peerSettings(flags, geoDistance, requestChatTitle, requestChatDate, businessBotId, businessBotManageUrl, chargePaidMessageStars, registrationMonth, phoneCountry, nameChangeDate, photoChangeDate):
                var result = PeerStatusSettings.Flags()
                if (flags & (1 << 1)) != 0 {
                    result.insert(.canAddContact)
                }
                if (flags & (1 << 0)) != 0 {
                    result.insert(.canReport)
                }
                if (flags & (1 << 2)) != 0 {
                    result.insert(.canBlock)
                }
                if (flags & (1 << 3)) != 0 {
                    result.insert(.canShareContact)
                }
                if (flags & (1 << 4)) != 0 {
                    result.insert(.addExceptionWhenAddingContact)
                }
                if (flags & (1 << 7)) != 0 {
                    result.insert(.autoArchived)
                }
                if (flags & (1 << 8)) != 0 {
                    result.insert(.suggestAddMembers)
                }
            
                var managingBot: ManagingBot?
                if let businessBotId {
                    let businessBotPaused = (flags & (1 << 11)) != 0
                    let businessBotCanReply = (flags & (1 << 12)) != 0
                    managingBot = ManagingBot(
                        id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(businessBotId)),
                        manageUrl: businessBotManageUrl,
                        isPaused: businessBotPaused,
                        canReply: businessBotCanReply
                    )
                }
                self = PeerStatusSettings(
                    flags: result,
                    geoDistance: geoDistance,
                    requestChatTitle: requestChatTitle,
                    requestChatDate: requestChatDate,
                    requestChatIsChannel: (flags & (1 << 10)) != 0,
                    managingBot: managingBot,
                    paidMessageStars: chargePaidMessageStars.flatMap { StarsAmount(value: $0, nanos: 0) },
                    registrationDate: registrationMonth,
                    phoneCountry: phoneCountry,
                    nameChangeDate: nameChangeDate,
                    photoChangeDate: photoChangeDate
                )
        }
    }
}

public func unarchiveAutomaticallyArchivedPeer(account: Account, peerId: PeerId) {
    let _ = (account.postbox.transaction { transaction -> Void in
        _internal_updatePeerGroupIdInteractively(transaction: transaction, peerId: peerId, groupId: .root)
        
        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
            if let currentData = current as? CachedUserData, let currentStatusSettings = currentData.peerStatusSettings {
                var statusSettings = currentStatusSettings
                statusSettings.flags.remove(.canBlock)
                statusSettings.flags.remove(.canReport)
                statusSettings.flags.remove(.autoArchived)
                return currentData.withUpdatedPeerStatusSettings(statusSettings)
            } else if let currentData = current as? CachedGroupData, let currentStatusSettings = currentData.peerStatusSettings {
                var statusSettings = currentStatusSettings
                statusSettings.flags.remove(.canReport)
                statusSettings.flags.remove(.autoArchived)
                return currentData.withUpdatedPeerStatusSettings(statusSettings)
             } else if let currentData = current as? CachedChannelData, let currentStatusSettings = currentData.peerStatusSettings {
                 var statusSettings = currentStatusSettings
                 statusSettings.flags.remove(.canReport)
                 statusSettings.flags.remove(.autoArchived)
                 return currentData.withUpdatedPeerStatusSettings(statusSettings)
             }else {
                return current
            }
        })
    }
    |> deliverOnMainQueue).start()
    
    let _ = _internal_updatePeerMuteSetting(account: account, peerId: peerId, threadId: nil, muteInterval: nil).start()
}
