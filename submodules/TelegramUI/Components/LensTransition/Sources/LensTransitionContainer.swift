import Foundation
import UIKit
import Display
import ComponentFlow
import Display
import UIKitRuntimeUtils
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

private func createFilter(name: String) -> NSObject? {
    if let classValue = NSClassFromString("CAFilter") as AnyObject as? NSObject {
        return classValue.perform(NSSelectorFromString("filterWithName:"), with: name).takeUnretainedValue() as? NSObject
    } else {
        return nil
    }
}

private func setFilterName(object: NSObject, name: String) {
    object.perform(NSSelectorFromString("setName:"), with: name)
}

private final class EmptyLayerDelegate: NSObject, CALayerDelegate {
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return NSNull()
    }
}

public protocol LensTransitionContainerEffectView: UIView {
    func updateSize(duration: Double, keyframes: [CGSize])
    func updateSize(size: CGSize, transition: ComponentTransition)
    func updatePosition(duration: Double, keyframes: [CGPoint])
    func updatePosition(position: CGPoint, transition: ComponentTransition)
    func updateCornerRadius(duration: Double, keyframes: [CGFloat])
    func setTransitionFraction(value: CGFloat, duration: Double)
}

public protocol LensTransitionContainerProtocol: UIView {
    var contentsView: UIView { get }
    
    func animateIn(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView)
    func animateOut(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView)
    func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, transition: ComponentTransition)
}

@available(iOS 26.0, *)
final class LensTransitionContainerImpl: UIView, LensTransitionContainerProtocol {
    private let effectSettingsContainerView: EffectSettingsContainerView
    public let effectView: LensTransitionContainerEffectView
    private let containerView: UIView
    public let contentsEffectView: UIView
    public let contentsView: UIView
    
    private let emptyLayerDelegate = EmptyLayerDelegate()
    
    private let sdfElementLayer: CALayer?
    private let sdfLayer: CALayer?
    private let displacementEffect: NSObject?
    
    init(effectView: LensTransitionContainerEffectView) {
        self.effectSettingsContainerView = EffectSettingsContainerView()
        
        self.containerView = UIView()
        self.effectView = effectView
        self.contentsEffectView = UIView()
        self.contentsView = UIView()
        
        self.sdfElementLayer = createObject(className: "CASDFElementLayer") as? CALayer
        self.sdfLayer = createObject(className: "CASDFLayer") as? CALayer
        self.displacementEffect = createObject(className: "CASDFGlassDisplacementEffect")
        
        super.init(frame: CGRect())
        
        self.addSubview(self.effectSettingsContainerView)
        self.effectSettingsContainerView.addSubview(self.containerView)
        self.contentsView.clipsToBounds = true
        
        self.containerView.addSubview(self.effectView)
        
        self.containerView.addSubview(self.contentsEffectView)
        self.contentsEffectView.addSubview(self.contentsView)
        
        if let displacementEffect = self.displacementEffect {
            displacementEffect.setValue(1.0, forKey: "curvature")
            displacementEffect.setValue(0.0 as NSNumber, forKey: "angle")
        }
        
        if let sdfLayer = self.sdfLayer, let displacementEffect = self.displacementEffect {
            sdfLayer.name = "sdfLayer"
            sdfLayer.setValue(3.0, forKey: "scale")
            sdfLayer.setValue(displacementEffect, forKey: "effect")
            sdfLayer.delegate = self.emptyLayerDelegate
        }
        
        if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
            sdfElementLayer.setValue(0.5 as NSNumber, forKey: "gradientOvalization")
            sdfElementLayer.isOpaque = true
            sdfElementLayer.allowsEdgeAntialiasing = true
            let sdfLayerDelegate = unsafeBitCast(sdfLayer, to: CALayerDelegate.self)
            sdfElementLayer.delegate = sdfLayerDelegate
            sdfElementLayer.setValue(3.0, forKey: "scale")
            sdfLayer.addSublayer(sdfElementLayer)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setIsFilterActive(isFilterActive: Bool) {
        if isFilterActive {
            if self.contentsEffectView.layer.filters == nil {
                if let sdfLayer = self.sdfLayer {
                    self.contentsEffectView.layer.insertSublayer(sdfLayer, at: 0)
                }
                if let blurFilter = createFilter(name: "gaussianBlur"), let displacementFilter = createFilter(name: "displacementMap") {
                    setFilterName(object: blurFilter, name: "gaussianBlur")
                    setFilterName(object: displacementFilter, name: "displacementMap")
                    displacementFilter.setValue("sdfLayer", forKey: "inputSourceSublayerName")
                    
                    self.contentsEffectView.layer.rasterizationScale = 3.0
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
    
    private func cancelAnimationsRecursively(layer: CALayer) {
        layer.removeAllAnimations()
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                self.cancelAnimationsRecursively(layer: sublayer)
            }
        }
    }
    
    private func cancelAnimationsRecursively(view: UIView) {
        self.cancelAnimationsRecursively(layer: view.layer)
        for subview in view.subviews {
            self.cancelAnimationsRecursively(view: subview)
        }
    }
    
    private func cancelCurrentTransitionAnimations(sourceEffectView: LensTransitionContainerEffectView) {
        self.cancelAnimationsRecursively(view: self.effectView)
        self.cancelAnimationsRecursively(view: self.contentsEffectView)
        self.cancelAnimationsRecursively(view: self.contentsView)
        self.cancelAnimationsRecursively(view: self.containerView)
        self.cancelAnimationsRecursively(view: sourceEffectView)
        
        if let sdfLayer = self.sdfLayer {
            self.cancelAnimationsRecursively(layer: sdfLayer)
        }
        if let sdfElementLayer = self.sdfElementLayer {
            self.cancelAnimationsRecursively(layer: sdfElementLayer)
        }
    }
    
    private struct TransitionKeyframes {
        let bakedSizes: [CGSize]
        let bakedPositions: [CGPoint]
        let localPositions: [CGPoint]
        let sourcePositions: [CGPoint]
        let radiusKeyframes: [CGFloat]
        let containerPositions: [CGPoint]
        let minSide: CGFloat
    }

    private func makeForwardTransitionKeyframes(fromRect: CGRect, toRect: CGRect, toCornerRadius: CGFloat) -> TransitionKeyframes {
        let sourceMaxEdgeDistance: CGFloat = 20.0
        let sourceSuckDurationFraction: CGFloat = 0.9
        let sourceFinalFurthestInsideDistance: CGFloat = -8.0
        let sourceFinalInsideStartFraction: CGFloat = 0.65
        let sourceFullInsideInset: CGFloat = max(1.0, min(fromRect.width, fromRect.height) * 0.5)
        let sampleCount = 30
        let sampleEndIndex = CGFloat(sampleCount - 1)
        let toSize = toRect.size
        let toHalf = CGPoint(x: toSize.width * 0.5, y: toSize.height * 0.5)
        let minSide = min(toSize.width, toSize.height)
        let maxSide = max(toSize.width, toSize.height)
        let fromCenter = CGPoint(x: fromRect.midX, y: fromRect.midY)
        let toCenter = CGPoint(x: toRect.midX, y: toRect.midY)
        let centerLineDelta = CGPoint(x: fromCenter.x - toCenter.x, y: fromCenter.y - toCenter.y)
        let centerLineLength = hypot(centerLineDelta.x, centerLineDelta.y)
        let centerLineDirection: CGPoint = centerLineLength > 1e-6 ? CGPoint(x: centerLineDelta.x / centerLineLength, y: centerLineDelta.y / centerLineLength) : CGPoint(x: 1.0, y: 0.0)
        let centerLineMinDistance: CGFloat = -centerLineLength
        
        func isPointInsideRoundedRect(point: CGPoint, rectCenter: CGPoint, rectSize: CGSize, cornerRadius: CGFloat) -> Bool {
            let halfWidth = rectSize.width * 0.5
            let halfHeight = rectSize.height * 0.5
            if halfWidth <= 0.0 || halfHeight <= 0.0 {
                return false
            }
            let radius = max(0.0, min(cornerRadius, min(halfWidth, halfHeight)))
            
            let localX = point.x - rectCenter.x
            let localY = point.y - rectCenter.y
            let absX = abs(localX)
            let absY = abs(localY)
            
            if absX > halfWidth || absY > halfHeight {
                return false
            }
            
            if absX <= halfWidth - radius || absY <= halfHeight - radius {
                return true
            }
            
            let cornerCenter = CGPoint(
                x: (halfWidth - radius) * (localX >= 0.0 ? 1.0 : -1.0),
                y: (halfHeight - radius) * (localY >= 0.0 ? 1.0 : -1.0)
            )
            let dx = localX - cornerCenter.x
            let dy = localY - cornerCenter.y
            return dx * dx + dy * dy <= radius * radius
        }
        
        func nearestBoundaryPointOnRoundedRect(point: CGPoint, rectCenter: CGPoint, rectSize: CGSize, cornerRadius: CGFloat) -> CGPoint {
            @inline(__always)
            func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
                return max(lower, min(upper, value))
            }
            
            @inline(__always)
            func normalizedAngle(_ angle: CGFloat) -> CGFloat {
                let twoPi = CGFloat.pi * 2.0
                var value = angle.truncatingRemainder(dividingBy: twoPi)
                if value < 0.0 {
                    value += twoPi
                }
                return value
            }
            
            @inline(__always)
            func clampedRangeValue(_ value: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
                if a <= b {
                    return clamp(value, a, b)
                } else {
                    return (a + b) * 0.5
                }
            }
            
            @inline(__always)
            func dist2(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
                let dx = a.x - b.x
                let dy = a.y - b.y
                return dx * dx + dy * dy
            }
            
            let halfWidth = rectSize.width * 0.5
            let halfHeight = rectSize.height * 0.5
            let maxRadius = min(halfWidth, halfHeight)
            let radius = max(0.0, min(cornerRadius, maxRadius))
            
            let localPoint = CGPoint(x: point.x - rectCenter.x, y: point.y - rectCenter.y)
            
            var candidates: [CGPoint] = []
            candidates.reserveCapacity(radius > 0.0 ? 8 : 4)
            
            let minX = -halfWidth
            let maxX = halfWidth
            let minY = -halfHeight
            let maxY = halfHeight
            
            let topX = clampedRangeValue(localPoint.x, minX + radius, maxX - radius)
            candidates.append(CGPoint(x: topX, y: minY))
            
            let bottomX = clampedRangeValue(localPoint.x, minX + radius, maxX - radius)
            candidates.append(CGPoint(x: bottomX, y: maxY))
            
            let leftY = clampedRangeValue(localPoint.y, minY + radius, maxY - radius)
            candidates.append(CGPoint(x: minX, y: leftY))
            
            let rightY = clampedRangeValue(localPoint.y, minY + radius, maxY - radius)
            candidates.append(CGPoint(x: maxX, y: rightY))
            
            if radius > 0.0 {
                typealias Arc = (center: CGPoint, start: CGFloat, end: CGFloat)
                let arcs: [Arc] = [
                    (CGPoint(x: minX + radius, y: minY + radius), .pi, .pi * 1.5),
                    (CGPoint(x: maxX - radius, y: minY + radius), .pi * 1.5, .pi * 2.0),
                    (CGPoint(x: maxX - radius, y: maxY - radius), 0.0, .pi * 0.5),
                    (CGPoint(x: minX + radius, y: maxY - radius), .pi * 0.5, .pi)
                ]
                
                for arc in arcs {
                    let vx = localPoint.x - arc.center.x
                    let vy = localPoint.y - arc.center.y
                    let rawAngle: CGFloat
                    if abs(vx) <= 1e-6 && abs(vy) <= 1e-6 {
                        rawAngle = arc.start
                    } else {
                        rawAngle = normalizedAngle(atan2(vy, vx))
                    }
                    var angle = rawAngle
                    if arc.end >= (.pi * 2.0) - 1e-6 && angle < arc.start {
                        angle += .pi * 2.0
                    }
                    let clampedAngle = clamp(angle, arc.start, arc.end)
                    candidates.append(
                        CGPoint(
                            x: arc.center.x + cos(clampedAngle) * radius,
                            y: arc.center.y + sin(clampedAngle) * radius
                        )
                    )
                }
            }
            
            guard let nearestLocal = candidates.min(by: { dist2($0, localPoint) < dist2($1, localPoint) }) else {
                return rectCenter
            }
            return CGPoint(x: rectCenter.x + nearestLocal.x, y: rectCenter.y + nearestLocal.y)
        }
        
        func boundaryPointOnRoundedRectRay(rectCenter: CGPoint, rectSize: CGSize, cornerRadius: CGFloat, direction: CGPoint) -> CGPoint {
            let halfWidth = rectSize.width * 0.5
            let halfHeight = rectSize.height * 0.5
            if halfWidth <= 0.0 || halfHeight <= 0.0 {
                return rectCenter
            }
            
            let radius = max(0.0, min(cornerRadius, min(halfWidth, halfHeight)))
            let innerX = max(0.0, halfWidth - radius)
            let innerY = max(0.0, halfHeight - radius)
            
            let dirLength = hypot(direction.x, direction.y)
            let dir: CGPoint
            if dirLength > 1e-6 {
                dir = CGPoint(x: direction.x / dirLength, y: direction.y / dirLength)
            } else {
                dir = CGPoint(x: 1.0, y: 0.0)
            }
            let dx = abs(dir.x)
            let dy = abs(dir.y)
            
            @inline(__always)
            func signedPoint(_ x: CGFloat, _ y: CGFloat, _ direction: CGPoint) -> CGPoint {
                let sx: CGFloat = direction.x >= 0.0 ? 1.0 : -1.0
                let sy: CGFloat = direction.y >= 0.0 ? 1.0 : -1.0
                return CGPoint(x: x * sx, y: y * sy)
            }
            
            if dx > 1e-6 {
                let tVertical = halfWidth / dx
                let yAtVertical = tVertical * dy
                if yAtVertical <= innerY + 1e-6 {
                    let local = signedPoint(halfWidth, yAtVertical, dir)
                    return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
                }
            }
            
            if dy > 1e-6 {
                let tHorizontal = halfHeight / dy
                let xAtHorizontal = tHorizontal * dx
                if xAtHorizontal <= innerX + 1e-6 {
                    let local = signedPoint(xAtHorizontal, halfHeight, dir)
                    return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
                }
            }
            
            if radius <= 1e-6 {
                let tx = dx > 1e-6 ? (halfWidth / dx) : CGFloat.greatestFiniteMagnitude
                let ty = dy > 1e-6 ? (halfHeight / dy) : CGFloat.greatestFiniteMagnitude
                let t = min(tx, ty)
                let local = signedPoint(dx * t, dy * t, dir)
                return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
            }
            
            let a = dx * dx + dy * dy
            let b = -2.0 * (dx * innerX + dy * innerY)
            let c = innerX * innerX + innerY * innerY - radius * radius
            let discriminant = max(0.0, b * b - 4.0 * a * c)
            let sqrtDiscriminant = sqrt(discriminant)
            let t1 = (-b - sqrtDiscriminant) / (2.0 * a)
            let t2 = (-b + sqrtDiscriminant) / (2.0 * a)
            let tCorner = max(0.0, max(t1, t2))
            let cornerLocal = signedPoint(dx * tCorner, dy * tCorner, dir)
            return CGPoint(x: rectCenter.x + cornerLocal.x, y: rectCenter.y + cornerLocal.y)
        }
        
        var bakedSizes: [CGSize] = []
        var bakedPositions: [CGPoint] = []
        var localPositions: [CGPoint] = []
        var sourcePositions: [CGPoint] = []
        var radiusKeyframes: [CGFloat] = []
        var containerPositions: [CGPoint] = []
        var lockedSourceInsetDistance: CGFloat?
        bakedSizes.reserveCapacity(sampleCount)
        bakedPositions.reserveCapacity(sampleCount)
        localPositions.reserveCapacity(sampleCount)
        sourcePositions.reserveCapacity(sampleCount)
        radiusKeyframes.reserveCapacity(sampleCount)
        containerPositions.reserveCapacity(sampleCount)
        
        for i in 0 ..< sampleCount {
            let t = sampleEndIndex > 0.0 ? CGFloat(i) / sampleEndIndex : 1.0
            let scale = CGFloat(scaleEase(Double(t)))
            
            let sideFraction = max(0.0, min(1.0, sideFractionEase(Double(t))))
            let sideValue = (1.0 - sideFraction) * minSide + sideFraction * maxSide
            let baseSize: CGSize
            if toSize.width > toSize.height {
                baseSize = CGSize(width: sideValue, height: minSide)
            } else {
                baseSize = CGSize(width: minSide, height: sideValue)
            }
            let scaledSize = CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
            bakedSizes.append(scaledSize)
            localPositions.append(CGPoint(x: scaledSize.width * 0.5, y: scaledSize.height * 0.5))
            let bakedPosition = CGPoint(
                x: (1.0 - scale) * toHalf.x + scale * baseSize.width * 0.5,
                y: (1.0 - scale) * toHalf.y + scale * baseSize.height * 0.5
            )
            bakedPositions.append(bakedPosition)
            
            let radiusFraction = max(0.0, min(1.0, radiusFractionEase(Double(t))))
            let baseRadius = (1.0 - radiusFraction) * (minSide * 0.5) + radiusFraction * toCornerRadius
            let scaledCornerRadius = baseRadius * scale
            radiusKeyframes.append(scaledCornerRadius)
            
            let positionFraction = springProgress(Double(t))
            let containerPosition = CGPoint(
                x: (1.0 - positionFraction) * fromCenter.x + positionFraction * toCenter.x,
                y: (1.0 - positionFraction) * fromCenter.y + positionFraction * toCenter.y
            )
            containerPositions.append(containerPosition)
            
            let blobCenter = CGPoint(
                x: containerPosition.x - toHalf.x + bakedPosition.x,
                y: containerPosition.y - toHalf.y + bakedPosition.y
            )
            
            if scaledSize.width < fromRect.width || scaledSize.height < fromRect.height {
                sourcePositions.append(fromCenter)
                continue
            }
            
            let lineDirection = centerLineDirection
            let nearestEdgePoint = boundaryPointOnRoundedRectRay(
                rectCenter: blobCenter,
                rectSize: scaledSize,
                cornerRadius: scaledCornerRadius,
                direction: lineDirection
            )
            
            let normalizedSuckProgress = max(0.0, min(1.0, t / sourceSuckDurationFraction))
            let oneMinusSuckProgress = 1.0 - normalizedSuckProgress
            let suckFraction = 1.0 - oneMinusSuckProgress * oneMinusSuckProgress * oneMinusSuckProgress
            let animatedSourceInsetDistance = sourceMaxEdgeDistance - suckFraction * (sourceMaxEdgeDistance + sourceFullInsideInset)
            let baseSourceInsetDistance = lockedSourceInsetDistance ?? animatedSourceInsetDistance
            let normalizedFinalInsideProgress = max(0.0, min(1.0, (t - sourceFinalInsideStartFraction) / max(0.001, 1.0 - sourceFinalInsideStartFraction)))
            let oneMinusFinalInsideProgress = 1.0 - normalizedFinalInsideProgress
            let finalInsideEase = 1.0 - oneMinusFinalInsideProgress * oneMinusFinalInsideProgress * oneMinusFinalInsideProgress
            let sourceHalfWidth = fromRect.width * 0.5
            let sourceHalfHeight = fromRect.height * 0.5
            let sourceHalfExtentAlongRay = abs(lineDirection.x) * sourceHalfWidth + abs(lineDirection.y) * sourceHalfHeight
            let sourceFinalInsideDistance = sourceFinalFurthestInsideDistance - sourceHalfExtentAlongRay * 2.0
            let sourceInsetDistance = baseSourceInsetDistance + (sourceFinalInsideDistance - baseSourceInsetDistance) * finalInsideEase
            let sourceCenterDistance = sourceInsetDistance + sourceHalfExtentAlongRay
            let sourcePosition = CGPoint(
                x: nearestEdgePoint.x + lineDirection.x * sourceCenterDistance,
                y: nearestEdgePoint.y + lineDirection.y * sourceCenterDistance
            )
            let centerLineDistance = (sourcePosition.x - fromCenter.x) * centerLineDirection.x + (sourcePosition.y - fromCenter.y) * centerLineDirection.y
            let centerLineOutwardAllowance = max(0.0, centerLineDistance) * finalInsideEase
            let centerLineUpperBound = sourceInsetDistance < 0.0 ? centerLineOutwardAllowance : 0.0
            let clampedCenterLineDistance = max(centerLineMinDistance, min(centerLineUpperBound, centerLineDistance))
            var projectedSourcePosition = CGPoint(
                x: fromCenter.x + centerLineDirection.x * clampedCenterLineDistance,
                y: fromCenter.y + centerLineDirection.y * clampedCenterLineDistance
            )
            let sourceNearestPoint = CGPoint(
                x: projectedSourcePosition.x - centerLineDirection.x * sourceHalfExtentAlongRay,
                y: projectedSourcePosition.y - centerLineDirection.y * sourceHalfExtentAlongRay
            )
            let sourceNearestBoundaryPoint = boundaryPointOnRoundedRectRay(
                rectCenter: blobCenter,
                rectSize: scaledSize,
                cornerRadius: scaledCornerRadius,
                direction: lineDirection
            )
            let sourceNearestSignedDistance: CGFloat =
                (sourceNearestPoint.x - sourceNearestBoundaryPoint.x) * lineDirection.x +
                (sourceNearestPoint.y - sourceNearestBoundaryPoint.y) * lineDirection.y
            let centerCorrection = sourceNearestSignedDistance - sourceInsetDistance
            if abs(centerCorrection) > 0.01 {
                let correctedCenterLineDistance = centerLineDistance - centerCorrection
                let clampedCorrectedCenterLineDistance = max(centerLineMinDistance, min(centerLineUpperBound, correctedCenterLineDistance))
                projectedSourcePosition = CGPoint(
                    x: fromCenter.x + centerLineDirection.x * clampedCorrectedCenterLineDistance,
                    y: fromCenter.y + centerLineDirection.y * clampedCorrectedCenterLineDistance
                )
            }
            sourcePositions.append(projectedSourcePosition)
            
            if lockedSourceInsetDistance == nil {
                let insetWidth = max(0.0, scaledSize.width - sourceFullInsideInset * 2.0)
                let insetHeight = max(0.0, scaledSize.height - sourceFullInsideInset * 2.0)
                let insetSize = CGSize(width: insetWidth, height: insetHeight)
                let insetRadius = max(0.0, scaledCornerRadius - sourceFullInsideInset)
                if sourceInsetDistance <= 0.0 && isPointInsideRoundedRect(
                    point: projectedSourcePosition,
                    rectCenter: blobCenter,
                    rectSize: insetSize,
                    cornerRadius: insetRadius
                ) {
                    lockedSourceInsetDistance = sourceInsetDistance
                }
            }
        }
        
        return TransitionKeyframes(
            bakedSizes: bakedSizes,
            bakedPositions: bakedPositions,
            localPositions: localPositions,
            sourcePositions: sourcePositions,
            radiusKeyframes: radiusKeyframes,
            containerPositions: containerPositions,
            minSide: minSide
        )
    }
    
    public func animateIn(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, duration: Double, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
        if isDark {
            self.effectSettingsContainerView.lumaMin = 0.0
            self.effectSettingsContainerView.lumaMax = 0.15
        } else {
            self.effectSettingsContainerView.lumaMin = 0.8
            self.effectSettingsContainerView.lumaMax = 0.801
        }
        
        self.cancelCurrentTransitionAnimations(sourceEffectView: sourceEffectView)
        self.setIsFilterActive(isFilterActive: true)
        sourceEffectView.setTransitionFraction(value: 1.0, duration: 0.0)
        sourceEffectView.setTransitionFraction(value: 0.0, duration: 0.2)

        let sourceMaxEdgeDistance: CGFloat = 20.0
        let sourceSuckDurationFraction: CGFloat = 0.9
        let sourceFinalFurthestInsideDistance: CGFloat = -8.0
        let sourceFinalInsideStartFraction: CGFloat = 0.65
        let sourceFullInsideInset: CGFloat = max(1.0, min(fromRect.width, fromRect.height) * 0.5)
        let sampleCount = 30
        let sampleEndIndex = CGFloat(sampleCount - 1)
        let toSize = toRect.size
        let toHalf = CGPoint(x: toSize.width * 0.5, y: toSize.height * 0.5)
        let minSide = min(toSize.width, toSize.height)
        let maxSide = max(toSize.width, toSize.height)
        let fromCenter = CGPoint(x: fromRect.midX, y: fromRect.midY)
        let toCenter = CGPoint(x: toRect.midX, y: toRect.midY)
        let centerLineDelta = CGPoint(x: fromCenter.x - toCenter.x, y: fromCenter.y - toCenter.y)
        let centerLineLength = hypot(centerLineDelta.x, centerLineDelta.y)
        let centerLineDirection: CGPoint = centerLineLength > 1e-6 ? CGPoint(x: centerLineDelta.x / centerLineLength, y: centerLineDelta.y / centerLineLength) : CGPoint(x: 1.0, y: 0.0)
        let centerLineMinDistance: CGFloat = -centerLineLength
        
        func isPointInsideRoundedRect(point: CGPoint, rectCenter: CGPoint, rectSize: CGSize, cornerRadius: CGFloat) -> Bool {
            let halfWidth = rectSize.width * 0.5
            let halfHeight = rectSize.height * 0.5
            if halfWidth <= 0.0 || halfHeight <= 0.0 {
                return false
            }
            let radius = max(0.0, min(cornerRadius, min(halfWidth, halfHeight)))
            
            let localX = point.x - rectCenter.x
            let localY = point.y - rectCenter.y
            let absX = abs(localX)
            let absY = abs(localY)
            
            if absX > halfWidth || absY > halfHeight {
                return false
            }
            
            // Central body strips.
            if absX <= halfWidth - radius || absY <= halfHeight - radius {
                return true
            }
            
            // Corner arc region.
            let cornerCenter = CGPoint(
                x: (halfWidth - radius) * (localX >= 0.0 ? 1.0 : -1.0),
                y: (halfHeight - radius) * (localY >= 0.0 ? 1.0 : -1.0)
            )
            let dx = localX - cornerCenter.x
            let dy = localY - cornerCenter.y
            return dx * dx + dy * dy <= radius * radius
        }
        
        func nearestBoundaryPointOnRoundedRect(point: CGPoint, rectCenter: CGPoint, rectSize: CGSize, cornerRadius: CGFloat) -> CGPoint {
            @inline(__always)
            func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
                return max(lower, min(upper, value))
            }
            
            @inline(__always)
            func normalizedAngle(_ angle: CGFloat) -> CGFloat {
                let twoPi = CGFloat.pi * 2.0
                var value = angle.truncatingRemainder(dividingBy: twoPi)
                if value < 0.0 {
                    value += twoPi
                }
                return value
            }
            
            @inline(__always)
            func clampedRangeValue(_ value: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
                if a <= b {
                    return clamp(value, a, b)
                } else {
                    return (a + b) * 0.5
                }
            }
            
            @inline(__always)
            func dist2(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
                let dx = a.x - b.x
                let dy = a.y - b.y
                return dx * dx + dy * dy
            }
            
            let halfWidth = rectSize.width * 0.5
            let halfHeight = rectSize.height * 0.5
            let maxRadius = min(halfWidth, halfHeight)
            let radius = max(0.0, min(cornerRadius, maxRadius))
            
            let localPoint = CGPoint(x: point.x - rectCenter.x, y: point.y - rectCenter.y)
            
            var candidates: [CGPoint] = []
            candidates.reserveCapacity(radius > 0.0 ? 8 : 4)
            
            // Side segments in local coordinates.
            let minX = -halfWidth
            let maxX = halfWidth
            let minY = -halfHeight
            let maxY = halfHeight
            
            let topX = clampedRangeValue(localPoint.x, minX + radius, maxX - radius)
            candidates.append(CGPoint(x: topX, y: minY))
            
            let bottomX = clampedRangeValue(localPoint.x, minX + radius, maxX - radius)
            candidates.append(CGPoint(x: bottomX, y: maxY))
            
            let leftY = clampedRangeValue(localPoint.y, minY + radius, maxY - radius)
            candidates.append(CGPoint(x: minX, y: leftY))
            
            let rightY = clampedRangeValue(localPoint.y, minY + radius, maxY - radius)
            candidates.append(CGPoint(x: maxX, y: rightY))
            
            if radius > 0.0 {
                typealias Arc = (center: CGPoint, start: CGFloat, end: CGFloat)
                let arcs: [Arc] = [
                    (CGPoint(x: minX + radius, y: minY + radius), .pi, .pi * 1.5),     // TL
                    (CGPoint(x: maxX - radius, y: minY + radius), .pi * 1.5, .pi * 2.0), // TR
                    (CGPoint(x: maxX - radius, y: maxY - radius), 0.0, .pi * 0.5),       // BR
                    (CGPoint(x: minX + radius, y: maxY - radius), .pi * 0.5, .pi)        // BL
                ]
                
                for arc in arcs {
                    let vx = localPoint.x - arc.center.x
                    let vy = localPoint.y - arc.center.y
                    let rawAngle: CGFloat
                    if abs(vx) <= 1e-6 && abs(vy) <= 1e-6 {
                        rawAngle = arc.start
                    } else {
                        rawAngle = normalizedAngle(atan2(vy, vx))
                    }
                    var angle = rawAngle
                    if arc.end >= (.pi * 2.0) - 1e-6 && angle < arc.start {
                        angle += .pi * 2.0
                    }
                    let clampedAngle = clamp(angle, arc.start, arc.end)
                    candidates.append(
                        CGPoint(
                            x: arc.center.x + cos(clampedAngle) * radius,
                            y: arc.center.y + sin(clampedAngle) * radius
                        )
                    )
                }
            }
            
            guard let nearestLocal = candidates.min(by: { dist2($0, localPoint) < dist2($1, localPoint) }) else {
                return rectCenter
            }
            return CGPoint(x: rectCenter.x + nearestLocal.x, y: rectCenter.y + nearestLocal.y)
        }
        
        func boundaryPointOnRoundedRectRay(rectCenter: CGPoint, rectSize: CGSize, cornerRadius: CGFloat, direction: CGPoint) -> CGPoint {
            let halfWidth = rectSize.width * 0.5
            let halfHeight = rectSize.height * 0.5
            if halfWidth <= 0.0 || halfHeight <= 0.0 {
                return rectCenter
            }
            
            let radius = max(0.0, min(cornerRadius, min(halfWidth, halfHeight)))
            let innerX = max(0.0, halfWidth - radius)
            let innerY = max(0.0, halfHeight - radius)
            
            let dirLength = hypot(direction.x, direction.y)
            let dir: CGPoint
            if dirLength > 1e-6 {
                dir = CGPoint(x: direction.x / dirLength, y: direction.y / dirLength)
            } else {
                dir = CGPoint(x: 1.0, y: 0.0)
            }
            let dx = abs(dir.x)
            let dy = abs(dir.y)
            
            @inline(__always)
            func signedPoint(_ x: CGFloat, _ y: CGFloat, _ direction: CGPoint) -> CGPoint {
                let sx: CGFloat = direction.x >= 0.0 ? 1.0 : -1.0
                let sy: CGFloat = direction.y >= 0.0 ? 1.0 : -1.0
                return CGPoint(x: x * sx, y: y * sy)
            }
            
            if dx > 1e-6 {
                let tVertical = halfWidth / dx
                let yAtVertical = tVertical * dy
                if yAtVertical <= innerY + 1e-6 {
                    let local = signedPoint(halfWidth, yAtVertical, dir)
                    return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
                }
            }
            
            if dy > 1e-6 {
                let tHorizontal = halfHeight / dy
                let xAtHorizontal = tHorizontal * dx
                if xAtHorizontal <= innerX + 1e-6 {
                    let local = signedPoint(xAtHorizontal, halfHeight, dir)
                    return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
                }
            }
            
            if radius <= 1e-6 {
                let tx = dx > 1e-6 ? (halfWidth / dx) : CGFloat.greatestFiniteMagnitude
                let ty = dy > 1e-6 ? (halfHeight / dy) : CGFloat.greatestFiniteMagnitude
                let t = min(tx, ty)
                let local = signedPoint(dx * t, dy * t, dir)
                return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
            }
            
            let a = dx * dx + dy * dy
            let b = -2.0 * (dx * innerX + dy * innerY)
            let c = innerX * innerX + innerY * innerY - radius * radius
            let discriminant = max(0.0, b * b - 4.0 * a * c)
            let sqrtDiscriminant = sqrt(discriminant)
            let t1 = (-b - sqrtDiscriminant) / (2.0 * a)
            let t2 = (-b + sqrtDiscriminant) / (2.0 * a)
            let tCorner = max(0.0, max(t1, t2))
            let cornerLocal = signedPoint(dx * tCorner, dy * tCorner, dir)
            return CGPoint(x: rectCenter.x + cornerLocal.x, y: rectCenter.y + cornerLocal.y)
        }
        
        var bakedSizes: [CGSize] = []
        var bakedPositions: [CGPoint] = []
        var localPositions: [CGPoint] = []
        var sourcePositions: [CGPoint] = []
        var radiusKeyframes: [CGFloat] = []
        var containerPositions: [CGPoint] = []
        var lockedSourceInsetDistance: CGFloat?
        bakedSizes.reserveCapacity(sampleCount)
        bakedPositions.reserveCapacity(sampleCount)
        localPositions.reserveCapacity(sampleCount)
        sourcePositions.reserveCapacity(sampleCount)
        radiusKeyframes.reserveCapacity(sampleCount)
        containerPositions.reserveCapacity(sampleCount)
        
        for i in 0 ..< sampleCount {
            let t = sampleEndIndex > 0.0 ? CGFloat(i) / sampleEndIndex : 1.0
            let scale = CGFloat(scaleEase(Double(t)))
            
            let sideFraction = max(0.0, min(1.0, sideFractionEase(Double(t))))
            let sideValue = (1.0 - sideFraction) * minSide + sideFraction * maxSide
            let baseSize: CGSize
            if toSize.width > toSize.height {
                baseSize = CGSize(width: sideValue, height: minSide)
            } else {
                baseSize = CGSize(width: minSide, height: sideValue)
            }
            let scaledSize = CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
            bakedSizes.append(scaledSize)
            localPositions.append(CGPoint(x: scaledSize.width * 0.5, y: scaledSize.height * 0.5))
            let bakedPosition = CGPoint(
                x: (1.0 - scale) * toHalf.x + scale * baseSize.width * 0.5,
                y: (1.0 - scale) * toHalf.y + scale * baseSize.height * 0.5
            )
            bakedPositions.append(bakedPosition)
            
            let radiusFraction = max(0.0, min(1.0, radiusFractionEase(Double(t))))
            let baseRadius = (1.0 - radiusFraction) * (minSide * 0.5) + radiusFraction * toCornerRadius
            let scaledCornerRadius = baseRadius * scale
            radiusKeyframes.append(scaledCornerRadius)
            
            let positionFraction = springProgress(Double(t))
            let containerPosition = CGPoint(
                x: (1.0 - positionFraction) * fromCenter.x + positionFraction * toCenter.x,
                y: (1.0 - positionFraction) * fromCenter.y + positionFraction * toCenter.y
            )
            containerPositions.append(containerPosition)
            
            let blobCenter = CGPoint(
                x: containerPosition.x - toHalf.x + bakedPosition.x,
                y: containerPosition.y - toHalf.y + bakedPosition.y
            )
            
            // Keep source fixed until the blob can fully contain it.
            if scaledSize.width < fromRect.width || scaledSize.height < fromRect.height {
                sourcePositions.append(fromCenter)
                continue
            }
            
            let lineDirection = centerLineDirection
            let nearestEdgePoint = boundaryPointOnRoundedRectRay(
                rectCenter: blobCenter,
                rectSize: scaledSize,
                cornerRadius: scaledCornerRadius,
                direction: lineDirection
            )
            
            let normalizedSuckProgress = max(0.0, min(1.0, t / sourceSuckDurationFraction))
            let oneMinusSuckProgress = 1.0 - normalizedSuckProgress
            let suckFraction = 1.0 - oneMinusSuckProgress * oneMinusSuckProgress * oneMinusSuckProgress
            let animatedSourceInsetDistance = sourceMaxEdgeDistance - suckFraction * (sourceMaxEdgeDistance + sourceFullInsideInset)
            let baseSourceInsetDistance = lockedSourceInsetDistance ?? animatedSourceInsetDistance
            let normalizedFinalInsideProgress = max(0.0, min(1.0, (t - sourceFinalInsideStartFraction) / max(0.001, 1.0 - sourceFinalInsideStartFraction)))
            let oneMinusFinalInsideProgress = 1.0 - normalizedFinalInsideProgress
            let finalInsideEase = 1.0 - oneMinusFinalInsideProgress * oneMinusFinalInsideProgress * oneMinusFinalInsideProgress
            let sourceHalfWidth = fromRect.width * 0.5
            let sourceHalfHeight = fromRect.height * 0.5
            let sourceHalfExtentAlongRay = abs(lineDirection.x) * sourceHalfWidth + abs(lineDirection.y) * sourceHalfHeight
            let sourceFinalInsideDistance = sourceFinalFurthestInsideDistance - sourceHalfExtentAlongRay * 2.0
            let sourceInsetDistance = baseSourceInsetDistance + (sourceFinalInsideDistance - baseSourceInsetDistance) * finalInsideEase
            let sourceCenterDistance = sourceInsetDistance + sourceHalfExtentAlongRay
            let sourcePosition = CGPoint(
                x: nearestEdgePoint.x + lineDirection.x * sourceCenterDistance,
                y: nearestEdgePoint.y + lineDirection.y * sourceCenterDistance
            )
            let centerLineDistance = (sourcePosition.x - fromCenter.x) * centerLineDirection.x + (sourcePosition.y - fromCenter.y) * centerLineDirection.y
            let centerLineOutwardAllowance = max(0.0, centerLineDistance) * finalInsideEase
            let centerLineUpperBound = sourceInsetDistance < 0.0 ? centerLineOutwardAllowance : 0.0
            let clampedCenterLineDistance = max(centerLineMinDistance, min(centerLineUpperBound, centerLineDistance))
            var projectedSourcePosition = CGPoint(
                x: fromCenter.x + centerLineDirection.x * clampedCenterLineDistance,
                y: fromCenter.y + centerLineDirection.y * clampedCenterLineDistance
            )
            let sourceNearestPoint = CGPoint(
                x: projectedSourcePosition.x - centerLineDirection.x * sourceHalfExtentAlongRay,
                y: projectedSourcePosition.y - centerLineDirection.y * sourceHalfExtentAlongRay
            )
            let sourceNearestBoundaryPoint = boundaryPointOnRoundedRectRay(
                rectCenter: blobCenter,
                rectSize: scaledSize,
                cornerRadius: scaledCornerRadius,
                direction: lineDirection
            )
            let sourceNearestSignedDistance: CGFloat =
                (sourceNearestPoint.x - sourceNearestBoundaryPoint.x) * lineDirection.x +
                (sourceNearestPoint.y - sourceNearestBoundaryPoint.y) * lineDirection.y
            let centerCorrection = sourceNearestSignedDistance - sourceInsetDistance
            if abs(centerCorrection) > 0.01 {
                let correctedCenterLineDistance = centerLineDistance - centerCorrection
                let clampedCorrectedCenterLineDistance = max(centerLineMinDistance, min(centerLineUpperBound, correctedCenterLineDistance))
                projectedSourcePosition = CGPoint(
                    x: fromCenter.x + centerLineDirection.x * clampedCorrectedCenterLineDistance,
                    y: fromCenter.y + centerLineDirection.y * clampedCorrectedCenterLineDistance
                )
            }
            sourcePositions.append(projectedSourcePosition)
            
            if lockedSourceInsetDistance == nil {
                let insetWidth = max(0.0, scaledSize.width - sourceFullInsideInset * 2.0)
                let insetHeight = max(0.0, scaledSize.height - sourceFullInsideInset * 2.0)
                let insetSize = CGSize(width: insetWidth, height: insetHeight)
                let insetRadius = max(0.0, scaledCornerRadius - sourceFullInsideInset)
                if sourceInsetDistance <= 0.0 && isPointInsideRoundedRect(
                    point: projectedSourcePosition,
                    rectCenter: blobCenter,
                    rectSize: insetSize,
                    cornerRadius: insetRadius
                ) {
                    lockedSourceInsetDistance = sourceInsetDistance
                }
            }
        }
        
        self.effectSettingsContainerView.addSubview(sourceEffectView)
        sourceEffectView.updateSize(size: fromRect.size, transition: .immediate)
        sourceEffectView.frame = fromRect
        sourceEffectView.updateCornerRadius(duration: 0.0, keyframes: [fromCornerRadius])
        sourceEffectView.updatePosition(duration: duration, keyframes: sourcePositions)
        do {
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "bounds.size")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = bakedSizes.map {
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
            
            let positionAnimation = CAKeyframeAnimation(keyPath: "position")
            positionAnimation.duration = duration * UIView.animationDurationFactor()
            positionAnimation.values = localPositions.map { NSValue(cgPoint: $0) }
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            positionAnimation.isRemovedOnCompletion = true
            positionAnimation.fillMode = .both
            self.contentsView.layer.add(positionAnimation, forKey: "position")
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(positionAnimation, forKey: "position")
                sdfElementLayer.add(positionAnimation, forKey: "position")
            }
            
            let containerPositionAnimation = CAKeyframeAnimation(keyPath: "position")
            containerPositionAnimation.duration = duration * UIView.animationDurationFactor()
            containerPositionAnimation.values = bakedPositions.map { NSValue(cgPoint: $0) }
            containerPositionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            containerPositionAnimation.isRemovedOnCompletion = true
            containerPositionAnimation.fillMode = .both
            self.contentsEffectView.layer.add(containerPositionAnimation, forKey: "position")
            
            self.effectView.updateSize(duration: duration, keyframes: bakedSizes)
            self.effectView.updatePosition(duration: duration, keyframes: bakedPositions)
        }
        do {
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "position")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = containerPositions.map { NSValue(cgPoint: $0) }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.containerView.layer.add(keyframeAnimation, forKey: "position")
        }
        do {
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
            self.effectView.updateCornerRadius(duration: duration, keyframes: radiusKeyframes)
        }
        do {
            self.contentsEffectView.layer.setValue(0.0 as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
            self.contentsEffectView.layer.setValue(0.0 as NSNumber, forKeyPath: "sublayers.sdfLayer.effect.height")
            self.contentsEffectView.layer.setValue(-0.001 as NSNumber, forKeyPath: "filters.displacementMap.inputAmount")
            
            let fromHeight: CGFloat = minSide * 0.25
            let toHeight: CGFloat = 0.001
            let effectHeightKeyframes = (0 ..< 30).map { i -> CGFloat in
                let t = CGFloat(i) / (30.0 - 1.0)
                let fraction = CGFloat(max(0.0, min(1.0, displacementFractionEase(Double(t)))))
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
                return CGFloat(blurEase(Double(t)))
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
                return CGFloat(subScaleEase(Double(t)))
            }
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "sublayerTransform.scale")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = subScaleKeyframes.map { $0 as NSNumber }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.contentsView.layer.add(keyframeAnimation, forKey: "sublayerTransform.scale")
        }
        
        self.contentsView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)

        let cleanupDelay = max(duration, duration * UIView.animationDurationFactor())
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + cleanupDelay, execute: { [weak self, weak sourceEffectView] in
            sourceEffectView?.removeFromSuperview()
            guard let self else { return }
            self.setIsFilterActive(isFilterActive: false)
        })
    }
    
    public func animateIn(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
        self.animateIn(
            fromRect: fromRect,
            toRect: toRect,
            fromCornerRadius: fromCornerRadius,
            toCornerRadius: toCornerRadius,
            duration: 0.5,
            isDark: isDark,
            sourceEffectView: sourceEffectView
        )
    }

    public func animateOut(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, duration: Double, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
        if isDark {
            self.effectSettingsContainerView.lumaMin = 0.0
            self.effectSettingsContainerView.lumaMax = 0.15
        } else {
            self.effectSettingsContainerView.lumaMin = 0.8
            self.effectSettingsContainerView.lumaMax = 0.801
        }
        
        self.cancelCurrentTransitionAnimations(sourceEffectView: sourceEffectView)
        self.setIsFilterActive(isFilterActive: true)
        sourceEffectView.setTransitionFraction(value: 0.0, duration: 0.0)
        sourceEffectView.setTransitionFraction(value: 1.0, duration: 0.3)
        //sourceEffectView.backgroundColor = .blue

        let sourceMaxEdgeDistance: CGFloat = 20.0
        let sourceSuckDurationFraction: CGFloat = 0.9
        let sourceFinalFurthestInsideDistance: CGFloat = -8.0
        let sourceFinalInsideStartFraction: CGFloat = 0.65
        let sourceFullInsideInset: CGFloat = max(1.0, min(fromRect.width, fromRect.height) * 0.5)
        
        let sampleCount = 36
        let sampleEndIndex = CGFloat(sampleCount - 1)
        let collapsedCenter = CGPoint(x: fromRect.midX, y: fromRect.midY)
        let expandedCenter = CGPoint(x: toRect.midX, y: toRect.midY)
        let expandedSize = toRect.size
        let collapsedSize = fromRect.size
        
        @inline(__always)
        func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
            return (1.0 - t) * a + t * b
        }
        
        @inline(__always)
        func lerpPoint(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            return CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
        }
        
        @inline(__always)
        func normalized(_ point: CGPoint) -> CGPoint {
            let length = hypot(point.x, point.y)
            if length <= 1e-6 {
                return CGPoint(x: 1.0, y: 0.0)
            }
            return CGPoint(x: point.x / length, y: point.y / length)
        }
        
        func boundaryPointOnRoundedRectRay(rectCenter: CGPoint, rectSize: CGSize, cornerRadius: CGFloat, direction: CGPoint) -> CGPoint {
            let halfWidth = rectSize.width * 0.5
            let halfHeight = rectSize.height * 0.5
            if halfWidth <= 0.0 || halfHeight <= 0.0 {
                return rectCenter
            }
            
            let radius = max(0.0, min(cornerRadius, min(halfWidth, halfHeight)))
            let innerX = max(0.0, halfWidth - radius)
            let innerY = max(0.0, halfHeight - radius)
            
            let dir = normalized(direction)
            let dx = abs(dir.x)
            let dy = abs(dir.y)
            
            @inline(__always)
            func signedPoint(_ x: CGFloat, _ y: CGFloat, _ direction: CGPoint) -> CGPoint {
                let sx: CGFloat = direction.x >= 0.0 ? 1.0 : -1.0
                let sy: CGFloat = direction.y >= 0.0 ? 1.0 : -1.0
                return CGPoint(x: x * sx, y: y * sy)
            }
            
            if dx > 1e-6 {
                let tVertical = halfWidth / dx
                let yAtVertical = tVertical * dy
                if yAtVertical <= innerY + 1e-6 {
                    let local = signedPoint(halfWidth, yAtVertical, dir)
                    return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
                }
            }
            
            if dy > 1e-6 {
                let tHorizontal = halfHeight / dy
                let xAtHorizontal = tHorizontal * dx
                if xAtHorizontal <= innerX + 1e-6 {
                    let local = signedPoint(xAtHorizontal, halfHeight, dir)
                    return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
                }
            }
            
            if radius <= 1e-6 {
                let tx = dx > 1e-6 ? (halfWidth / dx) : CGFloat.greatestFiniteMagnitude
                let ty = dy > 1e-6 ? (halfHeight / dy) : CGFloat.greatestFiniteMagnitude
                let t = min(tx, ty)
                let local = signedPoint(dx * t, dy * t, dir)
                return CGPoint(x: rectCenter.x + local.x, y: rectCenter.y + local.y)
            }
            
            let a = dx * dx + dy * dy
            let b = -2.0 * (dx * innerX + dy * innerY)
            let c = innerX * innerX + innerY * innerY - radius * radius
            let discriminant = max(0.0, b * b - 4.0 * a * c)
            let sqrtDiscriminant = sqrt(discriminant)
            let t1 = (-b - sqrtDiscriminant) / (2.0 * a)
            let t2 = (-b + sqrtDiscriminant) / (2.0 * a)
            // Use the farthest positive root: the near root may lie in the central body region,
            // while the far root is the actual outward boundary crossing on the corner arc.
            let tCorner = max(0.0, max(t1, t2))
            let cornerLocal = signedPoint(dx * tCorner, dy * tCorner, dir)
            return CGPoint(x: rectCenter.x + cornerLocal.x, y: rectCenter.y + cornerLocal.y)
        }
        
        func criticallyDampedProgress(_ uIn: Double, settleBy: Double) -> Double {
            let u = clamp01(uIn)
            let settle = max(0.1, settleBy)
            let k = 4.0 / settle
            
            @inline(__always)
            func raw(_ t: Double) -> Double {
                return 1.0 - exp(-k * t) * (1.0 + k * t)
            }
            
            let end = raw(1.0)
            if end <= 1e-12 {
                return u
            }
            return clamp01(raw(u) / end)
        }
        
        var bakedSizes: [CGSize] = []
        var bakedPositions: [CGPoint] = []
        var localPositions: [CGPoint] = []
        var sourcePositions: [CGPoint] = []
        var radiusKeyframes: [CGFloat] = []
        var containerPositions: [CGPoint] = []
        bakedSizes.reserveCapacity(sampleCount)
        bakedPositions.reserveCapacity(sampleCount)
        localPositions.reserveCapacity(sampleCount)
        sourcePositions.reserveCapacity(sampleCount)
        radiusKeyframes.reserveCapacity(sampleCount)
        containerPositions.reserveCapacity(sampleCount)
        
        let centerLineDirection = normalized(CGPoint(x: collapsedCenter.x - expandedCenter.x, y: collapsedCenter.y - expandedCenter.y))
        
        for i in 0 ..< sampleCount {
            let t = sampleEndIndex > 0.0 ? CGFloat(i) / sampleEndIndex : 1.0
            
            let positionFraction = CGFloat(max(0.0, min(1.0, springProgress(Double(t), dampingRatio: 0.62, settleBy: 0.82))))
            let sizeFraction = CGFloat(criticallyDampedProgress(Double(t), settleBy: 0.28))
            let radiusFraction = CGFloat(criticallyDampedProgress(Double(t), settleBy: 0.34))
            
            let size = CGSize(
                width: max(1.0, lerp(expandedSize.width, collapsedSize.width, sizeFraction)),
                height: max(1.0, lerp(expandedSize.height, collapsedSize.height, sizeFraction))
            )
            bakedSizes.append(size)
            localPositions.append(CGPoint(x: size.width * 0.5, y: size.height * 0.5))
            bakedPositions.append(expandedCenter)
            
            let rawRadius = lerp(toCornerRadius, fromCornerRadius, radiusFraction)
            let radius = max(0.0, min(rawRadius, min(size.width, size.height) * 0.5))
            radiusKeyframes.append(radius)
            
            let centerLinePosition = lerpPoint(expandedCenter, collapsedCenter, positionFraction)
            containerPositions.append(centerLinePosition)
            let sourceBoundaryPoint = boundaryPointOnRoundedRectRay(
                rectCenter: centerLinePosition,
                rectSize: size,
                cornerRadius: radius,
                direction: centerLineDirection
            )
            let lineDirection = centerLineDirection
            let sourceHalfWidth = fromRect.width * 0.5
            let sourceHalfHeight = fromRect.height * 0.5
            let sourceHalfExtentAlongRay = abs(lineDirection.x) * sourceHalfWidth + abs(lineDirection.y) * sourceHalfHeight
            let reverseT = 1.0 - t
            let normalizedSuckProgress = max(0.0, min(1.0, reverseT / sourceSuckDurationFraction))
            let oneMinusSuckProgress = 1.0 - normalizedSuckProgress
            let suckFraction = 1.0 - oneMinusSuckProgress * oneMinusSuckProgress * oneMinusSuckProgress
            let reverseAnimatedInsetDistance = sourceMaxEdgeDistance - suckFraction * (sourceMaxEdgeDistance + sourceFullInsideInset)
            let normalizedFinalInsideProgress = max(0.0, min(1.0, (reverseT - sourceFinalInsideStartFraction) / max(0.001, 1.0 - sourceFinalInsideStartFraction)))
            let oneMinusFinalInsideProgress = 1.0 - normalizedFinalInsideProgress
            let finalInsideEase = 1.0 - oneMinusFinalInsideProgress * oneMinusFinalInsideProgress * oneMinusFinalInsideProgress
            let sourceFinalInsideDistance = sourceFinalFurthestInsideDistance - sourceHalfExtentAlongRay * 2.0
            let reverseInsetDistance = reverseAnimatedInsetDistance + (sourceFinalInsideDistance - reverseAnimatedInsetDistance) * finalInsideEase
            let oneMinusCenterPull = 1.0 - t
            let centerPullEase = 1.0 - oneMinusCenterPull * oneMinusCenterPull * oneMinusCenterPull
            let sourceBoundaryDistanceFromCenter =
                (sourceBoundaryPoint.x - centerLinePosition.x) * lineDirection.x +
                (sourceBoundaryPoint.y - centerLinePosition.y) * lineDirection.y
            let sourceCenterInsetDistance = -(sourceBoundaryDistanceFromCenter + sourceHalfExtentAlongRay)
            let sourceInsetDistance = lerp(reverseInsetDistance, sourceCenterInsetDistance, centerPullEase)
            let sourceCenterDistance = sourceInsetDistance + sourceHalfExtentAlongRay
            var projectedSourcePosition = CGPoint(
                x: sourceBoundaryPoint.x + lineDirection.x * sourceCenterDistance,
                y: sourceBoundaryPoint.y + lineDirection.y * sourceCenterDistance
            )
            let sourceNearestPoint = CGPoint(
                x: projectedSourcePosition.x - lineDirection.x * sourceHalfExtentAlongRay,
                y: projectedSourcePosition.y - lineDirection.y * sourceHalfExtentAlongRay
            )
            let sourceNearestSignedDistance =
                (sourceNearestPoint.x - sourceBoundaryPoint.x) * lineDirection.x +
                (sourceNearestPoint.y - sourceBoundaryPoint.y) * lineDirection.y
            if sourceNearestSignedDistance > sourceMaxEdgeDistance {
                let centerCorrection = sourceNearestSignedDistance - sourceMaxEdgeDistance
                projectedSourcePosition = CGPoint(
                    x: projectedSourcePosition.x - lineDirection.x * centerCorrection,
                    y: projectedSourcePosition.y - lineDirection.y * centerCorrection
                )
            }
            sourcePositions.append(projectedSourcePosition)
        }

        if let finalContainerPosition = containerPositions.last {
            self.containerView.center = finalContainerPosition
        }
        if let finalSize = bakedSizes.last {
            self.contentsView.bounds = CGRect(origin: CGPoint(), size: finalSize)
            self.contentsEffectView.bounds = CGRect(origin: CGPoint(), size: finalSize)
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.bounds = CGRect(origin: CGPoint(), size: finalSize)
                sdfElementLayer.bounds = CGRect(origin: CGPoint(), size: finalSize)
            }
        }
        if let finalLocalPosition = localPositions.last {
            self.contentsView.layer.position = finalLocalPosition
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.position = finalLocalPosition
                sdfElementLayer.position = finalLocalPosition
            }
        }
        if let finalBakedPosition = bakedPositions.last {
            self.contentsEffectView.layer.position = finalBakedPosition
        }
        if let finalRadius = radiusKeyframes.last {
            self.contentsView.layer.cornerRadius = finalRadius
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.cornerRadius = finalRadius
                sdfElementLayer.cornerRadius = finalRadius
            }
        }

        self.effectSettingsContainerView.addSubview(sourceEffectView)
        sourceEffectView.updateSize(duration: 0.0, keyframes: [fromRect.size])
        sourceEffectView.frame = fromRect
        sourceEffectView.updateCornerRadius(duration: 0.0, keyframes: [fromCornerRadius])
        sourceEffectView.updatePosition(duration: duration, keyframes: sourcePositions)
        do {
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "bounds.size")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = bakedSizes.map {
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
            
            let positionAnimation = CAKeyframeAnimation(keyPath: "position")
            positionAnimation.duration = duration * UIView.animationDurationFactor()
            positionAnimation.values = localPositions.map { NSValue(cgPoint: $0) }
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            positionAnimation.isRemovedOnCompletion = true
            positionAnimation.fillMode = .both
            self.contentsView.layer.add(positionAnimation, forKey: "position")
            if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
                sdfLayer.add(positionAnimation, forKey: "position")
                sdfElementLayer.add(positionAnimation, forKey: "position")
            }
            
            let containerPositionAnimation = CAKeyframeAnimation(keyPath: "position")
            containerPositionAnimation.duration = duration * UIView.animationDurationFactor()
            containerPositionAnimation.values = bakedPositions.map { NSValue(cgPoint: $0) }
            containerPositionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            containerPositionAnimation.isRemovedOnCompletion = true
            containerPositionAnimation.fillMode = .both
            self.contentsEffectView.layer.add(containerPositionAnimation, forKey: "position")
            
            self.effectView.updateSize(duration: duration, keyframes: bakedSizes)
            self.effectView.updatePosition(duration: duration, keyframes: bakedPositions)
        }
        do {
            let keyframeAnimation = CAKeyframeAnimation(keyPath: "position")
            keyframeAnimation.duration = duration * UIView.animationDurationFactor()
            keyframeAnimation.values = containerPositions.map { NSValue(cgPoint: $0) }
            keyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            keyframeAnimation.isRemovedOnCompletion = true
            keyframeAnimation.fillMode = .both
            self.containerView.layer.add(keyframeAnimation, forKey: "position")
        }
        do {
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
            self.effectView.updateCornerRadius(duration: duration, keyframes: radiusKeyframes)
        }
        do {
            self.contentsEffectView.layer.setValue(0.0 as NSNumber, forKeyPath: "filters.gaussianBlur.inputRadius")
            let blurKeyframes = (0 ..< 30).map { i -> CGFloat in
                let t = CGFloat(i) / (30.0 - 1.0)
                return CGFloat(blurEase(Double(t)))
            }
            let blurKeyframeAnimation = CAKeyframeAnimation(keyPath: "filters.gaussianBlur.inputRadius")
            blurKeyframeAnimation.duration = duration * UIView.animationDurationFactor()
            blurKeyframeAnimation.values = blurKeyframes.map { $0 as NSNumber }
            blurKeyframeAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
            blurKeyframeAnimation.isRemovedOnCompletion = false
            blurKeyframeAnimation.fillMode = .both
            self.contentsEffectView.layer.add(blurKeyframeAnimation, forKey: "filters.gaussianBlur.inputRadius")
        }
        
        self.contentsView.alpha = 0.0
        self.contentsView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)

        let cleanupDelay = max(duration, duration * UIView.animationDurationFactor())
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + cleanupDelay, execute: { [weak self] in
            guard let self else { return }
            self.setIsFilterActive(isFilterActive: false)
        })
    }
    
    public func animateOut(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
        // Telegram call sites pass expanded->collapsed, while the keyframed implementation
        // expects collapsed->expanded. Adapt arguments here to preserve standalone parity.
        self.animateOut(
            fromRect: toRect,
            toRect: fromRect,
            fromCornerRadius: toCornerRadius,
            toCornerRadius: fromCornerRadius,
            duration: 0.5,
            isDark: isDark,
            sourceEffectView: sourceEffectView
        )
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, transition: ComponentTransition) {
        let bounds = CGRect(origin: .zero, size: size)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        
        transition.setBounds(view: self.containerView, bounds: bounds)
        transition.setPosition(view: self.containerView, position: center)
        
        transition.setBounds(view: self.contentsView, bounds: bounds)
        transition.setPosition(view: self.contentsView, position: center)
        transition.setCornerRadius(layer: self.contentsView.layer, cornerRadius: cornerRadius)
        
        transition.setBounds(view: self.contentsEffectView, bounds: bounds)
        transition.setPosition(view: self.contentsEffectView, position: center)
        
        self.effectView.updateSize(size: size, transition: transition)
        self.effectView.updatePosition(position: center, transition: transition)
        self.effectView.updateCornerRadius(duration: 0.0, keyframes: [cornerRadius])
        
        if let sdfLayer = self.sdfLayer, let sdfElementLayer = self.sdfElementLayer {
            transition.setFrame(layer: sdfLayer, frame: bounds)
            transition.setFrame(layer: sdfElementLayer, frame: bounds)
            transition.setCornerRadius(layer: sdfLayer, cornerRadius: cornerRadius)
            transition.setCornerRadius(layer: sdfElementLayer, cornerRadius: cornerRadius)
        }
    }
}

private final class LensTransitionContainerFallbackImpl: UIView, LensTransitionContainerProtocol {
    private let backgroundView: GlassBackgroundView
    
    public var contentsView: UIView {
        return self.backgroundView.contentView
    }
    
    override init(frame: CGRect) {
        self.backgroundView = GlassBackgroundView()
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateIn(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
    }
    
    func animateOut(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
    }
    
    func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, transition: ComponentTransition) {
        transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: .zero, size: size))
        transition.setPosition(view: self.backgroundView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
        self.backgroundView.update(size: size, cornerRadius: cornerRadius, isDark: isDark, tintColor: .init(kind: .panel), transition: transition)
    }
}

public final class LensTransitionContainer: UIView {
    private let impl: (UIView & LensTransitionContainerProtocol)
    
    public var effectView: UIView? {
        if #available(iOS 26.0, *) {
            if let impl = self.impl as? LensTransitionContainerImpl {
                return impl.effectView
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    public var contentsView: UIView {
        return impl.contentsView
    }
    
    public init(effectView: LensTransitionContainerEffectView) {
        if #available(iOS 26.0, *) {
            self.impl = LensTransitionContainerImpl(effectView: effectView)
        } else {
            self.impl = LensTransitionContainerFallbackImpl(frame: CGRect())
        }
        super.init(frame: .zero)
        
        self.addSubview(self.impl)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        self.impl.frame = self.bounds
    }
    
    public func animateIn(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
        self.impl.animateIn(fromRect: fromRect, toRect: toRect, fromCornerRadius: fromCornerRadius, toCornerRadius: toCornerRadius, isDark: isDark, sourceEffectView: sourceEffectView)
    }
    
    public func animateOut(fromRect: CGRect, toRect: CGRect, fromCornerRadius: CGFloat, toCornerRadius: CGFloat, isDark: Bool, sourceEffectView: LensTransitionContainerEffectView) {
        self.impl.animateOut(fromRect: fromRect, toRect: toRect, fromCornerRadius: fromCornerRadius, toCornerRadius: toCornerRadius, isDark: isDark, sourceEffectView: sourceEffectView)
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, transition: ComponentTransition) {
        self.impl.update(size: size, cornerRadius: cornerRadius, isDark: isDark, transition: transition)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.contentsView.hitTest(point, with: event)
    }
}

@inline(__always)
func clamp01(_ x: Double) -> Double { max(0.0, min(1.0, x)) }

// Normalized underdamped spring progress.
// - `uIn`: normalized time in [0, 1]
// - `dampingRatio`: 0..<1 (higher = less overshoot)
// - `settleBy`: target normalized time where motion is mostly settled
func springProgress(_ uIn: Double, dampingRatio: Double = 0.55, settleBy: Double = 0.5) -> Double {
    let u = clamp01(uIn)
    let z = max(0.05, min(0.99, dampingRatio))
    let settle = max(0.1, settleBy)
    
    // Choose a normalized natural frequency that approximately settles by `settle`.
    let wn = 4.0 / (z * settle)
    let wd = wn * sqrt(1.0 - z * z)
    let c = z / sqrt(1.0 - z * z)
    
    @inline(__always)
    func raw(_ t: Double) -> Double {
        let e = exp(-z * wn * t)
        return 1.0 - e * (cos(wd * t) + c * sin(wd * t))
    }
    
    // Normalize to hit exact endpoints in [0, 1].
    let start = raw(0.0)
    let end = raw(1.0)
    let denom = end - start
    if abs(denom) <= 1e-12 {
        return u
    }
    return (raw(u) - start) / denom
}

// scale easing fitted to steps 0...29 of your `scale:` series.
//
// We fit the *normalized fraction*:
//   frac[i] = (scale[i] - scale[0]) / (scale[29] - scale[0])
// using an underdamped step response:
//   raw(n) = 1 - exp(-k t) * (cos(w t) + B sin(w t)),  t = n - n0
//
// Then we baseline-shift and normalize so:
//   frac(0) == 0 and frac(29) == 1 exactly,
// and finally un-normalize back into the scale domain.
//
// `u` in [0,1] maps to steps 0...29.
func scaleEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    // Original endpoints for steps 0 and 29
    let s0: Double = 0.09669952058569901
    let s1: Double = 1.0 // step 29

    // Fitted parameters (least-squares over steps 0...29) for the normalized fraction.
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

    // Baseline shift (forces frac(0) == 0 even if n0 < 0)
    let base = raw(0.0)
    let end  = raw(endIndex)
    let denom = end - base
    if abs(denom) <= 1e-12 {
        return s0
    }

    let frac = (raw(n) - base) / denom

    // Un-normalize back to scale. (Allows slight overshoot, like your data.)
    let s = s0 + (s1 - s0) * frac
    return s
}

/// Side transition fraction easing fitted to your sideFraction series.
/// Normalization:
/// - step 0  -> 0.0
/// - step 29 -> 1.0
///
/// `u` in [0,1] maps to steps 0...29.
func sideFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    // Map u -> sample index n in [0,29]
    let endIndex = 29.0
    let n = u * endIndex

    // Critically damped step: g(t) = 1 - exp(-k t) * (1 + k t), with delay t = n - n0
    let k  = 0.4334891216702717
    let n0 = 0.8238404710496342

    @inline(__always)
    func g(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t) * (1.0 + k * t)
    }

    // Baked normalization anchor: g(29)
    let gEnd = 0.9999344552429187
    let eased = g(n) / gEnd

    return max(0.0, min(1.0, eased))
}

// Radius transition fraction easing fitted to your series.
/// Normalization:
/// - step 0  -> 0.0
/// - step 17 -> 1.0
///
/// `u` is normalized time [0,1] mapped to steps 0...17.
/// After the transition, you typically clamp to 1.0 in your animation code.
/// Radius transition fraction easing fitted to your radiusFraction series.
/// Normalization:
/// - step 0  -> 0.0
/// - step 29 -> 1.0
///
/// `u` in [0,1] maps to steps 0...29.
func radiusFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    // Map u -> sample index n in [0,29]
    let endIndex = 29.0
    let n = u * endIndex

    // Baked fit parameters for: g(t) = 1 - exp(-k t) * (1 + k t), with delay t = n - n0
    let k  = 0.5452042256694901
    let n0 = 8.025670446964643

    @inline(__always)
    func g(_ n: Double) -> Double {
        let t = n - n0
        if t <= 0.0 { return 0.0 }
        return 1.0 - exp(-k * t) * (1.0 + k * t)
    }

    // Normalize so g(29) == 1.0
    let gEnd = g(endIndex)
    if gEnd <= 1e-12 { return 0.0 }

    let eased = g(n) / gEnd
    return max(0.0, min(1.0, eased))
}

// displacementFraction transition easing fitted to steps 0...29.
// Normalization:
// - step 0  -> 0.0
// - step 29 -> 1.0
//
// `u` in [0,1] maps to steps 0...29.
func displacementFractionEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    // Map u -> sample index n in [0,29]
    let endIndex = 29.0
    let n = u * endIndex

    // Fitted parameters (least-squares over steps 0...29) for:
    // raw(n) = 1 - exp(-k t) * (cos(w t) + B sin(w t)), t = max(0, n - n0)
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

    // Normalize so raw(29) == 1.0 (and raw(0) == 0.0 due to t<=0 clamp)
    let end = raw(endIndex)
    if end <= 1e-12 { return 0.0 }

    let eased = raw(n) / end
    return max(0.0, min(1.0, eased))
}

// subScale easing fitted to steps 0...29.
//
// Model (damped oscillation about 1.0):
//   raw(n) = 1 + A * exp(-k n) * (cos(w n) + B sin(w n))
//
// Post-adjustment:
//   shift so raw(29) becomes exactly 1.0 (end-normalized like your other fits).
//
// `u` in [0,1] maps to steps 0...29.
func subScaleEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    // Map u -> sample index n in [0,29]
    let endIndex = 29.0
    let n = u * endIndex

    // Fitted parameters (least-squares over steps 0...29):
    let A = 0.02941789470493528
    let k = 0.18710512325378066
    let w = 0.1871386188061029
    let B = 36.12000805553303

    @inline(__always)
    func raw(_ n: Double) -> Double {
        let e = exp(-k * n)
        return 1.0 + A * e * (cos(w * n) + B * sin(w * n))
    }

    // Shift so the curve lands exactly on 1.0 at the endIndex.
    let end = raw(endIndex)
    let shifted = raw(n) - (end - 1.0)

    // Optional safety clamp (keeps extreme numerical outliers in check)
    return max(0.0, min(2.0, shifted))
}

// blur pulse fitted to steps 0...29.
//
// Model (gamma-shaped pulse):
//   raw(n) = A * t^p * exp(-k * t),   t = max(0, n - n0)
//
// Post-adjustment:
//   shift so raw(29) becomes exactly 0.0 (since your series is 0 long before that).
//
// `u` in [0,1] maps to steps 0...29.
func blurEase(_ uIn: Double) -> Double {
    let u = clamp01(uIn)

    let endIndex = 29.0
    let n = u * endIndex

    // Fitted parameters (least-squares over steps 0...29) for p = 3:
    // raw(n) = A * t^3 * exp(-k t), t = max(0, n - n0)
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

    // Force the tail to land at 0.0 at endIndex.
    let tail = raw(endIndex)
    let v = raw(n) - tail

    return max(0.0, v)
}
