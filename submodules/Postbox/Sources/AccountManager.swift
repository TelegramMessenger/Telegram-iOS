import Foundation
import SwiftSignalKit

public struct AccountManagerModifier {
    public let getRecords: () -> [AccountRecord]
    public let updateRecord: (AccountRecordId, (AccountRecord?) -> (AccountRecord?)) -> Void
    public let getCurrent: () -> (AccountRecordId, [AccountRecordAttribute])?
    public let setCurrentId: (AccountRecordId) -> Void
    public let getCurrentAuth: () -> AuthAccountRecord?
    public let createAuth: ([AccountRecordAttribute]) -> AuthAccountRecord?
    public let removeAuth: () -> Void
    public let createRecord: ([AccountRecordAttribute]) -> AccountRecordId
    public let getSharedData: (ValueBoxKey) -> PreferencesEntry?
    public let updateSharedData: (ValueBoxKey, (PreferencesEntry?) -> PreferencesEntry?) -> Void
    public let getAccessChallengeData: () -> PostboxAccessChallengeData
    public let setAccessChallengeData: (PostboxAccessChallengeData) -> Void
    public let getVersion: () -> Int32?
    public let setVersion: (Int32) -> Void
    public let getNotice: (NoticeEntryKey) -> NoticeEntry?
    public let setNotice: (NoticeEntryKey, NoticeEntry?) -> Void
    public let clearNotices: () -> Void
}

final class AccountManagerImpl {
    private let queue: Queue
    private let basePath: String
    private let atomicStatePath: String
    private let temporarySessionId: Int64
    private let guardValueBox: ValueBox?
    private let valueBox: ValueBox
    
    private var tables: [Table] = []
    
    private var currentAtomicState: AccountManagerAtomicState
    private var currentAtomicStateUpdated = false
    
    private let legacyMetadataTable: AccountManagerMetadataTable
    private let legacyRecordTable: AccountManagerRecordTable
    
    let sharedDataTable: AccountManagerSharedDataTable
    let noticeTable: NoticeTable
    
    private var currentRecordOperations: [AccountManagerRecordOperation] = []
    private var currentMetadataOperations: [AccountManagerMetadataOperation] = []
    
    private var currentUpdatedSharedDataKeys = Set<ValueBoxKey>()
    private var currentUpdatedNoticeEntryKeys = Set<NoticeEntryKey>()
    private var currentUpdatedAccessChallengeData: PostboxAccessChallengeData?
    
    private var recordsViews = Bag<(MutableAccountRecordsView, ValuePipe<AccountRecordsView>)>()
    
    private var sharedDataViews = Bag<(MutableAccountSharedDataView, ValuePipe<AccountSharedDataView>)>()
    private var noticeEntryViews = Bag<(MutableNoticeEntryView, ValuePipe<NoticeEntryView>)>()
    private var accessChallengeDataViews = Bag<(MutableAccessChallengeDataView, ValuePipe<AccessChallengeDataView>)>()
    
    fileprivate init(queue: Queue, basePath: String, temporarySessionId: Int64) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        self.queue = queue
        self.basePath = basePath
        self.atomicStatePath = "\(basePath)/atomic-state"
        self.temporarySessionId = temporarySessionId
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
        self.guardValueBox = SqliteValueBox(basePath: basePath + "/guard_db", queue: queue, encryptionParameters: nil, upgradeProgress: { _ in })
        self.valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, encryptionParameters: nil, upgradeProgress: { _ in })
        
        self.legacyMetadataTable = AccountManagerMetadataTable(valueBox: self.valueBox, table: AccountManagerMetadataTable.tableSpec(0))
        self.legacyRecordTable = AccountManagerRecordTable(valueBox: self.valueBox, table: AccountManagerRecordTable.tableSpec(1))
        self.sharedDataTable = AccountManagerSharedDataTable(valueBox: self.valueBox, table: AccountManagerSharedDataTable.tableSpec(2))
        self.noticeTable = NoticeTable(valueBox: self.valueBox, table: NoticeTable.tableSpec(3))
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: self.atomicStatePath))
            do {
                
                let atomicState = try JSONDecoder().decode(AccountManagerAtomicState.self, from: data)
                self.currentAtomicState = atomicState
            } catch let e {
                postboxLog("decode atomic state error: \(e)")
                let _ = try? FileManager.default.removeItem(atPath: self.atomicStatePath)
                preconditionFailure()
            }
        } catch let e {
            postboxLog("load atomic state error: \(e)")
            var legacyRecordDict: [AccountRecordId: AccountRecord] = [:]
            for record in self.legacyRecordTable.getRecords() {
                legacyRecordDict[record.id] = record
            }
            self.currentAtomicState = AccountManagerAtomicState(records: legacyRecordDict, currentRecordId: self.legacyMetadataTable.getCurrentAccountId(), currentAuthRecord: self.legacyMetadataTable.getCurrentAuthAccount())
            self.syncAtomicStateToFile()
        }
        
        postboxLog("AccountManager: currentAccountId = \(String(describing: currentAtomicState.currentRecordId))")
        
        self.tables.append(self.legacyMetadataTable)
        self.tables.append(self.legacyRecordTable)
        self.tables.append(self.sharedDataTable)
        self.tables.append(self.noticeTable)
        
        print("AccountManager initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    fileprivate func transaction<T>(ignoreDisabled: Bool, _ f: @escaping (AccountManagerModifier) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.justDispatch {
                self.valueBox.begin()
                
                let transaction = AccountManagerModifier(getRecords: {
                    return self.currentAtomicState.records.map { $0.1 }
                }, updateRecord: { id, update in
                    let current = self.currentAtomicState.records[id]
                    let updated = update(current)
                    if updated != current {
                        if let updated = updated {
                            self.currentAtomicState.records[id] = updated
                        } else {
                            self.currentAtomicState.records.removeValue(forKey: id)
                        }
                        self.currentAtomicStateUpdated = true
                        self.currentRecordOperations.append(.set(id: id, record: updated))
                    }
                }, getCurrent: {
                    if let id = self.currentAtomicState.currentRecordId, let record = self.currentAtomicState.records[id] {
                        return (record.id, record.attributes)
                    } else {
                        return nil
                    }
                }, setCurrentId: { id in
                    self.currentAtomicState.currentRecordId = id
                    self.currentMetadataOperations.append(.updateCurrentAccountId(id))
                    self.currentAtomicStateUpdated = true
                }, getCurrentAuth: {
                    if let record = self.currentAtomicState.currentAuthRecord {
                        return record
                    } else {
                        return nil
                    }
                }, createAuth: { attributes in
                    let record = AuthAccountRecord(id: generateAccountRecordId(), attributes: attributes)
                    self.currentAtomicState.currentAuthRecord = record
                    self.currentAtomicStateUpdated = true
                    self.currentMetadataOperations.append(.updateCurrentAuthAccountRecord(record))
                    return record
                }, removeAuth: {
                    self.currentAtomicState.currentAuthRecord = nil
                    self.currentMetadataOperations.append(.updateCurrentAuthAccountRecord(nil))
                    self.currentAtomicStateUpdated = true
                }, createRecord: { attributes in
                    let id = generateAccountRecordId()
                    let record = AccountRecord(id: id, attributes: attributes, temporarySessionId: nil)
                    self.currentAtomicState.records[id] = record
                    self.currentRecordOperations.append(.set(id: id, record: record))
                    self.currentAtomicStateUpdated = true
                    return id
                }, getSharedData: { key in
                    return self.sharedDataTable.get(key: key)
                }, updateSharedData: { key, f in
                    let updated = f(self.sharedDataTable.get(key: key))
                    self.sharedDataTable.set(key: key, value: updated, updatedKeys: &self.currentUpdatedSharedDataKeys)
                }, getAccessChallengeData: {
                    return self.legacyMetadataTable.getAccessChallengeData()
                }, setAccessChallengeData: { data in
                    self.currentUpdatedAccessChallengeData = data
                    self.legacyMetadataTable.setAccessChallengeData(data)
                }, getVersion: {
                    return self.legacyMetadataTable.getVersion()
                }, setVersion: { version in
                    self.legacyMetadataTable.setVersion(version)
                }, getNotice: { key in
                    self.noticeTable.get(key: key)
                }, setNotice: { key, value in
                    self.noticeTable.set(key: key, value: value)
                    self.currentUpdatedNoticeEntryKeys.insert(key)
                }, clearNotices: {
                    self.noticeTable.clear()
                })
                
                let result = f(transaction)
               
                self.beforeCommit()
                
                self.valueBox.commit()
                //self.valueBox.checkpoint()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    private func syncAtomicStateToFile() {
        if let data = try? JSONEncoder().encode(self.currentAtomicState) {
            if let _ = try? data.write(to: URL(fileURLWithPath: self.atomicStatePath), options: [.atomic]) {
            } else {
                preconditionFailure()
            }
        } else {
            preconditionFailure()
        }
    }
    
    private func beforeCommit() {
        if self.currentAtomicStateUpdated {
            self.syncAtomicStateToFile()
        }
        
        if !self.currentRecordOperations.isEmpty || !self.currentMetadataOperations.isEmpty {
            for (view, pipe) in self.recordsViews.copyItems() {
                if view.replay(operations: self.currentRecordOperations, metadataOperations: self.currentMetadataOperations) {
                    pipe.putNext(AccountRecordsView(view))
                }
            }
        }
        
        if !self.currentUpdatedSharedDataKeys.isEmpty {
            for (view, pipe) in self.sharedDataViews.copyItems() {
                if view.replay(accountManagerImpl: self, updatedKeys: self.currentUpdatedSharedDataKeys) {
                    pipe.putNext(AccountSharedDataView(view))
                }
            }
        }
        
        if !self.currentUpdatedNoticeEntryKeys.isEmpty {
            for (view, pipe) in self.noticeEntryViews.copyItems() {
                if view.replay(accountManagerImpl: self, updatedKeys: self.currentUpdatedNoticeEntryKeys) {
                    pipe.putNext(NoticeEntryView(view))
                }
            }
        }
        
        if let data = self.currentUpdatedAccessChallengeData {
            for (view, pipe) in self.accessChallengeDataViews.copyItems() {
                if view.replay(updatedData: data) {
                    pipe.putNext(AccessChallengeDataView(view))
                }
            }
        }
        
        self.currentRecordOperations.removeAll()
        self.currentMetadataOperations.removeAll()
        self.currentUpdatedSharedDataKeys.removeAll()
        self.currentUpdatedNoticeEntryKeys.removeAll()
        self.currentUpdatedAccessChallengeData = nil
        self.currentAtomicStateUpdated = false
        
        for table in self.tables {
            table.beforeCommit()
        }
    }
    
    fileprivate func accountRecords() -> Signal<AccountRecordsView, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccountRecordsView, NoError> in
            return self.accountRecordsInternal(transaction: transaction)
        })
        |> switchToLatest
    }
    
    fileprivate func sharedData(keys: Set<ValueBoxKey>) -> Signal<AccountSharedDataView, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccountSharedDataView, NoError> in
            return self.sharedDataInternal(transaction: transaction, keys: keys)
        })
        |> switchToLatest
    }
    
    fileprivate func noticeEntry(key: NoticeEntryKey) -> Signal<NoticeEntryView, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<NoticeEntryView, NoError> in
            return self.noticeEntryInternal(transaction: transaction, key: key)
        })
        |> switchToLatest
    }
    
    fileprivate func accessChallengeData() -> Signal<AccessChallengeDataView, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccessChallengeDataView, NoError> in
            return self.accessChallengeDataInternal(transaction: transaction)
        })
        |> switchToLatest
    }
    
    private func accountRecordsInternal(transaction: AccountManagerModifier) -> Signal<AccountRecordsView, NoError> {
        assert(self.queue.isCurrent())
        let mutableView = MutableAccountRecordsView(getRecords: {
            return self.currentAtomicState.records.map { $0.1 }
        }, currentId: self.currentAtomicState.currentRecordId, currentAuth: self.currentAtomicState.currentAuthRecord)
        let pipe = ValuePipe<AccountRecordsView>()
        let index = self.recordsViews.add((mutableView, pipe))
        
        let queue = self.queue
        return (.single(AccountRecordsView(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<AccountRecordsView, NoError> in
            return .complete()
        }
        |> afterDisposed { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.recordsViews.remove(index)
                }
            }
        }
    }
    
    private func sharedDataInternal(transaction: AccountManagerModifier, keys: Set<ValueBoxKey>) -> Signal<AccountSharedDataView, NoError> {
        let mutableView = MutableAccountSharedDataView(accountManagerImpl: self, keys: keys)
        let pipe = ValuePipe<AccountSharedDataView>()
        let index = self.sharedDataViews.add((mutableView, pipe))
        
        let queue = self.queue
        return (.single(AccountSharedDataView(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<AccountSharedDataView, NoError> in
            return .complete()
        }
        |> afterDisposed { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.sharedDataViews.remove(index)
                }
            }
        }
    }
    
    private func noticeEntryInternal(transaction: AccountManagerModifier, key: NoticeEntryKey) -> Signal<NoticeEntryView, NoError> {
        let mutableView = MutableNoticeEntryView(accountManagerImpl: self, key: key)
        let pipe = ValuePipe<NoticeEntryView>()
        let index = self.noticeEntryViews.add((mutableView, pipe))
        
        let queue = self.queue
        return (.single(NoticeEntryView(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<NoticeEntryView, NoError> in
            return .complete()
        }
        |> afterDisposed { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.noticeEntryViews.remove(index)
                }
            }
        }
    }
    
    private func accessChallengeDataInternal(transaction: AccountManagerModifier) -> Signal<AccessChallengeDataView, NoError> {
        let mutableView = MutableAccessChallengeDataView(data: transaction.getAccessChallengeData())
        let pipe = ValuePipe<AccessChallengeDataView>()
        let index = self.accessChallengeDataViews.add((mutableView, pipe))
        
        let queue = self.queue
        return (.single(AccessChallengeDataView(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<AccessChallengeDataView, NoError> in
            return .complete()
        }
        |> afterDisposed { [weak self] in
            queue.async {
                if let strongSelf = self {
                    strongSelf.accessChallengeDataViews.remove(index)
                }
            }
        }
    }
    
    fileprivate func currentAccountRecord(allocateIfNotExists: Bool) -> Signal<(AccountRecordId, [AccountRecordAttribute])?, NoError> {
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<(AccountRecordId, [AccountRecordAttribute])?, NoError> in
            let current = transaction.getCurrent()
            if let _ = current {
            } else if allocateIfNotExists {
                let id = generateAccountRecordId()
                transaction.setCurrentId(id)
                transaction.updateRecord(id, { _ in
                    return AccountRecord(id: id, attributes: [], temporarySessionId: nil)
                })
            } else {
                return .single(nil)
            }
            
            let signal = self.accountRecordsInternal(transaction: transaction)
            |> map { view -> (AccountRecordId, [AccountRecordAttribute])? in
                if let currentRecord = view.currentRecord {
                    return (currentRecord.id, currentRecord.attributes)
                } else {
                    return nil
                }
            }
            
            return signal
        })
        |> switchToLatest
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if let lhs = lhs, let rhs = rhs {
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1.count != rhs.1.count {
                    return false
                }
                for i in 0 ..< lhs.1.count {
                    if !lhs.1[i].isEqual(to: rhs.1[i]) {
                        return false
                    }
                }
                return true
            } else if (lhs != nil) != (rhs != nil) {
                return false
            } else {
                return true
            }
        })
    }
    
    func allocatedTemporaryAccountId() -> Signal<AccountRecordId, NoError> {
        let temporarySessionId = self.temporarySessionId
        return self.transaction(ignoreDisabled: false, { transaction -> Signal<AccountRecordId, NoError> in
            
            let id = generateAccountRecordId()
            transaction.updateRecord(id, { _ in
                return AccountRecord(id: id, attributes: [], temporarySessionId: temporarySessionId)
            })
            
            return .single(id)
        })
        |> switchToLatest
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
    }
}

private let sharedQueue = Queue()

public final class AccountManager {
    public let basePath: String
    public let mediaBox: MediaBox
    private let queue: Queue
    private let impl: QueueLocalObject<AccountManagerImpl>
    public let temporarySessionId: Int64
    
    public init(basePath: String) {
        self.queue = sharedQueue
        self.basePath = basePath
        var temporarySessionId: Int64 = 0
        arc4random_buf(&temporarySessionId, 8)
        self.temporarySessionId = temporarySessionId
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return AccountManagerImpl(queue: queue, basePath: basePath, temporarySessionId: temporarySessionId)
        })
        self.mediaBox = MediaBox(basePath: basePath + "/media")
    }
    
    public func transaction<T>(ignoreDisabled: Bool = false, _ f: @escaping (AccountManagerModifier) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.transaction(ignoreDisabled: ignoreDisabled, f).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func accountRecords() -> Signal<AccountRecordsView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.accountRecords().start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func sharedData(keys: Set<ValueBoxKey>) -> Signal<AccountSharedDataView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.sharedData(keys: keys).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func noticeEntry(key: NoticeEntryKey) -> Signal<NoticeEntryView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.noticeEntry(key: key).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func accessChallengeData() -> Signal<AccessChallengeDataView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.accessChallengeData().start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func currentAccountRecord(allocateIfNotExists: Bool) -> Signal<(AccountRecordId, [AccountRecordAttribute])?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.currentAccountRecord(allocateIfNotExists: allocateIfNotExists).start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func allocatedTemporaryAccountId() -> Signal<AccountRecordId, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.allocatedTemporaryAccountId().start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
}
