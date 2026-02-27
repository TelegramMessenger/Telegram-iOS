import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ComponentFlow
import AccountContext
import ViewControllerComponent
import TelegramCore
import SwiftSignalKit
import Display
import MultilineTextComponent
import ButtonComponent
import PlainButtonComponent
import Markdown
import SliderComponent
import RoundedRectWithTailPath
import AvatarNode
import BundleIconComponent
import TextFormat
import ContextUI
import StarsBalanceOverlayComponent
import StoryLiveChatMessageComponent
import TelegramStringFormatting
import GlassBarButtonComponent
import AnimatedTextComponent
import BotPaymentsUI
import UndoUI
import GiftItemComponent
import LottieComponent
import EdgeEffect
import ConfettiEffect

private final class BadgeComponent: Component {
    let theme: PresentationTheme
    let prefix: String?
    let title: String
    let subtitle: String?
    let subtitleOnTop: Bool
    let color: UIColor
    
    init(
        theme: PresentationTheme,
        prefix: String?,
        title: String,
        subtitle: String?,
        subtitleOnTop: Bool,
        color: UIColor
    ) {
        self.theme = theme
        self.prefix = prefix
        self.title = title
        self.subtitle = subtitle
        self.subtitleOnTop = subtitleOnTop
        self.color = color
    }
    
    static func ==(lhs: BadgeComponent, rhs: BadgeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.prefix != rhs.prefix {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.subtitleOnTop != rhs.subtitleOnTop {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let badgeView: UIView
        private let badgeMaskView: UIView
        private let badgeShapeView: UIImageView
        private let badgeShapeAnimation = ComponentView<Empty>()
        
        private let badgeForeground: SimpleLayer
        let badgeIcon: UIImageView
        private let badgeLabel: BadgeLabelView
        private let badgeLabelMaskView = UIImageView()
        
        private let prefix = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private var badgeTailPosition: CGFloat = 0.0
        private var badgeShapeArguments: (Double, Double, CGSize, CGFloat, CGFloat)?
        
        private var component: BadgeComponent?
        private var isUpdating: Bool = false
        
        private var previousAvailableSize: CGSize?
        
        override init(frame: CGRect) {
            self.badgeView = UIView()
            self.badgeView.alpha = 0.0
            self.badgeView.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            
            self.badgeShapeView = UIImageView()
            
            self.badgeMaskView = UIView()
            self.badgeMaskView.addSubview(self.badgeShapeView)
            self.badgeView.mask = self.badgeMaskView
            
            self.badgeForeground = SimpleLayer()
            self.badgeForeground.anchorPoint = CGPoint()
            
            self.badgeIcon = UIImageView()
            self.badgeIcon.contentMode = .center
                        
            self.badgeLabel = BadgeLabelView()
            let _ = self.badgeLabel.update(value: "0", transition: .immediate)
            self.badgeLabel.mask = self.badgeLabelMaskView
            
            super.init(frame: frame)
            
            self.addSubview(self.badgeView)
            self.badgeView.layer.addSublayer(self.badgeForeground)
            self.badgeView.addSubview(self.badgeIcon)
            self.badgeView.addSubview(self.badgeLabel)
            
            self.badgeLabelMaskView.contentMode = .scaleToFill
            self.badgeLabelMaskView.image = generateImage(CGSize(width: 2.0, height: 36.0), rotatedContext: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                
                let colorsArray: [CGColor] = [
                    UIColor(rgb: 0xffffff, alpha: 0.0).cgColor,
                    UIColor(rgb: 0xffffff).cgColor,
                    UIColor(rgb: 0xffffff).cgColor,
                    UIColor(rgb: 0xffffff, alpha: 0.0).cgColor,
                ]
                var locations: [CGFloat] = [0.0, 0.24, 0.76, 1.0]
                let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
            
            self.isUserInteractionEnabled = false
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.badgeView.frame.contains(point) {
                return self
            } else {
                return nil
            }
        }
                
        func update(component: BadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.badgeIcon.image = UIImage(bundleImageName: "Premium/SendStarsStarSliderIcon")?.withRenderingMode(.alwaysTemplate)
            }
             
            let previousComponent = self.component
            self.component = component
            self.badgeIcon.tintColor = .white
            
            self.badgeLabel.color = .white
                
            let badgeLabelSize = self.badgeLabel.update(value: component.title, transition: .easeInOut(duration: 0.12))
            let countWidth: CGFloat = badgeLabelSize.width + 3.0
            var badgeWidth: CGFloat = countWidth + 54.0
            
            var badgeOffset: CGPoint = .zero
            if let prefix = component.prefix {
                let prefixSize = self.prefix.update(
                    transition: .immediate,
                    component: AnyComponent(Text(text: prefix, font: Font.with(size: 24.0, design: .round, weight: .semibold, traits: []), color: .white)),
                    environment: {},
                    containerSize: availableSize
                )
                if let prefixView = self.prefix.view {
                    if prefixView.superview == nil {
                        self.badgeView.addSubview(prefixView)
                    }
                    prefixView.frame = CGRect(origin: CGPoint(x: 44.0, y: 9.0 - UIScreenPixel), size: prefixSize)
                    prefixView.alpha = 1.0
                }
                badgeWidth += prefixSize.width
                badgeOffset.x += prefixSize.width - 6.0
            } else if let prefixView = self.prefix.view {
                prefixView.alpha = 0.0
            }
            
            if let subtitle = component.subtitle {
                let subtitleSize = self.subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(Text(text: subtitle, font: Font.regular(11.0), color: UIColor.white)),
                    environment: {},
                    containerSize: availableSize
                )
                if let subtitleView = self.subtitle.view {
                    if subtitleView.superview == nil {
                        self.badgeView.addSubview(subtitleView)
                    }
                    subtitleView.frame = CGRect(origin: CGPoint(x: 44.0, y: 28.0), size: subtitleSize)
                    subtitleView.alpha = 1.0
                }
                badgeOffset.y -= 6.0 + UIScreenPixel
                
                let subtitleBadgeWidth = subtitleSize.width + 60.0
                if subtitleBadgeWidth > badgeWidth {
                    badgeOffset.x -= (subtitleBadgeWidth - badgeWidth) * 0.5
                    badgeWidth = subtitleBadgeWidth
                }
            } else if let subtitleView = self.subtitle.view {
                subtitleView.alpha = 0.0
            }
            
            let badgeSize = CGSize(width: badgeWidth, height: 48.0)
            let badgeFullSize = CGSize(width: badgeWidth, height: 48.0 + 12.0)
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeFullSize)
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeFullSize)
            self.badgeView.center = CGPoint(x: badgeSize.width / 2.0, y: badgeSize.height)
            
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 600.0, height: badgeFullSize.height + 10.0))
    
            self.badgeIcon.frame = CGRect(x: 10.0, y: 9.0, width: 30.0, height: 30.0)
            self.badgeLabelMaskView.frame = CGRect(x: 0.0, y: 0.0, width: 140.0, height: 36.0)
            
            self.badgeView.alpha = 1.0
            
            let size = badgeSize
            transition.setFrame(view: self.badgeLabel, frame: CGRect(origin: CGPoint(x: badgeOffset.x + 14.0 + floorToScreenPixels((badgeFullSize.width - badgeLabelSize.width) / 2.0), y: 5.0 + badgeOffset.y), size: badgeLabelSize))
            
            if self.previousAvailableSize != availableSize || previousComponent?.color != component.color {
                self.previousAvailableSize = availableSize
                
                let activeColors: [UIColor] = [
                    component.color,
                    component.color
                ]
                
                var locations: [CGFloat] = []
                let delta = 1.0 / CGFloat(activeColors.count - 1)
                for i in 0 ..< activeColors.count {
                    locations.append(delta * CGFloat(i))
                }
                
                let gradient = generateGradientImage(size: CGSize(width: 200.0, height: 60.0), colors: activeColors, locations: locations, direction: .horizontal)
                self.badgeForeground.contentsGravity = .resizeAspectFill
                self.badgeForeground.contents = gradient?.cgImage
                
                self.setupGradientAnimations()
            }
            
            return size
        }
        
        func adjustTail(size: CGSize, tailOffset: CGFloat, transition: ComponentTransition) {
            if self.badgeShapeView.image == nil {
                self.badgeShapeView.image = generateStretchableFilledCircleImage(diameter: 48.0, color: UIColor.white)
            }
            self.badgeShapeView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: 48.0))
            
            let badgeShapeSize = CGSize(width: 78, height: 60)
            let _ = self.badgeShapeAnimation.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "badge_with_tail"),
                    color: .white,
                    placeholderColor: nil,
                    startingPosition: .begin,
                    size: badgeShapeSize,
                    renderingScale: UIScreenScale,
                    loop: false,
                    playOnce: nil
                )),
                environment: {},
                containerSize: badgeShapeSize
            )
            if let badgeShapeAnimationView = self.badgeShapeAnimation.view as? LottieComponent.View {
                if badgeShapeAnimationView.superview == nil {
                    badgeShapeAnimationView.layer.anchorPoint = CGPoint()
                    self.badgeMaskView.addSubview(badgeShapeAnimationView)
                }
                
                var shapeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: badgeShapeSize)
                
                let badgeShapeWidth = badgeShapeSize.width
                
                let midFrame = 359 / 2
                if tailOffset < badgeShapeWidth * 0.5 {
                    let frameIndex = Int(floor(CGFloat(midFrame) * tailOffset / (badgeShapeWidth * 0.5)))
                    badgeShapeAnimationView.setFrameIndex(index: frameIndex)
                } else if tailOffset >= size.width - badgeShapeWidth * 0.5 {
                    let endOffset = tailOffset - (size.width - badgeShapeWidth * 0.5)
                    let frameIndex = midFrame + Int(floor(CGFloat(359 - midFrame) * endOffset / (badgeShapeWidth * 0.5)))
                    badgeShapeAnimationView.setFrameIndex(index: frameIndex)
                    shapeFrame.origin.x = size.width - badgeShapeWidth
                } else {
                    badgeShapeAnimationView.setFrameIndex(index: midFrame)
                    shapeFrame.origin.x = tailOffset - badgeShapeWidth * 0.5
                }
                
                badgeShapeAnimationView.center = shapeFrame.origin
                badgeShapeAnimationView.bounds = CGRect(origin: CGPoint(), size: shapeFrame.size)
            }
        }
        
        func updateBadgeAngle(angle: CGFloat) {
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateTransformRotation(view: self.badgeView, angle: angle)
        }
        
        private func setupGradientAnimations() {
            guard let _ = self.component else {
                return
            }
            if let _ = self.badgeForeground.animation(forKey: "movement") {
            } else {
                CATransaction.begin()
                
                let badgePreviousValue = self.badgeForeground.position.x
                let badgeNewValue: CGFloat
                if self.badgeForeground.position.x == -300.0 {
                    badgeNewValue = 0.0
                } else {
                    badgeNewValue = -300.0
                }
                self.badgeForeground.position = CGPoint(x: badgeNewValue, y: 0.0)
                
                let badgeAnimation = CABasicAnimation(keyPath: "position.x")
                badgeAnimation.duration = 4.5
                badgeAnimation.fromValue = badgePreviousValue
                badgeAnimation.toValue = badgeNewValue
                badgeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                CATransaction.setCompletionBlock { [weak self] in
                    self?.setupGradientAnimations()
                }
                self.badgeForeground.add(badgeAnimation, forKey: "movement")
                
                CATransaction.commit()
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class PeerPlaceComponent: Component {
    let theme: PresentationTheme
    let color: UIColor
    let place: Int32?
    let placeIsApproximate: Bool
    let groupingSeparator: String
    
    init(
        theme: PresentationTheme,
        color: UIColor,
        place: Int32?,
        placeIsApproximate: Bool,
        groupingSeparator: String
    ) {
        self.theme = theme
        self.color = color
        self.place = place
        self.placeIsApproximate = placeIsApproximate
        self.groupingSeparator = groupingSeparator
    }
    
    static func ==(lhs: PeerPlaceComponent, rhs: PeerPlaceComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.place != rhs.place {
            return false
        }
        if lhs.placeIsApproximate != rhs.placeIsApproximate {
            return false
        }
        if lhs.groupingSeparator != rhs.groupingSeparator {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var background = UIImageView()
        private let label = ComponentView<Empty>()

        private var component: PeerPlaceComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.background)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: PeerPlaceComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let textColor: UIColor
            let backgroundColors: [UIColor]?
            if let place = component.place, place < 4 {
                textColor = .white
                switch place {
                case 1:
                    backgroundColors = [UIColor(rgb: 0xffa901), UIColor(rgb: 0xffcd3b)]
                case 2:
                    backgroundColors = [UIColor(rgb: 0x999999), UIColor(rgb: 0xbbbbbb)]
                case 3:
                    backgroundColors = [UIColor(rgb: 0xcb692e), UIColor(rgb: 0xdc9a59)]
                default:
                    backgroundColors = nil
                }
            } else {
                textColor = component.color
                backgroundColors = nil
            }
            
            let backgroundSize = CGSize(width: 24.0, height: 24.0)
            if let backgroundColors {
                let colors: NSArray = Array(backgroundColors.map { $0.cgColor }) as NSArray
                self.background.image = generateGradientFilledCircleImage(
                    diameter: backgroundSize.width,
                    colors: colors,
                    direction: .vertical
                )
                self.background.isHidden = false
            } else {
                self.background.isHidden = true
            }
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - backgroundSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - backgroundSize.height) * 0.5)), size: backgroundSize)
            self.background.frame = backgroundFrame
            
            var placeString: String
            if let place = component.place {
                placeString = presentationStringsFormattedNumber(place, component.groupingSeparator)
                if component.placeIsApproximate {
                    placeString = "\(compactNumericCountString(Int(place), decimalSeparator: ".", showDecimalPart: false))+"
                }
            } else {
                placeString = "–"
            }
            
            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: placeString, font: Font.with(size: 17.0, traits: .monospacedNumbers), textColor: textColor)))),
                environment: {},
                containerSize: CGSize(width: 60.0, height: 40.0)
            )
            let labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - labelSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - labelSize.height) * 0.5)), size: labelSize)
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    self.addSubview(labelView)
                }
                labelView.frame = labelFrame
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class PeerComponent: Component {
    enum Status {
        case winning
        case outbid
        case returned
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let groupingSeparator: String
    let peer: EnginePeer
    let place: Int32
    let placeIsApproximate: Bool
    let amount: Int64
    let status: Status?
    let isLast: Bool
    let action: (() -> Void)?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        groupingSeparator: String,
        peer: EnginePeer,
        place: Int32,
        placeIsApproximate: Bool,
        amount: Int64,
        status: Status? = nil,
        isLast: Bool,
        action: (() -> Void)?
    ) {
        self.context = context
        self.theme = theme
        self.groupingSeparator = groupingSeparator
        self.peer = peer
        self.place = place
        self.placeIsApproximate = placeIsApproximate
        self.amount = amount
        self.status = status
        self.isLast = isLast
        self.action = action
    }
    
    static func ==(lhs: PeerComponent, rhs: PeerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.place != rhs.place {
            return false
        }
        if lhs.placeIsApproximate != rhs.placeIsApproximate {
            return false
        }
        if lhs.amount != rhs.amount {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        if lhs.isLast != rhs.isLast {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let selectionLayer = SimpleLayer()
        private var avatarNode: AvatarNode?
        private let place = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let amount = ComponentView<Empty>()
        private let amountStar = UIImageView()
        private let separator = SimpleLayer()
        private let button = HighlightTrackingButton()

        private var component: PeerComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.selectionLayer.opacity = 0.0
            
            self.layer.addSublayer(self.separator)
            self.layer.addSublayer(self.selectionLayer)
            
            self.amountStar.image = UIImage(bundleImageName: "Premium/Stars/StarSmall")
            self.addSubview(self.amountStar)
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
            self.addSubview(self.button)
            
            self.button.highligthedChanged = { [weak self] highlighted in
                if let self {
                    if highlighted {
                        self.selectionLayer.removeAnimation(forKey: "opacity")
                        self.selectionLayer.opacity = 1.0
                    } else {
                        self.selectionLayer.opacity = 0.0
                        self.selectionLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
            }
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func buttonPressed() {
            if let component = self.component {
                component.action?()
            }
        }
        
        func update(component: PeerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.button.isUserInteractionEnabled = component.action != nil
            
            let size = CGSize(width: availableSize.width, height: 52.0)
            
            var color = component.theme.list.itemSecondaryTextColor
            switch component.status {
            case .winning:
                color = UIColor(rgb: 0x53a939)
            case .outbid, .returned:
                color = component.theme.list.itemDestructiveColor
            default:
                break
            }
            self.selectionLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let placeSize = self.place.update(
                transition: .immediate,
                component: AnyComponent(
                    PeerPlaceComponent(
                        theme: component.theme,
                        color: color,
                        place: component.status == .returned ? nil : component.place,
                        placeIsApproximate: component.placeIsApproximate,
                        groupingSeparator: presentationData.dateTimeFormat.groupingSeparator
                    )
                ),
                environment: {
                },
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let placeFrame = CGRect(origin: CGPoint(x: 0.0, y:  floorToScreenPixels((size.height - placeSize.height) / 2.0)), size: placeSize)
            if let placeView = self.place.view {
                if placeView.superview == nil {
                    placeView.isUserInteractionEnabled = false
                    self.addSubview(placeView)
                }
                placeView.frame = placeFrame
            }
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
                avatarNode.isUserInteractionEnabled = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarSize = CGSize(width: 40.0, height: 40.0)
            let avatarFrame = CGRect(origin: CGPoint(x: 51.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0)), size: avatarSize)
            avatarNode.frame = avatarFrame
            avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, synchronousLoad: true)
            avatarNode.updateSize(size: avatarFrame.size)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.peer.compactDisplayTitle, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 120.0 - 110.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 110.0, y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let amountSize = self.amount.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(Int32(clamping: component.amount), component.groupingSeparator), font: Font.with(size: 15.0, traits: .monospacedNumbers), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let amountFrame = CGRect(origin: CGPoint(x: availableSize.width - amountSize.width, y: floorToScreenPixels((size.height - amountSize.height) / 2.0)), size: amountSize)
            if let amountView = self.amount.view {
                if amountView.superview == nil {
                    amountView.isUserInteractionEnabled = false
                    self.addSubview(amountView)
                }
                amountView.frame = amountFrame
            }
            
            if let icon = self.amountStar.image {
                self.amountStar.frame = CGRect(origin: CGPoint(x: amountFrame.minX - icon.size.width - 2.0, y: floorToScreenPixels((size.height - icon.size.height) / 2.0) - UIScreenPixel), size: icon.size)
            }
            
            self.separator.backgroundColor = component.theme.list.itemPlainSeparatorColor.cgColor
            self.separator.frame = CGRect(origin: CGPoint(x: 110.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width - 110.0, height: UIScreenPixel))
            transition.setAlpha(layer: self.separator, alpha: component.isLast ? 0.0 : 1.0)
            
            self.button.frame = CGRect(origin: .zero, size: size)
            self.selectionLayer.frame = CGRect(origin: .zero, size: size).insetBy(dx: -24.0, dy: -UIScreenPixel)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SliderBackgroundComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let value: CGFloat
    let topCutoff: CGFloat?
    let giftsPerRound: Int32
    let color: UIColor
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        value: CGFloat,
        topCutoff: CGFloat?,
        giftsPerRound: Int32,
        color: UIColor
    ) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.topCutoff = topCutoff
        self.giftsPerRound = giftsPerRound
        self.color = color
    }
    
    static func ==(lhs: SliderBackgroundComponent, rhs: SliderBackgroundComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.topCutoff != rhs.topCutoff {
            return false
        }
        if lhs.giftsPerRound != rhs.giftsPerRound {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }
    
    private enum TopTextOverflowState {
        case left
        case center
        case right
        
        func animates(from: TopTextOverflowState) -> Bool {
            switch self {
            case .left:
                return false
            case .center:
                switch from {
                case .left:
                    return false
                case .center:
                    return false
                case .right:
                    return true
                }
            case .right:
                switch from {
                case .left:
                    return false
                case .center:
                    return true
                case .right:
                    return false
                }
            }
        }
    }
    
    final class View: UIView {
        private let sliderBackground = UIView()
        private let sliderForeground = UIView()
        private let sliderStars = SliderStarsView()
        
        private let topForegroundLine = SimpleLayer()
        private let topBackgroundLine = SimpleLayer()
        private let topForegroundText = ComponentView<Empty>()
        private let topBackgroundText = ComponentView<Empty>()
        
        private var topTextOverflowState: TopTextOverflowState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.sliderBackground.clipsToBounds = true
            
            self.sliderForeground.clipsToBounds = true
            self.sliderForeground.addSubview(self.sliderStars)
            
            self.addSubview(self.sliderBackground)
            self.addSubview(self.sliderForeground)
            
            self.sliderBackground.layer.addSublayer(self.topBackgroundLine)
            self.sliderForeground.layer.addSublayer(self.topForegroundLine)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SliderBackgroundComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.sliderBackground.backgroundColor = component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(component.theme.overallDarkAppearance ? 0.2 : 0.07)
            self.sliderForeground.backgroundColor = component.color
            self.topForegroundLine.backgroundColor = component.theme.list.plainBackgroundColor.cgColor
            self.topBackgroundLine.backgroundColor = component.theme.list.plainBackgroundColor.cgColor
            
            transition.setFrame(view: self.sliderBackground, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let sliderMinWidth = availableSize.height
            let sliderAreaWidth: CGFloat = availableSize.width - sliderMinWidth
            let sliderForegroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: sliderMinWidth + floorToScreenPixels(sliderAreaWidth * component.value), height: availableSize.height))
            transition.setFrame(view: self.sliderForeground, frame: sliderForegroundFrame)
            
            self.sliderBackground.layer.cornerRadius = availableSize.height * 0.5
            self.sliderForeground.layer.cornerRadius = availableSize.height * 0.5
            
            self.sliderStars.frame = CGRect(origin: .zero, size: availableSize)
            self.sliderStars.update(size: availableSize, value: component.value)
            
            self.sliderForeground.isHidden = sliderForegroundFrame.width <= sliderMinWidth
            
            let topCutoff = component.topCutoff ?? 0.0
            
            let topX = floorToScreenPixels(sliderAreaWidth * topCutoff)
            let topLineAvoidDistance = 6.0
            let knobWidth: CGFloat = 30.0
            let topLineClosestEdge = min(abs(sliderForegroundFrame.maxX - topX), abs(sliderForegroundFrame.maxX - knobWidth - topX))
            var topLineOverlayFactor = topLineClosestEdge / topLineAvoidDistance
            topLineOverlayFactor = max(0.0, min(1.0, topLineOverlayFactor))
            if sliderForegroundFrame.maxX - knobWidth <= topX && sliderForegroundFrame.maxX >= topX {
                topLineOverlayFactor = 0.0
            }
            
            let topLineHeight: CGFloat = availableSize.height
            let topLineAlpha: CGFloat = topLineOverlayFactor * topLineOverlayFactor
            
            let topLineFrameTransition = transition
            let topLineAlphaTransition = transition
            /*if transition.userData(GiftAuctionBidScreenComponent.IsAdjustingAmountHint.self) != nil {
                topLineFrameTransition = .easeInOut(duration: 0.12)
                topLineAlphaTransition = .easeInOut(duration: 0.12)
            }*/
            
            let topLineFrame = CGRect(origin: CGPoint(x: topX, y: (availableSize.height - topLineHeight) * 0.5), size: CGSize(width: 1.0, height: topLineHeight))
            
            topLineFrameTransition.setFrame(layer: self.topForegroundLine, frame: topLineFrame)
            topLineAlphaTransition.setAlpha(layer: self.topForegroundLine, alpha: topLineAlpha)
            topLineFrameTransition.setFrame(layer: self.topBackgroundLine, frame: topLineFrame)
            topLineAlphaTransition.setAlpha(layer: self.topBackgroundLine, alpha: topLineAlpha)
            
            let topTextSize = self.topForegroundText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.Gift_AuctionBid_Top("\(component.giftsPerRound)").string, font: Font.semibold(15.0), textColor: UIColor(white: 1.0, alpha: 0.4)))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let _ = self.topBackgroundText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.Gift_AuctionBid_Top("\(component.giftsPerRound)").string, font: Font.semibold(15.0), textColor: component.theme.overallDarkAppearance ? UIColor(white: 1.0, alpha: 0.22) : UIColor(white: 0.0, alpha: 0.2)))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            
            var topTextFrame = CGRect(origin: CGPoint(x: topLineFrame.maxX + 6.0, y: floor((availableSize.height - topTextSize.height) * 0.5)), size: topTextSize)
            
            let topTextFrameTransition = transition
            
            let topTextLeftInset: CGFloat = 4.0
            var topTextOverflowWidth: CGFloat = 0.0
            let topTextOverflowState: TopTextOverflowState
            if sliderForegroundFrame.maxX < topTextFrame.minX - topTextLeftInset {
                topTextOverflowState = .left
            } else if sliderForegroundFrame.maxX >= topTextFrame.minX - topTextLeftInset && sliderForegroundFrame.maxX - knobWidth < topTextFrame.maxX + topTextLeftInset {
                topTextOverflowWidth = sliderForegroundFrame.maxX - (topTextFrame.minX - topTextLeftInset)
                topTextOverflowState = .center
            } else {
                topTextOverflowState = .right
            }
            
            topTextFrame.origin.x += topTextOverflowWidth
            
            if let topForegroundTextView = self.topForegroundText.view, let topBackgroundTextView = self.topBackgroundText.view {
                if topForegroundTextView.superview == nil {
                    topBackgroundTextView.layer.anchorPoint = CGPoint()
                    self.sliderBackground.addSubview(topBackgroundTextView)
                    
                    topForegroundTextView.layer.anchorPoint = CGPoint()
                    self.sliderForeground.addSubview(topForegroundTextView)
                }
                
                var animateTopTextAdditionalX: CGFloat = 0.0
                if transition.userData(GiftAuctionBidScreenComponent.IsAdjustingAmountHint.self) != nil {
                    if let previousState = self.topTextOverflowState, previousState != topTextOverflowState, topTextOverflowState.animates(from: previousState) {
                        animateTopTextAdditionalX = topForegroundTextView.center.x - topTextFrame.origin.x
                    }
                }
                
                topTextFrameTransition.setPosition(view: topForegroundTextView, position: topTextFrame.origin)
                topTextFrameTransition.setPosition(view: topBackgroundTextView, position: topTextFrame.origin)
                
                topForegroundTextView.bounds = CGRect(origin: CGPoint(), size: topTextFrame.size)
                topBackgroundTextView.bounds = CGRect(origin: CGPoint(), size: topTextFrame.size)
                
                if animateTopTextAdditionalX != 0.0 {
                    topForegroundTextView.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: animateTopTextAdditionalX, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.3, damping: 100.0, additive: true)
                    topBackgroundTextView.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: animateTopTextAdditionalX, y: 0.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.3, damping: 100.0, additive: true)
                }
                
                topForegroundTextView.isHidden = component.topCutoff == nil || topTextFrame.maxX > availableSize.width - 28.0
                topBackgroundTextView.isHidden = topForegroundTextView.isHidden
                self.topBackgroundLine.isHidden = topX < 10.0
                self.topForegroundLine.isHidden = self.topBackgroundLine.isHidden
            }
            self.topTextOverflowState = topTextOverflowState
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class GiftAuctionBidScreenComponent: Component {
    final class IsAdjustingAmountHint {
    }
    
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let toPeerId: EnginePeer.Id
    let text: String?
    let entities: [MessageTextEntity]?
    let hideName: Bool
    let gift: StarGift
    let auctionContext: GiftAuctionContext
    let acquiredGifts: Signal<[GiftAuctionAcquiredGift], NoError>?
    
    init(
        context: AccountContext,
        toPeerId: EnginePeer.Id,
        text: String?,
        entities: [MessageTextEntity]?,
        hideName: Bool,
        gift: StarGift,
        auctionContext: GiftAuctionContext,
        acquiredGifts: Signal<[GiftAuctionAcquiredGift], NoError>?
    ) {
        self.context = context
        self.toPeerId = toPeerId
        self.text = text
        self.entities = entities
        self.hideName = hideName
        self.gift = gift
        self.auctionContext = auctionContext
        self.acquiredGifts = acquiredGifts
    }
    
    static func ==(lhs: GiftAuctionBidScreenComponent, rhs: GiftAuctionBidScreenComponent) -> Bool {
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var containerCornerRadius: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    private struct Amount: Equatable {
        private let sliderSteps: [Int]
        private let minRealValue: Int
        let minAllowedRealValue: Int
        let maxRealValue: Int
        let maxSliderValue: Int
        private let isLogarithmic: Bool
        
        private(set) var realValue: Int
        private(set) var sliderValue: Int
        
        private static func makeSliderSteps(minRealValue: Int, maxRealValue: Int, isLogarithmic: Bool) -> [Int] {
            if isLogarithmic {
                var sliderSteps: [Int] = [100, 500, 1_000, 2_000, 5_000, 10_000, 25_000, 50_000, 100_000, 500_000]
                sliderSteps.removeAll(where: { $0 <= minRealValue })
                sliderSteps.insert(minRealValue, at: 0)
                sliderSteps.removeAll(where: { $0 >= maxRealValue })
                sliderSteps.append(maxRealValue)
                return sliderSteps
            } else {
                return [minRealValue, maxRealValue]
            }
        }
        
        private static func remapValueToSlider(realValue: Int, minAllowedRealValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
            guard realValue >= steps.first!, realValue <= steps.last! else { return 0 }

            let realValue = max(minAllowedRealValue, realValue)
            
            for i in 0 ..< steps.count - 1 {
                if realValue >= steps[i] && realValue <= steps[i + 1] {
                    let range = steps[i + 1] - steps[i]
                    let relativeValue = realValue - steps[i]
                    let stepFraction = Float(relativeValue) / Float(range)
                    return Int(Float(i) * Float(maxSliderValue) / Float(steps.count - 1)) + Int(stepFraction * Float(maxSliderValue) / Float(steps.count - 1))
                }
            }
            return maxSliderValue // Return max slider position if value equals the last step
        }

        private static func remapSliderToValue(sliderValue: Int, minAllowedRealValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
            guard sliderValue >= 0, sliderValue <= maxSliderValue else { return steps.first! }

            let stepIndex = Int(Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1))
            let fraction = Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1) - Float(stepIndex)
            
            if stepIndex >= steps.count - 1 {
                return steps.last!
            } else {
                let range = steps[stepIndex + 1] - steps[stepIndex]
                return max(minAllowedRealValue, steps[stepIndex] + Int(fraction * Float(range)))
            }
        }
        
        init(realValue: Int, minRealValue: Int, minAllowedRealValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
            self.sliderSteps = Amount.makeSliderSteps(minRealValue: minRealValue, maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
            self.minRealValue = minRealValue
            self.minAllowedRealValue = minAllowedRealValue
            self.maxRealValue = maxRealValue
            self.maxSliderValue = maxSliderValue
            self.isLogarithmic = isLogarithmic
            
            self.realValue = realValue
            self.sliderValue = Amount.remapValueToSlider(realValue: self.realValue, minAllowedRealValue: self.minAllowedRealValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
        }
        
        init(sliderValue: Int, minRealValue: Int, minAllowedRealValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
            self.sliderSteps = Amount.makeSliderSteps(minRealValue: minRealValue, maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
            self.minRealValue = minRealValue
            self.minAllowedRealValue = minAllowedRealValue
            self.maxRealValue = maxRealValue
            self.maxSliderValue = maxSliderValue
            self.isLogarithmic = isLogarithmic
            
            self.sliderValue = sliderValue
            self.realValue = Amount.remapSliderToValue(sliderValue: self.sliderValue, minAllowedRealValue: self.minAllowedRealValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
        }
        
        func withRealValue(_ realValue: Int) -> Amount {
            return Amount(realValue: realValue, minRealValue: self.minRealValue, minAllowedRealValue: self.minAllowedRealValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
        
        func withSliderValue(_ sliderValue: Int) -> Amount {
            return Amount(sliderValue: sliderValue, minRealValue: self.minRealValue, minAllowedRealValue: self.minAllowedRealValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
        
        func withMinAllowedRealValue(_ minAllowedRealValue: Int) -> Amount {
            return Amount(realValue: self.realValue, minRealValue: self.minRealValue, minAllowedRealValue: minAllowedRealValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
        
        func withMaxRealValue(_ maxRealValue: Int) -> Amount {
            return Amount(realValue: self.realValue, minRealValue: self.minRealValue, minAllowedRealValue: self.minAllowedRealValue, maxRealValue: maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
        
        func cutoffSliderValue(for cutoffRealValue: Int) -> Int {
            let clampedReal = max(self.minRealValue, min(cutoffRealValue, self.maxRealValue))
            
            return Amount.remapValueToSlider(
                realValue: clampedReal,
                minAllowedRealValue: self.minAllowedRealValue,
                maxSliderValue: self.maxSliderValue,
                steps: self.sliderSteps
            )
        }
    }
        
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        private let hierarchyTrackingNode: HierarchyTrackingNode
        
        private let topEdgeEffectView: EdgeEffectView
        private let bottomEdgeEffectView: EdgeEffectView
        
        private var balanceOverlay = ComponentView<Empty>()
        
        private let backgroundHandleView: UIImageView
        
        private let closeButton = ComponentView<Empty>()
        private let moreButton = ComponentView<Empty>()
        private let moreButtonPlayOnce = ActionSlot<Void>()
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private let badgeStars = BadgeStarsView()
        private let sliderBackground = ComponentView<Empty>()
        private let slider = ComponentView<Empty>()
        private let sliderPlus = ComponentView<Empty>()
        private let badge = ComponentView<Empty>()
        
        private var auctionStats: [ComponentView<Empty>] = []
        
        private let myGifts = ComponentView<Empty>()
                
        private var myPeerTitle: ComponentView<Empty>?
        private var myPeerItem: ComponentView<Empty>?
        
        private var topPeersTitle: ComponentView<Empty>?
        private var topPeerItems: [EnginePeer.Id: ComponentView<Empty>] = [:]
        
        private var giftAuctionState: GiftAuctionContext.State?
        private var giftAuctionDisposable: Disposable?
        private var giftAuctionTimer: SwiftSignalKit.Timer?
        private var peersMap: [EnginePeer.Id: EnginePeer] = [:]
        
        private var giftAuctionAcquiredGifts: [GiftAuctionAcquiredGift]?
        private let giftAuctionAcquiredGiftsDisposable = MetaDisposable()
        
        private let actionButton = ComponentView<Empty>()
                
        private var ignoreScrolling: Bool = false
        
        private var component: GiftAuctionBidScreenComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
                
        private var balance: StarsAmount?
        
        private var amount: Amount = Amount(realValue: 1, minRealValue: 1, minAllowedRealValue: 1, maxRealValue: 1000, maxSliderValue: 1000, isLogarithmic: true)
        private var didChangeAmount: Bool = false
        
        private var cachedStarImage: (UIImage, PresentationTheme)?
                
        private var balanceDisposable: Disposable?
        
        private var badgePhysicsLink: SharedDisplayLinkDriver.Link?
        
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = UIView()
            
            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 40.0
            self.containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 40.0
            
            self.backgroundHandleView = UIImageView()
            
            self.navigationBarContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.hierarchyTrackingNode = HierarchyTrackingNode()
            
            self.topEdgeEffectView = EdgeEffectView()
            self.topEdgeEffectView.clipsToBounds = true
            self.topEdgeEffectView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.topEdgeEffectView.layer.cornerRadius = 40.0
            
            self.bottomEdgeEffectView = EdgeEffectView()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.layer.addSublayer(self.backgroundLayer)
                        
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
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.containerView.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.containerView.addSubview(self.navigationBarContainer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.containerView.addSubnode(self.hierarchyTrackingNode)
            
            self.hierarchyTrackingNode.updated = { [weak self] value in
                guard let self else {
                    return
                }
                if value {
                    if self.badgePhysicsLink == nil {
                        let badgePhysicsLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.updateBadgePhysics()
                        })
                        self.badgePhysicsLink = badgePhysicsLink
                    }
                } else {
                    if let badgePhysicsLink = self.badgePhysicsLink {
                        self.badgePhysicsLink = nil
                        badgePhysicsLink.invalidate()
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.balanceDisposable?.dispose()
            self.giftAuctionDisposable?.dispose()
            self.giftAuctionTimer?.invalidate()
            self.giftAuctionAcquiredGiftsDisposable.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            if let balanceView = self.balanceOverlay.view, let result = balanceView.hitTest(self.convert(point, to: balanceView), with: event) {
                return result
            }
            
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            if let badgeView = self.badge.view, badgeView.hitTest(self.convert(point, to: badgeView), with: event) != nil {
                if let sliderView = self.slider.view as? SliderComponent.View, let hitTestTarget = sliderView.hitTestTarget {
                    return hitTestTarget
                }
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
        
        private func loadAcquiredGifts() {
            guard let component = self.component, case let .generic(gift) = component.gift else {
                return
            }
            self.giftAuctionAcquiredGiftsDisposable.set((component.context.engine.payments.getGiftAuctionAcquiredGifts(giftId: gift.id)
            |> deliverOnMainQueue).startStrict(next: { [weak self] acquiredGifts in
                guard let self else {
                    return
                }
                self.giftAuctionAcquiredGifts = acquiredGifts
                self.state?.updated(transition: .easeInOut(duration: 0.25))
            }))
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let minScale: CGFloat = (itemLayout.containerSize.width - 6.0 * 2.0) / itemLayout.containerSize.width
            let minScaledTranslation: CGFloat = (itemLayout.containerSize.height - itemLayout.containerSize.height * minScale) * 0.5 - 6.0
            let minScaledCornerRadius: CGFloat = itemLayout.containerCornerRadius
            
            let scale = minScale * (1.0 - topOffsetFraction) + 1.0 * topOffsetFraction
            let scaledTranslation = minScaledTranslation * (1.0 - topOffsetFraction)
            let scaledCornerRadius = minScaledCornerRadius * (1.0 - topOffsetFraction) + itemLayout.containerCornerRadius * topOffsetFraction
            
            var containerTransform = CATransform3DIdentity
            containerTransform = CATransform3DTranslate(containerTransform, 0.0, scaledTranslation, 0.0)
            containerTransform = CATransform3DScale(containerTransform, scale, scale, scale)
            transition.setTransform(view: self.containerView, transform: containerTransform)
            transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: scaledCornerRadius)
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            self.bottomEdgeEffectView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
            self.bottomEdgeEffectView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
          
            if let view = self.balanceOverlay.view {
                view.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4, removeOnCompletion: false)
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
        }
        
        private var previousSliderValue: Float = 0.0
        private var previousTimestamp: Double?
        
        private var badgeAngularSpeed: CGFloat = 0.0
        private var badgeAngle: CGFloat = 0.0
        private var previousBadgeX: CGFloat?
        private var previousPhysicsTimestamp: Double?
        
        private func updateBadgePhysics() {
            let timestamp = CACurrentMediaTime()
            
            let deltaTime: CGFloat
            if let previousPhysicsTimestamp = self.previousPhysicsTimestamp {
                deltaTime = CGFloat(min(1.0 / 60.0, timestamp - previousPhysicsTimestamp))
            } else {
                deltaTime = CGFloat(1.0 / 60.0)
            }
            self.previousPhysicsTimestamp = timestamp
            
            guard let badgeView = self.badge.view as? BadgeComponent.View else {
                return
            }
            let badgeX = badgeView.center.x
            
            let horizontalVelocity: CGFloat
            if let previousBadgeX = self.previousBadgeX {
                horizontalVelocity = (badgeX - previousBadgeX) / deltaTime
            } else {
                horizontalVelocity = 0.0
            }
            self.previousBadgeX = badgeX
            
            let testSpringFriction: CGFloat = 9.0
            let testSpringConstant: CGFloat = 243.0
            
            let frictionConstant: CGFloat = testSpringFriction
            let springConstant: CGFloat = testSpringConstant
            let time: CGFloat = deltaTime
            
            var badgeAngle = self.badgeAngle
            
            badgeAngle -= horizontalVelocity * 0.0001
            if abs(badgeAngle) > 0.22 {
                badgeAngle = badgeAngle < 0.0 ? -0.22 : 0.22
            }
            
            // friction force = velocity * friction constant
            let frictionForce = self.badgeAngularSpeed * frictionConstant
            // spring force = (target point - current position) * spring constant
            let springForce = -badgeAngle * springConstant
            // force = spring force - friction force
            let force = springForce - frictionForce
            
            // velocity = current velocity + force * time / mass
            self.badgeAngularSpeed = self.badgeAngularSpeed + force * time
            // position = current position + velocity * time
            badgeAngle = badgeAngle + self.badgeAngularSpeed * time
            badgeAngle = badgeAngle.isNaN ? 0.0 : badgeAngle
            
            let epsilon: CGFloat = 0.01
            if abs(badgeAngle) < epsilon && abs(self.badgeAngularSpeed) < epsilon {
                badgeAngle = 0.0
                self.badgeAngularSpeed = 0.0
            }
            
            if abs(badgeAngle) > 0.22 {
                badgeAngle = badgeAngle < 0.0 ? -0.22 : 0.22
            }
            
            if self.badgeAngle != badgeAngle {
                self.badgeAngle = badgeAngle
                badgeView.updateBadgeAngle(angle: self.badgeAngle)
            }
        }
        
        private var isLoading = false
        private func commitBid(value: Int64) {
            guard let component = self.component, let environment = self.environment, let controller = self.environment?.controller(), let balance = self.balance, case let .generic(gift) = component.gift else {
                return
            }
            
            var isUpdate = false
            var myBidPeerId: EnginePeer.Id?
            if let peerId = self.giftAuctionState?.myState.bidPeerId {
                myBidPeerId = peerId
            }
            var requiredStars = value
            if let myBidAmount = self.giftAuctionState?.myState.bidAmount {
                requiredStars = requiredStars - myBidAmount
                isUpdate = true
                if value == myBidAmount {
                    controller.dismiss()
                    return
                }
            }
            
            if balance < StarsAmount(value: requiredStars, nanos: 0) {
                let _ = (component.context.engine.payments.starsTopUpOptions()
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                    guard let self, let component = self.component else {
                        return
                    }
                    guard let starsContext = component.context.starsContext else {
                        return
                    }
                    
                    let purchasePurpose: StarsPurchasePurpose = .generic
                    let purchaseScreen = component.context.sharedContext.makeStarsPurchaseScreen(context: component.context, starsContext: starsContext, options: options, purpose: purchasePurpose, targetPeerId: nil, customTheme: environment.theme, completion: { result in
                        let _ = result
                        //TODO:release
                    })
                    self.environment?.controller()?.push(purchaseScreen)
                    self.environment?.controller()?.dismiss()
                })
                
                return
            }
            
            let giftsPerRounds = gift.auctionGiftsPerRound ?? 50
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            if let myBidAmount = self.giftAuctionState?.myState.bidAmount, let myMinBidAmount = self.giftAuctionState?.myState.minBidAmount, value < myMinBidAmount {
                HapticFeedback().error()
                controller.present(
                    UndoOverlayController(
                        presentationData: presentationData,
                        content: .info(
                            title: nil,
                            text: presentationData.strings.Gift_AuctionBid_AddMoreStars(presentationData.strings.Gift_AuctionBid_AddMoreStars_Stars(Int32(clamping: myMinBidAmount - myBidAmount))).string,
                            timeout: nil,
                            customUndoText: presentationData.strings.Gift_AuctionBid_AddMoreStars_Set
                        ),
                        position: .bottom,
                        action: { [weak self] action in
                            if let self, case .undo = action {
                                self.resetSliderValue(component: self.component, forceMinimum: true)
                            }
                            return true
                        }
                    ),
                    in: .current
                )
                return
            }
            
            self.isLoading = true
            self.state?.updated()
            
            var peerId: EnginePeer.Id?
            if !isUpdate || (myBidPeerId != nil && myBidPeerId != component.toPeerId) {
                peerId = component.toPeerId
            }
            
            let source: BotPaymentInvoiceSource = .starGiftAuctionBid(
               update: isUpdate,
               hideName: peerId != nil ? component.hideName : false,
               peerId: peerId,
               giftId: gift.id,
               bidAmount: value,
               text: peerId != nil ? component.text : nil,
               entities: peerId != nil ? component.entities : nil
           )
            
            let signal = BotCheckoutController.InputData.fetch(context: component.context, source: source)
            |> `catch` { error -> Signal<BotCheckoutController.InputData, SendBotPaymentFormError> in
                return .fail(.generic)
            }
            |> mapToSignal { inputData -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
                return component.context.engine.payments.sendStarsPaymentForm(formId: inputData.form.id, source: source)
            }
            |> deliverOnMainQueue
            
            let _ = signal.start(next: { [weak self, weak controller] result in
                guard let self, let component = self.component else {
                    return
                }
                Queue.mainQueue().after(0.1) {
                    self.isLoading = false
                    self.state?.updated()
                }
                
                let newMaxValue = Int(Double(value) * 1.5)
                var updatedAmount = self.amount.withMinAllowedRealValue(Int(value)).withRealValue(Int(value))
                if newMaxValue > self.amount.maxRealValue {
                    updatedAmount = updatedAmount.withMaxRealValue(newMaxValue)
                }
                self.amount = updatedAmount
                self.state?.updated()
                
                if !isUpdate {
                    component.auctionContext.load()
                }
                
                let title = isUpdate ? presentationData.strings.Gift_AuctionBid_Increased_Title : presentationData.strings.Gift_AuctionBid_Placed_Title
                let text = isUpdate ? presentationData.strings.Gift_AuctionBid_Increased_Text("\(giftsPerRounds)").string : presentationData.strings.Gift_AuctionBid_Placed_Text("\(giftsPerRounds)").string
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                controller?.present(
                    UndoOverlayController(
                        presentationData: presentationData,
                        content: .universalImage(
                            image: generateTintedImage(image:  UIImage(bundleImageName: "Premium/Auction/BidMedium"), color: .white)!,
                            size: nil,
                            title: title,
                            text: text,
                            customUndoText: nil,
                            timeout: nil
                        ),
                        position: .bottom,
                        action: { _ in return true }
                    ),
                    in: .current
                )
                  
                Queue.mainQueue().after(2.5) {
                    component.context.starsContext?.load(force: true)
                }
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                
                HapticFeedback().error()
                
                let currentValue = self.amount.realValue
                self.component?.context.starsContext?.load(force: true)
                self.resetSliderValue(component: self.component, forceMinimum: true)
                
                if self.amount.realValue > currentValue {
                    controller.present(
                        UndoOverlayController(
                            presentationData: presentationData,
                            content: .info(
                                title: nil,
                                text: presentationData.strings.Gift_AuctionBid_MinimumBidIncreased(presentationData.strings.Gift_AuctionBid_AddMoreStars_Stars(Int32(clamping: self.amount.realValue))).string,
                                timeout: nil,
                                customUndoText: nil
                            ),
                            position: .bottom,
                            action: { _ in
                                return true
                            }
                        ),
                        in: .current
                    )
                }
                
                Queue.mainQueue().after(0.1) {
                    self.isLoading = false
                    self.state?.updated()
                }
            })
        }
        
        private func openPeer(_ peer: EnginePeer, dismiss: Bool = true) {
            guard let component = self.component, let controller = self.environment?.controller() as? GiftAuctionBidScreen, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
                    
            let context = component.context
            let action = {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                    navigationController: navigationController,
                    chatController: nil,
                    context: context,
                    chatLocation: .peer(peer),
                    subject: nil,
                    botStart: nil,
                    updateTextInputState: nil,
                    keepStack: .always,
                    useExisting: true,
                    purposefulAction: nil,
                    scrollToEndIfExists: false,
                    activateMessageSearch: nil,
                    animated: true
                ))
            }
            
            if dismiss {
                controller.dismiss()
                Queue.mainQueue().after(0.4, {
                    action()
                })
            } else {
                action()
            }
        }
        
        func share() {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            
            let context = component.context
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var link = ""
            if case let .generic(gift) = component.auctionContext.gift, let slug = gift.auctionSlug {
                link = "https://t.me/auction/\(slug)"
            }
            
            let shareController = context.sharedContext.makeShareController(
                context: context,
                subject: .url(link),
                forceExternal: false,
                shareStory: nil,
                enqueued: { [weak self, weak controller] peerIds, _ in
                    guard let self else {
                        return
                    }
                    let _ = (context.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] peerList in
                        guard let self else {
                            return
                        }
                        let peers = peerList.compactMap { $0 }
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let text: String
                        var savedMessages = false
                        if peerIds.count == 1, let peerId = peerIds.first, peerId == context.account.peerId {
                            text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                            savedMessages = true
                        } else {
                            if peers.count == 1, let peer = peers.first {
                                var peerName = peer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                var firstPeerName = firstPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                var secondPeerName = secondPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                            } else if let peer = peers.first {
                                var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                            } else {
                                text = ""
                            }
                        }
                        
                        controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { [weak self, weak controller] action in
                            if let self, savedMessages, action == .info {
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                                |> deliverOnMainQueue).start(next: { [weak self, weak controller] peer in
                                    guard let peer else {
                                        return
                                    }
                                    self?.openPeer(peer)
                                    Queue.mainQueue().after(0.6) {
                                        controller?.dismiss(animated: false, completion: nil)
                                    }
                                })
                            }
                            return false
                        }, additionalView: nil), in: .current)
                    })
                },
                actionCompleted: { [weak controller] in
                    controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            )
            controller.present(shareController, in: .window(.root))
        }
        
        func morePressed(view: UIView, gesture: ContextGesture?) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            
            let context = component.context
            let gift = component.auctionContext.gift
            let auctionContext = component.auctionContext
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var link = ""
            if case let .generic(gift) = gift, let slug = gift.auctionSlug {
                link = "https://t.me/auction/\(slug)"
            }
            
            var items: [ContextMenuItem] = []
          
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Auction_Context_About, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor) }, action: { [weak controller] c, f in
                f(.default)
                
                let infoController = context.sharedContext.makeGiftAuctionInfoScreen(context: context, auctionContext: auctionContext, completion: nil)
                controller?.push(infoController)
            })))
                         
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Auction_Context_CopyLink, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor) }, action: { [weak controller] c, f in
                f(.default)
                
                UIPasteboard.general.string = link
                
                controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Auction_Context_Share, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                f(.default)
                
                self?.share()
            })))

            let contextController = makeContextController(presentationData: presentationData, source: .reference(GiftViewContextReferenceContentSource(controller: controller, sourceView: view)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            controller.presentInGlobalOverlay(contextController)
        }
        
        func presentCustomBidController() {
            guard let component = self.component, let environment = self.environment, case let .generic(gift) = component.gift else {
                return
            }
            
            guard let auctionState = self.giftAuctionState else {
                return
            }
            
            var minBidAmount: Int64 = 100
            if case let .ongoing(_, _, _, auctionMinBidAmount, _, _, _, _, _, _, _, _) = auctionState.auctionState {
                minBidAmount = auctionMinBidAmount
                if let myMinBidAmount = auctionState.myState.minBidAmount {
                    minBidAmount = myMinBidAmount
                }
            }
            
            
            let giftsPerRounds = gift.auctionGiftsPerRound ?? 50
            
            let controller = giftAuctionCustomBidController(
                context: component.context,
                title: environment.strings.Gift_AuctionBid_CustomBid_Title,
                text: environment.strings.Gift_AuctionBid_CustomBid_Text("\(giftsPerRounds)").string,
                placeholder: environment.strings.Gift_AuctionBid_CustomBid_Placeholder,
                action: environment.strings.Gift_AuctionBid_CustomBid_Done,
                minValue: minBidAmount,
                value: minBidAmount,
                apply: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.commitBid(value: value)
                },
                cancel: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.resetSliderValue()
                    self.state?.updated()
                }
            )
            self.environment?.controller()?.present(controller, in: .window(.root))
        }
        
        func resetSliderValue(component: GiftAuctionBidScreenComponent? = nil, forceMinimum: Bool = false) {
            guard let state = self.giftAuctionState else {
                return
            }
            var minBidAmount: Int64 = 100
            var maxBidAmount: Int64 = 50000
            if case let .ongoing(_, _, _, auctionMinBidAmount, bidLevels, _, _, _, _, _, _, _) = state.auctionState {
                minBidAmount = auctionMinBidAmount
                if let firstLevel = bidLevels.first(where: { $0.position == 1 }) {
                    maxBidAmount = max(maxBidAmount, Int64(Double(firstLevel.amount) * 1.5))
                }
            }
            var currentValue = Int(minBidAmount)
            var minAllowedRealValue: Int64 = minBidAmount
            if let myBidAmount = state.myState.bidAmount {
                if let component, let bidPeerId = state.myState.bidPeerId, bidPeerId != component.toPeerId || forceMinimum, let myMinBidAmount = state.myState.minBidAmount {
                    currentValue = Int(myMinBidAmount)
                } else {
                    currentValue = Int(myBidAmount)
                }
                minAllowedRealValue = myBidAmount
            }
            
            self.amount = Amount(realValue: currentValue, minRealValue: Int(minBidAmount), minAllowedRealValue: Int(minAllowedRealValue), maxRealValue: Int(maxBidAmount), maxSliderValue: 999, isLogarithmic: true)
        }
        
        func update(component: GiftAuctionBidScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, environment.deviceMetrics.screenSize.width) - environment.safeInsets.left * 2.0
            }
            let rawSideInset = floor((availableSize.width - fillingSize) * 0.5)
            let sideInset: CGFloat = floor((availableSize.width - fillingSize) * 0.5) + 24.0
            
            let context = component.context
            let balanceSize = self.balanceOverlay.update(
                transition: .immediate,
                component: AnyComponent(
                    StarsBalanceOverlayComponent(
                        context: component.context,
                        peerId: component.context.account.peerId,
                        theme: environment.theme,
                        currency: .stars,
                        action: { [weak self] in
                            guard let self, let starsContext = context.starsContext, let navigationController = self.environment?.controller()?.navigationController as? NavigationController else {
                                return
                            }
                            self.environment?.controller()?.dismiss()
                            
                            let _ = (context.engine.payments.starsTopUpOptions()
                            |> take(1)
                            |> deliverOnMainQueue).startStandalone(next: { options in
                                let controller = context.sharedContext.makeStarsPurchaseScreen(
                                    context: context,
                                    starsContext: starsContext,
                                    options: options,
                                    purpose: .generic,
                                    targetPeerId: nil,
                                    customTheme: environment.theme,
                                    completion: { _ in }
                                )
                                navigationController.pushViewController(controller)
                            })
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.balanceOverlay.view {
                if view.superview == nil {
                    self.addSubview(view)
                    
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: -64.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, removeOnCompletion: true, additive: false, completion: nil)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - balanceSize.width) / 2.0), y: environment.statusBarHeight + 5.0), size: balanceSize)
            }
            
            if self.component == nil {
                if let starsContext = component.context.starsContext {
                    self.balanceDisposable = (starsContext.state
                    |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        if let state {
                            if self.balance != state.balance {
                                self.balance = state.balance
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    })
                }
                
                let context = component.context
                let auctionContext = component.auctionContext
                self.giftAuctionDisposable = (component.auctionContext.state
                |> deliverOnMainQueue).start(next: { [weak self] auctionState in
                    guard let self else {
                        return
                    }
                    let isFirstTime = self.giftAuctionState == nil
                    let previousState = self.giftAuctionState
                    self.giftAuctionState = auctionState
                    
                    var peerIds: [EnginePeer.Id] = []
                    var transition = ComponentTransition.spring(duration: 0.4)

                    if isFirstTime {
                        peerIds.append(context.account.peerId)
                        self.resetSliderValue(component: component)
                        transition = .immediate
                        
                        if let acquiredGifts = component.acquiredGifts {
                            self.giftAuctionAcquiredGiftsDisposable.set((acquiredGifts
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] acquiredGifts in
                                self?.giftAuctionAcquiredGifts = acquiredGifts
                            }))
                        } else if let acquiredCount = auctionState?.myState.acquiredCount, acquiredCount > 0 {
                            Queue.mainQueue().justDispatch {
                                self.loadAcquiredGifts()
                            }
                        }
                    }
                    
                    if !peerIds.isEmpty {
                        let _ = (context.engine.data.get(EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                            }
                        ))
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] peers in
                            guard let self else {
                                return
                            }
                            var peersMap: [EnginePeer.Id: EnginePeer] = self.peersMap
                            for (peerId, maybePeer) in peers {
                                if let peer = maybePeer {
                                    peersMap[peerId] = peer
                                }
                            }
                            self.peersMap = peersMap
                            self.state?.updated(transition: transition)
                        })
                    }
                    self.state?.updated(transition: transition)
                    
                    if let acquiredCount = auctionState?.myState.acquiredCount, let previousAcquiredCount = previousState?.myState.acquiredCount, acquiredCount > previousAcquiredCount {
                        Queue.mainQueue().justDispatch {
                            self.loadAcquiredGifts()
                        }
                        if !isFirstTime {
                            if let bidPeerId = previousState?.myState.bidPeerId, let controller = self.environment?.controller() {
                                if let navigationController = controller.navigationController as? NavigationController {
                                    var controllers = navigationController.viewControllers
                                    controllers = controllers.filter { !($0 is GiftAuctionBidScreen) && !($0 is GiftSetupScreenProtocol) && !($0 is GiftOptionsScreenProtocol) && !($0 is PeerInfoScreen) && !($0 is ContactSelectionController) }
                                                                        
                                    var foundController = false
                                    for controller in controllers.reversed() {
                                        if let chatController = controller as? ChatController, case .peer(id: bidPeerId) = chatController.chatLocation {
                                            chatController.hintPlayNextOutgoingGift()
                                            foundController = true
                                            break
                                        }
                                    }
                                    if !foundController {
                                        let chatController = component.context.sharedContext.makeChatController(context: component.context, chatLocation: .peer(id: bidPeerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                                        chatController.hintPlayNextOutgoingGift()
                                        controllers.append(chatController)
                                    }
                                    navigationController.setViewControllers(controllers, animated: true)
                                    
                                    for controller in controllers {
                                        if controller is MinimizableController {
                                            controller.dismiss(animated: true)
                                        }
                                    }
                                }
                            } else {
                                self.resetSliderValue()
                                self.addSubview(ConfettiView(frame: self.bounds))
                            }
                        }
                    }
                    
                    if case .finished = auctionState?.auctionState, let controller = self.environment?.controller() {
                        if let navigationController = controller.navigationController as? NavigationController {
                            controller.dismiss()
                            let auctionController = context.sharedContext.makeGiftAuctionViewScreen(context: context, auctionContext: auctionContext, peerId: nil, completion: { _, _ in })
                            navigationController.pushViewController(auctionController)
                        }
                    }
                })
                
                self.giftAuctionTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                    let _ = self
                    self?.state?.updated()
                }, queue: Queue.mainQueue())
                self.giftAuctionTimer?.start()
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.actionSheet.opaqueItemBackgroundColor.cgColor
            }
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            
            let sliderInset: CGFloat = sideInset + 8.0
            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(SliderComponent(
                    content: .discrete(SliderComponent.Discrete(
                        valueCount: self.amount.maxSliderValue + 1,
                        value: self.amount.sliderValue,
                        markPositions: false,
                        valueUpdated: { [weak self] value in
                            guard let self else {
                                return
                            }
                            
                            let maxAmount: Int = 999
                            
                            self.amount = self.amount.withSliderValue(value)
                            self.didChangeAmount = true
                            
                            self.state?.updated(transition: ComponentTransition(animation: .none).withUserData(IsAdjustingAmountHint()))
                            
                            let sliderValue = Float(value) / Float(maxAmount)
                            let currentTimestamp = CACurrentMediaTime()
                            
                            if let previousTimestamp {
                                let deltaTime = currentTimestamp - previousTimestamp
                                let delta = sliderValue - self.previousSliderValue
                                let deltaValue = abs(sliderValue - self.previousSliderValue)
                                
                                let speed = deltaValue / Float(deltaTime)
                                let newSpeed = max(0, min(65.0, speed * 70.0))
                                
                                if newSpeed < 0.01 && deltaValue < 0.001 {
                                } else {
                                    self.badgeStars.update(speed: newSpeed, delta: delta)
                                }
                            }
                            
                            if sliderValue == 1.0 && self.previousSliderValue != 1.0 {
                                self.presentCustomBidController()
                                HapticFeedback().tap()
                                if let sliderView = self.slider.view as? SliderComponent.View {
                                    sliderView.cancelGestures()
                                }
                            }
                            
                            self.previousSliderValue = sliderValue
                            self.previousTimestamp = currentTimestamp
                        }
                    )),
                    trackBackgroundColor: .clear,
                    trackForegroundColor: .clear,
                    knobSize: 26.0,
                    knobColor: .white,
                    isTrackingUpdated: { [weak self] isTracking in
                        guard let self else {
                            return
                        }
                        if !isTracking {
                            self.previousTimestamp = nil
                            self.badgeStars.update(speed: 0.0)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sliderInset * 2.0, height: 30.0)
            )
            
            let sliderPlusSize = self.sliderPlus.update(
                transition: .immediate,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: "+", font: Font.with(size: 26.0, design: .round, weight: .regular), textColor: environment.theme.list.itemSecondaryTextColor.withAlphaComponent(0.5))))
                        ),
                        action: { [weak self] in
                            self?.presentCustomBidController()
                        }
                    ).minSize(CGSize(width: 30.0, height: 30.0))
                ),
                environment: {},
                containerSize: availableSize
            )

            contentHeight += 148.0
            
            let sliderFrame = CGRect(origin: CGPoint(x: sliderInset, y: contentHeight), size: sliderSize)
            let sliderBackgroundFrame = CGRect(origin: CGPoint(x: sliderFrame.minX - 8.0, y: sliderFrame.minY + 7.0), size: CGSize(width: sliderFrame.width + 16.0, height: sliderFrame.height - 14.0))
            let sliderPlusFrame = CGRect(origin: CGPoint(x: sliderBackgroundFrame.maxX - sliderPlusSize.width + 1.0, y: sliderBackgroundFrame.minY - 3.0 + UIScreenPixel), size: sliderPlusSize)
            
            let progressFraction: CGFloat = CGFloat(self.amount.sliderValue) / CGFloat(self.amount.maxSliderValue)
                        
            var sliderColor: UIColor = UIColor(rgb: 0xFFB10D)
            
            let liveStreamParams = LiveChatMessageParams(appConfig: component.context.currentAppConfiguration.with({ $0 }))
            let color = GroupCallMessagesContext.getStarAmountParamMapping(params: liveStreamParams, value: Int64(self.amount.realValue / 5)).color ?? GroupCallMessagesContext.Message.Color(rawValue: 0x985FDC)
            sliderColor = StoryLiveChatMessageComponent.getMessageColor(color: color)
            
            var giftsPerRound: Int32 = 50
            if case let .generic(gift) = self.giftAuctionState?.gift, let giftsPerRoundValue = gift.auctionGiftsPerRound {
                giftsPerRound = giftsPerRoundValue
            }
            
            var myBidTitleComponent: AnyComponent<Empty>?
            var myBidComponent: AnyComponent<Empty>?
            
            var topBidsTitleComponent: AnyComponent<Empty>?
            var topBidsComponents: [(EnginePeer.Id, AnyComponent<Empty>)] = []
            
            var isUpcoming = false
            let place: Int32
            if let giftAuctionState = self.giftAuctionState, case let .ongoing(_, startDate, _, _, bidLevels, topBidders, _, _, _, _, _, lastGiftNumber) = giftAuctionState.auctionState {
                if currentTime < startDate {
                    isUpcoming = true
                }
                var myBidAmount = Int64(self.amount.realValue)
                var myBidDate = currentTime
                var isBiddingUp = true
                
                if let currentAmount = giftAuctionState.myState.bidAmount, let currentDate = giftAuctionState.myState.bidDate, currentAmount >= myBidAmount {
                    myBidAmount = currentAmount
                    myBidDate = currentDate
                    isBiddingUp = false
                }
                                
                let placeAndIsApproximate = giftAuctionState.getPlace(myBid: myBidAmount, myBidDate: myBidDate) ?? (1, false)
                place = placeAndIsApproximate.place
                
                var bidTitle: String
                var bidTitleColor: UIColor
                var bidStatus: PeerComponent.Status?
                
                var giftTitle: String?
                var giftNumber: Int32?
                if isBiddingUp {
                    bidTitleColor = environment.theme.list.itemSecondaryTextColor
                    bidTitle = environment.strings.Gift_AuctionBid_BidPreview
                } else if isUpcoming {
                    bidTitleColor = environment.theme.list.itemSecondaryTextColor
                    bidTitle = environment.strings.Gift_AuctionBid_UpcomingBid
                } else if giftAuctionState.myState.isReturned {
                    bidTitle = environment.strings.Gift_AuctionBid_Outbid
                    bidTitleColor = environment.theme.list.itemDestructiveColor
                    bidStatus = .returned
                } else if place > giftsPerRound {
                    bidTitle = environment.strings.Gift_AuctionBid_Outbid
                    bidTitleColor = environment.theme.list.itemDestructiveColor
                    bidStatus = .outbid
                } else {
                    bidTitle = environment.strings.Gift_AuctionBid_Winning
                    bidTitleColor = UIColor(rgb: 0x53a939)
                    bidStatus = .winning
                    if case let .generic(gift) = giftAuctionState.gift {
                        giftTitle = gift.title
                        giftNumber = lastGiftNumber + place
                    }
                }
                
                if let peer = self.peersMap[component.context.account.peerId] {
                    myBidTitleComponent = AnyComponent(PeerHeaderComponent(color: bidTitleColor, dateTimeFormat: environment.dateTimeFormat, title: bidTitle, giftTitle: giftTitle, giftNumber: giftNumber))
                    myBidComponent = AnyComponent(PeerComponent(
                        context: component.context,
                        theme: environment.theme,
                        groupingSeparator: environment.dateTimeFormat.groupingSeparator,
                        peer: peer,
                        place: place,
                        placeIsApproximate: placeAndIsApproximate.isApproximate,
                        amount: myBidAmount,
                        status: bidStatus,
                        isLast: true,
                        action: nil
                    ))
                }
                
                var i: Int32 = 1
                for peer in topBidders {
                    var bid: Int64 = 0
                    for level in bidLevels {
                        if level.position == i {
                            bid = level.amount
                            break
                        }
                    }
                    topBidsComponents.append((peer.id, AnyComponent(PeerComponent(
                        context: component.context,
                        theme: environment.theme,
                        groupingSeparator: environment.dateTimeFormat.groupingSeparator,
                        peer: peer,
                        place: i,
                        placeIsApproximate: false,
                        amount: bid,
                        isLast: i == topBidders.count,
                        action: nil
                    ))))
                    i += 1
                }
                
                if !topBidsComponents.isEmpty {
                    topBidsTitleComponent = AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_AuctionBid_TopWinnersTotal("\(giftsPerRound)").string.uppercased(), font: Font.medium(13.0), textColor: environment.theme.list.itemSecondaryTextColor))))
                }
            } else {
                place = 1
            }
            
            var topCutoffRealValue: Int?
            if place > giftsPerRound {
                if let giftAuctionState = self.giftAuctionState, case let .ongoing(_, _, _, _, bidLevels, _, _, _, _, _, _, _) = giftAuctionState.auctionState {
                    for bidLevel in bidLevels {
                        if bidLevel.position == giftsPerRound - 1 {
                            topCutoffRealValue = Int(bidLevel.amount)
                            break
                        }
                    }
                }
            }
            
            var topCutoff: CGFloat?
            if let topCutoffRealValue {
                let cutoffSliderValue = self.amount.cutoffSliderValue(for: topCutoffRealValue)
                topCutoff = CGFloat(cutoffSliderValue) / CGFloat(self.amount.maxSliderValue)
            }
            
            let _ = self.sliderBackground.update(
                transition: transition,
                component: AnyComponent(SliderBackgroundComponent(
                    theme: environment.theme,
                    strings: environment.strings,
                    value: progressFraction,
                    topCutoff: topCutoff,
                    giftsPerRound: giftsPerRound,
                    color: sliderColor
                )),
                environment: {},
                containerSize: sliderBackgroundFrame.size
            )
            
            if let sliderView = self.slider.view, let sliderBackgroundView = self.sliderBackground.view, let sliderPlusView = self.sliderPlus.view {
                if sliderView.superview == nil {
                    self.scrollContentView.addSubview(self.badgeStars)
                    self.scrollContentView.addSubview(sliderBackgroundView)
                    self.scrollContentView.addSubview(sliderView)
                    self.scrollContentView.addSubview(sliderPlusView)
                }
                transition.setFrame(view: sliderView, frame: sliderFrame)
                
                transition.setFrame(view: sliderBackgroundView, frame: sliderBackgroundFrame)
                
                transition.setFrame(view: sliderPlusView, frame: sliderPlusFrame)
                
                var subtitle: String?
                var badgeValue: String = "\(self.amount.realValue)"
                var subtitleOnTop = false
                
                if self.amount.sliderValue == self.amount.maxSliderValue {
                    badgeValue = environment.strings.Gift_AuctionBid_Custom
                } else if let myBidAmount = self.giftAuctionState?.myState.bidAmount {
                    if self.amount.realValue > myBidAmount {
                        subtitle = "+\(self.amount.realValue - Int(myBidAmount))"
                        subtitleOnTop = true
                    } else if myBidAmount == self.amount.realValue {
                        subtitle = environment.strings.Gift_AuctionBid_YourBid
                    }
                }
                
                let badgeSize = self.badge.update(
                    transition: transition,
                    component: AnyComponent(BadgeComponent(
                        theme: environment.theme,
                        prefix: nil,
                        title: badgeValue,
                        subtitle: subtitle,
                        subtitleOnTop: subtitleOnTop,
                        color: sliderColor
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 200.0)
                )
                
                let sliderMinWidth = sliderBackgroundFrame.height
                let sliderAreaWidth: CGFloat = sliderBackgroundFrame.width - sliderMinWidth
                let sliderForegroundFrame = CGRect(origin: sliderBackgroundFrame.origin, size: CGSize(width: sliderMinWidth + floorToScreenPixels(sliderAreaWidth * progressFraction), height: sliderBackgroundFrame.height))
                
                var badgeFrame = CGRect()
                if let badgeView = self.badge.view as? BadgeComponent.View {
                    if badgeView.superview == nil {
                        self.scrollContentView.insertSubview(badgeView, belowSubview: self.badgeStars)
                    }

                    let apparentBadgeSize = badgeSize
                    
                    let badgeOriginX = sliderBackgroundFrame.minX + sliderForegroundFrame.width - 15.0
                    badgeFrame = CGRect(origin: CGPoint(x: badgeOriginX - apparentBadgeSize.width * 0.5, y: sliderForegroundFrame.minY - 9.0 - badgeSize.height), size: apparentBadgeSize)
                    
                    let badgeSideInset: CGFloat = rawSideInset + 23.0
                    
                    let badgeOverflowWidth: CGFloat
                    if badgeFrame.minX < badgeSideInset {
                        badgeOverflowWidth = badgeSideInset - badgeFrame.minX
                    } else if badgeFrame.minX + badgeFrame.width > availableSize.width - badgeSideInset {
                        badgeOverflowWidth = availableSize.width - badgeSideInset - badgeFrame.width - badgeFrame.minX
                    } else {
                        badgeOverflowWidth = 0.0
                    }
                    
                    badgeFrame.origin.x += badgeOverflowWidth
                    let badgeTailOffset = badgeOriginX - badgeFrame.minX
                    let badgePosition = CGPoint(x: badgeFrame.minX + badgeTailOffset, y: badgeFrame.maxY)
                                        
                    badgeView.center = badgePosition
                    badgeView.bounds = CGRect(origin: CGPoint(), size: badgeFrame.size)
                    transition.setAnchorPoint(layer: badgeView.layer, anchorPoint: CGPoint(x: max(0.0, min(1.0, badgeTailOffset / badgeFrame.width)), y: 1.0))
                    badgeView.adjustTail(size: apparentBadgeSize, tailOffset: badgeTailOffset, transition: transition)
                }
                
                let starsRect = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: sliderForegroundFrame.midY))
                self.badgeStars.frame = starsRect
                self.badgeStars.update(size: starsRect.size, color: sliderColor, emitterPosition: CGPoint(x: badgeFrame.midX, y: badgeFrame.maxY - 32.0))
            }
                        
            var auctionStats: [([AnimatedTextComponent.Item], String)] = []
            
            var minBidAnimatedItems: [AnimatedTextComponent.Item] = []
            var untilNextRoundAnimatedItems: [AnimatedTextComponent.Item] = []
            var dropsLeftAnimatedItems: [AnimatedTextComponent.Item] = []
            
            var nextRoundTitle = environment.strings.Gift_AuctionBid_UntilNext
            if let auctionState = self.giftAuctionState?.auctionState, case let .ongoing(_, startDate, _, minBidAmount, _, _, nextDropDate, dropsLeft, currentRound, totalRounds, _, _) = auctionState {
                if currentTime < startDate {
                    nextRoundTitle = environment.strings.Gift_AuctionBid_BeforeStart
                } else if currentRound == totalRounds {
                    nextRoundTitle = environment.strings.Gift_AuctionBid_UntilEnd
                }
                
                var minBidAmount = minBidAmount
                if let myMinBidAmmount = self.giftAuctionState?.myState.minBidAmount {
                    minBidAmount = myMinBidAmmount
                }
                var minBidString: String
                if minBidAmount > 99999 {
                    minBidString = compactNumericCountString(Int(minBidAmount), decimalSeparator: environment.dateTimeFormat.decimalSeparator, showDecimalPart: false)
                } else {
                    minBidString = presentationStringsFormattedNumber(Int32(clamping: minBidAmount), environment.dateTimeFormat.groupingSeparator)
                }
                minBidString = "# \(minBidString)"
                if let hashIndex = minBidString.firstIndex(of: "#") {
                    var prefix = String(minBidString[..<hashIndex])
                    if !prefix.isEmpty {
                        prefix.removeLast()
                        minBidAnimatedItems.append(
                            AnimatedTextComponent.Item(
                                id: AnyHashable(minBidAnimatedItems.count),
                                content: .text(prefix)
                            )
                        )
                    }
                    
                    minBidAnimatedItems.append(
                        AnimatedTextComponent.Item(
                            id: AnyHashable(minBidAnimatedItems.count),
                            content: .icon("Premium/Stars/StarMedium", tint: false, offset: CGPoint(x: 1.0, y: 2.0 - UIScreenPixel))
                        )
                    )
                    
                    let suffixStart = minBidString.index(after: hashIndex)
                    let suffix = minBidString[suffixStart...]
                    
                    var i = suffix.startIndex
                    while i < suffix.endIndex {
                        if suffix[i].isNumber {
                            var j = i
                            while j < suffix.endIndex, suffix[j].isNumber {
                                j = suffix.index(after: j)
                            }
                            let string = suffix[i..<j]
                            if let value = Int(string) {
                                minBidAnimatedItems.append(
                                    AnimatedTextComponent.Item(
                                        id: AnyHashable(minBidAnimatedItems.count),
                                        content: .number(value, minDigits: string.count)
                                    )
                                )
                            }
                            i = j
                        } else {
                            var j = i
                            while j < suffix.endIndex, !suffix[j].isNumber {
                                j = suffix.index(after: j)
                            }
                            let textRun = String(suffix[i..<j])
                            if !textRun.isEmpty {
                                minBidAnimatedItems.append(
                                    AnimatedTextComponent.Item(
                                        id: AnyHashable(minBidAnimatedItems.count),
                                        content: .text(textRun)
                                    )
                                )
                            }
                            i = j
                        }
                    }
                } else {
                    minBidAnimatedItems.append(AnimatedTextComponent.Item(id: "static", content: .text(minBidString)))
                }
                
                let dropTimeout: Int32
                if currentTime < startDate {
                    dropTimeout = max(0, startDate - currentTime)
                } else {
                    dropTimeout = max(0, nextDropDate - currentTime)
                }
                
                let hours = Int(dropTimeout / 3600)
                let minutes = Int((dropTimeout % 3600) / 60)
                let seconds = Int(dropTimeout % 60)
                
                if hours > 0 {
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "h", content: .number(hours, minDigits: 1)))
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "colon1", content: .text(":")))
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "colon2", content: .text(":")))
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
                } else {
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "m", content: .number(minutes, minDigits: 2)))
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "colon", content: .text(":")))
                    untilNextRoundAnimatedItems.append(AnimatedTextComponent.Item(id: "s", content: .number(seconds, minDigits: 2)))
                }
                
                if dropsLeft >= 10000 {
                    var compactString = compactNumericCountString(Int(dropsLeft), decimalSeparator: ".", showDecimalPart: false)
                    let suffix = String(compactString.suffix(1))
                    compactString.removeLast()
                    if let value = Int(compactString) {
                        dropsLeftAnimatedItems = [
                            AnimatedTextComponent.Item(id: "drops", content: .number(value, minDigits: 1)),
                            AnimatedTextComponent.Item(id: "suffix", content: .text(suffix))
                        ]
                    }
                } else {
                    dropsLeftAnimatedItems = [AnimatedTextComponent.Item(id: "drops", content: .number(Int(dropsLeft), minDigits: 1))]
                }
            }
            
            auctionStats.append((
                minBidAnimatedItems,
                environment.strings.Gift_AuctionBid_MinimumBid
            ))
            
            auctionStats.append((
                untilNextRoundAnimatedItems,
                nextRoundTitle
            ))
            
            auctionStats.append((
                dropsLeftAnimatedItems,
                environment.strings.Gift_AuctionBid_Left
            ))
            
            contentHeight += 54.0
            
            let statSpacing: CGFloat = 10.0
            let statWidth: CGFloat = floor((availableSize.width - sideInset * 2.0 - statSpacing * CGFloat(auctionStats.count - 1)) / CGFloat(auctionStats.count))
            let statHeight: CGFloat = 60.0
            
            for i in 0 ..< auctionStats.count {
                var statFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i) * (statWidth + statSpacing), y: contentHeight), size: CGSize(width: statWidth, height: statHeight))
                if i == auctionStats.count - 1 {
                    statFrame.size.width = max(0.0, availableSize.width - sideInset - statFrame.minX)
                }
                let statView: ComponentView<Empty>
                if self.auctionStats.count > i {
                    statView = self.auctionStats[i]
                } else {
                    statView = ComponentView()
                    self.auctionStats.append(statView)
                }
                let stat = auctionStats[i]
                let _ = statView.update(
                    transition: transition,
                    component: AnyComponent(AuctionStatComponent(
                        context: component.context,
                        gift: i == auctionStats.count - 1 ? component.auctionContext.gift : nil,
                        title: stat.0,
                        subtitle: stat.1,
                        small: false,
                        theme: environment.theme
                    )),
                    environment: {},
                    containerSize: statFrame.size
                )
                if let perkComponentView = statView.view {
                    if perkComponentView.superview == nil {
                        self.scrollContentView.addSubview(perkComponentView)
                    }
                    transition.setFrame(view: perkComponentView, frame: statFrame)
                }
            }
            
            contentHeight += statHeight
            contentHeight += 24.0
            
            let acquiredGiftsCount = self.giftAuctionState?.myState.acquiredCount ?? 0
            if acquiredGiftsCount > 0, case let .generic(gift) = component.gift {
                var myGiftsTransition = transition
                let myGiftsSize = self.myGifts.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PlainButtonComponent(content: AnyComponent(
                            HStack([
                                AnyComponentWithIdentity(id: "count", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: presentationStringsFormattedNumber(Int32(acquiredGiftsCount), environment.dateTimeFormat.groupingSeparator), font: Font.regular(17.0), textColor: environment.theme.actionSheet.controlAccentColor)))
                                )),
                                AnyComponentWithIdentity(id: "spacing", component: AnyComponent(
                                    Rectangle(color: .clear, width: 8.0, height: 1.0)
                                )),
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: environment.theme,
                                        strings: environment.strings,
                                        peer: nil,
                                        subject: .starGift(gift: gift, price: ""),
                                        mode: .buttonIcon
                                    )
                                )),
                                AnyComponentWithIdentity(id: "text", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: "  \(environment.strings.Gift_Auction_ItemsBought(Int32(acquiredGiftsCount)))", font: Font.regular(17.0), textColor: environment.theme.actionSheet.controlAccentColor)))
                                )),
                                AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
                                    BundleIconComponent(name: "Chat/Context Menu/Arrow", tintColor: environment.theme.actionSheet.controlAccentColor)
                                ))
                            ], spacing: 0.0)
                        ), action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            let giftController = GiftAuctionAcquiredScreen(context: component.context, gift: component.auctionContext.gift, acquiredGifts: self.giftAuctionAcquiredGifts ?? [])
                            self.environment?.controller()?.push(giftController)
                        }, animateScale: false)
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                let myGiftsFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - myGiftsSize.width) / 2.0), y: contentHeight), size: myGiftsSize)
                if let myGiftsView = self.myGifts.view {
                    if myGiftsView.superview == nil {
                        myGiftsTransition = .immediate
                        
                        self.scrollContentView.addSubview(myGiftsView)
                        
                        if !transition.animation.isImmediate {
                            transition.animateAlpha(view: myGiftsView, from: 0.0, to: 1.0)
                        }
                    }
                    myGiftsTransition.setFrame(view: myGiftsView, frame: myGiftsFrame)
                }
                contentHeight += myGiftsSize.height
                contentHeight += 15.0
            }
            
            if self.backgroundHandleView.image == nil {
                self.backgroundHandleView.image = generateStretchableFilledCircleImage(diameter: 5.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.backgroundHandleView.tintColor = environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(environment.theme.overallDarkAppearance ? 0.2 : 0.07)
            let backgroundHandleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - 36.0) * 0.5), y: 5.0), size: CGSize(width: 36.0, height: 5.0))
            if self.backgroundHandleView.superview == nil {
                self.navigationBarContainer.addSubview(self.backgroundHandleView)
            }
            transition.setFrame(view: self.backgroundHandleView, frame: backgroundHandleFrame)
            
            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: environment.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: rawSideInset + 16.0, y: 16.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let moreButtonSize = self.moreButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: environment.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "info", component: AnyComponent(
                        LottieComponent(
                            content: LottieComponent.AppBundleContent(
                                name: "anim_morewide"
                            ),
                            color: environment.theme.chat.inputPanel.panelControlColor,
                            size: CGSize(width: 34.0, height: 34.0),
                            playOnce: self.moreButtonPlayOnce
                        )
                    )),
                    action: { [weak self] view in
                        guard let self else {
                            return
                        }
                        self.morePressed(view: view, gesture: nil)
                        self.moreButtonPlayOnce.invoke(Void())
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            let infoButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - rawSideInset - 16.0 - moreButtonSize.width, y: 16.0), size: moreButtonSize)
            if let infoButtonView = self.moreButton.view {
                if infoButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(infoButtonView)
                }
                transition.setFrame(view: infoButtonView, frame: infoButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            var initialContentHeight = contentHeight
            let clippingY: CGFloat
            
            let titleString: String
            if isUpcoming {
                titleString = environment.strings.Gift_AuctionBid_UpcomingTitle
            } else {
                titleString = environment.strings.Gift_AuctionBid_Title
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            
            var subtitleString = environment.strings.Gift_AuctionBid_Subtitle("\(giftsPerRound)").string
            if let auctionState = self.giftAuctionState?.auctionState, case let .ongoing(_, _, _, _, _, _, _, _, currentRound, totalRounds, _, _) = auctionState {
                subtitleString = environment.strings.Gift_AuctionBid_RoundSubtitle(
                    presentationStringsFormattedNumber(currentRound, environment.dateTimeFormat.groupingSeparator),
                    presentationStringsFormattedNumber(totalRounds, environment.dateTimeFormat.groupingSeparator),
                ).string
            }
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: isUpcoming ? "" : subtitleString, font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: isUpcoming ? 29.0 : 21.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: 42.0), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.navigationBarContainer.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            
            if let myBidTitleComponent, let myBidComponent {
                let myPeerTitle: ComponentView<Empty>
                let myPeerItem: ComponentView<Empty>
                
                if let currentTitle = self.myPeerTitle, let currentItem = self.myPeerItem {
                    myPeerTitle = currentTitle
                    myPeerItem = currentItem
                } else {
                    myPeerTitle = ComponentView()
                    self.myPeerTitle = myPeerTitle
                    myPeerItem = ComponentView()
                    self.myPeerItem = myPeerItem
                }
                
                let myPeerTitleSize = myPeerTitle.update(
                    transition: .immediate,
                    component: myBidTitleComponent,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                let myPeerTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: myPeerTitleSize)
                if let myPeerTitleView = myPeerTitle.view {
                    if myPeerTitleView.superview == nil {
                        self.scrollContentView.addSubview(myPeerTitleView)
                    }
                    myPeerTitleView.frame = myPeerTitleFrame
                }
                contentHeight += myPeerTitleSize.height
                contentHeight += 7.0
                
                let myPeerItemSize = myPeerItem.update(
                    transition: .immediate,
                    component: myBidComponent,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                let myPeerItemFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: myPeerItemSize)
                if let myPeerItemView = myPeerItem.view {
                    if myPeerItemView.superview == nil {
                        self.scrollContentView.addSubview(myPeerItemView)
                    }
                    myPeerItemView.frame = myPeerItemFrame
                }
                contentHeight += myPeerItemSize.height
                contentHeight += 8.0
            } else if let myPeerTitle = self.myPeerTitle, let myPeerItem = self.myPeerItem {
                self.myPeerTitle = nil
                self.myPeerItem = nil
                
                if let myPeerTitleView = myPeerTitle.view, let myPeerItemView = myPeerItem.view {
                    transition.setAlpha(view: myPeerTitleView, alpha: 0.0, completion: { _ in
                        myPeerTitleView.removeFromSuperview()
                    })
                    transition.setAlpha(view: myPeerItemView, alpha: 0.0, completion: { _ in
                        myPeerItemView.removeFromSuperview()
                    })
                }
            }
            
            if let topBidsTitleComponent {
                let topPeersTitle: ComponentView<Empty>
                if let currentTitle = self.topPeersTitle {
                    topPeersTitle = currentTitle
                } else {
                    topPeersTitle = ComponentView()
                    self.topPeersTitle = topPeersTitle
                }
                
                let topPeersTitleSize = topPeersTitle.update(
                    transition: .immediate,
                    component: topBidsTitleComponent,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                )
                let topPeersTitleFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: topPeersTitleSize)
                if let topPeersTitleView = topPeersTitle.view {
                    if topPeersTitleView.superview == nil {
                        self.scrollContentView.addSubview(topPeersTitleView)
                    }
                    topPeersTitleView.frame = topPeersTitleFrame
                }
                contentHeight += topPeersTitleSize.height
                contentHeight += 7.0
                
                var validKeys: Set<EnginePeer.Id> = Set()
                for (peerId, topBidItemComponent) in topBidsComponents {
                    validKeys.insert(peerId)
                    
                    let topPeerItem: ComponentView<Empty>
                    if let current = self.topPeerItems[peerId] {
                        topPeerItem = current
                    } else {
                        topPeerItem = ComponentView()
                        self.topPeerItems[peerId] = topPeerItem
                    }
                    
                    let topPeerItemSize = topPeerItem.update(
                        transition: .immediate,
                        component: topBidItemComponent,
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: availableSize.height)
                    )
                    let topPeerItemFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: topPeerItemSize)
                    if let topPeerItemView = topPeerItem.view {
                        if topPeerItemView.superview == nil {
                            self.scrollContentView.addSubview(topPeerItemView)
                            transition.animateAlpha(view: topPeerItemView, from: 0.0, to: 1.0)
                        }
                        topPeerItemView.frame = topPeerItemFrame
                    }
                    contentHeight += topPeerItemSize.height
                }
                
                var removeKeys: [EnginePeer.Id] = []
                for (peerId, item) in self.topPeerItems {
                    if !validKeys.contains(peerId) {
                        removeKeys.append(peerId)
                        
                        if let itemView = item.view {
                            transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        }
                    }
                }
                for id in removeKeys {
                    self.topPeerItems.removeValue(forKey: id)
                }
                
                contentHeight += 16.0
            } else if let topPeersTitle = self.topPeersTitle {
                self.topPeersTitle = nil
                if let topPeersTitleView = topPeersTitle.view {
                    transition.setAlpha(view: topPeersTitleView, alpha: 0.0, completion: { _ in
                        topPeersTitleView.removeFromSuperview()
                    })
                }
                for (_, item) in self.topPeerItems {
                    if let itemView = item.view {
                        transition.setAlpha(view: itemView, alpha: 0.0, completion: { _ in
                            itemView.removeFromSuperview()
                        })
                    }
                }
                self.topPeerItems = [:]
            }

            initialContentHeight = contentHeight
            
            if self.cachedStarImage == nil || self.cachedStarImage?.1 !== environment.theme {
                self.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: .white)!, environment.theme)
            }
            
            var formattedAmount = presentationStringsFormattedNumber(Int32(clamping: self.amount.realValue), environment.dateTimeFormat.groupingSeparator)
            let buttonString: String
            let buttonId: String
            if let myBidAmount = self.giftAuctionState?.myState.bidAmount {
                if myBidAmount == self.amount.realValue {
                    buttonString = environment.strings.Common_OK
                    buttonId = "ok"
                } else {
                    formattedAmount = presentationStringsFormattedNumber(Int32(clamping: self.amount.realValue - Int(myBidAmount)), environment.dateTimeFormat.groupingSeparator)
                    buttonString = environment.strings.Gift_AuctionBid_AddToBid(" # \(formattedAmount)").string
                    buttonId = "add"
                }
            } else {
                buttonString = environment.strings.Gift_AuctionBid_PlaceBid(" # \(formattedAmount)").string
                buttonId = "bid"
            }
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.with(size: 17.0, weight: .semibold, traits: .monospacedNumbers), textColor: environment.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = self.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: environment.theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 54.0, sideInset: 32.0)
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 54.0 * 0.5
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(buttonId),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: self.isLoading,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.commitBid(value: Int64(self.amount.realValue))
                    }
                )),
                environment: {},
                containerSize: CGSize(width: fillingSize - buttonInsets.left - buttonInsets.right, height: 54.0)
            )
            
            let edgeEffectHeight: CGFloat = 80.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: CGSize(width: fillingSize, height: edgeEffectHeight))
            transition.setFrame(view: self.topEdgeEffectView, frame: edgeEffectFrame)
            self.topEdgeEffectView.update(content: environment.theme.actionSheet.opaqueItemBackgroundColor, blur: true, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectFrame.height, transition: transition)
            if self.topEdgeEffectView.superview == nil {
                self.navigationBarContainer.insertSubview(self.topEdgeEffectView, at: 0)
            }
            
            var bottomPanelHeight = 13.0 + buttonInsets.bottom + actionButtonSize.height
            
            let bottomEdgeEffectHeight: CGFloat = bottomPanelHeight
            let bottomEdgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: availableSize.height - bottomEdgeEffectHeight), size: CGSize(width: fillingSize, height: bottomEdgeEffectHeight))
            transition.setFrame(view: self.bottomEdgeEffectView, frame: bottomEdgeEffectFrame)
            self.bottomEdgeEffectView.update(content: environment.theme.actionSheet.opaqueItemBackgroundColor, blur: true, alpha: 1.0, rect: bottomEdgeEffectFrame, edge: .bottom, edgeSize: bottomEdgeEffectFrame.height, transition: transition)
            if self.bottomEdgeEffectView.superview == nil {
                self.containerView.addSubview(self.bottomEdgeEffectView)
            }
            
            let actionButtonFrame = CGRect(origin: CGPoint(x: rawSideInset + buttonInsets.left, y: availableSize.height - buttonInsets.bottom - actionButtonSize.height), size: actionButtonSize)
            bottomPanelHeight -= 1.0
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.containerView.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
                        
            contentHeight += bottomPanelHeight
            initialContentHeight += bottomPanelHeight
            
            clippingY = actionButtonFrame.maxY + 24.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 38.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, containerCornerRadius: environment.deviceMetrics.screenCornerRadius, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: fillingSize, height: availableSize.height)))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: availableSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setPosition(view: self.containerView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let bottomInset: CGFloat = contentHeight - 12.0
            
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            }
            
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

public class GiftAuctionBidScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    private var didPlayAppearAnimation: Bool = false
    private var isDismissed: Bool = false
    
    public init(context: AccountContext, toPeerId: EnginePeer.Id, text: String?, entities: [MessageTextEntity]?, hideName: Bool, auctionContext: GiftAuctionContext, acquiredGifts: Signal<[GiftAuctionAcquiredGift], NoError>?) {
        self.context = context
        
        super.init(context: context, component: GiftAuctionBidScreenComponent(
            context: context,
            toPeerId: toPeerId,
            text: text,
            entities: entities,
            hideName: hideName,
            gift: auctionContext.gift,
            auctionContext: auctionContext,
            acquiredGifts: acquiredGifts
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if !self.didPlayAppearAnimation {
            self.didPlayAppearAnimation = true
            
            if let componentView = self.node.hostView.componentView as? GiftAuctionBidScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
        
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            self.dismissAllTooltips()
            
            if let componentView = self.node.hostView.componentView as? GiftAuctionBidScreenComponent.View {
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

private final class BadgeStarsView: UIView {
    private let staticEmitterLayer = CAEmitterLayer()
    private let dynamicEmitterLayer = CAEmitterLayer()
    private var currentColor: UIColor?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.addSublayer(self.staticEmitterLayer)
        self.layer.addSublayer(self.dynamicEmitterLayer)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
        
    private func setupEmitter() {
        guard let currentColor = self.currentColor else {
            return
        }
        let color = currentColor
        
        self.staticEmitterLayer.emitterShape = .circle
        self.staticEmitterLayer.emitterSize = CGSize(width: 10.0, height: 5.0)
        self.staticEmitterLayer.emitterMode = .outline
        self.layer.addSublayer(self.staticEmitterLayer)
        
        self.dynamicEmitterLayer.birthRate = 0.0
        self.dynamicEmitterLayer.emitterShape = .circle
        self.dynamicEmitterLayer.emitterSize = CGSize(width: 10.0, height: 55.0)
        self.dynamicEmitterLayer.emitterMode = .surface
        self.layer.addSublayer(self.dynamicEmitterLayer)
        
        let staticEmitter = CAEmitterCell()
        staticEmitter.name = "emitter"
        staticEmitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        staticEmitter.birthRate = 20.0
        staticEmitter.lifetime = 2.7
        staticEmitter.velocity = 30.0
        staticEmitter.velocityRange = 3
        staticEmitter.scale = 0.15
        staticEmitter.scaleRange = 0.08
        staticEmitter.emissionRange = .pi * 2.0
        staticEmitter.setValue(3.0, forKey: "mass")
        staticEmitter.setValue(2.0, forKey: "massRange")
        
        let dynamicEmitter = CAEmitterCell()
        dynamicEmitter.name = "emitter"
        dynamicEmitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        dynamicEmitter.birthRate = 0.0
        dynamicEmitter.lifetime = 2.7
        dynamicEmitter.velocity = 30.0
        dynamicEmitter.velocityRange = 3
        dynamicEmitter.scale = 0.15
        dynamicEmitter.scaleRange = 0.08
        dynamicEmitter.emissionRange = .pi / 3.0
        dynamicEmitter.setValue(3.0, forKey: "mass")
        dynamicEmitter.setValue(2.0, forKey: "massRange")
        
        let staticColors: [Any] = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.35).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        staticEmitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        
        let dynamicColors: [Any] = [
            UIColor.white.withAlphaComponent(0.35).cgColor,
            color.withAlphaComponent(0.85).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let dynamicColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        dynamicColorBehavior.setValue(dynamicColors, forKey: "colors")
        dynamicEmitter.setValue([dynamicColorBehavior], forKey: "emitterBehaviors")
        
        let attractor = CAEmitterCell.createEmitterBehavior(type: "simpleAttractor")
        attractor.setValue("attractor", forKey: "name")
        attractor.setValue(20, forKey: "falloff")
        attractor.setValue(35, forKey: "radius")
        self.staticEmitterLayer.setValue([attractor], forKey: "emitterBehaviors")
        self.staticEmitterLayer.setValue(4.0, forKeyPath: "emitterBehaviors.attractor.stiffness")
        self.staticEmitterLayer.setValue(false, forKeyPath: "emitterBehaviors.attractor.enabled")
        
        self.staticEmitterLayer.emitterCells = [staticEmitter]
        self.dynamicEmitterLayer.emitterCells = [dynamicEmitter]
    }
    
    func update(speed: Float, delta: Float? = nil) {
        if speed > 0.0 {
            if self.dynamicEmitterLayer.birthRate.isZero {
                self.dynamicEmitterLayer.beginTime = CACurrentMediaTime()
            }
            
            self.dynamicEmitterLayer.setValue(Float(20.0 + speed * 1.4), forKeyPath: "emitterCells.emitter.birthRate")
            self.dynamicEmitterLayer.setValue(2.7 - min(1.1, 1.5 * speed / 120.0), forKeyPath: "emitterCells.emitter.lifetime")
            self.dynamicEmitterLayer.setValue(30.0 + CGFloat(speed / 80.0), forKeyPath: "emitterCells.emitter.velocity")
            
            if let delta, speed > 15.0 {
                self.dynamicEmitterLayer.setValue(delta > 0 ? .pi : 0, forKeyPath: "emitterCells.emitter.emissionLongitude")
                self.dynamicEmitterLayer.setValue(.pi / 2.0, forKeyPath: "emitterCells.emitter.emissionRange")
            } else {
                self.dynamicEmitterLayer.setValue(0.0, forKeyPath: "emitterCells.emitter.emissionLongitude")
                self.dynamicEmitterLayer.setValue(.pi * 2.0, forKeyPath: "emitterCells.emitter.emissionRange")
            }
            self.staticEmitterLayer.setValue(true, forKeyPath: "emitterBehaviors.attractor.enabled")
            
            self.dynamicEmitterLayer.birthRate = 1.0
            self.staticEmitterLayer.birthRate = 0.0
        } else {
            self.dynamicEmitterLayer.birthRate = 0.0
            
            if let staticEmitter = self.staticEmitterLayer.emitterCells?.first {
                staticEmitter.beginTime = CACurrentMediaTime()
            }
            self.staticEmitterLayer.birthRate = 1.0
            self.staticEmitterLayer.setValue(false, forKeyPath: "emitterBehaviors.attractor.enabled")
        }
    }
    
    func update(size: CGSize, color: UIColor, emitterPosition: CGPoint) {
        if self.staticEmitterLayer.emitterCells == nil {
            self.currentColor = color
            self.setupEmitter()
        } else if self.currentColor != color {
            self.currentColor = color
            
            let staticColors: [Any] = [
                UIColor.white.withAlphaComponent(0.0).cgColor,
                UIColor.white.withAlphaComponent(0.35).cgColor,
                color.cgColor,
                color.cgColor,
                color.withAlphaComponent(0.0).cgColor
            ]
            let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
            staticColorBehavior.setValue(staticColors, forKey: "colors")
            
            let dynamicColors: [Any] = [
                UIColor.white.withAlphaComponent(0.35).cgColor,
                color.withAlphaComponent(0.85).cgColor,
                color.cgColor,
                color.cgColor,
                color.withAlphaComponent(0.0).cgColor
            ]
            let dynamicColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
            dynamicColorBehavior.setValue(dynamicColors, forKey: "colors")
            
            for cell in self.staticEmitterLayer.emitterCells ?? [] {
                cell.setValue([staticColorBehavior], forKey: "emitterBehaviors")
            }
            for cell in self.dynamicEmitterLayer.emitterCells ?? [] {
                cell.setValue([dynamicColorBehavior], forKey: "emitterBehaviors")
            }
        }
        
        self.staticEmitterLayer.frame = CGRect(origin: .zero, size: size)
        self.staticEmitterLayer.emitterPosition = emitterPosition
        
        self.dynamicEmitterLayer.frame = CGRect(origin: .zero, size: size)
        self.dynamicEmitterLayer.emitterPosition = emitterPosition
        self.staticEmitterLayer.setValue(emitterPosition, forKeyPath: "emitterBehaviors.attractor.position")
    }
}

private final class SliderStarsView: UIView {
    private let emitterLayer = CAEmitterLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.addSublayer(self.emitterLayer)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
        
    private func setupEmitter() {
        self.emitterLayer.emitterShape = .rectangle
        self.emitterLayer.emitterMode = .surface
        self.layer.addSublayer(self.emitterLayer)
                
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 20.0
        emitter.lifetime = 2.0
        emitter.velocity = 15.0
        emitter.velocityRange = 10
        emitter.scale = 0.15
        emitter.scaleRange = 0.08
        emitter.emissionRange = .pi / 4.0
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        self.emitterLayer.emitterCells = [emitter]
        
        let colors: [Any] = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.38).cgColor,
            UIColor.white.withAlphaComponent(0.38).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.38).cgColor,
            UIColor.white.withAlphaComponent(0.38).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        let colorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        colorBehavior.setValue(colors, forKey: "colors")
        emitter.setValue([colorBehavior], forKey: "emitterBehaviors")
    }

    func update(size: CGSize, value: CGFloat) {
        if self.emitterLayer.emitterCells == nil {
            self.setupEmitter()
        }
        
        self.emitterLayer.setValue(20.0 + Float(value * 200.0), forKeyPath: "emitterCells.emitter.birthRate")
        self.emitterLayer.setValue(15.0 + value * 250.0, forKeyPath: "emitterCells.emitter.velocity")
        
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        self.emitterLayer.emitterSize = size
    }
}

private final class AuctionStatComponent: Component {
    let context: AccountContext
    let gift: StarGift?
    let title: [AnimatedTextComponent.Item]
    let subtitle: String
    let small: Bool
    let theme: PresentationTheme
    
    init(
        context: AccountContext,
        gift: StarGift?,
        title: [AnimatedTextComponent.Item],
        subtitle: String,
        small: Bool,
        theme: PresentationTheme
    ) {
        self.context = context
        self.gift = gift
        self.title = title
        self.subtitle = subtitle
        self.small = small
        self.theme = theme
    }
    
    static func ==(lhs: AuctionStatComponent, rhs: AuctionStatComponent) -> Bool {
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.small != rhs.small {
            return false
        }
        if lhs.theme != rhs.theme {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let gift = ComponentView<Empty>()
        let background = ComponentView<Empty>()
        let title = ComponentView<Empty>()
        let subtitle = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AuctionStatComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let backgroundFrame = CGRect(origin: CGPoint(), size: availableSize)
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: UIColor(rgb: 0x808084, alpha: 0.1),
                    cornerRadius: .value(12.0),
                    smoothCorners: true
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            var titleTotalWidth: CGFloat = 0.0
            let titleSize = self.title.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: component.small ? 17.0 : 20.0, weight: .semibold, traits: .monospacedNumbers),
                    color: component.theme.list.itemPrimaryTextColor,
                    items: component.title,
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            titleTotalWidth += titleSize.width
            
            var giftSize = CGSize()
            if let gift = component.gift, case let .generic(gift) = gift {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                giftSize = self.gift.update(
                    transition: .immediate,
                    component: AnyComponent(
                        GiftItemComponent(
                            context: component.context,
                            theme: presentationData.theme,
                            strings: presentationData.strings,
                            peer: nil,
                            subject: .starGift(gift: gift, price: ""),
                            mode: .buttonIcon
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                titleTotalWidth += giftSize.width
                titleTotalWidth += 4.0
            }

            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.subtitle, font: Font.regular(11.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            
            let spacing: CGFloat = 2.0
            
            let giftFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - titleTotalWidth) * 0.5), y: floor((backgroundFrame.height - giftSize.height - spacing - subtitleSize.height) * 0.5)), size: giftSize)
            let titleFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width + titleTotalWidth) * 0.5) - titleSize.width, y: floor((backgroundFrame.height - titleSize.height - spacing - subtitleSize.height) * 0.5)), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - subtitleSize.width) * 0.5), y: titleFrame.maxY + spacing), size: subtitleSize)
            
            if let giftView = self.gift.view {
                if giftView.superview == nil {
                    self.addSubview(giftView)
                }
                giftView.frame = giftFrame
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                subtitleView.frame = subtitleFrame
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class GiftViewContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class PeerHeaderComponent: CombinedComponent {
    let color: UIColor
    let dateTimeFormat: PresentationDateTimeFormat
    let title: String
    let giftTitle: String?
    let giftNumber: Int32?
    
    public init(
        color: UIColor,
        dateTimeFormat: PresentationDateTimeFormat,
        title: String,
        giftTitle: String?,
        giftNumber: Int32?
    ) {
        self.color = color
        self.dateTimeFormat = dateTimeFormat
        self.title = title
        self.giftTitle = giftTitle
        self.giftNumber = giftNumber
    }
    
    static func ==(lhs: PeerHeaderComponent, rhs: PeerHeaderComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.giftTitle != rhs.giftTitle {
            return false
        }
        if lhs.giftNumber != rhs.giftNumber {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        
        let background = Child(RoundedRectangle.self)
        let giftTitle = Child(MultilineTextComponent.self)
        
        return { context in
            let component = context.component
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title.uppercased(), font: Font.medium(13.0), textColor: component.color))
                ),
                availableSize: CGSize(width: context.availableSize.width - 16.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: title.size.width / 2.0, y: title.size.height / 2.0))
            )
            
            var contentSize = title.size
            if let titleString = component.giftTitle, let giftNumber = component.giftNumber {
                let giftTitle = giftTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(titleString) #\(formatCollectibleNumber(giftNumber, dateTimeFormat: component.dateTimeFormat))", font: Font.regular(12.0), textColor: component.color))
                    ),
                    availableSize: CGSize(width: context.availableSize.width - 16.0, height: context.availableSize.height),
                    transition: .immediate
                )
                
                let spacing: CGFloat = 6.0
                let padding: CGFloat = 5.0
                let backgroundSize = CGSize(width: giftTitle.size.width + padding * 2.0, height: giftTitle.size.height + 4.0)
                let background = background.update(
                    component: RoundedRectangle(
                        color: component.color.withAlphaComponent(0.1),
                        cornerRadius: backgroundSize.height / 2.0
                    ),
                    availableSize: backgroundSize,
                    transition: .immediate
                )
                context.add(background
                    .position(CGPoint(x: title.size.width + spacing + padding + giftTitle.size.width / 2.0, y: title.size.height / 2.0))
                    .appear(.default())
                    .disappear(.default())
                )

                context.add(giftTitle
                    .position(CGPoint(x: title.size.width + spacing + padding + giftTitle.size.width / 2.0, y: title.size.height / 2.0))
                    .appear(.default())
                    .disappear(.default())
                )
                
                contentSize.width += spacing + backgroundSize.width
            }
 
            return contentSize
        }
    }
}
