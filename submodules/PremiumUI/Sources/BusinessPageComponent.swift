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
import ScrollComponent

private final class HeaderComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        self.strings = strings
    }

    static func ==(lhs: HeaderComponent, rhs: HeaderComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: UIView {
        private let coin = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
        
        private var component: HeaderComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: HeaderComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            let containerSize = CGSize(width: min(414.0, availableSize.width), height: 220.0)
            
            let coinSize = self.coin.update(
                transition: .immediate,
                component: AnyComponent(PremiumCoinComponent(isIntro: true, isVisible: true, hasIdleAnimations: true)),
                environment: {},
                containerSize: containerSize
            )
            if let view = self.coin.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - coinSize.width) / 2.0), y: -84.0), size: coinSize)
            }
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.Premium_Business_Description, font: Font.regular(15.0), textColor: component.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 1000.0)
            )
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - textSize.width) / 2.0), y: 139.0), size: textSize)
            }
            
            return CGSize(width: availableSize.width, height: 210.0)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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

private final class BusinessListComponent: CombinedComponent {
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
    
    static func ==(lhs: BusinessListComponent, rhs: BusinessListComponent) -> Bool {
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
                UIColor(rgb: 0xef6922),
                UIColor(rgb: 0xe54937),
                UIColor(rgb: 0xdb374b),
                UIColor(rgb: 0xbc4395),
                UIColor(rgb: 0x9b4fed),
                UIColor(rgb: 0x8958ff),
                UIColor(rgb: 0x676bff),
                UIColor(rgb: 0x007aff)
            ]
            
            let titleColor = theme.list.itemPrimaryTextColor
            let textColor = theme.list.itemSecondaryTextColor
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            
            items.append(
                AnyComponentWithIdentity(
                    id: "header",
                    component: AnyComponent(HeaderComponent(
                        context: context.component.context,
                        theme: theme,
                        strings: strings
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "location",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Location_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Location_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Location",
                        iconColor: colors[0]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "hours",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Hours_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Hours_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Hours",
                        iconColor: colors[1]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "replies",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Replies_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Replies_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Replies",
                        iconColor: colors[2]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "greetings",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Greetings_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Greetings_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Greetings",
                        iconColor: colors[3]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "away",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Away_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Away_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Away",
                        iconColor: colors[4]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "links",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Links_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Links_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Links",
                        iconColor: colors[5]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "intro",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Intro_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Intro_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Intro",
                        iconColor: colors[6]
                    ))
                )
            )
            
            items.append(
                AnyComponentWithIdentity(
                    id: "chatbots",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.Premium_Business_Chatbots_Title,
                        titleColor: titleColor,
                        text: strings.Premium_Business_Chatbots_Text,
                        textColor: textColor,
                        iconName: "Premium/Business/Chatbots",
                        iconColor: colors[7]
                    ))
                )
            )
            
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: context.transition
            )
                        
            let contentHeight = context.component.topInset - 56.0 + list.size.height + context.component.bottomInset
            context.add(list
                .position(CGPoint(x: list.size.width / 2.0, y: context.component.topInset + list.size.height / 2.0))
            )
            
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

final class BusinessPageComponent: CombinedComponent {
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
    
    static func ==(lhs: BusinessPageComponent, rhs: BusinessPageComponent) -> Bool {
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
        
        var resetScroll: ActionSlot<CGPoint?>?
        
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
                        self.resetScroll?.invoke(nil)
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
        
        let resetScroll = ActionSlot<CGPoint?>()
        
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
                        BusinessListComponent(
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
                component: Rectangle(color: theme.overallDarkAppearance ? theme.list.blocksBackgroundColor : theme.list.plainBackgroundColor),
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
                    text: .plain(NSAttributedString(string: strings.Premium_Business, font: Font.semibold(20.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
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
            let titleBottomOriginY: CGFloat = 176.0
            let titleOriginDelta = titleTopOriginY - titleBottomOriginY
            
            let fraction = min(1.0, state.topContentOffset / abs(titleOriginDelta))
            let titleOriginY: CGFloat = titleBottomOriginY + fraction * titleOriginDelta
            let titleScale = 1.0 - max(0.0, fraction * 0.2)

            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY))
                .scale(titleScale)
            )
                        
            return scroll.size
        }
    }
}
