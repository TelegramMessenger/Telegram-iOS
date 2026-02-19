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
    
    private let emptyLayerDelegate = EmptyLayerDelegate()
    
    private let sdfElementLayer: CALayer?
    private let sdfLayer: CALayer?
    private let displacementEffect: NSObject?
    
    private(set) var state: State = .animatedOut
    
    override public init(frame: CGRect) {
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
    
    private func setIsFilterActive(isFilterActive: Bool) {
        if isFilterActive {
            if self.layer.filters == nil {
                if let sdfLayer = self.sdfLayer {
                    self.layer.insertSublayer(sdfLayer, at: 0)
                }
                if let displacementFilter = CALayer.displacementMap(), let blurFilter = CALayer.blur() {
                    setFilterName(object: blurFilter, name: "gaussianBlur")
                    blurFilter.setValue(true, forKey: "inputNormalizeEdgesTransparent")
                    
                    setFilterName(object: displacementFilter, name: "displacementMap")
                    displacementFilter.setValue("sdfLayer", forKey: "inputSourceSublayerName")
                    
                    self.layer.filters = [
                        blurFilter,
                        displacementFilter
                    ]
                }
            }
        } else if self.layer.filters != nil {
            self.layer.filters = nil
            if let sdfLayer = self.sdfLayer {
                sdfLayer.removeFromSuperlayer()
            }
        }
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, state: State, transition: ComponentTransition) {
        let minHeight: CGFloat = 60.0
        let fullHeight: CGFloat = 30.0
        let fullAmount: CGFloat = -40.0
        let fullBlur: CGFloat = 2.0
        
        let previousState = self.state
        self.state = state
        if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer, sdfLayer.bounds.size != size || previousState != state {
            let previousSize = sdfLayer.bounds.size
            
            self.setIsFilterActive(isFilterActive: true)
            
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
            
            let height: CGFloat = state == .animatedIn ? minHeight : fullHeight
            let amount: CGFloat = state == .animatedIn ? 0.0 : fullAmount
            let blur: CGFloat = state == .animatedIn ? 0.0 : fullBlur
            self.layer.setValue(height as NSNumber, forKeyPath: "sublayers.sdfLayer.effect.height")
            self.layer.setValue(amount as NSNumber, forKeyPath: "filters.displacementMap.inputAmount")
            self.layer.setValue(blur as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
            
            if !transition.animation.isImmediate && previousSize != .zero {
                if previousState != state {
                    let previousHeight: CGFloat = previousState == .animatedIn ? minHeight : fullHeight
                    let previousAmount: CGFloat = previousState == .animatedIn ? 0.0 : fullAmount
                    let previousBlur: CGFloat = previousState == .animatedIn ? 0.0 : fullBlur
                    
                    let glassTransition: ComponentTransition = transition
                    
                    glassTransition.animateScalarFloat(layer: self.layer, keyPath: "sublayers.sdfLayer.effect.height", from: previousHeight, to: height, delay: 0.0)
                    glassTransition.animateScalarFloat(layer: self.layer, keyPath: "filters.displacementMap.inputAmount", from: previousAmount, to: amount, delay: 0.0)
                    
                    transition.animateScalarFloat(layer: self.layer, keyPath: "filters.gaussianBlur.inputRadius", from: previousBlur, to: blur)
                }
            }
        }
    }
}
