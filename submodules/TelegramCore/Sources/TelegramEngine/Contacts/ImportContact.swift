import Postbox
import TelegramApi
import SwiftSignalKit


func _internal_importContact(account: Account, firstName: String, lastName: String, phoneNumber: String) -> Signal<PeerId?, NoError> {
    let input = Api.InputContact.inputPhoneContact(clientId: 1, phone: phoneNumber, firstName: firstName, lastName: lastName)
    
    return account.network.request(Api.functions.contacts.importContacts(contacts: [input]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.contacts.ImportedContacts?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<PeerId?, NoError> in
        return account.postbox.transaction { transaction -> PeerId? in
            if let result = result {
                switch result {
                    case let .importedContacts(_, _, _, users):
                        if let first = users.first {
                            let user = TelegramUser(user: first)
                            let peerId = user.id
                            updatePeers(transaction: transaction, peers: [user], update: { _, updated in
                                return updated
                            })
                            var peerIds = transaction.getContactPeerIds()
                            if !peerIds.contains(peerId) {
                                peerIds.insert(peerId)
                                transaction.replaceContactPeerIds(peerIds)
                            }
                            return peerId
                        }
                }
            }
            return nil
        }
    }
}

public enum AddContactError {
    case generic
}

func _internal_addContactInteractively(account: Account, peerId: PeerId, firstName: String, lastName: String, phoneNumber: String, addToPrivacyExceptions: Bool) -> Signal<Never, AddContactError> {
    return account.postbox.transaction { transaction -> (Api.InputUser, String)? in
        if let user = transaction.getPeer(peerId) as? TelegramUser, let inputUser = apiInputUser(user) {
            return (inputUser, user.phone == nil ? phoneNumber : "")
        } else {
            return nil
        }
    }
    |> castError(AddContactError.self)
    |> mapToSignal { inputUserAndPhone in
        guard let (inputUser, phone) = inputUserAndPhone else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if addToPrivacyExceptions {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.contacts.addContact(flags: flags, id: inputUser, firstName: firstName, lastName: lastName, phone: phone))
        |> mapError { _ -> AddContactError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, AddContactError> in
            return account.postbox.transaction { transaction -> Void in
                var peers: [Peer] = []
                switch result {
                    case let .updates(_, users, _, _, _):
                        for user in users {
                            peers.append(TelegramUser(user: user))
                        }
                    case let .updatesCombined(_, users, _, _, _, _):
                        for user in users {
                            peers.append(TelegramUser(user: user))
                        }
                    default:
                        break
                }
                updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                    return updated
                })
                var peerIds = transaction.getContactPeerIds()
                if !peerIds.contains(peerId) {
                    peerIds.insert(peerId)
                    transaction.replaceContactPeerIds(peerIds)
                }
                
                account.stateManager.addUpdates(result)
            }
            |> castError(AddContactError.self)
            |> ignoreValues
        }
    }
}

public enum AcceptAndShareContactError {
    case generic
}

func _internal_acceptAndShareContact(account: Account, peerId: PeerId) -> Signal<Never, AcceptAndShareContactError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> castError(AcceptAndShareContactError.self)
    |> mapToSignal { inputUser -> Signal<Never, AcceptAndShareContactError> in
        guard let inputUser = inputUser else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.contacts.acceptContact(id: inputUser))
        |> mapError { _ -> AcceptAndShareContactError in
            return .generic
        }
        |> mapToSignal { updates -> Signal<Never, AcceptAndShareContactError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
}
