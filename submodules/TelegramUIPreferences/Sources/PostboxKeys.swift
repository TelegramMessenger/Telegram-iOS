import Foundation
import TelegramCore

private enum ApplicationSpecificPreferencesKeyValues: Int32 {
    case voipDerivedState = 16
    case chatArchiveSettings = 17
    case chatListFilterSettings = 18
    case widgetSettings = 19
    case mediaAutoSaveSettings = 20
    case ageVerificationState = 21
    case textProcessingEditingState = 22
    case walletState = 23
}

public struct ApplicationSpecificPreferencesKeys {
    public static let voipDerivedState: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.voipDerivedState.rawValue)
    public static let chatArchiveSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.chatArchiveSettings.rawValue)
    public static let chatListFilterSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.chatListFilterSettings.rawValue)
    public static let widgetSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.widgetSettings.rawValue)
    public static let mediaAutoSaveSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.mediaAutoSaveSettings.rawValue)
    public static let ageVerificationState: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.ageVerificationState.rawValue)
    public static let walletState: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificPreferencesKeyValues.walletState.rawValue)
    
    public static func textProcessingEditingState(peerId: EnginePeer.Id) -> EngineDataBuffer {
        let key = EngineDataBuffer(length: 4 + 8)
        key.setInt32(0, value: ApplicationSpecificPreferencesKeyValues.textProcessingEditingState.rawValue)
        key.setInt64(4, value: peerId.toInt64())
        return key
    }
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
    case drawingSettings = 19
    case mediaDisplaySettings = 20
    case updateSettings = 21
    case chatSettings = 22
}

public struct ApplicationSpecificSharedDataKeys {
    public static let inAppNotificationSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.inAppNotificationSettings.rawValue)
    public static let presentationPasscodeSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.presentationPasscodeSettings.rawValue)
    public static let automaticMediaDownloadSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.automaticMediaDownloadSettings.rawValue)
    public static let generatedMediaStoreSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.generatedMediaStoreSettings.rawValue)
    public static let voiceCallSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.voiceCallSettings.rawValue)
    public static let presentationThemeSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.presentationThemeSettings.rawValue)
    public static let instantPagePresentationSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.instantPagePresentationSettings.rawValue)
    public static let callListSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.callListSettings.rawValue)
    public static let experimentalSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.experimentalSettings.rawValue)
    public static let musicPlaybackSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.musicPlaybackSettings.rawValue)
    public static let mediaInputSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.mediaInputSettings.rawValue)
    public static let experimentalUISettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.experimentalUISettings.rawValue)
    public static let stickerSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.stickerSettings.rawValue)
    public static let watchPresetSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.watchPresetSettings.rawValue)
    public static let webSearchSettings: EngineDataBuffer = applicationSpecificSharedDataKey(ApplicationSpecificSharedDataKeyValues.webSearchSettings.rawValue)
    public static let contactSynchronizationSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.contactSynchronizationSettings.rawValue)
    public static let webBrowserSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.webBrowserSettings.rawValue)
    public static let intentsSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.intentsSettings.rawValue)
    public static let translationSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.translationSettings.rawValue)
    public static let drawingSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.drawingSettings.rawValue)
    public static let mediaDisplaySettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.mediaDisplaySettings.rawValue)
    public static let updateSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.updateSettings.rawValue)
    public static let chatSettings: EngineDataBuffer = applicationSpecificPreferencesKey(ApplicationSpecificSharedDataKeyValues.chatSettings.rawValue)
}

private enum ApplicationSpecificItemCacheCollectionIdValues: Int8 {
    case instantPageStoredState = 0
    case cachedInstantPages = 1
    case cachedWallpapers = 2
    case mediaPlaybackStoredState = 3
    case cachedGeocodes = 4
    case visualMediaStoredState = 5
    case cachedImageRecognizedContent = 6
    case pendingInAppPurchaseState = 7
    case translationState = 10
    case storySource = 11
    case mediaEditorState = 12
    case shareWithPeersState = 13
    case webAppPermissionsState = 14
    case richTextArticleDrafts = 15
}

public struct ApplicationSpecificItemCacheCollectionId {
    public static let instantPageStoredState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.instantPageStoredState.rawValue)
    public static let cachedInstantPages = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedInstantPages.rawValue)
    public static let cachedWallpapers = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedWallpapers.rawValue)
    public static let cachedGeocodes = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedGeocodes.rawValue)
    public static let visualMediaStoredState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.visualMediaStoredState.rawValue)
    public static let cachedImageRecognizedContent = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.cachedImageRecognizedContent.rawValue)
    public static let pendingInAppPurchaseState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.pendingInAppPurchaseState.rawValue)
    public static let translationState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.translationState.rawValue)
    public static let storySource = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.storySource.rawValue)
    public static let mediaEditorState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.mediaEditorState.rawValue)
    public static let shareWithPeersState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.shareWithPeersState.rawValue)
    public static let webAppPermissionsState = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.webAppPermissionsState.rawValue)
    public static let richTextArticleDrafts = applicationSpecificItemCacheCollectionId(ApplicationSpecificItemCacheCollectionIdValues.richTextArticleDrafts.rawValue)
}

private enum ApplicationSpecificOrderedItemListCollectionIdValues: Int32 {
    case localThemes = 3
    case storyDrafts = 4
    case storySources = 5
    case hashtagSearchRecentQueries = 6
    case browserRecentlyVisited = 7
    case settingsSearchRecentItems = 8
}

public struct ApplicationSpecificOrderedItemListCollectionId {
    public static let settingsSearchRecentItems = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.settingsSearchRecentItems.rawValue)
    public static let localThemes = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.localThemes.rawValue)
    public static let storyDrafts = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.storyDrafts.rawValue)
    public static let storySources = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.storySources.rawValue)
    public static let hashtagSearchRecentQueries = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.hashtagSearchRecentQueries.rawValue)
    public static let browserRecentlyVisited = applicationSpecificOrderedItemListCollectionId(ApplicationSpecificOrderedItemListCollectionIdValues.browserRecentlyVisited.rawValue)
}
