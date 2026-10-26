import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import ChatMessageNotificationItem
import GlassBackgroundComponent

private struct NotificationItemSpring {
    let start: Double
    let velocity: Double
    let target: Double
    let dampingRatio: Double
    let response: Double

    func sample(at time: Double) -> (position: Double, velocity: Double) {
        let omega = 2.0 * Double.pi / self.response
        let decay = self.dampingRatio * omega
        let frequency = omega * sqrt(1.0 - self.dampingRatio * self.dampingRatio)
        let displacement = self.start - self.target
        let sineCoefficient = (self.velocity + decay * displacement) / frequency
        let cosine = cos(frequency * time)
        let sine = sin(frequency * time)
        let envelope = exp(-decay * time)
        return (
            self.target + envelope * (displacement * cosine + sineCoefficient * sine),
            envelope * ((-decay * displacement + sineCoefficient * frequency) * cosine + (-decay * sineCoefficient - displacement * frequency) * sine)
        )
    }

    func animation(keyPath: String) -> CASpringAnimation {
        let omega = 2.0 * Double.pi / self.response
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = 1.0
        animation.stiffness = CGFloat(omega * omega)
        animation.damping = CGFloat(2.0 * self.dampingRatio * omega)
        let distance = self.target - self.start
        animation.initialVelocity = abs(distance) > 1.0e-8 ? CGFloat(self.velocity / distance) : 0.0
        animation.fromValue = self.start
        animation.toValue = self.target
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        return animation
    }
}

final class NotificationItemContainerNode: ASDisplayNode {
    private struct Motion {
        let springs: [NotificationItemSpring]
        let startTime: Double
        let duration: Double
        let durationFactor: Double
        let fromBlurRadius: CGFloat
        let toBlurRadius: CGFloat
    }

    private struct MotionSnapshot {
        let values: [Double]
        let velocities: [Double]
        let blurRadius: CGFloat
    }

    private static let motionKey = "notification.motion"
    private static let blurKey = "filters.gaussianBlur.inputRadius"
    private static let blurDuration = 0.3
    private static let blurRadius: CGFloat = 18.0

    private let theme: PresentationTheme

    private let animationContainerNode = ASDisplayNode()
    private let backgroundView = GlassBackgroundView()
    private var bannerFrame: CGRect = .zero
    private var motion: Motion?
    private var motionGeneration = 0
    private var isDismissing = false
    private var isDismissed = false
    private var dismissCompletions: [() -> Void] = []
        
    var item: NotificationItem?
    
    private var hapticFeedback: HapticFeedback?
    private var willBeExpanded = false {
        didSet {
            if self.willBeExpanded != oldValue {
                if self.hapticFeedback == nil {
                    self.hapticFeedback = HapticFeedback()
                }
                self.hapticFeedback?.impact()
            }
        }
    }
    
    var contentNode: NotificationItemNode? {
        didSet {
            if self.contentNode !== oldValue {
                oldValue?.removeFromSupernode()
            }
            
            if let contentNode = self.contentNode {
                self.animationContainerNode.addSubnode(contentNode)
                
                if let validLayout = self.validLayout {
                    self.updateLayout(layout: validLayout, transition: .immediate)
                }
            }
        }
    }
    
    private var validLayout: ContainerViewLayout?
    
    var dismissed: ((NotificationItem) -> Void)?
    var cancelTimeout: ((NotificationItem) -> Void)?
    var resumeTimeout: ((NotificationItem) -> Void)?
    
    var cancelledTimeout = false
    
    init(theme: PresentationTheme, contentNode: NotificationItemNode?) {
        self.contentNode = contentNode
        self.theme = theme
                
        super.init()

        self.animationContainerNode.isOpaque = false
        self.addSubnode(self.animationContainerNode)
        if let contentNode {
            self.animationContainerNode.addSubnode(contentNode)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.animationContainerNode.view.insertSubview(self.backgroundView, at: 0)
        
        if let contentNode = self.contentNode, !contentNode.acceptsTouches {
            self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
            panRecognizer.delaysTouchesBegan = false
            panRecognizer.cancelsTouchesInView = false
            self.view.addGestureRecognizer(panRecognizer)
        }
    }
    
    func animateIn() {
        guard self.validLayout != nil, !self.bannerFrame.isEmpty, !self.isDismissing, !self.isDismissed else {
            return
        }
        let snapshot = self.motion != nil ? self.motionSnapshot() : MotionSnapshot(
            values: [0.19, 0.19, Double(self.bounds.minY - self.bannerFrame.height / 2.0)],
            velocities: [0.0, 0.0, 0.0],
            blurRadius: Self.blurRadius
        )
        self.animateMotion(presenting: true, from: snapshot)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        if self.isDismissed {
            completion()
            return
        }
        self.dismissCompletions.append(completion)
        guard !self.isDismissing else {
            return
        }
        self.isDismissing = true

        self.freezeGestureBounds()
        self.animateMotion(presenting: false, from: self.motionSnapshot())
    }

    private func freezeGestureBounds() {
        if self.layer.animation(forKey: "bounds") != nil {
            let bounds = self.layer.presentation()?.bounds ?? self.bounds
            self.layer.removeAnimation(forKey: "bounds")
            self.bounds = bounds
        }
    }

    private func motionSnapshot() -> MotionSnapshot {
        let layer = self.animationContainerNode.layer
        let presentation = layer.presentation()
        var values = [Double(layer.transform.m11), Double(layer.transform.m22), Double(layer.position.y)]
        var velocities = [0.0, 0.0, 0.0]
        var blurRadius: CGFloat = 0.0
        if let motion = self.motion {
            let elapsed = max(0.0, (layer.convertTime(CACurrentMediaTime(), from: nil) - motion.startTime) / motion.durationFactor)
            let samples = motion.springs.map { spring in
                elapsed < motion.duration ? spring.sample(at: elapsed) : (position: spring.target, velocity: 0.0)
            }
            values = samples.map { $0.position }
            velocities = samples.map { $0.velocity }
            let blurProgress = bezierPoint(0.0, 0.0, 0.58, 1.0, CGFloat(min(1.0, elapsed / Self.blurDuration)))
            blurRadius = motion.fromBlurRadius + (motion.toBlurRadius - motion.fromBlurRadius) * blurProgress
        }
        if let presentation {
            values = [Double(presentation.transform.m11), Double(presentation.transform.m22), Double(presentation.position.y)]
            for case let filter as NSObject in presentation.filters ?? [] {
                if filter.description.contains("gaussianBlur"), let radius = filter.value(forKey: "inputRadius") as? NSNumber {
                    blurRadius = CGFloat(radius.doubleValue)
                }
            }
        }
        return MotionSnapshot(values: values, velocities: velocities, blurRadius: blurRadius)
    }

    private func animateMotion(presenting: Bool, from snapshot: MotionSnapshot) {
        self.motionGeneration += 1
        let generation = self.motionGeneration
        let layer = self.animationContainerNode.layer
        let targets = presenting ? [1.0, 1.0, Double(self.bannerFrame.midY)] : [0.19, 0.19, Double(self.bounds.minY - self.bannerFrame.height)]
        let parameters: [(dampingRatio: Double, response: Double)] = [(0.69762, 0.728), (0.62275, 0.48669), (0.63333, 0.62832)]
        let springs = parameters.enumerated().map { index, parameters in
            NotificationItemSpring(start: snapshot.values[index], velocity: snapshot.velocities[index], target: targets[index], dampingRatio: parameters.dampingRatio, response: parameters.response)
        }
        let paths = ["transform.scale.x", "transform.scale.y", "position.y"]
        let springAnimations = zip(springs, paths).map { spring, keyPath in
            spring.animation(keyPath: keyPath)
        }
        let duration = springAnimations.map { $0.settlingDuration }.max() ?? 0.0
        let animationDurationFactor = UIView.animationDurationFactor
        let durationFactor = animationDurationFactor > 0.0 ? animationDurationFactor : 1.0
        let startTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        let toBlurRadius: CGFloat = presenting ? 0.0 : Self.blurRadius
        self.motion = Motion(springs: springs, startTime: startTime, duration: duration, durationFactor: durationFactor, fromBlurRadius: snapshot.blurRadius, toBlurRadius: toBlurRadius)

        if UIAccessibility.isReduceMotionEnabled || self.validLayout == nil || self.bannerFrame.isEmpty {
            self.finishMotion(presenting: presenting, generation: generation)
            return
        }

        let animations: [CAAnimation] = springAnimations.enumerated().map { index, animation in
            let spring = springs[index]
            if abs(spring.target - spring.start) <= 1.0e-8 && abs(spring.velocity) > 1.0e-8 {
                let count = max(2, Int(ceil(duration * 240.0)))
                let keyframes = CAKeyframeAnimation(keyPath: paths[index])
                keyframes.values = (0 ... count).map { spring.sample(at: Double($0) / Double(count) * duration).position }
                keyframes.duration = duration
                keyframes.calculationMode = .linear
                return keyframes
            }
            animation.duration = duration
            return animation
        }
        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = duration
        group.beginTime = startTime
        group.speed = Float(1.0 / durationFactor)
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        if #available(iOS 15.0, *) {
            let frameRate = Float(UIScreen.main.maximumFramesPerSecond)
            group.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: frameRate, preferred: frameRate)
        }
        group.completion = { [weak self] finished in
            if finished {
                self?.finishMotion(presenting: presenting, generation: generation)
            }
        }

        self.animationContainerNode.isHidden = false
        layer.transform = CATransform3DIdentity
        layer.removeAnimation(forKey: "position")
        self.animationContainerNode.position = CGPoint(x: self.bannerFrame.midX, y: self.bannerFrame.midY)
        layer.add(group, forKey: Self.motionKey)
        ComponentTransition.easeInOut(duration: Self.blurDuration).animateBlur(layer: layer, fromRadius: snapshot.blurRadius, toRadius: toBlurRadius)
    }

    private func finishMotion(presenting: Bool, generation: Int) {
        guard generation == self.motionGeneration, self.motion != nil else {
            return
        }
        self.motion = nil
        self.animationContainerNode.isHidden = !presenting
        self.animationContainerNode.layer.transform = CATransform3DIdentity
        self.animationContainerNode.position = CGPoint(x: self.bannerFrame.midX, y: self.bannerFrame.midY)
        self.animationContainerNode.layer.removeAnimation(forKey: Self.motionKey)
        self.animationContainerNode.layer.removeAnimation(forKey: Self.blurKey)
        self.animationContainerNode.layer.filters = nil
        if !presenting {
            self.isDismissed = true
            let completions = self.dismissCompletions
            self.dismissCompletions.removeAll()
            for completion in completions {
                completion()
            }
        }
    }

    private func prepareForExpansion() {
        self.freezeGestureBounds()
        let snapshot = self.motionSnapshot()
        self.motionGeneration += 1
        self.motion = nil
        let layer = self.animationContainerNode.layer
        layer.transform = CATransform3DMakeScale(CGFloat(snapshot.values[0]), CGFloat(snapshot.values[1]), 1.0)
        layer.position.y = CGFloat(snapshot.values[2])
        layer.removeAnimation(forKey: Self.motionKey)
        layer.removeAnimation(forKey: Self.blurKey)
        layer.filters = nil
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        if let contentNode = self.contentNode {
            let inset: CGFloat = 8.0
            
            var contentInsets = UIEdgeInsets(top: inset + layout.safeInsets.left, left: inset, bottom: inset, right: inset + layout.safeInsets.right)
            if layout.safeInsets.left != layout.safeInsets.right {
                contentInsets.top = inset
                contentInsets.right = inset
            }
            
            if let statusBarHeight = layout.statusBarHeight, statusBarHeight >= 39.0 {
                if layout.deviceMetrics.hasDynamicIsland || layout.topBarStatusIsland != nil {
                    contentInsets.top = statusBarHeight + 6.0
                } else if statusBarHeight >= 44.0 {
                    contentInsets.top += 34.0
                } else {
                    contentInsets.top += 29.0
                }
            }
            
            let placement = horizontalContainerFillingPlacementForLayout(layout: layout, margin: 0.0, includesSafeInsets: false)
            let containerWidth = placement.width
            let containerCenterX = placement.left == placement.right ? layout.size.width / 2.0 : placement.left + containerWidth / 2.0
            
            let contentWidth = containerWidth - contentInsets.left - contentInsets.right
            let contentHeight = contentNode.updateLayout(width: contentWidth, transition: transition)
            
            let backgroundInset: CGFloat = 8.0
            let backgroundSize = CGSize(width: containerWidth - backgroundInset * 2.0, height: contentHeight)
            let bannerFrame = CGRect(origin: CGPoint(x: floor(containerCenterX - backgroundSize.width / 2.0), y: contentInsets.top), size: backgroundSize)
            let snapshot = self.motion != nil && bannerFrame != self.bannerFrame ? self.motionSnapshot() : nil
            self.bannerFrame = bannerFrame
            let containerTransition: ContainedViewLayoutTransition = self.motion != nil ? .immediate : transition
            containerTransition.updateBounds(node: self.animationContainerNode, bounds: CGRect(origin: .zero, size: backgroundSize))
            containerTransition.updatePosition(node: self.animationContainerNode, position: CGPoint(x: bannerFrame.midX, y: bannerFrame.midY))
            self.backgroundView.update(size: backgroundSize, cornerRadius: 24.0, isDark: self.theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: ComponentTransition(transition))
            transition.updateFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: backgroundSize))
            
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: floor(containerCenterX - contentWidth / 2.0) - bannerFrame.minX, y: 0.0), size: CGSize(width: contentWidth, height: contentHeight)))
            if let snapshot {
                self.animateMotion(presenting: !self.isDismissing, from: snapshot)
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !self.isDismissing, !self.isDismissed, let contentNode = self.contentNode, contentNode.supernode === self.animationContainerNode else {
            return nil
        }
        let contentPoint: CGPoint
        if let presentation = contentNode.layer.presentation(), let containerPresentation = self.layer.presentation() {
            contentPoint = presentation.convert(point, from: containerPresentation)
        } else {
            contentPoint = self.view.convert(point, to: contentNode.view)
        }
        if contentNode.bounds.contains(contentPoint) {
            if contentNode.acceptsTouches {
                if let result = contentNode.view.hitTest(contentPoint, with: event) {
                    return result
                }
            }
            return self.view
        }
        return nil
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        guard !self.isDismissing, !self.isDismissed else {
            return
        }
        if case .ended = recognizer.state {
            if let item = self.item {
                item.tapped({ [weak self] in
                    if let strongSelf = self, !strongSelf.isDismissing, !strongSelf.isDismissed, let contentNode = strongSelf.contentNode, contentNode.supernode === strongSelf.animationContainerNode, let _ = strongSelf.item {
                        strongSelf.prepareForExpansion()
                        return (contentNode, {
                            if let strongSelf = self, let item = strongSelf.item {
                                strongSelf.dismissed?(item)
                            }
                        })
                    } else {
                        return (nil, {})
                    }
                })
            }
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        guard !self.isDismissing, !self.isDismissed else {
            return
        }
        switch recognizer.state {
            case .began:
                self.cancelledTimeout = false
            case .changed:
                let translation = recognizer.translation(in: self.view)
                var bounds = self.bounds
                bounds.origin.y = -translation.y
                if bounds.origin.y < 0.0 {
                    let delta = -bounds.origin.y
                    bounds.origin.y = -((1.0 - (1.0 / (((delta) * 0.55 / (50.0)) + 1.0))) * 50.0)
                }
                if abs(translation.y) > 1.0 {
                    if self.hapticFeedback == nil {
                        self.hapticFeedback = HapticFeedback()
                    }
                    self.hapticFeedback?.prepareImpact()
                }
                self.bounds = bounds
                var expand = false
                if let item = self.item {
                    if !self.cancelledTimeout && abs(translation.y) > 4.0 {
                        self.cancelledTimeout = true
                        self.cancelTimeout?(item)
                    }
                    expand = item.canBeExpanded() && bounds.minY < -24.0
                }
                if self.willBeExpanded != expand {
                    self.willBeExpanded = expand
                }
            case .ended:
                let translation = recognizer.translation(in: self.view)
                var bounds = self.bounds
                bounds.origin.y = -translation.y
                if bounds.origin.y < 0.0 {
                    let delta = -bounds.origin.y
                    bounds.origin.y = -((1.0 - (1.0 / (((delta) * 0.55 / (50.0)) + 1.0))) * 50.0)
                }
                
                let velocity = recognizer.velocity(in: self.view)
                
                if (bounds.minY < -20.0 || velocity.y > 300.0) {
                    if let item = self.item {
                        if !self.cancelledTimeout {
                            self.cancelledTimeout = true
                            self.cancelTimeout?(item)
                        }
                        
                        item.expand({ [weak self] in
                            if let strongSelf = self, !strongSelf.isDismissing, !strongSelf.isDismissed, let contentNode = strongSelf.contentNode, contentNode.supernode === strongSelf.animationContainerNode, let _ = strongSelf.item {
                                strongSelf.prepareForExpansion()
                                return (contentNode, {
                                    if let strongSelf = self, let item = strongSelf.item {
                                        strongSelf.dismissed?(item)
                                    }
                                })
                            } else {
                                return (nil, {})
                            }
                        })
                    }
                } else if bounds.minY > 5.0 || velocity.y < -200.0 {
                    self.animateOut(completion: { [weak self] in
                        if let strongSelf = self, let item = strongSelf.item {
                            strongSelf.dismissed?(item)
                        }
                    })
                } else {
                    if let item = self.item, self.cancelledTimeout {
                        self.cancelledTimeout = false
                        self.resumeTimeout?(item)
                    }
                    
                    self.cancelledTimeout = false
                    let previousBounds = self.bounds
                    var bounds = self.bounds
                    bounds.origin.y = 0.0
                    self.bounds = bounds
                    self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                    
                    self.willBeExpanded = false
                }
            case .cancelled:
                self.willBeExpanded = false
                self.cancelledTimeout = false
                let previousBounds = self.bounds
                var bounds = self.bounds
                bounds.origin.y = 0.0
                self.bounds = bounds
                self.layer.animateBounds(from: previousBounds, to: self.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
            default:
                break
        }
    }
}
