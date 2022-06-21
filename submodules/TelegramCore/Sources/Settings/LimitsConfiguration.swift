import Foundation
import Postbox


public func currentLimitsConfiguration(transaction: Transaction) -> LimitsConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration)?.get(LimitsConfiguration.self) {
        return entry
    } else {
        return LimitsConfiguration.defaultValue
    }
}

func updateLimitsConfiguration(transaction: Transaction, configuration: LimitsConfiguration) {
    if currentLimitsConfiguration(transaction: transaction) != configuration {
        transaction.setPreferencesEntry(key: PreferencesKeys.limitsConfiguration, value: PreferencesEntry(configuration))
    }
}
