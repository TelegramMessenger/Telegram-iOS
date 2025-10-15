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

public enum ChatTheme: PostboxCoding, Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case type
        case emoticon
        case gift
        case themeSettings
    }
    
    case emoticon(String)
    case gift(StarGift, [TelegramThemeSettings])
    
    public init(decoder: PostboxDecoder) {
        let type = decoder.decodeInt32ForKey(CodingKeys.type.rawValue, orElse: 0)
        switch type {
        case 0:
            self = .emoticon(decoder.decodeStringForKey(CodingKeys.emoticon.rawValue, orElse: ""))
        case 1:
            self = .gift(decoder.decodeObjectForKey(CodingKeys.gift.rawValue, decoder: { StarGift(decoder: $0) }) as! StarGift, decoder.decodeCodable([TelegramThemeSettings].self, forKey: CodingKeys.themeSettings.rawValue) ?? [])
        default:
            assertionFailure()
            self = .emoticon("")
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let type = try container.decode(Int32.self, forKey: .type)
        switch type {
        case 0:
            self = .emoticon(try container.decode(String.self, forKey: .emoticon))
        case 1:
            self = .gift(try container.decode(StarGift.self, forKey: .gift), try container.decode([TelegramThemeSettings].self, forKey: .themeSettings))
        default:
            assertionFailure()
            self = .emoticon("")
        }
    }
                                                    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case let .emoticon(emoticon):
            encoder.encodeInt32(0, forKey: CodingKeys.type.rawValue)
            encoder.encodeString(emoticon, forKey: CodingKeys.emoticon.rawValue)
        case let .gift(gift, themeSettings):
            encoder.encodeInt32(1, forKey: CodingKeys.type.rawValue)
            encoder.encodeObject(gift, forKey: CodingKeys.gift.rawValue)
            encoder.encodeCodable(themeSettings, forKey: CodingKeys.themeSettings.rawValue)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .emoticon(emoticon):
            try container.encode(0 as Int32, forKey: .type)
            try container.encode(emoticon, forKey: .emoticon)
        case let .gift(gift, themeSettings):
            try container.encode(1 as Int32, forKey: .type)
            try container.encode(gift, forKey: .gift)
            try container.encode(themeSettings, forKey: .themeSettings)
        }
    }
    
    public static func ==(lhs: ChatTheme, rhs: ChatTheme) -> Bool {
        switch lhs {
        case let .emoticon(emoticon):
            if case .emoticon(emoticon) = rhs {
                return true
            } else {
                return false
            }
        case let .gift(lhsGift, lhsThemeSettings):
            if case let .gift(rhsGift, rhsThemeSettings) = rhs {
                switch lhsGift {
                case let .generic(lhsGeneric):
                    switch rhsGift {
                    case let .generic(rhsGeneric):
                        return lhsGeneric == rhsGeneric && lhsThemeSettings == rhsThemeSettings
                    default:
                        return false
                    }
                case let .unique(lhsUnique):
                    switch rhsGift {
                    case let .unique(rhsUnique):
                        return lhsUnique.slug == rhsUnique.slug && lhsThemeSettings == rhsThemeSettings
                    default:
                        return false
                    }
                }
            } else {
                return false
            }
        }
    }
    
    public var isEmpty: Bool {
        if case .emoticon("") = self {
            return true
        } else {
            return false
        }
    }
    
    public var id: String {
        switch self {
        case let .emoticon(emoticon):
            return emoticon.strippedEmoji
        case let .gift(gift, _):
            if case let .unique(uniqueGift) = gift {
                return uniqueGift.slug
            } else {
                fatalError()
            }
        }
    }
    
    public func withThemePeerId(_ themePeerId: EnginePeer.Id?) -> ChatTheme {
        switch self {
        case .emoticon:
            return self
        case let .gift(gift, themeSettings):
            switch gift {
            case let .unique(uniqueGift):
                return .gift(.unique(uniqueGift.withThemePeerId(themePeerId)), themeSettings)
            case .generic:
                return self
            }
        }
    }
}

extension ChatTheme {
    init?(apiChatTheme: Api.ChatTheme) {
        switch apiChatTheme {
        case let .chatTheme(emoticon):
            self = .emoticon(emoticon)
        case let .chatThemeUniqueGift(gift, themeSettings):
            guard let gift = StarGift(apiStarGift: gift) else {
                return nil
            }
            self = .gift(gift, themeSettings.compactMap { TelegramThemeSettings(apiThemeSettings: $0) })
        }
    }
    
    var apiChatTheme: Api.InputChatTheme {
        switch self {
        case let .emoticon(emoticon):
            return .inputChatTheme(emoticon: emoticon)
        case let .gift(gift, _):
            switch gift {
            case let .unique(uniqueGift):
                return .inputChatThemeUniqueGift(slug: uniqueGift.slug)
            default:
                fatalError()
            }
        }
    }
}

func _internal_getChatThemes(accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, forceUpdate: Bool = false, onlyCached: Bool = false) -> Signal<[TelegramTheme], NoError> {
    let fetch: ([TelegramTheme]?, Int64?) -> Signal<[TelegramTheme], NoError> = { current, hash in
        return network.request(Api.functions.account.getChatThemes(hash: hash ?? 0))
        |> retryRequestIfNotFrozen
        |> mapToSignal { result -> Signal<[TelegramTheme], NoError> in
            guard let result else {
                return .complete()
            }
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

func _internal_setChatTheme(account: Account, peerId: PeerId, chatTheme: ChatTheme?) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> Signal<Void, NoError> in
            var chatTheme = chatTheme
            if case let .gift(gift, _) = chatTheme, case let .unique(uniqueGift) = gift, let previousThemePeerId = uniqueGift.themePeerId {
                transaction.updatePeerCachedData(peerIds: Set([previousThemePeerId]), update: { _, current in
                    if let current = current as? CachedUserData {
                        return current.withUpdatedChatTheme(nil)
                    } else if let current = current as? CachedGroupData {
                        return current.withUpdatedChatTheme(nil)
                    } else if let current = current as? CachedChannelData {
                        return current.withUpdatedChatTheme(nil)
                    } else {
                        return current
                    }
                })
            }
            chatTheme = chatTheme?.withThemePeerId(peerId)
            
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                if let current = current as? CachedUserData {
                    return current.withUpdatedChatTheme(chatTheme)
                } else if let current = current as? CachedGroupData {
                    return current.withUpdatedChatTheme(chatTheme)
                } else if let current = current as? CachedChannelData {
                    return current.withUpdatedChatTheme(chatTheme)
                } else {
                    return current
                }
            })
            
            let inputTheme: Api.InputChatTheme
            if let chatTheme {
                inputTheme = chatTheme.apiChatTheme
            } else {
                inputTheme = .inputChatThemeEmpty
            }
            return account.network.request(Api.functions.messages.setChatTheme(peer: inputPeer, theme: inputTheme))
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

func _internal_setChatWallpaper(postbox: Postbox, network: Network, stateManager: AccountStateManager, peerId: PeerId, wallpaper: TelegramWallpaper?, forBoth: Bool, applyUpdates: Bool = true) -> Signal<Api.Updates, SetChatWallpaperError> {
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
                } else if let current = current as? CachedChannelData {
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
            if forBoth {
                flags |= 1 << 3
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

public enum RevertChatWallpaperError {
    case generic
}

func _internal_revertChatWallpaper(account: Account, peerId: EnginePeer.Id) -> Signal<Void, RevertChatWallpaperError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> castError(RevertChatWallpaperError.self)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        let flags: Int32 = 1 << 4
        return account.network.request(Api.functions.messages.setChatWallPaper(flags: flags, peer: inputPeer, wallpaper: nil, settings: nil, id: nil), automaticFloodWait: false)
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.Updates?, RevertChatWallpaperError> in
            if error.errorDescription == "WALLPAPER_NOT_FOUND" {
                return .single(nil)
            }
            return .fail(.generic)
        }
        |> mapToSignal { updates -> Signal<Void, RevertChatWallpaperError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
                return .complete()
            } else {
                return account.postbox.transaction { transaction in
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if let current = current as? CachedUserData {
                            return current.withUpdatedWallpaper(nil)
                        } else {
                            return current
                        }
                    })
                }
                |> castError(RevertChatWallpaperError.self)
            }
        }
    }
}

public enum SetExistingChatWallpaperError {
    case generic
}
                                                                                        
func _internal_setExistingChatWallpaper(account: Account, messageId: MessageId, settings: WallpaperSettings?, forBoth: Bool) -> Signal<Void, SetExistingChatWallpaperError> {
    return account.postbox.transaction { transaction -> Peer? in
        if let peer = transaction.getPeer(messageId.peerId), let message = transaction.getMessage(messageId) {
            if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .setChatWallpaper(wallpaper, _) = action.action {
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
        if forBoth {
            flags |= 1 << 3
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

private final class CachedUniqueGiftChatThemes: Codable {
    enum CodingKeys: String, CodingKey {
        case themes
    }
    
    let themes: [ChatTheme]
    
    init(themes: [ChatTheme]) {
        self.themes = themes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.themes = try container.decode([ChatTheme].self, forKey: .themes)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.themes, forKey: .themes)
    }
}

private func entryId() -> ItemCacheEntryId {
    let cacheKey = ValueBoxKey(length: 8)
    cacheKey.setInt64(0, value: 0)
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedChatThemes, key: cacheKey)
}

public final class UniqueGiftChatThemesContext {
    public struct State: Equatable {
        public enum DataState: Equatable {
            case loading
            case ready(canLoadMore: Bool)
        }
        
        public var themes: [ChatTheme]
        public var dataState: DataState
    }
    
    private let queue: Queue = .mainQueue()
    private let account: Account
    
    private let disposable = MetaDisposable()
    private let cacheDisposable = MetaDisposable()
    
    private var themes: [ChatTheme] = []
    private var nextOffset: String?
    private var dataState: UniqueGiftChatThemesContext.State.DataState = .ready(canLoadMore: true)
    
    private let stateValue = Promise<State>()
    public var state: Signal<State, NoError> {
        return self.stateValue.get()
    }
    
    public init(account: Account) {
        self.account = account
        
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
        self.cacheDisposable.dispose()
    }
    
    public func reload() {
        self.themes = []
        self.nextOffset = nil
        self.dataState = .ready(canLoadMore: true)
        self.loadMore(reload: true)
    }
    
    public func loadMore(reload: Bool = false) {
        let network = self.account.network
        let postbox = self.account.postbox
        let accountPeerId = self.account.peerId
        let dataState = self.dataState
        let offset = self.nextOffset
        
        guard case .ready(true) = dataState else {
            return
        }
        if self.themes.isEmpty, !reload {
            self.cacheDisposable.set((postbox.transaction { transaction -> CachedUniqueGiftChatThemes? in
                return transaction.retrieveItemCacheEntry(id: entryId())?.get(CachedUniqueGiftChatThemes.self)
            } |> deliverOn(self.queue)).start(next: { [weak self] cachedUniqueGiftChatThemes in
                guard let self, let cachedUniqueGiftChatThemes else {
                    return
                }
                self.themes = cachedUniqueGiftChatThemes.themes
                if case .loading = self.dataState {
                    self.pushState()
                }
            }))
        }
        
        self.dataState = .loading
        if !reload {
            self.pushState()
        }
        
        let signal = network.request(Api.functions.account.getUniqueGiftChatThemes(offset: offset ?? "", limit: 50, hash: 0))
        |> map(Optional.init)
        |> `catch` { error in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<([ChatTheme], String?), NoError> in
            guard let result else {
                return .single(([], nil))
            }
            return postbox.transaction { transaction -> ([ChatTheme], String?) in
                switch result {
                case let .chatThemes(_, _, themes, chats, users, nextOffset):
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    return (themes.compactMap { ChatTheme(apiChatTheme: $0) }, nextOffset)
                case .chatThemesNotModified:
                    return ([], nil)
                }
            }
        }
        
        self.disposable.set((signal
        |> deliverOn(self.queue)).start(next: { [weak self] themes, nextOffset in
            guard let self else {
                return
            }
            if offset == nil || reload {
                self.themes = themes
                self.cacheDisposable.set(self.account.postbox.transaction { transaction in
                    if let entry = CodableEntry(CachedUniqueGiftChatThemes(themes: themes)) {
                        transaction.putItemCacheEntry(id: entryId(), entry: entry)
                    }
                }.start())
            } else {
                self.themes.append(contentsOf: themes)
            }
            if let nextOffset {
                self.nextOffset = nextOffset
            }
            self.dataState = .ready(canLoadMore: nextOffset != nil)
            self.pushState()
        }))
    }
    
    private func pushState() {
        let state = State(
            themes: self.themes,
            dataState: self.dataState
        )
        self.stateValue.set(.single(state))
    }
}
