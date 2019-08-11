import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import Intents

struct MatchingDeviceContact {
    let stableId: String
    let firstName: String
    let lastName: String
    let phoneNumbers: [String]
}

enum IntentContactsError {
    case generic
}

func matchingDeviceContacts(stableIds: [String]) -> Signal<[MatchingDeviceContact], IntentContactsError> {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
        return .fail(.generic)
    }
    let store = CNContactStore()
    guard let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(withIdentifiers: stableIds), keysToFetch: [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]) else {
        return .fail(.generic)
    }
    
    return .single(contacts.map({ contact in
        let phoneNumbers = contact.phoneNumbers.compactMap({ number -> String? in
            if !number.value.stringValue.isEmpty {
                return number.value.stringValue
            } else {
                return nil
            }
        })
        
        return MatchingDeviceContact(stableId: contact.identifier, firstName: contact.givenName, lastName: contact.familyName, phoneNumbers: phoneNumbers)
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
            if let peer = transaction.getPeer(peerId) as? TelegramUser, let peerPhoneNumber = peer.phone {
                for contact in contacts {
                    for phoneNumber in contact.phoneNumbers {
                        if matchPhoneNumbers(phoneNumber, peerPhoneNumber) {
                            result.append((contact.stableId, peer))
                            continue outer
                        }
                    }
                }
//        var parsedPhoneNumbers: [String: ParsedPhoneNumber] = [:]
//                let parsedPeerPhoneNumber: ParsedPhoneNumber?
//                if let number = parsedPhoneNumbers[peerPhoneNumber] {
//                    parsedPeerPhoneNumber = number
//                } else if let number = ParsedPhoneNumber(string: peerPhoneNumber) {
//                    parsedPeerPhoneNumber = number
//                    parsedPhoneNumbers[peerPhoneNumber] = number
//                } else {
//                    parsedPeerPhoneNumber = nil
//                }
//
//                for contact in contacts {
//                    for phoneNumber in contact.phoneNumbers {
//                        let parsedPhoneNumber: ParsedPhoneNumber?
//                        if let number = parsedPhoneNumbers[phoneNumber] {
//                            parsedPhoneNumber = number
//                        } else if let number = ParsedPhoneNumber(string: phoneNumber) {
//                            parsedPhoneNumber = number
//                            parsedPhoneNumbers[phoneNumber] = number
//                        } else {
//                            parsedPhoneNumber = nil
//                        }
//
//                        if parsedPeerPhoneNumber == parsedPhoneNumber {
//                            result.append((contact.stableId, peer))
//                            continue outer
//                        }
//                    }
//                }
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

func personWithUser(stableId: String, user: TelegramUser) -> INPerson {
    var nameComponents = PersonNameComponents()
    nameComponents.givenName = user.firstName
    nameComponents.familyName = user.lastName
    return INPerson(personHandle: INPersonHandle(value: stableId, type: .unknown), nameComponents: nameComponents, displayName: user.debugDisplayTitle, image: nil, contactIdentifier: stableId, customIdentifier: "tg\(user.id.toInt64())")
}
