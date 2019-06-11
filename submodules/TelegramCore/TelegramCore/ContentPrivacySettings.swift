import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

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

public func updateContentPrivacySettings(postbox: Postbox, _ f: @escaping (ContentPrivacySettings) -> ContentPrivacySettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var updated: ContentPrivacySettings?
        transaction.updatePreferencesEntry(key: PreferencesKeys.contentPrivacySettings, { current in
            if let current = current as? ContentPrivacySettings {
                updated = f(current)
                return updated
            } else {
                updated = f(ContentPrivacySettings.defaultSettings)
                return updated
            }
        })
    }
}
