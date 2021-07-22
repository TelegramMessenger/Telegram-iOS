import Foundation
import Postbox

public struct ContactsSettings: Equatable, PreferencesEntry {
    public var synchronizeContacts: Bool
    
    public static var defaultSettings: ContactsSettings {
        return ContactsSettings(synchronizeContacts: true)
    }
    
    public init(synchronizeContacts: Bool) {
        self.synchronizeContacts = synchronizeContacts
    }
    
    public init(decoder: PostboxDecoder) {
        self.synchronizeContacts = decoder.decodeInt32ForKey("synchronizeContacts", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.synchronizeContacts ? 1 : 0, forKey: "synchronizeContacts")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ContactsSettings {
            return self == to
        } else {
            return false
        }
    }
}
