import SwiftSignalKit
import Postbox

public enum EngineConfiguration {
    public struct Limits: Equatable {
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

        public init(
            maxPinnedChatCount: Int32,
            maxArchivedPinnedChatCount: Int32,
            maxGroupMemberCount: Int32,
            maxSupergroupMemberCount: Int32,
            maxMessageForwardBatchSize: Int32,
            maxSavedGifCount: Int32,
            maxRecentStickerCount: Int32,
            maxMessageEditingInterval: Int32,
            maxMediaCaptionLength: Int32,
            canRemoveIncomingMessagesInPrivateChats: Bool,
            maxMessageRevokeInterval: Int32,
            maxMessageRevokeIntervalInPrivateChats: Int32
        ) {
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
    }
}

extension EngineConfiguration.Limits {
    init(_ limitsConfiguration: LimitsConfiguration) {
        self.init(
            maxPinnedChatCount: limitsConfiguration.maxPinnedChatCount,
            maxArchivedPinnedChatCount: limitsConfiguration.maxArchivedPinnedChatCount,
            maxGroupMemberCount: limitsConfiguration.maxGroupMemberCount,
            maxSupergroupMemberCount: limitsConfiguration.maxSupergroupMemberCount,
            maxMessageForwardBatchSize: limitsConfiguration.maxMessageForwardBatchSize,
            maxSavedGifCount: limitsConfiguration.maxSavedGifCount,
            maxRecentStickerCount: limitsConfiguration.maxRecentStickerCount,
            maxMessageEditingInterval: limitsConfiguration.maxMessageEditingInterval,
            maxMediaCaptionLength: limitsConfiguration.maxMediaCaptionLength,
            canRemoveIncomingMessagesInPrivateChats: limitsConfiguration.canRemoveIncomingMessagesInPrivateChats,
            maxMessageRevokeInterval: limitsConfiguration.maxMessageRevokeInterval,
            maxMessageRevokeIntervalInPrivateChats: limitsConfiguration.maxMessageRevokeIntervalInPrivateChats
        )
    }
}

public extension TelegramEngine.EngineData.Item {
    enum Configuration {
        public struct Limits: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = EngineConfiguration.Limits

            public init() {
            }

            var key: PostboxViewKey {
                return .preferences(keys: Set([PreferencesKeys.limitsConfiguration]))
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? PreferencesView else {
                    preconditionFailure()
                }
                guard let limitsConfiguration = view.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration else {
                    return EngineConfiguration.Limits(LimitsConfiguration.defaultValue)
                }
                return EngineConfiguration.Limits(limitsConfiguration)
            }
        }
    }
}
