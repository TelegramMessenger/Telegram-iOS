import Postbox

public final class ContentPrivacySettings: PreferencesEntry, Equatable {
    public let enableSecretChatWebpagePreviews: Bool?
    
    public static var defaultSettings = ContentPrivacySettings(enableSecretChatWebpagePreviews: nil)
    
    public init(enableSecretChatWebpagePreviews: Bool?) {
        self.enableSecretChatWebpagePreviews = enableSecretChatWebpagePreviews
    }
    
    public init(decoder: PostboxDecoder) {
        self.enableSecretChatWebpagePreviews = decoder.decodeOptionalInt32ForKey("enableSecretChatWebpagePreviews").flatMap { $0 != 0 }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let enableSecretChatWebpagePreviews = self.enableSecretChatWebpagePreviews {
            encoder.encodeInt32(enableSecretChatWebpagePreviews ? 1 : 0, forKey: "enableSecretChatWebpagePreviews")
        } else {
            encoder.encodeNil(forKey: "enableSecretChatWebpagePreviews")
        }
    }
    
    public func withUpdatedEnableSecretChatWebpagePreviews(_ enableSecretChatWebpagePreviews: Bool) -> ContentPrivacySettings {
        return ContentPrivacySettings(enableSecretChatWebpagePreviews: enableSecretChatWebpagePreviews)
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? ContentPrivacySettings else {
            return false
        }
        
        return self == to
    }
    
    public static func ==(lhs: ContentPrivacySettings, rhs: ContentPrivacySettings) -> Bool {
        if lhs.enableSecretChatWebpagePreviews != rhs.enableSecretChatWebpagePreviews {
            return false
        }
        return true
    }
}