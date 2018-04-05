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
    public let id: Int64
    let accessHash: Int64
    let size: Int32
    let datacenterId: Int32
    public let timestamp: Int32
    public let fileHash: Data
    let encryptedSecret: Data
    
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
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.fileHash != rhs.fileHash {
            return false
        }
        if lhs.encryptedSecret != rhs.encryptedSecret {
            return false
        }
        return true
    }
}

extension SecureIdFileReference {
    init?(apiFile: Api.SecureFile) {
        switch apiFile {
            case let .secureFile(id, accessHash, size, dcId, date, fileHash, secret):
                self.init(id: id, accessHash: accessHash, size: size, datacenterId: dcId, timestamp: date, fileHash: fileHash.makeData(), encryptedSecret: secret.makeData())
            case .secureFileEmpty:
                return nil
        }
    }
}

extension SecureIdGender {
    init?(serializedString: String) {
        switch serializedString {
            case "male":
                self = .male
            case "female":
                self = .female
            default:
                return nil
        }
    }
    
    func serialize() -> String {
        switch self {
            case .male:
                return "male"
            case .female:
                return "female"
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

extension SecureIdDate {
    init?(serializedString: String) {
        guard let date = dateFormatter.date(from: serializedString) else {
            return nil
        }
        self.init(timestamp: Int32(date.timeIntervalSince1970))
    }
    
    func serialize() -> String {
        return dateFormatter.string(from: Date(timeIntervalSince1970: Double(self.timestamp)))
    }
}
