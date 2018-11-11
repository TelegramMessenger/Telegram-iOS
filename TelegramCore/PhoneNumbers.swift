import Foundation
import TelegramCorePrivateModule

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
