import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

import SyncCore

public func markSuggestedLocalizationAsSeenInteractively(postbox: Postbox, languageCode: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.suggestedLocalization, { current in
            if let current = current as? SuggestedLocalizationEntry {
                if current.languageCode == languageCode, !current.isSeen {
                    return SuggestedLocalizationEntry(languageCode: languageCode, isSeen: true)
                }
            } else {
                return SuggestedLocalizationEntry(languageCode: languageCode, isSeen: true)
            }
            return current
        })
    }
}
