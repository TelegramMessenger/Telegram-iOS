import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

//communities.exportCommunityInvite#41fe69d9 community:InputCommunity title:string peers:Vector<InputPeer> = communities.ExportedCommunityInvite;
//communities.exportedCommunityInvite#6b97a8ea filter:DialogFilter invite:ExportedCommunityInvite = communities.ExportedCommunityInvite;
//exportedCommunityInvite#af7afb2f title:string url:string peers:Vector<Peer> = ExportedCommunityInvite;

public enum ExportChatFolderError {
    case generic
}

public struct ExportedChatFolderLink: Equatable {
    public var title: String
    public var link: String
    public var peerIds: [EnginePeer.Id]
    
    public init(
        title: String,
        link: String,
        peerIds: [EnginePeer.Id]
    ) {
        self.title = title
        self.link = link
        self.peerIds = peerIds
    }
}

func _internal_exportChatFolder(account: Account, filterId: Int32, title: String, peerIds: [PeerId]) -> Signal<ExportedChatFolderLink, ExportChatFolderError> {
    return account.postbox.transaction { transaction -> [Api.InputPeer] in
        return peerIds.compactMap(transaction.getPeer).compactMap(apiInputPeer)
    }
    |> castError(ExportChatFolderError.self)
    |> mapToSignal { inputPeers -> Signal<ExportedChatFolderLink, ExportChatFolderError> in
        return account.network.request(Api.functions.communities.exportCommunityInvite(community: .inputCommunityDialogFilter(filterId: filterId), title: title, peers: inputPeers))
        |> mapError { _ -> ExportChatFolderError in
            return .generic
        }
        |> mapToSignal { result -> Signal<ExportedChatFolderLink, ExportChatFolderError> in
            return account.postbox.transaction { transaction -> Signal<ExportedChatFolderLink, ExportChatFolderError> in
                switch result {
                case let .exportedCommunityInvite(filter, invite):
                    let parsedFilter = ChatListFilter(apiFilter: filter)
                    
                    let _ = updateChatListFiltersState(transaction: transaction, { state in
                        var state = state
                        if let index = state.filters.firstIndex(where: { $0.id == filterId }) {
                            state.filters[index] = parsedFilter
                        } else {
                            state.filters.append(parsedFilter)
                        }
                        state.remoteFilters = state.filters
                        return state
                    })
                    
                    switch invite {
                    case let .exportedCommunityInvite(title, url, peers):
                        return .single(ExportedChatFolderLink(
                            title: title,
                            link: url,
                            peerIds: peers.map(\.peerId)
                        ))
                    }
                }
            }
            |> castError(ExportChatFolderError.self)
            |> switchToLatest
        }
    }
}

func _internal_getExportedChatLinks(account: Account, id: Int32) -> Signal<[ExportedChatFolderLink], NoError> {
    return account.network.request(Api.functions.communities.getExportedInvites(community: .inputCommunityDialogFilter(filterId: id)))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.communities.ExportedInvites?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<[ExportedChatFolderLink], NoError> in
        guard let result = result else {
            return .single([])
        }
        return account.postbox.transaction { transaction -> [ExportedChatFolderLink] in
            switch result {
            case let .exportedInvites(invites, chats, users):
                var peers: [Peer] = []
                var peerPresences: [PeerId: Api.User] = [:]
                
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    peerPresences[telegramUser.id] = user
                }
                for chat in chats {
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(peer)
                    }
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
                var result: [ExportedChatFolderLink] = []
                for invite in invites {
                    switch invite {
                    case let .exportedCommunityInvite(title, url, peers):
                        result.append(ExportedChatFolderLink(title: title, link: url, peerIds: peers.map(\.peerId)))
                    }
                }
                
                return result
            }
        }
    }
}
