import Foundation
import TelegramCorePrivateModule

private let phoneNumberUtil = NBPhoneNumberUtil()

func formatPhoneNumber(_ string: String) -> String {
    do {
        let number = try phoneNumberUtil.parse("+" + string, defaultRegion: nil)
        return try phoneNumberUtil.format(number, numberFormat: .INTERNATIONAL)
    } catch _ {
        return ""
    }
}
