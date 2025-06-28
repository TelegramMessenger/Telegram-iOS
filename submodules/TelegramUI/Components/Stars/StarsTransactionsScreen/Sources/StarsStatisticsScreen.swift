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
import ListSectionComponent
import BundleIconComponent
import TextFormat
import UndoUI
import ListItemComponentAdaptor
import StatisticsUI
import ItemListUI
import StarsWithdrawalScreen

final class StarsStatisticsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let revenueContext: StarsRevenueStatsContext
    let openTransaction: (StarsContext.State.Transaction) -> Void
    let buy: () -> Void
    let withdraw: () -> Void
    let showTimeoutTooltip: (Int32) -> Void
    let buyAds: () -> Void
    
    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        revenueContext: StarsRevenueStatsContext,
        openTransaction: @escaping (StarsContext.State.Transaction) -> Void,
        buy: @escaping () -> Void,
        withdraw: @escaping () -> Void,
        showTimeoutTooltip: @escaping (Int32) -> Void,
        buyAds: @escaping () -> Void
    ) {
        self.context = context
        self.peerId = peerId
        self.revenueContext = revenueContext
        self.openTransaction = openTransaction
        self.buy = buy
        self.withdraw = withdraw
        self.showTimeoutTooltip = showTimeoutTooltip
        self.buyAds = buyAds
    }
    
    static func ==(lhs: StarsStatisticsScreenComponent, rhs: StarsStatisticsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.revenueContext !== rhs.revenueContext {
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
                
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let _ = otherGestureRecognizer as? UIPanGestureRecognizer {
                return true
            }
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer, let gestureRecognizers = gestureRecognizer.view?.gestureRecognizers {
                for otherGestureRecognizer in gestureRecognizers {
                    if otherGestureRecognizer !== gestureRecognizer, let panGestureRecognizer = otherGestureRecognizer as? UIPanGestureRecognizer, panGestureRecognizer.minimumNumberOfTouches == 2 {
                        return gestureRecognizer.numberOfTouches < 2
                    }
                }
                
                if let view = gestureRecognizer.view?.hitTest(gestureRecognizer.location(in: gestureRecognizer.view), with: nil) as? UIControl {
                    if view is UIButton {
                        return true
                    } else {
                        return !view.isTracking
                    }
                }
                
                return true
            } else {
                return true
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
        
        private let titleView = ComponentView<Empty>()
        
        private let chartView = ComponentView<Empty>()
        private let proceedsView = ComponentView<Empty>()
        private let balanceView = ComponentView<Empty>()

        private let transactionsHeader = ComponentView<Empty>()
        private let transactionsBackground = UIView()
        
        private let panelContainer = ComponentView<StarsTransactionsPanelContainerEnvironment>()
        
        private var allTransactionsContext: StarsTransactionsContext?
        private var incomingTransactionsContext: StarsTransactionsContext?
        private var outgoingTransactionsContext: StarsTransactionsContext?
                                
        private var component: StarsStatisticsScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: Environment<ViewControllerComponentContainer.Environment>?
        private var navigationMetrics: (navigationHeight: CGFloat, statusBarHeight: CGFloat)?
        private var controller: (() -> ViewController?)?
                
        private var enableVelocityTracking: Bool = false
        private var previousVelocityM1: CGFloat = 0.0
        private var previousVelocity: CGFloat = 0.0
        
        private var listIsExpanded = false
        
        private var ignoreScrolling: Bool = false
        
        private var stateDisposable: Disposable?
        private var starsState: StarsRevenueStats?
        
        private var previousBalance: Int64?
                
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        
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
            self.scrollContainerView.addSubview(self.transactionsBackground)
            
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
        
        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.scrollView.contentInset.top), animated: true)
        }
                        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.enableVelocityTracking = true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
                
                if let view = self.chartView.view as? ListItemComponentAdaptor.View, let node = view.itemNode as? StatsGraphItemNode {
                    node.resetInteraction()
                }
                
                if self.enableVelocityTracking {
                    self.previousVelocityM1 = self.previousVelocity
                    if let value = (scrollView.value(forKey: (["_", "verticalVelocity"] as [String]).joined()) as? NSNumber)?.doubleValue {
                        self.previousVelocity = CGFloat(value)
                    }
                }
            }
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
                
        private var lastScrollBounds: CGRect?
        private var lastBottomOffset: CGFloat?
        private func updateScrolling(transition: ComponentTransition) {
            let scrollBounds = self.scrollView.bounds
            
            let isLockedAtPanels = scrollBounds.maxY == self.scrollView.contentSize.height
            
            if let _ = self.navigationMetrics {
                let topContentOffset = self.scrollView.contentOffset.y
                let navigationBackgroundAlpha = min(20.0, max(0.0, topContentOffset)) / 20.0
                                
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
//            guard let environment = self.environment?[ViewControllerComponentContainer.Environment.self].value else {
//                return
//            }
//        
//            let scrollBounds = self.scrollView.bounds
//                                        
//            let topContentOffset = self.scrollView.contentOffset.y
//            let navigationBackgroundAlpha = min(20.0, max(0.0, topContentOffset)) / 20.0
//                            
//            let animatedTransition = ComponentTransition(animation: .curve(duration: 0.18, curve: .easeInOut))
//            animatedTransition.setAlpha(view: self.navigationBackgroundView, alpha: navigationBackgroundAlpha)
//            animatedTransition.setAlpha(layer: self.navigationSeparatorLayerContainer, alpha: navigationBackgroundAlpha)
//            
//            let expansionDistance: CGFloat = 32.0
//            var expansionDistanceFactor: CGFloat = abs(scrollBounds.maxY - self.scrollView.contentSize.height) / expansionDistance
//            expansionDistanceFactor = max(0.0, min(1.0, expansionDistanceFactor))
//            
//            transition.setAlpha(layer: self.navigationSeparatorLayer, alpha: expansionDistanceFactor)
//            
//            let bottomOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.contentOffset.y - self.scrollView.frame.height)
//            self.lastBottomOffset = bottomOffset
//            
//            let transactionsScrollBounds: CGRect
//            if let transactionsView = self.transactionsView.view {
//                transactionsScrollBounds = CGRect(origin: CGPoint(x: 0.0, y: scrollBounds.origin.y - transactionsView.frame.minY), size: scrollBounds.size)
//            } else {
//                transactionsScrollBounds = .zero
//            }
//            self.lastScrollBounds = transactionsScrollBounds
//            
//            let _ = self.transactionsView.updateEnvironment(
//                transition: transition,
//                environment: {
//                    StarsTransactionsPanelEnvironment(
//                        theme: environment.theme,
//                        strings: environment.strings,
//                        dateTimeFormat: environment.dateTimeFormat,
//                        containerInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: environment.safeInsets.bottom, right: environment.safeInsets.right),
//                        isScrollable: false,
//                        isCurrent: true,
//                        externalScrollBounds: transactionsScrollBounds,
//                        externalBottomOffset: bottomOffset
//                    )
//                }
//            )
        }
                
        private var isUpdating = false
        func update(component: StarsStatisticsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.environment = environment
            self.state = state
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let strings = environment.strings
            
            if self.stateDisposable == nil {
                self.stateDisposable = (component.revenueContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    self.starsState = state.stats
                    
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
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
             
            contentHeight += environment.navigationHeight
            contentHeight += 31.0
                        
            let titleSize = self.titleView.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: strings.Stars_BotRevenue_Title, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor)),
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
                let titlePosition = CGPoint(x: availableSize.width / 2.0, y: environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)
                transition.setPosition(view: titleView, position: titlePosition)
                transition.setBounds(view: titleView, bounds: CGRect(origin: .zero, size: titleSize))
            }
            
            if let revenueGraph = self.starsState?.revenueGraph {
                let chartSize = self.chartView.update(
                    transition: .immediate,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.Stars_BotRevenue_Revenue_Title.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                                itemGenerator: StatsGraphItem(presentationData: ItemListPresentationData(presentationData), graph: revenueGraph, type: .stars, noInitialZoom: true, conversionRate: starsState?.usdRate ?? 0.0, sectionId: 0, style: .blocks),
                                params: ListViewItemLayoutParams(width: availableSize.width - sideInsets, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
                            ))),
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInsets, height: availableSize.height)
                )
                let chartFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - chartSize.width) / 2.0), y: contentHeight), size: chartSize)
                if let chartView = self.chartView.view {
                    if chartView.superview == nil {
                        self.scrollView.addSubview(chartView)
                    }
                    transition.setFrame(view: chartView, frame: chartFrame)
                }
                contentHeight += chartSize.height
                contentHeight += 44.0
            }
            
            let proceedsSize = self.proceedsView.update(
                transition: .immediate,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.Stars_BotRevenue_Proceeds_Title.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.peerId == component.context.account.peerId ? strings.Stars_AccountRevenue_Proceeds_Info : strings.Stars_BotRevenue_Proceeds_Info,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(StarsOverviewItemComponent(
                            theme: environment.theme,
                            dateTimeFormat: environment.dateTimeFormat,
                            title: strings.Stars_BotRevenue_Proceeds_Available,
                            value: starsState?.balances.availableBalance.amount ?? StarsAmount.zero,
                            rate: starsState?.usdRate ?? 0.0
                        ))),
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(StarsOverviewItemComponent(
                            theme: environment.theme,
                            dateTimeFormat: environment.dateTimeFormat,
                            title: strings.Stars_BotRevenue_Proceeds_Current,
                            value: starsState?.balances.currentBalance.amount ?? StarsAmount.zero,
                            rate: starsState?.usdRate ?? 0.0
                        ))),
                        AnyComponentWithIdentity(id: 2, component: AnyComponent(StarsOverviewItemComponent(
                            theme: environment.theme,
                            dateTimeFormat: environment.dateTimeFormat,
                            title: strings.Stars_BotRevenue_Proceeds_Total,
                            value: starsState?.balances.overallRevenue.amount ?? StarsAmount.zero,
                            rate: starsState?.usdRate ?? 0.0
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInsets, height: availableSize.height)
            )
            let proceedsFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - proceedsSize.width) / 2.0), y: contentHeight), size: proceedsSize)
            if let proceedsView = self.proceedsView.view {
                if proceedsView.superview == nil {
                    self.scrollView.addSubview(proceedsView)
                }
                transition.setFrame(view: proceedsView, frame: proceedsFrame)
            }
            contentHeight += proceedsSize.height
            contentHeight += 31.0
            
            let termsFont = Font.regular(13.0)
            let termsTextColor = environment.theme.list.freeTextColor
            let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsFont, textColor: environment.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let balanceRawString = component.peerId == component.context.account.peerId ? strings.Stars_AccountRevenue_Withdraw_Info : strings.Stars_BotRevenue_Withdraw_Info
            let balanceInfoString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(balanceRawString, attributes: termsMarkdownAttributes, textAlignment: .natural))
            if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
            }
            if let range = balanceInfoString.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                balanceInfoString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: balanceInfoString.string))
            }
                        
            var balanceItems: [AnyComponentWithIdentity<Empty>] = []
            if component.peerId == component.context.account.peerId {
                let withdrawEnabled = self.starsState?.balances.withdrawEnabled ?? false
                balanceItems = [
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        StarsBalanceComponent(
                            theme: environment.theme,
                            strings: strings,
                            dateTimeFormat: environment.dateTimeFormat,
                            count: self.starsState?.balances.availableBalance.amount ?? StarsAmount.zero,
                            currency: .stars,
                            rate: self.starsState?.usdRate ?? 0,
                            actionTitle: strings.Stars_Intro_BuyShort,
                            actionAvailable: true,
                            actionIsEnabled: true,
                            actionIcon: PresentationResourcesItemList.itemListRoundTopupIcon(environment.theme),
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.buy()
                            },
                            secondaryActionTitle: withdrawEnabled ? strings.Stars_Intro_Withdraw : nil,
                            secondaryActionIcon: PresentationResourcesItemList.itemListRoundWithdrawIcon(environment.theme),
                            secondaryActionCooldownUntilTimestamp: self.starsState?.balances.nextWithdrawalTimestamp,
                            secondaryAction: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                var remainingCooldownSeconds: Int32 = 0
                                if let cooldownUntilTimestamp = self.starsState?.balances.nextWithdrawalTimestamp {
                                    remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                                    remainingCooldownSeconds = max(0, remainingCooldownSeconds)
                                    
                                    if remainingCooldownSeconds > 0 {
                                        component.showTimeoutTooltip(cooldownUntilTimestamp)
                                    } else {
                                        component.withdraw()
                                    }
                                } else {
                                    component.withdraw()
                                }
                            }
                        )
                    ))
                ]
            } else {
                balanceItems = [
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        StarsBalanceComponent(
                            theme: environment.theme,
                            strings: strings,
                            dateTimeFormat: environment.dateTimeFormat,
                            count: self.starsState?.balances.availableBalance.amount ?? StarsAmount.zero,
                            currency: .stars,
                            rate: self.starsState?.usdRate ?? 0,
                            actionTitle: strings.Stars_BotRevenue_Withdraw_WithdrawShort,
                            actionAvailable: true,
                            actionIsEnabled: self.starsState?.balances.withdrawEnabled ?? true,
                            actionCooldownUntilTimestamp: self.starsState?.balances.nextWithdrawalTimestamp,
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                var remainingCooldownSeconds: Int32 = 0
                                if let cooldownUntilTimestamp = self.starsState?.balances.nextWithdrawalTimestamp {
                                    remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                                    remainingCooldownSeconds = max(0, remainingCooldownSeconds)
                                    
                                    if remainingCooldownSeconds > 0 {
                                        component.showTimeoutTooltip(cooldownUntilTimestamp)
                                    } else {
                                        component.withdraw()
                                    }
                                } else {
                                    component.withdraw()
                                }
                            },
                            secondaryActionTitle: strings.Stars_BotRevenue_Withdraw_BuyAds,
                            secondaryAction: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.buyAds()
                            }
                        )
                    ))
                ]
            }
            
            let balanceSize = self.balanceView.update(
                transition: .immediate,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.Stars_BotRevenue_Withdraw_Balance.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(balanceInfoString),
                        maximumNumberOfLines: 0,
                        highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            if let controller = self?.controller?() as? StarsStatisticsScreen, let navigationController = controller.navigationController as? NavigationController {
                                component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Stars_BotRevenue_Withdraw_Info_URL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                            }
                        }
                    )),
                    items: balanceItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInsets, height: availableSize.height)
            )
            let balanceFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - balanceSize.width) / 2.0), y: contentHeight), size: balanceSize)
            if let balanceView = self.balanceView.view {
                if balanceView.superview == nil {
                    self.scrollView.addSubview(balanceView)
                }
                transition.setFrame(view: balanceView, frame: balanceFrame)
            }
            
            contentHeight += balanceSize.height
            contentHeight += 44.0
                    
            var panelItems: [StarsTransactionsPanelContainerComponent.Item] = []
            if "".isEmpty {
                let allTransactionsContext: StarsTransactionsContext
                if let current = self.allTransactionsContext {
                    allTransactionsContext = current
                } else {
                    allTransactionsContext = component.context.engine.payments.peerStarsTransactionsContext(subject: .peer(peerId: component.peerId, ton: false), mode: .all)
                    self.allTransactionsContext = allTransactionsContext
                }
                
                let incomingTransactionsContext: StarsTransactionsContext
                if let current = self.incomingTransactionsContext {
                    incomingTransactionsContext = current
                } else {
                    incomingTransactionsContext = component.context.engine.payments.peerStarsTransactionsContext(subject: .starsTransactionsContext(allTransactionsContext), mode: .incoming)
                    self.incomingTransactionsContext = incomingTransactionsContext
                }
                
                let outgoingTransactionsContext: StarsTransactionsContext
                if let current = self.outgoingTransactionsContext {
                    outgoingTransactionsContext = current
                } else {
                    outgoingTransactionsContext = component.context.engine.payments.peerStarsTransactionsContext(subject: .starsTransactionsContext(allTransactionsContext), mode: .outgoing)
                    self.outgoingTransactionsContext = outgoingTransactionsContext
                }
                
                panelItems.append(StarsTransactionsPanelContainerComponent.Item(
                    id: "all",
                    title: environment.strings.Stars_Intro_AllTransactions,
                    panel: AnyComponent(StarsTransactionsListPanelComponent(
                        context: component.context,
                        transactionsContext: allTransactionsContext,
                        isAccount: false,
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
                        isAccount: false,
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
                        isAccount: false,
                        action: { transaction in
                            component.openTransaction(transaction)
                        }
                    ))
                ))
            }
            
            var wasLockedAtPanels = false
            if let panelContainerView = self.panelContainer.view, let navigationMetrics = self.navigationMetrics {
                if self.scrollView.bounds.minY > 0.0 && abs(self.scrollView.bounds.minY - (panelContainerView.frame.minY - navigationMetrics.navigationHeight)) <= UIScreenPixel {
                    wasLockedAtPanels = true
                }
            }
            
            let panelTransition = transition
            if !panelItems.isEmpty {
                let panelContainerInset: CGFloat = self.listIsExpanded ? 0.0 : 16.0
                let panelContainerCornerRadius: CGFloat = self.listIsExpanded ? 0.0 : 11.0
                
                let panelContainerSize = self.panelContainer.update(
                    transition: panelTransition,
                    component: AnyComponent(StarsTransactionsPanelContainerComponent(
                        theme: environment.theme,
                        strings: environment.strings,
                        dateTimeFormat: environment.dateTimeFormat,
                        insets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left + panelContainerInset, bottom: environment.safeInsets.bottom, right: environment.safeInsets.right + panelContainerInset),
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
            
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            transition.setFrame(view: self.scrollContainerView, frame: CGRect(origin: CGPoint(), size: contentSize))
            
            var scrollViewBounds = self.scrollView.bounds
            scrollViewBounds.size = availableSize
            transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
                        
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

public final class StarsStatisticsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let revenueContext: StarsRevenueStatsContext
    
    private weak var tooltipScreen: UndoOverlayController?
    private var timer: Foundation.Timer?
    
    private let options = Promise<[StarsTopUpOption]>()
    
    public init(context: AccountContext, peerId: EnginePeer.Id, revenueContext: StarsRevenueStatsContext) {
        self.context = context
        self.peerId = peerId
        self.revenueContext = revenueContext
        
        var buyImpl: (() -> Void)?
        var withdrawImpl: (() -> Void)?
        var buyAdsImpl: (() -> Void)?
        var showTimeoutTooltipImpl: ((Int32) -> Void)?
        var openTransactionImpl: ((StarsContext.State.Transaction) -> Void)?
        super.init(context: context, component: StarsStatisticsScreenComponent(
            context: context,
            peerId: peerId,
            revenueContext: revenueContext,
            openTransaction: { transaction in
                openTransactionImpl?(transaction)
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
            buyAds: {
                buyAdsImpl?()
            }
        ), navigationBarAppearance: .transparent)
        
        self.navigationPresentation = .modalInLargeLayout
                
        openTransactionImpl = { [weak self] transaction in
            guard let self else {
                return
            }
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                let controller = context.sharedContext.makeStarsTransactionScreen(context: context, transaction: transaction, peer: peer)
                self.push(controller)
            })
        }
        
        if peerId == context.account.peerId {
            self.options.set(.single([]) |> then(context.engine.payments.starsTopUpOptions()))
        }
        
        buyImpl = { [weak self] in
            guard let self else {
                return
            }
            let _ = (self.options.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] options in
                guard let self, let starsContext = context.starsContext else {
                    return
                }
                let controller = context.sharedContext.makeStarsPurchaseScreen(context: context, starsContext: starsContext, options: options, purpose: .generic, completion: { [weak self] stars in
                    guard let self else {
                        return
                    }
                    starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                    
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
            
            let _ = (context.engine.peers.checkStarsRevenueWithdrawalAvailability()
            |> deliverOnMainQueue).start(error: { [weak self] error in
                guard let self else {
                    return
                }
                switch error {
                case .serverProvided:
                    return
                case .requestPassword:
                    let _ = (revenueContext.state
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] state in
                        guard let self, let stats = state.stats else {
                            return
                        }
                        let controller = self.context.sharedContext.makeStarsWithdrawalScreen(context: context, stats: stats, completion: { [weak self] amount in
                            guard let self else {
                                return
                            }
                            let controller = confirmStarsRevenueWithdrawalController(context: context, peerId: peerId, amount: amount, present: { [weak self] c, a in
                                self?.present(c, in: .window(.root))
                            }, completion: { url in
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                                
                                Queue.mainQueue().after(2.0) {
                                    revenueContext.reload()
                                    //TODO:
                                    //self?.transactionsContext.reload()
                                }
                            })
                            self.present(controller, in: .window(.root))
                        })
                        self.push(controller)
                    })
                default:
                    let controller = starsRevenueWithdrawalController(context: context, peerId: peerId, amount: 0, initialError: error, present: { [weak self] c, a in
                        self?.present(c, in: .window(.root))
                    }, completion: { _ in
                        
                    })
                    self.present(controller, in: .window(.root))
                }
            })
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
        
        buyAdsImpl = {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let _ = (context.engine.peers.requestStarsRevenueAdsAccountlUrl(peerId: peerId)
            |> deliverOnMainQueue).startStandalone(next: { url in
                guard let url else {
                    return
                }
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
            })
        }
                
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? StarsStatisticsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
}
