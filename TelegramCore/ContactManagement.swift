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

private func updatedRemoteContactPeers(network: Network, hash: String) -> Signal<([Peer], [PeerId: PeerPresence])?, NoError> {
    return network.request(Api.functions.contacts.getContacts(hash: hash))
        |> retryRequest
        |> map { result -> ([Peer], [PeerId: PeerPresence])? in
            switch result {
                case .contactsNotModified:
                    return nil
                case let .contacts(_, users):
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
                        }
                    }
                    return (peers, peerPresences)
            }
        }
}

func manageContacts(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    let initialContactPeerIdsHash = postbox.contactPeerIdsView()
        |> take(1)
        |> map { peerIds -> String in
            var stringToHash = ""
            var first = true
            let sortedUserIds = Set(peerIds.peerIds.filter({ $0.namespace == Namespaces.Peer.CloudUser }).map({ $0.id })).sorted()
            for userId in sortedUserIds {
                if first {
                    first = false
                } else {
                    stringToHash.append(",")
                }
                stringToHash.append("\(userId)")
            }
            
            let hashData = md5(stringToHash.data(using: .utf8)!)
            let hashString = hashData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> String in
                let hexString = NSMutableString()
                for i in 0 ..< hashData.count {
                    let byteValue = UInt(bytes.advanced(by: i).pointee)
                    hexString.appendFormat("%02x", byteValue)
                }
                return hexString as String
            }
            
            return hashString
        }
    
    let updatedPeers = initialContactPeerIdsHash
        |> mapToSignal { hash -> Signal<([Peer], [PeerId: PeerPresence])?, NoError> in
            return updatedRemoteContactPeers(network: network, hash: hash)
        }
    
    let appliedUpdatedPeers = updatedPeers
        |> mapToSignal { peersAndPresences -> Signal<Void, NoError> in
            if let (peers, peerPresences) = peersAndPresences {
                return postbox.modify { modifier in
                    updatePeers(modifier: modifier, peers: peers, update: { return $1 })
                    modifier.updatePeerPresences(peerPresences)
                    modifier.replaceContactPeerIds(Set(peers.map { $0.id }))
                }
            } else {
                return .complete()
            }
        }
    
    return appliedUpdatedPeers
}

public func addContactPeerInteractively(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId) as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
            return account.network.request(Api.functions.contacts.importContacts(contacts: [Api.InputContact.inputPhoneContact(clientId: 1, phone: phone, firstName: peer.firstName ?? "", lastName: peer.lastName ?? "")], replace: .boolFalse))
                |> map { Optional($0) }
                |> `catch` { _ -> Signal<Api.contacts.ImportedContacts?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.modify { modifier -> Void in
                        if let result = result {
                            switch result {
                                case let .importedContacts(_, _, users):
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
