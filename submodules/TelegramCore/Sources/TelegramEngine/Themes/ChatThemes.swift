import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public struct ChatTheme: PostboxCoding, Equatable {
    public static func == (lhs: ChatTheme, rhs: ChatTheme) -> Bool {
        return lhs.emoji == rhs.emoji && lhs.theme == rhs.theme && lhs.darkTheme == rhs.darkTheme
    }

    public let emoji: String
    public let theme: TelegramTheme
    public let darkTheme: TelegramTheme
    
    public init(emoji: String, theme: TelegramTheme, darkTheme: TelegramTheme) {
        self.emoji = emoji
        self.theme = theme
        self.darkTheme = darkTheme
    }
    
    public init(decoder: PostboxDecoder) {
        self.emoji = decoder.decodeStringForKey("e", orElse: "")
        self.theme = decoder.decodeObjectForKey("t", decoder: { TelegramTheme(decoder: $0) }) as! TelegramTheme
        self.darkTheme = decoder.decodeObjectForKey("dt", decoder: { TelegramTheme(decoder: $0) }) as! TelegramTheme
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.emoji, forKey: "e")
        encoder.encodeObject(self.theme, forKey: "t")
        encoder.encodeObject(self.darkTheme, forKey: "dt")
    }
}


public final class ChatThemes: PreferencesEntry, Equatable {
    public let chatThemes: [ChatTheme]
    public let hash: Int32
 
    public init(chatThemes: [ChatTheme], hash: Int32) {
        self.chatThemes = chatThemes
        self.hash = hash
    }
    
    public init(decoder: PostboxDecoder) {
        self.chatThemes = decoder.decodeObjectArrayForKey("c").map { $0 as! ChatTheme }
        self.hash = decoder.decodeInt32ForKey("h", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.chatThemes, forKey: "c")
        encoder.encodeInt32(self.hash, forKey: "h")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatThemes {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: ChatThemes, rhs: ChatThemes) -> Bool {
        return lhs.chatThemes == rhs.chatThemes && lhs.hash == rhs.hash
    }
}

func _internal_getChatThemes(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, forceUpdate: Bool = false, onlyCached: Bool = false) -> Signal<[ChatTheme], NoError> {
    let fetch: ([ChatTheme]?, Int32?) -> Signal<[ChatTheme], NoError> = { current, hash in
        return network.request(Api.functions.account.getChatThemes(hash: hash ?? 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<[ChatTheme], NoError> in
            switch result {
                case let .chatThemes(hash, apiThemes):
                    let result = apiThemes.compactMap { ChatTheme(apiChatTheme: $0) }
                    if result == current {
                        return .complete()
                    } else {
                        let _ = accountManager.transaction { transaction in
                            transaction.updateSharedData(SharedDataKeys.chatThemes, { _ in
                                return ChatThemes(chatThemes: result, hash: hash)
                            })
                        }.start()
                        return .single(result)
                    }
                case .chatThemesNotModified:
                    return .complete()
            }
        }
    }
    
    if forceUpdate {
        return fetch(nil, nil)
    } else {
        return accountManager.sharedData(keys: [SharedDataKeys.chatThemes])
        |> take(1)
        |> map { sharedData -> ([ChatTheme], Int32) in
            if let chatThemes = sharedData.entries[SharedDataKeys.chatThemes] as? ChatThemes {
                return (chatThemes.chatThemes, chatThemes.hash)
            } else {
                return ([], 0)
            }
        }
        |> mapToSignal { current, hash -> Signal<[ChatTheme], NoError> in
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

extension ChatTheme {
    init(apiChatTheme: Api.ChatTheme) {
        switch apiChatTheme {
            case let .chatTheme(emoticon, theme, darkTheme):
                self.init(emoji: emoticon, theme: TelegramTheme(apiTheme: theme), darkTheme: TelegramTheme(apiTheme: darkTheme))
        }
    }
}

func managedChatThemesUpdates(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network) -> Signal<Void, NoError> {
    let poll = _internal_getChatThemes(accountManager: accountManager, network: network)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
