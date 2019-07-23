import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

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

enum TelegramDeviceContactImportedData: PostboxCoding {
    case imported(data: ImportableDeviceContactData, importedByCount: Int32)
    case retryLater
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .imported(data: decoder.decodeObjectForKey("d", decoder: { ImportableDeviceContactData(decoder: $0) }) as! ImportableDeviceContactData, importedByCount: decoder.decodeInt32ForKey("c", orElse: 0))
            case 1:
                self = .retryLater
            default:
                assertionFailure()
                self = .retryLater
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .imported(data, importedByCount):
                encoder.encodeInt32(0, forKey: "_t")
                encoder.encodeObject(data, forKey: "d")
                encoder.encodeInt32(importedByCount, forKey: "c")
            case .retryLater:
                encoder.encodeInt32(1, forKey: "_t")
        }
    }
}

public func deviceContactsImportedByCount(postbox: Postbox, contacts: [(String, [DeviceContactNormalizedPhoneNumber])]) -> Signal<[String: Int32], NoError> {
    return postbox.transaction { transaction -> [String: Int32] in
        var result: [String: Int32] = [:]
        for (id, numbers) in contacts {
            var maxCount: Int32 = 0
            for number in numbers {
                if let value = transaction.getDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(number).key) as? TelegramDeviceContactImportedData, case let .imported(imported) = value {

                    maxCount = max(maxCount, imported.importedByCount)
                }
            }
            if maxCount != 0 {
                result[id] = maxCount
            }
        }
        return result
    }
}
