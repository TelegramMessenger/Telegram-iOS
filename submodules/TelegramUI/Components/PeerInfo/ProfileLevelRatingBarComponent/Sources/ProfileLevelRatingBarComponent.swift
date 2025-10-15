import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import HierarchyTrackingLayer

public final class ProfileLevelRatingBarComponent: Component {
    public final class TransitionHint {
        public let animate: Bool
        
        public init(animate: Bool) {
            self.animate = animate
        }
    }
    
    public enum Icon {
        case rating
        case stars
    }
    
    let theme: PresentationTheme
    let value: CGFloat
    let leftLabel: String
    let rightLabel: String
    let badgeValue: String
    let badgeTotal: String?
    let level: Int
    let icon: Icon
    let inversed: Bool
    
    public init(
        theme: PresentationTheme,
        value: CGFloat,
        leftLabel: String,
        rightLabel: String,
        badgeValue: String,
        badgeTotal: String?,
        level: Int,
        icon: Icon,
        inversed: Bool = false
    ) {
        self.theme = theme
        self.value = value
        self.leftLabel = leftLabel
        self.rightLabel = rightLabel
        self.badgeValue = badgeValue
        self.badgeTotal = badgeTotal
        self.level = level
        self.icon = icon
        self.inversed = inversed
    }
    
    public static func ==(lhs: ProfileLevelRatingBarComponent, rhs: ProfileLevelRatingBarComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.leftLabel != rhs.leftLabel {
            return false
        }
        if lhs.rightLabel != rhs.rightLabel {
            return false
        }
        if lhs.badgeValue != rhs.badgeValue {
            return false
        }
        if lhs.badgeTotal != rhs.badgeTotal {
            return false
        }
        if lhs.level != rhs.level {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.inversed != rhs.inversed {
            return false
        }
        return true
    }
    
    private final class AnimationState {
        enum Wraparound {
            case left
            case right
        }
        
        let fromLevel: Int
        let toLevel: Int
        let fromLeftLabelText: String
        let fromRightLabelText: String
        let fromValue: CGFloat
        let toValue: CGFloat
        let fromBadgeSize: CGSize
        let startTime: Double
        let duration: Double
        let wraparound: Wraparound?
        
        init(fromLevel: Int, toLevel: Int, fromLeftLabelText: String, fromRightLabelText: String, fromValue: CGFloat, toValue: CGFloat, fromBadgeSize: CGSize, startTime: Double, duration: Double, wraparound: Wraparound?) {
            self.fromLevel = fromLevel
            self.toLevel = toLevel
            self.fromLeftLabelText = fromLeftLabelText
            self.fromRightLabelText = fromRightLabelText
            self.fromValue = fromValue
            self.toValue = toValue
            self.fromBadgeSize = fromBadgeSize
            self.startTime = startTime
            self.duration = duration
            self.wraparound = wraparound
        }
        
        func timeFraction(at timestamp: Double) -> CGFloat {
            var fraction = CGFloat((timestamp - self.startTime) / self.duration)
            fraction = max(0.0, min(1.0, fraction))
            return fraction
        }
        
        func stepFraction(at timestamp: Double) -> (step: Int, fraction: CGFloat) {
            if self.wraparound != nil {
                var t = self.timeFraction(at: timestamp)
                t = bezierPoint(0.6, 0.0, 0.4, 1.0, t)
                if t < 0.5 {
                    let vt = t / 0.5
                    return (0, vt)
                } else {
                    let vt = (t - 0.5) / 0.5
                    return (1, vt)
                }
            } else {
                let t = self.timeFraction(at: timestamp)
                return (0, listViewAnimationCurveSystem(t))
            }
        }
        
        func fraction(at timestamp: Double) -> CGFloat {
            let t = self.timeFraction(at: timestamp)
            if self.wraparound != nil {
                return listViewAnimationCurveEaseInOut(t)
            } else {
                return listViewAnimationCurveSystem(t)
            }
        }
        
        func value(at timestamp: Double) -> CGFloat {
            let fraction = self.fraction(at: timestamp)
            return (1.0 - fraction) * self.fromValue + fraction * self.toValue
        }
        
        func wrapAroundValue(at timestamp: Double, bottomValue: CGFloat, topValue: CGFloat) -> CGFloat {
            let (step, fraction) = self.stepFraction(at: timestamp)
            if step == 0 {
                return (1.0 - fraction) * self.fromValue + fraction * topValue
            } else {
                return (1.0 - fraction) * bottomValue + fraction * self.toValue
            }
        }
        
        func badgeSize(at timestamp: Double, endValue: CGSize) -> CGSize {
            let fraction = self.fraction(at: timestamp)
            return CGSize(
                width: (1.0 - fraction) * self.fromBadgeSize.width + fraction * endValue.width,
                height: endValue.height
            )
        }
    }
    
    public final class View: UIView {
        private let barBackground: UIImageView
        private let backgroundClippingContainer: UIView
        private let foregroundBarClippingContainer: UIView
        private let foregroundClippingContainer: UIView
        private let barForeground: UIImageView
        
        private let backgroundLeftLabel = ComponentView<Empty>()
        private let backgroundRightLabel = ComponentView<Empty>()
        private let foregroundLeftLabel = ComponentView<Empty>()
        private let foregroundRightLabel = ComponentView<Empty>()
        
        private let badge = ComponentView<Empty>()
        
        private var component: ProfileLevelRatingBarComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var hierarchyTracker: HierarchyTrackingLayer?
        private var animationLink: SharedDisplayLinkDriver.Link?
        private var badgePhysicsLink: SharedDisplayLinkDriver.Link?
        
        private var animationState: AnimationState?
        
        private var previousAnimationTimestamp: Double?
        private var previousAnimationTimeFraction: CGFloat?
        private var animationDeltaTime: Double?
        private var animationIsMovingOverStep: Bool = false
        
        private var badgeAngularSpeed: CGFloat = 0.0
        private var badgeScale: CGFloat = 1.0
        private var badgeAngle: CGFloat = 0.0
        private var previousPhysicsTimestamp: Double?
        
        private var testFraction: CGFloat?
        private var startTestFraction: CGFloat?
        
        override init(frame: CGRect) {
            self.barBackground = UIImageView()
            self.backgroundClippingContainer = UIView()
            self.backgroundClippingContainer.clipsToBounds = true
            self.foregroundBarClippingContainer = UIView()
            self.foregroundBarClippingContainer.clipsToBounds = true
            self.foregroundClippingContainer = UIView()
            self.foregroundClippingContainer.clipsToBounds = true
            self.barForeground = UIImageView()
            
            super.init(frame: frame)
            
            let hierarchyTracker = HierarchyTrackingLayer()
            self.hierarchyTracker = hierarchyTracker
            self.layer.addSublayer(hierarchyTracker)
            
            self.hierarchyTracker?.isInHierarchyUpdated = { [weak self] value in
                guard let self else {
                    return
                }
                self.updateAnimations()
                
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
            
            #if DEBUG
            self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.onPanGesture(_:))))
            #endif
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc private func onPanGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                if self.testFraction == nil {
                    self.testFraction = self.component?.value
                }
                if self.startTestFraction == nil {
                    if let testFraction = self.testFraction {
                        self.startTestFraction = testFraction
                    }
                }
                if let startTestFraction = self.startTestFraction {
                    let x = recognizer.translation(in: self).x
                    var value: CGFloat = startTestFraction + x / self.bounds.width
                    value = max(0.0, min(1.0, value))
                    self.testFraction = value
                    self.state?.updated(transition: .immediate, isLocal: true)
                }
            case .ended, .cancelled:
                self.startTestFraction = nil
            default:
                break
            }
        }
        
        private func updateAnimations() {
            let timestamp = CACurrentMediaTime()
            let deltaTime: CGFloat
            if let previousAnimationTimestamp = self.previousAnimationTimestamp {
                deltaTime = min(0.2, timestamp - previousAnimationTimestamp)
            } else {
                deltaTime = 1.0 / 60.0
            }
            
            if let hierarchyTracker = self.hierarchyTracker, hierarchyTracker.isInHierarchy {
                if self.animationState != nil {
                    if self.animationLink == nil {
                        self.animationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                            guard let self else {
                                return
                            }
                            self.updateAnimations()
                        })
                    }
                } else {
                    self.animationLink?.invalidate()
                    self.animationLink = nil
                    self.animationState = nil
                }
            } else {
                self.animationLink?.invalidate()
                self.animationLink = nil
                self.animationState = nil
            }
            
            if let animationState = self.animationState {
                let timeFraction = animationState.timeFraction(at: timestamp)
                if timeFraction >= 1.0 {
                    self.animationState = nil
                    self.updateAnimations()
                    return
                } else {
                    if let previousAnimationTimeFraction = self.previousAnimationTimeFraction {
                        if previousAnimationTimeFraction < 0.5 && timeFraction >= 0.5 {
                            self.animationIsMovingOverStep = true
                        }
                    }
                    self.previousAnimationTimeFraction = timeFraction
                }
            } else {
                self.previousAnimationTimeFraction = nil
            }
            
            self.animationDeltaTime = Double(deltaTime)
            
            if self.animationState != nil && !self.isUpdating {
                self.state?.updated(transition: .immediate, isLocal: true)
            }
            
            self.animationDeltaTime = nil
            self.animationIsMovingOverStep = false
        }
        
        private func addBadgeDeltaX(value: CGFloat, deltaTime: CGFloat) {
            var deltaTime = deltaTime
            deltaTime /= UIView.animationDurationFactor()
            let horizontalVelocity = value / deltaTime
            var badgeAngle = self.badgeAngle
            badgeAngle -= horizontalVelocity * 0.00005
            let maxAngle: CGFloat = 0.1
            if abs(badgeAngle) > maxAngle {
                badgeAngle = badgeAngle < 0.0 ? -maxAngle : maxAngle
            }
            self.badgeAngle = badgeAngle
        }
        
        private func updateBadgePhysics() {
            let timestamp = CACurrentMediaTime()
            
            var deltaTime: CGFloat
            if let previousPhysicsTimestamp = self.previousPhysicsTimestamp {
                deltaTime = CGFloat(min(1.0 / 60.0, timestamp - previousPhysicsTimestamp))
            } else {
                deltaTime = CGFloat(1.0 / 60.0)
            }
            self.previousPhysicsTimestamp = timestamp
            deltaTime /= UIView.animationDurationFactor()
            
            let testSpringFriction: CGFloat = 18.5
            let testSpringConstant: CGFloat = 243.0
            
            let frictionConstant: CGFloat = testSpringFriction
            let springConstant: CGFloat = testSpringConstant
            let time: CGFloat = deltaTime
            
            var badgeAngle = self.badgeAngle
            
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
                self.updateBadgeTransform()
            }
        }
        
        private func updateBadgeTransform() {
            guard let badgeView = self.badge.view else {
                return
            }
            var transform = CATransform3DIdentity
            transform = CATransform3DScale(transform, self.badgeScale, self.badgeScale, 1.0)
            transform = CATransform3DRotate(transform, self.badgeAngle, 0.0, 0.0, 1.0)
            badgeView.layer.transform = transform
        }
        
        func update(component: ProfileLevelRatingBarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let barHeight: CGFloat = 30.0
            
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            var labelsTransition = transition
            if let previousComponent = self.component, let hint = transition.userData(TransitionHint.self), hint.animate {
                labelsTransition = .spring(duration: 0.5)
                
                var fromLevel = previousComponent.level
                var fromLeftLabelText = previousComponent.leftLabel
                var fromRightLabelText = previousComponent.rightLabel
                let toLevel: Int = component.level
                let fromValue: CGFloat
                if let animationState = self.animationState {
                    if let wraparound = animationState.wraparound {
                        let wraparoundEnd: CGFloat
                        switch wraparound {
                        case .left:
                            wraparoundEnd = 0.0
                        case .right:
                            wraparoundEnd = 1.0
                        }
                        if animationState.stepFraction(at: CACurrentMediaTime()).step == 0 {
                            fromLevel = animationState.fromLevel
                            fromLeftLabelText = animationState.fromLeftLabelText
                            fromRightLabelText = animationState.fromRightLabelText
                        }
                        fromValue = animationState.wrapAroundValue(at: CACurrentMediaTime(), bottomValue: 1.0 - wraparoundEnd, topValue: wraparoundEnd)
                    } else {
                        fromValue = animationState.value(at: CACurrentMediaTime())
                    }
                } else {
                    fromValue = previousComponent.value
                }
                let fromBadgeSize: CGSize
                if let badgeView = self.badge.view as? ProfileLevelRatingBarBadge.View {
                    fromBadgeSize = badgeView.bounds.size
                } else {
                    fromBadgeSize = CGSize()
                }
                var wraparound: AnimationState.Wraparound?
                var duration = 0.4
                if previousComponent.level != component.level {
                    wraparound = component.level > previousComponent.level ? .right : .left
                    duration = 0.8
                }
                self.animationState = AnimationState(
                    fromLevel: fromLevel,
                    toLevel: toLevel,
                    fromLeftLabelText: fromLeftLabelText,
                    fromRightLabelText: fromRightLabelText,
                    fromValue: fromValue,
                    toValue: component.value,
                    fromBadgeSize: fromBadgeSize,
                    startTime: CACurrentMediaTime(),
                    duration: duration * UIView.animationDurationFactor(),
                    wraparound: wraparound
                )
                self.updateAnimations()
            }
            
            self.component = component
            self.state = state
            
            if self.barBackground.image == nil {
                self.barBackground.image = generateStretchableFilledCircleImage(diameter: 12.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                self.barForeground.image = self.barBackground.image
            }
            
            if self.barBackground.superview == nil {
                self.addSubview(self.barBackground)
                self.addSubview(self.backgroundClippingContainer)
                
                self.addSubview(self.foregroundBarClippingContainer)
                self.foregroundBarClippingContainer.addSubview(self.barForeground)
                
                self.addSubview(self.foregroundClippingContainer)
            }
            
            let progressValue: CGFloat
            if let testFraction = self.testFraction {
                progressValue = testFraction
            } else {
                progressValue = component.value
            }
            
            let barBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - barHeight), size: CGSize(width: availableSize.width, height: barHeight))
            transition.setFrame(view: self.barBackground, frame: barBackgroundFrame)
            
            let barForegroundOriginX = barBackgroundFrame.minX
            let barForegroundWidth = floorToScreenPixels(progressValue * barBackgroundFrame.width)
            var barForegroundFrame = CGRect(origin: CGPoint(x: barForegroundOriginX, y: barBackgroundFrame.minY), size: CGSize(width: barForegroundWidth, height: barBackgroundFrame.height))
            
            var foregroundAlpha: CGFloat = 1.0
            var foregroundContentsAlpha: CGFloat = 1.0
            var badgeScale: CGFloat = 1.0
            var currentIsNegativeRating: Bool = component.level < 0
            var leftLabelText = component.leftLabel
            var rightLabelText = component.rightLabel
            
            if let animationState = self.animationState {
                if let wraparound = animationState.wraparound {
                    let (step, progress) = animationState.stepFraction(at: CACurrentMediaTime())
                    if step == 0 {
                        currentIsNegativeRating = animationState.fromLevel < 0
                        leftLabelText = animationState.fromLeftLabelText
                        rightLabelText = animationState.fromRightLabelText
                    } else {
                        currentIsNegativeRating = animationState.toLevel < 0
                    }
                    let wraparoundEnd: CGFloat
                    switch wraparound {
                    case .left:
                        wraparoundEnd = 0.0
                        if step == 0 {
                            foregroundContentsAlpha = 1.0 * (1.0 - progress)
                            badgeScale = 1.0 * (1.0 - progress) + 0.3 * progress
                        } else {
                            foregroundAlpha = 1.0 * progress
                            foregroundContentsAlpha = foregroundAlpha
                            badgeScale = 1.0 * progress + 0.3 * (1.0 - progress)
                        }
                    case .right:
                        wraparoundEnd = 1.0
                        if step == 0 {
                            foregroundAlpha = 1.0 * (1.0 - progress)
                            foregroundContentsAlpha = foregroundAlpha
                            badgeScale = 1.0 * (1.0 - progress) + 0.3 * progress
                        } else {
                            foregroundContentsAlpha = 1.0 * progress
                            badgeScale = 1.0 * progress + 0.3 * (1.0 - progress)
                        }
                    }
                    
                    let progressValue = animationState.wrapAroundValue(at: CACurrentMediaTime(), bottomValue: 1.0 - wraparoundEnd, topValue: wraparoundEnd)
                    barForegroundFrame = CGRect(origin: barBackgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progressValue * barBackgroundFrame.width), height: barBackgroundFrame.height))
                } else {
                    let progressValue = animationState.value(at: CACurrentMediaTime())
                    barForegroundFrame = CGRect(origin: barBackgroundFrame.origin, size: CGSize(width: floorToScreenPixels(progressValue * barBackgroundFrame.width), height: barBackgroundFrame.height))
                }
            }
            
            let badgeColor: UIColor
            if currentIsNegativeRating {
                badgeColor = UIColor(rgb: 0xFF3B30)
            } else {
                badgeColor = component.theme.list.itemCheckColors.fillColor
            }
            
            self.barBackground.tintColor = component.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.5)
            self.barForeground.tintColor = badgeColor
            
            var effectiveBarForegroundFrame = barForegroundFrame
            if currentIsNegativeRating || component.inversed {
                effectiveBarForegroundFrame.size.width = barBackgroundFrame.maxX - barForegroundFrame.maxX
                effectiveBarForegroundFrame.origin.x = barBackgroundFrame.maxX - effectiveBarForegroundFrame.width
            }
            transition.setPosition(view: self.foregroundBarClippingContainer, position: effectiveBarForegroundFrame.center)
            transition.setBounds(view: self.foregroundBarClippingContainer, bounds: CGRect(origin: CGPoint(x: effectiveBarForegroundFrame.minX - barForegroundFrame.minX, y: 0.0), size: effectiveBarForegroundFrame.size))
            transition.setPosition(view: self.foregroundClippingContainer, position: effectiveBarForegroundFrame.center)
            transition.setBounds(view: self.foregroundClippingContainer, bounds: CGRect(origin: CGPoint(x: effectiveBarForegroundFrame.minX - barForegroundFrame.minX, y: 0.0), size: effectiveBarForegroundFrame.size))
            
            transition.setAlpha(view: self.foregroundBarClippingContainer, alpha: foregroundAlpha)
            transition.setAlpha(view: self.foregroundClippingContainer, alpha: foregroundContentsAlpha)
            
            let backgroundClippingFrame: CGRect
            if currentIsNegativeRating || component.inversed {
                backgroundClippingFrame = CGRect(
                    x: barBackgroundFrame.minX,
                    y: barBackgroundFrame.minY,
                    width: max(0.0, effectiveBarForegroundFrame.minX - barBackgroundFrame.minX),
                    height: barBackgroundFrame.height
                )
            } else {
                backgroundClippingFrame = CGRect(
                    x: effectiveBarForegroundFrame.maxX,
                    y: barBackgroundFrame.minY,
                    width: max(0, barBackgroundFrame.maxX - effectiveBarForegroundFrame.maxX),
                    height: barBackgroundFrame.height
                )
            }
            
            transition.setPosition(view: self.backgroundClippingContainer, position: backgroundClippingFrame.center)
            transition.setBounds(view: self.backgroundClippingContainer, bounds: CGRect(origin: CGPoint(x: backgroundClippingFrame.minX - barBackgroundFrame.minX, y: 0.0), size: backgroundClippingFrame.size))
            transition.setAlpha(view: self.backgroundClippingContainer, alpha: foregroundContentsAlpha)
            
            transition.setFrame(view: self.barForeground, frame: CGRect(origin: CGPoint(), size: barBackgroundFrame.size))
            
            let labelFont = Font.semibold(14.0)
            
            let leftLabelSize = self.backgroundLeftLabel.update(
                transition: labelsTransition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: leftLabelText, font: labelFont, textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            let _ = self.foregroundLeftLabel.update(
                transition: labelsTransition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: leftLabelText, font: labelFont, textColor: component.theme.list.itemCheckColors.foregroundColor))
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            let rightLabelSize = self.backgroundRightLabel.update(
                transition: labelsTransition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: rightLabelText, font: labelFont, textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            let _ =  self.foregroundRightLabel.update(
                transition: labelsTransition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: rightLabelText, font: labelFont, textColor: component.theme.list.itemCheckColors.foregroundColor))
                )),
                environment: {},
                containerSize: CGSize(width: barBackgroundFrame.width, height: 100.0)
            )
            
            let leftLabelFrame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((barBackgroundFrame.height - leftLabelSize.height) * 0.5)), size: leftLabelSize)
            let rightLabelFrame = CGRect(origin: CGPoint(x: barBackgroundFrame.width - 12.0 - rightLabelSize.width, y: floorToScreenPixels((barBackgroundFrame.height - rightLabelSize.height) * 0.5)), size: rightLabelSize)
            
            if let backgroundLeftLabelView = self.backgroundLeftLabel.view {
                if backgroundLeftLabelView.superview == nil {
                    backgroundLeftLabelView.layer.anchorPoint = CGPoint()
                    self.backgroundClippingContainer.addSubview(backgroundLeftLabelView)
                }
                transition.setPosition(view: backgroundLeftLabelView, position: leftLabelFrame.origin)
                backgroundLeftLabelView.bounds = CGRect(origin: CGPoint(), size: leftLabelFrame.size)
            }
            if let foregroundLeftLabelView = self.foregroundLeftLabel.view {
                if foregroundLeftLabelView.superview == nil {
                    foregroundLeftLabelView.layer.anchorPoint = CGPoint()
                    self.foregroundClippingContainer.addSubview(foregroundLeftLabelView)
                }
                transition.setPosition(view: foregroundLeftLabelView, position: leftLabelFrame.origin)
                foregroundLeftLabelView.bounds = CGRect(origin: CGPoint(), size: leftLabelFrame.size)
            }
            if let backgroundRightLabelView = self.backgroundRightLabel.view {
                if backgroundRightLabelView.superview == nil {
                    backgroundRightLabelView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.backgroundClippingContainer.addSubview(backgroundRightLabelView)
                }
                transition.setPosition(view: backgroundRightLabelView, position: CGPoint(x: rightLabelFrame.maxX, y: rightLabelFrame.minY))
                backgroundRightLabelView.bounds = CGRect(origin: CGPoint(), size: rightLabelFrame.size)
            }
            if let foregroundRightLabelView = self.foregroundRightLabel.view {
                if foregroundRightLabelView.superview == nil {
                    foregroundRightLabelView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                    self.foregroundClippingContainer.addSubview(foregroundRightLabelView)
                }
                transition.setPosition(view: foregroundRightLabelView, position: CGPoint(x: rightLabelFrame.maxX, y: rightLabelFrame.minY))
                foregroundRightLabelView.bounds = CGRect(origin: CGPoint(), size: rightLabelFrame.size)
            }
            
            let icon: ProfileLevelRatingBarBadge.Icon
            switch component.icon {
            case .rating:
                icon = .rating
            case .stars:
                icon = .stars
            }
            
            let badgeSize = self.badge.update(
                transition: transition.withUserData(ProfileLevelRatingBarBadge.TransitionHint(animateText: !labelsTransition.animation.isImmediate)),
                component: AnyComponent(ProfileLevelRatingBarBadge(
                    theme: component.theme,
                    title: component.level < 0 ? "" : "\(component.badgeValue)",
                    suffix: component.level < 0 ? nil : component.badgeTotal,
                    icon: icon
                )),
                environment: {},
                containerSize: CGSize(width: 200.0, height: 200.0)
            )
            
            if let badgeView = self.badge.view as? ProfileLevelRatingBarBadge.View {
                if badgeView.superview == nil {
                    self.addSubview(badgeView)
                }
                
                let apparentBadgeSize: CGSize
                if let animationState = self.animationState {
                    apparentBadgeSize = animationState.badgeSize(at: CACurrentMediaTime(), endValue: badgeSize)
                } else {
                    apparentBadgeSize = badgeSize
                }
                
                let badgeOriginX = barBackgroundFrame.minX + barForegroundFrame.width
                var badgeFrame = CGRect(origin: CGPoint(x: badgeOriginX - apparentBadgeSize.width * 0.5, y: barBackgroundFrame.minY - 18.0 - badgeSize.height), size: apparentBadgeSize)
                
                let badgeSideInset: CGFloat = 0.0
                
                let badgeOverflowWidth: CGFloat
                if badgeFrame.minX < badgeSideInset {
                    badgeOverflowWidth = badgeSideInset - badgeFrame.minX
                } else if badgeFrame.minX + badgeFrame.width > availableSize.width - badgeSideInset {
                    badgeOverflowWidth = availableSize.width - badgeSideInset - badgeFrame.width - badgeFrame.minX
                } else {
                    badgeOverflowWidth = 0.0
                }
                
                badgeFrame.origin.x += badgeOverflowWidth
                let badgeTailOffset = (barBackgroundFrame.minX + barForegroundFrame.width) - badgeFrame.minX
                let badgePosition = CGPoint(x: badgeFrame.minX + badgeTailOffset, y: badgeFrame.maxY)
                
                if let animationDeltaTime = self.animationDeltaTime, self.animationState != nil, !self.animationIsMovingOverStep {
                    let previousX = badgeView.center.x
                    self.addBadgeDeltaX(value: badgePosition.x - previousX, deltaTime: animationDeltaTime)
                }
                
                badgeView.center = badgePosition
                badgeView.bounds = CGRect(origin: CGPoint(), size: badgeFrame.size)
                transition.setAnchorPoint(layer: badgeView.layer, anchorPoint: CGPoint(x: max(0.0, min(1.0, badgeTailOffset / badgeFrame.width)), y: 1.0))
                
                badgeView.updateColors(background: badgeColor)
                
                badgeView.adjustTail(size: apparentBadgeSize, tailOffset: badgeTailOffset, transition: transition)
                transition.setAlpha(view: badgeView, alpha: foregroundContentsAlpha)
                self.badgeScale = badgeScale
                self.updateBadgeTransform()
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
