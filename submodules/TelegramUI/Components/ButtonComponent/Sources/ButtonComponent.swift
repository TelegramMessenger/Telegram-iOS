import Foundation
import UIKit
import Display
import ComponentFlow
import AnimatedTextComponent
import ActivityIndicator
import BundleIconComponent
import ShimmerEffect
import GlassBackgroundComponent

public final class ButtonBadgeComponent: Component {
    let fillColor: UIColor
    let style: ButtonTextContentComponent.BadgeStyle
    let content: AnyComponent<Empty>
    
    public init(
        fillColor: UIColor,
        style: ButtonTextContentComponent.BadgeStyle,
        content: AnyComponent<Empty>
    ) {
        self.fillColor = fillColor
        self.style = style
        self.content = content
    }
    
    public static func ==(lhs: ButtonBadgeComponent, rhs: ButtonBadgeComponent) -> Bool {
        if lhs.fillColor != rhs.fillColor {
            return false
        }
        if lhs.style != rhs.style {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView: UIImageView
        private let content = ComponentView<Empty>()
        
        private var component: ButtonBadgeComponent?
        
        override public init(frame: CGRect) {
            self.backgroundView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func update(component: ButtonBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let height: CGFloat
            switch component.style {
            case .round:
                height = 20.0
            case .roundedRectangle:
                height = 18.0
            }
            let contentInset: CGFloat = 10.0
            
            let themeUpdated = self.component?.fillColor != component.fillColor
            self.component = component
            
            let contentSize = self.content.update(
                transition: transition,
                component: component.content,
                environment: {},
                containerSize: availableSize
            )
            let backgroundWidth: CGFloat = max(height, contentSize.width + contentInset)
            let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: backgroundWidth, height: height))
            
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundFrame.width - contentSize.width) * 0.5), y: floorToScreenPixels((backgroundFrame.height - contentSize.height) * 0.5)), size: contentSize))
            }
            
            if themeUpdated || backgroundFrame.height != self.backgroundView.image?.size.height {
                switch component.style {
                case .round:
                    self.backgroundView.image = generateStretchableFilledCircleImage(diameter: backgroundFrame.height, color: component.fillColor)
                case .roundedRectangle:
                    self.backgroundView.image = generateFilledRoundedRectImage(size: CGSize(width: height, height: height), cornerRadius: 4.0, color: component.fillColor)?.stretchableImage(withLeftCapWidth: Int(height / 2.0), topCapHeight: Int(height / 2.0))
                }
            }
            
            return backgroundFrame.size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ButtonTextContentComponent: Component {
    public enum BadgeStyle {
        case round
        case roundedRectangle
    }
    
    public let text: String
    public let badge: Int
    public let textColor: UIColor
    public let fontSize: CGFloat
    public let badgeBackground: UIColor
    public let badgeForeground: UIColor
    public let badgeStyle: BadgeStyle
    public let badgeIconName: String?
    public let combinedAlignment: Bool
    
    public init(
        text: String,
        badge: Int,
        textColor: UIColor,
        fontSize: CGFloat = 17.0,
        badgeBackground: UIColor,
        badgeForeground: UIColor,
        badgeStyle: BadgeStyle = .round,
        badgeIconName: String? = nil,
        combinedAlignment: Bool = false
    ) {
        self.text = text
        self.badge = badge
        self.textColor = textColor
        self.fontSize = fontSize
        self.badgeBackground = badgeBackground
        self.badgeForeground = badgeForeground
        self.badgeStyle = badgeStyle
        self.badgeIconName = badgeIconName
        self.combinedAlignment = combinedAlignment
    }
    
    public static func ==(lhs: ButtonTextContentComponent, rhs: ButtonTextContentComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.badgeBackground != rhs.badgeBackground {
            return false
        }
        if lhs.badgeForeground != rhs.badgeForeground {
            return false
        }
        if lhs.badgeStyle != rhs.badgeStyle {
            return false
        }
        if lhs.badgeIconName != rhs.badgeIconName {
            return false
        }
        if lhs.combinedAlignment != rhs.combinedAlignment {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: ButtonTextContentComponent?
        private weak var componentState: EmptyComponentState?

        private let content = ComponentView<Empty>()
        private var badge: ComponentView<Empty>?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }

        func update(component: ButtonTextContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousBadge = self.component?.badge
            
            self.component = component
            self.componentState = state
            
            var badgeSpacing: CGFloat = 6.0
            if component.badgeIconName != nil {
                badgeSpacing += 4.0
            }
            
            let contentSize = self.content.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.text,
                    font: Font.semibold(component.fontSize),
                    color: component.textColor
                )),
                environment: {},
                containerSize: availableSize
            )
            
            var badgeSize: CGSize?
            if component.badge > 0 {
                var badgeTransition = transition
                let badge: ComponentView<Empty>
                if let current = self.badge {
                    badge = current
                } else {
                    badgeTransition = .immediate
                    badge = ComponentView()
                    self.badge = badge
                }
                
                var badgeContent: [AnyComponentWithIdentity<Empty>] = []
                if let badgeIconName = component.badgeIconName {
                    badgeContent.append(AnyComponentWithIdentity(
                        id: "icon",
                        component: AnyComponent(BundleIconComponent(
                            name: badgeIconName,
                            tintColor: component.badgeForeground
                        )))
                    )
                }
                badgeContent.append(AnyComponentWithIdentity(
                    id: "text", 
                    component: AnyComponent(AnimatedTextComponent(
                        font: Font.with(size: 15.0, design: .round, weight: .semibold, traits: .monospacedNumbers),
                        color: component.badgeForeground,
                        items: [
                            AnimatedTextComponent.Item(id: AnyHashable(0), content: .number(component.badge, minDigits: 0))
                        ]
                    )))
                )
                
                badgeSize = badge.update(
                    transition: badgeTransition,
                    component: AnyComponent(ButtonBadgeComponent(
                        fillColor: component.badgeBackground,
                        style: component.badgeStyle,
                        content: AnyComponent(HStack(badgeContent, spacing: 2.0))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            }
            
            var size = contentSize
            var measurementSize = size
            if let badgeSize {
                if component.combinedAlignment {
                    measurementSize.width += badgeSpacing
                    measurementSize.width += badgeSize.width
                }
                size.height = max(size.height, badgeSize.height)
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - measurementSize.width) * 0.5), y: floorToScreenPixels((size.height - measurementSize.height) * 0.5)), size: measurementSize)
            
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: CGRect(origin: contentFrame.origin, size: contentSize))
            }
            
            if let badgeSize, let badge = self.badge {
                let badgeFrame = CGRect(origin: CGPoint(x: contentFrame.minX + contentSize.width + badgeSpacing, y: floorToScreenPixels((size.height - badgeSize.height) * 0.5) + UIScreenPixel), size: badgeSize)
                
                if let badgeView = badge.view {
                    var animateIn = false
                    if badgeView.superview == nil {
                        animateIn = true
                        self.addSubview(badgeView)
                    }
                    
                    if animateIn {
                        badgeView.frame = badgeFrame
                    } else {
                        transition.setFrame(view: badgeView, frame: badgeFrame)
                        
                        if !transition.animation.isImmediate, let previousBadge, previousBadge != component.badge {
                            let middleScale: CGFloat = previousBadge < component.badge ? 1.1 : 0.9
                            let values: [NSNumber] = [1.0, middleScale as NSNumber, 1.0]
                            badgeView.layer.animateKeyframes(values: values, duration: 0.25, keyPath: "transform.scale")
                        }
                    }
                    
                    if animateIn, !transition.animation.isImmediate {
                        badgeView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        badgeView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                    }
                }
            } else {
                if let badge = self.badge {
                    self.badge = nil
                    if let badgeView = badge.view {
                        if !transition.animation.isImmediate {
                            badgeView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak badgeView] _ in
                                badgeView?.removeFromSuperview()
                            })
                            badgeView.layer.rasterizationScale = UIScreenScale
                            badgeView.layer.shouldRasterize = true
                            badgeView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.25, removeOnCompletion: false)
                        } else {
                            badgeView.removeFromSuperview()
                        }
                    }
                }
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ButtonComponent: Component {
    public struct Background: Equatable {
        public enum Style {
            case glass
            case actualGlass
            case legacy
        }

        public struct Gradient: Equatable {
            public enum Animation: Equatable {
                case horizontalShift(duration: Double)
            }

            public var colors: [UIColor]
            public var animation: Animation

            public init(
                colors: [UIColor],
                animation: Animation = .horizontalShift(duration: 4.5)
            ) {
                self.colors = colors
                self.animation = animation
            }
        }

        public var style: Style
        public var color: UIColor
        public var foreground: UIColor
        public var pressedColor: UIColor
        public var cornerRadius: CGFloat
        public var isShimmering: Bool
        public var gradient: Gradient?

        public init(
            style: Style = .legacy,
            color: UIColor,
            foreground: UIColor,
            pressedColor: UIColor,
            cornerRadius: CGFloat = 10.0,
            isShimmering: Bool = false,
            gradient: Gradient? = nil
        ) {
            self.style = style
            self.color = color
            self.foreground = foreground
            self.pressedColor = pressedColor
            self.cornerRadius = cornerRadius
            self.isShimmering = isShimmering
            self.gradient = gradient
        }
        
        public func withIsShimmering(_ isShimmering: Bool) -> Background {
            return Background(
                style: self.style,
                color: self.color,
                foreground: self.foreground,
                pressedColor: self.pressedColor,
                cornerRadius: self.cornerRadius,
                isShimmering: isShimmering,
                gradient: self.gradient
            )
        }
    }

    public let background: Background
    public let content: AnyComponentWithIdentity<Empty>
    public let restrictContentAnimations: Bool
    public let contentInsets: UIEdgeInsets?
    public let fitToContentWidth: Bool
    public let isEnabled: Bool
    public let tintWhenDisabled: Bool
    public let allowActionWhenDisabled: Bool
    public let displaysProgress: Bool
    public let action: () -> Void
    public let longPressAction: (() -> Void)?

    public init(
        background: Background,
        content: AnyComponentWithIdentity<Empty>,
        restrictContentAnimations: Bool = false,
        contentInsets: UIEdgeInsets? = nil,
        fitToContentWidth: Bool = false,
        isEnabled: Bool = true,
        tintWhenDisabled: Bool = true,
        allowActionWhenDisabled: Bool = false,
        displaysProgress: Bool = false,
        action: @escaping () -> Void,
        longPressAction: (() -> Void)? = nil
    ) {
        self.background = background
        self.content = content
        self.restrictContentAnimations = restrictContentAnimations
        self.contentInsets = contentInsets
        self.fitToContentWidth = fitToContentWidth
        self.isEnabled = isEnabled
        self.tintWhenDisabled = tintWhenDisabled
        self.allowActionWhenDisabled = allowActionWhenDisabled
        self.displaysProgress = displaysProgress
        self.action = action
        self.longPressAction = longPressAction
    }

    public static func ==(lhs: ButtonComponent, rhs: ButtonComponent) -> Bool {
        if lhs.background != rhs.background {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.restrictContentAnimations != rhs.restrictContentAnimations {
            return false
        }
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        if lhs.fitToContentWidth != rhs.fitToContentWidth {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.tintWhenDisabled != rhs.tintWhenDisabled {
            return false
        }
        if lhs.allowActionWhenDisabled != rhs.allowActionWhenDisabled {
            return false
        }
        if lhs.displaysProgress != rhs.displaysProgress {
            return false
        }
        if (lhs.longPressAction == nil) != (rhs.longPressAction == nil) {
            return false
        }
        return true
    }

    private final class ContentItem {
        let id: AnyHashable
        let view = ComponentView<Empty>()

        init(id: AnyHashable) {
            self.id = id
        }
    }

    public final class View: UIView {
        private var backgroundReveal: (from: UIColor, to: UIColor, origin: CGPoint, radius: CGFloat, progress: CGFloat, fade: Bool)?
        private var colorRevealLayer: CALayer?
        private var colorRevealMask: CAGradientLayer?

        public func setBackgroundReveal(from: UIColor, to: UIColor, origin: CGPoint, radius: CGFloat, progress: CGFloat, fade: Bool) {
            self.backgroundReveal = (from, to, origin, radius, progress, fade)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            self.containerView.backgroundColor = progress >= 1 ? to : from
            guard progress < 1 else {
                self.colorRevealLayer?.removeFromSuperlayer()
                self.colorRevealLayer = nil
                self.colorRevealMask = nil
                return
            }
            let layer: CALayer
            if let current = self.colorRevealLayer {
                layer = current
            } else {
                layer = CALayer()
                self.colorRevealLayer = layer
                self.containerView.layer.insertSublayer(layer, at: 0)
            }
            layer.frame = self.containerView.bounds
            layer.backgroundColor = to.cgColor
            layer.opacity = fade ? Float(progress) : 1
            if fade {
                layer.mask = nil
            } else {
                let mask = self.colorRevealMask ?? CAGradientLayer()
                self.colorRevealMask = mask
                mask.type = .radial
                mask.startPoint = CGPoint(x: 0.5, y: 0.5)
                mask.endPoint = CGPoint(x: 1, y: 1)
                let r = max(0.001, radius)
                mask.frame = CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2)
                mask.colors = (0...8).map { index in
                    let t = CGFloat(index) / 8
                    return UIColor.black.withAlphaComponent(1 - t * t * (3 - 2 * t)).cgColor
                }
                mask.locations = (0...8).map { index in
                    NSNumber(value: Double(max(0, 1 - 18 / r) + min(1, 18 / r) * CGFloat(index) / 8))
                }
                layer.mask = mask
            }
        }

        private var component: ButtonComponent?
        private weak var componentState: EmptyComponentState?

        private var containerView: UIView
        private var glassContainerView: GlassBackgroundView?
        private var glassShadowView: UIImageView?
        private var glassShadowCornerRadius: CGFloat?
        private var glassHighlightContainerView: UIView?
        private let button: HighlightTrackingButton
        private let glassHighlightRecognizer: GlassHighlightGestureRecognizer
        
        private var shimmeringView: ButtonShimmeringView?
        private var gradientBackgroundView: AnimatedGradientBackgroundView?
        private var chromeView: UIImageView?
        private var chromeTintView: UIImageView?
        private var chromeImageKey: ButtonRimImageKey?
        private var contentItem: ContentItem?
        
        private var activityIndicator: ActivityIndicator?
        private var longPressGesture: UILongPressGestureRecognizer?
        
        override init(frame: CGRect) {
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            self.containerView.isUserInteractionEnabled = false
            
            self.button = HighlightTrackingButton()
            self.glassHighlightRecognizer = GlassHighlightGestureRecognizer(target: nil, action: nil)
            
            super.init(frame: frame)
            
            self.button.isExclusiveTouch = true
            self.layer.rasterizationScale = UIScreenScale
            
            self.addSubview(self.containerView)
            self.addSubview(self.button)
            self.addGestureRecognizer(self.glassHighlightRecognizer)
            self.glassHighlightRecognizer.isEnabled = false
            self.glassHighlightRecognizer.pressedScale = 1.05
            
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)

            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
            longPressGesture.isEnabled = false
            self.longPressGesture = longPressGesture
            self.button.addGestureRecognizer(longPressGesture)

            self.button.highligthedChanged = { [weak self] highlighted in
                if let self, let component = self.component, component.isEnabled {
                    switch component.background.style {
                    case .legacy:
                        if highlighted {
                            self.containerView.layer.removeAnimation(forKey: "opacity")
                            self.containerView.alpha = 0.7
                        } else {
                            self.containerView.alpha = 1.0
                            self.containerView.layer.animateAlpha(from: 0.7, to: 1.0, duration: 0.2)
                        }
                    default:
                        break
                    }
                }
            }
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        private func removeGlassEffect(transition: ComponentTransition) {
            self.glassHighlightRecognizer.isEnabled = false
            self.glassHighlightRecognizer.highlightContainerView = nil
            
            if let glassShadowView = self.glassShadowView, glassShadowView.superview != nil {
                if transition.animation.isImmediate {
                    glassShadowView.removeFromSuperview()
                } else {
                    transition.setAlpha(view: glassShadowView, alpha: 0.0, completion: { _ in
                        glassShadowView.removeFromSuperview()
                    })
                }
            }
            if let glassHighlightContainerView = self.glassHighlightContainerView, glassHighlightContainerView.superview != nil {
                glassHighlightContainerView.removeFromSuperview()
            }
            self.glassShadowCornerRadius = nil
            
            self.layer.removeAnimation(forKey: "sublayerTransform")
            self.layer.sublayerTransform = CATransform3DIdentity
        }
        
        private func updateGlassEffect(component: ButtonComponent, size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
            let shadowInset: CGFloat = 48.0
            
            let glassShadowView: UIImageView
            if let current = self.glassShadowView {
                glassShadowView = current
            } else {
                glassShadowView = UIImageView()
                glassShadowView.isUserInteractionEnabled = false
                self.glassShadowView = glassShadowView
            }
            if glassShadowView.superview == nil {
                self.insertSubview(glassShadowView, at: 0)
            } else {
                self.sendSubviewToBack(glassShadowView)
            }
            if self.glassShadowCornerRadius != cornerRadius || glassShadowView.image == nil {
                glassShadowView.image = GlassBackgroundView.generateLegacyShadowImage(cornerRadius: cornerRadius, shadowInset: shadowInset, shadowIntensity: 0.18, shadowBlur: 64.0)
                self.glassShadowCornerRadius = cornerRadius
            }
            transition.setFrame(view: glassShadowView, frame: CGRect(origin: .zero, size: size).insetBy(dx: -shadowInset, dy: -shadowInset))
            transition.setAlpha(view: glassShadowView, alpha: 1.0)
            
            let glassHighlightContainerView: UIView
            if let current = self.glassHighlightContainerView {
                glassHighlightContainerView = current
            } else {
                glassHighlightContainerView = UIView()
                glassHighlightContainerView.isUserInteractionEnabled = false
                glassHighlightContainerView.clipsToBounds = true
                self.glassHighlightContainerView = glassHighlightContainerView
            }            
            if glassHighlightContainerView.superview == nil {
                self.insertSubview(glassHighlightContainerView, aboveSubview: self.containerView)
            } else if self.button.superview === self {
                self.insertSubview(glassHighlightContainerView, belowSubview: self.button)
            } else {
                self.bringSubviewToFront(glassHighlightContainerView)
            }
            transition.setFrame(view: glassHighlightContainerView, frame: CGRect(origin: .zero, size: size))
            transition.setCornerRadius(layer: glassHighlightContainerView.layer, cornerRadius: cornerRadius)

            self.glassHighlightRecognizer.highlightContainerView = glassHighlightContainerView
            self.glassHighlightRecognizer.isEnabled = component.isEnabled && !component.displaysProgress
        }

        private func updateGradientBackground(component: ButtonComponent, contentContainerView: UIView, size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
            guard component.background.style != .actualGlass, let gradient = component.background.gradient, gradient.colors.count > 1 else {
                if let gradientBackgroundView = self.gradientBackgroundView {
                    self.gradientBackgroundView = nil
                    if transition.animation.isImmediate {
                        gradientBackgroundView.removeFromSuperview()
                    } else {
                        gradientBackgroundView.layer.animateAlpha(from: gradientBackgroundView.alpha, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak gradientBackgroundView] _ in
                            gradientBackgroundView?.removeFromSuperview()
                        })
                    }
                }
                return
            }

            let gradientBackgroundView: AnimatedGradientBackgroundView
            var gradientTransition = transition
            if let current = self.gradientBackgroundView {
                gradientBackgroundView = current
            } else {
                gradientTransition = .immediate
                gradientBackgroundView = AnimatedGradientBackgroundView(frame: .zero)
                gradientBackgroundView.alpha = 0.0
                self.gradientBackgroundView = gradientBackgroundView
            }

            if gradientBackgroundView.superview !== contentContainerView {
                gradientBackgroundView.removeFromSuperview()
                contentContainerView.insertSubview(gradientBackgroundView, at: 0)
            } else {
                contentContainerView.sendSubviewToBack(gradientBackgroundView)
            }

            gradientBackgroundView.update(size: size, gradient: gradient, cornerRadius: cornerRadius, transition: gradientTransition)
            gradientTransition.setFrame(view: gradientBackgroundView, frame: CGRect(origin: .zero, size: size))
            transition.setAlpha(view: gradientBackgroundView, alpha: 1.0)
        }

        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }

        @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let component = self.component else {
                return
            }
            component.longPressAction?()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }

        func update(component: ButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state

            self.longPressGesture?.isEnabled = component.longPressAction != nil
            
            self.button.isEnabled = (component.isEnabled || component.allowActionWhenDisabled) && !component.displaysProgress
                        
            var contentAlpha: CGFloat = 1.0
            if component.displaysProgress {
                contentAlpha = 0.0
            } else if !component.isEnabled && component.tintWhenDisabled {
                contentAlpha = 0.7
            }
 
            var previousContentItem: ContentItem?
            let contentItem: ContentItem
            var contentItemTransition = component.restrictContentAnimations ? transition.withAnimation(.none) : transition
            if let current = self.contentItem, current.id == component.content.id {
                contentItem = current
            } else {
                contentItemTransition = .immediate
                previousContentItem = self.contentItem
                contentItem = ContentItem(id: component.content.id)
                self.contentItem = contentItem
            }
            
            var cornerRadius: CGFloat = component.background.cornerRadius
            if [.glass, .actualGlass].contains(component.background.style), component.background.cornerRadius == 10.0 {
                cornerRadius = availableSize.height * 0.5
            }
            
            var maxContentWidth = availableSize.width - cornerRadius
            if let contentInsets = component.contentInsets {
                if contentInsets.left == 0.0 && contentInsets.right == 0.0 {
                    maxContentWidth = availableSize.width
                }
            }

            let contentSize = contentItem.view.update(
                transition: contentItemTransition,
                component: component.content.component,
                environment: {},
                containerSize: CGSize(width: maxContentWidth, height: availableSize.height)
            )
            
            var size = availableSize
            if component.fitToContentWidth {
                size.width = floor(contentSize.width + cornerRadius * 1.5)
            }
            
            let contentContainerView: UIView
            switch component.background.style {
            case .actualGlass:
                let glassContainerView: GlassBackgroundView
                if let current = self.glassContainerView {
                    glassContainerView = current
                } else {
                    self.containerView.removeFromSuperview()
                    
                    glassContainerView = GlassBackgroundView()
                    self.glassContainerView = glassContainerView
                    self.insertSubview(glassContainerView, at: 0)
                    
                    glassContainerView.contentView.addSubview(self.button)
                }
                let tintColor: GlassBackgroundView.TintColor
                if component.background.color.alpha < 0.1 {
                    tintColor = .init(kind: .panel)
                } else {
                    tintColor = .init(kind: .panel, innerColor: component.background.color, innerInset: 0.0)
                }
                glassContainerView.update(size: size, cornerRadius: cornerRadius, isDark: component.background.color.brightness < 0.2, tintColor: tintColor, isInteractive: true, transition: transition)
                contentContainerView = glassContainerView.contentView
                                
                transition.setFrame(view: glassContainerView, frame: CGRect(origin: .zero, size: size))
            case .glass, .legacy:
                if self.containerView.superview == nil {
                    self.insertSubview(self.containerView, at: 0)
                    self.addSubview(self.button)
                }
                contentContainerView = self.containerView
                
                if self.backgroundReveal == nil {
                    transition.setBackgroundColor(view: self.containerView, color: component.background.color)
                }
                transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: cornerRadius)
            }
            
            self.updateGradientBackground(component: component, contentContainerView: contentContainerView, size: size, cornerRadius: cornerRadius, transition: transition)

            if component.background.style == .glass, component.background.color.alpha > 1.0 - .ulpOfOne {
                self.updateGlassEffect(component: component, size: size, cornerRadius: cornerRadius, transition: transition)
            } else {
                self.removeGlassEffect(transition: transition)
            }
            
            if let contentView = contentItem.view.view {
                var animateIn = false
                var contentTransition = transition
                if contentView.superview == nil {
                    contentTransition = .immediate
                    animateIn = true
                    contentView.layer.rasterizationScale = UIScreenScale
                    contentView.isUserInteractionEnabled = false
                    contentContainerView.addSubview(contentView)
                    
                    contentItem.view.parentState = state
                }
                let contentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - contentSize.width) * 0.5), y: floorToScreenPixels((size.height - contentSize.height) * 0.5)), size: contentSize)
                
                contentTransition.setFrame(view: contentView, frame: contentFrame)
                contentTransition.setAlpha(view: contentView, alpha: contentAlpha)
                
                if animateIn && previousContentItem != nil && !transition.animation.isImmediate {
                    contentView.layer.shouldRasterize = true
                    contentView.layer.animateScale(from: 0.4, to: 1.0, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                        contentView.layer.shouldRasterize = false
                    })
                    contentView.layer.animateAlpha(from: 0.0, to: contentAlpha, duration: 0.1)
                    contentView.layer.animatePosition(from: CGPoint(x: 0.0, y: -size.height * 0.15), to: CGPoint(), duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                }
            }
            
            if let previousContentItem, let previousContentView = previousContentItem.view.view {
                if !transition.animation.isImmediate {
                    previousContentView.layer.shouldRasterize = true
                    previousContentView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    previousContentView.layer.animateAlpha(from: contentAlpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousContentView] _ in
                        previousContentView?.removeFromSuperview()
                    })
                    previousContentView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: size.height * 0.35), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                } else {
                    previousContentView.removeFromSuperview()
                }
            }
            
            if component.displaysProgress {
                let activityIndicator: ActivityIndicator
                var activityIndicatorTransition = transition
                if let current = self.activityIndicator {
                    activityIndicator = current
                } else {
                    activityIndicatorTransition = .immediate
                    activityIndicator = ActivityIndicator(type: .custom(component.background.foreground, 22.0, 2.0, true))
                    activityIndicator.view.alpha = 0.0
                    self.activityIndicator = activityIndicator
                    contentContainerView.addSubview(activityIndicator.view)
                }
                let indicatorSize = CGSize(width: 22.0, height: 22.0)
                transition.setAlpha(view: activityIndicator.view, alpha: 1.0)
                activityIndicatorTransition.setFrame(view: activityIndicator.view, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - indicatorSize.width) / 2.0), y: floorToScreenPixels((size.height - indicatorSize.height) / 2.0)), size: indicatorSize))
            } else {
                if let activityIndicator = self.activityIndicator {
                    self.activityIndicator = nil
                    transition.setAlpha(view: activityIndicator.view, alpha: 0.0, completion: { [weak activityIndicator] _ in
                        activityIndicator?.view.removeFromSuperview()
                    })
                }
            }
            
            if component.background.isShimmering {
                let shimmeringView: ButtonShimmeringView
                var shimmeringTransition = transition
                if let current = self.shimmeringView {
                    shimmeringView = current
                } else {
                    shimmeringTransition = .immediate
                    shimmeringView = ButtonShimmeringView(frame: .zero)
                    self.shimmeringView = shimmeringView
                    if let gradientBackgroundView = self.gradientBackgroundView, gradientBackgroundView.superview === contentContainerView {
                        contentContainerView.insertSubview(shimmeringView, aboveSubview: gradientBackgroundView)
                    } else {
                        contentContainerView.insertSubview(shimmeringView, at: 0)
                    }
                }
                shimmeringView.update(size: size, background: component.background, cornerRadius: cornerRadius, transition: shimmeringTransition)
                shimmeringTransition.setFrame(view: shimmeringView, frame: CGRect(origin: .zero, size: size))
            } else if let shimmeringView = self.shimmeringView {
                self.shimmeringView = nil
                shimmeringView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                    shimmeringView.removeFromSuperview()
                })
            }
            
            if component.background.style == .glass, component.background.color.alpha > 0.9 {
                let chromeView: UIImageView
                var chromeTransition = transition
                if let current = self.chromeView {
                    chromeView = current
                } else {
                    chromeTransition = .immediate
                    chromeView = UIImageView()
                    self.chromeView = chromeView
                    if let shimmeringView = self.shimmeringView {
                        contentContainerView.insertSubview(chromeView, aboveSubview: shimmeringView)
                    } else if let gradientBackgroundView = self.gradientBackgroundView, gradientBackgroundView.superview === contentContainerView {
                        contentContainerView.insertSubview(chromeView, aboveSubview: gradientBackgroundView)
                    } else {
                        contentContainerView.insertSubview(chromeView, at: 0)
                    }
                    
                    chromeView.layer.compositingFilter = "overlayBlendMode"
                    chromeView.alpha = 0.75
                }
                let chromeTintView: UIImageView
                if let current = self.chromeTintView {
                    chromeTintView = current
                } else {
                    chromeTintView = UIImageView()
                    chromeTintView.alpha = 0.17
                    self.chromeTintView = chromeTintView
                    contentContainerView.insertSubview(chromeTintView, aboveSubview: chromeView)
                }
                let chromeIsDark = component.background.color.lightness < 0.36
                let chromeImageKey = ButtonRimImageKey(size: size, cornerRadius: cornerRadius, isDark: chromeIsDark)
                if self.chromeImageKey != chromeImageKey {
                    self.chromeImageKey = chromeImageKey
                    let rimImage = buttonRimImage(key: chromeImageKey)
                    chromeView.image = rimImage
                    chromeTintView.image = rimImage
                }
                chromeTransition.setFrame(view: chromeView, frame: CGRect(origin: .zero, size: size))
                chromeTransition.setFrame(view: chromeTintView, frame: CGRect(origin: .zero, size: size))
                
                self.containerView.layer.borderWidth = UIScreenPixel
                self.containerView.layer.borderColor = UIColor(white: 0.0, alpha: chromeIsDark ? 0.2 : 0.1).cgColor
            } else if let chromeView = self.chromeView {
                self.chromeView = nil
                self.chromeImageKey = nil
                self.containerView.layer.borderWidth = 0.0
                if let chromeTintView = self.chromeTintView {
                    self.chromeTintView = nil
                    chromeTintView.layer.animateAlpha(from: chromeTintView.alpha, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                        chromeTintView.removeFromSuperview()
                    })
                }
                chromeView.layer.animateAlpha(from: chromeView.alpha, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                    chromeView.removeFromSuperview()
                })
            }
            
            transition.setPosition(view: self.containerView, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
            transition.setBoundsSize(view: self.containerView, size: size)
            
            transition.setFrame(view: self.button, frame: CGRect(origin: .zero, size: size))
            
            if let reveal = self.backgroundReveal {
                self.setBackgroundReveal(from: reveal.from, to: reveal.to, origin: reveal.origin,
                    radius: reveal.radius, progress: reveal.progress, fade: reveal.fade)
            }
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private struct ButtonRimImageKey: Hashable {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let isDark: Bool
    let stretchesHorizontally: Bool
    let stretchesVertically: Bool
    
    init(size: CGSize, cornerRadius: CGFloat, isDark: Bool) {
        let stretchableSize = ButtonRimImageKey.capSize(cornerRadius: cornerRadius) * 2.0 + 1.0
        self.stretchesHorizontally = size.width > stretchableSize
        self.stretchesVertically = size.height > stretchableSize
        self.width = self.stretchesHorizontally ? stretchableSize : size.width
        self.height = self.stretchesVertically ? stretchableSize : size.height
        self.cornerRadius = cornerRadius
        self.isDark = isDark
    }
    
    static func capSize(cornerRadius: CGFloat) -> CGFloat {
        return ceil(cornerRadius * 1.6)
    }
}

private var buttonRimImageCache: [ButtonRimImageKey: UIImage] = [:]

private func buttonRimImage(key: ButtonRimImageKey) -> UIImage? {
    if let image = buttonRimImageCache[key] {
        return image
    }
    let image = generateButtonRimImage(key: key)
    buttonRimImageCache[key] = image
    return image
}

private let buttonRimBands: [(depth: CGFloat, intensity: CGFloat)] = [
    (0.5, 0.5),
    (0.83, 0.38),
    (1.17, 0.255),
    (1.5, 0.14),
    (2.0, 0.06),
    (3.0, 0.041),
    (4.5, 0.023),
    (6.0, 0.008)
]

private func generateButtonRimImage(key: ButtonRimImageKey) -> UIImage? {
    let imageSize = CGSize(width: key.width, height: key.height)
    if imageSize.width <= 0.0 || imageSize.height <= 0.0 {
        return nil
    }
    let bounds = CGRect(origin: .zero, size: imageSize)
    
    let rootLayer = CALayer()
    rootLayer.frame = bounds
    let intensityScale: CGFloat = key.isDark ? 0.5 : 1.0
    var innerIntensity: CGFloat = 0.0
    for band in buttonRimBands.reversed() {
        let target = band.intensity * intensityScale
        let alpha = 1.0 - (1.0 - target) / (1.0 - innerIntensity)
        innerIntensity = target
        
        let layer = CALayer()
        layer.frame = bounds
        layer.cornerRadius = key.cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = band.depth
        layer.borderColor = UIColor(white: 1.0, alpha: max(0.0, alpha)).cgColor
        rootLayer.insertSublayer(layer, at: 0)
    }
    
    let image = generateImage(imageSize, rotatedContext: { size, context in
        context.clear(bounds)
        rootLayer.render(in: context)
        
        let capWidth = min(key.cornerRadius, size.width * 0.5)
        let steps = 16
        var locations: [CGFloat] = []
        var colors: [CGColor] = []
        for i in 0 ... steps {
            let x = capWidth * CGFloat(i) / CGFloat(steps)
            let distance = (capWidth - x) / max(1.0, capWidth)
            let verticalFacing = sqrt(max(0.0, 1.0 - distance * distance))
            locations.append(x / size.width)
            colors.append(UIColor(white: 1.0, alpha: pow(verticalFacing, 3.0)).cgColor)
        }
        for i in (0 ... steps).reversed() {
            locations.append(1.0 - locations[i])
            colors.append(colors[i])
        }
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: &locations) {
            context.setBlendMode(.destinationIn)
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: size.width, y: 0.0), options: [])
        }
    })
    
    let capSize = Int(ButtonRimImageKey.capSize(cornerRadius: key.cornerRadius))
    let capWidth = key.stretchesHorizontally ? capSize : 0
    let capHeight = key.stretchesVertically ? capSize : 0
    if capWidth == 0 && capHeight == 0 {
        return image
    }
    return image?.stretchableImage(withLeftCapWidth: capWidth, topCapHeight: capHeight)
}

private final class AnimatedGradientBackgroundView: UIView {
    private let backgroundView: UIImageView
    private var animationView: UIImageView?

    private var currentGradient: ButtonComponent.Background.Gradient?
    private var currentImageHeight: CGFloat?

    override init(frame: CGRect) {
        self.backgroundView = UIImageView()
        self.backgroundView.clipsToBounds = true

        super.init(frame: frame)

        self.clipsToBounds = true
        self.isUserInteractionEnabled = false

        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
            self.backgroundView.layer.cornerCurve = .continuous
        }

        self.addSubview(self.backgroundView)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func update(size: CGSize, gradient: ButtonComponent.Background.Gradient, cornerRadius: CGFloat, transition: ComponentTransition) {
        let bounds = CGRect(origin: .zero, size: size)

        transition.setCornerRadius(layer: self.layer, cornerRadius: cornerRadius)
        transition.setCornerRadius(layer: self.backgroundView.layer, cornerRadius: cornerRadius)
        transition.setFrame(view: self.backgroundView, frame: bounds)

        let imageHeight = max(1.0, size.height)
        if self.currentGradient != gradient || self.currentImageHeight != imageHeight || self.backgroundView.image == nil {
            var locations: [CGFloat] = []
            let delta = 1.0 / CGFloat(gradient.colors.count - 1)
            for i in 0 ..< gradient.colors.count {
                locations.append(delta * CGFloat(i))
            }

            let image = generateGradientImage(size: CGSize(width: 200.0, height: imageHeight), colors: gradient.colors, locations: locations, direction: .horizontal)
            self.backgroundView.image = image
            self.animationView?.image = image
            self.animationView?.layer.removeAnimation(forKey: "movement")

            self.currentGradient = gradient
            self.currentImageHeight = imageHeight
        }

        let animationView: UIImageView
        if let current = self.animationView {
            animationView = current
        } else {
            animationView = UIImageView()
            animationView.image = self.backgroundView.image
            self.animationView = animationView
            self.backgroundView.addSubview(animationView)
        }

        animationView.bounds = CGRect(origin: .zero, size: CGSize(width: size.width * 2.4, height: size.height))
        if animationView.layer.animation(forKey: "movement") == nil {
            animationView.center = CGPoint(x: animationView.bounds.width / 2.0 - animationView.bounds.width * 0.35, y: size.height / 2.0)
        }
        self.setupGradientAnimations(size: size, gradient: gradient)
    }

    private func setupGradientAnimations(size: CGSize, gradient: ButtonComponent.Background.Gradient) {
        guard let animationView = self.animationView else {
            return
        }

        let duration: Double
        switch gradient.animation {
        case let .horizontalShift(value):
            duration = value
        }

        if animationView.layer.animation(forKey: "movement") == nil {
            let offset = (animationView.bounds.width - size.width) / 2.0
            let previousValue = animationView.center.x
            var newValue: CGFloat = offset
            if offset - previousValue < animationView.bounds.width * 0.25 {
                newValue -= animationView.bounds.width * 0.35
            }
            animationView.center = CGPoint(x: newValue, y: animationView.bounds.height / 2.0)

            CATransaction.begin()

            let animation = CABasicAnimation(keyPath: "position.x")
            animation.duration = duration
            animation.fromValue = previousValue
            animation.toValue = newValue
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            CATransaction.setCompletionBlock { [weak self] in
                self?.setupGradientAnimations(size: size, gradient: gradient)
            }

            animationView.layer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }
}

private class ButtonShimmeringView: UIView {
    private var shimmerView = ShimmerEffectForegroundView()
    private var borderView = UIView()
    private var borderMaskView = UIView()
    private var borderShimmerView = ShimmerEffectForegroundView()
    
    override init(frame: CGRect) {
        self.borderView.isUserInteractionEnabled = false
        
        self.borderMaskView.layer.borderWidth = 1.0 + UIScreenPixel
        self.borderMaskView.layer.borderColor = UIColor.white.cgColor
        self.borderView.mask = self.borderMaskView
        
        self.borderView.addSubview(self.borderShimmerView)
        
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        
        self.addSubview(self.shimmerView)
        self.addSubview(self.borderView)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    func update(size: CGSize, background: ButtonComponent.Background, cornerRadius: CGFloat, transition: ComponentTransition) {
        let color = background.foreground
        
        let alpha: CGFloat
        let borderAlpha: CGFloat
        let compositingFilter: String?
        if color.lightness > 0.5 {
            alpha = 0.5
            borderAlpha = 0.75
            compositingFilter = "overlayBlendMode"
        } else {
            alpha = 0.2
            borderAlpha = 0.3
            compositingFilter = nil
        }
        
        if let gradient = background.gradient, gradient.colors.count > 1 {
            self.backgroundColor = .clear
        } else {
            self.backgroundColor = background.color
        }
        self.layer.cornerRadius = cornerRadius
        self.borderMaskView.layer.cornerRadius = cornerRadius
        
        self.shimmerView.update(backgroundColor: .clear, foregroundColor: color.withAlphaComponent(alpha), gradientSize: 70.0, globalTimeOffset: false, duration: 4.0, horizontal: true)
        self.shimmerView.layer.compositingFilter = compositingFilter
        
        self.borderShimmerView.update(backgroundColor: .clear, foregroundColor: color.withAlphaComponent(borderAlpha), gradientSize: 70.0, globalTimeOffset: false, duration: 4.0, horizontal: true)
        self.borderShimmerView.layer.compositingFilter = compositingFilter
        
        let bounds = CGRect(origin: .zero, size: size)
        transition.setFrame(view: self.shimmerView, frame: bounds)
        transition.setFrame(view: self.borderView, frame: bounds)
        transition.setFrame(view: self.borderMaskView, frame: bounds)
        transition.setFrame(view: self.borderShimmerView, frame: bounds)
        
        self.shimmerView.updateAbsoluteRect(CGRect(origin: CGPoint(x: size.width * 4.0, y: 0.0), size: size), within: CGSize(width: size.width * 9.0, height: size.height))
        self.borderShimmerView.updateAbsoluteRect(CGRect(origin: CGPoint(x: size.width * 4.0, y: 0.0), size: size), within: CGSize(width: size.width * 9.0, height: size.height))
    }
}
