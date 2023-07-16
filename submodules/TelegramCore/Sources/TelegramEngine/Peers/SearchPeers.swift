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

func _internal_searchPeers(account: Account, query: String) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
    let accountPeerId = account.peerId
    
    let searchResult = account.network.request(Api.functions.contacts.search(q: query, limit: 20), automaticFloodWait: false)
    |> map(Optional.init)
    |> `catch` { _ in
        return Signal<Api.contacts.Found?, NoError>.single(nil)
    }
    let processedSearchResult = searchResult
    |> mapToSignal { result -> Signal<([FoundPeer], [FoundPeer]), NoError> in
        if let result = result {
            switch result {
            case let .found(myResults, results, chats, users):
                return account.postbox.transaction { transaction -> ([FoundPeer], [FoundPeer]) in
                    var subscribers: [PeerId: Int32] = [:]
                    
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            switch chat {
                            case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _):
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
                            renderedMyPeers.append(FoundPeer(peer: peer, subscribers: subscribers[peerId]))
                        }
                    }
                    
                    var renderedPeers: [FoundPeer] = []
                    for result in results {
                        let peerId: PeerId = result.peerId
                        if let peer = parsedPeers.get(peerId) {
                            if let group = peer as? TelegramGroup, group.migrationReference != nil {
                                continue
                            }
                            renderedPeers.append(FoundPeer(peer: peer, subscribers: subscribers[peerId]))
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

