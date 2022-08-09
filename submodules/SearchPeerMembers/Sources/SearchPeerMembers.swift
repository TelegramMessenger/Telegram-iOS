import Foundation
import TelegramCore
import SwiftSignalKit
import AccountContext

public enum SearchPeerMembersScope {
    case memberSuggestion
    case mention
}

public func searchPeerMembers(context: AccountContext, peerId: EnginePeer.Id, chatLocation: ChatLocation, query: String, scope: SearchPeerMembersScope) -> Signal<[EnginePeer], NoError> {
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        return context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId)
        )
        |> mapToSignal { participantCount -> Signal<([EnginePeer], Bool), NoError> in
            if case .peer = chatLocation, let memberCount = participantCount, memberCount <= 64 {
                return Signal { subscriber in
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: nil, requestUpdate: false, updated: { state in
                        if case .ready = state.loadingState {
                            let normalizedQuery = query.lowercased()
                            subscriber.putNext((state.list.compactMap { participant -> EnginePeer? in
                                if participant.peer.isDeleted {
                                    return nil
                                }
                                if normalizedQuery.isEmpty {
                                    return EnginePeer(participant.peer)
                                }
                                if normalizedQuery.isEmpty {
                                    return EnginePeer(participant.peer)
                                } else {
                                    if participant.peer.indexName.matchesByTokens(normalizedQuery) {
                                        return EnginePeer(participant.peer)
                                    }
                                    if let addressName = participant.peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
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
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, searchQuery: query.isEmpty ? nil : query, updated: { state in
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
                    let (disposable, _) = context.peerChannelMemberCategoriesContextsManager.mentions(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, threadMessageId: replyThreadMessage.messageId, searchQuery: query.isEmpty ? nil : query, updated: { state in
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
                    let normalizedQuery = query.lowercased()
                    if isReady {
                        if case let .channel(channel) = peer, case .group = channel.info {
                            var matches = false
                            if normalizedQuery.isEmpty {
                                matches = true
                            } else {
                                if channel.indexName.matchesByTokens(normalizedQuery) {
                                    matches = true
                                }
                                if let addressName = channel.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
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
        return context.engine.peers.searchGroupMembers(peerId: peerId, query: query)
        |> map { peers -> [EnginePeer] in
            return peers.map(EnginePeer.init)
        }
    }
}
