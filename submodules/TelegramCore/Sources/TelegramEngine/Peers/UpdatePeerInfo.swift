import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum UpdatePeerTitleError {
    case generic
}

func _internal_updatePeerTitle(account: Account, peerId: PeerId, title: String) -> Signal<Void, UpdatePeerTitleError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerTitleError> in
        if let peer = transaction.getPeer(peerId) {
            if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.editTitle(channel: inputChannel, title: title))
                    |> mapError { _ -> UpdatePeerTitleError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, UpdatePeerTitleError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.transaction { transaction -> Void in
                            if let apiChat = apiUpdatesGroups(result).first, let updatedPeer = parseTelegramGroupOrChannel(chat: apiChat) {
                                updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                    return updated
                                })
                            }
                        } |> mapError { _ -> UpdatePeerTitleError in }
                    }
            } else if let peer = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.editChatTitle(chatId: peer.id.id._internalGetInt64Value(), title: title))
                    |> mapError { _ -> UpdatePeerTitleError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, UpdatePeerTitleError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.transaction { transaction -> Void in
                            if let apiChat = apiUpdatesGroups(result).first, let updatedPeer = parseTelegramGroupOrChannel(chat: apiChat) {
                                updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                                    return updated
                                })
                            }
                        } |> mapError { _ -> UpdatePeerTitleError in }
                    }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> UpdatePeerTitleError in } |> switchToLatest
}

public enum UpdatePeerDescriptionError {
    case generic
}

func _internal_updatePeerDescription(account: Account, peerId: PeerId, description: String?) -> Signal<Void, UpdatePeerDescriptionError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdatePeerDescriptionError> in
        if let peer = transaction.getPeer(peerId) {
            if (peer is TelegramChannel || peer is TelegramGroup), let inputPeer = apiInputPeer(peer) {
                return account.network.request(Api.functions.messages.editChatAbout(peer: inputPeer, about: description ?? ""))
                |> mapError { _ -> UpdatePeerDescriptionError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, UpdatePeerDescriptionError> in
                    return account.postbox.transaction { transaction -> Void in
                        if case .boolTrue = result {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                if let current = current as? CachedChannelData {
                                    return current.withUpdatedAbout(description)
                                } else if let current = current as? CachedGroupData {
                                    return current.withUpdatedAbout(description)
                                } else {
                                    return current
                                }
                            })
                        }
                    }
                    |> mapError { _ -> UpdatePeerDescriptionError in }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> UpdatePeerDescriptionError in } |> switchToLatest
}
