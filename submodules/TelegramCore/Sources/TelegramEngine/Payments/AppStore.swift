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
        
        return account.postbox.peerView(id: account.peerId)
        |> castError(AssignAppStoreTransactionError.self)
        |> take(until: { view in
            if let peer = view.peers[view.peerId], peer.isPremium {
                return SignalTakeAction(passthrough: false, complete: true)
            } else {
                return SignalTakeAction(passthrough: false, complete: false)
            }
        })
        |> mapToSignal { _ -> Signal<Never, AssignAppStoreTransactionError> in
            return .never()
        }
    }
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
