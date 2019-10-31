import Foundation
import Postbox
import SwiftSignalKit

public struct IntentsSettings: PreferencesEntry, Equatable {
    public let initiallyReset: Bool
    
    public static var defaultSettings: IntentsSettings {
        return IntentsSettings(initiallyReset: false)
    }
    
    public init(initiallyReset: Bool) {
        self.initiallyReset = initiallyReset
    }
    
    public init(decoder: PostboxDecoder) {
        self.initiallyReset = decoder.decodeBoolForKey("initiallyReset", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(self.initiallyReset, forKey: "initiallyReset")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? IntentsSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: IntentsSettings, rhs: IntentsSettings) -> Bool {
        return lhs.initiallyReset == rhs.initiallyReset
    }
}
