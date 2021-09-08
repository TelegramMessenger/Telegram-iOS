import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit


public func updateContentPrivacySettings(postbox: Postbox, _ f: @escaping (ContentPrivacySettings) -> ContentPrivacySettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var updated: ContentPrivacySettings?
        transaction.updatePreferencesEntry(key: PreferencesKeys.contentPrivacySettings, { current in
            if let current = current as? ContentPrivacySettings {
                updated = f(current)
                return updated
            } else {
                updated = f(ContentPrivacySettings.defaultSettings)
                return updated
            }
        })
    }
}
