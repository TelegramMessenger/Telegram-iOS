import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit


public func updateContentPrivacySettings(postbox: Postbox, _ f: @escaping (ContentPrivacySettings) -> ContentPrivacySettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var updated: ContentPrivacySettings?
        transaction.updatePreferencesEntry(key: PreferencesKeys.contentPrivacySettings, { current in
            if let current = current?.get(ContentPrivacySettings.self) {
                updated = f(current)
                return PreferencesEntry(updated)
            } else {
                updated = f(ContentPrivacySettings.defaultSettings)
                return PreferencesEntry(updated)
            }
        })
    }
}
