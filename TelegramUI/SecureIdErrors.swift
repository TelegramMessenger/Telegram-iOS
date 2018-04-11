import Foundation
import TelegramCore

enum SecureIdErrorCategory: Int32, Hashable {
    case personalDetails
    case passport
    case driversLicense
    case idCard
    case address
    case bankStatement
    case utilityRecord
    case rentalAgreement
}

enum SecureIdErrorField: Int32, Hashable {
    case personalDetails
    case passport
    case driversLicense
    case idCard
    case address
    case bankStatement
    case utilityRecord
    case rentalAgreement
}

struct SecureIdErrorKey1: Hashable {
    let category: SecureIdErrorCategory
    let field: SecureIdErrorField
}

enum SecureIdErrorKey: Int32, Hashable {
    case personalDetails
}

func parseSecureIdErrors(_ string: String) -> [SecureIdErrorKey: [String]] {
    guard let data = string.data(using: .utf8) else {
        return [:]
    }
    guard let array = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [Any] else {
        return [:]
    }
    var result: [SecureIdErrorKey: [String]] = [:]
    for item in array {
        guard let dict = item as? [String: Any] else {
            continue
        }
        guard let type = dict["type"] as? String else {
            continue
        }
        guard let text = dict["description"] as? String else {
            continue
        }
        switch type {
            case "personal_details":
                if result[.personalDetails] == nil {
                    result[.personalDetails] = []
                }
                result[.personalDetails]!.append(text)
                break
            default:
                break
        }
    }
    return result
}

func filterSecureIdErrors(errors: [SecureIdErrorKey: [String]], afterSaving values: [SecureIdValueWithContext]) -> [SecureIdErrorKey: [String]] {
    var result = errors
    for value in values {
        switch value.value.key {
            case .personalDetails:
                result.removeValue(forKey: .personalDetails)
            default:
                break
        }
    }
    return errors
}
