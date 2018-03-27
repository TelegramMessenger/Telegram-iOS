import Foundation

public struct SecureIdDate: Equatable {
    public let timestamp: Int32
    
    public init(timestamp: Int32) {
        self.timestamp = timestamp
    }
    
    public static func ==(lhs: SecureIdDate, rhs: SecureIdDate) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        return true
    }
}

public enum SecureIdGender {
    case male
    case female
}

public struct SecureIdFileReference: Equatable {
    let id: Int64
    let accessHash: Int64
    let size: Int32
    let datacenterId: Int32
    let fileHash: Data
    
    public static func ==(lhs: SecureIdFileReference, rhs: SecureIdFileReference) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.accessHash != rhs.accessHash {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.datacenterId != rhs.datacenterId {
            return false
        }
        if lhs.fileHash != rhs.fileHash {
            return false
        }
        return true
    }
}

extension SecureIdFileReference {
    init?(apiFile: Api.SecureFile) {
        switch apiFile {
            case let .secureFile(id, accessHash, size, dcId, fileHash):
                self.init(id: id, accessHash: accessHash, size: size, datacenterId: dcId, fileHash: fileHash.makeData())
            case .secureFileEmpty:
                return nil
        }
    }
}
