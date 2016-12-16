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

public func searchPeers(account: Account, query: String) -> Signal<[Peer], NoError> {
    let searchResult = account.network.request(Api.functions.contacts.search(q: query, limit: 10))
        |> retryRequest
    
    let processedSearchResult = searchResult
        |> mapToSignal { result -> Signal<[Peer], NoError> in
            switch result {
                case let .found(results, chats, users):
                    return account.postbox.modify { modifier -> [Peer] in
                        var peers: [PeerId: Peer] = [:]
                        
                        for user in users {
                            if let user = TelegramUser.merge(modifier.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                peers[user.id] = user
                            }
                        }
                        
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers[groupOrChannel.id] = groupOrChannel
                            }
                        }
                        
                        var renderedPeers: [Peer] = []
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
                                renderedPeers.append(peer)
                            }
                        }
                        
                        return renderedPeers
                }
            }
    }
    
    return processedSearchResult
}
