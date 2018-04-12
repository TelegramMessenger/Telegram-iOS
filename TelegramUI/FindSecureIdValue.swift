import Foundation
import TelegramCore

func findValue(_ values: [SecureIdValueWithContext], key: SecureIdValueKey) -> (Int, SecureIdValue)? {
    for i in 0 ..< values.count {
        if values[i].value.key == key {
            return (i, values[i].value)
        }
    }
    return nil
}
