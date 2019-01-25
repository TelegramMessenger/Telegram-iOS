import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct LimitsConfiguration: Equatable, PreferencesEntry {
    public var maxGroupMemberCount: Int32
    public var maxSupergroupMemberCount: Int32
    public var maxMessageForwardBatchSize: Int32
    public var maxSavedGifCount: Int32
    public var maxRecentStickerCount: Int32
    public var maxMessageEditingInterval: Int32
    public var maxMediaCaptionLength: Int32
    public var canRemoveIncomingMessagesInPrivateChats: Bool
    
    public static var defaultValue: LimitsConfiguration {
        return LimitsConfiguration(maxGroupMemberCount: 200, maxSupergroupMemberCount: 200000, maxMessageForwardBatchSize: 50, maxSavedGifCount: 200, maxRecentStickerCount: 20, maxMessageEditingInterval: 2 * 24 * 60 * 60, maxMediaCaptionLength: 1000, canRemoveIncomingMessagesInPrivateChats: false)
    }
    
    init(maxGroupMemberCount: Int32, maxSupergroupMemberCount: Int32, maxMessageForwardBatchSize: Int32, maxSavedGifCount: Int32, maxRecentStickerCount: Int32, maxMessageEditingInterval: Int32, maxMediaCaptionLength: Int32, canRemoveIncomingMessagesInPrivateChats: Bool) {
        self.maxGroupMemberCount = maxGroupMemberCount
        self.maxSupergroupMemberCount = maxSupergroupMemberCount
        self.maxMessageForwardBatchSize = maxMessageForwardBatchSize
        self.maxSavedGifCount = maxSavedGifCount
        self.maxRecentStickerCount = maxRecentStickerCount
        self.maxMessageEditingInterval = maxMessageEditingInterval
        self.maxMediaCaptionLength = maxMediaCaptionLength
        self.canRemoveIncomingMessagesInPrivateChats = canRemoveIncomingMessagesInPrivateChats
    }
    
    public init(decoder: PostboxDecoder) {
        self.maxGroupMemberCount = decoder.decodeInt32ForKey("maxGroupMemberCount", orElse: 200)
        self.maxSupergroupMemberCount = decoder.decodeInt32ForKey("maxSupergroupMemberCount", orElse: 5000)
        self.maxMessageForwardBatchSize = decoder.decodeInt32ForKey("maxMessageForwardBatchSize", orElse: 50)
        self.maxSavedGifCount = decoder.decodeInt32ForKey("maxSavedGifCount", orElse: 200)
        self.maxRecentStickerCount = decoder.decodeInt32ForKey("maxRecentStickerCount", orElse: 20)
        self.maxMessageEditingInterval = decoder.decodeInt32ForKey("maxMessageEditingInterval", orElse: 2 * 24 * 60 * 60)
        self.maxMediaCaptionLength = decoder.decodeInt32ForKey("maxMediaCaptionLength", orElse: 1000)
        self.canRemoveIncomingMessagesInPrivateChats = decoder.decodeInt32ForKey("canRemoveIncomingMessagesInPrivateChats", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.maxGroupMemberCount, forKey: "maxGroupMemberCount")
        encoder.encodeInt32(self.maxSupergroupMemberCount, forKey: "maxSupergroupMemberCount")
        encoder.encodeInt32(self.maxMessageForwardBatchSize, forKey: "maxMessageForwardBatchSize")
        encoder.encodeInt32(self.maxSavedGifCount, forKey: "maxSavedGifCount")
        encoder.encodeInt32(self.maxRecentStickerCount, forKey: "maxRecentStickerCount")
        encoder.encodeInt32(self.maxMessageEditingInterval, forKey: "maxMessageEditingInterval")
        encoder.encodeInt32(self.maxMediaCaptionLength, forKey: "maxMediaCaptionLength")
        encoder.encodeInt32(self.canRemoveIncomingMessagesInPrivateChats ? 1 : 0, forKey: "canRemoveIncomingMessagesInPrivateChats")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? LimitsConfiguration else {
            return false
        }
        return self == to
    }
}

public func currentLimitsConfiguration(transaction: Transaction) -> LimitsConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration {
        return entry
    } else {
        return LimitsConfiguration.defaultValue
    }
}

func updateLimitsConfiguration(transaction: Transaction, configuration: LimitsConfiguration) {
    if !currentLimitsConfiguration(transaction: transaction).isEqual(to: configuration) {
        transaction.setPreferencesEntry(key: PreferencesKeys.limitsConfiguration, value: configuration)
    }
}
