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
    
    public let theme: PresentationTheme
    public let bottomInset: CGFloat
    public let emojiContent: EmojiPagerContentComponent
    public let stickerContent: EmojiPagerContentComponent
    public let gifContent: GifPagerContentComponent
    public let defaultToEmojiTab: Bool
    public let externalTopPanelContainer: UIView?
    public let topPanelExtensionUpdated: (CGFloat, Transition) -> Void
    public let hideInputUpdated: (Bool, Transition) -> Void
    public let makeSearchContainerNode: (EntitySearchContentType) -> EntitySearchContainerNode
    public let deviceMetrics: DeviceMetrics
    
    public init(
        theme: PresentationTheme,
        bottomInset: CGFloat,
        emojiContent: EmojiPagerContentComponent,
        stickerContent: EmojiPagerContentComponent,
        gifContent: GifPagerContentComponent,
        defaultToEmojiTab: Bool,
        externalTopPanelContainer: UIView?,
        topPanelExtensionUpdated: @escaping (CGFloat, Transition) -> Void,
        hideInputUpdated: @escaping (Bool, Transition) -> Void,
        makeSearchContainerNode: @escaping (EntitySearchContentType) -> EntitySearchContainerNode,
        deviceMetrics: DeviceMetrics
    ) {
        self.theme = theme
        self.bottomInset = bottomInset
        self.emojiContent = emojiContent
        self.stickerContent = stickerContent
        self.gifContent = gifContent
        self.defaultToEmojiTab = defaultToEmojiTab
        self.externalTopPanelContainer = externalTopPanelContainer
        self.topPanelExtensionUpdated = topPanelExtensionUpdated
        self.hideInputUpdated = hideInputUpdated
        self.makeSearchContainerNode = makeSearchContainerNode
        self.deviceMetrics = deviceMetrics
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
        if lhs.defaultToEmojiTab != rhs.defaultToEmojiTab {
            return false
        }
        if lhs.externalTopPanelContainer != rhs.externalTopPanelContainer {
            return false
        }
        if lhs.deviceMetrics != rhs.deviceMetrics {
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
        
        override init(frame: CGRect) {
            self.pagerView = ComponentHostView<EntityKeyboardChildEnvironment>()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
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
            topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                id: "recent",
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/RecentTabIcon",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: CGSize(width: 30.0, height: 30.0))
                )
            ))
            topGifItems.append(EntityKeyboardTopPanelComponent.Item(
                id: "trending",
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/TrendingGifs",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: CGSize(width: 30.0, height: 30.0))
                )
            ))
            contentTopPanels.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(EntityKeyboardTopPanelComponent(
                theme: component.theme,
                items: topGifItems,
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
                    if let iconName = iconMapping[id] {
                        topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                            id: itemGroup.id,
                            content: AnyComponent(Button(
                                content: AnyComponent(BundleIconComponent(
                                    name: iconName,
                                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                                    maxSize: CGSize(width: 30.0, height: 30.0)
                                )),
                                action: { [weak self] in
                                    self?.scrollToItemGroup(contentId: "stickers", groupId: itemGroup.id)
                                }
                            ).minSize(CGSize(width: 30.0, height: 30.0))
                            )
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
            contentAccessoryRightButtons.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(Button(
                content: AnyComponent(BundleIconComponent(
                    name: "Chat/Input/Media/EntityInputClearIcon",
                    tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                    maxSize: nil
                )),
                action: {
                    component.emojiContent.inputInteraction.deleteBackwards()
                }
            ).minSize(CGSize(width: 38.0, height: 38.0)))))
            
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
                        theme: component.theme
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
                    hidePanels: self.searchComponent != nil
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
                component.hideInputUpdated(true, Transition(animation: .curve(duration: 0.3, curve: .spring)))
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
            component.hideInputUpdated(false, Transition(animation: .curve(duration: 0.4, curve: .spring)))
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
