import Foundation
import UIKit
import Display
import ComponentFlow
import AnimatedTextComponent
import ActivityIndicator
import BundleIconComponent
import ShimmerEffect

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
                let badgeFrame = CGRect(origin: CGPoint(x: contentFrame.minX + contentSize.width + badgeSpacing, y: floorToScreenPixels((size.height - badgeSize.height) * 0.5) + 1.0), size: badgeSize)
                
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
        public var color: UIColor
        public var foreground: UIColor
        public var pressedColor: UIColor
        public var cornerRadius: CGFloat
        public var isShimmering: Bool

        public init(
            color: UIColor,
            foreground: UIColor,
            pressedColor: UIColor,
            cornerRadius: CGFloat = 10.0,
            isShimmering: Bool = false
        ) {
            self.color = color
            self.foreground = foreground
            self.pressedColor = pressedColor
            self.cornerRadius = cornerRadius
            self.isShimmering = isShimmering
        }
        
        public func withIsShimmering(_ isShimmering: Bool) -> Background {
            return Background(
                color: self.color,
                foreground: self.foreground,
                pressedColor: self.pressedColor,
                cornerRadius: self.cornerRadius,
                isShimmering: isShimmering
            )
        }
    }

    public let background: Background
    public let content: AnyComponentWithIdentity<Empty>
    public let isEnabled: Bool
    public let tintWhenDisabled: Bool
    public let allowActionWhenDisabled: Bool
    public let displaysProgress: Bool
    public let action: () -> Void
    
    public init(
        background: Background,
        content: AnyComponentWithIdentity<Empty>,
        isEnabled: Bool,
        tintWhenDisabled: Bool = true,
        allowActionWhenDisabled: Bool = false,
        displaysProgress: Bool,
        action: @escaping () -> Void
    ) {
        self.background = background
        self.content = content
        self.isEnabled = isEnabled
        self.tintWhenDisabled = tintWhenDisabled
        self.allowActionWhenDisabled = allowActionWhenDisabled
        self.displaysProgress = displaysProgress
        self.action = action
    }

    public static func ==(lhs: ButtonComponent, rhs: ButtonComponent) -> Bool {
        if lhs.background != rhs.background {
            return false
        }
        if lhs.content != rhs.content {
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
        return true
    }

    private final class ContentItem {
        let id: AnyHashable
        let view = ComponentView<Empty>()

        init(id: AnyHashable) {
            self.id = id
        }
    }

    public final class View: HighlightTrackingButton {
        private var component: ButtonComponent?
        private weak var componentState: EmptyComponentState?

        private var shimmeringView: ButtonShimmeringView?
        private var contentItem: ContentItem?
        
        private var activityIndicator: ActivityIndicator?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, let component = self.component, component.isEnabled {
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.alpha = 0.7
                    } else {
                        self.alpha = 1.0
                        self.layer.animateAlpha(from: 7, to: 1.0, duration: 0.2)
                    }
                }
            }
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }

        func update(component: ButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
            
            self.isEnabled = (component.isEnabled || component.allowActionWhenDisabled) && !component.displaysProgress
            
            transition.setBackgroundColor(view: self, color: component.background.color)
            transition.setCornerRadius(layer: self.layer, cornerRadius: component.background.cornerRadius)
            
            var contentAlpha: CGFloat = 1.0
            if component.displaysProgress {
                contentAlpha = 0.0
            } else if !component.isEnabled && component.tintWhenDisabled {
                contentAlpha = 0.7
            }
 
            var previousContentItem: ContentItem?
            let contentItem: ContentItem
            var contentItemTransition = transition
            if let current = self.contentItem, current.id == component.content.id {
                contentItem = current
            } else {
                contentItemTransition = .immediate
                previousContentItem = self.contentItem
                contentItem = ContentItem(id: component.content.id)
                self.contentItem = contentItem
            }

            let contentSize = contentItem.view.update(
                transition: contentItemTransition,
                component: component.content.component,
                environment: {},
                containerSize: availableSize
            )
            if let contentView = contentItem.view.view {
                var animateIn = false
                var contentTransition = transition
                if contentView.superview == nil {
                    contentTransition = .immediate
                    animateIn = true
                    contentView.isUserInteractionEnabled = false
                    self.addSubview(contentView)
                }
                let contentFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - contentSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - contentSize.height) * 0.5)), size: contentSize)
                
                contentTransition.setFrame(view: contentView, frame: contentFrame)
                contentTransition.setAlpha(view: contentView, alpha: contentAlpha)
                
                if animateIn && previousContentItem != nil && !transition.animation.isImmediate {
                    contentView.layer.animateScale(from: 0.4, to: 1.0, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring)
                    contentView.layer.animateAlpha(from: 0.0, to: contentAlpha, duration: 0.1)
                    contentView.layer.animatePosition(from: CGPoint(x: 0.0, y: -availableSize.height * 0.15), to: CGPoint(), duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                }
            }
            
            if let previousContentItem, let previousContentView = previousContentItem.view.view {
                if !transition.animation.isImmediate {
                    previousContentView.layer.animateScale(from: 1.0, to: 0.0, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    previousContentView.layer.animateAlpha(from: contentAlpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousContentView] _ in
                        previousContentView?.removeFromSuperview()
                    })
                    previousContentView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: availableSize.height * 0.35), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
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
                    self.addSubview(activityIndicator.view)
                }
                let indicatorSize = CGSize(width: 22.0, height: 22.0)
                transition.setAlpha(view: activityIndicator.view, alpha: 1.0)
                activityIndicatorTransition.setFrame(view: activityIndicator.view, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - indicatorSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - indicatorSize.height) / 2.0)), size: indicatorSize))
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
                    self.insertSubview(shimmeringView, at: 0)
                }
                shimmeringView.update(size: availableSize, background: component.background, cornerRadius: component.background.cornerRadius, transition: shimmeringTransition)
                shimmeringTransition.setFrame(view: shimmeringView, frame: CGRect(origin: .zero, size: availableSize))
            } else if let shimmeringView = self.shimmeringView {
                self.shimmeringView = nil
                shimmeringView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                    shimmeringView.removeFromSuperview()
                })
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
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
        
        self.backgroundColor = background.color
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
