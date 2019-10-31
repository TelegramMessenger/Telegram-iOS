import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext

public func searchPeerMembers(context: AccountContext, peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        return context.account.postbox.transaction { transaction -> CachedChannelData? in
            return transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData
        }
        |> mapToSignal { cachedData -> Signal<[Peer], NoError> in
            if let cachedData = cachedData, let memberCount = cachedData.participantsSummary.memberCount, memberCount <= 64 {
                return Signal { subscriber in
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, requestUpdate: false, updated: { state in
                        if case .ready = state.loadingState {
                            let normalizedQuery = query.lowercased()
                            subscriber.putNext(state.list.compactMap { participant -> Peer? in
                                if participant.peer.isDeleted {
                                    return nil
                                }
                                if normalizedQuery.isEmpty {
                                    return participant.peer
                                }
                                if normalizedQuery.isEmpty {
                                    return participant.peer
                                } else {
                                    if participant.peer.indexName.matchesByTokens(normalizedQuery) {
                                        return participant.peer
                                    }
                                    if let addressName = participant.peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                                        return participant.peer
                                    }
                                    
                                    return nil
                                }
                            })
                        }
                    })
                    
                    return ActionDisposable {
                        disposable.dispose()
                    }
                }
                |> runOn(Queue.mainQueue())
            }
            
            return Signal { subscriber in
                let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: query.isEmpty ? nil : query, updated: { state in
                    if case .ready = state.loadingState {
                        subscriber.putNext(state.list.compactMap { participant in
                            if participant.peer.isDeleted {
                                return nil
                            }
                            return participant.peer
                        })
                    }
                })
                
                return ActionDisposable {
                    disposable.dispose()
                }
            } |> runOn(Queue.mainQueue())
        }
    } else {
        return searchGroupMembers(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, query: query)
    }
}
