import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramCorePrivateModule

private func md5(_ data: Data) -> Data {
    return data.withUnsafeBytes { bytes -> Data in
        return CryptoMD5(bytes, Int32(data.count))
    }
}

private func updatedRemoteContactPeers(network: Network, hash: Int32) -> Signal<([Peer], [PeerId: PeerPresence], Int32)?, NoError> {
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

private func hashForCountAndIds(count: Int32, ids: [Int32]) -> Int32 {
    var acc: Int64 = 0
    
    acc = (acc &* 20261) &+ Int64(count)
    
    for id in ids {
        acc = (acc &* 20261) &+ Int64(id)
        acc = acc & Int64(0x7FFFFFFF)
    }
    return Int32(acc & Int64(0x7FFFFFFF))
}

func syncContactsOnce(network: Network, postbox: Postbox, accountPeerId: PeerId) -> Signal<Never, NoError> {
    let initialContactPeerIdsHash = postbox.transaction { transaction -> Int32 in
        let contactPeerIds = transaction.getContactPeerIds()
        let totalCount = transaction.getRemoteContactCount()
        let peerIds = Set(contactPeerIds.filter({ $0.namespace == Namespaces.Peer.CloudUser }))
        return hashForCountAndIds(count: totalCount, ids: peerIds.map({ $0.id }).sorted())
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
                    for s in stride(from: 0, to: peers.count, by: 100) {
                        let partPeers = Array(peers[s ..< min(s + 100, peers.count)])
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

public func addContactPeerInteractively(account: Account, peerId: PeerId, phone: String?) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId) as? TelegramUser, let phone = phone ?? peer.phone, !phone.isEmpty {
            return account.network.request(Api.functions.contacts.importContacts(contacts: [Api.InputContact.inputPhoneContact(clientId: 1, phone: phone, firstName: peer.firstName ?? "", lastName: peer.lastName ?? "")]))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.contacts.ImportedContacts?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                return account.postbox.transaction { transaction -> Void in
                    if let result = result {
                        switch result {
                            case let .importedContacts(_, _, _, users):
                                if let first = users.first {
                                    let user = TelegramUser(user: first)
                                    updatePeers(transaction: transaction, peers: [user], update: { _, updated in
                                        return updated
                                    })
                                    var peerIds = transaction.getContactPeerIds()
                                    if !peerIds.contains(peerId) {
                                        peerIds.insert(peerId)
                                        transaction.replaceContactPeerIds(peerIds)
                                    }
                                }
                        }
                    }
                }
            }
        } else {
            return .complete()
        }
    }
    |> switchToLatest
}

public func deleteContactPeerInteractively(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            return account.network.request(Api.functions.contacts.deleteContact(id: inputUser))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.contacts.Link?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return account.postbox.transaction { transaction -> Void in
                    var peerIds = transaction.getContactPeerIds()
                    if peerIds.contains(peerId) {
                        peerIds.remove(peerId)
                        transaction.replaceContactPeerIds(peerIds)
                    }
                }
            }
        } else {
            return .complete()
        }
    }
    |> switchToLatest
}

public func deleteAllContacts(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> [Api.InputUser] in
        return transaction.getContactPeerIds().compactMap(transaction.getPeer).compactMap({ apiInputUser($0) }).compactMap({ $0 })
    }
    |> mapToSignal { users -> Signal<Void, NoError> in
        return network.request(Api.functions.contacts.deleteContacts(id: users))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
}

public func resetSavedContacts(network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.contacts.resetSaved())
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}
