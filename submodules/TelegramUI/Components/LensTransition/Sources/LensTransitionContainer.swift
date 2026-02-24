import Foundation
import UIKit
import Display
import ComponentFlow

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

private final class EmptyLayerDelegate: NSObject, CALayerDelegate {
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return nullAction
    }
}

public final class LensTransitionContainer: UIView {
    public enum State {
        case animatedOut
        case animatedIn
    }

    public let contentsView: UIView

    private let emptyLayerDelegate = EmptyLayerDelegate()

    private let sdfElementLayer: CALayer?
    private let sdfLayer: CALayer?
    private let displacementEffect: NSObject?

    private(set) var state: State = .animatedOut

    override public init(frame: CGRect) {
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

        super.init(frame: frame)

        self.clipsToBounds = true
        self.addSubview(self.contentsView)
        
        //self.contentsView.backgroundColor = .blue

        let curvature: CGFloat = 1.0

        if let displacementEffect = self.displacementEffect {
            displacementEffect.setValue(curvature, forKey: "curvature")
            displacementEffect.setValue(0.0 as NSNumber, forKey: "angle")
        }

        if let sdfLayer = self.sdfLayer, let displacementEffect = self.displacementEffect {
            sdfLayer.name = "sdfLayer"
            sdfLayer.setValue(3.0, forKey: "scale")
            sdfLayer.setValue(displacementEffect, forKey: "effect")
            sdfLayer.delegate = self.emptyLayerDelegate
        }

        if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
            sdfElementLayer.setValue(0.0 as NSNumber, forKey: "gradientOvalization")
            sdfElementLayer.isOpaque = true
            sdfElementLayer.allowsEdgeAntialiasing = true
            let sdfLayerDelegate = unsafeBitCast(sdfLayer, to: CALayerDelegate.self)
            sdfElementLayer.delegate = sdfLayerDelegate
            sdfElementLayer.setValue(UIScreenScale, forKey: "scale")
            sdfLayer.addSublayer(sdfElementLayer)
        }
    }
    
    required public init?(coder: NSCoder) {
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
            if self.contentsView.layer.filters == nil {
                if let sdfLayer = self.sdfLayer {
                    self.contentsView.layer.insertSublayer(sdfLayer, at: 0)
                }
                if let displacementFilter = CALayer.displacementMap(), let blurFilter = CALayer.blur() {
                    setFilterName(object: blurFilter, name: "gaussianBlur")
                    blurFilter.setValue(true, forKey: "inputNormalizeEdgesTransparent")

                    setFilterName(object: displacementFilter, name: "displacementMap")
                    displacementFilter.setValue("sdfLayer", forKey: "inputSourceSublayerName")

                    self.contentsView.layer.filters = [
                        blurFilter,
                        displacementFilter
                    ]
                }
            }
        } else if self.contentsView.layer.filters != nil {
            self.contentsView.layer.filters = nil
            if let sdfLayer = self.sdfLayer {
                sdfLayer.removeFromSuperlayer()
            }
        }
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, state: State, transition: ComponentTransition) {
        let previousState = self.state
        self.state = state

        transition.setFrame(view: self.contentsView, frame: CGRect(origin: CGPoint(), size: size))

        if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer, sdfLayer.bounds.size != size || previousState != state {
            let previousSize = sdfLayer.bounds.size

            if previousState == .animatedOut && state == .animatedIn && !transition.animation.isImmediate && previousSize != .zero {
                self.setIsFilterActive(isFilterActive: true)
                self.animateIn(fromSize: previousSize, fromCornerRadius: sdfLayer.cornerRadius, toSize: size, toCornerRadius: cornerRadius, transition: transition)
            } else {
                transition.setFrame(layer: sdfLayer, frame: CGRect(origin: CGPoint(), size: size), completion: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.setIsFilterActive(isFilterActive: false)
                })
                transition.setCornerRadius(layer: sdfLayer, cornerRadius: cornerRadius)
                transition.setFrame(layer: sdfElementLayer, frame: CGRect(origin: CGPoint(), size: size))
                transition.setCornerRadius(layer: sdfElementLayer, cornerRadius: cornerRadius)
                transition.setCornerRadius(layer: self.layer, cornerRadius: cornerRadius)

                let phase3Height: CGFloat = 0.0
                let phase3Amount: CGFloat = -0.001
                let phase3Blur: CGFloat = 0.0
                self.contentsView.layer.setValue(phase3Height as NSNumber, forKeyPath: "sublayers.sdfLayer.effect.height")
                self.contentsView.layer.setValue(phase3Amount as NSNumber, forKeyPath: "filters.displacementMap.inputAmount")
                self.contentsView.layer.setValue(phase3Blur as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
            }
        }
    }

    private func animateIn(fromSize: CGSize, fromCornerRadius: CGFloat, toSize: CGSize, toCornerRadius: CGFloat, transition: ComponentTransition) {
        guard let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer else {
            return
        }

        let duration: Double
        let transitionTimingFunction: String
        if case let .curve(durationValue, _) = transition.animation {
            duration = durationValue
            transitionTimingFunction = kCAMediaTimingFunctionSpring
        } else {
            return
        }
        let firstPartDuration: Double = 0.35
        let timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue

        let phase1Height: CGFloat = fromCornerRadius * 0.5
        let phase1Amount: CGFloat = -phase1Height
        let phase1Scale: CGFloat = 1.05

        let phase2Height: CGFloat = min(toSize.width, toSize.height) / 3.3333
        let phase2Amount: CGFloat = -phase2Height
        let phase2Blur: CGFloat = 4.0
        let phase2Scale: CGFloat = 1.05

        let phase3Height: CGFloat = 0.0
        let phase3Amount: CGFloat = -0.001
        let phase3Blur: CGFloat = 0.0
        let phase3Scale: CGFloat = 1.0

        let capsuleCornerRadius = min(toSize.width, toSize.height) * 0.5

        let fromCenter = CGPoint(x: fromSize.width * 0.5, y: fromSize.height * 0.5)
        let toCenter = CGPoint(x: toSize.width * 0.5, y: toSize.height * 0.5)

        // --- Phase 1: circle → capsule, glass phase1 → phase2 ---
        let finalFrame = CGRect(origin: CGPoint(), size: toSize)
        sdfLayer.frame = finalFrame
        sdfElementLayer.frame = finalFrame
        self.contentsView.center = CGPoint(x: finalFrame.midX, y: finalFrame.midY)
        self.contentsView.layer.removeAllAnimations()
        sdfLayer.cornerRadius = capsuleCornerRadius
        sdfElementLayer.cornerRadius = capsuleCornerRadius
        self.layer.cornerRadius = capsuleCornerRadius
        self.contentsView.layer.setValue(phase2Height as NSNumber, forKeyPath: "sublayers.sdfLayer.effect.height")
        self.contentsView.layer.setValue(phase2Amount as NSNumber, forKeyPath: "filters.displacementMap.inputAmount")
        self.contentsView.layer.setValue(phase2Scale as NSNumber, forKeyPath: "transform.scale")
        self.contentsView.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * firstPartDuration)

        let phase1Duration = duration * firstPartDuration
        let phase2Duration = duration * (1.0 - firstPartDuration)
        let phase2BlurDuration = phase2Duration * 0.2
        
        let _ = phase2BlurDuration
        let _ = phase3Blur
        self.contentsView.layer.setValue(0.0 as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
        self.contentsView.layer.animate(from: phase2Blur as NSNumber, to: phase3Blur as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, duration: phase2BlurDuration, delay: phase1Duration * 0.8)

        for layer in [sdfLayer, sdfElementLayer] {
            layer.animate(from: NSValue(cgSize: fromSize), to: NSValue(cgSize: toSize), keyPath: "bounds.size", timingFunction: transitionTimingFunction, duration: duration)
            layer.removeAnimation(forKey: "position")
            layer.animate(from: fromCornerRadius as NSNumber, to: capsuleCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: timingFunction, duration: phase1Duration)
        }

        self.contentsView.layer.animate(from: NSValue(cgPoint: fromCenter), to: NSValue(cgPoint: toCenter), keyPath: "position", timingFunction: transitionTimingFunction, duration: duration)

        self.contentsView.layer.animate(from: phase1Height as NSNumber, to: phase2Height as NSNumber, keyPath: "sublayers.sdfLayer.effect.height", timingFunction: timingFunction, duration: phase1Duration)
        self.contentsView.layer.animate(from: phase1Amount as NSNumber, to: phase2Amount as NSNumber, keyPath: "filters.displacementMap.inputAmount", timingFunction: timingFunction, duration: phase1Duration)
        self.contentsView.layer.animate(from: phase1Scale as NSNumber, to: phase2Scale as NSNumber, keyPath: "transform.scale", timingFunction: timingFunction, duration: phase1Duration)
        self.layer.animate(from: fromCornerRadius as NSNumber, to: capsuleCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: timingFunction, duration: phase1Duration)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + UIView.animationDurationFactor() * phase1Duration, execute: { [weak self] in
            guard let self else { return }

            // --- Phase 2: capsule → final cornerRadius, glass phase2 → phase3 ---
            sdfLayer.cornerRadius = toCornerRadius
            sdfElementLayer.cornerRadius = toCornerRadius
            self.layer.cornerRadius = toCornerRadius
            self.contentsView.layer.setValue(phase3Height as NSNumber, forKeyPath: "sublayers.sdfLayer.effect.height")
            self.contentsView.layer.setValue(phase3Amount as NSNumber, forKeyPath: "filters.displacementMap.inputAmount")
            self.contentsView.layer.setValue(phase3Scale as NSNumber, forKeyPath: "transform.scale")

            for layer in [sdfLayer, sdfElementLayer] {
                layer.animate(from: capsuleCornerRadius as NSNumber, to: toCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: phase2Duration)
            }
            self.contentsView.layer.animate(from: phase2Height as NSNumber, to: phase3Height as NSNumber, keyPath: "sublayers.sdfLayer.effect.height", timingFunction: kCAMediaTimingFunctionSpring, duration: phase2Duration)
            self.contentsView.layer.animate(from: phase2Amount as NSNumber, to: phase3Amount as NSNumber, keyPath: "filters.displacementMap.inputAmount", timingFunction: kCAMediaTimingFunctionSpring, duration: phase2Duration)
            self.contentsView.layer.animate(from: phase2Scale as NSNumber, to: phase3Scale as NSNumber, keyPath: "transform.scale", timingFunction: kCAMediaTimingFunctionSpring, duration: phase2Duration)
            self.layer.animate(from: capsuleCornerRadius as NSNumber, to: toCornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: phase2Duration, completion: { [weak self] _ in
                guard let self else { return }
                self.setIsFilterActive(isFilterActive: false)
            })
        })
    }
}
