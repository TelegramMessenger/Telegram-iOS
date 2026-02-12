import Foundation
import UIKit
import Display
import AsyncDisplayKit
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

private func createBackdropLayer() -> CALayer? {
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
            method(object, selector, scale)
        }
    }
}

private final class BackdropLayerDelegate: NSObject, CALayerDelegate {
    func action(for layer: CALayer, forKey event: String) -> CAAction? {
        return nullAction
    }
}

private extension CGPoint {
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

private func length(_ v: CGPoint) -> CGFloat {
    return sqrt(v.x * v.x + v.y * v.y)
}

private func normalize(_ v: CGPoint) -> CGPoint {
    let len = length(v)
    return CGPoint(x: v.x / len, y: v.y / len)
}

private struct RippleParams {
    var amplitude: CGFloat
    var frequency: CGFloat
    var decay: CGFloat
    var speed: CGFloat
    
    init(amplitude: CGFloat, frequency: CGFloat, decay: CGFloat, speed: CGFloat) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.decay = decay
        self.speed = speed
    }
}

private func rippleOffset(
    position: CGPoint,
    origin: CGPoint,
    time: CGFloat,
    params: RippleParams
) -> CGPoint {
    // The distance of the current pixel position from `origin`.
    let distance: CGFloat = length(position - origin)
    
    if distance < 1.0 {
        return position
    }
    
    // The amount of time it takes for the ripple to arrive at the current pixel position.
    let delay = distance / params.speed

    // Adjust for delay, clamp to 0.
    var time = time
    time -= delay
    time = max(0.0, time)

    // The ripple is a sine wave that Metal scales by an exponential decay
    // function.
    var rippleAmount = params.amplitude * sin(params.frequency * time) * exp(-params.decay * time)
    let absRippleAmount = abs(rippleAmount)
    if rippleAmount < 0.0 {
        rippleAmount = -absRippleAmount
    } else {
        rippleAmount = absRippleAmount
    }
    
    if distance <= 60.0 {
        rippleAmount = 0.3 * rippleAmount
    }

    // A vector of length `amplitude` that points away from position.
    let n: CGPoint
    n = normalize(position - origin)

    // Scale `n` by the ripple amount at the current pixel position and add it
    // to the current pixel position.
    //
    // This new position moves toward or away from `origin` based on the
    // sign and magnitude of `rippleAmount`.
    return n * (-rippleAmount)
}

public protocol SpaceWarpNode: ASDisplayNode {
    var contentNode: ASDisplayNode { get }
    
    func triggerRipple(at point: CGPoint)
    func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition)
}

open class SpaceWarpNodeImpl: ASDisplayNode, SpaceWarpNode {
    private final class Shockwave {
        let startPoint: CGPoint
        var timeValue: CGFloat = 0.0
        
        init(startPoint: CGPoint) {
            self.startPoint = startPoint
        }
    }
    
    public var contentNode: ASDisplayNode {
        return self.contentNodeSource
    }
    
    private let contentNodeSource: ASDisplayNode
    private let backgroundView: UIView
    private let backdropLayer: CALayer?
    private let cornerOverlayView: UIImageView
    private let backdropLayerDelegate: BackdropLayerDelegate
    
    private var gradientLayer: SimpleGradientLayer?
    
    private var link: SharedDisplayLinkDriver.Link?
    
    private var shockwaves: [Shockwave] = []
    
    private var resolution: (x: Int, y: Int)?
    private var layoutParams: (size: CGSize, cornerRadius: CGFloat)?
    private var cornerOverlayImageRadius: CGFloat?
    
    private let cornerOverlayInset: CGFloat = 48.0
    
    override public init() {
        self.backdropLayerDelegate = BackdropLayerDelegate()
        self.backdropLayer = createBackdropLayer()
        self.cornerOverlayView = UIImageView()
        
        self.contentNodeSource = ASDisplayNode()
        self.contentNodeSource.layer.rasterizationScale = UIScreenScale
        
        self.backgroundView = UIView()
        self.backgroundView.backgroundColor = .black
        self.backgroundView.isHidden = true
        
        super.init()
        
        self.addSubnode(self.contentNodeSource)
        self.view.insertSubview(self.backgroundView, belowSubview: self.contentNodeSource.view)
        
        if let backdropLayer = self.backdropLayer {
            self.layer.addSublayer(backdropLayer)
            backdropLayer.delegate = self.backdropLayerDelegate
            backdropLayer.isHidden = true
            
            invokeBackdropLayerSetScaleMethod(object: backdropLayer, scale: UIScreenScale)
            backdropLayer.rasterizationScale = UIScreenScale
        }
        
        self.cornerOverlayView.isUserInteractionEnabled = false
        self.cornerOverlayView.isHidden = true
        self.cornerOverlayView.layer.rasterizationScale = UIScreenScale
        self.view.addSubview(self.cornerOverlayView)
    }
    
    public static func supportsHierarchy(layer: CALayer) -> Bool {
        return true
    }
    
    public func triggerRipple(at point: CGPoint) {
        if !SpaceWarpNodeImpl.supportsHierarchy(layer: self.contentNodeSource.view.layer) {
            return
        }
        
        self.shockwaves.append(Shockwave(startPoint: point))
        if self.shockwaves.count > 8 {
            self.shockwaves.removeFirst()
        }
        
        if self.link == nil {
            var previousTimestamp = CACurrentMediaTime()
            self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                guard let self else {
                    return
                }
                
                let timestamp = CACurrentMediaTime()
                let deltaTime = max(0.0, min(10.0 / 60.0, timestamp - previousTimestamp))
                previousTimestamp = timestamp
                
                for shockwave in self.shockwaves {
                    shockwave.timeValue += deltaTime * (1.0 / CGFloat(UIView.animationDurationFactor()))
                }
                
                if let (size, cornerRadius) = self.layoutParams {
                    self.update(size: size, cornerRadius: cornerRadius, transition: .immediate)
                }
            })
        }
    }
    
    private func updateGrid(resolutionX: Int, resolutionY: Int) {
        if let resolution = self.resolution, resolution.x == resolutionX, resolution.y == resolutionY {
            return
        }
        self.resolution = (resolutionX, resolutionY)
    }
    
    private func makeRippleMeshTransform(size: CGSize, resolution: (x: Int, y: Int), params: RippleParams) -> MeshTransform.Value? {
        let vertexWidth = resolution.x + 1
        let vertexHeight = resolution.y + 1
        let vertexCount = vertexWidth * vertexHeight
        
        guard size.width > 0.0, size.height > 0.0, vertexCount > 0 else {
            return nil
        }
        
        func vertexIndex(_ x: Int, _ y: Int) -> Int {
            return y * vertexWidth + x
        }
        
        var positions = Array(repeating: CGPoint(), count: vertexCount)
        for y in 0 ..< vertexHeight {
            let normalizedY = CGFloat(y) / CGFloat(resolution.y)
            for x in 0 ..< vertexWidth {
                let normalizedX = CGFloat(x) / CGFloat(resolution.x)
                let initialPosition = CGPoint(x: normalizedX * size.width, y: normalizedY * size.height)
                
                var displacedPosition = initialPosition
                for shockwave in self.shockwaves {
                    displacedPosition = displacedPosition + rippleOffset(position: initialPosition, origin: shockwave.startPoint, time: shockwave.timeValue, params: params)
                }
                
                positions[vertexIndex(x, y)] = displacedPosition
            }
        }
        
        let mesh = MeshTransform()
        for y in 0 ..< vertexHeight {
            let normalizedY = CGFloat(y) / CGFloat(resolution.y)
            for x in 0 ..< vertexWidth {
                let normalizedX = CGFloat(x) / CGFloat(resolution.x)
                let source = CGPoint(x: normalizedX, y: normalizedY)
                let displacedPosition = positions[vertexIndex(x, y)]
                let destination = MeshTransform.Point3D(
                    x: displacedPosition.x / size.width,
                    y: displacedPosition.y / size.height,
                    z: 0.0
                )
                mesh.add(MeshTransform.Vertex(from: source, to: destination))
            }
        }
        
        for y in 0 ..< resolution.y {
            for x in 0 ..< resolution.x {
                let topLeft = UInt32(vertexIndex(x, y))
                let topRight = UInt32(vertexIndex(x + 1, y))
                let bottomRight = UInt32(vertexIndex(x + 1, y + 1))
                let bottomLeft = UInt32(vertexIndex(x, y + 1))
                
                mesh.add(MeshTransform.Face(indices: (topLeft, topRight, bottomRight, bottomLeft), w: (0.0, 0.0, 0.0, 0.0)))
            }
        }
        
        return mesh.makeValue()
    }
    
    private func updateCornerOverlayImage(cornerRadius: CGFloat) {
        let cornerRadius = max(0.0, cornerRadius)
        if let currentRadius = self.cornerOverlayImageRadius, abs(currentRadius - cornerRadius) < 0.001 {
            return
        }
        self.cornerOverlayImageRadius = cornerRadius
        
        let cornerExtent = max(1.0, ceil(cornerRadius + self.cornerOverlayInset))
        let imageSize = CGSize(width: cornerExtent * 2.0 + 1.0, height: cornerExtent * 2.0 + 1.0)
        
        self.cornerOverlayView.image = generateImage(imageSize, opaque: false, rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(bounds)
            
            let innerRect = bounds.insetBy(dx: self.cornerOverlayInset, dy: self.cornerOverlayInset)
            context.setBlendMode(.clear)
            context.addPath(UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius).cgPath)
            context.fillPath()
            context.setBlendMode(.normal)
        })?.resizableImage(
            withCapInsets: UIEdgeInsets(top: cornerExtent, left: cornerExtent, bottom: cornerExtent, right: cornerExtent),
            resizingMode: .stretch
        )
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        self.layoutParams = (size, cornerRadius)
        if size.width <= 0.0 || size.height <= 0.0 {
            return
        }
        
        self.contentNodeSource.frame = CGRect(origin: CGPoint(), size: size)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        
        let params = RippleParams(amplitude: 15.0, frequency: 15.0, decay: 5.5, speed: 1400.0)
        
        let maxEdge = (max(size.width, size.height) * 0.5) * 2.0
        let maxDistance = sqrt(maxEdge * maxEdge + maxEdge * maxEdge)
        let maxDelay = maxDistance / params.speed
        
        for i in (0 ..< self.shockwaves.count).reversed() {
            if self.shockwaves[i].timeValue >= maxDelay {
                self.shockwaves.remove(at: i)
            }
        }
        
        guard !self.shockwaves.isEmpty else {
            if let link = self.link {
                self.link = nil
                link.invalidate()
            }
            
            if let backdropLayer = self.backdropLayer {
                backdropLayer.removeAnimation(forKey: "meshTransform")
                backdropLayer.setValue(nil, forKey: "meshTransform")
                backdropLayer.isHidden = true
            }
            self.cornerOverlayView.layer.removeAnimation(forKey: "meshTransform")
            self.cornerOverlayView.layer.setValue(nil, forKey: "meshTransform")
            self.cornerOverlayView.isHidden = true
            
            self.resolution = nil
            self.backgroundView.isHidden = true
            self.contentNodeSource.clipsToBounds = false
            self.contentNodeSource.layer.cornerRadius = 0.0
            
            if let gradientLayer = self.gradientLayer {
                self.gradientLayer = nil
                gradientLayer.removeFromSuperlayer()
            }
            
            return
        }
        
        self.backgroundView.isHidden = false
        self.contentNodeSource.clipsToBounds = true
        self.contentNodeSource.layer.cornerRadius = cornerRadius
        
        if let backdropLayer = self.backdropLayer {
            backdropLayer.isHidden = false
            transition.setFrame(layer: backdropLayer, frame: CGRect(origin: CGPoint(), size: size))
            transition.setCornerRadius(layer: backdropLayer, cornerRadius: cornerRadius)
            
            self.cornerOverlayView.isHidden = false
            self.updateCornerOverlayImage(cornerRadius: cornerRadius)
            transition.setFrame(
                view: self.cornerOverlayView,
                frame: CGRect(
                    x: -self.cornerOverlayInset,
                    y: -self.cornerOverlayInset,
                    width: size.width + self.cornerOverlayInset * 2.0,
                    height: size.height + self.cornerOverlayInset * 2.0
                )
            )
        } else {
            self.cornerOverlayView.isHidden = true
        }
        
        let resolutionX = max(2, Int(size.width / 48.0))
        let resolutionY = max(2, Int(size.height / 48.0))
        self.updateGrid(resolutionX: resolutionX, resolutionY: resolutionY)
        guard let resolution = self.resolution else {
            return
        }
        
        if let shockwave = self.shockwaves.first {
            let gradientLayer: SimpleGradientLayer
            if let current = self.gradientLayer {
                gradientLayer = current
            } else {
                gradientLayer = SimpleGradientLayer()
                self.gradientLayer = gradientLayer
                self.layer.addSublayer(gradientLayer)
                
                gradientLayer.type = .radial
                gradientLayer.colors = [UIColor(white: 1.0, alpha: 0.0).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor, UIColor(white: 1.0, alpha: 0.2).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor]
            }
            
            gradientLayer.frame = CGRect(origin: CGPoint(), size: size)
            
            gradientLayer.startPoint = CGPoint(x: shockwave.startPoint.x / size.width, y: shockwave.startPoint.y / size.height)
            
            let distance = shockwave.timeValue * params.speed
            let progress = max(0.0, distance / min(size.width, size.height))
            
            let radius = CGSize(width: 1.0 * progress, height: (size.width / size.height) * progress)
            let endEndPoint = CGPoint(x: (gradientLayer.startPoint.x + radius.width), y: (gradientLayer.startPoint.y + radius.height))
            gradientLayer.endPoint = endEndPoint
            
            let maxWavefrontNorm: CGFloat = 0.4
            
            let normProgress = max(0.0, min(1.0, progress))
            let interpolatedNorm: CGFloat = 1.0 * (1.0 - normProgress) + maxWavefrontNorm * normProgress
            let wavefrontNorm: CGFloat = max(0.01, min(0.99, interpolatedNorm))
            
            gradientLayer.locations = ([0.0, 1.0 - wavefrontNorm, 1.0 - wavefrontNorm * 0.5, 1.0] as [CGFloat]).map { $0 as NSNumber }
            
            let alphaProgress: CGFloat = max(0.0, min(1.0, normProgress / 0.15))
            var interpolatedAlpha: CGFloat = alphaProgress
            interpolatedAlpha = max(0.0, min(1.0, interpolatedAlpha))
            gradientLayer.opacity = Float(interpolatedAlpha)
        } else {
            if let gradientLayer = self.gradientLayer {
                self.gradientLayer = nil
                gradientLayer.removeFromSuperlayer()
            }
        }
        
        if let backdropLayer = self.backdropLayer {
            if let meshTransform = self.makeRippleMeshTransform(size: size, resolution: resolution, params: params) {
                if !transition.animation.isImmediate {
                    backdropLayer.removeAnimation(forKey: "meshTransform")
                    self.cornerOverlayView.layer.removeAnimation(forKey: "meshTransform")
                }
                backdropLayer.setValue(meshTransform, forKey: "meshTransform")
                self.cornerOverlayView.layer.setValue(meshTransform, forKey: "meshTransform")
            } else {
                backdropLayer.setValue(nil, forKey: "meshTransform")
                self.cornerOverlayView.layer.setValue(nil, forKey: "meshTransform")
            }
        } else {
            self.cornerOverlayView.layer.setValue(nil, forKey: "meshTransform")
        }
    }
    
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero || self.isHidden || !self.isUserInteractionEnabled {
            return nil
        }
        for view in self.contentNode.view.subviews.reversed() {
            if let result = view.hitTest(self.view.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                return result
            }
        }
        
        let result = super.hitTest(point, with: event)
        if result != self {
            return result
        } else {
            return nil
        }
    }
}
