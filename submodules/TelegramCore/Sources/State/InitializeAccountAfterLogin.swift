import Foundation
import SwiftSignalKit
import Postbox


func initializedAppSettingsAfterLogin(transaction: Transaction, appVersion: String, syncContacts: Bool, isSupportUser: Bool = false) {
    updateAppChangelogState(transaction: transaction, { state in
        var state = state
        state.checkedVersion = appVersion
        state.previousVersion = appVersion
        return state
    })
    transaction.updatePreferencesEntry(key: PreferencesKeys.contactsSettings, { _ in
        return PreferencesEntry(ContactsSettings(synchronizeContacts: syncContacts))
    })
    if isSupportUser {
        // Support volunteers work a queue; message notifications are off by default so the
        // device is not driven by ticket traffic. These are per-account settings, so this
        // cannot affect the volunteer's other accounts — and because they are stored rather
        // than forced, the volunteer can re-enable them in Settings.
        //
        // `toBeSynchronized` (not just `remote`) is required: Telegram holds notification
        // settings server-side, so a local-only value would be silently overwritten by the
        // next sync, quietly re-enabling notifications. The trade-off is that this does
        // propagate to the volunteer's other clients for *this* account.
        let silenced = MessageNotificationSettings(
            enabled: false,
            displayPreviews: false,
            sound: defaultCloudPeerNotificationSound,
            storySettings: PeerStoryNotificationSettings.default
        )
        let settings = GlobalNotificationSettingsSet(
            privateChats: silenced,
            groupChats: silenced,
            channels: silenced,
            reactionSettings: .default,
            contactsJoined: false
        )
        transaction.updatePreferencesEntry(key: PreferencesKeys.globalNotifications, { _ in
            return PreferencesEntry(GlobalNotificationSettings(toBeSynchronized: settings, remote: settings))
        })
        transaction.globalNotificationSettingsUpdated()
    }
}

