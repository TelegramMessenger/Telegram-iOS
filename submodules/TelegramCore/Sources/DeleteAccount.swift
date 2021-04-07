import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum DeleteAccountError {
    case generic
}

public func deleteAccount(account: Account) -> Signal<Never, DeleteAccountError> {
    return account.network.request(Api.functions.account.deleteAccount(reason: "GDPR"))
    |> mapError { _ -> DeleteAccountError in
        return .generic
    }
    |> ignoreValues
}
