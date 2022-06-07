import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public struct ExperimentalUISettings: Codable, Equatable {
    public struct AccountReactionOverrides: Equatable, Codable {
        public struct Item: Equatable, Codable {
            public var key: String
            public var messageId: MessageId
            public var mediaId: MediaId
            
            public init(key: String, messageId: MessageId, mediaId: MediaId) {
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
    public var playlistPlayback: Bool
    public var preferredVideoCodec: String?
    public var disableVideoAspectScaling: Bool
    public var enableVoipTcp: Bool
    public var experimentalCompatibility: Bool
    public var enableDebugDataDisplay: Bool
    public var acceleratedStickers: Bool
    public var experimentalBackground: Bool
    public var snow: Bool
    public var inlineStickers: Bool
    public var localTranscription: Bool
    public var enableReactionOverrides: Bool
    public var accountReactionEffectOverrides: [AccountReactionOverrides]
    public var accountStickerEffectOverrides: [AccountReactionOverrides]
    
    public static var defaultSettings: ExperimentalUISettings {
        return ExperimentalUISettings(
            keepChatNavigationStack: false,
            skipReadHistory: false,
            crashOnLongQueries: false,
            chatListPhotos: false,
            knockoutWallpaper: false,
            foldersTabAtBottom: false,
            playerEmbedding: false,
            playlistPlayback: false,
            preferredVideoCodec: nil,
            disableVideoAspectScaling: false,
            enableVoipTcp: false,
            experimentalCompatibility: false,
            enableDebugDataDisplay: false,
            acceleratedStickers: false,
            experimentalBackground: false,
            snow: false,
            inlineStickers: false,
            localTranscription: false,
            enableReactionOverrides: false,
            accountReactionEffectOverrides: [],
            accountStickerEffectOverrides: []
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
        playlistPlayback: Bool,
        preferredVideoCodec: String?,
        disableVideoAspectScaling: Bool,
        enableVoipTcp: Bool,
        experimentalCompatibility: Bool,
        enableDebugDataDisplay: Bool,
        acceleratedStickers: Bool,
        experimentalBackground: Bool,
        snow: Bool,
        inlineStickers: Bool,
        localTranscription: Bool,
        enableReactionOverrides: Bool,
        accountReactionEffectOverrides: [AccountReactionOverrides],
        accountStickerEffectOverrides: [AccountReactionOverrides]
    ) {
        self.keepChatNavigationStack = keepChatNavigationStack
        self.skipReadHistory = skipReadHistory
        self.crashOnLongQueries = crashOnLongQueries
        self.chatListPhotos = chatListPhotos
        self.knockoutWallpaper = knockoutWallpaper
        self.foldersTabAtBottom = foldersTabAtBottom
        self.playerEmbedding = playerEmbedding
        self.playlistPlayback = playlistPlayback
        self.preferredVideoCodec = preferredVideoCodec
        self.disableVideoAspectScaling = disableVideoAspectScaling
        self.enableVoipTcp = enableVoipTcp
        self.experimentalCompatibility = experimentalCompatibility
        self.enableDebugDataDisplay = enableDebugDataDisplay
        self.acceleratedStickers = acceleratedStickers
        self.experimentalBackground = experimentalBackground
        self.snow = snow
        self.inlineStickers = inlineStickers
        self.localTranscription = localTranscription
        self.enableReactionOverrides = enableReactionOverrides
        self.accountReactionEffectOverrides = accountReactionEffectOverrides
        self.accountStickerEffectOverrides = accountStickerEffectOverrides
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
        self.playlistPlayback = (try container.decodeIfPresent(Int32.self, forKey: "playlistPlayback") ?? 0) != 0
        self.preferredVideoCodec = try container.decodeIfPresent(String.self.self, forKey: "preferredVideoCodec")
        self.disableVideoAspectScaling = (try container.decodeIfPresent(Int32.self, forKey: "disableVideoAspectScaling") ?? 0) != 0
        self.enableVoipTcp = (try container.decodeIfPresent(Int32.self, forKey: "enableVoipTcp") ?? 0) != 0
        self.experimentalCompatibility = (try container.decodeIfPresent(Int32.self, forKey: "experimentalCompatibility") ?? 0) != 0
        self.enableDebugDataDisplay = (try container.decodeIfPresent(Int32.self, forKey: "enableDebugDataDisplay") ?? 0) != 0
        self.acceleratedStickers = (try container.decodeIfPresent(Int32.self, forKey: "acceleratedStickers") ?? 0) != 0
        self.experimentalBackground = (try container.decodeIfPresent(Int32.self, forKey: "experimentalBackground") ?? 0) != 0
        self.snow = (try container.decodeIfPresent(Int32.self, forKey: "snow") ?? 0) != 0
        self.inlineStickers = (try container.decodeIfPresent(Int32.self, forKey: "inlineStickers") ?? 0) != 0
        self.localTranscription = (try container.decodeIfPresent(Int32.self, forKey: "localTranscription") ?? 0) != 0
        self.enableReactionOverrides = try container.decodeIfPresent(Bool.self, forKey: "enableReactionOverrides") ?? false
        self.accountReactionEffectOverrides = (try container.decodeIfPresent([AccountReactionOverrides].self, forKey: "accountReactionEffectOverrides")) ?? []
        self.accountStickerEffectOverrides = (try container.decodeIfPresent([AccountReactionOverrides].self, forKey: "accountStickerEffectOverrides")) ?? []
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
        try container.encode((self.playlistPlayback ? 1 : 0) as Int32, forKey: "playlistPlayback")
        try container.encodeIfPresent(self.preferredVideoCodec, forKey: "preferredVideoCodec")
        try container.encode((self.disableVideoAspectScaling ? 1 : 0) as Int32, forKey: "disableVideoAspectScaling")
        try container.encode((self.enableVoipTcp ? 1 : 0) as Int32, forKey: "enableVoipTcp")
        try container.encode((self.experimentalCompatibility ? 1 : 0) as Int32, forKey: "experimentalCompatibility")
        try container.encode((self.enableDebugDataDisplay ? 1 : 0) as Int32, forKey: "enableDebugDataDisplay")
        try container.encode((self.acceleratedStickers ? 1 : 0) as Int32, forKey: "acceleratedStickers")
        try container.encode((self.experimentalBackground ? 1 : 0) as Int32, forKey: "experimentalBackground")
        try container.encode((self.snow ? 1 : 0) as Int32, forKey: "snow")
        try container.encode((self.inlineStickers ? 1 : 0) as Int32, forKey: "inlineStickers")
        try container.encode((self.localTranscription ? 1 : 0) as Int32, forKey: "localTranscription")
        try container.encode(self.enableReactionOverrides, forKey: "enableReactionOverrides")
        try container.encode(self.accountReactionEffectOverrides, forKey: "accountReactionEffectOverrides")
        try container.encode(self.accountStickerEffectOverrides, forKey: "accountStickerEffectOverrides")
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
            return PreferencesEntry(f(currentSettings))
        })
    }
}
