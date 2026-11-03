import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import Intents

func formatPhoneNumber(_ value: String) -> String {
    if value.hasPrefix("+") {
        return value
    } else {
        return "+\(value)"
    }
}

struct MatchingDeviceContact {
    let stableId: String
    let firstName: String
    let lastName: String
    /// The numbers exactly as the device stores them (`CNPhoneNumber.stringValue`): the form the
    /// app imports them in, and so the key contact sync records each one's match under.
    let phoneNumbers: [String]
    let peerId: PeerId?
}

enum IntentContactsError {
    case generic
}

private let phonebookUsernamePathPrefix = "@id"
private let phonebookUsernamePrefix = "https://t.me/" + phonebookUsernamePathPrefix

private func parseAppSpecificContactReference(_ value: String) -> PeerId? {
    if !value.hasPrefix(phonebookUsernamePrefix) {
        return nil
    }
    let idString = String(value[value.index(value.startIndex, offsetBy: phonebookUsernamePrefix.count)...])
    if let id = Int64(idString) {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
    }
    return nil
}

private func cleanPhoneNumber(_ text: String) -> String {
    var result = ""
    for c in text {
        if c == "+" {
            if result.isEmpty {
                result += String(c)
            }
        } else if c >= "0" && c <= "9" {
            result += String(c)
        }
    }
    return result
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func matchingDeviceContacts(stableIds: [String]) -> Signal<[MatchingDeviceContact], IntentContactsError> {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
        return .fail(.generic)
    }
    let store = CNContactStore()
    guard let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(withIdentifiers: stableIds), keysToFetch: [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor, CNContactUrlAddressesKey as CNKeyDescriptor]) else {
        return .fail(.generic)
    }
    
    return .single(contacts.map(matchingDeviceContact))
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func matchingDeviceContact(_ contact: CNContact) -> MatchingDeviceContact {
    let phoneNumbers = contact.phoneNumbers.compactMap({ number -> String? in
        if !number.value.stringValue.isEmpty {
            return number.value.stringValue
        } else {
            return nil
        }
    })

    var contactPeerId: PeerId?
    for address in contact.urlAddresses {
        if address.label == "Telegram", let peerId = parseAppSpecificContactReference(address.value as String) {
            contactPeerId = peerId
        }
    }

    return MatchingDeviceContact(stableId: contact.identifier, firstName: contact.givenName, lastName: contact.familyName, phoneNumbers: phoneNumbers, peerId: contactPeerId)
}

private func matchPhoneNumbers(_ lhs: String, _ rhs: String) -> Bool {
    if lhs.count < 10 && lhs.count == rhs.count {
        return lhs == rhs
    } else if lhs.count >= 10 && rhs.count >= 10 && lhs.suffix(10) == rhs.suffix(10) {
        return true
    } else {
        return false
    }
}

func matchingCloudContacts(postbox: Postbox, contacts: [MatchingDeviceContact]) -> Signal<[(String, TelegramUser)], NoError> {
    return postbox.transaction { transaction -> [(String, TelegramUser)] in
        return matchingCloudContacts(transaction: transaction, contacts: contacts)
    }
}

/// The Telegram users a device contact Siri picked stands for, strongest link first: the
/// contact's own Telegram link, then whom contact sync imported each of its numbers as, then the
/// contacts whose phone matches one of its numbers by digits.
///
/// The import record is the only way to place a number saved in national format ("600 00 00 00"
/// for +34 600 00 00 00): it carries no country code, so the comparison of digits can never match
/// it to the international number a Telegram user has. The digits still run on every number: they
/// are all there is when sync has no record (sync off, not run yet), and they follow a number's
/// current owner, while a record is rewritten only when the device contact changes. When the two
/// disagree (the person the contact was imported as has moved to another number and someone else
/// now holds this one) both are offered and Siri asks. Deleting a contact leaves its record
/// behind, so a record counts only while its user is still a contact, the same bound the digits
/// have.
func matchingCloudContacts(transaction: Transaction, contacts: [MatchingDeviceContact]) -> [(String, TelegramUser)] {
    var result: [(String, TelegramUser)] = []
    var matchingIds = Set<EnginePeer.Id>()
    func add(_ stableId: String, _ peer: TelegramUser) {
        if matchingIds.insert(peer.id).inserted {
            result.append((stableId, peer))
        }
    }
    let contactPeerIds = transaction.getContactPeerIds()

    for contact in contacts {
        if let peerId = contact.peerId, let peer = transaction.getPeer(peerId) as? TelegramUser {
            add(contact.stableId, peer)
        }
    }
    for contact in contacts {
        for phoneNumber in contact.phoneNumbers {
            if let peerId = deviceContactImportedPeerId(transaction: transaction, number: DeviceContactNormalizedPhoneNumber(rawValue: phoneNumber)), contactPeerIds.contains(peerId), let peer = transaction.getPeer(peerId) as? TelegramUser {
                add(contact.stableId, peer)
            }
        }
    }
    let cleanPhoneNumbers = contacts.map { $0.phoneNumbers.map(cleanPhoneNumber) }
    outer: for peerId in contactPeerIds {
        if let peer = transaction.getPeer(peerId) as? TelegramUser, let peerPhoneNumber = peer.phone {
            for (contact, phoneNumbers) in zip(contacts, cleanPhoneNumbers) {
                for phoneNumber in phoneNumbers {
                    if matchPhoneNumbers(phoneNumber, peerPhoneNumber) {
                        add(contact.stableId, peer)
                        continue outer
                    }
                }
            }
        }
    }

    return result
}

func matchingCloudContact(postbox: Postbox, peerId: PeerId) -> Signal<TelegramUser?, NoError> {
    return postbox.transaction { transaction -> TelegramUser? in
        if let user = transaction.getPeer(peerId) as? TelegramUser {
            return user
        } else {
            return nil
        }
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func personWithUser(stableId: String, user: TelegramUser) -> INPerson {
    var nameComponents = PersonNameComponents()
    nameComponents.givenName = user.firstName
    nameComponents.familyName = user.lastName
    let personHandle: INPersonHandle
    if let phone = user.phone {
        personHandle = INPersonHandle(value: formatPhoneNumber(phone), type: .phoneNumber)
    } else if let username = user.addressName {
        personHandle = INPersonHandle(value: "@\(username)", type: .unknown)
    } else {
        personHandle = INPersonHandle(value: user.nameOrPhone, type: .unknown)
    }
    
    return INPerson(personHandle: personHandle, nameComponents: nameComponents, displayName: user.debugDisplayTitle, image: nil, contactIdentifier: stableId, customIdentifier: "tg\(user.id.toInt64())")
}

/// The `INPerson` standing for any peer Siri can name: a user through `personWithUser`, a
/// group or channel by its title (its handle is the public @username when it has one).
@available(iOSApplicationExtension 10.0, iOS 10.0, *)
func personWithPeer(stableId: String, peer: Peer) -> INPerson {
    if let user = peer as? TelegramUser {
        return personWithUser(stableId: stableId, user: user)
    }
    let personHandle = INPersonHandle(value: peer.addressName.flatMap { "@\($0)" } ?? peer.debugDisplayTitle, type: .unknown)
    return INPerson(personHandle: personHandle, nameComponents: nil, displayName: peer.debugDisplayTitle, image: nil, contactIdentifier: stableId, customIdentifier: "tg\(peer.id.toInt64())")
}
