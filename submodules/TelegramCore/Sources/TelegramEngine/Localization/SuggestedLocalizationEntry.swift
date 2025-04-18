import Foundation
import Postbox
import SwiftSignalKit


func _internal_markSuggestedLocalizationAsSeenInteractively(postbox: Postbox, languageCode: String) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.suggestedLocalization, { current in
            if let current = current?.get(SuggestedLocalizationEntry.self) {
                if current.languageCode == languageCode, !current.isSeen {
                    return PreferencesEntry(SuggestedLocalizationEntry(languageCode: languageCode, isSeen: true))
                }
            } else {
                return PreferencesEntry(SuggestedLocalizationEntry(languageCode: languageCode, isSeen: true))
            }
            return current
        })
    }
}
