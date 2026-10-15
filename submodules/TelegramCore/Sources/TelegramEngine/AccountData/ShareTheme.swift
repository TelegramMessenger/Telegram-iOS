import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

public enum TelegramShareTheme: Equatable {
    case `default`
    case emoji([MessageReaction.Reaction])
    case color(Int32)
    case gift(StarGift)
}

public enum TelegramShareThemeUpdate: Equatable {
    case `default`
    case emoji([MessageReaction.Reaction])
    case color(Int32)
    case gift(StarGiftReference)
}

public enum SetShareThemeError {
    case generic
}

func _internal_getShareTheme(account: Account) -> Signal<TelegramShareTheme?, NoError> {
    return account.network.request(Api.functions.account.getShareTheme())
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
        case let .shareThemeEmoji(data):
            let reactions = data.emojis.compactMap(MessageReaction.Reaction.init(apiReaction:))
            return reactions.isEmpty ? .default : .emoji(reactions)
        case let .shareThemeColor(data):
            return .color(data.colorId)
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

func _internal_setShareTheme(account: Account, theme: TelegramShareThemeUpdate) -> Signal<Never, SetShareThemeError> {
    return account.postbox.transaction { transaction -> Api.ShareTheme? in
        switch theme {
        case .default:
            return .shareThemeDefault
        case let .emoji(reactions):
            return .shareThemeEmoji(.init(emojis: reactions.map(\.apiReaction)))
        case let .color(colorId):
            return .shareThemeColor(.init(colorId: colorId))
        case let .gift(reference):
            guard let input = reference.apiStarGiftReference(transaction: transaction) else {
                return nil
            }
            return .inputShareThemeGift(.init(stargift: input))
        }
    }
    |> castError(SetShareThemeError.self)
    |> mapToSignal { apiTheme -> Signal<Never, SetShareThemeError> in
        guard let apiTheme else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.account.setShareTheme(theme: apiTheme))
        |> mapError { _ -> SetShareThemeError in
            return .generic
        }
        |> ignoreValues
    }
}
