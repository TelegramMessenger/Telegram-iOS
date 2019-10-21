import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

import SyncCore

public func currentLimitsConfiguration(transaction: Transaction) -> LimitsConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration {
        return entry
    } else {
        return LimitsConfiguration.defaultValue
    }
}

func updateLimitsConfiguration(transaction: Transaction, configuration: LimitsConfiguration) {
    if !currentLimitsConfiguration(transaction: transaction).isEqual(to: configuration) {
        transaction.setPreferencesEntry(key: PreferencesKeys.limitsConfiguration, value: configuration)
    }
}
