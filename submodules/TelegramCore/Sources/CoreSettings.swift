import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

import SyncCore

public final class CoreSettings: PreferencesEntry, Equatable {
    public let fastForward: Bool
    
    public static var defaultSettings = CoreSettings(fastForward: true)
    
    public init(fastForward: Bool) {
        self.fastForward = fastForward
    }
    
    public init(decoder: PostboxDecoder) {
        self.fastForward = decoder.decodeInt32ForKey("fastForward", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.fastForward ? 1 : 0, forKey: "fastForward")
    }
    
    public func withUpdatedFastForward(_ fastForward: Bool) -> CoreSettings {
        return CoreSettings(fastForward: fastForward)
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? CoreSettings else {
            return false
        }
        
        return self == to
    }
    
    public static func ==(lhs: CoreSettings, rhs: CoreSettings) -> Bool {
        if lhs.fastForward != rhs.fastForward {
            return false
        }
        return true
    }
}

public func updateCoreSettings(postbox: Postbox, _ f: @escaping (CoreSettings) -> CoreSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var updated: CoreSettings?
        transaction.updatePreferencesEntry(key: PreferencesKeys.coreSettings, { current in
            if let current = current as? CoreSettings {
                updated = f(current)
                return updated
            } else {
                updated = f(CoreSettings.defaultSettings)
                return updated
            }
        })
    }
}

