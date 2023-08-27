import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AccountContext
import MultilineTextComponent
import BlurredBackgroundComponent
import Markdown
import TelegramPresentationData
import BundleIconComponent
import AvatarNode
import AvatarStoryIndicatorComponent

private final class AvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer

    init(context: AccountContext, theme: PresentationTheme, peer: EnginePeer) {
        self.context = context
        self.theme = theme
        self.peer = peer
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        private let indicator = ComponentView<Empty>()
        
        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
            
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 78.0, height: 78.0)

            self.avatarNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - size.width) / 2.0), y: -22.0), size: size)
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer,
                synchronousLoad: true
            )
            
            let colors = [
                UIColor(rgb: 0xbb6de8),
                UIColor(rgb: 0x738cff),
                UIColor(rgb: 0x8f76ff)
            ]
            let indicatorSize = self.indicator.update(
                transition: .immediate,
                component: AnyComponent(
                    AvatarStoryIndicatorComponent(
                        hasUnseen: true,
                        hasUnseenCloseFriendsItems: false,
                        colors: AvatarStoryIndicatorComponent.Colors(unseenColors: colors, unseenCloseFriendsColors: colors, seenColors: colors),
                        activeLineWidth: 3.0,
                        inactiveLineWidth: 3.0,
                        counters: AvatarStoryIndicatorComponent.Counters(totalCount: 8, unseenCount: 8)
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 78.0, height: 78.0)
            )
            if let view = self.indicator.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - indicatorSize.width) / 2.0), y: -22.0), size: indicatorSize)
            }
            
            return CGSize(width: availableSize.width, height: 122.0)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ParagraphComponent: CombinedComponent {
    let title: String
    let titleColor: UIColor
    let text: String
    let textColor: UIColor
    let iconName: String
    let iconColor: UIColor
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        iconName: String,
        iconColor: UIColor
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.iconName = iconName
        self.iconColor = iconColor
    }
    
    static func ==(lhs: ParagraphComponent, rhs: ParagraphComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            
            let leftInset: CGFloat = 64.0
            let rightInset: CGFloat = 32.0
            let textSideInset: CGFloat = leftInset + 8.0
            let spacing: CGFloat = 5.0
            
            let textTopInset: CGFloat = 9.0
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.semibold(15.0),
                        textColor: component.titleColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = component.textColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: textColor),
                linkAttribute: { _ in
                    return nil
                }
            )
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: context.availableSize.height),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.iconColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
         
            context.add(title
                .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(icon
                .position(CGPoint(x: 47.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 25.0)
        }
    }
}

private final class StoriesListComponent: CombinedComponent {
    typealias EnvironmentType = (Empty, ScrollChildEnvironment)
    
    let context: AccountContext
    let theme: PresentationTheme
    let topInset: CGFloat
    let bottomInset: CGFloat
    
    init(context: AccountContext, theme: PresentationTheme, topInset: CGFloat, bottomInset: CGFloat) {
        self.context = context
        self.theme = theme
        self.topInset = topInset
        self.bottomInset = bottomInset
    }
    
    static func ==(lhs: StoriesListComponent, rhs: StoriesListComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.topInset != rhs.topInset {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        private var disposable: Disposable?
        var limits: EngineConfiguration.UserLimits = .defaultValue
        var premiumLimits: EngineConfiguration.UserLimits = .defaultValue
        
        var accountPeer: EnginePeer?
        
        init(context: AccountContext) {
            self.context = context
          
            super.init()
            
            self.disposable = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true),
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] limits, premiumLimits, accountPeer in
                if let strongSelf = self {
                    strongSelf.limits = limits
                    strongSelf.premiumLimits = premiumLimits
                    strongSelf.accountPeer = accountPeer
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context)
    }
    
    static var body: Body {
        let list = Child(List<Empty>.self)
        
        return { context in
            let theme = context.component.theme
            let strings = context.component.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let colors = [
                UIColor(rgb: 0x0275f3),
                UIColor(rgb: 0x8698ff),
                UIColor(rgb: 0xc871ff),
                UIColor(rgb: 0xc356ad),
                UIColor(rgb: 0xe85c44),
                UIColor(rgb: 0xff932b),
                UIColor(rgb: 0xe9af18)
            ]
            
            let titleColor = theme.list.itemPrimaryTextColor
            let textColor = theme.list.itemSecondaryTextColor
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            
            if let accountPeer = context.state.accountPeer {
                items.append(
                    AnyComponentWithIdentity(
                        id: "avatar",
                        component: AnyComponent(AvatarComponent(
                            context: context.component.context,
                            theme: theme,
                            peer: accountPeer
                        ))
                    )
                )
            }
            
            items.append(
                AnyComponentWithIdentity(
                    id: "order",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Stories_Order_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Stories_Order_Text,
                        textColor: textColor,
                        iconName: "Premium/Stories/Order",
                        iconColor: colors[0]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "stealth",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Stories_Stealth_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Stories_Stealth_Text,
                        textColor: textColor,
                        iconName: "Premium/Stories/Stealth",
                        iconColor: colors[1]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "views",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Stories_Views_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Stories_Views_Text,
                        textColor: textColor,
                        iconName: "Premium/Stories/Views",
                        iconColor: colors[2]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "expiration",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Stories_Expiration_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Stories_Expiration_Text,
                        textColor: textColor,
                        iconName: "Premium/Stories/Expire",
                        iconColor: colors[3]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "save",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Stories_Save_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Stories_Save_Text,
                        textColor: textColor,
                        iconName: "Premium/Stories/Save",
                        iconColor: colors[4]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "captions",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Stories_Captions_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Stories_Captions_Text,
                        textColor: textColor,
                        iconName: "Premium/Stories/Caption",
                        iconColor: colors[5]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "format",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Stories_Format_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Stories_Format_Text,
                        textColor: textColor,
                        iconName: "Premium/Stories/Format",
                        iconColor: colors[6]
                    ))
                )
            )
            
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: context.transition
            )
                        
            let contentHeight = context.component.topInset + list.size.height + context.component.bottomInset
            context.add(list
                .position(CGPoint(x: list.size.width / 2.0, y: context.component.topInset + list.size.height / 2.0))
            )
            
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

struct PageNeighbors: Equatable {
    var leftIsList: Bool
    var rightIsList: Bool
}

final class StoriesPageComponent: CombinedComponent {
    typealias EnvironmentType = DemoPageEnvironment
    
    let context: AccountContext
    let theme: PresentationTheme
    let neighbors: PageNeighbors
    let bottomInset: CGFloat
    let updatedBottomAlpha: (CGFloat) -> Void
    let updatedDismissOffset: (CGFloat) -> Void
    let updatedIsDisplaying: (Bool) -> Void

    init(context: AccountContext, theme: PresentationTheme, neighbors: PageNeighbors, bottomInset: CGFloat, updatedBottomAlpha: @escaping (CGFloat) -> Void, updatedDismissOffset: @escaping (CGFloat) -> Void, updatedIsDisplaying: @escaping (Bool) -> Void) {
        self.context = context
        self.theme = theme
        self.neighbors = neighbors
        self.bottomInset = bottomInset
        self.updatedBottomAlpha = updatedBottomAlpha
        self.updatedDismissOffset = updatedDismissOffset
        self.updatedIsDisplaying = updatedIsDisplaying
    }
    
    static func ==(lhs: StoriesPageComponent, rhs: StoriesPageComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.neighbors != rhs.neighbors {
            return false
        }
        if lhs.bottomInset != rhs.bottomInset {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let updateBottomAlpha: (CGFloat) -> Void
        let updateDismissOffset: (CGFloat) -> Void
        let updatedIsDisplaying: (Bool) -> Void
        
        var resetScroll: ActionSlot<Void>?
        
        var topContentOffset: CGFloat = 0.0
        var bottomContentOffset: CGFloat = 100.0 {
            didSet {
                self.updateAlpha()
            }
        }
        
        var position: CGFloat? {
            didSet {
                self.updateAlpha()
            }
        }
        
        var isDisplaying = false {
            didSet {
                if oldValue != self.isDisplaying {
                    self.updatedIsDisplaying(self.isDisplaying)
                    
                    if !self.isDisplaying {
                        self.resetScroll?.invoke(Void())
                    }
                }
            }
        }
        
        var neighbors = PageNeighbors(leftIsList: false, rightIsList: false)
        
        init(updateBottomAlpha: @escaping (CGFloat) -> Void, updateDismissOffset: @escaping (CGFloat) -> Void, updateIsDisplaying: @escaping (Bool) -> Void) {
            self.updateBottomAlpha = updateBottomAlpha
            self.updateDismissOffset = updateDismissOffset
            self.updatedIsDisplaying = updateIsDisplaying
            
            super.init()
        }
        
        func updateAlpha() {
            var dismissToLeft = false
            if let position = self.position, position > 0.0 {
                dismissToLeft = true
            }
            var dismissPosition = min(1.0, abs(self.position ?? 0.0) / 1.3333)
            var position = min(1.0, abs(self.position ?? 0.0))
            if position > 0.001, (dismissToLeft && self.neighbors.leftIsList) || (!dismissToLeft && self.neighbors.rightIsList) {
                dismissPosition = 0.0
                position = 1.0
            }
            self.updateDismissOffset(dismissPosition)
            
            let verticalPosition = 1.0 - min(30.0, self.bottomContentOffset) / 30.0
            
            let backgroundAlpha: CGFloat = max(position, verticalPosition)
            self.updateBottomAlpha(backgroundAlpha)
        }
    }
    
    func makeState() -> State {
        return State(updateBottomAlpha: self.updatedBottomAlpha, updateDismissOffset: self.updatedDismissOffset, updateIsDisplaying: self.updatedIsDisplaying)
    }
        
    static var body: Body {
        let background = Child(Rectangle.self)
        let scroll = Child(ScrollComponent<Empty>.self)
        let topPanel = Child(BlurredBackgroundComponent.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        let secondaryTitle = Child(MultilineTextComponent.self)
        
        let resetScroll = ActionSlot<Void>()
        
        return { context in
            let state = context.state
            
            let environment = context.environment[DemoPageEnvironment.self].value
            state.neighbors = context.component.neighbors
            state.resetScroll = resetScroll
            state.position = environment.position
            state.isDisplaying = environment.isDisplaying
            
            let theme = context.component.theme
            let strings = context.component.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let topInset: CGFloat = 56.0
            
            let scroll = scroll.update(
                component: ScrollComponent<Empty>(
                    content: AnyComponent(
                        StoriesListComponent(
                            context: context.component.context,
                            theme: theme,
                            topInset: topInset,
                            bottomInset: context.component.bottomInset + 110.0
                        )
                    ),
                    contentInsets: UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0),
                    contentOffsetUpdated: { [weak state] topContentOffset, bottomContentOffset in
                        state?.topContentOffset = topContentOffset
                        state?.bottomContentOffset = bottomContentOffset
                        Queue.mainQueue().justDispatch {
                            state?.updated(transition: .immediate)
                        }
                    },
                    contentOffsetWillCommit: { _ in },
                    resetScroll: resetScroll
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                        
            let background = background.update(
                component: Rectangle(color: theme.list.plainBackgroundColor),
                availableSize: scroll.size,
                transition: context.transition
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: background.size.height / 2.0))
            )
     
            context.add(scroll
                .position(CGPoint(x: context.availableSize.width / 2.0, y: scroll.size.height / 2.0))
            )
            
            let topPanel = topPanel.update(
                component: BlurredBackgroundComponent(
                    color: theme.rootController.navigationBar.blurredBackgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: topInset),
                transition: context.transition
            )
            
            let topSeparator = topSeparator.update(
                component: Rectangle(
                    color: theme.rootController.navigationBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.Premium_Stories_Title, font: Font.semibold(20.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let secondaryTitle = secondaryTitle.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: strings.Premium_Stories_AdditionalTitle, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                  
            let topPanelAlpha: CGFloat
            if state.topContentOffset > 78.0 {
                topPanelAlpha = min(30.0, state.topContentOffset - 78.0) / 30.0
            } else {
                topPanelAlpha = 0.0
            }
            context.add(topPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
                .opacity(topPanelAlpha)
            )
            context.add(topSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height))
                .opacity(topPanelAlpha)
            )
            
            let titleTopOriginY = topPanel.size.height / 2.0
            let titleBottomOriginY: CGFloat = 144.0
            let titleOriginDelta = titleTopOriginY - titleBottomOriginY
            
            let fraction = min(1.0, state.topContentOffset / abs(titleOriginDelta))
            let titleOriginY: CGFloat = titleBottomOriginY + fraction * titleOriginDelta
            let titleScale = 1.0 - max(0.0, fraction * 0.2)

            let titleAlpha: CGFloat
            if fraction > 0.78 {
                titleAlpha = max(0.0, 1.0 - (fraction - 0.78) / 0.16)
            } else {
                titleAlpha = 1.0
            }
            let secondaryTitleAlpha: CGFloat = 1.0 - titleAlpha
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY))
                .scale(titleScale)
                .opacity(titleAlpha)
            )
            
            context.add(secondaryTitle
                .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY))
                .opacity(secondaryTitleAlpha)
            )
                        
            return scroll.size
        }
    }
}
