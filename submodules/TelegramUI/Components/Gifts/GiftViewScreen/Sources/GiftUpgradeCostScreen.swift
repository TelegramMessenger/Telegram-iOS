import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import ViewControllerComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BalancedTextComponent
import ButtonComponent
import PresentationDataUtils
import LottieComponent
import ProfileLevelRatingBarComponent
import TextFormat
import TelegramStringFormatting

private final class GiftUpgradeCostScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let upgradePreview: StarGiftUpgradePreview
    
    init(
        context: AccountContext,
        upgradePreview: StarGiftUpgradePreview
    ) {
        self.context = context
        self.upgradePreview = upgradePreview
    }
    
    static func ==(lhs: GiftUpgradeCostScreenComponent, rhs: GiftUpgradeCostScreenComponent) -> Bool {
        return true
    }
        
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationBarSeparator: SimpleLayer
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let closeButton = ComponentView<Empty>()
                        
        private let title = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let bar = ComponentView<Empty>()
        private let table = ComponentView<Empty>()
        private let additionalDescription = ComponentView<Empty>()
        
        private let bottomPanelContainer: UIView
        private let bottomPanelSeparator: SimpleLayer
        private let actionButton = ComponentView<Empty>()

        private var isFirstTimeApplyingModalFactor: Bool = true
        private var ignoreScrolling: Bool = false
        
        private var component: GiftUpgradeCostScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        private var itemLayout: ItemLayout?
        private var topOffsetDistance: CGFloat?
        
        private var cachedCloseImage: UIImage?
        
        private var upgradePreviewTimer: SwiftSignalKit.Timer?
        private var effectiveUpgradePrice: StarGiftUpgradePreview.Price?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationBarSeparator = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.bottomPanelContainer = UIView()
            self.bottomPanelSeparator = SimpleLayer()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.addSubview(self.navigationBarContainer)
            self.addSubview(self.bottomPanelContainer)
            
            self.navigationBarContainer.addSubview(self.navigationBackgroundView)
            self.navigationBarContainer.layer.addSublayer(self.navigationBarSeparator)
            
            self.layer.addSublayer(self.bottomPanelSeparator)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        func upgradePreviewTimerTick() {
            guard let upgradePreview = self.component?.upgradePreview else {
                return
            }
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if let currentPrice = self.effectiveUpgradePrice {
                if let price = upgradePreview.nextPrices.reversed().first(where: { currentTime >= $0.date  }) {
                    if price.stars != currentPrice.stars {
                        self.effectiveUpgradePrice = price
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate.withUserData(ProfileLevelRatingBarComponent.TransitionHint(animate: true)))
                        }
                    }
                } else {
                    self.upgradePreviewTimer?.invalidate()
                    self.upgradePreviewTimer = nil
                }
            } else if let price = upgradePreview.nextPrices.reversed().first(where: { currentTime >= $0.date}) {
                self.effectiveUpgradePrice = price
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            
            let titleTransformFraction: CGFloat = max(0.0, min(1.0, -topOffset / 20.0))
            
            let navigationAlpha: CGFloat = titleTransformFraction
            transition.setAlpha(view: self.navigationBackgroundView, alpha: navigationAlpha)
            transition.setAlpha(layer: self.navigationBarSeparator, alpha: navigationAlpha)
            
            let bottomPanelAlphaDistance: CGFloat = 20.0
            let bottomPanelDistance: CGFloat = self.scrollView.contentSize.height - self.scrollView.bounds.maxY
            let bottomPanelAlphaFraction: CGFloat = max(0.0, min(1.0, bottomPanelDistance / bottomPanelAlphaDistance))
            
            let bottomPanelAlpha: CGFloat = bottomPanelAlphaFraction
            if self.bottomPanelSeparator.opacity != Float(bottomPanelAlpha) {
                let alphaTransition = transition
                alphaTransition.setAlpha(layer: self.bottomPanelSeparator, alpha: bottomPanelAlpha)
            }
            
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = 80.0
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            var modalOverlayTransition = transition
            if self.isFirstTimeApplyingModalFactor {
                self.isFirstTimeApplyingModalFactor = false
                modalOverlayTransition = .spring(duration: 0.5)
            }
            if self.isUpdating {
                DispatchQueue.main.async { [weak controller] in
                    guard let controller else {
                        return
                    }
                    controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalOverlayTransition.containedViewLayoutTransition)
                }
            } else {
                controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: modalOverlayTransition.containedViewLayoutTransition)
            }
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomPanelContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.bottomPanelSeparator.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomPanelContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.bottomPanelSeparator.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            
            if let environment = self.environment, let controller = environment.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        }
        
        func update(component: GiftUpgradeCostScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                                    
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                       
            let isFirstTime = self.component == nil
            self.component = component
            self.state = state
            self.environment = environment
            
            if isFirstTime {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                if let _ = component.upgradePreview.nextPrices.first(where: { currentTime < $0.date }) {
                    self.upgradePreviewTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        self?.upgradePreviewTimerTick()
                    }, queue: Queue.mainQueue())
                    self.upgradePreviewTimer?.start()
                    self.upgradePreviewTimerTick()
                }
            }
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor.cgColor
                
                self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationBarSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
                self.bottomPanelSeparator.backgroundColor = environment.theme.rootController.tabBar.separatorColor.cgColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            
            let closeImage: UIImage
            if let image = self.cachedCloseImage, !themeUpdated {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.05), foregroundColor: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.4))!
                self.cachedCloseImage = closeImage
            }
            
            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Image(image: closeImage, size: closeImage.size)),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        controller.dismiss()
                    }
                ).minSize(CGSize(width: 62.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - closeButtonSize.width, y: 0.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            let clippingY: CGFloat
          
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_UpgradeCost_Title, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((56.0 - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            contentHeight += 56.0
            
            let navigationBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: 54.0))
            transition.setFrame(view: self.navigationBackgroundView, frame: navigationBackgroundFrame)
            self.navigationBackgroundView.update(size: navigationBackgroundFrame.size, cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.navigationBarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 54.0), size: CGSize(width: availableSize.width, height: UIScreenPixel)))
                        
            var value: CGFloat = 0.0
            if let startStars = component.upgradePreview.prices.first?.stars, let endStars = component.upgradePreview.prices.last?.stars {
                let effectiveValue = self.effectiveUpgradePrice?.stars ?? endStars
                value = (CGFloat(effectiveValue - endStars) / CGFloat(startStars - endStars))
            }
            value = pow(value, 0.6)
            value = min(0.96, 1.0 - value)
            
            let barSize = self.bar.update(
                transition: transition,
                component: AnyComponent(ProfileLevelRatingBarComponent(
                    theme: environment.theme,
                    value: value,
                    leftLabel: environment.strings.Gift_UpgradeCost_Stars(Int32(clamping: component.upgradePreview.prices.first?.stars ?? 0)),
                    rightLabel: environment.strings.Gift_UpgradeCost_Stars(Int32(clamping: component.upgradePreview.prices.last?.stars ?? 0)),
                    badgeValue: "\(self.effectiveUpgradePrice?.stars ?? 0)",
                    badgeTotal: "",
                    level: 0,
                    icon: .stars,
                    inversed: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 110.0)
            )
            let barFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - barSize.width) * 0.5), y: contentHeight), size: barSize)
            if let barView = self.bar.view {
                if barView.superview == nil {
                    self.scrollContentView.addSubview(barView)
                }
                transition.setFrame(view: barView, frame: barFrame)
            }
            contentHeight += barSize.height + 25.0
            
            let descriptionSize = self.descriptionText.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Gift_UpgradeCost_Description,
                        font: Font.regular(15.0),
                        textColor: environment.theme.list.itemPrimaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 50.0, height: .greatestFiniteMagnitude)
            )
            let descriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionSize.width) * 0.5), y: contentHeight), size: descriptionSize)
            if let descriptionView = self.descriptionText.view {
                if descriptionView.superview == nil {
                    self.scrollContentView.addSubview(descriptionView)
                }
                transition.setFrame(view: descriptionView, frame: descriptionFrame)
            }
            contentHeight += descriptionSize.height + 23.0
        
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            var tableItems: [TableComponent.Item] = []
            for price in component.upgradePreview.prices {
                if price.date < currentTime {
                    continue
                }
                let valueString = "⭐️\(presentationStringsFormattedNumber(abs(Int32(clamping: price.stars)), environment.dateTimeFormat.groupingSeparator))"
                let valueAttributedString = NSMutableAttributedString(string: valueString, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)
                let range = (valueAttributedString.string as NSString).range(of: "⭐️")
                if range.location != NSNotFound {
                    valueAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                    valueAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
                }
                tableItems.append(TableComponent.Item(
                    id: price.stars,
                    title: stringForGiftUpgradeTimestamp(strings: environment.strings, dateTimeFormat: environment.dateTimeFormat, timestamp: price.date),
                    titleFont: .bold,
                    component: AnyComponent(MultilineTextWithEntitiesComponent(context: component.context, animationCache: component.context.animationCache, animationRenderer: component.context.animationRenderer, placeholderColor: .white, text: .plain(valueAttributedString)))
                ))
            }
            let tableSize = self.table.update(
                transition: transition,
                component: AnyComponent(TableComponent(
                    theme: environment.theme,
                    items: tableItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
            )
            let tableFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - tableSize.width) * 0.5), y: contentHeight), size: tableSize)
            if let tableView = self.table.view {
                if tableView.superview == nil {
                    self.scrollContentView.addSubview(tableView)
                }
                transition.setFrame(view: tableView, frame: tableFrame)
            }
            contentHeight += tableSize.height + 15.0
            
            let additionalDescriptionSize = self.additionalDescription.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Gift_UpgradeCost_AdditionalDescription,
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.itemSecondaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 5,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 50.0, height: .greatestFiniteMagnitude)
            )
            let additionalDescriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - additionalDescriptionSize.width) * 0.5), y: contentHeight), size: additionalDescriptionSize)
            if let additionalDescriptionView = self.additionalDescription.view {
                if additionalDescriptionView.superview == nil {
                    self.scrollContentView.addSubview(additionalDescriptionView)
                }
                transition.setFrame(view: additionalDescriptionView, frame: additionalDescriptionFrame)
            }
            contentHeight += additionalDescriptionSize.height + 15.0
            

            let actionButtonTitle: String = environment.strings.Gift_UpgradeCost_Done
            
            var buttonTitle: [AnyComponentWithIdentity<Empty>] = []
            let playButtonAnimation = ActionSlot<Void>()
            buttonTitle.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(LottieComponent(
                content: LottieComponent.AppBundleContent(name: "anim_ok"),
                color: environment.theme.list.itemCheckColors.foregroundColor,
                startingPosition: .begin,
                size: CGSize(width: 28.0, height: 28.0),
                playOnce: playButtonAnimation
            ))))
            buttonTitle.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ButtonTextContentComponent(
                text: actionButtonTitle,
                badge: 0,
                textColor: environment.theme.list.itemCheckColors.foregroundColor,
                badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                badgeForeground: environment.theme.list.itemCheckColors.fillColor
            ))))
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(HStack(buttonTitle, spacing: 2.0))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            
            let bottomPanelHeight = 10.0 + environment.safeInsets.bottom + actionButtonSize.height
            
            let bottomPanelSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight - 8.0), size: CGSize(width: availableSize.width, height: UIScreenPixel))
            transition.setFrame(layer: self.bottomPanelSeparator, frame: bottomPanelSeparatorFrame)
            
            let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - bottomPanelHeight), size: CGSize(width: availableSize.width, height: bottomPanelHeight))
            transition.setFrame(view: self.bottomPanelContainer, frame: bottomPanelFrame)
            
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: 0.0), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.bottomPanelContainer.addSubview(actionButtonView)
                    playButtonAnimation.invoke(Void())
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            contentHeight += bottomPanelHeight
            
            clippingY = bottomPanelFrame.minY - 8.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - contentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset), size: CGSize(width: availableSize.width - sideInset * 2.0, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            let previousBounds = self.scrollView.bounds
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            } else {
                if !previousBounds.isEmpty, !transition.animation.isImmediate {
                    let bounds = self.scrollView.bounds
                    if bounds.maxY != previousBounds.maxY {
                        let offsetY = previousBounds.maxY - bounds.maxY
                        transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                    }
                }
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

public class GiftUpgradeCostScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        upgradePreview: StarGiftUpgradePreview
    ) {
        self.context = context
        
        super.init(context: context, component: GiftUpgradeCostScreenComponent(
            context: context,
            upgradePreview: upgradePreview
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? GiftUpgradeCostScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? GiftUpgradeCostScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

