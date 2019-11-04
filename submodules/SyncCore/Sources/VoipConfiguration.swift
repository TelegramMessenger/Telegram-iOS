import Foundation
import Postbox

public enum VoiceCallP2PMode: Int32 {
    case never = 0
    case contacts = 1
    case always = 2
}

public struct VoipConfiguration: PreferencesEntry, Equatable {
    public var serializedData: String?
    
    public static var defaultValue: VoipConfiguration {
        return VoipConfiguration(serializedData: nil)
    }
    
    init(serializedData: String?) {
        self.serializedData = serializedData
    }
    
    public init(decoder: PostboxDecoder) {
        self.serializedData = decoder.decodeOptionalStringForKey("serializedData")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let serializedData = self.serializedData {
            encoder.encodeString(serializedData, forKey: "serializedData")
        } else {
            encoder.encodeNil(forKey: "serializedData")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? VoipConfiguration else {
            return false
        }
        return self == to
    }
}
