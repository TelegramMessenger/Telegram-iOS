import Foundation
import TelegramCore

public enum PremiumIntroSource {
    case settings
    case stickers
    case reactions
    case ads
    case upload
    case groupsAndChannels
    case pinnedChats
    case publicLinks
    case savedGifs
    case savedStickers
    case folders
    case chatsPerFolder
    case accounts
    case appIcons
    case about
    case deeplink(String?)
    case profile(EnginePeer.Id)
    case emojiStatus(EnginePeer.Id, Int64, TelegramMediaFile?, LoadedStickerPack?)
    case voiceToText
    case fasterDownload
    case translation
    case stories
    case storiesDownload
    case storiesStealthMode
    case storiesPermanentViews
    case storiesFormatting
    case storiesExpirationDurations
    case storiesSuggestedReactions
    case storiesHigherQuality
    case storiesLinks
    case channelBoost(EnginePeer.Id)
    case nameColor
    case similarChannels
    case wallpapers
    case presence
    case readTime
    case messageTags
    case folderTags
    case animatedEmoji
    case messageEffects
    case todo
    case auth(String)
}

public enum PremiumGiftSource: Equatable {
    case profile
    case attachMenu
    case settings([EnginePeer.Id: TelegramBirthday]?)
    case chatList([EnginePeer.Id: TelegramBirthday]?)
    case stars([EnginePeer.Id: TelegramBirthday]?)
    case starGiftTransfer([EnginePeer.Id: TelegramBirthday]?, StarGiftReference, StarGift.UniqueGift, Int64, Int32?, Bool)
    case channelBoost
    case deeplink(String?)
}

public enum PremiumDemoSubject {
    case doubleLimits
    case moreUpload
    case fasterDownload
    case voiceToText
    case noAds
    case uniqueReactions
    case premiumStickers
    case advancedChatManagement
    case profileBadge
    case animatedUserpics
    case appIcons
    case animatedEmoji
    case emojiStatus
    case translation
    case stories
    case colors
    case wallpapers
    case messageTags
    case lastSeen
    case messagePrivacy
    case folderTags
    case business
    case messageEffects
    case todo
    
    case businessLocation
    case businessHours
    case businessGreetingMessage
    case businessQuickReplies
    case businessAwayMessage
    case businessChatBots
}

public enum PremiumLimitSubject {
    case folders
    case chatsPerFolder
    case pins
    case files
    case accounts
    case linksPerSharedFolder
    case membershipInSharedFolders
    case channels
    case expiringStories
    case multiStories
    case storiesWeekly
    case storiesMonthly
    case storiesChannelBoost(peer: EnginePeer, isCurrent: Bool, level: Int32, currentLevelBoosts: Int32, nextLevelBoosts: Int32?, link: String?, myBoostCount: Int32, canBoostAgain: Bool)
}

public enum PremiumPrivacySubject {
    case presence
    case readTime
}

public enum BoostSubject: Equatable {
    case stories
    case channelReactions(reactionCount: Int32)
    case nameColors(colors: PeerNameColor)
    case nameIcon
    case profileColors(colors: PeerNameColor)
    case profileIcon
    case emojiStatus
    case wallpaper
    case customWallpaper
    case audioTranscription
    case emojiPack
    case noAds
    case wearGift
    case autoTranslate
}

public enum StarsPurchasePurpose: Equatable {
    case generic
    case topUp(requiredStars: Int64, purpose: String?)
    case transfer(peerId: EnginePeer.Id, requiredStars: Int64)
    case reactions(peerId: EnginePeer.Id, requiredStars: Int64)
    case subscription(peerId: EnginePeer.Id, requiredStars: Int64, renew: Bool)
    case gift(peerId: EnginePeer.Id)
    case unlockMedia(requiredStars: Int64)
    case starGift(peerId: EnginePeer.Id, requiredStars: Int64)
    case upgradeStarGift(requiredStars: Int64)
    case transferStarGift(requiredStars: Int64)
    case sendMessage(peerId: EnginePeer.Id, requiredStars: Int64)
    case buyStarGift(requiredStars: Int64)
}

public struct PremiumConfiguration {
    public static var defaultValue: PremiumConfiguration {
        return PremiumConfiguration(
            isPremiumDisabled: false,
            areStarsDisabled: true,
            subscriptionManagementUrl: "",
            showPremiumGiftInAttachMenu: false,
            showPremiumGiftInTextField: false,
            giveawayGiftsPurchaseAvailable: false,
            starsGiftsPurchaseAvailable: false,
            starGiftsPurchaseBlocked: true,
            boostsPerGiftCount: 3,
            audioTransciptionTrialMaxDuration: 300,
            audioTransciptionTrialCount: 2,
            minChannelNameColorLevel: 1,
            minChannelNameIconLevel: 4,
            minChannelProfileColorLevel: 5,
            minChannelProfileIconLevel: 7,
            minChannelEmojiStatusLevel: 8,
            minChannelWallpaperLevel: 9,
            minChannelCustomWallpaperLevel: 10,
            minChannelRestrictAdsLevel: 50,
            minChannelWearGiftLevel: 8,
            minChannelAutoTranslateLevel: 3,
            minGroupProfileIconLevel: 7,
            minGroupEmojiStatusLevel: 8,
            minGroupWallpaperLevel: 9,
            minGroupCustomWallpaperLevel: 9,
            minGroupEmojiPackLevel: 9,
            minGroupAudioTranscriptionLevel: 9
        )
    }
    
    public let isPremiumDisabled: Bool
    public let areStarsDisabled: Bool
    public let subscriptionManagementUrl: String
    public let showPremiumGiftInAttachMenu: Bool
    public let showPremiumGiftInTextField: Bool
    public let giveawayGiftsPurchaseAvailable: Bool
    public let starsGiftsPurchaseAvailable: Bool
    public let starGiftsPurchaseBlocked: Bool
    public let boostsPerGiftCount: Int32
    public let audioTransciptionTrialMaxDuration: Int32
    public let audioTransciptionTrialCount: Int32
    public let minChannelNameColorLevel: Int32
    public let minChannelNameIconLevel: Int32
    public let minChannelProfileColorLevel: Int32
    public let minChannelProfileIconLevel: Int32
    public let minChannelEmojiStatusLevel: Int32
    public let minChannelWallpaperLevel: Int32
    public let minChannelCustomWallpaperLevel: Int32
    public let minChannelRestrictAdsLevel: Int32
    public let minChannelWearGiftLevel: Int32
    public let minChannelAutoTranslateLevel: Int32
    public let minGroupProfileIconLevel: Int32
    public let minGroupEmojiStatusLevel: Int32
    public let minGroupWallpaperLevel: Int32
    public let minGroupCustomWallpaperLevel: Int32
    public let minGroupEmojiPackLevel: Int32
    public let minGroupAudioTranscriptionLevel: Int32
    
    fileprivate init(
        isPremiumDisabled: Bool,
        areStarsDisabled: Bool,
        subscriptionManagementUrl: String,
        showPremiumGiftInAttachMenu: Bool,
        showPremiumGiftInTextField: Bool,
        giveawayGiftsPurchaseAvailable: Bool,
        starsGiftsPurchaseAvailable: Bool,
        starGiftsPurchaseBlocked: Bool,
        boostsPerGiftCount: Int32,
        audioTransciptionTrialMaxDuration: Int32,
        audioTransciptionTrialCount: Int32,
        minChannelNameColorLevel: Int32,
        minChannelNameIconLevel: Int32,
        minChannelProfileColorLevel: Int32,
        minChannelProfileIconLevel: Int32,
        minChannelEmojiStatusLevel: Int32,
        minChannelWallpaperLevel: Int32,
        minChannelCustomWallpaperLevel: Int32,
        minChannelRestrictAdsLevel: Int32,
        minChannelWearGiftLevel: Int32,
        minChannelAutoTranslateLevel: Int32,
        minGroupProfileIconLevel: Int32,
        minGroupEmojiStatusLevel: Int32,
        minGroupWallpaperLevel: Int32,
        minGroupCustomWallpaperLevel: Int32,
        minGroupEmojiPackLevel: Int32,
        minGroupAudioTranscriptionLevel: Int32
    ) {
        self.isPremiumDisabled = isPremiumDisabled
        self.areStarsDisabled = areStarsDisabled
        self.subscriptionManagementUrl = subscriptionManagementUrl
        self.showPremiumGiftInAttachMenu = showPremiumGiftInAttachMenu
        self.showPremiumGiftInTextField = showPremiumGiftInTextField
        self.giveawayGiftsPurchaseAvailable = giveawayGiftsPurchaseAvailable
        self.starsGiftsPurchaseAvailable = starsGiftsPurchaseAvailable
        self.starGiftsPurchaseBlocked = starGiftsPurchaseBlocked
        self.boostsPerGiftCount = boostsPerGiftCount
        self.audioTransciptionTrialMaxDuration = audioTransciptionTrialMaxDuration
        self.audioTransciptionTrialCount = audioTransciptionTrialCount
        self.minChannelNameColorLevel = minChannelNameColorLevel
        self.minChannelNameIconLevel = minChannelNameIconLevel
        self.minChannelProfileColorLevel = minChannelProfileColorLevel
        self.minChannelProfileIconLevel = minChannelProfileIconLevel
        self.minChannelEmojiStatusLevel = minChannelEmojiStatusLevel
        self.minChannelWallpaperLevel = minChannelWallpaperLevel
        self.minChannelCustomWallpaperLevel = minChannelCustomWallpaperLevel
        self.minChannelRestrictAdsLevel = minChannelRestrictAdsLevel
        self.minChannelWearGiftLevel = minChannelWearGiftLevel
        self.minChannelAutoTranslateLevel = minChannelAutoTranslateLevel
        self.minGroupProfileIconLevel = minGroupProfileIconLevel
        self.minGroupEmojiStatusLevel = minGroupEmojiStatusLevel
        self.minGroupWallpaperLevel = minGroupWallpaperLevel
        self.minGroupCustomWallpaperLevel = minGroupCustomWallpaperLevel
        self.minGroupEmojiPackLevel = minGroupEmojiPackLevel
        self.minGroupAudioTranscriptionLevel = minGroupAudioTranscriptionLevel
    }
    
    public static func with(appConfiguration: AppConfiguration) -> PremiumConfiguration {
        let defaultValue = self.defaultValue
        if let data = appConfiguration.data {
            func get(_ value: Any?) -> Int32? {
                return (value as? Double).flatMap(Int32.init)
            }
            return PremiumConfiguration(
                isPremiumDisabled: data["premium_purchase_blocked"] as? Bool ?? defaultValue.isPremiumDisabled,
                areStarsDisabled: data["stars_purchase_blocked"] as? Bool ?? defaultValue.areStarsDisabled,
                subscriptionManagementUrl: data["premium_manage_subscription_url"] as? String ?? "",
                showPremiumGiftInAttachMenu: data["premium_gift_attach_menu_icon"] as? Bool ?? defaultValue.showPremiumGiftInAttachMenu,
                showPremiumGiftInTextField: data["premium_gift_text_field_icon"] as? Bool ?? defaultValue.showPremiumGiftInTextField,
                giveawayGiftsPurchaseAvailable: data["giveaway_gifts_purchase_available"] as? Bool ?? defaultValue.giveawayGiftsPurchaseAvailable,
                starsGiftsPurchaseAvailable: data["stars_gifts_enabled"] as? Bool ?? defaultValue.starsGiftsPurchaseAvailable,
                starGiftsPurchaseBlocked: data["stargifts_blocked"] as? Bool ?? defaultValue.starGiftsPurchaseBlocked,
                boostsPerGiftCount: get(data["boosts_per_sent_gift"]) ?? defaultValue.boostsPerGiftCount,
                audioTransciptionTrialMaxDuration: get(data["transcribe_audio_trial_duration_max"]) ?? defaultValue.audioTransciptionTrialMaxDuration,
                audioTransciptionTrialCount: get(data["transcribe_audio_trial_weekly_number"]) ?? defaultValue.audioTransciptionTrialCount,
                minChannelNameColorLevel: get(data["channel_color_level_min"]) ?? defaultValue.minChannelNameColorLevel,
                minChannelNameIconLevel: get(data["channel_bg_icon_level_min"]) ?? defaultValue.minChannelNameIconLevel,
                minChannelProfileColorLevel: get(data["channel_profile_color_level_min"]) ?? defaultValue.minChannelProfileColorLevel,
                minChannelProfileIconLevel: get(data["channel_profile_bg_icon_level_min"]) ?? defaultValue.minChannelProfileIconLevel,
                minChannelEmojiStatusLevel: get(data["channel_emoji_status_level_min"]) ?? defaultValue.minChannelEmojiStatusLevel,
                minChannelWallpaperLevel: get(data["channel_wallpaper_level_min"]) ?? defaultValue.minChannelWallpaperLevel,
                minChannelCustomWallpaperLevel: get(data["channel_custom_wallpaper_level_min"]) ?? defaultValue.minChannelCustomWallpaperLevel,
                minChannelRestrictAdsLevel: get(data["channel_restrict_sponsored_level_min"]) ?? defaultValue.minChannelRestrictAdsLevel,
                minChannelWearGiftLevel: get(data["channel_emoji_status_level_min"]) ?? defaultValue.minChannelWearGiftLevel,
                minChannelAutoTranslateLevel: get(data["channel_autotranslation_level_min"]) ?? defaultValue.minChannelAutoTranslateLevel,
                minGroupProfileIconLevel: get(data["group_profile_bg_icon_level_min"]) ?? defaultValue.minGroupProfileIconLevel,
                minGroupEmojiStatusLevel: get(data["group_emoji_status_level_min"]) ?? defaultValue.minGroupEmojiStatusLevel,
                minGroupWallpaperLevel: get(data["group_wallpaper_level_min"]) ?? defaultValue.minGroupWallpaperLevel,
                minGroupCustomWallpaperLevel: get(data["group_custom_wallpaper_level_min"]) ?? defaultValue.minGroupCustomWallpaperLevel,
                minGroupEmojiPackLevel: get(data["group_emoji_stickers_level_min"]) ?? defaultValue.minGroupEmojiPackLevel,
                minGroupAudioTranscriptionLevel: get(data["group_transcribe_level_min"]) ?? defaultValue.minGroupAudioTranscriptionLevel
            )
        } else {
            return defaultValue
        }
    }
}

public struct AccountFreezeConfiguration {
    public static var defaultValue: AccountFreezeConfiguration {
        return AccountFreezeConfiguration(
            freezeSinceDate: nil,
            freezeUntilDate: nil,
            freezeAppealUrl: nil
        )
    }
    
    public let freezeSinceDate: Int32?
    public let freezeUntilDate: Int32?
    public let freezeAppealUrl: String?
    
    fileprivate init(
        freezeSinceDate: Int32?,
        freezeUntilDate: Int32?,
        freezeAppealUrl: String?
    ) {
        self.freezeSinceDate = freezeSinceDate
        self.freezeUntilDate = freezeUntilDate
        self.freezeAppealUrl = freezeAppealUrl
    }
    
    public static func with(appConfiguration: AppConfiguration) -> AccountFreezeConfiguration {
        let defaultValue = self.defaultValue
        if let data = appConfiguration.data {
            return AccountFreezeConfiguration(
                freezeSinceDate: (data["freeze_since_date"] as? Double).flatMap(Int32.init) ?? defaultValue.freezeSinceDate,
                freezeUntilDate: (data["freeze_until_date"] as? Double).flatMap(Int32.init) ?? defaultValue.freezeUntilDate,
                freezeAppealUrl: data["freeze_appeal_url"] as? String ?? defaultValue.freezeAppealUrl
            )
        } else {
            return defaultValue
        }
    }
}


public protocol GiftOptionsScreenProtocol {
    
}
