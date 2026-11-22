import Foundation
import TelegramCore
import TelegramUIPreferences

public struct ChatInterfaceStickerSettings: Equatable {
    public init() {
    }
    
    public init(stickerSettings: StickerSettings) {
    }
    
    public static func ==(lhs: ChatInterfaceStickerSettings, rhs: ChatInterfaceStickerSettings) -> Bool {
        return true
    }
}

public enum ChatMediaInputGifMode: Equatable {
    case recent
    case trending
    case emojiSearch(String)
}

public final class ChatMediaInputNodeInteraction {
    public let navigateToCollectionId: (EngineItemCollectionId) -> Void
    public let navigateBackToStickers: () -> Void
    public let setGifMode: (ChatMediaInputGifMode) -> Void
    public let openSettings: () -> Void
    public let openTrending: (EngineItemCollectionId?) -> Void
    public let dismissTrendingPacks: ([EngineItemCollectionId]) -> Void
    public let toggleSearch: (Bool, ChatMediaInputSearchMode?, String) -> Void
    public let openPeerSpecificSettings: () -> Void
    public let dismissPeerSpecificSettings: () -> Void
    public let clearRecentlyUsedStickers: () -> Void
    
    public var stickerSettings: ChatInterfaceStickerSettings?
    public var highlightedStickerEngineItemCollectionId: EngineItemCollectionId?
    public var highlightedEngineItemCollectionId: EngineItemCollectionId?
    public var highlightedGifMode: ChatMediaInputGifMode = .recent
    public var previewedStickerPackItemFile: TelegramMediaFile?
    public var appearanceTransition: CGFloat = 1.0
    public var displayStickerPlaceholder = true
    public var displayStickerPackManageControls = true
    
    public init(navigateToCollectionId: @escaping (EngineItemCollectionId) -> Void, navigateBackToStickers: @escaping () -> Void, setGifMode: @escaping (ChatMediaInputGifMode) -> Void, openSettings: @escaping () -> Void, openTrending: @escaping (EngineItemCollectionId?) -> Void, dismissTrendingPacks: @escaping ([EngineItemCollectionId]) -> Void, toggleSearch: @escaping (Bool, ChatMediaInputSearchMode?, String) -> Void, openPeerSpecificSettings: @escaping () -> Void, dismissPeerSpecificSettings: @escaping () -> Void, clearRecentlyUsedStickers: @escaping () -> Void) {
        self.navigateToCollectionId = navigateToCollectionId
        self.navigateBackToStickers = navigateBackToStickers
        self.setGifMode = setGifMode
        self.openSettings = openSettings
        self.openTrending = openTrending
        self.dismissTrendingPacks = dismissTrendingPacks
        self.toggleSearch = toggleSearch
        self.openPeerSpecificSettings = openPeerSpecificSettings
        self.dismissPeerSpecificSettings = dismissPeerSpecificSettings
        self.clearRecentlyUsedStickers = clearRecentlyUsedStickers
    }
}
