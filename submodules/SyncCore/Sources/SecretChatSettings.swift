import Foundation
import Postbox


public struct SecretChatSettings: Equatable, PreferencesEntry {
    public private(set) var acceptOnThisDevice: Bool
    
    public static var defaultSettings: SecretChatSettings {
        return SecretChatSettings(acceptOnThisDevice: true)
    }
    
    public init(acceptOnThisDevice: Bool) {
        self.acceptOnThisDevice = acceptOnThisDevice
    }
    
    public init(decoder: PostboxDecoder) {
        self.acceptOnThisDevice = decoder.decodeInt32ForKey("acceptOnThisDevice", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.acceptOnThisDevice ? 1 : 0, forKey: "acceptOnThisDevice")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? SecretChatSettings {
            return self == to
        } else {
            return false
        }
    }
}
