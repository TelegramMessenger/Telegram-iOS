import Foundation
import TelegramCore
import SwiftSignalKit
import AccountContext
import StringTransliteration

public enum SearchPeerMembersScope {
    case memberSuggestion
    case mention
}

public func searchPeerMembers(context: AccountContext, peerId: EnginePeer.Id, chatLocation: ChatLocation, query: String, scope: SearchPeerMembersScope) -> Signal<[EnginePeer], NoError> {
    let normalizedQuery = query.lowercased()
    let transformedQuery = postboxTransformedString(normalizedQuery as NSString, true, false) ?? normalizedQuery
    
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        return context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId)
        )
        |> mapToSignal { participantCount -> Signal<([EnginePeer], Bool), NoError> in
            if case .peer = chatLocation, let memberCount = participantCount, memberCount <= 64 {
                return Signal { subscriber in
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, requestUpdate: false, updated: { state in
                        if case .ready = state.loadingState {
                            subscriber.putNext((state.list.compactMap { participant -> EnginePeer? in
                                if participant.peer.isDeleted {
                                    return nil
                                }
                                if normalizedQuery.isEmpty {
                                    return EnginePeer(participant.peer)
                                } else {
                                    if participant.peer.indexName.matchesByTokens(normalizedQuery) || participant.peer.indexName.matchesByTokens(transformedQuery) {
                                        return EnginePeer(participant.peer)
                                    }
                                    if let addressName = participant.peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) || addressName.lowercased().hasPrefix(transformedQuery) {
                                        return EnginePeer(participant.peer)
                                    }
                                    
                                    return nil
                                }
                            }, true))
                        }
                    })
                    
                    return ActionDisposable {
                        disposable.dispose()
                    }
                }
                |> runOn(Queue.mainQueue())
            }
            
            return Signal { subscriber in
                switch chatLocation {
                case let .peer(peerId):
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: normalizedQuery.isEmpty ? nil : normalizedQuery, updated: { state in
                        if case .ready = state.loadingState {
                            subscriber.putNext((state.list.compactMap { participant in
                                if participant.peer.isDeleted {
                                    return nil
                                }
                                return EnginePeer(participant.peer)
                            }, true))
                        }
                    })
                    
                    return ActionDisposable {
                        disposable.dispose()
                    }
                case let .replyThread(replyThreadMessage):
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.mentions(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, threadMessageId: replyThreadMessage.messageId, searchQuery: normalizedQuery.isEmpty ? nil : normalizedQuery, updated: { state in
                        if case .ready = state.loadingState {
                            subscriber.putNext((state.list.compactMap { participant in
                                if participant.peer.isDeleted {
                                    return nil
                                }
                                return EnginePeer(participant.peer)
                            }, true))
                        }
                    })
                    
                    return ActionDisposable {
                        disposable.dispose()
                    }
                case .feed:
                    subscriber.putNext(([], true))
                    
                    return ActionDisposable {
                    }
                }
            } |> runOn(Queue.mainQueue())
        }
        |> mapToSignal { result, isReady -> Signal<[EnginePeer], NoError> in
            switch scope {
            case .mention:
                return .single(result)
            case .memberSuggestion:
                return context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
                |> map { peer -> [EnginePeer] in
                    var result = result
                    if isReady {
                        if case let .channel(channel) = peer, case .group = channel.info {
                            var matches = false
                            if normalizedQuery.isEmpty {
                                matches = true
                            } else {
                                if channel.indexName.matchesByTokens(normalizedQuery) || channel.indexName.matchesByTokens(transformedQuery) {
                                    matches = true
                                }
                                if let addressName = channel.addressName, addressName.lowercased().hasPrefix(normalizedQuery) || addressName.lowercased().hasPrefix(transformedQuery) {
                                    matches = true
                                }
                            }
                            if matches {
                                result.insert(.channel(channel), at: 0)
                            }
                        }
                    }
                    return result
                }
            }
        }
    } else {
        let transliteratedPeers: Signal<[EnginePeer], NoError>
        if transformedQuery != normalizedQuery {
            transliteratedPeers = context.engine.peers.searchGroupMembers(peerId: peerId, query: transformedQuery)
        } else {
            transliteratedPeers = .single([])
        }
        
        return combineLatest(
            context.engine.peers.searchGroupMembers(peerId: peerId, query: normalizedQuery),
            transliteratedPeers
        )
        |> map { peers, transliteratedPeers -> [EnginePeer] in
            var existingPeerIds = Set<EnginePeer.Id>()
            var result = peers
            for peer in peers {
                existingPeerIds.insert(peer.id)
            }
            for peer in transliteratedPeers {
                if !existingPeerIds.contains(peer.id) {
                    result.append(peer)
                }
            }
            return result
        }
    }
}
