import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public enum UpdatePeerTitleError {
    case generic
}

public func updatePeerTitle(account: Account, peerId: PeerId, title: String) -> Signal<Void, UpdatePeerTitleError> {
    return account.postbox.modify { modifier -> Signal<Void, UpdatePeerTitleError> in
        if let peer = modifier.getPeer(peerId) {
            if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.editTitle(channel: inputChannel, title: title))
                    |> mapError { _ -> UpdatePeerTitleError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, UpdatePeerTitleError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.modify { modifier -> Void in
                            if let apiChat = result.groups.first, let updatedPeer = parseTelegramGroupOrChannel(chat: apiChat) {
                                updatePeers(modifier: modifier, peers: [updatedPeer], update: { _, updated in
                                    return updated
                                })
                            }
                        } |> mapError { _ -> UpdatePeerTitleError in return .generic }
                    }
            } else if let peer = peer as? TelegramGroup {
                return account.network.request(Api.functions.messages.editChatTitle(chatId: peer.id.id, title: title))
                    |> mapError { _ -> UpdatePeerTitleError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, UpdatePeerTitleError> in
                        account.stateManager.addUpdates(result)
                        
                        return account.postbox.modify { modifier -> Void in
                            if let apiChat = result.groups.first, let updatedPeer = parseTelegramGroupOrChannel(chat: apiChat) {
                                updatePeers(modifier: modifier, peers: [updatedPeer], update: { _, updated in
                                    return updated
                                })
                            }
                        } |> mapError { _ -> UpdatePeerTitleError in return .generic }
                    }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> UpdatePeerTitleError in return .generic } |> switchToLatest
}

public enum UpdatePeerDescriptionError {
    case generic
}

public func updatePeerDescription(account: Account, peerId: PeerId, description: String?) -> Signal<Void, UpdatePeerDescriptionError> {
    return account.postbox.modify { modifier -> Signal<Void, UpdatePeerDescriptionError> in
        if let peer = modifier.getPeer(peerId) {
            if let peer = peer as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.editAbout(channel: inputChannel, about: description ?? ""))
                    |> mapError { _ -> UpdatePeerDescriptionError in
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<Void, UpdatePeerDescriptionError> in
                        return account.postbox.modify { modifier -> Void in
                            if case .boolTrue = result {
                                modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedChannelData {
                                        return current.withUpdatedAbout(description)
                                    } else {
                                        return current
                                    }
                                })
                            }
                        } |> mapError { _ -> UpdatePeerDescriptionError in return .generic }
                }
            } else {
                return .fail(.generic)
            }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> UpdatePeerDescriptionError in return .generic } |> switchToLatest
}
