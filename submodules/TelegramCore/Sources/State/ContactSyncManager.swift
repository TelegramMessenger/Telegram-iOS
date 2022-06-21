import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


private func normalizedPhoneNumber(_ value: String) -> String {
    var result = ""
    for c in value {
        if c.isNumber {
            result.append(c)
        }
    }
    return result
}

private final class ContactSyncOperation {
    let id: Int32
    var isRunning: Bool = false
    let content: ContactSyncOperationContent
    let disposable = DisposableSet()
    
    init(id: Int32, content: ContactSyncOperationContent) {
        self.id = id
        self.content = content
    }
}

private enum ContactSyncOperationContent {
    case waitForUpdatedState
    case updatePresences
    case sync(importableContacts: [DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData]?)
    case updateIsContact([(PeerId, Bool)])
}

private final class ContactSyncManagerImpl {
    private let queue: Queue
    private let postbox: Postbox
    private let network: Network
    private let accountPeerId: PeerId
    private let stateManager: AccountStateManager
    private var nextId: Int32 = 0
    private var operations: [ContactSyncOperation] = []
    
    private var lastContactPresencesRequestTimestamp: Double?
    private var reimportAttempts: [TelegramDeviceContactImportIdentifier: Double] = [:]
    
    private let importableContactsDisposable = MetaDisposable()
    private let significantStateUpdateCompletedDisposable = MetaDisposable()
    
    init(queue: Queue, postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
        self.stateManager = stateManager
    }
    
    deinit {
        self.importableContactsDisposable.dispose()
    }
    
    func beginSync(importableContacts: Signal<[DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData], NoError>) {
        self.importableContactsDisposable.set((importableContacts
        |> deliverOn(self.queue)).start(next: { [weak self] importableContacts in
            guard let strongSelf = self else {
                return
            }
            strongSelf.addOperation(.waitForUpdatedState)
            strongSelf.addOperation(.updatePresences)
            strongSelf.addOperation(.sync(importableContacts: importableContacts))
        }))
        self.significantStateUpdateCompletedDisposable.set((self.stateManager.significantStateUpdateCompleted
        |> deliverOn(self.queue)).start(next: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let timestamp = CFAbsoluteTimeGetCurrent()
            let shouldUpdate: Bool
            if let lastContactPresencesRequestTimestamp = strongSelf.lastContactPresencesRequestTimestamp {
                if timestamp > lastContactPresencesRequestTimestamp + 2.0 * 60.0 {
                    shouldUpdate = true
                } else {
                    shouldUpdate = false
                }
            } else {
                shouldUpdate = true
            }
            if shouldUpdate {
                strongSelf.lastContactPresencesRequestTimestamp = timestamp
                var found = false
                for operation in strongSelf.operations {
                    if case .updatePresences = operation.content {
                        found = true
                        break
                    }
                }
                if !found {
                    strongSelf.addOperation(.updatePresences)
                }
            }
        }))
    }
    
    func addIsContactUpdates(_ updates: [(PeerId, Bool)]) {
        self.addOperation(.updateIsContact(updates))
    }
    
    func addOperation(_ content: ContactSyncOperationContent) {
        let id = self.nextId
        self.nextId += 1
        let operation = ContactSyncOperation(id: id, content: content)
        switch content {
            case .waitForUpdatedState:
                self.operations.append(operation)
            case .updatePresences:
                for i in (0 ..< self.operations.count).reversed() {
                    if case .updatePresences = self.operations[i].content {
                        if !self.operations[i].isRunning {
                            self.operations.remove(at: i)
                        }
                    }
                }
                self.operations.append(operation)
            case .sync:
                for i in (0 ..< self.operations.count).reversed() {
                    if case .sync = self.operations[i].content {
                        if !self.operations[i].isRunning {
                            self.operations.remove(at: i)
                        }
                    }
                }
                self.operations.append(operation)
            case let .updateIsContact(updates):
                var mergedUpdates: [(PeerId, Bool)] = []
                var removeIndices: [Int] = []
                for i in 0 ..< self.operations.count {
                    if case let .updateIsContact(operationUpdates) = self.operations[i].content {
                        if !self.operations[i].isRunning {
                            mergedUpdates.append(contentsOf: operationUpdates)
                            removeIndices.append(i)
                        }
                    }
                }
                mergedUpdates.append(contentsOf: updates)
                for index in removeIndices.reversed() {
                    self.operations.remove(at: index)
                }
                if self.operations.isEmpty || !self.operations[0].isRunning {
                    self.operations.insert(operation, at: 0)
                } else {
                    self.operations.insert(operation, at: 1)
                }
        }
        self.updateOperations()
    }
    
    func updateOperations() {
        if let first = self.operations.first, !first.isRunning {
            first.isRunning = true
            let id = first.id
            let queue = self.queue
            self.startOperation(first.content, disposable: first.disposable, completion: { [weak self] in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    if let currentFirst = strongSelf.operations.first, currentFirst.id == id {
                        strongSelf.operations.remove(at: 0)
                        strongSelf.updateOperations()
                    } else {
                        assertionFailure()
                    }
                }
            })
        }
    }
    
    func startOperation(_ operation: ContactSyncOperationContent, disposable: DisposableSet, completion: @escaping () -> Void) {
        switch operation {
            case .waitForUpdatedState:
                disposable.add((self.stateManager.pollStateUpdateCompletion()
                |> deliverOn(self.queue)).start(next: { _ in
                    completion()
                }))
            case .updatePresences:
                disposable.add(updateContactPresences(postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId).start(completed: {
                    completion()
                }))
            case let .sync(importableContacts):
                let importSignal: Signal<PushDeviceContactsResult, NoError>
                if let importableContacts = importableContacts {
                    importSignal = pushDeviceContacts(postbox: self.postbox, network: self.network, importableContacts: importableContacts, reimportAttempts: self.reimportAttempts)
                } else {
                    importSignal = .single(PushDeviceContactsResult(addedReimportAttempts: [:]))
                }
                disposable.add(
                    (syncContactsOnce(network: self.network, postbox: self.postbox, accountPeerId: self.accountPeerId)
                    |> mapToSignal { _ -> Signal<PushDeviceContactsResult, NoError> in
                    }
                    |> then(importSignal)
                    |> deliverOn(self.queue)
                ).start(next: { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    for (identifier, timestamp) in result.addedReimportAttempts {
                        strongSelf.reimportAttempts[identifier] = timestamp
                    }
                    
                    completion()
                }))
            case let .updateIsContact(updates):
                disposable.add((self.postbox.transaction { transaction -> Void in
                    var contactPeerIds = transaction.getContactPeerIds()
                    for (peerId, isContact) in updates {
                        if isContact {
                            contactPeerIds.insert(peerId)
                        } else {
                            contactPeerIds.remove(peerId)
                        }
                    }
                    transaction.replaceContactPeerIds(contactPeerIds)
                }
                |> deliverOnMainQueue).start(completed: {
                    completion()
                }))
        }
    }
}

private struct PushDeviceContactsResult {
    let addedReimportAttempts: [TelegramDeviceContactImportIdentifier: Double]
}

private func pushDeviceContacts(postbox: Postbox, network: Network, importableContacts: [DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData], reimportAttempts: [TelegramDeviceContactImportIdentifier: Double]) -> Signal<PushDeviceContactsResult, NoError> {
    return postbox.transaction { transaction -> Signal<PushDeviceContactsResult, NoError> in
        var noLongerImportedIdentifiers = Set<TelegramDeviceContactImportIdentifier>()
        var updatedDataIdentifiers = Set<TelegramDeviceContactImportIdentifier>()
        var addedIdentifiers = Set<TelegramDeviceContactImportIdentifier>()
        var retryLaterIdentifiers = Set<TelegramDeviceContactImportIdentifier>()
        
        addedIdentifiers.formUnion(importableContacts.keys.map(TelegramDeviceContactImportIdentifier.phoneNumber))
        transaction.enumerateDeviceContactImportInfoItems({ key, value in
            if let identifier = TelegramDeviceContactImportIdentifier(key: key) {
                addedIdentifiers.remove(identifier)
                switch identifier {
                    case let .phoneNumber(number):
                        if let updatedData = importableContacts[number] {
                            if let value = value as? TelegramDeviceContactImportedData {
                                switch value {
                                    case let .imported(data, _):
                                        if data != updatedData {
                                           updatedDataIdentifiers.insert(identifier)
                                        }
                                    case .retryLater:
                                        retryLaterIdentifiers.insert(identifier)
                                }
                            } else {
                                assertionFailure()
                            }
                        } else {
                            noLongerImportedIdentifiers.insert(identifier)
                        }
                }
            } else {
                assertionFailure()
            }
            return true
        })
        
        for identifier in noLongerImportedIdentifiers {
            transaction.setDeviceContactImportInfo(identifier.key, value: nil)
        }
        
        var orderedPushIdentifiers: [TelegramDeviceContactImportIdentifier] = []
        orderedPushIdentifiers.append(contentsOf: addedIdentifiers.sorted())
        orderedPushIdentifiers.append(contentsOf: updatedDataIdentifiers.sorted())
        orderedPushIdentifiers.append(contentsOf: retryLaterIdentifiers.sorted())
        
        var currentContactDetails: [TelegramDeviceContactImportIdentifier: TelegramUser] = [:]
        for peerId in transaction.getContactPeerIds() {
            if let user = transaction.getPeer(peerId) as? TelegramUser, let phone = user.phone, !phone.isEmpty {
                currentContactDetails[.phoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: normalizedPhoneNumber(phone)))] = user
            }
        }
        
        let timestamp = CFAbsoluteTimeGetCurrent()
        outer: for i in (0 ..< orderedPushIdentifiers.count).reversed() {
            if let user = currentContactDetails[orderedPushIdentifiers[i]], case let .phoneNumber(number) = orderedPushIdentifiers[i], let data = importableContacts[number] {
                if (user.firstName ?? "") == data.firstName && (user.lastName ?? "") == data.lastName {
                    transaction.setDeviceContactImportInfo(orderedPushIdentifiers[i].key, value: TelegramDeviceContactImportedData.imported(data: data, importedByCount: 0))
                    orderedPushIdentifiers.remove(at: i)
                    continue outer
                }
            }
            
            if let attemptTimestamp = reimportAttempts[orderedPushIdentifiers[i]], attemptTimestamp + 60.0 * 60.0 * 24.0 > timestamp {
                orderedPushIdentifiers.remove(at: i)
            }
        }
        
        var preparedContactData: [(DeviceContactNormalizedPhoneNumber, ImportableDeviceContactData)] = []
        for identifier in orderedPushIdentifiers {
            if case let .phoneNumber(number) = identifier, let value = importableContacts[number] {
                preparedContactData.append((number, value))
            }
        }
        
        return pushDeviceContactData(postbox: postbox, network: network, contacts: preparedContactData)
    }
    |> switchToLatest
}

private let importBatchCount: Int = 500

private func pushDeviceContactData(postbox: Postbox, network: Network, contacts: [(DeviceContactNormalizedPhoneNumber, ImportableDeviceContactData)]) -> Signal<PushDeviceContactsResult, NoError> {
    var batches: Signal<PushDeviceContactsResult, NoError> = .single(PushDeviceContactsResult(addedReimportAttempts: [:]))
    for s in stride(from: 0, to: contacts.count, by: importBatchCount) {
        let batch = Array(contacts[s ..< min(s + importBatchCount, contacts.count)])
        batches = batches
        |> mapToSignal { intermediateResult -> Signal<PushDeviceContactsResult, NoError> in
            return network.request(Api.functions.contacts.importContacts(contacts: zip(0 ..< batch.count, batch).map { index, item -> Api.InputContact in
                return .inputPhoneContact(clientId: Int64(index), phone: item.0.rawValue, firstName: item.1.firstName, lastName: item.1.lastName)
            }))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.contacts.ImportedContacts?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<PushDeviceContactsResult, NoError> in
                return postbox.transaction { transaction -> PushDeviceContactsResult in
                    var addedReimportAttempts: [TelegramDeviceContactImportIdentifier: Double] = intermediateResult.addedReimportAttempts
                    if let result = result {
                        var addedContactPeerIds = Set<PeerId>()
                        var retryIndices = Set<Int>()
                        var importedCounts: [Int: Int32] = [:]
                        switch result {
                            case let .importedContacts(imported, popularInvites, retryContacts, users):
                                let peers = users.map { TelegramUser(user: $0) as Peer }
                                updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                                    return updated
                                })
                                for item in imported {
                                    switch item {
                                        case let .importedContact(userId, _):
                                            addedContactPeerIds.insert(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
                                    }
                                }
                                for item in retryContacts {
                                    retryIndices.insert(Int(item))
                                }
                                for item in popularInvites {
                                    switch item {
                                        case let .popularContact(clientId, importers):
                                            importedCounts[Int(clientId)] = importers
                                    }
                                }
                        }
                        let timestamp = CFAbsoluteTimeGetCurrent()
                        for i in 0 ..< batch.count {
                            let importedData: TelegramDeviceContactImportedData
                            if retryIndices.contains(i) {
                                importedData = .retryLater
                                addedReimportAttempts[.phoneNumber(batch[i].0)] = timestamp
                            } else {
                                importedData = .imported(data: batch[i].1, importedByCount: importedCounts[i] ?? 0)
                            }
                            transaction.setDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(batch[i].0).key, value: importedData)
                        }
                        var contactPeerIds = transaction.getContactPeerIds()
                        contactPeerIds.formUnion(addedContactPeerIds)
                        transaction.replaceContactPeerIds(contactPeerIds)
                    } else {
                        let timestamp = CFAbsoluteTimeGetCurrent()
                        for (number, _) in batch {
                            addedReimportAttempts[.phoneNumber(number)] = timestamp
                            transaction.setDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(number).key, value: TelegramDeviceContactImportedData.retryLater)
                        }
                    }
                    
                    return PushDeviceContactsResult(addedReimportAttempts: addedReimportAttempts)
                }
            }
        }
    }
    return batches
}

private func updateContactPresences(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Never, NoError> {
    return network.request(Api.functions.contacts.getStatuses())
    |> `catch` { _ -> Signal<[Api.ContactStatus], NoError> in
        return .single([])
    }
    |> mapToSignal { statuses -> Signal<Never, NoError> in
        return postbox.transaction { transaction -> Void in
            var peerPresences: [PeerId: PeerPresence] = [:]
            for status in statuses {
                switch status {
                    case let .contactStatus(userId, status):
                        peerPresences[PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))] = TelegramUserPresence(apiStatus: status)
                }
            }
            updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
        }
        |> ignoreValues
    }
}

final class ContactSyncManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<ContactSyncManagerImpl>
    
    init(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ContactSyncManagerImpl(queue: queue, postbox: postbox, network: network, accountPeerId: accountPeerId, stateManager: stateManager)
        })
    }
    
    func beginSync(importableContacts: Signal<[DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData], NoError>) {
        self.impl.with { impl in
            impl.beginSync(importableContacts: importableContacts)
        }
    }
    
    func addIsContactUpdates(_ updates: [(PeerId, Bool)]) {
        self.impl.with { impl in
            impl.addIsContactUpdates(updates)
        }
    }
}
