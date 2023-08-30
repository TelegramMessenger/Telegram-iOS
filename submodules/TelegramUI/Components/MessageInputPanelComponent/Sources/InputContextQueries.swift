import Foundation
import SwiftSignalKit
import TelegramCore
import TextFieldComponent
import ChatContextQuery
import AccountContext
import TelegramUIPreferences
import SearchPeerMembers

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

func contextQueryResultState(context: AccountContext, inputState: TextFieldComponent.InputState, availableTypes: [ChatPresentationInputQueryKind], chatLocation: ChatLocation?, currentQueryStates: inout [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)]) -> [ChatPresentationInputQueryKind: ChatContextQueryUpdate] {
    let inputQueries = inputContextQueries(inputState).filter({ query in
        return availableTypes.contains(query.kind)
    })
    
    var updates: [ChatPresentationInputQueryKind: ChatContextQueryUpdate] = [:]
    
    for query in inputQueries {
        let previousQuery = currentQueryStates[query.kind]?.0
        if previousQuery != query {
            let signal = updatedContextQueryResultStateForQuery(context: context, chatLocation: chatLocation, inputQuery: query, previousQuery: previousQuery)
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

private func updatedContextQueryResultStateForQuery(context: AccountContext, chatLocation: ChatLocation?, inputQuery: ChatPresentationInputQuery, previousQuery: ChatPresentationInputQuery?) -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> {
    switch inputQuery {
    case let .emoji(query):
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
        if let previousQuery = previousQuery {
            switch previousQuery {
                case .emoji:
                    break
                default:
                    signal = .single({ _ in return .stickers([]) })
            }
        } else {
            signal = .single({ _ in return .stickers([]) })
        }
        
        let stickerConfiguration = context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        |> map { preferencesView -> StickersSearchConfiguration in
            let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
            return StickersSearchConfiguration.with(appConfiguration: appConfiguration)
        }
        let stickerSettings = context.sharedContext.accountManager.transaction { transaction -> StickerSettings in
            let stickerSettings: StickerSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.stickerSettings)?.get(StickerSettings.self) ?? .defaultSettings
            return stickerSettings
        }

        let stickers: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = combineLatest(stickerConfiguration, stickerSettings)
        |> castError(ChatContextQueryError.self)
        |> mapToSignal { stickerConfiguration, stickerSettings -> Signal<[FoundStickerItem], ChatContextQueryError> in
            let scope: SearchStickersScope
            switch stickerSettings.emojiStickerSuggestionMode {
                case .none:
                    scope = []
                case .all:
                    if stickerConfiguration.disableLocalSuggestions {
                        scope = [.remote]
                    } else {
                        scope = [.installed, .remote]
                    }
                case .installed:
                    scope = [.installed]
            }
            return context.engine.stickers.searchStickers(query: [query.basicEmoji.0], scope: scope)
            |> map { items -> [FoundStickerItem] in
                return items.items
            }
            |> castError(ChatContextQueryError.self)
        }
        |> map { stickers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
            return { _ in
                return .stickers(stickers)
            }
        }
        return signal |> then(stickers)
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
    case let .mention(query, types):
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
        
        if let chatLocation, let peerId = chatLocation.peerId {
            let inlineBots: Signal<[(EnginePeer, Double)], NoError> = types.contains(.contextBots) ? context.engine.peers.recentlyUsedInlineBots() : .single([])
            let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
            let participants = combineLatest(inlineBots, searchPeerMembers(context: context, peerId: peerId, chatLocation: chatLocation, query: query, scope: .mention))
            |> map { inlineBots, peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                let filteredInlineBots = inlineBots.sorted(by: { $0.1 > $1.1 }).filter { peer, rating in
                    if rating < 0.14 {
                        return false
                    }
                    if peer.indexName.matchesByTokens(normalizedQuery) {
                        return true
                    }
                    if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                        return true
                    }
                    return false
                }.map { $0.0 }
                
                let inlineBotPeerIds = Set(filteredInlineBots.map { $0.id })
                
                let filteredPeers = peers.filter { peer in
                    if inlineBotPeerIds.contains(peer.id) {
                        return false
                    }
                    if !types.contains(.accountPeer) && peer.id == context.account.peerId {
                        return false
                    }
                    return true
                }
                var sortedPeers = filteredInlineBots
                sortedPeers.append(contentsOf: filteredPeers.sorted(by: { lhs, rhs in
                    let result = lhs.indexName.stringRepresentation(lastNameFirst: true).compare(rhs.indexName.stringRepresentation(lastNameFirst: true))
                    return result == .orderedAscending
                }))
                sortedPeers = sortedPeers.filter { peer in
                    return !peer.displayTitle(strings: strings, displayOrder: .firstLast).isEmpty
                }
                return { _ in return .mentions(sortedPeers) }
            }
            |> castError(ChatContextQueryError.self)
            
            return signal |> then(participants)
        } else {
            if normalizedQuery.isEmpty {
                let peers: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = context.engine.peers.recentPeers()
                |> map { recentPeers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    if case let .peers(peers) = recentPeers {
                        let peers = peers.filter { peer in
                            return peer.addressName != nil
                        }.compactMap { EnginePeer($0) }
                        return { _ in return .mentions(peers) }
                    } else {
                        return { _ in return .mentions([]) }
                    }
                }
                |> castError(ChatContextQueryError.self)
                return signal |> then(peers)
            } else {
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
            }
        }
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
