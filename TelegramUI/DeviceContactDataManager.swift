import Foundation
import SwiftSignalKit
import TelegramCore
import Contacts
import AddressBook

public typealias DeviceContactStableId = String

private protocol DeviceContactDataContext {
    func getExtendedContactData(stableId: DeviceContactStableId) -> DeviceContactExtendedData?
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId) -> DeviceContactExtendedData?
    func createContactWithData(_ contactData: DeviceContactExtendedData) -> (DeviceContactStableId, DeviceContactExtendedData)?
}

@available(iOSApplicationExtension 9.0, *)
private final class DeviceContactDataModernContext: DeviceContactDataContext {
    let store = CNContactStore()
    var updateHandle: NSObjectProtocol?
    var currentContacts: [DeviceContactStableId: DeviceContactBasicData] = [:]
    
    init(queue: Queue, updated: @escaping ([DeviceContactStableId: DeviceContactBasicData]) -> Void) {
        self.currentContacts = self.retrieveContacts()
        updated(self.currentContacts)
        let handle = NotificationCenter.default.addObserver(forName: NSNotification.Name.CNContactStoreDidChange, object: nil, queue: nil, using: { [weak self] _ in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                let contacts = strongSelf.retrieveContacts()
                if strongSelf.currentContacts != contacts {
                    strongSelf.currentContacts = contacts
                    updated(strongSelf.currentContacts)
                }
            }
        })
        self.updateHandle = handle
    }
    
    deinit {
        if let updateHandle = updateHandle {
            NotificationCenter.default.removeObserver(updateHandle)
        }
    }
    
    private func retrieveContacts() -> [DeviceContactStableId: DeviceContactBasicData] {
        let keysToFetch: [CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName), CNContactPhoneNumbersKey as CNKeyDescriptor]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.unifyResults = true
        
        var result: [DeviceContactStableId: DeviceContactBasicData] = [:]
        let _ = try? self.store.enumerateContacts(with: request, usingBlock: { contact, _ in
            let stableIdAndContact = DeviceContactDataModernContext.parseContact(contact)
            result[stableIdAndContact.0] = stableIdAndContact.1
        })
        return result
    }
    
    private static func parseContact(_ contact: CNContact) -> (DeviceContactStableId, DeviceContactBasicData) {
        var phoneNumbers: [DeviceContactPhoneNumberData] = []
        for number in contact.phoneNumbers {
            phoneNumbers.append(DeviceContactPhoneNumberData(label: number.label ?? "", value: number.value.stringValue))
        }
        return (contact.identifier, DeviceContactBasicData(firstName: contact.givenName, lastName: contact.familyName, phoneNumbers: phoneNumbers))
    }
    
    func getExtendedContactData(stableId: DeviceContactStableId) -> DeviceContactExtendedData? {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactSocialProfilesKey as CNKeyDescriptor,
            CNContactInstantMessageAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactDepartmentNameKey as CNKeyDescriptor
        ]
        
        guard let contact = try? self.store.unifiedContact(withIdentifier: stableId, keysToFetch: keysToFetch) else {
            return nil
        }
        
        return DeviceContactExtendedData(contact: contact)
    }
    
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId) -> DeviceContactExtendedData? {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactSocialProfilesKey as CNKeyDescriptor,
            CNContactInstantMessageAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactDepartmentNameKey as CNKeyDescriptor
        ]
        
        guard let current = try? self.store.unifiedContact(withIdentifier: stableId, keysToFetch: keysToFetch) else {
            return nil
        }
        
        let contact = contactData.asMutableCNContact()
        
        let mutableContact = current.mutableCopy() as! CNMutableContact
        mutableContact.givenName = contact.givenName
        mutableContact.familyName = contact.familyName
        
        var phoneNumbers = mutableContact.phoneNumbers
        for phoneNumber in contact.phoneNumbers.reversed() {
            var found = false
            inner: for n in phoneNumbers {
                if n.value.stringValue == phoneNumber.value.stringValue {
                    found = true
                    break inner
                }
            }
            if !found {
                phoneNumbers.insert(phoneNumber, at: 0)
            }
        }
        mutableContact.phoneNumbers = phoneNumbers
        
        var urlAddresses = mutableContact.urlAddresses
        for urlAddress in contact.urlAddresses.reversed() {
            var found = false
            inner: for n in urlAddresses {
                if n.value.isEqual(urlAddress.value) {
                    found = true
                    break inner
                }
            }
            if !found {
                urlAddresses.insert(urlAddress, at: 0)
            }
        }
        mutableContact.urlAddresses = urlAddresses
        
        var emailAddresses = mutableContact.emailAddresses
        for emailAddress in contact.emailAddresses.reversed() {
            var found = false
            inner: for n in emailAddresses {
                if n.value.isEqual(emailAddress.value) {
                    found = true
                    break inner
                }
            }
            if !found {
                emailAddresses.insert(emailAddress, at: 0)
            }
        }
        mutableContact.emailAddresses = emailAddresses
        
        var postalAddresses = mutableContact.postalAddresses
        for postalAddress in contact.postalAddresses.reversed() {
            var found = false
            inner: for n in postalAddresses {
                if n.value.isEqual(postalAddress.value) {
                    found = true
                    break inner
                }
            }
            if !found {
                postalAddresses.insert(postalAddress, at: 0)
            }
        }
        mutableContact.postalAddresses = postalAddresses
        
        if contact.birthday != nil {
            mutableContact.birthday = contact.birthday
        }
        
        var socialProfiles = mutableContact.socialProfiles
        for socialProfile in contact.socialProfiles.reversed() {
            var found = false
            inner: for n in socialProfiles {
                if n.value.username.lowercased() == socialProfile.value.username.lowercased() && n.value.service.lowercased() == socialProfile.value.service.lowercased() {
                    found = true
                    break inner
                }
            }
            if !found {
                socialProfiles.insert(socialProfile, at: 0)
            }
        }
        mutableContact.socialProfiles = socialProfiles
        
        var instantMessageAddresses = mutableContact.instantMessageAddresses
        for instantMessageAddress in contact.instantMessageAddresses.reversed() {
            var found = false
            inner: for n in instantMessageAddresses {
                if n.value.isEqual(instantMessageAddress.value) {
                    found = true
                    break inner
                }
            }
            if !found {
                instantMessageAddresses.insert(instantMessageAddress, at: 0)
            }
        }
        mutableContact.instantMessageAddresses = instantMessageAddresses
        
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)
        let _ = try? self.store.execute(saveRequest)
        
        return DeviceContactExtendedData(contact: mutableContact)
    }
    
    func createContactWithData(_ contactData: DeviceContactExtendedData) -> (DeviceContactStableId, DeviceContactExtendedData)? {
        let saveRequest = CNSaveRequest()
        let mutableContact = contactData.asMutableCNContact()
        saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
        let _ = try? self.store.execute(saveRequest)
        
        return (mutableContact.identifier, contactData)
    }
}

private func withAddressBook(_ f: (ABAddressBook) -> Void) {
    let addressBookRef = ABAddressBookCreateWithOptions(nil, nil)
    
    if let addressBook = addressBookRef?.takeRetainedValue() {
        f(addressBook)
    }
}

private final class DeviceContactDataLegacyContext: DeviceContactDataContext {
    var currentContacts: [DeviceContactStableId: DeviceContactBasicData] = [:]
    
    init(queue: Queue, updated: @escaping ([DeviceContactStableId: DeviceContactBasicData]) -> Void) {
        self.currentContacts = self.retrieveContacts()
        updated(self.currentContacts)
        /*let handle = NotificationCenter.default.addObserver(forName: NSNotification.Name.CNContactStoreDidChange, object: nil, queue: nil, using: { [weak self] _ in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                let contacts = strongSelf.retrieveContacts()
                if strongSelf.currentContacts != contacts {
                    strongSelf.currentContacts = contacts
                    updated(strongSelf.currentContacts)
                }
            }
        })*/
        //self.updateHandle = handle
    }
    
    deinit {
        /*if let updateHandle = updateHandle {
            NotificationCenter.default.removeObserver(updateHandle)
        }*/
    }
    
    private func retrieveContacts() -> [DeviceContactStableId: DeviceContactBasicData] {
        var result: [DeviceContactStableId: DeviceContactBasicData] = [:]
        withAddressBook { addressBook in
            guard let peopleRef = ABAddressBookCopyArrayOfAllPeople(addressBook)?.takeRetainedValue() else {
                return
            }
            
            for recordRef in peopleRef as NSArray {
                let record = recordRef as ABRecord
                let (stableId, basicData) = DeviceContactDataLegacyContext.parseContact(record)
                result[stableId] = basicData
            }
        }
        return result
    }
    
    private func getContactById(stableId: String) -> ABRecord? {
        let recordId: ABRecordID
        if stableId.hasPrefix("ab-"), let idValue = Int(String(stableId[stableId.index(stableId.startIndex, offsetBy: 3)])) {
            recordId = Int32(clamping: idValue)
        } else {
            return nil
        }
        
        var result: ABRecord?
        withAddressBook { addressBook in
            result = ABAddressBookGetPersonWithRecordID(addressBook, recordId)?.takeUnretainedValue()
        }
        return result
    }
    
    private static func parseContact(_ contact: ABRecord) -> (DeviceContactStableId, DeviceContactBasicData) {
        let stableId = "ab-\(ABRecordGetRecordID(contact))"
        var firstName = ""
        var lastName = ""
        if let value = ABRecordCopyValue(contact, kABPersonFirstNameProperty)?.takeRetainedValue() {
            firstName = value as! CFString as String
        }
        if let value = ABRecordCopyValue(contact, kABPersonLastNameProperty)?.takeRetainedValue() {
            lastName = value as! CFString as String
        }
        
        var phoneNumbers: [DeviceContactPhoneNumberData] = []
        if let value = ABRecordCopyValue(contact, kABPersonPhoneProperty)?.takeRetainedValue() {
            let phones = value as ABMultiValue
            let count = ABMultiValueGetCount(phones)
            for i in 0 ..< count {
                if let phoneRef = ABMultiValueCopyValueAtIndex(phones, i)?.takeRetainedValue() {
                    let phone = phoneRef as! CFString as String
                    var label = ""
                    if let labelRef = ABMultiValueCopyLabelAtIndex(phones, i)?.takeRetainedValue() {
                        label = labelRef as String
                    }
                    phoneNumbers.append(DeviceContactPhoneNumberData(label: label, value: phone))
                }
            }
        }
        
        return (stableId, DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: phoneNumbers))
    }
    
    func getExtendedContactData(stableId: DeviceContactStableId) -> DeviceContactExtendedData? {
        if let contact = self.getContactById(stableId: stableId) {
            let basicData = DeviceContactDataLegacyContext.parseContact(contact).1
            return DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [])
        } else {
            return nil
        }
    }
    
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId) -> DeviceContactExtendedData? {
        return nil
    }
    
    func createContactWithData(_ contactData: DeviceContactExtendedData) -> (DeviceContactStableId, DeviceContactExtendedData)? {
        var result: (DeviceContactStableId, DeviceContactExtendedData)?
        withAddressBook { addressBook in
            let contact = ABPersonCreate()?.takeRetainedValue()
            ABRecordSetValue(contact, kABPersonFirstNameProperty, contactData.basicData.firstName as CFString, nil)
            ABRecordSetValue(contact, kABPersonLastNameProperty, contactData.basicData.lastName as CFString, nil)
            
            let phones = ABMultiValueCreateMutable(ABPropertyType(kABMultiStringPropertyType))?.takeRetainedValue()
            for phone in contactData.basicData.phoneNumbers {
                ABMultiValueAddValueAndLabel(phones, phone.value as CFString, phone.label as CFString, nil)
            }
            ABRecordSetValue(contact, kABPersonPhoneProperty, phones, nil)
            
            if ABAddressBookAddRecord(addressBook, contact, nil) {
                ABAddressBookSave(addressBook, nil)
                
                let stableId = "ab-\(ABRecordGetRecordID(contact))"
                if let contact = self.getContactById(stableId: stableId) {
                    let parsedContact = DeviceContactDataLegacyContext.parseContact(contact).1
                    result = (stableId, DeviceContactExtendedData(basicData: parsedContact, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: []))
                }
            }
        }
        return result
    }
}

private final class ExtendedContactDataContext {
    var value: DeviceContactExtendedData?
    let subscribers = Bag<(DeviceContactExtendedData) -> Void>()
}

private final class BasicDataForNormalizedNumberContext {
    var value: [(DeviceContactStableId, DeviceContactBasicData)]
    let subscribers = Bag<([(DeviceContactStableId, DeviceContactBasicData)]) -> Void>()
    
    init(value: [(DeviceContactStableId, DeviceContactBasicData)]) {
        self.value = value
    }
}

private final class DeviceContactDataManagerImpl {
    private let queue: Queue
    
    private var accessInitialized = false
    
    private var dataContext: DeviceContactDataContext?
    private var extendedContexts: [DeviceContactStableId: ExtendedContactDataContext] = [:]
    
    private var stableIdToBasicContactData: [DeviceContactStableId: DeviceContactBasicData] = [:]
    private var normalizedPhoneNumberToStableId: [DeviceContactNormalizedPhoneNumber: [DeviceContactStableId]] = [:]
    
    private var importableContacts: [DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData] = [:]
    
    private var accessDisposable: Disposable?
    private let dataDisposable = MetaDisposable()
    
    private let basicDataSubscribers = Bag<([DeviceContactStableId: DeviceContactBasicData]) -> Void>()
    private var basicDataForNormalizedNumberContexts: [DeviceContactNormalizedPhoneNumber: BasicDataForNormalizedNumberContext] = [:]
    private let importableContactsSubscribers = Bag<([DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData]) -> Void>()
    
    init(queue: Queue) {
        self.queue = queue
        self.accessDisposable = (DeviceAccess.contacts
        |> deliverOn(self.queue)).start(next: { [weak self] authorizationStatus in
            guard let strongSelf = self, let authorizationStatus = authorizationStatus else {
                return
            }
            strongSelf.accessInitialized = true
            if authorizationStatus {
                if #available(iOSApplicationExtension 9.0, *) {
                    strongSelf.dataContext = DeviceContactDataModernContext(queue: strongSelf.queue, updated: { stableIdToBasicContactData in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateAll(stableIdToBasicContactData)
                    })
                } else {
                    strongSelf.dataContext = DeviceContactDataLegacyContext(queue: strongSelf.queue, updated: { stableIdToBasicContactData in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateAll(stableIdToBasicContactData)
                    })
                }
                
                /*strongSelf.dataContext = DeviceContactDataLegacyContext(queue: strongSelf.queue, updated: { stableIdToBasicContactData in
                     guard let strongSelf = self else {
                         return
                     }
                     strongSelf.updateAll(stableIdToBasicContactData)
                 })*/
            } else {
                strongSelf.updateAll([:])
            }
        })
    }
    
    deinit {
        self.accessDisposable?.dispose()
    }
    
    private func updateAll(_ stableIdToBasicContactData: [DeviceContactStableId: DeviceContactBasicData]) {
        self.stableIdToBasicContactData = stableIdToBasicContactData
        var normalizedPhoneNumberToStableId: [DeviceContactNormalizedPhoneNumber: [DeviceContactStableId]] = [:]
        for (stableId, basicData) in self.stableIdToBasicContactData {
            for phoneNumber in basicData.phoneNumbers {
                let normalizedPhoneNumber = DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phoneNumber.value))
                if normalizedPhoneNumberToStableId[normalizedPhoneNumber] == nil {
                    normalizedPhoneNumberToStableId[normalizedPhoneNumber] = []
                }
                normalizedPhoneNumberToStableId[normalizedPhoneNumber]!.append(stableId)
            }
        }
        self.normalizedPhoneNumberToStableId = normalizedPhoneNumberToStableId
        for f in self.basicDataSubscribers.copyItems() {
            f(self.stableIdToBasicContactData)
        }
        
        for (normalizedNumber, context) in self.basicDataForNormalizedNumberContexts {
            var value: [(DeviceContactStableId, DeviceContactBasicData)] = []
            if let ids = self.normalizedPhoneNumberToStableId[normalizedNumber] {
                for id in ids {
                    if let basicData = self.stableIdToBasicContactData[id] {
                        value.append((id, basicData))
                    }
                }
            }
            
            var updated = false
            if value.count != context.value.count {
                updated = true
            } else {
                for i in 0 ..< value.count {
                    if value[i].0 != context.value[i].0 || value[i].1 != context.value[i].1 {
                        updated = true
                        break
                    }
                }
            }
            
            if updated {
                context.value = value
                for f in context.subscribers.copyItems() {
                    f(value)
                }
            }
        }
        
        var importableContactData: [String: (DeviceContactStableId, ImportableDeviceContactData)] = [:]
        for (stableId, basicData) in self.stableIdToBasicContactData {
            for phoneNumber in basicData.phoneNumbers {
                let normalizedNumber = phoneNumber.value
                var replace = false
                if let current = importableContactData[normalizedNumber] {
                    if stableId < current.0 {
                        replace = true
                    }
                } else {
                    replace = true
                }
                if replace {
                    importableContactData[normalizedNumber] = (stableId, ImportableDeviceContactData(firstName: basicData.firstName, lastName: basicData.lastName))
                }
            }
        }
        var importabledContacts: [DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData] = [:]
        for (number, data) in importableContactData {
            importabledContacts[DeviceContactNormalizedPhoneNumber(rawValue: number)] = data.1
        }
        self.importableContacts = importabledContacts
        for f in self.importableContactsSubscribers.copyItems() {
            f(importableContacts)
        }
    }
    
    func basicData(updated: @escaping ([DeviceContactStableId: DeviceContactBasicData]) -> Void) -> Disposable {
        let queue = self.queue
        
        let index = self.basicDataSubscribers.add({ data in
            updated(data)
        })
        
        updated(self.stableIdToBasicContactData)
        
        return ActionDisposable { [weak self] in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.basicDataSubscribers.remove(index)
            }
        }
    }
    
    func basicDataForNormalizedPhoneNumber(_ normalizedNumber: DeviceContactNormalizedPhoneNumber, updated: @escaping ([(DeviceContactStableId, DeviceContactBasicData)]) -> Void) -> Disposable {
        let queue = self.queue
        let context: BasicDataForNormalizedNumberContext
        if let current = self.basicDataForNormalizedNumberContexts[normalizedNumber] {
            context = current
        } else {
            var value: [(DeviceContactStableId, DeviceContactBasicData)] = []
            if let ids = self.normalizedPhoneNumberToStableId[normalizedNumber] {
                for id in ids {
                    if let basicData = self.stableIdToBasicContactData[id] {
                        value.append((id, basicData))
                    }
                }
            }
            context = BasicDataForNormalizedNumberContext(value: value)
            self.basicDataForNormalizedNumberContexts[normalizedNumber] = context
        }
        updated(context.value)
        let index = context.subscribers.add({ value in
            updated(value)
        })
        return ActionDisposable { [weak self, weak context] in
            queue.async {
                if let strongSelf = self, let foundContext = strongSelf.basicDataForNormalizedNumberContexts[normalizedNumber], foundContext === context {
                    foundContext.subscribers.remove(index)
                    if foundContext.subscribers.isEmpty {
                        strongSelf.basicDataForNormalizedNumberContexts.removeValue(forKey: normalizedNumber)
                    }
                }
            }
        }
    }
    
    func extendedData(stableId: String, updated: @escaping (DeviceContactExtendedData?) -> Void) -> Disposable {
        let queue = self.queue
        
        let current = self.dataContext?.getExtendedContactData(stableId: stableId)
        updated(current)
        
        return ActionDisposable { [weak self] in
            queue.async {
                
            }
        }
    }
    
    func importable(updated: @escaping ([DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData]) -> Void) -> Disposable {
        let queue = self.queue
        
        let index = self.importableContactsSubscribers.add({ data in
            updated(data)
        })
        if self.accessInitialized {
            updated(self.importableContacts)
        }
        
        return ActionDisposable { [weak self] in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.importableContactsSubscribers.remove(index)
            }
        }
    }
    
    func search(query: String, updated: @escaping ([DeviceContactStableId: DeviceContactBasicData]) -> Void) -> Disposable {
        let normalizedQuery = query.lowercased()
        var result: [DeviceContactStableId: DeviceContactBasicData] = [:]
        for (stableId, basicData) in self.stableIdToBasicContactData {
            if basicData.firstName.lowercased().hasPrefix(normalizedQuery) || basicData.lastName.lowercased().hasPrefix(normalizedQuery) {
                result[stableId] = basicData
            }
        }
        updated(result)
        return EmptyDisposable
    }
    
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId, completion: @escaping (DeviceContactExtendedData?) -> Void) {
        let result = self.dataContext?.appendContactData(contactData, to: stableId)
        completion(result)
    }
    
    func createContactWithData(_ contactData: DeviceContactExtendedData, completion: @escaping ((DeviceContactStableId, DeviceContactExtendedData)?) -> Void) {
        let result = self.dataContext?.createContactWithData(contactData)
        completion(result)
    }
}

public final class DeviceContactDataManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<DeviceContactDataManagerImpl>
    
    init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return DeviceContactDataManagerImpl(queue: queue)
        })
    }
    
    public func basicData() -> Signal<[DeviceContactStableId: DeviceContactBasicData], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                disposable.set(impl.basicData(updated: { value in
                    subscriber.putNext(value)
                }))
            })
            return disposable
        }
    }
    
    public func basicDataForNormalizedPhoneNumber(_ normalizedNumber: DeviceContactNormalizedPhoneNumber) -> Signal<[(DeviceContactStableId, DeviceContactBasicData)], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                disposable.set(impl.basicDataForNormalizedPhoneNumber(normalizedNumber, updated: { value in
                    subscriber.putNext(value)
                }))
            })
            return disposable
        }
    }
    
    public func extendedData(stableId: DeviceContactStableId) -> Signal<DeviceContactExtendedData?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                disposable.set(impl.extendedData(stableId: stableId, updated: { value in
                    subscriber.putNext(value)
                }))
            })
            return disposable
        }
    }
    
    public func importable() -> Signal<[DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                disposable.set(impl.importable(updated: { value in
                    subscriber.putNext(value)
                }))
            })
            return disposable
        }
    }
    
    public func search(query: String) -> Signal<[DeviceContactStableId: DeviceContactBasicData], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                disposable.set(impl.search(query: query, updated: { value in
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                }))
            })
            return disposable
        }
    }
    
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId) -> Signal<DeviceContactExtendedData?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                impl.appendContactData(contactData, to: stableId, completion: { next in
                    subscriber.putNext(next)
                    subscriber.putCompletion()
                })
            })
            return disposable
        }
    }
    
    func createContactWithData(_ contactData: DeviceContactExtendedData) -> Signal<(DeviceContactStableId, DeviceContactExtendedData)?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                impl.createContactWithData(contactData, completion: { next in
                    subscriber.putNext(next)
                    subscriber.putCompletion()
                })
            })
            return disposable
        }
    }
}
