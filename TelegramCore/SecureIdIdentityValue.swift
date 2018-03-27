import Foundation

public enum SecureIdIdentityValue: Equatable {
    case passport(SecureIdIdentityPassportValue)
    
    public static func ==(lhs: SecureIdIdentityValue, rhs: SecureIdIdentityValue) -> Bool {
        switch lhs {
            case let .passport(value):
                if case .passport(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct SecureIdIdentityPassportValue: Equatable {
    public var identifier: String
    public var firstName: String
    public var lastName: String
    public var birthdate: SecureIdDate
    public var countryCode: String
    public var gender: SecureIdGender
    public var issueDate: SecureIdDate
    public var expiryDate: SecureIdDate?
    public var verificationDocuments: [SecureIdFileReference]
    
    public init(identifier: String, firstName: String, lastName: String, birthdate: SecureIdDate, countryCode: String, gender: SecureIdGender, issueDate: SecureIdDate, expiryDate: SecureIdDate?, verificationDocuments: [SecureIdFileReference]) {
        self.identifier = identifier
        self.firstName = firstName
        self.lastName = lastName
        self.birthdate = birthdate
        self.countryCode = countryCode
        self.gender = gender
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.verificationDocuments = verificationDocuments
    }
    
    public static func ==(lhs: SecureIdIdentityPassportValue, rhs: SecureIdIdentityPassportValue) -> Bool {
        if lhs.identifier != rhs.identifier {
            return false
        }
        if lhs.firstName != rhs.firstName {
            return false
        }
        if lhs.lastName != rhs.lastName {
            return false
        }
        if lhs.birthdate != rhs.birthdate {
            return false
        }
        if lhs.countryCode != rhs.countryCode {
            return false
        }
        if lhs.gender != rhs.gender {
            return false
        }
        if lhs.issueDate != rhs.issueDate {
            return false
        }
        if lhs.expiryDate != rhs.expiryDate {
            return false
        }
        return true
    }
}

private func parseGender(_ string: String) -> SecureIdGender? {
    switch string {
        case "male":
            return .male
        case "female":
            return .female
        default:
            return nil
    }
}

private func serializeGender(_ gender: SecureIdGender) -> String {
    switch gender {
        case .male:
            return "male"
        case .female:
            return "female"
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

private func parseDate(_ string: String) -> SecureIdDate? {
    guard let date = dateFormatter.date(from: string) else {
        return nil
    }
    return SecureIdDate(timestamp: Int32(date.timeIntervalSince1970))
}

private func serializeDate(_ date: SecureIdDate) -> String {
    return dateFormatter.string(from: Date(timeIntervalSince1970: Double(date.timestamp)))
}

private func parseFileReferenceId(_ string: String) -> Int64? {
    let data = dataWithHexString(string)
    if data.count != 8 {
        return nil
    }
    var value: Int64 = 0
    data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
        memcpy(&value, bytes, 8)
    }
    return value
}

private func serializeFileReferenceId(_ id: Int64) -> String {
    var data = Data(count: 8)
    data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) -> Void in
        var id = id
        memcpy(bytes, &id, 8)
    }
    return hexString(data)
}

extension SecureIdIdentityValue {
    init?(data: Data, fileReferences: [Int64: SecureIdFileReference]) {
        guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return nil
        }
        guard let documentType = dict["document_type"] as? String else {
            return nil
        }
        
        switch documentType {
            case "passport":
                if let passport = SecureIdIdentityPassportValue(dict: dict, fileReferences: fileReferences) {
                    self = .passport(passport)
                }
            default:
                return nil
        }
        
        return nil
    }
    
    func serialize() -> (Data, [SecureIdFileReference])? {
        var dict: [String: Any] = [:]
        let fileReferences: [SecureIdFileReference]
        switch self {
            case let .passport(value):
                dict["document_type"] = "passport"
                let (valueDict, references) = value.serialize()
                dict.merge(valueDict, uniquingKeysWith: { lhs, _ in return lhs })
                fileReferences = references
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            return nil
        }
        return (data, fileReferences)
    }
}

private extension SecureIdIdentityPassportValue {
    init?(dict: [String: Any], fileReferences: [Int64: SecureIdFileReference]) {
        guard let identifier = dict["document_no"] as? String else {
            return nil
        }
        guard let firstName = dict["first_name"] as? String else {
            return nil
        }
        guard let lastName = dict["last_name"] as? String else {
            return nil
        }
        guard let birthdate = (dict["date_of_birth"] as? String).flatMap(parseDate) else {
            return nil
        }
        guard let gender = (dict["gender"] as? String).flatMap(parseGender) else {
            return nil
        }
        guard let countryCode = dict["country_code"] as? String else {
            return nil
        }
        guard let issueDate = (dict["issue_date"] as? String).flatMap(parseDate) else {
            return nil
        }
        let expiryDate = (dict["expiry_date"] as? String).flatMap(parseDate)
        
        var verificationDocuments: [SecureIdFileReference] = []
        if let files = dict["files"] as? [String] {
            for fileId in files {
                guard let fileId = parseFileReferenceId(fileId) else {
                    continue
                }
                guard let file = fileReferences[fileId] else {
                    continue
                }
                verificationDocuments.append(file)
            }
        }
        
        self.init(identifier: identifier, firstName: firstName, lastName: lastName, birthdate: birthdate, countryCode: countryCode, gender: gender, issueDate: issueDate, expiryDate: expiryDate, verificationDocuments: verificationDocuments)
    }
    
    func serialize() -> ([String: Any], [SecureIdFileReference]) {
        var dict: [String: Any] = [:]
        dict["document_no"] = self.identifier
        dict["first_name"] = self.firstName
        dict["last_name"] = self.lastName
        dict["date_of_birth"] = serializeDate(self.birthdate)
        dict["gender"] = serializeGender(self.gender)
        dict["country_code"] = self.countryCode
        dict["issue_date"] = serializeDate(self.issueDate)
        if let expiryDate = self.expiryDate {
            dict["expiry_date"] = serializeDate(expiryDate)
        }
        if !self.verificationDocuments.isEmpty {
            dict["files"] = self.verificationDocuments.map { serializeFileReferenceId($0.id) }
        }
        
        return (dict, self.verificationDocuments)
    }
}
