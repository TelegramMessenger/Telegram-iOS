import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramApi

public func availableGroupFeedPeers(postbox: Postbox, network: Network, groupId: PeerGroupId) -> Signal<[(Peer, Bool)], NoError> {
    /*feed*/
    return .single([])
    /*return network.request(Api.functions.channels.getFeedSources(flags: 0, feedId: groupId.rawValue, hash: 0))
    |> retryRequest
    |> mapToSignal { result -> Signal<[(Peer, Bool)], NoError> in
        return postbox.transaction { transaction -> [(Peer, Bool)] in
            switch result {
                case .feedSourcesNotModified:
                    return []
                case let .feedSources(_, newlyJoinedFeed, feeds, chats, users):
                    var includedPeerIds = Set<PeerId>()
                    var excludedPeerIds = Set<PeerId>()
                    for feedsInfo in feeds {
                        switch feedsInfo {
                            case let .feedBroadcasts(feedId, channels):
                                if feedId == groupId.rawValue {
                                    for id in channels {
                                        includedPeerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: id))
                                    }
                                }
                            case let .feedBroadcastsUngrouped(channels):
                                for id in channels {
                                    excludedPeerIds.insert(PeerId(namespace: Namespaces.Peer.CloudChannel, id: id))
                                }
                        }
                    }
                    var peers: [(Peer, Bool)] = []
                    for peerId in includedPeerIds {
                        if let peer = transaction.getPeer(peerId) {
                            peers.append((peer, true))
                        }
                    }
                    for peerId in excludedPeerIds {
                        if let peer = transaction.getPeer(peerId) {
                            peers.append((peer, false))
                        }
                    }
                    return peers
            }
        }
    }*/
}
