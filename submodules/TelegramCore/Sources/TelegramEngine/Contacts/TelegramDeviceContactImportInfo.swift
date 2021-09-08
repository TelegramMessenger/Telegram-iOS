import Foundation
import Postbox
import SwiftSignalKit


private let phoneNumberKeyPrefix: ValueBoxKey = {
    let result = ValueBoxKey(length: 1)
    result.setInt8(0, value: 0)
    return result
}()

enum TelegramDeviceContactImportIdentifier: Hashable, Comparable, Equatable {
    case phoneNumber(DeviceContactNormalizedPhoneNumber)
    
    init?(key: ValueBoxKey) {
        if key.length < 2 {
            return nil
        }
        switch key.getInt8(0) {
            case 0:
                guard let string = key.substringValue(1 ..< key.length) else {
                    return nil
                }
                self = .phoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: string))
            default:
                return nil
        }
    }
    
    var key: ValueBoxKey {
        switch self {
            case let .phoneNumber(number):
                
                let numberKey = ValueBoxKey(number.rawValue)
                return phoneNumberKeyPrefix + numberKey
        }
    }
    
    static func <(lhs: TelegramDeviceContactImportIdentifier, rhs: TelegramDeviceContactImportIdentifier) -> Bool {
        switch lhs {
            case let .phoneNumber(lhsNumber):
                switch rhs {
                    case let .phoneNumber(rhsNumber):
                        return lhsNumber.rawValue < rhsNumber.rawValue
                }
        }
    }
}

func _internal_deviceContactsImportedByCount(postbox: Postbox, contacts: [(String, [DeviceContactNormalizedPhoneNumber])]) -> Signal<[String: Int32], NoError> {
    return postbox.transaction { transaction -> [String: Int32] in
        var result: [String: Int32] = [:]
        for (id, numbers) in contacts {
            var maxCount: Int32 = 0
            for number in numbers {
                if let value = transaction.getDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(number).key) as? TelegramDeviceContactImportedData, case let .imported(_, importedByCount) = value {
                    maxCount = max(maxCount, importedByCount)
                }
            }
            if maxCount != 0 {
                result[id] = maxCount
            }
        }
        return result
    }
}
