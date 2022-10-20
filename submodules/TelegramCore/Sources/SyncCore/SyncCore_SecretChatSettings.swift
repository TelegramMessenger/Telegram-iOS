import Foundation
import Postbox


public struct SecretChatSettings: Equatable, Codable {
    public private(set) var acceptOnThisDevice: Bool
    
    public static var defaultSettings: SecretChatSettings {
        return SecretChatSettings(acceptOnThisDevice: true)
    }
    
    public init(acceptOnThisDevice: Bool) {
        self.acceptOnThisDevice = acceptOnThisDevice
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.acceptOnThisDevice = ((try? container.decode(Int32.self, forKey: "acceptOnThisDevice")) ?? 1) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.acceptOnThisDevice ? 1 : 0) as Int32, forKey: "acceptOnThisDevice")
    }
}
