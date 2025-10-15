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
import BalancedTextComponent
import ButtonComponent
import BundleIconComponent
import PresentationDataUtils
import PlainButtonComponent
import Markdown
import PremiumUI
import LottieComponent
import AnimatedTextComponent
import ProfileLevelRatingBarComponent

private final class ProfileLevelInfoScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let starRating: TelegramStarRating
    let pendingStarRating: TelegramStarPendingRating?
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        starRating: TelegramStarRating,
        pendingStarRating: TelegramStarPendingRating?
    ) {
        self.context = context
        self.peer = peer
        self.starRating = starRating
        self.pendingStarRating = pendingStarRating
    }
    
    static func ==(lhs: ProfileLevelInfoScreenComponent, rhs: ProfileLevelInfoScreenComponent) -> Bool {
        return true
    }
    
    private final class TransitionHint {
        let isChangingPreview: Bool
        
        init(isChangingPreview: Bool) {
            self.isChangingPreview = isChangingPreview
        }
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
        
        private let peerAvatar = ComponentView<Empty>()
    
        private let title = ComponentView<Empty>()
        private let levelInfo = ComponentView<Empty>()
        private var secondaryDescriptionText: ComponentView<Empty>?
        private let descriptionText = ComponentView<Empty>()
        
        private var items: [ComponentView<Empty>] = []
        
        private let bottomPanelContainer: UIView
        private let actionButton = ComponentView<Empty>()
                
        private var isFirstTimeApplyingModalFactor: Bool = true
        private var ignoreScrolling: Bool = false
        
        private var component: ProfileLevelInfoScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        private var isPreviewingPendingRating: Bool = false
        
        private var itemLayout: ItemLayout?
        private var topOffsetDistance: CGFloat?
        
        private var cachedChevronImage: UIImage?
        private var cachedCloseImage: UIImage?
        
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
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            
            let titleTransformFraction: CGFloat = max(0.0, min(1.0, -topOffset / 20.0))
            
            let navigationAlpha: CGFloat = titleTransformFraction
            transition.setAlpha(view: self.navigationBackgroundView, alpha: navigationAlpha)
            transition.setAlpha(layer: self.navigationBarSeparator, alpha: navigationAlpha)
            
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
            
            if let environment = self.environment, let controller = environment.controller() {
                controller.updateModalStyleOverlayTransitionFactor(0.0, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        }
        
        func update(component: ProfileLevelInfoScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let isChangingPreview = transition.userData(TransitionHint.self)?.isChangingPreview ?? false
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.16)
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor.cgColor
                
                self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationBarSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
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

            let titleString: String = environment.strings.ProfileLevelInfo_Title
            let descriptionTextString: String
            var secondaryDescriptionTextString: String?
            if component.peer.id == component.context.account.peerId {
                descriptionTextString = environment.strings.ProfileLevelInfo_MyText
                
                let timestamp = Int32(Date().timeIntervalSince1970)
                if let pendingStarRating = component.pendingStarRating, pendingStarRating.timestamp > timestamp {
                    if pendingStarRating.rating.stars > component.starRating.stars {
                        let pendingPoints = pendingStarRating.rating.stars - component.starRating.stars
                        
                        let dayCount = (pendingStarRating.timestamp - timestamp) / (24 * 60 * 60)
                        
                        if self.isPreviewingPendingRating {
                            if dayCount == 0 {
                                secondaryDescriptionTextString = environment.strings.ProfileLevelInfo_MyDescriptionInPreviewToday(Int32(pendingPoints))
                            } else {
                                secondaryDescriptionTextString = environment.strings.ProfileLevelInfo_MyDescriptionInPreview(environment.strings.ProfileLevelInfo_MyDescriptionInPreviewDays(Int32(dayCount)), environment.strings.ProfileLevelInfo_MyDescriptionInPreviewPoints(Int32(pendingPoints))).string
                            }
                        } else {
                            if dayCount == 0 {
                                secondaryDescriptionTextString = environment.strings.ProfileLevelInfo_MyDescriptionToday(Int32(pendingPoints))
                            } else {
                                secondaryDescriptionTextString = environment.strings.ProfileLevelInfo_MyDescriptionPreview(environment.strings.ProfileLevelInfo_MyDescriptionDays(Int32(dayCount)), environment.strings.ProfileLevelInfo_MyDescriptionPoints(Int32(pendingPoints))).string
                            }
                        }
                    }
                }
            } else {
                descriptionTextString = environment.strings.ProfileLevelInfo_OtherDescription(component.peer.compactDisplayTitle).string
            }
            
            var titleItems: [AnimatedTextComponent.Item] = []
            
            let ratingTitle = environment.strings.ProfileLevelInfo_RatingTitle
            let futureTitle = environment.strings.ProfileLevelInfo_FutureRatingTitle
            
            if self.isPreviewingPendingRating {
                if let range = futureTitle.range(of: ratingTitle) {
                    if !futureTitle[..<range.lowerBound].isEmpty {
                        titleItems.append(AnimatedTextComponent.Item(
                            id: AnyHashable(0),
                            isUnbreakable: false,
                            content: .text(String(futureTitle[..<range.lowerBound]))
                        ))
                    }
                    
                    titleItems.append(AnimatedTextComponent.Item(
                        id: AnyHashable(1),
                        isUnbreakable: true,
                        content: .text(ratingTitle)
                    ))
                    
                    if !futureTitle[range.upperBound...].isEmpty {
                        titleItems.append(AnimatedTextComponent.Item(
                            id: AnyHashable(2),
                            isUnbreakable: false,
                            content: .text(String(futureTitle[range.upperBound...]))
                        ))
                    }
                } else {
                    titleItems.append(AnimatedTextComponent.Item(
                        id: AnyHashable(0),
                        isUnbreakable: true,
                        content: .text(futureTitle)
                    ))
                }
            } else {
                titleItems.append(AnimatedTextComponent.Item(
                    id: AnyHashable(1),
                    isUnbreakable: true,
                    content: .text(ratingTitle)
                ))
            }
            
            let _ = titleString
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.semibold(17.0),
                    color: environment.theme.list.itemPrimaryTextColor,
                    items: titleItems,
                    noDelay: true,
                    animateScale: false,
                    preferredDirectionIsDown: true,
                    blur: true
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
                        
            var levelFraction: CGFloat
            
            let badgeText: String
            var badgeTextSuffix: String?
            let currentLevel: Int32
            let nextLevel: Int32?
            
            if let pendingStarRating = component.pendingStarRating, pendingStarRating.rating.stars > component.starRating.stars, self.isPreviewingPendingRating {
                badgeText = starCountString(Int64(pendingStarRating.rating.stars), decimalSeparator: ".")
                currentLevel = pendingStarRating.rating.level
                nextLevel = pendingStarRating.rating.nextLevelStars == nil ? nil : currentLevel + 1
                if let nextLevelStars = pendingStarRating.rating.nextLevelStars {
                    badgeTextSuffix = " / \(starCountString(Int64(nextLevelStars), decimalSeparator: "."))"
                }
                if let nextLevelStars = pendingStarRating.rating.nextLevelStars, nextLevelStars > pendingStarRating.rating.stars {
                    levelFraction = Double(pendingStarRating.rating.stars - pendingStarRating.rating.currentLevelStars) / Double(nextLevelStars - pendingStarRating.rating.currentLevelStars)
                } else {
                    levelFraction = 1.0
                }
            } else {
                badgeText = starCountString(Int64(component.starRating.stars), decimalSeparator: ".")
                currentLevel = component.starRating.level
                nextLevel = component.starRating.nextLevelStars == nil ? nil : currentLevel + 1
                if let nextLevelStars = component.starRating.nextLevelStars {
                    badgeTextSuffix = " / \(starCountString(Int64(nextLevelStars), decimalSeparator: "."))"
                }
                if component.starRating.stars < 0 {
                    levelFraction = 0.5
                } else if let nextLevelStars = component.starRating.nextLevelStars {
                    levelFraction = Double(component.starRating.stars - component.starRating.currentLevelStars) / Double(nextLevelStars - component.starRating.currentLevelStars)
                } else {
                    levelFraction = 1.0
                }
            }
            
            levelFraction = max(0.0, levelFraction)
            
            let levelInfoSize = self.levelInfo.update(
                transition: isChangingPreview ? ComponentTransition.immediate.withUserData(ProfileLevelRatingBarComponent.TransitionHint(animate: true)) : .immediate,
                component: AnyComponent(ProfileLevelRatingBarComponent(
                    theme: environment.theme,
                    value: levelFraction,
                    leftLabel: currentLevel < 0 ? "" : environment.strings.ProfileLevelInfo_LevelIndex(Int32(currentLevel)),
                    rightLabel: currentLevel < 0 ? environment.strings.ProfileLevelInfo_NegativeRating : nextLevel.flatMap { environment.strings.ProfileLevelInfo_LevelIndex(Int32($0)) } ?? "",
                    badgeValue: badgeText,
                    badgeTotal: badgeTextSuffix,
                    level: Int(currentLevel),
                    icon: .rating
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 110.0)
            )
            if let levelInfoView = self.levelInfo.view {
                if levelInfoView.superview == nil {
                    self.scrollContentView.addSubview(levelInfoView)
                }
                levelInfoView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - levelInfoSize.width) * 0.5), y: contentHeight - 6.0), size: levelInfoSize)
            }

            contentHeight += 129.0
            
            if let secondaryDescriptionTextString {
                let changingPreviewAnimationOffset: CGFloat = self.isPreviewingPendingRating ? -100.0 : 100.0
                let transitionBlurRadius: CGFloat = 10.0
                
                if isChangingPreview, let secondaryDescriptionTextView = self.secondaryDescriptionText?.view {
                    self.secondaryDescriptionText = nil
                    transition.setTransform(view: secondaryDescriptionTextView, transform: CATransform3DMakeTranslation(changingPreviewAnimationOffset, 0.0, 0.0))
                    alphaTransition.setAlpha(view: secondaryDescriptionTextView, alpha: 0.0, completion: { [weak secondaryDescriptionTextView] _ in
                        secondaryDescriptionTextView?.removeFromSuperview()
                    })
                    
                    if let blurFilter = CALayer.blur() {
                        blurFilter.setValue(transitionBlurRadius as NSNumber, forKey: "inputRadius")
                        secondaryDescriptionTextView.layer.filters = [blurFilter]
                        secondaryDescriptionTextView.layer.animate(from: 0.0 as NSNumber, to: transitionBlurRadius as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, removeOnCompletion: false)
                    }
                }
                
                contentHeight -= 8.0
                let secondaryDescriptionText: ComponentView<Empty>
                var secondaryDescriptionTextTransition = transition
                if let current = self.secondaryDescriptionText {
                    secondaryDescriptionText = current
                } else {
                    secondaryDescriptionTextTransition = .immediate
                    secondaryDescriptionText = ComponentView()
                    self.secondaryDescriptionText = secondaryDescriptionText
                }
                
                let secondaryTextColor: UIColor
                if currentLevel < 0 {
                    secondaryTextColor = UIColor(rgb: 0xFF3B30)
                } else {
                    secondaryTextColor = environment.theme.list.itemSecondaryTextColor
                }
                
                let secondaryDescriptionAttributedString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(secondaryDescriptionTextString, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: secondaryTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: secondaryTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                )))
                
                let chevronImage: UIImage?
                if let current = self.cachedChevronImage {
                    chevronImage = current
                } else {
                    chevronImage = generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: .white)
                    self.cachedChevronImage = chevronImage
                }
                if let range = secondaryDescriptionAttributedString.string.range(of: ">"), let chevronImage {
                    secondaryDescriptionAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: secondaryDescriptionAttributedString.string))
                }
                
                let secondaryDescriptionTextSize = secondaryDescriptionText.update(
                    transition: .immediate,
                    component: AnyComponent(BalancedTextComponent(
                        text: .plain(secondaryDescriptionAttributedString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2,
                        highlightColor: environment.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                                return NSAttributedString.Key(rawValue: "URL")
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            guard let self else {
                                return
                            }
                            self.isPreviewingPendingRating = !self.isPreviewingPendingRating
                            var transition: ComponentTransition = .spring(duration: 0.4)
                            transition = transition.withUserData(TransitionHint(isChangingPreview: true))
                            self.state?.updated(transition: transition)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let secondaryDescriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - secondaryDescriptionTextSize.width) * 0.5), y: contentHeight), size: secondaryDescriptionTextSize)
                if let secondaryDescriptionTextView = secondaryDescriptionText.view {
                    if secondaryDescriptionTextView.superview == nil {
                        self.scrollContentView.addSubview(secondaryDescriptionTextView)
                        if isChangingPreview {
                            transition.animatePosition(view: secondaryDescriptionTextView, from: CGPoint(x: -changingPreviewAnimationOffset, y: 0.0), to: CGPoint(), additive: true)
                            alphaTransition.animateAlpha(view: secondaryDescriptionTextView, from: 0.0, to: 1.0)
                            
                            if let blurFilter = CALayer.blur() {
                                blurFilter.setValue(transitionBlurRadius as NSNumber, forKey: "inputRadius")
                                secondaryDescriptionTextView.layer.filters = [blurFilter]
                                secondaryDescriptionTextView.layer.animate(from: transitionBlurRadius as NSNumber, to: 0.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, removeOnCompletion: false, completion: { [weak secondaryDescriptionTextView] _ in
                                    secondaryDescriptionTextView?.layer.filters = nil
                                })
                            }
                        }
                    }
                    secondaryDescriptionTextTransition.setPosition(view: secondaryDescriptionTextView, position: secondaryDescriptionTextFrame.center)
                    secondaryDescriptionTextView.bounds = CGRect(origin: CGPoint(), size: secondaryDescriptionTextFrame.size)
                }
                contentHeight += secondaryDescriptionTextSize.height
                contentHeight += 23.0
            } else if let secondaryDescriptionText = self.secondaryDescriptionText {
                self.secondaryDescriptionText = nil
                secondaryDescriptionText.view?.removeFromSuperview()
            }

            let descriptionTextSize = self.descriptionText.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .markdown(
                        text: descriptionTextString,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                            linkAttribute: { url in
                                return ("URL", url)
                            }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
            if let descriptionTextView = self.descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.scrollContentView.addSubview(descriptionTextView)
                }
                transition.setPosition(view: descriptionTextView, position: descriptionTextFrame.center)
                descriptionTextView.bounds = CGRect(origin: CGPoint(), size: descriptionTextFrame.size)
            }
            contentHeight += descriptionTextSize.height

            contentHeight += 24.0
            
            struct Item {
                let title: String
                let text: String
                let badgeText: String
                let isBadgeAccent: Bool
                let icon: String
            }
            let items: [Item] = [
                Item(
                    title: environment.strings.ProfileLevelInfo_Item0_Title,
                    text: environment.strings.ProfileLevelInfo_Item0_Text,
                    badgeText: environment.strings.ProfileLevelInfo_Item0_Badge,
                    isBadgeAccent: true,
                    icon: "Chat/Input/Accessory Panels/Gift"
                ),
                Item(
                    title: environment.strings.ProfileLevelInfo_Item1_Title,
                    text: environment.strings.ProfileLevelInfo_Item1_Text,
                    badgeText: environment.strings.ProfileLevelInfo_Item1_Badge,
                    isBadgeAccent: true,
                    icon: "Peer Info/ProfileLevelInfo2"
                ),
                Item(
                    title: environment.strings.ProfileLevelInfo_Item2_Title,
                    text: environment.strings.ProfileLevelInfo_Item2_Text,
                    badgeText: environment.strings.ProfileLevelInfo_Item2_Badge,
                    isBadgeAccent: false,
                    icon: "Peer Info/ProfileLevelInfo3"
                )
            ]
            
            let itemSpacing: CGFloat = 24.0
            
            for i in 0 ..< items.count {
                if i != 0 {
                    contentHeight += itemSpacing
                }
                
                let item = items[i]
                let itemView: ComponentView<Empty>
                if self.items.count > i {
                    itemView = self.items[i]
                } else {
                    itemView = ComponentView()
                    self.items.append(itemView)
                }
                
                let itemSize = itemView.update(
                    transition: .immediate,
                    component: AnyComponent(ItemComponent(
                        theme: environment.theme,
                        title: item.title,
                        text: item.text,
                        badge: item.badgeText,
                        isBadgeAccent: item.isBadgeAccent,
                        icon: item.icon
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let itemFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: itemSize)
                if let itemComponentView = itemView.view {
                    if itemComponentView.superview == nil {
                        self.scrollContentView.addSubview(itemComponentView)
                    }
                    itemComponentView.frame = itemFrame
                }
                
                contentHeight += itemSize.height
            }
            
            contentHeight += 31.0
            
            let actionButtonTitle: String = environment.strings.ProfileLevelInfo_CloseButton
            
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

public class ProfileLevelInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        peer: EnginePeer,
        starRating: TelegramStarRating,
        pendingStarRating: TelegramStarPendingRating?,
        customTheme: PresentationTheme?
    ) {
        self.context = context
        
        let theme: ViewControllerComponentContainer.Theme
        if let customTheme {
            theme = .custom(customTheme)
        } else {
            theme = .default
        }
        super.init(context: context, component: ProfileLevelInfoScreenComponent(
            context: context,
            peer: peer,
            starRating: starRating,
            pendingStarRating: pendingStarRating
        ), navigationBarAppearance: .none, theme: theme)
        
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
        
        if let componentView = self.node.hostView.componentView as? ProfileLevelInfoScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? ProfileLevelInfoScreenComponent.View {
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

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.beginPath()
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

private final class ItemComponent: Component {
    let theme: PresentationTheme
    let title: String
    let text: String
    let badge: String
    let isBadgeAccent: Bool
    let icon: String
    
    init(
        theme: PresentationTheme,
        title: String,
        text: String,
        badge: String,
        isBadgeAccent: Bool,
        icon: String
    ) {
        self.theme = theme
        self.title = title
        self.text = text
        self.badge = badge
        self.isBadgeAccent = isBadgeAccent
        self.icon = icon
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        if lhs.isBadgeAccent != rhs.isBadgeAccent {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let title = ComponentView<Empty>()
        let text = ComponentView<Empty>()
        let badgeBackground = ComponentView<Empty>()
        let badgeText = ComponentView<Empty>()
        let icon = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let leftInset: CGFloat = 44.0
            let titleSpacing: CGFloat = 5.0
            let badgeInsets = UIEdgeInsets(top: 2.0, left: 4.0, bottom: 2.0, right: 4.0)
            let badgeSpacing: CGFloat = 4.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(15.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset, height: 10000.0)
            )
            
            let badgeTextSize = self.badgeText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.badge, font: Font.semibold(11.0), textColor: component.isBadgeAccent ? component.theme.chatList.unreadBadgeActiveTextColor : component.theme.chatList.unreadBadgeInactiveTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: 1000.0, height: 10000.0)
            )
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.text, font: Font.regular(15.0), textColor: component.theme.list.itemSecondaryTextColor)),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    cutout: TextNodeCutout(topLeft: CGSize(width: badgeInsets.left + badgeTextSize.width + badgeInsets.right + badgeSpacing, height: 6.0))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset, height: 10000.0)
            )
            
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: titleSize)
            let textFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: textSize)
            
            let badgeSize = CGSize(width: badgeInsets.left + badgeTextSize.width + badgeInsets.right, height: badgeInsets.top + badgeTextSize.height + badgeInsets.bottom)
            let badgeFrame = CGRect(origin: CGPoint(x: leftInset, y: textFrame.minY), size: badgeSize)
            let badgeTextFrame = CGRect(origin: CGPoint(x: badgeFrame.minX + badgeInsets.left, y: badgeFrame.minY + badgeInsets.top), size: badgeTextSize)
            
            let _ = self.badgeBackground.update(
                transition: .immediate,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.isBadgeAccent ? component.theme.chatList.unreadBadgeActiveBackgroundColor : component.theme.chatList.unreadBadgeInactiveBackgroundColor,
                    cornerRadius: .value(6.0),
                    smoothCorners: true
                )),
                environment: {},
                containerSize: badgeSize
            )
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                }
                textView.frame = textFrame
            }
            if let badgeBackgroundView = self.badgeBackground.view {
                if badgeBackgroundView.superview == nil {
                    self.addSubview(badgeBackgroundView)
                }
                badgeBackgroundView.frame = badgeFrame
            }
            if let badgeTextView = self.badgeText.view {
                if badgeTextView.superview == nil {
                    self.addSubview(badgeTextView)
                }
                badgeTextView.frame = badgeTextFrame
            }
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: component.icon,
                    tintColor: component.theme.list.itemAccentColor
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 200.0)
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.frame = CGRect(origin: CGPoint(x: floor((leftInset - iconSize.width) * 0.5) - 2.0, y: 4.0), size: iconSize)
            }
            
            return CGSize(width: availableSize.width, height: textFrame.maxY)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func starCountString(_ size: Int64, forceDecimal: Bool = false, decimalSeparator: String) -> String {
    if size >= 1000 * 1000 {
        let remainder = Int64((Double(size % (1000 * 1000)) / (1000.0 * 100.0)).rounded(.down))
        if remainder != 0 || forceDecimal {
            return "\(size / (1000 * 1000))\(decimalSeparator)\(remainder)M"
        } else {
            return "\(size / (1000 * 1000))M"
        }
    } else if size >= 100000 {
        let remainder = (size % (1000)) / (100)
        if remainder != 0 || forceDecimal {
            return "\(size / 1000)\(decimalSeparator)\(remainder)K"
        } else {
            return "\(size / 1000)K"
        }
    } else {
        return "\(size)"
    }
}
