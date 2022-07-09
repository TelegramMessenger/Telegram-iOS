import Foundation
import UIKit
import Display
import ComponentFlow
import PagerComponent
import TelegramPresentationData
import TelegramCore
import Postbox
import BlurredBackgroundComponent
import BundleIconComponent

public final class EntityKeyboardChildEnvironment: Equatable {
    public let theme: PresentationTheme
    public let getContentActiveItemUpdated: (AnyHashable) -> ActionSlot<(AnyHashable, Transition)>?
    
    public init(
        theme: PresentationTheme,
        getContentActiveItemUpdated: @escaping (AnyHashable) -> ActionSlot<(AnyHashable, Transition)>?
    ) {
        self.theme = theme
        self.getContentActiveItemUpdated = getContentActiveItemUpdated
    }
    
    public static func ==(lhs: EntityKeyboardChildEnvironment, rhs: EntityKeyboardChildEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
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
    public let bottomInset: CGFloat
    public let emojiContent: EmojiPagerContentComponent
    public let stickerContent: EmojiPagerContentComponent
    public let gifContent: GifPagerContentComponent
    public let availableGifSearchEmojies: [GifSearchEmoji]
    public let defaultToEmojiTab: Bool
    public let externalTopPanelContainer: PagerExternalTopPanelContainer?
    public let topPanelExtensionUpdated: (CGFloat, Transition) -> Void
    public let hideInputUpdated: (Bool, Bool, Transition) -> Void
    public let switchToTextInput: () -> Void
    public let switchToGifSubject: (GifPagerContentComponent.Subject) -> Void
    public let makeSearchContainerNode: (EntitySearchContentType) -> EntitySearchContainerNode
    public let deviceMetrics: DeviceMetrics
    public let hiddenInputHeight: CGFloat
    public let isExpanded: Bool
    
    public init(
        theme: PresentationTheme,
        bottomInset: CGFloat,
        emojiContent: EmojiPagerContentComponent,
        stickerContent: EmojiPagerContentComponent,
        gifContent: GifPagerContentComponent,
        availableGifSearchEmojies: [GifSearchEmoji],
        defaultToEmojiTab: Bool,
        externalTopPanelContainer: PagerExternalTopPanelContainer?,
        topPanelExtensionUpdated: @escaping (CGFloat, Transition) -> Void,
        hideInputUpdated: @escaping (Bool, Bool, Transition) -> Void,
        switchToTextInput: @escaping () -> Void,
        switchToGifSubject: @escaping (GifPagerContentComponent.Subject) -> Void,
        makeSearchContainerNode: @escaping (EntitySearchContentType) -> EntitySearchContainerNode,
        deviceMetrics: DeviceMetrics,
        hiddenInputHeight: CGFloat,
        isExpanded: Bool
    ) {
        self.theme = theme
        self.bottomInset = bottomInset
        self.emojiContent = emojiContent
        self.stickerContent = stickerContent
        self.gifContent = gifContent
        self.availableGifSearchEmojies = availableGifSearchEmojies
        self.defaultToEmojiTab = defaultToEmojiTab
        self.externalTopPanelContainer = externalTopPanelContainer
        self.topPanelExtensionUpdated = topPanelExtensionUpdated
        self.hideInputUpdated = hideInputUpdated
        self.switchToTextInput = switchToTextInput
        self.switchToGifSubject = switchToGifSubject
        self.makeSearchContainerNode = makeSearchContainerNode
        self.deviceMetrics = deviceMetrics
        self.hiddenInputHeight = hiddenInputHeight
        self.isExpanded = isExpanded
    }
    
    public static func ==(lhs: EntityKeyboardComponent, rhs: EntityKeyboardComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        if lhs.emojiContent != rhs.emojiContent {
            return false
        }
        if lhs.stickerContent != rhs.stickerContent {
            return false
        }
        if lhs.gifContent != rhs.gifContent {
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
        if lhs.deviceMetrics != rhs.deviceMetrics {
            return false
        }
        if lhs.hiddenInputHeight != rhs.hiddenInputHeight {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        
        return true
    }
    
    public final class View: UIView {
        private let pagerView: ComponentHostView<EntityKeyboardChildEnvironment>
        
        private var component: EntityKeyboardComponent?
        private weak var state: EmptyComponentState?
        
        private var searchView: ComponentHostView<EntitySearchContentEnvironment>?
        private var searchComponent: EntitySearchContentComponent?
        
        private var topPanelExtension: CGFloat?
        private var isTopPanelExpanded: Bool = false
        
        override init(frame: CGRect) {
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
            var contentIcons: [AnyComponentWithIdentity<Empty>] = []
            var contentAccessoryLeftButtons: [AnyComponentWithIdentity<Empty>] = []
            var contentAccessoryRightButtons: [AnyComponentWithIdentity<Empty>] = []
            
            let gifsContentItemIdUpdated = ActionSlot<(AnyHashable, Transition)>()
            contents.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(component.gifContent)))
            var topGifItems: [EntityKeyboardTopPanelComponent.Item] = []
            //TODO:localize
            topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                id: "recent",
                content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                    imageName: "Chat/Input/Media/RecentTabIcon",
                    theme: component.theme,
                    title: "Recent",
                    pressed: { [weak self] in
                        self?.component?.switchToGifSubject(.recent)
                    }
                ))
            ))
            topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                id: "trending",
                content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                    imageName: "Chat/Input/Media/TrendingGifs",
                    theme: component.theme,
                    title: "Trending",
                    pressed: { [weak self] in
                        self?.component?.switchToGifSubject(.trending)
                    }
                ))
            ))
            for emoji in component.availableGifSearchEmojies {
                topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                    id: emoji.emoji,
                    content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                        context: component.stickerContent.context,
                        file: emoji.file,
                        animationCache: component.stickerContent.animationCache,
                        animationRenderer: component.stickerContent.animationRenderer,
                        theme: component.theme,
                        title: emoji.title,
                        pressed: { [weak self] in
                            self?.component?.switchToGifSubject(.emojiSearch(emoji.emoji))
                        }
                    ))
                ))
            }
            let defaultActiveGifItemId: AnyHashable
            switch component.gifContent.subject {
            case .recent:
                defaultActiveGifItemId = "recent"
            case .trending:
                defaultActiveGifItemId = "trending"
            case let .emojiSearch(value):
                defaultActiveGifItemId = AnyHashable(value)
            }
            contentTopPanels.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(EntityKeyboardTopPanelComponent(
                theme: component.theme,
                items: topGifItems,
                defaultActiveItemId: defaultActiveGifItemId,
                activeContentItemIdUpdated: gifsContentItemIdUpdated
            ))))
            contentIcons.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(BundleIconComponent(
                name: "Chat/Input/Media/EntityInputGifsIcon",
                tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                maxSize: nil
            ))))
            contentAccessoryLeftButtons.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(Button(
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/EntityInputSearchIcon",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: nil
                )),
                action: { [weak self] in
                    self?.openSearch()
                }
            ).minSize(CGSize(width: 38.0, height: 38.0)))))
            /*contentAccessoryRightButtons.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(Button(
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/EntityInputSettingsIcon",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: nil
                )),
                action: {
                }
            ).minSize(CGSize(width: 38.0, height: 38.0)))))*/
            
            var topStickerItems: [EntityKeyboardTopPanelComponent.Item] = []
            for itemGroup in component.stickerContent.itemGroups {
                if let id = itemGroup.id.base as? String {
                    let iconMapping: [String: String] = [
                        "recent": "Chat/Input/Media/RecentTabIcon",
                        "premium": "Chat/Input/Media/PremiumIcon"
                    ]
                    let titleMapping: [String: String] = [
                        "recent": "Recent",
                        "premium": "Premium"
                    ]
                    if let iconName = iconMapping[id], let title = titleMapping[id] {
                        topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                            id: itemGroup.id,
                            content: AnyComponent(EntityKeyboardIconTopPanelComponent(
                                imageName: iconName,
                                theme: component.theme,
                                title: title,
                                pressed: { [weak self] in
                                    self?.scrollToItemGroup(contentId: "stickers", groupId: itemGroup.id)
                                }
                            ))
                        ))
                    }
                } else {
                    if !itemGroup.items.isEmpty {
                        topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                            id: itemGroup.id,
                            content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                                context: component.stickerContent.context,
                                file: itemGroup.items[0].file,
                                animationCache: component.stickerContent.animationCache,
                                animationRenderer: component.stickerContent.animationRenderer,
                                theme: component.theme,
                                title: itemGroup.title ?? "",
                                pressed: { [weak self] in
                                    self?.scrollToItemGroup(contentId: "stickers", groupId: itemGroup.id)
                                }
                            ))
                        ))
                    }
                }
            }
            let stickersContentItemIdUpdated = ActionSlot<(AnyHashable, Transition)>()
            contents.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(component.stickerContent)))
            contentTopPanels.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(EntityKeyboardTopPanelComponent(
                theme: component.theme,
                items: topStickerItems,
                activeContentItemIdUpdated: stickersContentItemIdUpdated
            ))))
            contentIcons.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(BundleIconComponent(
                name: "Chat/Input/Media/EntityInputStickersIcon",
                tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                maxSize: nil
            ))))
            contentAccessoryLeftButtons.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(Button(
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/EntityInputSearchIcon",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: nil
                )),
                action: { [weak self] in
                    self?.openSearch()
                }
            ).minSize(CGSize(width: 38.0, height: 38.0)))))
            contentAccessoryRightButtons.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(Button(
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/EntityInputSettingsIcon",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: nil
                )),
                action: {
                    component.stickerContent.inputInteraction.openStickerSettings()
                }
            ).minSize(CGSize(width: 38.0, height: 38.0)))))
            
            let emojiContentItemIdUpdated = ActionSlot<(AnyHashable, Transition)>()
            contents.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(component.emojiContent)))
            var topEmojiItems: [EntityKeyboardTopPanelComponent.Item] = []
            for itemGroup in component.emojiContent.itemGroups {
                if !itemGroup.items.isEmpty {
                    topEmojiItems.append(EntityKeyboardTopPanelComponent.Item(
                        id: itemGroup.id,
                        content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                            context: component.emojiContent.context,
                            file: itemGroup.items[0].file,
                            animationCache: component.emojiContent.animationCache,
                            animationRenderer: component.emojiContent.animationRenderer,
                            theme: component.theme,
                            title: itemGroup.title ?? "",
                            pressed: { [weak self] in
                                self?.scrollToItemGroup(contentId: "emoji", groupId: itemGroup.id)
                            }
                        ))
                    ))
                }
            }
            contentTopPanels.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(EntityKeyboardTopPanelComponent(
                theme: component.theme,
                items: topEmojiItems,
                activeContentItemIdUpdated: emojiContentItemIdUpdated
            ))))
            contentIcons.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(BundleIconComponent(
                name: "Chat/Input/Media/EntityInputEmojiIcon",
                tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                maxSize: nil
            ))))
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
            let deleteBackwards = component.emojiContent.inputInteraction.deleteBackwards
            contentAccessoryRightButtons.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(Button(
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/EntityInputClearIcon",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: nil
                )),
                action: {
                    deleteBackwards()
                }
            ).withHoldAction({
                deleteBackwards()
            }).minSize(CGSize(width: 38.0, height: 38.0)))))
            
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
                    contentInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0),
                    contents: contents,
                    contentTopPanels: contentTopPanels,
                    contentIcons: contentIcons,
                    contentAccessoryLeftButtons: contentAccessoryLeftButtons,
                    contentAccessoryRightButtons: contentAccessoryRightButtons,
                    defaultId: component.defaultToEmojiTab ? "emoji" : "stickers",
                    contentBackground: AnyComponent(BlurredBackgroundComponent(
                        color: component.theme.chat.inputMediaPanel.stickersBackgroundColor.withMultipliedAlpha(0.75)
                    )),
                    topPanel: AnyComponent(EntityKeyboardTopContainerPanelComponent(
                        theme: component.theme,
                        overflowHeight: component.hiddenInputHeight
                    )),
                    externalTopPanelContainer: component.externalTopPanelContainer,
                    bottomPanel: AnyComponent(EntityKeyboardBottomPanelComponent(
                        theme: component.theme,
                        bottomInset: component.bottomInset,
                        deleteBackwards: { [weak self] in
                            self?.component?.emojiContent.inputInteraction.deleteBackwards()
                        }
                    )),
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
                    panelHideBehavior: panelHideBehavior
                )),
                environment: {
                    EntityKeyboardChildEnvironment(
                        theme: component.theme,
                        getContentActiveItemUpdated: { id in
                            if id == AnyHashable("gifs") {
                                return gifsContentItemIdUpdated
                            } else if id == AnyHashable("stickers") {
                                return stickersContentItemIdUpdated
                            } else if id == AnyHashable("emoji") {
                                return emojiContentItemIdUpdated
                            }
                            return nil
                        }
                    )
                },
                containerSize: availableSize
            )
            transition.setFrame(view: self.pagerView, frame: CGRect(origin: CGPoint(), size: pagerSize))
            
            if transition.userData(MarkInputCollapsed.self) != nil {
                self.searchComponent = nil
            }
            
            if let searchComponent = self.searchComponent {
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
                            context: component.stickerContent.context,
                            theme: component.theme,
                            deviceMetrics: component.deviceMetrics
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
        
        private func openSearch() {
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
        
        private func scrollToItemGroup(contentId: String, groupId: AnyHashable) {
            if let pagerView = self.pagerView.findTaggedView(tag: EmojiPagerContentComponent.Tag(id: contentId)) as? EmojiPagerContentComponent.View {
                pagerView.scrollToItemGroup(groupId: groupId)
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
