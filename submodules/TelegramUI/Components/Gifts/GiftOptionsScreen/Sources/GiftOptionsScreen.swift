import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import Markdown
import TelegramStringFormatting
import PlainButtonComponent
import BlurredBackgroundComponent
import PremiumStarComponent
import ConfettiEffect
import TextFormat
import GiftItemComponent
import InAppPurchaseManager
import TabSelectorComponent
import GiftSetupScreen
import GiftViewScreen
import UndoUI

final class GiftOptionsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let starsContext: StarsContext
    let peerId: EnginePeer.Id
    let premiumOptions: [CachedPremiumGiftOption]
    let hasBirthday: Bool
    let completion: (() -> Void)?
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        peerId: EnginePeer.Id,
        premiumOptions: [CachedPremiumGiftOption],
        hasBirthday: Bool,
        completion: (() -> Void)?
    ) {
        self.context = context
        self.starsContext = starsContext
        self.peerId = peerId
        self.premiumOptions = premiumOptions
        self.hasBirthday = hasBirthday
        self.completion = completion
    }

    static func ==(lhs: GiftOptionsScreenComponent, rhs: GiftOptionsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.premiumOptions != rhs.premiumOptions {
            return false
        }
        if lhs.hasBirthday != rhs.hasBirthday {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    public enum StarsFilter: Equatable {
        case all
        case limited
        case stars(Int64)
        
        init(rawValue: Int64) {
            switch rawValue {
            case 0:
                self = .all
            case -1:
                self = .limited
            default:
                self = .stars(rawValue)
            }
        }
        
        public var rawValue: Int64 {
            switch self {
            case .all:
                return 0
            case .limited:
                return -1
            case let .stars(stars):
                return stars
            }
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        
        private let topPanel = ComponentView<Empty>()
        private let topSeparator = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        
        private let header = ComponentView<Empty>()
        
        private let balanceTitle = ComponentView<Empty>()
        private let balanceValue = ComponentView<Empty>()
        private let balanceIcon = ComponentView<Empty>()
        
        private let premiumTitle = ComponentView<Empty>()
        private let premiumDescription = ComponentView<Empty>()
        private var premiumItems: [AnyHashable: ComponentView<Empty>] = [:]
        private var inProgressPremiumGift: String?
        private let purchaseDisposable = MetaDisposable()
        
        private let starsTitle = ComponentView<Empty>()
        private let starsDescription = ComponentView<Empty>()
        private var starsItems: [AnyHashable: ComponentView<Empty>] = [:]
        private let tabSelector = ComponentView<Empty>()
        private var starsFilter: StarsFilter = .all
        
        private var _effectiveStarGifts: ([StarGift.Gift], StarsFilter)?
        private var effectiveStarGifts: [StarGift.Gift]? {
            get {
                if let (currentGifts, currentFilter) = self._effectiveStarGifts, currentFilter == self.starsFilter {
                    return currentGifts
                } else if let allGifts = self.state?.starGifts {
                    var sortedGifts = allGifts
                    if self.component?.hasBirthday == true {
                        var updatedGifts: [StarGift.Gift] = []
                        for gift in allGifts {
                            if gift.flags.contains(.isBirthdayGift) {
                                updatedGifts.append(gift)
                            }
                        }
                        for gift in allGifts {
                            if !gift.flags.contains(.isBirthdayGift) {
                                updatedGifts.append(gift)
                            }
                        }
                        sortedGifts = updatedGifts
                    }
                    let filteredGifts: [StarGift.Gift] = sortedGifts.filter {
                        switch self.starsFilter {
                        case .all:
                            return true
                        case .limited:
                            if $0.availability != nil {
                                return true
                            }
                        case let .stars(stars):
                            if $0.price == stars {
                                return true
                            }
                        }
                        return false
                    }
                    self._effectiveStarGifts = (filteredGifts, self.starsFilter)
                    return filteredGifts
                } else {
                    return nil
                }
            }
        }
        
        private var isUpdating: Bool = false
        
        private var starsStateDisposable: Disposable?
        private var starsState: StarsContext.State?
        
        private var component: GiftOptionsScreenComponent?
        private(set) weak var state: State?
        private var environment: EnvironmentType?
        
        private var starsItemsOrigin: CGFloat = 0.0
        
        private var chevronImage: (UIImage, PresentationTheme)?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
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
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.starsStateDisposable?.dispose()
            self.purchaseDisposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        private func dismissAllTooltips(controller: ViewController) {
            controller.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismissWithCommitAction()
                }
                return true
            })
            controller.window?.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismissWithCommitAction()
                }
            })
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let component = self.component else {
                return
            }
               
            let availableWidth = self.scrollView.bounds.width
            let contentOffset = self.scrollView.contentOffset.y
                        
            let topPanelAlpha = min(20.0, max(0.0, contentOffset - 95.0)) / 20.0
            if let topPanelView = self.topPanel.view, let topSeparator = self.topSeparator.view {
                transition.setAlpha(view: topPanelView, alpha: topPanelAlpha)
                transition.setAlpha(view: topSeparator, alpha: topPanelAlpha)
            }
            
            let topInset: CGFloat = 0.0
            let headerTopInset: CGFloat = environment.navigationHeight - 56.0
            
            let premiumTitleInitialPosition = (topInset + 160.0)
            let premiumTitleOffsetDelta = premiumTitleInitialPosition - (environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)
            let premiumTitleOffset = contentOffset + max(0.0, min(1.0, contentOffset / premiumTitleOffsetDelta)) * 10.0
            let premiumTitleFraction = max(0.0, min(1.0, premiumTitleOffset / premiumTitleOffsetDelta))
            let premiumTitleScale = 1.0 - premiumTitleFraction * 0.36
            var premiumTitleAdditionalOffset: CGFloat = 0.0
            
            let starsTitleOffsetDelta = (topInset + 100.0) - (environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)
            
            let starsTitleOffset: CGFloat
            let starsTitleFraction: CGFloat
            if contentOffset > 350 {
                starsTitleOffset = contentOffset + max(0.0, min(1.0, (contentOffset - 350.0) / starsTitleOffsetDelta)) * 10.0
                starsTitleFraction = max(0.0, min(1.0, (starsTitleOffset - 350.0) / starsTitleOffsetDelta))
                if contentOffset > 380.0 {
                    premiumTitleAdditionalOffset = contentOffset - 380.0
                }
            } else {
                starsTitleOffset = contentOffset
                starsTitleFraction = 0.0
            }
            let starsTitleScale = 1.0 - starsTitleFraction * 0.36
            if let starsTitleView = self.starsTitle.view {
                var starsTitlePosition: CGFloat = 455.0
                if let descriptionPosition = self.starsDescription.view?.frame.minY {
                    starsTitlePosition = descriptionPosition - 28.0
                }
                transition.setPosition(view: starsTitleView, position: CGPoint(x: availableWidth / 2.0, y: max(topInset + starsTitlePosition - starsTitleOffset, environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0)))
                transition.setScale(view: starsTitleView, scale: starsTitleScale)
            }
            
            if let premiumTitleView = self.premiumTitle.view {
                transition.setPosition(view: premiumTitleView, position: CGPoint(x: availableWidth / 2.0, y: max(premiumTitleInitialPosition - premiumTitleOffset, environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0) - premiumTitleAdditionalOffset))
                transition.setScale(view: premiumTitleView, scale: premiumTitleScale)
            }
            
            if let headerView = self.header.view {
                transition.setPosition(view: headerView, position: CGPoint(x: availableWidth / 2.0, y: headerTopInset + headerView.bounds.height / 2.0 - 30.0 - premiumTitleOffset * premiumTitleScale))
                transition.setScale(view: headerView, scale: premiumTitleScale)
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -10.0)
            if let starGifts = self.effectiveStarGifts {
                let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                
                let optionSpacing: CGFloat = 10.0
                let optionWidth = (availableWidth - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
                let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
                
                var validIds: [AnyHashable] = []
                var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: self.starsItemsOrigin), size: starsOptionSize)
                
                let controller = environment.controller
                
                for gift in starGifts {
                    var isVisible = false
                    if visibleBounds.intersects(itemFrame) {
                        isVisible = true
                    }
                    
                    if isVisible {
                        let itemId = AnyHashable(gift.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.starsItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.starsItems[itemId] = visibleItem
                        }
                        
                        var ribbon: GiftItemComponent.Ribbon?
                        if let _ = gift.soldOut {
                            ribbon = GiftItemComponent.Ribbon(
                                text: environment.strings.Gift_Options_Gift_SoldOut,
                                color: .red
                            )
                        } else if let _ = gift.availability {
                            ribbon = GiftItemComponent.Ribbon(
                                text: environment.strings.Gift_Options_Gift_Limited,
                                color: .blue
                            )
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(
                                PlainButtonComponent(
                                    content: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: environment.theme,
                                            peer: nil,
                                            subject: .starGift(gift: gift, price: "⭐️ \(gift.price)"),
                                            ribbon: ribbon,
                                            isSoldOut: gift.soldOut != nil
                                        )
                                    ),
                                    effectAlignment: .center,
                                    action: { [weak self] in
                                        if let self, let component = self.component {
                                            if let controller = controller() as? GiftOptionsScreen {
                                                let mainController: ViewController
                                                if let parentController = controller.parentController() {
                                                    mainController = parentController
                                                } else {
                                                    mainController = controller
                                                }
                                                if gift.availability?.remains == 0 {
                                                    let giftController = GiftViewScreen(
                                                        context: component.context,
                                                        subject: .soldOutGift(gift)
                                                    )
                                                    mainController.push(giftController)
                                                } else {
                                                    let giftController = GiftSetupScreen(
                                                        context: component.context,
                                                        peerId: component.peerId,
                                                        subject: .starGift(gift),
                                                        completion: component.completion
                                                    )
                                                    mainController.push(giftController)
                                                }
                                               
                                            }
                                        }
                                    },
                                    animateAlpha: false
                                )
                            ),
                            environment: {},
                            containerSize: starsOptionSize
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                self.scrollView.addSubview(itemView)
                                if !transition.animation.isImmediate {
                                    transition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                                    transition.animateScale(view: itemView, from: 0.01, to: 1.0)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                    itemFrame.origin.x += itemFrame.width + optionSpacing
                    if itemFrame.maxX > availableWidth {
                        itemFrame.origin.x = sideInset
                        itemFrame.origin.y += starsOptionSize.height + optionSpacing
                    }
                }
                
                var removeIds: [AnyHashable] = []
                for (id, item) in self.starsItems {
                    if !validIds.contains(id) {
                        removeIds.append(id)
                        if let itemView = item.view {
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                                itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                    itemView.removeFromSuperview()
                                })
                            } else {
                                itemView.removeFromSuperview()
                            }
                        }
                    }
                }
                for id in removeIds {
                    self.starsItems.removeValue(forKey: id)
                }
            }
        }
        
        func update(component: GiftOptionsScreenComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let controller = environment.controller
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            self.state = state
            
            if self.component == nil {
                self.starsStateDisposable = (component.starsContext.state
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
            self.component = component
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let theme = environment.theme
            let strings = environment.strings
            
            let textColor = theme.list.itemPrimaryTextColor
            let accentColor = theme.list.itemAccentColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            let bottomContentInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 24.0
            let headerSideInset: CGFloat = 24.0 + environment.safeInsets.left
            
            let _ = bottomContentInset
            let _ = sectionSpacing
            
            let isSelfGift = component.peerId == component.context.account.peerId
            
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight - 56.0 + 188.0
                    
            let headerSize = self.header.update(
                transition: .immediate,
                component: AnyComponent(
                    GiftAvatarComponent(
                        context: component.context,
                        theme: theme,
                        peers: state.peer.flatMap { [$0] } ?? [],
                        isVisible: true,
                        hasIdleAnimations: true,
                        color: UIColor(rgb: 0xf9b004),
                        hasLargeParticles: true
                    )
                ),
                environment: {},
                containerSize: CGSize(width: min(414.0, availableSize.width), height: 220.0)
            )
            if let headerView = self.header.view {
                if headerView.superview == nil {
                    self.addSubview(headerView)
                }
                transition.setBounds(view: headerView, bounds: CGRect(origin: .zero, size: headerSize))
            }
            
            let topPanelSize = self.topPanel.update(
                transition: transition,
                component: AnyComponent(BlurredBackgroundComponent(
                    color: theme.rootController.navigationBar.blurredBackgroundColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: environment.navigationHeight)
            )
            
            let topSeparatorSize = self.topSeparator.update(
                transition: transition,
                component: AnyComponent(Rectangle(
                    color: theme.rootController.navigationBar.separatorColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: UIScreenPixel)
            )
            let topPanelFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: topPanelSize.height))
            let topSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelSize.height), size: CGSize(width: topSeparatorSize.width, height: topSeparatorSize.height))
            if let topPanelView = self.topPanel.view, let topSeparatorView = self.topSeparator.view {
                if topPanelView.superview == nil {
                    self.addSubview(topPanelView)
                    self.addSubview(topSeparatorView)
                }
                transition.setFrame(view: topPanelView, frame: topPanelFrame)
                transition.setFrame(view: topSeparatorView, frame: topSeparatorFrame)
            }
            
            let cancelButtonSize = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(string: strings.Common_Cancel, font: Font.regular(17.0), textColor: theme.rootController.navigationBar.accentTextColor)),
                                horizontalAlignment: .center
                            )
                        ),
                        effectAlignment: .center,
                        action: {
                            controller()?.dismiss()
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let cancelButtonFrame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: environment.statusBarHeight + (environment.navigationHeight - environment.statusBarHeight) / 2.0 - cancelButtonSize.height / 2.0), size: cancelButtonSize)
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            let balanceTitleSize = self.balanceTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.Stars_Purchase_Balance,
                        font: Font.regular(14.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            let balanceValueSize = self.balanceValue.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: presentationStringsFormattedNumber(self.starsState?.balance ?? StarsAmount.zero, environment.dateTimeFormat.groupingSeparator),
                        font: Font.semibold(14.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            let balanceIconSize = self.balanceIcon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(name: "Premium/Stars/StarSmall", tintColor: nil)),
                environment: {},
                containerSize: availableSize
            )
            
            if let balanceTitleView = self.balanceTitle.view, let balanceValueView = self.balanceValue.view, let balanceIconView = self.balanceIcon.view {
                if balanceTitleView.superview == nil {
                    self.addSubview(balanceTitleView)
                    self.addSubview(balanceValueView)
                    self.addSubview(balanceIconView)
                }
                let navigationHeight = environment.navigationHeight - environment.statusBarHeight
                let topBalanceOriginY = environment.statusBarHeight + (navigationHeight - balanceTitleSize.height - balanceValueSize.height) / 2.0
                balanceTitleView.center = CGPoint(x: availableSize.width - 16.0 - environment.safeInsets.right - balanceTitleSize.width / 2.0, y: topBalanceOriginY + balanceTitleSize.height / 2.0)
                balanceTitleView.bounds = CGRect(origin: .zero, size: balanceTitleSize)
                balanceValueView.center = CGPoint(x: availableSize.width - 16.0 - environment.safeInsets.right - balanceValueSize.width / 2.0, y: topBalanceOriginY + balanceTitleSize.height + balanceValueSize.height / 2.0)
                balanceValueView.bounds = CGRect(origin: .zero, size: balanceValueSize)
                balanceIconView.center = CGPoint(x: availableSize.width - 16.0 - environment.safeInsets.right - balanceValueSize.width - balanceIconSize.width / 2.0 - 2.0, y: topBalanceOriginY + balanceTitleSize.height + balanceValueSize.height / 2.0 - UIScreenPixel)
                balanceIconView.bounds = CGRect(origin: .zero, size: balanceIconSize)
            }
            
            let premiumTitleSize = self.premiumTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: isSelfGift ? strings.Gift_Options_GiftSelf_Title : strings.Gift_Options_Premium_Title, font: Font.bold(28.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 100.0)
            )
            if let premiumTitleView = self.premiumTitle.view {
                if premiumTitleView.superview == nil {
                    self.addSubview(premiumTitleView)
                }
                transition.setBounds(view: premiumTitleView, bounds: CGRect(origin: .zero, size: premiumTitleSize))
            }
            
            if self.chevronImage == nil || self.chevronImage?.1 !== theme {
                self.chevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: accentColor)!, theme)
            }
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: accentColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let peerName = state.peer?.compactDisplayTitle ?? ""
            
            let premiumDescriptionString = parseMarkdownIntoAttributedString(isSelfGift ? strings.Gift_Options_GiftSelf_Text : strings.Gift_Options_Premium_Text(peerName).string, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
            if let range = premiumDescriptionString.string.range(of: ">"), let chevronImage = self.chevronImage?.0 {
                premiumDescriptionString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: premiumDescriptionString.string))
            }
            let premiumDescriptionSize = self.premiumDescription.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(premiumDescriptionString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: accentColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        let introController = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .settings, forceDark: false, dismissed: nil)
                        introController.navigationPresentation = .modal
                        
                        if let controller = environment.controller() as? GiftOptionsScreen {
                            let mainController: ViewController
                            if let parentController = controller.parentController() {
                                mainController = parentController
                            } else {
                                mainController = controller
                            }
                            mainController.push(introController)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 1000.0)
            )
            let premiumDescriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - premiumDescriptionSize.width) / 2.0), y: contentHeight), size: premiumDescriptionSize)
            if let premiumDescriptionView = self.premiumDescription.view {
                if premiumDescriptionView.superview == nil {
                    self.scrollView.addSubview(premiumDescriptionView)
                }
                transition.setFrame(view: premiumDescriptionView, frame: premiumDescriptionFrame)
            }
            contentHeight += premiumDescriptionSize.height
            contentHeight += 11.0
            
            let optionSpacing: CGFloat = 10.0
            let optionWidth = (availableSize.width - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
            
            if isSelfGift {
                contentHeight += 6.0
            } else {
                if let premiumProducts = state.premiumProducts {
                    let premiumOptionSize = CGSize(width: optionWidth, height: 178.0)
                    
                    var validIds: [AnyHashable] = []
                    var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: premiumOptionSize)
                    for product in premiumProducts {
                        let itemId = AnyHashable(product.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.premiumItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.premiumItems[itemId] = visibleItem
                        }
                        
                        let title: String
                        switch product.months {
                        case 6:
                            title = strings.Gift_Options_Premium_Months(6)
                        case 12:
                            title = strings.Gift_Options_Premium_Years(1)
                        default:
                            title = strings.Gift_Options_Premium_Months(3)
                        }
                        
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(
                                PlainButtonComponent(
                                    content: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: theme,
                                            peer: nil,
                                            subject: .premium(months: product.months, price: product.price),
                                            title: title,
                                            subtitle: strings.Gift_Options_Premium_Premium,
                                            ribbon: product.discount.flatMap {
                                                GiftItemComponent.Ribbon(
                                                    text:  "-\($0)%",
                                                    color: .red
                                                )
                                            },
                                            isLoading: self.inProgressPremiumGift == product.id
                                        )
                                    ),
                                    effectAlignment: .center,
                                    action: { [weak self] in
                                        if let self, let component = self.component {
                                            if let controller = controller() as? GiftOptionsScreen {
                                                let mainController: ViewController
                                                if let parentController = controller.parentController() {
                                                    mainController = parentController
                                                } else {
                                                    mainController = controller
                                                }
                                                let giftController = GiftSetupScreen(
                                                    context: component.context,
                                                    peerId: component.peerId,
                                                    subject: .premium(product),
                                                    completion: component.completion
                                                )
                                                mainController.push(giftController)
                                            }
                                        }
                                    },
                                    animateAlpha: false
                                )
                            ),
                            environment: {},
                            containerSize: premiumOptionSize
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                self.scrollView.addSubview(itemView)
                                if !transition.animation.isImmediate {
                                    transition.animateAlpha(view: itemView, from: 0.0, to: 1.0)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                        itemFrame.origin.x += itemFrame.width + optionSpacing
                        if itemFrame.maxX > availableSize.width {
                            itemFrame.origin.x = sideInset
                            itemFrame.origin.y += premiumOptionSize.height + optionSpacing
                        }
                    }
                    
                    var removeIds: [AnyHashable] = []
                    for (id, item) in self.premiumItems {
                        if !validIds.contains(id) {
                            removeIds.append(id)
                            if let itemView = item.view {
                                if !transition.animation.isImmediate {
                                    itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                        itemView.removeFromSuperview()
                                    })
                                } else {
                                    itemView.removeFromSuperview()
                                }
                            }
                        }
                    }
                    for id in removeIds {
                        self.premiumItems.removeValue(forKey: id)
                    }
                    
                    contentHeight += ceil(CGFloat(premiumProducts.count) / 3.0) * premiumOptionSize.height
                    contentHeight += 66.0
                }
                
                let starsTitleSize = self.starsTitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: strings.Gift_Options_Gift_Title, font: Font.bold(28.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                        horizontalAlignment: .center
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 100.0)
                )
                if let starsTitleView = self.starsTitle.view {
                    if starsTitleView.superview == nil {
                        self.addSubview(starsTitleView)
                    }
                    transition.setBounds(view: starsTitleView, bounds: CGRect(origin: .zero, size: starsTitleSize))
                }
                
                let starsDescriptionString = parseMarkdownIntoAttributedString(strings.Gift_Options_Gift_Text(peerName).string, attributes: markdownAttributes).mutableCopy() as! NSMutableAttributedString
                if let range = starsDescriptionString.string.range(of: ">"), let chevronImage = self.chevronImage?.0 {
                    starsDescriptionString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: starsDescriptionString.string))
                }
                let starsDescriptionSize = self.starsDescription.update(
                    transition: transition,
                    component: AnyComponent(BalancedTextComponent(
                        text: .plain(starsDescriptionString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2,
                        highlightColor: accentColor.withAlphaComponent(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] _, _ in
                            guard let self, let component = self.component, let environment = self.environment else {
                                return
                            }
                            let introController = component.context.sharedContext.makeStarsIntroScreen(context: component.context)
                            if let controller = environment.controller() as? GiftOptionsScreen {
                                let mainController: ViewController
                                if let parentController = controller.parentController() {
                                    mainController = parentController
                                } else {
                                    mainController = controller
                                }
                                mainController.push(introController)
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 1000.0)
                )
                let starsDescriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - starsDescriptionSize.width) / 2.0), y: contentHeight), size: starsDescriptionSize)
                if let starsDescriptionView = self.starsDescription.view {
                    if starsDescriptionView.superview == nil {
                        self.scrollView.addSubview(starsDescriptionView)
                    }
                    transition.setFrame(view: starsDescriptionView, frame: starsDescriptionFrame)
                }
                contentHeight += starsDescriptionSize.height
                contentHeight += 16.0
            }
            
            var tabSelectorItems: [TabSelectorComponent.Item] = []
            tabSelectorItems.append(TabSelectorComponent.Item(
                id: AnyHashable(StarsFilter.all.rawValue),
                title: strings.Gift_Options_Gift_Filter_AllGifts
            ))
            
            var hasLimited = false
            var starsAmountsSet = Set<Int64>()
            if let starGifts = self.state?.starGifts {
                for product in starGifts {
                    starsAmountsSet.insert(product.price)
                    if product.availability != nil {
                        hasLimited = true
                    }
                }
            }
            
            if hasLimited {
                tabSelectorItems.append(TabSelectorComponent.Item(
                    id: AnyHashable(StarsFilter.limited.rawValue),
                    title: strings.Gift_Options_Gift_Filter_Limited
                ))
            }

            let starsAmounts = Array(starsAmountsSet).sorted()
            for amount in starsAmounts {
                tabSelectorItems.append(TabSelectorComponent.Item(
                    id: AnyHashable(StarsFilter.stars(amount).rawValue),
                    title: "⭐️\(amount)"
                ))
            }
            
            let tabSelectorSize = self.tabSelector.update(
                transition: transition,
                component: AnyComponent(TabSelectorComponent(
                    context: component.context,
                    colors: TabSelectorComponent.Colors(
                        foreground: theme.list.itemSecondaryTextColor,
                        selection: theme.list.itemSecondaryTextColor.withMultipliedAlpha(0.15),
                        simple: true
                    ),
                    items: tabSelectorItems,
                    selectedId: AnyHashable(self.starsFilter.rawValue),
                    setSelectedId: { [weak self] id in
                        guard let self, let idValue = id.base as? Int64 else {
                            return
                        }
                        let starsFilter = StarsFilter(rawValue: idValue)
                        if self.starsFilter != starsFilter {
                            self.starsFilter = starsFilter
                            self.state?.updated(transition: .easeInOut(duration: 0.25))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 10.0 * 2.0, height: 50.0)
            )
            if let tabSelectorView = self.tabSelector.view {
                if tabSelectorView.superview == nil {
                    self.scrollView.addSubview(tabSelectorView)
                }
                transition.setFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - tabSelectorSize.width) / 2.0), y: contentHeight), size: tabSelectorSize))
            }
            contentHeight += tabSelectorSize.height
            contentHeight += 19.0
            
            if let starGifts = self.effectiveStarGifts {
                self.starsItemsOrigin = contentHeight

                let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
                let optionSpacing: CGFloat = 10.0
                contentHeight += ceil(CGFloat(starGifts.count) / 3.0) * (starsOptionSize.height + optionSpacing)
                contentHeight += -optionSpacing + 66.0
            }
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private var disposable: Disposable?
        private var updateDisposable: Disposable?
        
        fileprivate var peer: EnginePeer?
        fileprivate var premiumProducts: [PremiumGiftProduct]?
        fileprivate var starGifts: [StarGift.Gift]?
        
        init(
            context: AccountContext,
            peerId: EnginePeer.Id,
            premiumOptions: [CachedPremiumGiftOption]
        ) {
            self.context = context
            
            super.init()
            
            let availableProducts: Signal<[InAppPurchaseManager.Product], NoError>
            if let inAppPurchaseManager = context.inAppPurchaseManager {
                availableProducts = inAppPurchaseManager.availableProducts
            } else {
                availableProducts = .single([])
            }
            
            self.disposable = combineLatest(
                queue: Queue.mainQueue(),
                context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer.init(id: peerId)
                ),
                availableProducts,
                context.engine.payments.cachedStarGifts()
            ).start(next: { [weak self] peer, availableProducts, starGifts in
                guard let self, let peer else {
                    return
                }
                self.peer = peer
                
                if peerId != context.account.peerId {
                    if availableProducts.isEmpty {
                        var premiumProducts: [PremiumGiftProduct] = []
                        for option in premiumOptions {
                            premiumProducts.append(
                                PremiumGiftProduct(
                                    giftOption: CachedPremiumGiftOption(
                                        months: option.months,
                                        currency: option.currency,
                                        amount: option.amount,
                                        botUrl: "",
                                        storeProductId: option.storeProductId
                                    ),
                                    storeProduct: nil,
                                    discount: nil
                                )
                            )
                        }
                        self.premiumProducts = premiumProducts.sorted(by: { $0.months < $1.months })
                    } else {
                        let shortestOptionPrice: (Int64, NSDecimalNumber)
                        if let product = availableProducts.first(where: { $0.id.hasSuffix(".monthly") }) {
                            shortestOptionPrice = (Int64(Float(product.priceCurrencyAndAmount.amount)), product.priceValue)
                        } else {
                            shortestOptionPrice = (1, NSDecimalNumber(decimal: 1))
                        }
                        
                        var premiumProducts: [PremiumGiftProduct] = []
                        for option in premiumOptions {
                            if let product = availableProducts.first(where: { $0.id == option.storeProductId }), !product.isSubscription {
                                let fraction = Float(product.priceCurrencyAndAmount.amount) / Float(option.months) / Float(shortestOptionPrice.0)
                                let discountValue = Int(round((1.0 - fraction) * 20.0) * 5.0)
                                premiumProducts.append(PremiumGiftProduct(giftOption: option, storeProduct: product, discount: discountValue > 0 ? discountValue : nil))
                            }
                        }
                        self.premiumProducts = premiumProducts.sorted(by: { $0.months < $1.months })
                    }
                }
                    
                self.starGifts = starGifts?.compactMap { gift in
                    if case let .generic(gift) = gift {
                        return gift
                    } else {
                        return nil
                    }
                }

                self.updated()
            })
            
            self.updateDisposable = self.context.engine.payments.keepStarGiftsUpdated().start()
        }
        
        deinit {
            self.disposable?.dispose()
            self.updateDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId, premiumOptions: self.premiumOptions)
    }
    
    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

open class GiftOptionsScreen: ViewControllerComponentContainer, GiftOptionsScreenProtocol {
    private let context: AccountContext
    
    public var parentController: () -> ViewController? = {
        return nil
    }
    
    public init(
        context: AccountContext,
        starsContext: StarsContext,
        peerId: EnginePeer.Id,
        premiumOptions: [CachedPremiumGiftOption],
        hasBirthday: Bool,
        completion: (() -> Void)? = nil
    ) {
        self.context = context
        
        super.init(context: context, component: GiftOptionsScreenComponent(
            context: context,
            starsContext: starsContext,
            peerId: peerId,
            premiumOptions: premiumOptions,
            hasBirthday: hasBirthday,
            completion: completion
        ), navigationBarAppearance: .none, theme: .default, updatedPresentationData: nil)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? GiftOptionsScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
}
