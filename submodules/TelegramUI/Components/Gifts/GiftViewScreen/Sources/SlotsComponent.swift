import Foundation
import UIKit
import Display
import ComponentFlow
import ImageBlur

private let additionalInset: CGFloat = 4.0
private let maskInset: CGFloat = 8.0

final class SlotsComponent<ChildEnvironment: Equatable>: Component {
    public typealias EnvironmentType = ChildEnvironment

    private let item: AnyComponent<ChildEnvironment>
    private let items: [AnyComponentWithIdentity<ChildEnvironment>]
    private let isAnimating: Bool
    private let tintColor: UIColor?
    private let verticalOffset: CGFloat
    private let motionBlur: Bool
    private let size: CGSize
    
    public init(
        item: AnyComponent<ChildEnvironment>,
        items: [AnyComponentWithIdentity<ChildEnvironment>],
        isAnimating: Bool,
        tintColor: UIColor? = nil,
        verticalOffset: CGFloat = 0.0,
        motionBlur: Bool = true,
        size: CGSize
    ) {
        self.item = item
        self.items = items
        self.isAnimating = isAnimating
        self.tintColor = tintColor
        self.verticalOffset = verticalOffset
        self.motionBlur = motionBlur
        self.size = size
    }

    public static func == (lhs: SlotsComponent<ChildEnvironment>, rhs: SlotsComponent<ChildEnvironment>) -> Bool {
        if lhs.item != rhs.item {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.isAnimating != rhs.isAnimating {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.verticalOffset != rhs.verticalOffset {
            return false
        }
        if lhs.motionBlur != rhs.motionBlur {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var itemViews: [AnyHashable: ComponentView<ChildEnvironment>] = [:]
        private var motionBlurLayers: [AnyHashable: SimpleLayer] = [:]
        private var order: [AnyHashable] = []

        private let containerView = UIView()
        private let maskLayer = SimpleGradientLayer()

        private enum SpinState {
            case idle
            case spinning
            case decelerating
            case settled
        }

        private var spinState: SpinState = .idle
        private var isAnimating = false
        private var animationLink: SharedDisplayLinkDriver.Link?

        private var currentIds = Set<AnyHashable>()
        private var lastSpawnTime: Double?
        private var currentInterval: Double = 0.09
        
        private var motionBlurFactor: CGFloat = 1.0
        private var decelQueue: [AnyComponentWithIdentity<ChildEnvironment>] = []
        private var decelTotalSteps: Int = 0
        private var decelStepIndex: Int = 0
        
        private let minSpawnInterval: Double = 0.10
        private let maxSpawnInterval: Double = 0.80
        
        private let baseAnimDuration: Double = 0.18
        private let maxAnimDuration: Double  = 0.5
        
        private var component: SlotsComponent?
        private var environment: Environment<ChildEnvironment>?
        private var availableSize: CGSize?
        
        @inline(__always) private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
        @inline(__always) private func clamp01(_ x: Double) -> Double { max(0.0, min(1.0, x)) }

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.containerView)

            self.containerView.clipsToBounds = true

            self.maskLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            self.maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)

            let fade: CGFloat = 0.2
            self.maskLayer.locations = [0.0, NSNumber(value: Float(fade)), NSNumber(value: Float(1.0 - fade)), 1.0]
            self.maskLayer.colors = [
                UIColor.black.withAlphaComponent(0.0).cgColor,
                UIColor.black.withAlphaComponent(1.0).cgColor,
                UIColor.black.withAlphaComponent(1.0).cgColor,
                UIColor.black.withAlphaComponent(0.0).cgColor
            ]
            self.containerView.layer.mask = self.maskLayer
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func spawnRandomSlot(availableSize: CGSize) {
            guard var items = self.component?.items, !items.isEmpty else { return }
            items = items.filter { !self.currentIds.contains($0.id) }
            guard let randomItem = items.randomElement() else { return }

            self.spawnSlot(item: randomItem, availableSize: availableSize) {}
        }

        private func spawnSlot(
            item: AnyComponentWithIdentity<ChildEnvironment>,
            isFinal: Bool = false,
            availableSize: CGSize,
            animDuration: Double? = nil,
            completion: @escaping () -> Void
        ) {
            guard let component = self.component, let environment = self.environment else { return }

            self.currentIds.insert(item.id)
            self.lastSpawnTime = CACurrentMediaTime()

            let itemView = self.itemViews[item.id] ?? ComponentView<ChildEnvironment>()
            self.itemViews[item.id] = itemView

            let size = itemView.update(
                transition: .immediate,
                component: item.component,
                environment: { environment[ChildEnvironment.self] },
                containerSize: availableSize
            )
            if let view = itemView.view {
                if view.superview == nil {
                    if let tintColor = component.tintColor {
                        view.layer.layerTintColor = tintColor.cgColor
                    }
                    view.layer.allowsGroupOpacity = true
                    self.containerView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: 0.0, y: -size.height - additionalInset), size: size)
                
                let travelDistance = (size.height + maskInset + additionalInset) * 2.0
                let pitch = (size.height + additionalInset)
                
                if isFinal {
                    var finalFrame = view.frame
                    finalFrame.origin.y = maskInset
                    view.frame = finalFrame
                    
                    let fromY = size.height + maskInset + additionalInset
                    let overshoot: CGFloat = 7.0
                    
                    let anim = CAKeyframeAnimation(keyPath: "position.y")
                    anim.isAdditive = true
                    anim.values = [ fromY, -overshoot, 0.0 ]
                    anim.keyTimes = [0.0, 0.7, 1.0]
                    anim.timingFunctions = [
                        CAMediaTimingFunction(name: .easeOut),
                        CAMediaTimingFunction(name: .easeInEaseOut)
                    ]
                    anim.duration = 0.5
                    
                    CATransaction.begin()
                    CATransaction.setCompletionBlock {
                        completion()
                        self.currentIds.remove(item.id)
                        self.finishSettled()
                    }
                    view.layer.add(anim, forKey: "finalOvershoot")
                    CATransaction.commit()
                }
                else {
                    let duration: Double = animDuration ?? baseAnimDuration
                    
                    view.layer.animatePosition(
                        from: CGPoint(x: 0.0, y: (size.height + maskInset + additionalInset) * 2.0),
                        to: .zero,
                        duration: duration,
                        timingFunction: CAMediaTimingFunctionName.linear.rawValue,
                        additive: true,
                        completion: { _ in
                            completion()
                            self.currentIds.remove(item.id)
                        }
                    )
                    
                    let intervalForConstantSpacing = Double(pitch / travelDistance) * duration
                    self.currentInterval = intervalForConstantSpacing
                }
            }

            self.setMotionBlurFactor(id: item.id, factor: self.motionBlurFactor, transition: .immediate)
        }

        private func setMotionBlurFactor(id: AnyHashable, factor: CGFloat, transition: ComponentTransition) {
            guard let component = self.component, component.motionBlur, let itemView = self.itemViews[id]?.view else {
                return
            }

            if factor != 0.0 {
                let motionBlurLayer: SimpleLayer
                if let current = self.motionBlurLayers[id] {
                    motionBlurLayer = current
                } else {
                    motionBlurLayer = SimpleLayer()

                    let image = generateImage(itemView.bounds.size, rotatedContext: { size, context in
                        UIGraphicsPushContext(context)
                        defer { UIGraphicsPopContext() }
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        itemView.layer.render(in: context)
                    })
                    if let image {
                        motionBlurLayer.contents = verticalBlurredImage(image, radius: 8.0)?.cgImage
                    }
                    motionBlurLayer.contentsScale = itemView.layer.contentsScale
                    self.motionBlurLayers[id] = motionBlurLayer
                    itemView.layer.addSublayer(motionBlurLayer)

                    motionBlurLayer.position = CGPoint(x: itemView.bounds.size.width * 0.5, y: itemView.bounds.size.height * 0.5)
                    motionBlurLayer.bounds = CGRect(origin: CGPoint(), size: itemView.bounds.size)
                    
                    if let tintColor = component.tintColor {
                        motionBlurLayer.layerTintColor = tintColor.cgColor
                    }
                }
                
                let scaleFactor = 1.0 * (1.0 - factor) + 1.25 * factor
                let opacityFactor =  1.0 * (1.0 - factor) + 0.6 * factor
                transition.setTransform(layer: motionBlurLayer, transform: CATransform3DMakeScale(1.0, scaleFactor, 1.0))
                transition.setAlpha(layer: itemView.layer, alpha: opacityFactor)
            } else if let motionBlurLayer = self.motionBlurLayers[id] {
                self.motionBlurLayers.removeValue(forKey: id)
                transition.setAlpha(layer: motionBlurLayer, alpha: 0.0, completion: { [weak motionBlurLayer] _ in
                    motionBlurLayer?.removeFromSuperlayer()
                })
                transition.setTransform(layer: motionBlurLayer, transform: CATransform3DIdentity)
            }
        }

        private func beginSpinning() {
            self.spinState = .spinning
            self.isAnimating = true
            self.motionBlurFactor = 1.0
            self.currentInterval = 0.1

            self.ensureDisplayLink()
        }

        private func beginDeceleration() {
            guard let component = self.component, self.spinState == .spinning || self.spinState == .decelerating else { return }

            self.spinState = .decelerating
            self.isAnimating = false

            var queue: [AnyComponentWithIdentity<ChildEnvironment>] = []
            if !component.items.isEmpty {
                let shuffled = Array(component.items.shuffled().prefix(3))
                queue.append(contentsOf: shuffled)
            }
            queue.append(AnyComponentWithIdentity(id: "final", component: component.item))
            
            self.decelQueue = queue
            self.decelTotalSteps = queue.count
            self.decelStepIndex = 0
            
            self.motionBlurFactor = max(self.motionBlurFactor, 0.0001)

            self.ensureDisplayLink()
        }

        private func ensureDisplayLink() {
            guard self.animationLink == nil else {
                return
            }
            self.animationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                self?.tick()
            })
        }

        private func invalidateDisplayLinkIfIdle() {
            if self.spinState == .idle || self.spinState == .settled {
                self.animationLink?.invalidate()
                self.animationLink = nil
            }
        }
        
        private func applyEdge3DSquish() {
            let H = self.containerView.bounds.height
            guard H > 0 else { return }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for (_, cv) in self.itemViews {
                guard let v = cv.view, v.superview === self.containerView else { continue }
                let midY = liveMidY(in: self.containerView, of: v)
                let scaleY = edgeScaleY(for: midY, containerHeight: H)
                var t = CATransform3DIdentity
                t = CATransform3DScale(t, 1.0, scaleY, 1.0)
                v.layer.transform = t
            }
            CATransaction.commit()
        }

        private func tick() {
            guard let availableSize = self.availableSize else {
                return
            }
            let now = CACurrentMediaTime()

            switch self.spinState {
            case .spinning:
                if let last = self.lastSpawnTime, now - last >= self.currentInterval || self.lastSpawnTime == nil {
                    self.spawnRandomSlot(availableSize: availableSize)
                }
            case .decelerating:
                let t = clamp01(self.decelTotalSteps > 1 ? Double(self.decelStepIndex) / Double(self.decelTotalSteps - 1) : 1.0)
                                
                if let last = self.lastSpawnTime, now - last >= self.currentInterval {
                    if !self.decelQueue.isEmpty {
                        let next = self.decelQueue.removeFirst()
                        let isFinal = self.decelQueue.isEmpty
                        let animDuration = isFinal ? nil : lerp(baseAnimDuration, maxAnimDuration, t)
                        self.spawnSlot(item: next, isFinal: isFinal, availableSize: availableSize, animDuration: animDuration, completion: {})
                        
                        self.motionBlurFactor = CGFloat(1.0 - t)

                        self.decelStepIndex += 1
                    }
                } else if self.lastSpawnTime == nil {
                    if !self.decelQueue.isEmpty {
                        let next = self.decelQueue.removeFirst()
                        self.spawnSlot(item: next, availableSize: availableSize) {}
                    }
                }

            case .settled, .idle:
                self.invalidateDisplayLinkIfIdle()
            }
            
            self.applyEdge3DSquish()
        }

        private func finishSettled() {
            for (id, _) in self.motionBlurLayers {
                self.setMotionBlurFactor(id: id, factor: 0.0, transition: .easeInOut(duration: 0.2))
            }
            self.motionBlurLayers.removeAll()

            self.spinState = .settled
            self.decelQueue.removeAll()
            self.invalidateDisplayLinkIfIdle()
        }

        func update(
            component: SlotsComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<ChildEnvironment>,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component
            self.environment = environment
            self.availableSize = availableSize

            let size = component.size
            self.containerView.frame = CGRect(origin: CGPoint(x: 0.0, y: component.verticalOffset), size: size).insetBy(dx: 0.0, dy: -maskInset)
            self.maskLayer.frame = CGRect(origin: .zero, size: self.containerView.bounds.size)

            let wasAnimating = self.isAnimating
            let nowAnimating = component.isAnimating

            if nowAnimating && !wasAnimating {
                self.beginSpinning()
                self.spawnRandomSlot(availableSize: availableSize)
            } else if !nowAnimating && wasAnimating {
                self.beginDeceleration()
            } else if nowAnimating && self.spinState == .settled {
                self.beginSpinning()
                self.spawnRandomSlot(availableSize: availableSize)
            }
            
            if let tintColor = component.tintColor {
                for (id, itemView) in self.itemViews {
                    if let itemLayer = itemView.view?.layer {
                        transition.setTintColor(layer: itemLayer, color: tintColor)
                    }
                    if let blurLayer = self.motionBlurLayers[id] {
                        transition.setTintColor(layer: blurLayer, color: tintColor)
                    }
                }
            }

            return size
        }
    }

    public func makeView() -> View {
        return View()
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private let minScaleYAtEdge: CGFloat = 0.7
private let squishFalloff: CGFloat = 0.12

private func smoothstep(_ x: CGFloat) -> CGFloat {
    let t = max(0.0, min(1.0, x))
    return t * t * (3.0 - 2.0 * t)
}

private func liveMidY(in container: UIView, of view: UIView) -> CGFloat {
    if let pres = view.layer.presentation() {
        let p = container.layer.convert(pres.position, from: view.layer.superlayer)
        return p.y
    }
    return view.center.y
}

private func edgeScaleY(for midY: CGFloat, containerHeight H: CGFloat) -> CGFloat {
    guard H > 0 else { return 1.0 }
    let d = abs((midY - H * 0.5) / (H * 0.5))
    let uRaw = (d - squishFalloff) / (1.0 - squishFalloff)
    let u = smoothstep(max(0.0, min(1.0, uRaw)))
    return (1.0 - u) + minScaleYAtEdge * u
}


final class SpacerComponent: Component {
    let size: CGSize

    init(
        size: CGSize
    ) {
        self.size = size
    }

    static func ==(lhs: SpacerComponent, rhs: SpacerComponent) -> Bool {
        return lhs.size == rhs.size
    }

    final class View: UIView {
        private var component: SpacerComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: SpacerComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            return component.size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
