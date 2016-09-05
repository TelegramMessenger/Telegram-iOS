import Foundation
import TelegramCorePrivateModule

private let phoneNumberUtil = NBPhoneNumberUtil()

public func formatPhoneNumber(_ string: String) -> String {
    do {
        return string
        //let number = try phoneNumberUtil.parse("+" + string, defaultRegion: nil)
        //return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
    } catch _ {
        return string
    }
}
