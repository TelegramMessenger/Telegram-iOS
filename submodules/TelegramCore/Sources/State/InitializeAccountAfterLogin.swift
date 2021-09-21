import Foundation
import SwiftSignalKit
import Postbox


func initializedAppSettingsAfterLogin(transaction: Transaction, appVersion: String, syncContacts: Bool) {
    updateAppChangelogState(transaction: transaction, { state in
        var state = state
        state.checkedVersion = appVersion
        state.previousVersion = appVersion
        return state
    })
    transaction.updatePreferencesEntry(key: PreferencesKeys.contactsSettings, { _ in
        return PreferencesEntry(ContactsSettings(synchronizeContacts: syncContacts))
    })
}

