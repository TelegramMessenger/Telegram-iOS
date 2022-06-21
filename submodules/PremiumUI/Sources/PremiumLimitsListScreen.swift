import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
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

private final class PremimLimitsListScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let expand: () -> Void
    
    var disposable: Disposable?

    init(context: AccountContext, expand: @escaping () -> Void) {
        self.context = context
        self.expand = expand
    }
    
    static func ==(lhs: PremimLimitsListScreenComponent, rhs: PremimLimitsListScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
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
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            let theme = environment.theme
            let strings = environment.strings
            
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
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: environment.navigationHeight + list.size.height / 2.0))
            )
            
            return CGSize(width: context.availableSize.width, height: environment.navigationHeight + list.size.height + environment.safeInsets.bottom)
        }
    }
}

public class PremimLimitsListScreen: ViewController {
    final class Node: ViewControllerTracingNode, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private var presentationData: PresentationData
        private weak var controller: PremimLimitsListScreen?
        
        private let component: AnyComponent<ViewControllerComponentContainer.Environment>
        private let theme: PresentationTheme?
        
        let dim: ASDisplayNode
        let wrappingView: UIView
        let containerView: UIView
        let scrollView: UIScrollView
        let hostView: ComponentHostView<ViewControllerComponentContainer.Environment>
        
        fileprivate let footerNode: FooterNode
        
        private(set) var isExpanded = false
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var panGestureArguments: (topInset: CGFloat, offset: CGFloat, scrollView: UIScrollView?, listNode: ListView?)?
        
        private var currentIsVisible: Bool = false
        private var currentLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
        
        fileprivate var temporaryDismiss = false
        
        init(context: AccountContext, controller: PremimLimitsListScreen, component: AnyComponent<ViewControllerComponentContainer.Environment>, theme: PresentationTheme?, buttonTitle: String, gloss: Bool) {
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            self.controller = controller
            
            self.component = component
            self.theme = theme
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.wrappingView = UIView()
            self.containerView = UIView()
            self.scrollView = UIScrollView()
            self.hostView = ComponentHostView()
            
            self.footerNode = FooterNode(theme: self.presentationData.theme, title: buttonTitle, gloss: gloss)
            
            super.init()
            
            self.scrollView.delegate = self
            self.scrollView.showsVerticalScrollIndicator = false
            
            self.containerView.clipsToBounds = true
            self.containerView.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.dim)
            
            self.view.addSubview(self.wrappingView)
            self.wrappingView.addSubview(self.containerView)
            self.containerView.addSubview(self.scrollView)
            self.containerView.addSubnode(self.footerNode)
            self.scrollView.addSubview(self.hostView)
            
            self.footerNode.action = { [weak self] in
                self?.controller?.action()
            }
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
            if let (layout, _) = self.currentLayout {
                if case .regular = layout.metrics.widthClass {
                    return false
                }
            }
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = self.scrollView.contentOffset.y
            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
            
            let bottomOffsetY = max(0.0, self.scrollView.contentSize.height - contentOffset - self.scrollView.frame.height)
            let backgroundAlpha: CGFloat = min(30.0, bottomOffsetY) / 30.0
            
            self.footerNode.updateBackgroundAlpha(backgroundAlpha, transition: .immediate)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
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
            
            if !self.temporaryDismiss {
                self.controller?.updateModalStyleOverlayTransitionFactor(0.0, transition: positionTransition)
            }
        }
                
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: Transition) {
            self.currentLayout = (layout, navigationHeight)
            
            if let controller = self.controller, let navigationBar = controller.navigationBar, navigationBar.view.superview !== self.wrappingView {
                self.containerView.addSubview(navigationBar.view)
            }
            
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
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: clipFrame.size), completion: nil)
            
            var clipLayout = layout.withUpdatedSize(clipFrame.size)
            if case .regular = layout.metrics.widthClass {
                clipLayout = clipLayout.withUpdatedIntrinsicInsets(.zero)
            }
            let footerHeight = self.footerNode.updateLayout(layout: clipLayout, transition: .immediate)
            
            let convertedFooterFrame = self.view.convert(CGRect(origin: CGPoint(x: clipFrame.minX, y: clipFrame.maxY - footerHeight), size: CGSize(width: clipFrame.width, height: footerHeight)), to: self.containerView)
            transition.setFrame(view: self.footerNode.view, frame: convertedFooterFrame)
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: 0.0,
                navigationHeight: navigationHeight,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: footerHeight, right: layout.safeInsets.right),
                metrics: layout.metrics,
                isVisible: self.currentIsVisible,
                theme: self.theme ?? self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            var contentSize = self.hostView.update(
                transition: transition,
                component: self.component,
                environment: {
                    environment
                },
                forceUpdate: true,
                containerSize: CGSize(width: clipFrame.size.width, height: 10000.0)
            )
            contentSize.height = max(layout.size.height - navigationHeight, contentSize.height)
            transition.setFrame(view: self.hostView, frame: CGRect(origin: CGPoint(), size: contentSize), completion: nil)
            
            self.scrollView.contentSize = contentSize
        }
        
        private var didPlayAppearAnimation = false
        func updateIsVisible(isVisible: Bool) {
            if self.currentIsVisible == isVisible {
                return
            }
            self.currentIsVisible = isVisible
            
            guard let currentLayout = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: currentLayout.layout, navigationHeight: currentLayout.navigationHeight, transition: .immediate)
            
            if !self.didPlayAppearAnimation {
                self.didPlayAppearAnimation = true
                self.animateIn()
            }
        }
        
        private var defaultTopInset: CGFloat {
            guard let (layout, _) = self.currentLayout else{
                return 210.0
            }
            if case .compact = layout.metrics.widthClass {
                var factor: CGFloat = 0.2488
                if layout.size.width <= 320.0 {
                    factor = 0.15
                }
                return floor(max(layout.size.width, layout.size.height) * factor)
            } else {
                return 210.0
            }
        }
        
        private func findScrollView(view: UIView?) -> (UIScrollView, ListView?)? {
            if let view = view {
                if let view = view as? UIScrollView {
                    return (view, nil)
                }
                if let node = view.asyncdisplaykit_node as? ListView {
                    return (node.scroller, node)
                }
                return findScrollView(view: view.superview)
            } else {
                return nil
            }
        }
        
        @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            
            let isLandscape = layout.orientation == .landscape
            let edgeTopInset = isLandscape ? 0.0 : defaultTopInset
        
            switch recognizer.state {
                case .began:
                    let point = recognizer.location(in: self.view)
                    let currentHitView = self.hitTest(point, with: nil)
                    
                    var scrollViewAndListNode = self.findScrollView(view: currentHitView)
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
                
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
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

                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                        } else {
                            self.isExpanded = true
                            
                            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                        }
                    } else if (velocity.y < -300.0 || offset < topInset / 2.0) {
                        if velocity.y > -2200.0 && velocity.y < -300.0, let listNode = listNode {
                            DispatchQueue.main.async {
                                listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            }
                        }
                                                    
                        let initialVelocity: CGFloat = offset.isZero ? 0.0 : abs(velocity.y / offset)
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.45, curve: .customSpring(damping: 124.0, initialVelocity: initialVelocity))
                        self.isExpanded = true
                       
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
                    } else {
                        if let listNode = listNode {
                            listNode.scroller.setContentOffset(CGPoint(), animated: false)
                        } else if let scrollView = scrollView {
                            scrollView.setContentOffset(CGPoint(x: 0.0, y: -scrollView.contentInset.top), animated: false)
                        }
                        
                        self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
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
                    
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(.animated(duration: 0.3, curve: .easeInOut)))
                default:
                    break
            }
        }
        
        func update(isExpanded: Bool, transition: ContainedViewLayoutTransition) {
            guard isExpanded != self.isExpanded else {
                return
            }
            self.isExpanded = isExpanded
            
            guard let (layout, navigationHeight) = self.currentLayout else {
                return
            }
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
        }
    }
    
    var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let theme: PresentationTheme?
    private let component: AnyComponent<ViewControllerComponentContainer.Environment>
    private var isInitiallyExpanded = false
    
    private var currentLayout: ContainerViewLayout?
        
    private let buttonText: String
    private let buttonGloss: Bool
    
    var action: () -> Void = {}
    var disposed: () -> Void = {}
    
    public convenience init(context: AccountContext, buttonText: String, isPremium: Bool) {
        var expandImpl: (() -> Void)?
        self.init(context: context, component: PremimLimitsListScreenComponent(context: context, expand: {
            expandImpl?()
        }), buttonText: buttonText, buttonGloss: !isPremium)
                        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = presentationData.strings.Premium_Limits_Title
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        let rightBarButtonNode = ASImageNode()
        rightBarButtonNode.image = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: presentationData.theme.actionSheet.inputClearButtonColor)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: rightBarButtonNode)
        self.navigationItem.rightBarButtonItem?.target = self
        self.navigationItem.rightBarButtonItem?.action = #selector(self.cancelPressed)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
                
        expandImpl = { [weak self] in
            self?.node.update(isExpanded: true, transition: .animated(duration: 0.4, curve: .spring))
            if let currentLayout = self?.currentLayout {
                self?.containerLayoutUpdated(currentLayout, transition: .animated(duration: 0.4, curve: .spring))
            }
        }
    }
    
    private init<C: Component>(context: AccountContext, component: C, theme: PresentationTheme? = nil, buttonText: String, buttonGloss: Bool) where C.EnvironmentType == ViewControllerComponentContainer.Environment {
        self.context = context
        self.component = AnyComponent(component)
        self.theme = nil
        self.buttonText = buttonText
        self.buttonGloss = buttonGloss
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: context.sharedContext.currentPresentationData.with { $0 }))
        
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
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
        self.displayNode = Node(context: self.context, controller: self, component: self.component, theme: self.theme, buttonTitle: self.buttonText, gloss: self.buttonGloss)
        if self.isInitiallyExpanded {
            (self.displayNode as! Node).update(isExpanded: true, transition: .immediate)
        }
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
    
    override public func updateNavigationBarLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var navigationLayout = self.navigationLayout(layout: layout)
        var navigationFrame = navigationLayout.navigationFrame
        
        var layout = layout
        if case .regular = layout.metrics.widthClass {
            let verticalInset: CGFloat = 44.0
            let maxSide = max(layout.size.width, layout.size.height)
            let minSide = min(layout.size.width, layout.size.height)
            let containerSize = CGSize(width: min(layout.size.width - 20.0, floor(maxSide / 2.0)), height: min(layout.size.height, minSide) - verticalInset * 2.0)
            let clipFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: floor((layout.size.height - containerSize.height) / 2.0)), size: containerSize)
            navigationFrame.size.width = clipFrame.width
            layout.size = clipFrame.size
        }
        
        navigationFrame.size.height = 56.0
        navigationLayout.navigationFrame = navigationFrame
        navigationLayout.defaultContentHeight = 56.0
        
        layout.statusBarHeight = nil
        
        self.applyNavigationBarLayout(layout, navigationLayout: navigationLayout, additionalBackgroundHeight: 0.0, transition: transition)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.currentLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
        
        let navigationHeight: CGFloat = 56.0
        
        self.node.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: Transition(transition))
    }
}

private class FooterNode: ASDisplayNode {
    private let backgroundNode: NavigationBackgroundNode
    private let separatorNode: ASDisplayNode
    private let buttonNode: SolidRoundedButtonNode
    
    private var theme: PresentationTheme
    private var validLayout: ContainerViewLayout?
    
    var action: () -> Void = {}
        
    init(theme: PresentationTheme, title: String, gloss: Bool) {
        self.theme = theme
        
        self.backgroundNode = NavigationBackgroundNode(color: theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), height: 50.0, cornerRadius: 11.0, gloss: gloss)
        self.buttonNode.title = title
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.buttonNode)
        
        self.updateTheme(theme)
        
        self.buttonNode.pressed = { [weak self] in
            self?.action()
        }
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
    
    func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.backgroundNode, alpha: alpha)
        transition.updateAlpha(node: self.separatorNode, alpha: alpha)
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        
        let buttonInset: CGFloat = 16.0
        let buttonWidth = layout.size.width - layout.safeInsets.left - layout.safeInsets.right - buttonInset * 2.0
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        let bottomPanelPadding: CGFloat = 12.0
        let bottomInset: CGFloat = layout.intrinsicInsets.bottom > 0.0 ? layout.intrinsicInsets.bottom + 5.0 : bottomPanelPadding
                
        let panelHeight: CGFloat = bottomPanelPadding + 50.0 + bottomInset
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: panelHeight))
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + buttonInset, y: bottomPanelPadding), size: CGSize(width: buttonWidth, height: buttonHeight)))
        
        transition.updateFrame(node: self.backgroundNode, frame: panelFrame)
        self.backgroundNode.update(size: panelFrame.size, transition: transition)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: panelFrame.width, height: UIScreenPixel)))
        
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
