import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public enum AssignAppStoreTransactionError {
    case generic
    case timeout
    case serverProvided
}

func _internal_sendAppStoreReceipt(account: Account, receipt: Data, restore: Bool) -> Signal<Never, AssignAppStoreTransactionError> {
    var flags: Int32 = 0
    if restore {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.payments.assignAppStoreTransaction(flags: flags, receipt: Buffer(data: receipt)))
    |> mapError { error -> AssignAppStoreTransactionError in
        if error.errorCode == 406 {
            return .serverProvided
        } else {
            return .generic
        }
    }
    |> mapToSignal { updates -> Signal<Never, AssignAppStoreTransactionError> in
        account.stateManager.addUpdates(updates)
        return .complete()
    }
}

public enum RestoreAppStoreReceiptError {
    case generic
}

func _internal_canPurchasePremium(account: Account) -> Signal<Bool, NoError> {
    return account.network.request(Api.functions.payments.canPurchasePremium())
    |> map { result -> Bool in
        switch result {
            case .boolTrue:
                return true
            case .boolFalse:
                return false
        }
    }
    |> `catch` { _ -> Signal<Bool, NoError> in
        return.single(false)
    }
}
