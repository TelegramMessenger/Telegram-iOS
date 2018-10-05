import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
#else
import Postbox
import SwiftSignalKit
import MtProtoKitDynamic
#endif

struct AppChangelogState: PreferencesEntry, Equatable {
    var checkedVersion: String
    var previousVersion: String
    
    static var `default` = AppChangelogState(checkedVersion: "", previousVersion: "5.0.8")
    
    init(checkedVersion: String, previousVersion: String) {
        self.checkedVersion = checkedVersion
        self.previousVersion = previousVersion
    }
    
    init(decoder: PostboxDecoder) {
        self.checkedVersion = decoder.decodeStringForKey("checkedVersion", orElse: "")
        self.previousVersion = decoder.decodeStringForKey("previousVersion", orElse: "")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.checkedVersion, forKey: "checkedVersion")
        encoder.encodeString(self.previousVersion, forKey: "previousVersion")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? AppChangelogState else {
            return false
        }
        
        return self == to
    }
}

func updateAppChangelogState(transaction: Transaction, _ f: @escaping (AppChangelogState) -> AppChangelogState) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.appChangelogState, { current in
        return f((current as? AppChangelogState) ?? AppChangelogState.default)
    })
}
