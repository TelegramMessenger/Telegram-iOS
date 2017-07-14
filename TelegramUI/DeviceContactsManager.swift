import Foundation
import Contacts
import SwiftSignalKit
import Postbox
import TelegramCore

private func authorizedContacts() -> Signal<Bool, NoError> {
    return Signal { subscriber in
        if #available(iOSApplicationExtension 9.0, *) {
            if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
                let store = CNContactStore()
                store.requestAccess(for: .contacts, completionHandler: { authorized, _ in
                    subscriber.putNext(authorized)
                    subscriber.putCompletion()
                })
            } else if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
                subscriber.putNext(true)
                subscriber.putCompletion()
            }
        } else {
            
        }
        
        return EmptyDisposable
    }
}

@available(iOSApplicationExtension 9.0, *)
private func retrieveContactsWithStore(_ store: CNContactStore) -> [DeviceContact] {
    let keysToFetch: [CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]
    
    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
    request.unifyResults = true
    
    var result: [DeviceContact] = []
    let _ = try? store.enumerateContacts(with: request, usingBlock: { contact, _ in
        var phoneNumbers: [DeviceContactPhoneNumber] = []
        for number in contact.phoneNumbers {
            phoneNumbers.append(DeviceContactPhoneNumber(label: number.label ?? "", number: number.value.stringValue))
        }
        result.append(DeviceContact(id: contact.identifier, firstName: contact.givenName, lastName: contact.familyName, phoneNumbers: phoneNumbers))
    })
    return result
}

@available(iOSApplicationExtension 9.0, *)
private func modernContacts() -> Signal<[DeviceContact], NoError> {
    return authorizedContacts()
        |> mapToSignal { authorized -> Signal<[DeviceContact], NoError> in
            return Signal { subscriber in
                let queue = Queue()
                let disposable = MetaDisposable()
                queue.async {
                    let store = CNContactStore()
                    var current = retrieveContactsWithStore(store)
                    subscriber.putNext(current)
                    
                    let handle = NotificationCenter.default.addObserver(forName: NSNotification.Name.CNContactStoreDidChange, object: nil, queue: nil, using: { _ in
                        queue.async {
                            let updated = retrieveContactsWithStore(store)
                            if current != updated {
                                current = updated
                                subscriber.putNext(updated)
                            }
                        }
                    })
                    
                    disposable.set(ActionDisposable {
                        NotificationCenter.default.removeObserver(handle)
                    })
                }
                return disposable
            }
        }
}

public final class DeviceContactsManager {
    private let contactsValue = Promise<[DeviceContact]>()
    public var contacts: Signal<[DeviceContact], NoError> {
        return self.contactsValue.get()
    }
    
    init() {
        if #available(iOSApplicationExtension 9.0, *) {
            self.contactsValue.set(modernContacts())
        } else {
            
        }
    }
}
