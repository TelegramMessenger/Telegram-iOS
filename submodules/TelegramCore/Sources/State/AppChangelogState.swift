import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit


func updateAppChangelogState(transaction: Transaction, _ f: @escaping (AppChangelogState) -> AppChangelogState) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.appChangelogState, { current in
        return PreferencesEntry(f((current?.get(AppChangelogState.self)) ?? AppChangelogState.default))
    })
}
