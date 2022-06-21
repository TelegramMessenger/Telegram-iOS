import Foundation
import TelegramCore
import Postbox

private enum ApplicationSpecificPreferencesKeyValues: Int32 {
    case voipDerivedState = 16
    case chatArchiveSettings = 17
    case chatListFilterSettings = 18
    case widgetSettings = 19
}

public struct ApplicationSpecificPreferencesKeys {
    public static let voipDerivedState = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.voipDerivedState.rawValue)
    public static let chatArchiveSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.chatArchiveSettings.rawValue)
    public static let chatListFilterSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.chatListFilterSettings.rawValue)
    public static let widgetSettings = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.widgetSettings.rawValue)
}

private enum ApplicationSpecificSharedDataKeyValues: Int32 {
    case inAppNotificationSettings = 0
    case presentationPasscodeSettings = 1
    case automaticMediaDownloadSettings = 2
    case generatedMediaStoreSettings = 3
    case voiceCallSettings = 4
    case presentationThemeSettings = 5
    case instantPagePresentationSettings = 6
    case callListSettings = 7
    case experimentalSettings = 8
    case musicPlaybackSettings = 9
    case mediaInputSettings = 10
    case experimentalUISettings = 11
    case stickerSettings = 12
    case watchPresetSettings = 13
    case webSearchSettings = 14
    case contactSynchronizationSettings = 15
    case webBrowserSettings = 16
    case intentsSettings = 17
    case translationSettings = 18
}

public struct ApplicationSpecificSharedDataKeys {
    public static let inAppNotificationSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.inAppNotificationSettings.rawValue)
    public static let presentationPasscodeSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.presentationPasscodeSettings.rawValue)
    public static let automaticMediaDownloadSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.automaticMediaDownloadSettings.rawValue)
    public static let generatedMediaStoreSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.generatedMediaStoreSettings.rawValue)
    public static let voiceCallSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.voiceCallSettings.rawValue)
    public static let presentationThemeSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.presentationThemeSettings.rawValue)
    public static let instantPagePresentationSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.instantPagePresentationSettings.rawValue)
    public static let callListSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.callListSettings.rawValue)
    public static let experimentalSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.experimentalSettings.rawValue)
    public static let musicPlaybackSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.musicPlaybackSettings.rawValue)
    public static let mediaInputSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.mediaInputSettings.rawValue)
    public static let experimentalUISettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.experimentalUISettings.rawValue)
    public static let stickerSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.stickerSettings.rawValue)
    public static let watchPresetSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.watchPresetSettings.rawValue)
    public static let webSearchSettings = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.webSearchSettings.rawValue)
    public static let contactSynchronizationSettings = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.contactSynchronizationSettings.rawValue)
    public static let webBrowserSettings = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.webBrowserSettings.rawValue)
    public static let intentsSettings = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.intentsSettings.rawValue)
    public static let translationSettings = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.translationSettings.rawValue)
}

private enum ApplicationSpecificItemCacheCollectionIdValues: Int8 {
    case instantPageStoredState = 0
    case cachedInstantPages = 1
    case cachedWallpapers = 2
    case mediaPlaybackStoredState = 3
    case cachedGeocodes = 4
    case visualMediaStoredState = 5
    case cachedImageRecognizedContent = 6
}

public struct ApplicationSpecificItemCacheCollectionId {
    public static let instantPageStoredState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.instantPageStoredState.rawValue)
    public static let cachedInstantPages = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedInstantPages.rawValue)
    public static let cachedWallpapers = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedWallpapers.rawValue)
    public static let mediaPlaybackStoredState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.mediaPlaybackStoredState.rawValue)
    public static let cachedGeocodes = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedGeocodes.rawValue)
    public static let visualMediaStoredState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.visualMediaStoredState.rawValue)
    public static let cachedImageRecognizedContent = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedImageRecognizedContent.rawValue)
}

private enum ApplicationSpecificOrderedItemListCollectionIdValues: Int32 {
    case webSearchRecentQueries = 0
    case wallpaperSearchRecentQueries = 1
    case settingsSearchRecentItems = 2
    case localThemes = 3
}

public struct ApplicationSpecificOrderedItemListCollectionId {
    public static let webSearchRecentQueries = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.webSearchRecentQueries.rawValue)
    public static let wallpaperSearchRecentQueries = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.wallpaperSearchRecentQueries.rawValue)
    public static let settingsSearchRecentItems = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.settingsSearchRecentItems.rawValue)
    public static let localThemes = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.localThemes.rawValue)
}
