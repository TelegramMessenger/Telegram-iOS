#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

extension Api.Updates {
    var groups: [Api.Chat] {
        switch self {
            case let .updates( _, _, chats, _, _):
                return chats
            case let .updatesCombined(_, _, chats, _, _, _):
                return chats
            default:
                return []
        }
    }
}


public enum ExternalJoiningChatState {
    case invite(title: String, photoRepresentation: TelegramMediaImageRepresentation?, participantsCount: Int32, participants: [Peer]?)
    case alreadyJoined(PeerId)
    case invalidHash
}

public func joinChatInteractively(with hash: String, account: Account) -> Signal <PeerId?, Void> {
    return account.network.request(Api.functions.messages.importChatInvite(hash: hash))
        |> map { Optional($0) }
        |> `catch` { _ in
            return Signal<Api.Updates?, NoError>.single(nil)
        }
        |> mapToSignal { updates -> Signal<PeerId?, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
                if let peerId = updates.groups.first?.peerId {
                    return account.postbox.multiplePeersView([peerId])
                        |> filter { view in
                            return view.peers[peerId] != nil
                        }
                        |> take(1)
                        |> map { _ in
                            return peerId
                        }
                        |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
                }
                return .single(nil)
            } else {
                return .single(nil)
            }
    }
}

public func joinLinkInformation(_ hash: String, account: Account) -> Signal<ExternalJoiningChatState, Void> {
    return account.network.request(Api.functions.messages.checkChatInvite(hash: hash))
        |> map { Optional($0) }
        |> `catch` { _ in
            return Signal<Api.ChatInvite?, NoError>.single(nil)
        }
        |> mapToSignal { (result) -> Signal<ExternalJoiningChatState, Void> in
            if let result = result {
                switch result {
                    case let .chatInvite(invite):
                        let photo: TelegramMediaImageRepresentation?
                        switch invite.photo {
                            case let .chatPhoto(photos):
                                if let resource = mediaResourceFromApiFileLocation(photos.photoSmall, size: nil) {
                                    photo = TelegramMediaImageRepresentation(dimensions: CGSize(width: 100.0, height: 100.0), resource: resource)
                                } else {
                                    photo = nil
                                }
                            case .chatPhotoEmpty:
                                photo = nil
                        }
                        return .single(.invite(title: invite.title, photoRepresentation: photo, participantsCount: invite.participantsCount, participants: invite.participants?.map({TelegramUser(user: $0)})))
                    case let .chatInviteAlready(chat: chat):
                        if let peer = parseTelegramGroupOrChannel(chat: chat) {
                            return account.postbox.modify({ (modifier) -> ExternalJoiningChatState in
                                updatePeers(modifier: modifier, peers: [peer], update: { (previous, updated) -> Peer? in
                                    return updated
                                })
                                
                                return .alreadyJoined(peer.id)
                            })
                        }
                        return .single(.invalidHash)
                }
            } else {
                return .single(.invalidHash)
            }
    }
}
