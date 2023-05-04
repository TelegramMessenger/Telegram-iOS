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

func _internal_setChatTheme(account: Account, peerId: PeerId, emoticon: String?) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        
        return account.postbox.transaction { transaction -> Signal<Void, NoError> in
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
            
            return account.network.request(Api.functions.messages.setChatTheme(peer: inputPeer, emoticon: emoticon ?? ""))
            |> `catch` { error in
                return .complete()
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                account.stateManager.addUpdates(updates)
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

public enum SetChatWallpaperError {
    case generic
    case flood
}

func _internal_setChatWallpaper(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, wallpaper: TelegramWallpaper?, applyUpdates: Bool = true) -> Signal<Api.Updates, SetChatWallpaperError> {
    return postbox.loadedPeerWithId(peerId)
    |> castError(SetChatWallpaperError.self)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        return postbox.transaction { transaction -> Signal<Api.Updates, SetChatWallpaperError> in
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                if let current = current as? CachedUserData {
                    return current.withUpdatedWallpaper(wallpaper)
                } else {
                    return current
                }
            })
            
            var flags: Int32 = 0
            var inputWallpaper: Api.InputWallPaper?
            var inputSettings: Api.WallPaperSettings?
            if let inputWallpaperAndInputSettings = wallpaper?.apiInputWallpaperAndSettings {
                flags |= 1 << 0
                flags |= 1 << 2
                inputWallpaper = inputWallpaperAndInputSettings.0
                inputSettings = inputWallpaperAndInputSettings.1
            }
            return network.request(Api.functions.messages.setChatWallPaper(flags: flags, peer: inputPeer, wallpaper: inputWallpaper, settings: inputSettings, id: nil), automaticFloodWait: false)
            |> mapError { error -> SetChatWallpaperError in
                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .flood
                } else {
                    return .generic
                }
            }
            |> mapToSignal { updates -> Signal<Api.Updates, SetChatWallpaperError> in
                if applyUpdates {
                    stateManager.addUpdates(updates)
                }
                return .single(updates)
            }
        }
        |> castError(SetChatWallpaperError.self)
        |> switchToLatest
    }
}

public enum SetExistingChatWallpaperError {
    case generic
}

func _internal_setExistingChatWallpaper(account: Account, messageId: MessageId, settings: WallpaperSettings?) -> Signal<Void, SetExistingChatWallpaperError> {
    return account.postbox.transaction { transaction -> Peer? in
        if let peer = transaction.getPeer(messageId.peerId), let message = transaction.getMessage(messageId) {
            if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .setChatWallpaper(wallpaper) = action.action {
                var wallpaper = wallpaper
                if let settings = settings {
                    wallpaper = wallpaper.withUpdatedSettings(settings)
                }
                transaction.updatePeerCachedData(peerIds: Set([peer.id]), update: { _, current in
                    if let current = current as? CachedUserData {
                        return current.withUpdatedWallpaper(wallpaper)
                    } else {
                        return current
                    }
                })
            }
            return peer
        } else {
            return nil
        }
    }
    |> castError(SetExistingChatWallpaperError.self)
    |> mapToSignal { peer -> Signal<Void, SetExistingChatWallpaperError> in
        guard let peer = peer, let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        var flags: Int32 = 1 << 1
        
        var inputSettings: Api.WallPaperSettings?
        if let settings = settings {
            flags |= 1 << 2
            inputSettings = apiWallpaperSettings(settings)
        }
        return account.network.request(Api.functions.messages.setChatWallPaper(flags: flags, peer: inputPeer, wallpaper: nil, settings: inputSettings, id: messageId.id), automaticFloodWait: false)
        |> `catch` { _ -> Signal<Api.Updates, SetExistingChatWallpaperError> in
            return .fail(.generic)
        }
        |> mapToSignal { updates -> Signal<Void, SetExistingChatWallpaperError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
}
