import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public struct FoundPeer: Equatable {
    public let peer: Peer
    public let subscribers: Int32?
    
    public init(peer: Peer, subscribers: Int32?) {
        self.peer = peer
        self.subscribers = subscribers
    }
    
    public static func ==(lhs: FoundPeer, rhs: FoundPeer) -> Bool {
        return lhs.peer.isEqual(rhs.peer) && lhs.subscribers == rhs.subscribers
    }
}

public enum TelegramSearchPeersScope {
    case everywhere
    case channels
    case groups
    case privateChats
}

public func _internal_searchPeers(accountPeerId: PeerId, postbox: Postbox, network: Network, query: String, scope: TelegramSearchPeersScope) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
    let searchResult = network.request(Api.functions.contacts.search(q: query, limit: 20), automaticFloodWait: false)
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.contacts.Found?, NoError>.single(nil)
    }
    let processedSearchResult = searchResult
    |> mapToSignal { result -> Signal<([FoundPeer], [FoundPeer]), NoError> in
        if let result = result {
            switch result {
            case let .found(myResults, results, chats, users):
                return postbox.transaction { transaction -> ([FoundPeer], [FoundPeer]) in
                    var subscribers: [PeerId: Int32] = [:]
                    
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            switch chat {
                            case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _, _, _, _, _, _, _, _, _, _):
                                if let participantsCount = participantsCount {
                                    subscribers[groupOrChannel.id] = participantsCount
                                }
                            default:
                                break
                            }
                        }
                    }
                                        
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    
                    var renderedMyPeers: [FoundPeer] = []
                    for result in myResults {
                        let peerId: PeerId = result.peerId
                        if let peer = parsedPeers.get(peerId) {
                            if let group = peer as? TelegramGroup, group.migrationReference != nil {
                                continue
                            }
                            if let user = peer as? TelegramUser {
                                renderedMyPeers.append(FoundPeer(peer: peer, subscribers: user.subscriberCount))
                            } else {
                                renderedMyPeers.append(FoundPeer(peer: peer, subscribers: subscribers[peerId]))
                            }
                        }
                    }
                    
                    var renderedPeers: [FoundPeer] = []
                    for result in results {
                        let peerId: PeerId = result.peerId
                        if let peer = parsedPeers.get(peerId) {
                            if let group = peer as? TelegramGroup, group.migrationReference != nil {
                                continue
                            }
                            if let user = peer as? TelegramUser {
                                renderedPeers.append(FoundPeer(peer: peer, subscribers: user.subscriberCount))
                            } else {
                                renderedPeers.append(FoundPeer(peer: peer, subscribers: subscribers[peerId]))
                            }
                        }
                    }
                    
                    switch scope {
                    case .everywhere:
                        break
                    case .channels:
                        renderedMyPeers = renderedMyPeers.filter { item in
                            if let channel = item.peer as? TelegramChannel, case .broadcast = channel.info {
                                return true
                            } else {
                                return false
                            }
                        }
                        renderedPeers = renderedPeers.filter { item in
                            if let channel = item.peer as? TelegramChannel, case .broadcast = channel.info {
                                return true
                            } else {
                                return false
                            }
                        }
                    case .groups:
                        renderedMyPeers = renderedMyPeers.filter { item in
                            if let channel = item.peer as? TelegramChannel, case .group = channel.info {
                                return true
                            } else if item.peer is TelegramGroup {
                                return true
                            } else {
                                return false
                            }
                        }
                        renderedPeers = renderedPeers.filter { item in
                            if let channel = item.peer as? TelegramChannel, case .group = channel.info {
                                return true
                            } else if item.peer is TelegramGroup {
                                return true
                            } else {
                                return false
                            }
                        }
                    case .privateChats:
                        renderedMyPeers = renderedMyPeers.filter { item in
                            if item.peer is TelegramUser {
                                return true
                            } else {
                                return false
                            }
                        }
                        renderedPeers = renderedPeers.filter { item in
                            if item.peer is TelegramUser {
                                return true
                            } else {
                                return false
                            }
                        }
                    }
                    
                    return (renderedMyPeers, renderedPeers)
                }
            }
        } else {
            return .single(([], []))
        }
    }
    
    return processedSearchResult
}

func _internal_searchLocalSavedMessagesPeers(account: Account, query: String, indexNameMapping: [EnginePeer.Id: [PeerIndexNameRepresentation]]) -> Signal<[EnginePeer], NoError> {
    return account.postbox.transaction { transaction -> [EnginePeer] in
        return transaction.searchSubPeers(peerId: account.peerId, query: query, indexNameMapping: indexNameMapping).map(EnginePeer.init)
    }
}

func _internal_requestMessageAuthor(account: Account, id: EngineMessage.Id) -> Signal<EnginePeer?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(id.peerId).flatMap(apiInputChannel)
    }
    |> mapToSignal { inputChannel -> Signal<EnginePeer?, NoError> in
        guard let inputChannel else {
            return .single(nil)
        }
        if id.namespace != Namespaces.Message.Cloud {
            return .single(nil)
        }
        return account.network.request(Api.functions.channels.getMessageAuthor(channel: inputChannel, id: id.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.User?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { user -> Signal<EnginePeer?, NoError> in
            guard let user else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> EnginePeer? in
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: [user]))
                return transaction.getPeer(user.peerId).flatMap(EnginePeer.init)
            }
        }
    }
}
