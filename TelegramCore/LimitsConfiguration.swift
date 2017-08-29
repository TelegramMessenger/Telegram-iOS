import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class LimitsConfiguration: PreferencesEntry {
    public let maxGroupMemberCount: Int32
    public let maxSupergroupMemberCount: Int32
    public let maxMessageForwardBatchSize: Int32
    public let maxSavedGifCount: Int32
    public let maxRecentStickerCount: Int32
    public let maxMessageEditingInterval: Int32
    
    static var defaultValue: LimitsConfiguration {
        return LimitsConfiguration(maxGroupMemberCount: 200, maxSupergroupMemberCount: 5000, maxMessageForwardBatchSize: 50, maxSavedGifCount: 200, maxRecentStickerCount: 20, maxMessageEditingInterval: 2 * 24 * 60 * 60)
    }
    
    init(maxGroupMemberCount: Int32, maxSupergroupMemberCount: Int32, maxMessageForwardBatchSize: Int32, maxSavedGifCount: Int32, maxRecentStickerCount: Int32, maxMessageEditingInterval: Int32) {
        self.maxGroupMemberCount = maxGroupMemberCount
        self.maxSupergroupMemberCount = maxSupergroupMemberCount
        self.maxMessageForwardBatchSize = maxMessageForwardBatchSize
        self.maxSavedGifCount = maxSavedGifCount
        self.maxRecentStickerCount = maxRecentStickerCount
        self.maxMessageEditingInterval = maxMessageEditingInterval
    }
    
    public init(decoder: PostboxDecoder) {
        self.maxGroupMemberCount = decoder.decodeInt32ForKey("maxGroupMemberCount", orElse: 200)
        self.maxSupergroupMemberCount = decoder.decodeInt32ForKey("maxSupergroupMemberCount", orElse: 5000)
        self.maxMessageForwardBatchSize = decoder.decodeInt32ForKey("maxMessageForwardBatchSize", orElse: 50)
        self.maxSavedGifCount = decoder.decodeInt32ForKey("maxSavedGifCount", orElse: 200)
        self.maxRecentStickerCount = decoder.decodeInt32ForKey("maxRecentStickerCount", orElse: 20)
        self.maxMessageEditingInterval = decoder.decodeInt32ForKey("maxMessageEditingInterval", orElse: 2 * 24 * 60 * 60)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.maxGroupMemberCount, forKey: "maxGroupMemberCount")
        encoder.encodeInt32(self.maxSupergroupMemberCount, forKey: "maxSupergroupMemberCount")
        encoder.encodeInt32(self.maxMessageForwardBatchSize, forKey: "maxMessageForwardBatchSize")
        encoder.encodeInt32(self.maxSavedGifCount, forKey: "maxSavedGifCount")
        encoder.encodeInt32(self.maxRecentStickerCount, forKey: "maxRecentStickerCount")
        encoder.encodeInt32(self.maxMessageEditingInterval, forKey: "maxMessageEditingInterval")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? LimitsConfiguration else {
            return false
        }
        if self.maxGroupMemberCount != to.maxGroupMemberCount {
            return false
        }
        if self.maxSupergroupMemberCount != to.maxSupergroupMemberCount {
            return false
        }
        if self.maxMessageForwardBatchSize != to.maxMessageForwardBatchSize {
            return false
        }
        if self.maxSavedGifCount != to.maxSavedGifCount {
            return false
        }
        if self.maxRecentStickerCount != to.maxRecentStickerCount {
            return false
        }
        if self.maxMessageEditingInterval != to.maxMessageEditingInterval {
            return false
        }
        return true
    }
}

public func currentLimitsConfiguration(modifier: Modifier) -> LimitsConfiguration {
    if let entry = modifier.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration {
        return entry
    } else {
        return LimitsConfiguration.defaultValue
    }
}

func updateLimitsConfiguration(modifier: Modifier, configuration: LimitsConfiguration) {
    if !currentLimitsConfiguration(modifier: modifier).isEqual(to: configuration) {
        modifier.setPreferencesEntry(key: PreferencesKeys.limitsConfiguration, value: configuration)
    }
}
