import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import Markdown
import SolidRoundedButtonNode

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
    let topInset: CGFloat
    let bottomInset: CGFloat
    
    init(context: AccountContext, topInset: CGFloat, bottomInset: CGFloat) {
        self.context = context
        self.topInset = topInset
        self.bottomInset = bottomInset
    }
    
    static func ==(lhs: LimitsListComponent, rhs: LimitsListComponent) -> Bool {
        if lhs.context !== rhs.context {
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

private final class LimitsPageComponent: CombinedComponent {
    typealias EnvironmentType = DemoPageEnvironment
    
    let context: AccountContext
    let bottomInset: CGFloat
    let updatedBottomAlpha: (CGFloat) -> Void
    let updatedDismissOffset: (CGFloat) -> Void
    let updatedIsDisplaying: (Bool) -> Void

    init(context: AccountContext, bottomInset: CGFloat, updatedBottomAlpha: @escaping (CGFloat) -> Void, updatedDismissOffset: @escaping (CGFloat) -> Void, updatedIsDisplaying: @escaping (Bool) -> Void) {
        self.context = context
        self.bottomInset = bottomInset
        self.updatedBottomAlpha = updatedBottomAlpha
        self.updatedDismissOffset = updatedDismissOffset
        self.updatedIsDisplaying = updatedIsDisplaying
    }
    
    static func ==(lhs: LimitsPageComponent, rhs: LimitsPageComponent) -> Bool {
        if lhs.context !== rhs.context {
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
        
        init(updateBottomAlpha: @escaping (CGFloat) -> Void, updateDismissOffset: @escaping (CGFloat) -> Void, updateIsDisplaying: @escaping (Bool) -> Void) {
            self.updateBottomAlpha = updateBottomAlpha
            self.updateDismissOffset = updateDismissOffset
            self.updatedIsDisplaying = updateIsDisplaying
            
            super.init()
        }
        
        func updateAlpha() {
            let dismissPosition = min(1.0, abs(self.position ?? 0.0) / 1.3333)
            let position = min(1.0, abs(self.position ?? 0.0))
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
        let topPanel = Child(BlurredRectangle.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(MultilineTextComponent.self)
        
        let resetScroll = ActionSlot<Void>()
        
        return { context in
            let state = context.state
            
            let environment = context.environment[DemoPageEnvironment.self].value
            state.resetScroll = resetScroll
            state.position = environment.position
            state.isDisplaying = environment.isDisplaying
            
            let theme = context.component.context.sharedContext.currentPresentationData.with { $0 }.theme
            let strings = context.component.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let topInset: CGFloat = 56.0
            
            let scroll = scroll.update(
                component: ScrollComponent<Empty>(
                    content: AnyComponent(
                        LimitsListComponent(
                            context: context.component.context,
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
                component: BlurredRectangle(
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

public class PremiumLimitsListScreen: ViewController {
    final class Node: ViewControllerTracingNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: PremiumLimitsListScreen?
                
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        
        let backgroundView: ComponentHostView<Empty>
        let pagerView: ComponentHostView<Empty>
        let closeView: ComponentHostView<Empty>
        
        fileprivate let footerNode: FooterNode
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: ContainerViewLayout?
                
        var isPremium: Bool?
        var reactions: [AvailableReactions.Reaction]?
        var stickers: [TelegramMediaFile]?
        var appIcons: [PresentationAppIcon]?
        var disposable: Disposable?
        var promoConfiguration: PremiumPromoConfiguration?
        
        init(context: AccountContext, controller: PremiumLimitsListScreen, buttonTitle: String, gloss: Bool) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
//            self.scrollView = UIScrollView()
            self.backgroundView = ComponentHostView()
            self.pagerView = ComponentHostView()
            self.closeView = ComponentHostView()
            
            self.footerNode = FooterNode(theme: self.presentationData.theme, title: buttonTitle, gloss: gloss)
            
            super.init()
            
//            self.scrollView.delegate = self
//            self.scrollView.showsVerticalScrollIndicator = false
            
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.backgroundView)
            self.containerView.addSubview(self.pagerView)
            self.containerView.addSubnode(self.footerNode)
            self.containerView.addSubview(self.closeView)
//            self.scrollView.addSubview(self.hostView)
            
            self.footerNode.action = { [weak self] in
                self?.controller?.action()
            }
            
            let context = controller.context
            
            let accountSpecificStickerOverrides: [ExperimentalUISettings.AccountReactionOverrides.Item]
            if context.sharedContext.immediateExperimentalUISettings.enableReactionOverrides, let value = context.sharedContext.immediateExperimentalUISettings.accountStickerEffectOverrides.first(where: { $0.accountId == context.account.id.int64 }) {
                accountSpecificStickerOverrides = value.items
            } else {
                accountSpecificStickerOverrides = []
            }
            let stickerOverrideMessages = context.engine.data.get(
                EngineDataMap(accountSpecificStickerOverrides.map(\.messageId).map(TelegramEngine.EngineData.Item.Messages.Message.init))
            )
            
            self.appIcons = controller.context.sharedContext.applicationBindings.getAvailableAlternateIcons()
            
            let stickersKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudPremiumStickers)
            self.disposable = (combineLatest(
                queue: Queue.mainQueue(),
                context.account.postbox.combinedView(keys: [stickersKey])
                |> map { views -> [OrderedItemListEntry]? in
                    if let view = views.views[stickersKey] as? OrderedItemListView {
                        return view.items
                    } else {
                        return nil
                    }
                }
                |> filter { items in
                    return items != nil
                }
                |> take(1),
                context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                    TelegramEngine.EngineData.Item.Configuration.PremiumPromo()
                ),
                stickerOverrideMessages
            )
            |> map { items, data, stickerOverrideMessages -> ([TelegramMediaFile], Bool?, PremiumPromoConfiguration?) in
                var stickerOverrides: [MessageReaction.Reaction: TelegramMediaFile] = [:]
                for item in accountSpecificStickerOverrides {
                    if let maybeMessage = stickerOverrideMessages[item.messageId], let message = maybeMessage {
                        for media in message.media {
                            if let file = media as? TelegramMediaFile, file.fileId == item.mediaId {
                                stickerOverrides[item.key] = file
                            }
                        }
                    }
                }
                
                var result: [TelegramMediaFile] = []
                if let items = items {
                    for item in items {
                        if let mediaItem = item.contents.get(RecentMediaItem.self) {
                            result.append(mediaItem.media)
                        }
                    }
                }
                return (result.map { file -> TelegramMediaFile in
                    for attribute in file.attributes {
                        switch attribute {
                        case let .Sticker(displayText, _, _):
                            if let replacementFile = stickerOverrides[.builtin(displayText)], let dimensions = replacementFile.dimensions {
                                let _ = dimensions
                                return TelegramMediaFile(
                                    fileId: file.fileId,
                                    partialReference: file.partialReference,
                                    resource: file.resource,
                                    previewRepresentations: file.previewRepresentations,
                                    videoThumbnails: [TelegramMediaFile.VideoThumbnail(dimensions: dimensions, resource: replacementFile.resource)],
                                    immediateThumbnailData: file.immediateThumbnailData,
                                    mimeType: file.mimeType,
                                    size: file.size,
                                    attributes: file.attributes
                                )
                            }
                        default:
                            break
                        }
                    }
                    return file
                }, data.0?.isPremium ?? false, data.1)
            }).start(next: { [weak self] stickers, isPremium, promoConfiguration in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.stickers = stickers
                strongSelf.isPremium = isPremium
                strongSelf.promoConfiguration = promoConfiguration
                if !stickers.isEmpty {
                    strongSelf.updated(transition: Transition(.immediate).withUserData(DemoAnimateInTransition()))
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delegate = self
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = true
            self.panGestureRecognizer = panRecognizer
            self.wrappingView.addGestureRecognizer(panRecognizer)
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.controller?.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let layout = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                if let scrollView = otherGestureRecognizer.view as? UIScrollView {
                    if scrollView.contentSize.width > scrollView.contentSize.height || scrollView.contentSize.height > 1500.0 {
                        return false
                    }
                }
                return true
            }
            return false
        }
        
        private var isDismissing = false
        func animateIn() {
            ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear).updateAlpha(node: self.dim, alpha: 1.0)
            
            let targetPosition = self.containerView.center
            let startPosition = targetPosition.offsetBy(dx: 0.0, dy: self.bounds.height)
            
            self.containerView.center = startPosition
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.animateView(allowUserInteraction: true, {
                self.containerView.center = targetPosition
            }, completion: { _ in
            })
        }
        
        func animateOut(completion: @escaping () -> Void = {}) {
            self.isDismissing = true
            
            let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            positionTransition.updatePosition(layer: self.containerView.layer, position: CGPoint(x: self.containerView.center.x, y: self.bounds.height + self.containerView.bounds.height / 2.0), completion: { [weak self] _ in
                self?.controller?.dismiss(animated: false, completion: completion)
            })
            let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
        }
                
        private var dismissOffset: CGFloat?
        func containerLayoutUpdated(layout: ContainerViewLayout, transition: Transition) {
            self.currentLayout = layout
            
            self.dim.frame = CGRect(origin: CGPoint(x: 0.0, y: -layout.size.height), size: CGSize(width: layout.size.width, height: layout.size.height * 3.0))
                        
            var effectiveExpanded = self.isExpanded
            if case .regular = layout.metrics.widthClass {
                effectiveExpanded = true
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : self.defaultTopInset
            let topInset: CGFloat
            if let (panInitialTopInset, panOffset, _, _) = self.panGestureArguments {
                if effectiveExpanded {
                    topInset = min(edgeTopInset, panInitialTopInset + max(0.0, panOffset))
                } else {
                    topInset = max(0.0, panInitialTopInset + min(0.0, panOffset))
                }
            } else if let dismissOffset = self.dismissOffset {
                topInset = edgeTopInset * dismissOffset
            } else {
                topInset = effectiveExpanded ? 0.0 : edgeTopInset
            }
            transition.setFrame(view: self.wrappingView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: layout.size), completion: nil)
            
            let modalProgress = isLandscape ? 0.0 : (1.0 - topInset / self.defaultTopInset)
            self.controller?.updateModalStyleOverlayTransitionFactor(modalProgress, transition: transition.containedViewLayoutTransition)
            
            let clipFrame: CGRect
            if layout.metrics.widthClass == .compact {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.25)
                if isLandscape {
                    self.containerView.layer.cornerRadius = 0.0
                } else {
                    self.containerView.layer.cornerRadius = 10.0
                }
                
                if #available(iOS 11.0, *) {
                    if layout.safeInsets.bottom.isZero {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    } else {
                        self.containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    }
                }
                
                if isLandscape {
                    clipFrame = CGRect(origin: CGPoint(), size: layout.size)
                } else {
                    let coveredByModalTransition: CGFloat = 0.0
                    var containerTopInset: CGFloat = 10.0
                    if let statusBarHeight = layout.statusBarHeight {
                        containerTopInset += statusBarHeight
                    }
                                        
                    let unscaledFrame = CGRect(origin: CGPoint(x: 0.0, y: containerTopInset - coveredByModalTransition * 10.0), size: CGSize(width: layout.size.width, height: layout.size.height - containerTopInset))
                    let maxScale: CGFloat = (layout.size.width - 16.0 * 2.0) / layout.size.width
                    let containerScale = 1.0 * (1.0 - coveredByModalTransition) + maxScale * coveredByModalTransition
                    let maxScaledTopInset: CGFloat = containerTopInset - 10.0
                    let scaledTopInset: CGFloat = containerTopInset * (1.0 - coveredByModalTransition) + maxScaledTopInset * coveredByModalTransition
                    let containerFrame = unscaledFrame.offsetBy(dx: 0.0, dy: scaledTopInset - (unscaledFrame.midY - containerScale * unscaledFrame.height / 2.0))
                    
                    clipFrame = CGRect(x: containerFrame.minX, y: containerFrame.minY, width: containerFrame.width, height: containerFrame.height)
                }
            } else {
                self.dim.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
                self.containerView.layer.cornerRadius = 10.0
                
                let verticalInset: CGFloat = 44.0
                
                let maxSide = max(layout.size.width, layout.size.height)
                let minSide = min(layout.size.width, layout.size.height)
                let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
                clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            }
            
            transition.setFrame(view: self.containerView, frame: clipFrame)
//            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: clipFrame.size), completion: nil)
            
            var clipLayout = layout.withUpdatedSize(clipFrame.size)
            if case .regular = layout.metrics.widthClass {
                clipLayout = clipLayout.withUpdatedIntrinsicInsets(.zero)
            }
            let footerHeight = self.footerNode.updateLayout(layout: clipLayout, transition: .immediate)
            
            let convertedFooterFrame = self.view.convert(CGRect(origin: CGPoint(x: clipFrame.minX, y: clipFrame.maxY - footerHeight), size: CGSize(width: clipFrame.width, height: footerHeight)), to: self.containerView)
            transition.setFrame(view: self.footerNode.view, frame: convertedFooterFrame)
            
            self.updated(transition: transition)
        }
        
        func updated(transition: Transition) {
            guard let controller = self.controller, let layout = self.currentLayout else {
                return
            }
            
            let backgroundSize = self.backgroundView.update(
                transition: .immediate,
                component: AnyComponent(
                    GradientBackgroundComponent(colors: [
                        UIColor(rgb: 0x0077ff),
                        UIColor(rgb: 0x6b93ff),
                        UIColor(rgb: 0x8878ff),
                        UIColor(rgb: 0xe46ace)
                    ])
                ),
                environment: {},
                containerSize: CGSize(width: layout.size.width, height: layout.size.width)
            )
            self.backgroundView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
            
            var isStandalone = false
            if case .other = controller.source {
                isStandalone = true
            }
            
            if let stickers = self.stickers, let appIcons = self.appIcons, let configuration = self.promoConfiguration {
                let context = controller.context
                let theme = self.presentationData.theme
                let strings = self.presentationData.strings
                                
                let textColor = theme.actionSheet.primaryTextColor
                
                var availableItems: [PremiumPerk: DemoPagerComponent.Item] = [:]
                availableItems[.doubleLimits] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.doubleLimits,
                        component: AnyComponent(
                            LimitsPageComponent(
                                context: context,
                                bottomInset: self.footerNode.frame.height,
                                updatedBottomAlpha: { [weak self] alpha in
                                    if let strongSelf = self {
                                        strongSelf.footerNode.updateCoverAlpha(alpha, transition: .immediate)
                                    }
                                },
                                updatedDismissOffset: { [weak self] offset in
                                    if let strongSelf = self {
                                        strongSelf.updateDismissOffset(offset)
                                    }
                                },
                                updatedIsDisplaying: { [weak self] isDisplaying in
                                    if let strongSelf = self, strongSelf.isExpanded && !isDisplaying {
                                        strongSelf.update(isExpanded: false, transition: .animated(duration: 0.2, curve: .easeInOut))
                                    }
                                }
                            )
                        )
                    )
                )
                availableItems[.moreUpload] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.moreUpload,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .bottom,
                                    videoFile: configuration.videos["more_upload"],
                                    decoration: .dataRain
                                )),
                                title: strings.Premium_UploadSize,
                                text: strings.Premium_UploadSizeInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.fasterDownload] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.fasterDownload,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: configuration.videos["faster_download"],
                                    decoration: .fasterStars
                                )),
                                title: strings.Premium_FasterSpeed,
                                text: strings.Premium_FasterSpeedInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.voiceToText] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.voiceToText,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: configuration.videos["voice_to_text"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_VoiceToText,
                                text: strings.Premium_VoiceToTextInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.noAds] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.noAds,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .bottom,
                                    videoFile: configuration.videos["no_ads"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_NoAds,
                                text: isStandalone ? strings.Premium_NoAdsStandaloneInfo : strings.Premium_NoAdsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.uniqueReactions] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.uniqueReactions,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: configuration.videos["infinite_reactions"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_InfiniteReactions,
                                text: strings.Premium_InfiniteReactionsInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.premiumStickers] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.premiumStickers,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(
                                    StickersCarouselComponent(
                                        context: context,
                                        stickers: stickers
                                    )
                                ),
                                title: strings.Premium_Stickers,
                                text: strings.Premium_StickersInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.emojiStatus] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.emojiStatus,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: configuration.videos["emoji_status"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_EmojiStatus,
                                text: strings.Premium_EmojiStatusInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.advancedChatManagement] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.advancedChatManagement,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: configuration.videos["advanced_chat_management"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_ChatManagement,
                                text: strings.Premium_ChatManagementInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.profileBadge] =  DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.profileBadge,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: configuration.videos["profile_badge"],
                                    decoration: .badgeStars
                                )),
                                title: strings.Premium_Badge,
                                text: strings.Premium_BadgeInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.animatedUserpics] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.animatedUserpics,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .top,
                                    videoFile: configuration.videos["animated_userpics"],
                                    decoration: .swirlStars
                                )),
                                title: strings.Premium_Avatar,
                                text: strings.Premium_AvatarInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                availableItems[.appIcons] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.appIcons,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(AppIconsDemoComponent(
                                    context: context,
                                    appIcons: appIcons
                                )),
                                title: isStandalone ? strings.Premium_AppIconStandalone : strings.Premium_AppIcon,
                                text: isStandalone ? strings.Premium_AppIconStandaloneInfo :strings.Premium_AppIconInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                
                availableItems[.animatedEmoji] = DemoPagerComponent.Item(
                    AnyComponentWithIdentity(
                        id: PremiumDemoScreen.Subject.animatedEmoji,
                        component: AnyComponent(
                            PageComponent(
                                content: AnyComponent(PhoneDemoComponent(
                                    context: context,
                                    position: .bottom,
                                    videoFile: configuration.videos["animated_emoji"],
                                    decoration: .emoji
                                )),
                                title: strings.Premium_AnimatedEmoji,
                                text: isStandalone ? strings.Premium_AnimatedEmojiStandaloneInfo : strings.Premium_AnimatedEmojiInfo,
                                textColor: textColor
                            )
                        )
                    )
                )
                
                if let order = controller.order {
                    var items: [DemoPagerComponent.Item] = order.compactMap { availableItems[$0] }
                    let index: Int
                    switch controller.source {
                    case .intro, .gift:
                        index = items.firstIndex(where: { (controller.subject as AnyHashable) == $0.content.id }) ?? 0
                    case .other:
                        items = items.filter { item in
                            return item.content.id == (controller.subject as AnyHashable)
                        }
                        index = 0
                    }
                    
                    let pagerSize = self.pagerView.update(
                        transition: .immediate,
                        component: AnyComponent(
                            DemoPagerComponent(
                                items: items,
                                index: index,
                                updated: { [weak self] position, count in
                                    if let strongSelf = self {
                                        strongSelf.footerNode.updatePosition(position, count: count)
                                    }
                                }
                            )
                        ),
                        environment: {},
                        containerSize: CGSize(width: layout.size.width, height: self.containerView.frame.height)
                    )
                    self.pagerView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - pagerSize.width) / 2.0), y: 0.0), size: pagerSize)
                }
            }
            
            let closeImage: UIImage
            if let image = self.cachedCloseImage {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff))!
                self.cachedCloseImage = closeImage
            }
                  
            
            let closeSize = self.closeView.update(
                transition: .immediate,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(ZStack([
                            AnyComponentWithIdentity(
                                id: "background",
                                component: AnyComponent(
                                    BlurredRectangle(
                                        color:  UIColor(rgb: 0x888888, alpha: 0.3),
                                        radius: 15.0
                                    )
                                )
                            ),
                            AnyComponentWithIdentity(
                                id: "icon",
                                component: AnyComponent(
                                    Image(image: closeImage)
                                )
                            ),
                        ])),
                        action: { [weak self] in
                            self?.controller?.dismiss(animated: true, completion: nil)
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            self.closeView.frame = CGRect(origin: CGPoint(x: layout.size.width - closeSize.width * 1.5, y: 28.0 - closeSize.height / 2.0), size: closeSize)
        }
        private var cachedCloseImage: UIImage?
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var defaultTopInset: CGFloat {
            guard let layout = self.currentLayout else {
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                let bottomPanelPadding: CGFloat = 12.0
                let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                let panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset + 28.0
                
                return layout.size.height - layout.size.width - 178.0 - panelHeight
            } else {
                return 210.0
            }
        }
        
        private func findVerticalScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? UIScrollView, view.contentSize.height > view.contentSize.width && view.contentSize.height < 1500.0 {
                    return (view, nil)
                }
                if let node = view.asyncdisplaykit_node as? ListView {
                    return (node.scroller, node)
                }
                return findVerticalScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let layout = self.currentLayout else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollViewAndListNode = self.findVerticalScrollView(view: currentHitView)
                    if scrollViewAndListNode?.0.frame.height == self.frame.width {
                        scrollViewAndListNode = nil
                    }
                    let scrollView = scrollViewAndListNode?.0
                    let listNode = scrollViewAndListNode?.1
                                
                    let topInset: CGFloat
                    if self.isExpanded {
                        topInset = 0.0
                    } else {
                        topInset = edgeTopInset
                    }
                
                    self.panGestureArguments = (topInset, 0.0, scrollView, listNode)
                case .changed:
                    guard let (topInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    var translation = recognizer.translation(in: self.view).y

                    var currentOffset = topInset + translation
                
                    let epsilon = 1.0
                    if case let .known(value) = visibleContentOffset, value <= epsilon {
                        if let scrollView = scrollView {
                            scrollView.bounces = false
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
                        }
                    } else if let scrollView = scrollView, contentOffset <= -scrollView.contentInset.top + epsilon {
                        scrollView.bounces = false
                        scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                    } else if let scrollView = scrollView {
                        translation = panOffset
                        currentOffset = topInset + translation
                        if self.isExpanded {
                            recognizer.setTranslation(CGPoint(), in: self.view)
                        } else if currentOffset > 0.0 {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                    }
                
                    if scrollView == nil {
                        translation = max(0.0, translation)
                    }
                    
                    self.panGestureArguments = (topInset, translation, scrollView, listNode)
                    
                    if !self.isExpanded {
                        if currentOffset > 0.0, let scrollView = scrollView {
                            scrollView.panGestureRecognizer.setTranslation(CGPoint(), in: scrollView)
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                    self.bounds = bounds
                
                    self.containerLayoutUpdated(layout: layout, transition: .immediate)
                case .ended:
                    guard let (currentTopInset, panOffset, scrollView, listNode) = self.panGestureArguments else {
                        return
                    }
                    self.panGestureArguments = nil
                
                    let visibleContentOffset = listNode?.visibleContentOffset()
                    let contentOffset = scrollView?.contentOffset.y ?? 0.0
                
                    let translation = recognizer.translation(in: self.view).y
                    var velocity = recognizer.velocity(in: self.view)
                    
                    if self.isExpanded {
                        if case let .known(value) = visibleContentOffset, value > 0.1 {
                            velocity = CGPoint()
                        } else if case .unknown = visibleContentOffset {
                            velocity = CGPoint()
                        } else if contentOffset > 0.1 {
                            velocity = CGPoint()
                        }
                    }
                
                    var bounds = self.bounds
                    if self.isExpanded {
                        bounds.origin.y = -max(0.0, translation - edgeTopInset)
                    } else {
                        bounds.origin.y = -translation
                    }
                    bounds.origin.y = min(0.0, bounds.origin.y)
                
                    scrollView?.bounces = true
                
                    let offset = currentTopInset + panOffset
                    let topInset: CGFloat = edgeTopInset

                    var dismissing = false
                    if bounds.minY < -60 || (bounds.minY < 0.0 && velocity.y > 300.0) || (self.isExpanded && bounds.minY.isZero && velocity.y > 1800.0) {
                        self.controller?.dismiss(animated: true, completion: nil)
                        dismissing = true
                    } else if self.isExpanded {
                        if velocity.y > 300.0 || offset > topInset / 2.0 {
                            self.isExpanded = false
                            if let listNode = listNode {
                                listNode.scroller.setContentOffset(CGPoint(), animated: false)
                            } else if let scrollView = scrollView {
                                scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                            }
                            
                            let distance = topInset - offset
                            let initialVelocity: CGFloat = distance.isZero ? 0.0 : abs(velocity.y / distance)
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))

                            self.containerLayoutUpdated(layout: layout, transition: Transition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if scrollView != nil, (velocity.y < -300.0 || offset < topInset / 2.0) {
                        if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                            DispatchQueue.main.async {
                                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            }
                        }
                                                    
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, transition: Transition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                    }
                    
                    if !dismissing {
                        var bounds = self.bounds
                        let previousBounds = bounds
                        bounds.origin.y = 0.0
                        self.bounds = bounds
                        self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    }
                case .cancelled:
                    self.panGestureArguments = nil
                    
                    self.containerLayoutUpdated(layout: layout, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func updateDismissOffset(_ offset: CGFloat) {
            guard self.isExpanded, let layout = self.currentLayout else {
                return
            }
            
            self.dismissOffset = offset
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.dismissOffset = nil
            self.isExpanded = isExpanded
            
            guard let layout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, transition: Transition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    
    let subject: PremiumDemoScreen.Subject
    let source: PremiumDemoScreen.Source
    let order: [PremiumPerk]?
    
    private var currentLayout: ContainerViewLayout?
        
    private let buttonText: String
    private let buttonGloss: Bool
    
    var action: () -> Void = {}
    var disposed: () -> Void = {}
    
    init(context: AccountContext, subject: PremiumDemoScreen.Subject, source: PremiumDemoScreen.Source, order: [PremiumPerk]?, buttonText: String, isPremium: Bool) {
        self.context = context
        self.subject = subject
        self.source = source
        self.order = order
        self.buttonText = buttonText
        self.buttonGloss = !isPremium
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    @objc private func cancelPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    override open func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, buttonTitle: self.buttonText, gloss: self.buttonGloss)
        self.displayNodeDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.animateOut(completion: {
                super.dismiss(animated: false, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.node.updateIsVisible(isVisible: true)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.node.updateIsVisible(isVisible: false)
    }
        
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
                
        self.node.containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
}

private class FooterNode: ASDisplayNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let coverNode: ASDisplayNode
    private let buttonNode: SolidRoundedButtonNode
    private let pageIndicatorView: ComponentHostView<Empty>
    
    private var theme: PresentationTheme
    private var validLayout: ContainerViewLayout?
    private var currentParams: (CGFloat, Int)?
    
    var action: () -> Void = {}
        
    init(theme: PresentationTheme, title: String, gloss: Bool) {
        self.theme = theme
        
        self.backgroundNode = NavigationBackgroundNode(color: theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 11.0, gloss: gloss)
        self.buttonNode.title = title
        
        self.coverNode = ASDisplayNode()
        self.coverNode.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.pageIndicatorView = ComponentHostView<Empty>()
        self.pageIndicatorView.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.coverNode)
        self.addSubnode(self.buttonNode)
        
        self.updateTheme(theme)
        
        self.buttonNode.pressed = { [weak self] in
            self?.action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.pageIndicatorView)
    }
    
    private func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.backgroundNode.updateColor(color: self.theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = self.theme.rootController.tabBar.separatorColor
        
        let backgroundColors = [
            UIColor(rgb: 0x0077ff),
            UIColor(rgb: 0x6b93ff),
            UIColor(rgb: 0x8878ff),
            UIColor(rgb: 0xe46ace)
        ]
        
        self.buttonNode.updateTheme(SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0x0077ff), backgroundColors: backgroundColors, foregroundColor: .white), animated: true)
    }
    
    func updateCoverAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.coverNode, alpha: alpha)
    }
    
    func updatePosition(_ position: CGFloat, count: Int) {
        self.currentParams = (position, count)
        if let layout = self.validLayout {
            let _ = self.updateLayout(layout: layout, transition: .immediate)
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        
        let buttonInset: CGFloat = 16.0
        let buttonWidth = layout.size.width - layout.safeInsets.left - layout.safeInsets.right - buttonInset * 2.0
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        let bottomPanelPadding: CGFloat = 12.0
        let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                
        let panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset + 28.0
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: panelHeight))
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInset, y: 40.0), size: CGSize(width: buttonWidth, height: buttonHeight)))
        
        transition.updateFrame(node: self.backgroundNode, frame: panelFrame)
        self.backgroundNode.update(size: panelFrame.size, transition: transition)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: panelFrame.width, height: UIScreenPixel)))
        
        if let (position, count) = self.currentParams {
            let indicatorSize = self.pageIndicatorView.update(
                transition: .immediate,
                component: AnyComponent(
                    PageIndicatorComponent(
                        pageCount: count,
                        position: position,
                        inactiveColor: self.theme.list.disclosureArrowColor,
                        activeColor: UIColor(rgb: 0x7169ff)
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            self.pageIndicatorView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - indicatorSize.width) / 2.0), y: 10.0), size: indicatorSize)
        }
        
        transition.updateFrame(node: self.coverNode, frame: panelFrame)
        
        return panelHeight
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if self.backgroundNode.frame.contains(point) {
            return true
        } else {
            return false
        }
    }
}
