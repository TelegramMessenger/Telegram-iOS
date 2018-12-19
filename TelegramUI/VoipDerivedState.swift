import Foundation
import Postbox
import SwiftSignalKit

struct VoipDerivedState: Equatable, PreferencesEntry {
    var data: Data
    
    static var `default`: VoipDerivedState {
        return VoipDerivedState(data: Data())
    }
    
    init(data: Data) {
        self.data = data
    }
    
    init(decoder: PostboxDecoder) {
        self.data = decoder.decodeDataForKey("data") ?? Data()
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeData(self.data, forKey: "data")
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? VoipDerivedState {
            return self == to
        } else {
            return false
        }
    }
}

func updateVoipDerivedStateInteractively(postbox: Postbox, _ f: @escaping (VoipDerivedState) -> VoipDerivedState) -> Signal<Void, NoError> {
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
