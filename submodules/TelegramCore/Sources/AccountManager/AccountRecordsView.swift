import Foundation

final class MutableAccountRecordsView<Types: AccountManagerTypes> {
    fileprivate var records: [AccountRecord<Types.Attribute>]
    fileprivate var currentId: AccountRecordId?
    fileprivate var currentAuth: AuthAccountRecord<Types.Attribute>?
    
    init(getRecords: () -> [AccountRecord<Types.Attribute>], currentId: AccountRecordId?, currentAuth: AuthAccountRecord<Types.Attribute>?) {
        self.records = getRecords()
        self.currentId = currentId
        self.currentAuth = currentAuth
    }
    
    func replay(operations: [AccountManagerRecordOperation<Types.Attribute>], metadataOperations: [AccountManagerMetadataOperation<Types.Attribute>]) -> Bool {
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
                case let .updateCurrentAuthAccountRecord(record):
                    updated = true
                    self.currentAuth = record
            }
        }
        
        return updated
    }
}

public final class AccountRecordsView<Types: AccountManagerTypes> {
    public let records: [AccountRecord<Types.Attribute>]
    public let currentRecord: AccountRecord<Types.Attribute>?
    public let currentAuthAccount: AuthAccountRecord<Types.Attribute>?
    
    init(_ view: MutableAccountRecordsView<Types>) {
        self.records = view.records
        if let currentId = view.currentId {
            var currentRecord: AccountRecord<Types.Attribute>?
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
        self.currentAuthAccount = view.currentAuth
    }
}
