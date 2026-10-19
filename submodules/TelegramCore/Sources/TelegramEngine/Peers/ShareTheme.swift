import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

public enum TelegramShareTheme: Equatable {
    case `default`
    case emojiBackdrop(emojis: [MessageReaction.Reaction]?, backdropId: Int32?)
    case gift(StarGift)
}

public enum TelegramShareThemeUpdate: Equatable {
    case `default`
    case emojiBackdrop(emojis: [MessageReaction.Reaction]?, backdropId: Int32?)
    case gift(StarGiftReference)
}

public enum SetShareThemeError {
    case generic
}

public struct TelegramShareThemeBackdrop: Codable, Equatable {
    public let id: Int32
    public let name: String
    public let centerColor: Int32
    public let edgeColor: Int32
    public let patternColor: Int32
    public let textColor: Int32

    public init(id: Int32, name: String, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32) {
        self.id = id
        self.name = name
        self.centerColor = centerColor
        self.edgeColor = edgeColor
        self.patternColor = patternColor
        self.textColor = textColor
    }
}

private struct CachedShareThemeBackdrops: Codable {
    let hash: Int32
    let backdrops: [TelegramShareThemeBackdrop]
}

private let cachedShareThemeBackdropsEntryId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.shareThemeBackdrops, key: ValueBoxKey(length: 0))

private struct CodedShareTheme: Codable {
    let emojis: [MessageReaction.Reaction]?
    let backdropId: Int32?
    let gift: StarGift?

    init(_ theme: TelegramShareTheme) {
        switch theme {
        case .default:
            self.emojis = nil
            self.backdropId = nil
            self.gift = nil
        case let .emojiBackdrop(emojis, backdropId):
            self.emojis = emojis
            self.backdropId = backdropId
            self.gift = nil
        case let .gift(gift):
            self.emojis = nil
            self.backdropId = nil
            self.gift = gift
        }
    }

    var theme: TelegramShareTheme {
        if let gift = self.gift {
            return .gift(gift)
        }
        if self.emojis == nil && self.backdropId == nil {
            return .default
        }
        return .emojiBackdrop(emojis: self.emojis, backdropId: self.backdropId)
    }
}

extension TelegramShareTheme: Codable {
    public init(from decoder: Decoder) throws {
        self = try CodedShareTheme(from: decoder).theme
    }

    public func encode(to encoder: Encoder) throws {
        try CodedShareTheme(self).encode(to: encoder)
    }
}

extension TelegramShareTheme {
    init?(apiShareTheme: Api.ShareTheme) {
        switch apiShareTheme {
        case .shareThemeDefault:
            self = .default
        case let .shareThemeEmojiBackdrop(data):
            let reactions = data.emojis?.compactMap(MessageReaction.Reaction.init(apiReaction:))
            let emojis = reactions.flatMap { $0.isEmpty ? nil : $0 }
            if emojis == nil && data.backdropId == nil {
                self = .default
            } else {
                self = .emojiBackdrop(emojis: emojis, backdropId: data.backdropId)
            }
        case let .shareThemeGift(data):
            guard let gift = StarGift(apiStarGift: data.stargift) else {
                return nil
            }
            self = .gift(gift)
        case .inputShareThemeGift:
            return nil
        }
    }
}

private func _internal_localShareTheme(postbox: Postbox, peerId: PeerId) -> Signal<TelegramShareTheme?, NoError> {
    let key = PostboxViewKey.cachedPeerData(peerId: peerId)
    return postbox.combinedView(keys: [key])
    |> map { views -> TelegramShareTheme? in
        guard let cachedData = (views.views[key] as? CachedPeerDataView)?.cachedPeerData else {
            return nil
        }
        if let cachedData = cachedData as? CachedUserData {
            return cachedData.shareTheme
        }
        if let cachedData = cachedData as? CachedChannelData {
            return cachedData.shareTheme
        }
        return .default
    }
    |> distinctUntilChanged
}

func _internal_getShareTheme(account: Account, peerId: PeerId) -> Signal<TelegramShareTheme?, NoError> {
    let local = _internal_localShareTheme(postbox: account.postbox, peerId: peerId)
    let fetched: Signal<Bool, NoError> = .single(false)
    |> then(
        _internal_fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)
        |> map { _ -> Bool in
            return true
        }
    )
    return combineLatest(local, fetched)
    |> mapToSignal { theme, fetched -> Signal<TelegramShareTheme?, NoError> in
        if let theme {
            return .single(theme)
        }
        if fetched {
            return .single(nil)
        }
        return .complete()
    }
    |> distinctUntilChanged
}

func _internal_preloadShareTheme(account: Account, peerId: PeerId) -> Signal<Never, NoError> {
    let files = _internal_localShareTheme(postbox: account.postbox, peerId: peerId)
    |> mapToSignal { theme -> Signal<[TelegramMediaFile], NoError> in
        guard let theme else {
            return .single([])
        }
        switch theme {
        case .default:
            return .single([])
        case let .emojiBackdrop(emojis, _):
            let fileIds = (emojis ?? []).compactMap { reaction -> Int64? in
                if case let .custom(fileId) = reaction {
                    return fileId
                }
                return nil
            }
            if fileIds.isEmpty {
                return .single([])
            }
            return _internal_resolveInlineStickers(postbox: account.postbox, network: account.network, fileIds: fileIds)
            |> map { files -> [TelegramMediaFile] in
                return fileIds.compactMap { files[$0] }
            }
        case let .gift(gift):
            guard case let .unique(uniqueGift) = gift else {
                return .single([])
            }
            var files: [TelegramMediaFile] = []
            for attribute in uniqueGift.attributes {
                switch attribute {
                case let .model(_, file, _, _), let .pattern(_, file, _):
                    files.append(file)
                default:
                    break
                }
            }
            return .single(files)
        }
    }
    |> mapToSignal { files -> Signal<Never, NoError> in
        let fetches = files.map { file -> Signal<Never, NoError> in
            return fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .peer(peerId), userContentType: .sticker, reference: .media(media: .standalone(media: file), resource: file.resource))
            |> ignoreValues
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            }
        }
        return combineLatest(fetches)
        |> ignoreValues
    }
    let backdrops = _internal_shareThemeBackdrops(account: account)
    |> ignoreValues
    return combineLatest(files, backdrops)
    |> ignoreValues
}

func _internal_setShareTheme(account: Account, peerId: PeerId, theme: TelegramShareThemeUpdate) -> Signal<Never, SetShareThemeError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer, Api.ShareTheme)? in
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
            return nil
        }
        let apiTheme: Api.ShareTheme
        switch theme {
        case .default:
            apiTheme = .shareThemeDefault
        case let .emojiBackdrop(emojis, backdropId):
            let emojis = emojis.flatMap { $0.isEmpty ? nil : $0 }
            if emojis == nil && backdropId == nil {
                apiTheme = .shareThemeDefault
            } else {
                var flags: Int32 = 0
                if backdropId != nil {
                    flags |= 1 << 0
                }
                if emojis != nil {
                    flags |= 1 << 1
                }
                apiTheme = .shareThemeEmojiBackdrop(.init(flags: flags, backdropId: backdropId, emojis: emojis?.map(\.apiReaction)))
            }
        case let .gift(reference):
            guard let input = reference.apiStarGiftReference(transaction: transaction) else {
                return nil
            }
            apiTheme = .inputShareThemeGift(.init(stargift: input))
        }
        return (inputPeer, apiTheme)
    }
    |> castError(SetShareThemeError.self)
    |> mapToSignal { input -> Signal<Never, SetShareThemeError> in
        guard let (inputPeer, apiTheme) = input else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.messages.setShareTheme(peer: inputPeer, theme: apiTheme))
        |> mapError { _ -> SetShareThemeError in
            return .generic
        }
        |> ignoreValues
        |> then(
            _internal_fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)
            |> ignoreValues
            |> castError(SetShareThemeError.self)
        )
    }
}

func _internal_shareThemeBackdrops(account: Account) -> Signal<[TelegramShareThemeBackdrop], NoError> {
    let postbox = account.postbox
    let network = account.network
    return postbox.transaction { transaction -> CachedShareThemeBackdrops? in
        return transaction.retrieveItemCacheEntry(id: cachedShareThemeBackdropsEntryId)?.get(CachedShareThemeBackdrops.self)
    }
    |> mapToSignal { cached -> Signal<[TelegramShareThemeBackdrop], NoError> in
        let remote = network.request(Api.functions.messages.getShareThemeBackdrops(hash: cached?.hash ?? 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.ShareThemeBackdrops?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<[TelegramShareThemeBackdrop], NoError> in
            guard let result else {
                return .complete()
            }
            switch result {
            case .shareThemeBackdropsNotModified:
                return .complete()
            case let .shareThemeBackdrops(data):
                let backdrops = data.backdrops.map { option -> TelegramShareThemeBackdrop in
                    switch option {
                    case let .shareThemeBackdropOption(option):
                        return TelegramShareThemeBackdrop(id: option.backdropId, name: option.name, centerColor: option.centerColor, edgeColor: option.edgeColor, patternColor: option.patternColor, textColor: option.textColor)
                    }
                }
                let hash = data.hash
                return postbox.transaction { transaction -> [TelegramShareThemeBackdrop] in
                    if let entry = CodableEntry(CachedShareThemeBackdrops(hash: hash, backdrops: backdrops)) {
                        transaction.putItemCacheEntry(id: cachedShareThemeBackdropsEntryId, entry: entry)
                    }
                    return backdrops
                }
            }
        }
        if let cached {
            return .single(cached.backdrops) |> then(remote)
        } else {
            return remote
        }
    }
}
