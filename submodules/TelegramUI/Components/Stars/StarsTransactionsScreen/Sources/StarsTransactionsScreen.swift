import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import Postbox
import MultilineTextComponent
import BalancedTextComponent
import Markdown
import PremiumStarComponent
import ListSectionComponent
import TextFormat

final class StarsTransactionsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let starsContext: StarsContext
    let openTransaction: (StarsContext.State.Transaction) -> Void
    let buy: () -> Void
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        openTransaction: @escaping (StarsContext.State.Transaction) -> Void,
        buy: @escaping () -> Void
    ) {
        self.context = context
        self.starsContext = starsContext
        self.openTransaction = openTransaction
        self.buy = buy
    }
    
    static func ==(lhs: StarsTransactionsScreenComponent, rhs: StarsTransactionsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.starsContext !== rhs.starsContext {
            return false
        }
        return true
    }
    
    private final class ScrollViewImpl: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
        
        override var contentOffset: CGPoint {
            set(value) {
                var value = value
                if value.y > self.contentSize.height - self.bounds.height {
                    value.y = max(0.0, self.contentSize.height - self.bounds.height)
                    self.bounces = false
                } else {
                    self.bounces = true
                }
                super.contentOffset = value
            } get {
                return super.contentOffset
            }
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        
        private var currentSelectedPanelId: AnyHashable?
       
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationSeparatorLayer: SimpleLayer
        private let navigationSeparatorLayerContainer: SimpleLayer
        
        private let headerView = ComponentView<Empty>()
        private let headerOffsetContainer: UIView
        
        private let scrollContainerView: UIView
        
        private let overscroll = ComponentView<Empty>()
        private let fade = ComponentView<Empty>()
        private let starView = ComponentView<Empty>()
        private let titleView = ComponentView<Empty>()
        private let descriptionView = ComponentView<Empty>()
        
        private let balanceView = ComponentView<Empty>()
        
        private let topBalanceView = ComponentView<Empty>()
                
        private let panelContainer = ComponentView<StarsTransactionsPanelContainerEnvironment>()
                                
        private var component: StarsTransactionsScreenComponent?
        private weak var state: EmptyComponentState?
        private var navigationMetrics: (navigationHeight: CGFloat, statusBarHeight: CGFloat)?
        private var controller: (() -> ViewController?)?
        
        private var enableVelocityTracking: Bool = false
        private var previousVelocityM1: CGFloat = 0.0
        private var previousVelocity: CGFloat = 0.0
        
        private var ignoreScrolling: Bool = false
        
        private var stateDisposable: Disposable?
        private var starsState: StarsContext.State?
        
        override init(frame: CGRect) {
            self.headerOffsetContainer = UIView()
            self.headerOffsetContainer.isUserInteractionEnabled = false
            
            self.navigationBackgroundView = BlurredBackgroundView(color: nil, enableBlur: true)
            self.navigationBackgroundView.alpha = 0.0
            
            self.navigationSeparatorLayer = SimpleLayer()
            self.navigationSeparatorLayer.opacity = 0.0
            self.navigationSeparatorLayerContainer = SimpleLayer()
            self.navigationSeparatorLayerContainer.opacity = 0.0
            
            self.scrollContainerView = UIView()
            self.scrollView = ScrollViewImpl()
                                    
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContainerView)
                        
            self.addSubview(self.navigationBackgroundView)
            
            self.navigationSeparatorLayerContainer.addSublayer(self.navigationSeparatorLayer)
            self.layer.addSublayer(self.navigationSeparatorLayerContainer)
            
            self.addSubview(self.headerOffsetContainer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.enableVelocityTracking = true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                if self.enableVelocityTracking {
                    self.previousVelocityM1 = self.previousVelocity
                    if let value = (scrollView.value(forKey: (["_", "verticalVelocity"] as [String]).joined()) as? NSNumber)?.doubleValue {
                        self.previousVelocity = CGFloat(value)
                    }
                }
                
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let _ = self.navigationMetrics else {
                return
            }
            
            let paneAreaExpansionDistance: CGFloat = 32.0
            let paneAreaExpansionFinalPoint: CGFloat = scrollView.contentSize.height - scrollView.bounds.height
            if targetContentOffset.pointee.y > paneAreaExpansionFinalPoint - paneAreaExpansionDistance && targetContentOffset.pointee.y < paneAreaExpansionFinalPoint {
                targetContentOffset.pointee.y = paneAreaExpansionFinalPoint
                self.enableVelocityTracking = false
                self.previousVelocity = 0.0
                self.previousVelocityM1 = 0.0
            }
        }
                
        private func updateScrolling(transition: Transition) {
            let scrollBounds = self.scrollView.bounds
            
            let isLockedAtPanels = scrollBounds.maxY == self.scrollView.contentSize.height
            
            if let navigationMetrics = self.navigationMetrics {
                let topInset: CGFloat = navigationMetrics.navigationHeight - 56.0
                
                let titleOffset: CGFloat
                let titleScale: CGFloat
                let titleOffsetDelta = (topInset + 160.0) - (navigationMetrics.statusBarHeight + (navigationMetrics.navigationHeight - navigationMetrics.statusBarHeight) / 2.0)
                
                var topContentOffset = self.scrollView.contentOffset.y
                
                let navigationBackgroundAlpha = min(20.0, max(0.0, topContentOffset - 95.0)) / 20.0
                topContentOffset = topContentOffset + max(0.0, min(1.0, topContentOffset / titleOffsetDelta)) * 10.0
                titleOffset = topContentOffset
                let fraction = max(0.0, min(1.0, titleOffset / titleOffsetDelta))
                titleScale = 1.0 - fraction * 0.36
                
                let headerTransition: Transition = .immediate
                
                if let starView = self.starView.view {
                    let starPosition = CGPoint(x: self.scrollView.frame.width / 2.0, y: topInset + starView.bounds.height / 2.0 - 30.0 - titleOffset * titleScale)
                    
                    headerTransition.setPosition(view: starView, position: starPosition)
                    headerTransition.setScale(view: starView, scale: titleScale)
                }
                
                if let titleView = self.titleView.view {
                    let titlePosition = CGPoint(x: scrollBounds.width / 2.0, y: max(topInset + 160.0 - titleOffset, navigationMetrics.statusBarHeight + (navigationMetrics.navigationHeight - navigationMetrics.statusBarHeight) / 2.0))
                    
                    headerTransition.setPosition(view: titleView, position: titlePosition)
                    headerTransition.setScale(view: titleView, scale: titleScale)
                }
                
                let animatedTransition = Transition(animation: .curve(duration: 0.18, curve: .easeInOut))
                animatedTransition.setAlpha(view: self.navigationBackgroundView, alpha: navigationBackgroundAlpha)
                animatedTransition.setAlpha(layer: self.navigationSeparatorLayerContainer, alpha: navigationBackgroundAlpha)
                
                let expansionDistance: CGFloat = 32.0
                var expansionDistanceFactor: CGFloat = abs(scrollBounds.maxY - self.scrollView.contentSize.height) / expansionDistance
                expansionDistanceFactor = max(0.0, min(1.0, expansionDistanceFactor))
                
                transition.setAlpha(layer: self.navigationSeparatorLayer, alpha: expansionDistanceFactor)
                if let panelContainerView = self.panelContainer.view as? StarsTransactionsPanelContainerComponent.View {
                    panelContainerView.updateNavigationMergeFactor(value: 1.0 - expansionDistanceFactor, transition: transition)
                }
                
                if let topBalanceView = self.topBalanceView.view {
                    topBalanceView.alpha = 1.0 - expansionDistanceFactor
                }
            }
            
            let _ = self.panelContainer.updateEnvironment(
                transition: transition,
                environment: {
                    StarsTransactionsPanelContainerEnvironment(isScrollable: isLockedAtPanels)
                }
            )
        }
        
        private var previousBalance: Int64?
        
        private var isUpdating = false
        func update(component: StarsTransactionsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            var balanceUpdated = false
            if let starsState = self.starsState {
                if let previousBalance, starsState.balance != previousBalance {
                    balanceUpdated = true
                }
                self.previousBalance = starsState.balance
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            if self.stateDisposable == nil {
                self.stateDisposable = (component.starsContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    self.starsState = state
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
            }
            
            var wasLockedAtPanels = false
            if let panelContainerView = self.panelContainer.view, let navigationMetrics = self.navigationMetrics {
                if self.scrollView.bounds.minY > 0.0 && abs(self.scrollView.bounds.minY - (panelContainerView.frame.minY - navigationMetrics.navigationHeight)) <= UIScreenPixel {
                    wasLockedAtPanels = true
                }
            }
            
            self.controller = environment.controller
            
            self.navigationMetrics = (environment.navigationHeight, environment.statusBarHeight)
            
            self.navigationSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            
            let navigationFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: environment.navigationHeight))
            self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
            self.navigationBackgroundView.update(size: navigationFrame.size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationFrame)
            
            let navigationSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationFrame.maxY), size: CGSize(width: availableSize.width, height: UIScreenPixel))
            
            transition.setFrame(layer: self.navigationSeparatorLayerContainer, frame: navigationSeparatorFrame)
            transition.setFrame(layer: self.navigationSeparatorLayer, frame: CGRect(origin: CGPoint(), size: navigationSeparatorFrame.size))
            
            self.backgroundColor = environment.theme.list.blocksBackgroundColor
            
            var contentHeight: CGFloat = 0.0
                        
            let sideInsets: CGFloat = environment.safeInsets.left + environment.safeInsets.right + 16 * 2.0
            let bottomInset: CGFloat = environment.safeInsets.bottom
             
            contentHeight += environment.statusBarHeight
            
            let starTransition: Transition = .immediate
            
            var topBackgroundColor = environment.theme.list.plainBackgroundColor
            let bottomBackgroundColor = environment.theme.list.blocksBackgroundColor
            if environment.theme.overallDarkAppearance {
                topBackgroundColor = bottomBackgroundColor
            }
            
            let overscrollSize = self.overscroll.update(
                transition: .immediate,
                component: AnyComponent(Rectangle(color: topBackgroundColor)),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            let overscrollFrame = CGRect(origin: CGPoint(x: 0.0, y: -overscrollSize.height), size: overscrollSize)
            if let overscrollView = self.overscroll.view {
                if overscrollView.superview == nil {
                    self.scrollView.addSubview(overscrollView)
                }
                starTransition.setFrame(view: overscrollView, frame: overscrollFrame)
            }
            
            let fadeSize = self.fade.update(
                transition: .immediate,
                component: AnyComponent(RoundedRectangle(
                    colors: [
                        topBackgroundColor,
                        bottomBackgroundColor
                    ],
                    cornerRadius: 0.0,
                    gradientDirection: .vertical
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            let fadeFrame = CGRect(origin: CGPoint(x: 0.0, y: -fadeSize.height), size: fadeSize)
            if let fadeView = self.fade.view {
                if fadeView.superview == nil {
                    self.scrollView.addSubview(fadeView)
                }
                starTransition.setFrame(view: fadeView, frame: fadeFrame)
            }
                    
            let starSize = self.starView.update(
                transition: .immediate,
                component: AnyComponent(PremiumStarComponent(
                    isIntro: true,
                    isVisible: true,
                    hasIdleAnimations: true,
                    colors: [
                        UIColor(rgb: 0xea8904),
                        UIColor(rgb: 0xf09903),
                        UIColor(rgb: 0xfec209),
                        UIColor(rgb: 0xfed31a)
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: min(414.0, availableSize.width), height: 220.0)
            )
            let starFrame = CGRect(origin: .zero, size: starSize)
            if let starView = self.starView.view {
                if starView.superview == nil {
                    self.insertSubview(starView, aboveSubview: self.scrollView)
                }
                starTransition.setBounds(view: starView, bounds: starFrame)
            }
                       
            let titleSize = self.titleView.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.Stars_Intro_Title, font: Font.bold(28.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center,
                        truncationType: .end,
                        maximumNumberOfLines: 1
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let titleView = self.titleView.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                starTransition.setBounds(view: titleView, bounds: CGRect(origin: .zero, size: titleSize))
            }
            
            let textFont = Font.regular(14.0)
            let boldTextFont = Font.semibold(14.0)
            let textColor = environment.theme.actionSheet.primaryTextColor
            let linkColor = environment.theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let balanceAttributedString = parseMarkdownIntoAttributedString(" \(environment.strings.Stars_Intro_Balance)\n #  **\(self.starsState?.balance ?? 0)**", attributes: markdownAttributes, textAlignment: .right).mutableCopy() as! NSMutableAttributedString
            if let range = balanceAttributedString.string.range(of: "#"), let chevronImage = generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: UIColor(rgb: 0xf09903)) {
                balanceAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: balanceAttributedString.string))
                balanceAttributedString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xf09903), range: NSRange(range, in: balanceAttributedString.string))
                balanceAttributedString.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: balanceAttributedString.string))
            }
            let topBalanceSize = self.topBalanceView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(balanceAttributedString),
                    horizontalAlignment: .right,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            if let topBalanceView = self.topBalanceView.view {
                if topBalanceView.superview == nil {
                    topBalanceView.alpha = 0.0
                    self.addSubview(topBalanceView)
                }
                starTransition.setFrame(view: topBalanceView, frame: CGRect(origin: CGPoint(x: availableSize.width - topBalanceSize.width - 16.0, y: 56.0), size: topBalanceSize))
            }

            contentHeight += 181.0
            
            let descriptionSize = self.descriptionView.update(
                transition: .immediate,
                component: AnyComponent(
                    BalancedTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.Stars_Intro_Description, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInsets - 8.0, height: 240.0)
            )
            let descriptionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - descriptionSize.width) / 2.0), y: contentHeight), size: descriptionSize)
            if let descriptionView = self.descriptionView.view {
                if descriptionView.superview == nil {
                    self.scrollView.addSubview(descriptionView)
                }
                
                starTransition.setFrame(view: descriptionView, frame: descriptionFrame)
            }
    
            contentHeight += descriptionSize.height
            contentHeight += 29.0
            
            let balanceSize = self.balanceView.update(
                transition: .immediate,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        StarsBalanceComponent(
                            theme: environment.theme,
                            strings: environment.strings,
                            count: self.starsState?.balance ?? 0,
                            buy: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.buy()
                            }
                        )
                    ))]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInsets, height: availableSize.height)
            )
            let balanceFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - balanceSize.width) / 2.0), y: contentHeight), size: balanceSize)
            if let balanceView = self.balanceView.view {
                if balanceView.superview == nil {
                    self.scrollView.addSubview(balanceView)
                }
                starTransition.setFrame(view: balanceView, frame: balanceFrame)
            }
            
            contentHeight += balanceSize.height
            contentHeight += 44.0
            
            let transactions = self.starsState?.transactions ?? []
            let allItems = StarsTransactionsListPanelComponent.Items(
                items: transactions.map { StarsTransactionsListPanelComponent.Item(transaction: $0) }
            )
            let incomingItems = StarsTransactionsListPanelComponent.Items(
                items: transactions.filter { $0.count > 0 }.map { StarsTransactionsListPanelComponent.Item(transaction: $0) }
            )
            let outgoingItems = StarsTransactionsListPanelComponent.Items(
                items: transactions.filter { $0.count < 0 }.map { StarsTransactionsListPanelComponent.Item(transaction: $0) }
            )
            
            var panelItems: [StarsTransactionsPanelContainerComponent.Item] = []
            if !allItems.items.isEmpty {
                panelItems.append(StarsTransactionsPanelContainerComponent.Item(
                    id: "all",
                    title: environment.strings.Stars_Intro_AllTransactions,
                    panel: AnyComponent(StarsTransactionsListPanelComponent(
                        context: component.context,
                        items: allItems,
                        action: { transaction in
                            component.openTransaction(transaction)
                        }
                    ))
                ))
                
                if !outgoingItems.items.isEmpty {
                    panelItems.append(StarsTransactionsPanelContainerComponent.Item(
                        id: "incoming",
                        title: environment.strings.Stars_Intro_Incoming,
                        panel: AnyComponent(StarsTransactionsListPanelComponent(
                            context: component.context,
                            items: incomingItems,
                            action: { transaction in
                                component.openTransaction(transaction)
                            }
                        ))
                    ))
                    
                    panelItems.append(StarsTransactionsPanelContainerComponent.Item(
                        id: "outgoing",
                        title: environment.strings.Stars_Intro_Outgoing,
                        panel: AnyComponent(StarsTransactionsListPanelComponent(
                            context: component.context,
                            items: outgoingItems,
                            action: { transaction in
                                component.openTransaction(transaction)
                            }
                        ))
                    ))
                }
            }
            
            var panelTransition = transition
            if balanceUpdated {
                panelTransition = .easeInOut(duration: 0.25)
            }
            
            if !panelItems.isEmpty {
                let panelContainerSize = self.panelContainer.update(
                    transition: panelTransition,
                    component: AnyComponent(StarsTransactionsPanelContainerComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        dateTimeFormat: environment.dateTimeFormat,
                        insets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: bottomInset, right: environment.safeInsets.right),
                        items: panelItems,
                        currentPanelUpdated: { [weak self] id, transition in
                            guard let self else {
                                return
                            }
                            self.currentSelectedPanelId = id
                            self.state?.updated(transition: transition)
                        }
                    )),
                    environment: {
                        StarsTransactionsPanelContainerEnvironment(isScrollable: wasLockedAtPanels)
                    },
                    containerSize: CGSize(width: availableSize.width, height: availableSize.height - environment.navigationHeight)
                )
                if let panelContainerView = self.panelContainer.view {
                    if panelContainerView.superview == nil {
                        self.scrollContainerView.addSubview(panelContainerView)
                    }
                    transition.setFrame(view: panelContainerView, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: panelContainerSize))
                }
                contentHeight += panelContainerSize.height
            } else {
                self.panelContainer.view?.removeFromSuperview()
            }
            
            self.ignoreScrolling = true
            
            let contentOffset = self.scrollView.bounds.minY
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            transition.setFrame(view: self.scrollContainerView, frame: CGRect(origin: CGPoint(), size: contentSize))
            
            var scrollViewBounds = self.scrollView.bounds
            scrollViewBounds.size = availableSize
            if wasLockedAtPanels, let panelContainerView = self.panelContainer.view {
                scrollViewBounds.origin.y = panelContainerView.frame.minY - environment.navigationHeight
            }
            transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
            
            if !wasLockedAtPanels && !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class StarsTransactionsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let starsContext: StarsContext
    
    private let options = Promise<[StarsTopUpOption]>()
    
    public init(context: AccountContext, starsContext: StarsContext, forceDark: Bool = false) {
        self.context = context
        self.starsContext = starsContext
        
        var buyImpl: (() -> Void)?
        var openTransactionImpl: ((StarsContext.State.Transaction) -> Void)?
        super.init(context: context, component: StarsTransactionsScreenComponent(
            context: context,
            starsContext: starsContext,
            openTransaction: { transaction in
                openTransactionImpl?(transaction)
            },
            buy: {
                buyImpl?()
            }
        ), navigationBarAppearance: .transparent)
        
        self.options.set(.single([]) |> then(context.engine.payments.starsTopUpOptions()))
        
        openTransactionImpl = { [weak self] transaction in
            guard let self else {
                return
            }
            let controller = context.sharedContext.makeStarsTransactionScreen(context: context, transaction: transaction)
            self.push(controller)
        }
        
        buyImpl = { [weak self] in
            guard let self else {
                return
            }
            let _ = (self.options.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] options in
                guard let self else {
                    return
                }
                let controller = context.sharedContext.makeStarsPurchaseScreen(context: context, starsContext: starsContext, options: options, peerId: nil, requiredStars: nil, completion: { [weak self] stars in
                    guard let self else {
                        return
                    }
                    self.starsContext.add(balance: stars)
                })
                self.push(controller)
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
}
