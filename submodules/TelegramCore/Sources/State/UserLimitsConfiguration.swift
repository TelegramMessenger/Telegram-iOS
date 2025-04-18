import Postbox
import SwiftSignalKit

public struct UserLimitsConfiguration: Equatable {
    public var maxPinnedChatCount: Int32
    public var maxPinnedSavedChatCount: Int32
    public var maxArchivedPinnedChatCount: Int32
    public var maxChannelsCount: Int32
    public var maxPublicLinksCount: Int32
    public var maxSavedGifCount: Int32
    public var maxFavedStickerCount: Int32
    public var maxFoldersCount: Int32
    public var maxFolderChatsCount: Int32
    public var maxCaptionLength: Int32
    public var maxUploadFileParts: Int32
    public var maxAboutLength: Int32
    public var maxAnimatedEmojisInText: Int32
    public var maxReactionsPerMessage: Int32
    public var maxSharedFolderInviteLinks: Int32
    public var maxSharedFolderJoin: Int32
    public var maxStoryCaptionLength: Int32
    public var maxExpiringStoriesCount: Int32
    public var maxStoriesWeeklyCount: Int32
    public var maxStoriesMonthlyCount: Int32
    public var maxStoriesSuggestedReactions: Int32
    public var maxStoriesLinksCount: Int32
    public var maxGiveawayChannelsCount: Int32
    public var maxGiveawayCountriesCount: Int32
    public var maxGiveawayPeriodSeconds: Int32
    public var maxChannelRecommendationsCount: Int32
    
    public static var defaultValue: UserLimitsConfiguration {
        return UserLimitsConfiguration(
            maxPinnedChatCount: 5,
            maxPinnedSavedChatCount: 5,
            maxArchivedPinnedChatCount: 100,
            maxChannelsCount: 500,
            maxPublicLinksCount: 10,
            maxSavedGifCount: 200,
            maxFavedStickerCount: 5,
            maxFoldersCount: 10,
            maxFolderChatsCount: 100,
            maxCaptionLength: 1024,
            maxUploadFileParts: 4000,
            maxAboutLength: 70,
            maxAnimatedEmojisInText: 10,
            maxReactionsPerMessage: 1,
            maxSharedFolderInviteLinks: 3,
            maxSharedFolderJoin: 2,
            maxStoryCaptionLength: 200,
            maxExpiringStoriesCount: 3,
            maxStoriesWeeklyCount: 7,
            maxStoriesMonthlyCount: 30,
            maxStoriesSuggestedReactions: 1,
            maxStoriesLinksCount: 3,
            maxGiveawayChannelsCount: 10,
            maxGiveawayCountriesCount: 10,
            maxGiveawayPeriodSeconds: 86400 * 31,
            maxChannelRecommendationsCount: 10
        )
    }

    public init(
        maxPinnedChatCount: Int32,
        maxPinnedSavedChatCount: Int32,
        maxArchivedPinnedChatCount: Int32,
        maxChannelsCount: Int32,
        maxPublicLinksCount: Int32,
        maxSavedGifCount: Int32,
        maxFavedStickerCount: Int32,
        maxFoldersCount: Int32,
        maxFolderChatsCount: Int32,
        maxCaptionLength: Int32,
        maxUploadFileParts: Int32,
        maxAboutLength: Int32,
        maxAnimatedEmojisInText: Int32,
        maxReactionsPerMessage: Int32,
        maxSharedFolderInviteLinks: Int32,
        maxSharedFolderJoin: Int32,
        maxStoryCaptionLength: Int32,
        maxExpiringStoriesCount: Int32,
        maxStoriesWeeklyCount: Int32,
        maxStoriesMonthlyCount: Int32,
        maxStoriesSuggestedReactions: Int32,
        maxStoriesLinksCount: Int32,
        maxGiveawayChannelsCount: Int32,
        maxGiveawayCountriesCount: Int32,
        maxGiveawayPeriodSeconds: Int32,
        maxChannelRecommendationsCount: Int32
    ) {
        self.maxPinnedChatCount = maxPinnedChatCount
        self.maxPinnedSavedChatCount = maxPinnedSavedChatCount
        self.maxArchivedPinnedChatCount = maxArchivedPinnedChatCount
        self.maxChannelsCount = maxChannelsCount
        self.maxPublicLinksCount = maxPublicLinksCount
        self.maxSavedGifCount = maxSavedGifCount
        self.maxFavedStickerCount = maxFavedStickerCount
        self.maxFoldersCount = maxFoldersCount
        self.maxFolderChatsCount = maxFolderChatsCount
        self.maxCaptionLength = maxCaptionLength
        self.maxUploadFileParts = maxUploadFileParts
        self.maxAboutLength = maxAboutLength
        self.maxAnimatedEmojisInText = maxAnimatedEmojisInText
        self.maxReactionsPerMessage = maxReactionsPerMessage
        self.maxSharedFolderInviteLinks = maxSharedFolderInviteLinks
        self.maxSharedFolderJoin = maxSharedFolderJoin
        self.maxStoryCaptionLength = maxStoryCaptionLength
        self.maxExpiringStoriesCount = maxExpiringStoriesCount
        self.maxStoriesWeeklyCount = maxStoriesWeeklyCount
        self.maxStoriesMonthlyCount = maxStoriesMonthlyCount
        self.maxStoriesSuggestedReactions = maxStoriesSuggestedReactions
        self.maxStoriesLinksCount = maxStoriesLinksCount
        self.maxGiveawayChannelsCount = maxGiveawayChannelsCount
        self.maxGiveawayCountriesCount = maxGiveawayCountriesCount
        self.maxGiveawayPeriodSeconds = maxGiveawayPeriodSeconds
        self.maxChannelRecommendationsCount = maxChannelRecommendationsCount
    }
}

extension UserLimitsConfiguration {
    init(appConfiguration: AppConfiguration, isPremium: Bool) {
        let keySuffix = isPremium ? "_premium" : "_default"
        var defaultValue = UserLimitsConfiguration.defaultValue
        if isPremium {
            defaultValue.maxPinnedSavedChatCount = 100
        }
        
        func getValue(_ key: String, orElse defaultValue: Int32) -> Int32 {
            if let value = appConfiguration.data?[key + keySuffix] as? Double {
                return Int32(value)
            } else {
                return defaultValue
            }
        }
        
        func getGeneralValue(_ key: String, orElse defaultValue: Int32) -> Int32 {
            if let value = appConfiguration.data?[key] as? Double {
                return Int32(value)
            } else {
                return defaultValue
            }
        }
        
        self.maxPinnedChatCount = getValue("dialogs_pinned_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxPinnedSavedChatCount = getValue("saved_dialogs_pinned_limit", orElse: defaultValue.maxPinnedSavedChatCount)
        self.maxArchivedPinnedChatCount = getValue("dialogs_folder_pinned_limit", orElse: defaultValue.maxArchivedPinnedChatCount)
        self.maxChannelsCount = getValue("channels_limit", orElse: defaultValue.maxChannelsCount)
        self.maxPublicLinksCount = getValue("channels_public_limit", orElse: defaultValue.maxPublicLinksCount)
        self.maxSavedGifCount = getValue("saved_gifs_limit", orElse: defaultValue.maxSavedGifCount)
        self.maxFavedStickerCount = getValue("stickers_faved_limit", orElse: defaultValue.maxFavedStickerCount)
        self.maxFoldersCount = getValue("dialog_filters_limit", orElse: defaultValue.maxFoldersCount)
        self.maxFolderChatsCount = getValue("dialog_filters_chats_limit", orElse: defaultValue.maxFolderChatsCount)
        self.maxCaptionLength = getValue("caption_length_limit", orElse: defaultValue.maxCaptionLength)
        self.maxUploadFileParts = getValue("upload_max_fileparts", orElse: defaultValue.maxUploadFileParts)
        self.maxAboutLength = getValue("about_length_limit", orElse: defaultValue.maxAboutLength)
        self.maxAnimatedEmojisInText = getGeneralValue("message_animated_emoji_max", orElse: defaultValue.maxAnimatedEmojisInText)
        self.maxReactionsPerMessage = getValue("reactions_user_max", orElse: 1)
        self.maxSharedFolderInviteLinks = getValue("chatlist_invites_limit", orElse: isPremium ? 100 : 3)
        self.maxSharedFolderJoin = getValue("chatlists_joined_limit", orElse: isPremium ? 100 : 2)
        self.maxStoryCaptionLength = getValue("story_caption_length_limit", orElse: defaultValue.maxStoryCaptionLength)
        self.maxExpiringStoriesCount = getValue("story_expiring_limit", orElse: defaultValue.maxExpiringStoriesCount)
        self.maxStoriesWeeklyCount = getValue("stories_sent_weekly_limit", orElse: defaultValue.maxStoriesWeeklyCount)
        self.maxStoriesMonthlyCount = getValue("stories_sent_monthly_limit", orElse: defaultValue.maxStoriesMonthlyCount)
        self.maxStoriesSuggestedReactions = getValue("stories_suggested_reactions_limit", orElse: defaultValue.maxStoriesMonthlyCount)
        self.maxStoriesLinksCount = getGeneralValue("stories_area_url_max", orElse: defaultValue.maxStoriesLinksCount)
        self.maxGiveawayChannelsCount = getGeneralValue("giveaway_add_peers_max", orElse: defaultValue.maxGiveawayChannelsCount)
        self.maxGiveawayCountriesCount = getGeneralValue("giveaway_countries_max", orElse: defaultValue.maxGiveawayCountriesCount)
        self.maxGiveawayPeriodSeconds = getGeneralValue("giveaway_period_max", orElse: defaultValue.maxGiveawayPeriodSeconds)
        self.maxChannelRecommendationsCount = getValue("recommended_channels_limit", orElse: defaultValue.maxChannelRecommendationsCount)
    }
}
