import Foundation
import UIKit
import LocalAuthentication
import Display
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import TextFormat
import ComponentFlow
import ViewControllerComponent
import ChatListHeaderComponent
import BundleIconComponent
import QrCodeUI
import ContextUI
import SwiftSignalKit
import TelegramCore
import TelegramNotices
import WalletContext
import WalletCardComponent
import EdgeEffect
import ButtonComponent
import ListSectionComponent
import ListActionItemComponent
import WalletCollectibleItemComponent
import WalletTransactionItemComponent
import WalletTransactionScreen
import InfoParagraphComponent
import MultilineTextComponent
import HorizontalTabsComponent
import GlassBackgroundComponent
import WalletSendScreen
import WalletPeerSelectionScreen
import SettingsUI
import UndoUI
import WalletAuthorizationUI
import PasscodeCore
import Markdown

private let walletSectionOverscan: CGFloat = 100.0
private let walletTransactionItemHeight: CGFloat = 79.0
private let walletCollectibleTransactionItemHeight: CGFloat = 132.0
private let walletCollectibleItemHeight: CGFloat = 58.0

private struct WalletItemsLayout {
    let itemOffsets: [CGFloat]

    var itemCount: Int {
        return self.itemOffsets.count - 1
    }

    var contentHeight: CGFloat {
        return self.itemOffsets.last ?? 0.0
    }

    init(itemHeights: [CGFloat]) {
        var itemOffsets: [CGFloat] = [0.0]
        itemOffsets.reserveCapacity(itemHeights.count + 1)
        for itemHeight in itemHeights {
            itemOffsets.append(itemOffsets[itemOffsets.count - 1] + itemHeight)
        }
        self.itemOffsets = itemOffsets
    }

    func itemOffset(at index: Int) -> CGFloat {
        return self.itemOffsets[index]
    }

    func visibleItems(for rect: CGRect) -> Range<Int>? {
        guard self.itemCount != 0, rect.maxY > 0.0, rect.minY < self.contentHeight else {
            return nil
        }

        let minY = max(0.0, rect.minY)
        let maxY = min(self.contentHeight, rect.maxY)

        var lowerBound = 0
        var upperBound = self.itemCount
        while lowerBound < upperBound {
            let index = (lowerBound + upperBound) / 2
            if self.itemOffsets[index + 1] <= minY {
                lowerBound = index + 1
            } else {
                upperBound = index
            }
        }
        let minIndex = lowerBound

        lowerBound = minIndex
        upperBound = self.itemCount
        while lowerBound < upperBound {
            let index = (lowerBound + upperBound) / 2
            if self.itemOffsets[index] < maxY {
                lowerBound = index + 1
            } else {
                upperBound = index
            }
        }
        let maxIndex = lowerBound

        if minIndex < maxIndex {
            return minIndex ..< maxIndex
        } else {
            return nil
        }
    }
}

private final class LazySectionView: UIView {
    struct Item {
        let id: AnyHashable
        let height: CGFloat
        let component: () -> AnyComponent<Empty>
    }

    private enum PlaceholderId: Hashable {
        case top
        case bottom
    }

    private let contentView: ListSectionContentView
    private let topPlaceholderView: ListSectionContentView.ItemView
    private let bottomPlaceholderView: ListSectionContentView.ItemView
    private var footer: ComponentView<Empty>?

    private var items: [Item] = []
    private var itemLayout = WalletItemsLayout(itemHeights: [])
    private var configuration: ListSectionContentView.Configuration?
    private weak var state: EmptyComponentState?
    private var width: CGFloat = 0.0
    private var currentVisibleRange: Range<Int>?

    private final class LiftedItem {
        weak var parent: UIView?
        weak var view: ListSectionContentView.ItemView?
        init(view: ListSectionContentView.ItemView) { self.parent = view.superview; self.view = view }
    }
    private var liftedIds = Set<AnyHashable>()
    private var liftedItems: [AnyHashable: LiftedItem] = [:]

    func itemFrame(id: AnyHashable) -> CGRect? {
        guard let index = self.items.firstIndex(where: { $0.id == id }) else { return nil }
        return CGRect(x: 0.0, y: self.itemLayout.itemOffset(at: index), width: self.width, height: self.items[index].height)
    }

    func itemView(id: AnyHashable) -> ListSectionContentView.ItemView? {
        return self.contentView.itemViews[id]
    }

    func setLiftedItems(_ ids: Set<AnyHashable>) {
        self.liftedIds = ids
        for (id, item) in self.liftedItems where !ids.contains(id) || self.contentView.itemViews[id] !== item.view {
            if let view = item.view {
                view.transform = .identity
                view.layer.zPosition = 0.0
                view.separatorLayer.isHidden = false
                if self.contentView.itemViews[id] === view { item.parent?.addSubview(view) }
            }
            self.liftedItems.removeValue(forKey: id)
        }
        for id in ids {
            guard let view = self.contentView.itemViews[id], view.superview != nil else { continue }
            if view.superview !== self {
                self.liftedItems[id] = LiftedItem(view: view)
                self.addSubview(view)
            }
        }
    }

    override init(frame: CGRect) {
        self.contentView = ListSectionContentView(frame: CGRect())
        self.topPlaceholderView = ListSectionContentView.ItemView()
        self.bottomPlaceholderView = ListSectionContentView.ItemView()

        super.init(frame: frame)

        self.addSubview(self.contentView.externalContentBackgroundView)
        self.addSubview(self.contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        theme: PresentationTheme,
        state: EmptyComponentState,
        items: [Item],
        footer footerComponent: AnyComponent<Empty>?,
        width: CGFloat,
        visibleBounds: CGRect,
        transition: ComponentTransition
    ) -> CGSize {
        self.items = items
        self.itemLayout = WalletItemsLayout(itemHeights: items.map(\.height))
        self.configuration = ListSectionContentView.Configuration(
            theme: theme,
            style: .glass,
            displaySeparators: true,
            extendsItemHighlightToSection: false,
            background: .all
        )
        self.state = state
        self.width = width

        self.updateVisibleBounds(visibleBounds, force: true, transition: transition)

        var contentHeight = self.itemLayout.contentHeight
        if let footerComponent {
            let footer: ComponentView<Empty>
            var footerTransition = transition
            if let current = self.footer {
                footer = current
            } else {
                footer = ComponentView()
                self.footer = footer
                footerTransition = footerTransition.withAnimation(.none)
            }
            footer.parentState = state
            let footerSize = footer.update(
                transition: footerTransition,
                component: footerComponent,
                environment: {},
                containerSize: CGSize(width: max(0.0, width - 32.0), height: 1000.0)
            )
            if contentHeight != 0.0 {
                contentHeight += 8.0 - UIScreenPixel
            }
            if let footerView = footer.view {
                if footerView.superview == nil {
                    self.addSubview(footerView)
                }
                footerTransition.setFrame(
                    view: footerView,
                    frame: CGRect(
                        origin: CGPoint(x: 16.0, y: contentHeight),
                        size: footerSize
                    )
                )
            }
            contentHeight += footerSize.height
        } else if let footer = self.footer {
            self.footer = nil
            footer.view?.removeFromSuperview()
        }

        return CGSize(width: width, height: contentHeight)
    }

    func updateVisibleBounds(_ visibleBounds: CGRect, force: Bool = false, transition: ComponentTransition) {
        guard let configuration = self.configuration, let state = self.state else {
            return
        }

        let visibleRange = self.itemLayout.visibleItems(for: visibleBounds)
        if !force && self.currentVisibleRange == visibleRange {
            return
        }
        self.currentVisibleRange = visibleRange
        for item in self.liftedItems.values { item.view?.transform = .identity }
        var readyItems: [ListSectionContentView.ReadyItem] = []
        if let visibleRange {
            let topHeight = self.itemLayout.itemOffset(at: visibleRange.lowerBound)
            if topHeight != 0.0 {
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: AnyHashable(PlaceholderId.top),
                    itemView: self.topPlaceholderView,
                    size: CGSize(width: self.width, height: topHeight),
                    transition: .immediate
                ))
            }

            for index in visibleRange {
                let item = self.items[index]
                let itemView: ListSectionContentView.ItemView
                var itemTransition = transition
                if let current = self.contentView.itemViews[item.id] {
                    itemView = current
                } else {
                    itemView = ListSectionContentView.ItemView()
                    self.contentView.itemViews[item.id] = itemView
                    itemView.contents.parentState = state
                    itemTransition = .immediate
                }

                let itemSize = itemView.contents.update(
                    transition: itemTransition,
                    component: item.component(),
                    environment: {},
                    containerSize: CGSize(width: self.width, height: item.height)
                )
                assert(
                    abs(itemSize.height - item.height) <= UIScreenPixel,
                    "Unexpected wallet item height: expected \(item.height), got \(itemSize.height)"
                )
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: item.id,
                    itemView: itemView,
                    size: CGSize(width: self.width, height: item.height),
                    transition: itemTransition
                ))
            }

            let bottomHeight = self.itemLayout.contentHeight - self.itemLayout.itemOffset(at: visibleRange.upperBound)
            if bottomHeight != 0.0 {
                readyItems.append(ListSectionContentView.ReadyItem(
                    id: AnyHashable(PlaceholderId.bottom),
                    itemView: self.bottomPlaceholderView,
                    size: CGSize(width: self.width, height: bottomHeight),
                    transition: .immediate
                ))
            }
        } else if self.itemLayout.contentHeight != 0.0 {
            readyItems.append(ListSectionContentView.ReadyItem(
                id: AnyHashable(PlaceholderId.top),
                itemView: self.topPlaceholderView,
                size: CGSize(width: self.width, height: self.itemLayout.contentHeight),
                transition: .immediate
            ))
        }

        let updateResult = self.contentView.update(
            configuration: configuration,
            width: self.width,
            leftInset: 0.0,
            readyItems: readyItems,
            transition: transition
        )
        transition.setFrame(
            view: self.contentView,
            frame: CGRect(origin: CGPoint(), size: updateResult.size)
        )
        self.setLiftedItems(self.liftedIds)
    }

    func clearVisibleItems() {
        self.updateVisibleBounds(
            CGRect(x: 0.0, y: self.itemLayout.contentHeight, width: self.width, height: 0.0),
            force: true,
            transition: .immediate
        )
    }
}

private final class WalletNavigationBalanceComponent: Component {
    typealias EnvironmentType = Empty

    let theme: PresentationTheme
    let balance: Int64?
    let fiatCurrency: WalletContext.FiatCurrency
    let fiatRate: WalletContext.FiatRate?
    let dateTimeFormat: PresentationDateTimeFormat

    init(
        theme: PresentationTheme,
        balance: Int64?,
        fiatCurrency: WalletContext.FiatCurrency,
        fiatRate: WalletContext.FiatRate?,
        dateTimeFormat: PresentationDateTimeFormat
    ) {
        self.theme = theme
        self.balance = balance
        self.fiatCurrency = fiatCurrency
        self.fiatRate = fiatRate
        self.dateTimeFormat = dateTimeFormat
    }

    static func ==(lhs: WalletNavigationBalanceComponent, rhs: WalletNavigationBalanceComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.balance != rhs.balance {
            return false
        }
        if lhs.fiatCurrency != rhs.fiatCurrency || lhs.fiatRate != rhs.fiatRate {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        return true
    }

    final class View: UIView {
        private let primaryCollapseContainerView = UIView()
        private let secondaryCollapseContainerView = UIView()
        private let primaryContainerView = UIView()
        private let secondaryContainerView = UIView()
        private let balanceText = ComponentView<Empty>()
        private let gramIcon = ComponentView<Empty>()
        private let fiatText = ComponentView<Empty>()

        var primaryTargetFrame: CGRect = .zero
        var secondaryTargetFrame: CGRect = .zero

        var primaryContentLayout: (size: CGSize, text: CGRect, icon: CGRect)? {
            guard let textView = self.balanceText.view, let iconView = self.gramIcon.view else {
                return nil
            }
            return (self.primaryTargetFrame.size, textView.frame, iconView.frame)
        }

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.clipsToBounds = false
            self.primaryCollapseContainerView.clipsToBounds = false
            self.secondaryCollapseContainerView.clipsToBounds = false
            self.primaryContainerView.clipsToBounds = false
            self.secondaryContainerView.clipsToBounds = false
            self.addSubview(self.primaryCollapseContainerView)
            self.addSubview(self.secondaryCollapseContainerView)
            self.primaryCollapseContainerView.addSubview(self.primaryContainerView)
            self.secondaryCollapseContainerView.addSubview(self.secondaryContainerView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletNavigationBalanceComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let formattedBalance: String
            if let balance = component.balance {
                formattedBalance = formatTonAmountText(
                    balance,
                    dateTimeFormat: component.dateTimeFormat,
                    maxDecimalPositions: 2
                )
            } else {
                formattedBalance = "0"
            }

            let formattedFiatBalance: String
            if let balance = component.balance, let fiatRate = component.fiatRate {
                formattedFiatBalance = formatTonFiatValue(
                    balance,
                    divide: true,
                    rate: fiatRate.unitsPerGram,
                    currencySymbol: component.fiatCurrency.symbol,
                    maxDecimalPositions: balance == 0 ? 0 : 2,
                    dateTimeFormat: component.dateTimeFormat
                )
            } else {
                formattedFiatBalance = "—"
            }

            let primaryColor = component.theme.rootController.navigationBar.primaryTextColor
            let secondaryColor = component.theme.rootController.navigationBar.secondaryTextColor
            let iconSize = self.gramIcon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: "Wallet/TopGram",
                    tintColor: nil,
                    maxSize: CGSize(width: 20.0, height: 20.0)
                )),
                environment: {},
                containerSize: CGSize(width: 20.0, height: 20.0)
            )
            let balanceSpacing: CGFloat = 2.0
            let balanceAttributedString = NSMutableAttributedString(string: formattedBalance, attributes: [
                .font: Font.with(size: 17.0, weight: .semibold, traits: .monospacedNumbers),
                .foregroundColor: primaryColor
            ])
            if let decimalRange = formattedBalance.range(of: component.dateTimeFormat.decimalSeparator) {
                balanceAttributedString.addAttribute(
                    .font,
                    value: Font.with(size: 14.0, weight: .semibold, traits: .monospacedNumbers),
                    range: NSRange(decimalRange.lowerBound ..< formattedBalance.endIndex, in: formattedBalance)
                )
            }
            let balanceSize = self.balanceText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(balanceAttributedString),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(0.0, availableSize.width - balanceSpacing - iconSize.width),
                    height: availableSize.height
                )
            )
            let fiatSize = self.fiatText.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: formattedFiatBalance,
                        font: Font.regular(13.0),
                        textColor: secondaryColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )

            let balanceRowSize = CGSize(
                width: balanceSize.width + balanceSpacing + iconSize.width,
                height: max(balanceSize.height, iconSize.height)
            )
            let verticalSpacing: CGFloat = 0.0
            let size = CGSize(
                width: max(balanceRowSize.width, fiatSize.width),
                height: balanceRowSize.height + verticalSpacing + fiatSize.height
            )

            for collapseContainerView in [self.primaryCollapseContainerView, self.secondaryCollapseContainerView] {
                ComponentTransition.immediate.setBounds(
                    view: collapseContainerView,
                    bounds: CGRect(origin: CGPoint(), size: size)
                )
                ComponentTransition.immediate.setPosition(
                    view: collapseContainerView,
                    position: CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                )
            }

            self.primaryTargetFrame = CGRect(
                origin: CGPoint(
                    x: floor((size.width - balanceRowSize.width) * 0.5),
                    y: 0.0
                ),
                size: balanceRowSize
            )
            self.secondaryTargetFrame = CGRect(
                origin: CGPoint(
                    x: floor((size.width - fiatSize.width) * 0.5),
                    y: balanceRowSize.height + verticalSpacing
                ),
                size: fiatSize
            )
            ComponentTransition.immediate.setBounds(
                view: self.primaryContainerView,
                bounds: CGRect(origin: CGPoint(), size: balanceRowSize)
            )
            ComponentTransition.immediate.setPosition(
                view: self.primaryContainerView,
                position: self.primaryTargetFrame.center
            )
            ComponentTransition.immediate.setBounds(
                view: self.secondaryContainerView,
                bounds: CGRect(origin: CGPoint(), size: fiatSize)
            )
            ComponentTransition.immediate.setPosition(
                view: self.secondaryContainerView,
                position: self.secondaryTargetFrame.center
            )

            if let balanceTextView = self.balanceText.view {
                if balanceTextView.superview !== self.primaryContainerView {
                    self.primaryContainerView.addSubview(balanceTextView)
                }
                transition.setFrame(
                    view: balanceTextView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: iconSize.width + balanceSpacing,
                            y: floor((balanceRowSize.height - balanceSize.height) * 0.5)
                        ),
                        size: balanceSize
                    )
                )
            }
            if let gramIconView = self.gramIcon.view {
                if gramIconView.superview !== self.primaryContainerView {
                    self.primaryContainerView.addSubview(gramIconView)
                }
                transition.setFrame(
                    view: gramIconView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: 1.0,
                            y: floor((balanceRowSize.height - iconSize.height) * 0.5) - UIScreenPixel
                        ),
                        size: iconSize
                    )
                )
            }
            if let fiatTextView = self.fiatText.view {
                if fiatTextView.superview !== self.secondaryContainerView {
                    self.secondaryContainerView.addSubview(fiatTextView)
                }
                transition.setFrame(
                    view: fiatTextView,
                    frame: CGRect(origin: CGPoint(), size: fiatSize)
                )
            }

            return size
        }

        func updateTransitionFrames(
            primaryFrame: CGRect?,
            secondaryFrame: CGRect?,
            collapseFraction: CGFloat,
            transition: ComponentTransition
        ) {
            self.updateTransitionContainer(
                self.primaryCollapseContainerView,
                self.primaryContainerView,
                targetFrame: self.primaryTargetFrame,
                currentFrame: primaryFrame,
                collapseFraction: collapseFraction,
                transition: transition
            )
            self.updateTransitionContainer(
                self.secondaryCollapseContainerView,
                self.secondaryContainerView,
                targetFrame: self.secondaryTargetFrame,
                currentFrame: secondaryFrame,
                collapseFraction: collapseFraction,
                transition: transition
            )
        }

        private func updateTransitionContainer(
            _ collapseContainerView: UIView,
            _ containerView: UIView,
            targetFrame: CGRect,
            currentFrame: CGRect?,
            collapseFraction: CGFloat,
            transition: ComponentTransition
        ) {
            guard !targetFrame.isEmpty,
                  let currentFrame,
                  !currentFrame.isEmpty,
                  currentFrame.width.isFinite,
                  currentFrame.height.isFinite else {
                transition.setPosition(view: containerView, position: targetFrame.center)
                transition.setTransform(view: containerView, transform: CATransform3DIdentity)
                transition.setTransform(view: collapseContainerView, transform: CATransform3DIdentity)
                return
            }

            let scaleX = currentFrame.width / targetFrame.width
            let scaleY = currentFrame.height / targetFrame.height
            transition.setPosition(view: containerView, position: currentFrame.center)
            transition.setTransform(
                view: containerView,
                transform: CATransform3DMakeScale(scaleX, scaleY, 1.0)
            )
            transition.setTransform(
                view: collapseContainerView,
                transform: self.collapseTransform(
                    in: collapseContainerView,
                    from: currentFrame,
                    to: targetFrame,
                    fraction: collapseFraction
                )
            )
        }

        private func collapseTransform(in containerView: UIView, from sourceFrame: CGRect, to targetFrame: CGRect, fraction: CGFloat) -> CATransform3D {
            let scaleX = targetFrame.width / sourceFrame.width
            let scaleY = targetFrame.height / sourceFrame.height
            let anchor = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
            var transform = CATransform3DMakeScale(1.0 + (scaleX - 1.0) * fraction, 1.0 + (scaleY - 1.0) * fraction, 1.0)
            transform.m41 = (targetFrame.midX - anchor.x - (sourceFrame.midX - anchor.x) * scaleX) * fraction
            transform.m42 = (targetFrame.midY - anchor.y - (sourceFrame.midY - anchor.y) * scaleY) * fraction
            return transform
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

private final class WalletScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    let walletContext: WalletContext

    init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        walletContext: WalletContext
    ) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.walletContext = walletContext
    }

    static func ==(lhs: WalletScreenComponent, rhs: WalletScreenComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.updatedPresentationData.initial === rhs.updatedPresentationData.initial
            && lhs.updatedPresentationData.signal === rhs.updatedPresentationData.signal
            && lhs.walletContext === rhs.walletContext
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }

    private final class BalanceContainerView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            return result === self ? nil : result
        }
    }

    final class View: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        private enum SelectedSection: Equatable {
            case transactions
            case collectibles
        }

        private let cardSpacing: CGFloat = 12.0
        private let cardCollapsedScale: CGFloat = 0.19
        private let cardCollapsedPitch: CGFloat = .pi / 3.0

        private let scrollView: ScrollView
        private let topContentContainerView = UIView()
        private let topEdgeEffectView: EdgeEffectView
        private let header = ComponentView<Empty>()
        private let navigationTitle = ComponentView<Empty>()
        private let navigationBalance = ComponentView<Empty>()
        private let navigationBalanceButton = UIButton(type: .custom)
        private let cardContainerView: UIView
        private let cardBalanceCoordinateView: UIView
        private let cardVisualContainerView: UIView
        private let cardBalanceClippingView = BalanceContainerView()
        private let navigationBalanceClippingView = UIView()
        private let cardBalanceMaskLayer = CAShapeLayer()
        private let navigationBalanceMaskLayer = CAShapeLayer()
        private let additionalBalancesSection = ComponentView<Empty>()
        private var additionalBalancesIsVisible = false
        private var additionalBalancesVisibilityGeneration: UInt64 = 0
        private let earningsIcon = UIImage(bundleImageName: "Wallet/TransactionGram")?.withRenderingMode(.alwaysOriginal)
        private let card = ComponentView<Empty>()
        private var gramTooltip: ComponentView<Empty>?
        private let gramTooltipTapGestureRecognizer = UITapGestureRecognizer()
        private var gramTooltipTimer: Foundation.Timer?
        private let addFundsButton = ComponentView<Empty>()
        private let sendButton = ComponentView<Empty>()
        private let accountProtectionSection = ComponentView<Empty>()
        private let transactionTabsBackgroundView = GlassBackgroundView()
        private let transactionTabs = ComponentView<Empty>()
        private let transactionsSection = LazySectionView()
        private var pendingTransferAnimations: [String: WalletPendingTransferAnimation] = [:]
        private var newTransferPresentationIds = Set<String>()
        private var pendingTransferToReveal: String?
        private var shouldRevealLatestTransactions = false
        private var transferDisplayLink: SharedDisplayLinkDriver.Link?
        private var transferScreenVisible = true
        private var isReturningForTransfer = false
        private var transferApplicationInForeground = UIApplication.shared.applicationState != .background
        private let transferForegroundDisposable = MetaDisposable()
        private var transferMotionObserver: NSObjectProtocol?
        private var isUpdatingTransferAnimations = false

        private let collectiblesSection = LazySectionView()
        private let emptyTransactionsInfo = ComponentView<Empty>()
        private let emptyTransactionsFooter = ComponentView<Empty>()
        private let accountProtectionIcon = renderSettingsIcon(
            name: "Item List/Icons/Warning",
            backgroundColors: [UIColor(rgb: 0xff453a)]
        )

        private var component: WalletScreenComponent?
        private var environment: EnvironmentType?
        private var componentState: EmptyComponentState?

        private var walletContext: WalletContext?
        private var walletState: WalletContext.State?
        private var walletStateDisposable: Disposable?
        private var suppressedCollectibleAddresses = Set<String>()
        private var suppressedCollectiblesWalletAddress: String?
        private let loadMoreDisposable = MetaDisposable()
        private var nextLoadMoreRequestId: Int = 0
        private var loadMoreRequestId: Int?
        private let gramTooltipDisposable = MetaDisposable()
        private let signingAccessDisposable = MetaDisposable()
        private let peerAddressDisposable = MetaDisposable()
        private var restorationSession: PasscodeSession?
        private var restorationGeneration = 0
        private var accountContext: AccountContext?
        private var accountName = ""
        private var accountPeerDisposable: Disposable?
        private var existingWaltBalance: WalletExistingBalance?
        private let existingWaltBalanceDisposable = MetaDisposable()
        private var isLoadingExistingWaltBalance = false
        private var previousWalletsBalance: Int64 = 0
        private let previousWalletsDisposable = MetaDisposable()
        private var previousWalletsGeneration: UInt64 = 0
        private let earningsDisposable = MetaDisposable()
        private let waltBalanceBotAppDisposable = MetaDisposable()
        private var isOpeningWaltBalance = false
        private var isWaitingForWaltBalanceUrl = false
        private var earningsContext: StarsRevenueStatsContext?
        private var availableEarnings: CurrencyAmount?
        private var twoStepAuthData: Promise<TwoStepAuthData?>?
        private var twoStepAuthDataDisposable: Disposable?
        private var hasTwoStepAuth: Bool?
        private var isAwaitingAccountProtectionResult = false
        private var isUpdating = false
        private var isGramTooltipPresentationPending = false
        private var gramTooltipGeneration = 0
        private var isDismissingGramTooltip = false
        private var didPresentGramTooltip = false
        private var gramTooltipWalletAddress: String?
        private var isResolvingSigningAccess = false
        private var selectedSection: SelectedSection = .transactions
        private var cardExpandedFrame: CGRect?
        private var cardTransitionStart: CGFloat = 0.0

        private var cardTransitionDistance: CGFloat {
            guard let cardExpandedFrame = self.cardExpandedFrame else {
                return 0.0
            }
            return cardExpandedFrame.height + self.cardSpacing
        }

        private var cardTransitionFraction: CGFloat {
            guard self.cardTransitionDistance > 0.0 else {
                return 0.0
            }
            return max(0.0, min(1.0, (self.scrollView.contentOffset.y - self.cardTransitionStart) / self.cardTransitionDistance))
        }

        private var cardScrollOffset: CGFloat {
            let fraction = self.cardTransitionFraction
            return self.scrollView.contentOffset.y - self.cardTransitionDistance * 0.6 * fraction * (1.0 - fraction)
        }

        private func currentPresentationData(for component: WalletScreenComponent) -> (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            return (
                initial: presentationData.withUpdated(theme: self.environment?.theme ?? component.updatedPresentationData.initial.theme),
                signal: component.updatedPresentationData.signal
            )
        }
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.topEdgeEffectView = EdgeEffectView()
            self.cardContainerView = UIView()
            self.cardBalanceCoordinateView = BalanceContainerView()
            self.cardVisualContainerView = UIView()
            self.cardContainerView.clipsToBounds = false
            self.cardVisualContainerView.clipsToBounds = false
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.scrollView.delegate = self
            self.gramTooltipTapGestureRecognizer.addTarget(self, action: #selector(self.gramTooltipTap(_:)))
            self.gramTooltipTapGestureRecognizer.delegate = self
            self.gramTooltipTapGestureRecognizer.cancelsTouchesInView = false
            self.gramTooltipTapGestureRecognizer.delaysTouchesBegan = false
            self.gramTooltipTapGestureRecognizer.delaysTouchesEnded = false
            self.gramTooltipTapGestureRecognizer.isEnabled = false
            self.addGestureRecognizer(self.gramTooltipTapGestureRecognizer)
            self.topEdgeEffectView.alpha = 0.0
            self.topEdgeEffectView.isUserInteractionEnabled = false

            self.navigationBalanceClippingView.isUserInteractionEnabled = false
            self.cardBalanceMaskLayer.fillColor = UIColor.black.cgColor
            self.navigationBalanceMaskLayer.fillColor = UIColor.black.cgColor
            self.cardBalanceMaskLayer.contentsScale = UIScreen.main.scale
            self.navigationBalanceMaskLayer.contentsScale = UIScreen.main.scale
            self.cardBalanceClippingView.layer.mask = self.cardBalanceMaskLayer
            self.navigationBalanceClippingView.layer.mask = self.navigationBalanceMaskLayer
            self.cardContainerView.addSubview(self.cardVisualContainerView)
            self.cardBalanceClippingView.addSubview(self.cardBalanceCoordinateView)
            self.addSubview(self.scrollView)
            self.scrollView.addSubview(self.topContentContainerView)
            self.addSubview(self.topEdgeEffectView)
            self.insertSubview(self.cardContainerView, aboveSubview: self.topEdgeEffectView)
            self.insertSubview(self.navigationBalanceClippingView, belowSubview: self.cardContainerView)
            self.insertSubview(self.cardBalanceClippingView, aboveSubview: self.cardContainerView)
            self.addSubview(self.navigationBalanceButton)
            self.navigationBalanceButton.addTarget(
                self,
                action: #selector(self.navigationBalancePressed),
                for: .touchUpInside
            )
            
            self.transactionsSection.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            self.transferMotionObserver = NotificationCenter.default.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.updatePendingTransferAnimations()
            }
            self.collectiblesSection.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            self.updatePendingTransferAnimations()

            if self.window == nil {
                self.dismissGramTooltip(animated: false)
            } else if let cardView = self.card.view as? WalletCardComponent.View {
                self.maybePresentGramTooltip(cardView: cardView)
            }
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            guard result.isDescendant(of: self.cardVisualContainerView) else {
                return result
            }

            var currentView: UIView? = result
            while let current = currentView, current !== self.cardVisualContainerView {
                if current is UIControl {
                    return result
                }
                currentView = current.superview
            }
            return self.scrollView
        }

        deinit {
            self.transferDisplayLink?.invalidate()
            self.transferForegroundDisposable.dispose()
            if let observer = self.transferMotionObserver { NotificationCenter.default.removeObserver(observer) }
            self.restorationSession?.invalidate()
            (self.card.view as? WalletCardComponent.View)?.setBalanceTransitionContainer(nil)
            self.walletStateDisposable?.dispose()
            self.accountPeerDisposable?.dispose()
            self.existingWaltBalanceDisposable.dispose()
            self.previousWalletsDisposable.dispose()
            self.earningsDisposable.dispose()
            self.waltBalanceBotAppDisposable.dispose()
            self.twoStepAuthDataDisposable?.dispose()
            self.loadMoreDisposable.dispose()
            self.gramTooltipDisposable.dispose()
            self.gramTooltipTimer?.invalidate()
            self.signingAccessDisposable.dispose()
            self.peerAddressDisposable.dispose()
        }

        func refreshTwoStepAuth() {
            guard let component = self.component, self.accountContext === component.context else {
                return
            }

            let updatedData = component.context.engine.auth.twoStepAuthData()
            |> map(Optional.init)
            |> `catch` { _ -> Signal<TwoStepAuthData?, NoError> in
                return .single(nil)
            }
            |> beforeNext { [weak self] data in
                guard let self, self.isAwaitingAccountProtectionResult else {
                    return
                }
                self.isAwaitingAccountProtectionResult = false

                guard data?.currentPasswordDerivation != nil else {
                    return
                }
                Queue.mainQueue().after(0.4) { [weak self] in
                    self?.presentPasswordSetToast()
                }
            }
            component.context.twoStepAuthData.set(updatedData)
        }

        private var additionalBalancesTransition: ComponentTransition {
            if self.environment?.isVisible == true && self.window != nil {
                return .easeInOut(duration: 0.25)
            }
            return .immediate
        }

        private func loadExistingWaltBalance() {
            guard let component = self.component,
                  self.accountContext === component.context,
                  !self.isLoadingExistingWaltBalance else {
                return
            }

            let context = component.context
            self.isLoadingExistingWaltBalance = true
            self.existingWaltBalanceDisposable.set((context.engine.wallet.getExistingWaltBalance()
            |> deliverOnMainQueue).start(next: { [weak self] balance in
                guard let self, self.accountContext === context else {
                    return
                }
                let balanceChanged = self.existingWaltBalance != balance
                self.existingWaltBalance = balance

                if let balance, let url = balance.url {
                    if !balance.hasBalance {
                        self.cancelWaltBalanceOpening()
                    } else if self.isWaitingForWaltBalanceUrl {
                        self.isWaitingForWaltBalanceUrl = false
                        self.openWaltBalance(url: url)
                    }
                }

                if balanceChanged && !self.isUpdating {
                    self.componentState?.updated(transition: self.additionalBalancesTransition)
                }
            }, completed: { [weak self] in
                guard let self, self.accountContext === context else {
                    return
                }
                self.isLoadingExistingWaltBalance = false
                if self.isWaitingForWaltBalanceUrl {
                    self.presentWaltBalanceError()
                }
            }))
        }

        func reloadPreviousWallets() {
            guard let walletContext = self.walletContext else {
                return
            }
            self.previousWalletsGeneration &+= 1
            let generation = self.previousWalletsGeneration
            self.previousWalletsDisposable.set((walletContext.previousWallets(refreshBalances: true)
            |> deliverOnMainQueue).start(next: { [weak self] previousWallets in
                guard let self,
                      self.previousWalletsGeneration == generation,
                      self.walletContext === walletContext else {
                    return
                }
                var seenAddresses = Set<String>()
                let balance = previousWallets
                    .sorted { $0.lastUsedAt > $1.lastUsedAt }
                    .filter { seenAddresses.insert($0.address).inserted }
                    .reduce(Int64(0)) { $0 + ($1.balance ?? 0) }
                if self.previousWalletsBalance != balance {
                    self.previousWalletsBalance = balance
                    if !self.isUpdating {
                        self.componentState?.updated(transition: self.additionalBalancesTransition)
                    }
                }
            }))
        }

        private func openWaltBalance() {
            guard let component = self.component,
                  self.accountContext === component.context,
                  self.walletInfo != nil,
                  self.existingWaltBalance?.hasBalance == true,
                  self.environment?.controller() != nil,
                  !self.isOpeningWaltBalance else {
                return
            }

            self.isOpeningWaltBalance = true
            if let url = self.existingWaltBalance?.url {
                self.openWaltBalance(url: url)
            } else {
                self.isWaitingForWaltBalanceUrl = true
                self.loadExistingWaltBalance()
            }
        }

        private func openWaltBalance(url: String) {
            guard let component = self.component,
                  let walletInfo = self.walletInfo,
                  self.environment?.controller() != nil,
                  self.isOpeningWaltBalance else {
                self.cancelWaltBalanceOpening()
                return
            }
            guard !url.isEmpty else {
                self.presentWaltBalanceError()
                return
            }

            let context = component.context
            let walletContext = component.walletContext
            let address = walletInfo.address

            self.waltBalanceBotAppDisposable.set((context.sharedContext.resolveUrl(
                context: context,
                peerId: nil,
                url: url,
                skipUrlAuth: true
            )
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self,
                      self.component?.context === context,
                      self.component?.walletContext === walletContext,
                      self.walletInfo?.address == address,
                      self.isOpeningWaltBalance else {
                    return
                }
                self.isOpeningWaltBalance = false
                guard case let .peer(peer, .withBotApp(botAppStart)) = result, let botPeer = peer.flatMap(EnginePeer.init) else {
                    self.presentWaltBalanceError()
                    return
                }
                guard let controller = self.environment?.controller() else {
                    return
                }
                let navigationController = (controller.navigationController as? NavigationController)
                    ?? (context.sharedContext.mainWindow?.viewController as? NavigationController)
                guard let parentController = navigationController?.viewControllers.last as? ViewController else {
                    self.presentWaltBalanceError()
                    return
                }
                context.sharedContext.openBotApp(
                    context: context,
                    parentController: parentController,
                    botApp: botAppStart.botApp,
                    botPeer: botPeer,
                    payload: botAppStart.payload,
                    mode: botAppStart.mode,
                    isOnramp: true,
                    willOpen: {},
                    completion: {}
                )
            }, completed: { [weak self] in
                guard let self,
                      self.component?.context === context,
                      self.component?.walletContext === walletContext,
                      self.walletInfo?.address == address,
                      self.isOpeningWaltBalance else {
                    return
                }
                self.presentWaltBalanceError()
            }))
        }

        private func cancelWaltBalanceOpening() {
            self.isOpeningWaltBalance = false
            self.isWaitingForWaltBalanceUrl = false
            self.waltBalanceBotAppDisposable.set(nil)
        }

        private func presentWaltBalanceError() {
            self.cancelWaltBalanceOpening()
            if let balance = self.existingWaltBalance {
                self.existingWaltBalance = WalletExistingBalance(hasBalance: balance.hasBalance, url: nil)
            }
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = self.currentPresentationData(for: component).initial
            controller.present(textAlertController(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                title: nil,
                text: presentationData.strings.Login_UnknownError,
                actions: [
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                ]
            ), in: .window(.root))
        }

        private func openEarnings() {
            guard let component = self.component,
                  let tonContext = component.context.tonContext,
                  let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeStarsTransactionsScreen(context: component.context, starsContext: tonContext))
        }

        private func updateAdditionalBalancesSection(
            environment: EnvironmentType,
            state: EmptyComponentState,
            origin: CGPoint,
            width: CGFloat,
            transition: ComponentTransition
        ) -> CGFloat {
            var items: [AnyComponentWithIdentity<Empty>] = []
            func appendItem(id: String, title: NSAttributedString, action: @escaping () -> Void) {
                items.append(AnyComponentWithIdentity(id: id, component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(title),
                        maximumNumberOfLines: 0
                    )),
                    accessory: .arrow,
                    action: { _ in
                        action()
                    }
                ))))
            }

            let font = Font.medium(15.0)
            let textColor = environment.theme.list.itemPrimaryTextColor
            if self.existingWaltBalance?.hasBalance == true {
                items.append(AnyComponentWithIdentity(id: "walt", component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Wallet_WaltBalance,
                            font: font,
                            textColor: textColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    accessory: .arrow,
                    action: { [weak self] _ in
                        self?.openWaltBalance()
                    }
                ))))
            }
            if let availableEarnings = self.availableEarnings, availableEarnings.currency == .ton, availableEarnings.amount.value >= 10_000_000_000 {
                let amount = formatCurrencyAmountText(availableEarnings, dateTimeFormat: environment.dateTimeFormat, maxDecimalPositions: nil)
                let balanceTitle = environment.strings.Wallet_EarningsBalance("💎\(amount)")
                let title = NSMutableAttributedString(string: balanceTitle.string, font: font, textColor: textColor)
                let amountText = NSMutableAttributedString(string: "💎\(amount)", font: font, textColor: environment.theme.list.itemAccentColor)
                if let earningsIcon = self.earningsIcon {
                    let range = (amountText.string as NSString).range(of: "💎")
                    amountText.addAttribute(.attachment, value: earningsIcon, range: range)
                    amountText.addAttribute(.baselineOffset, value: 1.5, range: range)
                    amountText.addAttribute(.kern, value: 0.0, range: range)
                }
                for range in balanceTitle.ranges.reversed() where range.index == 0 {
                    title.replaceCharacters(in: range.range, with: amountText)
                }
                
                appendItem(id: "earnings", title: title, action: { [weak self] in
                    self?.openEarnings()
                })
            }
            if self.previousWalletsBalance > 0 {
                let amount = formatTonAmountText(self.previousWalletsBalance, dateTimeFormat: environment.dateTimeFormat, maxDecimalPositions: 2)
                let balanceTitle = environment.strings.Wallet_PreviousWalletsBalance("💎\(amount)")
                let title = NSMutableAttributedString(string: balanceTitle.string, font: font, textColor: textColor)
                let amountText = NSMutableAttributedString(string: "💎\(amount)", font: font, textColor: environment.theme.list.itemAccentColor)
                if let earningsIcon = self.earningsIcon {
                    let range = (amountText.string as NSString).range(of: "💎")
                    amountText.addAttribute(.attachment, value: earningsIcon, range: range)
                    amountText.addAttribute(.baselineOffset, value: 1.5, range: range)
                    amountText.addAttribute(.kern, value: 0.0, range: range)
                }
                for range in balanceTitle.ranges.reversed() where range.index == 0 {
                    title.replaceCharacters(in: range.range, with: amountText)
                }
                appendItem(id: "previousWallets", title: title, action: { [weak self] in
                    self?.openWalletSettings()
                })
            }
            let isVisible = !items.isEmpty
            let visibilityChanged = self.additionalBalancesIsVisible != isVisible
            if visibilityChanged {
                self.additionalBalancesIsVisible = isVisible
                self.additionalBalancesVisibilityGeneration &+= 1
            }
            guard isVisible else {
                if let sectionView = self.additionalBalancesSection.view, sectionView.superview != nil {
                    if transition.animation.isImmediate {
                        self.additionalBalancesVisibilityGeneration &+= 1
                        sectionView.layer.removeAnimation(forKey: "opacity")
                        sectionView.removeFromSuperview()
                    } else if visibilityChanged {
                        let generation = self.additionalBalancesVisibilityGeneration
                        transition.setAlpha(view: sectionView, alpha: 0.0, completion: { [weak self, weak sectionView] completed in
                            guard completed, let self, let sectionView,
                                  self.additionalBalancesVisibilityGeneration == generation,
                                  !self.additionalBalancesIsVisible else {
                                return
                            }
                            sectionView.removeFromSuperview()
                        })
                    }
                }
                return 0.0
            }

            let wasVisible = self.additionalBalancesSection.view?.superview != nil
            let sectionTransition: ComponentTransition = !wasVisible ? .immediate : transition
            self.additionalBalancesSection.parentState = state
            let sectionSize = self.additionalBalancesSection.update(
                transition: sectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    style: .glass,
                    backgroundColor: environment.theme.overallDarkAppearance ? environment.theme.list.itemBlocksBackgroundColor : textColor.withMultipliedAlpha(0.04),
                    header: nil,
                    footer: nil,
                    items: items
                )),
                environment: {},
                containerSize: CGSize(width: width, height: 10000.0)
            )
            if let sectionView = self.additionalBalancesSection.view {
                if sectionView.superview == nil {
                    sectionView.layer.removeAnimation(forKey: "opacity")
                    sectionView.alpha = 1.0
                    self.topContentContainerView.addSubview(sectionView)
                }
                sectionTransition.setFrame(view: sectionView, frame: CGRect(origin: origin, size: sectionSize))
                if !wasVisible && !transition.animation.isImmediate {
                    transition.animateAlpha(view: sectionView, from: 0.0, to: 1.0)
                } else {
                    transition.setAlpha(view: sectionView, alpha: 1.0)
                    if transition.animation.isImmediate {
                        sectionView.layer.removeAnimation(forKey: "opacity")
                    }
                }
            }
            return sectionSize.height + 10.0
        }

        private func presentPasswordSetToast() {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  controller.navigationController?.topViewController === controller else {
                return
            }
            let presentationData = self.currentPresentationData(for: component).initial
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: presentationData.strings.Wallet_PasswordSetTitle,
                        text: presentationData.strings.Wallet_PasswordSetText,
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ),
                in: .current
            )
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        @objc private func navigationBalancePressed() {
            self.scrollToTop()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView === self.scrollView, !self.isUpdating else {
                return
            }
            if self.isGramTooltipPresentationPending || (self.gramTooltip != nil && !self.isDismissingGramTooltip) {
                self.dismissGramTooltip(animated: true)
            }
            self.updateScrolling(transition: .immediate)
            self.updateVisibleSections(transition: .immediate)
            self.loadMoreItemsIfNeeded()
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard scrollView === self.scrollView else {
                return
            }
            targetContentOffset.pointee.y = self.snappedCardScrollOffset(targetContentOffset.pointee.y)
        }

        private func snappedCardScrollOffset(_ offset: CGFloat) -> CGFloat {
            let distance = self.cardTransitionDistance
            let start = self.cardTransitionStart
            let maximumOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.bounds.height)
            guard start + distance <= maximumOffset, offset > start, offset < start + distance else {
                return offset
            }
            return offset < start + distance * 0.5 ? start : start + distance
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if scrollView === self.scrollView && !decelerate {
                self.settleCardScrollPosition()
            }
        }

        private func settleCardScrollPosition() {
            let offset = self.scrollView.contentOffset
            let snappedOffset = self.snappedCardScrollOffset(offset.y)
            if snappedOffset != offset.y {
                self.scrollView.setContentOffset(CGPoint(x: offset.x, y: snappedOffset), animated: true)
            }
        }

        private func visibleBounds(for sectionFrame: CGRect, viewportSize: CGSize) -> CGRect {
            return CGRect(origin: self.scrollView.contentOffset, size: viewportSize)
                .insetBy(dx: 0.0, dy: -walletSectionOverscan)
                .offsetBy(dx: -sectionFrame.minX, dy: -sectionFrame.minY)
        }

        private func updateVisibleSections(transition: ComponentTransition) {
            switch self.selectedSection {
            case .transactions:
                if self.transactionsSection.superview != nil {
                    self.transactionsSection.updateVisibleBounds(
                        self.visibleBounds(for: self.transactionsSection.frame, viewportSize: self.scrollView.bounds.size),
                        transition: transition
                    )
                }
            case .collectibles:
                if self.collectiblesSection.superview != nil {
                    self.collectiblesSection.updateVisibleBounds(
                        self.visibleBounds(for: self.collectiblesSection.frame, viewportSize: self.scrollView.bounds.size),
                        transition: transition
                    )
                }
            }
        }

        private func hideSection(_ section: LazySectionView, transition: ComponentTransition) {
            guard section.superview != nil else {
                section.clearVisibleItems()
                return
            }
            transition.setAlpha(view: section, alpha: 0.0, completion: { [weak section] _ in
                guard let section, section.alpha == 0.0 else {
                    return
                }
                section.removeFromSuperview()
                section.clearVisibleItems()
            })
        }

        private func updateSection(
            _ section: LazySectionView,
            theme: PresentationTheme,
            state: EmptyComponentState,
            items: [LazySectionView.Item],
            footer: AnyComponent<Empty>?,
            frame: CGRect,
            viewportSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let wasVisible = section.superview != nil
            let sectionSize = section.update(
                theme: theme,
                state: state,
                items: items,
                footer: footer,
                width: frame.width,
                visibleBounds: self.visibleBounds(for: frame, viewportSize: viewportSize),
                transition: wasVisible ? transition : .immediate
            )
            if !wasVisible {
                section.alpha = 1.0
                self.scrollView.addSubview(section)
            }
            if !wasVisible && !transition.animation.isImmediate {
                section.layer.allowsGroupOpacity = true
                transition.animateAlpha(view: section, from: 0.0, to: 1.0, completion: { [weak section] _ in
                    section?.layer.allowsGroupOpacity = false
                })
            } else {
                transition.setAlpha(view: section, alpha: 1.0)
            }
                        
            let layoutTransition: ComponentTransition = wasVisible ? transition : .immediate
            layoutTransition.setPosition(
                view: section,
                position: CGPoint(x: frame.midX, y: frame.minY)
            )
            layoutTransition.setBounds(
                view: section,
                bounds: CGRect(origin: .zero, size: sectionSize)
            )
            return sectionSize
        }

        private func hideEmptyTransactionsFooter(transition: ComponentTransition) {
            guard let footerView = self.emptyTransactionsFooter.view, footerView.superview != nil else {
                return
            }
            transition.setAlpha(view: footerView, alpha: 0.0, completion: { [weak footerView] _ in
                guard let footerView, footerView.alpha == 0.0 else {
                    return
                }
                footerView.removeFromSuperview()
            })
        }

        private var displayBalance: Int64? {
            guard let balance = self.walletState?.balance.currentValue else {
                return nil
            }
            return balance.magnitude < 1_000_000 ? 0 : balance
        }

        private var walletAddress: String? {
            return self.walletState?.walletAddress
        }

        private var walletInfo: WalletContext.WalletInfo? {
            guard let walletState = self.walletState else {
                return nil
            }
            if case let .wallet(info) = walletState.phase {
                return info
            }
            return nil
        }

        private func maybePresentGramTooltip(cardView: WalletCardComponent.View) {
            let walletAddress = self.walletAddress
            if self.gramTooltipWalletAddress != walletAddress {
                self.dismissGramTooltip(animated: false)
                self.gramTooltipWalletAddress = walletAddress
                self.didPresentGramTooltip = false
            }
            
            guard let walletAddress,
                  !self.isGramTooltipPresentationPending,
                  !self.didPresentGramTooltip,
                  self.cardTransitionFraction == 0.0,
                  !self.scrollView.isDragging,
                  !self.scrollView.isDecelerating,
                  self.environment?.isVisible == true,
                  cardView.window != nil,
                  !cardView.gramIconFrame.isEmpty else {
                return
            }

            guard let component = self.component else {
                return
            }
            self.gramTooltipGeneration += 1
            let generation = self.gramTooltipGeneration
            self.isGramTooltipPresentationPending = true
            self.gramTooltipDisposable.set((ApplicationSpecificNotice.getWalletGramTooltip(accountManager: component.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self, weak cardView] count in
                guard let self, self.gramTooltipGeneration == generation else {
                    return
                }
                self.isGramTooltipPresentationPending = false

                guard self.gramTooltipWalletAddress == walletAddress,
                      self.walletAddress == walletAddress,
                      !self.didPresentGramTooltip else {
                    return
                }
                if count >= 3 {
                    self.didPresentGramTooltip = true
                    return
                }
                
                guard self.cardTransitionFraction == 0.0,
                      !self.scrollView.isDragging,
                      !self.scrollView.isDecelerating,
                      self.environment?.isVisible == true,
                      let cardView,
                      cardView.window != nil,
                      !cardView.gramIconFrame.isEmpty,
                      self.card.view === cardView else {
                    return
                }

                let tooltip = ComponentView<Empty>()
                self.gramTooltip = tooltip
                self.isDismissingGramTooltip = false
                self.updateGramTooltip()
                guard let tooltipView = tooltip.view as? WalletTooltipComponent.View, tooltipView.superview === cardView else {
                    self.gramTooltip = nil
                    return
                }
                self.didPresentGramTooltip = true
                self.gramTooltipTapGestureRecognizer.isEnabled = true
                tooltipView.animateIn()
                let timer = Foundation.Timer(timeInterval: 5.0, repeats: false, block: { [weak self, weak tooltipView] _ in
                    guard let self, let tooltipView, self.gramTooltip?.view === tooltipView else {
                        return
                    }
                    self.dismissGramTooltip(animated: true)
                })
                self.gramTooltipTimer = timer
                RunLoop.main.add(timer, forMode: .common)
                let _ = ApplicationSpecificNotice.incrementWalletGramTooltip(accountManager: component.context.sharedContext.accountManager).startStandalone()
            }))
        }

        private func updateGramTooltip() {
            guard let tooltip = self.gramTooltip,
                  let environment = self.environment,
                  let cardView = self.card.view as? WalletCardComponent.View else {
                return
            }
            let leftInset = environment.safeInsets.left + 26.0
            let rightInset = environment.safeInsets.right + 26.0
            let availableWidth = self.scrollView.bounds.width - leftInset - rightInset
            guard availableWidth > 22.0 else {
                return
            }
            let tooltipSize = tooltip.update(
                transition: .immediate,
                component: AnyComponent(WalletTooltipComponent(text: environment.strings.Wallet_GramTooltip)),
                environment: {},
                containerSize: CGSize(width: min(614.0, availableWidth), height: 10000.0)
            )
            guard let tooltipView = tooltip.view as? WalletTooltipComponent.View else {
                return
            }
            if tooltipView.superview !== cardView {
                tooltipView.layer.zPosition = (cardView.layer.sublayers?.map { $0.zPosition }.max() ?? 0.0) + 1.0
                cardView.addSubview(tooltipView)
            }
            tooltipView.isHidden = cardView.gramIconFrame.isEmpty
            let sourceFrame = cardView.gramIconFrame.offsetBy(dx: 0.0, dy: -4.0)
            let availableFrame = cardView.convert(CGRect(x: leftInset, y: 0.0, width: availableWidth, height: 0.0), from: self)
            let tooltipFrame = CGRect(
                origin: CGPoint(
                    x: max(availableFrame.minX, min(availableFrame.maxX - tooltipSize.width, sourceFrame.midX - tooltipSize.width * 0.5)),
                    y: sourceFrame.minY - 10.0 - tooltipSize.height
                ),
                size: tooltipSize
            )
            ComponentTransition.immediate.setFrame(view: tooltipView, frame: tooltipFrame)
            tooltipView.updateArrowPosition(sourceFrame.midX - tooltipFrame.minX)
        }

        private func dismissGramTooltip(animated: Bool) {
            self.gramTooltipGeneration += 1
            self.isGramTooltipPresentationPending = false
            self.gramTooltipDisposable.set(nil)
            self.gramTooltipTimer?.invalidate()
            self.gramTooltipTimer = nil
            self.gramTooltipTapGestureRecognizer.isEnabled = false

            guard let tooltipView = self.gramTooltip?.view as? WalletTooltipComponent.View else {
                self.gramTooltip = nil
                self.isDismissingGramTooltip = false
                return
            }
            if animated {
                guard !self.isDismissingGramTooltip else {
                    return
                }
                self.isDismissingGramTooltip = true
                tooltipView.animateOut(completion: { [weak self, weak tooltipView] in
                    guard let self, let tooltipView, self.gramTooltip?.view === tooltipView else {
                        return
                    }
                    tooltipView.removeFromSuperview()
                    self.gramTooltip = nil
                    self.isDismissingGramTooltip = false
                })
            } else {
                self.gramTooltip = nil
                self.isDismissingGramTooltip = false
                tooltipView.removeFromSuperview()
            }
        }

        @objc private func gramTooltipTap(_ gestureRecognizer: UITapGestureRecognizer) {
            if gestureRecognizer.state == .ended {
                self.dismissGramTooltip(animated: true)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return gestureRecognizer === self.gramTooltipTapGestureRecognizer || otherGestureRecognizer === self.gramTooltipTapGestureRecognizer
        }

        private func loadMoreItemsIfNeeded() {
            guard let component = self.component,
                  let walletState = self.walletState,
                  walletState.activeOperation == nil,
                  self.loadMoreRequestId == nil,
                  self.scrollView.contentOffset.y + self.scrollView.bounds.height > self.scrollView.contentSize.height - 240.0 else {
                return
            }

            let signal: Signal<Void, WalletContext.WalletError>
            switch self.selectedSection {
            case .transactions:
                guard walletState.transactions.canLoadMore, !walletState.transactions.isLoadingMore else {
                    return
                }
                signal = component.walletContext.loadMoreTransactions()
            case .collectibles:
                guard walletState.collectibles.canLoadMore, !walletState.collectibles.isRefreshing, !walletState.collectibles.isLoadingMore else {
                    return
                }
                signal = component.walletContext.loadMoreCollectibles()
            }

            self.nextLoadMoreRequestId &+= 1
            let requestId = self.nextLoadMoreRequestId
            let walletContext = component.walletContext
            self.loadMoreRequestId = requestId
            self.loadMoreDisposable.set(signal.start(error: { [weak self, weak walletContext] _ in
                guard let self, let walletContext else {
                    return
                }
                self.finishLoadMoreRequest(id: requestId, walletContext: walletContext, loadNextPageIfNeeded: false)
            }, completed: { [weak self, weak walletContext] in
                guard let self, let walletContext else {
                    return
                }
                self.finishLoadMoreRequest(id: requestId, walletContext: walletContext, loadNextPageIfNeeded: true)
            }))
        }

        private func finishLoadMoreRequest(id: Int, walletContext: WalletContext, loadNextPageIfNeeded: Bool) {
            guard self.walletContext === walletContext, self.loadMoreRequestId == id else {
                return
            }
            self.loadMoreRequestId = nil
            if loadNextPageIfNeeded {
                Queue.mainQueue().async { [weak self] in
                    guard let self, self.walletContext === walletContext else {
                        return
                    }
                    self.loadMoreItemsIfNeeded()
                }
            }
        }

        private func updateTransactionTabs(
            component: WalletScreenComponent,
            environment: EnvironmentType,
            state: EmptyComponentState,
            availableWidth: CGFloat,
            containerWidth: CGFloat,
            originY: CGFloat,
            transition: ComponentTransition
        ) -> CGSize {
            var tabsTransition = transition
            if self.transactionTabs.view?.superview == nil {
                tabsTransition = .immediate
            }

            let transactionsTabId = AnyHashable("transactions")
            let collectiblesTabId = AnyHashable("collectibles")
            self.transactionTabs.parentState = state
            let tabsSize = self.transactionTabs.update(
                transition: tabsTransition,
                component: AnyComponent(HorizontalTabsComponent(
                    context: component.context,
                    theme: environment.theme,
                    tabs: [
                        HorizontalTabsComponent.Tab(
                            id: transactionsTabId,
                            content: .title(HorizontalTabsComponent.Tab.Title(
                                text: environment.strings.Wallet_Transactions,
                                entities: [],
                                enableAnimations: false
                            )),
                            badge: nil,
                            action: { [weak self] in
                                guard let self, self.selectedSection != .transactions else {
                                    return
                                }
                                self.selectedSection = .transactions
                                self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                            }
                        ),
                        HorizontalTabsComponent.Tab(
                            id: collectiblesTabId,
                            content: .title(HorizontalTabsComponent.Tab.Title(
                                text: environment.strings.Wallet_Collectibles,
                                entities: [],
                                enableAnimations: false
                            )),
                            badge: nil,
                            action: { [weak self] in
                                guard let self, self.selectedSection != .collectibles else {
                                    return
                                }
                                self.selectedSection = .collectibles
                                self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                            }
                        )
                    ],
                    selectedTab: self.selectedSection == .transactions ? transactionsTabId : collectiblesTabId,
                    isEditing: false,
                    layout: .fill,
                    liftWhileSwitching: environment.deviceMetrics.type == .phone
                )),
                environment: {},
                containerSize: CGSize(width: containerWidth, height: 40.0)
            )
            let tabsFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableWidth - tabsSize.width) / 2.0),
                    y: originY
                ),
                size: tabsSize
            )
            let backgroundFrame = CGRect(
                x: tabsFrame.minX,
                y: tabsFrame.minY + floorToScreenPixels((tabsFrame.height - 40.0) / 2.0),
                width: tabsFrame.width,
                height: 40.0
            )
            let wasVisible = self.transactionTabsBackgroundView.superview != nil
            if self.transactionTabsBackgroundView.superview == nil {
                self.scrollView.addSubview(self.transactionTabsBackgroundView)
            }
            tabsTransition.setFrame(view: self.transactionTabsBackgroundView, frame: backgroundFrame)
            self.transactionTabsBackgroundView.update(
                size: backgroundFrame.size,
                cornerRadius: 20.0,
                isDark: environment.theme.overallDarkAppearance,
                tintColor: .init(kind: .panel),
                isInteractive: true,
                transition: tabsTransition
            )
            if !wasVisible && !transition.animation.isImmediate {
                transition.animateAlpha(view: self.transactionTabsBackgroundView, from: 0.0, to: 1.0)
            } else {
                transition.setAlpha(view: self.transactionTabsBackgroundView, alpha: 1.0)
            }
            if let tabsView = self.transactionTabs.view as? HorizontalTabsComponent.View {
                if tabsView.superview !== self.transactionTabsBackgroundView.contentView {
                    self.transactionTabsBackgroundView.contentView.addSubview(tabsView)
                    tabsView.setOverlayContainerView(overlayContainerView: self.scrollView)
                }
                tabsTransition.setFrame(
                    view: tabsView,
                    frame: CGRect(
                        x: tabsFrame.minX - backgroundFrame.minX,
                        y: tabsFrame.minY - backgroundFrame.minY,
                        width: tabsFrame.width,
                        height: tabsFrame.height
                    )
                )
                if !wasVisible && !transition.animation.isImmediate {
                    transition.animateAlpha(view: tabsView, from: 0.0, to: 1.0)
                } else {
                    transition.setAlpha(view: tabsView, alpha: 1.0)
                }
            }
            return tabsSize
        }

        func setTransferAnimationsVisible(_ visible: Bool) {
            self.transferScreenVisible = visible
            if visible { self.isReturningForTransfer = false }
            self.updatePendingTransferAnimations()
        }

        private func observePendingTransfers(_ state: WalletContext.State) {
            let transactions = Dictionary(state.transactions.items.map { ($0.presentationId, $0) }, uniquingKeysWith: { first, _ in first })
            for (id, animation) in self.pendingTransferAnimations {
                guard let transaction = transactions[id], transaction.status != .failed else {
                    animation.suspend()
                    self.pendingTransferAnimations.removeValue(forKey: id)
                    continue
                }
                animation.isPending = transaction.status == .pending
                if !animation.isPending && !animation.isFlying && (!animation.isVisible || !self.transferScreenVisible || !self.transferApplicationInForeground) {
                    self.pendingTransferAnimations.removeValue(forKey: id)
                }
            }
            self.newTransferPresentationIds.formIntersection(transactions.keys)
            for transaction in state.transactions.items where transaction.status == .pending && transaction.currency == .ton
                && transaction.direction == .outgoing && transaction.kind != .deployContract && transaction.kind != .keyChange
                && transaction.collectible == nil && transaction.isVisibleInWalletHistory {
                guard self.pendingTransferAnimations[transaction.presentationId] == nil else { continue }
                self.pendingTransferAnimations[transaction.presentationId] = WalletPendingTransferAnimation(id: transaction.presentationId)
                if let previous = self.walletState, !previous.transactions.items.contains(where: { $0.presentationId == transaction.presentationId }) {
                    self.newTransferPresentationIds.insert(transaction.presentationId)
                }
            }
        }

        private func receiveTransferAnimation(id: String, source: WalletSendTransferAnimationSource?) -> Bool {
            guard self.transferApplicationInForeground,
                  let transaction = self.walletState?.transactions.items.first(where: { $0.presentationId == id }),
                  transaction.status != .failed, transaction.isVisibleInWalletHistory else { return false }
            if let source, source.window == nil { return false }
            let animation = self.pendingTransferAnimations[id] ?? WalletPendingTransferAnimation(id: id)
            animation.isPending = transaction.status == .pending
            self.pendingTransferAnimations[id] = animation
            self.pendingTransferToReveal = id
            self.shouldRevealLatestTransactions = false
            self.selectedSection = .transactions
            self.isReturningForTransfer = !self.transferScreenVisible
            if let source { animation.launch(source, at: CACurrentMediaTime()) }
            self.componentState?.updated(transition: .immediate)
            self.updatePendingTransferAnimations()
            return true
        }

        private func showTransactions() {
            self.selectedSection = .transactions
            self.pendingTransferToReveal = nil
            self.shouldRevealLatestTransactions = true
            self.componentState?.updated(transition: .immediate)
        }

        private func revealNewTransfer() {
            if self.pendingTransferToReveal == nil {
                self.pendingTransferToReveal = self.walletState?.transactions.items.first(where: {
                    self.newTransferPresentationIds.contains($0.presentationId)
                })?.presentationId
            }
            if self.pendingTransferToReveal == nil && !self.pendingTransferAnimations.values.contains(where: { $0.isFlying }) {
                self.showTransactions()
                return
            }
            self.shouldRevealLatestTransactions = false
            self.selectedSection = .transactions
            self.componentState?.updated(transition: .immediate)
        }

        private func revealLatestTransactionsIfNeeded(firstTransactionId: String?) {
            guard self.shouldRevealLatestTransactions, self.selectedSection == .transactions else {
                return
            }
            self.shouldRevealLatestTransactions = false
            if let firstTransactionId, let frame = self.transactionsSection.itemFrame(id: AnyHashable(firstTransactionId)) {
                self.scrollToTransactionIfNeeded(frame: frame)
            } else {
                self.scrollView.setContentOffset(.zero, animated: false)
            }
        }

        private func revealPendingTransferIfNeeded() {
            guard let id = self.pendingTransferToReveal, self.selectedSection == .transactions,
                  let frame = self.transactionsSection.itemFrame(id: AnyHashable(id)) else { return }
            self.pendingTransferToReveal = nil
            self.newTransferPresentationIds.remove(id)
            self.scrollToTransactionIfNeeded(frame: frame)
        }

        private func scrollToTransactionIfNeeded(frame: CGRect) {
            let rect = self.transactionsSection.convert(frame, to: self.scrollView)
            let top = (self.environment?.navigationHeight ?? 0.0) + 16.0
            let bottom: CGFloat = 24.0
            let visible = self.scrollView.bounds.inset(by: UIEdgeInsets(top: top, left: 0.0, bottom: bottom, right: 0.0))
            if !visible.contains(rect) {
                let y = max(-self.scrollView.contentInset.top, min(rect.minY - top,
                    self.scrollView.contentSize.height - self.scrollView.bounds.height + self.scrollView.contentInset.bottom))
                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: y), animated: false)
                self.transactionsSection.updateVisibleBounds(self.visibleBounds(for: self.transactionsSection.frame, viewportSize: self.scrollView.bounds.size), force: true, transition: .immediate)
            }
        }

        private func updatePendingTransferAnimations() {
            guard !self.isUpdatingTransferAnimations else { return }
            self.isUpdatingTransferAnimations = true
            defer { self.isUpdatingTransferAnimations = false }
            let active = self.transferApplicationInForeground
                && ((self.transferScreenVisible && self.window != nil) || (self.isReturningForTransfer && self.pendingTransferAnimations.values.contains(where: { $0.isFlying })))
            let now = CACurrentMediaTime()
            var needsFrames = false
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.transactionsSection.setLiftedItems(Set(self.pendingTransferAnimations.keys.map { AnyHashable($0) }))
            if let theme = self.environment?.theme {
                for (id, animation) in self.pendingTransferAnimations {
                    let row = self.transactionsSection.itemView(id: AnyHashable(id))
                    func findContent(_ view: UIView) -> WalletTransactionItemComponent.View? {
                        if let view = view as? WalletTransactionItemComponent.View { return view }
                        for subview in view.subviews {
                            if let result = findContent(subview) { return result }
                        }
                        return nil
                    }
                    let content = row.flatMap { findContent($0) }
                    animation.bind(row: row, content: content, theme: theme)
                    if active && animation.isFlying && (row?.window == nil || self.pendingTransferToReveal == id) {
                        needsFrames = animation.waitForFlightLayout(at: now) || needsFrames
                        continue
                    }
                    let visible = active && self.selectedSection == .transactions && row?.window != nil
                        && row.map { self.scrollView.bounds.intersects($0.convert($0.bounds, to: self.scrollView)) } == true
                    animation.update(at: now, visible: visible)
                    if animation.finished {
                        self.pendingTransferAnimations.removeValue(forKey: id)
                    } else if visible && (!UIAccessibility.isReduceMotionEnabled || animation.completion != nil) {
                        needsFrames = true
                    }
                }
            }
            self.transactionsSection.setLiftedItems(Set(self.pendingTransferAnimations.keys.map { AnyHashable($0) }))
            CATransaction.commit()
            if needsFrames {
                if self.transferDisplayLink == nil {
                    self.transferDisplayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                        self?.updatePendingTransferAnimations()
                    })
                }
            } else {
                self.transferDisplayLink?.invalidate()
                self.transferDisplayLink = nil
            }
        }

        private func updateScrolling(transition: ComponentTransition) {
            self.updatePendingTransferAnimations()
            let fraction = self.cardTransitionFraction
            let edgeEffectAlpha = max(0.0, min(1.0, self.scrollView.contentOffset.y / 20.0))
            transition.setAlpha(view: self.topEdgeEffectView, alpha: edgeEffectAlpha)
            if let cardView = self.card.view as? WalletCardComponent.View {
                cardView.updateScrollTransform(self.makeCardTransform(
                    fraction: fraction,
                    scale: 1.0 + (self.cardCollapsedScale - 1.0) * fraction
                ))
            }

            if let cardExpandedFrame = self.cardExpandedFrame {
                transition.setFrame(
                    view: self.cardContainerView,
                    frame: cardExpandedFrame.offsetBy(dx: 0.0, dy: -self.cardScrollOffset)
                )
                transition.setFrame(
                    view: self.cardBalanceCoordinateView,
                    frame: self.cardBalanceClippingView.convert(self.cardContainerView.bounds, from: self.cardContainerView)
                )
            }

            let cardAlpha = self.cardVisibilityAlpha()
            ComponentTransition.immediate.setAlpha(view: self.cardVisualContainerView, alpha: cardAlpha)
            ComponentTransition.immediate.setAlpha(view: self.cardBalanceCoordinateView, alpha: 1.0)
            if let navigationBalanceView = self.navigationBalance.view {
                ComponentTransition.immediate.setAlpha(view: navigationBalanceView, alpha: 1.0)
            }
            self.navigationBalanceButton.isHidden = fraction < 1.0
            self.navigationBalanceButton.isUserInteractionEnabled = fraction == 1.0
            self.cardContainerView.isUserInteractionEnabled = cardAlpha > 0.0

            if let cardView = self.card.view as? WalletCardComponent.View {
                cardView.updateScrollVisibility(fraction < 1.0)
                cardView.updateOverscroll(distance: max(0.0, -self.scrollView.contentOffset.y))
            }
            if let navigationTitleView = self.navigationTitle.view {
                var headerTransitionFraction: CGFloat = 0.0
                if self.scrollView.contentOffset.y > 0.0,
                   let cardView = self.card.view as? WalletCardComponent.View,
                   !cardView.renderedCardFrame.isEmpty {
                    let titleFrame = navigationTitleView.convert(navigationTitleView.bounds, to: self)
                    let cardFrame = cardView.convert(cardView.renderedCardFrame, to: self)
                    let fadeStartY = titleFrame.maxY + 24.0
                    let fadeStopY = titleFrame.maxY
                    let progress = max(0.0, min(1.0, (fadeStartY - cardFrame.minY) / max(1.0, fadeStartY - fadeStopY)))
                    headerTransitionFraction = progress * progress * (3.0 - 2.0 * progress)
                }
                ComponentTransition.immediate.setAlpha(view: navigationTitleView, alpha: 1.0 - headerTransitionFraction)
                navigationTitleView.layer.removeAnimation(forKey: "filters.gaussianBlur.inputRadius")
                ComponentTransition.immediate.setBlur(layer: navigationTitleView.layer, radius: headerTransitionFraction * 8.0)
            }
            self.updateBalanceTransition(transition: transition)
            self.updateBalanceClipping(transition: transition)
            self.updateGramTooltip()
        }

        private func updateBalanceClipping(transition: ComponentTransition) {
            guard let cardView = self.card.view as? WalletCardComponent.View, !cardView.bounds.isEmpty else {
                return
            }
            let edge = cardView.renderedCardBottomEdge
            func maskPath(in view: UIView, belowEdge: Bool) -> CGPath {
                return self.balanceMaskPath(
                    bounds: view.bounds,
                    left: view.convert(edge.left, from: cardView),
                    right: view.convert(edge.right, from: cardView),
                    belowEdge: belowEdge
                )
            }

            func updateMask(_ layer: CAShapeLayer, in view: UIView, belowEdge: Bool) {
                layer.frame = view.bounds
                let path = maskPath(in: view, belowEdge: belowEdge)
                guard layer.path != path else {
                    return
                }
                if transition.animation.isImmediate {
                    layer.removeAnimation(forKey: "path")
                } else if layer.animation(forKey: "path") != nil, let presentationPath = layer.presentation()?.path {
                    layer.path = presentationPath
                }
                transition.setShapeLayerPath(layer: layer, path: path)
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            updateMask(self.cardBalanceMaskLayer, in: self.cardBalanceClippingView, belowEdge: false)
            updateMask(self.navigationBalanceMaskLayer, in: self.navigationBalanceClippingView, belowEdge: true)
            CATransaction.commit()
        }

        private func balanceMaskPath(bounds: CGRect, left: CGPoint, right: CGPoint, belowEdge: Bool) -> CGPath {
            let corners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
            func distance(_ point: CGPoint) -> CGFloat {
                let value = (right.x - left.x) * (point.y - left.y) - (right.y - left.y) * (point.x - left.x)
                return belowEdge ? value : -value
            }

            var points: [CGPoint] = []
            var previous = corners[corners.count - 1]
            var previousDistance = distance(previous)
            for point in corners {
                let currentDistance = distance(point)
                if (previousDistance >= 0.0) != (currentDistance >= 0.0) {
                    let fraction = previousDistance / (previousDistance - currentDistance)
                    points.append(CGPoint(
                        x: previous.x + (point.x - previous.x) * fraction,
                        y: previous.y + (point.y - previous.y) * fraction
                    ))
                }
                if currentDistance >= 0.0 {
                    points.append(point)
                }
                previous = point
                previousDistance = currentDistance
            }

            let path = CGMutablePath()
            if points.count >= 3 {
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                path.closeSubpath()
            }
            return path
        }

        private func cardVisibilityAlpha() -> CGFloat {
            guard let cardView = self.card.view as? WalletCardComponent.View,
                  let environment = self.environment else {
                return 1.0
            }

            let hasTopCutout: Bool
            switch environment.deviceMetrics {
            case .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax:
                hasTopCutout = true
            default:
                hasTopCutout = environment.deviceMetrics.hasTopNotch || environment.deviceMetrics.hasDynamicIsland
            }
            let fadeBoundary = hasTopCutout && self.bounds.height >= self.bounds.width ? environment.statusBarHeight : 0.0
            let cardFrame = cardView.convert(cardView.renderedCardFrame, to: self)
            let fadeDistance = min(24.0, max(1.0, cardFrame.height * 0.5))
            let fadeFraction = max(0.0, min(1.0, (fadeBoundary - cardFrame.midY) / fadeDistance))
            return 1.0 - fadeFraction * fadeFraction * (3.0 - 2.0 * fadeFraction)
        }

        private func makeCardTransform(fraction: CGFloat, scale: CGFloat = 1.0) -> CATransform3D {
            var transform = CATransform3DIdentity
            if !UIAccessibility.isReduceMotionEnabled {
                let pitchFraction = fraction * (2.0 - fraction)
                let pitch = self.cardCollapsedPitch * pitchFraction
                transform.m34 = -fraction / 650.0
                transform = CATransform3DRotate(transform, pitch, 1.0, 0.0, 0.0)
            }
            transform = CATransform3DScale(transform, scale, scale, 1.0)
            return transform
        }

        private func updateBalanceTransition(transition: ComponentTransition) {
            guard let cardView = self.card.view as? WalletCardComponent.View,
                  let navigationBalanceView = self.navigationBalance.view as? WalletNavigationBalanceComponent.View,
                  let cardExpandedFrame = self.cardExpandedFrame else {
                return
            }

            let fraction = self.cardTransitionFraction
            if self.scrollView.contentOffset.y <= self.cardTransitionStart {
                let primaryFrame = self.cardBalanceCoordinateView.convert(cardView.primaryBalanceSourceFrame, to: self)
                let secondaryFrame = self.cardBalanceCoordinateView.convert(cardView.secondaryBalanceSourceFrame, to: self)
                navigationBalanceView.updateTransitionFrames(
                    primaryFrame: navigationBalanceView.convert(primaryFrame, from: self),
                    secondaryFrame: navigationBalanceView.convert(secondaryFrame, from: self),
                    collapseFraction: 0.0,
                    transition: transition
                )
                cardView.updateBalanceTransition(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    primaryCollapsedFrame: nil,
                    secondaryCollapsedFrame: nil,
                    fraction: 0.0,
                    collapseFraction: 0.0,
                    transition: .immediate
                )
                return
            }

            let primarySourceFrame = cardView.primaryBalanceSourceFrame.offsetBy(dx: cardExpandedFrame.minX, dy: cardExpandedFrame.minY)
            let secondarySourceFrame = cardView.secondaryBalanceSourceFrame.offsetBy(dx: cardExpandedFrame.minX, dy: cardExpandedFrame.minY)
            let primaryTargetFrame = navigationBalanceView.convert(navigationBalanceView.primaryTargetFrame, to: self)
            let secondaryTargetFrame = navigationBalanceView.convert(navigationBalanceView.secondaryTargetFrame, to: self)

            guard !primarySourceFrame.isEmpty,
                  !secondarySourceFrame.isEmpty,
                  !primaryTargetFrame.isEmpty,
                  !secondaryTargetFrame.isEmpty else {
                navigationBalanceView.updateTransitionFrames(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    collapseFraction: fraction,
                    transition: transition
                )
                cardView.updateBalanceTransition(
                    primaryFrame: nil,
                    secondaryFrame: nil,
                    primaryCollapsedFrame: nil,
                    secondaryCollapsedFrame: nil,
                    fraction: fraction,
                    collapseFraction: fraction,
                    scrollTransform: self.makeCardTransform(fraction: fraction),
                    transition: .immediate
                )
                return
            }

            let navigationFrame = primaryTargetFrame.union(secondaryTargetFrame)
            let travelDistance = max(1.0, cardExpandedFrame.midY - self.cardTransitionStart - navigationFrame.midY)
            let travelFraction = max(0.0, min(1.0, (self.cardScrollOffset - self.cardTransitionStart) / travelDistance))
            let balanceFraction = travelFraction + pow(travelFraction, 6.0) * (1.0 - travelFraction)
            let horizontalFraction = 1.0 - pow(1.0 - balanceFraction, 3.0)

            func interpolate(_ from: CGFloat, _ to: CGFloat, fraction: CGFloat) -> CGFloat {
                return from + (to - from) * fraction
            }

            let sourceBalanceFrame = primarySourceFrame.union(secondarySourceFrame)
            let cardFrame = cardView.convert(cardView.renderedCardFrame, to: self)
            let followingCenterY = interpolate(
                sourceBalanceFrame.midY - self.cardScrollOffset,
                cardFrame.midY,
                fraction: balanceFraction
            )
            let arrivalDistance = max(1.0, navigationFrame.height * 0.5)
            let distanceToHeader = followingCenterY - navigationFrame.midY
            let centerY: CGFloat
            if distanceToHeader >= arrivalDistance {
                centerY = followingCenterY
            } else {
                let remainingDistance = max(0.0, distanceToHeader + arrivalDistance)
                centerY = navigationFrame.midY + remainingDistance * remainingDistance / (4.0 * arrivalDistance)
            }
            let verticalOffset = centerY - interpolate(sourceBalanceFrame.midY, navigationFrame.midY, fraction: balanceFraction)

            func balanceFrame(sourceFrame: CGRect, targetFrame: CGRect) -> CGRect {
                let size = CGSize(
                    width: interpolate(sourceFrame.width, targetFrame.width, fraction: balanceFraction),
                    height: interpolate(sourceFrame.height, targetFrame.height, fraction: balanceFraction)
                )
                let center = CGPoint(
                    x: interpolate(sourceFrame.midX, targetFrame.midX, fraction: horizontalFraction),
                    y: interpolate(sourceFrame.midY, targetFrame.midY, fraction: balanceFraction) + verticalOffset
                )
                return CGRect(
                    origin: CGPoint(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5),
                    size: size
                )
            }

            let primaryFrame = balanceFrame(
                sourceFrame: primarySourceFrame,
                targetFrame: primaryTargetFrame
            )
            let secondaryFrame = balanceFrame(
                sourceFrame: secondarySourceFrame,
                targetFrame: secondaryTargetFrame
            )

            navigationBalanceView.updateTransitionFrames(
                primaryFrame: navigationBalanceView.convert(primaryFrame, from: self),
                secondaryFrame: navigationBalanceView.convert(secondaryFrame, from: self),
                collapseFraction: 0.0,
                transition: transition
            )
            cardView.updateBalanceTransition(
                primaryFrame: self.cardBalanceCoordinateView.convert(primaryFrame, from: self),
                secondaryFrame: self.cardBalanceCoordinateView.convert(secondaryFrame, from: self),
                primaryCollapsedFrame: nil,
                secondaryCollapsedFrame: nil,
                fraction: fraction,
                collapseFraction: balanceFraction * balanceFraction * balanceFraction,
                scrollTransform: self.makeCardTransform(fraction: fraction),
                primaryContentTarget: navigationBalanceView.primaryContentLayout,
                contentFraction: balanceFraction * balanceFraction * (3.0 - 2.0 * balanceFraction),
                transition: .immediate
            )
        }

        private func dismiss() {
            self.abandonRestoration()
            self.environment?.controller()?.dismiss()
        }

        fileprivate func abandonRestoration() {
            self.signingAccessDisposable.set(nil)
            self.restorationGeneration &+= 1
            self.restorationSession?.invalidate()
            self.restorationSession = nil
            self.isResolvingSigningAccess = false
        }

        private func restorationAuthorization() -> Signal<PasscodeSession, WalletContext.WalletError> {
            guard let component = self.component else { return .fail(.authorizationCancelled) }
            if let session = self.restorationSession, session.isValid { return .single(session) }
            let generation = self.restorationGeneration
            return component.walletContext.beginWalletFlow(reason: "Restore wallet")
            |> deliverOnMainQueue
            |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
                guard let self, self.restorationGeneration == generation else {
                    session.invalidate()
                    return .fail(.authorizationCancelled)
                }
                self.restorationSession?.invalidate()
                self.restorationSession = session
                return .single(session)
            }
        }

        private func openQrCodeScanner() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let scanner = QrCodeScanScreen(context: component.context, subject: .customValidated(
                info: self.currentPresentationData(for: component).initial.strings.Wallet_ScanQR,
                validate: { value in
                    return WalletContext.isTonConnectUrl(value)
                        || WalletContext.transferAddress(from: value) != nil
                }
            ))
            scanner.completion = { [weak self, weak scanner] value in
                guard let self, let value else {
                    return
                }
                if WalletContext.isTonConnectUrl(value) {
                    Queue.mainQueue().after(0.15) {
                        scanner?.dismiss()
                        component.walletContext.processTonConnectUrl(value)
                    }
                } else if let recipient = WalletContext.transferRecipient(from: value) {
                    Queue.mainQueue().after(0.15) {
                        scanner?.dismiss()
                        self.openSend(address: recipient.transferInput)
                    }
                }
            }
            controller.push(scanner)
        }

        private func openReceive() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            guard let walletAddress = self.walletAddress else {
                return
            }
            let walletContext = component.walletContext
            controller.push(component.context.sharedContext.makeWalletReceiveScreen(
                context: component.context,
                address: walletAddress,
                appeared: { [weak self, weak walletContext] in
                    guard let self, let walletContext, self.walletContext === walletContext,
                          self.walletAddress == walletAddress else {
                        return
                    }
                    self.showTransactions()
                }
            ))
        }

        private func openSend(address: String? = nil) {
            guard let component = self.component,
                  let controller = self.environment?.controller(),
                  self.walletAddress != nil,
                  !self.isResolvingSigningAccess else {
                return
            }
            guard let walletInfo = self.walletInfo else {
                self.routeToSend(address: address)
                return
            }
            if !walletInfo.canSign {
                if walletInfo.canExportPhrase {
                    self.isResolvingSigningAccess = true
                    let generation = self.restorationGeneration
                    self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                    self.signingAccessDisposable.set(performWalletAuthorizedOperation(
                        context: component.context,
                        updatedPresentationData: self.currentPresentationData(for: component),
                        present: { [weak controller] alert in
                            controller?.present(alert, in: .window(.root))
                        },
                        operation: { [weak self] password -> Signal<[String], WalletContext.WalletError> in
                            guard let self, self.restorationGeneration == generation else { return .fail(.authorizationCancelled) }
                            return self.restorationAuthorization()
                            |> mapToSignal { session in component.walletContext.recoveryPhrase(password: password, session: session) }
                        },
                        next: { [weak self] _ in
                            guard let self, self.restorationGeneration == generation, self.component?.walletContext === component.walletContext else {
                                return
                            }
                            self.routeToSend(address: address)
                            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                        },
                        failed: { [weak self] error in
                            guard let self, self.restorationGeneration == generation else { return }
                            self.finishResolvingSigningAccess(error: error, address: address)
                        }
                    ))
                } else {
                    self.openRecoveryPhraseImport()
                }
                return
            }
            self.routeToSend(address: address)
        }

        private func routeToSend(address: String?) {
            self.newTransferPresentationIds.removeAll()
            self.abandonRestoration()
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            if let address {
                self.peerAddressDisposable.set((component.context.engine.wallet.getUserAddresses(addresses: [WalletContext.transferAddress(from: address) ?? address])
                |> `catch` { _ -> Signal<[WalletUserAddress], NoError> in
                    return .single([])
                }
                |> mapToSignal { addresses -> Signal<EnginePeer?, NoError> in
                    guard let userId = addresses.first?.userId else {
                        return .single(nil)
                    }
                    return component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: userId))
                }
                |> deliverOnMainQueue).start(next: { [weak self, weak controller] peer in
                    guard let controller, controller.navigationController?.viewControllers.last === controller else {
                        return
                    }
                    let sendScreen: WalletSendScreen
                    if let peer {
                        sendScreen = WalletSendScreen(
                            context: component.context,
                            peer: peer,
                            walletContext: component.walletContext,
                            initialAddress: address,
                            refreshBalanceOnOpen: false,
                            completed: { [weak controller] in
                                guard let navigationController = controller?.navigationController as? NavigationController else {
                                    return
                                }
                                component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peer), keepStack: .default, useExisting: true, completion: { chatController in
                                    chatController.scrollToEndOfHistory()
                                }, forceOpenChat: true))
                            }
                        )
                    } else {
                        sendScreen = WalletSendScreen(context: component.context, walletContext: component.walletContext, address: address, refreshBalanceOnOpen: false, transferAnimation: { [weak self] id, source in
                            return self?.receiveTransferAnimation(id: id, source: source) ?? false
                        }, completed: { [weak self] in
                            self?.revealNewTransfer()
                        })
                    }
                    sendScreen.navigationPresentation = .modal
                    controller.push(sendScreen)
                }))
            } else {
                let peerSelectionScreen = WalletPeerSelectionScreen(
                    context: component.context,
                    walletContext: component.walletContext,
                    transferAnimation: { [weak self] id, source in
                        return self?.receiveTransferAnimation(id: id, source: source) ?? false
                    },
                    returnedToWallet: { [weak self] in
                        self?.revealNewTransfer()
                    }
                )
                peerSelectionScreen.navigationPresentation = .modal
                controller.push(peerSelectionScreen)
            }
        }

        private func finishResolvingSigningAccess(error: WalletContext.WalletError, address: String?) {
            self.isResolvingSigningAccess = false
            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            if error == .authorizationCancelled { self.abandonRestoration(); return }
            guard let component = self.component,
                  let controller = self.environment?.controller() else {
                return
            }
            let strings = self.currentPresentationData(for: component).initial.strings
            let message = walletAuthorizationErrorMessage(error, strings: strings)
            let generation = self.restorationGeneration
            controller.present(textAlertController(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                title: message?.title ?? strings.Wallet_RestoreErrorTitle,
                text: message?.text ?? strings.Wallet_NetworkError,
                actions: [
                    TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: { [weak self] in
                        guard let self, self.restorationGeneration == generation else { return }
                        self.abandonRestoration()
                    }),
                    TextAlertAction(type: .defaultAction, title: strings.Wallet_Retry, action: { [weak self] in
                        guard let self, self.restorationGeneration == generation else { return }
                        self.openSend(address: address)
                    })
                ],
                dismissOnOutsideTap: false
            ), in: .window(.root))
        }

        private func openRecoveryPhraseImport() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletImportScreen(
                context: component.context,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.completeRecoveryPhraseImport()
                }
            ))
        }

        private func completeRecoveryPhraseImport() {
            guard let component = self.component,
                  let walletController = self.environment?.controller(),
                  let navigationController = walletController.navigationController as? NavigationController,
                  let walletControllerIndex = navigationController.viewControllers.firstIndex(where: { $0 === walletController }) else {
                return
            }
            let viewControllers = Array(navigationController.viewControllers.prefix(through: walletControllerIndex))
            let presentationData = self.currentPresentationData(for: component).initial
            navigationController.setViewControllers(viewControllers, animated: true)
            Queue.mainQueue().after(0.4) { [weak walletController] in
                walletController?.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(
                        title: presentationData.strings.Wallet_Settings_WalletImportedTitle,
                        text: presentationData.strings.Wallet_Settings_WalletImportedText,
                        cancel: nil,
                        destructive: false
                    ),
                    position: .bottom,
                    action: { _ in false }
                ), in: .current)
            }
        }

        private func openWalletInfo() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletInfoScreen(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                mode: .wallet,
                completion: nil
            ))
        }

        private func openWalletSettings() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletSettingsScreen(context: component.context))
        }

        private func openWalletApps() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            controller.push(component.context.sharedContext.makeWalletAppsScreen(context: component.context))
        }

        private func openAccountProtection() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.isAwaitingAccountProtectionResult = true
            controller.push(component.context.sharedContext.makeSetupTwoFactorAuthController(context: component.context))
        }

        private func openPasscodeSettings() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let context = component.context
            let updatedPresentationData = self.currentPresentationData(for: component)
            let _ = passcodeOptionsAccessController(
                context: context,
                preferredModalWidth: 480.0,
                initialAutolockTimeout: nil,
                useCustomNumericKeyboard: true,
                allowFourDigitPasscode: false,
                replaceController: { [weak controller] passcodeController in
                    (controller?.navigationController as? NavigationController)?.replaceTopController(passcodeController, animated: true)
                },
                authorizationCompleted: { [weak controller] result in
                    guard case let .success(session) = result else { return }
                    guard let navigation = controller?.navigationController as? NavigationController else { session.invalidate(); return }
                    navigation.replaceTopController(PasscodeOptionsScreen(context: context, updatedPresentationData: updatedPresentationData, settingsSession: session, allowFourDigitPasscode: false), animated: true)
                }
            ).start(next: { [weak controller] passcodeController in
                if let passcodeController {
                    controller?.push(passcodeController)
                }
            })
        }

        private func openTerms(url: String) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            component.context.sharedContext.openExternalUrl(
                context: component.context,
                urlContext: .generic,
                url: url,
                forceExternal: false,
                presentationData: presentationData,
                navigationController: controller.navigationController as? NavigationController,
                dismissInput: {}
            )
        }

        private func openTransaction(_ transaction: WalletContext.Transaction) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            self.newTransferPresentationIds.removeAll()
            controller.push(WalletTransactionScreen(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                walletContext: component.walletContext,
                transaction: transaction,
                fromChat: false,
                decryptCommentOnOpen: false,
                transferAnimation: { [weak self] id, source in
                    return self?.receiveTransferAnimation(id: id, source: source) ?? false
                },
                returnedToWallet: { [weak self] in
                    self?.revealNewTransfer()
                }
            ))
        }

        private func openCollectible(_ collectible: WalletContext.Collectible) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let walletContext = component.walletContext
            controller.push(component.context.sharedContext.makeWalletCollectibleScreen(
                context: component.context,
                walletContext: walletContext,
                collectible: collectible,
                collectibleSent: { [weak self, weak walletContext] address in
                    guard let self, let walletContext, self.walletContext === walletContext else {
                        return
                    }
                    self.suppressCollectible(address: address)
                    self.showTransactions()
                }
            ))
        }

        private func suppressCollectible(address: String) {
            guard self.suppressedCollectibleAddresses.insert(address).inserted else {
                return
            }
            self.componentState?.updated(transition: .easeInOut(duration: 0.25))
        }

        private func updateSuppressedCollectibles(_ state: WalletContext.State) {
            switch state.phase {
            case let .wallet(info):
                if let currentAddress = self.suppressedCollectiblesWalletAddress, currentAddress != info.address {
                    self.suppressedCollectibleAddresses.removeAll()
                }
                self.suppressedCollectiblesWalletAddress = info.address
                let collectibles = state.collectibles
                if let previous = self.walletState?.collectibles,
                   previous.generation == collectibles.generation,
                   previous.isRefreshing || previous.isLoadingMore,
                   !collectibles.isRefreshing, !collectibles.isLoadingMore,
                   collectibles.error == nil, collectibles.nextOffset == nil {
                    self.suppressedCollectibleAddresses.formIntersection(collectibles.items.map(\.address))
                }
            case .restoring:
                break
            case .creating, .empty, .failed:
                self.suppressedCollectibleAddresses.removeAll()
                self.suppressedCollectiblesWalletAddress = nil
            }
        }

        private func openContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let presentationData = self.currentPresentationData(for: component).initial

            let selectedCurrency = self.walletState?.fiat.selectedCurrency ?? .usd

            let biometricContext = LAContext()
            _ = biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            let hasTouchId = biometricContext.biometryType == .touchID

            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(
                    text: presentationData.strings.Wallet_Currency,
                    textLayout: .secondLineWithValue(selectedCurrency.code),
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Globe"), color: theme.contextMenu.primaryColor)
                    },
                    additionalLeftIcon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Arrow"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] contextController, _ in
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        let selectedCurrency = self?.walletState?.fiat.selectedCurrency ?? .usd
                        let orderedCurrencies = walletCurrencyListItems(
                            selectedCurrency: selectedCurrency,
                            appLanguageCode: presentationData.strings.primaryComponent.languageCode,
                            fallbackAppLanguageCode: presentationData.strings.baseLanguageCode,
                            systemLanguageCode: Locale.preferredLanguages.first,
                            keyboardLanguageCodes: UITextInputMode.activeInputModes.compactMap { $0.primaryLanguage }
                        )
                        let searchQueryPromise = ValuePromise<String>("")
                        let currencyItems: [ContextMenuItem] = [
                            .action(ContextMenuActionItem(
                                text: presentationData.strings.Common_Back,
                                icon: { theme in
                                    return generateTintedImage(
                                        image: UIImage(bundleImageName: "Chat/Context Menu/Back"),
                                        color: theme.contextMenu.primaryColor
                                    )
                                },
                                iconPosition: .left,
                                action: { contextController, _ in
                                    contextController?.popItems()
                                }
                            )),
                            .separator,
                            .custom(WalletCurrencySearchContextItem(
                                context: component.context,
                                placeholder: presentationData.strings.Common_Search,
                                valueChanged: { value in
                                    searchQueryPromise.set(value)
                                }
                            ), false),
                            .separator,
                            .custom(WalletCurrencyListContextItem(
                                context: component.context,
                                currencies: orderedCurrencies,
                                selectedCurrency: selectedCurrency,
                                searchQuery: searchQueryPromise.get(),
                                currencySelected: { [weak self] currency in
                                    self?.component?.walletContext.setFiatCurrency(currency)
                                }
                            ), false)
                        ]
                        contextController?.pushItems(items: .single(ContextController.Items(content: .list(currencyItems))))
                    }
                )),
                .action(ContextMenuActionItem(
                    text: hasTouchId ? presentationData.strings.Wallet_PasscodeTouchId : presentationData.strings.Wallet_PasscodeFaceId,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: hasTouchId ? "Chat/Context Menu/TouchId" : "Chat/Context Menu/FaceId"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openPasscodeSettings()
                    }
                )),
                .action(ContextMenuActionItem(
                    text: presentationData.strings.Wallet_KeysAndBackup,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Cloud"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openWalletSettings()
                    }
                )),
                .separator,
                .action(ContextMenuActionItem(
                    text: presentationData.strings.Wallet_Info_Title,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Help"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.openWalletInfo()
                    }
                ))
            ]

            let connectedAppsItem = ContextMenuItem.action(ContextMenuActionItem(
                text: presentationData.strings.Wallet_Apps_Title,
                icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Apps"), color: theme.contextMenu.primaryColor)
                },
                action: { [weak self] _, dismiss in
                    dismiss(.default)
                    self?.openWalletApps()
                }
            ))
            let menuItems = component.walletContext.tonConnectState
            |> map { state -> Bool in
                return state.sessions.contains { session in
                    return session.manifest != nil && (session.status == .connected || session.status == .disconnecting)
                }
            }
            |> distinctUntilChanged
            |> deliverOnMainQueue
            |> map { hasConnectedApps -> ContextController.Items in
                var items = items
                if hasConnectedApps {
                    items.insert(connectedAppsItem, at: items.count - 2)
                }
                return ContextController.Items(content: .list(items))
            }
            let contextController = makeContextController(
                presentationData: presentationData,
                source: .reference(WalletContextReferenceContentSource(sourceView: sourceView)),
                items: menuItems,
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
        }

        private func updateHeader(
            component: WalletScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: EnvironmentType,
            transition: ComponentTransition
        ) -> (originY: CGFloat, size: CGSize) {
            let leftButton: AnyComponentWithIdentity<NavigationButtonComponentEnvironment> = AnyComponentWithIdentity(
                id: "back",
                component: AnyComponent(NavigationButtonComponent(
                    content: .icon(imageName: environment.metrics.widthClass == .regular ? "Navigation/Close" : "Navigation/Back"),
                    pressed: { [weak self] _ in
                        self?.dismiss()
                    }
                ))
            )
            let rightButtons: [AnyComponentWithIdentity<NavigationButtonComponentEnvironment>] = [
                AnyComponentWithIdentity(
                    id: "more",
                    component: AnyComponent(NavigationButtonComponent(
                        content: .more,
                        pressed: { [weak self] sourceView in
                            self?.openContextMenu(sourceView: sourceView)
                        }
                    ))
                ),
                AnyComponentWithIdentity(
                    id: "scanQr",
                    component: AnyComponent(NavigationButtonComponent(
                        content: .icon(imageName: "Navigation/ScanQr"),
                        pressed: { [weak self] _ in
                            self?.openQrCodeScanner()
                        }
                    ))
                )
            ]
            let primaryContent = ChatListHeaderComponent.Content(
                title: "",
                navigationBackTitle: nil,
                titleComponent: nil,
                chatListTitle: nil,
                leftButton: leftButton,
                rightButtons: rightButtons,
                backPressed: nil
            )

            let headerSize = self.header.update(
                transition: transition,
                component: AnyComponent(ChatListHeaderComponent(
                    leftInset: 16.0 + environment.safeInsets.left,
                    rightInset: 16.0 + environment.safeInsets.right,
                    primaryContent: primaryContent,
                    secondaryContent: nil,
                    secondaryTransition: 0.0,
                    networkStatus: nil,
                    storySubscriptions: nil,
                    storiesIncludeHidden: false,
                    storiesFraction: 0.0,
                    storiesUnlocked: false,
                    uploadProgress: [:],
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    openStatusSetup: { _ in
                    },
                    toggleIsLocked: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 44.0)
            )
            let headerOriginY: CGFloat
            if environment.metrics.widthClass == .regular {
                headerOriginY = 16.0
            } else if environment.statusBarHeight < 1.0 {
                headerOriginY = 0.0
            } else {
                headerOriginY = environment.statusBarHeight + 10.0
            }
            if let headerView = self.header.view {
                if headerView.superview == nil {
                    self.insertSubview(headerView, aboveSubview: self.cardBalanceClippingView)
                }
                transition.setFrame(
                    view: headerView,
                    frame: CGRect(
                        origin: CGPoint(x: 0.0, y: headerOriginY),
                        size: headerSize
                    )
                )
            }

            self.navigationTitle.parentState = state
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(Text(
                    text: environment.strings.Settings_Money,
                    font: Font.semibold(17.0),
                    color: environment.theme.rootController.navigationBar.primaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: headerSize.height)
            )
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    navigationTitleView.isUserInteractionEnabled = false
                    self.insertSubview(navigationTitleView, belowSubview: self.cardContainerView)
                }
                transition.setFrame(
                    view: navigationTitleView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: floor((availableSize.width - navigationTitleSize.width) * 0.5),
                            y: headerOriginY + floor((headerSize.height - navigationTitleSize.height) * 0.5)
                        ),
                        size: navigationTitleSize
                    )
                )
            }

            self.navigationBalance.parentState = state
            let navigationBalanceSize = self.navigationBalance.update(
                transition: transition,
                component: AnyComponent(WalletNavigationBalanceComponent(
                    theme: environment.theme,
                    balance: self.displayBalance,
                    fiatCurrency: self.walletState?.fiat.selectedCurrency ?? .usd,
                    fiatRate: self.walletState?.fiat.selectedRate,
                    dateTimeFormat: environment.dateTimeFormat
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(0.0, availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 200.0),
                    height: headerSize.height
                )
            )
            if let navigationBalanceView = self.navigationBalance.view {
                let navigationBalanceFrame = CGRect(
                    origin: CGPoint(
                        x: floor((availableSize.width - navigationBalanceSize.width) * 0.5),
                        y: headerOriginY + floor((headerSize.height - navigationBalanceSize.height) * 0.5)
                    ),
                    size: navigationBalanceSize
                )
                if navigationBalanceView.superview == nil {
                    navigationBalanceView.isUserInteractionEnabled = false
                    self.navigationBalanceClippingView.addSubview(navigationBalanceView)
                }
                transition.setFrame(
                    view: navigationBalanceView,
                    frame: navigationBalanceFrame
                )
                transition.setSublayerTransform(
                    view: navigationBalanceView,
                    transform: CATransform3DIdentity
                )

                let maximumHitWidth = max(
                    0.0,
                    availableSize.width - environment.safeInsets.left - environment.safeInsets.right - 200.0
                )
                let hitSize = CGSize(
                    width: max(44.0, min(maximumHitWidth, navigationBalanceSize.width + 16.0)),
                    height: max(44.0, headerSize.height)
                )
                transition.setFrame(
                    view: self.navigationBalanceButton,
                    frame: CGRect(
                        origin: CGPoint(
                            x: floor((availableSize.width - hitSize.width) * 0.5),
                            y: headerOriginY + floor((headerSize.height - hitSize.height) * 0.5)
                        ),
                        size: hitSize
                    )
                )
                self.navigationBalanceButton.accessibilityLabel = environment.strings.Stars_Intro_Balance
            }

            let topEdgeEffectHeight = environment.navigationHeight
            let topEdgeEffectFrame = CGRect(
                origin: CGPoint(x: 0.0, y: -20.0),
                size: CGSize(width: availableSize.width, height: 20.0 + topEdgeEffectHeight + 24.0)
            )
            transition.setFrame(view: self.topEdgeEffectView, frame: topEdgeEffectFrame)
            self.topEdgeEffectView.update(
                content: environment.theme.list.blocksBackgroundColor,
                blur: true,
                rect: CGRect(origin: CGPoint(), size: topEdgeEffectFrame.size),
                edge: .top,
                edgeSize: 64.0,
                transition: transition
            )
            return (headerOriginY, headerSize)
        }

        func update(
            component: WalletScreenComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            if self.component?.context !== component.context || self.walletContext !== component.walletContext {
                self.dismissGramTooltip(animated: false)
                self.gramTooltipWalletAddress = nil
                self.didPresentGramTooltip = false
            } else if !environment.isVisible {
                self.dismissGramTooltip(animated: false)
            }
            self.component = component
            self.environment = environment
            self.componentState = state
            let previousContentOffset = self.scrollView.contentOffset
            let clippingFrame = CGRect(origin: .zero, size: availableSize)
            ComponentTransition.immediate.setFrame(view: self.cardBalanceClippingView, frame: clippingFrame)
            ComponentTransition.immediate.setFrame(view: self.navigationBalanceClippingView, frame: clippingFrame)

            if self.walletContext !== component.walletContext {
                self.cancelWaltBalanceOpening()
                self.abandonRestoration()
                self.walletStateDisposable?.dispose()
                self.previousWalletsGeneration &+= 1
                self.previousWalletsDisposable.set(nil)
                self.previousWalletsBalance = 0
                self.loadMoreRequestId = nil
                self.loadMoreDisposable.set(nil)
                self.suppressedCollectibleAddresses.removeAll()
                self.suppressedCollectiblesWalletAddress = nil
                let subscribedContext = component.walletContext
                self.walletContext = subscribedContext
                self.pendingTransferAnimations.removeAll()
                self.newTransferPresentationIds.removeAll()
                self.pendingTransferToReveal = nil
                self.shouldRevealLatestTransactions = false
                self.isReturningForTransfer = false
                self.walletState = nil
                self.transferForegroundDisposable.set((component.context.sharedContext.applicationBindings.applicationInForeground
                |> distinctUntilChanged |> deliverOnMainQueue).start(next: { [weak self] foreground in
                    self?.transferApplicationInForeground = foreground
                    self?.updatePendingTransferAnimations()
                }))
                self.walletStateDisposable = (subscribedContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.walletContext === subscribedContext else {
                        return
                    }
                    let isFirstState = self.walletState == nil
                    let previousPhase = self.walletState?.phase
                    let previousWalletAddress = self.walletAddress
                    if case let .wallet(previousInfo) = self.walletState?.phase {
                        switch walletState.phase {
                        case let .wallet(info) where previousInfo.address == info.address && previousInfo.publicKey == info.publicKey:
                            break
                        default:
                            self.cancelWaltBalanceOpening()
                            self.abandonRestoration()
                            self.shouldRevealLatestTransactions = false
                        }
                    }
                    self.updateSuppressedCollectibles(walletState)
                    self.observePendingTransfers(walletState)
                    self.walletState = walletState
                    if previousPhase != walletState.phase || previousWalletAddress != walletState.walletAddress {
                        if previousWalletAddress != walletState.walletAddress {
                            self.previousWalletsBalance = 0
                        }
                        self.reloadPreviousWallets()
                    }
                    if !self.isUpdating {
                        self.componentState?.updated(transition: isFirstState ? .immediate : .easeInOut(duration: 0.25))
                    }
                })
            }

            if self.twoStepAuthData !== component.context.twoStepAuthData {
                self.twoStepAuthDataDisposable?.dispose()
                let subscribedTwoStepAuthData = component.context.twoStepAuthData
                self.twoStepAuthData = subscribedTwoStepAuthData
                self.hasTwoStepAuth = nil
                self.twoStepAuthDataDisposable = (subscribedTwoStepAuthData.get()
                |> deliverOnMainQueue).start(next: { [weak self, weak subscribedTwoStepAuthData] data in
                    guard let self, let subscribedTwoStepAuthData, self.twoStepAuthData === subscribedTwoStepAuthData else {
                        return
                    }
                    let hadTwoStepAuthValue = self.hasTwoStepAuth != nil
                    
                    let hasTwoStepAuth: Bool?
                    if let data {
                        hasTwoStepAuth = data.currentPasswordDerivation != nil || data.unconfirmedEmailPattern != nil
                    } else {
                        hasTwoStepAuth = nil
                    }
                    if self.hasTwoStepAuth != hasTwoStepAuth {
                        self.hasTwoStepAuth = hasTwoStepAuth
                        if !self.isUpdating {
                            self.componentState?.updated(transition: hadTwoStepAuthValue ? .easeInOut(duration: 0.2) : .immediate)
                        }
                    }
                })
            }

            if self.accountContext !== component.context {
                self.cancelWaltBalanceOpening()
                self.accountPeerDisposable?.dispose()
                self.existingWaltBalanceDisposable.set(nil)
                self.isLoadingExistingWaltBalance = false
                self.earningsDisposable.set(nil)
                let subscribedContext = component.context
                self.accountContext = subscribedContext
                self.accountName = ""
                self.existingWaltBalance = nil
                self.availableEarnings = nil
                self.loadExistingWaltBalance()
                
                let earningsContext = subscribedContext.engine.payments.peerStarsRevenueContext(peerId: subscribedContext.account.peerId, ton: true)
                self.earningsContext = earningsContext
                self.earningsDisposable.set((earningsContext.state
                |> deliverOnMainQueue).start(next: { [weak self] revenueState in
                    guard let self, self.accountContext === subscribedContext else {
                        return
                    }
                    let availableEarningsBalance: CurrencyAmount?
                    if let balance = revenueState.stats?.balances.availableBalance, balance.currency == .ton {
                        availableEarningsBalance = balance
                    } else {
                        availableEarningsBalance = nil
                    }
                    if self.availableEarnings != availableEarningsBalance {
                        self.availableEarnings = availableEarningsBalance
                        if !self.isUpdating {
                            self.componentState?.updated(transition: self.additionalBalancesTransition)
                        }
                    }
                }))
                
                self.accountPeerDisposable = (subscribedContext.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: subscribedContext.account.peerId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, self.accountContext === subscribedContext else {
                        return
                    }
                    let accountName = peer?.debugDisplayTitle.uppercased() ?? ""
                    if self.accountName != accountName {
                        self.accountName = accountName
                        if !self.isUpdating {
                            self.componentState?.updated(transition: .immediate)
                        }
                    }
                })
            }

            let transactions = (self.walletState?.transactions.items ?? []).filter {
                $0.isVisibleInWalletHistory && $0.kind != .deployContract
            }
            let collectibles = (self.walletState?.collectibles.items ?? []).filter {
                !self.suppressedCollectibleAddresses.contains($0.address)
            }
            if collectibles.isEmpty && self.selectedSection == .collectibles {
                self.selectedSection = .transactions
            }
            let hasEmptyTransactions = self.selectedSection == .transactions && transactions.isEmpty

            let headerLayout = self.updateHeader(
                component: component,
                availableSize: availableSize,
                state: state,
                environment: environment,
                transition: transition
            )
            let headerOriginY = headerLayout.originY
            let headerSize = headerLayout.size
            let sideInset: CGFloat = 16.0
            let cardWidth = max(
                0.0,
                availableSize.width - environment.safeInsets.left - environment.safeInsets.right - sideInset * 2.0
            )
            let previousCardTransitionStart = self.cardTransitionStart
            let additionalBalancesOriginY = headerOriginY + headerSize.height + 10.0
            self.cardTransitionStart = self.updateAdditionalBalancesSection(
                environment: environment,
                state: state,
                origin: CGPoint(x: environment.safeInsets.left + sideInset, y: additionalBalancesOriginY),
                width: cardWidth,
                transition: transition
            )
            let additionalBalancesHeightChanged = previousCardTransitionStart != self.cardTransitionStart
            let compensateAdditionalBalancesOffset = additionalBalancesHeightChanged && previousContentOffset.y > 0.0
            let contentLayoutTransition = compensateAdditionalBalancesOffset ? transition.withAnimation(.none) : transition
            let cardOriginY = additionalBalancesOriginY + self.cardTransitionStart
            let walletAddress = self.walletAddress
            let fiatCurrency = self.walletState?.fiat.selectedCurrency ?? .usd
            let fiatRate = self.walletState?.fiat.selectedRate
            self.card.parentState = state
            let cardSize = self.card.update(
                transition: transition,
                component: AnyComponent(WalletCardComponent(
                    theme: environment.theme,
                    balance: self.displayBalance,
                    fiatCurrency: fiatCurrency,
                    fiatRate: fiatRate,
                    dateTimeFormat: environment.dateTimeFormat,
                    name: self.accountName,
                    address: walletAddress ?? "",
                    isVisible: environment.isVisible,
                    cardPressed: { [weak self] in
                        self?.openReceive()
                    },
                    qrPressed: { [weak self] in
                        self?.openReceive()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: cardWidth, height: availableSize.height)
            )
            self.cardExpandedFrame = CGRect(
                origin: CGPoint(
                    x: environment.safeInsets.left + sideInset,
                    y: cardOriginY
                ),
                size: cardSize
            )
            ComponentTransition.immediate.setFrame(
                view: self.cardVisualContainerView,
                frame: CGRect(origin: CGPoint(), size: cardSize)
            )
            if let cardView = self.card.view {
                if cardView.superview !== self.cardVisualContainerView {
                    self.cardVisualContainerView.addSubview(cardView)
                }
                contentLayoutTransition.setFrame(
                    view: cardView,
                    frame: CGRect(
                        origin: CGPoint(),
                        size: cardSize
                    )
                )
                if let cardView = cardView as? WalletCardComponent.View {
                    cardView.setBalanceTransitionContainer(self.cardBalanceCoordinateView)
                    cardView.balanceGeometryUpdated = { [weak self, weak cardView] in
                        guard let self,
                              let cardView,
                              !self.isUpdating,
                              let currentCardView = self.card.view as? WalletCardComponent.View,
                              currentCardView === cardView else {
                            return
                        }
                        if self.scrollView.contentOffset.y > self.cardTransitionStart {
                            self.updateScrolling(transition: .immediate)
                        } else {
                            self.updateGramTooltip()
                        }
                    }
                }
            }

            let buttonsSpacing: CGFloat = 10.0
            let addFundsButtonWidth = floorToScreenPixels((cardWidth - buttonsSpacing) * 0.5)
            let sendButtonWidth = cardWidth - buttonsSpacing - addFundsButtonWidth
            let buttonsOriginY = cardOriginY + cardSize.height + self.cardSpacing
            let buttonBackground = ButtonComponent.Background(
                style: .glass,
                color: environment.theme.list.itemCheckColors.fillColor,
                foreground: environment.theme.list.itemCheckColors.foregroundColor,
                pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
            )
            let isNewAddFundsButton = self.addFundsButton.view?.superview == nil
            self.addFundsButton.parentState = state
            let addFundsButtonSize = self.addFundsButton.update(
                transition: isNewAddFundsButton ? .immediate : transition,
                component: AnyComponent(ButtonComponent(
                    background: buttonBackground,
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(
                            text: environment.strings.Wallet_AddFunds,
                            font: Font.semibold(17.0),
                            color: environment.theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: walletAddress != nil,
                    action: { [weak self] in
                        self?.openReceive()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: addFundsButtonWidth, height: 52.0)
            )
            if let addFundsButtonView = self.addFundsButton.view {
                if addFundsButtonView.superview == nil {
                    self.topContentContainerView.addSubview(addFundsButtonView)
                }
                let buttonFrame = CGRect(
                    origin: CGPoint(x: environment.safeInsets.left + sideInset, y: buttonsOriginY),
                    size: addFundsButtonSize
                )
                let layoutTransition: ComponentTransition = isNewAddFundsButton ? .immediate : contentLayoutTransition
                layoutTransition.setPosition(view: addFundsButtonView, position: buttonFrame.center)
                layoutTransition.setBounds(
                    view: addFundsButtonView,
                    bounds: CGRect(origin: .zero, size: buttonFrame.size)
                )
            }

            let isNewSendButton = self.sendButton.view?.superview == nil
            self.sendButton.parentState = state
            let sendButtonSize = self.sendButton.update(
                transition: isNewSendButton ? .immediate : transition,
                component: AnyComponent(ButtonComponent(
                    background: buttonBackground,
                    content: AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(
                            text: environment.strings.Wallet_Send,
                            font: Font.semibold(17.0),
                            color: environment.theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: walletAddress != nil && !self.isResolvingSigningAccess,
                    displaysProgress: self.isResolvingSigningAccess,
                    action: { [weak self] in
                        self?.openSend()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: sendButtonWidth, height: 52.0)
            )
            if let sendButtonView = self.sendButton.view {
                if sendButtonView.superview == nil {
                    self.topContentContainerView.addSubview(sendButtonView)
                }
                let buttonFrame = CGRect(
                    origin: CGPoint(
                        x: environment.safeInsets.left + sideInset + addFundsButtonWidth + buttonsSpacing,
                        y: buttonsOriginY
                    ),
                    size: sendButtonSize
                )
                let layoutTransition: ComponentTransition = isNewSendButton ? .immediate : contentLayoutTransition
                layoutTransition.setPosition(view: sendButtonView, position: buttonFrame.center)
                layoutTransition.setBounds(
                    view: sendButtonView,
                    bounds: CGRect(origin: .zero, size: buttonFrame.size)
                )
            }

            let buttonsHeight = max(addFundsButtonSize.height, sendButtonSize.height)
            var contentHeight = buttonsOriginY + buttonsHeight
            ComponentTransition.immediate.setFrame(
                view: self.topContentContainerView,
                frame: CGRect(
                    origin: .zero,
                    size: CGSize(width: availableSize.width, height: contentHeight)
                )
            )

            if self.hasTwoStepAuth == false && !transactions.isEmpty {
                var transition = contentLayoutTransition
                if self.accountProtectionSection.view?.superview == nil {
                    transition = .immediate
                }
                self.accountProtectionSection.parentState = state
                let accountProtectionSectionSize = self.accountProtectionSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: "accountProtection", component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                style: .glass,
                                title: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.Wallet_ProtectAccount,
                                        font: Font.regular(17.0),
                                        textColor: environment.theme.list.itemDestructiveColor
                                    )),
                                    maximumNumberOfLines: 1
                                )),
                                leftIcon: .custom(AnyComponentWithIdentity(
                                    id: "accountProtectionIcon",
                                    component: AnyComponent(Image(
                                        image: self.accountProtectionIcon,
                                        size: CGSize(width: 30.0, height: 30.0)
                                    ))
                                ), false),
                                accessory: .arrow,
                                action: { [weak self] _ in
                                    self?.openAccountProtection()
                                }
                            )))
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: cardWidth, height: 10000.0)
                )
                if let accountProtectionSectionView = self.accountProtectionSection.view {
                    if accountProtectionSectionView.superview == nil {
                        self.scrollView.addSubview(accountProtectionSectionView)
                    }
                    let accountProtectionOriginY = contentHeight + 12.0
                    transition.setFrame(
                        view: accountProtectionSectionView,
                        frame: CGRect(
                            origin: CGPoint(x: environment.safeInsets.left + sideInset, y: accountProtectionOriginY),
                            size: accountProtectionSectionSize
                        )
                    )
                    contentHeight = accountProtectionOriginY + accountProtectionSectionSize.height
                }
            } else {
                self.accountProtectionSection.view?.removeFromSuperview()
            }

            if !collectibles.isEmpty {
                let transactionTabsOriginY = contentHeight + 12.0
                let transactionTabsSize = self.updateTransactionTabs(
                    component: component,
                    environment: environment,
                    state: state,
                    availableWidth: availableSize.width,
                    containerWidth: cardWidth,
                    originY: transactionTabsOriginY,
                    transition: contentLayoutTransition
                )
                contentHeight = transactionTabsOriginY + transactionTabsSize.height
            } else if self.transactionTabsBackgroundView.superview != nil {
                self.transactionTabsBackgroundView.removeFromSuperview()
            }

            if self.selectedSection == .transactions && !transactions.isEmpty {
                self.hideSection(self.collectiblesSection, transition: transition)

                let itemContext = component.context
                let itemTheme = environment.theme
                let itemStrings = environment.strings
                let itemDateTimeFormat = environment.dateTimeFormat
                let items: [LazySectionView.Item] = transactions.map { transaction in
                    return LazySectionView.Item(
                        id: AnyHashable(transaction.presentationId),
                        height: transaction.collectible == nil ? walletTransactionItemHeight : walletCollectibleTransactionItemHeight,
                        component: { [weak self] in
                            return AnyComponent(ListActionItemComponent(
                                theme: itemTheme,
                                style: .glass,
                                title: AnyComponent(WalletTransactionItemComponent(
                                    context: itemContext,
                                    theme: itemTheme,
                                    strings: itemStrings,
                                    dateTimeFormat: itemDateTimeFormat,
                                    transaction: transaction,
                                    walletAddress: walletAddress,
                                    animatesPendingTransfer: self?.pendingTransferAnimations[transaction.presentationId] != nil
                                )),
                                contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 8.0, right: 0.0),
                                separatorInset: 62.0,
                                icon: nil,
                                accessory: nil,
                                action: { [weak self] _ in
                                    self?.openTransaction(transaction)
                                },
                                highlighting: .default
                            ))
                        }
                    )
                }

                let transactionsOriginY = contentHeight + 12.0
                let transactionsFrame = CGRect(
                    origin: CGPoint(x: environment.safeInsets.left + sideInset, y: transactionsOriginY),
                    size: CGSize(width: cardWidth, height: 0.0)
                )
                let walletConfiguration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                let formattedMinAmount = formatTonAmountText(
                    walletConfiguration.transferMinAmount,
                    dateTimeFormat: environment.dateTimeFormat,
                    maxDecimalPositions: 9,
                    formatString: environment.strings.Currency_Grams
                )
                let transactionsSectionSize = self.updateSection(
                    self.transactionsSection,
                    theme: environment.theme,
                    state: state,
                    items: items,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.Wallet_HiddenTransactions(formattedMinAmount).string,
                            font: Font.regular(13.0),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    frame: transactionsFrame,
                    viewportSize: availableSize,
                    transition: contentLayoutTransition
                )
                contentHeight = transactionsOriginY + transactionsSectionSize.height
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view, emptyTransactionsInfoView.superview != nil {
                    transition.setAlpha(view: emptyTransactionsInfoView, alpha: 0.0, completion: { [weak emptyTransactionsInfoView] _ in
                        emptyTransactionsInfoView?.removeFromSuperview()
                    })
                }
                self.hideEmptyTransactionsFooter(transition: transition)
                
                transition.setBackgroundColor(view: self, color: environment.theme.list.blocksBackgroundColor)
            } else if self.selectedSection == .collectibles {
                self.hideSection(self.transactionsSection, transition: transition)
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view {
                    emptyTransactionsInfoView.removeFromSuperview()
                }
                self.hideEmptyTransactionsFooter(transition: transition)

                let itemContext = component.context
                let itemTheme = environment.theme
                let items: [LazySectionView.Item] = collectibles.map { collectible in
                    return LazySectionView.Item(
                        id: AnyHashable(collectible.address),
                        height: walletCollectibleItemHeight,
                        component: { [weak self] in
                            return AnyComponent(ListActionItemComponent(
                                theme: itemTheme,
                                style: .glass,
                                title: AnyComponent(WalletCollectibleItemComponent(
                                    context: itemContext,
                                    theme: itemTheme,
                                    collectible: collectible
                                )),
                                contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0),
                                separatorInset: 60.0,
                                icon: nil,
                                accessory: nil,
                                action: { [weak self] _ in
                                    self?.openCollectible(collectible)
                                },
                                highlighting: .default
                            ))
                        }
                    )
                }

                let collectiblesOriginY = contentHeight + 12.0
                let collectiblesFrame = CGRect(
                    origin: CGPoint(x: environment.safeInsets.left + sideInset, y: collectiblesOriginY),
                    size: CGSize(width: cardWidth, height: 0.0)
                )
                let collectiblesSectionSize = self.updateSection(
                    self.collectiblesSection,
                    theme: environment.theme,
                    state: state,
                    items: items,
                    footer: nil,
                    frame: collectiblesFrame,
                    viewportSize: availableSize,
                    transition: contentLayoutTransition
                )
                contentHeight = collectiblesOriginY + collectiblesSectionSize.height

                transition.setBackgroundColor(view: self, color: environment.theme.list.blocksBackgroundColor)
            } else {
                if collectibles.isEmpty && self.transactionTabsBackgroundView.superview != nil {
                    self.transactionTabsBackgroundView.removeFromSuperview()
                }
                self.collectiblesSection.removeFromSuperview()
                self.collectiblesSection.clearVisibleItems()
                self.hideSection(self.transactionsSection, transition: transition)

                let titleColor = environment.theme.actionSheet.primaryTextColor
                let textColor = environment.theme.actionSheet.secondaryTextColor
                let accentColor = environment.theme.list.itemAccentColor
                let emptyItems: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(
                        id: "instantTransfers",
                        component: AnyComponent(InfoParagraphComponent(
                            title: environment.strings.Wallet_Empty_InstantTransfersTitle,
                            titleColor: titleColor,
                            text: environment.strings.Wallet_Info_InstantTransfersText,
                            textColor: textColor,
                            accentColor: accentColor,
                            iconName: "Wallet/InfoFast",
                            iconColor: accentColor
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "zeroFees",
                        component: AnyComponent(InfoParagraphComponent(
                            title: environment.strings.Wallet_Empty_ZeroFeesTitle,
                            titleColor: titleColor,
                            text: environment.strings.Wallet_Info_ZeroFeesText,
                            textColor: textColor,
                            accentColor: accentColor,
                            iconName: "Wallet/InfoCheap",
                            iconColor: accentColor
                        ))
                    ),
                    AnyComponentWithIdentity(
                        id: "blockchainVerified",
                        component: AnyComponent(InfoParagraphComponent(
                            title: environment.strings.Wallet_Info_BlockchainVerifiedTitle,
                            titleColor: titleColor,
                            text: environment.strings.Wallet_Info_BlockchainVerifiedText,
                            textColor: textColor,
                            accentColor: accentColor,
                            iconName: "Wallet/InfoVerified",
                            iconColor: accentColor
                        ))
                    )
                ]

                let emptyTransactionsOriginY = contentHeight + 36.0
                self.emptyTransactionsInfo.parentState = state
                let emptyTransactionsInfoSize = self.emptyTransactionsInfo.update(
                    transition: transition,
                    component: AnyComponent(List(emptyItems)),
                    environment: {},
                    containerSize: CGSize(width: cardWidth - 64.0, height: 10000.0)
                )
                if let emptyTransactionsInfoView = self.emptyTransactionsInfo.view {
                    var wasVisible = true
                    if emptyTransactionsInfoView.superview == nil {
                        wasVisible = false
                        self.scrollView.addSubview(emptyTransactionsInfoView)
                    }
                    if !transition.animation.isImmediate && !wasVisible {
                        transition.animateAlpha(view: emptyTransactionsInfoView, from: 0.0, to: 1.0)
                    } else {
                        transition.setAlpha(view: emptyTransactionsInfoView, alpha: 1.0)
                    }

                    var layoutTransition = contentLayoutTransition
                    if !wasVisible {
                        layoutTransition = .immediate
                    }
                    layoutTransition.setFrame(
                        view: emptyTransactionsInfoView,
                        frame: CGRect(
                            origin: CGPoint(x: floor((availableSize.width - emptyTransactionsInfoSize.width) / 2.0), y: emptyTransactionsOriginY),
                            size: emptyTransactionsInfoSize
                        )
                    )
                }
                contentHeight = emptyTransactionsOriginY + emptyTransactionsInfoSize.height

                let url = environment.strings.Wallet_TermsText_URL
                self.emptyTransactionsFooter.parentState = state
                let emptyTransactionsFooterSize = self.emptyTransactionsFooter.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: environment.strings.Wallet_TermsText, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: textColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: textColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: accentColor),
                            linkAttribute: { contents in
                                return (TelegramTextAttributes.URL, contents)
                            }
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        highlightColor: accentColor.withAlphaComponent(0.2),
                        highlightAction: { attributes in
                            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] != nil {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] _, _ in
                            self?.openTerms(url: url)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: cardWidth, height: 10000.0)
                )
                let emptyTransactionsFooterOriginY = max(
                    contentHeight + 24.0,
                    availableSize.height - environment.safeInsets.bottom - emptyTransactionsFooterSize.height - 16.0
                )
                if let emptyTransactionsFooterView = self.emptyTransactionsFooter.view {
                    var wasVisible = true
                    if emptyTransactionsFooterView.superview == nil {
                        wasVisible = false
                        self.scrollView.addSubview(emptyTransactionsFooterView)
                    }
                    if !transition.animation.isImmediate && !wasVisible {
                        transition.animateAlpha(view: emptyTransactionsFooterView, from: 0.0, to: 1.0)
                    } else {
                        transition.setAlpha(view: emptyTransactionsFooterView, alpha: 1.0)
                    }

                    let layoutTransition: ComponentTransition = wasVisible ? contentLayoutTransition : .immediate
                    layoutTransition.setFrame(
                        view: emptyTransactionsFooterView,
                        frame: CGRect(
                            origin: CGPoint(
                                x: floor((availableSize.width - emptyTransactionsFooterSize.width) * 0.5),
                                y: emptyTransactionsFooterOriginY
                            ),
                            size: emptyTransactionsFooterSize
                        )
                    )
                }
                contentHeight = emptyTransactionsFooterOriginY + emptyTransactionsFooterSize.height
                
                transition.setBackgroundColor(view: self, color: environment.theme.list.plainBackgroundColor)
            }

            transition.setFrame(
                view: self.scrollView,
                frame: CGRect(origin: CGPoint(), size: availableSize)
            )
            contentHeight += (hasEmptyTransactions ? 16.0 : 24.0) + environment.safeInsets.bottom
            self.scrollView.isScrollEnabled = !hasEmptyTransactions || contentHeight > availableSize.height + UIScreenPixel
            let minimumContentHeight = hasEmptyTransactions ? availableSize.height : availableSize.height + self.cardTransitionStart + self.cardTransitionDistance + 1.0
            let contentSize = CGSize(
                width: availableSize.width,
                height: max(contentHeight, minimumContentHeight)
            )
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            var contentOffset = previousContentOffset
            if compensateAdditionalBalancesOffset {
                contentOffset.y = max(0.0, contentOffset.y + self.cardTransitionStart - previousCardTransitionStart)
            }
            if !self.scrollView.isScrollEnabled {
                contentOffset = .zero
            } else if !self.scrollView.isTracking && !self.scrollView.isDecelerating {
                contentOffset.y = min(contentOffset.y, max(0.0, contentSize.height - availableSize.height))
            }
            if contentOffset != self.scrollView.contentOffset {
                self.scrollView.setContentOffset(contentOffset, animated: false)
            }
            let scrollInsets = UIEdgeInsets(
                top: headerOriginY + headerSize.height,
                left: 0.0,
                bottom: environment.safeInsets.bottom,
                right: 0.0
            )
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }

            self.revealLatestTransactionsIfNeeded(firstTransactionId: transactions.first?.presentationId)
            self.updateScrolling(transition: contentLayoutTransition)
            if let cardView = self.card.view as? WalletCardComponent.View {
                self.maybePresentGramTooltip(cardView: cardView)
            }
            self.updateVisibleSections(transition: .immediate)
            self.loadMoreItemsIfNeeded()

            self.revealPendingTransferIfNeeded()
            self.updatePendingTransferAnimations()
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

public final class WalletScreen: ViewControllerComponentContainer {
    private let walletContext: WalletContext
    private var walletScreenUpdatesDisposable: Disposable?
    private var didAppear = false

    public init(
        context: AccountContext,
        walletContext: WalletContext
    ) {
        self.walletContext = walletContext
        let updatedPresentationData = presentationDataWithDefaultAccent((
            initial: context.sharedContext.currentPresentationData.with { $0 },
            signal: context.sharedContext.presentationData
        ))
        super.init(
            context: context,
            component: WalletScreenComponent(
                context: context,
                updatedPresentationData: updatedPresentationData,
                walletContext: walletContext
            ),
            navigationBarAppearance: .transparent,
            statusBarStyle: .default,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )

        self.navigationPresentation = .modalInLargeLayout

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)

        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? WalletScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        guard layout.metrics.widthClass == .regular else {
            return nil
        }
        return CGSize(
            width: min(480.0, layout.size.width - 20.0),
            height: min(layout.size.width, layout.size.height) - 88.0
        )
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.didAppear = true
        if self.walletScreenUpdatesDisposable == nil {
            self.walletScreenUpdatesDisposable = self.walletContext.beginWalletScreenUpdates()
        }

        guard let componentView = self.node.hostView.componentView as? WalletScreenComponent.View else {
            return
        }
        componentView.setTransferAnimationsVisible(true)
        componentView.refreshTwoStepAuth()
        componentView.reloadPreviousWallets()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (self.node.hostView.componentView as? WalletScreenComponent.View)?.setTransferAnimationsVisible(false)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.navigationController?.viewControllers.contains(where: { $0 === self }) != true {
            (self.node.hostView.componentView as? WalletScreenComponent.View)?.abandonRestoration()
        }

        self.walletScreenUpdatesDisposable?.dispose()
        self.walletScreenUpdatesDisposable = nil
    }

    deinit {
        self.walletScreenUpdatesDisposable?.dispose()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class WalletContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    let forceDisplayBelowKeyboard = true

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceView,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            actionsPosition: .bottom
        )
    }
}
