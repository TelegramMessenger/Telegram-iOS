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
import EmojiStatusComponent
import SliderComponent
import RoundedRectWithTailPath
import AvatarNode
import BundleIconComponent
import CheckNode
import TextFormat
import CheckComponent
import ContextUI
import StarsBalanceOverlayComponent
import TelegramStringFormatting
import ChatScheduleTimeController

private final class BalanceComponent: CombinedComponent {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let balance: StarsAmount?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        balance: StarsAmount?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.balance = balance
    }
    
    static func ==(lhs: BalanceComponent, rhs: BalanceComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.balance != rhs.balance {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let balance = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            var size = CGSize(width: 0.0, height: 0.0)
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: context.component.strings.SendStarReactions_Balance, font: Font.regular(14.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            size.width = max(size.width, title.size.width)
            size.height += title.size.height
            
            let balanceText: String
            if let value = context.component.balance {
                balanceText = "\(value.stringValue)"
            } else {
                balanceText = "..."
            }
            let balance = balance.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: balanceText, font: Font.medium(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let iconSize = CGSize(width: 18.0, height: 18.0)
            let icon = icon.update(
                component: BundleIconComponent(
                    name: "Premium/Stars/StarLarge",
                    tintColor: nil
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let titleSpacing: CGFloat = 1.0
            let iconSpacing: CGFloat = 2.0
            
            size.height += titleSpacing
            
            size.width = max(size.width, icon.size.width + iconSpacing + balance.size.width)
            size.height += balance.size.height
            
            context.add(
                title.position(
                    title.size.centered(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: title.size)).center
                )
            )
            context.add(
                balance.position(
                    balance.size.centered(in: CGRect(origin: CGPoint(x: icon.size.width + iconSpacing, y: title.size.height + titleSpacing), size: balance.size)).center
                )
            )
            context.add(
                icon.position(
                    icon.size.centered(in: CGRect(origin: CGPoint(x: -1.0, y: title.size.height + titleSpacing), size: icon.size)).center
                )
            )

            return size
        }
    }
}

private final class BadgeComponent: Component {
    let theme: PresentationTheme
    let title: String
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: BadgeComponent, rhs: BadgeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let badgeView: UIView
        private let badgeMaskView: UIView
        private let badgeShapeLayer = SimpleShapeLayer()
        
        private let badgeForeground: SimpleLayer
        let badgeIcon: UIImageView
        private let badgeLabel: BadgeLabelView
        private let badgeLabelMaskView = UIImageView()
        
        private var badgeTailPosition: CGFloat = 0.0
        private var badgeShapeArguments: (Double, Double, CGSize, CGFloat, CGFloat)?
        
        private var component: BadgeComponent?
        private var isUpdating: Bool = false
        
        private var previousAvailableSize: CGSize?
        
        override init(frame: CGRect) {
            self.badgeView = UIView()
            self.badgeView.alpha = 0.0
            
            self.badgeShapeLayer.fillColor = UIColor.white.cgColor
            self.badgeShapeLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            
            self.badgeMaskView = UIView()
            self.badgeMaskView.layer.addSublayer(self.badgeShapeLayer)
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
             
            self.component = component
            self.badgeIcon.tintColor = .white
            
            self.badgeLabel.color = .white
                
            let badgeLabelSize = self.badgeLabel.update(value: component.title, transition: .easeInOut(duration: 0.12))
            let countWidth: CGFloat = badgeLabelSize.width + 3.0
            let badgeWidth: CGFloat = countWidth + 54.0
            
            let badgeSize = CGSize(width: badgeWidth, height: 48.0)
            let badgeFullSize = CGSize(width: badgeWidth, height: 48.0 + 12.0)
            self.badgeMaskView.frame = CGRect(origin: .zero, size: badgeFullSize)
            self.badgeShapeLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -4.0), size: badgeFullSize)
            
            self.badgeView.bounds = CGRect(origin: .zero, size: badgeFullSize)
            
            self.badgeForeground.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 600.0, height: badgeFullSize.height + 10.0))
    
            self.badgeIcon.frame = CGRect(x: 10.0, y: 9.0, width: 30.0, height: 30.0)
            self.badgeLabelMaskView.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 36.0)
            
            self.badgeView.alpha = 1.0
            
            let size = badgeSize
            transition.setFrame(view: self.badgeLabel, frame: CGRect(origin: CGPoint(x: 14.0 + floorToScreenPixels((badgeFullSize.width - badgeLabelSize.width) / 2.0), y: 5.0), size: badgeLabelSize))
            
            if self.previousAvailableSize != availableSize {
                self.previousAvailableSize = availableSize
                
                let activeColors: [UIColor] = [
                    UIColor(rgb: 0xFFAB03),
                    UIColor(rgb: 0xFFCB37)
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
        
        func adjustTail(size: CGSize, overflowWidth: CGFloat) {
            var tailPosition = size.width * 0.5
            tailPosition += overflowWidth
            tailPosition = max(0.0, min(size.width, tailPosition))
            
            let tailPositionFraction = tailPosition / size.width
            self.badgeShapeLayer.path = generateRoundedRectWithTailPath(rectSize: size, tailPosition: tailPositionFraction).cgPath
            
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateAnchorPoint(layer: self.badgeView.layer, anchorPoint: CGPoint(x: tailPositionFraction, y: 1.0))
            transition.updatePosition(layer: self.badgeView.layer, position: CGPoint(x: (tailPositionFraction - 0.5) * size.width, y: 0.0))
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

private final class PeerBadgeComponent: Component {
    let theme: PresentationTheme
    let title: String
    
    init(
        theme: PresentationTheme,
        title: String
    ) {
        self.theme = theme
        self.title = title
    }
    
    static func ==(lhs: PeerBadgeComponent, rhs: PeerBadgeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let backgroundMaskLayer = SimpleLayer()
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()

        private var component: PeerBadgeComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundMaskLayer)
            self.layer.addSublayer(self.backgroundLayer)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: PeerBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: "Premium/SendStarsPeerBadgeStarIcon",
                    tintColor: .white)
                ),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            let sideInset: CGFloat = 3.0
            let titleSpacing: CGFloat = 1.0
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.bold(9.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - titleSpacing - iconSize.width, height: 100.0)
            )
            
            let contentSize = CGSize(width: iconSize.width + titleSpacing + titleSize.width, height: titleSize.height)
            let size = CGSize(width: contentSize.width + sideInset * 2.0, height: contentSize.height + 3.0 * 2.0)
            
            self.backgroundMaskLayer.backgroundColor = component.theme.list.plainBackgroundColor.cgColor
            self.backgroundLayer.backgroundColor = UIColor(rgb: 0xFFB10D).cgColor
            
            let backgroundFrame = CGRect(origin: CGPoint(), size: size)
            self.backgroundLayer.frame = backgroundFrame
            
            let badkgroundMaskFrame = backgroundFrame.insetBy(dx: -1.0 - UIScreenPixel, dy: -1.0 - UIScreenPixel)
            self.backgroundMaskLayer.frame = badkgroundMaskFrame
            
            self.backgroundLayer.cornerRadius = backgroundFrame.height * 0.5
            self.backgroundMaskLayer.cornerRadius = badkgroundMaskFrame.height * 0.5
            
            let titleFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + sideInset + iconSize.width + titleSpacing, y: floor((backgroundFrame.height - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + sideInset + 1.0, y: floor((backgroundFrame.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.frame = iconFrame
            }
            
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

private final class PeerComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer?
    let count: String
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer?,
        count: String
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.count = count
    }
    
    static func ==(lhs: PeerComponent, rhs: PeerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var avatarNode: AvatarNode?
        private let badge = ComponentView<Empty>()
        private let title = ComponentView<Empty>()

        private var component: PeerComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: PeerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 24.0))
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarSize = CGSize(width: 60.0, height: 60.0)
            let avatarFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: avatarSize)
            avatarNode.frame = avatarFrame
            if let peer = component.peer {
                avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, synchronousLoad: true)
            } else {
                avatarNode.setPeer(context: component.context, theme: component.theme, peer: nil, overrideImage: .anonymousSavedMessagesIcon(isColored: false), synchronousLoad: true)
            }
            avatarNode.updateSize(size: avatarFrame.size)
            
            let badgeSize = self.badge.update(
                transition: .immediate,
                component: AnyComponent(PeerBadgeComponent(
                    theme: component.theme,
                    title: component.count
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 200.0)
            )
            let badgeFrame = CGRect(origin: CGPoint(x: avatarFrame.minX + floor((avatarFrame.width - badgeSize.width) * 0.5), y: avatarFrame.maxY - badgeSize.height + 3.0), size: badgeSize)
            if let badgeView = self.badge.view {
                if badgeView.superview == nil {
                    self.addSubview(badgeView)
                }
                badgeView.frame = badgeFrame
            }
            
            let titleSpacing: CGFloat = 8.0
            
            let peerTitle: String
            if let peer = component.peer {
                peerTitle = peer.compactDisplayTitle
            } else {
                peerTitle = component.strings.SendStarReactions_UserLabelAnonymous
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: peerTitle, font: Font.regular(11.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: avatarSize.width + 10.0 * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((avatarSize.width - titleSize.width) * 0.5), y: avatarSize.height + titleSpacing), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                titleView.frame = titleFrame
            }
            
            return CGSize(width: avatarSize.width, height: avatarSize.height + titleSpacing + titleSize.height)
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
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        value: CGFloat,
        topCutoff: CGFloat?
    ) {
        self.theme = theme
        self.strings = strings
        self.value = value
        self.topCutoff = topCutoff
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
            self.sliderForeground.backgroundColor = UIColor(rgb: 0xFFB10D)
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
            /*if transition.userData(ChatSendStarsScreenComponent.IsAdjustingAmountHint.self) != nil {
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
                    text: .plain(NSAttributedString(string: component.strings.SendStarReactions_SliderTop, font: Font.semibold(15.0), textColor: UIColor(white: 1.0, alpha: 0.4)))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let _ = self.topBackgroundText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.strings.SendStarReactions_SliderTop, font: Font.semibold(15.0), textColor: component.theme.overallDarkAppearance ? UIColor(white: 1.0, alpha: 0.22) : UIColor(white: 0.0, alpha: 0.2)))
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
                if transition.userData(ChatSendStarsScreenComponent.IsAdjustingAmountHint.self) != nil {
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
                
                topForegroundTextView.isHidden = component.topCutoff == nil || topLineFrame.maxX + topTextSize.width + 20.0 > availableSize.width
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

private final class ChatSendStarsScreenComponent: Component {
    final class IsAdjustingAmountHint {
    }
    
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialData: ChatSendStarsScreen.InitialData
    
    init(
        context: AccountContext,
        initialData: ChatSendStarsScreen.InitialData
    ) {
        self.context = context
        self.initialData = initialData
    }
    
    static func ==(lhs: ChatSendStarsScreenComponent, rhs: ChatSendStarsScreenComponent) -> Bool {
        return true
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
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    private struct Amount: Equatable {
        private let sliderSteps: [Int]
        private let maxRealValue: Int
        let maxSliderValue: Int
        private let isLogarithmic: Bool
        
        private(set) var realValue: Int
        private(set) var sliderValue: Int
        
        private static func makeSliderSteps(maxRealValue: Int, isLogarithmic: Bool) -> [Int] {
            if isLogarithmic {
                var sliderSteps: [Int] = [ 1, 10, 50, 100, 500, 1_000, 2_000, 5_000, 7_500, 10_000 ]
                sliderSteps.removeAll(where: { $0 >= maxRealValue })
                sliderSteps.append(maxRealValue)
                return sliderSteps
            } else {
                return [1, maxRealValue]
            }
        }
        
        private static func remapValueToSlider(realValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
            guard realValue >= steps.first!, realValue <= steps.last! else { return 0 }

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

        private static func remapSliderToValue(sliderValue: Int, maxSliderValue: Int, steps: [Int]) -> Int {
            guard sliderValue >= 0, sliderValue <= maxSliderValue else { return steps.first! }

            let stepIndex = Int(Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1))
            let fraction = Float(sliderValue) / Float(maxSliderValue) * Float(steps.count - 1) - Float(stepIndex)
            
            if stepIndex >= steps.count - 1 {
                return steps.last!
            } else {
                let range = steps[stepIndex + 1] - steps[stepIndex]
                return steps[stepIndex] + Int(fraction * Float(range))
            }
        }
        
        init(realValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
            self.sliderSteps = Amount.makeSliderSteps(maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
            self.maxRealValue = maxRealValue
            self.maxSliderValue = maxSliderValue
            self.isLogarithmic = isLogarithmic
            
            self.realValue = realValue
            self.sliderValue = Amount.remapValueToSlider(realValue: self.realValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
        }
        
        init(sliderValue: Int, maxRealValue: Int, maxSliderValue: Int, isLogarithmic: Bool) {
            self.sliderSteps = Amount.makeSliderSteps(maxRealValue: maxRealValue, isLogarithmic: isLogarithmic)
            self.maxRealValue = maxRealValue
            self.maxSliderValue = maxSliderValue
            self.isLogarithmic = isLogarithmic
            
            self.sliderValue = sliderValue
            self.realValue = Amount.remapSliderToValue(sliderValue: self.sliderValue, maxSliderValue: self.maxSliderValue, steps: self.sliderSteps)
        }
        
        func withRealValue(_ realValue: Int) -> Amount {
            return Amount(realValue: realValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
        
        func withSliderValue(_ sliderValue: Int) -> Amount {
            return Amount(sliderValue: sliderValue, maxRealValue: self.maxRealValue, maxSliderValue: self.maxSliderValue, isLogarithmic: self.isLogarithmic)
        }
    }
    
    enum PrivacyPeer: Equatable {
        case account
        case anonymous
        case peer(EnginePeer)
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        private let hierarchyTrackingNode: HierarchyTrackingNode
        
        private var balanceOverlay = ComponentView<Empty>()
        
        private let leftButton = ComponentView<Empty>()
        private let peerSelectorButton = ComponentView<Empty>()
        private let closeButton = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let timeSelectorButton = ComponentView<Empty>()
        
        private let badgeStars = BadgeStarsView()
        private let sliderBackground = ComponentView<Empty>()
        private let slider = ComponentView<Empty>()
        private let badge = ComponentView<Empty>()
        
        private var topPeersLeftSeparator: SimpleLayer?
        private var topPeersRightSeparator: SimpleLayer?
        private var topPeersTitleBackground: SimpleLayer?
        private var topPeersTitle: ComponentView<Empty>?
        
        private var anonymousSeparator = SimpleLayer()
        private var anonymousContents = ComponentView<Empty>()
        
        private var topPeerItems: [ChatSendStarsScreen.TopPeer.Id: ComponentView<Empty>] = [:]
        
        private let actionButton = ComponentView<Empty>()
        private let buttonDescriptionText = ComponentView<Empty>()
        
        private let bottomOverscrollLimit: CGFloat
        
        private var ignoreScrolling: Bool = false
        
        private var component: ChatSendStarsScreenComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var balance: StarsAmount?
        
        private var amount: Amount = Amount(realValue: 1, maxRealValue: 1000, maxSliderValue: 1000, isLogarithmic: true)
        private var didChangeAmount: Bool = false
        
        private var privacyPeer: PrivacyPeer = .account
        private var cachedStarImage: (UIImage, PresentationTheme)?
        private var cachedCloseImage: UIImage?
        
        private var isPastTopCutoff: Bool?
        
        private var balanceDisposable: Disposable?
        
        private var badgePhysicsLink: SharedDisplayLinkDriver.Link?
        
        private var currentMyPeer: EnginePeer?
        private var channelsForPublicReaction: [EnginePeer] = []
        private var channelsForPublicReactionDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.hierarchyTrackingNode = HierarchyTrackingNode()
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
                        
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
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.addSubview(self.navigationBarContainer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.addSubnode(self.hierarchyTrackingNode)
            
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
            self.channelsForPublicReactionDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            
            if topOffset < topOffsetDistance {
                targetContentOffset.pointee.y = scrollView.contentOffset.y
                scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
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
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(60.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
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
            if let buttonDescriptionTextView = self.buttonDescriptionText.view {
                buttonDescriptionTextView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
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
            if let buttonDescriptionTextView = self.buttonDescriptionText.view {
                buttonDescriptionTextView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
            
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
        
        private func displayTargetSelectionMenu(sourceView: UIView) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            guard case let .react(reactData) = component.initialData.subjectInitialData else {
                return
            }
            
            var items: [ContextMenuItem] = []
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
            
            var peers: [EnginePeer] = [reactData.myPeer]
            peers.append(contentsOf: self.channelsForPublicReaction)
            
            let avatarSize = CGSize(width: 30.0, height: 30.0)
            
            for peer in peers {
                let peerLabel: String
                if peer.id == component.context.account.peerId {
                    peerLabel = environment.strings.AffiliateProgram_PeerTypeSelf
                } else if case .channel = peer {
                    peerLabel = environment.strings.Channel_Status
                } else {
                    peerLabel = environment.strings.Bot_GenericBotStatus
                }
                let isSelected = peer.id == self.currentMyPeer?.id
                let accentColor = environment.theme.list.itemAccentColor
                let avatarSignal = peerAvatarCompleteImage(account: component.context.account, peer: peer, size: avatarSize)
                |> map { image in
                    let context = DrawingContext(size: avatarSize, scale: 0.0, clear: true)
                    context?.withContext { c in
                        UIGraphicsPushContext(c)
                        defer {
                            UIGraphicsPopContext()
                        }
                        if isSelected {
                            
                        }
                        c.saveGState()
                        let scaleFactor = (avatarSize.width - 3.0 * 2.0) / avatarSize.width
                        if isSelected {
                            c.translateBy(x: avatarSize.width * 0.5, y: avatarSize.height * 0.5)
                            c.scaleBy(x: scaleFactor, y: scaleFactor)
                            c.translateBy(x: -avatarSize.width * 0.5, y: -avatarSize.height * 0.5)
                        }
                        if let image {
                            image.draw(in: CGRect(origin: CGPoint(), size: avatarSize))
                        }
                        c.restoreGState()
                        
                        if isSelected {
                            c.setStrokeColor(accentColor.cgColor)
                            let lineWidth: CGFloat = 1.0 + UIScreenPixel
                            c.setLineWidth(lineWidth)
                            c.strokeEllipse(in: CGRect(origin: CGPoint(), size: avatarSize).insetBy(dx: lineWidth * 0.5, dy: lineWidth * 0.5))
                        }
                    }
                    return context?.generateImage()
                }
                items.append(.action(ContextMenuActionItem(text: peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder), textLayout: .secondLineWithValue(peerLabel), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: avatarSignal), action: { [weak self] c, _ in
                    c?.dismiss(completion: {})
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    guard case let .react(reactData) = component.initialData.subjectInitialData else {
                        return
                    }
                    if self.currentMyPeer?.id == peer.id {
                        return
                    }
                    
                    if self.currentMyPeer != peer {
                        self.currentMyPeer = peer
                        
                        if peer.id == component.context.account.peerId {
                            self.privacyPeer = .account
                        } else {
                            self.privacyPeer = .peer(peer)
                        }
                        
                        if reactData.myTopPeer != nil {
                            let mappedPrivacy: TelegramPaidReactionPrivacy
                            switch self.privacyPeer {
                            case .account:
                                mappedPrivacy = .default
                            case .anonymous:
                                mappedPrivacy = .anonymous
                            case let .peer(peer):
                                mappedPrivacy = .peer(peer.id)
                            }
                            
                            let _ = component.context.engine.messages.updateStarsReactionPrivacy(id: reactData.messageId, privacy: mappedPrivacy).startStandalone()
                        }
                    }
                    
                    self.state?.updated(transition: .immediate)
                })))
            }
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, actionsOnTop: false)), items: .single(ContextController.Items(id: AnyHashable(0), content: .list(items))), gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
        
        func update(component: ChatSendStarsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
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
                fillingSize = min(availableSize.width, 428.0) - environment.safeInsets.left * 2.0
            }
            let sideInset: CGFloat = floor((availableSize.width - fillingSize) * 0.5) + 16.0
            
            let context = component.context
            let balanceSize = self.balanceOverlay.update(
                transition: .immediate,
                component: AnyComponent(
                    StarsBalanceOverlayComponent(
                        context: component.context,
                        peerId: component.context.account.peerId,
                        theme: environment.theme,
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
                self.balance = component.initialData.balance
                
                switch component.initialData.subjectInitialData {
                case let .react(reactData):
                    self.currentMyPeer = reactData.myPeer
                    self.amount = Amount(realValue: 50, maxRealValue: reactData.maxAmount, maxSliderValue: 999, isLogarithmic: true)
                    
                    if let myTopPeer = reactData.myTopPeer {
                        if myTopPeer.isAnonymous {
                            self.privacyPeer = .anonymous
                        } else if myTopPeer.peer?.id == component.context.account.peerId {
                            self.privacyPeer = .account
                        } else if let peer = myTopPeer.peer {
                            self.privacyPeer = .peer(peer)
                            self.currentMyPeer = peer
                        } else {
                            self.privacyPeer = .account
                        }
                    } else {
                        self.privacyPeer = reactData.defaultPrivacyPeer
                        switch self.privacyPeer {
                        case .anonymous, .account:
                            break
                        case let .peer(peer):
                            self.currentMyPeer = peer
                        }
                    }
                    
                    self.channelsForPublicReactionDisposable = (component.context.engine.peers.channelsForPublicReaction(useLocalCache: false)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                        guard let self else {
                            return
                        }
                        if self.channelsForPublicReaction != peers {
                            self.channelsForPublicReaction = peers
                            if !self.isUpdating {
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    })
                }
                
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
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.list.plainBackgroundColor.cgColor
                
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 6
                for i in 0 ..< numStops {
                    let step = CGFloat(i) / CGFloat(numStops - 1)
                    locations.append(step as NSNumber)
                    colors.append(environment.theme.list.blocksBackgroundColor.withAlphaComponent(1.0 - step * step).cgColor)
                }
            }
            
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
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            let maxAmount: Int
                            switch component.initialData.subjectInitialData {
                            case let .react(reactData):
                                maxAmount = reactData.maxAmount
                            }
                            
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
            let sliderFrame = CGRect(origin: CGPoint(x: sliderInset, y: contentHeight + 127.0), size: sliderSize)
            let sliderBackgroundFrame = CGRect(origin: CGPoint(x: sliderFrame.minX - 8.0, y: sliderFrame.minY + 7.0), size: CGSize(width: sliderFrame.width + 16.0, height: sliderFrame.height - 14.0))
            
            let progressFraction: CGFloat = CGFloat(self.amount.sliderValue) / CGFloat(self.amount.maxSliderValue)
            
            var topCutoffFraction: CGFloat?
            
            var topCount: Int?
            switch component.initialData.subjectInitialData {
            case let .react(reactData):
                let topOthersCount: Int? = reactData.topPeers.filter({ !$0.isMy }).max(by: { $0.count < $1.count })?.count
                if let topOthersCount {
                    if let myTopPeer = reactData.myTopPeer {
                        topCount = max(0, topOthersCount - myTopPeer.count + 1)
                    } else {
                        topCount = topOthersCount
                    }
                    if topCount == 0 {
                        topCount = nil
                    }
                }
                
                if let topCount {
                    let topCutoffFractionValue = CGFloat(topCount) / CGFloat(reactData.maxAmount - 1)
                    topCutoffFraction = topCutoffFractionValue
                    
                    let isPastCutoff = progressFraction >= topCutoffFractionValue
                    if let isPastTopCutoff = self.isPastTopCutoff, isPastTopCutoff != isPastCutoff {
                        HapticFeedback().tap()
                    }
                    self.isPastTopCutoff = isPastCutoff
                } else {
                    self.isPastTopCutoff = nil
                }
            }
            
            let _ = self.sliderBackground.update(
                transition: transition,
                component: AnyComponent(SliderBackgroundComponent(
                    theme: environment.theme,
                    strings: environment.strings,
                    value: progressFraction,
                    topCutoff: topCutoffFraction
                )),
                environment: {},
                containerSize: sliderBackgroundFrame.size
            )
            
            if let sliderView = self.slider.view, let sliderBackgroundView = self.sliderBackground.view {
                if sliderView.superview == nil {
                    self.scrollContentView.addSubview(self.badgeStars)
                    self.scrollContentView.addSubview(sliderBackgroundView)
                    self.scrollContentView.addSubview(sliderView)
                }
                transition.setFrame(view: sliderView, frame: sliderFrame)
                
                transition.setFrame(view: sliderBackgroundView, frame: sliderBackgroundFrame)
                
                let badgeSize = self.badge.update(
                    transition: transition,
                    component: AnyComponent(BadgeComponent(
                        theme: environment.theme,
                        title: "\(self.amount.realValue)"
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 200.0)
                )
                
                let sliderMinWidth = sliderBackgroundFrame.height
                let sliderAreaWidth: CGFloat = sliderBackgroundFrame.width - sliderMinWidth
                let sliderForegroundFrame = CGRect(origin: sliderBackgroundFrame.origin, size: CGSize(width: sliderMinWidth + floorToScreenPixels(sliderAreaWidth * progressFraction), height: sliderBackgroundFrame.height))
                
                var badgeFrame = CGRect(origin: CGPoint(x: sliderForegroundFrame.minX + sliderForegroundFrame.width - floorToScreenPixels(sliderMinWidth * 0.5), y: sliderForegroundFrame.minY - 8.0), size: badgeSize)
                if let badgeView = self.badge.view as? BadgeComponent.View {
                    if badgeView.superview == nil {
                        self.scrollContentView.insertSubview(badgeView, belowSubview: self.badgeStars)
                    }
                    
                    let badgeSideInset = sideInset + 15.0
                    
                    let badgeOverflowWidth: CGFloat
                    if badgeFrame.minX - badgeSize.width * 0.5 < badgeSideInset {
                        badgeOverflowWidth = badgeSideInset - (badgeFrame.minX - badgeSize.width * 0.5)
                    } else if badgeFrame.minX + badgeSize.width * 0.5 > availableSize.width - badgeSideInset {
                        badgeOverflowWidth = availableSize.width - badgeSideInset - (badgeFrame.minX + badgeSize.width * 0.5)
                    } else {
                        badgeOverflowWidth = 0.0
                    }
                    
                    badgeFrame.origin.x += badgeOverflowWidth
                    
                    badgeView.frame = badgeFrame
                    
                    badgeView.adjustTail(size: badgeSize, overflowWidth: -badgeOverflowWidth)
                }
                
                let starsRect = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: sliderForegroundFrame.midY))
                self.badgeStars.frame = starsRect
                self.badgeStars.update(size: starsRect.size, emitterPosition: CGPoint(x: badgeFrame.minX, y: badgeFrame.midY - 64.0))
            }
            
            contentHeight += 123.0
            
            var leftButtonFrameValue: CGRect?
            switch component.initialData.subjectInitialData {
            case let .react(reactData):
                var sendAsPeers: [EnginePeer] = [reactData.myPeer]
                sendAsPeers.append(contentsOf: self.channelsForPublicReaction)
                
                let leftButtonSize = self.leftButton.update(
                    transition: transition,
                    component: AnyComponent(BalanceComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        balance: self.balance
                    )),
                    environment: {},
                    containerSize: CGSize(width: 120.0, height: 100.0)
                )
                let leftButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((56.0 - leftButtonSize.height) * 0.5)), size: leftButtonSize)
                if let leftButtonView = self.leftButton.view {
                    if leftButtonView.superview == nil {
                        self.navigationBarContainer.addSubview(leftButtonView)
                    }
                    transition.setFrame(view: leftButtonView, frame: leftButtonFrame)
                    leftButtonView.isHidden = sendAsPeers.count > 1
                }
                leftButtonFrameValue = leftButtonFrame
                
                let currentMyPeer = self.currentMyPeer ?? reactData.myPeer
                
                let peerSelectorButtonSize = self.peerSelectorButton.update(
                    transition: transition,
                    component: AnyComponent(PeerSelectorBadgeComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        peer: currentMyPeer,
                        action: { [weak self] sourceView in
                            guard let self else {
                                return
                            }
                            self.displayTargetSelectionMenu(sourceView: sourceView)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 120.0, height: 100.0)
                )
                let peerSelectorButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: 1.0 + floor((56.0 - peerSelectorButtonSize.height) * 0.5)), size: peerSelectorButtonSize)
                if let peerSelectorButtonView = self.peerSelectorButton.view {
                    if peerSelectorButtonView.superview == nil {
                        self.navigationBarContainer.addSubview(peerSelectorButtonView)
                    }
                    transition.setFrame(view: peerSelectorButtonView, frame: peerSelectorButtonFrame)
                    peerSelectorButtonView.isHidden = sendAsPeers.count <= 1
                }
            }
            
            if themeUpdated {
                self.cachedCloseImage = nil
            }
            let closeImage: UIImage
            if let current = self.cachedCloseImage {
                closeImage = current
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: environment.theme.actionSheet.inputClearButtonColor)!
                self.cachedCloseImage = closeImage
            }
            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(Image(image: closeImage)),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - closeButtonSize.width, y: floor((56.0 - 34.0) * 0.5)), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            
            var initialContentHeight = contentHeight
            let clippingY: CGFloat
            
            let title = self.title
            let descriptionText = self.descriptionText
            let actionButton = self.actionButton
            
            let titleSubtitleSpacing: CGFloat = 1.0
            
            let subtitleText: String?
            switch component.initialData.subjectInitialData {
            case let .react(reactData):
                let currentMyPeer = self.currentMyPeer ?? reactData.myPeer
                subtitleText = environment.strings.SendStarReactions_SubtitleFrom(currentMyPeer.compactDisplayTitle).string
            }
            
            var subtitleSize: CGSize?
            if let subtitleText {
                subtitleSize = self.subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: subtitleText, font: Font.regular(12.0), textColor: environment.theme.list.itemSecondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - (leftButtonFrameValue?.maxX ?? sideInset) * 2.0, height: 100.0)
                )
            }
            
            let titleText: String
            switch component.initialData.subjectInitialData {
            case .react:
                titleText = environment.strings.SendStarReactions_Title
            }
            
            let titleSize = title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - (leftButtonFrameValue?.maxX ?? sideInset) * 2.0, height: 100.0)
            )
            
            let titleSubtitleHeight: CGFloat
            if let subtitleSize {
                titleSubtitleHeight = titleSize.height + titleSubtitleSpacing + subtitleSize.height
            } else {
                titleSubtitleHeight = titleSize.height
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((56.0 - titleSubtitleHeight) * 0.5)), size: titleSize)
            if let titleView = title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            if let subtitleSize {
                let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleSize)
                if let subtitleView = self.subtitle.view {
                    if subtitleView.superview == nil {
                        self.navigationBarContainer.addSubview(subtitleView)
                    }
                    transition.setFrame(view: subtitleView, frame: subtitleFrame)
                }
            }
            
            contentHeight += 56.0
            contentHeight += 8.0
            
            let text: String
            switch component.initialData.subjectInitialData {
            case let .react(reactData):
                if let currentSentAmount = reactData.currentSentAmount {
                    text = environment.strings.SendStarReactions_TextSentStars(Int32(currentSentAmount))
                } else {
                    text = environment.strings.SendStarReactions_TextGeneric(reactData.peer.debugDisplayTitle).string
                }
            }
            
            let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.itemPrimaryTextColor)
            
            let descriptionTextSize = descriptionText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: text, attributes: MarkdownAttributes(
                        body: body,
                        bold: bold,
                        link: body,
                        linkAttribute: { _ in nil }
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 1000.0)
            )
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
            if let descriptionTextView = descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.scrollContentView.addSubview(descriptionTextView)
                }
                transition.setFrame(view: descriptionTextView, frame: descriptionTextFrame)
            }
            
            contentHeight += descriptionTextFrame.height
            contentHeight += 22.0
            contentHeight += 2.0
            
            switch component.initialData.subjectInitialData {
            case let .react(reactData):
                if !reactData.topPeers.isEmpty {
                    contentHeight += 3.0
                    
                    let topPeersLeftSeparator: SimpleLayer
                    if let current = self.topPeersLeftSeparator {
                        topPeersLeftSeparator = current
                    } else {
                        topPeersLeftSeparator = SimpleLayer()
                        self.topPeersLeftSeparator = topPeersLeftSeparator
                        self.scrollContentView.layer.addSublayer(topPeersLeftSeparator)
                    }
                    
                    let topPeersRightSeparator: SimpleLayer
                    if let current = self.topPeersRightSeparator {
                        topPeersRightSeparator = current
                    } else {
                        topPeersRightSeparator = SimpleLayer()
                        self.topPeersRightSeparator = topPeersRightSeparator
                        self.scrollContentView.layer.addSublayer(topPeersRightSeparator)
                    }
                    
                    let topPeersTitleBackground: SimpleLayer
                    if let current = self.topPeersTitleBackground {
                        topPeersTitleBackground = current
                    } else {
                        topPeersTitleBackground = SimpleLayer()
                        self.topPeersTitleBackground = topPeersTitleBackground
                        self.scrollContentView.layer.addSublayer(topPeersTitleBackground)
                    }
                    
                    let topPeersTitle: ComponentView<Empty>
                    if let current = self.topPeersTitle {
                        topPeersTitle = current
                    } else {
                        topPeersTitle = ComponentView()
                        self.topPeersTitle = topPeersTitle
                    }
                    
                    topPeersLeftSeparator.backgroundColor = environment.theme.list.itemPlainSeparatorColor.cgColor
                    topPeersRightSeparator.backgroundColor = environment.theme.list.itemPlainSeparatorColor.cgColor
                    
                    let topPeersTitleSize = topPeersTitle.update(
                        transition: .immediate,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.SendStarReactions_SectionTop, font: Font.semibold(15.0), textColor: .white))
                        )),
                        environment: {},
                        containerSize: CGSize(width: 300.0, height: 100.0)
                    )
                    let topPeersBackgroundSize = CGSize(width: topPeersTitleSize.width + 16.0 * 2.0, height: topPeersTitleSize.height + 9.0 * 2.0)
                    let topPeersBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - topPeersBackgroundSize.width) * 0.5), y: contentHeight), size: topPeersBackgroundSize)
                    
                    topPeersTitleBackground.backgroundColor = UIColor(rgb: 0xFFB10D).cgColor
                    topPeersTitleBackground.cornerRadius = topPeersBackgroundFrame.height * 0.5
                    transition.setFrame(layer: topPeersTitleBackground, frame: topPeersBackgroundFrame)
                    
                    let topPeersTitleFrame = CGRect(origin: CGPoint(x: topPeersBackgroundFrame.minX + floor((topPeersBackgroundFrame.width - topPeersTitleSize.width) * 0.5), y: topPeersBackgroundFrame.minY + floor((topPeersBackgroundFrame.height - topPeersTitleSize.height) * 0.5)), size: topPeersTitleSize)
                    if let topPeersTitleView = topPeersTitle.view {
                        if topPeersTitleView.superview == nil {
                            self.scrollContentView.addSubview(topPeersTitleView)
                        }
                        transition.setFrame(view: topPeersTitleView, frame: topPeersTitleFrame)
                    }
                    
                    let separatorY = topPeersBackgroundFrame.midY
                    let separatorSpacing: CGFloat = 10.0
                    transition.setFrame(layer: topPeersLeftSeparator, frame: CGRect(origin: CGPoint(x: sideInset, y: separatorY), size: CGSize(width: max(0.0, topPeersBackgroundFrame.minX - separatorSpacing - sideInset), height: UIScreenPixel)))
                    transition.setFrame(layer: topPeersRightSeparator, frame: CGRect(origin: CGPoint(x: topPeersBackgroundFrame.maxX + separatorSpacing, y: separatorY), size: CGSize(width: max(0.0, availableSize.width - sideInset - (topPeersBackgroundFrame.maxX + separatorSpacing)), height: UIScreenPixel)))
                    
                    var mappedTopPeers = reactData.topPeers
                    if let index = mappedTopPeers.firstIndex(where: { $0.isMy }) {
                        mappedTopPeers.remove(at: index)
                    }
                    
                    var myCount = 0
                    if let myTopPeer = reactData.myTopPeer {
                        myCount += myTopPeer.count
                    }
                    var myCountAddition = 0
                    if self.didChangeAmount {
                        myCountAddition = Int(self.amount.realValue)
                    }
                    myCount += myCountAddition
                    if myCount != 0 {
                        var topPeer: EnginePeer?
                        switch self.privacyPeer {
                        case .anonymous:
                            topPeer = nil
                        case .account:
                            topPeer = reactData.myPeer
                        case let .peer(peer):
                            topPeer = peer
                        }
                        
                        mappedTopPeers.append(ChatSendStarsScreen.TopPeer(
                            randomIndex: -1,
                            peer: topPeer,
                            isMy: true,
                            count: myCount
                        ))
                    }
                    mappedTopPeers.sort(by: { $0.count > $1.count })
                    if mappedTopPeers.count > 3 {
                        mappedTopPeers = Array(mappedTopPeers.prefix(3))
                    }
                    
                    var animateItems = false
                    var itemPositionTransition = transition
                    var itemAlphaTransition = transition
                    if transition.userData(IsAdjustingAmountHint.self) != nil {
                        animateItems = true
                        itemPositionTransition = .spring(duration: 0.3)
                        itemAlphaTransition = .easeInOut(duration: 0.15)
                    }
                    
                    var validIds: [ChatSendStarsScreen.TopPeer.Id] = []
                    var items: [(itemView: ComponentView<Empty>, size: CGSize)] = []
                    for topPeer in mappedTopPeers {
                        validIds.append(topPeer.id)
                        
                        let itemView: ComponentView<Empty>
                        if let current = self.topPeerItems[topPeer.id] {
                            itemView = current
                        } else {
                            itemView = ComponentView()
                            self.topPeerItems[topPeer.id] = itemView
                        }
                        
                        let itemCountString = presentationStringsFormattedNumber(Int32(topPeer.count), environment.dateTimeFormat.groupingSeparator)
                        
                        let itemSize = itemView.update(
                            transition: .immediate,
                            component: AnyComponent(PlainButtonComponent(
                                content: AnyComponent(PeerComponent(
                                    context: component.context,
                                    theme: environment.theme,
                                    strings: environment.strings,
                                    peer: topPeer.peer,
                                    count: itemCountString
                                )),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    guard let self, let component = self.component, let peer = topPeer.peer else {
                                        return
                                    }
                                    guard let controller = self.environment?.controller() else {
                                        return
                                    }
                                    guard let navigationController = controller.navigationController as? NavigationController else {
                                        return
                                    }
                                    var viewControllers = navigationController.viewControllers
                                    guard let index = viewControllers.firstIndex(where: { $0 === controller }) else {
                                        return
                                    }
                                    
                                    let context = component.context
                                    
                                    if case .user = peer {
                                        if let peerInfoController = context.sharedContext.makePeerInfoController(
                                            context: context,
                                            updatedPresentationData: nil,
                                            peer: peer._asPeer(),
                                            mode: .generic,
                                            avatarInitiallyExpanded: false,
                                            fromChat: false,
                                            requestsContext: nil
                                        ) {
                                            viewControllers.insert(peerInfoController, at: index)
                                        }
                                    } else {
                                        let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                                        viewControllers.insert(chatController, at: index)
                                    }
                                    navigationController.setViewControllers(viewControllers, animated: true)
                                    controller.dismiss()
                                },
                                isEnabled: topPeer.peer != nil && topPeer.peer?.id != component.context.account.peerId,
                                animateAlpha: false
                            )),
                            environment: {},
                            containerSize: CGSize(width: 200.0, height: 200.0)
                        )
                        items.append((itemView, itemSize))
                    }
                    var removedIds: [ChatSendStarsScreen.TopPeer.Id] = []
                    for (id, itemView) in self.topPeerItems {
                        if !validIds.contains(id) {
                            removedIds.append(id)
                            
                            if animateItems {
                                if let itemComponentView = itemView.view {
                                    itemPositionTransition.setScale(view: itemComponentView, scale: 0.001)
                                    itemAlphaTransition.setAlpha(view: itemComponentView, alpha: 0.0, completion: { [weak itemComponentView] _ in
                                        itemComponentView?.removeFromSuperview()
                                    })
                                }
                            } else {
                                itemView.view?.removeFromSuperview()
                            }
                        }
                    }
                    for id in removedIds {
                        self.topPeerItems.removeValue(forKey: id)
                    }
                    
                    var itemsWidth: CGFloat = 0.0
                    for (_, itemSize) in items {
                        itemsWidth += itemSize.width
                    }
                    
                    let maxItemSpacing = 48.0
                    var itemSpacing = floor((availableSize.width - itemsWidth) / CGFloat(items.count + 1))
                    itemSpacing = min(itemSpacing, maxItemSpacing)
                    
                    let totalWidth = itemsWidth + itemSpacing * CGFloat(items.count + 1)
                    var itemX: CGFloat = floor((availableSize.width - totalWidth) * 0.5) + itemSpacing
                    for (itemView, itemSize) in items {
                        if let itemComponentView = itemView.view {
                            var animateItem = animateItems
                            if itemComponentView.superview == nil {
                                self.scrollContentView.addSubview(itemComponentView)
                                animateItem = false
                                ComponentTransition.immediate.setScale(view: itemComponentView, scale: 0.001)
                                itemComponentView.alpha = 0.0
                            }
                            
                            let itemFrame = CGRect(origin: CGPoint(x: itemX, y: contentHeight + 56.0), size: itemSize)
                            
                            if animateItem {
                                itemPositionTransition.setPosition(view: itemComponentView, position: itemFrame.center)
                                itemPositionTransition.setBounds(view: itemComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            } else {
                                itemComponentView.center = itemFrame.center
                                itemComponentView.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
                            }
                            
                            itemPositionTransition.setScale(view: itemComponentView, scale: 1.0)
                            itemAlphaTransition.setAlpha(view: itemComponentView, alpha: 1.0)
                        }
                        itemX += itemSize.width + itemSpacing
                    }
                    
                    contentHeight += 161.0
                }
                
                if !reactData.topPeers.isEmpty {
                    contentHeight += 2.0
                }
                
                if self.anonymousSeparator.superlayer == nil {
                    self.scrollContentView.layer.addSublayer(self.anonymousSeparator)
                }
                
                self.anonymousSeparator.backgroundColor = environment.theme.list.itemPlainSeparatorColor.cgColor
                
                let checkTheme = CheckComponent.Theme(
                    backgroundColor: environment.theme.list.itemCheckColors.fillColor,
                    strokeColor: environment.theme.list.itemCheckColors.foregroundColor,
                    borderColor: environment.theme.list.itemCheckColors.strokeColor,
                    overlayBorder: false,
                    hasInset: false,
                    hasShadow: false
                )
                let anonymousContentsSize = self.anonymousContents.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                theme: checkTheme,
                                selected: self.privacyPeer != .anonymous
                            ))),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: environment.strings.SendStarReactions_ShowMyselfInTop, font: Font.regular(16.0), textColor: environment.theme.list.itemPrimaryTextColor))
                            )))
                        ], spacing: 10.0)),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            switch self.privacyPeer {
                            case .anonymous:
                                if let currentMyPeer = self.currentMyPeer {
                                    if currentMyPeer.id == component.context.account.peerId {
                                        self.privacyPeer = .account
                                    } else {
                                        self.privacyPeer = .peer(currentMyPeer)
                                    }
                                }
                            default:
                                self.privacyPeer = .anonymous
                            }
                            self.state?.updated(transition: .easeInOut(duration: 0.2))
                            
                            if reactData.myTopPeer != nil {
                                let mappedPrivacy: TelegramPaidReactionPrivacy
                                switch self.privacyPeer {
                                case .account:
                                    mappedPrivacy = .default
                                case .anonymous:
                                    mappedPrivacy = .anonymous
                                case let .peer(peer):
                                    mappedPrivacy = .peer(peer.id)
                                }
                                
                                let _ = component.context.engine.messages.updateStarsReactionPrivacy(id: reactData.messageId, privacy: mappedPrivacy).startStandalone()
                            }
                        },
                        animateAlpha: false,
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                
                transition.setFrame(layer: self.anonymousSeparator, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: UIScreenPixel)))
                
                contentHeight += 21.0
                
                let anonymousContentsFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - anonymousContentsSize.width) * 0.5), y: contentHeight), size: anonymousContentsSize)
                if let anonymousContentsView = self.anonymousContents.view {
                    if anonymousContentsView.superview == nil {
                        self.scrollContentView.addSubview(anonymousContentsView)
                    }
                    transition.setFrame(view: anonymousContentsView, frame: anonymousContentsFrame)
                }
                
                contentHeight += anonymousContentsSize.height + 27.0
            }
            
            initialContentHeight = contentHeight
            
            if self.cachedStarImage == nil || self.cachedStarImage?.1 !== environment.theme {
                self.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: .white)!, environment.theme)
            }
            
            let buttonString: String
            switch component.initialData.subjectInitialData {
            case .react:
                buttonString = environment.strings.SendStarReactions_SendButtonTitle("\(self.amount.realValue)").string
            }
            let buttonAttributedString = NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: .white, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = self.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: UIColor(rgb: 0xffffff), range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            
            let actionButtonSize = actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let balance = self.balance else {
                            return
                        }
                        
                        if balance < StarsAmount(value: Int64(self.amount.realValue), nanos: 0) {
                            let _ = (component.context.engine.payments.starsTopUpOptions()
                            |> take(1)
                            |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                                guard let self, let component = self.component else {
                                    return
                                }
                                guard let starsContext = component.context.starsContext else {
                                    return
                                }
                                
                                let purchasePurpose: StarsPurchasePurpose
                                switch component.initialData.subjectInitialData {
                                case let .react(reactData):
                                    purchasePurpose = .reactions(peerId: reactData.peer.id, requiredStars: Int64(self.amount.realValue))
                                }
                                
                                let purchaseScreen = component.context.sharedContext.makeStarsPurchaseScreen(context: component.context, starsContext: starsContext, options: options, purpose: purchasePurpose, completion: { result in
                                    let _ = result
                                    //TODO:release
                                })
                                self.environment?.controller()?.push(purchaseScreen)
                                self.environment?.controller()?.dismiss()
                            })
                            
                            return
                        }
                        
                        guard let badgeView = self.badge.view as? BadgeComponent.View else {
                            return
                        }
                        let isBecomingTop: Bool
                        if let topCount {
                            isBecomingTop = self.amount.realValue > topCount
                        } else {
                            isBecomingTop = true
                        }
                        
                        let mappedPrivacy: TelegramPaidReactionPrivacy
                        switch self.privacyPeer {
                        case .account:
                            mappedPrivacy = .default
                        case .anonymous:
                            mappedPrivacy = .anonymous
                        case let .peer(peer):
                            mappedPrivacy = .peer(peer.id)
                        }
                        
                        switch component.initialData.subjectInitialData {
                        case let .react(reactData):
                            reactData.completion(
                                Int64(self.amount.realValue),
                                mappedPrivacy,
                                isBecomingTop,
                                ChatSendStarsScreen.TransitionOut(
                                    sourceView: badgeView.badgeIcon
                                )
                            )
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            
            var buttonDescriptionTextSize: CGSize?
            if case .react = component.initialData.subjectInitialData {
                buttonDescriptionTextSize = self.buttonDescriptionText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .markdown(text: environment.strings.SendStarReactions_TermsOfServiceFooter, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.itemSecondaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                            linkAttribute: { contents in
                                return (TelegramTextAttributes.URL, contents)
                            }
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.2),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak self] attributes, _ in
                            if let controller = self?.environment?.controller(), let navigationController = controller.navigationController as? NavigationController, let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset, height: 1000.0)
                )
            }
            let buttonDescriptionSpacing: CGFloat = 14.0
            
            var bottomPanelHeight = 13.0 + environment.safeInsets.bottom + actionButtonSize.height
            if let buttonDescriptionTextSize {
                bottomPanelHeight += buttonDescriptionSpacing + buttonDescriptionTextSize.height
            } else {
                bottomPanelHeight -= 1.0
            }
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
            if let actionButtonView = actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            if let buttonDescriptionTextSize {
                let buttonDescriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - buttonDescriptionTextSize.width) * 0.5), y: actionButtonFrame.maxY + buttonDescriptionSpacing), size: buttonDescriptionTextSize)
                if let buttonDescriptionTextView = buttonDescriptionText.view {
                    if buttonDescriptionTextView.superview == nil {
                        self.addSubview(buttonDescriptionTextView)
                    }
                    transition.setFrame(view: buttonDescriptionTextView, frame: buttonDescriptionTextFrame)
                }
            }
            
            contentHeight += bottomPanelHeight
            initialContentHeight += bottomPanelHeight
            
            clippingY = actionButtonFrame.minY - 24.0
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 10.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
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

public class ChatSendStarsScreen: ViewControllerComponentContainer {
    fileprivate enum SubjectInitialData {
        final class React {
            let peer: EnginePeer
            let myPeer: EnginePeer
            let defaultPrivacyPeer: ChatSendStarsScreenComponent.PrivacyPeer
            let channelsForPublicReaction: [EnginePeer]
            let messageId: EngineMessage.Id
            let currentSentAmount: Int?
            let topPeers: [ChatSendStarsScreen.TopPeer]
            let myTopPeer: ChatSendStarsScreen.TopPeer?
            let maxAmount: Int
            let completion: (Int64, TelegramPaidReactionPrivacy, Bool, ChatSendStarsScreen.TransitionOut) -> Void
            
            init(peer: EnginePeer, myPeer: EnginePeer, defaultPrivacyPeer: ChatSendStarsScreenComponent.PrivacyPeer, channelsForPublicReaction: [EnginePeer], messageId: EngineMessage.Id, currentSentAmount: Int?, topPeers: [ChatSendStarsScreen.TopPeer], myTopPeer: ChatSendStarsScreen.TopPeer?, maxAmount: Int, completion: @escaping (Int64, TelegramPaidReactionPrivacy, Bool, ChatSendStarsScreen.TransitionOut) -> Void) {
                self.peer = peer
                self.myPeer = myPeer
                self.defaultPrivacyPeer = defaultPrivacyPeer
                self.channelsForPublicReaction = channelsForPublicReaction
                self.messageId = messageId
                self.currentSentAmount = currentSentAmount
                self.topPeers = topPeers
                self.myTopPeer = myTopPeer
                self.maxAmount = maxAmount
                self.completion = completion
            }
        }
        
        case react(React)
    }
    
    public final class InitialData {
        fileprivate let subjectInitialData: SubjectInitialData
        fileprivate let balance: StarsAmount?
        
        fileprivate init(
            subjectInitialData: SubjectInitialData,
            balance: StarsAmount?
        ) {
            self.subjectInitialData = subjectInitialData
            self.balance = balance
        }
    }
    
    fileprivate final class TopPeer: Equatable {
        enum Id: Hashable {
            case anonymous(Int)
            case my
            case peer(EnginePeer.Id)
        }
        
        var id: Id {
            if self.isMy {
                return .my
            } else if let peer = self.peer {
                return .peer(peer.id)
            } else {
                return .anonymous(self.randomIndex)
            }
        }
        
        var isAnonymous: Bool {
            return self.peer == nil
        }
        
        let randomIndex: Int
        let peer: EnginePeer?
        let isMy: Bool
        let count: Int
        
        init(randomIndex: Int, peer: EnginePeer?, isMy: Bool, count: Int) {
            self.randomIndex = randomIndex
            self.peer = peer
            self.isMy = isMy
            self.count = count
        }
        
        static func ==(lhs: TopPeer, rhs: TopPeer) -> Bool {
            if lhs.randomIndex != rhs.randomIndex {
                return false
            }
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.isMy != rhs.isMy {
                return false
            }
            if lhs.count != rhs.count {
                return false
            }
            return true
        }
    }
    
    public final class TransitionOut {
        public let sourceView: UIView
        
        init(sourceView: UIView) {
            self.sourceView = sourceView
        }
    }
    
    private let context: AccountContext
    
    private var didPlayAppearAnimation: Bool = false
    private var isDismissed: Bool = false
    
    private var presenceDisposable: Disposable?
    
    public init(context: AccountContext, initialData: InitialData) {
        self.context = context
        
        super.init(context: context, component: ChatSendStarsScreenComponent(
            context: context,
            initialData: initialData
        ), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presenceDisposable?.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if !self.didPlayAppearAnimation {
            self.didPlayAppearAnimation = true
            
            if let componentView = self.node.hostView.componentView as? ChatSendStarsScreenComponent.View {
                componentView.animateIn()
            }
        }
    }
    
    public static func initialData(context: AccountContext, peerId: EnginePeer.Id, messageId: EngineMessage.Id, topPeers: [ReactionsMessageAttribute.TopPeer], completion: @escaping (Int64, TelegramPaidReactionPrivacy, Bool, TransitionOut) -> Void) -> Signal<InitialData?, NoError> {
        let balance: Signal<StarsAmount?, NoError>
        if let starsContext = context.starsContext {
            balance = starsContext.state
            |> map { state in
                return state?.balance
            }
            |> take(1)
        } else {
            balance = .single(nil)
        }
        
        var currentSentAmount: Int?
        var myTopPeer: ReactionsMessageAttribute.TopPeer?
        if let myPeer = topPeers.first(where: { $0.isMy }) {
            myTopPeer = myPeer
            currentSentAmount = Int(myPeer.count)
        }
        
        let allPeerIds = topPeers.compactMap(\.peerId)
        
        var topPeers = topPeers.sorted(by: { $0.count > $1.count })
        if topPeers.count > 3 {
            topPeers = Array(topPeers.prefix(3))
        }
        
        let channelsForPublicReaction = context.engine.peers.channelsForPublicReaction(useLocalCache: true)
        
        let defaultPrivacyPeer: Signal<ChatSendStarsScreenComponent.PrivacyPeer, NoError> = context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.StarsReactionDefaultPrivacy()
        )
        |> mapToSignal { defaultPrivacy -> Signal<ChatSendStarsScreenComponent.PrivacyPeer, NoError> in
            switch defaultPrivacy {
            case .anonymous:
                return .single(.anonymous)
            case .default:
                return .single(.account)
            case let .peer(peerId):
                return context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
                |> map { peer -> ChatSendStarsScreenComponent.PrivacyPeer in
                    if let peer {
                        return .peer(peer)
                    } else {
                        return .anonymous
                    }
                }
            }
        }
        
        var maxAmount = 2500
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["stars_paid_reaction_amount_max"] as? Double {
            maxAmount = Int(value)
        }
        
        return combineLatest(
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                EngineDataMap(allPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            ),
            balance,
            channelsForPublicReaction,
            defaultPrivacyPeer
        )
        |> map { peerAndTopPeerMap, balance, channelsForPublicReaction, defaultPrivacyPeer -> InitialData? in
            let (peer, myPeer, topPeerMap) = peerAndTopPeerMap
            guard let peer, let myPeer else {
                return nil
            }
            
            var nextRandomIndex = 0
            return InitialData(
                subjectInitialData: .react(SubjectInitialData.React(
                    peer: peer,
                    myPeer: myPeer,
                    defaultPrivacyPeer: defaultPrivacyPeer,
                    channelsForPublicReaction: channelsForPublicReaction,
                    messageId: messageId,
                    currentSentAmount: currentSentAmount,
                    topPeers: topPeers.compactMap { topPeer -> ChatSendStarsScreen.TopPeer? in
                        guard let topPeerId = topPeer.peerId else {
                            let randomIndex = nextRandomIndex
                            nextRandomIndex += 1
                            return ChatSendStarsScreen.TopPeer(
                                randomIndex: randomIndex,
                                peer: nil,
                                isMy: topPeer.isMy,
                                count: Int(topPeer.count)
                            )
                        }
                        guard let topPeerValue = topPeerMap[topPeerId] else {
                            return nil
                        }
                        guard let topPeerValue else {
                            return nil
                        }
                        let randomIndex = nextRandomIndex
                        nextRandomIndex += 1
                        return ChatSendStarsScreen.TopPeer(
                            randomIndex: randomIndex,
                            peer: topPeer.isAnonymous ? nil : topPeerValue,
                            isMy: topPeer.isMy,
                            count: Int(topPeer.count)
                        )
                    },
                    myTopPeer: myTopPeer.flatMap { topPeer -> ChatSendStarsScreen.TopPeer? in
                        guard let topPeerId = topPeer.peerId else {
                            return ChatSendStarsScreen.TopPeer(
                                randomIndex: -1,
                                peer: nil,
                                isMy: topPeer.isMy,
                                count: Int(topPeer.count)
                            )
                        }
                        guard let topPeerValue = topPeerMap[topPeerId] else {
                            return nil
                        }
                        guard let topPeerValue else {
                            return nil
                        }
                        return ChatSendStarsScreen.TopPeer(
                            randomIndex: -1,
                            peer: topPeer.isAnonymous ? nil : topPeerValue,
                            isMy: topPeer.isMy,
                            count: Int(topPeer.count)
                        )
                    },
                    maxAmount: maxAmount,
                    completion: completion
                )),
                balance: balance
            )
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? ChatSendStarsScreenComponent.View {
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

private final class BadgeStarsView: UIView {
    private let staticEmitterLayer = CAEmitterLayer()
    private let dynamicEmitterLayer = CAEmitterLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.addSublayer(self.staticEmitterLayer)
        self.layer.addSublayer(self.dynamicEmitterLayer)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
        
    private func setupEmitter() {
        let color = UIColor(rgb: 0xffbe27)
        
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
    
    func update(size: CGSize, emitterPosition: CGPoint) {
        if self.staticEmitterLayer.emitterCells == nil {
            self.setupEmitter()
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
        
        self.emitterLayer.setValue(20.0 + Float(value * 40.0), forKeyPath: "emitterCells.emitter.birthRate")
        self.emitterLayer.setValue(15.0 + value * 75.0, forKeyPath: "emitterCells.emitter.velocity")
        
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        self.emitterLayer.emitterSize = size
    }
}

private final class PeerSelectorBadgeComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer
    let action: ((UIView) -> Void)?
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        action: ((UIView) -> Void)?
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.action = action
    }
    
    static func ==(lhs: PeerSelectorBadgeComponent, rhs: PeerSelectorBadgeComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    final class View: HighlightableButton {
        private let background = ComponentView<Empty>()
        private var avatarNode: AvatarNode?
        private var selectorIcon: ComponentView<Empty>?
        
        private var component: PeerSelectorBadgeComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action?(self)
        }
        
        func update(component: PeerSelectorBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.isEnabled = component.action != nil
            
            let height: CGFloat = 32.0
            let avatarPadding: CGFloat = 1.0
            
            let avatarDiameter = height - avatarPadding * 2.0
            let avatarTextSpacing: CGFloat = -4.0
            let rightTextInset: CGFloat = component.action != nil ? 26.0 : 12.0
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(avatarDiameter * 0.5)))
                avatarNode.isUserInteractionEnabled = false
                avatarNode.displaysAsynchronously = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: avatarPadding, y: avatarPadding), size: CGSize(width: avatarDiameter, height: avatarDiameter))
            avatarNode.frame = avatarFrame
            avatarNode.updateSize(size: avatarFrame.size)
            avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, synchronousLoad: true)
            
            let size = CGSize(width: avatarPadding + avatarDiameter + avatarTextSpacing + rightTextInset, height: height)
            
            if component.action != nil {
                let selectorIcon: ComponentView<Empty>
                if let current = self.selectorIcon {
                    selectorIcon = current
                } else {
                    selectorIcon = ComponentView()
                    self.selectorIcon = selectorIcon
                }
                let selectorIconSize = selectorIcon.update(
                    transition: transition,
                    component: AnyComponent(BundleIconComponent(
                        name: "Item List/ExpandableSelectorArrows", tintColor: component.theme.list.itemInputField.primaryColor.withMultipliedAlpha(0.5))),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let selectorIconFrame = CGRect(origin: CGPoint(x: size.width - 8.0 - selectorIconSize.width, y: floorToScreenPixels((size.height - selectorIconSize.height) * 0.5)), size: selectorIconSize)
                if let selectorIconView = selectorIcon.view {
                    if selectorIconView.superview == nil {
                        selectorIconView.isUserInteractionEnabled = false
                        self.addSubview(selectorIconView)
                    }
                    transition.setFrame(view: selectorIconView, frame: selectorIconFrame)
                }
            } else if let selectorIcon = self.selectorIcon {
                self.selectorIcon = nil
                selectorIcon.view?.removeFromSuperview()
            }
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: component.theme.list.itemInputField.backgroundColor,
                    cornerRadius: .minEdge,
                    smoothCorners: false
                )),
                environment: {},
                containerSize: size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    backgroundView.isUserInteractionEnabled = false
                    self.insertSubview(backgroundView, at: 0)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            }
            
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

final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    private let actionsOnTop: Bool

    init(controller: ViewController, sourceView: UIView, actionsOnTop: Bool) {
        self.controller = controller
        self.sourceView = sourceView
        self.actionsOnTop = actionsOnTop
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, actionsPosition: self.actionsOnTop ? .top : .bottom)
    }
}
