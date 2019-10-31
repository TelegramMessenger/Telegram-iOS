import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKit
#endif

import SyncCore

func updateAppChangelogState(transaction: Transaction, _ f: @escaping (AppChangelogState) -> AppChangelogState) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.appChangelogState, { current in
        return f((current as? AppChangelogState) ?? AppChangelogState.default)
    })
}
