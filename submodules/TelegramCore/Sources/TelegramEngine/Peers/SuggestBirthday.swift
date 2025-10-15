import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum SuggestBirthdayError {
    case generic
}

func _internal_suggestBirthday(account: Account, peerId: EnginePeer.Id, birthday: TelegramBirthday) -> Signal<Never, SuggestBirthdayError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> castError(SuggestBirthdayError.self)
    |> mapToSignal { peer in
        guard let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        return account.network.request(Api.functions.users.suggestBirthday(id: inputUser, birthday: birthday.apiBirthday))
        |> mapError { _ in
            return .generic
        }
        |> mapToSignal { updates in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
}
