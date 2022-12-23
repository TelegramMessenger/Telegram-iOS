import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum JoinLinkInfoError {
    case generic
    case flood
}

public enum JoinLinkError {
    case generic
    case tooMuchJoined
    case tooMuchUsers
    case requestSent
    case flood
}

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
    public struct Invite: Equatable {
        public struct Flags: Equatable, Codable {
            public let isChannel: Bool
            public let isBroadcast: Bool
            public let isPublic: Bool
            public let isMegagroup: Bool
            public let requestNeeded: Bool
        }
        
        public let flags: Flags
        public let title: String
        public let about: String?
        public let photoRepresentation: TelegramMediaImageRepresentation?
        public let participantsCount: Int32
        public let participants: [EnginePeer]?
    }
    
    case invite(Invite)
    case alreadyJoined(EnginePeer)
    case invalidHash
    case peek(EnginePeer, Int32)
}

func _internal_joinChatInteractively(with hash: String, account: Account) -> Signal<PeerId?, JoinLinkError> {
    return account.network.request(Api.functions.messages.importChatInvite(hash: hash), automaticFloodWait: false)
    |> mapError { error -> JoinLinkError in
        switch error.errorDescription {
            case "CHANNELS_TOO_MUCH":
                return .tooMuchJoined
            case "USERS_TOO_MUCH":
                return .tooMuchUsers
            case "INVITE_REQUEST_SENT":
                return .requestSent
            default:
                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .flood
                } else {
                    return .generic
                }
        }
    }
    |> mapToSignal { updates -> Signal<PeerId?, JoinLinkError> in
        account.stateManager.addUpdates(updates)
        if let peerId = apiUpdatesGroups(updates).first?.peerId {
            return account.postbox.multiplePeersView([peerId])
            |> castError(JoinLinkError.self)
            |> filter { view in
                return view.peers[peerId] != nil
            }
            |> take(1)
            |> map { _ in
                return peerId
            }
            |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil) |> castError(JoinLinkError.self))
        }
        return .single(nil)
    }
}

func _internal_joinLinkInformation(_ hash: String, account: Account) -> Signal<ExternalJoiningChatState, JoinLinkInfoError> {
    return account.network.request(Api.functions.messages.checkChatInvite(hash: hash), automaticFloodWait: false)
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.ChatInvite?, JoinLinkInfoError> in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .fail(.flood)
        } else {
            return .single(nil)
        }
    }
    |> mapToSignal { result -> Signal<ExternalJoiningChatState, JoinLinkInfoError> in
        if let result = result {
            switch result {
                case let .chatInvite(flags, title, about, invitePhoto, participantsCount, participants):
                    let photo = telegramMediaImageFromApiPhoto(invitePhoto).flatMap({ smallestImageRepresentation($0.representations) })
                    let flags: ExternalJoiningChatState.Invite.Flags = .init(isChannel: (flags & (1 << 0)) != 0, isBroadcast: (flags & (1 << 1)) != 0, isPublic: (flags & (1 << 2)) != 0, isMegagroup: (flags & (1 << 3)) != 0, requestNeeded: (flags & (1 << 6)) != 0)
                    return .single(.invite(ExternalJoiningChatState.Invite(flags: flags, title: title, about: about, photoRepresentation: photo, participantsCount: participantsCount, participants: participants?.map({ EnginePeer(TelegramUser(user: $0)) }))))
                case let .chatInviteAlready(chat):
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        return account.postbox.transaction({ (transaction) -> ExternalJoiningChatState in
                            updatePeers(transaction: transaction, peers: [peer], update: { (previous, updated) -> Peer? in
                                return updated
                            })
                            
                            return .alreadyJoined(EnginePeer(peer))
                        })
                        |> castError(JoinLinkInfoError.self)
                    }
                    return .single(.invalidHash)
                case let .chatInvitePeek(chat, expires):
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        return account.postbox.transaction({ (transaction) -> ExternalJoiningChatState in
                            updatePeers(transaction: transaction, peers: [peer], update: { (previous, updated) -> Peer? in
                                return updated
                            })
                            
                            return .peek(EnginePeer(peer), expires)
                        })
                        |> castError(JoinLinkInfoError.self)
                    }
                    return .single(.invalidHash)
            }
        } else {
            return .single(.invalidHash)
        }
    }
}
