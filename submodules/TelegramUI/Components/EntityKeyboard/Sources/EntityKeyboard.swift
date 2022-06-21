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
    
    public init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    public static func ==(lhs: EntityKeyboardChildEnvironment, rhs: EntityKeyboardChildEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        
        return true
    }
}

public final class EntityKeyboardComponent: Component {
    public let theme: PresentationTheme
    public let bottomInset: CGFloat
    public let emojiContent: EmojiPagerContentComponent
    public let stickerContent: EmojiPagerContentComponent
    public let gifContent: GifPagerContentComponent
    public let externalTopPanelContainer: UIView?
    public let topPanelExtensionUpdated: (CGFloat, Transition) -> Void
    
    public init(
        theme: PresentationTheme,
        bottomInset: CGFloat,
        emojiContent: EmojiPagerContentComponent,
        stickerContent: EmojiPagerContentComponent,
        gifContent: GifPagerContentComponent,
        externalTopPanelContainer: UIView?,
        topPanelExtensionUpdated: @escaping (CGFloat, Transition) -> Void
    ) {
        self.theme = theme
        self.bottomInset = bottomInset
        self.emojiContent = emojiContent
        self.stickerContent = stickerContent
        self.gifContent = gifContent
        self.externalTopPanelContainer = externalTopPanelContainer
        self.topPanelExtensionUpdated = topPanelExtensionUpdated
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
        if lhs.externalTopPanelContainer != rhs.externalTopPanelContainer {
            return false
        }
        
        return true
    }
    
    public final class View: UIView {
        private let pagerView: ComponentHostView<EntityKeyboardChildEnvironment>
        
        private var component: EntityKeyboardComponent?
        
        override init(frame: CGRect) {
            self.pagerView = ComponentHostView<EntityKeyboardChildEnvironment>()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            
            self.addSubview(self.pagerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: EntityKeyboardComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            var contents: [AnyComponentWithIdentity<(EntityKeyboardChildEnvironment, PagerComponentChildEnvironment)>] = []
            var contentTopPanels: [AnyComponentWithIdentity<Empty>] = []
            var contentIcons: [AnyComponentWithIdentity<Empty>] = []
            var contentAccessoryRightButtons: [AnyComponentWithIdentity<Empty>] = []
            
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
                items: topGifItems
            ))))
            contentIcons.append(AnyComponentWithIdentity(id: "gifs", component: AnyComponent(BundleIconComponent(
                name: "Chat/Input/Media/EntityInputGifsIcon",
                tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                maxSize: nil
            ))))
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
                            id: id,
                            content: AnyComponent(BundleIconComponent(
                                name: iconName,
                                tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                                maxSize: CGSize(width: 30.0, height: 30.0))
                            )
                        ))
                    }
                } else {
                    if !itemGroup.items.isEmpty {
                        topStickerItems.append(EntityKeyboardTopPanelComponent.Item(
                            id: AnyHashable(itemGroup.items[0].file.fileId),
                            content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                                context: component.stickerContent.context,
                                file: itemGroup.items[0].file,
                                animationCache: component.stickerContent.animationCache,
                                animationRenderer: component.stickerContent.animationRenderer
                            ))
                        ))
                    }
                }
            }
            contents.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(component.stickerContent)))
            contentTopPanels.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(EntityKeyboardTopPanelComponent(
                theme: component.theme,
                items: topStickerItems
            ))))
            contentIcons.append(AnyComponentWithIdentity(id: "stickers", component: AnyComponent(BundleIconComponent(
                name: "Chat/Input/Media/EntityInputStickersIcon",
                tintColor: component.theme.chat.inputMediaPanel.panelIconColor,
                maxSize: nil
            ))))
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
            
            contents.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(component.emojiContent)))
            var topEmojiItems: [EntityKeyboardTopPanelComponent.Item] = []
            for itemGroup in component.emojiContent.itemGroups {
                if !itemGroup.items.isEmpty {
                    topEmojiItems.append(EntityKeyboardTopPanelComponent.Item(
                        id: AnyHashable(itemGroup.items[0].file.fileId),
                        content: AnyComponent(EntityKeyboardAnimationTopPanelComponent(
                            context: component.emojiContent.context,
                            file: itemGroup.items[0].file,
                            animationCache: component.emojiContent.animationCache,
                            animationRenderer: component.emojiContent.animationRenderer
                        ))
                    ))
                }
            }
            contentTopPanels.append(AnyComponentWithIdentity(id: "emoji", component: AnyComponent(EntityKeyboardTopPanelComponent(
                theme: component.theme,
                items: topEmojiItems
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
                    contentAccessoryRightButtons: contentAccessoryRightButtons,
                    defaultId: "emoji",
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
                    panelStateUpdated: { panelState, transition in
                        component.topPanelExtensionUpdated(panelState.topPanelHeight, transition)
                    }
                )),
                environment: {
                    EntityKeyboardChildEnvironment(theme: component.theme)
                },
                containerSize: availableSize
            )
            transition.setFrame(view: self.pagerView, frame: CGRect(origin: CGPoint(), size: pagerSize))
            
            self.component = component
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
