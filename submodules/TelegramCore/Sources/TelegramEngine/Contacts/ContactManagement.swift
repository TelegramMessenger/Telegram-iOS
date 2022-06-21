import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import CryptoUtils

private func md5(_ data: Data) -> Data {
    return data.withUnsafeBytes { rawBytes -> Data in
        let bytes = rawBytes.baseAddress!

        return CryptoMD5(bytes, Int32(data.count))
    }
}

private func updatedRemoteContactPeers(network: Network, hash: Int64) -> Signal<([Peer], [PeerId: PeerPresence], Int32)?, NoError> {
    return network.request(Api.functions.contacts.getContacts(hash: hash), automaticFloodWait: false)
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.contacts.Contacts?, NoError> in
        return .single(nil)
    }
    |> map { result -> ([Peer], [PeerId: PeerPresence], Int32)? in
        guard let result = result else {
            return nil
        }
        switch result {
            case .contactsNotModified:
                return nil
            case let .contacts(_, savedCount, users):
                var peers: [Peer] = []
                var peerPresences: [PeerId: PeerPresence] = [:]
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    if let presence = TelegramUserPresence(apiUser: user) {
                        peerPresences[telegramUser.id] = presence
                    }
                }
                return (peers, peerPresences, savedCount)
        }
    }
}

private func hashForCountAndIds(count: Int32, ids: [Int64]) -> Int64 {
    var acc: UInt64 = 0
    
    combineInt64Hash(&acc, with: UInt64(count))
    
    for id in ids {
        combineInt64Hash(&acc, with: UInt64(bitPattern: id))
    }
    return finalizeInt64Hash(acc)
}

func syncContactsOnce(network: Network, postbox: Postbox, accountPeerId: PeerId) -> Signal<Never, NoError> {
    let initialContactPeerIdsHash = postbox.transaction { transaction -> Int64 in
        let contactPeerIds = transaction.getContactPeerIds()
        let totalCount = transaction.getRemoteContactCount()
        let peerIds = Set(contactPeerIds.filter({ $0.namespace == Namespaces.Peer.CloudUser }))
        return hashForCountAndIds(count: totalCount, ids: peerIds.map({ $0.id._internalGetInt64Value() }).sorted())
    }

    let updatedPeers = initialContactPeerIdsHash
    |> mapToSignal { hash -> Signal<([Peer], [PeerId: PeerPresence], Int32)?, NoError> in
        return updatedRemoteContactPeers(network: network, hash: hash)
    }

    let appliedUpdatedPeers = updatedPeers
    |> mapToSignal { peersAndPresences -> Signal<Never, NoError> in
        if let (peers, peerPresences, totalCount) = peersAndPresences {
            return postbox.transaction { transaction -> Signal<Void, NoError> in
                let previousIds = transaction.getContactPeerIds()
                let wasEmpty = previousIds.isEmpty
                
                transaction.replaceRemoteContactCount(totalCount)
                
                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                
                if wasEmpty {
                    var insertSignal: Signal<Void, NoError> = .complete()
                    for s in stride(from: 0, to: peers.count, by: 500) {
                        let partPeers = Array(peers[s ..< min(s + 500, peers.count)])
                        let partSignal = postbox.transaction { transaction -> Void in
                            updatePeers(transaction: transaction, peers: partPeers, update: { return $1 })
                            var updatedIds = transaction.getContactPeerIds()
                            updatedIds.formUnion(partPeers.map { $0.id })
                            transaction.replaceContactPeerIds(updatedIds)
                        }
                        |> delay(0.1, queue: Queue.concurrentDefaultQueue())
                        insertSignal = insertSignal |> then(partSignal)
                    }
                    
                    return insertSignal
                } else {
                    transaction.replaceContactPeerIds(Set(peers.map { $0.id }))
                    return .complete()
                }
            }
            |> switchToLatest
            |> ignoreValues
        } else {
            return .complete()
        }
    }
    
    return appliedUpdatedPeers
}

func _internal_deleteContactPeerInteractively(account: Account, peerId: PeerId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Never, NoError> in
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            return account.network.request(Api.functions.contacts.deleteContacts(id: [inputUser]))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                }
                return account.postbox.transaction { transaction -> Void in
                    var peerIds = transaction.getContactPeerIds()
                    if peerIds.contains(peerId) {
                        peerIds.remove(peerId)
                        transaction.replaceContactPeerIds(peerIds)
                    }
                }
            }
            |> ignoreValues
        } else {
            return .complete()
        }
    }
    |> switchToLatest
}

func _internal_deleteAllContacts(account: Account) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> [Api.InputUser] in
        return transaction.getContactPeerIds().compactMap(transaction.getPeer).compactMap({ apiInputUser($0) }).compactMap({ $0 })
    }
    |> mapToSignal { users -> Signal<Never, NoError> in
        let deleteContacts = account.network.request(Api.functions.contacts.deleteContacts(id: users))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        let deleteImported = account.network.request(Api.functions.contacts.resetSaved())
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        return combineLatest(deleteContacts, deleteImported)
        |> mapToSignal { updates, _ -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> Void in
                transaction.replaceContactPeerIds(Set())
                transaction.clearDeviceContactImportInfoIdentifiers()
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                account.restartContactManagement()
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                }
                
                return .complete()
            }
            |> ignoreValues
        }
    }
}

func _internal_resetSavedContacts(network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.contacts.resetSaved())
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}
