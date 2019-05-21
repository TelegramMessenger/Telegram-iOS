import Foundation

final class AccountManagerAtomicState: Codable {
    var records: [AccountRecordId: AccountRecord]
    var currentRecordId: AccountRecordId?
    var currentAuthRecord: AuthAccountRecord?
    
    init(records: [AccountRecordId: AccountRecord] = [:], currentRecordId: AccountRecordId? = nil, currentAuthRecord: AuthAccountRecord? = nil) {
        self.records = records
        self.currentRecordId = currentRecordId
        self.currentAuthRecord = currentAuthRecord
    }
}
