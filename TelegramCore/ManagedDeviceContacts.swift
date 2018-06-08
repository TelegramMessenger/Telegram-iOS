import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramCorePrivateModule

final class ManagedDeviceContactsMetaInfo: UnorderedItemListTagMetaInfo {
    let version: Int32
    
    init(version: Int32) {
        self.version = version
    }
    
    init(decoder: PostboxDecoder) {
        self.version = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.version, forKey: "v")
    }
    
    func isEqual(to: UnorderedItemListTagMetaInfo) -> Bool {
        if let to = to as? ManagedDeviceContactsMetaInfo {
            return self.version == to.version
        } else {
            return false
        }
    }
}

final class ManagedDeviceContactEntryContents: PostboxCoding {
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let peerId: PeerId?
    let importDelayedUntil: Int32?
    
    init(firstName: String, lastName: String, phoneNumber: String, peerId: PeerId?, importDelayedUntil: Int32?) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.peerId = peerId
        self.importDelayedUntil = importDelayedUntil
    }
    
    init(decoder: PostboxDecoder) {
        self.firstName = decoder.decodeStringForKey("f", orElse: "")
        self.lastName = decoder.decodeStringForKey("l", orElse: "")
        self.phoneNumber = decoder.decodeStringForKey("n", orElse: "")
        if let peerId = decoder.decodeOptionalInt64ForKey("p") {
            self.peerId = PeerId(peerId)
        } else {
            self.peerId = nil
        }
        self.importDelayedUntil = decoder.decodeOptionalInt32ForKey("dt")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.firstName, forKey: "f")
        encoder.encodeString(self.lastName, forKey: "l")
        encoder.encodeString(self.phoneNumber, forKey: "n")
        if let peerId = self.peerId {
            encoder.encodeInt64(peerId.toInt64(), forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        if let importDelayedUntil = self.importDelayedUntil {
            encoder.encodeInt32(importDelayedUntil, forKey: "dt")
        } else {
            encoder.encodeNil(forKey: "dt")
        }
    }
    
    func withUpdatedPeerId(_ peerId: PeerId?) -> ManagedDeviceContactEntryContents {
        return ManagedDeviceContactEntryContents(firstName: self.firstName, lastName: self.lastName, phoneNumber: self.phoneNumber, peerId: peerId, importDelayedUntil: self.importDelayedUntil)
    }
    
    func withUpdatedImportDelayedUntil(_ importDelayedUntil: Int32?) -> ManagedDeviceContactEntryContents {
        return ManagedDeviceContactEntryContents(firstName: self.firstName, lastName: self.lastName, phoneNumber: self.phoneNumber, peerId: self.peerId, importDelayedUntil: importDelayedUntil)
    }
}

private func unorderedListEntriesForDeviceContact(_ deviceContact: DeviceContact) -> [UnorderedItemListEntry] {
    var entries: [UnorderedItemListEntry] = []
    for phoneNumber in deviceContact.phoneNumbers {
        let stringToHash = "\(deviceContact.firstName):\(deviceContact.lastName):\(phoneNumber.number)"
        entries.append(UnorderedItemListEntry(id: ValueBoxKey(phoneNumber.number.normalized.rawValue), info: UnorderedItemListEntryInfo(hashValue: Int64(stringToHash.hashValue)), contents: ManagedDeviceContactEntryContents(firstName: deviceContact.firstName, lastName: deviceContact.lastName, phoneNumber: phoneNumber.number.normalized.rawValue, peerId: nil, importDelayedUntil: nil)))
    }
    return entries
}

private enum ManagedDeviceContactsError {
    case generic
    case done
}

func managedDeviceContacts(postbox: Postbox, network: Network, deviceContacts: Signal<[DeviceContact], NoError>) -> Signal<Void, NoError> {
    #if os(iOS) && DEBUG
    return .never()
    #endif
    let queue = Queue()
    
    return deviceContacts
        |> deliverOn(queue)
        |> mapToSignal { contacts -> Signal<Void, NoError> in
            var entries: [ValueBoxKey: UnorderedItemListEntry] = [:]
            for contact in contacts {
                for entry in unorderedListEntriesForDeviceContact(contact) {
                    entries[entry.id] = entry
                }
            }
    
            var infos: [ValueBoxKey: UnorderedItemListEntryInfo] = [:]
            for (id, entry) in entries {
                infos[id] = UnorderedItemListEntryInfo(hashValue: entry.info.hashValue)
            }
            let appliedDifference = postbox.modify { modifier -> Signal<Void, ManagedDeviceContactsError> in
                let (metaInfo, added, removed, updated) = modifier.unorderedItemListDifference(tag: Namespaces.UnorderedItemList.synchronizedDeviceContacts, updatedEntryInfos: infos)
                
                let timestamp = Int32(CFAbsoluteTimeGetCurrent())
                var reimportKeys = Set<ValueBoxKey>()
                modifier.unorderedItemListScan(tag: Namespaces.UnorderedItemList.synchronizedDeviceContacts, { entry in
                    if let contents = entry.contents as? ManagedDeviceContactEntryContents {
                        if let importDelayedUntil = contents.importDelayedUntil, importDelayedUntil <= timestamp {
                            reimportKeys.insert(entry.id)
                        }
                    }
                })
                
                var addedOrUpdatedContacts: [ManagedDeviceContactEntryContents] = []
                
                for id in added {
                    reimportKeys.remove(id)
                    
                    if let entry = entries[id], let contents = entry.contents as? ManagedDeviceContactEntryContents {
                        addedOrUpdatedContacts.append(contents)
                    } else {
                        assertionFailure()
                    }
                }
                
                for previousEntry in updated {
                    reimportKeys.remove(previousEntry.id)
                    
                    if let entry = entries[previousEntry.id], let contents = entry.contents as? ManagedDeviceContactEntryContents {
                        addedOrUpdatedContacts.append(contents)
                    } else {
                        assertionFailure()
                    }
                }
                
                var removedPeerIds: [PeerId] = []
                for entry in removed {
                    reimportKeys.remove(entry.id)
                    
                    if let contents = entry.contents as? ManagedDeviceContactEntryContents {
                        if let peerId = contents.peerId {
                            removedPeerIds.append(peerId)
                        }
                    }
                }
                
                for id in reimportKeys {
                    if let entry = entries[id], let contents = entry.contents as? ManagedDeviceContactEntryContents {
                        addedOrUpdatedContacts.append(contents)
                    }
                }
                
                return (applyRemovedContacts(postbox: postbox, network: network, peerIds: removedPeerIds)
                    |> map { _ -> ([Peer], [PeerId: PeerPresence], [ValueBoxKey: ManagedDeviceContactEntryContents], [String: Int32]) in
                        assertionFailure()
                        return ([], [:], [:], [:])
                    }
                    |> then(applyAddedOrUpdatedContacts(network: network, contacts: addedOrUpdatedContacts)))
                    |> mapToSignal { peers, peerPresences, importedContents, importedByCounts -> Signal<Void, ManagedDeviceContactsError> in
                        return postbox.modify { modifier -> Signal<Void, ManagedDeviceContactsError> in
                            for (phone, count) in importedByCounts {
                                modifier.setDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(phone), value: TelegramDeviceContactImportInfo(importedByCount: count))
                            }
                            
                            let updatedInfo: UnorderedItemListTagMetaInfo
                            if let previousInfo = metaInfo as? ManagedDeviceContactsMetaInfo {
                                updatedInfo = ManagedDeviceContactsMetaInfo(version: previousInfo.version + 1)
                            } else {
                                updatedInfo = ManagedDeviceContactsMetaInfo(version: 0)
                            }
                            var setItems: [UnorderedItemListEntry] = []
                            var addedPeerIds: [PeerId] = []
                            for contents in importedContents.values {
                                let stringToHash = "\(contents.firstName):\(contents.lastName):\(contents.phoneNumber)"
                                if let peerId = contents.peerId {
                                    addedPeerIds.append(peerId)
                                }
                                setItems.append(UnorderedItemListEntry(id: ValueBoxKey(contents.phoneNumber), info: UnorderedItemListEntryInfo(hashValue: Int64(stringToHash.hashValue)), contents: contents))
                            }
                            if modifier.unorderedItemListApplyDifference(tag: Namespaces.UnorderedItemList.synchronizedDeviceContacts, previousInfo: metaInfo, updatedInfo: updatedInfo, setItems: setItems, removeItemIds: removed.map { $0.id }) {
                                updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                                    return updated
                                })
                                modifier.updatePeerPresences(peerPresences)
                                
                                if !removedPeerIds.isEmpty || !addedPeerIds.isEmpty {
                                    var updatedPeerIds = modifier.getContactPeerIds()
                                    for peerId in removedPeerIds {
                                        updatedPeerIds.remove(peerId)
                                    }
                                    for peerId in addedPeerIds {
                                        updatedPeerIds.insert(peerId)
                                    }
                                    modifier.replaceContactPeerIds(updatedPeerIds)
                                }
                                
                                if importedContents.count == addedOrUpdatedContacts.count {
                                    return .fail(.done)
                                } else {
                                    return .complete()
                                }
                            } else {
                                return .complete()
                            }
                        } |> mapError { _ -> ManagedDeviceContactsError in return .generic } |> switchToLatest
                    }
            } |> mapError { _ -> ManagedDeviceContactsError in return .generic } |> switchToLatest
    
            return ((appliedDifference
                |> `catch` { error -> Signal<Void, NoError> in
                    switch error {
                        case .done:
                            return .fail(NoError())
                        case .generic:
                            return .fail(NoError())
                    }
                }) |> restart) |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
        }
}

private func applyRemovedContacts(postbox: Postbox, network: Network, peerIds: [PeerId]) -> Signal<Void, ManagedDeviceContactsError> {
    if peerIds.isEmpty {
        return .complete()
    }
    
    return postbox.modify { modifier -> Signal<Void, ManagedDeviceContactsError> in
        var inputUsers: [Api.InputUser] = []
        for peerId in peerIds {
            if let peer = modifier.getPeer(peerId), let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            }
        }
        return .complete()
        /*return network.request(Api.functions.contacts.deleteContacts(id: inputUsers))
            |> `catch` { _ -> Signal<Api.Bool, ManagedDeviceContactsError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, ManagedDeviceContactsError> in
                return .complete()
            }*/
    } |> mapError { _ -> ManagedDeviceContactsError in return .generic } |> switchToLatest
}

private func applyAddedOrUpdatedContacts(network: Network, contacts: [ManagedDeviceContactEntryContents]) -> Signal<([Peer], [PeerId: PeerPresence], [ValueBoxKey: ManagedDeviceContactEntryContents], [String: Int32]), ManagedDeviceContactsError> {
    if contacts.isEmpty {
        return .single(([], [:], [:], [:]))
    }
    
    var clientIdToContact: [Int64: ManagedDeviceContactEntryContents] = [:]
    var apiContacts: [Api.InputContact] = []
    var nextId: Int64 = 0
    for contact in contacts {
        clientIdToContact[nextId] = contact
        apiContacts.append(.inputPhoneContact(clientId: nextId, phone: contact.phoneNumber, firstName: contact.firstName, lastName: contact.lastName))
        nextId += 1
    }
    return network.request(Api.functions.contacts.importContacts(contacts: apiContacts))
        |> `catch` { _ -> Signal<Api.contacts.ImportedContacts, ManagedDeviceContactsError> in
            return .fail(.generic)
        }
        |> mapToSignal { result -> Signal<([Peer], [PeerId: PeerPresence], [ValueBoxKey: ManagedDeviceContactEntryContents], [String: Int32]), ManagedDeviceContactsError> in
            switch result {
                case let .importedContacts(imported, popularInvites, retryContacts, users):
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    var importedContents: [ValueBoxKey: ManagedDeviceContactEntryContents] = [:]
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
                        }
                    }
                    var importedClientIds = Set<Int64>()
                    for item in imported {
                        switch item {
                            case let .importedContact(userId, clientId):
                                if let contents = clientIdToContact[clientId] {
                                    importedClientIds.insert(clientId)
                                    importedContents[ValueBoxKey(contents.phoneNumber)] = contents.withUpdatedPeerId(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId))
                                }
                        }
                    }
                    
                    let reimportClientIds = Set(retryContacts)
                    
                    let reimportTimestamp = Int32(CFAbsoluteTimeGetCurrent()) + Int32(1 * 60 * 60)
                    for (clientId, contents) in clientIdToContact {
                        if !importedClientIds.contains(clientId) {
                            var updatedContents = contents
                            if reimportClientIds.contains(clientId) {
                                updatedContents = updatedContents.withUpdatedImportDelayedUntil(reimportTimestamp)
                            }
                            importedContents[ValueBoxKey(contents.phoneNumber)] = updatedContents
                        }
                    }
                    
                    var importedByCounts: [String: Int32] = [:]
                    for item in popularInvites {
                        switch item {
                            case let .popularContact(clientId, importers):
                                if let contact = clientIdToContact[clientId] {
                                    importedByCounts[contact.phoneNumber] = importers
                                }
                        }
                    }
                
                    return .single((peers, peerPresences, importedContents, importedByCounts))
            }
        }
}
