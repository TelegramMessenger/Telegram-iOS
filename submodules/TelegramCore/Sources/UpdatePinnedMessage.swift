import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public enum UpdatePinnedMessageError {
    case generic
}

public enum PinnedMessageUpdate {
    case pin(id: MessageId, silent: Bool)
    case clear
}

public func requestUpdatePinnedMessage(account: Account, peerId: PeerId, update: PinnedMessageUpdate) -> Signal<Void, UpdatePinnedMessageError> {
    return account.postbox.transaction { transaction -> (Peer?, CachedPeerData?) in
        return (transaction.getPeer(peerId), transaction.getPeerCachedData(peerId: peerId))
    }
    |> mapError { _ -> UpdatePinnedMessageError in
        return .generic
    }
    |> mapToSignal { peer, cachedPeerData -> Signal<Void, UpdatePinnedMessageError> in
        guard let peer = peer, let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        if let channel = peer as? TelegramChannel, let inputPeer = apiInputPeer(channel) {
            let canManagePin = channel.hasPermission(.pinMessages)
            
            if canManagePin {
                var flags: Int32 = 0
                let messageId: Int32
                switch update {
                    case let .pin(id, silent):
                        messageId = id.id
                        if silent {
                            flags |= (1 << 0)
                        }
                    case .clear:
                        messageId = 0
                }
                
                let request = Api.functions.messages.updatePinnedMessage(flags: flags, peer: inputPeer, id: messageId)
                
                return account.network.request(request)
                |> mapError { _ -> UpdatePinnedMessageError in
                    return .generic
                }
                |> mapToSignal { updates -> Signal<Void, UpdatePinnedMessageError> in
                    account.stateManager.addUpdates(updates)
                    return account.postbox.transaction { transaction in
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let current = current as? CachedChannelData {
                                let pinnedMessageId: MessageId?
                                switch update {
                                    case let .pin(id, _):
                                        pinnedMessageId = id
                                    case .clear:
                                        pinnedMessageId = nil
                                }
                                return current.withUpdatedPinnedMessageId(pinnedMessageId)
                            } else {
                                return current
                            }
                        })
                    }
                    |> mapError { _ -> UpdatePinnedMessageError in return .generic
                    }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            var canPin = false
            if let group = peer as? TelegramGroup {
                switch group.role {
                    case .creator, .admin:
                        canPin = true
                    default:
                        if let defaultBannedRights = group.defaultBannedRights {
                            canPin = !defaultBannedRights.flags.contains(.banPinMessages)
                        } else {
                            canPin = true
                        }
                }
            } else if let _ = peer as? TelegramUser, let cachedPeerData = cachedPeerData as? CachedUserData {
                canPin = cachedPeerData.canPinMessages
            }
            if canPin {
                var flags: Int32 = 0
                let messageId: Int32
                switch update {
                    case let .pin(id, silent):
                        messageId = id.id
                        if silent {
                            flags |= (1 << 0)
                        }
                    case .clear:
                        messageId = 0
                }
                
                let request = Api.functions.messages.updatePinnedMessage(flags: flags, peer: inputPeer, id: messageId)
                
                return account.network.request(request)
                |> mapError { _ -> UpdatePinnedMessageError in
                    return .generic
                }
                |> mapToSignal { updates -> Signal<Void, UpdatePinnedMessageError> in
                    account.stateManager.addUpdates(updates)
                    return account.postbox.transaction { transaction in
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                            if let _ = peer as? TelegramGroup {
                                let current = current as? CachedGroupData ?? CachedGroupData()
                                let pinnedMessageId: MessageId?
                                switch update {
                                    case let .pin(id, _):
                                        pinnedMessageId = id
                                    case .clear:
                                        pinnedMessageId = nil
                                }
                                return current.withUpdatedPinnedMessageId(pinnedMessageId)
                            } else if let _ = peer as? TelegramUser {
                                let current = current as? CachedUserData ?? CachedUserData()
                                
                                let pinnedMessageId: MessageId?
                                switch update {
                                    case let .pin(id, _):
                                        pinnedMessageId = id
                                    case .clear:
                                        pinnedMessageId = nil
                                }
                                return current.withUpdatedPinnedMessageId(pinnedMessageId)
                            } else {
                                return current
                            }
                        })
                    }
                    |> mapError { _ -> UpdatePinnedMessageError in
                        return .generic
                    }
                }
            } else {
                return .fail(.generic)
            }
        }
    }
}
