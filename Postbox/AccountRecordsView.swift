import Foundation

final class MutableAccountRecordsView {
    fileprivate var records: [AccountRecord]
    fileprivate var currentId: AccountRecordId?
    
    init(getRecords: () -> [AccountRecord], currentId: AccountRecordId?) {
        self.records = getRecords()
        self.currentId = currentId
    }
    
    func replay(operations: [AccountManagerRecordOperation], metadataOperations: [AccountManagerMetadataOperation]) -> Bool {
        var updated = false
        
        for operation in operations {
            switch operation {
                case let .set(id, record):
                    if let record = record {
                        updated = true
                        var found = false
                        for i in 0 ..< self.records.count {
                            if self.records[i].id == id {
                                self.records[i] = record
                                found = true
                                break
                            }
                        }
                        
                        if !found {
                            self.records.append(record)
                            self.records.sort(by: { lhs, rhs in
                                return lhs.id < rhs.id
                            })
                        }
                    } else {
                        for i in 0 ..< self.records.count {
                            if self.records[i].id == id {
                                self.records.remove(at: i)
                                updated = true
                                break
                            }
                        }
                    }
            }
        }
        
        for operation in metadataOperations {
            switch operation {
                case let .updateCurrentAccountId(id):
                    updated = true
                    self.currentId = id
            }
        }
        
        return updated
    }
}

public final class AccountRecordsView {
    public let records: [AccountRecord]
    public let currentRecord: AccountRecord?
    
    init(_ view: MutableAccountRecordsView) {
        self.records = view.records
        if let currentId = view.currentId {
            var currentRecord: AccountRecord?
            for record in view.records {
                if record.id == currentId {
                    currentRecord = record
                    break
                }
            }
            self.currentRecord = currentRecord
        } else {
            self.currentRecord = nil
        }
    }
}
