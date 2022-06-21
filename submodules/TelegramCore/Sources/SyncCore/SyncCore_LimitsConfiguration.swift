import Postbox

public struct LimitsConfiguration: Codable, Equatable {
    public static let timeIntervalForever: Int32 = 0x7fffffff
    
    public var maxPinnedChatCount: Int32
    public var maxArchivedPinnedChatCount: Int32
    public var maxGroupMemberCount: Int32
    public var maxSupergroupMemberCount: Int32
    public var maxMessageForwardBatchSize: Int32
    public var maxSavedGifCount: Int32
    public var maxRecentStickerCount: Int32
    public var maxMessageEditingInterval: Int32
    public var maxMediaCaptionLength: Int32
    public var canRemoveIncomingMessagesInPrivateChats: Bool
    public var maxMessageRevokeInterval: Int32
    public var maxMessageRevokeIntervalInPrivateChats: Int32
    
    public static var defaultValue: LimitsConfiguration {
        return LimitsConfiguration(maxPinnedChatCount: 5, maxArchivedPinnedChatCount: 20, maxGroupMemberCount: 200, maxSupergroupMemberCount: 200000, maxMessageForwardBatchSize: 50, maxSavedGifCount: 200, maxRecentStickerCount: 20, maxMessageEditingInterval: 2 * 24 * 60 * 60, maxMediaCaptionLength: 1000, canRemoveIncomingMessagesInPrivateChats: false, maxMessageRevokeInterval: 2 * 24 * 60 * 60, maxMessageRevokeIntervalInPrivateChats: 2 * 24 * 60 * 60)
    }
    
    public init(maxPinnedChatCount: Int32, maxArchivedPinnedChatCount: Int32, maxGroupMemberCount: Int32, maxSupergroupMemberCount: Int32, maxMessageForwardBatchSize: Int32, maxSavedGifCount: Int32, maxRecentStickerCount: Int32, maxMessageEditingInterval: Int32, maxMediaCaptionLength: Int32, canRemoveIncomingMessagesInPrivateChats: Bool, maxMessageRevokeInterval: Int32, maxMessageRevokeIntervalInPrivateChats: Int32) {
        self.maxPinnedChatCount = maxPinnedChatCount
        self.maxArchivedPinnedChatCount = maxArchivedPinnedChatCount
        self.maxGroupMemberCount = maxGroupMemberCount
        self.maxSupergroupMemberCount = maxSupergroupMemberCount
        self.maxMessageForwardBatchSize = maxMessageForwardBatchSize
        self.maxSavedGifCount = maxSavedGifCount
        self.maxRecentStickerCount = maxRecentStickerCount
        self.maxMessageEditingInterval = maxMessageEditingInterval
        self.maxMediaCaptionLength = maxMediaCaptionLength
        self.canRemoveIncomingMessagesInPrivateChats = canRemoveIncomingMessagesInPrivateChats
        self.maxMessageRevokeInterval = maxMessageRevokeInterval
        self.maxMessageRevokeIntervalInPrivateChats = maxMessageRevokeIntervalInPrivateChats
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.maxPinnedChatCount = (try? container.decodeIfPresent(Int32.self, forKey: "maxPinnedChatCount")) ?? 5
        self.maxArchivedPinnedChatCount = (try? container.decodeIfPresent(Int32.self, forKey: "maxArchivedPinnedChatCount")) ?? 20
        self.maxGroupMemberCount = (try? container.decodeIfPresent(Int32.self, forKey: "maxGroupMemberCount")) ?? 200
        self.maxSupergroupMemberCount = (try? container.decodeIfPresent(Int32.self, forKey: "maxSupergroupMemberCount")) ?? 5000
        self.maxMessageForwardBatchSize = (try? container.decodeIfPresent(Int32.self, forKey: "maxMessageForwardBatchSize")) ?? 50
        self.maxSavedGifCount = (try? container.decodeIfPresent(Int32.self, forKey: "maxSavedGifCount")) ?? 200
        self.maxRecentStickerCount = (try? container.decodeIfPresent(Int32.self, forKey: "maxRecentStickerCount")) ?? 20
        self.maxMessageEditingInterval = (try? container.decodeIfPresent(Int32.self, forKey: "maxMessageEditingInterval")) ?? (2 * 24 * 60 * 60)
        self.maxMediaCaptionLength = (try? container.decodeIfPresent(Int32.self, forKey: "maxMediaCaptionLength")) ?? 1000
        self.canRemoveIncomingMessagesInPrivateChats = (try? container.decodeIfPresent(Int32.self, forKey: "canRemoveIncomingMessagesInPrivateChats") ?? 0) != 0
        self.maxMessageRevokeInterval = (try? container.decodeIfPresent(Int32.self, forKey: "maxMessageRevokeInterval")) ?? (2 * 24 * 60 * 60)
        self.maxMessageRevokeIntervalInPrivateChats = (try? container.decodeIfPresent(Int32.self, forKey: "maxMessageRevokeIntervalInPrivateChats")) ?? (2 * 24 * 60 * 60)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.maxPinnedChatCount, forKey: "maxPinnedChatCount")
        try container.encode(self.maxArchivedPinnedChatCount, forKey: "maxArchivedPinnedChatCount")
        try container.encode(self.maxGroupMemberCount, forKey: "maxGroupMemberCount")
        try container.encode(self.maxSupergroupMemberCount, forKey: "maxSupergroupMemberCount")
        try container.encode(self.maxMessageForwardBatchSize, forKey: "maxMessageForwardBatchSize")
        try container.encode(self.maxSavedGifCount, forKey: "maxSavedGifCount")
        try container.encode(self.maxRecentStickerCount, forKey: "maxRecentStickerCount")
        try container.encode(self.maxMessageEditingInterval, forKey: "maxMessageEditingInterval")
        try container.encode(self.maxMediaCaptionLength, forKey: "maxMediaCaptionLength")
        try container.encode((self.canRemoveIncomingMessagesInPrivateChats ? 1 : 0) as Int32, forKey: "canRemoveIncomingMessagesInPrivateChats")
        try container.encode(self.maxMessageRevokeInterval, forKey: "maxMessageRevokeInterval")
        try container.encode(self.maxMessageRevokeIntervalInPrivateChats, forKey: "maxMessageRevokeIntervalInPrivateChats")
    }
}
