import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct AppConfiguration: PreferencesEntry, Equatable {
    public var data: JSON?
    
    public static var defaultValue: AppConfiguration {
        return AppConfiguration(data: nil)
    }
    
    init(data: JSON?) {
        self.data = data
    }
    
    public init(decoder: PostboxDecoder) {
        self.data = decoder.decodeObjectForKey("data", decoder: { JSON(decoder: $0) }) as? JSON
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let data = self.data {
            encoder.encodeObject(data, forKey: "data")
        } else {
            encoder.encodeNil(forKey: "data")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? AppConfiguration else {
            return false
        }
        return self == to
    }
}

public func currentAppConfiguration(transaction: Transaction) -> AppConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration) as? AppConfiguration {
        return entry
    } else {
        return AppConfiguration.defaultValue
    }
}

func updateAppConfiguration(transaction: Transaction, _ f: (AppConfiguration) -> AppConfiguration) {
    let current = currentAppConfiguration(transaction: transaction)
    let updated = f(current)
    if updated != current {
        transaction.setPreferencesEntry(key: PreferencesKeys.appConfiguration, value: updated)
    }
}
