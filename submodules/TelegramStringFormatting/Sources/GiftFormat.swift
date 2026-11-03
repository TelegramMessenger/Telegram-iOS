import Foundation
import TelegramPresentationData

public func formatCollectibleNumber(_ number: Int32, dateTimeFormat: PresentationDateTimeFormat) -> String {
    if number > 9999 {
        return presentationStringsFormattedNumber(number, dateTimeFormat.groupingSeparator)
    } else {
        return "\(number)"
    }
}
