import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Contacts {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func deleteContactPeerInteractively(peerId: PeerId) -> Signal<Never, NoError> {
            return _internal_deleteContactPeerInteractively(account: self.account, peerId: peerId)
        }
        
        public func deleteContacts(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return _internal_deleteContacts(account: self.account, peerIds: peerIds)
        }

        public func deleteAllContacts() -> Signal<Never, NoError> {
            return _internal_deleteAllContacts(account: self.account)
        }

        public func resetSavedContacts() -> Signal<Void, NoError> {
            return _internal_resetSavedContacts(network: self.account.network)
        }

        public func updateContactName(peerId: PeerId, firstName: String, lastName: String) -> Signal<Void, UpdateContactNameError> {
            return _internal_updateContactName(account: self.account, peerId: peerId, firstName: firstName, lastName: lastName)
        }

        public func updateContactPhoto(peerId: PeerId, resource: MediaResource?, videoResource: MediaResource?, videoStartTimestamp: Double?, markup: UploadPeerPhotoMarkup?, mode: SetCustomPeerPhotoMode, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updateContactPhoto(account: self.account, peerId: peerId, resource: resource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: markup, mode: mode, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
        }
        
        public func deviceContactsImportedByCount(contacts: [(String, [DeviceContactNormalizedPhoneNumber])]) -> Signal<[String: Int32], NoError> {
            return _internal_deviceContactsImportedByCount(postbox: self.account.postbox, contacts: contacts)
        }

        public func importContact(firstName: String, lastName: String, phoneNumber: String) -> Signal<PeerId?, NoError> {
            return _internal_importContact(account: self.account, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber)
        }

        public func addContactInteractively(peerId: PeerId, firstName: String, lastName: String, phoneNumber: String, addToPrivacyExceptions: Bool) -> Signal<Never, AddContactError> {
            return _internal_addContactInteractively(account: self.account, peerId: peerId, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, addToPrivacyExceptions: addToPrivacyExceptions)
        }

        public func acceptAndShareContact(peerId: PeerId) -> Signal<Never, AcceptAndShareContactError> {
            return _internal_acceptAndShareContact(account: self.account, peerId: peerId)
        }

        public func searchRemotePeers(query: String, scope: TelegramSearchPeersScope = .everywhere) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
            return _internal_searchPeers(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, query: query, scope: scope)
        }

        public func searchLocalPeers(query: String, scope: TelegramSearchPeersScope = .everywhere) -> Signal<[EngineRenderedPeer], NoError> {
            return self.account.postbox.searchPeers(query: query)
            |> map { peers in
                switch scope {
                case .everywhere:
                    return peers.map(EngineRenderedPeer.init)
                case .channels:
                    return peers.filter { peer in
                        if let channel = peer.peer as? TelegramChannel, case .broadcast = channel.info {
                            return true
                        } else {
                            return false
                        }
                    }.map(EngineRenderedPeer.init)
                case .groups:
                    return peers.filter { item in
                        if let channel = item.peer as? TelegramChannel, case .group = channel.info {
                            return true
                        } else if item.peer is TelegramGroup {
                            return true
                        } else {
                            return false
                        }
                    }.map(EngineRenderedPeer.init)
                case .privateChats:
                    return peers.filter { item in
                        if item.peer is TelegramUser {
                            return true
                        } else {
                            return false
                        }
                    }.map(EngineRenderedPeer.init)
                }
            }
        }

        public func searchContacts(query: String) -> Signal<([EnginePeer], [EnginePeer.Id: EnginePeer.Presence]), NoError> {
            return self.account.postbox.searchContacts(query: query)
            |> map { peers, presences in
                return (peers.map(EnginePeer.init), presences.mapValues(EnginePeer.Presence.init))
            }
        }
        
        public func updateIsContactSynchronizationEnabled(isContactSynchronizationEnabled: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.updatePreferencesEntry(key: PreferencesKeys.contactsSettings, { current in
                    var settings = current?.get(ContactsSettings.self) ?? ContactsSettings.defaultSettings
                    settings.synchronizeContacts = isContactSynchronizationEnabled
                    return PreferencesEntry(settings)
                })
            }
            |> ignoreValues
        }
        
        public func findPeerByLocalContactIdentifier(identifier: String) -> Signal<EnginePeer?, NoError> {
            return self.account.postbox.transaction { transaction -> EnginePeer? in
                var foundPeerId: PeerId?
                transaction.enumerateDeviceContactImportInfoItems({ _, value in
                    if let value = value as? TelegramDeviceContactImportedData {
                        switch value {
                        case let .imported(data, _, peerId):
                            if data.localIdentifiers.contains(identifier) {
                                if let peerId = peerId {
                                    foundPeerId = peerId
                                    return false
                                }
                            }
                        default:
                            break
                        }
                    }
                    return true
                })
                if let foundPeerId = foundPeerId {
                    return transaction.getPeer(foundPeerId).flatMap(EnginePeer.init)
                } else {
                    return nil
                }
            }
        }
    }
}
