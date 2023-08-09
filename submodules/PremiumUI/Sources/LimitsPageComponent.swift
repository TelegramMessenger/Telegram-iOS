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

private final class LimitComponent: CombinedComponent {
    let title: String
    let titleColor: UIColor
    let text: String
    let textColor: UIColor
    let accentColor: UIColor
    let inactiveColor: UIColor
    let inactiveTextColor: UIColor
    let inactiveTitle: String
    let inactiveValue: String
    let activeColor: UIColor
    let activeTextColor: UIColor
    let activeTitle: String
    let activeValue: String
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        accentColor: UIColor,
        inactiveColor: UIColor,
        inactiveTextColor: UIColor,
        inactiveTitle: String,
        inactiveValue: String,
        activeColor: UIColor,
        activeTextColor: UIColor,
        activeTitle: String,
        activeValue: String
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.accentColor = accentColor
        self.inactiveColor = inactiveColor
        self.inactiveTextColor = inactiveTextColor
        self.inactiveTitle = inactiveTitle
        self.inactiveValue = inactiveValue
        self.activeColor = activeColor
        self.activeTextColor = activeTextColor
        self.activeTitle = activeTitle
        self.activeValue = activeValue
    }
    
    static func ==(lhs: LimitComponent, rhs: LimitComponent) -> Bool {
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
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.inactiveColor != rhs.inactiveColor {
            return false
        }
        if lhs.inactiveTextColor != rhs.inactiveTextColor {
            return false
        }
        if lhs.inactiveTitle != rhs.inactiveTitle {
            return false
        }
        if lhs.inactiveValue != rhs.inactiveValue {
            return false
        }
        if lhs.activeColor != rhs.activeColor {
            return false
        }
        if lhs.activeTextColor != rhs.activeTextColor {
            return false
        }
        if lhs.activeTitle != rhs.activeTitle {
            return false
        }
        if lhs.activeValue != rhs.activeValue {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let limit = Child(PremiumLimitDisplayComponent.self)
        
        return { context in
            let component = context.component
            
            let sideInset: CGFloat = 16.0
            let textSideInset: CGFloat = sideInset + 8.0
            let spacing: CGFloat = 4.0
            
            let textTopInset: CGFloat = 9.0
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.regular(17.0),
                        textColor: component.titleColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(13.0)
            let boldTextFont = Font.semibold(13.0)
            let textColor = component.textColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: component.accentColor),
                linkAttribute: { _ in
                    return nil
                }
            )
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.0
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let limit = limit.update(
                component: PremiumLimitDisplayComponent(
                    inactiveColor: component.inactiveColor,
                    activeColors: [component.activeColor],
                    inactiveTitle: component.inactiveTitle,
                    inactiveValue: component.inactiveValue,
                    inactiveTitleColor: component.inactiveTextColor,
                    activeTitle: component.activeTitle,
                    activeValue: component.activeValue,
                    activeTitleColor: component.activeTextColor,
                    badgeIconName: "",
                    badgeText: nil,
                    badgePosition: 0.0,
                    badgeGraphPosition: 0.5,
                    isPremiumDisabled: false
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
         
            context.add(title
                .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(limit
                .position(CGPoint(x: context.availableSize.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height - 20.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 56.0)
        }
    }
}

private enum Limit: CaseIterable {
    case groups
    case pins
    case publicLinks
    case savedGifs
    case favedStickers
    case about
    case captions
    case folders
    case chatsPerFolder
    case account
    
    func title(strings: PresentationStrings) -> String {
        switch self {
            case .groups:
                return strings.Premium_Limits_GroupsAndChannels
            case .pins:
                return strings.Premium_Limits_PinnedChats
            case .publicLinks:
                return strings.Premium_Limits_PublicLinks
            case .savedGifs:
                return strings.Premium_Limits_SavedGifs
            case .favedStickers:
                return strings.Premium_Limits_FavedStickers
            case .about:
                return strings.Premium_Limits_Bio
            case .captions:
                return strings.Premium_Limits_Captions
            case .folders:
                return strings.Premium_Limits_Folders
            case .chatsPerFolder:
                return strings.Premium_Limits_ChatsPerFolder
            case .account:
                return strings.Premium_Limits_Accounts
        }
    }
    
    func text(strings: PresentationStrings) -> String {
        switch self {
            case .groups:
                return strings.Premium_Limits_GroupsAndChannelsInfo
            case .pins:
                return strings.Premium_Limits_PinnedChatsInfo
            case .publicLinks:
                return strings.Premium_Limits_PublicLinksInfo
            case .savedGifs:
                return strings.Premium_Limits_SavedGifsInfo
            case .favedStickers:
                return strings.Premium_Limits_FavedStickersInfo
            case .about:
                return strings.Premium_Limits_BioInfo
            case .captions:
                return strings.Premium_Limits_CaptionsInfo
            case .folders:
                return strings.Premium_Limits_FoldersInfo
            case .chatsPerFolder:
                return strings.Premium_Limits_ChatsPerFolderInfo
            case .account:
                return strings.Premium_Limits_AccountsInfo
        }
    }
    
    func limit(_ configuration: EngineConfiguration.UserLimits, isPremium: Bool) -> String {
        let value: Int32
        switch self {
            case .groups:
                value = configuration.maxChannelsCount
            case .pins:
                value = configuration.maxPinnedChatCount
            case .publicLinks:
                value = configuration.maxPublicLinksCount
            case .savedGifs:
                value = configuration.maxSavedGifCount
            case .favedStickers:
                value = configuration.maxFavedStickerCount
            case .about:
                value = configuration.maxAboutLength
            case .captions:
                value = configuration.maxCaptionLength
            case .folders:
                value = configuration.maxFoldersCount
            case .chatsPerFolder:
                value = configuration.maxFolderChatsCount
            case .account:
                value = isPremium ? 4 : 3
        }
        return "\(value)"
    }
}

private final class LimitsListComponent: CombinedComponent {
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
    
    static func ==(lhs: LimitsListComponent, rhs: LimitsListComponent) -> Bool {
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
        
        init(context: AccountContext) {
            self.context = context
          
            super.init()
            
            self.disposable = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            )
            |> deliverOnMainQueue).start(next: { [weak self] limits, premiumLimits in
                if let strongSelf = self {
                    strongSelf.limits = limits
                    strongSelf.premiumLimits = premiumLimits
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
            let state = context.state
            let theme = context.component.context.sharedContext.currentPresentationData.with { $0 }.theme
            let strings = context.component.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let colors = [
                UIColor(rgb: 0x5ba0ff),
                UIColor(rgb: 0x798aff),
                UIColor(rgb: 0x9377ff),
                UIColor(rgb: 0xac64f3),
                UIColor(rgb: 0xc456ae),
                UIColor(rgb: 0xcf579a),
                UIColor(rgb: 0xdb5887),
                UIColor(rgb: 0xdb496f),
                UIColor(rgb: 0xe95d44),
                UIColor(rgb: 0xf2822a)
            ]
            
            let items: [AnyComponentWithIdentity<Empty>] = Limit.allCases.enumerated().map { index, value in
                AnyComponentWithIdentity(
                    id: value, component: AnyComponent(
                        LimitComponent(
                            title: value.title(strings: strings),
                            titleColor: theme.list.itemPrimaryTextColor,
                            text: value.text(strings: strings),
                            textColor: theme.list.itemSecondaryTextColor,
                            accentColor: theme.list.itemAccentColor,
                            inactiveColor: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.5),
                            inactiveTextColor: theme.list.itemPrimaryTextColor,
                            inactiveTitle: strings.Premium_Free,
                            inactiveValue: value.limit(state.limits, isPremium: false),
                            activeColor: colors[index],
                            activeTextColor: .white,
                            activeTitle: strings.Premium_Premium,
                            activeValue: value.limit(state.premiumLimits, isPremium: true)
                        )
                    )
                )
            }
                                
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


final class LimitsPageComponent: CombinedComponent {
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
    
    static func ==(lhs: LimitsPageComponent, rhs: LimitsPageComponent) -> Bool {
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
                position = 0.0
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
                        LimitsListComponent(
                            context: context.component.context,
                            theme: context.component.theme,
                            topInset: topInset,
                            bottomInset: context.component.bottomInset
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
                    text: .plain(NSAttributedString(string: strings.Premium_DoubledLimits, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
                  
            let topPanelAlpha: CGFloat = min(30.0, state.topContentOffset) / 30.0
            context.add(topPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
                .opacity(topPanelAlpha)
            )
            context.add(topSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height))
                .opacity(topPanelAlpha)
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
            )
                        
            return scroll.size
        }
    }
}
