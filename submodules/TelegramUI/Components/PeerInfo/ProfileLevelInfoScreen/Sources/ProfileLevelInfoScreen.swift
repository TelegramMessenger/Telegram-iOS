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
import ResizableSheetComponent
import GlassBarButtonComponent

private final class SheetContent: Component {
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
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        return true
    }
    
    private final class TransitionHint {
        let isChangingPreview: Bool
        
        init(isChangingPreview: Bool) {
            self.isChangingPreview = isChangingPreview
        }
    }
            
    final class View: UIView, UIScrollViewDelegate {
        private let peerAvatar = ComponentView<Empty>()
    
        private let title = ComponentView<Empty>()
        private let levelInfo = ComponentView<Empty>()
        private var secondaryDescriptionText: ComponentView<Empty>?
        private let descriptionText = ComponentView<Empty>()
        
        private var items: [ComponentView<Empty>] = []
                        
        private var component: SheetContent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        private var isPreviewingPendingRating: Bool = false
                
        private var cachedChevronImage: UIImage?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func update(component: SheetContent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let isChangingPreview = transition.userData(TransitionHint.self)?.isChangingPreview ?? false
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.16)
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
                        
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            self.component = component
            self.state = state
            self.environment = environment
                                    
            var contentHeight: CGFloat = 0.0
                      
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
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) * 0.5), y: floorToScreenPixels((72.0 - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            contentHeight += 72.0
                                    
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
                    self.addSubview(levelInfoView)
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
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
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
                        self.addSubview(secondaryDescriptionTextView)
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
                    self.addSubview(descriptionTextView)
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
                        self.addSubview(itemComponentView)
                    }
                    itemComponentView.frame = itemFrame
                }
                
                contentHeight += itemSize.height
            }
            
            contentHeight += 31.0
            
            contentHeight += 82.0
                        
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}




private final class ProfileLevelInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let peer: EnginePeer
    private let starRating: TelegramStarRating
    private let pendingStarRating: TelegramStarPendingRating?
    
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
    
    static func ==(lhs: ProfileLevelInfoSheetComponent, rhs: ProfileLevelInfoSheetComponent) -> Bool {
        return true
    }
        
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let playButtonAnimation = ActionSlot<Void>()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else {
                    if let controller = controller() {
                        controller.dismiss(completion: nil)
                    }
                }
            }
            
            let theme = environment.theme.withModalBlocksBackground()
            
            let actionButtonTitle: String = environment.strings.ProfileLevelInfo_CloseButton
            
            var buttonTitle: [AnyComponentWithIdentity<Empty>] = []
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
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        peer: context.component.peer,
                        starRating: context.component.starRating,
                        pendingStarRating: context.component.pendingStarRating
                    )),
                    titleItem: nil,
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
                            size: CGSize(width: 44.0, height: 44.0),
                            backgroundColor: nil,
                            isDark: theme.overallDarkAppearance,
                            state: .glass,
                            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                                BundleIconComponent(
                                    name: "Navigation/Close",
                                    tintColor: theme.chat.inputPanel.panelControlColor
                                )
                            )),
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
                    hasTopEdgeEffect: false,
                    bottomItem: AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: environment.theme.list.itemCheckColors.fillColor,
                                foreground: environment.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(HStack(buttonTitle, spacing: 2.0))
                            ),
                            action: {
                                dismiss(true)
                            }
                        )
                    ),
                    backgroundColor: .color(theme.actionSheet.opaqueItemBackgroundColor),
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class ProfileLevelInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
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
        super.init(
            context: context,
            component: ProfileLevelInfoSheetComponent(
                context: context,
                peer: peer,
                starRating: starRating,
                pendingStarRating: pendingStarRating
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: theme
        )
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
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
                    smoothCorners: false
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
