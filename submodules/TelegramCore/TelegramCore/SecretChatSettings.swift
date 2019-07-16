import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public struct SecretChatSettings: PreferencesEntry, Equatable {
    public var acceptOnThisDevice: Bool
    
    public static var defaultSettings = SecretChatSettings(acceptOnThisDevice: true)
    
    public init(acceptOnThisDevice: Bool) {
        self.acceptOnThisDevice = acceptOnThisDevice
    }
    
    public init(decoder: PostboxDecoder) {
        self.acceptOnThisDevice = decoder.decodeInt32ForKey("acceptOnThisDevice", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.acceptOnThisDevice ? 1 : 0, forKey: "fastForward")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? SecretChatSettings else {
            return false
        }
        
        return self == to
    }
}

public func updateSecretChatSettings(postbox: Postbox, _ f: @escaping (SecretChatSettings) -> SecretChatSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.secretChatSettings, { current in
            if let current = current as? SecretChatSettings {
                let updated = f(current)
                return updated
            } else {
                let updated = f(SecretChatSettings.defaultSettings)
                return updated
            }
        })
    }
}

