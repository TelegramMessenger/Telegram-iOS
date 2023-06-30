import Foundation
import SwiftSignalKit
import TelegramCore
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
                if let peer = peer.peer, case .user = peer, peer.addressName != nil {
                    return true
                } else {
                    return false
                }
            }.compactMap { $0.peer }
            return { _ in return .mentions(peers) }
        }
        |> castError(ChatContextQueryError.self)
        
        return signal |> then(peers)
    case let .emojiSearch(query, languageCode, range):
        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { peer -> Bool in
            guard case let .user(user) = peer else {
                return false
            }
            return user.isPremium
        }
        |> distinctUntilChanged
    
        if query.isSingleEmoji {
            return combineLatest(
                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                hasPremium
            )
            |> map { view, hasPremium -> [(String, TelegramMediaFile?, String)] in
                var result: [(String, TelegramMediaFile?, String)] = []
                
                for entry in view.entries {
                    guard let item = entry.item as? StickerPackItem else {
                        continue
                    }
                    for attribute in item.file.attributes {
                        switch attribute {
                        case let .CustomEmoji(_, _, alt, _):
                            if alt == query {
                                if !item.file.isPremiumEmoji || hasPremium {
                                    result.append((alt, item.file, alt))
                                }
                            }
                        default:
                            break
                        }
                    }
                }
                return result
            }
            |> map { result -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                return { _ in return .emojis(result, range) }
            }
            |> castError(ChatContextQueryError.self)
        } else {
            var signal = context.engine.stickers.searchEmojiKeywords(inputLanguageCode: languageCode, query: query, completeMatch: query.count < 2)
            if !languageCode.lowercased().hasPrefix("en") {
                signal = signal
                |> mapToSignal { keywords in
                    return .single(keywords)
                    |> then(
                        context.engine.stickers.searchEmojiKeywords(inputLanguageCode: "en-US", query: query, completeMatch: query.count < 3)
                        |> map { englishKeywords in
                            return keywords + englishKeywords
                        }
                    )
                }
            }
            
            return signal
            |> castError(ChatContextQueryError.self)
            |> mapToSignal { keywords -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> in
                return combineLatest(
                    context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
                    hasPremium
                )
                |> map { view, hasPremium -> [(String, TelegramMediaFile?, String)] in
                    var result: [(String, TelegramMediaFile?, String)] = []
                    
                    var allEmoticons: [String: String] = [:]
                    for keyword in keywords {
                        for emoticon in keyword.emoticons {
                            allEmoticons[emoticon] = keyword.keyword
                        }
                    }
                    
                    for entry in view.entries {
                        guard let item = entry.item as? StickerPackItem else {
                            continue
                        }
                        for attribute in item.file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, _, alt, _):
                                if !alt.isEmpty, let keyword = allEmoticons[alt] {
                                    if !item.file.isPremiumEmoji || hasPremium {
                                        result.append((alt, item.file, keyword))
                                    }
                                }
                            default:
                                break
                            }
                        }
                    }
                    
                    for keyword in keywords {
                        for emoticon in keyword.emoticons {
                            result.append((emoticon, nil, keyword.keyword))
                        }
                    }
                    return result
                }
                |> map { result -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in return .emojis(result, range) }
                }
                |> castError(ChatContextQueryError.self)
            }
        }
    default:
        return .complete()
    }
}
