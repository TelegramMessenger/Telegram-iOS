import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public func requestPhoneNumber(account: Account, peerId: PeerId) -> Signal<Never, NoError> {
    return .never()
    /*return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.sendPhoneNumberRequest(peer: inputPeer, randomId: arc4random64()))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }*/
}

