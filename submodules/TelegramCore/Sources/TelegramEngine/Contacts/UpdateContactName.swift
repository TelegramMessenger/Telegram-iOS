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
            return account.network.request(Api.functions.contacts.addContact(flags: 0, id: inputUser, firstName: firstName, lastName: lastName, phone: "", note: nil))
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
    |> mapError { _ -> UpdateContactNameError in }
    |> switchToLatest
}

public enum UpdateContactNoteError {
    case generic
}

func _internal_updateContactNote(account: Account, peerId: PeerId, text: String, entities: [MessageTextEntity]) -> Signal<Never, UpdateContactNoteError> {
    return account.postbox.transaction { transaction -> Signal<Void, UpdateContactNoteError> in
        if let peer = transaction.getPeer(peerId) as? TelegramUser, let inputUser = apiInputUser(peer) {
            return account.network.request(Api.functions.contacts.updateContactNote(id: inputUser, note: .textWithEntities(text: text, entities: apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary()))))
            |> mapError { _ -> UpdateContactNoteError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Void, UpdateContactNoteError> in
                return account.postbox.transaction { transaction in
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { peerId, cachedData in
                        let cachedData = cachedData as? CachedUserData ?? CachedUserData()
                        return cachedData.withUpdatedNote(!text.isEmpty ? CachedUserData.Note(text: text, entities: entities) : nil)
                    })
                }
                |> castError(UpdateContactNoteError.self)
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapError { _ -> UpdateContactNoteError in }
    |> switchToLatest
    |> ignoreValues
}
