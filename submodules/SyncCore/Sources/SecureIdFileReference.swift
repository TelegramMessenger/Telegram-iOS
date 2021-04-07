import Foundation
import Postbox

public struct SecureIdFileReference: Equatable {
    public let id: Int64
    public let accessHash: Int64
    public let size: Int32
    public let datacenterId: Int32
    public let timestamp: Int32
    public let fileHash: Data
    public let encryptedSecret: Data

    public init(id: Int64, accessHash: Int64, size: Int32, datacenterId: Int32, timestamp: Int32, fileHash: Data, encryptedSecret: Data) {
    	self.id = id
    	self.accessHash = accessHash
    	self.size = size
    	self.datacenterId = datacenterId
    	self.timestamp = timestamp
    	self.fileHash = fileHash
    	self.encryptedSecret = encryptedSecret
    }
}
