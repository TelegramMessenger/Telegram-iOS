import Foundation
#if os(macOS)
import PostboxMac
#else
import Postbox
#endif

public enum VoiceCallP2PMode: Int32 {
    case never = 0
    case contacts = 1
    case always = 2
}

public struct VoipConfiguration: PreferencesEntry, Equatable {
    public var defaultP2PMode: VoiceCallP2PMode
    public var serializedData: String?
    
    public static var defaultValue: VoipConfiguration {
        return VoipConfiguration(defaultP2PMode: .contacts, serializedData: nil)
    }
    
    init(defaultP2PMode: VoiceCallP2PMode, serializedData: String?) {
        self.defaultP2PMode = defaultP2PMode
        self.serializedData = serializedData
    }
    
    public init(decoder: PostboxDecoder) {
        self.defaultP2PMode = VoiceCallP2PMode(rawValue: decoder.decodeInt32ForKey("defaultP2PMode", orElse: 1)) ?? .contacts
        self.serializedData = decoder.decodeOptionalStringForKey("serializedData")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.defaultP2PMode.rawValue, forKey: "defaultP2PMode")
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

public func currentVoipConfiguration(transaction: Transaction) -> VoipConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.voipConfiguration) as? VoipConfiguration {
        return entry
    } else {
        return VoipConfiguration.defaultValue
    }
}

func updateVoipConfiguration(transaction: Transaction, _ f: (VoipConfiguration) -> VoipConfiguration) {
    let current = currentVoipConfiguration(transaction: transaction)
    let updated = f(current)
    if updated != current {
        transaction.setPreferencesEntry(key: PreferencesKeys.voipConfiguration, value: updated)
    }
}
