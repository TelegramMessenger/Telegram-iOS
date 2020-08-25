import Foundation
import Postbox
import SwiftSignalKit

public struct ExperimentalUISettings: Equatable, PreferencesEntry {
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
            enableVoipTcp: false
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
        enableVoipTcp: Bool
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
    }
    
    public init(decoder: PostboxDecoder) {
        self.keepChatNavigationStack = decoder.decodeInt32ForKey("keepChatNavigationStack", orElse: 0) != 0
        self.skipReadHistory = decoder.decodeInt32ForKey("skipReadHistory", orElse: 0) != 0
        self.crashOnLongQueries = decoder.decodeInt32ForKey("crashOnLongQueries", orElse: 0) != 0
        self.chatListPhotos = decoder.decodeInt32ForKey("chatListPhotos", orElse: 0) != 0
        self.knockoutWallpaper = decoder.decodeInt32ForKey("knockoutWallpaper", orElse: 0) != 0
        self.foldersTabAtBottom = decoder.decodeInt32ForKey("foldersTabAtBottom", orElse: 0) != 0
        self.playerEmbedding = decoder.decodeInt32ForKey("playerEmbedding", orElse: 0) != 0
        self.playlistPlayback = decoder.decodeInt32ForKey("playlistPlayback", orElse: 0) != 0
        self.preferredVideoCodec = decoder.decodeOptionalStringForKey("preferredVideoCodec")
        self.disableVideoAspectScaling = decoder.decodeInt32ForKey("disableVideoAspectScaling", orElse: 0) != 0
        self.enableVoipTcp = decoder.decodeInt32ForKey("enableVoipTcp", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.keepChatNavigationStack ? 1 : 0, forKey: "keepChatNavigationStack")
        encoder.encodeInt32(self.skipReadHistory ? 1 : 0, forKey: "skipReadHistory")
        encoder.encodeInt32(self.crashOnLongQueries ? 1 : 0, forKey: "crashOnLongQueries")
        encoder.encodeInt32(self.chatListPhotos ? 1 : 0, forKey: "chatListPhotos")
        encoder.encodeInt32(self.knockoutWallpaper ? 1 : 0, forKey: "knockoutWallpaper")
        encoder.encodeInt32(self.foldersTabAtBottom ? 1 : 0, forKey: "foldersTabAtBottom")
        encoder.encodeInt32(self.playerEmbedding ? 1 : 0, forKey: "playerEmbedding")
        encoder.encodeInt32(self.playlistPlayback ? 1 : 0, forKey: "playlistPlayback")
        if let preferredVideoCodec = self.preferredVideoCodec {
            encoder.encodeString(preferredVideoCodec, forKey: "preferredVideoCodec")
        }
        encoder.encodeInt32(self.disableVideoAspectScaling ? 1 : 0, forKey: "disableVideoAspectScaling")
        encoder.encodeInt32(self.enableVoipTcp ? 1 : 0, forKey: "enableVoipTcp")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ExperimentalUISettings {
            return self == to
        } else {
            return false
        }
    }
}

public func updateExperimentalUISettingsInteractively(accountManager: AccountManager, _ f: @escaping (ExperimentalUISettings) -> ExperimentalUISettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { entry in
            let currentSettings: ExperimentalUISettings
            if let entry = entry as? ExperimentalUISettings {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return f(currentSettings)
        })
    }
}
