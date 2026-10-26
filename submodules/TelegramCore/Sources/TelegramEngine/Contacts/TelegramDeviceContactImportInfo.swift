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

/// The user the server matched a device phone number to when the app last imported it; nil when
/// it matched nobody, is waiting for a retry, or was never imported (contact sync is off, or has
/// not run since the number was saved).
///
/// `number` is the number exactly as the device stores it (`CNPhoneNumber.stringValue`), because
/// that is what the app imports and keys the record by. A national-format number ("600 00 00 00")
/// is only meaningful in the account's own country, and it is the server that reads it that way,
/// so this record is the one mapping from such a number to a user that the device can trust.
public func deviceContactImportedPeerId(transaction: Transaction, number: DeviceContactNormalizedPhoneNumber) -> PeerId? {
    guard let value = transaction.getDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(number).key) as? TelegramDeviceContactImportedData, case let .imported(_, _, peerId) = value else {
        return nil
    }
    return peerId
}

func _internal_deviceContactsImportedByCount(postbox: Postbox, contacts: [(String, [DeviceContactNormalizedPhoneNumber])]) -> Signal<[String: Int32], NoError> {
    return postbox.transaction { transaction -> [String: Int32] in
        var result: [String: Int32] = [:]
        for (id, numbers) in contacts {
            var maxCount: Int32 = 0
            for number in numbers {
                if let value = transaction.getDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(number).key) as? TelegramDeviceContactImportedData, case let .imported(_, importedByCount, _) = value {
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
