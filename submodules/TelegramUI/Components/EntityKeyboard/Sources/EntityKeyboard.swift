import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import BundleIconComponent
import AudioToolbox
import SwiftSignalKit
import LocalizedPeerData

public final class EntityKeyboardChildEnvironment: Equatable {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let isContentInFocus: Bool
    public let getContentActiveItemUpdated: (AnyHashable) -> ActionSlot<(AnyHashable, AnyHashable?, Transition)>?
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        isContentInFocus: Bool,
        getContentActiveItemUpdated: @escaping (AnyHashable) -> ActionSlot<(AnyHashable, AnyHashable?, Transition)>?
    ) {
        self.theme = theme
        self.strings = strings
        self.isContentInFocus = isContentInFocus
        self.getContentActiveItemUpdated = getContentActiveItemUpdated
    }
    
    public static func ==(lhs: EntityKeyboardChildEnvironment, rhs: EntityKeyboardChildEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isContentInFocus != rhs.isContentInFocus {
            return false
        }
        
        return true
    }
}

public enum EntitySearchContentType {
    case stickers
    case gifs
}

public final class EntityKeyboardComponent: Component {
    public final class MarkInputCollapsed {
        public init() {
        }
    }
    
    public enum ReorderCategory {
        case stickers
        case emoji
        case masks
    }
    
    public struct GifSearchEmoji: Equatable {
        public var emoji: String
        public var file: TelegramMediaFile
        public var title: String
        
        public init(emoji: String, file: TelegramMediaFile, title: String) {
            self.emoji = emoji
            self.file = file
            self.title = title
        }
        
        public static func ==(lhs: GifSearchEmoji, rhs: GifSearchEmoji) -> Bool {
            if lhs.emoji != rhs.emoji {
                return false
            }
            if lhs.file.fileId != rhs.file.fileId {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            return true
        }
    }
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let isContentInFocus: Bool
    public let containerInsets: UIEdgeInsets
    public let topPanelInsets: UIEdgeInsets
    public let emojiContent: EmojiPagerContentComponent?
    public let stickerContent: EmojiPagerContentComponent?
    public let maskContent: EmojiPagerContentComponent?
    public let gifContent: GifPagerContentComponent?
    public let hasRecentGifs: Bool
    public let availableGifSearchEmojies: [GifSearchEmoji]
    public let defaultToEmojiTab: Bool
    public let externalTopPanelContainer: PagerExternalTopPanelContainer?
    public let externalBottomPanelContainer: PagerExternalTopPanelContainer?
    public let displayTopPanelBackground: Bool
    public let topPanelExtensionUpdated: (CGFloat, Transition) -> Void
    public let hideInputUpdated: (Bool, Bool, Transition) -> Void
    public let hideTopPanelUpdated: (Bool, Transition) -> Void
    public let switchToTextInput: () -> Void
    public let switchToGifSubject: (GifPagerContentComponent.Subject) -> Void
    public let reorderItems: (ReorderCategory, [EntityKeyboardTopPanelComponent.Item]) -> Void
    public let makeSearchContainerNode: (EntitySearchContentType) -> EntitySearchContainerNode?
    public let deviceMetrics: DeviceMetrics
    public let hiddenInputHeight: CGFloat
    public let inputHeight: CGFloat
    public let displayBottomPanel: Bool
    public let isExpanded: Bool
    public let clipContentToTopPanel: Bool
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        isContentInFocus: Bool,
        containerInsets: UIEdgeInsets,
        topPanelInsets: UIEdgeInsets,
        emojiContent: EmojiPagerContentComponent?,
        stickerContent: EmojiPagerContentComponent?,
        maskContent: EmojiPagerContentComponent?,
        gifContent: GifPagerContentComponent?,
        hasRecentGifs: Bool,
        availableGifSearchEmojies: [GifSearchEmoji],
        defaultToEmojiTab: Bool,
        externalTopPanelContainer: PagerExternalTopPanelContainer?,
        externalBottomPanelContainer: PagerExternalTopPanelContainer?,
        displayTopPanelBackground: Bool,
        topPanelExtensionUpdated: @escaping (CGFloat, Transition) -> Void,
        hideInputUpdated: @escaping (Bool, Bool, Transition) -> Void,
        hideTopPanelUpdated: @escaping (Bool, Transition) -> Void,
        switchToTextInput: @escaping () -> Void,
        switchToGifSubject: @escaping (GifPagerContentComponent.Subject) -> Void,
        reorderItems: @escaping (ReorderCategory, [EntityKeyboardTopPanelComponent.Item]) -> Void,
        makeSearchContainerNode: @escaping (EntitySearchContentType) -> EntitySearchContainerNode?,
        deviceMetrics: DeviceMetrics,
        hiddenInputHeight: CGFloat,
        inputHeight: CGFloat,
        displayBottomPanel: Bool,
        isExpanded: Bool,
        clipContentToTopPanel: Bool
    ) {
        self.theme = theme
        self.strings = strings
        self.isContentInFocus = isContentInFocus
        self.containerInsets = containerInsets
        self.topPanelInsets = topPanelInsets
        self.emojiContent = emojiContent
        self.stickerContent = stickerContent
        self.maskContent = maskContent
        self.gifContent = gifContent
        self.hasRecentGifs = hasRecentGifs
        self.availableGifSearchEmojies = availableGifSearchEmojies
        self.defaultToEmojiTab = defaultToEmojiTab
        self.externalTopPanelContainer = externalTopPanelContainer
        self.externalBottomPanelContainer = externalBottomPanelContainer
        self.displayTopPanelBackground = displayTopPanelBackground
        self.topPanelExtensionUpdated = topPanelExtensionUpdated
        self.hideInputUpdated = hideInputUpdated
        self.hideTopPanelUpdated = hideTopPanelUpdated
        self.switchToTextInput = switchToTextInput
        self.switchToGifSubject = switchToGifSubject
        self.reorderItems = reorderItems
        self.makeSearchContainerNode = makeSearchContainerNode
        self.deviceMetrics = deviceMetrics
        self.hiddenInputHeight = hiddenInputHeight
        self.inputHeight = inputHeight
        self.displayBottomPanel = displayBottomPanel
        self.isExpanded = isExpanded
        self.clipContentToTopPanel = clipContentToTopPanel
    }
    
    public static func ==(lhs: EntityKeyboardComponent, rhs: EntityKeyboardComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.isContentInFocus != rhs.isContentInFocus {
            return false
        }
        if lhs.containerInsets != rhs.containerInsets {
            return false
        }
        if lhs.topPanelInsets != rhs.topPanelInsets {
            return false
        }
        if lhs.emojiContent != rhs.emojiContent {
            return false
        }
        if lhs.stickerContent != rhs.stickerContent {
            return false
        }
        if lhs.maskContent != rhs.maskContent {
            return false
        }
        if lhs.gifContent != rhs.gifContent {
            return false
        }
        if lhs.hasRecentGifs != rhs.hasRecentGifs {
            return false
        }
        if lhs.availableGifSearchEmojies != rhs.availableGifSearchEmojies {
            return false
        }
        if lhs.defaultToEmojiTab != rhs.defaultToEmojiTab {
            return false
        }
        if lhs.externalTopPanelContainer != rhs.externalTopPanelContainer {
            return false
        }
        if lhs.displayTopPanelBackground != rhs.displayTopPanelBackground {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.hiddenInputHeight != rhs.hiddenInputHeight {
            return false
        }
        if lhs.inputHeight != rhs.inputHeight {
            return false
        }
        if lhs.displayBottomPanel != rhs.displayBottomPanel {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        if lhs.clipContentToTopPanel != rhs.clipContentToTopPanel {
            return false
        }
        
        return true
    }
    
    public final class View: UIView {
        private let tintContainerView: UIView
        
        private let pagerView: ComponentHostView<EntityKeyboardChildEnvironment>
        
        private var component: EntityKeyboardComponent?
        private weak var state: EmptyComponentState?
        
        private var searchView: ComponentHostView<EntitySearchContentEnvironment>?
        private var searchComponent: EntitySearchContentComponent?
        
        private var topPanelExtension: CGFloat?
        private var isTopPanelExpanded: Bool = false
        private var isTopPanelHidden: Bool = false
        
        public var centralId: AnyHashable? {
            if let pagerView = self.pagerView.findTaggedView(tag: PagerComponentViewTag()) as? PagerComponent<EntityKeyboardChildEnvironment, EntityKeyboardTopContainerPanelEnvironment>.View {
                return pagerView.centralId
            } else {
                return nil
            }
        }
        
        override init(frame: CGRect) {
            self.tintContainerView = UIView()
            self.pagerView = ComponentHostView<EntityKeyboardChildEnvironment>()
            
            super.init(frame: frame)
            
            //self.clipsToBounds = true
            self.disablesInteractiveTransitionGestureRecognizer = true
            
            self.addSubview(self.pagerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntityKeyboardComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.state = state
            
            var contents: [AnyComponentWithIdentity<(EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)>] = []
            var contentTopPanels: [AnyComponentWithIdentity<EntityKeyboardTopContainerPanelEnvironment>] = []
            var contentIcons: [PagerComponentContentIcon] = []
            var contentAccessoryLeftButtons: [AnyComponentWithIdentity<Empty>] = []
            var contentAccessoryRightButtons: [AnyComponentWithIdentity<Empty>] = []
            
            let gifsContentItemIdUpdated = ActionSlot<(AnyHashable, AnyHashable?, Transition)>()
            let stickersContentItemIdUpdated = ActionSlot<(AnyHashable, AnyHashable?, Transition)>()
            let masksContentItemIdUpdated = ActionSlot<(AnyHashable, AnyHashable?, Transition)>()
            
            if transition.userData(MarkInputCollapsed.self) != nil {
                self.searchComponent = nil
            }
            
            if let maskContent = component.maskContent {
                var topMaskItems: [EntityKeyboardTopPanelComponent.Item] = []
                                
                for itemGroup in maskContent.itemGroups {
                    if let id = itemGroup.supergroupId.base as? String {
                        let iconMapping: [String: EntityKeyboardIconTopPanelComponent.Icon] = [
                            "saved": .saved,
                            "recent": .recent,
                            "premium": .premium
                        ]
                        let titleMapping: [String: String] = [
                            "saved": component.strings.Stickers_Favorites,
                            "recent": component.strings.Stickers_Recent,
                            "premium": component.strings.EmojiInput_PanelTitlePremium
                        ]
                        if let icon = iconMapping[id], let title = titleMapping[id] {
                            topMaskItems.append(EntityKeyboardTopPanelComponent.Item(
                                id: itemGroup.supergroupId,
                                isReorderable: false,
                                content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                                    icon: icon,
                                    theme: component.theme,
                                    useAccentColor: false,
                                    title: title,
                                    pressed: { [weak self] in
                                        self?.scrollToItemGroup(contentId: "masks", groupId: itemGroup.supergroupId, subgroupId: nil)
                                    }
                                ))
                            ))
                        }
                    } else {
                        if !itemGroup.items.isEmpty {
                            if let animationData = itemGroup.items[0].animationData {
                                topMaskItems.append(EntityKeyboardTopPanelComponent.Item(
                                    id: itemGroup.supergroupId,
                                    isReorderable: !itemGroup.isFeatured,
                                    content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                                        context: maskContent.context,
                                        item: itemGroup.headerItem ?? animationData,
                                        isFeatured: itemGroup.isFeatured,
                                        isPremiumLocked: itemGroup.isPremiumLocked,
                                        animationCache: maskContent.animationCache,
                                        animationRenderer: maskContent.animationRenderer,
                                        theme: component.theme,
                                        title: itemGroup.title ?? "",
                                        pressed: { [weak self] in
                                            self?.scrollToItemGroup(contentId: "masks", groupId: itemGroup.supergroupId, subgroupId: nil)
                                        }
                                    ))
                                ))
                            }
                        }
                    }
                }
                contents.append(AnyComponentWithIdentity(id: "masks", component: AnyComponent(maskContent)))
                contentTopPanels.append(AnyComponentWithIdentity(id: "masks", component: AnyComponent(EntityKeyboardTopPanelComponent(
                    id: "masks",
                    theme: component.theme,
                    items: topMaskItems,
                    containerSideInset: component.containerInsets.left + component.topPanelInsets.left,
                    defaultActiveItemId: maskContent.itemGroups.first?.groupId,
                    activeContentItemIdUpdated: masksContentItemIdUpdated,
                    reorderItems: { [weak self] items in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.reorderPacks(category: .masks, items: items)
                    }
                ))))
                contentIcons.append(PagerComponentContentIcon(id: "masks", imageName: "Chat/Input/Media/EntityInputMasksIcon"))
                if let _ = component.maskContent?.inputInteractionHolder.inputInteraction?.openStickerSettings {
                    contentAccessoryRightButtons.append(AnyComponentWithIdentity(id: "masks", component: AnyComponent(Button(
                        content: AnyComponent(BundleIconComponent(
                            name: "Chat/Input/Media/EntityInputSettingsIcon",
                            tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                            maxSize: nil
                        )),
                        action: {
                            maskContent.inputInteractionHolder.inputInteraction?.openStickerSettings?()
                        }
                    ).minSize(CGSize(width: 38.0, height: 38.0)))))
                }
            }
            
            if let gifContent = component.gifContent {
                contents.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(gifContent)))
                var topGifItems: [EntityKeyboardTopPanelComponent.Item] = []
                if component.hasRecentGifs {
                    topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                        id: "recent",
                        isReorderable: false,
                        content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                            icon: .recent,
                            theme: component.theme,
                            useAccentColor: false,
                            title: component.strings.Stickers_Recent,
                            pressed: { [weak self] in
                                self?.component?.switchToGifSubject(.recent)
                            }
                        ))
                    ))
                }
                topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                    id: "trending",
                    isReorderable: false,
                    content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                        icon: .trending,
                        theme: component.theme,
                        useAccentColor: false,
                        title: component.strings.Stickers_Trending,
                        pressed: { [weak self] in
                            self?.component?.switchToGifSubject(.trending)
                        }
                    ))
                ))
                if let emojiContent = component.emojiContent {
                    for emoji in component.availableGifSearchEmojies {
                        topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                            id: emoji.emoji,
                            isReorderable: false,
                            content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                                context: emojiContent.context,
                                item: EntityKeyboardAnimationData(file: emoji.file),
                                isFeatured: false,
                                isPremiumLocked: false,
                                animationCache: emojiContent.animationCache,
                                animationRenderer: emojiContent.animationRenderer,
                                theme: component.theme,
                                title: emoji.title,
                                pressed: { [weak self] in
                                    self?.component?.switchToGifSubject(.emojiSearch(emoji.emoji))
                                }
                            ))
                        ))
                    }
                }
                let defaultActiveGifItemId: AnyHashable
                switch gifContent.subject {
                case .recent:
                    defaultActiveGifItemId = "recent"
                case .trending:
                    defaultActiveGifItemId = "trending"
                case let .emojiSearch(value):
                    defaultActiveGifItemId = AnyHashable(value)
                }
                contentTopPanels.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(EntityKeyboardTopPanelComponent(
                    id: "gifs",
                    theme: component.theme,
                    items: topGifItems,
                    containerSideInset: component.containerInsets.left + component.topPanelInsets.left,
                    forceActiveItemId: defaultActiveGifItemId,
                    activeContentItemIdUpdated: gifsContentItemIdUpdated,
                    reorderItems: { _ in
                    }
                ))))
                contentIcons.append(PagerComponentContentIcon(id: "gifs", imageName: "Chat/Input/Media/EntityInputGifsIcon"))
            }
            
            if let stickerContent = component.stickerContent {
                var topStickerItems: [EntityKeyboardTopPanelComponent.Item] = []
                
                if let _ = stickerContent.inputInteractionHolder.inputInteraction?.openFeatured {
                    topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                        id: "featuredTop",
                        isReorderable: false,
                        content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                            icon: .featured,
                            theme: component.theme,
                            useAccentColor: false,
                            title: component.strings.Stickers_Trending,
                            pressed: { [weak self] in
                                self?.component?.stickerContent?.inputInteractionHolder.inputInteraction?.openFeatured?()
                            }
                        ))
                    ))
                }
                
                for itemGroup in stickerContent.itemGroups {
                    if let id = itemGroup.supergroupId.base as? String {
                        if id == "peerSpecific" {
                            if let avatarPeer = stickerContent.avatarPeer {
                                topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                                    id: itemGroup.supergroupId,
                                    isReorderable: false,
                                    content: AnyComponent(EntityKeyboardAvatarTopPanelComponent(
                                        context: stickerContent.context,
                                        peer: avatarPeer,
                                        theme: component.theme,
                                        title: avatarPeer.compactDisplayTitle,
                                        pressed: { [weak self] in
                                            self?.scrollToItemGroup(contentId: "stickers", groupId: itemGroup.supergroupId, subgroupId: nil)
                                        }
                                    ))
                                ))
                            }
                        } else {
                            let iconMapping: [String: EntityKeyboardIconTopPanelComponent.Icon] = [
                                "saved": .saved,
                                "recent": .recent,
                                "premium": .premium
                            ]
                            let titleMapping: [String: String] = [
                                "saved": component.strings.Stickers_Favorites,
                                "recent": component.strings.Stickers_Recent,
                                "premium": component.strings.EmojiInput_PanelTitlePremium
                            ]
                            if let icon = iconMapping[id], let title = titleMapping[id] {
                                topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                                    id: itemGroup.supergroupId,
                                    isReorderable: false,
                                    content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                                        icon: icon,
                                        theme: component.theme,
                                        useAccentColor: false,
                                        title: title,
                                        pressed: { [weak self] in
                                            self?.scrollToItemGroup(contentId: "stickers", groupId: itemGroup.supergroupId, subgroupId: nil)
                                        }
                                    ))
                                ))
                            }
                        }
                    } else {
                        if !itemGroup.items.isEmpty {
                            if let animationData = itemGroup.items[0].animationData {
                                topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                                    id: itemGroup.supergroupId,
                                    isReorderable: !itemGroup.isFeatured,
                                    content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                                        context: stickerContent.context,
                                        item: itemGroup.headerItem ?? animationData,
                                        isFeatured: itemGroup.isFeatured,
                                        isPremiumLocked: itemGroup.isPremiumLocked,
                                        animationCache: stickerContent.animationCache,
                                        animationRenderer: stickerContent.animationRenderer,
                                        theme: component.theme,
                                        title: itemGroup.title ?? "",
                                        pressed: { [weak self] in
                                            self?.scrollToItemGroup(contentId: "stickers", groupId: itemGroup.supergroupId, subgroupId: nil)
                                        }
                                    ))
                                ))
                            }
                        }
                    }
                }
                contents.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(stickerContent)))
                contentTopPanels.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(EntityKeyboardTopPanelComponent(
                    id: "stickers",
                    theme: component.theme,
                    items: topStickerItems,
                    containerSideInset: component.containerInsets.left + component.topPanelInsets.left,
                    defaultActiveItemId: stickerContent.itemGroups.first?.groupId,
                    activeContentItemIdUpdated: stickersContentItemIdUpdated,
                    reorderItems: { [weak self] items in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.reorderPacks(category: .stickers, items: items)
                    }
                ))))
                contentIcons.append(PagerComponentContentIcon(id: "stickers", imageName: "Chat/Input/Media/EntityInputStickersIcon"))
                if let _ = component.stickerContent?.inputInteractionHolder.inputInteraction?.openStickerSettings {
                    contentAccessoryRightButtons.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(Button(
                        content: AnyComponent(BundleIconComponent(
                            name: "Chat/Input/Media/EntityInputSettingsIcon",
                            tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                            maxSize: nil
                        )),
                        action: {
                            stickerContent.inputInteractionHolder.inputInteraction?.openStickerSettings?()
                        }
                    ).minSize(CGSize(width: 38.0, height: 38.0)))))
                }
            }
            
            let deleteBackwards = component.emojiContent?.inputInteractionHolder.inputInteraction?.deleteBackwards
            
            let emojiContentItemIdUpdated = ActionSlot<(AnyHashable, AnyHashable?, Transition)>()
            if let emojiContent = component.emojiContent {
                contents.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(emojiContent)))
                var topEmojiItems: [EntityKeyboardTopPanelComponent.Item] = []
                for itemGroup in emojiContent.itemGroups {
                    if !itemGroup.items.isEmpty {
                        if let id = itemGroup.groupId.base as? String {
                            if id == "recent" {
                                let iconMapping: [String: EntityKeyboardIconTopPanelComponent.Icon] = [
                                    "recent": .recent,
                                ]
                                let titleMapping: [String: String] = [
                                    "recent": component.strings.Stickers_Recent,
                                ]
                                if let icon = iconMapping[id], let title = titleMapping[id] {
                                    topEmojiItems.append(EntityKeyboardTopPanelComponent.Item(
                                        id: itemGroup.supergroupId,
                                        isReorderable: false,
                                        content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                                            icon: icon,
                                            theme: component.theme,
                                            useAccentColor: false,
                                            title: title,
                                            pressed: { [weak self] in
                                                self?.scrollToItemGroup(contentId: "emoji", groupId: itemGroup.supergroupId, subgroupId: nil)
                                            }
                                        ))
                                    ))
                                }
                            } else if id == "static" {
                                topEmojiItems.append(EntityKeyboardTopPanelComponent.Item(
                                    id: itemGroup.supergroupId,
                                    isReorderable: false,
                                    content: AnyComponent(EntityKeyboardStaticStickersPanelComponent(
                                        theme: component.theme,
                                        title: component.strings.EmojiInput_PanelTitleEmoji,
                                        pressed: { [weak self] subgroupId in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            strongSelf.scrollToItemGroup(contentId: "emoji", groupId: itemGroup.supergroupId, subgroupId: subgroupId.rawValue)
                                        }
                                    ))
                                ))
                            }
                        } else {
                            if let animationData = itemGroup.items[0].animationData {
                                topEmojiItems.append(EntityKeyboardTopPanelComponent.Item(
                                    id: itemGroup.supergroupId,
                                    isReorderable: !itemGroup.isFeatured,
                                    content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                                        context: emojiContent.context,
                                        item: itemGroup.headerItem ?? animationData,
                                        isFeatured: itemGroup.isFeatured,
                                        isPremiumLocked: itemGroup.isPremiumLocked,
                                        animationCache: emojiContent.animationCache,
                                        animationRenderer: emojiContent.animationRenderer,
                                        theme: component.theme,
                                        title: itemGroup.title ?? "",
                                        pressed: { [weak self] in
                                            self?.scrollToItemGroup(contentId: "emoji", groupId: itemGroup.supergroupId, subgroupId: nil)
                                        }
                                    ))
                                ))
                            }
                        }
                    }
                }
                contentTopPanels.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(EntityKeyboardTopPanelComponent(
                    id: "emoji",
                    theme: component.theme,
                    items: topEmojiItems,
                    containerSideInset: component.containerInsets.left + component.topPanelInsets.left,
                    activeContentItemIdUpdated: emojiContentItemIdUpdated,
                    activeContentItemMapping: ["popular": "recent"],
                    reorderItems: { [weak self] items in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.reorderPacks(category: .emoji, items: items)
                    }
                ))))
                contentIcons.append(PagerComponentContentIcon(id: "emoji", imageName: "Chat/Input/Media/EntityInputEmojiIcon"))
                if let _ = deleteBackwards {
                    contentAccessoryLeftButtons.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(Button(
                        content: AnyComponent(BundleIconComponent(
                            name: "Chat/Input/Media/EntityInputGlobeIcon",
                            tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                            maxSize: nil
                        )),
                        action: { [weak self] in
                            guard let strongSelf = self, let component = strongSelf.component else {
                                return
                            }
                            component.switchToTextInput()
                        }
                    ).minSize(CGSize(width: 38.0, height: 38.0)))))
                }
            }
                            
            if let _ = deleteBackwards {
                contentAccessoryRightButtons.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(Button(
                    content: AnyComponent(BundleIconComponent(
                        name: "Chat/Input/Media/EntityInputClearIcon",
                        tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                        maxSize: nil
                    )),
                    action: {
                        deleteBackwards?()
                        AudioServicesPlaySystemSound(1155)
                    }
                ).withHoldAction({
                    deleteBackwards?()
                    AudioServicesPlaySystemSound(1155)
                }).minSize(CGSize(width: 38.0, height: 38.0)))))
            }
            
            let panelHideBehavior: PagerComponentPanelHideBehavior
            if self.searchComponent != nil {
                panelHideBehavior = .hide
            } else if component.isExpanded {
                panelHideBehavior = .show
            } else {
                panelHideBehavior = .hideOnScroll
            }
            
            let pagerSize = self.pagerView.update(
                transition: transition,
                component: AnyComponent(PagerComponent(
                    contentInsets: component.containerInsets,
                    contents: contents,
                    contentTopPanels: contentTopPanels,
                    contentIcons: contentIcons,
                    contentAccessoryLeftButtons: contentAccessoryLeftButtons,
                    contentAccessoryRightButtons: contentAccessoryRightButtons,
                    defaultId: component.defaultToEmojiTab ? "emoji" : "stickers",
                    contentBackground: nil,
                    topPanel: AnyComponent(EntityKeyboardTopContainerPanelComponent(
                        theme: component.theme,
                        overflowHeight: component.hiddenInputHeight,
                        displayBackground: component.externalTopPanelContainer == nil && component.displayTopPanelBackground
                    )),
                    externalTopPanelContainer: component.externalTopPanelContainer,
                    bottomPanel: component.displayBottomPanel ? AnyComponent(EntityKeyboardBottomPanelComponent(
                        theme: component.theme,
                        containerInsets: component.containerInsets,
                        deleteBackwards: { [weak self] in
                            self?.component?.emojiContent?.inputInteractionHolder.inputInteraction?.deleteBackwards?()
                            AudioServicesPlaySystemSound(0x451)
                        }
                    )) : nil,
                    externalBottomPanelContainer: component.externalBottomPanelContainer,
                    panelStateUpdated: { [weak self] panelState, transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.topPanelExtensionUpdated(height: panelState.topPanelHeight, transition: transition)
                    },
                    isTopPanelExpandedUpdated: { [weak self] isExpanded, transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.isTopPanelExpandedUpdated(isExpanded: isExpanded, transition: transition)
                    },
                    isTopPanelHiddenUpdated: { [weak self] isTopPanelHidden, transition in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.isTopPanelHiddenUpdated(isTopPanelHidden: isTopPanelHidden, transition: transition)
                    },
                    panelHideBehavior: panelHideBehavior,
                    clipContentToTopPanel: component.clipContentToTopPanel
                )),
                environment: {
                    EntityKeyboardChildEnvironment(
                        theme: component.theme,
                        strings: component.strings,
                        isContentInFocus: component.isContentInFocus,
                        getContentActiveItemUpdated: { id in
                            if id == AnyHashable("gifs") {
                                return gifsContentItemIdUpdated
                            } else if id == AnyHashable("stickers") {
                                return stickersContentItemIdUpdated
                            } else if id == AnyHashable("emoji") {
                                return emojiContentItemIdUpdated
                            } else if id == AnyHashable("masks") {
                                return masksContentItemIdUpdated
                            }
                            return nil
                        }
                    )
                },
                containerSize: availableSize
            )
            transition.setFrame(view: self.pagerView, frame: CGRect(origin: CGPoint(), size: pagerSize))
            
            let accountContext = component.emojiContent?.context ?? component.stickerContent?.context
            if let searchComponent = self.searchComponent, let accountContext = accountContext {
                var animateIn = false
                let searchView: ComponentHostView<EntitySearchContentEnvironment>
                var searchViewTransition = transition
                if let current = self.searchView {
                    searchView = current
                } else {
                    searchViewTransition = .immediate
                    searchView = ComponentHostView<EntitySearchContentEnvironment>()
                    self.searchView = searchView
                    self.addSubview(searchView)
                    
                    animateIn = true
                    component.topPanelExtensionUpdated(0.0, transition)
                }
                
                let _ = searchView.update(
                    transition: searchViewTransition,
                    component: AnyComponent(searchComponent),
                    environment: {
                        EntitySearchContentEnvironment(
                            context: accountContext,
                            theme: component.theme,
                            deviceMetrics: component.deviceMetrics,
                            inputHeight: component.inputHeight
                        )
                    },
                    containerSize: availableSize
                )
                searchViewTransition.setFrame(view: searchView, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if animateIn {
                    transition.animateAlpha(view: searchView, from: 0.0, to: 1.0)
                    transition.animatePosition(view: searchView, from: CGPoint(x: 0.0, y: self.topPanelExtension ?? 0.0), to: CGPoint(), additive: true, completion: nil)
                }
            } else {
                if let searchView = self.searchView {
                    self.searchView = nil
                    
                    transition.setFrame(view: searchView, frame: CGRect(origin: CGPoint(x: 0.0, y: self.topPanelExtension ?? 0.0), size: availableSize))
                    transition.setAlpha(view: searchView, alpha: 0.0, completion: { [weak searchView] _ in
                        searchView?.removeFromSuperview()
                    })
                    
                    if let topPanelExtension = self.topPanelExtension {
                        component.topPanelExtensionUpdated(topPanelExtension, transition)
                    }
                }
            }
            
            self.component = component
            
            return availableSize
        }
        
        private func topPanelExtensionUpdated(height: CGFloat, transition: Transition) {
            guard let component = self.component else {
                return
            }
            if self.topPanelExtension != height {
                self.topPanelExtension = height
            }
            if self.searchComponent == nil {
                component.topPanelExtensionUpdated(height, transition)
            }
        }
        
        private func isTopPanelExpandedUpdated(isExpanded: Bool, transition: Transition) {
            if self.isTopPanelExpanded != isExpanded {
                self.isTopPanelExpanded = isExpanded
            }
            
            guard let component = self.component else {
                return
            }
            
            component.hideInputUpdated(self.isTopPanelExpanded, false, transition)
        }
        
        private func isTopPanelHiddenUpdated(isTopPanelHidden: Bool, transition: Transition) {
            if self.isTopPanelHidden != isTopPanelHidden {
                self.isTopPanelHidden = isTopPanelHidden
            }
            
            guard let component = self.component else {
                return
            }
            
            component.hideTopPanelUpdated(self.isTopPanelHidden, transition)
        }
        
        public func openSearch() {
            guard let component = self.component else {
                return
            }
            if self.searchComponent != nil {
                return
            }
            
            if let pagerView = self.pagerView.findTaggedView(tag: PagerComponentViewTag()) as? PagerComponent<EntityKeyboardChildEnvironment, EntityKeyboardTopContainerPanelEnvironment>.View, let centralId = pagerView.centralId {
                let contentType: EntitySearchContentType
                if centralId == AnyHashable("gifs") {
                    contentType = .gifs
                } else {
                    contentType = .stickers
                }
                
                self.searchComponent = EntitySearchContentComponent(
                    makeContainerNode: {
                        return component.makeSearchContainerNode(contentType)
                    },
                    dismissSearch: { [weak self] in
                        self?.closeSearch()
                    }
                )
                //self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
                component.hideInputUpdated(true, true, Transition(animation: .curve(duration: 0.3, curve: .spring)))
            }
        }
        
        private func closeSearch() {
            guard let component = self.component else {
                return
            }
            if self.searchComponent == nil {
                return
            }
            self.searchComponent = nil
            //self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
            component.hideInputUpdated(false, false, Transition(animation: .curve(duration: 0.4, curve: .spring)))
        }
        
        private func scrollToItemGroup(contentId: String, groupId: AnyHashable, subgroupId: Int32?) {
            guard let pagerView = self.pagerView.findTaggedView(tag: PagerComponentViewTag()) as? PagerComponent<EntityKeyboardChildEnvironment, EntityKeyboardTopContainerPanelEnvironment>.View else {
                return
            }
            guard let pagerContentView = self.pagerView.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: contentId)) as? EmojiPagerContentComponent.View else {
                return
            }
            if let topPanelView = pagerView.topPanelComponentView as? EntityKeyboardTopContainerPanelComponent.View {
                topPanelView.internalUpdatePanelsAreCollapsed()
            }
            self.component?.emojiContent?.inputInteractionHolder.inputInteraction?.updateScrollingToItemGroup()
            
            pagerContentView.scrollToItemGroup(id: groupId, subgroupId: subgroupId)
            pagerView.collapseTopPanel()
        }
        
        private func reorderPacks(category: ReorderCategory, items: [EntityKeyboardTopPanelComponent.Item]) {
            self.component?.reorderItems(category, items)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
