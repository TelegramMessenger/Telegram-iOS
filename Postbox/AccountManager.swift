import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public struct AccountManagerModifier {
    public let getRecords: () -> [AccountRecord]
    public let updateRecord: (AccountRecordId, (AccountRecord?) -> (AccountRecord?)) -> Void
    public let getCurrentId: () -> AccountRecordId?
    public let setCurrentId: (AccountRecordId) -> Void
    public let createRecord: ([AccountRecordAttribute]) -> AccountRecordId
}

public final class AccountManager {
    private let queue: Queue
    private let basePath: String
    private let valueBox: ValueBox
    
    private var tables: [Table] = []
    
    private let metadataTable: AccountManagerMetadataTable
    private let recordTable: AccountManagerRecordTable
    
    private var currentRecordOperations: [AccountManagerRecordOperation] = []
    private var currentMetadataOperations: [AccountManagerMetadataOperation] = []
    
    private var recordsViews = Bag<(MutableAccountRecordsView, ValuePipe<AccountRecordsView>)>()
    
    fileprivate init(queue: Queue, basePath: String) {
        self.queue = queue
        self.basePath = basePath
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: false, attributes: nil)
        self.valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue)
        
        self.metadataTable = AccountManagerMetadataTable(valueBox: self.valueBox, table: AccountManagerMetadataTable.tableSpec(0))
        self.recordTable = AccountManagerRecordTable(valueBox: self.valueBox, table: AccountManagerRecordTable.tableSpec(1))
        
        self.tables.append(self.metadataTable)
        self.tables.append(self.recordTable)
    }
    
    public func modify<T>(_ f: @escaping (AccountManagerModifier) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.justDispatch {
                self.valueBox.begin()
                
                let modifier = AccountManagerModifier(getRecords: {
                    return self.recordTable.getRecords()
                }, updateRecord: { id, update in
                    let current = self.recordTable.getRecord(id: id)
                    let updated = update(current)
                    if updated != current {
                        self.recordTable.setRecord(id: id, record: updated, operations: &self.currentRecordOperations)
                    }
                }, getCurrentId: {
                    return self.metadataTable.getCurrentAccountId()
                }, setCurrentId: { id in
                    self.metadataTable.setCurrentAccountId(id, operations: &self.currentMetadataOperations)
                }, createRecord: { attributes in
                    let id = generateAccountRecordId()
                    let record = AccountRecord(id: id, attributes: attributes)
                    self.recordTable.setRecord(id: id, record: record, operations: &self.currentRecordOperations)
                    return id
                })
                
                let result = f(modifier)
               
                self.beforeCommit()
                
                self.valueBox.commit()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    private func beforeCommit() {
        if !self.currentRecordOperations.isEmpty || !self.currentMetadataOperations.isEmpty {
            for (view, pipe) in self.recordsViews.copyItems() {
                if view.replay(operations: self.currentRecordOperations, metadataOperations: self.currentMetadataOperations) {
                    pipe.putNext(AccountRecordsView(view))
                }
            }
        }
        
        self.currentRecordOperations.removeAll()
        self.currentMetadataOperations.removeAll()
        
        for table in self.tables {
            table.beforeCommit()
        }
    }
    
    public func accountRecords() -> Signal<AccountRecordsView, NoError> {
        return self.modify { modifier -> Signal<AccountRecordsView, NoError> in
            return self.accountRecordsInternal(modifier: modifier)
        } |> switchToLatest
    }
    
    private func accountRecordsInternal(modifier: AccountManagerModifier) -> Signal<AccountRecordsView, NoError> {
        let mutableView = MutableAccountRecordsView(getRecords: {
            return self.recordTable.getRecords()
        }, currentId: self.metadataTable.getCurrentAccountId())
        let pipe = ValuePipe<AccountRecordsView>()
        let index = self.recordsViews.add((mutableView, pipe))
        
        return (.single(AccountRecordsView(mutableView))
            |> then(pipe.signal()))
            |> afterDisposed { [weak self] in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.recordsViews.remove(index)
                    }
                }
        }
    }
    
    public func allocatedCurrentAccountId() -> Signal<AccountRecordId?, NoError> {
        return self.modify { modifier -> Signal<AccountRecordId?, NoError> in
            let current = modifier.getCurrentId()
            let id: AccountRecordId
            if let current = current {
                id = current
            } else {
                id = generateAccountRecordId()
                modifier.setCurrentId(id)
                modifier.updateRecord(id, { _ in
                    return AccountRecord(id: id, attributes: [])
                })
            }
            
            let signal = self.accountRecordsInternal(modifier: modifier) |> map { view -> AccountRecordId? in
                return view.currentRecord?.id
            }
            
            return signal
        } |> switchToLatest |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
    }
}

public func accountManager(basePath: String) -> Signal<AccountManager, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        queue.async {
            subscriber.putNext(AccountManager(queue: queue, basePath: basePath))
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
}
