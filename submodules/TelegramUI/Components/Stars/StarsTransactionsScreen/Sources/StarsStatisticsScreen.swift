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

final class StarsStatisticsScreenComponent: Component {
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
    
    static func ==(lhs: StarsStatisticsScreenComponent, rhs: StarsStatisticsScreenComponent) -> Bool {
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
        
        private let titleView = ComponentView<Empty>()
        
        private let chartView = ComponentView<Empty>()
        private let proceedsView = ComponentView<Empty>()
        private let balanceView = ComponentView<Empty>()

        private let panelContainer = ComponentView<StarsTransactionsPanelContainerEnvironment>()
                                
        private var component: StarsStatisticsScreenComponent?
        private weak var state: EmptyComponentState?
        private var navigationMetrics: (navigationHeight: CGFloat, statusBarHeight: CGFloat)?
        private var controller: (() -> ViewController?)?
        
        private var enableVelocityTracking: Bool = false
        private var previousVelocityM1: CGFloat = 0.0
        private var previousVelocity: CGFloat = 0.0
        
        private var ignoreScrolling: Bool = false
        
        private var stateDisposable: Disposable?
        private var starsState: StarsContext.State?
        
        private var previousBalance: Int64?
        
        private var allTransactionsContext: StarsTransactionsContext?
        
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
                            
            let topContentOffset = self.scrollView.contentOffset.y
            let navigationBackgroundAlpha = min(20.0, max(0.0, topContentOffset - 95.0)) / 20.0
                            
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
            
            let _ = self.panelContainer.updateEnvironment(
                transition: transition,
                environment: {
                    StarsTransactionsPanelContainerEnvironment(isScrollable: isLockedAtPanels)
                }
            )
        }
                
        private var isUpdating = false
        func update(component: StarsStatisticsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
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
             
            contentHeight += environment.navigationHeight
            contentHeight += 31.0
            
            let titleSize = self.titleView.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "Stars Balance", font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor)),
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
            
            let proceedsSize = self.proceedsView.update(
                transition: .immediate,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Proceeds Overview".uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        VStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(name: "Premium/Stars/StarMedium", tintColor: nil))),
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(Int32(self.starsState?.balance ?? 0), environment.dateTimeFormat.groupingSeparator), font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))))),
                                AnyComponentWithIdentity(id: 2, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: formatUsdValue(self.starsState?.balance ?? 0, rate: 0.2), font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor))))),
                            ], spacing: 3.0))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Available Balance", font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor)))))
                        ], alignment: .left, spacing: 2.0)
                    )),
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(
                        VStack([
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(name: "Premium/Stars/StarMedium", tintColor: nil))),
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(Int32(self.starsState?.balance ?? 0) * 3, environment.dateTimeFormat.groupingSeparator), font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))))),
                                AnyComponentWithIdentity(id: 2, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: formatUsdValue((self.starsState?.balance ?? 0) * 3, rate: 0.2), font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor))))),
                            ], spacing: 3.0))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Total Lifetime Proceeds", font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor)))))
                        ], alignment: .left, spacing: 2.0)
                    ))],
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
            contentHeight += 44.0
            
            let termsFont = Font.regular(13.0)
            let termsTextColor = environment.theme.list.freeTextColor
            let termsMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), bold: MarkdownAttributeSet(font: termsFont, textColor: termsTextColor), link: MarkdownAttributeSet(font: termsFont, textColor: environment.theme.list.itemAccentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let balanceInfoString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString("You can withdraw Stars using Fragment, or use Stars to advertise your bot. [Learn More >]()", attributes: termsMarkdownAttributes, textAlignment: .natural
            ))
            if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
            }
            if let range = balanceInfoString.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                balanceInfoString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: balanceInfoString.string))
            }
                        
            let balanceSize = self.balanceView.update(
                transition: .immediate,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Available Balance".uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(balanceInfoString),
                        maximumNumberOfLines: 0
                    )),
                    items: [AnyComponentWithIdentity(id: 0, component: AnyComponent(
                        StarsBalanceComponent(
                            theme: environment.theme,
                            strings: environment.strings,
                            dateTimeFormat: environment.dateTimeFormat,
                            count: self.starsState?.balance ?? 0,
                            rate: 0.2,
                            actionTitle: "Withdraw via Fragment",
                            actionAvailable: true,
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
                transition.setFrame(view: balanceView, frame: balanceFrame)
            }
            
            contentHeight += balanceSize.height
            contentHeight += 44.0
            
            let initialTransactions = self.starsState?.transactions ?? []
            var panelItems: [StarsTransactionsPanelContainerComponent.Item] = []
            if !initialTransactions.isEmpty {
                let allTransactionsContext: StarsTransactionsContext
                if let current = self.allTransactionsContext {
                    allTransactionsContext = current
                } else {
                    allTransactionsContext = component.context.engine.payments.peerStarsTransactionsContext(starsContext: component.starsContext, subject: .all)
                }
                                
                panelItems.append(StarsTransactionsPanelContainerComponent.Item(
                    id: "all",
                    title: environment.strings.Stars_Intro_AllTransactions,
                    panel: AnyComponent(StarsTransactionsListPanelComponent(
                        context: component.context,
                        transactionsContext: allTransactionsContext,
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

public final class StarsStatisticsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let starsContext: StarsContext
        
    public init(context: AccountContext, starsContext: StarsContext, forceDark: Bool = false) {
        self.context = context
        self.starsContext = starsContext
        
        var withdrawImpl: (() -> Void)?
        var openTransactionImpl: ((StarsContext.State.Transaction) -> Void)?
        super.init(context: context, component: StarsStatisticsScreenComponent(
            context: context,
            starsContext: starsContext,
            openTransaction: { transaction in
                openTransactionImpl?(transaction)
            },
            buy: {
                withdrawImpl?()
            }
        ), navigationBarAppearance: .transparent)
        
        self.navigationPresentation = .modalInLargeLayout
                
        openTransactionImpl = { [weak self] transaction in
            guard let self else {
                return
            }
            let controller = context.sharedContext.makeStarsTransactionScreen(context: context, transaction: transaction)
            self.push(controller)
        }
        
        withdrawImpl = { [weak self] in
            guard let _ = self else {
                return
            }
        }
        
        self.starsContext.load(force: false)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
    }
}
