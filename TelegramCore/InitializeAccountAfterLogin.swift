import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif

func initializedAppSettingsAfterLogin(transaction: Transaction, appVersion: String, syncContacts: Bool) {
    updateAppChangelogState(transaction: transaction, { state in
        var state = state
        state.checkedVersion = appVersion
        state.previousVersion = appVersion
        return state
    })
    transaction.updatePreferencesEntry(key: PreferencesKeys.contactsSettings, { _ in
        return ContactsSettings(synchronizeContacts: syncContacts)
    })
}

