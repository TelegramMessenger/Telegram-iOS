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
    public let temporarySessionId: Int64
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
        var temporarySessionId: Int64 = 0
        arc4random_buf(&temporarySessionId, 8)
        self.temporarySessionId = temporarySessionId
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
        self.valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue)
        
        self.metadataTable = AccountManagerMetadataTable(valueBox: self.valueBox, table: AccountManagerMetadataTable.tableSpec(0))
        self.recordTable = AccountManagerRecordTable(valueBox: self.valueBox, table: AccountManagerRecordTable.tableSpec(1))
        
        self.tables.append(self.metadataTable)
        self.tables.append(self.recordTable)
    }
    
    public func transaction<T>(_ f: @escaping (AccountManagerModifier) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.justDispatch {
                self.valueBox.begin()
                
                let transaction = AccountManagerModifier(getRecords: {
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
                    let record = AccountRecord(id: id, attributes: attributes, temporarySessionId: nil)
                    self.recordTable.setRecord(id: id, record: record, operations: &self.currentRecordOperations)
                    return id
                })
                
                let result = f(transaction)
               
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
        return self.transaction { transaction -> Signal<AccountRecordsView, NoError> in
            return self.accountRecordsInternal(transaction: transaction)
        } |> switchToLatest
    }
    
    private func accountRecordsInternal(transaction: AccountManagerModifier) -> Signal<AccountRecordsView, NoError> {
        let mutableView = MutableAccountRecordsView(getRecords: {
            return self.recordTable.getRecords()
        }, currentId: self.metadataTable.getCurrentAccountId())
        let pipe = ValuePipe<AccountRecordsView>()
        let index = self.recordsViews.add((mutableView, pipe))
        
        return (.single(AccountRecordsView(mutableView))
        |> then(pipe.signal()))
        |> `catch` { _ -> Signal<AccountRecordsView, NoError> in
            return .complete()
        }
        |> afterDisposed { [weak self] in
            if let strongSelf = self {
                strongSelf.queue.async {
                    strongSelf.recordsViews.remove(index)
                }
            }
        }
    }
    
    public func allocatedCurrentAccountId() -> Signal<AccountRecordId?, NoError> {
        return self.transaction { transaction -> Signal<AccountRecordId?, NoError> in
            let current = transaction.getCurrentId()
            let id: AccountRecordId
            if let current = current {
                id = current
            } else {
                id = generateAccountRecordId()
                transaction.setCurrentId(id)
                transaction.updateRecord(id, { _ in
                    return AccountRecord(id: id, attributes: [], temporarySessionId: nil)
                })
            }
            
            let signal = self.accountRecordsInternal(transaction: transaction) |> map { view -> AccountRecordId? in
                return view.currentRecord?.id
            }
            
            return signal
        } |> switchToLatest |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
    }
    
    public func allocatedTemporaryAccountId() -> Signal<AccountRecordId, NoError> {
        let temporarySessionId = self.temporarySessionId
        return self.transaction { transaction -> Signal<AccountRecordId, NoError> in
            
            let id = generateAccountRecordId()
            transaction.updateRecord(id, { _ in
                return AccountRecord(id: id, attributes: [], temporarySessionId: temporarySessionId)
            })
            
            return .single(id)
        }
        |> switchToLatest
        |> distinctUntilChanged(isEqual: { lhs, rhs in
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
