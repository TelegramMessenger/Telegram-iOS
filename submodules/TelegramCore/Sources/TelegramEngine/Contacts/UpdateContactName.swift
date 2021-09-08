import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum UpdateContactNameError {
    case generic
}

func _internal_updateContactName(account: Account, peerId: PeerId, firstName: String, lastName: String) -> Signal<Void, UpdateContactNameError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdateContactNameError> in
        if let peer = transaction.getPeer(peerId) as? TelegramUser, let inputUser = apiInputUser(peer) {
            return account.network.request(Api.functions.contacts.addContact(flags: 0, id: inputUser, firstName: firstName, lastName: lastName, phone: ""))
            |> mapError { _ -> UpdateContactNameError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Void, UpdateContactNameError> in
                account.stateManager.addUpdates(result)
                return .complete()
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateContactNameError in return .generic }
    |> switchToLatest
}
