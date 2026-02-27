import Foundation
import UIKit
import Display
import ComponentFlow
import MeshTransform

private let backdropLayerClass: NSObject? = {
    let name = ("CA" as NSString).appendingFormat("BackdropLayer")
    if let cls = NSClassFromString(name as String) as AnyObject as? NSObject {
        return cls
    }
    return nil
}()

@inline(__always)
private func getMethod<T>(object: NSObject, selector: String) -> T? {
    guard let method = object.method(for: NSSelectorFromString(selector)) else {
        return nil
    }
    return unsafeBitCast(method, to: T.self)
}

private var cachedBackdropLayerAllocMethod: (@convention(c) (AnyObject, Selector) -> NSObject?, Selector)?
private func invokeBackdropLayerCreateMethod() -> NSObject? {
    guard let backdropLayerClass = backdropLayerClass else {
        return nil
    }
    if let cachedBackdropLayerAllocMethod {
        return cachedBackdropLayerAllocMethod.0(backdropLayerClass, cachedBackdropLayerAllocMethod.1)
    } else {
        let method: (@convention(c) (AnyObject, Selector) -> NSObject?)? = getMethod(object: backdropLayerClass, selector: "alloc")
        if let method {
            let selector = NSSelectorFromString("alloc")
            cachedBackdropLayerAllocMethod = (method, selector)
            return method(backdropLayerClass, selector)
        } else {
            return nil
        }
    }
}

private var cachedBackdropLayerInitMethod: (@convention(c) (NSObject, Selector) -> NSObject?, Selector)?
private func invokeBackdropLayerInitMethod(object: NSObject) -> NSObject? {
    if let cachedBackdropLayerInitMethod {
        return cachedBackdropLayerInitMethod.0(object, cachedBackdropLayerInitMethod.1)
    } else {
        let method: (@convention(c) (AnyObject, Selector) -> NSObject?)? = getMethod(object: object, selector: "init")
        if let method {
            let selector = NSSelectorFromString("init")
            cachedBackdropLayerInitMethod = (method, selector)
            return method(object, selector)
        } else {
            return nil
        }
    }
}

public func createBackdropLayer() -> CALayer? {
    return invokeBackdropLayerCreateMethod().flatMap(invokeBackdropLayerInitMethod) as? CALayer
}


private var cachedBackdropLayerSetScaleMethod: (@convention(c) (NSObject, Selector, Double) -> Void, Selector)?
private func invokeBackdropLayerSetScaleMethod(object: NSObject, scale: Double) {
    if let cachedBackdropLayerSetScaleMethod {
        cachedBackdropLayerSetScaleMethod.0(object, cachedBackdropLayerSetScaleMethod.1, scale)
    } else {
        let method: (@convention(c) (AnyObject, Selector, Double) -> Void)? = getMethod(object: object, selector: "setScale:")
        if let method {
            let selector = NSSelectorFromString("setScale:")
            cachedBackdropLayerSetScaleMethod = (method, selector)
            return method(object, selector, scale)
        }
    }
}

private final class BackdropLayerDelegate: NSObject, CALayerDelegate {
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return nullAction
    }
}

final class LegacyGlassView: UIView {
    private struct Params: Equatable {
        let size: CGSize
        let cornerRadius: CGFloat
        
        init(size: CGSize, cornerRadius: CGFloat) {
            self.size = size
            self.cornerRadius = cornerRadius
        }
    }
    
    private var params: Params?
    
    private let backdropLayer: CALayer?
    private let backdropLayerDelegate: BackdropLayerDelegate
    
    override init(frame: CGRect) {
        self.backdropLayerDelegate = BackdropLayerDelegate()
        self.backdropLayer = createBackdropLayer()
        
        super.init(frame: frame)
        
        self.layer.cornerCurve = .circular
        self.clipsToBounds = true
        
        if let backdropLayer = self.backdropLayer {
            self.layer.addSublayer(backdropLayer)
            backdropLayer.delegate = self.backdropLayerDelegate
            
            let blur: CGFloat
            let scale: CGFloat
            
            blur = 2.0
            scale = 1.0
            
            invokeBackdropLayerSetScaleMethod(object: backdropLayer, scale: scale)
            backdropLayer.rasterizationScale = scale
            
            if let blurFilter = CALayer.blur() {
                blurFilter.setValue(blur as NSNumber, forKey: "inputRadius")
                backdropLayer.filters = [blurFilter]
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        let params = Params(size: size, cornerRadius: cornerRadius)
        if self.params == params {
            return
        }
        self.params = params
        
        guard let backdropLayer = self.backdropLayer else {
            return
        }
        
        transition.setCornerRadius(layer: self.layer, cornerRadius: cornerRadius)
        transition.setFrame(layer: backdropLayer, frame: CGRect(origin: CGPoint(), size: size))
        
        if !"".isEmpty {
            let size = CGSize(width: max(1.0, size.width), height: max(1.0, size.height))
            let cornerRadius = min(min(size.width, size.height) * 0.5, cornerRadius)
            let displacementMagnitudePoints: CGFloat = 20.0
            let displacementMagnitudeU = displacementMagnitudePoints / size.width
            let displacementMagnitudeV = displacementMagnitudePoints / size.height
            let outerEdgeDistance = 2.0
            
            if let displacementMap = generateDisplacementMap(size: size, cornerRadius: cornerRadius, edgeDistance: min(12.0, cornerRadius), scale: 1.0) {
                let meshTransform = generateGlassMeshFromDisplacementMap(
                    size: size,
                    cornerRadius: cornerRadius,
                    displacementMap: displacementMap,
                    displacementMagnitudeU: displacementMagnitudeU,
                    displacementMagnitudeV: displacementMagnitudeV,
                    cornerResolution: 12,
                    outerEdgeDistance: outerEdgeDistance,
                    bezier: DisplacementBezier(
                        x1: 0.816137566137566,
                        y1: 0.20502645502645533,
                        x2: 0.5806878306878306,
                        y2: 0.873015873015873
                    )
                ).mesh.makeValue()
                
                if let meshTransform {
                    if !transition.animation.isImmediate, let previousTransform = backdropLayer.value(forKey: "meshTransform") as? NSObject {
                        backdropLayer.removeAnimation(forKey: "meshTransform")
                        backdropLayer.setValue(meshTransform, forKey: "meshTransform")
                        transition.animateMeshTransform(layer: backdropLayer, from: previousTransform, to: meshTransform)
                    } else {
                        backdropLayer.setValue(meshTransform, forKey: "meshTransform")
                    }
                }
            }
        }
    }
}
