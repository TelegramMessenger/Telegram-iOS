import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public final class ChatThemes: Codable, Equatable {
    public let chatThemes: [TelegramTheme]
    public let hash: Int64
 
    public init(chatThemes: [TelegramTheme], hash: Int64) {
        self.chatThemes = chatThemes
        self.hash = hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.chatThemes = try container.decode([TelegramThemeNativeCodable].self, forKey: "c").map { $0.value }
        self.hash = try container.decode(Int64.self, forKey: "h")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.chatThemes.map { TelegramThemeNativeCodable($0) }, forKey: "c")
        try container.encode(self.hash, forKey: "h")
    }
    
    public static func ==(lhs: ChatThemes, rhs: ChatThemes) -> Bool {
        return lhs.chatThemes == rhs.chatThemes && lhs.hash == rhs.hash
    }
}

func _internal_getChatThemes(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, forceUpdate: Bool = false, onlyCached: Bool = false) -> Signal<[TelegramTheme], NoError> {
    let fetch: ([TelegramTheme]?, Int64?) -> Signal<[TelegramTheme], NoError> = { current, hash in
        return network.request(Api.functions.account.getChatThemes(hash: hash ?? 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<[TelegramTheme], NoError> in
            switch result {
                case let .themes(hash, apiThemes):
                    let result = apiThemes.compactMap { TelegramTheme(apiTheme: $0) }
                    if result == current {
                        return .complete()
                    } else {
                        let _ = accountManager.transaction { transaction in
                            transaction.updateSharedData(SharedDataKeys.chatThemes, { _ in
                                return PreferencesEntry(ChatThemes(chatThemes: result, hash: hash))
                            })
                        }.start()
                        return .single(result)
                    }
                case .themesNotModified:
                    return .complete()
            }
        }
    }
    
    if forceUpdate {
        return fetch(nil, nil)
    } else {
        return accountManager.sharedData(keys: [SharedDataKeys.chatThemes])
        |> take(1)
        |> map { sharedData -> ([TelegramTheme], Int64) in
            if let chatThemes = sharedData.entries[SharedDataKeys.chatThemes]?.get(ChatThemes.self) {
                return (chatThemes.chatThemes, chatThemes.hash)
            } else {
                return ([], 0)
            }
        }
        |> mapToSignal { current, hash -> Signal<[TelegramTheme], NoError> in
            if onlyCached && !current.isEmpty {
                return .single(current)
            } else {
                return .single(current)
                |> then(fetch(current, hash))
            }
        }
    }
}

func _internal_setChatTheme(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, emoticon: String?) -> Signal<Void, NoError> {
    return postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                if let current = current as? CachedUserData {
                    return current.withUpdatedThemeEmoticon(emoticon)
                } else if let current = current as? CachedGroupData {
                    return current.withUpdatedThemeEmoticon(emoticon)
                } else if let current = current as? CachedChannelData {
                    return current.withUpdatedThemeEmoticon(emoticon)
                } else {
                    return current
                }
            })
            
            return network.request(Api.functions.messages.setChatTheme(peer: inputPeer, emoticon: emoticon ?? ""))
            |> `catch` { error in
                return .complete()
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                stateManager.addUpdates(updates)
                return .complete()
            }
        } |> switchToLatest
    }
}

func managedChatThemesUpdates(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network) -> Signal<Void, NoError> {
    let poll = _internal_getChatThemes(accountManager: accountManager, network: network)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
