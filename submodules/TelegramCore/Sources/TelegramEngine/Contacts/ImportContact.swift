import Postbox
import TelegramApi
import SwiftSignalKit


func _internal_importContact(account: Account, firstName: String, lastName: String, phoneNumber: String, noteText: String, noteEntities: [MessageTextEntity]) -> Signal<PeerId?, NoError> {
    let accountPeerId = account.peerId
    
    var flags: Int32 = 0
    var note: Api.TextWithEntities?
    if !noteText.isEmpty {
        flags |= (1 << 1)
        note = .textWithEntities(.init(text: noteText, entities: apiEntitiesFromMessageTextEntities(noteEntities, associatedPeers: SimpleDictionary())))
    }
    
    let input = Api.InputContact.inputPhoneContact(.init(flags: 0, clientId: 1, phone: phoneNumber, firstName: firstName, lastName: lastName, note: note))
    
    return account.network.request(Api.functions.contacts.importContacts(contacts: [input]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.contacts.ImportedContacts?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<PeerId?, NoError> in
        return account.postbox.transaction { transaction -> PeerId? in
            if let result = result {
                switch result {
                    case let .importedContacts(importedContactsData):
                        let users = importedContactsData.users
                        if let first = users.first {
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                            
                            let peerId = first.peerId
                            
                            var peerIds = transaction.getContactPeerIds()
                            if !peerIds.contains(peerId) {
                                peerIds.insert(peerId)
                                transaction.replaceContactPeerIds(peerIds)
                            }
                            if !noteText.isEmpty {
                                transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, cachedData in
                                    (cachedData as? CachedUserData)?.withUpdatedNote(.init(text: noteText, entities: noteEntities))
                                })
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

func _internal_addContactInteractively(account: Account, peerId: PeerId, firstName: String, lastName: String, phoneNumber: String, noteText: String, noteEntities: [MessageTextEntity], addToPrivacyExceptions: Bool) -> Signal<Never, AddContactError> {
    let accountPeerId = account.peerId
    
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
        var note: Api.TextWithEntities?
        if !noteText.isEmpty {
            flags |= (1 << 1)
            note = .textWithEntities(.init(text: noteText, entities: apiEntitiesFromMessageTextEntities(noteEntities, associatedPeers: SimpleDictionary())))
        }
        return account.network.request(Api.functions.contacts.addContact(flags: flags, id: inputUser, firstName: firstName, lastName: lastName, phone: phone, note: note))
        |> mapError { _ -> AddContactError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, AddContactError> in
            return account.postbox.transaction { transaction -> Void in
                var peers = AccumulatedPeers()
                switch result {
                case let .updates(updatesData):
                    let users = updatesData.users
                    peers = AccumulatedPeers(users: users)
                case let .updatesCombined(updatesCombinedData):
                    let users = updatesCombinedData.users
                    peers = AccumulatedPeers(users: users)
                default:
                    break
                }
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: peers)
                var peerIds = transaction.getContactPeerIds()
                if !peerIds.contains(peerId) {
                    peerIds.insert(peerId)
                    transaction.replaceContactPeerIds(peerIds)
                }
                if !noteText.isEmpty {
                    transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, cachedData in
                        (cachedData as? CachedUserData)?.withUpdatedNote(.init(text: noteText, entities: noteEntities))
                    })
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
