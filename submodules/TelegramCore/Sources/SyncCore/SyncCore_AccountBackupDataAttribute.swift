import Foundation
import Postbox

public struct AccountBackupData: Codable, Equatable {
    public var masterDatacenterId: Int32
    public var peerId: Int64
    public var masterDatacenterKey: Data
    public var masterDatacenterKeyId: Int64

    public init(masterDatacenterId: Int32, peerId: Int64, masterDatacenterKey: Data, masterDatacenterKeyId: Int64) {
    	self.masterDatacenterId = masterDatacenterId
    	self.peerId = peerId
    	self.masterDatacenterKey = masterDatacenterKey
    	self.masterDatacenterKeyId = masterDatacenterKeyId
    }
}

public final class AccountBackupDataAttribute: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case data
    }

    public let data: AccountBackupData?
    
    public init(data: AccountBackupData?) {
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.data = try? JSONDecoder().decode(AccountBackupData.self, from: (try? container.decode(Data.self, forKey: .data)) ?? Data())
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let data = self.data, let serializedData = try? JSONEncoder().encode(data) {
            try container.encode(serializedData, forKey: .data)
        } else {
            try container.encodeNil(forKey: .data)
        }
    }
    
    public static func ==(lhs: AccountBackupDataAttribute, rhs: AccountBackupDataAttribute) -> Bool {
        return lhs.data == rhs.data
    }
}
