import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

import SyncCore

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
