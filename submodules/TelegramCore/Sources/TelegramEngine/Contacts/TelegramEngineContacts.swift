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

        public func deleteAllContacts() -> Signal<Never, NoError> {
            return _internal_deleteAllContacts(account: self.account)
        }

        public func resetSavedContacts() -> Signal<Void, NoError> {
            return _internal_resetSavedContacts(network: self.account.network)
        }

        public func updateContactName(peerId: PeerId, firstName: String, lastName: String) -> Signal<Void, UpdateContactNameError> {
            return _internal_updateContactName(account: self.account, peerId: peerId, firstName: firstName, lastName: lastName)
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

        public func searchRemotePeers(query: String) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
            return _internal_searchPeers(account: self.account, query: query)
        }

        public func searchLocalPeers(query: String) -> Signal<[EngineRenderedPeer], NoError> {
            return self.account.postbox.searchPeers(query: query)
            |> map { peers in
                return peers.map(EngineRenderedPeer.init)
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
    }
}
