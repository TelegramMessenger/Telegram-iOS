import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi


public enum AssignAppStoreTransactionError {
    case generic
}

func _internal_assignAppStoreTransaction(account: Account, transactionId: String) -> Signal<Never, AssignAppStoreTransactionError> {
    return account.network.request(Api.functions.payments.assignAppStoreTransaction(transactionId: transactionId))
    |> mapError { _ -> AssignAppStoreTransactionError in
        return .generic
    }
    |> mapToSignal { updates -> Signal<Never, AssignAppStoreTransactionError> in
        account.stateManager.addUpdates(updates)
        
        return .never()
    }
}
