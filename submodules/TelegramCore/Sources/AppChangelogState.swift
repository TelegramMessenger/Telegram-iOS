import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

import SyncCore

func updateAppChangelogState(transaction: Transaction, _ f: @escaping (AppChangelogState) -> AppChangelogState) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.appChangelogState, { current in
        return f((current as? AppChangelogState) ?? AppChangelogState.default)
    })
}
