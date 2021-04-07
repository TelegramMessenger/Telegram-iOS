import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

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

public func searchPeers(account: Account, query: String) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
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
                    var peers: [PeerId: Peer] = [:]
                    var subscribers: [PeerId: Int32] = [:]
                    for user in users {
                        if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                            peers[user.id] = user
                        }
                    }
                    
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            peers[groupOrChannel.id] = groupOrChannel
                            switch chat {
                                /*feed*/
                                case let .channel(channel):
                                    if let participantsCount = channel.participantsCount {
                                        subscribers[groupOrChannel.id] = participantsCount
                                    }
                                default:
                                    break
                            }
                        }
                    }
                    
                    updatePeers(transaction: transaction, peers: Array(peers.values), update: { _, updated in
                        return updated
                    })
                    
                    var renderedMyPeers: [FoundPeer] = []
                    for result in myResults {
                        let peerId: PeerId
                        switch result {
                            case let .peerUser(userId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            case let .peerChat(chatId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                            case let .peerChannel(channelId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        }
                        if let peer = peers[peerId] {
                            if let group = peer as? TelegramGroup, group.migrationReference != nil {
                                continue
                            }
                            renderedMyPeers.append(FoundPeer(peer: peer, subscribers: subscribers[peerId]))
                        }
                    }
                    
                    var renderedPeers: [FoundPeer] = []
                    for result in results {
                        let peerId: PeerId
                        switch result {
                            case let .peerUser(userId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            case let .peerChat(chatId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                            case let .peerChannel(channelId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        }
                        if let peer = peers[peerId] {
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

