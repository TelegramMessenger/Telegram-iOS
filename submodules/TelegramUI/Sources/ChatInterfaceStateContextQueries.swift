import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramUIPreferences
import LegacyComponents
import TextFormat
import AccountContext
import Emoji
import SearchPeerMembers
import DeviceLocationManager
import TelegramNotices
import ChatPresentationInterfaceState

enum ChatContextQueryError {
    case generic
    case inlineBotLocationRequest(PeerId)
}

enum ChatContextQueryUpdate {
    case remove
    case update(ChatPresentationInputQuery, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError>)
}

func contextQueryResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentQueryStates: inout [ChatPresentationInputQueryKind: (ChatPresentationInputQuery, Disposable)], requestBotLocationStatus: @escaping (PeerId) -> Void) -> [ChatPresentationInputQueryKind: ChatContextQueryUpdate] {
    guard let peer = chatPresentationInterfaceState.renderedPeer?.peer else {
        return [:]
    }
    let inputQueries = inputContextQueriesForChatPresentationIntefaceState(chatPresentationInterfaceState).filter({ query in
        if chatPresentationInterfaceState.editMessageState != nil {
            switch query {
                case .contextRequest, .command, .emoji:
                    return false
                default:
                    return true
            }
        } else {
            return true
        }
    })
    
    var updates: [ChatPresentationInputQueryKind: ChatContextQueryUpdate] = [:]
    
    for query in inputQueries {
        let previousQuery = currentQueryStates[query.kind]?.0
        if previousQuery != query {
            let signal = updatedContextQueryResultStateForQuery(context: context, peer: peer, chatLocation: chatPresentationInterfaceState.chatLocation, inputQuery: query, previousQuery: previousQuery, requestBotLocationStatus: requestBotLocationStatus)
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

struct StickersSearchConfiguration {
    static var defaultValue: StickersSearchConfiguration {
        return StickersSearchConfiguration(disableLocalSuggestions: false)
    }
    
    public let disableLocalSuggestions: Bool
    
    fileprivate init(disableLocalSuggestions: Bool) {
        self.disableLocalSuggestions = disableLocalSuggestions
    }
    
    static func with(appConfiguration: AppConfiguration) -> StickersSearchConfiguration {
        if let data = appConfiguration.data, let suggestOnlyApi = data["stickers_emoji_suggest_only_api"] as? Bool {
            return StickersSearchConfiguration(disableLocalSuggestions: suggestOnlyApi)
        } else {
            return .defaultValue
        }
    }
}

private func updatedContextQueryResultStateForQuery(context: AccountContext, peer: Peer, chatLocation: ChatLocation, inputQuery: ChatPresentationInputQuery, previousQuery: ChatPresentationInputQuery?, requestBotLocationStatus: @escaping (PeerId) -> Void) -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> {
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
                return context.engine.stickers.searchStickers(query: query.basicEmoji.0, scope: scope)
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
            let normalizedQuery = query.lowercased()
            
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
            
            let inlineBots: Signal<[(EnginePeer, Double)], NoError> = types.contains(.contextBots) ? context.engine.peers.recentlyUsedInlineBots() : .single([])
            let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
            let participants = combineLatest(inlineBots, searchPeerMembers(context: context, peerId: peer.id, chatLocation: chatLocation, query: query, scope: .mention))
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
        case let .command(query):
            let normalizedQuery = query.lowercased()
            
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case .command:
                        break
                    default:
                        signal = .single({ _ in return .commands([]) })
                }
            } else {
                signal = .single({ _ in return .commands([]) })
            }
            
            let commands = context.engine.peers.peerCommands(id: peer.id)
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
            |> castError(ChatContextQueryError.self)
            return signal |> then(commands)
        case let .contextRequest(addressName, query):
            var delayRequest = true
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .complete()
            if let previousQuery = previousQuery {
                switch previousQuery {
                    case let .contextRequest(currentAddressName, currentContextQuery) where currentAddressName == addressName:
                        if query.isEmpty && !currentContextQuery.isEmpty {
                            delayRequest = false
                        }
                    default:
                        delayRequest = false
                        signal = .single({ _ in return .contextRequestResult(nil, nil) })
                }
            } else {
                signal = .single({ _ in return .contextRequestResult(nil, nil) })
            }
            
            let chatPeer = peer
            let contextBot = context.engine.peers.resolvePeerByName(name: addressName)
            |> castError(ChatContextQueryError.self)
            |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> in
                if case let .user(user) = peer, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                    let contextResults = context.engine.messages.requestChatContextResults(botId: user.id, peerId: chatPeer.id, query: query, location: context.sharedContext.locationManager.flatMap { locationManager -> Signal<(Double, Double)?, NoError> in
                        return `deferred` {
                            Queue.mainQueue().async {
                                requestBotLocationStatus(user.id)
                            }
                            
                            return ApplicationSpecificNotice.inlineBotLocationRequestStatus(accountManager: context.sharedContext.accountManager, peerId: user.id)
                            |> filter { $0 }
                            |> take(1)
                            |> mapToSignal { _ -> Signal<(Double, Double)?, NoError> in
                                return currentLocationManagerCoordinate(manager: locationManager, timeout: 5.0)
                                |> flatMap { coordinate -> (Double, Double) in
                                    return (coordinate.latitude, coordinate.longitude)
                                }
                            }
                        }
                    } ?? .single(nil), offset: "")
                    |> mapError { error -> ChatContextQueryError in
                        switch error {
                            case .generic:
                                return .generic
                            case .locationRequired:
                                return .inlineBotLocationRequest(user.id)
                        }
                    }
                    |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                        return { _ in
                            return .contextRequestResult(.user(user), results?.results)
                        }
                    }
                    
                    let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError> = .single({ previousResult in
                        var passthroughPreviousResult: ChatContextResultCollection?
                        if let previousResult = previousResult {
                            if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                                if previousUser?.id == user.id {
                                    passthroughPreviousResult = previousResults
                                }
                            }
                        }
                        return .contextRequestResult(.user(user), passthroughPreviousResult)
                    })
                    
                    let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, ChatContextQueryError>
                    if delayRequest {
                        maybeDelayedContextResults = contextResults
                        |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                    } else {
                        maybeDelayedContextResults = contextResults
                    }
                    
                    return botResult |> then(maybeDelayedContextResults)
                } else {
                    return .single({ _ in return nil })
                }
            }
            
            return signal |> then(contextBot)
        case let .emojiSearch(query, languageCode, range):
            if query.isSingleEmoji {
                let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> map { peer -> Bool in
                    guard case let .user(user) = peer else {
                        return false
                    }
                    return user.isPremium
                }
                |> distinctUntilChanged
                
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
                            case let .CustomEmoji(_, alt, _):
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
            
                let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> map { peer -> Bool in
                    guard case let .user(user) = peer else {
                        return false
                    }
                    return user.isPremium
                }
                |> distinctUntilChanged
                
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
                                case let .CustomEmoji(_, alt, _):
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
    }
}

func searchQuerySuggestionResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentQuery: ChatPresentationInputQuery?) -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)? {
    var inputQuery: ChatPresentationInputQuery?
    if let search = chatPresentationInterfaceState.search {
        switch search.domain {
            case .members:
                inputQuery = .mention(query: search.query, types: [.members, .accountPeer])
            default:
                break
        }
    }
    
    if let inputQuery = inputQuery {
        if inputQuery == currentQuery {
            return nil
        } else {
            switch inputQuery {
                case let .mention(query, _):
                    if let peer = chatPresentationInterfaceState.renderedPeer?.peer {
                        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
                        if let currentQuery = currentQuery {
                            switch currentQuery {
                            case .mention:
                                break
                            default:
                                signal = .single({ _ in return nil })
                            }
                        }
                        
                        let participants = searchPeerMembers(context: context, peerId: peer.id, chatLocation: chatPresentationInterfaceState.chatLocation, query: query, scope: .memberSuggestion)
                        |> map { peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                            let filteredPeers = peers
                            var sortedPeers: [EnginePeer] = []
                            sortedPeers.append(contentsOf: filteredPeers.sorted(by: { lhs, rhs in
                                let result = lhs.indexName.stringRepresentation(lastNameFirst: true).compare(rhs.indexName.stringRepresentation(lastNameFirst: true))
                                return result == .orderedAscending
                            }))
                            return { _ in return .mentions(sortedPeers) }
                        }
                        
                        return (inputQuery, signal |> then(participants))
                    } else {
                        return (nil, .single({ _ in return nil }))
                    }
                default:
                    return (nil, .single({ _ in return nil }))
            }
        }
    } else {
        return (nil, .single({ _ in return nil }))
    }
}

private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)

func detectUrl(_ inputText: NSAttributedString?) -> String? {
    var detectedUrl: String?
    if let text = inputText, let dataDetector = dataDetector {
        let utf16 = text.string.utf16
        
        let nsRange = NSRange(location: 0, length: utf16.count)
        let matches = dataDetector.matches(in: text.string, options: [], range: nsRange)
        if let match = matches.first {
            let urlText = (text.string as NSString).substring(with: match.range)
            detectedUrl = urlText
        }
        
        if detectedUrl == nil {
            inputText?.enumerateAttribute(ChatTextInputAttributes.textUrl, in: nsRange, options: [], using: { value, range, stop in
                if let value = value as? ChatTextInputTextUrlAttribute {
                    detectedUrl = value.url
                }
            })
        }
    }
    return detectedUrl
}

func urlPreviewStateForInputText(_ inputText: NSAttributedString?, context: AccountContext, currentQuery: String?) -> (String?, Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError>)? {
    guard let _ = inputText else {
        if currentQuery != nil {
            return (nil, .single({ _ in return nil }))
        } else {
            return nil
        }
    }
    if let _ = dataDetector {
        let detectedUrl = detectUrl(inputText)
        if detectedUrl != currentQuery {
            if let detectedUrl = detectedUrl {
                return (detectedUrl, webpagePreview(account: context.account, url: detectedUrl) |> map { value in
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
