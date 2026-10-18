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

func _internal_getShareTheme(account: Account, peerId: PeerId) -> Signal<TelegramShareTheme?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<TelegramShareTheme?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.messages.getShareTheme(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.ShareTheme?, NoError> in
            return .single(nil)
        }
        |> map { result -> TelegramShareTheme? in
            guard let result else {
                return nil
            }
            switch result {
            case .shareThemeDefault:
                return .default
            case let .shareThemeEmojiBackdrop(data):
                let reactions = data.emojis?.compactMap(MessageReaction.Reaction.init(apiReaction:))
                let emojis = reactions.flatMap { $0.isEmpty ? nil : $0 }
                if emojis == nil && data.backdropId == nil {
                    return .default
                }
                return .emojiBackdrop(emojis: emojis, backdropId: data.backdropId)
            case let .shareThemeGift(data):
                guard let gift = StarGift(apiStarGift: data.stargift) else {
                    return .default
                }
                return .gift(gift)
            case .inputShareThemeGift:
                return nil
            }
        }
    }
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
