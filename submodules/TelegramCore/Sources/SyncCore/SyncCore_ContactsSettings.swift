import Foundation
import Postbox

public struct ContactsSettings: Codable {
    public var synchronizeContacts: Bool
    
    public static var defaultSettings: ContactsSettings {
        return ContactsSettings(synchronizeContacts: true)
    }
    
    public init(synchronizeContacts: Bool) {
        self.synchronizeContacts = synchronizeContacts
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.synchronizeContacts = ((try? container.decode(Int32.self, forKey: "synchronizeContacts")) ?? 0) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.synchronizeContacts ? 1 : 0) as Int32, forKey: "synchronizeContacts")
    }
}
