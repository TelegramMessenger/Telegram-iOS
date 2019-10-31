import Foundation
import libphonenumber

private let phoneNumberUtil = NBPhoneNumberUtil()

public func formatPhoneNumber(_ string: String) -> String {
    do {
        let number = try phoneNumberUtil.parse("+" + string, defaultRegion: nil)
        return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
    } catch _ {
        return string
    }
}

public func isViablePhoneNumber(_ string: String) -> Bool {
    return phoneNumberUtil.isViablePhoneNumber(string)
}

public class ParsedPhoneNumber: Equatable {
    let rawPhoneNumber: NBPhoneNumber?
    
    public init?(string: String) {
        if let number = try? phoneNumberUtil.parse(string, defaultRegion: NB_UNKNOWN_REGION) {
            self.rawPhoneNumber = number
        } else {
            return nil
        }
    }
    
    public static func == (lhs: ParsedPhoneNumber, rhs: ParsedPhoneNumber) -> Bool {
        var error: NSError?
        let result = phoneNumberUtil.isNumberMatch(lhs.rawPhoneNumber, second: rhs.rawPhoneNumber, error: &error)
        if error != nil {
            return false
        }
        if result != .NO_MATCH && result != .NOT_A_NUMBER {
            return true
        } else {
            return false
        }
    }
}
