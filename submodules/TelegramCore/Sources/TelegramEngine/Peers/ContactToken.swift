import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func _internal_importContactToken(account: Account, token: String) -> Signal<EnginePeer?, NoError> {
    return account.network.request(Api.functions.contacts.importContactToken(token: token))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.User?, NoError> in
        return .single(nil)
    }
    |> map { result -> EnginePeer? in
        return result.flatMap { EnginePeer(TelegramUser(user: $0)) }
    }
}

public struct ExportedContactToken {
    public let url: String
    public let expires: Int32
}

func _internal_exportContactToken(account: Account) -> Signal<ExportedContactToken?, NoError> {
    return account.network.request(Api.functions.contacts.exportContactToken())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.ExportedContactToken?, NoError> in
        return .single(nil)
    }
    |> map { result -> ExportedContactToken? in
        if let result = result, case let .exportedContactToken(url, expires) = result {
            return ExportedContactToken(url: url, expires: expires)
        } else {
            return nil
        }
    }
}
