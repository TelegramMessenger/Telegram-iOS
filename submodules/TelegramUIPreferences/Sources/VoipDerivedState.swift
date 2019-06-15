import Foundation
import Postbox
import SwiftSignalKit

public struct VoipDerivedState: Equatable, PreferencesEntry {
    public var data: Data
    
    public static var `default`: VoipDerivedState {
        return VoipDerivedState(data: Data())
    }
    
    public init(data: Data) {
        self.data = data
    }
    
    public init(decoder: PostboxDecoder) {
        self.data = decoder.decodeDataForKey("data") ?? Data()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeData(self.data, forKey: "data")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoipDerivedState {
            return self == to
        } else {
            return false
        }
    }
}

public func updateVoipDerivedStateInteractively(postbox: Postbox, _ f: @escaping (VoipDerivedState) -> VoipDerivedState) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.voipDerivedState, { entry in
            let currentSettings: VoipDerivedState
            if let entry = entry as? VoipDerivedState {
                currentSettings = entry
            } else {
                currentSettings = .default
            }
            return f(currentSettings)
        })
    }
}
