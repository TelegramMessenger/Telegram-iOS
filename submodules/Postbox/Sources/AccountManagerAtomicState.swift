import Foundation

final class AccountManagerAtomicState: Codable {
    enum CodingKeys: String, CodingKey {
        case records
        case currentRecordId
        case currentAuthRecord
        case accessChallengeData
    }
    
    var records: [AccountRecordId: AccountRecord]
    var currentRecordId: AccountRecordId?
    var currentAuthRecord: AuthAccountRecord?
    var accessChallengeData: PostboxAccessChallengeData
    
    init(records: [AccountRecordId: AccountRecord] = [:], currentRecordId: AccountRecordId? = nil, currentAuthRecord: AuthAccountRecord? = nil, accessChallengeData: PostboxAccessChallengeData = .none) {
        self.records = records
        self.currentRecordId = currentRecordId
        self.currentAuthRecord = currentAuthRecord
        self.accessChallengeData = accessChallengeData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let records = try? container.decode(Array<AccountRecord>.self, forKey: .records) {
            var recordDict: [AccountRecordId: AccountRecord] = [:]
            for record in records {
                recordDict[record.id] = record
            }
            self.records = recordDict
        } else {
            self.records = try container.decode(Dictionary<AccountRecordId, AccountRecord>.self, forKey: .records)
        }
        if let idString = try? container.decodeIfPresent(String.self, forKey: .currentRecordId), let idValue = Int64(idString) {
            self.currentRecordId = AccountRecordId(rawValue: idValue)
        } else {
            self.currentRecordId = try container.decodeIfPresent(AccountRecordId.self, forKey: .currentRecordId)
        }
        self.currentAuthRecord = try container.decodeIfPresent(AuthAccountRecord.self, forKey: .currentAuthRecord)
        
        if let accessChallengeData = try? container.decodeIfPresent(PostboxAccessChallengeData.self, forKey: .accessChallengeData) {
            self.accessChallengeData = accessChallengeData
        } else {
            self.accessChallengeData = .none
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let recordsArray: Array<AccountRecord> = Array(self.records.values)
        try container.encode(recordsArray, forKey: .records)
        let currentRecordIdString: String? = self.currentRecordId.flatMap({ "\($0.rawValue)" })
        try container.encodeIfPresent(currentRecordIdString, forKey: .currentRecordId)
        try container.encodeIfPresent(self.currentAuthRecord, forKey: .currentAuthRecord)
        try container.encode(self.accessChallengeData, forKey: .accessChallengeData)
    }
}
