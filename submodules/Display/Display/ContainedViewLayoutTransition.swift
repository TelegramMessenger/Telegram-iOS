import Foundation
import UIKit
import AsyncDisplayKit

public enum ContainedViewLayoutTransitionCurve {
    case easeInOut
    case spring
    case custom(Float, Float, Float, Float)
    
    public static var slide: ContainedViewLayoutTransitionCurve {
        return .custom(0.33, 0.52, 0.25, 0.99)
    }
}

public extension ContainedViewLayoutTransitionCurve {
    var timingFunction: String {
        switch self {
            case .easeInOut:
                return CAMediaTimingFunctionName.easeInEaseOut.rawValue
            case .spring:
                return kCAMediaTimingFunctionSpring
            case .custom:
                return CAMediaTimingFunctionName.easeInEaseOut.rawValue
        }
    }
    
    var mediaTimingFunction: CAMediaTimingFunction? {
        switch self {
            case .easeInOut:
                return nil
            case .spring:
                return nil
            case let .custom(p1, p2, p3, p4):
                return CAMediaTimingFunction(controlPoints: p1, p2, p3, p4)
        }
    }
    
    #if os(iOS)
    var viewAnimationOptions: UIView.AnimationOptions {
        switch self {
            case .easeInOut:
                return [.curveEaseInOut]
            case .spring:
                return UIView.AnimationOptions(rawValue: 7 << 16)
            case .custom:
                return []
        }
    }
    #endif
}

public enum ContainedViewLayoutTransition {
    case immediate
    case animated(duration: Double, curve: ContainedViewLayoutTransitionCurve)
    
    public var isAnimated: Bool {
        if case .immediate = self {
            return false
        } else {
            return true
        }
    }
}

public extension ContainedViewLayoutTransition {
    func updateFrame(node: ASDisplayNode, frame: CGRect, force: Bool = false, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if node.frame.equalTo(frame) && !force {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                node.frame = frame
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousFrame: CGRect
                if beginWithCurrentState, let presentation = node.layer.presentation() {
                    previousFrame = presentation.frame
                } else {
                    previousFrame = node.frame
                }
                node.frame = frame
                node.layer.animateFrame(from: previousFrame, to: frame, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, force: force, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func updateFrameAsPositionAndBounds(node: ASDisplayNode, frame: CGRect, force: Bool = false, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if node.frame.equalTo(frame) && !force {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                node.position = frame.center
                node.bounds = CGRect(origin: CGPoint(), size: frame.size)
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousPosition: CGPoint
                let previousBounds: CGRect
                if beginWithCurrentState, let presentation = node.layer.presentation() {
                    previousPosition = presentation.position
                    previousBounds = presentation.bounds
                } else {
                    previousPosition = node.position
                    previousBounds = node.bounds
                }
                node.position = frame.center
                node.bounds = CGRect(origin: CGPoint(), size: frame.size)
                node.layer.animateFrame(from:
                    CGRect(origin: CGPoint(x: previousPosition.x - previousBounds.width / 2.0, y: previousPosition.y - previousBounds.height / 2.0), size: previousBounds.size), to: frame, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, force: force, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func updateFrameAdditive(node: ASDisplayNode, frame: CGRect, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if node.frame.equalTo(frame) && !force {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                node.frame = frame
                if let completion = completion {
                    completion(true)
                }
            case .animated:
                let previousFrame = node.frame
                node.frame = frame
                self.animatePositionAdditive(node: node, offset: CGPoint(x: previousFrame.minX - frame.minX, y: previousFrame.minY - frame.minY))
            }
        }
    }
    
    func updateFrameAdditiveToCenter(node: ASDisplayNode, frame: CGRect, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if node.frame.equalTo(frame) && !force {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                node.position = frame.center
                node.bounds = CGRect(origin: node.bounds.origin, size: frame.size)
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousBounds = node.bounds
                let previousCenter = node.frame.center
                node.position = frame.center
                node.bounds = CGRect(origin: node.bounds.origin, size: frame.size)
                self.animatePositionAdditive(node: node, offset: CGPoint(x: previousCenter.x - frame.midX, y: previousCenter.y - frame.midY))
            }
        }
    }
    
    func updateBounds(node: ASDisplayNode, bounds: CGRect, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if node.bounds.equalTo(bounds) && !force {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                node.bounds = bounds
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousBounds = node.bounds
                node.bounds = bounds
                node.layer.animateBounds(from: previousBounds, to: bounds, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, force: force, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func updateBounds(layer: CALayer, bounds: CGRect, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if layer.bounds.equalTo(bounds) && !force {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                layer.bounds = bounds
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousBounds = layer.bounds
                layer.bounds = bounds
                layer.animateBounds(from: previousBounds, to: bounds, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, force: force, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func updatePosition(node: ASDisplayNode, position: CGPoint, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if node.position.equalTo(position) {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                node.position = position
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousPosition: CGPoint
                if beginWithCurrentState {
                    previousPosition = node.layer.presentation()?.position ?? node.position
                } else {
                    previousPosition = node.position
                }
                node.position = position
                node.layer.animatePosition(from: previousPosition, to: position, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func updatePosition(layer: CALayer, position: CGPoint, completion: ((Bool) -> Void)? = nil) {
        if layer.position.equalTo(position) {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                layer.position = position
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousPosition = layer.position
                layer.position = position
                layer.animatePosition(from: previousPosition, to: position, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func animatePosition(node: ASDisplayNode, from position: CGPoint, completion: ((Bool) -> Void)? = nil) {
        switch self {
            case .immediate:
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                node.layer.animatePosition(from: position, to: node.position, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
    
    func animatePosition(node: ASDisplayNode, to position: CGPoint, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        if node.position.equalTo(position) {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                node.layer.animatePosition(from: node.position, to: position, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: removeOnCompletion, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func animateFrame(node: ASDisplayNode, from frame: CGRect, to toFrame: CGRect? = nil, removeOnCompletion: Bool = true, additive: Bool = false, completion: ((Bool) -> Void)? = nil) {
        switch self {
            case .immediate:
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                node.layer.animateFrame(from: frame, to: toFrame ?? node.layer.frame, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: additive, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
    
    func animateBounds(layer: CALayer, from bounds: CGRect, removeOnCompletion: Bool = true, completion: ((Bool) -> Void)? = nil) {
        switch self {
            case .immediate:
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                layer.animateBounds(from: bounds, to: layer.bounds, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: removeOnCompletion, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
    
    func animateOffsetAdditive(node: ASDisplayNode, offset: CGFloat) {
        switch self {
            case .immediate:
                break
            case let .animated(duration, curve):
                node.layer.animateBoundsOriginYAdditive(from: offset, to: 0.0, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction)
        }
    }
    
    func animateHorizontalOffsetAdditive(node: ASDisplayNode, offset: CGFloat) {
        switch self {
            case .immediate:
                break
            case let .animated(duration, curve):
                node.layer.animateBoundsOriginXAdditive(from: offset, to: 0.0, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction)
        }
    }
    
    func animateOffsetAdditive(layer: CALayer, offset: CGFloat, completion: (() -> Void)? = nil) {
        switch self {
            case .immediate:
                completion?()
            case let .animated(duration, curve):
                layer.animateBoundsOriginYAdditive(from: offset, to: 0.0, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { _ in
                    completion?()
                })
        }
    }
    
    func animatePositionAdditive(node: ASDisplayNode, offset: CGFloat, removeOnCompletion: Bool = true, completion: @escaping (Bool) -> Void) {
        switch self {
            case .immediate:
                completion(true)
            case let .animated(duration, curve):
                node.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: true, completion: completion)
        }
    }
    
    func animatePositionAdditive(layer: CALayer, offset: CGFloat, removeOnCompletion: Bool = true, completion: @escaping (Bool) -> Void) {
        switch self {
            case .immediate:
                completion(true)
            case let .animated(duration, curve):
                layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: true, completion: completion)
        }
    }
    
    func animatePositionAdditive(node: ASDisplayNode, offset: CGPoint, removeOnCompletion: Bool = true, completion: (() -> Void)? = nil) {
        switch self {
            case .immediate:
                completion?()
            case let .animated(duration, curve):
                node.layer.animatePosition(from: offset, to: CGPoint(), duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: true, completion: { _ in
                    completion?()
                })
        }
    }
    
    func animatePositionAdditive(layer: CALayer, offset: CGPoint, to toOffset: CGPoint = CGPoint(), removeOnCompletion: Bool = true, completion: (() -> Void)? = nil) {
        switch self {
            case .immediate:
                completion?()
            case let .animated(duration, curve):
                layer.animatePosition(from: offset, to: toOffset, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: removeOnCompletion, additive: true, completion: { _ in
                    completion?()
                })
        }
    }
    
    func updateFrame(view: UIView, frame: CGRect, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if view.frame.equalTo(frame) && !force {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                view.frame = frame
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousFrame = view.frame
                view.frame = frame
                view.layer.animateFrame(from: previousFrame, to: frame, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, force: force, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func updateFrame(layer: CALayer, frame: CGRect, completion: ((Bool) -> Void)? = nil) {
        if layer.frame.equalTo(frame) {
            completion?(true)
        } else {
            switch self {
            case .immediate:
                layer.frame = frame
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                let previousFrame = layer.frame
                layer.frame = frame
                layer.animateFrame(from: previousFrame, to: frame, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            }
        }
    }
    
    func updateAlpha(node: ASDisplayNode, alpha: CGFloat, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if node.alpha.isEqual(to: alpha) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            node.alpha = alpha
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousAlpha: CGFloat
            if beginWithCurrentState, let presentation = node.layer.presentation() {
                previousAlpha = CGFloat(presentation.opacity)
            } else {
                previousAlpha = node.alpha
            }
            node.alpha = alpha
            node.layer.animateAlpha(from: previousAlpha, to: alpha, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateAlpha(layer: CALayer, alpha: CGFloat, completion: ((Bool) -> Void)? = nil) {
        if layer.opacity.isEqual(to: Float(alpha)) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            layer.opacity = Float(alpha)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousAlpha = layer.opacity
            layer.opacity = Float(alpha)
            layer.animateAlpha(from: CGFloat(previousAlpha), to: alpha, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateBackgroundColor(node: ASDisplayNode, color: UIColor, completion: ((Bool) -> Void)? = nil) {
        if let nodeColor = node.backgroundColor, nodeColor.isEqual(color) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            node.backgroundColor = color
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            if let nodeColor = node.backgroundColor {
                node.backgroundColor = color
                node.layer.animate(from: nodeColor.cgColor, to: color.cgColor, keyPath: "backgroundColor", timingFunction: curve.timingFunction, duration: duration, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                    if let completion = completion {
                        completion(result)
                    }
                })
            } else {
                node.backgroundColor = color
                if let completion = completion {
                    completion(true)
                }
            }
        }
    }
    
    func updateCornerRadius(node: ASDisplayNode, cornerRadius: CGFloat, completion: ((Bool) -> Void)? = nil) {
        if node.cornerRadius.isEqual(to: cornerRadius) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            node.cornerRadius = cornerRadius
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousCornerRadius = node.cornerRadius
            node.cornerRadius = cornerRadius
            node.layer.animate(from: NSNumber(value: Float(previousCornerRadius)), to: NSNumber(value: Float(cornerRadius)), keyPath: "cornerRadius", timingFunction: curve.timingFunction, duration: duration, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func animateTransformScale(node: ASDisplayNode, from fromScale: CGFloat, completion: ((Bool) -> Void)? = nil) {
        let t = node.layer.transform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale.isEqual(to: fromScale) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            node.layer.animateScale(from: fromScale, to: currentScale, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func animateTransformScale(view: UIView, from fromScale: CGFloat, completion: ((Bool) -> Void)? = nil) {
        let t = view.layer.transform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale.isEqual(to: fromScale) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            view.layer.animateScale(from: fromScale, to: currentScale, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateTransformScale(node: ASDisplayNode, scale: CGFloat, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let t = node.layer.transform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale.isEqual(to: scale) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            node.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousScale: CGFloat
            if beginWithCurrentState, let presentation = node.layer.presentation() {
                let t = presentation.transform
                previousScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
            } else {
                previousScale = currentScale
            }
            node.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            node.layer.animateScale(from: previousScale, to: scale, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateTransformScale(layer: CALayer, scale: CGFloat, completion: ((Bool) -> Void)? = nil) {
        let t = layer.transform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale.isEqual(to: scale) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            layer.transform = CATransform3DMakeScale(scale, scale, 1.0)
            layer.animateScale(from: currentScale, to: scale, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateSublayerTransformScale(node: ASDisplayNode, scale: CGFloat, completion: ((Bool) -> Void)? = nil) {
        if !node.isNodeLoaded {
            node.subnodeTransform = CATransform3DMakeScale(scale, scale, 1.0)
            completion?(true)
            return
        }
        let t = node.layer.sublayerTransform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale.isEqual(to: scale) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            node.layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            node.layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0)
            node.layer.animate(from: NSValue(caTransform3D: t), to: NSValue(caTransform3D: node.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: curve.timingFunction, duration: duration, delay: 0.0, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: true, additive: false, completion: {
                result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateSublayerTransformScaleAdditive(node: ASDisplayNode, scale: CGFloat, completion: ((Bool) -> Void)? = nil) {
        if !node.isNodeLoaded {
            node.subnodeTransform = CATransform3DMakeScale(scale, scale, 1.0)
            completion?(true)
            return
        }
        let t = node.layer.sublayerTransform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        if currentScale.isEqual(to: scale) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            node.layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let t = node.layer.sublayerTransform
            let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
            node.layer.sublayerTransform = CATransform3DMakeScale(scale, scale, 1.0)
            node.layer.animate(from: -(scale - currentScale) as NSNumber, to: 0.0 as NSNumber, keyPath: "sublayerTransform.scale", timingFunction: curve.timingFunction, duration: duration, delay: 0.0, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: true, additive: true, completion: {
                result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateSublayerTransformScaleAndOffset(node: ASDisplayNode, scale: CGFloat, offset: CGPoint, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if !node.isNodeLoaded {
            node.subnodeTransform = CATransform3DMakeScale(scale, scale, 1.0)
            completion?(true)
            return
        }
        let t = node.layer.sublayerTransform
        let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        let currentOffset = CGPoint(x: t.m41 / currentScale, y: t.m42 / currentScale)
        if abs(currentScale - scale) <= CGFloat.ulpOfOne && abs(currentOffset.x - offset.x) <= CGFloat.ulpOfOne && abs(currentOffset.y - offset.y) <= CGFloat.ulpOfOne {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        let transform = CATransform3DTranslate(CATransform3DMakeScale(scale, scale, 1.0), offset.x, offset.y, 0.0)
        
        switch self {
        case .immediate:
            node.layer.sublayerTransform = transform
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let initialTransform: CATransform3D
            if beginWithCurrentState, node.isNodeLoaded {
                initialTransform = node.layer.presentation()?.sublayerTransform ?? t
            } else {
                initialTransform = t
            }
            
            node.layer.sublayerTransform = transform
            node.layer.animate(from: NSValue(caTransform3D: initialTransform), to: NSValue(caTransform3D: node.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: curve.timingFunction, duration: duration, delay: 0.0, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: true, additive: false, completion: {
                result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateSublayerTransformScale(node: ASDisplayNode, scale: CGPoint, completion: ((Bool) -> Void)? = nil) {
        if !node.isNodeLoaded {
            node.subnodeTransform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
            completion?(true)
            return
        }
        let t = node.layer.sublayerTransform
        let currentScaleX = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        var currentScaleY = sqrt((t.m21 * t.m21) + (t.m22 * t.m22) + (t.m23 * t.m23))
        if t.m22 < 0.0 {
            currentScaleY = -currentScaleY
        }
        if CGPoint(x: currentScaleX, y: currentScaleY) == scale {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
            case .immediate:
                node.layer.sublayerTransform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                node.layer.sublayerTransform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
                node.layer.animate(from: NSValue(caTransform3D: t), to: NSValue(caTransform3D: node.layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: curve.timingFunction, duration: duration, delay: 0.0, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: true, additive: false, completion: {
                    result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
    
    func updateSublayerTransformScale(layer: CALayer, scale: CGPoint, completion: ((Bool) -> Void)? = nil) {
        let t = layer.sublayerTransform
        let currentScaleX = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        var currentScaleY = sqrt((t.m21 * t.m21) + (t.m22 * t.m22) + (t.m23 * t.m23))
        if t.m22 < 0.0 {
            currentScaleY = -currentScaleY
        }
        if CGPoint(x: currentScaleX, y: currentScaleY) == scale {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            layer.sublayerTransform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            layer.sublayerTransform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
            layer.animate(from: NSValue(caTransform3D: t), to: NSValue(caTransform3D: layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: curve.timingFunction, duration: duration, delay: 0.0, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: true, additive: false, completion: {
                result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateTransformScale(node: ASDisplayNode, scale: CGPoint, completion: ((Bool) -> Void)? = nil) {
        if !node.isNodeLoaded {
            node.subnodeTransform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
            completion?(true)
            return
        }
        let t = node.layer.transform
        let currentScaleX = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
        var currentScaleY = sqrt((t.m21 * t.m21) + (t.m22 * t.m22) + (t.m23 * t.m23))
        if t.m22 < 0.0 {
            currentScaleY = -currentScaleY
        }
        if CGPoint(x: currentScaleX, y: currentScaleY) == scale {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
            case .immediate:
                node.layer.transform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
                if let completion = completion {
                    completion(true)
                }
            case let .animated(duration, curve):
                node.layer.transform = CATransform3DMakeScale(scale.x, scale.y, 1.0)
                node.layer.animate(from: NSValue(caTransform3D: t), to: NSValue(caTransform3D: node.layer.transform), keyPath: "transform", timingFunction: curve.timingFunction, duration: duration, delay: 0.0, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: true, additive: false, completion: {
                    result in
                    if let completion = completion {
                        completion(result)
                    }
                })
        }
    }
    
    func updateSublayerTransformOffset(layer: CALayer, offset: CGPoint, completion: ((Bool) -> Void)? = nil) {
        let t = layer.sublayerTransform
        let currentOffset = CGPoint(x: t.m41, y: t.m42)
        if currentOffset == offset {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            layer.sublayerTransform = CATransform3DMakeTranslation(offset.x, offset.y, 0.0)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            layer.sublayerTransform = CATransform3DMakeTranslation(offset.x, offset.y, 0.0)
            layer.animate(from: NSValue(caTransform3D: t), to: NSValue(caTransform3D: layer.sublayerTransform), keyPath: "sublayerTransform", timingFunction: curve.timingFunction, duration: duration, delay: 0.0, mediaTimingFunction: curve.mediaTimingFunction, removeOnCompletion: true, additive: false, completion: {
                result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
    
    func updateTransformRotation(node: ASDisplayNode, angle: CGFloat, beginWithCurrentState: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let t = node.layer.transform
        let currentAngle = atan2(t.m12, t.m11)
        if currentAngle.isEqual(to: angle) {
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        switch self {
        case .immediate:
            node.layer.transform = CATransform3DMakeRotation(angle, 0.0, 0.0, 1.0)
            if let completion = completion {
                completion(true)
            }
        case let .animated(duration, curve):
            let previousAngle: CGFloat
            if beginWithCurrentState, let presentation = node.layer.presentation() {
                let t = presentation.transform
                previousAngle = atan2(t.m12, t.m11)
            } else {
                previousAngle = currentAngle
            }
            node.layer.transform = CATransform3DMakeRotation(angle, 0.0, 0.0, 1.0)
            node.layer.animateRotation(from: previousAngle, to: angle, duration: duration, timingFunction: curve.timingFunction, mediaTimingFunction: curve.mediaTimingFunction, completion: { result in
                if let completion = completion {
                    completion(result)
                }
            })
        }
    }
}

#if os(iOS)
    
public extension ContainedViewLayoutTransition {
    func animateView(_ f: @escaping () -> Void) {
        switch self {
        case .immediate:
            f()
        case let .animated(duration, curve):
            UIView.animate(withDuration: duration, delay: 0.0, options: curve.viewAnimationOptions, animations: {
                f()
            }, completion: nil)
        }
    }
}
    
#endif
