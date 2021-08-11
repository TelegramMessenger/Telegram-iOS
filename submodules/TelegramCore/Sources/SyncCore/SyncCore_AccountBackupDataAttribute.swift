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

public final class AccountBackupDataAttribute: AccountRecordAttribute, Equatable {
    public let data: AccountBackupData?
    
    public init(data: AccountBackupData?) {
        self.data = data
    }
    
    public init(decoder: PostboxDecoder) {
        self.data = try? JSONDecoder().decode(AccountBackupData.self, from: decoder.decodeDataForKey("data") ?? Data())
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let data = self.data, let serializedData = try? JSONEncoder().encode(data) {
            encoder.encodeData(serializedData, forKey: "data")
        }
    }
    
    public static func ==(lhs: AccountBackupDataAttribute, rhs: AccountBackupDataAttribute) -> Bool {
        return lhs.data == rhs.data
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        if let to = to as? AccountBackupDataAttribute {
            return self == to
        } else {
            return false
        }
    }
}
