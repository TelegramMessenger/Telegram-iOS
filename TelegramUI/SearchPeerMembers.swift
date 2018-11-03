import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

func searchPeerMembers(account: Account, peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel && !query.isEmpty {
        return account.postbox.transaction { transaction -> CachedChannelData? in
            return transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData
        }
        |> mapToSignal { cachedData -> Signal<[Peer], NoError> in
            if let cachedData = cachedData, let memberCount = cachedData.participantsSummary.memberCount, memberCount <= 64 {
                return Signal { subscriber in
                    let (disposable, _) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.recent(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: nil, requestUpdate: false, updated: { state in
                        if case .ready = state.loadingState {
                            let normalizedQuery = query.lowercased()
                            subscriber.putNext(state.list.compactMap { participant -> Peer? in
                                if normalizedQuery.isEmpty {
                                    return participant.peer
                                }
                                
                                if participant.peer.indexName.matchesByTokens(normalizedQuery) {
                                    return participant.peer
                                }
                                if let addressName = participant.peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                                    return participant.peer
                                }
                                
                                return nil
                            })
                        }
                    })
                    
                    return ActionDisposable {
                        disposable.dispose()
                    }
                } |> runOn(Queue.mainQueue())
            }
            
            return Signal { subscriber in
                let (disposable, _) = account.telegramApplicationContext.peerChannelMemberCategoriesContextsManager.recent(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, searchQuery: query, updated: { state in
                    if case .ready = state.loadingState {
                        subscriber.putNext(state.list.map { $0.peer })
                    }
                })
                
                return ActionDisposable {
                    disposable.dispose()
                }
            } |> runOn(Queue.mainQueue())
        }
    } else {
        return searchGroupMembers(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, query: query)
    }
}
