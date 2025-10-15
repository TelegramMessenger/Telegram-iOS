import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Contacts
import TelegramUIPreferences
import DeviceAccess
import AccountContext
import PhoneNumberFormat
import ContactsHelper
import AccountContext

private protocol DeviceContactDataContext {
    func personNameDisplayOrder() -> PresentationPersonNameOrder
    func getExtendedContactData(stableId: DeviceContactStableId) -> DeviceContactExtendedData?
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId) -> DeviceContactExtendedData?
    func appendPhoneNumber(_ phoneNumber: DeviceContactPhoneNumberData, to stableId: DeviceContactStableId) -> DeviceContactExtendedData?
    func createContactWithData(_ contactData: DeviceContactExtendedData) -> (DeviceContactStableId, DeviceContactExtendedData)?
    func deleteContactWithAppSpecificReference(peerId: PeerId)
}

private final class DeviceContactDataModernContext: DeviceContactDataContext {
    let queue: Queue
    let accountManager: AccountManager<TelegramAccountManagerTypes>
    let store = CNContactStore()
    var updateHandle: NSObjectProtocol?
    var currentContacts: [DeviceContactStableId: DeviceContactBasicData] = [:]
    var currentAppSpecificReferences: [PeerId: DeviceContactBasicDataWithReference] = [:]
    
    private var retrieveContactsDisposable: Disposable?
    
    init(queue: Queue, accountManager: AccountManager<TelegramAccountManagerTypes>, updated: @escaping ([DeviceContactStableId: DeviceContactBasicData]) -> Void, appSpecificReferencesUpdated: @escaping ([PeerId: DeviceContactBasicDataWithReference]) -> Void) {
        self.queue = queue
        self.accountManager = accountManager
        
        self.retrieveContactsDisposable?.dispose()
        self.retrieveContactsDisposable = (self.retrieveContacts()
        |> deliverOn(self.queue)).startStrict(next: { [weak self] contacts, references in
            guard let self else {
                return
            }
            
            self.currentContacts = contacts
            self.currentAppSpecificReferences = references
            updated(self.currentContacts)
            appSpecificReferencesUpdated(self.currentAppSpecificReferences)
            let handle = NotificationCenter.default.addObserver(forName: NSNotification.Name.CNContactStoreDidChange, object: nil, queue: nil, using: { [weak self] _ in
                queue.async {
                    guard let self else {
                        return
                    }
                    self.retrieveContactsDisposable?.dispose()
                    self.retrieveContactsDisposable = (self.retrieveContacts()
                    |> deliverOn(self.queue)).startStrict(next: { [weak self] contacts, references in
                        guard let self else {
                            return
                        }
                        
                        if self.currentContacts != contacts {
                            self.currentContacts = contacts
                            updated(self.currentContacts)
                        }
                        if self.currentAppSpecificReferences != references {
                            self.currentAppSpecificReferences = references
                            appSpecificReferencesUpdated(self.currentAppSpecificReferences)
                        }
                    })
                }
            })
            self.updateHandle = handle
        })
    }
    
    deinit {
        self.retrieveContactsDisposable?.dispose()
        if let updateHandle = self.updateHandle {
            NotificationCenter.default.removeObserver(updateHandle)
        }
    }
    
    private func retrieveContacts() -> Signal<([DeviceContactStableId: DeviceContactBasicData], [PeerId: DeviceContactBasicDataWithReference]), NoError> {
        return self.accountManager.transaction { transaction -> DeviceContactDataState? in
            return transaction.getSharedData(SharedDataKeys.deviceContacts)?.get(DeviceContactDataState.self)
        }
        |> deliverOn(self.queue)
        |> map { currentData -> ([DeviceContactStableId: DeviceContactBasicData], [PeerId: DeviceContactBasicDataWithReference]) in
            if let currentData, let stateToken = currentData.stateToken, !sharedDisableDeviceContactDataDiffing {
                final class ChangeVisitor: NSObject, CNChangeHistoryEventVisitor {
                    let onDropEverything: () -> Void
                    let onAdd: (CNContact) -> Void
                    let onUpdate: (CNContact) -> Void
                    let onDelete: (String) -> Void
                    
                    init(onDropEverything: @escaping () -> Void, onAdd: @escaping (CNContact) -> Void, onUpdate: @escaping (CNContact) -> Void, onDelete: @escaping (String) -> Void) {
                        self.onDropEverything = onDropEverything
                        self.onAdd = onAdd
                        self.onUpdate = onUpdate
                        self.onDelete = onDelete
                        
                        super.init()
                    }
                    
                    func visit(_ event: CNChangeHistoryDropEverythingEvent) {
                        self.onDropEverything()
                    }
                    
                    func visit(_ event: CNChangeHistoryAddContactEvent) {
                        self.onAdd(event.contact)
                    }
                    
                    func visit(_ event: CNChangeHistoryUpdateContactEvent) {
                        self.onUpdate(event.contact)
                    }
                    
                    func visit(_ event: CNChangeHistoryDeleteContactEvent) {
                        self.onDelete(event.contactIdentifier)
                    }
                }
                
                let changeRequest = CNChangeHistoryFetchRequest()
                changeRequest.startingToken = stateToken
                changeRequest.additionalContactKeyDescriptors = [
                    CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                    CNContactUrlAddressesKey as CNKeyDescriptor
                ]
                
                var contacts: [DeviceContactStableId: DeviceContactBasicData] = currentData.contacts
                var telegramReferences: [PeerId: String] = currentData.telegramReferences
                var reverseTelegramReferences: [String: Set<PeerId>] = [:]
                for (peerId, id) in telegramReferences {
                    if reverseTelegramReferences[id] == nil {
                        reverseTelegramReferences[id] = Set()
                    }
                    reverseTelegramReferences[id]?.insert(peerId)
                }
                
                let visitor = ChangeVisitor(
                    onDropEverything: {
                        contacts.removeAll()
                        telegramReferences.removeAll()
                        reverseTelegramReferences.removeAll()
                    },
                    onAdd: { contact in
                        let stableIdAndContact = DeviceContactDataModernContext.parseContact(contact)
                        contacts[stableIdAndContact.0] = stableIdAndContact.1
                        for address in contact.urlAddresses {
                            if address.label == "Telegram", let peerId = parseAppSpecificContactReference(address.value as String) {
                                telegramReferences[peerId] = stableIdAndContact.0
                                if reverseTelegramReferences[stableIdAndContact.0] == nil {
                                    reverseTelegramReferences[stableIdAndContact.0] = Set()
                                }
                                reverseTelegramReferences[stableIdAndContact.0]?.insert(peerId)
                            }
                        }
                    },
                    onUpdate: { contact in
                        let stableIdAndContact = DeviceContactDataModernContext.parseContact(contact)
                        contacts[stableIdAndContact.0] = stableIdAndContact.1
                        for address in contact.urlAddresses {
                            if address.label == "Telegram", let peerId = parseAppSpecificContactReference(address.value as String) {
                                telegramReferences[peerId] = stableIdAndContact.0
                                telegramReferences[peerId] = stableIdAndContact.0
                                if reverseTelegramReferences[stableIdAndContact.0] == nil {
                                    reverseTelegramReferences[stableIdAndContact.0] = Set()
                                }
                                reverseTelegramReferences[stableIdAndContact.0]?.insert(peerId)
                            }
                        }
                    },
                    onDelete: { contactId in
                        contacts.removeValue(forKey: contactId)
                        if let peerIds = reverseTelegramReferences[contactId] {
                            for peerId in peerIds {
                                telegramReferences.removeValue(forKey: peerId)
                            }
                            reverseTelegramReferences.removeValue(forKey: contactId)
                        }
                    }
                )
                
                let resultState = ContactsEnumerateChangeRequest(self.store, changeRequest, visitor)
                
                let _ = self.accountManager.transaction({ transaction -> Void in
                    transaction.updateSharedData(SharedDataKeys.deviceContacts, { _ in
                        return PreferencesEntry(DeviceContactDataState(
                            contacts: contacts, telegramReferences: telegramReferences, stateToken: resultState?.stateToken))
                    })
                }).startStandalone()
                
                var references: [PeerId: DeviceContactBasicDataWithReference] = [:]
                for (peerId, id) in telegramReferences {
                    if let basicData = contacts[id] {
                        references[peerId] = DeviceContactBasicDataWithReference(stableId: id, basicData: basicData)
                    }
                }
                
                return (contacts, references)
            } else {
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                    CNContactPhoneNumbersKey as CNKeyDescriptor,
                    CNContactUrlAddressesKey as CNKeyDescriptor
                ]
                
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                request.unifyResults = true
                
                var contacts: [String: DeviceContactBasicData] = [:]
                var telegramReferences: [EnginePeer.Id: String] = [:]
                let resultState = ContactsEnumerateRequest(self.store, request, { contact in
                    let stableIdAndContact = DeviceContactDataModernContext.parseContact(contact)
                    contacts[stableIdAndContact.0] = stableIdAndContact.1
                    for address in contact.urlAddresses {
                        if address.label == "Telegram", let peerId = parseAppSpecificContactReference(address.value as String) {
                            telegramReferences[peerId] = stableIdAndContact.0
                        }
                    }
                })
                
                let _ = self.accountManager.transaction({ transaction -> Void in
                    transaction.updateSharedData(SharedDataKeys.deviceContacts, { _ in
                        return PreferencesEntry(DeviceContactDataState(
                            contacts: contacts, telegramReferences: telegramReferences, stateToken: resultState?.stateToken))
                    })
                }).startStandalone()
                
                var references: [PeerId: DeviceContactBasicDataWithReference] = [:]
                for (peerId, id) in telegramReferences {
                    if let basicData = contacts[id] {
                        references[peerId] = DeviceContactBasicDataWithReference(stableId: id, basicData: basicData)
                    }
                }
                
                return (contacts, references)
            }
        }
    }
    
    private static func parseContact(_ contact: CNContact) -> (DeviceContactStableId, DeviceContactBasicData) {
        var phoneNumbers: [DeviceContactPhoneNumberData] = []
        for number in contact.phoneNumbers {
            phoneNumbers.append(DeviceContactPhoneNumberData(label: number.label ?? "", value: number.value.stringValue))
        }
        return (contact.identifier, DeviceContactBasicData(firstName: contact.givenName, lastName: contact.familyName, phoneNumbers: phoneNumbers))
    }
    
    func personNameDisplayOrder() -> PresentationPersonNameOrder {
        switch CNContactFormatter.nameOrder(for: CNContact()) {
            case .givenNameFirst:
                return .firstLast
            default:
                return .lastFirst
        }
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
    
    func appendPhoneNumber(_ phoneNumber: DeviceContactPhoneNumberData, to stableId: DeviceContactStableId) -> DeviceContactExtendedData? {
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
        
        let mutableContact = current.mutableCopy() as! CNMutableContact
        
        var phoneNumbers = mutableContact.phoneNumbers
        let appendPhoneNumbers: [CNLabeledValue<CNPhoneNumber>] = [CNLabeledValue<CNPhoneNumber>(label: phoneNumber.label, value: CNPhoneNumber(stringValue: phoneNumber.value))]
        for appendPhoneNumber in appendPhoneNumbers {
            var found = false
            inner: for n in phoneNumbers {
                if n.value.stringValue == appendPhoneNumber.value.stringValue {
                    found = true
                    break inner
                }
            }
            if !found {
                phoneNumbers.insert(appendPhoneNumber, at: 0)
            }
        }
        mutableContact.phoneNumbers = phoneNumbers
        
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
    
    func deleteContactWithAppSpecificReference(peerId: PeerId) {
        guard let reference = self.currentAppSpecificReferences[peerId] else {
            return
        }
        guard let current = try? self.store.unifiedContact(withIdentifier: reference.stableId, keysToFetch: []) else {
            return
        }
        
        let saveRequest = CNSaveRequest()
            saveRequest.delete(current.mutableCopy() as! CNMutableContact)
        let _ = try? self.store.execute(saveRequest)
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

private final class DeviceContactDataManagerPrivateImpl {
    private let queue: Queue
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    
    private var accessInitialized = false
    
    private var dataContext: DeviceContactDataContext?
    let personNameDisplayOrder = ValuePromise<PresentationPersonNameOrder>()
    private var extendedContexts: [DeviceContactStableId: ExtendedContactDataContext] = [:]
    
    private var stableIdToBasicContactData: [DeviceContactStableId: DeviceContactBasicData] = [:]
    private var normalizedPhoneNumberToStableId: [DeviceContactNormalizedPhoneNumber: [DeviceContactStableId]] = [:]
    private var appSpecificReferences: [PeerId: DeviceContactBasicDataWithReference] = [:]
    private var stableIdToAppSpecificReference: [DeviceContactStableId: PeerId] = [:]
    
    private var importableContacts: [DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData] = [:]
    
    private var accessDisposable: Disposable?
    private let dataDisposable = MetaDisposable()
    
    private let basicDataSubscribers = Bag<([DeviceContactStableId: DeviceContactBasicData]) -> Void>()
    private var basicDataForNormalizedNumberContexts: [DeviceContactNormalizedPhoneNumber: BasicDataForNormalizedNumberContext] = [:]
    private let importableContactsSubscribers = Bag<([DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData]) -> Void>()
    private let appSpecificReferencesSubscribers = Bag<([PeerId: DeviceContactBasicDataWithReference]) -> Void>()
    
    init(queue: Queue, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.queue = queue
        self.accountManager = accountManager
        self.accessDisposable = (DeviceAccess.authorizationStatus(subject: .contacts)
        |> delay(2.0, queue: .mainQueue())
        |> deliverOn(self.queue)).startStrict(next: { [weak self] authorizationStatus in
            guard let strongSelf = self, authorizationStatus != .notDetermined else {
                return
            }
            strongSelf.accessInitialized = true
            if authorizationStatus == .allowed {
                let dataContext = DeviceContactDataModernContext(queue: strongSelf.queue, accountManager: strongSelf.accountManager, updated: { stableIdToBasicContactData in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateAll(stableIdToBasicContactData)
                }, appSpecificReferencesUpdated: { appSpecificReferences in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateAppSpecificReferences(appSpecificReferences: appSpecificReferences)
                })
                strongSelf.dataContext = dataContext
                strongSelf.personNameDisplayOrder.set(dataContext.personNameDisplayOrder())
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
                var replace = false
                var currentLocalIdentifiers: [String] = []
                if let current = importableContactData[phoneNumber.value] {
                    if stableId < current.0 {
                        replace = true
                        currentLocalIdentifiers = current.1.localIdentifiers
                    }
                } else {
                    replace = true
                }
                if replace {
                    if !currentLocalIdentifiers.contains(stableId) {
                        currentLocalIdentifiers.append(stableId)
                    }
                    importableContactData[phoneNumber.value] = (stableId, ImportableDeviceContactData(firstName: basicData.firstName, lastName: basicData.lastName, localIdentifiers: currentLocalIdentifiers))
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
    
    private func updateAppSpecificReferences(appSpecificReferences: [PeerId: DeviceContactBasicDataWithReference]) {
        self.appSpecificReferences = appSpecificReferences
        var stableIdToAppSpecificReference: [DeviceContactStableId: PeerId] = [:]
        for (peerId, value) in appSpecificReferences {
            stableIdToAppSpecificReference[value.stableId] = peerId
        }
        self.stableIdToAppSpecificReference = stableIdToAppSpecificReference
        for f in self.appSpecificReferencesSubscribers.copyItems() {
            f(appSpecificReferences)
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
        let current = self.dataContext?.getExtendedContactData(stableId: stableId)
        updated(current)
        
        return ActionDisposable {
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
    
    func appSpecificReferences(updated: @escaping ([PeerId: DeviceContactBasicDataWithReference]) -> Void) -> Disposable {
        let queue = self.queue
        
        let index = self.appSpecificReferencesSubscribers.add({ data in
            updated(data)
        })
        if self.accessInitialized {
            updated(self.appSpecificReferences)
        }
        
        return ActionDisposable { [weak self] in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.appSpecificReferencesSubscribers.remove(index)
            }
        }
    }
    
    func search(query: String, updated: @escaping ([DeviceContactStableId: (DeviceContactBasicData, PeerId?)]) -> Void) -> Disposable {
        let normalizedQuery = query.lowercased()
        var result: [DeviceContactStableId: (DeviceContactBasicData, PeerId?)] = [:]
        for (stableId, basicData) in self.stableIdToBasicContactData {
            if basicData.firstName.lowercased().hasPrefix(normalizedQuery) || basicData.lastName.lowercased().hasPrefix(normalizedQuery) {
                result[stableId] = (basicData, self.stableIdToAppSpecificReference[stableId])
            }
        }
        updated(result)
        return EmptyDisposable
    }
    
    func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId, completion: @escaping (DeviceContactExtendedData?) -> Void) {
        let result = self.dataContext?.appendContactData(contactData, to: stableId)
        completion(result)
    }
    
    func appendPhoneNumber(_ phoneNumber: DeviceContactPhoneNumberData, to stableId: DeviceContactStableId, completion: @escaping (DeviceContactExtendedData?) -> Void) {
        let result = self.dataContext?.appendPhoneNumber(phoneNumber, to: stableId)
        completion(result)
    }
    
    func createContactWithData(_ contactData: DeviceContactExtendedData, completion: @escaping ((DeviceContactStableId, DeviceContactExtendedData)?) -> Void) {
        let result = self.dataContext?.createContactWithData(contactData)
        completion(result)
    }
    
    func deleteContactWithAppSpecificReference(peerId: PeerId, completion: @escaping () -> Void) {
        self.dataContext?.deleteContactWithAppSpecificReference(peerId: peerId)
        completion()
    }
}

public final class DeviceContactDataManagerImpl: DeviceContactDataManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<DeviceContactDataManagerPrivateImpl>
    
    init(accountManager: AccountManager<TelegramAccountManagerTypes>) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return DeviceContactDataManagerPrivateImpl(queue: queue, accountManager: accountManager)
        })
    }
    
    public func personNameDisplayOrder() -> Signal<PresentationPersonNameOrder, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                disposable.set(impl.personNameDisplayOrder.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            })
            return disposable
        }
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
    
    public func appSpecificReferences() -> Signal<[PeerId: DeviceContactBasicDataWithReference], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                disposable.set(impl.appSpecificReferences(updated: { value in
                    subscriber.putNext(value)
                }))
            })
            return disposable
        }
    }
    
    public func search(query: String) -> Signal<[DeviceContactStableId: (DeviceContactBasicData, PeerId?)], NoError> {
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
    
    public func appendContactData(_ contactData: DeviceContactExtendedData, to stableId: DeviceContactStableId) -> Signal<DeviceContactExtendedData?, NoError> {
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
    
    public func appendPhoneNumber(_ phoneNumber: DeviceContactPhoneNumberData, to stableId: DeviceContactStableId) -> Signal<DeviceContactExtendedData?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                impl.appendPhoneNumber(phoneNumber, to: stableId, completion: { next in
                    subscriber.putNext(next)
                    subscriber.putCompletion()
                })
            })
            return disposable
        }
    }
    
    public func createContactWithData(_ contactData: DeviceContactExtendedData) -> Signal<(DeviceContactStableId, DeviceContactExtendedData)?, NoError> {
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
    
    public func deleteContactWithAppSpecificReference(peerId: PeerId) -> Signal<Never, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with({ impl in
                impl.deleteContactWithAppSpecificReference(peerId: peerId, completion: {
                    subscriber.putCompletion()
                })
            })
            return disposable
        }
    }
}
