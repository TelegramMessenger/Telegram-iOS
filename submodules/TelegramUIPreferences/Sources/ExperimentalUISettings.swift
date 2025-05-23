import Foundation
import TelegramCore
import SwiftSignalKit

public struct ExperimentalUISettings: Codable, Equatable {
    public struct AccountReactionOverrides: Equatable, Codable {
        public struct Item: Equatable, Codable {
            public var key: MessageReaction.Reaction
            public var messageId: EngineMessage.Id
            public var mediaId: EngineMedia.Id
            
            public init(key: MessageReaction.Reaction, messageId: EngineMessage.Id, mediaId: EngineMedia.Id) {
                self.key = key
                self.messageId = messageId
                self.mediaId = mediaId
            }
        }
        
        public var accountId: Int64
        public var items: [Item]
        
        public init(accountId: Int64, items: [Item]) {
            self.accountId = accountId
            self.items = items
        }
    }
    
    public var keepChatNavigationStack: Bool
    public var skipReadHistory: Bool
    public var crashOnLongQueries: Bool
    public var chatListPhotos: Bool
    public var knockoutWallpaper: Bool
    public var foldersTabAtBottom: Bool
    public var playerEmbedding: Bool
    public var preferredVideoCodec: String?
    public var disableVideoAspectScaling: Bool
    public var enableVoipTcp: Bool
    public var experimentalCompatibility: Bool
    public var enableDebugDataDisplay: Bool
    public var rippleEffect: Bool
    public var compressedEmojiCache: Bool
    public var localTranscription: Bool
    public var enableReactionOverrides: Bool
    public var browserExperiment: Bool
    public var accountReactionEffectOverrides: [AccountReactionOverrides]
    public var accountStickerEffectOverrides: [AccountReactionOverrides]
    public var disableQuickReaction: Bool
    public var disableLanguageRecognition: Bool
    public var disableImageContentAnalysis: Bool
    public var disableBackgroundAnimation: Bool
    public var logLanguageRecognition: Bool
    public var storiesExperiment: Bool
    public var storiesJpegExperiment: Bool
    public var crashOnMemoryPressure: Bool
    public var dustEffect: Bool
    public var disableCallV2: Bool
    public var experimentalCallMute: Bool
    public var allowWebViewInspection: Bool
    public var disableReloginTokens: Bool
    public var liveStreamV2: Bool
    public var dynamicStreaming: Bool
    public var enableLocalTranslation: Bool
    public var autoBenchmarkReflectors: Bool?
    public var playerV2: Bool
    public var devRequests: Bool
    public var fakeAds: Bool
    public var conferenceDebug: Bool
    public var checkSerializedData: Bool
    public var allForumsHaveTabs: Bool
    
    public static var defaultSettings: ExperimentalUISettings {
        return ExperimentalUISettings(
            keepChatNavigationStack: false,
            skipReadHistory: false,
            crashOnLongQueries: false,
            chatListPhotos: false,
            knockoutWallpaper: false,
            foldersTabAtBottom: false,
            playerEmbedding: false,
            preferredVideoCodec: nil,
            disableVideoAspectScaling: false,
            enableVoipTcp: false,
            experimentalCompatibility: false,
            enableDebugDataDisplay: false,
            rippleEffect: false,
            compressedEmojiCache: false,
            localTranscription: false,
            enableReactionOverrides: false,
            browserExperiment: false,
            accountReactionEffectOverrides: [],
            accountStickerEffectOverrides: [],
            disableQuickReaction: false,
            disableLanguageRecognition: false,
            disableImageContentAnalysis: false,
            disableBackgroundAnimation: false,
            logLanguageRecognition: false,
            storiesExperiment: false,
            storiesJpegExperiment: false,
            crashOnMemoryPressure: false,
            dustEffect: false,
            disableCallV2: false,
            experimentalCallMute: false,
            allowWebViewInspection: false,
            disableReloginTokens: false,
            liveStreamV2: false,
            dynamicStreaming: false,
            enableLocalTranslation: false,
            autoBenchmarkReflectors: nil,
            playerV2: false,
            devRequests: false,
            fakeAds: false,
            conferenceDebug: false,
            checkSerializedData: false,
            allForumsHaveTabs: false
        )
    }
    
    public init(
        keepChatNavigationStack: Bool,
        skipReadHistory: Bool,
        crashOnLongQueries: Bool,
        chatListPhotos: Bool,
        knockoutWallpaper: Bool,
        foldersTabAtBottom: Bool,
        playerEmbedding: Bool,
        preferredVideoCodec: String?,
        disableVideoAspectScaling: Bool,
        enableVoipTcp: Bool,
        experimentalCompatibility: Bool,
        enableDebugDataDisplay: Bool,
        rippleEffect: Bool,
        compressedEmojiCache: Bool,
        localTranscription: Bool,
        enableReactionOverrides: Bool,
        browserExperiment: Bool,
        accountReactionEffectOverrides: [AccountReactionOverrides],
        accountStickerEffectOverrides: [AccountReactionOverrides],
        disableQuickReaction: Bool,
        disableLanguageRecognition: Bool,
        disableImageContentAnalysis: Bool,
        disableBackgroundAnimation: Bool,
        logLanguageRecognition: Bool,
        storiesExperiment: Bool,
        storiesJpegExperiment: Bool,
        crashOnMemoryPressure: Bool,
        dustEffect: Bool,
        disableCallV2: Bool,
        experimentalCallMute: Bool,
        allowWebViewInspection: Bool,
        disableReloginTokens: Bool,
        liveStreamV2: Bool,
        dynamicStreaming: Bool,
        enableLocalTranslation: Bool,
        autoBenchmarkReflectors: Bool?,
        playerV2: Bool,
        devRequests: Bool,
        fakeAds: Bool,
        conferenceDebug: Bool,
        checkSerializedData: Bool,
        allForumsHaveTabs: Bool
    ) {
        self.keepChatNavigationStack = keepChatNavigationStack
        self.skipReadHistory = skipReadHistory
        self.crashOnLongQueries = crashOnLongQueries
        self.chatListPhotos = chatListPhotos
        self.knockoutWallpaper = knockoutWallpaper
        self.foldersTabAtBottom = foldersTabAtBottom
        self.playerEmbedding = playerEmbedding
        self.preferredVideoCodec = preferredVideoCodec
        self.disableVideoAspectScaling = disableVideoAspectScaling
        self.enableVoipTcp = enableVoipTcp
        self.experimentalCompatibility = experimentalCompatibility
        self.enableDebugDataDisplay = enableDebugDataDisplay
        self.rippleEffect = rippleEffect
        self.compressedEmojiCache = compressedEmojiCache
        self.localTranscription = localTranscription
        self.enableReactionOverrides = enableReactionOverrides
        self.browserExperiment = browserExperiment
        self.accountReactionEffectOverrides = accountReactionEffectOverrides
        self.accountStickerEffectOverrides = accountStickerEffectOverrides
        self.disableQuickReaction = disableQuickReaction
        self.disableLanguageRecognition = disableLanguageRecognition
        self.disableImageContentAnalysis = disableImageContentAnalysis
        self.disableBackgroundAnimation = disableBackgroundAnimation
        self.logLanguageRecognition = logLanguageRecognition
        self.storiesExperiment = storiesExperiment
        self.storiesJpegExperiment = storiesJpegExperiment
        self.crashOnMemoryPressure = crashOnMemoryPressure
        self.dustEffect = dustEffect
        self.disableCallV2 = disableCallV2
        self.experimentalCallMute = experimentalCallMute
        self.allowWebViewInspection = allowWebViewInspection
        self.disableReloginTokens = disableReloginTokens
        self.liveStreamV2 = liveStreamV2
        self.dynamicStreaming = dynamicStreaming
        self.enableLocalTranslation = enableLocalTranslation
        self.autoBenchmarkReflectors = autoBenchmarkReflectors
        self.playerV2 = playerV2
        self.devRequests = devRequests
        self.fakeAds = fakeAds
        self.conferenceDebug = conferenceDebug
        self.checkSerializedData = checkSerializedData
        self.allForumsHaveTabs = allForumsHaveTabs
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.keepChatNavigationStack = (try container.decodeIfPresent(Int32.self, forKey: "keepChatNavigationStack") ?? 0) != 0
        self.skipReadHistory = (try container.decodeIfPresent(Int32.self, forKey: "skipReadHistory") ?? 0) != 0
        self.crashOnLongQueries = (try container.decodeIfPresent(Int32.self, forKey: "crashOnLongQueries") ?? 0) != 0
        self.chatListPhotos = (try container.decodeIfPresent(Int32.self, forKey: "chatListPhotos") ?? 0) != 0
        self.knockoutWallpaper = (try container.decodeIfPresent(Int32.self, forKey: "knockoutWallpaper") ?? 0) != 0
        self.foldersTabAtBottom = (try container.decodeIfPresent(Int32.self, forKey: "foldersTabAtBottom") ?? 0) != 0
        self.playerEmbedding = (try container.decodeIfPresent(Int32.self, forKey: "playerEmbedding") ?? 0) != 0
        self.preferredVideoCodec = try container.decodeIfPresent(String.self.self, forKey: "preferredVideoCodec")
        self.disableVideoAspectScaling = (try container.decodeIfPresent(Int32.self, forKey: "disableVideoAspectScaling") ?? 0) != 0
        self.enableVoipTcp = (try container.decodeIfPresent(Int32.self, forKey: "enableVoipTcp") ?? 0) != 0
        self.experimentalCompatibility = (try container.decodeIfPresent(Int32.self, forKey: "experimentalCompatibility") ?? 0) != 0
        self.enableDebugDataDisplay = (try container.decodeIfPresent(Int32.self, forKey: "enableDebugDataDisplay") ?? 0) != 0
        self.rippleEffect = (try container.decodeIfPresent(Int32.self, forKey: "rippleEffect") ?? 0) != 0
        self.compressedEmojiCache = (try container.decodeIfPresent(Int32.self, forKey: "compressedEmojiCache") ?? 0) != 0
        self.localTranscription = (try container.decodeIfPresent(Int32.self, forKey: "localTranscription") ?? 0) != 0
        self.enableReactionOverrides = try container.decodeIfPresent(Bool.self, forKey: "enableReactionOverrides") ?? false
        self.browserExperiment = try container.decodeIfPresent(Bool.self, forKey: "browserExperiment") ?? false
        self.accountReactionEffectOverrides = (try? container.decodeIfPresent([AccountReactionOverrides].self, forKey: "accountReactionEffectOverrides")) ?? []
        self.accountStickerEffectOverrides = (try? container.decodeIfPresent([AccountReactionOverrides].self, forKey: "accountStickerEffectOverrides")) ?? []
        self.disableQuickReaction = try container.decodeIfPresent(Bool.self, forKey: "disableQuickReaction") ?? false
        self.disableLanguageRecognition = try container.decodeIfPresent(Bool.self, forKey: "disableLanguageRecognition") ?? false
        self.disableImageContentAnalysis = try container.decodeIfPresent(Bool.self, forKey: "disableImageContentAnalysis") ?? false
        self.disableBackgroundAnimation = try container.decodeIfPresent(Bool.self, forKey: "disableBackgroundAnimation") ?? false
        self.logLanguageRecognition = try container.decodeIfPresent(Bool.self, forKey: "logLanguageRecognition") ?? false
        self.storiesExperiment = try container.decodeIfPresent(Bool.self, forKey: "storiesExperiment") ?? false
        self.storiesJpegExperiment = try container.decodeIfPresent(Bool.self, forKey: "storiesJpegExperiment") ?? false
        self.crashOnMemoryPressure = try container.decodeIfPresent(Bool.self, forKey: "crashOnMemoryPressure") ?? false
        self.dustEffect = try container.decodeIfPresent(Bool.self, forKey: "dustEffect") ?? false
        self.disableCallV2 = try container.decodeIfPresent(Bool.self, forKey: "disableCallV2") ?? false
        self.experimentalCallMute = try container.decodeIfPresent(Bool.self, forKey: "experimentalCallMute") ?? false
        self.allowWebViewInspection = try container.decodeIfPresent(Bool.self, forKey: "allowWebViewInspection") ?? false
        self.disableReloginTokens = try container.decodeIfPresent(Bool.self, forKey: "disableReloginTokens") ?? false
        self.liveStreamV2 = try container.decodeIfPresent(Bool.self, forKey: "liveStreamV2") ?? false
        self.dynamicStreaming = try container.decodeIfPresent(Bool.self, forKey: "dynamicStreaming_v2") ?? false
        self.enableLocalTranslation = try container.decodeIfPresent(Bool.self, forKey: "enableLocalTranslation") ?? false
        self.autoBenchmarkReflectors = try container.decodeIfPresent(Bool.self, forKey: "autoBenchmarkReflectors")
        self.playerV2 = try container.decodeIfPresent(Bool.self, forKey: "playerV2") ?? false
        self.devRequests = try container.decodeIfPresent(Bool.self, forKey: "devRequests") ?? false
        self.fakeAds = try container.decodeIfPresent(Bool.self, forKey: "fakeAds") ?? false
        self.conferenceDebug = try container.decodeIfPresent(Bool.self, forKey: "conferenceDebug") ?? false
        self.checkSerializedData = try container.decodeIfPresent(Bool.self, forKey: "checkSerializedData") ?? false
        self.allForumsHaveTabs = try container.decodeIfPresent(Bool.self, forKey: "allForumsHaveTabs") ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.keepChatNavigationStack ? 1 : 0) as Int32, forKey: "keepChatNavigationStack")
        try container.encode((self.skipReadHistory ? 1 : 0) as Int32, forKey: "skipReadHistory")
        try container.encode((self.crashOnLongQueries ? 1 : 0) as Int32, forKey: "crashOnLongQueries")
        try container.encode((self.chatListPhotos ? 1 : 0) as Int32, forKey: "chatListPhotos")
        try container.encode((self.knockoutWallpaper ? 1 : 0) as Int32, forKey: "knockoutWallpaper")
        try container.encode((self.foldersTabAtBottom ? 1 : 0) as Int32, forKey: "foldersTabAtBottom")
        try container.encode((self.playerEmbedding ? 1 : 0) as Int32, forKey: "playerEmbedding")
        try container.encodeIfPresent(self.preferredVideoCodec, forKey: "preferredVideoCodec")
        try container.encode((self.disableVideoAspectScaling ? 1 : 0) as Int32, forKey: "disableVideoAspectScaling")
        try container.encode((self.enableVoipTcp ? 1 : 0) as Int32, forKey: "enableVoipTcp")
        try container.encode((self.experimentalCompatibility ? 1 : 0) as Int32, forKey: "experimentalCompatibility")
        try container.encode((self.enableDebugDataDisplay ? 1 : 0) as Int32, forKey: "enableDebugDataDisplay")
        try container.encode((self.rippleEffect ? 1 : 0) as Int32, forKey: "rippleEffect")
        try container.encode((self.compressedEmojiCache ? 1 : 0) as Int32, forKey: "compressedEmojiCache")
        try container.encode((self.localTranscription ? 1 : 0) as Int32, forKey: "localTranscription")
        try container.encode(self.enableReactionOverrides, forKey: "enableReactionOverrides")
        try container.encode(self.browserExperiment, forKey: "browserExperiment")
        try container.encode(self.accountReactionEffectOverrides, forKey: "accountReactionEffectOverrides")
        try container.encode(self.accountStickerEffectOverrides, forKey: "accountStickerEffectOverrides")
        try container.encode(self.disableQuickReaction, forKey: "disableQuickReaction")
        try container.encode(self.disableLanguageRecognition, forKey: "disableLanguageRecognition")
        try container.encode(self.disableImageContentAnalysis, forKey: "disableImageContentAnalysis")
        try container.encode(self.disableBackgroundAnimation, forKey: "disableBackgroundAnimation")
        try container.encode(self.logLanguageRecognition, forKey: "logLanguageRecognition")
        try container.encode(self.storiesExperiment, forKey: "storiesExperiment")
        try container.encode(self.storiesJpegExperiment, forKey: "storiesJpegExperiment")
        try container.encode(self.crashOnMemoryPressure, forKey: "crashOnMemoryPressure")
        try container.encode(self.dustEffect, forKey: "dustEffect")
        try container.encode(self.disableCallV2, forKey: "disableCallV2")
        try container.encode(self.experimentalCallMute, forKey: "experimentalCallMute")
        try container.encode(self.allowWebViewInspection, forKey: "allowWebViewInspection")
        try container.encode(self.disableReloginTokens, forKey: "disableReloginTokens")
        try container.encode(self.liveStreamV2, forKey: "liveStreamV2")
        try container.encode(self.dynamicStreaming, forKey: "dynamicStreaming")
        try container.encode(self.enableLocalTranslation, forKey: "enableLocalTranslation")
        try container.encodeIfPresent(self.autoBenchmarkReflectors, forKey: "autoBenchmarkReflectors")
        try container.encodeIfPresent(self.playerV2, forKey: "playerV2")
        try container.encodeIfPresent(self.devRequests, forKey: "devRequests")
        try container.encodeIfPresent(self.fakeAds, forKey: "fakeAds")
        try container.encodeIfPresent(self.conferenceDebug, forKey: "conferenceDebug")
        try container.encodeIfPresent(self.checkSerializedData, forKey: "checkSerializedData")
        try container.encodeIfPresent(self.allForumsHaveTabs, forKey: "allForumsHaveTabs")
    }
}

public func updateExperimentalUISettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ExperimentalUISettings) -> ExperimentalUISettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { entry in
            let currentSettings: ExperimentalUISettings
            if let entry = entry?.get(ExperimentalUISettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
