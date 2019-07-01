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

func matchingDeviceContacts(stableIds: [String]) -> Signal<[MatchingDeviceContact], NoError> {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
        return .single([])
    }
    let store = CNContactStore()
    guard let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(withIdentifiers: stableIds), keysToFetch: [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]) else {
        return .single([])
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

func matchingCloudContacts(postbox: Postbox, contacts: [MatchingDeviceContact]) -> Signal<[(String, TelegramUser)], NoError> {
    return postbox.transaction { transaction -> [(String, TelegramUser)] in
        var result: [(String, TelegramUser)] = []
        outer: for peerId in transaction.getContactPeerIds() {
            if let peer = transaction.getPeer(peerId) as? TelegramUser, let phone = peer.phone {
                for contact in contacts {
                    for phoneNumber in contact.phoneNumbers {
                        if arePhoneNumbersEqual(phoneNumber, phone) {
                            result.append((contact.stableId, peer))
                            continue outer
                        }
                    }
                }
            }
        }
        return result
    }
}

func personWithUser(stableId: String, user: TelegramUser) -> INPerson {
    var nameComponents = PersonNameComponents()
    nameComponents.givenName = user.firstName
    nameComponents.familyName = user.lastName
    return INPerson(personHandle: INPersonHandle(value: stableId, type: .unknown), nameComponents: nameComponents, displayName: user.debugDisplayTitle, image: nil, contactIdentifier: stableId, customIdentifier: "tg\(user.id.toInt64())")
}
