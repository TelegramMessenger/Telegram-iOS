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
private func parseContact(_ contact: CNContact) -> DeviceContact {
    var phoneNumbers: [DeviceContactPhoneNumber] = []
    for number in contact.phoneNumbers {
        phoneNumbers.append(DeviceContactPhoneNumber(label: number.label ?? "", number: DeviceContactPhoneNumberValue(plain: number.value.stringValue, normalized: DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(number.value.stringValue)))))
    }
    return DeviceContact(id: contact.identifier, firstName: contact.givenName, lastName: contact.familyName, phoneNumbers: phoneNumbers)
}

@available(iOSApplicationExtension 9.0, *)
private func retrieveContactsWithStore(_ store: CNContactStore) -> [DeviceContact] {
    let keysToFetch: [CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]
    
    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
    request.unifyResults = true
    
    var result: [DeviceContact] = []
    let _ = try? store.enumerateContacts(with: request, usingBlock: { contact, _ in
        result.append(parseContact(contact))
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

private final class DeviceContactsMappingSubscriberContext {
    var subscribers = Bag<([DeviceContact]) -> Void>()
    
    var isEmpty: Bool {
        if !self.subscribers.isEmpty {
            return false
        }
        return true
    }
}

private final class DeviceContactsManagerContext {
    private let queue: Queue
    private var contacts: [DeviceContact] = []
    private var contactMapping: [DeviceContactNormalizedPhoneNumber: [DeviceContact]] = [:]
    
    private var disposable: Disposable?
    
    private var mappingSubscriberContexts: [DeviceContactNormalizedPhoneNumber: DeviceContactsMappingSubscriberContext] = [:]
    
    init(queue: Queue) {
        self.queue = queue
        
        if #available(iOSApplicationExtension 9.0, *) {
            self.disposable = (modernContacts()
                |> deliverOn(self.queue)).start(next: { [weak self] value in
                    if let strongSelf = self {
                        strongSelf.updateContacts(value)
                    }
                })
        }
    }
    
    private func updateContacts(_ contacts: [DeviceContact]) {
        self.contacts = contacts
        var contactMapping: [DeviceContactNormalizedPhoneNumber: [DeviceContact]] = [:]
        
        for contact in contacts {
            for phoneNumber in contact.phoneNumbers {
                if contactMapping[phoneNumber.number.normalized] == nil {
                    contactMapping[phoneNumber.number.normalized] = []
                }
                contactMapping[phoneNumber.number.normalized]!.append(contact)
            }
        }
        
        self.contactMapping = contactMapping
        
        for (key, context) in self.mappingSubscriberContexts {
            for f in context.subscribers.copyItems() {
                f(contactMapping[key] ?? [])
            }
        }
    }
    
    func subscribe(_ number: DeviceContactNormalizedPhoneNumber) -> Signal<[DeviceContact], NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext(strongSelf.contactMapping[number] ?? [])
                let context: DeviceContactsMappingSubscriberContext
                if let current = strongSelf.mappingSubscriberContexts[number] {
                    context = current
                } else {
                    context = DeviceContactsMappingSubscriberContext()
                    strongSelf.mappingSubscriberContexts[number] = context
                }
                let index = context.subscribers.add({ next in
                    subscriber.putNext(next)
                })
                return ActionDisposable { [weak context] in
                    queue.async {
                        if let strongSelf = self, let current = strongSelf.mappingSubscriberContexts[number], current === context {
                            current.subscribers.remove(index)
                            if current.isEmpty {
                                strongSelf.mappingSubscriberContexts.removeValue(forKey: number)
                            }
                        }
                    }
                }
            } else {
                subscriber.putNext([])
                subscriber.putCompletion()
                return EmptyDisposable
            }
        } |> runOn(self.queue)
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

public final class DeviceContactsManager {
    private let contactsValue = Promise<[DeviceContact]>()
    public var contacts: Signal<[DeviceContact], NoError> {
        return self.contactsValue.get()
    }
    
    private let impl: QueueLocalObject<DeviceContactsManagerContext>
    
    init() {
        let queue = Queue()
        self.impl = QueueLocalObject<DeviceContactsManagerContext>(queue: queue, generate: {
            return DeviceContactsManagerContext(queue: queue)
        })
        
        if #available(iOSApplicationExtension 9.0, *) {
            self.contactsValue.set(modernContacts())
        }
    }
    
    public func subscribe(_ number: DeviceContactNormalizedPhoneNumber) -> Signal<[DeviceContact], NoError> {
        return Signal<Signal<[DeviceContact], NoError>, NoError> { subscriber in
            self.impl.with { context in
                subscriber.putNext(context.subscribe(number))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        } |> switchToLatest
    }
    
    public func add(firstName: String, lastName: String, phoneNumbers: [DeviceContactPhoneNumber]) -> Signal<DeviceContact?, NoError> {
        return authorizedContacts()
        |> mapToSignal { authorized -> Signal<DeviceContact?, NoError> in
            if !authorized {
                return .single(nil)
            }
            if #available(iOSApplicationExtension 9.0, *) {
                let store = CNContactStore()
                
                let contact = CNMutableContact()
                contact.familyName = firstName
                contact.givenName = lastName
                
                contact.phoneNumbers = phoneNumbers.map { value in
                    return CNLabeledValue(label: value.label, value: CNPhoneNumber(stringValue: value.number.normalized.rawValue))
                }
                
                let request = CNSaveRequest()
                request.add(contact, toContainerWithIdentifier: nil)
                
                if let _ = try? store.execute(request) {
                    return .single(parseContact(contact))
                } else {
                    return .single(nil)
                }
            } else {
                return .single(nil)
            }
        }
    }
}
