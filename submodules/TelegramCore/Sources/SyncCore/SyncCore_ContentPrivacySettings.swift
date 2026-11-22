import Postbox

public final class ContentPrivacySettings: Codable {
    public let enableSecretChatWebpagePreviews: Bool?
    
    public static var defaultSettings = ContentPrivacySettings(enableSecretChatWebpagePreviews: nil)
    
    public init(enableSecretChatWebpagePreviews: Bool?) {
        self.enableSecretChatWebpagePreviews = enableSecretChatWebpagePreviews
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let value = try? container.decodeIfPresent(Int32.self, forKey: "enableSecretChatWebpagePreviews") {
            self.enableSecretChatWebpagePreviews = value != 0
        } else {
            self.enableSecretChatWebpagePreviews = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let enableSecretChatWebpagePreviews = self.enableSecretChatWebpagePreviews {
            try container.encode((enableSecretChatWebpagePreviews ? 1 : 0) as Int32, forKey: "enableSecretChatWebpagePreviews")
        } else {
            try container.encodeNil(forKey: "enableSecretChatWebpagePreviews")
        }
    }
    
    public func withUpdatedEnableSecretChatWebpagePreviews(_ enableSecretChatWebpagePreviews: Bool) -> ContentPrivacySettings {
        return ContentPrivacySettings(enableSecretChatWebpagePreviews: enableSecretChatWebpagePreviews)
    }
}
