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

public enum AppStoreTransactionPurpose {
    case subscription
    case gift(EnginePeer.Id)
    case restore
}

func _internal_sendAppStoreReceipt(account: Account, receipt: Data, purpose: AppStoreTransactionPurpose) -> Signal<Never, AssignAppStoreTransactionError> {
    var purposeSignal: Signal<Api.InputStorePaymentPurpose, NoError>
    switch purpose {
    case .subscription, .restore:
        var flags: Int32 = 0
        if case .restore = purpose {
            flags |= (1 << 0)
        }
        purposeSignal = .single(.inputStorePaymentPremiumSubscription(flags: flags))
    case let .gift(peerId):
        purposeSignal = account.postbox.loadedPeerWithId(peerId)
        |> mapToSignal { peer -> Signal<Api.InputStorePaymentPurpose, NoError> in
            if let inputUser = apiInputUser(peer) {
                return .single(.inputStorePaymentGiftPremium(userId: inputUser))
            } else {
                return .complete()
            }
        }
    }
    
    return purposeSignal
    |> castError(AssignAppStoreTransactionError.self)
    |> mapToSignal { purpose -> Signal<Never, AssignAppStoreTransactionError> in
        return account.network.request(Api.functions.payments.assignAppStoreTransaction(receipt: Buffer(data: receipt), purpose: purpose))
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
