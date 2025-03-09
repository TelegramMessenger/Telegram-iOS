import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import STCMeshView
import UIKitRuntimeUtils

private final class FPSView: UIView {
    private var lastTimestamp: Double?
    private var counter: Int = 0
    private var fpsValue: Int?
    private var fpsString: NSAttributedString?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.layer.anchorPoint = CGPoint()
        self.backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update() {
        self.counter += 1
        let timestamp = CACurrentMediaTime()
        let deltaTime: Double
        if let lastTimestamp = self.lastTimestamp {
            deltaTime = timestamp - lastTimestamp
        } else {
            deltaTime = 1.0 / 60.0
            self.lastTimestamp = timestamp
        }
        if deltaTime >= 1.0 {
            let fpsValue = Int(Double(self.counter) / deltaTime)
            if self.fpsValue != fpsValue {
                self.fpsValue = fpsValue
                let fpsString = NSAttributedString(string: "\(fpsValue)", attributes: [.foregroundColor: UIColor.white])
                self.bounds = fpsString.boundingRect(with: CGSize(width: 100.0, height: 100.0), context: nil).integral
                self.fpsString = fpsString
                self.setNeedsDisplay()
            }
            self.counter = 0
            self.lastTimestamp = timestamp
        }
    }
                
    override func draw(_ rect: CGRect) {
        guard let fpsString = self.fpsString else {
            return
        }
        
        fpsString.draw(at: CGPoint())
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

func transformToFitQuad2(frame: CGRect, topLeft tl: CGPoint, topRight tr: CGPoint, bottomLeft bl: CGPoint, bottomRight br: CGPoint) -> (frame: CGRect, transform: CATransform3D) {
    let frameTopLeft = frame.origin
    
    let transform = rectToQuad(
        rect: CGRect(origin: CGPoint(), size: frame.size),
        quadTL: CGPoint(x: tl.x - frameTopLeft.x, y: tl.y - frameTopLeft.y),
        quadTR: CGPoint(x: tr.x - frameTopLeft.x, y: tr.y - frameTopLeft.y),
        quadBL: CGPoint(x: bl.x - frameTopLeft.x, y: bl.y - frameTopLeft.y),
        quadBR: CGPoint(x: br.x - frameTopLeft.x, y: br.y - frameTopLeft.y)
    )
    
    let anchorPoint = frame.origin
    let anchorOffset = CGPoint(x: anchorPoint.x - frame.origin.x, y: anchorPoint.y - frame.origin.y)
    let transPos = CATransform3DMakeTranslation(anchorOffset.x, anchorOffset.y, 0)
    let transNeg = CATransform3DMakeTranslation(-anchorOffset.x, -anchorOffset.y, 0)
    let fullTransform = CATransform3DConcat(CATransform3DConcat(transPos, transform), transNeg)
    
    return (frame, fullTransform)
}

func transformToFitQuad(frame: CGRect, topLeft tl: CGPoint, topRight tr: CGPoint, bottomLeft bl: CGPoint, bottomRight br: CGPoint) -> (frame: CGRect, transform: CATransform3D) {
    let boundingBox = boundingBox(forQuadWithTR: tr, tl: tl, bl: bl, br: br)
    
    let frameTopLeft = boundingBox.origin
    let transform = rectToQuad(
        rect: CGRect(origin: CGPoint(), size: frame.size),
        quadTL: CGPoint(x: tl.x - frameTopLeft.x, y: tl.y - frameTopLeft.y),
        quadTR: CGPoint(x: tr.x - frameTopLeft.x, y: tr.y - frameTopLeft.y),
        quadBL: CGPoint(x: bl.x - frameTopLeft.x, y: bl.y - frameTopLeft.y),
        quadBR: CGPoint(x: br.x - frameTopLeft.x, y: br.y - frameTopLeft.y)
    )
    
    // To account for anchor point, we must translate, transform, translate
    let anchorPoint = frame.center
    let anchorOffset = CGPoint(x: anchorPoint.x - boundingBox.origin.x, y: anchorPoint.y - boundingBox.origin.y)
    let transPos = CATransform3DMakeTranslation(anchorOffset.x, anchorOffset.y, 0)
    let transNeg = CATransform3DMakeTranslation(-anchorOffset.x, -anchorOffset.y, 0)
    let fullTransform = CATransform3DConcat(CATransform3DConcat(transPos, transform), transNeg)
    
    // Now we set our transform
    return (boundingBox, fullTransform)
}

private func boundingBox(forQuadWithTR tr: CGPoint, tl: CGPoint, bl: CGPoint, br: CGPoint) -> CGRect {
    var boundingBox = CGRect.zero
    
    let xmin = min(min(min(tr.x, tl.x), bl.x), br.x)
    let ymin = min(min(min(tr.y, tl.y), bl.y), br.y)
    let xmax = max(max(max(tr.x, tl.x), bl.x), br.x)
    let ymax = max(max(max(tr.y, tl.y), bl.y), br.y)
    
    boundingBox.origin.x = xmin
    boundingBox.origin.y = ymin
    boundingBox.size.width = xmax - xmin
    boundingBox.size.height = ymax - ymin
    
    return boundingBox
}

func rectToQuad(rect: CGRect, quadTL topLeft: CGPoint, quadTR topRight: CGPoint, quadBL bottomLeft: CGPoint, quadBR bottomRight: CGPoint) -> CATransform3D {
    return rectToQuad(rect: rect, quadTLX: topLeft.x, quadTLY: topLeft.y, quadTRX: topRight.x, quadTRY: topRight.y, quadBLX: bottomLeft.x, quadBLY: bottomLeft.y, quadBRX: bottomRight.x, quadBRY: bottomRight.y)
}

private func rectToQuad(rect: CGRect, quadTLX x1a: CGFloat, quadTLY y1a: CGFloat, quadTRX x2a: CGFloat, quadTRY y2a: CGFloat, quadBLX x3a: CGFloat, quadBLY y3a: CGFloat, quadBRX x4a: CGFloat, quadBRY y4a: CGFloat) -> CATransform3D {
    let X = rect.origin.x
    let Y = rect.origin.y
    let W = rect.size.width
    let H = rect.size.height
    
    let y21 = y2a - y1a
    let y32 = y3a - y2a
    let y43 = y4a - y3a
    let y14 = y1a - y4a
    let y31 = y3a - y1a
    let y42 = y4a - y2a
    
    let a = -H * (x2a * x3a * y14 + x2a * x4a * y31 - x1a * x4a * y32 + x1a * x3a * y42)
    let b = W * (x2a * x3a * y14 + x3a * x4a * y21 + x1a * x4a * y32 + x1a * x2a * y43)
    let c = H * X * (x2a * x3a * y14 + x2a * x4a * y31 - x1a * x4a * y32 + x1a * x3a * y42) - H * W * x1a * (x4a * y32 - x3a * y42 + x2a * y43) - W * Y * (x2a * x3a * y14 + x3a * x4a * y21 + x1a * x4a * y32 + x1a * x2a * y43)
    
    let d = H * (-x4a * y21 * y3a + x2a * y1a * y43 - x1a * y2a * y43 - x3a * y1a * y4a + x3a * y2a * y4a)
    let e = W * (x4a * y2a * y31 - x3a * y1a * y42 - x2a * y31 * y4a + x1a * y3a * y42)
    let f = -(W * (x4a * (Y * y2a * y31 + H * y1a * y32) - x3a * (H + Y) * y1a * y42 + H * x2a * y1a * y43 + x2a * Y * (y1a - y3a) * y4a + x1a * Y * y3a * (-y2a + y4a)) - H * X * (x4a * y21 * y3a - x2a * y1a * y43 + x3a * (y1a - y2a) * y4a + x1a * y2a * (-y3a + y4a)))
    
    let g = H * (x3a * y21 - x4a * y21 + (-x1a + x2a) * y43)
    let h = W * (-x2a * y31 + x4a * y31 + (x1a - x3a) * y42)
    var i = W * Y * (x2a * y31 - x4a * y31 - x1a * y42 + x3a * y42) + H * (X * (-(x3a * y21) + x4a * y21 + x1a * y43 - x2a * y43) + W * (-(x3a * y2a) + x4a * y2a + x2a * y3a - x4a * y3a - x2a * y4a + x3a * y4a))
    
    let kEpsilon = 0.0001
    
    if abs(i) < kEpsilon {
        i = kEpsilon * (i > 0 ? 1.0 : -1.0)
    }
    
    let transform = CATransform3D(
        m11: a / i, m12: d / i, m13: 0, m14: g / i,
        m21: b / i, m22: e / i, m23: 0, m24: h / i,
        m31: 0, m32: 0, m33: 1, m34: 0,
        m41: c / i, m42: f / i, m43: 0, m44: 1.0
    )
    
    return transform
}

public protocol SpaceWarpNode: ASDisplayNode {
    var contentNode: ASDisplayNode { get }
    
    func triggerRipple(at point: CGPoint)
    func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition)
}

private final class MaskGridLayer: SimpleLayer {
    private var itemLayers: [SimpleLayer] = []
    
    private var resolution: (x: Int, y: Int)?
    
    func updateGrid(size: CGSize, resolutionX: Int, resolutionY: Int, cornerRadius: CGFloat) {
        if let resolution = self.resolution, resolution.x == resolutionX, resolution.y == resolutionY {
            return
        }
        self.resolution = (resolutionX, resolutionY)
        
        for itemLayer in self.itemLayers {
            itemLayer.removeFromSuperlayer()
        }
        self.itemLayers.removeAll()
        
        let itemSize = CGSize(width: size.width / CGFloat(resolutionX), height: size.height / CGFloat(resolutionY))
        
        let topLeftCorner = CGRect(origin: CGPoint(), size: CGSize(width: cornerRadius, height: cornerRadius))
        let topRightCorner = CGRect(origin: CGPoint(x: size.width - cornerRadius, y: 0.0), size: CGSize(width: cornerRadius, height: cornerRadius))
        let bottomLeftCorner = CGRect(origin: CGPoint(x: 0.0, y: size.height - cornerRadius), size: CGSize(width: cornerRadius, height: cornerRadius))
        let bottomRightCorner = CGRect(origin: CGPoint(x: size.width - cornerRadius, y: size.height - cornerRadius), size: CGSize(width: cornerRadius, height: cornerRadius))
        
        var cornersImage: UIImage?
        if cornerRadius > 0.0 {
            cornersImage = generateImage(CGSize(width: cornerRadius * 2.0 + 200.0, height: cornerRadius * 2.0 + 200.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor.black.cgColor)
                context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: cornerRadius).cgPath)
                context.fillPath()
            })
        }
        
        for y in 0 ..< resolutionY {
            for x in 0 ..< resolutionX {
                let itemLayer = SimpleLayer()
                itemLayer.backgroundColor = UIColor.black.cgColor
                itemLayer.isOpaque = true
                itemLayer.opacity = 1.0
                itemLayer.anchorPoint = CGPoint()
                self.addSublayer(itemLayer)
                self.itemLayers.append(itemLayer)
                
                if cornerRadius > 0.0, let cornersImage {
                    let gridPosition = CGPoint(x: CGFloat(x) / CGFloat(resolutionX), y: CGFloat(y) / CGFloat(resolutionY))
                    let sourceRect = CGRect(origin: CGPoint(x: gridPosition.x * (size.width), y: gridPosition.y * (size.height)), size: itemSize)
                    if sourceRect.intersects(topLeftCorner) || sourceRect.intersects(topRightCorner) || sourceRect.intersects(bottomLeftCorner) || sourceRect.intersects(bottomRightCorner) {
                        var clippedCornersRect = sourceRect
                        if clippedCornersRect.maxX > cornersImage.size.width {
                            clippedCornersRect.origin.x -= size.width - cornersImage.size.width
                        }
                        if clippedCornersRect.maxY > cornersImage.size.height {
                            clippedCornersRect.origin.y -= size.height - cornersImage.size.height
                        }
                        
                        itemLayer.contents = cornersImage.cgImage
                        itemLayer.contentsRect = CGRect(origin: CGPoint(x: clippedCornersRect.minX / cornersImage.size.width, y: clippedCornersRect.minY / cornersImage.size.height), size: CGSize(width: clippedCornersRect.width / cornersImage.size.width, height: clippedCornersRect.height / cornersImage.size.height))
                        itemLayer.backgroundColor = nil
                        itemLayer.isOpaque = false
                    }
                }
            }
        }
    }
    
    func update(positions: [CGPoint], bounds: [CGRect], transforms: [CATransform3D]) {
        for i in 0 ..< self.itemLayers.count {
            if i < positions.count && i < bounds.count && i < transforms.count {
                let itemLayer = self.itemLayers[i]
                itemLayer.position = positions[i]
                itemLayer.bounds = bounds[i]
                itemLayer.transform = transforms[i]
            }
        }
    }
}

private final class PrivateContentLayerRestoreContext {
    final class Reference {
        weak var layer: CALayer?
        
        init(layer: CALayer) {
            self.layer = layer
        }
    }
    
    private static func collectPrivateContentLayers(layer: CALayer, into references: inout [Reference]) {
        if getLayerDisableScreenshots(layer) {
            references.append(Reference(layer: layer))
        }
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                collectPrivateContentLayers(layer: sublayer, into: &references)
            }
        }
    }
    
    private let references: [Reference]
    
    init(rootLayer: CALayer) {
        var references: [Reference] = []
        PrivateContentLayerRestoreContext.collectPrivateContentLayers(layer: rootLayer, into: &references)
        self.references = references
        
        for reference in self.references {
            if let layer = reference.layer {
                setLayerDisableScreenshots(layer, false)
            }
        }
    }
    
    func restore() {
        for reference in self.references {
            if let layer = reference.layer {
                setLayerDisableScreenshots(layer, true)
            }
        }
    }
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
    private var currentCloneView: UIView?
    private var meshView: STCMeshView?
    
    private var privateContentRestoreContext: PrivateContentLayerRestoreContext?
    
    private var gradientLayer: SimpleGradientLayer?
    private var gradientMaskLayer: MaskGridLayer?
    
    #if DEBUG
    private var fpsView: FPSView?
    #endif
    
    private var link: SharedDisplayLinkDriver.Link?
    
    private var shockwaves: [Shockwave] = []

    private var hasCompletedFirstInARowShockwave: Bool = false

    private var resolution: (x: Int, y: Int)?
    private var layoutParams: (size: CGSize, cornerRadius: CGFloat)?
    
    override public init() {
        self.contentNodeSource = ASDisplayNode()
        
        self.backgroundView = UIView()
        self.backgroundView.backgroundColor = .black
        
        #if DEBUG && false
        self.fpsView = FPSView(frame: CGRect(origin: CGPoint(x: 4.0, y: 40.0), size: CGSize()))
        #endif
        
        super.init()
        
        self.addSubnode(self.contentNodeSource)
        self.view.addSubview(self.backgroundView)
        
        #if DEBUG
        if let fpsView = self.fpsView {
            self.view.addSubview(fpsView)
        }
        #endif
    }
    
    public static func supportsHierarchy(layer: CALayer) -> Bool {
        if getLayerDisableScreenshots(layer) {
            return false
        }
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                if !supportsHierarchy(layer: sublayer) {
                    return false
                }
            }
        }
        return true
    }
    
    public func triggerRipple(at point: CGPoint) {
        if !SpaceWarpNodeImpl.supportsHierarchy(layer: self.contentNodeSource.view.layer) {
            return
        }

        if self.shockwaves.isEmpty {
            self.hasCompletedFirstInARowShockwave = false
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
        
        if let meshView = self.meshView {
            self.meshView = nil
            meshView.removeFromSuperview()
        }
        
        let meshView = STCMeshView(frame: CGRect())
        self.meshView = meshView
        self.view.insertSubview(meshView, aboveSubview: self.backgroundView)
        
        meshView.instanceCount = resolutionX * resolutionY
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        self.layoutParams = (size, cornerRadius)
        if size.width <= 0.0 || size.height <= 0.0 {
            return
        }
        
        self.contentNodeSource.frame = CGRect(origin: CGPoint(), size: size)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        
        let params = RippleParams(amplitude: 10.0, frequency: 15.0, decay: 5.5, speed: 1400.0)
        
        if let currentCloneView = self.currentCloneView {
            currentCloneView.removeFromSuperview()
            self.currentCloneView = nil
        }
        
        let maxEdge = (max(size.width, size.height) * 0.5) * 2.0
        let maxDistance = sqrt(maxEdge * maxEdge + maxEdge * maxEdge)
        let maxDelay = maxDistance / params.speed
        
        for i in (0 ..< self.shockwaves.count).reversed() {
            if self.shockwaves[i].timeValue >= maxDelay {
                self.shockwaves.remove(at: i)

                if i == 0 {
                    self.hasCompletedFirstInARowShockwave = true
                }
            }
        }
        
        guard !self.shockwaves.isEmpty else {
            if let link = self.link {
                self.link = nil
                link.invalidate()
            }
            
            if let meshView = self.meshView {
                self.meshView = nil
                meshView.removeFromSuperview()
            }
            
            self.resolution = nil
            self.backgroundView.isHidden = true
            self.contentNodeSource.clipsToBounds = false
            self.contentNodeSource.layer.cornerRadius = 0.0
            
            if let gradientLayer = self.gradientLayer {
                self.gradientLayer = nil
                gradientLayer.removeFromSuperlayer()
            }
            if let gradientMaskLayer = self.gradientMaskLayer {
                self.gradientMaskLayer = nil
                gradientMaskLayer.removeFromSuperlayer()
            }
            
            if let privateContentRestoreContext = self.privateContentRestoreContext {
                self.privateContentRestoreContext = nil
                privateContentRestoreContext.restore()
            }
            
            return
        }
        
        if self.privateContentRestoreContext == nil {
            self.privateContentRestoreContext = PrivateContentLayerRestoreContext(rootLayer: self.contentNodeSource.view.layer)
        }
        
        self.backgroundView.isHidden = false
        self.contentNodeSource.clipsToBounds = true
        self.contentNodeSource.layer.cornerRadius = cornerRadius
        
        #if DEBUG
        if let fpsView = self.fpsView {
            fpsView.update()
        }
        #endif
        
        let resolutionX = max(2, Int(size.width / 40.0))
        let resolutionY = max(2, Int(size.height / 40.0))
        self.updateGrid(resolutionX: resolutionX, resolutionY: resolutionY)
        guard let resolution = self.resolution, let meshView = self.meshView else {
            return
        }
        
        if let cloneView = self.contentNodeSource.view.resizableSnapshotView(from: CGRect(origin: CGPoint(), size: size), afterScreenUpdates: false, withCapInsets: UIEdgeInsets()) {
            self.currentCloneView = cloneView
            meshView.contentView.addSubview(cloneView)
        }
        
        meshView.frame = CGRect(origin: CGPoint(), size: size)
        
        if let shockwave = self.shockwaves.first {
            let gradientMaskLayer: MaskGridLayer
            if let current = self.gradientMaskLayer {
                gradientMaskLayer = current
            } else {
                gradientMaskLayer = MaskGridLayer()
                self.gradientMaskLayer = gradientMaskLayer
            }
            
            let gradientLayer: SimpleGradientLayer
            if let current = self.gradientLayer {
                gradientLayer = current
            } else {
                gradientLayer = SimpleGradientLayer()
                self.gradientLayer = gradientLayer
                self.layer.addSublayer(gradientLayer)
                
                gradientLayer.type = .radial
                gradientLayer.colors = [UIColor(white: 1.0, alpha: 0.0).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor, UIColor(white: 1.0, alpha: 0.2).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor]
                
                gradientLayer.mask = gradientMaskLayer
            }
            
            gradientLayer.frame = CGRect(origin: CGPoint(), size: size)
            gradientMaskLayer.frame = CGRect(origin: CGPoint(), size: size)
            
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
        
        let itemSize = CGSize(width: size.width / CGFloat(resolution.x), height: size.height / CGFloat(resolution.y))
        
        var instanceBounds: [CGRect] = []
        var instancePositions: [CGPoint] = []
        var instanceTransforms: [CATransform3D] = []
        
        for y in 0 ..< resolution.y {
            for x in 0 ..< resolution.x {
                let gridPosition = CGPoint(x: CGFloat(x) / CGFloat(resolution.x), y: CGFloat(y) / CGFloat(resolution.y))
                
                let sourceRect = CGRect(origin: CGPoint(x: gridPosition.x * (size.width), y: gridPosition.y * (size.height)), size: itemSize)
                
                let initialTopLeft = CGPoint(x: sourceRect.minX, y: sourceRect.minY)
                let initialTopRight = CGPoint(x: sourceRect.maxX, y: sourceRect.minY)
                let initialBottomLeft = CGPoint(x: sourceRect.minX, y: sourceRect.maxY)
                let initialBottomRight = CGPoint(x: sourceRect.maxX, y: sourceRect.maxY)
                
                var topLeft = initialTopLeft
                var topRight = initialTopRight
                var bottomLeft = initialBottomLeft
                var bottomRight = initialBottomRight
                
                for shockwave in self.shockwaves {
                    topLeft = topLeft + rippleOffset(position: initialTopLeft, origin: shockwave.startPoint, time: shockwave.timeValue, params: params)
                    topRight = topRight + rippleOffset(position: initialTopRight, origin: shockwave.startPoint, time: shockwave.timeValue, params: params)
                    bottomLeft = bottomLeft + rippleOffset(position: initialBottomLeft, origin: shockwave.startPoint, time: shockwave.timeValue, params: params)
                    bottomRight = bottomRight + rippleOffset(position: initialBottomRight, origin: shockwave.startPoint, time: shockwave.timeValue, params: params)
                }
                /*topLeft = transformCoordinate(position: topLeft, origin: startPoint, time: self.timeValue, params: params)
                topRight = transformCoordinate(position: topRight, origin: startPoint, time: self.timeValue, params: params)
                bottomLeft = transformCoordinate(position: bottomLeft, origin: startPoint, time: self.timeValue, params: params)
                bottomRight = transformCoordinate(position: bottomRight, origin: startPoint, time: self.timeValue, params: params)*/
                
                let distanceTopLeft = length(topLeft - initialTopLeft)
                let distanceTopRight = length(topRight - initialTopRight)
                let distanceBottomLeft = length(bottomLeft - initialBottomLeft)
                let distanceBottomRight = length(bottomRight - initialBottomRight)
                var maxDistance = max(distanceTopLeft, distanceTopRight)
                maxDistance = max(maxDistance, distanceBottomLeft)
                maxDistance = max(maxDistance, distanceBottomRight)
                
                var (frame, transform) = transformToFitQuad2(frame: sourceRect, topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
                
                if maxDistance <= 0.005 {
                    transform = CATransform3DIdentity
                }
                
                instanceBounds.append(frame)
                instancePositions.append(frame.origin)
                
                instanceTransforms.append(transform)
            }
        }
        
        instanceBounds.withUnsafeMutableBufferPointer { buffer in
            meshView.instanceBounds = buffer.baseAddress!
        }
        instancePositions.withUnsafeMutableBufferPointer { buffer in
            meshView.instancePositions = buffer.baseAddress!
        }
        instanceTransforms.withUnsafeMutableBufferPointer { buffer in
            meshView.instanceTransforms = buffer.baseAddress!
        }
        
        if let gradientMaskLayer = self.gradientMaskLayer {
            gradientMaskLayer.updateGrid(size: size, resolutionX: resolutionX, resolutionY: resolutionY, cornerRadius: cornerRadius)
            gradientMaskLayer.update(positions: instancePositions, bounds: instanceBounds, transforms: instanceTransforms)
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
