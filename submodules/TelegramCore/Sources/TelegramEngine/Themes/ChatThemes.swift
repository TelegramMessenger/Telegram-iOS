import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public struct ChatTheme: Codable, Equatable {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.emoji = try container.decode(String.self, forKey: "e")

        let themeData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "t")
        self.theme = TelegramTheme(decoder: PostboxDecoder(buffer: MemoryBuffer(data: themeData.data)))

        let darkThemeData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "dt")
        self.darkTheme = TelegramTheme(decoder: PostboxDecoder(buffer: MemoryBuffer(data: darkThemeData.data)))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.emoji, forKey: "e")
        try container.encode(PostboxEncoder().encodeObjectToRawData(self.theme), forKey: "t")
        try container.encode(PostboxEncoder().encodeObjectToRawData(self.darkTheme), forKey: "dt")
    }
}

public final class ChatThemes: Codable, Equatable {
    public let chatThemes: [ChatTheme]
    public let hash: Int32
 
    public init(chatThemes: [ChatTheme], hash: Int32) {
        self.chatThemes = chatThemes
        self.hash = hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.chatThemes = try container.decode([ChatTheme].self, forKey: "c")
        self.hash = try container.decode(Int32.self, forKey: "h")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.chatThemes, forKey: "c")
        try container.encode(self.hash, forKey: "h")
    }
    
    public static func ==(lhs: ChatThemes, rhs: ChatThemes) -> Bool {
        return lhs.chatThemes == rhs.chatThemes && lhs.hash == rhs.hash
    }
}

func _internal_getChatThemes(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, forceUpdate: Bool = false, onlyCached: Bool = false) -> Signal<[ChatTheme], NoError> {
    let fetch: ([ChatTheme]?, Int32?) -> Signal<[ChatTheme], NoError> = { current, hash in
        return network.request(Api.functions.account.getChatThemes(hash: 0))
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
                                return PreferencesEntry(ChatThemes(chatThemes: result, hash: hash))
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
            if let chatThemes = sharedData.entries[SharedDataKeys.chatThemes]?.get(ChatThemes.self) {
                return (chatThemes.chatThemes, chatThemes.hash)
            } else {
                return ([], 0)
            }
        }
        |> mapToSignal { current, hash -> Signal<[ChatTheme], NoError> in
            if onlyCached {
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
