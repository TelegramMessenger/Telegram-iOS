import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

func contextQueryResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentQuery: ChatPresentationInputQuery?) -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)? {
    if let inputQuery = inputContextQueryForChatPresentationIntefaceState(chatPresentationInterfaceState) {
        if inputQuery == currentQuery {
            return nil
        } else {
            switch inputQuery {
                case let .emoji(query):
                    var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                    if let currentQuery = currentQuery {
                        switch currentQuery {
                            case .emoji:
                                break
                            default:
                                signal = .single({ _ in return nil })
                        }
                    }
                    let stickers: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = searchStickers(postbox: account.postbox, query: query)
                        |> map { stickers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                            return { _ in
                                return .stickers(stickers)
                            }
                        }
                    return (inputQuery, signal |> then(stickers))
                case let .hashtag(query):
                    var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                    if let currentQuery = currentQuery {
                        switch currentQuery {
                            case .hashtag:
                                break
                            default:
                                signal = .single({ _ in return nil })
                        }
                    }
                    
                    let hashtags: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = recentlyUsedHashtags(postbox: account.postbox) |> map { hashtags -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                        let normalizedQuery = query.lowercased()
                        var result: [String] = []
                        for hashtag in hashtags {
                            if hashtag.lowercased().hasPrefix(normalizedQuery) {
                                result.append(hashtag)
                            }
                        }
                        return { _ in return .hashtags(result) }
                    }
                    
                    return (inputQuery, signal |> then(hashtags))
                case let .mention(query):
                    let normalizedQuery = query.lowercased()
                    
                    if let peer = chatPresentationInterfaceState.peer {
                        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                        if let currentQuery = currentQuery {
                            switch currentQuery {
                                case .mention:
                                    break
                                default:
                                    signal = .single({ _ in return nil })
                            }
                        }
                        
                        let participants = peerParticipants(account: account, id: peer.id)
                            |> map { peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                                let filteredPeers = peers.filter { peer in
                                    if peer.indexName.matchesByTokens(normalizedQuery) {
                                        return true
                                    }
                                    if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                                        return true
                                    }
                                    return false
                                }
                                let sortedPeers = filteredPeers.sorted(by: { lhs, rhs in
                                    let result = lhs.indexName.indexName(.lastNameFirst).compare(rhs.indexName.indexName(.lastNameFirst))
                                    return result == .orderedAscending
                                })
                                return { _ in return .mentions(sortedPeers) }
                            }
                        
                        return (inputQuery, signal |> then(participants))
                    } else {
                        return (nil, .single({ _ in return nil }))
                    }
                case let .command(query):
                    let normalizedQuery = query.lowercased()
                    
                    if let peer = chatPresentationInterfaceState.peer {
                        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                        if let currentQuery = currentQuery {
                            switch currentQuery {
                                case .command:
                                    break
                                default:
                                    signal = .single({ _ in return nil })
                            }
                        }
                        
                        let participants = peerCommands(account: account, id: peer.id)
                            |> map { commands -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                                let filteredCommands = commands.commands.filter { command in
                                    if command.command.text.hasPrefix(normalizedQuery) {
                                        return true
                                    }
                                    return false
                                }
                                let sortedCommands = filteredCommands
                                return { _ in return .commands(sortedCommands) }
                        }
                        
                        return (inputQuery, signal |> then(participants))
                    } else {
                        return (nil, .single({ _ in return nil }))
                    }
                case let .contextRequest(addressName, query):
                    guard let chatPeer = chatPresentationInterfaceState.peer else {
                        return (nil, .single({ _ in return nil }))
                    }
                    
                    var delayRequest = true
                    var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                    if let currentQuery = currentQuery {
                        switch currentQuery {
                            case let .contextRequest(currentAddressName, currentContextQuery) where currentAddressName == addressName:
                                if query.isEmpty && !currentContextQuery.isEmpty {
                                    delayRequest = false
                                }
                            default:
                                delayRequest = false
                                signal = .single({ _ in return nil })
                        }
                    }
                    
                    let contextBot = resolvePeerByName(account: account, name: addressName)
                        |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                            if let peerId = peerId {
                                return account.postbox.loadedPeerWithId(peerId)
                                    |> map { peer -> Peer? in
                                        return peer
                                    }
                                    |> take(1)
                            } else {
                                return .single(nil)
                            }
                        }
                        |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> in
                            if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                                let contextResults = requestChatContextResults(account: account, botId: user.id, peerId: chatPeer.id, query: query, offset: "")
                                    |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                                        return { _ in
                                            return .contextRequestResult(user, results)
                                        }
                                    }
                                
                                let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .single({ previousResult in
                                    var passthroughPreviousResult: ChatContextResultCollection?
                                    if let previousResult = previousResult {
                                        if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                                            if previousUser.id == user.id {
                                                passthroughPreviousResult = previousResults
                                            }
                                        }
                                    }
                                    return .contextRequestResult(user, passthroughPreviousResult)
                                })
                                
                                let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>
                                if delayRequest {
                                    maybeDelayedContextResults = contextResults |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                                } else {
                                    maybeDelayedContextResults = contextResults
                                }
                                
                                return botResult |> then(maybeDelayedContextResults)
                            } else {
                                return .single({ _ in return nil })
                            }
                        }
                    
                    return (inputQuery, signal |> then(contextBot))
            }
        }
    } else {
        return (nil, .single({ _ in return nil }))
    }
}

private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)

func urlPreviewStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentQuery: String?) -> (String?, Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError>)? {
    if let dataDetector = dataDetector {
        let text = chatPresentationInterfaceState.interfaceState.composeInputState.inputText
        let utf16 = text.utf16
        
        var detectedUrl: String?
        
        let matches = dataDetector.matches(in: text, options: [], range: NSRange(location: 0, length: utf16.count))
        if let match = matches.first {
            let urlText = (text as NSString).substring(with: match.range)
            detectedUrl = urlText
        }
        
        if detectedUrl != currentQuery {
            if let detectedUrl = detectedUrl {
                return (detectedUrl, webpagePreview(account: account, url: detectedUrl) |> map { value in
                    return { _ in return value }
                })
            } else {
                return (nil, .single({ _ in return nil }))
            }
        } else {
            return nil
        }
    } else {
        return (nil, .single({ _ in return nil }))
    }
}
