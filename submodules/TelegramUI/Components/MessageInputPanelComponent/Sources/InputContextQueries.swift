import Foundation
import SwiftSignalKit
import TextFieldComponent
import ChatContextQuery
import AccountContext

func textInputStateContextQueryRangeAndType(inputState: TextFieldComponent.InputState) -> [(NSRange, PossibleContextQueryTypes, NSRange?)] {
    return textInputStateContextQueryRangeAndType(inputText: inputState.inputText, selectionRange: inputState.selectionRange)
}

func inputContextQueries(_ inputState: TextFieldComponent.InputState) -> [ChatPresentationInputQuery] {
    let inputString: NSString = inputState.inputText.string as NSString
    var result: [ChatPresentationInputQuery] = []
    for (possibleQueryRange, possibleTypes, additionalStringRange) in textInputStateContextQueryRangeAndType(inputText: inputState.inputText, selectionRange: inputState.selectionRange) {
        let query = inputString.substring(with: possibleQueryRange)
        if possibleTypes == [.emoji] {
            result.append(.emoji(query.basicEmoji.0))
        } else if possibleTypes == [.hashtag] {
            result.append(.hashtag(query))
        } else if possibleTypes == [.mention] {
            let types: ChatInputQueryMentionTypes = [.members]
//            if possibleQueryRange.lowerBound == 1 {
//                types.insert(.contextBots)
//            }
            result.append(.mention(query: query, types: types))
        } else if possibleTypes == [.command] {
            result.append(.command(query))
        } else if possibleTypes == [.contextRequest], let additionalStringRange = additionalStringRange {
            let additionalString = inputString.substring(with: additionalStringRange)
            result.append(.contextRequest(addressName: query, query: additionalString))
        }
//        else if possibleTypes == [.emojiSearch], !query.isEmpty, let inputLanguage = chatPresentationInterfaceState.interfaceState.inputLanguage {
//            result.append(.emojiSearch(query: query, languageCode: inputLanguage, range: possibleQueryRange))
//        }
    }
    return result
}

func contextQueryResultState(context: AccountContext, inputState: TextFieldComponent.InputState, currentQueryStates: inout [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)]) -> [ChatPresentationInputQueryKind: ChatContextQueryUpdate] {
    let inputQueries = inputContextQueries(inputState).filter({ query in
        switch query {
        case .contextRequest, .command, .emoji:
            return false
        default:
            return true
        }
    })
    
    var updates: [ChatPresentationInputQueryKind: ChatContextQueryUpdate] = [:]
    
    for query in inputQueries {
        let previousQuery = currentQueryStates[query.kind]?.0
        if previousQuery != query {
            let signal = updatedContextQueryResultStateForQuery(context: context, inputQuery: query, previousQuery: previousQuery)
            updates[query.kind] = .update(query, signal)
        }
    }
    
    for currentQueryKind in currentQueryStates.keys {
        var found = false
        inner: for query in inputQueries {
            if query.kind == currentQueryKind {
                found = true
                break inner
            }
        }
        if !found {
            updates[currentQueryKind] = .remove
        }
    }
    
    return updates
}

private func updatedContextQueryResultStateForQuery(context: AccountContext, inputQuery: ChatPresentationInputQuery, previousQuery: ChatPresentationInputQuery?) -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> {
    switch inputQuery {
    case let .hashtag(query):
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
        if let previousQuery = previousQuery {
            switch previousQuery {
                case .hashtag:
                    break
                default:
                    signal = .single({ _ in return .hashtags([]) })
            }
        } else {
            signal = .single({ _ in return .hashtags([]) })
        }
        
        let hashtags: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = context.engine.messages.recentlyUsedHashtags()
        |> map { hashtags -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
            let normalizedQuery = query.lowercased()
            var result: [String] = []
            for hashtag in hashtags {
                if hashtag.lowercased().hasPrefix(normalizedQuery) {
                    result.append(hashtag)
                }
            }
            return { _ in return .hashtags(result) }
        }
        |> castError(ChatContextQueryError.self)
        
        return signal |> then(hashtags)
    case let .mention(query, _):
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
        if let previousQuery = previousQuery {
            switch previousQuery {
                case .mention:
                    break
                default:
                    signal = .single({ _ in return .mentions([]) })
            }
        } else {
            signal = .single({ _ in return .mentions([]) })
        }
        
        let normalizedQuery = query.lowercased()
        let peers: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = context.engine.contacts.searchLocalPeers(query: normalizedQuery)
        |> map { peersAndPresences -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
            let peers = peersAndPresences.filter { peer in
                if let peer = peer.peer, case .user = peer {
                    return true
                } else {
                    return false
                }
            }.compactMap { $0.peer }
            return { _ in return .mentions(peers) }
        }
        |> castError(ChatContextQueryError.self)
        
        return signal |> then(peers)
    default:
        return .complete()
    }
}
