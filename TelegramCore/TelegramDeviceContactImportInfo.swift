import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

enum TelegramDeviceContactImportIdentifier: DeviceContactImportIdentifier {
    case phoneNumber(String)
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .phoneNumber(decoder.decodeStringForKey("p", orElse: ""))
            default:
                assertionFailure()
                self = .phoneNumber("")
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .phoneNumber(number):
                encoder.encodeInt32(0, forKey: "_t")
                encoder.encodeString(number, forKey: "p")
        }
    }
    
    var key: ValueBoxKey {
        switch self {
            case let .phoneNumber(number):
                let numberKey = ValueBoxKey(number)
                return numberKey
        }
    }
}

final class TelegramDeviceContactImportInfo: PostboxCoding {
    let importedByCount: Int32
    
    init(importedByCount: Int32) {
        self.importedByCount = importedByCount
    }
    
    init(decoder: PostboxDecoder) {
        self.importedByCount = decoder.decodeInt32ForKey("ic", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.importedByCount, forKey: "ic")
    }
}

public func deviceContactsImportedByCount(postbox: Postbox, contacts: [DeviceContact]) -> Signal<[String: Int32], NoError> {
    return postbox.modify { modifier -> [String: Int32] in
        var result: [String: Int32] = [:]
        for contact in contacts {
            var maxCount: Int32 = 0
            for number in contact.phoneNumbers {
                if let value = modifier.getDeviceContactImportInfo(TelegramDeviceContactImportIdentifier.phoneNumber(number.number.normalized.rawValue)) as? TelegramDeviceContactImportInfo {
                    maxCount = max(maxCount, value.importedByCount)
                }
            }
            if maxCount != 0 {
                result[contact.id] = maxCount
            }
        }
        return result
    }
}
