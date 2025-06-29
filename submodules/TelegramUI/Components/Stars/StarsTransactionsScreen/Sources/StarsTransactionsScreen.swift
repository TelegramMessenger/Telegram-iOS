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
import BundleIconComponent
import TextFormat
import UndoUI
import ListActionItemComponent
import StarsAvatarComponent
import TelegramStringFormatting
import ListItemComponentAdaptor
import ItemListUI
import StarsWithdrawalScreen
import PremiumDiamondComponent

private let initialSubscriptionsDisplayedLimit: Int32 = 3

final class StarsTransactionsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let starsContext: StarsContext
    let starsRevenueStatsContext: StarsRevenueStatsContext
    let subscriptionsContext: StarsSubscriptionsContext?
    let openTransaction: (StarsContext.State.Transaction) -> Void
    let openSubscription: (StarsContext.State.Subscription) -> Void
    let buy: () -> Void
    let withdraw: () -> Void
    let showTimeoutTooltip: (Int32) -> Void
    let gift: () -> Void
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        starsRevenueStatsContext: StarsRevenueStatsContext,
        subscriptionsContext: StarsSubscriptionsContext?,
        openTransaction: @escaping (StarsContext.State.Transaction) -> Void,
        openSubscription: @escaping (StarsContext.State.Subscription) -> Void,
        buy: @escaping () -> Void,
        withdraw: @escaping () -> Void,
        showTimeoutTooltip: @escaping (Int32) -> Void,
        gift: @escaping () -> Void
    ) {
        self.context = context
        self.starsContext = starsContext
        self.starsRevenueStatsContext = starsRevenueStatsContext
        self.subscriptionsContext = subscriptionsContext
        self.openTransaction = openTransaction
        self.openSubscription = openSubscription
        self.buy = buy
        self.withdraw = withdraw
        self.showTimeoutTooltip = showTimeoutTooltip
        self.gift = gift
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
                
        private let scrollContainerView: UIView
        
        private let overscroll = ComponentView<Empty>()
        private let fade = ComponentView<Empty>()
        private let starView = ComponentView<Empty>()
        private let titleView = ComponentView<Empty>()
        private let descriptionView = ComponentView<Empty>()
        
        private let balanceView = ComponentView<Empty>()
        private let earnStarsSection = ComponentView<Empty>()
        
        private let subscriptionsView = ComponentView<Empty>()
        
        private let topBalanceTitleView = ComponentView<Empty>()
        private let topBalanceValueView = ComponentView<Empty>()
        private let topBalanceIconView = ComponentView<Empty>()
                
        private let panelContainer = ComponentView<StarsTransactionsPanelContainerEnvironment>()
                                
        private var component: StarsTransactionsScreenComponent?
        private weak var state: EmptyComponentState?
        private var navigationMetrics: (navigationHeight: CGFloat, statusBarHeight: CGFloat)?
        private var controller: (() -> ViewController?)?
        
        private var enableVelocityTracking: Bool = false
        private var previousVelocityM1: CGFloat = 0.0
        private var previousVelocity: CGFloat = 0.0
        
        private var listIsExpanded = false
        
        private var ignoreScrolling: Bool = false
        
        private var stateDisposable: Disposable?
        private var starsState: StarsContext.State?
        
        private var revenueStateDisposable: Disposable?
        private var revenueState: StarsRevenueStats?
        
        private var previousBalance: StarsAmount?
        
        private var subscriptionsStateDisposable: Disposable?
        private var subscriptionsState: StarsSubscriptionsContext.State?
        private var subscriptionsExpanded = false
        private var subscriptionsMoreDisplayed: Int32 = 0
        
        private var allTransactionsContext: StarsTransactionsContext?
        private var incomingTransactionsContext: StarsTransactionsContext?
        private var outgoingTransactionsContext: StarsTransactionsContext?
                
        override init(frame: CGRect) {
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
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.revenueStateDisposable?.dispose()
            self.subscriptionsStateDisposable?.dispose()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            var currentParent: UIView? = result
            while true {
                if currentParent == nil || currentParent === self {
                    break
                }
                if let scrollView = currentParent as? UIScrollView {
                    if scrollView === self.scrollView {
                        break
                    }
                    if scrollView.isDecelerating && scrollView.contentOffset.y < -scrollView.contentInset.top {
                        return self.scrollView
                    }
                }
                currentParent = currentParent?.superview
            }
            return result
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.enableVelocityTracking = true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !self.ignoreScrolling else {
                return
            }
            if self.enableVelocityTracking {
                self.previousVelocityM1 = self.previousVelocity
                if let value = (scrollView.value(forKey: (["_", "verticalVelocity"] as [String]).joined()) as? NSNumber)?.doubleValue {
                    self.previousVelocity = CGFloat(value)
                }
            }
            
            self.updateScrolling(transition: .immediate)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard let navigationMetrics = self.navigationMetrics else {
                return
            }
            
            if let panelContainerView = self.panelContainer.view as? StarsTransactionsPanelContainerComponent.View {
                let paneAreaExpansionFinalPoint: CGFloat = panelContainerView.frame.minY - navigationMetrics.navigationHeight
                if abs(scrollView.contentOffset.y - paneAreaExpansionFinalPoint) < .ulpOfOne {
                    panelContainerView.transferVelocity(self.previousVelocityM1)
                }
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
        
        func scrollToTop() {
            if let panelContainerView = self.panelContainer.view as? StarsTransactionsPanelContainerComponent.View, !panelContainerView.scrollToTop() {
                self.scrollView.setContentOffset(.zero, animated: true)
            }
        }
                
        private func updateScrolling(transition: ComponentTransition) {
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
                
                let headerTransition: ComponentTransition = .immediate
                
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
                
                let animatedTransition = ComponentTransition(animation: .curve(duration: 0.18, curve: .easeInOut))
                animatedTransition.setAlpha(view: self.navigationBackgroundView, alpha: navigationBackgroundAlpha)
                animatedTransition.setAlpha(layer: self.navigationSeparatorLayerContainer, alpha: navigationBackgroundAlpha)
                
                let expansionDistance: CGFloat = 32.0
                var expansionDistanceFactor: CGFloat = abs(scrollBounds.maxY - self.scrollView.contentSize.height) / expansionDistance
                expansionDistanceFactor = max(0.0, min(1.0, expansionDistanceFactor))
                
                transition.setAlpha(layer: self.navigationSeparatorLayer, alpha: expansionDistanceFactor)
                if let panelContainerView = self.panelContainer.view as? StarsTransactionsPanelContainerComponent.View {
                    panelContainerView.updateNavigationMergeFactor(value: 1.0 - expansionDistanceFactor, transition: transition)
                }
                
                let topBalanceAlpha = 1.0 - expansionDistanceFactor
                if let view = self.topBalanceTitleView.view {
                    view.alpha = topBalanceAlpha
                }
                if let view = self.topBalanceValueView.view {
                    view.alpha = topBalanceAlpha
                }
                if let view = self.topBalanceIconView.view {
                    view.alpha = topBalanceAlpha
                }
                
                let listIsExpanded = expansionDistanceFactor == 0.0
                if listIsExpanded != self.listIsExpanded {
                    self.listIsExpanded = listIsExpanded
                    if !self.isUpdating {
                        self.state?.updated(transition: .init(animation: .curve(duration: 0.25, curve: .slide)))
                    }
                }
            }
            
            let _ = self.panelContainer.updateEnvironment(
                transition: transition,
                environment: {
                    StarsTransactionsPanelContainerEnvironment(isScrollable: isLockedAtPanels)
                }
            )
        }
                
        private var isUpdating = false
        func update(component: StarsTransactionsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            var balanceUpdated = false
            if let starsState = self.starsState {
                if let previousBalance = self.previousBalance, starsState.balance != previousBalance {
                    balanceUpdated = true
                }
                self.previousBalance = starsState.balance
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
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
                
                self.revenueStateDisposable = (component.starsRevenueStatsContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    self.revenueState = state.stats
                    
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
                
                if let subscriptionsContext = component.subscriptionsContext {
                    self.subscriptionsStateDisposable = (subscriptionsContext.state
                    |> deliverOnMainQueue).start(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        let isFirstTime = self.subscriptionsState == nil
                        if !state.subscriptions.isEmpty {
                            self.subscriptionsState = state
                        } else {
                            self.subscriptionsState = nil
                        }
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: isFirstTime ? .immediate : .spring(duration: 0.4))
                        }
                    })
                }
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
                        
            let sideInsets: CGFloat = environment.safeInsets.left + environment.safeInsets.right + 16.0 * 2.0
            let bottomInset: CGFloat = environment.safeInsets.bottom
             
            if environment.statusBarHeight > 0.0 {
                contentHeight += environment.statusBarHeight
            } else {
                contentHeight += 12.0
            }
            
            let starTransition: ComponentTransition = .immediate
            
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
            
            let headerComponent: AnyComponent<Empty>
            if component.starsContext.ton {
                headerComponent = AnyComponent(PremiumDiamondComponent(theme: environment.theme))
            } else {
                headerComponent = AnyComponent(PremiumStarComponent(
                    theme: environment.theme,
                    isIntro: true,
                    isVisible: true,
                    hasIdleAnimations: true,
                    colors: [
                        UIColor(rgb: 0xe57d02),
                        UIColor(rgb: 0xf09903),
                        UIColor(rgb: 0xf9b004),
                        UIColor(rgb: 0xfdd219)
                    ],
                    particleColor: UIColor(rgb: 0xf9b004),
                    backgroundColor: environment.theme.list.blocksBackgroundColor
                ))
            }
                    
            let starSize = self.starView.update(
                transition: .immediate,
                component: headerComponent,
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
            
            let titleString: String
            let descriptionString: String
            if component.starsContext.ton {
                titleString = environment.strings.Stars_Ton_Title
                descriptionString = environment.strings.Stars_Ton_Description
            } else {
                titleString = environment.strings.Stars_Intro_Title
                descriptionString = environment.strings.Stars_Intro_Description
            }
                       
            let titleSize = self.titleView.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleString, font: Font.bold(28.0), textColor: environment.theme.list.itemPrimaryTextColor)),
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
            
            let topBalanceTitleSize = self.topBalanceTitleView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Stars_Intro_Balance,
                        font: Font.regular(14.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            
            let formattedBalance: String
            if component.starsContext.ton {
                formattedBalance = formatTonAmountText(self.starsState?.balance.value ?? 0, dateTimeFormat: environment.dateTimeFormat)
            } else {
                formattedBalance = formatStarsAmountText(self.starsState?.balance ?? StarsAmount.zero, dateTimeFormat: environment.dateTimeFormat)
            }
            let smallLabelFont = Font.regular(11.0)
            let labelFont = Font.semibold(14.0)
            let balanceText = tonAmountAttributedString(formattedBalance, integralFont: labelFont, fractionalFont: smallLabelFont, color: environment.theme.actionSheet.primaryTextColor, decimalSeparator: environment.dateTimeFormat.decimalSeparator)
            
            let topBalanceValueSize = self.topBalanceValueView.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(balanceText),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            let topBalanceIconSize = self.topBalanceIconView.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: component.starsContext.ton ? "Ads/TonBig" : "Premium/Stars/StarSmall",
                    tintColor: component.starsContext.ton ? environment.theme.list.itemAccentColor : nil,
                    maxSize: component.starsContext.ton ? CGSize(width: 12.0, height: 12.0) : nil
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let navigationHeight = environment.navigationHeight - environment.statusBarHeight
            let topBalanceOriginY = environment.statusBarHeight + (navigationHeight - topBalanceTitleSize.height - topBalanceValueSize.height) / 2.0
            let topBalanceTitleFrame = CGRect(origin: CGPoint(x: availableSize.width - topBalanceTitleSize.width - 16.0 - environment.safeInsets.right, y: topBalanceOriginY), size: topBalanceTitleSize)
            if let topBalanceTitleView = self.topBalanceTitleView.view {
                if topBalanceTitleView.superview == nil {
                    topBalanceTitleView.alpha = 0.0
                    self.addSubview(topBalanceTitleView)
                }
                starTransition.setFrame(view: topBalanceTitleView, frame: topBalanceTitleFrame)
            }
    
            let topBalanceValueFrame = CGRect(origin: CGPoint(x: availableSize.width - topBalanceValueSize.width - 16.0 - environment.safeInsets.right, y: topBalanceTitleFrame.maxY), size: topBalanceValueSize)
            if let topBalanceValueView = self.topBalanceValueView.view {
                if topBalanceValueView.superview == nil {
                    topBalanceValueView.alpha = 0.0
                    self.addSubview(topBalanceValueView)
                }
                starTransition.setFrame(view: topBalanceValueView, frame: topBalanceValueFrame)
            }
            
            var topBalanceIconFrame = CGRect(origin: CGPoint(x: topBalanceValueFrame.minX - topBalanceIconSize.width - 2.0, y: floorToScreenPixels(topBalanceValueFrame.midY - topBalanceIconSize.height / 2.0) - UIScreenPixel), size: topBalanceIconSize)
            if component.starsContext.ton {
                topBalanceIconFrame.origin.y += 1.0 - UIScreenPixel
            }
            if let topBalanceIconView = self.topBalanceIconView.view {
                if topBalanceIconView.superview == nil {
                    topBalanceIconView.alpha = 0.0
                    self.addSubview(topBalanceIconView)
                }
                starTransition.setFrame(view: topBalanceIconView, frame: topBalanceIconFrame)
            }

            contentHeight += 181.0
            
            let descriptionSize = self.descriptionView.update(
                transition: .immediate,
                component: AnyComponent(
                    BalancedTextComponent(
                        text: .plain(NSAttributedString(string: descriptionString, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInsets - 8.0, height: 240.0)
            )
            let descriptionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - descriptionSize.width) / 2.0), y: contentHeight + 20.0 - floor(descriptionSize.height / 2.0)), size: descriptionSize)
            if let descriptionView = self.descriptionView.view {
                if descriptionView.superview == nil {
                    self.scrollView.addSubview(descriptionView)
                }
                
                starTransition.setFrame(view: descriptionView, frame: descriptionFrame)
            }
    
            contentHeight += descriptionSize.height
            contentHeight += 29.0
            
            let withdrawAvailable = (self.revenueState?.balances.overallRevenue.amount.value ?? 0) > 0
                   
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
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
                            dateTimeFormat: environment.dateTimeFormat,
                            count: self.starsState?.balance ?? StarsAmount.zero,
                            currency: component.starsContext.ton ? .ton : .stars,
                            rate: nil,
                            actionTitle: (withdrawAvailable ? environment.strings.Stars_Intro_BuyShort : environment.strings.Stars_Intro_Buy),
                            actionAvailable: (!component.starsContext.ton && !premiumConfiguration.areStarsDisabled && !premiumConfiguration.isPremiumDisabled),
                            actionIsEnabled: true,
                            actionIcon: component.starsContext.ton ? nil : PresentationResourcesItemList.itemListRoundTopupIcon(environment.theme),
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if component.starsContext.ton {
                                    component.withdraw()
                                } else {
                                    component.buy()
                                }
                            },
                            secondaryActionTitle: withdrawAvailable && !component.starsContext.ton ? environment.strings.Stars_Intro_Stats : nil,
                            secondaryActionIcon: withdrawAvailable && !component.starsContext.ton ? PresentationResourcesItemList.itemListStatsIcon(environment.theme) : nil,
                            secondaryAction: withdrawAvailable && !component.starsContext.ton ? { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.withdraw()
                            } : nil,
                            additionalAction: (premiumConfiguration.starsGiftsPurchaseAvailable && !premiumConfiguration.isPremiumDisabled && !component.starsContext.ton) ? AnyComponent(
                                Button(
                                    content: AnyComponent(
                                        HStack([
                                            AnyComponentWithIdentity(
                                                id: "icon",
                                                component: AnyComponent(BundleIconComponent(name: "Premium/Stars/Gift", tintColor: environment.theme.list.itemAccentColor))
                                            ),
                                            AnyComponentWithIdentity(
                                                id: "label",
                                                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Stars_Intro_GiftStars, font: Font.regular(17.0), textColor: environment.theme.list.itemAccentColor))))
                                            )
                                        ],
                                        spacing: 6.0)
                                    ),
                                    action: {
                                        component.gift()
                                    }
                                )
                            ) : nil
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
            contentHeight += 34.0
            
            var canJoinRefProgram = false
            if !component.starsContext.ton, let data = component.context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
                if let value = value as? Double {
                    canJoinRefProgram = value != 0.0
                } else if let value = value as? Bool {
                    canJoinRefProgram = value
                }
            }
            
            if canJoinRefProgram {
                let earnStarsSectionSize = self.earnStarsSection.update(
                    transition: .immediate,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                                itemGenerator: ItemListDisclosureItem(presentationData: ItemListPresentationData(presentationData), icon: PresentationResourcesSettings.earnStars, title: environment.strings.Monetization_EarnStarsInfo_Title, titleBadge: presentationData.strings.Settings_New, label: environment.strings.Monetization_EarnStarsInfo_Text, labelStyle: .multilineDetailText, sectionId: 0, style: .blocks, action: {
                                }),
                                params: ListViewItemLayoutParams(width: availableSize.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true),
                                action: { [weak self] in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    let _ = (component.context.sharedContext.makeAffiliateProgramSetupScreenInitialData(context: component.context, peerId: component.context.account.peerId, mode: .connectedPrograms)
                                    |> deliverOnMainQueue).startStandalone(next: { [weak self] initialData in
                                        guard let self, let component = self.component else {
                                            return
                                        }
                                        let setupScreen = component.context.sharedContext.makeAffiliateProgramSetupScreen(context: component.context, initialData: initialData)
                                        self.controller?()?.push(setupScreen)
                                    })
                                }
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInsets, height: availableSize.height)
                )
                let earnStarsSectionFrame = CGRect(origin: CGPoint(x: sideInsets * 0.5, y: contentHeight), size: earnStarsSectionSize)
                if let earnStarsSectionView = self.earnStarsSection.view {
                    if earnStarsSectionView.superview == nil {
                        self.scrollView.addSubview(earnStarsSectionView)
                    }
                    starTransition.setFrame(view: earnStarsSectionView, frame: earnStarsSectionFrame)
                }
                contentHeight += earnStarsSectionSize.height
                contentHeight += 44.0
            }
            
            let fontBaseDisplaySize = 17.0
            var subscriptionsItems: [AnyComponentWithIdentity<Empty>] = []
            if let subscriptionsState = self.subscriptionsState {
                var subscriptions = subscriptionsState.subscriptions
                var limit: Int32
                if self.subscriptionsExpanded {
                    limit = 25 + self.subscriptionsMoreDisplayed
                } else {
                    limit = initialSubscriptionsDisplayedLimit
                }
                subscriptions = Array(subscriptions.prefix(Int(limit)))
                
                for subscription in subscriptions {
                    var titleComponents: [AnyComponentWithIdentity<Empty>] = []
                    titleComponents.append(
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: subscription.peer.compactDisplayTitle,
                                font: Font.semibold(fontBaseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    )
                    let dateText: String
                    let dateValue = stringForDateWithoutYear(date: Date(timeIntervalSince1970: Double(subscription.untilDate)), strings: environment.strings)
                    var isExpired = false
                    if subscription.untilDate > Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                        if subscription.flags.contains(.isCancelled) {
                            dateText = environment.strings.Stars_Intro_Subscriptions_Expires(dateValue).string
                        } else {
                            dateText = environment.strings.Stars_Intro_Subscriptions_Renews(dateValue).string
                        }
                    } else {
                        dateText = environment.strings.Stars_Intro_Subscriptions_Expired(dateValue).string
                        if !subscription.flags.contains(.isCancelled) {
                            isExpired = true
                        }
                    }
                    
                    if let title = subscription.title {
                        let nameComponent = AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: title,
                                font: Font.regular(fontBaseDisplaySize * 16.0 / 17.0),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            ))
                        ))
                        var nameGroupComponent: AnyComponent<Empty>
                        if let photo = subscription.photo {
                            nameGroupComponent = AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(StarsAvatarComponent(context: component.context, theme: environment.theme, peer: nil, photo: photo, media: [], uniqueGift: nil, backgroundColor: .clear, size: CGSize(width: 19.0, height: 19.0)))),
                                    AnyComponentWithIdentity(id: AnyHashable(1), component: nameComponent)
                                ], spacing: 6.0)
                            )
                        } else {
                            nameGroupComponent = nameComponent
                        }
                        titleComponents.append(
                            AnyComponentWithIdentity(id: AnyHashable(1), component: nameGroupComponent)
                        )
                    }
                    
                    titleComponents.append(
                        AnyComponentWithIdentity(id: AnyHashable(2), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: dateText,
                                font: Font.regular(floor(fontBaseDisplaySize * 15.0 / 17.0)),
                                textColor: environment.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    )
                    let labelComponent: AnyComponentWithIdentity<Empty>
                    if subscription.flags.contains(.isCancelled) || isExpired {
                        labelComponent = AnyComponentWithIdentity(id: "cancelledLabel", component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: isExpired ? environment.strings.Stars_Intro_Subscriptions_ExpiredStatus : environment.strings.Stars_Intro_Subscriptions_Cancelled, font: Font.regular(floor(fontBaseDisplaySize * 13.0 / 17.0)), textColor: environment.theme.list.itemDestructiveColor)))
                        ))
                    } else {
                        let itemLabelColor = environment.theme.list.itemPrimaryTextColor
                        let itemLabel = NSAttributedString(string: "\(subscription.pricing.amount)", font: Font.medium(fontBaseDisplaySize), textColor: itemLabelColor)
                        let itemSublabel = NSAttributedString(string: environment.strings.Stars_Intro_Subscriptions_PerMonth, font: Font.regular(floor(fontBaseDisplaySize * 13.0 / 17.0)), textColor: environment.theme.list.itemSecondaryTextColor)
                        
                        labelComponent = AnyComponentWithIdentity(id: "label", component: AnyComponent(StarsLabelComponent(text: itemLabel, subtext: itemSublabel)))
                    }
                    
                    subscriptionsItems.append(AnyComponentWithIdentity(
                        id: subscription.id,
                        component: AnyComponent(
                            ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(VStack(titleComponents, alignment: .left, spacing: 2.0)),
                                contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 8.0, right: 0.0),
                                leftIcon: .custom(AnyComponentWithIdentity(id: "avatar", component: AnyComponent(StarsAvatarComponent(context: component.context, theme: environment.theme, peer: .peer(subscription.peer), photo: nil, media: [], uniqueGift: nil, backgroundColor: environment.theme.list.plainBackgroundColor))), false),
                                icon: nil,
                                accessory: .custom(ListActionItemComponent.CustomAccessory(component: labelComponent, insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16.0))),
                                action: { [weak self] _ in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    component.openSubscription(subscription)
                                }
                            )
                        )
                    ))
                }
                if subscriptionsState.canLoadMore {
                    subscriptionsItems.append(AnyComponentWithIdentity(
                        id: "showMore",
                        component: AnyComponent(
                            ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(Text(
                                    text: environment.strings.Stars_Intro_Subscriptions_ShowMore,
                                    font: Font.regular(17.0),
                                    color: environment.theme.list.itemAccentColor
                                )),
                                leftIcon: .custom(
                                    AnyComponentWithIdentity(
                                        id: "icon",
                                        component: AnyComponent(Image(
                                            image: PresentationResourcesItemList.downArrowImage(environment.theme),
                                            size: CGSize(width: 30.0, height: 30.0)
                                        ))
                                    ),
                                    false
                                ),
                                accessory: nil,
                                action: { [weak self] _ in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    if self.subscriptionsExpanded {
                                        self.subscriptionsMoreDisplayed += 10
                                    } else {
                                        self.subscriptionsExpanded = true
                                    }
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                    component.subscriptionsContext?.loadMore()
                                },
                                highlighting: .default,
                                updateIsHighlighted: { view, _ in
                                    
                                })
                        )
                    ))
                }
            }
            
            if !subscriptionsItems.isEmpty {
                let subscriptionsSize = self.subscriptionsView.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Stars_Intro_Subscriptions_Title.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: subscriptionsItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInsets, height: availableSize.height)
                )
                let subscriptionsFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - subscriptionsSize.width) / 2.0), y: contentHeight), size: subscriptionsSize)
                if let subscriptionsView = self.subscriptionsView.view {
                    if subscriptionsView.superview == nil {
                        self.scrollView.addSubview(subscriptionsView)
                    }
                    starTransition.setFrame(view: subscriptionsView, frame: subscriptionsFrame)
                }
                contentHeight += subscriptionsSize.height
                contentHeight += 44.0
            }
            
            let initialTransactions = self.starsState?.transactions ?? []
            var panelItems: [StarsTransactionsPanelContainerComponent.Item] = []
            if !initialTransactions.isEmpty {
                let allTransactionsContext: StarsTransactionsContext
                if let current = self.allTransactionsContext {
                    allTransactionsContext = current
                } else {
                    allTransactionsContext = component.context.engine.payments.peerStarsTransactionsContext(subject: .starsContext(component.starsContext), mode: .all)
                    self.allTransactionsContext = allTransactionsContext
                }
                
                let incomingTransactionsContext: StarsTransactionsContext
                if let current = self.incomingTransactionsContext {
                    incomingTransactionsContext = current
                } else {
                    incomingTransactionsContext = component.context.engine.payments.peerStarsTransactionsContext(subject: .starsContext(component.starsContext), mode: .incoming)
                    self.incomingTransactionsContext = incomingTransactionsContext
                }
                
                let outgoingTransactionsContext: StarsTransactionsContext
                if let current = self.outgoingTransactionsContext {
                    outgoingTransactionsContext = current
                } else {
                    outgoingTransactionsContext = component.context.engine.payments.peerStarsTransactionsContext(subject: .starsContext(component.starsContext), mode: .outgoing)
                    self.outgoingTransactionsContext = outgoingTransactionsContext
                }
                
                panelItems.append(StarsTransactionsPanelContainerComponent.Item(
                    id: "all",
                    title: environment.strings.Stars_Intro_AllTransactions,
                    panel: AnyComponent(StarsTransactionsListPanelComponent(
                        context: component.context,
                        transactionsContext: allTransactionsContext,
                        isAccount: true,
                        action: { transaction in
                            component.openTransaction(transaction)
                        }
                    ))
                ))
                
                panelItems.append(StarsTransactionsPanelContainerComponent.Item(
                    id: "incoming",
                    title: environment.strings.Stars_Intro_Incoming,
                    panel: AnyComponent(StarsTransactionsListPanelComponent(
                        context: component.context,
                        transactionsContext: incomingTransactionsContext,
                        isAccount: true,
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
                        transactionsContext: outgoingTransactionsContext,
                        isAccount: true,
                        action: { transaction in
                            component.openTransaction(transaction)
                        }
                    ))
                ))
            }
            
            var panelTransition = transition
            if balanceUpdated {
                panelTransition = .easeInOut(duration: 0.25)
            }
            
            if !panelItems.isEmpty {
                let panelContainerInset: CGFloat = self.listIsExpanded ? 0.0 : 16.0
                let panelContainerCornerRadius: CGFloat = self.listIsExpanded ? 0.0 : 11.0
                
                let panelContainerSize = self.panelContainer.update(
                    transition: panelTransition,
                    component: AnyComponent(StarsTransactionsPanelContainerComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        dateTimeFormat: environment.dateTimeFormat,
                        insets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left + panelContainerInset, bottom: bottomInset, right: environment.safeInsets.right + panelContainerInset),
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
                    transition.setFrame(view: panelContainerView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - panelContainerSize.width) / 2.0), y: contentHeight), size: panelContainerSize))
                    transition.setCornerRadius(layer: panelContainerView.layer, cornerRadius: panelContainerCornerRadius)
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
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class StarsTransactionsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let starsContext: StarsContext
    private let starsRevenueStatsContext: StarsRevenueStatsContext
    private let subscriptionsContext: StarsSubscriptionsContext?
    
    private let options = Promise<[StarsTopUpOption]>()
    
    private let navigateDisposable = MetaDisposable()
    
    private weak var tooltipScreen: UndoOverlayController?
    private var timer: Foundation.Timer?
    
    public init(context: AccountContext, starsContext: StarsContext, forceDark: Bool = false) {
        self.context = context
        self.starsContext = starsContext
        
        self.starsRevenueStatsContext = context.engine.payments.peerStarsRevenueContext(peerId: context.account.peerId, ton: false)
        if !starsContext.ton {
            self.subscriptionsContext = context.engine.payments.peerStarsSubscriptionsContext(starsContext: starsContext)
        } else {
            self.subscriptionsContext = nil
        }
        
        var buyImpl: (() -> Void)?
        var withdrawImpl: (() -> Void)?
        var showTimeoutTooltipImpl: ((Int32) -> Void)?
        var giftImpl: (() -> Void)?
        var openTransactionImpl: ((StarsContext.State.Transaction) -> Void)?
        var openSubscriptionImpl: ((StarsContext.State.Subscription) -> Void)?
        super.init(context: context, component: StarsTransactionsScreenComponent(
            context: self.context,
            starsContext: self.starsContext,
            starsRevenueStatsContext: self.starsRevenueStatsContext,
            subscriptionsContext: self.subscriptionsContext,
            openTransaction: { transaction in
                openTransactionImpl?(transaction)
            },
            openSubscription: { subscription in
                openSubscriptionImpl?(subscription)
            },
            buy: {
                buyImpl?()
            },
            withdraw: {
                withdrawImpl?()
            },
            showTimeoutTooltip: { timestamp in
                showTimeoutTooltipImpl?(timestamp)
            },
            gift: {
                giftImpl?()
            }
        ), navigationBarAppearance: .transparent)
        
        self.navigationPresentation = .modalInLargeLayout
        
        self.options.set(.single([]) |> then(context.engine.payments.starsTopUpOptions()))
        
        openTransactionImpl = { [weak self] transaction in
            guard let self else {
                return
            }
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                let controller = context.sharedContext.makeStarsTransactionScreen(context: context, transaction: transaction, peer: peer)
                self.push(controller)
            })
        }
        
        openSubscriptionImpl = { [weak self] subscription in
            guard let self else {
                return
            }
            let controller = context.sharedContext.makeStarsSubscriptionScreen(context: context, subscription: subscription, update: { [weak self] cancel in
                guard let self else {
                    return
                }
                if subscription.untilDate > Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                    var updated = false
                    if let channel = subscription.peer._asPeer() as? TelegramChannel, channel.participationStatus == .left && !subscription.flags.contains(.isCancelled) {
                        let _ = self.context.engine.payments.fulfillStarsSubscription(peerId: context.account.peerId, subscriptionId: subscription.id).startStandalone()
                        updated = true
                    }
                    if let _ = subscription.inviteHash, !subscription.flags.contains(.isCancelledByBot) {
                        let _ = self.context.engine.payments.fulfillStarsSubscription(peerId: context.account.peerId, subscriptionId: subscription.id).startStandalone()
                        updated = true
                    }
                    if !updated {
                        if subscription.flags.contains(.isCancelled) {
                            self.subscriptionsContext?.updateSubscription(id: subscription.id, cancel: false)
                        } else {
                            self.subscriptionsContext?.updateSubscription(id: subscription.id, cancel: true)
                        }
                    }
                } else {
                    if let inviteHash = subscription.inviteHash {
                        self.context.sharedContext.handleTextLinkAction(context: self.context, peerId: nil, navigateDisposable: self.navigateDisposable, controller: self, action: .tap, itemLink: .url(url: "https://t.me/+\(inviteHash)", concealed: false))
                    } else if let invoiceSlug = subscription.invoiceSlug {
                        self.context.sharedContext.handleTextLinkAction(context: self.context, peerId: nil, navigateDisposable: self.navigateDisposable, controller: self, action: .tap, itemLink: .url(url: "https://t.me/$\(invoiceSlug)", concealed: false))
                    }
                }
            })
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
                let controller = context.sharedContext.makeStarsPurchaseScreen(context: context, starsContext: starsContext, options: options, purpose: .generic, completion: { [weak self] stars in
                    guard let self else {
                        return
                    }
                    self.starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let resultController = UndoOverlayController(
                        presentationData: presentationData,
                        content: .universal(
                            animation: "StarsBuy",
                            scale: 0.066,
                            colors: [:],
                            title: presentationData.strings.Stars_Intro_PurchasedTitle, 
                            text: presentationData.strings.Stars_Intro_PurchasedText(presentationData.strings.Stars_Intro_PurchasedText_Stars(Int32(stars))).string,
                            customUndoText: nil,
                            timeout: nil
                        ),
                        elevatedLayout: false,
                        action: { _ in return true})
                    self.present(resultController, in: .window(.root))
                })
                self.push(controller)
            })
        }
        
        withdrawImpl = { [weak self] in
            guard let self else {
                return
            }
            
            let controller = self.context.sharedContext.makeStarsStatisticsScreen(context: context, peerId: context.account.peerId, revenueContext: self.starsRevenueStatsContext)
            self.push(controller)
            
//            let _ = (context.engine.peers.checkStarsRevenueWithdrawalAvailability()
//            |> deliverOnMainQueue).start(error: { [weak self] error in
//                guard let self else {
//                    return
//                }
//                switch error {
//                case .serverProvided:
//                    return
//                case .requestPassword:
//                    let _ = (self.starsRevenueStatsContext.state
//                    |> take(1)
//                    |> deliverOnMainQueue).start(next: { [weak self] state in
//                        guard let self else {
//                            return
//                        }
//                        let controller = self.context.sharedContext.makeStarsWithdrawalScreen(context: context, completion: { [weak self] amount in
//                            guard let self else {
//                                return
//                            }
//                            let controller = confirmStarsRevenueWithdrawalController(context: context, peerId: context.account.peerId, amount: amount, present: { [weak self] c, a in
//                                self?.present(c, in: .window(.root))
//                            }, completion: { [weak self] url in
//                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
//                                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
//                                
//                                Queue.mainQueue().after(2.0) {
//                                    self?.starsRevenueStatsContext.reload()
//                                }
//                            })
//                            self.present(controller, in: .window(.root))
//                        })
//                        self.push(controller)
//                    })
//                default:
//                    let controller = starsRevenueWithdrawalController(context: context, peerId: context.account.peerId, amount: 0, initialError: error, present: { [weak self] c, a in
//                        self?.present(c, in: .window(.root))
//                    }, completion: { _ in
//                        
//                    })
//                    self.present(controller, in: .window(.root))
//                }
//            })
        }
        
        showTimeoutTooltipImpl = { [weak self] cooldownUntilTimestamp in
            guard let self, self.tooltipScreen == nil else {
                return
            }
            
            let remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
        
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let content: UndoOverlayContent = .universal(
                animation: "anim_clock",
                scale: 0.058,
                colors: [:],
                title: nil,
                text: presentationData.strings.Stars_Withdraw_Withdraw_ErrorTimeout(stringForRemainingTime(remainingCooldownSeconds)).string,
                customUndoText: nil,
                timeout: nil
            )
            let controller = UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in
                return true
            })
            self.tooltipScreen = controller
            self.present(controller, in: .window(.root))
            
            if remainingCooldownSeconds < 3600 {
                if self.timer == nil {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        if let tooltipScreen = self.tooltipScreen {
                            let remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                            let content: UndoOverlayContent = .universal(
                                animation: "anim_clock",
                                scale: 0.058,
                                colors: [:],
                                title: nil,
                                text: presentationData.strings.Stars_Withdraw_Withdraw_ErrorTimeout(stringForRemainingTime(remainingCooldownSeconds)).string,
                                customUndoText: nil,
                                timeout: nil
                            )
                            tooltipScreen.content = content
                        } else {
                            if let timer = self.timer {
                                self.timer = nil
                                timer.invalidate()
                            }
                        }
                    })
                }
            }
        }
        
        giftImpl = { [weak self] in
            guard let self else {
                return
            }
            let _ = combineLatest(queue: Queue.mainQueue(),
                self.options.get() |> take(1),
                self.context.account.stateManager.contactBirthdays |> take(1)
            ).start(next: { [weak self] options, birthdays in
                guard let self else {
                    return
                }
                let controller = self.context.sharedContext.makeStarsGiftController(context: self.context, birthdays: birthdays, completion: { [weak self] peerIds in
                    guard let self, let peerId = peerIds.first else {
                        return
                    }
                    let purchaseController = self.context.sharedContext.makeStarsPurchaseScreen(
                        context: self.context,
                        starsContext: starsContext,
                        options: options,
                        purpose: .gift(peerId: peerId),
                        completion: { [weak self] stars in
                            guard let self else {
                                return
                            }
                            
                            if let navigationController = self.navigationController as? NavigationController {
                                var controllers = navigationController.viewControllers
                                controllers = controllers.filter { !($0 is ContactSelectionController) }
                                navigationController.setViewControllers(controllers, animated: true)
                            }
                            
                            Queue.mainQueue().after(2.0) {
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                let resultController = UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .universal(
                                        animation: "StarsSend",
                                        scale: 0.066,
                                        colors: [:],
                                        title: nil,
                                        text: presentationData.strings.Stars_Intro_StarsSent(Int32(stars)),
                                        customUndoText: presentationData.strings.Stars_Intro_StarsSent_ViewChat,
                                        timeout: nil
                                    ),
                                    elevatedLayout: false,
                                    action: { [weak self] action in
                                        if case .undo = action, let navigationController = self?.navigationController as? NavigationController {
                                            let _ = (context.engine.data.get(
                                                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                                            )
                                            |> deliverOnMainQueue).start(next: { peer in
                                                guard let peer else {
                                                    return
                                                }
                                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), subject: nil, botStart: nil, updateTextInputState: nil, keepStack: .always, useExisting: true, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: nil, animated: true))
                                            })
                                        }
                                        return true
                                    })
                                self.present(resultController, in: .window(.root))
                            }
                        }
                    )
                    self.push(purchaseController)
                })
                self.push(controller)
            })
        }
        
        self.starsContext.load(force: false)
        self.subscriptionsContext?.loadMore()
        
        self.scrollToTop = { [weak self] in
            guard let self else {
                return
            }
            if let componentView = self.node.hostView.componentView as? StarsTransactionsScreenComponent.View {
                componentView.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.navigateDisposable.dispose()
    }
    
    public func update() {
        self.subscriptionsContext?.loadMore()
    }
}
