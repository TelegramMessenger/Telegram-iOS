#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
    import TelegramApiMac
#else
    import Postbox
    import SwiftSignalKit
    import TelegramApi
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

func apiUpdatesGroups(_ updates: Api.Updates) -> [Api.Chat] {
    switch updates {
        case let .updates( _, _, chats, _, _):
            return chats
        case let .updatesCombined(_, _, chats, _, _, _):
            return chats
        default:
            return []
    }
}

public enum ExternalJoiningChatState {
    case invite(title: String, photoRepresentation: TelegramMediaImageRepresentation?, participantsCount: Int32, participants: [Peer]?)
    case alreadyJoined(PeerId)
    case invalidHash
}

public func joinChatInteractively(with hash: String, account: Account) -> Signal <PeerId?, NoError> {
    return account.network.request(Api.functions.messages.importChatInvite(hash: hash))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { updates -> Signal<PeerId?, NoError> in
        if let updates = updates {
            account.stateManager.addUpdates(updates)
            if let peerId = apiUpdatesGroups(updates).first?.peerId {
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

public func joinLinkInformation(_ hash: String, account: Account) -> Signal<ExternalJoiningChatState, NoError> {
    return account.network.request(Api.functions.messages.checkChatInvite(hash: hash))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.ChatInvite?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { (result) -> Signal<ExternalJoiningChatState, NoError> in
        if let result = result {
            switch result {
                case let .chatInvite(invite):
                    let photo = telegramMediaImageFromApiPhoto(invite.photo).flatMap({ smallestImageRepresentation($0.representations) })
                    return .single(.invite(title: invite.title, photoRepresentation: photo, participantsCount: invite.participantsCount, participants: invite.participants?.map({TelegramUser(user: $0)})))
                case let .chatInviteAlready(chat: chat):
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        return account.postbox.transaction({ (transaction) -> ExternalJoiningChatState in
                            updatePeers(transaction: transaction, peers: [peer], update: { (previous, updated) -> Peer? in
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
