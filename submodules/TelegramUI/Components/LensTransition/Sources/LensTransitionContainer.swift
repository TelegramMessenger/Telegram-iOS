import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent

@inline(__always)
private func getMethod<T>(object: NSObject, selector: String) -> T? {
    guard let method = object.method(for: NSSelectorFromString(selector)) else {
        return nil
    }
    return unsafeBitCast(method, to: T.self)
}

private var cachedClasses: [String: NSObject] = [:]
private func getAndCacheClass(name: String) -> NSObject? {
    if let value = cachedClasses[name] {
        return value
    } else {
        if let value = NSClassFromString(name as String) as AnyObject as? NSObject {
            cachedClasses[name] = value
            return value
        } else {
            return nil
        }
    }
}

private var cachedAllocMethods: [String: (@convention(c) (AnyObject, Selector) -> NSObject?, Selector)] = [:]
private func invokeAllocMethod(className: String) -> NSObject? {
    guard let classObject = getAndCacheClass(name: className) else {
        return nil
    }
    if let cachedMethod = cachedAllocMethods[className] {
        return cachedMethod.0(classObject, cachedMethod.1)
    } else {
        let method: (@convention(c) (AnyObject, Selector) -> NSObject?)? = getMethod(object: classObject, selector: "alloc")
        if let method {
            let selector = NSSelectorFromString("alloc")
            cachedAllocMethods[className] = (method, selector)
            return method(classObject, selector)
        } else {
            return nil
        }
    }
}

private var cachedInitMethods: [String: (@convention(c) (AnyObject, Selector) -> NSObject?, Selector)] = [:]
private func invokeInitMethod(className: String, object: NSObject) -> NSObject? {
    if let cachedInitMethod = cachedInitMethods[className] {
        return cachedInitMethod.0(object, cachedInitMethod.1)
    } else {
        let method: (@convention(c) (AnyObject, Selector) -> NSObject?)? = getMethod(object: object, selector: "init")
        if let method {
            let selector = NSSelectorFromString("init")
            cachedInitMethods[className] = (method, selector)
            return method(object, selector)
        } else {
            return nil
        }
    }
}

private func createObject(className: String) -> NSObject? {
    if let object = invokeAllocMethod(className: className) {
        return invokeInitMethod(className: className, object: object)
    } else {
        return nil
    }
}

private func setFilterName(object: NSObject, name: String) {
    object.perform(NSSelectorFromString("setName:"), with: name)
}

public protocol LensTransitionContainerEffectView: UIView {
    func updateSize(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition)
    func updateSize(duration: Double, keyframes: [CGSize])
    func updateCornerRadius(duration: Double, keyframes: [CGFloat])
}

private final class EmptyLayerDelegate: NSObject, CALayerDelegate {
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return nullAction
    }
}

public final class LensTransitionContainer: UIView {
    public let effectView: LensTransitionContainerEffectView?
    public let sourceEffectView: LensTransitionContainerEffectView?
    private let containerView: UIView
    public let contentsEffectView: UIView
    public let contentsView: UIView

    private let emptyLayerDelegate = EmptyLayerDelegate()

    private let sdfElementLayer: CALayer?
    private let sdfLayer: CALayer?
    private let displacementEffect: NSObject?

    public init(effectView: LensTransitionContainerEffectView? = nil, sourceEffectView: LensTransitionContainerEffectView? = nil) {
        self.containerView = UIView()
        self.effectView = effectView
        self.sourceEffectView = sourceEffectView
        self.contentsEffectView = UIView()
        self.contentsView = UIView()

        if #available(iOS 26.0, *) {
            self.sdfElementLayer = createObject(className: ("CAS" as NSString).appending("DFElementLayer") as String) as? CALayer
            self.sdfLayer = createObject(className: ("CAS" as NSString).appending("DFLayer")) as? CALayer
            self.displacementEffect = createObject(className: ("CAS" as NSString).appending("DFGlassDisplacementEffect"))
        } else {
            self.sdfElementLayer = nil
            self.sdfLayer = nil
            self.displacementEffect = nil
        }

        super.init(frame: CGRect())

        self.addSubview(self.containerView)
        self.contentsView.clipsToBounds = true

        if let effectView = self.effectView {
            self.containerView.addSubview(effectView)
        }

        self.containerView.addSubview(self.contentsEffectView)
        self.contentsEffectView.addSubview(self.contentsView)

        if let displacementEffect = self.displacementEffect {
            displacementEffect.setValue(1.0, forKey: "curvature")
            displacementEffect.setValue(0.0 as NSNumber, forKey: "angle")
        }

        if let sdfLayer = self.sdfLayer, let displacementEffect = self.displacementEffect {
            sdfLayer.name = "sdfLayer"
            sdfLayer.setValue(UIScreenScale, forKey: "scale")
            sdfLayer.setValue(displacementEffect, forKey: "effect")
            sdfLayer.delegate = self.emptyLayerDelegate
        }

        if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
            sdfElementLayer.setValue(0.5 as NSNumber, forKey: "gradientOvalization")
            sdfElementLayer.isOpaque = true
            sdfElementLayer.allowsEdgeAntialiasing = true
            let sdfLayerDelegate = unsafeBitCast(sdfLayer, to: CALayerDelegate.self)
            sdfElementLayer.delegate = sdfLayerDelegate
            sdfElementLayer.setValue(UIScreenScale, forKey: "scale")
            sdfLayer.addSublayer(sdfElementLayer)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero {
            return nil
        }
        for view in self.contentsView.subviews.reversed() {
            if let result = view.hitTest(self.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                return result
            }
        }

        let result = self.contentsView.hitTest(point, with: event)
        if result != self.contentsView {
            return result
        } else {
            return nil
        }
    }

    private func setIsFilterActive(isFilterActive: Bool) {
        if isFilterActive {
            if self.contentsEffectView.layer.filters == nil {
                if let sdfLayer = self.sdfLayer {
                    self.contentsEffectView.layer.insertSublayer(sdfLayer, at: 0)
                }
                if let displacementFilter = CALayer.displacementMap(), let blurFilter = CALayer.blur() {
                    setFilterName(object: blurFilter, name: "gaussianBlur")
                    blurFilter.setValue(true, forKey: "inputNormalizeEdgesTransparent")

                    setFilterName(object: displacementFilter, name: "displacementMap")
                    displacementFilter.setValue("sdfLayer", forKey: "inputSourceSublayerName")

                    self.contentsEffectView.layer.rasterizationScale = UIScreenScale
                    self.contentsEffectView.layer.filters = [
                        blurFilter,
                        displacementFilter
                    ]
                }
            }
        } else if self.contentsEffectView.layer.filters != nil {
            self.contentsEffectView.layer.filters = nil
            if let sdfLayer = self.sdfLayer {
                sdfLayer.removeFromSuperlayer()
            }
        }
    }

    public func animateIn(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat) {
        self.setIsFilterActive(isFilterActive: true)

        let duration = 0.5
        let toSize = toRect.size

        if let sourceEffectView = self.sourceEffectView, !"".isEmpty {
            self.insertSubview(sourceEffectView, at: 0)
            sourceEffectView.frame = fromRect
            sourceEffectView.updateSize(size: fromRect.size, cornerRadius: fromCornerRadius, transition: .immediate)

            let minSide = min(toSize.width, toSize.height)
            let maxSide = max(toSize.width, toSize.height)

            let sizeKeyframes: [CGSize] = (0 ..< 30).map { i in
                let t = CGFloat(i) / (30.0 - 1.0)
                let scale = scaleEase(t)
                let sideFraction = max(0.0, min(1.0, sideFractionEase(t)))
                let side = (1.0 - sideFraction) * minSide + sideFraction * maxSide
                let size: CGSize
                if toSize.width > toSize.height {
                    size = CGSize(width: side, height: minSide)
                } else {
                    size = CGSize(width: minSide, height: side)
                }
                return CGSize(width: size.width * scale, height: size.height * scale)
            }

            let cornerRadiusKeyframes: [CGFloat] = (0 ..< 30).map { i in
                let t = CGFloat(i) / (30.0 - 1.0)
                let scale = scaleEase(t)
                let fraction = max(0.0, min(1.0, radiusFractionEase(t)))
                let radius = (1.0 - fraction) * (minSide * 0.5) + fraction * toCornerRadius
                return radius * scale
            }

            sourceEffectView.updateSize(duration: duration, keyframes: sizeKeyframes)
            sourceEffectView.updateCornerRadius(duration: duration, keyframes: cornerRadiusKeyframes)

            let fromCenter = CGPoint(x: fromRect.midX, y: fromRect.midY)
            let toCenter = CGPoint(x: toRect.midX, y: toRect.midY)

            var options: UIView.KeyframeAnimationOptions = [.calculationModeLinear]
            options.insert(UIView.KeyframeAnimationOptions(rawValue: UIView.AnimationOptions.curveLinear.rawValue))
            UIView.animateKeyframes(
                withDuration: duration,
                delay: 0.0,
                options: options,
                animations: {
                    let segmentCount = 29
                    let step = 1.0 / Double(segmentCount)
                    for i in 0 ..< segmentCount {
                        let t = CGFloat(i + 1) / (30.0 - 1.0)
                        let fx = positionXFractionEase(t)
                        let fy = positionYFractionEase(t)
                        let center = CGPoint(
                            x: (1.0 - fx) * fromCenter.x + fx * toCenter.x,
                            y: (1.0 - fy) * fromCenter.y + fy * toCenter.y
                        )
                        UIView.addKeyframe(
                            withRelativeStartTime: Double(i) * step,
                            relativeDuration: step
                        ) {
                            sourceEffectView.center = center
                        }
                    }
                },
                completion: { [weak sourceEffectView] finished in
                    if finished {
                        sourceEffectView?.removeFromSuperview()
                    }
                }
            )
        }

        do {
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = (0 ..< 30).map { i in
                let t = CGFloat(i) / (30.0 - 1.0)
                return scaleEase(t) as NSNumber
            }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.containerView.layer.add(keyframeAnimation, forKey: "transform.scale")
        }
        do {
            let minSide = min(toSize.width, toSize.height)
            let maxSide = max(toSize.width, toSize.height)
            let sizes: [CGSize] = (0 ..< 30).map { i in
                let t = CGFloat(i) / (30.0 - 1.0)
                let fraction = max(0.0, min(1.0, sideFractionEase(t)))
                let value = (1.0 - fraction) * minSide + fraction * maxSide
                if toSize.width > toSize.height {
                    return CGSize(width: value, height: minSide)
                } else {
                    return CGSize(width: minSide, height: value)
                }
            }

            let keyframeAnimation = CAKeyframeAnimation(keyPath: "bounds.size")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = sizes.map {
                NSValue(cgSize: $0)
            }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.contentsView.layer.add(keyframeAnimation, forKey: "bounds.size")
            self.contentsEffectView.layer.add(keyframeAnimation, forKey: "bounds.size")

            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(keyframeAnimation, forKey: "bounds.size")
                sdfElementLayer.add(keyframeAnimation, forKey: "bounds.size")
            }

            let positions: [CGPoint] = (0 ..< 30).map { i in
                let t = CGFloat(i) / (30.0 - 1.0)
                let fraction = max(0.0, min(1.0, sideFractionEase(t)))
                let value = (1.0 - fraction) * minSide + fraction * maxSide
                let size: CGSize
                if toSize.width > toSize.height {
                    size = CGSize(width: value, height: minSide)
                } else {
                    size = CGSize(width: minSide, height: value)
                }
                return CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            }
            let positionAnimation = CAKeyframeAnimation(keyPath: "position")
            positionAnimation.duration = duration * UIView.animationDurationFactor()
            positionAnimation.values = positions.map { NSValue(cgPoint: $0) }
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            positionAnimation.isRemovedOnCompletion = true
            positionAnimation.fillMode = .both
            self.contentsView.layer.add(positionAnimation, forKey: "position")
            self.contentsEffectView.layer.add(positionAnimation, forKey: "position")
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(positionAnimation, forKey: "position")
                sdfElementLayer.add(positionAnimation, forKey: "position")
            }

            if let effectView = self.effectView {
                effectView.layer.add(positionAnimation, forKey: "position")
                effectView.updateSize(duration: duration, keyframes: sizes)
            }
        }
        do {
            let fromCenter = CGPoint(x: fromRect.midX, y: fromRect.midY)
            let toCenter = CGPoint(x: toRect.midX, y: toRect.midY)
            let positions: [CGPoint] = (0..<30).map { i in
                let t = CGFloat(i) / 29.0
                let fx = positionXFractionEase(t)
                let fy = positionYFractionEase(t)
                return CGPoint(
                    x: (1.0 - fx) * fromCenter.x + fx * toCenter.x,
                    y: (1.0 - fy) * fromCenter.y + fy * toCenter.y
                )
            }

            let keyframeAnimation = CAKeyframeAnimation(keyPath: "position")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = positions.map { NSValue(cgPoint: $0) }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.containerView.layer.add(keyframeAnimation, forKey: "position")
        }
        do {
            let minSide = min(toSize.width, toSize.height)
            let radiusKeyframes = (0 ..< 30).map { i -> CGFloat in
                let t = CGFloat(i) / (30.0 - 1.0)
                let fraction = max(0.0, min(1.0, radiusFractionEase(t)))
                let value = (1.0 - fraction) * (minSide * 0.5) + fraction * toCornerRadius
                return value
            }
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "cornerRadius")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = radiusKeyframes.map { $0 as NSNumber }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.contentsView.layer.add(keyframeAnimation, forKey: "cornerRadius")
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(keyframeAnimation, forKey: "cornerRadius")
                sdfElementLayer.add(keyframeAnimation, forKey: "cornerRadius")
            }
            self.effectView?.updateCornerRadius(duration: duration, keyframes: radiusKeyframes)
        }
        do {
            self.contentsEffectView.layer.setValue(0.0 as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
            self.contentsEffectView.layer.setValue(0.0 as NSNumber, forKeyPath: "sublayers.sdfLayer.effect.height")
            self.contentsEffectView.layer.setValue(-0.001 as NSNumber, forKeyPath: "filters.displacementMap.inputAmount")

            let minSide = min(toSize.width, toSize.height)
            let fromHeight: CGFloat = minSide * 0.33
            let toHeight: CGFloat = 0.001
            let effectHeightKeyframes = (0 ..< 30).map { i -> CGFloat in
                let t = CGFloat(i) / (30.0 - 1.0)
                let fraction = max(0.0, min(1.0, displacementFractionEase(t)))
                let value = (1.0 - fraction) * fromHeight + fraction * toHeight
                return value
            }

            let heightKeyframeAnimation = CAKeyframeAnimation(keyPath: "sublayers.sdfLayer.effect.height")
            heightKeyframeAnimation.duration = duration * UIView.animationDurationFactor()
            heightKeyframeAnimation.values = effectHeightKeyframes.map { $0 as NSNumber }
            heightKeyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            heightKeyframeAnimation.isRemovedOnCompletion = true
            heightKeyframeAnimation.fillMode = .both
            self.contentsEffectView.layer.add(heightKeyframeAnimation, forKey: "sublayers.sdfLayer.effect.height")

            let displacementKeyframeAnimation = CAKeyframeAnimation(keyPath: "filters.displacementMap.inputAmount")
            displacementKeyframeAnimation.duration = duration * UIView.animationDurationFactor()
            displacementKeyframeAnimation.values = effectHeightKeyframes.map { -$0 as NSNumber }
            displacementKeyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            displacementKeyframeAnimation.isRemovedOnCompletion = true
            displacementKeyframeAnimation.fillMode = .both
            self.contentsEffectView.layer.add(displacementKeyframeAnimation, forKey: "filters.displacementMap.inputAmount")

            let blurKeyframes = (0 ..< 30).map { i -> CGFloat in
                let t = CGFloat(i) / (30.0 - 1.0)
                return blurEase(t)
            }
            let blurKeyframeAnimation = CAKeyframeAnimation(keyPath: "filters.gaussianBlur.inputRadius")
            blurKeyframeAnimation.duration = duration * UIView.animationDurationFactor()
            blurKeyframeAnimation.values = blurKeyframes.map { $0 as NSNumber }
            blurKeyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            blurKeyframeAnimation.isRemovedOnCompletion = true
            blurKeyframeAnimation.fillMode = .both
            self.contentsEffectView.layer.add(blurKeyframeAnimation, forKey: "filters.gaussianBlur.inputRadius")
        }
        do {
            let subScaleKeyframes = (0 ..< 30).map { i -> CGFloat in
                let t = CGFloat(i) / (30.0 - 1.0)
                return subScaleEase(t)
            }
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = subScaleKeyframes.map { $0 as NSNumber }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.contentsView.layer.add(keyframeAnimation, forKey: "transform.scale")
        }

        self.contentsView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + UIView.animationDurationFactor() * duration, execute: { [weak self] in
            guard let self else { return }
            self.setIsFilterActive(isFilterActive: false)
        })
    }

    public func animateOut(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat) {
        self.setIsFilterActive(isFilterActive: true)
        
        let duration: Double = 0.15

        if let sourceEffectView = self.sourceEffectView, !"".isEmpty {
            self.insertSubview(sourceEffectView, at: 0)
            sourceEffectView.frame = fromRect
            sourceEffectView.updateSize(size: fromRect.size, cornerRadius: fromCornerRadius, transition: .immediate)
            sourceEffectView.updateSize(size: toRect.size, cornerRadius: toCornerRadius, transition: .easeInOut(duration: duration))
            UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseInOut, animations: {
                sourceEffectView.center = toRect.center
            })
        }

        let fromSize = fromRect.size
        //let toSize = toRect.size
        let timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // Scale: 1.0 -> 0.097
        do {
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 1.0 as NSNumber
            animation.toValue = 0.097 as NSNumber
            animation.duration = duration * UIView.animationDurationFactor()
            animation.timingFunction = timingFunction
            animation.isRemovedOnCompletion = false
            animation.fillMode = .both
            self.containerView.layer.add(animation, forKey: "transform.scale")
        }

        // Bounds size: fromSize -> square(minSide)
        do {
            let minSide = min(fromSize.width, fromSize.height)
            let toSquare = CGSize(width: minSide, height: minSide)

            let sizeAnimation = CABasicAnimation(keyPath: "bounds.size")
            sizeAnimation.fromValue = NSValue(cgSize: fromSize)
            sizeAnimation.toValue = NSValue(cgSize: toSquare)
            sizeAnimation.duration = duration * UIView.animationDurationFactor()
            sizeAnimation.timingFunction = timingFunction
            sizeAnimation.isRemovedOnCompletion = false
            sizeAnimation.fillMode = .both
            self.contentsView.layer.add(sizeAnimation, forKey: "bounds.size")
            self.contentsEffectView.layer.add(sizeAnimation, forKey: "bounds.size")

            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(sizeAnimation, forKey: "bounds.size")
                sdfElementLayer.add(sizeAnimation, forKey: "bounds.size")
            }

            // Position tracks the center of the shrinking bounds
            let fromPosition = CGPoint(x: fromSize.width * 0.5, y: fromSize.height * 0.5)
            let toPosition = CGPoint(x: minSide * 0.5, y: minSide * 0.5)

            let positionAnimation = CABasicAnimation(keyPath: "position")
            positionAnimation.fromValue = NSValue(cgPoint: fromPosition)
            positionAnimation.toValue = NSValue(cgPoint: toPosition)
            positionAnimation.duration = duration * UIView.animationDurationFactor()
            positionAnimation.timingFunction = timingFunction
            positionAnimation.isRemovedOnCompletion = false
            positionAnimation.fillMode = .both
            self.contentsView.layer.add(positionAnimation, forKey: "position")
            self.contentsEffectView.layer.add(positionAnimation, forKey: "position")
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(positionAnimation, forKey: "position")
                sdfElementLayer.add(positionAnimation, forKey: "position")
            }

            if let effectView = self.effectView {
                effectView.layer.add(sizeAnimation, forKey: "bounds.size")
                effectView.layer.add(positionAnimation, forKey: "position")
                effectView.updateSize(size: toSquare, cornerRadius: minSide * 0.5, transition: .easeInOut(duration: duration))
            }
        }

        // Container position: fromRect center -> toRect center
        do {
            let fromCenter = CGPoint(x: fromRect.midX, y: fromRect.midY)
            let toCenter = CGPoint(x: toRect.midX, y: toRect.midY)

            let animation = CABasicAnimation(keyPath: "position")
            animation.fromValue = NSValue(cgPoint: fromCenter)
            animation.toValue = NSValue(cgPoint: toCenter)
            animation.duration = duration * UIView.animationDurationFactor()
            animation.timingFunction = timingFunction
            animation.isRemovedOnCompletion = false
            animation.fillMode = .both
            self.containerView.layer.add(animation, forKey: "position")
        }

        // Corner radius: fromCornerRadius -> minSide * 0.5 (circle)
        do {
            let minSide = min(fromSize.width, fromSize.height)
            let toRadius = minSide * 0.5

            let animation = CABasicAnimation(keyPath: "cornerRadius")
            animation.fromValue = fromCornerRadius as NSNumber
            animation.toValue = toRadius as NSNumber
            animation.duration = duration * UIView.animationDurationFactor()
            animation.timingFunction = timingFunction
            animation.isRemovedOnCompletion = false
            animation.fillMode = .both
            self.contentsView.layer.add(animation, forKey: "cornerRadius")
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(animation, forKey: "cornerRadius")
                sdfElementLayer.add(animation, forKey: "cornerRadius")
            }
            self.effectView?.updateCornerRadius(duration: duration, keyframes: [fromCornerRadius, toRadius])
        }

        // Blur: ramp from 0 to peak (~3.0)
        // No displacement animations
        do {
            self.contentsEffectView.layer.setValue(0.0 as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
            self.contentsEffectView.layer.setValue(0.0 as NSNumber, forKeyPath: "sublayers.sdfLayer.effect.height")
            self.contentsEffectView.layer.setValue(-0.001 as NSNumber, forKeyPath: "filters.displacementMap.inputAmount")

            let blurPeak: CGFloat = 3.0
            let animation = CABasicAnimation(keyPath: "filters.gaussianBlur.inputRadius")
            animation.fromValue = 0.0 as NSNumber
            animation.toValue = blurPeak as NSNumber
            animation.duration = duration * UIView.animationDurationFactor()
            animation.timingFunction = timingFunction
            animation.isRemovedOnCompletion = false
            animation.fillMode = .both
            self.contentsEffectView.layer.add(animation, forKey: "filters.gaussianBlur.inputRadius")
        }

        // SubScale: 1.0 -> 1.0 (no visible change, skip)

        // Alpha: 1.0 -> 0.0 over last 0.15s
        self.contentsView.alpha = 0.0
        self.contentsView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, delay: duration - 0.15)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + UIView.animationDurationFactor() * duration, execute: { [weak self] in
            guard let self else { return }
            self.setIsFilterActive(isFilterActive: false)
        })
    }

    public func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: size))
        transition.setPosition(view: self.containerView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        transition.setBounds(view: self.contentsView, bounds: CGRect(origin: CGPoint(), size: size))
        transition.setPosition(view: self.contentsView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        transition.setCornerRadius(layer: self.contentsView.layer, cornerRadius: cornerRadius)
        transition.setBounds(view: self.contentsEffectView, bounds: CGRect(origin: CGPoint(), size: size))
        transition.setPosition(view: self.contentsEffectView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))

        if let effectView = self.effectView {
            transition.setBounds(view: effectView, bounds: CGRect(origin: CGPoint(), size: size))
            transition.setPosition(view: effectView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
            effectView.updateSize(size: size, cornerRadius: cornerRadius, transition: transition)
        }

        if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
            transition.setFrame(layer: sdfLayer, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(layer: sdfElementLayer, frame: CGRect(origin: CGPoint(), size: size))
            sdfLayer.cornerRadius = cornerRadius
            sdfElementLayer.cornerRadius = cornerRadius
        }
    }
}

@inline(__always)
private func clamp01(_ x: Double) -> Double { max(0.0, min(1.0, x)) }

private func scaleEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let s0: Double = 0.09669952058569901
    let s1: Double = 1.0

    let k: Double  = 0.2047679706652983
    let w: Double  = 0.15481658188988102
    let B: Double  = 0.08646704068381172
    let n0: Double = -0.19300689982260073

    @inline(__always)
    func raw(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t) * (cos(w * t) + B * sin(w * t))
    }

    let base = raw(0.0)
    let end  = raw(endIndex)
    let denom = end - base
    if abs(denom) <= 1e-12 {
        return s0
    }

    let frac = (raw(n) - base) / denom

    let s = s0 + (s1 - s0) * frac
    return s
}

private func sideFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let k  = 0.4334891216702717
    let n0 = 0.8238404710496342

    @inline(__always)
    func g(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t) * (1.0 + k * t)
    }

    let gEnd = 0.9999344552429187
    let eased = g(n) / gEnd

    return max(0.0, min(1.0, eased))
}

private func radiusFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let k  = 0.5452042256694901
    let n0 = 8.025670446964643

    @inline(__always)
    func g(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t) * (1.0 + k * t)
    }

    let gEnd = g(endIndex)
    if gEnd <= 1e-12 { return 0.0 }

    let eased = g(n) / gEnd
    return max(0.0, min(1.0, eased))
}

private func positionXFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let k  = 0.4576441099336031
    let n0 = -1.1076590882287138

    @inline(__always)
    func raw(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t) * (1.0 + k * t)
    }

    let base = raw(0.0)

    @inline(__always)
    func g(_ n: Double) -> Double {
        let v = raw(n) - base
        return v > 0.0 ? v : 0.0
    }

    let gEnd = g(endIndex)
    if gEnd <= 1e-12 { return 0.0 }

    let eased = g(n) / gEnd
    return max(0.0, min(1.0, eased))
}

private func positionYFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let k  = 0.7328940609652471
    let n0 = -0.11837294418417923

    @inline(__always)
    func raw(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t)
    }

    let base = raw(0.0)

    @inline(__always)
    func g(_ n: Double) -> Double {
        let v = raw(n) - base
        return v > 0.0 ? v : 0.0
    }

    let gEnd = g(endIndex)
    if gEnd <= 1e-12 { return 0.0 }

    let eased = g(n) / gEnd
    return max(0.0, min(1.0, eased))
}

private func displacementFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let k  = 0.14743333600632425
    let w  = 31.30115940141963
    let B  = -3.3813807242203156
    let n0 = 0.1872224520792323

    @inline(__always)
    func raw(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t) * (cos(w * t) + B * sin(w * t))
    }

    let end = raw(endIndex)
    if end <= 1e-12 { return 0.0 }

    let eased = raw(n) / end
    return max(0.0, min(1.0, eased))
}

private func subScaleEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let A = 0.02941789470493528
    let k = 0.18710512325378066
    let w = 0.1871386188061029
    let B = 36.12000805553303

    @inline(__always)
    func raw(_ n: Double) -> Double {
        let e = exp(-k * n)
        return 1.0 + A * e * (cos(w * n) + B * sin(w * n))
    }

    let end = raw(endIndex)
    let shifted = raw(n) - (end - 1.0)

    return max(0.0, min(2.0, shifted))
}

private func blurEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    let A: Double  = 0.40877086657583617
    let k: Double  = 0.564
    let n0: Double = -1.4575
    let p: Double  = 3.0

    @inline(__always)
    func raw(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return A * pow(t, p) * exp(-k * t)
    }

    let tail = raw(endIndex)
    let v = raw(n) - tail

    return max(0.0, v)
}
