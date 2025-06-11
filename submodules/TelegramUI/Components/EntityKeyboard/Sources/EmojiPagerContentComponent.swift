import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import MultiAnimationRenderer
import AnimationCache
import AccountContext
import LottieAnimationCache
import VideoAnimationCache
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import ShimmerEffect
import PagerComponent
import StickerResources
import AppBundle
import UndoUI
import AudioToolbox
import SolidRoundedButtonComponent
import EmojiTextAttachmentView
import EmojiStatusComponent
import TelegramNotices
import GenerateStickerPlaceholderImage

public struct EmojiComponentReactionItem: Equatable {
    public var reaction: MessageReaction.Reaction
    public var file: TelegramMediaFile.Accessor
    
    public init(reaction: MessageReaction.Reaction, file: TelegramMediaFile.Accessor) {
        self.reaction = reaction
        self.file = file
    }
}

public final class EntityKeyboardAnimationData: Equatable {
    public enum Id: Hashable {
        case file(MediaId)
        case stickerPackThumbnail(ItemCollectionId)
        case gift(String)
    }
    
    public enum ItemType: Equatable {
        case still
        case lottie
        case video(isVP9: Bool)
        
        var animationCacheAnimationType: AnimationCacheAnimationType {
            switch self {
            case .still:
                return .still
            case .lottie:
                return .lottie
            case let .video(isVP9):
                return .video(isVP9: isVP9)
            }
        }
    }
    
    public enum Resource: Equatable {
        case resource(MediaResourceReference)
        case stickerPackThumbnail(id: Int64, accessHash: Int64, info: StickerPackCollectionInfo.Accessor)
        case file(PartialMediaReference?, TelegramMediaFile.Accessor)
        
        func _parse() -> MediaResourceReference? {
            switch self {
            case let .resource(resource):
                return resource
            case let .stickerPackThumbnail(id, accessHash, info):
                guard let thumbnail = info._parse().thumbnail else {
                    return nil
                }
                return .stickerPackThumbnail(stickerPack: .id(id: id, accessHash: accessHash), resource: thumbnail.resource)
            case let .file(partialReference, file):
                let file = file._parse()
                if let partialReference {
                    return partialReference.mediaReference(file).resourceReference(file.resource)
                } else {
                    return .standalone(resource: file.resource)
                }
            }
        }
    }
    
    public let id: Id
    public let type: ItemType
    public let resource: Resource
    public let dimensions: CGSize
    public let immediateThumbnailData: Data?
    public let isReaction: Bool
    public let isTemplate: Bool
    public let particleColor: UIColor?
    
    public init(id: Id, type: ItemType, resource: Resource, dimensions: CGSize, immediateThumbnailData: Data?, isReaction: Bool, isTemplate: Bool, particleColor: UIColor? = nil) {
        self.id = id
        self.type = type
        self.resource = resource
        self.dimensions = dimensions
        self.immediateThumbnailData = immediateThumbnailData
        self.isReaction = isReaction
        self.isTemplate = isTemplate
        self.particleColor = particleColor
    }
    
    public convenience init(file: TelegramMediaFile.Accessor, isReaction: Bool = false, partialReference: PartialMediaReference? = nil) {
        let type: ItemType
        if file.isVideoSticker || file.isVideoEmoji {
            type = .video(isVP9: true)
        } else if file.isAnimatedSticker {
            type = .lottie
        } else if file.isVideo {
            type = .video(isVP9: false)
        } else {
            type = .still
        }
        let isTemplate = file.isCustomTemplateEmoji
        
        let resource: Resource = .file(partialReference, file)
        self.init(id: .file(file.fileId), type: type, resource: resource, dimensions: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), immediateThumbnailData: file.immediateThumbnailData, isReaction: isReaction, isTemplate: isTemplate)
    }
    
    public convenience init?(gift: StarGift.UniqueGift) {
        var file: TelegramMediaFile?
        var color: UIColor?
        for attribute in gift.attributes {
            if case let .model(_, fileValue, _) = attribute {
                file = fileValue
            } else if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                color = UIColor(rgb: UInt32(bitPattern: innerColor))
                let _ = outerColor
            }
        }
        if let file, let color {
            let resourceReference: MediaResourceReference = .standalone(resource: file.resource)
            self.init(id: .gift(gift.slug), type: .lottie, resource: .resource(resourceReference), dimensions: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), immediateThumbnailData: file.immediateThumbnailData, isReaction: false, isTemplate: false, particleColor: color)
        } else {
            return nil
        }
    }
    
    public static func ==(lhs: EntityKeyboardAnimationData, rhs: EntityKeyboardAnimationData) -> Bool {
        if lhs === rhs {
            return true
        }
        
        if lhs.resource != rhs.resource {
            return false
        }
        if lhs.dimensions != rhs.dimensions {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        if lhs.immediateThumbnailData != rhs.immediateThumbnailData {
            return false
        }
        if lhs.isReaction != rhs.isReaction {
            return false
        }
        
        return true
    }
}

public protocol EmojiContentPeekBehavior: AnyObject {
    func setGestureRecognizerEnabled(view: UIView, isEnabled: Bool, itemAtPoint: @escaping (CGPoint) -> (AnyHashable, CALayer, TelegramMediaFile)?)
}

public protocol EmojiCustomContentView: UIView {
    var tintContainerView: UIView { get }
    
    func update(theme: PresentationTheme, strings: PresentationStrings, useOpaqueTheme: Bool, availableSize: CGSize, transition: ComponentTransition) -> CGSize
}

public final class EmojiPagerContentComponent: Component {
    public typealias EnvironmentType = (EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)
    
    public final class ContentAnimation {
        public enum AnimationType {
            case generic
            case groupExpanded(id: AnyHashable)
            case groupInstalled(id: AnyHashable, scrollToGroup: Bool)
            case groupRemoved(id: AnyHashable)
        }
        
        public let type: AnimationType
        
        public init(type: AnimationType) {
            self.type = type
        }
    }
    
    public final class StateContext {
        var scrollPosition: CGFloat = 0.0
        
        public init() {
        }
    }
    
    public final class SynchronousLoadBehavior {
        public let isDisabled: Bool
        
        public init(isDisabled: Bool) {
            self.isDisabled = isDisabled
        }
    }
        
    public struct CustomLayout: Equatable {
        public var topPanelAlwaysHidden: Bool
        public var itemsPerRow: Int
        public var itemSize: CGFloat
        public var sideInset: CGFloat
        public var itemSpacing: CGFloat
        
        public init(
            topPanelAlwaysHidden: Bool,
            itemsPerRow: Int,
            itemSize: CGFloat,
            sideInset: CGFloat,
            itemSpacing: CGFloat
        ) {
            self.topPanelAlwaysHidden = topPanelAlwaysHidden
            self.itemsPerRow = itemsPerRow
            self.itemSize = itemSize
            self.sideInset = sideInset
            self.itemSpacing = itemSpacing
        }
    }
    
    public final class ExternalBackground {
        public let effectContainerView: UIView?
        
        public init(
            effectContainerView: UIView?
        ) {
            self.effectContainerView = effectContainerView
        }
    }
    
    public final class InputInteractionHolder {
        public var inputInteraction: InputInteraction?
        
        public init() {
        }
    }
    
    public final class InputInteraction {
        public let performItemAction: (AnyHashable, Item, UIView, CGRect, CALayer, Bool) -> Void
        public let deleteBackwards: (() -> Void)?
        public let openStickerSettings: (() -> Void)?
        public let openFeatured: (() -> Void)?
        public let openSearch: () -> Void
        public let addGroupAction: (AnyHashable, Bool, Bool) -> Void
        public let clearGroup: (AnyHashable) -> Void
        public let editAction: (AnyHashable) -> Void
        public let pushController: (ViewController) -> Void
        public let presentController: (ViewController) -> Void
        public let presentGlobalOverlayController: (ViewController) -> Void
        public let navigationController: () -> NavigationController?
        public let requestUpdate: (ComponentTransition) -> Void
        public let updateSearchQuery: (EmojiPagerContentComponent.SearchQuery?) -> Void
        public let updateScrollingToItemGroup: () -> Void
        public let externalCancel: (() -> Void)?
        public let onScroll: () -> Void
        public let chatPeerId: PeerId?
        public let peekBehavior: EmojiContentPeekBehavior?
        public let customLayout: CustomLayout?
        public let externalBackground: ExternalBackground?
        public weak var externalExpansionView: UIView?
        public let customContentView: EmojiCustomContentView?
        public let useOpaqueTheme: Bool
        public let hideBackground: Bool
        public let scrollingStickersGridPromise = ValuePromise<Bool>(false)
        public let stateContext: StateContext?
        public let addImage: (() -> Void)?
        
        public init(
            performItemAction: @escaping (AnyHashable, Item, UIView, CGRect, CALayer, Bool) -> Void,
            deleteBackwards: (() -> Void)?,
            openStickerSettings: (() -> Void)?,
            openFeatured: (() -> Void)?,
            openSearch: @escaping () -> Void,
            addGroupAction: @escaping (AnyHashable, Bool, Bool) -> Void,
            clearGroup: @escaping (AnyHashable) -> Void,
            editAction: @escaping (AnyHashable) -> Void,
            pushController: @escaping (ViewController) -> Void,
            presentController: @escaping (ViewController) -> Void,
            presentGlobalOverlayController: @escaping (ViewController) -> Void,
            navigationController: @escaping () -> NavigationController?,
            requestUpdate: @escaping (ComponentTransition) -> Void,
            updateSearchQuery: @escaping (SearchQuery?) -> Void,
            updateScrollingToItemGroup: @escaping () -> Void,
            externalCancel: (() -> Void)? = nil,
            onScroll: @escaping () -> Void,
            chatPeerId: PeerId?,
            peekBehavior: EmojiContentPeekBehavior?,
            customLayout: CustomLayout?,
            externalBackground: ExternalBackground?,
            externalExpansionView: UIView?,
            customContentView: EmojiCustomContentView?,
            useOpaqueTheme: Bool,
            hideBackground: Bool,
            stateContext: StateContext?,
            addImage: (() -> Void)?
        ) {
            self.performItemAction = performItemAction
            self.deleteBackwards = deleteBackwards
            self.openStickerSettings = openStickerSettings
            self.openFeatured = openFeatured
            self.openSearch = openSearch
            self.addGroupAction = addGroupAction
            self.clearGroup = clearGroup
            self.editAction = editAction
            self.pushController = pushController
            self.presentController = presentController
            self.presentGlobalOverlayController = presentGlobalOverlayController
            self.navigationController = navigationController
            self.requestUpdate = requestUpdate
            self.updateSearchQuery = updateSearchQuery
            self.updateScrollingToItemGroup = updateScrollingToItemGroup
            self.externalCancel = externalCancel
            self.onScroll = onScroll
            self.chatPeerId = chatPeerId
            self.peekBehavior = peekBehavior
            self.customLayout = customLayout
            self.externalBackground = externalBackground
            self.externalExpansionView = externalExpansionView
            self.customContentView = customContentView
            self.useOpaqueTheme = useOpaqueTheme
            self.hideBackground = hideBackground
            self.stateContext = stateContext
            self.addImage = addImage
        }
    }
    
    public enum StaticEmojiSegment: Int32, CaseIterable {
        case people = 0
        case animalsAndNature = 1
        case foodAndDrink = 2
        case activityAndSport = 3
        case travelAndPlaces = 4
        case objects = 5
        case symbols = 6
        case flags = 7
    }
    
    public enum SearchQuery: Equatable {
        case text(value: String, language: String)
        case category(value: EmojiSearchCategories.Group)
    }
    
    public enum ItemContent: Equatable {
        public enum Id: Hashable {
            case animation(EntityKeyboardAnimationData.Id)
            case staticEmoji(String)
            case icon(Icon)
            case starGift(String)
        }
        
        public enum Icon: Equatable, Hashable {
            case premiumStar
            case topic(String, Int32)
            case stop
            case add
        }
        
        case animation(EntityKeyboardAnimationData)
        case staticEmoji(String)
        case icon(Icon)
        
        public var id: Id {
            switch self {
            case let .animation(animation):
                return .animation(animation.id)
            case let .staticEmoji(value):
                return .staticEmoji(value)
            case let .icon(icon):
                return .icon(icon)
            }
        }
    }
    
    public final class Item: Equatable {
        public enum Icon: Equatable {
            case none
            case locked
            case premium
            case text(String)
            case customFile(TelegramMediaFile.Accessor)
        }
        
        public enum TintMode: Equatable {
            case none
            case accent
            case primary
            case custom(UIColor)
        }
        
        public let animationData: EntityKeyboardAnimationData?
        public let content: ItemContent
        public let itemFile: TelegramMediaFile.Accessor?
        public let itemGift: StarGift.UniqueGift?
        public let subgroupId: Int32?
        public let icon: Icon
        public let tintMode: TintMode
        
        public init(
            animationData: EntityKeyboardAnimationData?,
            content: ItemContent,
            itemFile: TelegramMediaFile.Accessor?,
            itemGift: StarGift.UniqueGift? = nil,
            subgroupId: Int32?,
            icon: Icon,
            tintMode: TintMode
        ) {
            self.animationData = animationData
            self.content = content
            self.itemFile = itemFile
            self.itemGift = itemGift
            self.subgroupId = subgroupId
            self.icon = icon
            self.tintMode = tintMode
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.animationData?.resource != rhs.animationData?.resource {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            if lhs.itemFile?.fileId != rhs.itemFile?.fileId {
                return false
            }
            if lhs.itemGift?.id != rhs.itemGift?.id {
                return false
            }
            if lhs.subgroupId != rhs.subgroupId {
                return false
            }
            if lhs.icon != rhs.icon {
                return false
            }
            if lhs.tintMode != rhs.tintMode {
                return false
            }
            
            return true
        }
    }
    
    public final class ItemGroup: Equatable {
        public let supergroupId: AnyHashable
        public let groupId: AnyHashable
        public let title: String?
        public let subtitle: String?
        public let badge: String?
        public let actionButtonTitle: String?
        public let isFeatured: Bool
        public let isPremiumLocked: Bool
        public let isEmbedded: Bool
        public let hasClear: Bool
        public let hasEdit: Bool
        public let collapsedLineCount: Int?
        public let displayPremiumBadges: Bool
        public let headerItem: EntityKeyboardAnimationData?
        public let fillWithLoadingPlaceholders: Bool
        public let customTintColor: UIColor?
        public let items: [Item]
        
        public init(
            supergroupId: AnyHashable,
            groupId: AnyHashable,
            title: String?,
            subtitle: String?,
            badge: String?,
            actionButtonTitle: String?,
            isFeatured: Bool,
            isPremiumLocked: Bool,
            isEmbedded: Bool,
            hasClear: Bool,
            hasEdit: Bool,
            collapsedLineCount: Int?,
            displayPremiumBadges: Bool,
            headerItem: EntityKeyboardAnimationData?,
            fillWithLoadingPlaceholders: Bool,
            customTintColor: UIColor? = nil,
            items: [Item]
        ) {
            self.supergroupId = supergroupId
            self.groupId = groupId
            self.title = title
            self.subtitle = subtitle
            self.badge = badge
            self.actionButtonTitle = actionButtonTitle
            self.isFeatured = isFeatured
            self.isPremiumLocked = isPremiumLocked
            self.isEmbedded = isEmbedded
            self.hasClear = hasClear
            self.hasEdit = hasEdit
            self.collapsedLineCount = collapsedLineCount
            self.displayPremiumBadges = displayPremiumBadges
            self.headerItem = headerItem
            self.fillWithLoadingPlaceholders = fillWithLoadingPlaceholders
            self.customTintColor = customTintColor
            self.items = items
        }
        
        public static func ==(lhs: ItemGroup, rhs: ItemGroup) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.supergroupId != rhs.supergroupId {
                return false
            }
            if lhs.groupId != rhs.groupId {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.subtitle != rhs.subtitle {
                return false
            }
            if lhs.badge != rhs.badge {
                return false
            }
            if lhs.actionButtonTitle != rhs.actionButtonTitle {
                return false
            }
            if lhs.isFeatured != rhs.isFeatured {
                return false
            }
            if lhs.isPremiumLocked != rhs.isPremiumLocked {
                return false
            }
            if lhs.isEmbedded != rhs.isEmbedded {
                return false
            }
            if lhs.hasClear != rhs.hasClear {
                return false
            }
            if lhs.collapsedLineCount != rhs.collapsedLineCount {
                return false
            }
            if lhs.displayPremiumBadges != rhs.displayPremiumBadges {
                return false
            }
            if lhs.headerItem != rhs.headerItem {
                return false
            }
            if lhs.fillWithLoadingPlaceholders != rhs.fillWithLoadingPlaceholders {
                return false
            }
            if lhs.customTintColor != rhs.customTintColor {
                return false
            }
            if lhs.items != rhs.items {
                return false
            }
            return true
        }
    }
    
    public enum ItemLayoutType {
        case compact
        case detailed
    }
    
    public enum SearchState: Equatable {
        case empty(hasResults: Bool)
        case searching
        case active
    }
    
    public final class EmptySearchResults: Equatable {
        public let text: String
        public let iconFile: TelegramMediaFile?
        
        public init(text: String, iconFile: TelegramMediaFile?) {
            self.text = text
            self.iconFile = iconFile
        }
        
        public static func ==(lhs: EmptySearchResults, rhs: EmptySearchResults) -> Bool {
            if lhs.text != rhs.text {
                return false
            }
            if lhs.iconFile?.fileId != rhs.iconFile?.fileId {
                return false
            }
            return true
        }
    }
    
    public struct ContentId: Equatable {
        public var id: AnyHashable
        public var version: Int
        
        public init(id: AnyHashable, version: Int) {
            self.id = id
            self.version = version
        }
    }
    
    public let id: AnyHashable
    public let context: AccountContext
    public let avatarPeer: EnginePeer?
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer
    public let inputInteractionHolder: InputInteractionHolder
    public let panelItemGroups: [ItemGroup]
    public let contentItemGroups: [ItemGroup]
    public let itemLayoutType: ItemLayoutType
    public let itemContentUniqueId: ContentId?
    public let searchState: SearchState
    public let warpContentsOnEdges: Bool
    public let hideBackground: Bool
    public let displaySearchWithPlaceholder: String?
    public let searchCategories: EmojiSearchCategories?
    public let searchInitiallyHidden: Bool
    public let searchAlwaysActive: Bool
    public let searchIsPlaceholderOnly: Bool
    public let searchUnicodeEmojiOnly: Bool
    public let emptySearchResults: EmptySearchResults?
    public let enableLongPress: Bool
    public let selectedItems: Set<AnyHashable>
    public let customTintColor: UIColor?
    
    public init(
        id: AnyHashable,
        context: AccountContext,
        avatarPeer: EnginePeer?,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        inputInteractionHolder: InputInteractionHolder,
        panelItemGroups: [ItemGroup],
        contentItemGroups: [ItemGroup],
        itemLayoutType: ItemLayoutType,
        itemContentUniqueId: ContentId?,
        searchState: SearchState,
        warpContentsOnEdges: Bool,
        hideBackground: Bool,
        displaySearchWithPlaceholder: String?,
        searchCategories: EmojiSearchCategories?,
        searchInitiallyHidden: Bool,
        searchAlwaysActive: Bool,
        searchIsPlaceholderOnly: Bool,
        searchUnicodeEmojiOnly: Bool,
        emptySearchResults: EmptySearchResults?,
        enableLongPress: Bool,
        selectedItems: Set<AnyHashable>,
        customTintColor: UIColor?
    ) {
        self.id = id
        self.context = context
        self.avatarPeer = avatarPeer
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.inputInteractionHolder = inputInteractionHolder
        self.panelItemGroups = panelItemGroups
        self.contentItemGroups = contentItemGroups
        self.itemLayoutType = itemLayoutType
        self.itemContentUniqueId = itemContentUniqueId
        self.searchState = searchState
        self.warpContentsOnEdges = warpContentsOnEdges
        self.hideBackground = hideBackground
        self.displaySearchWithPlaceholder = displaySearchWithPlaceholder
        self.searchCategories = searchCategories
        self.searchInitiallyHidden = searchInitiallyHidden
        self.searchAlwaysActive = searchAlwaysActive
        self.searchIsPlaceholderOnly = searchIsPlaceholderOnly
        self.searchUnicodeEmojiOnly = searchUnicodeEmojiOnly
        self.emptySearchResults = emptySearchResults
        self.enableLongPress = enableLongPress
        self.selectedItems = selectedItems
        self.customTintColor = customTintColor
    }
    
    public func withUpdatedItemGroups(panelItemGroups: [ItemGroup], contentItemGroups: [ItemGroup], itemContentUniqueId: ContentId?, emptySearchResults: EmptySearchResults?, searchState: SearchState) -> EmojiPagerContentComponent {
        return EmojiPagerContentComponent(
            id: self.id,
            context: self.context,
            avatarPeer: self.avatarPeer,
            animationCache: self.animationCache,
            animationRenderer: self.animationRenderer,
            inputInteractionHolder: self.inputInteractionHolder,
            panelItemGroups: panelItemGroups,
            contentItemGroups: contentItemGroups,
            itemLayoutType: self.itemLayoutType,
            itemContentUniqueId: itemContentUniqueId,
            searchState: searchState,
            warpContentsOnEdges: self.warpContentsOnEdges,
            hideBackground: self.hideBackground,
            displaySearchWithPlaceholder: self.displaySearchWithPlaceholder,
            searchCategories: self.searchCategories,
            searchInitiallyHidden: self.searchInitiallyHidden,
            searchAlwaysActive: self.searchAlwaysActive,
            searchIsPlaceholderOnly: self.searchIsPlaceholderOnly,
            searchUnicodeEmojiOnly: self.searchUnicodeEmojiOnly,
            emptySearchResults: emptySearchResults,
            enableLongPress: self.enableLongPress,
            selectedItems: self.selectedItems,
            customTintColor: self.customTintColor
        )
    }
    
    public func withSelectedItems(_ selectedItems: Set<MediaId>) -> EmojiPagerContentComponent {
        return EmojiPagerContentComponent(
            id: self.id,
            context: self.context,
            avatarPeer: self.avatarPeer,
            animationCache: self.animationCache,
            animationRenderer: self.animationRenderer,
            inputInteractionHolder: self.inputInteractionHolder,
            panelItemGroups: panelItemGroups,
            contentItemGroups: contentItemGroups,
            itemLayoutType: self.itemLayoutType,
            itemContentUniqueId: itemContentUniqueId,
            searchState: searchState,
            warpContentsOnEdges: self.warpContentsOnEdges,
            hideBackground: self.hideBackground,
            displaySearchWithPlaceholder: self.displaySearchWithPlaceholder,
            searchCategories: self.searchCategories,
            searchInitiallyHidden: self.searchInitiallyHidden,
            searchAlwaysActive: self.searchAlwaysActive,
            searchIsPlaceholderOnly: self.searchIsPlaceholderOnly,
            searchUnicodeEmojiOnly: self.searchUnicodeEmojiOnly,
            emptySearchResults: emptySearchResults,
            enableLongPress: self.enableLongPress,
            selectedItems: selectedItems,
            customTintColor: self.customTintColor
        )
    }
    
    public func withCustomTintColor(_ customTintColor: UIColor?) -> EmojiPagerContentComponent {
        return EmojiPagerContentComponent(
            id: self.id,
            context: self.context,
            avatarPeer: self.avatarPeer,
            animationCache: self.animationCache,
            animationRenderer: self.animationRenderer,
            inputInteractionHolder: self.inputInteractionHolder,
            panelItemGroups: panelItemGroups,
            contentItemGroups: contentItemGroups,
            itemLayoutType: self.itemLayoutType,
            itemContentUniqueId: itemContentUniqueId,
            searchState: searchState,
            warpContentsOnEdges: self.warpContentsOnEdges,
            hideBackground: self.hideBackground,
            displaySearchWithPlaceholder: self.displaySearchWithPlaceholder,
            searchCategories: self.searchCategories,
            searchInitiallyHidden: self.searchInitiallyHidden,
            searchAlwaysActive: self.searchAlwaysActive,
            searchIsPlaceholderOnly: self.searchIsPlaceholderOnly,
            searchUnicodeEmojiOnly: self.searchUnicodeEmojiOnly,
            emptySearchResults: emptySearchResults,
            enableLongPress: self.enableLongPress,
            selectedItems: self.selectedItems,
            customTintColor: customTintColor
        )
    }
    
    public static func ==(lhs: EmojiPagerContentComponent, rhs: EmojiPagerContentComponent) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.avatarPeer != rhs.avatarPeer {
            return false
        }
        if lhs.animationCache !== rhs.animationCache {
            return false
        }
        if lhs.animationRenderer !== rhs.animationRenderer {
            return false
        }
        if lhs.inputInteractionHolder !== rhs.inputInteractionHolder {
            return false
        }
        if lhs.panelItemGroups != rhs.panelItemGroups {
            return false
        }
        if lhs.contentItemGroups != rhs.contentItemGroups {
            return false
        }
        if lhs.itemLayoutType != rhs.itemLayoutType {
            return false
        }
        if lhs.itemContentUniqueId != rhs.itemContentUniqueId {
            return false
        }
        if lhs.searchState != rhs.searchState {
            return false
        }
        if lhs.warpContentsOnEdges != rhs.warpContentsOnEdges {
            return false
        }
        if lhs.hideBackground != rhs.hideBackground {
            return false
        }
        if lhs.displaySearchWithPlaceholder != rhs.displaySearchWithPlaceholder {
            return false
        }
        if lhs.searchCategories != rhs.searchCategories {
            return false
        }
        if lhs.searchInitiallyHidden != rhs.searchInitiallyHidden {
            return false
        }
        if lhs.searchAlwaysActive != rhs.searchAlwaysActive {
            return false
        }
        if lhs.searchIsPlaceholderOnly != rhs.searchIsPlaceholderOnly {
            return false
        }
        if lhs.emptySearchResults != rhs.emptySearchResults {
            return false
        }
        if lhs.enableLongPress != rhs.enableLongPress {
            return false
        }
        if lhs.selectedItems != rhs.selectedItems {
            return false
        }
        if lhs.customTintColor != rhs.customTintColor {
            return false
        }
        
        return true
    }
    
    public final class Tag {
        public let id: AnyHashable
        
        public init(id: AnyHashable) {
            self.id = id
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate, PagerContentViewWithBackground, ComponentTaggedView {
        private struct ItemGroupDescription: Equatable {
            let supergroupId: AnyHashable
            let groupId: AnyHashable
            let hasTitle: Bool
            let isPremiumLocked: Bool
            let isFeatured: Bool
            let itemCount: Int
            let isEmbedded: Bool
            let collapsedLineCount: Int?
        }
        
        private struct ItemGroupLayout: Equatable {
            let frame: CGRect
            let supergroupId: AnyHashable
            let groupId: AnyHashable
            let itemsPerRow: Int
            let nativeItemSize: CGFloat
            let visibleItemSize: CGFloat
            let playbackItemSize: CGFloat
            let horizontalSpacing: CGFloat
            let verticalSpacing: CGFloat
            let itemInsets: UIEdgeInsets
            let headerHeight: CGFloat
            let itemTopOffset: CGFloat
            let itemCount: Int
            let collapsedItemIndex: Int?
            let collapsedItemText: String?
        }
        
        private struct ItemLayout: Equatable {
            var layoutType: ItemLayoutType
            var width: CGFloat
            var headerInsets: UIEdgeInsets
            var itemInsets: UIEdgeInsets
            var curveNearBounds: Bool
            var itemGroupLayouts: [ItemGroupLayout]
            var itemDefaultHeaderHeight: CGFloat
            var itemFeaturedHeaderHeight: CGFloat
            var nativeItemSize: CGFloat
            let visibleItemSize: CGFloat
            let playbackItemSize: CGFloat
            var horizontalSpacing: CGFloat
            var verticalSpacing: CGFloat
            var verticalGroupDefaultSpacing: CGFloat
            var verticalGroupFeaturedSpacing: CGFloat
            var itemsPerRow: Int
            var customContentHeight: CGFloat
            var contentSize: CGSize
            
            var searchInsets: UIEdgeInsets
            var searchHeight: CGFloat
            
            var premiumButtonInset: CGFloat
            var premiumButtonHeight: CGFloat
            
            init(
                layoutType: ItemLayoutType,
                width: CGFloat,
                containerInsets: UIEdgeInsets,
                itemGroups: [ItemGroupDescription],
                expandedGroupIds: Set<AnyHashable>,
                curveNearBounds: Bool,
                displaySearch: Bool,
                isSearchActivated: Bool,
                customContentHeight: CGFloat,
                customLayout: CustomLayout?
            ) {
                self.layoutType = layoutType
                self.width = width
                self.customContentHeight = customContentHeight
                
                self.premiumButtonInset = 6.0
                self.premiumButtonHeight = 50.0
                
                self.searchHeight = 54.0
                self.searchInsets = UIEdgeInsets(top: max(0.0, containerInsets.top - 8.0), left: containerInsets.left, bottom: 0.0, right: containerInsets.right)
                
                self.curveNearBounds = curveNearBounds
                
                let minItemsPerRow: Int
                let minSpacing: CGFloat
                let itemInsets: UIEdgeInsets
                switch layoutType {
                case .compact:
                    minItemsPerRow = 8
                    self.nativeItemSize = 40.0
                    self.playbackItemSize = 48.0
                    self.verticalSpacing = 9.0
                    
                    if width >= 420.0 {
                        itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 5.0, bottom: containerInsets.bottom, right: containerInsets.right + 5.0)
                        minSpacing = 2.0
                    } else {
                        itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 7.0, bottom: containerInsets.bottom, right: containerInsets.right + 7.0)
                        minSpacing = 9.0
                    }
                    
                    self.headerInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 16.0, bottom: containerInsets.bottom, right: containerInsets.right + 16.0)
                    
                    self.itemDefaultHeaderHeight = 24.0
                    self.itemFeaturedHeaderHeight = self.itemDefaultHeaderHeight
                case .detailed:
                    minItemsPerRow = 5
                    self.nativeItemSize = 70.0
                    self.playbackItemSize = 96.0
                    self.verticalSpacing = 2.0
                    minSpacing = 12.0
                    self.itemDefaultHeaderHeight = 24.0
                    self.itemFeaturedHeaderHeight = 60.0
                    itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 10.0, bottom: containerInsets.bottom, right: containerInsets.right + 10.0)
                    self.headerInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 16.0, bottom: containerInsets.bottom, right: containerInsets.right + 16.0)
                }
                
                self.verticalGroupDefaultSpacing = 18.0
                self.verticalGroupFeaturedSpacing = 15.0
                
                if let customLayout = customLayout {
                    self.itemsPerRow = customLayout.itemsPerRow
                    self.nativeItemSize = customLayout.itemSize
                    self.visibleItemSize = customLayout.itemSize
                    self.verticalSpacing = 9.0
                    self.itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + customLayout.sideInset, bottom: containerInsets.bottom, right: containerInsets.right + customLayout.sideInset)
                    self.horizontalSpacing = customLayout.itemSpacing
                } else {
                    self.itemInsets = itemInsets
                    let itemHorizontalSpace = width - self.itemInsets.left - self.itemInsets.right
                    self.itemsPerRow = max(minItemsPerRow, Int((itemHorizontalSpace + minSpacing) / (self.nativeItemSize + minSpacing)))
                    let proposedItemSize = floor((itemHorizontalSpace - minSpacing * (CGFloat(self.itemsPerRow) - 1.0)) / CGFloat(self.itemsPerRow))
                    self.visibleItemSize = proposedItemSize < self.nativeItemSize ? proposedItemSize : self.nativeItemSize
                    self.horizontalSpacing = floorToScreenPixels((itemHorizontalSpace - self.visibleItemSize * CGFloat(self.itemsPerRow)) / CGFloat(self.itemsPerRow - 1))
                }
                
                let actualContentWidth = self.visibleItemSize * CGFloat(self.itemsPerRow) + self.horizontalSpacing * CGFloat(self.itemsPerRow - 1)
                self.itemInsets.left = floorToScreenPixels((width - actualContentWidth) / 2.0)
                self.itemInsets.right = self.itemInsets.left
                
                self.itemInsets.top += self.customContentHeight
                
                if displaySearch {
                    self.itemInsets.top += self.searchHeight - 4.0
                }
                
                var verticalGroupOrigin: CGFloat = self.itemInsets.top
                self.itemGroupLayouts = []
                for i in 0 ..< itemGroups.count {
                    let itemGroup = itemGroups[i]
                    var itemsPerRow = self.itemsPerRow
                    var nativeItemSize = self.nativeItemSize
                    var visibleItemSize = self.visibleItemSize
                    var playbackItemSize = self.playbackItemSize
                    var horizontalSpacing = self.horizontalSpacing
                    var verticalSpacing = self.verticalSpacing
                    var itemInsets = self.itemInsets

                    if itemGroup.groupId == AnyHashable("stickers") {
                        let minItemsPerRow = 5
                        nativeItemSize = 70.0
                        playbackItemSize = 96.0
                        verticalSpacing = 2.0
                        let minSpacing = 12.0

                        itemInsets = UIEdgeInsets(top: containerInsets.top, left: containerInsets.left + 10.0, bottom: containerInsets.bottom, right: containerInsets.right + 10.0)
                        
                        let itemHorizontalSpace = width - itemInsets.left - itemInsets.right
                        itemsPerRow = max(minItemsPerRow, Int((itemHorizontalSpace + minSpacing) / (nativeItemSize + minSpacing)))
                        let proposedItemSize = floor((itemHorizontalSpace - minSpacing * (CGFloat(itemsPerRow) - 1.0)) / CGFloat(itemsPerRow))
                        visibleItemSize = proposedItemSize < nativeItemSize ? proposedItemSize : nativeItemSize
                        horizontalSpacing = floorToScreenPixels((itemHorizontalSpace - visibleItemSize * CGFloat(itemsPerRow)) / CGFloat(itemsPerRow - 1))
                    }
                    
                    var itemTopOffset: CGFloat = 0.0
                    var headerHeight: CGFloat = 0.0
                    var groupSpacing = self.verticalGroupDefaultSpacing
                    if itemGroup.hasTitle {
                        if itemGroup.isFeatured {
                            headerHeight = self.itemFeaturedHeaderHeight
                            groupSpacing = self.verticalGroupFeaturedSpacing
                        } else {
                            headerHeight = self.itemDefaultHeaderHeight
                        }
                    }
                    if itemGroup.isEmbedded {
                        headerHeight += 32.0
                        groupSpacing -= 4.0
                    }
                    itemTopOffset += headerHeight
                    
                    var numRowsInGroup: Int
                    if itemGroup.isEmbedded {
                        numRowsInGroup = 0
                    } else {
                        numRowsInGroup = (itemGroup.itemCount + (itemsPerRow - 1)) / itemsPerRow
                    }
                    
                    var collapsedItemIndex: Int?
                    var collapsedItemText: String?
                    let visibleItemCount: Int
                    if itemGroup.isEmbedded {
                        visibleItemCount = 0
                    } else if let collapsedLineCount = itemGroup.collapsedLineCount, !expandedGroupIds.contains(itemGroup.groupId) {
                        let maxLines: Int = collapsedLineCount
                        if numRowsInGroup > maxLines {
                            visibleItemCount = itemsPerRow * maxLines - 1
                            collapsedItemIndex = visibleItemCount
                            collapsedItemText = "+\(itemGroup.itemCount - visibleItemCount)"
                        } else {
                            visibleItemCount = itemGroup.itemCount
                        }
                    } else {
                        visibleItemCount = itemGroup.itemCount
                    }
                    
                    if !itemGroup.isEmbedded {
                        numRowsInGroup = (visibleItemCount + (itemsPerRow - 1)) / itemsPerRow
                    }
                    
                    var groupContentSize = CGSize(width: width, height: itemTopOffset + CGFloat(numRowsInGroup) * visibleItemSize + CGFloat(max(0, numRowsInGroup - 1)) * verticalSpacing)
                    if (itemGroup.isPremiumLocked || itemGroup.isFeatured), case .compact = layoutType {
                        groupContentSize.height += self.premiumButtonInset + self.premiumButtonHeight
                    }
                    
                    self.itemGroupLayouts.append(ItemGroupLayout(
                        frame: CGRect(origin: CGPoint(x: 0.0, y: verticalGroupOrigin), size: groupContentSize),
                        supergroupId: itemGroup.supergroupId,
                        groupId: itemGroup.groupId,
                        itemsPerRow: itemsPerRow,
                        nativeItemSize: nativeItemSize,
                        visibleItemSize: visibleItemSize,
                        playbackItemSize: playbackItemSize,
                        horizontalSpacing: horizontalSpacing,
                        verticalSpacing: verticalSpacing,
                        itemInsets: itemInsets,
                        headerHeight: headerHeight,
                        itemTopOffset: itemTopOffset,
                        itemCount: visibleItemCount,
                        collapsedItemIndex: collapsedItemIndex,
                        collapsedItemText: collapsedItemText
                    ))
                    verticalGroupOrigin += groupContentSize.height
                    if i != itemGroups.count - 1 {
                        verticalGroupOrigin += groupSpacing
                    }
                }
                verticalGroupOrigin += itemInsets.bottom
                self.contentSize = CGSize(width: width, height: verticalGroupOrigin)
            }
            
            func frame(groupIndex: Int, itemIndex: Int) -> CGRect {
                let groupLayout = self.itemGroupLayouts[groupIndex]
                
                let row = itemIndex / groupLayout.itemsPerRow
                let column = itemIndex % groupLayout.itemsPerRow
                
                return CGRect(
                    origin: CGPoint(
                        x: groupLayout.itemInsets.left + CGFloat(column) * (groupLayout.visibleItemSize + groupLayout.horizontalSpacing),
                        y: groupLayout.frame.minY + groupLayout.itemTopOffset + CGFloat(row) * (groupLayout.visibleItemSize + groupLayout.verticalSpacing)
                    ),
                    size: CGSize(
                        width: groupLayout.visibleItemSize,
                        height: groupLayout.visibleItemSize
                    )
                )
            }
            
            func visibleItems(for rect: CGRect) -> [(supergroupId: AnyHashable, groupId: AnyHashable, groupIndex: Int, groupItems: Range<Int>?)] {
                var result: [(supergroupId: AnyHashable, groupId: AnyHashable, groupIndex: Int, groupItems: Range<Int>?)] = []
                
                for groupIndex in 0 ..< self.itemGroupLayouts.count {
                    let groupLayout = self.itemGroupLayouts[groupIndex]
                    
                    if !rect.intersects(groupLayout.frame) {
                        continue
                    }
                    let offsetRect = rect.offsetBy(dx: -groupLayout.itemInsets.left, dy: -groupLayout.frame.minY - groupLayout.itemTopOffset)
                    var minVisibleRow = Int(floor((offsetRect.minY - groupLayout.verticalSpacing) / (groupLayout.visibleItemSize + groupLayout.verticalSpacing)))
                    minVisibleRow = max(0, minVisibleRow)
                    let maxVisibleRow = Int(ceil((offsetRect.maxY - groupLayout.verticalSpacing) / (groupLayout.visibleItemSize + groupLayout.verticalSpacing)))

                    let minVisibleIndex = minVisibleRow * groupLayout.itemsPerRow
                    let maxVisibleIndex = min(groupLayout.itemCount - 1, (maxVisibleRow + 1) * groupLayout.itemsPerRow - 1)
                    
                    result.append((
                        supergroupId: groupLayout.supergroupId,
                        groupId: groupLayout.groupId,
                        groupIndex: groupIndex,
                        groupItems: maxVisibleIndex >= minVisibleIndex ? (minVisibleIndex ..< (maxVisibleIndex + 1)) : nil
                    ))
                }
                
                return result
            }
        }
        
        public final class ItemPlaceholderView: UIView {
            public enum Content {
                case thumbnail(Data)
                case template(UIImage)
            }
            
            private let shimmerView: PortalSourceView?
            private var placeholderView: PortalView?
            private let placeholderMaskLayer: SimpleLayer
            private var placeholderImageView: UIImageView?
            
            public init(
                context: AccountContext,
                dimensions: CGSize?,
                content: Content?,
                shimmerView: PortalSourceView?,
                color: UIColor,
                size: CGSize
            ) {
                self.shimmerView = shimmerView
                self.placeholderMaskLayer = SimpleLayer()
                
                super.init(frame: CGRect())
                
                if let shimmerView = self.shimmerView, let placeholderView = PortalView() {
                    self.placeholderView = placeholderView
                    
                    placeholderView.view.clipsToBounds = true
                    placeholderView.view.layer.mask = self.placeholderMaskLayer
                    self.addSubview(placeholderView.view)
                    shimmerView.addPortal(view: placeholderView)
                }
                
                let useDirectContent = self.placeholderView == nil
                if let content {
                    switch content {
                    case let .thumbnail(immediateThumbnailData):
                        Queue.concurrentDefaultQueue().async { [weak self] in
                            if let image = generateStickerPlaceholderImage(data: immediateThumbnailData, size: size, scale: min(2.0, UIScreenScale), imageSize: dimensions ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: useDirectContent ? color : .black) {
                                Queue.mainQueue().async {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    
                                    if useDirectContent {
                                        strongSelf.layer.contents = image.cgImage
                                    } else {
                                        strongSelf.placeholderMaskLayer.contents = image.cgImage
                                    }
                                }
                            }
                        }
                    case let .template(templateImage):
                        if useDirectContent {
                            self.layer.contents = templateImage.cgImage
                            self.tintColor = color
                        } else {
                            self.placeholderMaskLayer.contents = templateImage.cgImage
                        }
                    }
                }
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            public func update(size: CGSize) {
                if let placeholderView = self.placeholderView {
                    placeholderView.view.frame = CGRect(origin: CGPoint(), size: size)
                }
                self.placeholderMaskLayer.frame = CGRect(origin: CGPoint(), size: size)
            }
        }
        
        private final class GroupBorderLayer: PassthroughShapeLayer {
            let tintContainerLayer: CAShapeLayer
            
            override init() {
                self.tintContainerLayer = CAShapeLayer()
                
                super.init()
                
                self.mirrorLayer = self.tintContainerLayer
            }
            
            override func action(forKey event: String) -> CAAction? {
                return nullAction
            }
            
            override init(layer: Any) {
                self.tintContainerLayer = CAShapeLayer()
                
                super.init(layer: layer)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        private final class ItemSelectionLayer: PassthroughLayer {
            let tintContainerLayer: SimpleLayer
            
            override init() {
                self.tintContainerLayer = SimpleLayer()
                
                super.init()
                
                self.mirrorLayer = self.tintContainerLayer
            }
            
            override func action(forKey event: String) -> CAAction? {
                return nullAction
            }
            
            override init(layer: Any) {
                self.tintContainerLayer = SimpleLayer()
                
                super.init(layer: layer)
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
        }
        
        public final class ContentScrollLayer: CALayer {
            public var mirrorLayer: CALayer?
            
            override public init() {
                super.init()
            }
            
            override public init(layer: Any) {
                super.init(layer: layer)
            }
            
            required public init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override public var position: CGPoint {
                get {
                    return super.position
                } set(value) {
                    if let mirrorLayer = self.mirrorLayer {
                        mirrorLayer.position = value
                    }
                    super.position = value
                }
            }
            
            override public var bounds: CGRect {
                get {
                    return super.bounds
                } set(value) {
                    if let mirrorLayer = self.mirrorLayer {
                        mirrorLayer.bounds = value
                    }
                    super.bounds = value
                }
            }
            
            override public func add(_ animation: CAAnimation, forKey key: String?) {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.add(animation, forKey: key)
                }
                
                super.add(animation, forKey: key)
            }
            
            override public func removeAllAnimations() {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.removeAllAnimations()
                }
                
                super.removeAllAnimations()
            }
            
            override public func removeAnimation(forKey: String) {
                if let mirrorLayer = self.mirrorLayer {
                    mirrorLayer.removeAnimation(forKey: forKey)
                }
                
                super.removeAnimation(forKey: forKey)
            }
        }
        
        private final class ContentScrollView: UIScrollView, PagerExpandableScrollView {
            override static var layerClass: AnyClass {
                return ContentScrollLayer.self
            }
            
            private let mirrorView: UIView
            
            init(mirrorView: UIView) {
                self.mirrorView = mirrorView
                
                super.init(frame: CGRect())
                
                (self.layer as? ContentScrollLayer)?.mirrorLayer = mirrorView.layer
                self.canCancelContentTouches = true
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            override func touchesShouldCancel(in view: UIView) -> Bool {
                return true
            }
        }
        
        private enum VisualItemKey: Hashable {
            case item(id: EmojiKeyboardItemLayer.Key)
            case header(groupId: AnyHashable)
            case groupExpandButton(groupId: AnyHashable)
            case groupActionButton(groupId: AnyHashable)
        }
        
        private let shimmerHostView: PortalSourceView?
        private let standaloneShimmerEffect: StandaloneShimmerEffect?
        
        private var isSearchActivated: Bool = false
        
        private let backgroundView: BlurredBackgroundView
        private let backgroundTintView: UIView
        private var fadingMaskLayer: FadingMaskLayer?
        private var vibrancyClippingView: UIView
        private var vibrancyEffectView: UIView?
        public private(set) var mirrorContentClippingView: UIView?
        private let mirrorContentScrollView: UIView
        private var warpView: WarpView?
        private var mirrorContentWarpView: WarpView?
        
        private let scrollViewClippingView: UIView
        private let scrollView: ContentScrollView
        private var scrollGradientLayer: SimpleGradientLayer?
        private let boundsChangeTrackerLayer = SimpleLayer()
        private var effectiveVisibleSize: CGSize = CGSize()
        
        private let placeholdersContainerView: UIView
        private var visibleSearchHeader: EmojiSearchHeaderView?
        private var visibleEmptySearchResultsView: EmptySearchResultsView?
        private var visibleCustomContentView: EmojiCustomContentView?
        private var visibleItemPlaceholderViews: [EmojiKeyboardItemLayer.Key: ItemPlaceholderView] = [:]
        private var visibleFillPlaceholdersViews: [Int: ItemPlaceholderView] = [:]
        private var visibleItemSelectionLayers: [EmojiKeyboardItemLayer.Key: ItemSelectionLayer] = [:]
        private var visibleItemLayers: [EmojiKeyboardItemLayer.Key: EmojiKeyboardItemLayer] = [:]
        private var visibleGroupHeaders: [AnyHashable: GroupHeaderLayer] = [:]
        private var visibleGroupBorders: [AnyHashable: GroupBorderLayer] = [:]
        private var visibleGroupPremiumButtons: [AnyHashable: ComponentView<Empty>] = [:]
        private var visibleGroupExpandActionButtons: [AnyHashable: GroupExpandActionButton] = [:]
        private var expandedGroupIds: Set<AnyHashable> = Set()
        private var ignoreScrolling: Bool = false
        private var keepTopPanelVisibleUntilScrollingInput: Bool = false
        
        private struct FillPlaceholderParams: Equatable {
            var size: CGSize
            
            init(size: CGSize) {
                self.size = size
            }
        }
        
        private var fillPlaceholder: (params: FillPlaceholderParams, image: UIImage)?
        
        private var component: EmojiPagerContentComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var pagerEnvironment: PagerComponentChildEnvironment?
        private var keyboardChildEnvironment: EntityKeyboardChildEnvironment?
        private var activeItemUpdated: ActionSlot<(AnyHashable, AnyHashable?, ComponentTransition)>?
        private var itemLayout: ItemLayout?
        
        private var contextFocusItemKey: EmojiKeyboardItemLayer.Key?
        
        private var contextGesture: ContextGesture?
        private var tapRecognizer: UITapGestureRecognizer?
        private var longTapRecognizer: UILongPressGestureRecognizer?
        
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: nil)
            self.backgroundTintView = UIView()
            
            if ProcessInfo.processInfo.processorCount > 4 {
                self.shimmerHostView = PortalSourceView()
                self.standaloneShimmerEffect = StandaloneShimmerEffect()
            } else {
                self.shimmerHostView = nil
                self.standaloneShimmerEffect = nil
            }
            
            self.vibrancyClippingView = UIView()
            self.vibrancyClippingView.clipsToBounds = true
            
            self.scrollViewClippingView = UIView()
            self.scrollViewClippingView.clipsToBounds = true
            
            self.mirrorContentScrollView = UIView()
            self.mirrorContentScrollView.layer.anchorPoint = CGPoint()
            self.mirrorContentScrollView.clipsToBounds = true
            self.scrollView = ContentScrollView(mirrorView: self.mirrorContentScrollView)
            self.scrollView.layer.anchorPoint = CGPoint()
            
            self.placeholdersContainerView = UIView()
            
            super.init(frame: frame)
            
            self.backgroundView.addSubview(self.backgroundTintView)
            self.addSubview(self.backgroundView)
            
            if let shimmerHostView = self.shimmerHostView {
                shimmerHostView.alpha = 0.0
                self.addSubview(shimmerHostView)
            }
            
            self.boundsChangeTrackerLayer.opacity = 0.0
            self.layer.addSublayer(self.boundsChangeTrackerLayer)
            self.boundsChangeTrackerLayer.didEnterHierarchy = { [weak self] in
                self?.standaloneShimmerEffect?.updateLayer()
            }
            
            self.scrollView.delaysContentTouches = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = false
            self.scrollView.scrollsToTop = false
            self.addSubview(self.scrollViewClippingView)
            self.scrollViewClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.placeholdersContainerView)
            
            let contextGesture = ContextGesture(target: self, action: #selector(self.tapGesture(_:)))
            contextGesture.activateOnTap = true
            contextGesture.shouldBegin = { [weak self] point in
                guard let `self` = self, let _ = self.component else {
                    return false
                }
                
                let locationInScrollView = self.convert(point, to: self.scrollView)
                outer: for (_, groupHeader) in self.visibleGroupHeaders {
                    if groupHeader.frame.insetBy(dx: -10.0, dy: -6.0).contains(locationInScrollView) {
                        let groupHeaderPoint = self.scrollView.convert(locationInScrollView, to: groupHeader)
                        if let clearIconLayer = groupHeader.clearIconLayer, clearIconLayer.frame.insetBy(dx: -4.0, dy: -4.0).contains(groupHeaderPoint) {
                            return true
                        } else {
                            return true
                        }
                    }
                }
                
                var foundItem = false
                var foundExactItem = false
                if let (_, itemKey) = self.item(atPoint: point), let itemLayer = self.visibleItemLayers[itemKey] {
                    foundExactItem = true
                    foundItem = true
                    if !itemLayer.displayPlaceholder {
                        self.contextFocusItemKey = itemKey
                        return true
                    }
                }
                
                if !foundExactItem {
                    if let (_, itemKey) = self.item(atPoint: point, extendedHitRange: true), let itemLayer = self.visibleItemLayers[itemKey] {
                        foundItem = true
                        if !itemLayer.displayPlaceholder {
                            self.contextFocusItemKey = itemKey
                            return true
                        }
                    }
                }
                
                let _ = foundItem
                
                return false
            }
            contextGesture.activationProgress = { [weak self] progress, transition in
                guard let self = self, let contextFocusItemKey = self.contextFocusItemKey else {
                    return
                }
                if let itemLayer = self.visibleItemLayers[contextFocusItemKey] {
                    switch transition {
                    case .begin:
                        break
                    case .update:
                        ContainedViewLayoutTransition.immediate.updateTransformScale(layer: itemLayer, scale: 1.0 * (1.0 - progress) + 0.7 * progress)
                    case let .ended(previousValue):
                        let _ = previousValue
                    }
                }
            }
            contextGesture.activatedAfterCompletion = { [weak self] point, wasTap in
                guard let self, let component = self.component else {
                    return
                }
                
                if let contextFocusItemKey = self.contextFocusItemKey {
                    self.contextFocusItemKey = nil
                    if let itemLayer = self.visibleItemLayers[contextFocusItemKey] {
                        if wasTap {
                            let transition: ContainedViewLayoutTransition = .animated(duration: 0.08, curve: .linear)
                            transition.updateTransformScale(layer: itemLayer, scale: 0.7, completion: { [weak itemLayer] _ in
                                guard let itemLayer = itemLayer else {
                                    return
                                }
                                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .spring)
                                transition.updateTransformScale(layer: itemLayer, scale: 1.0)
                            })
                        } else {
                            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .spring)
                            transition.updateTransformScale(layer: itemLayer, scale: 1.0)
                        }
                    }
                }
                
                let locationInScrollView = self.convert(point, to: self.scrollView)
                outer: for (id, groupHeader) in self.visibleGroupHeaders {
                    if groupHeader.frame.insetBy(dx: -10.0, dy: -6.0).contains(locationInScrollView) {
                        let groupHeaderPoint = self.scrollView.convert(locationInScrollView, to: groupHeader)
                        if let clearIconLayer = groupHeader.clearIconLayer, clearIconLayer.frame.insetBy(dx: -4.0, dy: -4.0).contains(groupHeaderPoint) {
                            component.inputInteractionHolder.inputInteraction?.clearGroup(id)
                            return
                        } else {
                            if groupHeader.tapGesture(point: self.convert(point, to: groupHeader)) {
                                return
                            }
                        }
                    }
                }
                
                var foundItem = false
                var foundExactItem = false
                if let (item, itemKey) = self.item(atPoint: point), let itemLayer = self.visibleItemLayers[itemKey] {
                    foundExactItem = true
                    foundItem = true
                    if !itemLayer.displayPlaceholder {
                        component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, false)
                    }
                }
                
                if !foundExactItem {
                    if let (item, itemKey) = self.item(atPoint: point, extendedHitRange: true), let itemLayer = self.visibleItemLayers[itemKey] {
                        foundItem = true
                        if !itemLayer.displayPlaceholder {
                            component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, false)
                        }
                    }
                }
                
                let _ = foundItem
            }
            self.contextGesture = contextGesture
            self.addGestureRecognizer(contextGesture)
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            self.tapRecognizer = tapRecognizer
            self.addGestureRecognizer(tapRecognizer)
            
            let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressGesture(_:)))
            longTapRecognizer.minimumPressDuration = 0.2
            self.longTapRecognizer = longTapRecognizer
            self.addGestureRecognizer(longTapRecognizer)
            longTapRecognizer.isEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateIsWarpEnabled(isEnabled: Bool) {
            if isEnabled {
                if self.warpView == nil {
                    let warpView = WarpView(frame: CGRect())
                    self.warpView = warpView
                    
                    self.insertSubview(warpView, aboveSubview: self.scrollView)
                    warpView.contentView.addSubview(self.scrollView)
                }
                if self.mirrorContentWarpView == nil {
                    let mirrorContentWarpView = WarpView(frame: CGRect())
                    self.mirrorContentWarpView = mirrorContentWarpView
                    
                    mirrorContentWarpView.contentView.addSubview(self.mirrorContentScrollView)
                }
            } else {
                if let warpView = self.warpView {
                    self.warpView = nil
                    
                    self.insertSubview(self.scrollView, aboveSubview: warpView)
                    warpView.removeFromSuperview()
                }
                if let mirrorContentWarpView = self.mirrorContentWarpView {
                    self.mirrorContentWarpView = nil
                    
                    if let mirrorContentClippingView = self.mirrorContentClippingView {
                        mirrorContentClippingView.addSubview(self.mirrorContentScrollView)
                    } else if let vibrancyEffectView = self.vibrancyEffectView {
                        vibrancyEffectView.addSubview(self.mirrorContentScrollView)
                    }
                    
                    mirrorContentWarpView.removeFromSuperview()
                }
            }
        }
        
        public func matches(tag: Any) -> Bool {
            if let tag = tag as? Tag {
                if tag.id == self.component?.id {
                    return true
                }
            }
            return false
        }
        
        public func wantsDisplayBelowKeyboard() -> Bool {
            if let visibleSearchHeader = self.visibleSearchHeader {
                return visibleSearchHeader.wantsDisplayBelowKeyboard
            } else {
                return false
            }
        }
        
        public func animateIn(fromLocation: CGPoint) {
            let scrollLocation = self.convert(fromLocation, to: self.scrollView)
            for (key, itemLayer) in self.visibleItemLayers {
                let distanceVector = CGPoint(x: scrollLocation.x - itemLayer.position.x, y: scrollLocation.y - itemLayer.position.y)
                let distance = sqrt(distanceVector.x * distanceVector.x + distanceVector.y * distanceVector.y)
                
                let distanceNorm = min(1.0, max(0.0, distance / self.bounds.width))
                let delay = 0.05 + (distanceNorm) * 0.3
                
                let t = itemLayer.transform
                let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                
                itemLayer.animateScale(from: 0.01, to: currentScale, duration: 0.18, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                
                if let itemSelectionLayer = self.visibleItemSelectionLayers[key] {
                    itemSelectionLayer.animateScale(from: 0.01, to: 1.0, duration: 0.18, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        }
        
        public func animateInReactionSelection(sourceItems: [MediaId: (frame: CGRect, cornerRadius: CGFloat, frameIndex: Int, placeholder: UIImage)]) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }

            for (key, itemLayer) in self.visibleItemLayers {
                guard case let .animation(animationData) = itemLayer.item.content else {
                    continue
                }
                guard let file = itemLayer.item.itemFile else {
                    continue
                }
                if let sourceItem = sourceItems[file.fileId] {
                    itemLayer.animatePosition(from: CGPoint(x: sourceItem.frame.center.x - itemLayer.position.x, y: 0.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    
                    if let itemSelectionLayer = self.visibleItemSelectionLayers[key] {
                        itemSelectionLayer.animatePosition(from: CGPoint(x: sourceItem.frame.center.x - itemLayer.position.x, y: 0.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        
                        itemSelectionLayer.animate(from: (min(sourceItem.frame.width, sourceItem.frame.height) * 0.5) as NSNumber, to: 8.0 as NSNumber, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.3)
                    }
                    
                    if sourceItem.cornerRadius > 0.0 {
                        itemLayer.masksToBounds = true
                        itemLayer.animate(from: sourceItem.cornerRadius as NSNumber, to: 0.0 as NSNumber, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.3, completion: { [weak itemLayer] _ in
                            itemLayer?.masksToBounds = false
                        })
                    }
                    
                    if let resource = animationData.resource._parse() {
                        component.animationRenderer.setFrameIndex(itemId: resource.resource.id.stringRepresentation, size: itemLayer.pixelSize, frameIndex: sourceItem.frameIndex, placeholder: sourceItem.placeholder)
                    }
                } else {
                    let distance = itemLayer.position.y - itemLayout.frame(groupIndex: 0, itemIndex: 0).midY
                    let maxDistance = self.bounds.height
                    let clippedDistance = max(0.0, min(distance, maxDistance))
                    let distanceNorm = clippedDistance / maxDistance
                    
                    let delay = listViewAnimationCurveSystem(distanceNorm) * 0.1
                    
                    itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                    
                    let t = itemLayer.transform
                    let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                    
                    itemLayer.animateSpring(from: 0.01 as NSNumber, to: currentScale as NSNumber, keyPath: "transform.scale", duration: 0.6, delay: delay)
                    
                    if let itemSelectionLayer = self.visibleItemSelectionLayers[key] {
                        itemSelectionLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                        itemSelectionLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, delay: delay)
                    }
                }
            }
            
            for (_, groupHeader) in self.visibleGroupHeaders {
                let distance = groupHeader.layer.position.y - itemLayout.frame(groupIndex: 0, itemIndex: 0).midY
                let maxDistance = self.bounds.height
                let clippedDistance = max(0.0, min(distance, maxDistance))
                let distanceNorm = clippedDistance / maxDistance
                
                let delay = listViewAnimationCurveSystem(distanceNorm) * 0.16
                
                groupHeader.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                groupHeader.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, delay: delay)
                groupHeader.tintContentLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: delay)
                groupHeader.tintContentLayer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, delay: delay)
            }
        }
        
        public func layerForItem(groupId: AnyHashable, item: EmojiPagerContentComponent.Item) -> CALayer? {
            let itemKey = EmojiKeyboardItemLayer.Key(groupId: groupId, itemId: item.content.id)
            if let itemLayer = self.visibleItemLayers[itemKey] {
                return itemLayer
            } else {
                return nil
            }
        }
        
        public func scrollToTop() {
            guard let _ = self.component, let _ = self.pagerEnvironment, let itemLayout = self.itemLayout else {
                return
            }
            if itemLayout.itemGroupLayouts.isEmpty {
                return
            }
            
            if "".isEmpty {
                let wasIgnoringScrollingEvents = self.ignoreScrolling
                self.ignoreScrolling = true
                self.scrollView.setContentOffset(self.scrollView.contentOffset, animated: false)
                
                self.keepTopPanelVisibleUntilScrollingInput = true
                
                let scrollPosition: CGFloat = 0.0
                
                let offsetDirectionSign: Double = scrollPosition < self.scrollView.bounds.minY ? -1.0 : 1.0
                
                var previousVisibleLayers: [EmojiKeyboardItemLayer.Key: (CALayer, CGRect)] = [:]
                for (id, layer) in self.visibleItemLayers {
                    previousVisibleLayers[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                }
                var previousVisibleItemSelectionLayers: [EmojiKeyboardItemLayer.Key: (CALayer, CGRect)] = [:]
                for (id, layer) in self.visibleItemSelectionLayers {
                    previousVisibleItemSelectionLayers[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                }
                var previousVisiblePlaceholderViews: [EmojiKeyboardItemLayer.Key: (UIView, CGRect)] = [:]
                for (id, view) in self.visibleItemPlaceholderViews {
                    previousVisiblePlaceholderViews[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                }
                var previousVisibleGroupHeaders: [AnyHashable: (GroupHeaderLayer, CGRect)] = [:]
                for (id, view) in self.visibleGroupHeaders {
                    if !self.scrollView.bounds.intersects(view.frame) {
                        continue
                    }
                    previousVisibleGroupHeaders[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                }
                var previousVisibleGroupBorders: [AnyHashable: (GroupBorderLayer, CGRect)] = [:]
                for (id, layer) in self.visibleGroupBorders {
                    previousVisibleGroupBorders[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                }
                var previousVisibleGroupPremiumButtons: [AnyHashable: (UIView, CGRect)] = [:]
                for (id, view) in self.visibleGroupPremiumButtons {
                    if let view = view.view {
                        previousVisibleGroupPremiumButtons[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                }
                var previousVisibleGroupExpandActionButtons: [AnyHashable: (GroupExpandActionButton, CGRect)] = [:]
                for (id, view) in self.visibleGroupExpandActionButtons {
                    previousVisibleGroupExpandActionButtons[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                }
                
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: scrollPosition), size: self.scrollView.bounds.size)
                self.ignoreScrolling = wasIgnoringScrollingEvents
                
                self.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: true, previousItemPositions: nil, updatedItemPositions: nil)
                
                var commonItemOffset: CGFloat?
                var previousVisibleBoundingRect: CGRect?
                for (id, layerAndFrame) in previousVisibleLayers {
                    if let layer = self.visibleItemLayers[id] {
                        if commonItemOffset == nil {
                            let visibleFrame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                        }
                        break
                    } else {
                        if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                            previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                        } else {
                            previousVisibleBoundingRect = layerAndFrame.1
                        }
                    }
                }
                
                for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                    if let view = self.visibleItemPlaceholderViews[id] {
                        if commonItemOffset == nil {
                            let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                        }
                        break
                    } else {
                        if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                            previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                        } else {
                            previousVisibleBoundingRect = viewAndFrame.1
                        }
                    }
                }
                
                for (id, layerAndFrame) in previousVisibleGroupHeaders {
                    if let view = self.visibleGroupHeaders[id] {
                        if commonItemOffset == nil, self.scrollView.bounds.intersects(view.frame) {
                            let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                        }
                        break
                    } else {
                        if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                            previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                        } else {
                            previousVisibleBoundingRect = layerAndFrame.1
                        }
                    }
                }
                
                for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                    if let view = self.visibleGroupPremiumButtons[id]?.view, self.scrollView.bounds.intersects(view.frame) {
                        if commonItemOffset == nil {
                            let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                        }
                        break
                    } else {
                        if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                            previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                        } else {
                            previousVisibleBoundingRect = viewAndFrame.1
                        }
                    }
                }
                
                for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                    if let view = self.visibleGroupExpandActionButtons[id], self.scrollView.bounds.intersects(view.frame) {
                        if commonItemOffset == nil {
                            let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                        }
                        break
                    } else {
                        if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                            previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                        } else {
                            previousVisibleBoundingRect = viewAndFrame.1
                        }
                    }
                }
                
                let duration = 0.4
                let timingFunction = kCAMediaTimingFunctionSpring
                
                if let commonItemOffset = commonItemOffset {
                    for (_, layer) in self.visibleItemLayers {
                        layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                    }
                    for (id, layerAndFrame) in previousVisibleLayers {
                        if self.visibleItemLayers[id] != nil {
                            continue
                        }
                        let layer = layerAndFrame.0
                        self.scrollView.layer.addSublayer(layer)
                        layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                            layer?.removeFromSuperlayer()
                        })
                    }
                    
                    for (_, view) in self.visibleItemPlaceholderViews {
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                    }
                    for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                        if self.visibleItemPlaceholderViews[id] != nil {
                            continue
                        }
                        let view = viewAndFrame.0
                        self.placeholdersContainerView.addSubview(view)
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    }
                    
                    for (_, view) in self.visibleGroupHeaders {
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                    }
                    for (id, viewAndFrame) in previousVisibleGroupHeaders {
                        if self.visibleGroupHeaders[id] != nil {
                            continue
                        }
                        let view = viewAndFrame.0
                        self.scrollView.addSubview(view)
                        let tintContentLayer = view.tintContentLayer
                        self.mirrorContentScrollView.layer.addSublayer(tintContentLayer)
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContentLayer] _ in
                            view?.removeFromSuperview()
                            tintContentLayer?.removeFromSuperlayer()
                        })
                    }
                    
                    for (_, layer) in self.visibleGroupBorders {
                        layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                    }
                    for (id, layerAndFrame) in previousVisibleGroupBorders {
                        if self.visibleGroupBorders[id] != nil {
                            continue
                        }
                        let layer = layerAndFrame.0
                        self.scrollView.layer.addSublayer(layer)
                        let tintContainerLayer = layer.tintContainerLayer
                        self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                        layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                            layer?.removeFromSuperlayer()
                            tintContainerLayer?.removeFromSuperlayer()
                        })
                    }
                    
                    for (_, view) in self.visibleGroupPremiumButtons {
                        if let view = view.view {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                    }
                    for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                        if self.visibleGroupPremiumButtons[id] != nil {
                            continue
                        }
                        let view = viewAndFrame.0
                        self.scrollView.addSubview(view)
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                            view?.removeFromSuperview()
                        })
                    }
                    
                    for (_, view) in self.visibleGroupExpandActionButtons {
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                    }
                    for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                        if self.visibleGroupExpandActionButtons[id] != nil {
                            continue
                        }
                        let view = viewAndFrame.0
                        self.scrollView.addSubview(view)
                        let tintContainerLayer = view.tintContainerLayer
                        self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                        view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContainerLayer] _ in
                            view?.removeFromSuperview()
                            tintContainerLayer?.removeFromSuperlayer()
                        })
                    }
                } else if let previousVisibleBoundingRect = previousVisibleBoundingRect {
                    var updatedVisibleBoundingRect: CGRect?
                    
                    for (_, layer) in self.visibleItemLayers {
                        let frame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                        if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                            updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                        } else {
                            updatedVisibleBoundingRect = frame
                        }
                    }
                    for (_, view) in self.visibleItemPlaceholderViews {
                        let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                        if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                            updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                        } else {
                            updatedVisibleBoundingRect = frame
                        }
                    }
                    for (_, view) in self.visibleGroupHeaders {
                        if !self.scrollView.bounds.intersects(view.frame) {
                            continue
                        }
                        let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                        if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                            updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                        } else {
                            updatedVisibleBoundingRect = frame
                        }
                    }
                    for (_, view) in self.visibleGroupPremiumButtons {
                        if let view = view.view {
                            if !self.scrollView.bounds.intersects(view.frame) {
                                continue
                            }
                            
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                    }
                    for (_, view) in self.visibleGroupExpandActionButtons {
                        if !self.scrollView.bounds.intersects(view.frame) {
                            continue
                        }
                        
                        let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                        if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                            updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                        } else {
                            updatedVisibleBoundingRect = frame
                        }
                    }
                    
                    if let updatedVisibleBoundingRect = updatedVisibleBoundingRect {
                        var commonItemOffset = updatedVisibleBoundingRect.height * offsetDirectionSign
                        
                        if previousVisibleBoundingRect.intersects(updatedVisibleBoundingRect) {
                            if offsetDirectionSign < 0.0 {
                                commonItemOffset = previousVisibleBoundingRect.minY - updatedVisibleBoundingRect.maxY
                            } else {
                                commonItemOffset = previousVisibleBoundingRect.maxY - updatedVisibleBoundingRect.minY
                            }
                        }
                        
                        for (_, layer) in self.visibleItemLayers {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (_, layer) in self.visibleItemSelectionLayers {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleLayers {
                            if self.visibleItemLayers[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            self.scrollView.layer.addSublayer(layer)
                            layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                layer?.removeFromSuperlayer()
                            })
                        }
                        for (id, layerAndFrame) in previousVisibleItemSelectionLayers {
                            if self.visibleItemSelectionLayers[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            self.scrollView.layer.addSublayer(layer)
                            layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                layer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleItemPlaceholderViews {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                            if self.visibleItemPlaceholderViews[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            self.placeholdersContainerView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupHeaders {
                            if !self.scrollView.bounds.intersects(view.frame) {
                                continue
                            }
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisibleGroupHeaders {
                            if self.visibleGroupHeaders[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            self.scrollView.addSubview(view)
                            let tintContentLayer = view.tintContentLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContentLayer)
                            view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContentLayer] _ in
                                view?.removeFromSuperview()
                                tintContentLayer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, layer) in self.visibleGroupBorders {
                            if !self.scrollView.bounds.intersects(layer.frame) {
                                continue
                            }
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleGroupBorders {
                            if self.visibleGroupBorders[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            self.scrollView.layer.addSublayer(layer)
                            let tintContainerLayer = layer.tintContainerLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                            layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                                layer?.removeFromSuperlayer()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupPremiumButtons {
                            if let view = view.view {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                        }
                        for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                            if self.visibleGroupPremiumButtons[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            self.scrollView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupExpandActionButtons {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                            if self.visibleGroupExpandActionButtons[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                            self.scrollView.addSubview(view)
                            let tintContainerLayer = view.tintContainerLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                            view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContainerLayer] _ in
                                view?.removeFromSuperview()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                    }
                }
            }
        }
        
        public func scrollToItemGroup(id supergroupId: AnyHashable, subgroupId: Int32?, animated: Bool) {
            guard let component = self.component, let pagerEnvironment = self.pagerEnvironment, let itemLayout = self.itemLayout else {
                return
            }
            
            if !component.contentItemGroups.contains(where: { $0.groupId == supergroupId }), self.isSearchActivated {
                self.visibleSearchHeader?.clearCategorySearch()
                return
            }
            
            guard let itemGroup = component.contentItemGroups.first(where: { $0.supergroupId == supergroupId }) else {
                return
            }
            
            for groupIndex in 0 ..< itemLayout.itemGroupLayouts.count {
                let group = itemLayout.itemGroupLayouts[groupIndex]
                
                var subgroupItemIndex: Int?
                if group.supergroupId == supergroupId {
                    if let subgroupId = subgroupId {
                        inner: for itemGroup in component.contentItemGroups {
                            if itemGroup.supergroupId == supergroupId {
                                for i in 0 ..< itemGroup.items.count {
                                    if itemGroup.items[i].subgroupId == subgroupId {
                                        subgroupItemIndex = i
                                        break
                                    }
                                }
                                break inner
                            }
                        }
                    }
                    let wasIgnoringScrollingEvents = self.ignoreScrolling
                    self.ignoreScrolling = true
                    self.scrollView.setContentOffset(self.scrollView.contentOffset, animated: false)
                    
                    self.keepTopPanelVisibleUntilScrollingInput = true
                    
                    let anchorFrame: CGRect
                    if let subgroupItemIndex = subgroupItemIndex {
                        anchorFrame = itemLayout.frame(groupIndex: groupIndex, itemIndex: subgroupItemIndex)
                    } else {
                        anchorFrame = group.frame
                    }
                    
                    var scrollPosition = anchorFrame.minY + floor(-itemLayout.verticalGroupDefaultSpacing / 2.0) - pagerEnvironment.containerInsets.top
                    if !animated {
                        scrollPosition = floor(anchorFrame.midY - self.scrollView.bounds.height * 0.5)
                    }
                    if scrollPosition > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                        scrollPosition = self.scrollView.contentSize.height - self.scrollView.bounds.height
                    }
                    if scrollPosition < 0.0 {
                        scrollPosition = 0.0
                    }
                    
                    if !animated, let keyboardChildEnvironment = self.keyboardChildEnvironment, let inputInteraction = component.inputInteractionHolder.inputInteraction, inputInteraction.useOpaqueTheme {
                        let highlightLayer = SimpleLayer()
                        highlightLayer.backgroundColor = keyboardChildEnvironment.theme.list.itemAccentColor.withMultipliedAlpha(0.1).cgColor
                        highlightLayer.cornerRadius = 20.0
                        var highlightFrame = group.frame
                        if highlightFrame.origin.x < 4.0 {
                            highlightFrame.size.width += (4.0 - highlightFrame.origin.x)
                            highlightFrame.origin.x = 4.0
                        }
                        if highlightFrame.minX + highlightFrame.size.width > self.scrollView.bounds.width - 4.0 {
                            highlightFrame.size.width = self.scrollView.bounds.width - 4.0 - highlightFrame.minX
                        }
                        
                        if (itemGroup.isPremiumLocked || itemGroup.isFeatured), !itemGroup.isEmbedded, case .compact = itemLayout.layoutType {
                            highlightFrame.size.height += 6.0
                        }
                        
                        highlightLayer.frame = highlightFrame
                        self.scrollView.layer.insertSublayer(highlightLayer, at: 0)
                        highlightLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.8, removeOnCompletion: false, completion: { [weak highlightLayer] _ in
                            highlightLayer?.removeFromSuperlayer()
                        })
                    }
                    
                    let offsetDirectionSign: Double = scrollPosition < self.scrollView.bounds.minY ? -1.0 : 1.0
                    
                    var previousVisibleLayers: [EmojiKeyboardItemLayer.Key: (CALayer, CGRect)] = [:]
                    for (id, layer) in self.visibleItemLayers {
                        previousVisibleLayers[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleItemSelectionLayers: [EmojiKeyboardItemLayer.Key: (ItemSelectionLayer, CGRect)] = [:]
                    for (id, layer) in self.visibleItemSelectionLayers {
                        previousVisibleItemSelectionLayers[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisiblePlaceholderViews: [EmojiKeyboardItemLayer.Key: (UIView, CGRect)] = [:]
                    for (id, view) in self.visibleItemPlaceholderViews {
                        previousVisiblePlaceholderViews[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupHeaders: [AnyHashable: (GroupHeaderLayer, CGRect)] = [:]
                    for (id, view) in self.visibleGroupHeaders {
                        if !self.scrollView.bounds.intersects(view.frame) {
                            continue
                        }
                        previousVisibleGroupHeaders[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupBorders: [AnyHashable: (GroupBorderLayer, CGRect)] = [:]
                    for (id, layer) in self.visibleGroupBorders {
                        previousVisibleGroupBorders[id] = (layer, layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    var previousVisibleGroupPremiumButtons: [AnyHashable: (UIView, CGRect)] = [:]
                    for (id, view) in self.visibleGroupPremiumButtons {
                        if let view = view.view {
                            previousVisibleGroupPremiumButtons[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                        }
                    }
                    var previousVisibleGroupExpandActionButtons: [AnyHashable: (GroupExpandActionButton, CGRect)] = [:]
                    for (id, view) in self.visibleGroupExpandActionButtons {
                        previousVisibleGroupExpandActionButtons[id] = (view, view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY))
                    }
                    
                    self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: scrollPosition), size: self.scrollView.bounds.size)
                    self.ignoreScrolling = wasIgnoringScrollingEvents
                    
                    self.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: true, previousItemPositions: nil, updatedItemPositions: nil)
                    
                    var commonItemOffset: CGFloat?
                    var previousVisibleBoundingRect: CGRect?
                    for (id, layerAndFrame) in previousVisibleLayers {
                        if let layer = self.visibleItemLayers[id] {
                            if commonItemOffset == nil {
                                let visibleFrame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }
                    
                    for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                        if let view = self.visibleItemPlaceholderViews[id] {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    for (id, layerAndFrame) in previousVisibleGroupHeaders {
                        if let view = self.visibleGroupHeaders[id] {
                            if commonItemOffset == nil, self.scrollView.bounds.intersects(view.frame) {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = layerAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = layerAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = layerAndFrame.1
                            }
                        }
                    }
                    
                    for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                        if let view = self.visibleGroupPremiumButtons[id]?.view, self.scrollView.bounds.intersects(view.frame) {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                        if let view = self.visibleGroupExpandActionButtons[id], self.scrollView.bounds.intersects(view.frame) {
                            if commonItemOffset == nil {
                                let visibleFrame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                commonItemOffset = viewAndFrame.1.minY - visibleFrame.minY
                            }
                            break
                        } else {
                            if let previousVisibleBoundingRectValue = previousVisibleBoundingRect {
                                previousVisibleBoundingRect = viewAndFrame.1.union(previousVisibleBoundingRectValue)
                            } else {
                                previousVisibleBoundingRect = viewAndFrame.1
                            }
                        }
                    }
                    
                    let duration: Double = animated ? 0.4 : 0.0
                    let timingFunction = kCAMediaTimingFunctionSpring
                    
                    if let commonItemOffset = commonItemOffset {
                        for (_, layer) in self.visibleItemLayers {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (_, layer) in self.visibleItemSelectionLayers {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        
                        for (id, layerAndFrame) in previousVisibleLayers {
                            if self.visibleItemLayers[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                layer?.removeFromSuperlayer()
                            })
                        }
                        for (id, layerAndFrame) in previousVisibleItemSelectionLayers {
                            if self.visibleItemSelectionLayers[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            let tintContainerLayer = layer.tintContainerLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                                layer?.removeFromSuperlayer()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleItemPlaceholderViews {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                            if self.visibleItemPlaceholderViews[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.placeholdersContainerView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupHeaders {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisibleGroupHeaders {
                            if self.visibleGroupHeaders[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.scrollView.addSubview(view)
                            let tintContentLayer = view.tintContentLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContentLayer)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContentLayer] _ in
                                view?.removeFromSuperview()
                                tintContentLayer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, layer) in self.visibleGroupBorders {
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, layerAndFrame) in previousVisibleGroupBorders {
                            if self.visibleGroupBorders[id] != nil {
                                continue
                            }
                            let layer = layerAndFrame.0
                            self.scrollView.layer.addSublayer(layer)
                            let tintContainerLayer = layer.tintContainerLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                            layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                                layer?.removeFromSuperlayer()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupPremiumButtons {
                            if let view = view.view {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                        }
                        for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                            if self.visibleGroupPremiumButtons[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.scrollView.addSubview(view)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        }
                        
                        for (_, view) in self.visibleGroupExpandActionButtons {
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                        }
                        for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                            if self.visibleGroupExpandActionButtons[id] != nil {
                                continue
                            }
                            let view = viewAndFrame.0
                            self.scrollView.addSubview(view)
                            let tintContainerLayer = view.tintContainerLayer
                            self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                            view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContainerLayer] _ in
                                view?.removeFromSuperview()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                    } else if let previousVisibleBoundingRect = previousVisibleBoundingRect {
                        var updatedVisibleBoundingRect: CGRect?
                        
                        for (_, layer) in self.visibleItemLayers {
                            let frame = layer.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleItemPlaceholderViews {
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleGroupHeaders {
                            if !self.scrollView.bounds.intersects(view.frame) {
                                continue
                            }
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        for (_, view) in self.visibleGroupPremiumButtons {
                            if let view = view.view {
                                if !self.scrollView.bounds.intersects(view.frame) {
                                    continue
                                }
                                
                                let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                                if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                    updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                                } else {
                                    updatedVisibleBoundingRect = frame
                                }
                            }
                        }
                        for (_, view) in self.visibleGroupExpandActionButtons {
                            if !self.scrollView.bounds.intersects(view.frame) {
                                continue
                            }
                            
                            let frame = view.frame.offsetBy(dx: 0.0, dy: -self.scrollView.bounds.minY)
                            if let updatedVisibleBoundingRectValue = updatedVisibleBoundingRect {
                                updatedVisibleBoundingRect = frame.union(updatedVisibleBoundingRectValue)
                            } else {
                                updatedVisibleBoundingRect = frame
                            }
                        }
                        
                        if let updatedVisibleBoundingRect = updatedVisibleBoundingRect {
                            var commonItemOffset = updatedVisibleBoundingRect.height * offsetDirectionSign
                            
                            if previousVisibleBoundingRect.intersects(updatedVisibleBoundingRect) {
                                if offsetDirectionSign < 0.0 {
                                    commonItemOffset = previousVisibleBoundingRect.minY - updatedVisibleBoundingRect.maxY
                                } else {
                                    commonItemOffset = previousVisibleBoundingRect.maxY - updatedVisibleBoundingRect.minY
                                }
                            }
                            
                            for (_, layer) in self.visibleItemLayers {
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (_, layer) in self.visibleItemSelectionLayers {
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, layerAndFrame) in previousVisibleLayers {
                                if self.visibleItemLayers[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer] _ in
                                    layer?.removeFromSuperlayer()
                                })
                            }
                            for (id, layerAndFrame) in previousVisibleItemSelectionLayers {
                                if self.visibleItemSelectionLayers[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                let tintContainerLayer = layer.tintContainerLayer
                                self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                                    layer?.removeFromSuperlayer()
                                    tintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, view) in self.visibleItemPlaceholderViews {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, viewAndFrame) in previousVisiblePlaceholderViews {
                                if self.visibleItemPlaceholderViews[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.placeholdersContainerView.addSubview(view)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                    view?.removeFromSuperview()
                                })
                            }
                            
                            for (_, view) in self.visibleGroupHeaders {
                                if !self.scrollView.bounds.intersects(view.frame) {
                                    continue
                                }
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, viewAndFrame) in previousVisibleGroupHeaders {
                                if self.visibleGroupHeaders[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.addSubview(view)
                                let tintContentLayer = view.tintContentLayer
                                self.mirrorContentScrollView.layer.addSublayer(tintContentLayer)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContentLayer] _ in
                                    view?.removeFromSuperview()
                                    tintContentLayer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, layer) in self.visibleGroupBorders {
                                if !self.scrollView.bounds.intersects(layer.frame) {
                                    continue
                                }
                                layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, layerAndFrame) in previousVisibleGroupBorders {
                                if self.visibleGroupBorders[id] != nil {
                                    continue
                                }
                                let layer = layerAndFrame.0
                                layer.frame = layerAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.layer.addSublayer(layer)
                                let tintContainerLayer = layer.tintContainerLayer
                                self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                                layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak layer, weak tintContainerLayer] _ in
                                    layer?.removeFromSuperlayer()
                                    tintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                            
                            for (_, view) in self.visibleGroupPremiumButtons {
                                if let view = view.view {
                                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                                }
                            }
                            for (id, viewAndFrame) in previousVisibleGroupPremiumButtons {
                                if self.visibleGroupPremiumButtons[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.addSubview(view)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view] _ in
                                    view?.removeFromSuperview()
                                })
                            }
                            
                            for (_, view) in self.visibleGroupExpandActionButtons {
                                view.layer.animatePosition(from: CGPoint(x: 0.0, y: commonItemOffset), to: CGPoint(), duration: duration, timingFunction: timingFunction, additive: true)
                            }
                            for (id, viewAndFrame) in previousVisibleGroupExpandActionButtons {
                                if self.visibleGroupExpandActionButtons[id] != nil {
                                    continue
                                }
                                let view = viewAndFrame.0
                                view.frame = viewAndFrame.1.offsetBy(dx: 0.0, dy: self.scrollView.bounds.minY)
                                self.scrollView.addSubview(view)
                                let tintContainerLayer = view.tintContainerLayer
                                self.mirrorContentScrollView.layer.addSublayer(tintContainerLayer)
                                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -commonItemOffset), duration: duration, timingFunction: timingFunction, removeOnCompletion: false, additive: true, completion: { [weak view, weak tintContainerLayer] _ in
                                    view?.removeFromSuperview()
                                    tintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                        }
                    }
                }
            }
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                if self.scrollViewClippingView.bounds.contains(recognizer.location(in: self.scrollViewClippingView)) {
                    let locationInScrollView = recognizer.location(in: self.scrollView)
                    outer: for (id, groupHeader) in self.visibleGroupHeaders {
                        if groupHeader.frame.insetBy(dx: -10.0, dy: -6.0).contains(locationInScrollView) {
                            let groupHeaderPoint = self.scrollView.convert(locationInScrollView, to: groupHeader)
                            if let clearIconLayer = groupHeader.clearIconLayer, clearIconLayer.frame.insetBy(dx: -4.0, dy: -4.0).contains(groupHeaderPoint) {
                                component.inputInteractionHolder.inputInteraction?.clearGroup(id)
                                return
                            } else {
                                if groupHeader.tapGesture(point: recognizer.location(in: groupHeader)) {
                                    return
                                }
                            }
                        }
                    }
                    
                    var foundItem = false
                    var foundExactItem = false
                    if let (item, itemKey) = self.item(atPoint: recognizer.location(in: self)), let itemLayer = self.visibleItemLayers[itemKey] {
                        foundExactItem = true
                        foundItem = true
                        if !itemLayer.displayPlaceholder {
                            component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, false)
                        }
                    }
                    
                    if !foundExactItem {
                        if let (item, itemKey) = self.item(atPoint: recognizer.location(in: self), extendedHitRange: true), let itemLayer = self.visibleItemLayers[itemKey] {
                            foundItem = true
                            if !itemLayer.displayPlaceholder {
                                component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, false)
                            }
                        }
                    }
                    
                    let _ = foundItem
                }
            }
        }
        
        private let longPressDuration: Double = 0.5
        private var longPressItem: EmojiKeyboardItemLayer.Key?
        private var currentLongPressLayer: EmojiKeyboardCloneItemLayer?
        private var hapticFeedback: HapticFeedback?
        private var continuousHaptic: AnyObject?
        private var longPressTimer: SwiftSignalKit.Timer?
        
        @objc private func longPressGesture(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                let point = recognizer.location(in: self)
                
                guard let item = self.item(atPoint: point), let itemLayer = self.visibleItemLayers[item.1] else {
                    return
                }
                switch item.0.content {
                case .animation:
                    break
                default:
                    return
                }
                
                if item.0.icon == .locked {
                    return
                }
                
                self.longPressItem = item.1
                
                if #available(iOS 13.0, *), item.0.itemFile != nil {
                    self.continuousHaptic = try? ContinuousHaptic(duration: longPressDuration)
                }
                
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                
                if let externalExpansionView = self.component?.inputInteractionHolder.inputInteraction?.externalExpansionView {
                    if let currentLongPressLayer = self.currentLongPressLayer {
                        self.currentLongPressLayer = nil
                        currentLongPressLayer.removeFromSuperlayer()
                    }
                    let currentLongPressLayer = EmojiKeyboardCloneItemLayer()
                    currentLongPressLayer.position = self.scrollView.layer.convert(itemLayer.position, to: externalExpansionView.layer)
                    currentLongPressLayer.bounds = itemLayer.convert(itemLayer.bounds, to: externalExpansionView.layer)
                    currentLongPressLayer.transform = itemLayer.transform
                    externalExpansionView.layer.addSublayer(currentLongPressLayer)
                    self.currentLongPressLayer = currentLongPressLayer
                    itemLayer.cloneLayer = currentLongPressLayer
                    
                    itemLayer.isHidden = true
                    let transition = ComponentTransition(animation: .curve(duration: longPressDuration, curve: .easeInOut))
                    transition.setScale(layer: currentLongPressLayer, scale: 1.85)
                }
                
                self.longPressTimer?.invalidate()
                self.longPressTimer = SwiftSignalKit.Timer(timeout: longPressDuration, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.longTapRecognizer?.state = .ended
                }, queue: .mainQueue())
                self.longPressTimer?.start()
            case .changed:
                let point = recognizer.location(in: self)
                
                if let longPressItem = self.longPressItem, let item = self.item(atPoint: point), longPressItem == item.1 {
                } else {
                    self.longTapRecognizer?.state = .cancelled
                }
            case .cancelled:
                self.longPressTimer?.invalidate()
                self.continuousHaptic = nil
                
                if let itemKey = self.longPressItem {
                    self.longPressItem = nil
                    
                    if let itemLayer = self.visibleItemLayers[itemKey] {
                        let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                        transition.setScale(layer: itemLayer, scale: 1.0)
                        
                        if let currentLongPressLayer = self.currentLongPressLayer {
                            self.currentLongPressLayer = nil
                            
                            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setScale(layer: currentLongPressLayer, scale: 1.0, completion: { [weak itemLayer, weak currentLongPressLayer] _ in
                                itemLayer?.isHidden = false
                                currentLongPressLayer?.removeFromSuperlayer()
                            })
                        }
                    } else if let currentLongPressLayer = self.currentLongPressLayer {
                        self.currentLongPressLayer = nil
                        currentLongPressLayer.removeFromSuperlayer()
                    }
                } else if let currentLongPressLayer = self.currentLongPressLayer {
                    self.currentLongPressLayer = nil
                    currentLongPressLayer.removeFromSuperlayer()
                }
            case .ended:
                self.longPressTimer?.invalidate()
                self.continuousHaptic = nil
                
                if let itemKey = self.longPressItem {
                    self.longPressItem = nil
                    
                    if let component = self.component, let itemLayer = self.visibleItemLayers[itemKey] {
                        if let externalExpansionView = self.component?.inputInteractionHolder.inputInteraction?.externalExpansionView, let currentLongPressLayer = self.currentLongPressLayer {
                            component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, itemLayer.item, externalExpansionView, currentLongPressLayer.frame, currentLongPressLayer, true)
                        } else {
                            component.inputInteractionHolder.inputInteraction?.performItemAction(itemKey.groupId, itemLayer.item, self, self.scrollView.convert(itemLayer.frame, to: self), itemLayer, true)
                        }
                    } else {
                        if let itemLayer = self.visibleItemLayers[itemKey] {
                            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setScale(layer: itemLayer, scale: 1.0)
                            
                            if let currentLongPressLayer = self.currentLongPressLayer {
                                self.currentLongPressLayer = nil
                                
                                let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                                transition.setScale(layer: currentLongPressLayer, scale: 1.0, completion: { [weak itemLayer, weak currentLongPressLayer] _ in
                                    itemLayer?.isHidden = false
                                    currentLongPressLayer?.removeFromSuperlayer()
                                })
                            }
                        } else if let currentLongPressLayer = self.currentLongPressLayer {
                            self.currentLongPressLayer = nil
                            
                            let transition = ComponentTransition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setScale(layer: currentLongPressLayer, scale: 1.0, completion: { [weak currentLongPressLayer] _ in
                                currentLongPressLayer?.removeFromSuperlayer()
                            })
                        }
                    }
                }
            default:
                break
            }
        }
        
        private func item(atPoint point: CGPoint, extendedHitRange: Bool = false) -> (Item, EmojiKeyboardItemLayer.Key)? {
            let localPoint = self.convert(point, to: self.scrollView)
            
            var closestItem: (key: EmojiKeyboardItemLayer.Key, distance: CGFloat)?
            
            for (key, itemLayer) in self.visibleItemLayers {
                if extendedHitRange {
                    let position = CGPoint(x: itemLayer.frame.midX, y: itemLayer.frame.midY)
                    let distance = CGPoint(x: localPoint.x - position.x, y: localPoint.y - position.y)
                    let distance2 = distance.x * distance.x + distance.y * distance.y
                    if distance2 > pow(max(itemLayer.bounds.width, itemLayer.bounds.height), 2.0) {
                        continue
                    }
                    
                    if let closestItemValue = closestItem {
                        if closestItemValue.distance > distance2 {
                            closestItem = (key, distance2)
                        }
                    } else {
                        closestItem = (key, distance2)
                    }
                } else {
                    if itemLayer.frame.contains(localPoint) {
                        return (itemLayer.item, key)
                    }
                }
            }
            
            if let key = closestItem?.key {
                if let itemLayer = self.visibleItemLayers[key] {
                    return (itemLayer.item, key)
                }
            }
            
            return nil
        }
        
        private struct ScrollingOffsetState: Equatable {
            var value: CGFloat
            var isDraggingOrDecelerating: Bool
        }
        
        private var previousScrollingOffset: ScrollingOffsetState?
                
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            if self.keepTopPanelVisibleUntilScrollingInput {
                self.keepTopPanelVisibleUntilScrollingInput = false
                
                self.updateScrollingOffset(isReset: true, transition: .immediate)
            }
            if let presentation = scrollView.layer.presentation() {
                scrollView.bounds = presentation.bounds
                scrollView.layer.removeAllAnimations()
            }
            
            if let component = self.component, self.isSearchActivated, let visibleSearchHeader = self.visibleSearchHeader, visibleSearchHeader.isActive && !component.searchAlwaysActive {
                visibleSearchHeader.deactivate()
            }
            self.component?.inputInteractionHolder.inputInteraction?.onScroll()
            self.component?.inputInteractionHolder.inputInteraction?.scrollingStickersGridPromise.set(true)
        }
        
        public func ensureSearchUnfocused() {
            if self.isSearchActivated, let visibleSearchHeader = self.visibleSearchHeader, visibleSearchHeader.currentPresetSearchTerm == nil {
                self.visibleSearchHeader?.deactivate()
            } else {
                self.visibleSearchHeader?.endEditing(true)
            }
        }
    
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if self.ignoreScrolling {
                return
            }
            
            self.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: false, previousItemPositions: nil, updatedItemPositions: nil)
            
            self.updateScrollingOffset(isReset: false, transition: .immediate)
            
            if let stateContext = self.component?.inputInteractionHolder.inputInteraction?.stateContext {
                stateContext.scrollPosition = scrollView.bounds.minY
            }
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            if velocity.y != 0.0 {
                targetContentOffset.pointee.y = self.snappedContentOffset(proposedOffset: targetContentOffset.pointee.y)
            }
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                self.snapScrollingOffsetToInsets()
                self.component?.inputInteractionHolder.inputInteraction?.scrollingStickersGridPromise.set(false)
            }
        }
        
        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            self.snapScrollingOffsetToInsets()
            self.component?.inputInteractionHolder.inputInteraction?.scrollingStickersGridPromise.set(false)
        }
        
        private func updateScrollingOffset(isReset: Bool, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }

            let isInteracting = self.scrollView.isDragging || self.scrollView.isDecelerating
            if let previousScrollingOffsetValue = self.previousScrollingOffset, !self.keepTopPanelVisibleUntilScrollingInput, !self.isSearchActivated {
                let currentBounds = self.scrollView.bounds
                let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
                let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
                
                let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue.value
                if !component.warpContentsOnEdges {
                    self.pagerEnvironment?.onChildScrollingUpdate(PagerComponentChildEnvironment.ContentScrollingUpdate(
                        relativeOffset: relativeOffset,
                        absoluteOffsetToTopEdge: offsetToTopEdge,
                        absoluteOffsetToBottomEdge: offsetToBottomEdge,
                        isReset: isReset,
                        isInteracting: isInteracting,
                        transition: transition
                    ))
                }
            }
            self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: isInteracting)
        }
        
        private func snappedContentOffset(proposedOffset: CGFloat) -> CGFloat {
            guard let pagerEnvironment = self.pagerEnvironment else {
                return proposedOffset
            }
            
            var proposedOffset = proposedOffset
            let bounds = self.bounds
            if proposedOffset + bounds.height > self.scrollView.contentSize.height - pagerEnvironment.containerInsets.bottom {
                proposedOffset = self.scrollView.contentSize.height - bounds.height
            }
            if proposedOffset < pagerEnvironment.containerInsets.top {
                proposedOffset = 0.0
            }
            
            return proposedOffset
        }
        
        private func snapScrollingOffsetToInsets() {
            let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
            
            var currentBounds = self.scrollView.bounds
            currentBounds.origin.y = self.snappedContentOffset(proposedOffset: currentBounds.minY)
            transition.setBounds(view: self.scrollView, bounds: currentBounds)
            
            self.updateScrollingOffset(isReset: false, transition: transition)
        }
        
        private func updateVisibleItems(transition: ComponentTransition, attemptSynchronousLoads: Bool, previousItemPositions: [VisualItemKey: CGPoint]?, previousAbsoluteItemPositions: [VisualItemKey: CGPoint]? = nil, updatedItemPositions: [VisualItemKey: CGPoint]?, hintDisappearingGroupFrame: (groupId: AnyHashable, frame: CGRect)? = nil) {
            guard let component = self.component, let pagerEnvironment = self.pagerEnvironment, let keyboardChildEnvironment = self.keyboardChildEnvironment, let itemLayout = self.itemLayout else {
                return
            }
            
            let useOpaqueTheme = component.inputInteractionHolder.inputInteraction?.useOpaqueTheme ?? false
            
            var topVisibleGroupId: AnyHashable?
            var topVisibleSubgroupId: AnyHashable?
            
            var validIds = Set<EmojiKeyboardItemLayer.Key>()
            var validGroupHeaderIds = Set<AnyHashable>()
            var validGroupBorderIds = Set<AnyHashable>()
            var validGroupPremiumButtonIds = Set<AnyHashable>()
            var validGroupExpandActionButtons = Set<AnyHashable>()
            var validFillPlaceholdersIndices = Set<Int>()
            
            let effectiveVisibleBounds = CGRect(origin: self.scrollView.bounds.origin, size: self.effectiveVisibleSize)
            let topVisibleDetectionBounds = effectiveVisibleBounds.offsetBy(dx: 0.0, dy: pagerEnvironment.containerInsets.top)
            
            let contentAnimation = transition.userData(ContentAnimation.self)
            var transitionHintInstalledGroupId: AnyHashable?
            var transitionHintExpandedGroupId: AnyHashable?
            if let contentAnimation = contentAnimation {
                switch contentAnimation.type {
                case let .groupInstalled(groupId, scrollToGroup):
                    if scrollToGroup {
                        transitionHintInstalledGroupId = groupId
                    }
                case let .groupExpanded(groupId):
                    transitionHintExpandedGroupId = groupId
                case let .groupRemoved(groupId):
                    transitionHintInstalledGroupId = groupId
                default:
                    break
                }
            }
            
            for groupItems in itemLayout.visibleItems(for: effectiveVisibleBounds) {
                let itemGroup = component.contentItemGroups[groupItems.groupIndex]
                let itemGroupLayout = itemLayout.itemGroupLayouts[groupItems.groupIndex]
                
                var assignTopVisibleSubgroupId = false
                if topVisibleGroupId == nil && itemGroupLayout.frame.intersects(topVisibleDetectionBounds) {
                    topVisibleGroupId = groupItems.supergroupId
                    assignTopVisibleSubgroupId = true
                }
                
                var headerCentralContentWidth: CGFloat?
                var headerSizeUpdated = false
                if let title = itemGroup.title {
                    let hasEdit = itemGroup.hasEdit
                    validGroupHeaderIds.insert(itemGroup.groupId)
                    let groupHeaderView: GroupHeaderLayer
                    var groupHeaderTransition = transition
                    if let current = self.visibleGroupHeaders[itemGroup.groupId] {
                        groupHeaderView = current
                    } else {
                        groupHeaderTransition = .immediate
                        let groupId = itemGroup.groupId
                        groupHeaderView = GroupHeaderLayer(
                            actionPressed: { [weak self] in
                                guard let strongSelf = self, let component = strongSelf.component else {
                                    return
                                }
                                if hasEdit {
                                    component.inputInteractionHolder.inputInteraction?.editAction(groupId)
                                } else {
                                    component.inputInteractionHolder.inputInteraction?.addGroupAction(groupId, false, true)
                                }
                            },
                            performItemAction: { [weak self] item, view, rect, layer in
                                guard let strongSelf = self, let component = strongSelf.component else {
                                    return
                                }
                                component.inputInteractionHolder.inputInteraction?.performItemAction(groupId, item, view, rect, layer, false)
                            }
                        )
                        self.visibleGroupHeaders[itemGroup.groupId] = groupHeaderView
                        self.scrollView.addSubview(groupHeaderView)
                        self.mirrorContentScrollView.layer.addSublayer(groupHeaderView.tintContentLayer)
                    }
                    
                    var actionButtonTitle: String?
                    var actionButtonIsCompact = false
                    if case .detailed = itemLayout.layoutType, itemGroup.isFeatured {
                        actionButtonTitle = itemGroup.actionButtonTitle
                    } else if itemGroup.hasEdit {
                        actionButtonTitle = keyboardChildEnvironment.strings.Stickers_Edit
                        actionButtonIsCompact = true
                    }
                    
                    let hasTopSeparator = false
                    
                    let (groupHeaderSize, centralContentWidth) = groupHeaderView.update(
                        context: component.context,
                        theme: keyboardChildEnvironment.theme,
                        forceNeedsVibrancy: component.inputInteractionHolder.inputInteraction?.externalBackground != nil,
                        layoutType: itemLayout.layoutType,
                        hasTopSeparator: hasTopSeparator,
                        actionButtonTitle: actionButtonTitle,
                        actionButtonIsCompact: actionButtonIsCompact,
                        title: title,
                        subtitle: itemGroup.subtitle,
                        badge: itemGroup.badge,
                        isPremiumLocked: itemGroup.isPremiumLocked,
                        hasClear: itemGroup.hasClear,
                        embeddedItems: itemGroup.isEmbedded ? itemGroup.items : nil,
                        isStickers: component.itemLayoutType == .detailed,
                        constrainedSize: CGSize(width: itemLayout.contentSize.width - itemLayout.headerInsets.left - itemLayout.headerInsets.right, height: itemGroupLayout.headerHeight),
                        insets: itemLayout.headerInsets,
                        cache: component.animationCache,
                        renderer: component.animationRenderer,
                        attemptSynchronousLoad: attemptSynchronousLoads
                    )
                    
                    if groupHeaderView.bounds.size != groupHeaderSize {
                        headerSizeUpdated = true
                    }
                    headerCentralContentWidth = centralContentWidth
                    
                    let groupHeaderFrame = CGRect(origin: CGPoint(x: floor((itemLayout.contentSize.width - groupHeaderSize.width) / 2.0), y: itemGroupLayout.frame.minY + 1.0), size: groupHeaderSize)
                    groupHeaderView.bounds = CGRect(origin: CGPoint(), size: groupHeaderFrame.size)
                    groupHeaderTransition.setPosition(view: groupHeaderView, position: CGPoint(x: groupHeaderFrame.midX, y: groupHeaderFrame.midY))
                }
                
                let groupBorderRadius: CGFloat = 16.0
                
                if itemGroup.isPremiumLocked && !itemGroup.isFeatured && !itemGroup.isEmbedded && !itemLayout.curveNearBounds {
                    validGroupBorderIds.insert(itemGroup.groupId)
                    let groupBorderLayer: GroupBorderLayer
                    var groupBorderTransition = transition
                    if let current = self.visibleGroupBorders[itemGroup.groupId] {
                        groupBorderLayer = current
                    } else {
                        groupBorderTransition = .immediate
                        groupBorderLayer = GroupBorderLayer()
                        self.visibleGroupBorders[itemGroup.groupId] = groupBorderLayer
                        self.scrollView.layer.insertSublayer(groupBorderLayer, at: 0)
                        self.mirrorContentScrollView.layer.addSublayer(groupBorderLayer.tintContainerLayer)
                        
                        let borderColor: UIColor
                        if keyboardChildEnvironment.theme.overallDarkAppearance && component.inputInteractionHolder.inputInteraction?.externalBackground != nil {
                            borderColor = keyboardChildEnvironment.theme.chat.inputMediaPanel.panelContentVibrantOverlayColor.withMultipliedAlpha(0.2)
                        } else {
                            borderColor = keyboardChildEnvironment.theme.chat.inputMediaPanel.panelContentVibrantOverlayColor
                        }
                        
                        groupBorderLayer.strokeColor = borderColor.cgColor
                        groupBorderLayer.tintContainerLayer.strokeColor = UIColor.black.cgColor
                        groupBorderLayer.lineWidth = 1.6
                        groupBorderLayer.lineCap = .round
                        groupBorderLayer.fillColor = nil
                    }
                    
                    let groupBorderHorizontalInset: CGFloat = itemLayout.itemInsets.left - 4.0
                    let groupBorderVerticalTopOffset: CGFloat = 8.0
                    let groupBorderVerticalInset: CGFloat = 6.0
                    
                    let groupBorderFrame = CGRect(origin: CGPoint(x: groupBorderHorizontalInset, y: itemGroupLayout.frame.minY + groupBorderVerticalTopOffset), size: CGSize(width: itemLayout.width - groupBorderHorizontalInset * 2.0, height: itemGroupLayout.frame.size.height - groupBorderVerticalTopOffset + groupBorderVerticalInset))
                    
                    if groupBorderLayer.bounds.size != groupBorderFrame.size || headerSizeUpdated {
                        let headerWidth: CGFloat
                        if let headerCentralContentWidth = headerCentralContentWidth {
                            headerWidth = headerCentralContentWidth + 14.0
                        } else {
                            headerWidth = 0.0
                        }
                        let path = CGMutablePath()
                        let radius = groupBorderRadius
                        path.move(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0), y: 0.0))
                        path.addLine(to: CGPoint(x: radius, y: 0.0))
                        path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: 0.0, y: radius), radius: radius)
                        path.addLine(to: CGPoint(x: 0.0, y: groupBorderFrame.height - radius))
                        path.addArc(tangent1End: CGPoint(x: 0.0, y: groupBorderFrame.height), tangent2End: CGPoint(x: radius, y: groupBorderFrame.height), radius: radius)
                        path.addLine(to: CGPoint(x: groupBorderFrame.width - radius, y: groupBorderFrame.height))
                        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height), tangent2End: CGPoint(x: groupBorderFrame.width, y: groupBorderFrame.height - radius), radius: radius)
                        path.addLine(to: CGPoint(x: groupBorderFrame.width, y: radius))
                        path.addArc(tangent1End: CGPoint(x: groupBorderFrame.width, y: 0.0), tangent2End: CGPoint(x: groupBorderFrame.width - radius, y: 0.0), radius: radius)
                        path.addLine(to: CGPoint(x: floor((groupBorderFrame.width - headerWidth) / 2.0) + headerWidth, y: 0.0))
                        
                        let pathLength = (2.0 * groupBorderFrame.width + 2.0 * groupBorderFrame.height - 8.0 * radius + 2.0 * .pi * radius) - headerWidth
                        
                        var numberOfDashes = Int(floor(pathLength / 6.0))
                        if numberOfDashes % 2 == 0 {
                            numberOfDashes -= 1
                        }
                        let wholeLength = 6.0 * CGFloat(numberOfDashes)
                        let remainingLength = pathLength - wholeLength
                        let dashSpace = remainingLength / CGFloat(numberOfDashes)
                        
                        groupBorderTransition.setShapeLayerPath(layer: groupBorderLayer, path: path)
                        groupBorderTransition.setShapeLayerLineDashPattern(layer: groupBorderLayer, pattern: [(5.0 + dashSpace) as NSNumber, (7.0 + dashSpace) as NSNumber])
                    }
                    groupBorderTransition.setFrame(layer: groupBorderLayer, frame: groupBorderFrame)
                }
                
                if (itemGroup.isPremiumLocked || itemGroup.isFeatured), !itemGroup.isEmbedded, case .compact = itemLayout.layoutType {
                    let groupPremiumButtonMeasuringFrame = CGRect(origin: CGPoint(x: itemLayout.itemInsets.left, y: itemGroupLayout.frame.maxY - 50.0 + 1.0), size: CGSize(width: 100.0, height: 50.0))
                    
                    if effectiveVisibleBounds.intersects(groupPremiumButtonMeasuringFrame) {
                        validGroupPremiumButtonIds.insert(itemGroup.groupId)
                        
                        let groupPremiumButton: ComponentView<Empty>
                        var groupPremiumButtonTransition = transition
                        var animateButtonIn = false
                        if let current = self.visibleGroupPremiumButtons[itemGroup.groupId] {
                            groupPremiumButton = current
                        } else {
                            groupPremiumButtonTransition = .immediate
                            animateButtonIn = !transition.animation.isImmediate
                            groupPremiumButton = ComponentView<Empty>()
                            self.visibleGroupPremiumButtons[itemGroup.groupId] = groupPremiumButton
                        }
                        
                        let groupId = itemGroup.groupId
                        let isPremiumLocked = itemGroup.isPremiumLocked
                        
                        let title: String
                        let backgroundColor: UIColor
                        let backgroundColors: [UIColor]
                        let foregroundColor: UIColor
                        let animationName: String?
                        let gloss: Bool
                        if itemGroup.isPremiumLocked {
                            title = keyboardChildEnvironment.strings.EmojiInput_UnlockPack(itemGroup.title ?? "Emoji").string
                            backgroundColors = [
                                UIColor(rgb: 0x0077ff),
                                UIColor(rgb: 0x6b93ff),
                                UIColor(rgb: 0x8878ff),
                                UIColor(rgb: 0xe46ace)
                            ]
                            backgroundColor = backgroundColors[0]
                            foregroundColor = .white
                            animationName = "premium_unlock"
                            gloss = true
                        } else {
                            title = keyboardChildEnvironment.strings.EmojiInput_AddPack(itemGroup.title ?? "Emoji").string
                            backgroundColors = []
                            backgroundColor = keyboardChildEnvironment.theme.list.itemCheckColors.fillColor
                            foregroundColor = keyboardChildEnvironment.theme.list.itemCheckColors.foregroundColor
                            animationName = nil
                            gloss = false
                        }
                        
                        let groupPremiumButtonSize = groupPremiumButton.update(
                            transition: groupPremiumButtonTransition,
                            component: AnyComponent(SolidRoundedButtonComponent(
                                title: title,
                                theme: SolidRoundedButtonComponent.Theme(
                                    backgroundColor: backgroundColor,
                                    backgroundColors: backgroundColors,
                                    foregroundColor: foregroundColor
                                ),
                                font: .bold,
                                fontSize: 17.0,
                                height: 50.0,
                                cornerRadius: groupBorderRadius,
                                gloss: gloss,
                                animationName: animationName,
                                iconPosition: .right,
                                iconSpacing: 4.0,
                                action: { [weak self] in
                                    guard let strongSelf = self, let component = strongSelf.component else {
                                        return
                                    }
                                    component.inputInteractionHolder.inputInteraction?.addGroupAction(groupId, isPremiumLocked, true)
                                }
                            )),
                            environment: {},
                            containerSize: CGSize(width: itemLayout.width - itemLayout.itemInsets.left - itemLayout.itemInsets.right, height: itemLayout.premiumButtonHeight)
                        )
                        let groupPremiumButtonFrame = CGRect(origin: CGPoint(x: itemLayout.itemInsets.left, y: itemGroupLayout.frame.maxY - groupPremiumButtonSize.height + 1.0), size: groupPremiumButtonSize)
                        if let view = groupPremiumButton.view {
                            if view.superview == nil {
                                self.scrollView.addSubview(view)
                            }
                            
                            if animateButtonIn, !transition.animation.isImmediate {
                                if let previousItemPosition = previousItemPositions?[.groupActionButton(groupId: itemGroup.groupId)], transitionHintInstalledGroupId != itemGroup.groupId, transitionHintExpandedGroupId != itemGroup.groupId {
                                    groupPremiumButtonTransition = transition
                                    view.center = previousItemPosition
                                }
                            }
                            
                            groupPremiumButtonTransition.setFrame(view: view, frame: groupPremiumButtonFrame)
                            if animateButtonIn, !transition.animation.isImmediate {
                                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                transition.animateScale(view: view, from: 0.01, to: 1.0)
                            }
                        }
                    }
                }
                
                if !itemGroup.isEmbedded, let collapsedItemIndex = itemGroupLayout.collapsedItemIndex, let collapsedItemText = itemGroupLayout.collapsedItemText {
                    validGroupExpandActionButtons.insert(itemGroup.groupId)
                    let groupId = itemGroup.groupId
                    
                    var animateButtonIn = false
                    var groupExpandActionButtonTransition = transition
                    let groupExpandActionButton: GroupExpandActionButton
                    if let current = self.visibleGroupExpandActionButtons[itemGroup.groupId] {
                        groupExpandActionButton = current
                    } else {
                        groupExpandActionButtonTransition = .immediate
                        animateButtonIn = !transition.animation.isImmediate
                        groupExpandActionButton = GroupExpandActionButton(pressed: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.expandGroup(groupId: groupId)
                        })
                        self.visibleGroupExpandActionButtons[itemGroup.groupId] = groupExpandActionButton
                        self.scrollView.addSubview(groupExpandActionButton)
                        self.mirrorContentScrollView.layer.addSublayer(groupExpandActionButton.tintContainerLayer)
                    }
                    
                    if animateButtonIn, !transition.animation.isImmediate {
                        if let previousItemPosition = previousItemPositions?[.groupExpandButton(groupId: itemGroup.groupId)], transitionHintInstalledGroupId != itemGroup.groupId, transitionHintExpandedGroupId != itemGroup.groupId {
                            groupExpandActionButtonTransition = transition
                            groupExpandActionButton.center = previousItemPosition
                        }
                    }
                    
                    let baseItemFrame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: collapsedItemIndex)
                    let buttonSize = groupExpandActionButton.update(theme: keyboardChildEnvironment.theme, title: collapsedItemText, useOpaqueTheme: useOpaqueTheme)
                    let buttonFrame = CGRect(origin: CGPoint(x: baseItemFrame.minX + floor((baseItemFrame.width - buttonSize.width) / 2.0), y: baseItemFrame.minY + floor((baseItemFrame.height - buttonSize.height) / 2.0)), size: buttonSize)
                    groupExpandActionButtonTransition.setFrame(view: groupExpandActionButton, frame: buttonFrame)
                }
                
                if !itemGroup.isEmbedded, let groupItemRange = groupItems.groupItems {
                    for index in groupItemRange.lowerBound ..< groupItemRange.upperBound {
                        let item = itemGroup.items[index]
                        
                        if assignTopVisibleSubgroupId {
                            if let subgroupId = item.subgroupId {
                                topVisibleSubgroupId = AnyHashable(subgroupId)
                            }
                        }
                        
                        let itemId = EmojiKeyboardItemLayer.Key(
                            groupId: itemGroup.groupId,
                            itemId: item.content.id
                        )
                        validIds.insert(itemId)
                        
                        let itemDimensions: CGSize = item.animationData?.dimensions ?? CGSize(width: 512.0, height: 512.0)
                        
                        let itemNativeFitSize = itemDimensions.aspectFitted(CGSize(width: itemGroupLayout.nativeItemSize, height: itemGroupLayout.nativeItemSize))
                        let itemVisibleFitSize = itemDimensions.aspectFitted(CGSize(width: itemGroupLayout.visibleItemSize, height: itemGroupLayout.visibleItemSize))
                        let itemPlaybackSize = itemDimensions.aspectFitted(CGSize(width: itemGroupLayout.playbackItemSize, height: itemGroupLayout.playbackItemSize))
                        
                        var animateItemIn = false
                        var updateItemLayerPlaceholder = false
                        var itemTransition = transition
                        let itemLayer: EmojiKeyboardItemLayer
                        if let current = self.visibleItemLayers[itemId] {
                            itemLayer = current
                        } else {
                            updateItemLayerPlaceholder = true
                            itemTransition = .immediate
                            animateItemIn = !transition.animation.isImmediate
                            
                            let pointSize: CGSize
                            if case .staticEmoji = item.content {
                                pointSize = itemVisibleFitSize
                            } else {
                                pointSize = itemPlaybackSize
                            }
                            
                            let placeholderColor = keyboardChildEnvironment.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1)
                            itemLayer = EmojiKeyboardItemLayer(
                                item: item,
                                context: component.context,
                                attemptSynchronousLoad: attemptSynchronousLoads,
                                content: item.content,
                                cache: component.animationCache,
                                renderer: component.animationRenderer,
                                placeholderColor: placeholderColor,
                                blurredBadgeColor: keyboardChildEnvironment.theme.chat.inputPanel.panelBackgroundColor.withMultipliedAlpha(0.5),
                                accentIconColor: keyboardChildEnvironment.theme.list.itemAccentColor,
                                pointSize: pointSize,
                                onUpdateDisplayPlaceholder: { [weak self] displayPlaceholder, duration in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    if displayPlaceholder, let animationData = item.animationData {
                                        if let itemLayer = strongSelf.visibleItemLayers[itemId] {
                                            let placeholderView: ItemPlaceholderView
                                            if let current = strongSelf.visibleItemPlaceholderViews[itemId] {
                                                placeholderView = current
                                            } else {
                                                var placeholderContent: ItemPlaceholderView.Content?
                                                if let immediateThumbnailData = animationData.immediateThumbnailData {
                                                    placeholderContent = .thumbnail(immediateThumbnailData)
                                                }
                                                placeholderView = ItemPlaceholderView(
                                                    context: component.context,
                                                    dimensions: animationData.dimensions,
                                                    content: placeholderContent,
                                                    shimmerView: strongSelf.shimmerHostView,
                                                    color: placeholderColor,
                                                    size: itemNativeFitSize
                                                )
                                                strongSelf.visibleItemPlaceholderViews[itemId] = placeholderView
                                                strongSelf.placeholdersContainerView.addSubview(placeholderView)
                                            }
                                            placeholderView.frame = itemLayer.frame
                                            placeholderView.update(size: placeholderView.bounds.size)
                                            
                                            strongSelf.updateShimmerIfNeeded()
                                        }
                                    } else {
                                        if let placeholderView = strongSelf.visibleItemPlaceholderViews[itemId] {
                                            strongSelf.visibleItemPlaceholderViews.removeValue(forKey: itemId)
                                            
                                            if duration > 0.0 {
                                                placeholderView.layer.opacity = 0.0
                                                placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, completion: { [weak self, weak placeholderView] _ in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    placeholderView?.removeFromSuperview()
                                                    strongSelf.updateShimmerIfNeeded()
                                                })
                                            } else {
                                                placeholderView.removeFromSuperview()
                                                strongSelf.updateShimmerIfNeeded()
                                            }
                                        }
                                    }
                                }
                            )
                            
                            self.visibleItemLayers[itemId] = itemLayer
                            if let underlyingContentLayer = itemLayer.underlyingContentLayer {
                                self.scrollView.layer.addSublayer(underlyingContentLayer)
                            }
                            self.scrollView.layer.addSublayer(itemLayer)
                            if let tintContentLayer = itemLayer.tintContentLayer {
                                self.mirrorContentScrollView.layer.addSublayer(tintContentLayer)
                            }
                        }
                        
                        var itemFrame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: index)
                        let baseItemFrame = itemFrame
                        
                        itemFrame.origin.x += floor((itemFrame.width - itemVisibleFitSize.width) / 2.0)
                        itemFrame.origin.y += floor((itemFrame.height - itemVisibleFitSize.height) / 2.0)
                        itemFrame.size = itemVisibleFitSize
                        
                        let itemBounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                        itemTransition.setBounds(layer: itemLayer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                        
                        if animateItemIn, !transition.animation.isImmediate {
                            if let previousItemPosition = previousItemPositions?[.item(id: itemId)], transitionHintInstalledGroupId != itemId.groupId, transitionHintExpandedGroupId != itemId.groupId {
                                itemTransition = transition
                                itemLayer.position = previousItemPosition
                            } else {
                                if transitionHintInstalledGroupId == itemId.groupId || transitionHintExpandedGroupId == itemId.groupId {
                                    itemLayer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                                    itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                                } else {
                                    itemLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                }
                            }
                        }
                        
                        let itemPosition = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                        itemTransition.setPosition(layer: itemLayer, position: itemPosition)
                        
                        var badge: EmojiKeyboardItemLayer.Badge?
                        if itemGroup.displayPremiumBadges, let file = item.itemFile, file.isPremiumSticker {
                            badge = .premium
                        } else {
                            switch item.icon {
                            case .none:
                                break
                            case .locked:
                                badge = .locked
                            case .premium:
                                badge = .premium
                            case let .text(value):
                                badge = .text(value)
                            case let .customFile(customFile):
                                badge = .customFile(customFile)
                            }
                        }
                        
                        if case .icon = item.content {
                            itemLayer.update(content: item.content, theme: keyboardChildEnvironment.theme, strings: keyboardChildEnvironment.strings)
                        }
                        
                        itemLayer.update(
                            transition: transition,
                            size: itemFrame.size,
                            badge: badge,
                            blurredBadgeColor: UIColor(white: 0.0, alpha: 0.1),
                            blurredBadgeBackgroundColor: keyboardChildEnvironment.theme.list.plainBackgroundColor
                        )
                        
                        switch item.tintMode {
                        case let .custom(color):
                            itemLayer.layerTintColor = color.cgColor
                        case .accent:
                            itemLayer.layerTintColor = component.customTintColor?.cgColor ?? keyboardChildEnvironment.theme.list.itemAccentColor.cgColor
                        case .primary:
                            itemLayer.layerTintColor = keyboardChildEnvironment.theme.list.itemPrimaryTextColor.cgColor
                        case .none:
                            itemLayer.layerTintColor = nil
                        }
                        
                        if let placeholderView = self.visibleItemPlaceholderViews[itemId] {
                            if placeholderView.layer.position != itemPosition || placeholderView.layer.bounds != itemBounds {
                                itemTransition.setFrame(view: placeholderView, frame: itemFrame)
                                placeholderView.update(size: itemFrame.size)
                            }
                        } else if updateItemLayerPlaceholder {
                            if itemLayer.displayPlaceholder {
                                itemLayer.onUpdateDisplayPlaceholder(true, 0.0)
                            }
                        }
                        
                        var isSelected = false
                        var isEmoji = false
                        if case let .staticEmoji(emoji) = item.content, component.selectedItems.contains(emoji) {
                            isSelected = true
                            isEmoji = true
                        } else if let itemFile = item.itemFile, component.selectedItems.contains(itemFile.fileId) {
                            isSelected = true
                        } else if case let .icon(icon) = item.content.id, component.selectedItems.isEmpty {
                            if case .topic = icon {
                                isSelected = true
                            } else if case .stop = icon {
                                isSelected = true
                            }
                        }
                        
                        if isSelected {
                            let itemSelectionLayer: ItemSelectionLayer
                            if let current = self.visibleItemSelectionLayers[itemId] {
                                itemSelectionLayer = current
                            } else {
                                let cornerRadius = isEmoji ? baseItemFrame.width / 2.0 : 8.0
                                itemSelectionLayer = ItemSelectionLayer()
                                itemSelectionLayer.cornerRadius = cornerRadius
                                itemSelectionLayer.tintContainerLayer.cornerRadius = cornerRadius
                                self.scrollView.layer.insertSublayer(itemSelectionLayer, below: itemLayer)
                                self.mirrorContentScrollView.layer.addSublayer(itemSelectionLayer.tintContainerLayer)
                                self.visibleItemSelectionLayers[itemId] = itemSelectionLayer
                            }
                            
                            if case let .custom(color) = item.tintMode {
                                itemSelectionLayer.backgroundColor = color.withMultipliedAlpha(0.1).cgColor
                                itemSelectionLayer.tintContainerLayer.backgroundColor = UIColor.clear.cgColor
                            } else if case .accent = item.tintMode {
                                itemSelectionLayer.backgroundColor = component.customTintColor?.withMultipliedAlpha(0.1).cgColor ?? keyboardChildEnvironment.theme.list.itemAccentColor.withMultipliedAlpha(0.1).cgColor
                                itemSelectionLayer.tintContainerLayer.backgroundColor = UIColor.clear.cgColor
                            } else {
                                if useOpaqueTheme {
                                    itemSelectionLayer.backgroundColor = keyboardChildEnvironment.theme.chat.inputMediaPanel.panelContentControlOpaqueSelectionColor.cgColor
                                    itemSelectionLayer.tintContainerLayer.backgroundColor = UIColor.clear.cgColor
                                } else {
                                    itemSelectionLayer.backgroundColor = keyboardChildEnvironment.theme.chat.inputMediaPanel.panelContentControlVibrantSelectionColor.cgColor
                                    itemSelectionLayer.tintContainerLayer.backgroundColor = UIColor(white: 0.0, alpha: 0.2).cgColor
                                }
                            }
                            
                            itemTransition.setFrame(layer: itemSelectionLayer, frame: baseItemFrame)
                            
                            if isEmoji {
                                itemLayer.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
                            }
                        } else {
                            if isEmoji {
                                itemLayer.transform = CATransform3DIdentity
                            }
                        }
                        
                        if animateItemIn, !transition.animation.isImmediate, let contentAnimation = contentAnimation, case .groupExpanded(id: itemGroup.groupId) = contentAnimation.type, let placeholderView = self.visibleItemPlaceholderViews[itemId] {
                            placeholderView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                            placeholderView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        }
                        
                        let allowPlayback: Bool
                        if case .detailed = component.itemLayoutType {
                            allowPlayback = component.context.sharedContext.energyUsageSettings.loopStickers
                        } else {
                            allowPlayback = component.context.sharedContext.energyUsageSettings.loopEmoji
                        }
                        
                        itemLayer.isVisibleForAnimations = keyboardChildEnvironment.isContentInFocus && allowPlayback
                    }
                }
                if itemGroup.fillWithLoadingPlaceholders {
                    let placeholderSizeFactor: CGFloat = 0.9
                    let placeholderColor = keyboardChildEnvironment.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1)
                    let fillPlaceholderImage: UIImage?
                    let fillPlaceholderParams = FillPlaceholderParams(size: CGSize(width: floor(itemLayout.nativeItemSize * placeholderSizeFactor), height: floor(itemLayout.nativeItemSize * placeholderSizeFactor)))
                    if let current = self.fillPlaceholder, current.params == fillPlaceholderParams {
                        fillPlaceholderImage = current.image
                    } else {
                        switch component.itemLayoutType {
                        case .compact:
                            fillPlaceholderImage = generateFilledCircleImage(diameter: fillPlaceholderParams.size.width, color: .black)
                        case .detailed:
                            fillPlaceholderImage = generateFilledRoundedRectImage(size: fillPlaceholderParams.size, cornerRadius: floor(fillPlaceholderParams.size.width * 0.2), color: .black)
                        }
                        if let fillPlaceholderImage {
                            self.fillPlaceholder = (fillPlaceholderParams, fillPlaceholderImage)
                        }
                    }
                    let fillPlaceholderContent: ItemPlaceholderView.Content? = fillPlaceholderImage.flatMap(ItemPlaceholderView.Content.template)
                    
                    var placeholderIndex = groupItems.groupItems?.lowerBound ?? 0
                    while true {
                        var itemFrame = itemLayout.frame(groupIndex: groupItems.groupIndex, itemIndex: placeholderIndex)
                        if itemFrame.minY >= effectiveVisibleBounds.maxY {
                            break
                        }
                        let visibleItemSize = CGSize(width: floor(itemFrame.width * placeholderSizeFactor), height: floor(itemFrame.height * placeholderSizeFactor))
                        itemFrame = CGRect(origin: CGPoint(x: floor(itemFrame.midX - visibleItemSize.width * 0.5), y: floor(itemFrame.midY - visibleItemSize.height * 0.5)), size: visibleItemSize)
                        
                        validFillPlaceholdersIndices.insert(placeholderIndex)
                        
                        let placeholderView: ItemPlaceholderView
                        if let current = self.visibleFillPlaceholdersViews[placeholderIndex] {
                            placeholderView = current
                        } else {
                            placeholderView = ItemPlaceholderView(
                                context: component.context,
                                dimensions: nil,
                                content: fillPlaceholderContent,
                                shimmerView: self.shimmerHostView,
                                color: placeholderColor,
                                size: itemFrame.size
                            )
                            self.visibleFillPlaceholdersViews[placeholderIndex] = placeholderView
                            self.placeholdersContainerView.addSubview(placeholderView)
                        }
                        
                        placeholderView.frame = itemFrame
                        placeholderView.update(size: itemFrame.size)
                        
                        placeholderIndex += 1
                    }
                    
                    self.updateShimmerIfNeeded()
                }
            }

            var removedPlaceholerViews = false
            var removedIds: [EmojiKeyboardItemLayer.Key] = []
            for (id, itemLayer) in self.visibleItemLayers {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    
                    let itemSelectionLayer = self.visibleItemSelectionLayers[id]
                    
                    if !transition.animation.isImmediate {
                        if let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id.groupId {
                            if let previousAbsolutePosition = previousAbsoluteItemPositions?[.item(id: id)] {
                                itemLayer.position = self.convert(previousAbsolutePosition, to: self.scrollView)
                                transition.setPosition(layer: itemLayer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            }
                            
                            itemLayer.opacity = 0.0
                            itemLayer.animateScale(from: 1.0, to: 0.01, duration: 0.16)
                            itemLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak itemLayer] _ in
                                itemLayer?.underlyingContentLayer?.removeFromSuperlayer()
                                itemLayer?.tintContentLayer?.removeFromSuperlayer()
                                itemLayer?.removeFromSuperlayer()
                            })
                            
                            if let itemSelectionLayer = itemSelectionLayer {
                                itemSelectionLayer.opacity = 0.0
                                itemSelectionLayer.animateScale(from: 1.0, to: 0.01, duration: 0.16)
                                itemSelectionLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak itemSelectionLayer] _ in
                                    itemSelectionLayer?.removeFromSuperlayer()
                                })
                                
                                let itemSelectionTintContainerLayer = itemSelectionLayer.tintContainerLayer
                                itemSelectionTintContainerLayer.opacity = 0.0
                                itemSelectionTintContainerLayer.animateScale(from: 1.0, to: 0.01, duration: 0.16)
                                itemSelectionTintContainerLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak itemSelectionTintContainerLayer] _ in
                                    itemSelectionTintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                        } else if let position = updatedItemPositions?[.item(id: id)], transitionHintInstalledGroupId != id.groupId {
                            transition.setPosition(layer: itemLayer, position: position, completion: { [weak itemLayer] _ in
                                itemLayer?.underlyingContentLayer?.removeFromSuperlayer()
                                itemLayer?.tintContentLayer?.removeFromSuperlayer()
                                itemLayer?.removeFromSuperlayer()
                            })
                            if let itemSelectionLayer = itemSelectionLayer {
                                let itemSelectionTintContainerLayer = itemSelectionLayer.tintContainerLayer
                                transition.setPosition(layer: itemSelectionLayer, position: position, completion: { [weak itemSelectionLayer, weak itemSelectionTintContainerLayer] _ in
                                    itemSelectionLayer?.removeFromSuperlayer()
                                    itemSelectionTintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                        } else {
                            itemLayer.opacity = 0.0
                            itemLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                            itemLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak itemLayer] _ in
                                itemLayer?.underlyingContentLayer?.removeFromSuperlayer()
                                itemLayer?.tintContentLayer?.removeFromSuperlayer()
                                itemLayer?.removeFromSuperlayer()
                            })
                            
                            if let itemSelectionLayer = itemSelectionLayer {
                                itemSelectionLayer.opacity = 0.0
                                itemSelectionLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                                itemSelectionLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak itemSelectionLayer] _ in
                                    itemSelectionLayer?.removeFromSuperlayer()
                                })
                                
                                let itemSelectionTintContainerLayer = itemSelectionLayer.tintContainerLayer
                                itemSelectionTintContainerLayer.opacity = 0.0
                                itemSelectionTintContainerLayer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
                                itemSelectionTintContainerLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak itemSelectionTintContainerLayer] _ in
                                    itemSelectionTintContainerLayer?.removeFromSuperlayer()
                                })
                            }
                        }
                    } else {
                        itemLayer.underlyingContentLayer?.removeFromSuperlayer()
                        itemLayer.tintContentLayer?.removeFromSuperlayer()
                        itemLayer.removeFromSuperlayer()
                        
                        if let itemSelectionLayer = itemSelectionLayer {
                            itemSelectionLayer.removeFromSuperlayer()
                            itemSelectionLayer.tintContainerLayer.removeFromSuperlayer()
                        }
                    }
                }
            }
            for id in removedIds {
                self.visibleItemLayers.removeValue(forKey: id)
                self.visibleItemSelectionLayers.removeValue(forKey: id)
                
                if let view = self.visibleItemPlaceholderViews.removeValue(forKey: id) {
                    view.removeFromSuperview()
                    removedPlaceholerViews = true
                }
            }
            var removedItemSelectionLayerIds: [EmojiKeyboardItemLayer.Key] = []
            for (id, itemSelectionLayer) in self.visibleItemSelectionLayers {
                var fileId: MediaId?
                switch id.itemId {
                case let .animation(id):
                    switch id {
                    case let .file(fileIdValue):
                        fileId = fileIdValue
                    default:
                        break
                    }
                default:
                    break
                }
                if case let .icon(icon) = id.itemId, case .topic = icon, component.selectedItems.isEmpty {
                } else if case let .icon(icon) = id.itemId, case .stop = icon, component.selectedItems.isEmpty {
                } else if let fileId = fileId, component.selectedItems.contains(fileId) {
                } else if case let .staticEmoji(emoji) = id.itemId, component.selectedItems.contains(emoji) {
                } else {
                    itemSelectionLayer.removeFromSuperlayer()
                    removedItemSelectionLayerIds.append(id)
                }
            }
            for id in removedItemSelectionLayerIds {
                self.visibleItemSelectionLayers.removeValue(forKey: id)
            }
            
            var removedFillPlaceholderIndices: [Int] = []
            for (index, placeholderView) in self.visibleFillPlaceholdersViews {
                if !validFillPlaceholdersIndices.contains(index) {
                    if !transition.animation.isImmediate {
                        placeholderView.alpha = 0.0
                        placeholderView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak placeholderView] _ in
                            placeholderView?.removeFromSuperview()
                        })
                    } else {
                        placeholderView.removeFromSuperview()
                    }
                    
                    removedFillPlaceholderIndices.append(index)
                    removedPlaceholerViews = true
                }
            }
            for index in removedFillPlaceholderIndices {
                self.visibleFillPlaceholdersViews.removeValue(forKey: index)
            }
            
            var removedGroupHeaderIds: [AnyHashable] = []
            for (id, groupHeaderLayer) in self.visibleGroupHeaders {
                if !validGroupHeaderIds.contains(id) {
                    removedGroupHeaderIds.append(id)
                    
                    if !transition.animation.isImmediate {
                        var isAnimatingDisappearance = false
                        if let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id, let previousAbsolutePosition = previousAbsoluteItemPositions?[VisualItemKey.header(groupId: id)] {
                            groupHeaderLayer.center = self.convert(previousAbsolutePosition, to: self.scrollView)
                            transition.setPosition(layer: groupHeaderLayer.layer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            isAnimatingDisappearance = true
                        }
                        
                        let tintContentLayer = groupHeaderLayer.tintContentLayer
                        
                        if !isAnimatingDisappearance, let position = updatedItemPositions?[.header(groupId: id)] {
                            transition.setPosition(layer: groupHeaderLayer.layer, position: position, completion: { [weak groupHeaderLayer, weak tintContentLayer] _ in
                                groupHeaderLayer?.removeFromSuperview()
                                tintContentLayer?.removeFromSuperlayer()
                            })
                        } else {
                            groupHeaderLayer.alpha = 0.0
                            groupHeaderLayer.layer.animateScale(from: 1.0, to: 0.5, duration: 0.16)
                            groupHeaderLayer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak groupHeaderLayer, weak tintContentLayer] _ in
                                groupHeaderLayer?.removeFromSuperview()
                                tintContentLayer?.removeFromSuperlayer()
                            })
                        }
                    } else {
                        groupHeaderLayer.removeFromSuperview()
                        groupHeaderLayer.tintContentLayer.removeFromSuperlayer()
                    }
                }
            }
            for id in removedGroupHeaderIds {
                self.visibleGroupHeaders.removeValue(forKey: id)
            }
            
            var removedGroupBorderIds: [AnyHashable] = []
            for (id, groupBorderLayer) in self.visibleGroupBorders {
                if !validGroupBorderIds.contains(id) {
                    removedGroupBorderIds.append(id)
                    groupBorderLayer.removeFromSuperlayer()
                    groupBorderLayer.tintContainerLayer.removeFromSuperlayer()
                }
            }
            for id in removedGroupBorderIds {
                self.visibleGroupBorders.removeValue(forKey: id)
            }
            
            var removedGroupPremiumButtonIds: [AnyHashable] = []
            for (id, groupPremiumButton) in self.visibleGroupPremiumButtons {
                if !validGroupPremiumButtonIds.contains(id), let buttonView = groupPremiumButton.view {
                    if !transition.animation.isImmediate {
                        var isAnimatingDisappearance = false
                        if let position = updatedItemPositions?[.groupActionButton(groupId: id)], position.y > buttonView.center.y {
                        } else if let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id, let previousAbsolutePosition = previousAbsoluteItemPositions?[VisualItemKey.groupActionButton(groupId: id)] {
                            buttonView.center = self.convert(previousAbsolutePosition, to: self.scrollView)
                            transition.setPosition(layer: buttonView.layer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            isAnimatingDisappearance = true
                        }
                        
                        if !isAnimatingDisappearance, let position = updatedItemPositions?[.groupActionButton(groupId: id)] {
                            buttonView.alpha = 0.0
                            buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak buttonView] _ in
                                buttonView?.removeFromSuperview()
                            })
                            transition.setPosition(layer: buttonView.layer, position: position)
                        } else {
                            buttonView.alpha = 0.0
                            if transitionHintExpandedGroupId == id || hintDisappearingGroupFrame?.groupId == id {
                                buttonView.layer.animateScale(from: 1.0, to: 0.5, duration: 0.16)
                            }
                            buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak buttonView] _ in
                                buttonView?.removeFromSuperview()
                            })
                        }
                    } else {
                        removedGroupPremiumButtonIds.append(id)
                        buttonView.removeFromSuperview()
                    }
                }
            }
            for id in removedGroupPremiumButtonIds {
                self.visibleGroupPremiumButtons.removeValue(forKey: id)
            }
            
            var removedGroupExpandActionButtonIds: [AnyHashable] = []
            for (id, button) in self.visibleGroupExpandActionButtons {
                if !validGroupExpandActionButtons.contains(id) {
                    removedGroupExpandActionButtonIds.append(id)
                    
                    if !transition.animation.isImmediate {
                        var isAnimatingDisappearance = false
                        if self.visibleGroupHeaders[id] == nil, let hintDisappearingGroupFrame = hintDisappearingGroupFrame, hintDisappearingGroupFrame.groupId == id, let previousAbsolutePosition = previousAbsoluteItemPositions?[.groupExpandButton(groupId: id)] {
                            button.center = self.convert(previousAbsolutePosition, to: self.scrollView)
                            button.tintContainerLayer.position = button.center
                            transition.setPosition(layer: button.layer, position: CGPoint(x: hintDisappearingGroupFrame.frame.midX, y: hintDisappearingGroupFrame.frame.minY + 20.0))
                            isAnimatingDisappearance = true
                        }
                        
                        let tintContainerLayer = button.tintContainerLayer
                        
                        if !isAnimatingDisappearance, let position = updatedItemPositions?[.groupExpandButton(groupId: id)] {
                            transition.setPosition(layer: button.layer, position: position, completion: { [weak button, weak tintContainerLayer] _ in
                                button?.removeFromSuperview()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        } else {
                            button.alpha = 0.0
                            if transitionHintExpandedGroupId == id || hintDisappearingGroupFrame?.groupId == id {
                                button.layer.animateScale(from: 1.0, to: 0.5, duration: 0.16)
                            }
                            button.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, completion: { [weak button, weak tintContainerLayer] _ in
                                button?.removeFromSuperview()
                                tintContainerLayer?.removeFromSuperlayer()
                            })
                        }
                    } else {
                        button.removeFromSuperview()
                        button.tintContainerLayer.removeFromSuperlayer()
                    }
                }
            }
            for id in removedGroupExpandActionButtonIds {
                self.visibleGroupExpandActionButtons.removeValue(forKey: id)
            }
            
            if removedPlaceholerViews {
                self.updateShimmerIfNeeded()
            }
            
            if itemLayout.curveNearBounds {
            } else {
                if let scrollGradientLayer = self.scrollGradientLayer {
                    self.scrollGradientLayer = nil
                    scrollGradientLayer.removeFromSuperlayer()
                }
            }
            
            if let topVisibleGroupId = topVisibleGroupId {
                self.activeItemUpdated?.invoke((topVisibleGroupId, topVisibleSubgroupId, .immediate))
            }
            
            if let fadingMaskLayer = self.fadingMaskLayer {
                fadingMaskLayer.internalAlpha = max(0.0, min(1.0, self.scrollView.contentOffset.y / 30.0))
            }
        }
        
        private func updateShimmerIfNeeded() {
            if let standaloneShimmerEffect = self.standaloneShimmerEffect, let shimmerHostView = self.shimmerHostView {
                if self.placeholdersContainerView.subviews.isEmpty {
                    standaloneShimmerEffect.layer = nil
                } else {
                    standaloneShimmerEffect.layer = shimmerHostView.layer
                }
            }
        }
        
        private func expandGroup(groupId: AnyHashable) {
            self.expandedGroupIds.insert(groupId)
            
            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(ContentAnimation(type: .groupExpanded(id: groupId))))
        }
        
        public func pagerUpdateBackground(backgroundFrame: CGRect, topPanelHeight: CGFloat, transition: ComponentTransition) {
            guard let component = self.component, let keyboardChildEnvironment = self.keyboardChildEnvironment, let pagerEnvironment = self.pagerEnvironment else {
                return
            }
            
            if let externalBackground = component.inputInteractionHolder.inputInteraction?.externalBackground, let effectContainerView = externalBackground.effectContainerView {
                let mirrorContentClippingView: UIView
                if let current = self.mirrorContentClippingView {
                    mirrorContentClippingView = current
                } else {
                    mirrorContentClippingView = UIView()
                    mirrorContentClippingView.clipsToBounds = true
                    self.mirrorContentClippingView = mirrorContentClippingView
                    
                    if let mirrorContentWarpView = self.mirrorContentWarpView {
                        mirrorContentClippingView.addSubview(mirrorContentWarpView)
                    } else {
                        mirrorContentClippingView.addSubview(self.mirrorContentScrollView)
                    }
                }
                
                let clippingFrame = CGRect(origin: CGPoint(x: 0.0, y: pagerEnvironment.containerInsets.top), size: CGSize(width: backgroundFrame.width, height: backgroundFrame.height))
                transition.setPosition(view: mirrorContentClippingView, position: clippingFrame.center)
                transition.setBounds(view: mirrorContentClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: pagerEnvironment.containerInsets.top), size: clippingFrame.size))
                
                if mirrorContentClippingView.superview !== effectContainerView {
                    effectContainerView.addSubview(mirrorContentClippingView)
                }
            } else if keyboardChildEnvironment.theme.overallDarkAppearance || component.warpContentsOnEdges {
                if let vibrancyEffectView = self.vibrancyEffectView {
                    self.vibrancyEffectView = nil
                    vibrancyEffectView.removeFromSuperview()
                }
            } else {
                if self.vibrancyEffectView == nil {
                    let vibrancyEffectView = UIView()
                    vibrancyEffectView.backgroundColor = .white
                    if let filter = CALayer.luminanceToAlpha() {
                        vibrancyEffectView.layer.filters = [filter]
                    }
                    self.vibrancyEffectView = vibrancyEffectView
                    self.backgroundTintView.mask = vibrancyEffectView
                    self.vibrancyClippingView.addSubview(self.mirrorContentScrollView)
                    vibrancyEffectView.addSubview(self.vibrancyClippingView)
                }
            }
            
            if component.hideBackground {
                self.backgroundView.isHidden = true
                
                let maskLayer: FadingMaskLayer
                if let current = self.fadingMaskLayer {
                    maskLayer = current
                } else {
                    maskLayer = FadingMaskLayer()
                    self.fadingMaskLayer = maskLayer
                }
                if self.layer.mask == nil {
                    self.layer.mask = maskLayer
                }
                maskLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((topPanelHeight - 34.0) * 0.75)), size: backgroundFrame.size)
            } else if component.warpContentsOnEdges {
                self.backgroundView.isHidden = true
            } else {
                self.backgroundView.isHidden = false
            }
            
            let hideBackground = component.inputInteractionHolder.inputInteraction?.hideBackground ?? false
            var backgroundColor = keyboardChildEnvironment.theme.chat.inputMediaPanel.backgroundColor
            if hideBackground {
                backgroundColor = backgroundColor.withAlphaComponent(0.01)
            }
            
            self.backgroundTintView.backgroundColor = backgroundColor
            transition.setFrame(view: self.backgroundTintView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            
            self.backgroundView.updateColor(color: .clear, enableBlur: true, forceKeepBlur: true, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            self.backgroundView.update(size: backgroundFrame.size, transition: transition.containedViewLayoutTransition)
            
            if let vibrancyEffectView = self.vibrancyEffectView {
                transition.setFrame(view: vibrancyEffectView, frame: CGRect(origin: CGPoint(x: 0.0, y: -backgroundFrame.minY), size: CGSize(width: backgroundFrame.width, height: backgroundFrame.height + backgroundFrame.minY)))
            }
        }
        
        func update(component: EmojiPagerContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            if component.searchAlwaysActive {
                self.isSearchActivated = true
            }
            
            component.inputInteractionHolder.inputInteraction?.peekBehavior?.setGestureRecognizerEnabled(view: self, isEnabled: true, itemAtPoint: { [weak self] point in
                guard let strongSelf = self else {
                    return nil
                }
                if !strongSelf.scrollViewClippingView.bounds.contains(strongSelf.convert(point, to: strongSelf.scrollViewClippingView)) {
                    return nil
                }
                guard let item = strongSelf.item(atPoint: point), let itemLayer = strongSelf.visibleItemLayers[item.1], let file = item.0.itemFile else {
                    return nil
                }
                if itemLayer.displayPlaceholder {
                    return nil
                }
                return (item.1.groupId, itemLayer, file._parse())
            })
            
            let keyboardChildEnvironment = environment[EntityKeyboardChildEnvironment.self].value
            let pagerEnvironment = environment[PagerComponentChildEnvironment.self].value
            
            self.keyboardChildEnvironment = keyboardChildEnvironment
            self.activeItemUpdated = keyboardChildEnvironment.getContentActiveItemUpdated(component.id)
            
            self.pagerEnvironment = pagerEnvironment
            
            pagerEnvironment.scrollToTop.connect { [weak self] in
                guard let self else {
                    return
                }
                
                self.scrollView.setContentOffset(CGPoint(), animated: true)
            }
            
            self.updateIsWarpEnabled(isEnabled: component.warpContentsOnEdges)
            
            if let longTapRecognizer = self.longTapRecognizer {
                longTapRecognizer.isEnabled = component.enableLongPress
            }
            if let tapRecognizer = self.tapRecognizer {
                tapRecognizer.isEnabled = component.enableLongPress || component.inputInteractionHolder.inputInteraction?.peekBehavior != nil
            }
            if let contextGesture = self.contextGesture {
                contextGesture.isEnabled = !component.enableLongPress && component.inputInteractionHolder.inputInteraction?.peekBehavior == nil
            }
            
            if let shimmerHostView = self.shimmerHostView {
                transition.setFrame(view: shimmerHostView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            if let standaloneShimmerEffect = self.standaloneShimmerEffect {
                let shimmerBackgroundColor = keyboardChildEnvironment.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.08)
                let shimmerForegroundColor = keyboardChildEnvironment.theme.list.itemBlocksBackgroundColor.withMultipliedAlpha(0.15)
                standaloneShimmerEffect.update(background: shimmerBackgroundColor, foreground: shimmerForegroundColor)
            }
            
            var previousItemPositions: [VisualItemKey: CGPoint]?
            
            var calculateUpdatedItemPositions = false
            var updatedItemPositions: [VisualItemKey: CGPoint]?
            
            let contentAnimation = transition.userData(ContentAnimation.self)
            let useOpaqueTheme = component.inputInteractionHolder.inputInteraction?.useOpaqueTheme ?? false
            
            var transitionHintInstalledGroupId: AnyHashable?
            var transitionHintExpandedGroupId: AnyHashable?
            var keepOffset = false
            if let contentAnimation = contentAnimation {
                switch contentAnimation.type {
                case let .groupInstalled(groupId, scrollToGroup):
                    if scrollToGroup {
                        transitionHintInstalledGroupId = groupId
                    } else {
                        keepOffset = true
                    }
                case let .groupExpanded(groupId):
                    transitionHintExpandedGroupId = groupId
                case let .groupRemoved(groupId):
                    transitionHintInstalledGroupId = groupId
                default:
                    break
                }
            }
            let _ = transitionHintExpandedGroupId
            
            var hintDisappearingGroupFrame: (groupId: AnyHashable, frame: CGRect)?
            var previousAbsoluteItemPositions: [VisualItemKey: CGPoint] = [:]
            
            var anchorItems: [EmojiKeyboardItemLayer.Key: CGRect] = [:]
            if let previousComponent = previousComponent, let previousItemLayout = self.itemLayout, previousComponent.contentItemGroups != component.contentItemGroups, previousComponent.itemContentUniqueId == component.itemContentUniqueId {
                if !transition.animation.isImmediate {
                    var previousItemPositionsValue: [VisualItemKey: CGPoint] = [:]
                    for groupIndex in 0 ..< previousComponent.contentItemGroups.count {
                        let itemGroup = previousComponent.contentItemGroups[groupIndex]
                        for itemIndex in 0 ..< itemGroup.items.count {
                            let item = itemGroup.items[itemIndex]
                            let itemKey: EmojiKeyboardItemLayer.Key
                            itemKey = EmojiKeyboardItemLayer.Key(
                                groupId: itemGroup.groupId,
                                itemId: item.content.id
                            )
                            let itemFrame = previousItemLayout.frame(groupIndex: groupIndex, itemIndex: itemIndex)
                            previousItemPositionsValue[.item(id: itemKey)] = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                        }
                    }
                    previousItemPositions = previousItemPositionsValue
                    calculateUpdatedItemPositions = true
                }
                
                let effectiveVisibleBounds = CGRect(origin: self.scrollView.bounds.origin, size: self.effectiveVisibleSize)
                let topVisibleDetectionBounds = effectiveVisibleBounds
                for (key, itemLayer) in self.visibleItemLayers {
                    if !topVisibleDetectionBounds.intersects(itemLayer.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(itemLayer.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == key.groupId {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (key.groupId, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.item(id: key)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    } else {
                        anchorItems[key] = absoluteFrame
                    }
                }
                
                for (id, groupHeader) in self.visibleGroupHeaders {
                    if !topVisibleDetectionBounds.intersects(groupHeader.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(groupHeader.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == id {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (id, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.header(groupId: id)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    }
                }
                
                for (id, button) in self.visibleGroupExpandActionButtons {
                    if !topVisibleDetectionBounds.intersects(button.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(button.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == id {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (id, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.groupExpandButton(groupId: id)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    }
                }
                
                for (id, button) in self.visibleGroupPremiumButtons {
                    guard let buttonView = button.view else {
                        continue
                    }
                    if !topVisibleDetectionBounds.intersects(buttonView.frame) {
                        continue
                    }
                    
                    let absoluteFrame = self.scrollView.convert(buttonView.frame, to: self)
                    
                    if let transitionHintInstalledGroupId = transitionHintInstalledGroupId, transitionHintInstalledGroupId == id {
                        if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                            hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, absoluteFrame.union(hintDisappearingGroupFrameValue.frame))
                        } else {
                            hintDisappearingGroupFrame = (id, absoluteFrame)
                        }
                        previousAbsoluteItemPositions[.groupActionButton(groupId: id)] = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
                    }
                }
            }
            
            if transitionHintExpandedGroupId != nil {
                calculateUpdatedItemPositions = true
            }
            
            var itemTransition = transition
            if let previousItemLayout = self.itemLayout {
                if previousItemLayout.width != availableSize.width {
                    itemTransition = .immediate
                } else if transition.userData(ContentAnimation.self) == nil {
                    if previousItemLayout.itemInsets.top != pagerEnvironment.containerInsets.top + 9.0 {
                    } else {
                        itemTransition = .immediate
                    }
                }
            } else {
                itemTransition = .immediate
            }
            
            var isFirstUpdate = false
            var resetScrolling = false
            if self.scrollView.bounds.isEmpty && component.displaySearchWithPlaceholder != nil {
                resetScrolling = true
            }
            if previousComponent == nil {
                isFirstUpdate = true
            }
            if previousComponent?.itemContentUniqueId != component.itemContentUniqueId {
                resetScrolling = true
            }
            if resetScrolling {
                itemTransition = .immediate
            }
            
            var animateContentCrossfade = false
            if let previousComponent, previousComponent.itemContentUniqueId != component.itemContentUniqueId, itemTransition.animation.isImmediate {
                if !(previousComponent.contentItemGroups.contains(where: { $0.fillWithLoadingPlaceholders }) && component.contentItemGroups.contains(where: { $0.fillWithLoadingPlaceholders })) && previousComponent.itemContentUniqueId?.id != component.itemContentUniqueId?.id {
                    animateContentCrossfade = true
                }
            }
            
            var customContentHeight: CGFloat = 0.0
            if let customContentView = component.inputInteractionHolder.inputInteraction?.customContentView, !self.isSearchActivated {
                var customContentViewTransition = transition
                if let _ = self.visibleCustomContentView {
                    
                } else {
                    customContentViewTransition = .immediate
                    self.visibleCustomContentView = customContentView
                    self.scrollView.addSubview(customContentView)
                    self.mirrorContentScrollView.addSubview(customContentView.tintContainerView)
                    
                    if animateContentCrossfade {
                        customContentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        customContentView.tintContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                let availableCustomContentSize = availableSize
                let customContentViewSize = customContentView.update(theme: keyboardChildEnvironment.theme, strings: keyboardChildEnvironment.strings, useOpaqueTheme: useOpaqueTheme, availableSize: availableCustomContentSize, transition: customContentViewTransition)
                customContentViewTransition.setFrame(view: customContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: pagerEnvironment.containerInsets.top + (component.displaySearchWithPlaceholder != nil ? 54.0 : 0.0)), size: customContentViewSize))
                
                customContentHeight = customContentViewSize.height
            } else {
                if let visibleCustomContentView = self.visibleCustomContentView {
                    self.visibleCustomContentView = nil
                    if animateContentCrossfade {
                        visibleCustomContentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                            visibleCustomContentView.removeFromSuperview()
                        })
                        visibleCustomContentView.tintContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                            visibleCustomContentView.tintContainerView.removeFromSuperview()
                        })
                    } else {
                        visibleCustomContentView.removeFromSuperview()
                        visibleCustomContentView.tintContainerView.removeFromSuperview()
                    }
                }
            }
            
            var itemGroups: [ItemGroupDescription] = []
            for itemGroup in component.contentItemGroups {
                itemGroups.append(ItemGroupDescription(
                    supergroupId: itemGroup.supergroupId,
                    groupId: itemGroup.groupId,
                    hasTitle: itemGroup.title != nil,
                    isPremiumLocked: itemGroup.isPremiumLocked,
                    isFeatured: itemGroup.isFeatured,
                    itemCount: itemGroup.items.count,
                    isEmbedded: itemGroup.isEmbedded,
                    collapsedLineCount: itemGroup.collapsedLineCount
                ))
            }
            
            let extractedExpr = ItemLayout(
                layoutType: component.itemLayoutType,
                width: availableSize.width,
                containerInsets: UIEdgeInsets(top: pagerEnvironment.containerInsets.top + 9.0, left: pagerEnvironment.containerInsets.left, bottom: 9.0 + pagerEnvironment.containerInsets.bottom, right: pagerEnvironment.containerInsets.right),
                itemGroups: itemGroups,
                expandedGroupIds: self.expandedGroupIds,
                curveNearBounds: component.warpContentsOnEdges,
                displaySearch: component.displaySearchWithPlaceholder != nil,
                isSearchActivated: self.isSearchActivated,
                customContentHeight: customContentHeight,
                customLayout: component.inputInteractionHolder.inputInteraction?.customLayout
            )
            let itemLayout = extractedExpr
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            
            let scrollOriginY: CGFloat = 0.0
            
            let scrollSize = CGSize(width: availableSize.width, height: availableSize.height)
            transition.setPosition(view: self.scrollView, position: CGPoint(x: 0.0, y: scrollOriginY))
            
            let clippingTopInset: CGFloat = itemLayout.searchInsets.top + itemLayout.searchHeight - 1.0
            
            transition.setFrame(view: self.scrollViewClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isSearchActivated ? clippingTopInset : 0.0), size: availableSize))
            transition.setBounds(view: self.scrollViewClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: self.isSearchActivated ? clippingTopInset : 0.0), size: availableSize))
            
            transition.setFrame(view: self.vibrancyClippingView, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isSearchActivated ? clippingTopInset : 0.0), size: availableSize))
            transition.setBounds(view: self.vibrancyClippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: self.isSearchActivated ? clippingTopInset : 0.0), size: availableSize))
            
            let previousSize = self.scrollView.bounds.size
            self.scrollView.bounds = CGRect(origin: self.scrollView.bounds.origin, size: scrollSize)

            let warpHeight: CGFloat = 50.0
            var topWarpInset = pagerEnvironment.containerInsets.top
            if self.isSearchActivated {
                topWarpInset = itemLayout.searchInsets.top + itemLayout.searchHeight
            }
            if let warpView = self.warpView {
                transition.setFrame(view: warpView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize))
                warpView.update(size: CGSize(width: availableSize.width, height: availableSize.height), topInset: topWarpInset, warpHeight: warpHeight, theme: keyboardChildEnvironment.theme, transition: transition)
            }
            if let mirrorContentWarpView = self.mirrorContentWarpView {
                transition.setFrame(view: mirrorContentWarpView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize))
                mirrorContentWarpView.update(size: CGSize(width: availableSize.width, height: availableSize.height), topInset: topWarpInset, warpHeight: warpHeight, theme: keyboardChildEnvironment.theme, transition: transition)
            }
            
            if scrollSize.height > previousSize.height || transition.animation.isImmediate {
                self.boundsChangeTrackerLayer.removeAllAnimations()
                self.boundsChangeTrackerLayer.bounds = self.scrollView.bounds
                self.effectiveVisibleSize = self.scrollView.bounds.size
            } else {
                self.effectiveVisibleSize = CGSize(width: scrollSize.width, height: max(self.effectiveVisibleSize.height, scrollSize.height))
                transition.setBounds(layer: self.boundsChangeTrackerLayer, bounds: self.scrollView.bounds, completion: { [weak self] completed in
                    guard let strongSelf = self else {
                        return
                    }
                    let effectiveVisibleSize = strongSelf.scrollView.bounds.size
                    if strongSelf.effectiveVisibleSize != effectiveVisibleSize {
                        strongSelf.effectiveVisibleSize = effectiveVisibleSize
                        strongSelf.updateVisibleItems(transition: .immediate, attemptSynchronousLoads: false, previousItemPositions: nil, updatedItemPositions: nil)
                    }
                })
            }
            
            var effectiveContentSize = itemLayout.contentSize
            if self.isSearchActivated {
                effectiveContentSize.height = max(itemLayout.contentSize.height, availableSize.height + 1.0)
            }
            
            if self.scrollView.contentSize != effectiveContentSize {
                self.scrollView.contentSize = effectiveContentSize
            }
            var scrollIndicatorInsets = pagerEnvironment.containerInsets
            if let inputInteraction = component.inputInteractionHolder.inputInteraction, let customLayout = inputInteraction.customLayout, customLayout.topPanelAlwaysHidden {
                scrollIndicatorInsets.top += 20.0
            }
            if self.warpView != nil {
                scrollIndicatorInsets.bottom += 20.0
            }
            if self.scrollView.verticalScrollIndicatorInsets != scrollIndicatorInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollIndicatorInsets
            }
            self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: scrollView.isDragging || scrollView.isDecelerating)
            
            var animatedScrollOffset: CGFloat = 0.0
            if !anchorItems.isEmpty && !keepOffset {
                let sortedAnchorItems: [(EmojiKeyboardItemLayer.Key, CGRect)] = anchorItems.sorted(by: { lhs, rhs in
                    if lhs.value.minY != rhs.value.minY {
                        return lhs.value.minY < rhs.value.minY
                    } else {
                        return lhs.value.minX < rhs.value.minX
                    }
                })
                
                outer: for i in 0 ..< component.contentItemGroups.count {
                    for anchorItem in sortedAnchorItems {
                        if component.contentItemGroups[i].groupId != anchorItem.0.groupId {
                            continue
                        }
                        for j in 0 ..< component.contentItemGroups[i].items.count {
                            let itemKey: EmojiKeyboardItemLayer.Key
                            itemKey = EmojiKeyboardItemLayer.Key(
                                groupId: component.contentItemGroups[i].groupId,
                                itemId: component.contentItemGroups[i].items[j].content.id
                            )
                            
                            if itemKey == anchorItem.0 {
                                let itemFrame = itemLayout.frame(groupIndex: i, itemIndex: j)
                                
                                var contentOffsetY = itemFrame.minY - anchorItem.1.minY
                                if contentOffsetY > self.scrollView.contentSize.height - self.scrollView.bounds.height {
                                    contentOffsetY = self.scrollView.contentSize.height - self.scrollView.bounds.height
                                }
                                if contentOffsetY < 0.0 {
                                    contentOffsetY = 0.0
                                }
                                
                                let previousBounds = self.scrollView.bounds
                                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: contentOffsetY), animated: false)
                                let scrollOffset = previousBounds.minY - contentOffsetY
                                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: scrollOffset), to: CGPoint(), additive: true)
                                animatedScrollOffset = scrollOffset
                                
                                break outer
                            }
                        }
                    }
                }
            }
            
            if resetScrolling {
                var resetScrollY: CGFloat = 0.0
                if isFirstUpdate, let stateContext = component.inputInteractionHolder.inputInteraction?.stateContext {
                    resetScrollY = stateContext.scrollPosition
                }
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: resetScrollY), size: scrollSize)
            }
            
            self.ignoreScrolling = false
            
            if calculateUpdatedItemPositions {
                var updatedItemPositionsValue: [VisualItemKey: CGPoint] = [:]
                for groupIndex in 0 ..< component.contentItemGroups.count {
                    let itemGroup = component.contentItemGroups[groupIndex]
                    let itemGroupLayout = itemLayout.itemGroupLayouts[groupIndex]
                    for itemIndex in 0 ..< itemGroup.items.count {
                        let item = itemGroup.items[itemIndex]
                        let itemKey: EmojiKeyboardItemLayer.Key
                        itemKey = EmojiKeyboardItemLayer.Key(
                            groupId: itemGroup.groupId,
                            itemId: item.content.id
                        )
                        
                        let itemFrame = itemLayout.frame(groupIndex: groupIndex, itemIndex: itemIndex)
                        updatedItemPositionsValue[.item(id: itemKey)] = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
                    }
                    
                    let groupPremiumButtonFrame = CGRect(origin: CGPoint(x: itemLayout.itemInsets.left, y: itemGroupLayout.frame.maxY - itemLayout.premiumButtonHeight + 1.0), size: CGSize(width: itemLayout.width - itemLayout.itemInsets.left - itemLayout.itemInsets.right, height: itemLayout.premiumButtonHeight))
                    updatedItemPositionsValue[.groupActionButton(groupId: itemGroup.groupId)] = CGPoint(x: groupPremiumButtonFrame.midX, y: groupPremiumButtonFrame.midY)
                }
                updatedItemPositions = updatedItemPositionsValue
            }
            
            if let hintDisappearingGroupFrameValue = hintDisappearingGroupFrame {
                hintDisappearingGroupFrame = (hintDisappearingGroupFrameValue.groupId, self.scrollView.convert(hintDisappearingGroupFrameValue.frame, from: self))
            }
            
            for (id, position) in previousAbsoluteItemPositions {
                previousAbsoluteItemPositions[id] = position.offsetBy(dx: 0.0, dy: animatedScrollOffset)
            }
            
            var attemptSynchronousLoads = !(scrollView.isDragging || scrollView.isDecelerating)
            if resetScrolling {
                attemptSynchronousLoads = true
            }
            if let synchronousLoadBehavior = transition.userData(SynchronousLoadBehavior.self) {
                if synchronousLoadBehavior.isDisabled {
                    attemptSynchronousLoads = false
                }
            }
            
            
            if let displaySearchWithPlaceholder = component.displaySearchWithPlaceholder {
                let visibleSearchHeader: EmojiSearchHeaderView
                if let current = self.visibleSearchHeader {
                    visibleSearchHeader = current
                    
                    if self.isSearchActivated {
                        if visibleSearchHeader.superview != self {
                            self.addSubview(visibleSearchHeader)
                            if self.mirrorContentClippingView != nil {
                                self.mirrorContentClippingView?.addSubview(visibleSearchHeader.tintContainerView)
                            } else {
                                self.mirrorContentScrollView.superview?.superview?.addSubview(visibleSearchHeader.tintContainerView)
                            }
                        }
                    } else {
                        /*if useOpaqueTheme {
                            if visibleSearchHeader.superview != self.scrollView {
                                self.scrollView.addSubview(visibleSearchHeader)
                                self.mirrorContentScrollView.addSubview(visibleSearchHeader.tintContainerView)
                            }
                        }*/
                    }
                } else {
                    visibleSearchHeader = EmojiSearchHeaderView(activated: { [weak self] isTextInput in
                        guard let strongSelf = self, let visibleSearchHeader = strongSelf.visibleSearchHeader else {
                            return
                        }
                        
                        if let component = strongSelf.component, component.searchIsPlaceholderOnly, isTextInput {
                            component.inputInteractionHolder.inputInteraction?.openSearch()
                        } else {
                            strongSelf.isSearchActivated = true
                            if visibleSearchHeader.currentPresetSearchTerm == nil {
                                strongSelf.pagerEnvironment?.onWantsExclusiveModeUpdated(true)
                            }
                            strongSelf.component?.inputInteractionHolder.inputInteraction?.requestUpdate(.immediate)
                        }
                    }, deactivated: { [weak self] isFirstResponder in
                        guard let strongSelf = self, let component = strongSelf.component else {
                            return
                        }
                        
                        if let externalCancel = component.inputInteractionHolder.inputInteraction?.externalCancel {
                            externalCancel()
                        } else {
                            strongSelf.scrollToTop()
                            
                            strongSelf.isSearchActivated = false
                            strongSelf.pagerEnvironment?.onWantsExclusiveModeUpdated(false)
                            
                            if !isFirstResponder {
                                strongSelf.component?.inputInteractionHolder.inputInteraction?.requestUpdate(
                                    ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            } else {
                                DispatchQueue.main.async {
                                    self?.component?.inputInteractionHolder.inputInteraction?.requestUpdate(
                                        ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                                }
                            }
                            
                            if !strongSelf.isUpdating {
                                strongSelf.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                            }
                        }
                    }, updateQuery: { [weak self] query in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.component?.inputInteractionHolder.inputInteraction?.updateSearchQuery(query)
                    })
                    self.visibleSearchHeader = visibleSearchHeader
                    if self.isSearchActivated {
                        self.addSubview(visibleSearchHeader)
                        self.mirrorContentClippingView?.addSubview(visibleSearchHeader.tintContainerView)
                    } else {
                        self.scrollView.addSubview(visibleSearchHeader)
                        self.mirrorContentScrollView.addSubview(visibleSearchHeader.tintContainerView)
                    }
                }
                
                let searchHeaderFrame = CGRect(origin: CGPoint(x: itemLayout.searchInsets.left, y: itemLayout.searchInsets.top), size: CGSize(width: itemLayout.width - itemLayout.searchInsets.left - itemLayout.searchInsets.right, height: itemLayout.searchHeight))
                visibleSearchHeader.update(context: component.context, theme: keyboardChildEnvironment.theme, forceNeedsVibrancy: component.inputInteractionHolder.inputInteraction?.externalBackground != nil, strings: keyboardChildEnvironment.strings, text: displaySearchWithPlaceholder, useOpaqueTheme: useOpaqueTheme, isActive: self.isSearchActivated, size: searchHeaderFrame.size, canFocus: !component.searchIsPlaceholderOnly, searchCategories: component.searchCategories, searchState: component.searchState, transition: transition)
       
                transition.setFrame(view: visibleSearchHeader, frame: searchHeaderFrame)
                // Temporary workaround for status selection; use a separate search container (see GIF)

                if case let .curve(duration, _) = transition.animation, duration != 0.0 {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration, execute: { [weak self] in
                        guard let strongSelf = self, let visibleSearchHeader = strongSelf.visibleSearchHeader else {
                            return
                        }
                        
                        if !strongSelf.isSearchActivated && visibleSearchHeader.superview != strongSelf.scrollView {
                            strongSelf.scrollView.addSubview(visibleSearchHeader)
                            strongSelf.mirrorContentScrollView.addSubview(visibleSearchHeader.tintContainerView)
                        }
                    })
                } else {
                    if !self.isSearchActivated && visibleSearchHeader.superview != self.scrollView {
                        self.scrollView.addSubview(visibleSearchHeader)
                        self.mirrorContentScrollView.addSubview(visibleSearchHeader.tintContainerView)
                    }
                }
            } else {
                if let visibleSearchHeader = self.visibleSearchHeader {
                    self.visibleSearchHeader = nil
                    visibleSearchHeader.removeFromSuperview()
                    visibleSearchHeader.tintContainerView.removeFromSuperview()
                }
            }
             
            if let emptySearchResults = component.emptySearchResults {
                let visibleEmptySearchResultsView: EmptySearchResultsView
                var emptySearchResultsTransition = transition
                if let current = self.visibleEmptySearchResultsView {
                    visibleEmptySearchResultsView = current
                } else {
                    emptySearchResultsTransition = .immediate
                    visibleEmptySearchResultsView = EmptySearchResultsView(frame: CGRect())
                    self.visibleEmptySearchResultsView = visibleEmptySearchResultsView
                    self.addSubview(visibleEmptySearchResultsView)
                    if let mirrorContentClippingView = self.mirrorContentClippingView {
                        mirrorContentClippingView.addSubview(visibleEmptySearchResultsView.tintContainerView)
                    } else if let vibrancyEffectView = self.vibrancyEffectView {
                        vibrancyEffectView.addSubview(visibleEmptySearchResultsView.tintContainerView)
                    }
                }
                let emptySearchResultsSize = CGSize(width: availableSize.width, height: availableSize.height - itemLayout.searchInsets.top - itemLayout.searchHeight)
                visibleEmptySearchResultsView.update(
                    context: component.context,
                    theme: keyboardChildEnvironment.theme,
                    useOpaqueTheme: useOpaqueTheme,
                    text: emptySearchResults.text,
                    file: emptySearchResults.iconFile,
                    size: emptySearchResultsSize,
                    searchInitiallyHidden: component.searchInitiallyHidden,
                    transition: emptySearchResultsTransition
                )
                emptySearchResultsTransition.setFrame(view: visibleEmptySearchResultsView, frame: CGRect(origin: CGPoint(x: 0.0, y: itemLayout.searchInsets.top + itemLayout.searchHeight), size: emptySearchResultsSize))
            } else {
                if let visibleEmptySearchResultsView = self.visibleEmptySearchResultsView {
                    self.visibleEmptySearchResultsView = nil
                    visibleEmptySearchResultsView.removeFromSuperview()
                    visibleEmptySearchResultsView.tintContainerView.removeFromSuperview()
                }
            }
                        
            let crossfadeMinScale: CGFloat = 0.4
            
            if animateContentCrossfade {
                for (_, itemLayer) in self.visibleItemLayers {
                    if let snapshotLayer = itemLayer.snapshotContentTree() {
                        itemLayer.superlayer?.insertSublayer(snapshotLayer, above: itemLayer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                        snapshotLayer.animateScale(from: 1.0, to: crossfadeMinScale, duration: 0.2, removeOnCompletion: false)
                    }
                }
                for (_, placeholderView) in self.visibleItemPlaceholderViews {
                    if let snapshotLayer = placeholderView.layer.snapshotContentTree() {
                        placeholderView.layer.superlayer?.insertSublayer(snapshotLayer, above: placeholderView.layer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                        snapshotLayer.animateScale(from: 1.0, to: crossfadeMinScale, duration: 0.2, removeOnCompletion: false)
                    }
                }
                for (_, placeholderView) in self.visibleFillPlaceholdersViews {
                    if let snapshotLayer = placeholderView.layer.snapshotContentTree() {
                        placeholderView.layer.superlayer?.insertSublayer(snapshotLayer, above: placeholderView.layer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                        snapshotLayer.animateScale(from: 1.0, to: crossfadeMinScale, duration: 0.2, removeOnCompletion: false)
                    }
                }
                for (_, selectionLayer) in self.visibleItemSelectionLayers {
                    if let snapshotLayer = selectionLayer.snapshotContentTree() {
                        selectionLayer.superlayer?.insertSublayer(snapshotLayer, above: selectionLayer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                    }
                }
                for (_, groupHeader) in self.visibleGroupHeaders {
                    if let snapshotLayer = groupHeader.layer.snapshotContentTree() {
                        groupHeader.layer.superlayer?.insertSublayer(snapshotLayer, above: groupHeader.layer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                    }
                }
                for (_, borderLayer) in self.visibleGroupBorders {
                    if let snapshotLayer = borderLayer.snapshotContentTree() {
                        borderLayer.superlayer?.insertSublayer(snapshotLayer, above: borderLayer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                    }
                }
                for (_, button) in self.visibleGroupPremiumButtons {
                    if let buttonView = button.view, let snapshotLayer = buttonView.layer.snapshotContentTree() {
                        buttonView.layer.superlayer?.insertSublayer(snapshotLayer, above: buttonView.layer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                    }
                }
                for (_, button) in self.visibleGroupExpandActionButtons {
                    if let snapshotLayer = button.layer.snapshotContentTree() {
                        button.layer.superlayer?.insertSublayer(snapshotLayer, above: button.layer)
                        snapshotLayer.animateAlpha(from: CGFloat(snapshotLayer.opacity), to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            
            self.updateVisibleItems(transition: itemTransition, attemptSynchronousLoads: attemptSynchronousLoads, previousItemPositions: previousItemPositions, previousAbsoluteItemPositions: previousAbsoluteItemPositions, updatedItemPositions: updatedItemPositions, hintDisappearingGroupFrame: hintDisappearingGroupFrame)
            
            if animateContentCrossfade {
                for (_, itemLayer) in self.visibleItemLayers {
                    itemLayer.animateAlpha(from: 0.0, to: CGFloat(itemLayer.opacity), duration: 0.2)
                    itemLayer.animateScale(from: crossfadeMinScale, to: 1.0, duration: 0.2)
                }
                for (_, placeholderView) in self.visibleItemPlaceholderViews {
                    placeholderView.layer.animateAlpha(from: 0.0, to: CGFloat(placeholderView.layer.opacity), duration: 0.2)
                    placeholderView.layer.animateScale(from: crossfadeMinScale, to: 1.0, duration: 0.2)
                }
                for (_, placeholderView) in self.visibleFillPlaceholdersViews {
                    placeholderView.layer.animateAlpha(from: 0.0, to: CGFloat(placeholderView.layer.opacity), duration: 0.2)
                    placeholderView.layer.animateScale(from: crossfadeMinScale, to: 1.0, duration: 0.2)
                }
                for (_, selectionLayer) in self.visibleItemSelectionLayers {
                    selectionLayer.animateAlpha(from: 0.0, to: CGFloat(selectionLayer.opacity), duration: 0.2)
                }
                for (_, groupHeader) in self.visibleGroupHeaders {
                    groupHeader.layer.animateAlpha(from: 0.0, to: CGFloat(groupHeader.layer.opacity), duration: 0.2)
                }
                for (_, borderLayer) in self.visibleGroupBorders {
                    borderLayer.animateAlpha(from: 0.0, to: CGFloat(borderLayer.opacity), duration: 0.2)
                }
                for (_, button) in self.visibleGroupPremiumButtons {
                    if let buttonView = button.view {
                        buttonView.layer.animateAlpha(from: 0.0, to: CGFloat(buttonView.layer.opacity), duration: 0.2)
                    }
                }
                for (_, button) in self.visibleGroupExpandActionButtons {
                    button.layer.animateAlpha(from: 0.0, to: CGFloat(button.layer.opacity), duration: 0.2)
                }
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

func generateTopicIcon(backgroundColors: [UIColor], strokeColors: [UIColor], title: String) -> UIImage? {
    return generateImage(CGSize(width: 44.0, height: 44.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        context.saveGState()
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.2, y: 1.2)
        context.translateBy(x: -14.0 - UIScreenPixel, y: -14.0 - UIScreenPixel)
        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        context.clip()
        
        let colorsArray = backgroundColors.map { $0.cgColor } as NSArray
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        if let path = context.path {
            let strokePath = path.copy(strokingWithWidth: 1.0, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
            context.beginPath()
            context.addPath(strokePath)
            context.clip()
            
            let colorsArray = strokeColors.map { $0.cgColor } as NSArray
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
        
        context.restoreGState()
        
        let attributedString = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font: Font.with(size: 19.0, design: .round, weight: .bold), NSAttributedString.Key.foregroundColor: UIColor.white])
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        
        let lineOrigin = CGPoint(x: floorToScreenPixels(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0), y: floorToScreenPixels(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0) + 1.0)
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
        CTLineDraw(line, context)
        context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)
    })
}

private final class FadingMaskLayer: SimpleLayer {
    let gradientLayer = SimpleLayer()
    let fillLayer = SimpleLayer()
    let gradientFillLayer = SimpleLayer()
    
    var internalAlpha: CGFloat = 1.0 {
        didSet {
            self.gradientFillLayer.opacity = Float(1.0 - self.internalAlpha)
        }
    }
    
    override func layoutSublayers() {
        let gradientHeight: CGFloat = 66.0
        if self.gradientLayer.contents == nil {
            self.addSublayer(self.gradientLayer)
            self.addSublayer(self.fillLayer)
            self.addSublayer(self.gradientFillLayer)
            
            let gradientImage = generateGradientImage(size: CGSize(width: 1.0, height: gradientHeight), colors: [UIColor.white.withAlphaComponent(0.0), UIColor.white.withAlphaComponent(0.0), UIColor.white, UIColor.white], locations: [0.0, 0.4, 0.9, 1.0], direction: .vertical)
            self.gradientLayer.contents = gradientImage?.cgImage
            self.gradientLayer.contentsGravity = .resize
            self.fillLayer.backgroundColor = UIColor.white.cgColor
            self.gradientFillLayer.backgroundColor = UIColor.white.cgColor
        }
        
        self.gradientLayer.frame = CGRect(origin: .zero, size: CGSize(width: self.bounds.width, height: gradientHeight))
        self.gradientFillLayer.frame = self.gradientLayer.frame
        self.fillLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: gradientHeight), size: CGSize(width: self.bounds.width, height: self.bounds.height - gradientHeight))
    }
}

public struct StickerPickerInputData: StickerPickerInput, Equatable {
    public var emoji: EmojiPagerContentComponent?
    public var stickers: EmojiPagerContentComponent?
    public var gifs: GifPagerContentComponent?
    
    public init(
        emoji: EmojiPagerContentComponent?,
        stickers: EmojiPagerContentComponent?,
        gifs: GifPagerContentComponent?
    ) {
        self.emoji = emoji
        self.stickers = stickers
        self.gifs = gifs
    }
}
