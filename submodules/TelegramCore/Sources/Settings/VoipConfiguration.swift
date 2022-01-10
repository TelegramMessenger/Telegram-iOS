import Postbox

public func currentVoipConfiguration(transaction: Transaction) -> VoipConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.voipConfiguration)?.get(VoipConfiguration.self) {
        return entry
    } else {
        return VoipConfiguration.defaultValue
    }
}

func updateVoipConfiguration(transaction: Transaction, _ f: (VoipConfiguration) -> VoipConfiguration) {
    let current = currentVoipConfiguration(transaction: transaction)
    let updated = f(current)
    if updated != current {
        transaction.setPreferencesEntry(key: PreferencesKeys.voipConfiguration, value: PreferencesEntry(updated))
    }
}
