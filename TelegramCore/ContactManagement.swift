import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramCorePrivateModule

private func md5(_ data : Data) -> Data {
    var res = Data()
    res.count = Int(CC_MD5_DIGEST_LENGTH)
    res.withUnsafeMutableBytes { mutableBytes -> Void in
        data.withUnsafeBytes { bytes -> Void in
            CC_MD5(bytes, CC_LONG(data.count), mutableBytes)
        }
    }
    return res
}

private func updatedRemoteContactPeers(network: Network, hash: Int32) -> Signal<([Peer], [PeerId: PeerPresence], Int32)?, NoError> {
    return network.request(Api.functions.contacts.getContacts(hash: hash))
        |> retryRequest
        |> map { result -> ([Peer], [PeerId: PeerPresence], Int32)? in
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
    var acc: UInt32 = 0
    
    acc = (acc &* 20261) &+ UInt32(bitPattern: count)
    
    for id in ids {
        let low = UInt32(bitPattern: id)
        acc = (acc &* 20261) &+ low
    }
    return Int32(bitPattern: acc & UInt32(0x7FFFFFFF))
}

func manageContacts(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    #if DEBUG
        return .never()
    #endif
    let initialContactPeerIdsHash = postbox.contactPeerIdsView()
        |> take(1)
        |> map { view -> Int32 in
            let peerIds = Set(view.peerIds.filter({ $0.namespace == Namespaces.Peer.CloudUser }))
            let sortedUserIds = peerIds.map({ $0.id }).sorted()
            
            return hashForCountAndIds(count: view.remoteTotalCount, ids: sortedUserIds)
        }
    
    let updatedPeers = initialContactPeerIdsHash
        |> mapToSignal { hash -> Signal<([Peer], [PeerId: PeerPresence], Int32)?, NoError> in
            return updatedRemoteContactPeers(network: network, hash: hash)
        }
    
    let appliedUpdatedPeers = updatedPeers
        |> mapToSignal { peersAndPresences -> Signal<Void, NoError> in
            if let (peers, peerPresences, totalCount) = peersAndPresences {
                return postbox.modify { modifier in
                    updatePeers(modifier: modifier, peers: peers, update: { return $1 })
                    modifier.updatePeerPresences(peerPresences)
                    modifier.replaceContactPeerIds(Set(peers.map { $0.id }))
                    modifier.replaceRemoteContactCount(totalCount)
                }
            } else {
                return .complete()
            }
        }
    
    return appliedUpdatedPeers
}

public func addContactPeerInteractively(account: Account, peerId: PeerId, phone: String?) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId) as? TelegramUser, let phone = phone ?? peer.phone, !phone.isEmpty {
            return account.network.request(Api.functions.contacts.importContacts(contacts: [Api.InputContact.inputPhoneContact(clientId: 1, phone: phone, firstName: peer.firstName ?? "", lastName: peer.lastName ?? "")]))
                |> map { Optional($0) }
                |> `catch` { _ -> Signal<Api.contacts.ImportedContacts?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.modify { modifier -> Void in
                        if let result = result {
                            switch result {
                                case let .importedContacts(_, _, _, users):
                                    if let first = users.first {
                                        let user = TelegramUser(user: first)
                                        updatePeers(modifier: modifier, peers: [user], update: { _, updated in
                                            return updated
                                        })
                                        var peerIds = modifier.getContactPeerIds()
                                        if !peerIds.contains(peerId) {
                                            peerIds.insert(peerId)
                                            modifier.replaceContactPeerIds(peerIds)
                                        }
                                    }
                            }
                        }
                    }
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func deleteContactPeerInteractively(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputUser = apiInputUser(peer) {
            return account.network.request(Api.functions.contacts.deleteContact(id: inputUser))
                |> map { Optional($0) }
                |> `catch` { _ -> Signal<Api.contacts.Link?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return account.postbox.modify { modifier -> Void in
                        var peerIds = modifier.getContactPeerIds()
                        if peerIds.contains(peerId) {
                            peerIds.remove(peerId)
                            modifier.replaceContactPeerIds(peerIds)
                        }
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
