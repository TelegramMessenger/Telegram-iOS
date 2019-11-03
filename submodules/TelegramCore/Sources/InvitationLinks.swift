import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public func ensuredExistingPeerExportedInvitation(account: Account, peerId: PeerId, revokeExisted: Bool = false) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            if let _ = peer as? TelegramChannel {
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData, cachedData.exportedInvitation != nil && !revokeExisted {
                    return .complete()
                } else {
                    return account.network.request(Api.functions.messages.exportChatInvite(peer: inputPeer))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return account.postbox.transaction { transaction -> Void in
                            if let invitation = ExportedInvitation(apiExportedInvite: result) {
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedChannelData {
                                        return current.withUpdatedExportedInvitation(invitation)
                                    } else {
                                        return CachedChannelData().withUpdatedExportedInvitation(invitation)
                                    }
                                })
                            }
                        }
                    }
                }
            } else if let _ = peer as? TelegramGroup {
                if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedGroupData, cachedData.exportedInvitation != nil && !revokeExisted {
                    return .complete()
                } else {
                    return account.network.request(Api.functions.messages.exportChatInvite(peer: inputPeer))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return account.postbox.transaction { transaction -> Void in
                            if let invitation = ExportedInvitation(apiExportedInvite: result) {
                                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedGroupData {
                                        return current.withUpdatedExportedInvitation(invitation)
                                    } else {
                                        return current
                                    }
                                })
                            }
                        }
                    }
                }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
