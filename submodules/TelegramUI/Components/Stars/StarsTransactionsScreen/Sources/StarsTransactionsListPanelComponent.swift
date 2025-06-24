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
import MultilineTextComponent
import ListActionItemComponent
import TelegramStringFormatting
import AvatarNode
import BundleIconComponent
import PhotoResources
import StarsAvatarComponent
import GiftAnimationComponent
import TelegramStringFormatting

private extension StarsContext.State.Transaction {
    var extendedId: String {
        if self.count.amount > StarsAmount.zero {
            return "\(id)_in"
        } else {
            return "\(id)_out"
        }
    }
}

final class StarsTransactionsListPanelComponent: Component {
    typealias EnvironmentType = StarsTransactionsPanelEnvironment
        
    let context: AccountContext
    let transactionsContext: StarsTransactionsContext
    let isAccount: Bool
    let action: (StarsContext.State.Transaction) -> Void

    init(
        context: AccountContext,
        transactionsContext: StarsTransactionsContext,
        isAccount: Bool,
        action: @escaping (StarsContext.State.Transaction) -> Void
    ) {
        self.context = context
        self.transactionsContext = transactionsContext
        self.isAccount = isAccount
        self.action = action
    }
    
    static func ==(lhs: StarsTransactionsListPanelComponent, rhs: StarsTransactionsListPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.isAccount != rhs.isAccount {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        let containerInsets: UIEdgeInsets
        let containerWidth: CGFloat
        let itemHeight: CGFloat
        let itemCount: Int
        
        let contentHeight: CGFloat
        
        init(
            containerInsets: UIEdgeInsets,
            containerWidth: CGFloat,
            itemHeight: CGFloat,
            itemCount: Int
        ) {
            self.containerInsets = containerInsets
            self.containerWidth = containerWidth
            self.itemHeight = itemHeight
            self.itemCount = itemCount
            
            self.contentHeight = containerInsets.top + containerInsets.bottom + CGFloat(itemCount) * itemHeight
        }
        
        func visibleItems(for rect: CGRect) -> Range<Int>? {
            let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: -self.containerInsets.top)
            var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemHeight)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemHeight)))
            
            let minVisibleIndex = minVisibleRow
            let maxVisibleIndex = maxVisibleRow
            
            if maxVisibleIndex >= minVisibleIndex {
                return minVisibleIndex ..< (maxVisibleIndex + 1)
            } else {
                return nil
            }
        }
        
        func itemFrame(for index: Int) -> CGRect {
            return CGRect(origin: CGPoint(x: 0.0, y: self.containerInsets.top + CGFloat(index) * self.itemHeight), size: CGSize(width: self.containerWidth, height: self.itemHeight))
        }
    }
    
    private final class ScrollViewImpl: UIScrollView {
        var forceDecelerating = false
        
        override var isDecelerating: Bool {
            return self.forceDecelerating || super.isDecelerating
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollViewImpl
        
        private let measureItem = ComponentView<Empty>()
        private var visibleItems: [AnyHashable: ComponentView<Empty>] = [:]
        private var separatorLayers: [AnyHashable: SimpleLayer] = [:]
        private var highlightLayer = SimpleLayer()
        
        private var ignoreScrolling: Bool = false
        
        private var component: StarsTransactionsListPanelComponent?
        private var environment: StarsTransactionsPanelEnvironment?
        private var itemLayout: ItemLayout?
        
        private var items: [StarsContext.State.Transaction] = []
        private var itemsDisposable: Disposable?
        private var currentLoadMoreId: String?
        
        override init(frame: CGRect) {
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
            
            self.scrollView.layer.addSublayer(self.highlightLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.itemsDisposable?.dispose()
        }
        
        func scrollToTop() -> Bool {
            if self.scrollView.contentOffset.y > 0.0 {
                self.scrollView.setContentOffset(CGPoint(), animated: true)
                return true
            } else {
                return false
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            cancelContextGestures(view: scrollView)
            if let decelerationAnimator = self.decelerationAnimator {
                self.scrollView.forceDecelerating = false
                self.decelerationAnimator = nil
                decelerationAnimator.invalidate()
            }
        }
        
        private var decelerationAnimator: ConstantDisplayLinkAnimator?
        func transferVelocity(_ velocity: CGFloat) {
            if velocity <= 0.0 {
                return
            }
            self.decelerationAnimator?.isPaused = true
            let startTime = CACurrentMediaTime()
            var currentOffset = self.scrollView.contentOffset
            let decelerationRate: CGFloat = 0.998
            self.scrollView.forceDecelerating = true
            //self.scrollViewDidEndDragging(self.scrollView, willDecelerate: true)
            self.decelerationAnimator = ConstantDisplayLinkAnimator(update: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let t = CACurrentMediaTime() - startTime
                var currentVelocity = velocity * 15.0 * CGFloat(pow(Double(decelerationRate), 1000.0 * t))
                currentOffset.y += currentVelocity
                let maxOffset = strongSelf.scrollView.contentSize.height - strongSelf.scrollView.bounds.height
                if currentOffset.y >= maxOffset {
                    currentOffset.y = maxOffset
                    currentVelocity = 0.0
                }
                if currentOffset.y < 0.0 {
                    currentOffset.y = 0.0
                    currentVelocity = 0.0
                }

                var didEnd = false
                if abs(currentVelocity) < 0.1 {
                    strongSelf.decelerationAnimator?.isPaused = true
                    strongSelf.decelerationAnimator = nil
                    didEnd = true
                }
                var contentOffset = strongSelf.scrollView.contentOffset
                contentOffset.y = floorToScreenPixels(currentOffset.y)
                strongSelf.scrollView.setContentOffset(contentOffset, animated: false)
                strongSelf.scrollViewDidScroll(strongSelf.scrollView)
                if didEnd {
                    //strongSelf.scrollViewDidEndDecelerating(strongSelf.scrollView)
                    strongSelf.scrollView.forceDecelerating = false
                }
            })
            self.decelerationAnimator?.isPaused = false
        }
        
        private var highlightedItemId: AnyHashable?
        private func updateHighlightedItem(itemId: AnyHashable?) {
            guard let environment = self.environment else {
                return
            }
            if self.highlightedItemId == itemId {
                return
            }
            let previousHighlightedItemId = self.highlightedItemId
            self.highlightedItemId = itemId
            
            if let _ = previousHighlightedItemId, itemId == nil {
                ComponentTransition.easeInOut(duration: 0.2).setBackgroundColor(layer: self.highlightLayer, color: .clear)
            }
            if let itemId, let itemView = self.visibleItems[itemId]?.view {
                var highlightFrame = itemView.frame
                highlightFrame.size.height += UIScreenPixel
                self.highlightLayer.frame = highlightFrame
                ComponentTransition.immediate.setBackgroundColor(layer: self.highlightLayer, color: environment.theme.list.itemHighlightedBackgroundColor)
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment, let itemLayout = self.itemLayout else {
                return
            }
            
            var visibleBounds = environment.externalScrollBounds ?? self.scrollView.bounds
            visibleBounds = visibleBounds.insetBy(dx: 0.0, dy: -100.0)
            
            var validIds = Set<AnyHashable>()
            if let visibleItems = itemLayout.visibleItems(for: visibleBounds) {
                for index in visibleItems.lowerBound ..< visibleItems.upperBound {
                    if index >= self.items.count {
                        continue
                    }
                    let item = self.items[index]
                    let id = AnyHashable(item.extendedId)
                    validIds.insert(id)
                    
                    var itemTransition = transition
                    let itemView: ComponentView<Empty>
                    let separatorLayer: SimpleLayer
                    if let current = self.visibleItems[id], let currentSeparator = self.separatorLayers[id] {
                        itemView = current
                        separatorLayer = currentSeparator
                    } else {
                        itemTransition = .immediate
                        itemView = ComponentView()
                        self.visibleItems[id] = itemView
                        
                        separatorLayer = SimpleLayer()
                        self.separatorLayers[id] = separatorLayer
                        self.scrollView.layer.addSublayer(separatorLayer)
                    }
                    
                    separatorLayer.backgroundColor = environment.theme.list.itemBlocksSeparatorColor.cgColor
                    separatorLayer.isHidden = index == self.items.count - 1
                                  
                    let fontBaseDisplaySize = 17.0
                    
                    var itemTitle: String
                    let itemSubtitle: String?
                    var itemDate: String
                    var itemPeer = item.peer
                    var itemFile: TelegramMediaFile?
                    var uniqueGift: StarGift.UniqueGift?
                    switch item.peer {
                    case let .peer(peer):
                        if let months = item.premiumGiftMonths {
                            itemTitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                            itemSubtitle = environment.strings.Stars_Intro_Transaction_TelegramPremium(months)
                        } else if item.flags.contains(.isPaidMessage) {
                            itemTitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                            itemSubtitle = environment.strings.Stars_Intro_Transaction_PaidMessage(item.paidMessageCount ?? 1)
                        } else if let starGift = item.starGift {
                            if item.flags.contains(.isStarGiftUpgrade), case let .unique(gift) = starGift {
                                itemTitle = "\(gift.title) #\(presentationStringsFormattedNumber(gift.number, environment.dateTimeFormat.groupingSeparator))"
                                itemSubtitle = environment.strings.Stars_Intro_Transaction_GiftUpgrade
                                uniqueGift = gift
                            } else {
                                itemTitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                                switch starGift {
                                case let .generic(gift):
                                    itemFile = gift.file
                                    itemSubtitle = item.count.amount > StarsAmount.zero ? environment.strings.Stars_Intro_Transaction_ConvertedGift : environment.strings.Stars_Intro_Transaction_Gift
                                case let .unique(gift):
                                    for attribute in gift.attributes {
                                        if case let .model(_, file, _) = attribute {
                                            itemFile = file
                                            break
                                        }
                                    }
                                    if item.count.amount > StarsAmount.zero {
                                        itemSubtitle = environment.strings.Stars_Intro_Transaction_GiftSale
                                    } else {
                                        if item.flags.contains(.isStarGiftResale) {
                                            itemSubtitle = environment.strings.Stars_Intro_Transaction_GiftPurchase
                                        } else {
                                            itemSubtitle = environment.strings.Stars_Intro_Transaction_GiftTransfer
                                        }
                                    }
                                }
                            }
                        } else if let _ = item.giveawayMessageId {
                            itemTitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                            itemSubtitle = environment.strings.Stars_Intro_Transaction_GiveawayPrize
                        } else if !item.media.isEmpty {
                            itemTitle = environment.strings.Stars_Intro_Transaction_MediaPurchase
                            itemSubtitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                        } else if let title = item.title {
                            itemTitle = title
                            itemSubtitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                        } else {
                            itemTitle = peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
                            if item.flags.contains(.isReaction) {
                                itemSubtitle = environment.strings.Stars_Intro_Transaction_Reaction_Title
                            } else if item.flags.contains(.isGift) {
                                itemSubtitle = environment.strings.Stars_Intro_Transaction_Gift_Title
                            } else if let _ = item.subscriptionPeriod {
                                itemSubtitle = environment.strings.Stars_Intro_Transaction_SubscriptionFee_Title
                            } else {
                                itemSubtitle = nil
                            }
                        }
                    case .appStore:
                        itemTitle = environment.strings.Stars_Intro_Transaction_AppleTopUp_Title
                        itemSubtitle = environment.strings.Stars_Intro_Transaction_AppleTopUp_Subtitle
                    case .playMarket:
                        itemTitle = environment.strings.Stars_Intro_Transaction_GoogleTopUp_Title
                        itemSubtitle = environment.strings.Stars_Intro_Transaction_GoogleTopUp_Subtitle
                    case .fragment:
                        if component.isAccount {
                            if item.flags.contains(.isGift) {
                                itemTitle = environment.strings.Stars_Intro_Transaction_Gift_UnknownUser
                                itemSubtitle = environment.strings.Stars_Intro_Transaction_Gift_Title
                                itemPeer = .fragment
                            } else {
                                if (item.count.amount.value < 0 && !item.flags.contains(.isRefund)) || (item.count.amount.value > 0 && item.flags.contains(.isRefund)) {
                                    itemTitle = environment.strings.Stars_Intro_Transaction_FragmentWithdrawal_Title
                                    itemSubtitle = environment.strings.Stars_Intro_Transaction_FragmentWithdrawal_Subtitle
                                } else {
                                    itemTitle = environment.strings.Stars_Intro_Transaction_FragmentTopUp_Title
                                    itemSubtitle = environment.strings.Stars_Intro_Transaction_FragmentTopUp_Subtitle
                                }
                            }
                        } else {
                            if item.count.amount > StarsAmount.zero && !item.flags.contains(.isRefund) {
                                itemTitle = environment.strings.Stars_Intro_Transaction_FragmentTopUp_Title
                                itemSubtitle = environment.strings.Stars_Intro_Transaction_FragmentTopUp_Subtitle
                            } else {
                                itemTitle = environment.strings.Stars_Intro_Transaction_FragmentWithdrawal_Title
                                itemSubtitle = environment.strings.Stars_Intro_Transaction_FragmentWithdrawal_Subtitle
                            }
                        }
                    case .premiumBot:
                        itemTitle = environment.strings.Stars_Intro_Transaction_PremiumBotTopUp_Title
                        itemSubtitle = environment.strings.Stars_Intro_Transaction_PremiumBotTopUp_Subtitle
                    case .ads:
                        itemTitle = environment.strings.Stars_Intro_Transaction_TelegramAds_Title
                        itemSubtitle = environment.strings.Stars_Intro_Transaction_TelegramAds_Subtitle
                    case .apiLimitExtension:
                        itemTitle = environment.strings.Stars_Intro_Transaction_TelegramBotApi_Title
                        if let floodskipNumber = item.floodskipNumber {
                            itemSubtitle = environment.strings.Stars_Intro_Transaction_TelegramBotApi_Messages(floodskipNumber)
                        } else {
                            itemSubtitle = nil
                        }
                    case .unsupported:
                        itemTitle = environment.strings.Stars_Intro_Transaction_Unsupported_Title
                        itemSubtitle = nil
                    }
                    
                    let itemLabel: NSAttributedString
                    let formattedLabel = formatCurrencyAmountText(item.count, dateTimeFormat: environment.dateTimeFormat, showPlus: true)
                    
                    let smallLabelFont = Font.with(size: floor(fontBaseDisplaySize / 17.0 * 13.0))
                    let labelFont = Font.medium(fontBaseDisplaySize)
                    let labelColor = formattedLabel.hasPrefix("-") ? environment.theme.list.itemDestructiveColor : environment.theme.list.itemDisclosureActions.constructive.fillColor
                    itemLabel = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: environment.dateTimeFormat.decimalSeparator)
                    
                    let itemIconName: String
                    let itemIconColor: UIColor?
                    switch item.count.currency {
                    case .stars:
                        itemIconName = "Premium/Stars/StarMedium"
                        itemIconColor = nil
                    case .ton:
                        itemIconName = "Ads/TonAbout"
                        itemIconColor = labelColor
                    }
                    
                    var itemDateColor = environment.theme.list.itemSecondaryTextColor
                    itemDate = stringForMediumCompactDate(timestamp: item.date, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat)
                    if item.flags.contains(.isRefund) {
                        itemDate += " – \(environment.strings.Stars_Intro_Transaction_Refund)"
                    } else if item.flags.contains(.isPending) {
                        itemDate += " – \(environment.strings.Monetization_Transaction_Pending)"
                    } else if item.flags.contains(.isFailed) {
                        itemDate += " – \(environment.strings.Monetization_Transaction_Failed)"
                        itemDateColor = environment.theme.list.itemDestructiveColor
                    }
                                        
                    var titleComponents: [AnyComponentWithIdentity<Empty>] = []
                    titleComponents.append(
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: itemTitle,
                                font: Font.semibold(fontBaseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    )
                    if let itemSubtitle {
                        let subtitleComponent: AnyComponent<Empty>
                        if let itemFile {
                            subtitleComponent = AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(
                                        GiftAnimationComponent(
                                            context: component.context,
                                            theme: environment.theme,
                                            file: itemFile,
                                            still: true,
                                            size: CGSize(width: 20.0, height: 20.0)
                                        )
                                    )),
                                    AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(
                                        MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: itemSubtitle,
                                                font: Font.regular(fontBaseDisplaySize * 16.0 / 17.0),
                                                textColor: environment.theme.list.itemPrimaryTextColor
                                            )
                                        )
                                    )))
                                ], spacing: 2.0)
                            )
                        } else {
                            subtitleComponent = AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: itemSubtitle,
                                    font: Font.regular(fontBaseDisplaySize * 16.0 / 17.0),
                                    textColor: environment.theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))
                        }
                        
                        titleComponents.append(
                            AnyComponentWithIdentity(id: AnyHashable(1), component: subtitleComponent)
                        )
                    }
                    titleComponents.append(
                        AnyComponentWithIdentity(id: AnyHashable(2), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: itemDate,
                                font: Font.regular(floor(fontBaseDisplaySize * 14.0 / 17.0)),
                                textColor: itemDateColor
                            )),
                            maximumNumberOfLines: 1
                        )))
                    )
                    let _ = itemView.update(
                        transition: itemTransition,
                        component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack(titleComponents, alignment: .left, spacing: 2.0)),
                            contentInsets: UIEdgeInsets(top: 9.0, left: environment.containerInsets.left, bottom: 8.0, right: environment.containerInsets.right),
                            leftIcon: .custom(AnyComponentWithIdentity(id: "avatar", component: AnyComponent(StarsAvatarComponent(context: component.context, theme: environment.theme, peer: itemPeer, photo: item.photo, media: item.media, uniqueGift: uniqueGift, backgroundColor: environment.theme.list.plainBackgroundColor))), false),
                            icon: nil,
                            accessory: .custom(ListActionItemComponent.CustomAccessory(component: AnyComponentWithIdentity(id: "label", component: AnyComponent(StarsLabelComponent(text: itemLabel, iconName: itemIconName, iconColor: itemIconColor))), insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16.0))),
                            action: { [weak self] _ in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if !item.flags.contains(.isLocal) {
                                    component.action(item)
                                }
                            },
                            updateIsHighlighted: { [weak self] _, highlighted in
                                guard let self else {
                                    return
                                }
                                self.updateHighlightedItem(itemId: highlighted ? id : nil)
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: itemLayout.containerWidth - itemLayout.containerInsets.left - itemLayout.containerInsets.right, height: itemLayout.itemHeight)
                    )
                    let itemFrame = itemLayout.itemFrame(for: index).offsetBy(dx: itemLayout.containerInsets.left, dy: 0.0)
                    if let itemComponentView = itemView.view {
                        if itemComponentView.superview == nil {
                            if !transition.animation.isImmediate {
                                transition.animateAlpha(view: itemComponentView, from: 0.0, to: 1.0)
                            }
                            self.scrollView.addSubview(itemComponentView)
                        }
                        itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                    let sideInset: CGFloat = 60.0 + environment.containerInsets.left
                    itemTransition.setFrame(layer: separatorLayer, frame: CGRect(x: sideInset, y: itemFrame.maxY, width: itemFrame.width - sideInset - environment.containerInsets.right, height: UIScreenPixel))
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemComponentView = itemView.view {
                        transition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                            itemComponentView?.removeFromSuperview()
                        })
                    }
                }
            }
            for (id, separatorLayer) in self.separatorLayers {
                if !validIds.contains(id) {
                    transition.setAlpha(layer: separatorLayer, alpha: 0.0, completion: { [weak separatorLayer] _ in
                        separatorLayer?.removeFromSuperlayer()
                    })
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
            
            let bottomOffset = self.environment?.externalBottomOffset ?? max(0.0, self.scrollView.contentSize.height - self.scrollView.contentOffset.y - self.scrollView.frame.height)
            let loadMore = bottomOffset < 100.0
            if environment.isCurrent, loadMore {
                let lastId = self.items.last?.extendedId
                if lastId != self.currentLoadMoreId || lastId == nil {
                    self.currentLoadMoreId = lastId
                    component.transactionsContext.loadMore()
                }
            }
        }
        
        private var isUpdating = false
        func update(component: StarsTransactionsListPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StarsTransactionsPanelEnvironment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            if self.itemsDisposable == nil {
                self.itemsDisposable = (component.transactionsContext.state
                |> deliverOnMainQueue).start(next: { [weak self, weak state] status in
                    guard let self else {
                        return
                    }
                    let wasEmpty = self.items.isEmpty
                    let hadLocalTransactions = self.items.contains(where: { $0.flags.contains(.isLocal) })
                    
                    var existingIds = Set<String>()
                    var filteredItems: [StarsContext.State.Transaction] = []
                    for transaction in status.transactions {
                        let id = transaction.extendedId
                        if !existingIds.contains(id) {
                            existingIds.insert(id)
                            filteredItems.append(transaction)
                        }
                    }
                    
                    self.items = filteredItems
                    if !status.isLoading {
                        self.currentLoadMoreId = nil
                    }
                    if !self.isUpdating {
                        state?.updated(transition: wasEmpty || hadLocalTransactions ? .immediate : .easeInOut(duration: 0.2))
                    }
                })
            }
            
            let environment = environment[StarsTransactionsPanelEnvironment.self].value
            self.environment = environment
            
            let fontBaseDisplaySize = 17.0
            let measureItemSize = self.measureItem.update(
                transition: .immediate,
                component: AnyComponent(ListActionItemComponent(
                    theme: environment.theme,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "ABC",
                                font: Font.regular(fontBaseDisplaySize),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 0
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "abc",
                                font: Font.regular(fontBaseDisplaySize * 16.0 / 17.0),
                                textColor: environment.theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                        AnyComponentWithIdentity(id: AnyHashable(2), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: "abc",
                                font: Font.regular(floor(fontBaseDisplaySize * 14.0 / 17.0)),
                                textColor: environment.theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.18
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 8.0, right: 0.0),
                    leftIcon: nil,
                    icon: nil,
                    accessory: nil,
                    action: { _ in }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            
            let itemLayout = ItemLayout(
                containerInsets: environment.containerInsets,
                containerWidth: availableSize.width,
                itemHeight: measureItemSize.height,
                itemCount: self.items.count
            )
            self.itemLayout = itemLayout
            
            self.ignoreScrolling = true
            let contentOffset = self.scrollView.bounds.minY
            
            var scrollBounds = self.scrollView.bounds
            if let _ = environment.externalScrollBounds {
                scrollBounds.origin = CGPoint()
                scrollBounds.size = CGSize(width: availableSize.width, height: itemLayout.contentHeight)
                transition.setPosition(view: self.scrollView, position: scrollBounds.center)
            } else {
                transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
                scrollBounds.size = availableSize
                if !environment.isScrollable {
                    scrollBounds.origin = CGPoint()
                }
            }
            transition.setBounds(view: self.scrollView, bounds: scrollBounds)
            self.scrollView.isScrollEnabled = environment.isScrollable
            let contentSize = CGSize(width: availableSize.width, height: itemLayout.contentHeight)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.scrollView.verticalScrollIndicatorInsets = environment.containerInsets
            if !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            if let _ = environment.externalScrollBounds {
                return CGSize(width: availableSize.width, height: contentSize.height)
            } else {
                return availableSize
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StarsTransactionsPanelEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}
