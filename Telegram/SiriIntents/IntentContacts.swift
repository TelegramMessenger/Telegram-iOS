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
    
    return .single(contacts.map({ contact in
        let phoneNumbers = contact.phoneNumbers.compactMap({ number -> String? in
            if !number.value.stringValue.isEmpty {
                return cleanPhoneNumber(number.value.stringValue)
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
    }))
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
        var result: [(String, TelegramUser)] = []
        outer: for peerId in transaction.getContactPeerIds() {
            if let peer = transaction.getPeer(peerId) as? TelegramUser {
                for contact in contacts {
                    if let contactPeerId = contact.peerId, contactPeerId == peerId {
                        result.append((contact.stableId, peer))
                        continue outer
                    } else if let peerPhoneNumber = peer.phone {
                        for contactPhoneNumber in contact.phoneNumbers {
                            if matchPhoneNumbers(contactPhoneNumber, peerPhoneNumber) {
                                result.append((contact.stableId, peer))
                                continue outer
                            }
                        }
                    }
                }
            }
        }
        return result
    }
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
