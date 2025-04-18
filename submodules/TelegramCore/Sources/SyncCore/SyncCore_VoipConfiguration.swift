import Foundation
import Postbox

public enum VoiceCallP2PMode: Int32 {
    case never = 0
    case contacts = 1
    case always = 2
}

public struct VoipConfiguration: Codable, Equatable {
    public var serializedData: String?
    
    public static var defaultValue: VoipConfiguration {
        return VoipConfiguration(serializedData: nil)
    }
    
    init(serializedData: String?) {
        self.serializedData = serializedData
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.serializedData = try container.decodeIfPresent(String.self, forKey: "serializedData")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encodeIfPresent(self.serializedData, forKey: "serializedData")
    }
}
