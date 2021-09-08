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
    }
}
