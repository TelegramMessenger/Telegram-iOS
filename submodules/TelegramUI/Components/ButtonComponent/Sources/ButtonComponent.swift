import Foundation
import UIKit
import Display
import ComponentFlow
import AnimatedTextComponent
import ActivityIndicator

public final class ButtonBadgeComponent: Component {
    let fillColor: UIColor
    let content: AnyComponent<Empty>
    
    public init(
        fillColor: UIColor,
        content: AnyComponent<Empty>
    ) {
        self.fillColor = fillColor
        self.content = content
    }
    
    public static func ==(lhs: ButtonBadgeComponent, rhs: ButtonBadgeComponent) -> Bool {
        if lhs.fillColor != rhs.fillColor {
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
        
        public func update(component: ButtonBadgeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let height: CGFloat = 20.0
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
                transition.setFrame(view: contentView, frame: CGRect(origin: CGPoint(x: floor((backgroundFrame.width - contentSize.width) * 0.5), y: floor((backgroundFrame.height - contentSize.height) * 0.5)), size: contentSize))
            }
            
            if themeUpdated || backgroundFrame.height != self.backgroundView.image?.size.height {
                self.backgroundView.image = generateStretchableFilledCircleImage(diameter: backgroundFrame.height, color: component.fillColor)
            }
            
            return backgroundFrame.size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ButtonTextContentComponent: Component {
    public let text: String
    public let badge: Int
    public let textColor: UIColor
    public let badgeBackground: UIColor
    public let badgeForeground: UIColor
    
    public init(
        text: String,
        badge: Int,
        textColor: UIColor,
        badgeBackground: UIColor,
        badgeForeground: UIColor
    ) {
        self.text = text
        self.badge = badge
        self.textColor = textColor
        self.badgeBackground = badgeBackground
        self.badgeForeground = badgeForeground
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
        if lhs.badgeBackground != rhs.badgeBackground {
            return false
        }
        if lhs.badgeForeground != rhs.badgeForeground {
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

        func update(component: ButtonTextContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousBadge = self.component?.badge
            
            self.component = component
            self.componentState = state
            
            let badgeSpacing: CGFloat = 6.0
            
            let contentSize = self.content.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: component.text,
                    font: Font.semibold(17.0),
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
                badgeSize = badge.update(
                    transition: badgeTransition,
                    component: AnyComponent(ButtonBadgeComponent(
                        fillColor: component.badgeBackground,
                        content: AnyComponent(AnimatedTextComponent(
                            font: Font.semibold(15.0),
                            color: component.badgeForeground,
                            items: [
                                AnimatedTextComponent.Item(id: AnyHashable(0), content: .number(component.badge))
                            ]
                        ))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
            }
            
            var size = contentSize
            if let badgeSize {
                //size.width += badgeSpacing
                //size.width += badgeSize.width
                size.height = max(size.height, badgeSize.height)
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) * 0.5), y: floor((size.height - contentSize.height) * 0.5)), size: contentSize)
            
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: contentFrame)
            }
            
            if let badgeSize, let badge = self.badge {
                let badgeFrame = CGRect(origin: CGPoint(x: contentFrame.maxX + badgeSpacing, y: floor((size.height - badgeSize.height) * 0.5) + 1.0), size: badgeSize)
                
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

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class ButtonComponent: Component {
    public struct Background: Equatable {
        public var color: UIColor
        public var foreground: UIColor
        public var pressedColor: UIColor
        public var cornerRadius: CGFloat

        public init(
            color: UIColor,
            foreground: UIColor,
            pressedColor: UIColor,
            cornerRadius: CGFloat = 10.0
        ) {
            self.color = color
            self.foreground = foreground
            self.pressedColor = pressedColor
            self.cornerRadius = cornerRadius
        }
    }

    public let background: Background
    public let content: AnyComponentWithIdentity<Empty>
    public let isEnabled: Bool
    public let displaysProgress: Bool
    public let action: () -> Void
    
    public init(
        background: Background,
        content: AnyComponentWithIdentity<Empty>,
        isEnabled: Bool,
        displaysProgress: Bool,
        action: @escaping () -> Void
    ) {
        self.background = background
        self.content = content
        self.isEnabled = isEnabled
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

        func update(component: ButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.componentState = state
            
            self.isEnabled = component.isEnabled && !component.displaysProgress
            
            transition.setBackgroundColor(view: self, color: component.background.color)
            transition.setCornerRadius(layer: self.layer, cornerRadius: component.background.cornerRadius)
            
            var contentAlpha: CGFloat = 1.0
            if component.displaysProgress {
                contentAlpha = 0.0
            } else if !component.isEnabled {
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
                let contentFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - contentSize.width) * 0.5), y: floor((availableSize.height - contentSize.height) * 0.5)), size: contentSize)
                
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
                activityIndicatorTransition.setFrame(view: activityIndicator.view, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - indicatorSize.width) / 2.0), y: floor((availableSize.height - indicatorSize.height) / 2.0)), size: indicatorSize))
            } else {
                if let activityIndicator = self.activityIndicator {
                    self.activityIndicator = nil
                    transition.setAlpha(view: activityIndicator.view, alpha: 0.0, completion: { [weak activityIndicator] _ in
                        activityIndicator?.view.removeFromSuperview()
                    })
                }
            }
            
            return availableSize
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
