import Foundation

public struct SecureIdDate: Equatable {
    private var timestamp: Int32
    
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

public enum SecureIdFileReference: Equatable {
    case none
    case file(id: Int64, accessHash: Int64, size: Int32, datacenterId: Int32, fileHash: String)
    
    public static func ==(lhs: SecureIdFileReference, rhs: SecureIdFileReference) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .file(id, accessHash, size, datacenterId, fileHash):
                if case .file(id, accessHash, size, datacenterId, fileHash) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}
