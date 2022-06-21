import Postbox

private func currentAppConfiguration(transaction: Transaction) -> AppConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) {
        return entry
    } else {
        return AppConfiguration.defaultValue
    }
}

func updateAppConfiguration(transaction: Transaction, _ f: (AppConfiguration) -> AppConfiguration) {
    let current = currentAppConfiguration(transaction: transaction)
    let updated = f(current)
    if updated != current {
        transaction.setPreferencesEntry(key: PreferencesKeys.appConfiguration, value: PreferencesEntry(updated))
    }
}
