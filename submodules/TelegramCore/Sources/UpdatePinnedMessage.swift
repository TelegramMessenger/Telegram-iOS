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
    case clear(id: MessageId)
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
        
        if let channel = peer as? TelegramChannel {
            let canManagePin = channel.hasPermission(.pinMessages)
            if !canManagePin {
                return .fail(.generic)
            }
        } else if let group = peer as? TelegramGroup {
            switch group.role {
            case .creator, .admin:
                break
            default:
                if let defaultBannedRights = group.defaultBannedRights {
                    if defaultBannedRights.flags.contains(.banPinMessages) {
                        return .fail(.generic)
                    }
                }
            }
        } else if let _ = peer as? TelegramUser, let cachedPeerData = cachedPeerData as? CachedUserData {
            if !cachedPeerData.canPinMessages {
                return .fail(.generic)
            }
        }
            
        var flags: Int32 = 0
        let messageId: Int32
        switch update {
        case let .pin(id, silent):
            messageId = id.id
            if silent {
                flags |= (1 << 0)
            }
        case let .clear(id):
            messageId = id.id
            flags |= 1 << 1
        }
        
        let request = Api.functions.messages.updatePinnedMessage(flags: flags, peer: inputPeer, id: messageId)
        
        return account.network.request(request)
        |> mapError { _ -> UpdatePinnedMessageError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Void, UpdatePinnedMessageError> in
            account.stateManager.addUpdates(updates)
            return account.postbox.transaction { transaction in
                switch updates {
                case let .updates(updates, _, _, _, _):
                    if updates.isEmpty {
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let messageId: MessageId
                            switch update {
                            case let .pin(id, _):
                                messageId = id
                            case let .clear(id):
                                messageId = id
                            }
                            transaction.updateMessage(messageId, update: { currentMessage in
                                let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                var updatedTags = currentMessage.tags
                                switch update {
                                case .pin:
                                    updatedTags.insert(.pinned)
                                case .clear:
                                    updatedTags.remove(.pinned)
                                }
                                if updatedTags == currentMessage.tags {
                                    return .skip
                                }
                                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: updatedTags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                            })
                        }
                    }
                default:
                    break
                }
            }
            |> mapError { _ -> UpdatePinnedMessageError in
                return .generic
            }
        }
    }
}
