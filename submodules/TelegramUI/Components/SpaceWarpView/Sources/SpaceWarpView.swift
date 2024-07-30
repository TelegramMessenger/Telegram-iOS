import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import STCMeshView

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
        rippleAmount = 0.4 * rippleAmount
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
    
    private var gradientLayer: SimpleGradientLayer?
    
    private var debugLayers: [SimpleLayer] = []
    
    #if DEBUG
    private var fpsView: FPSView?
    #endif
    
    private var link: SharedDisplayLinkDriver.Link?
    
    private var shockwaves: [Shockwave] = []
    
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
    
    public func triggerRipple(at point: CGPoint) {
        self.shockwaves.append(Shockwave(startPoint: point))
        if self.shockwaves.count > 8 {
            self.shockwaves.removeFirst()
        }
        
        if self.link == nil {
            self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                guard let self else {
                    return
                }
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
        for debugLayer in self.debugLayers {
            debugLayer.removeFromSuperlayer()
        }
        self.debugLayers.removeAll()
        
        let meshView = STCMeshView(frame: CGRect())
        self.meshView = meshView
        self.view.insertSubview(meshView, aboveSubview: self.backgroundView)
        
        meshView.instanceCount = resolutionX * resolutionY
        
        /*for _ in 0 ..< resolutionX * resolutionY {
            let debugLayer = SimpleLayer()
            debugLayer.backgroundColor = UIColor.red.cgColor
            debugLayer.opacity = 1.0
            self.layer.addSublayer(debugLayer)
            self.debugLayers.append(debugLayer)
        }*/
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        self.layoutParams = (size, cornerRadius)
        if size.width <= 0.0 || size.height <= 0.0 {
            return
        }
        
        self.contentNodeSource.frame = CGRect(origin: CGPoint(), size: size)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        
        let params = RippleParams(amplitude: 20.0, frequency: 15.0, decay: 8.0, speed: 1400.0)
        
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
            
            for debugLayer in self.debugLayers {
                debugLayer.removeFromSuperlayer()
            }
            self.debugLayers.removeAll()
            
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
        
        /*let gradientLayer: SimpleGradientLayer
        if let current = self.gradientLayer {
            gradientLayer = current
        } else {
            gradientLayer = SimpleGradientLayer()
            self.gradientLayer = gradientLayer
            self.layer.addSublayer(gradientLayer)
            
            gradientLayer.type = .radial
            gradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        }
        gradientLayer.frame = CGRect(origin: CGPoint(), size: size)
        
        gradientLayer.startPoint = CGPoint(x: startPoint.x / size.width, y: startPoint.x / size.height)
        let radius = CGSize(width: maxEdge, height: maxEdge)
        let endEndPoint = CGPoint(x: (gradientLayer.startPoint.x + radius.width) * 1.0, y: (gradientLayer.startPoint.y + radius.height) * 1.0)
        gradientLayer.endPoint = endEndPoint
        
        let progress = max(0.0, min(1.0, self.timeValue / maxDelay))*/
        
        #if DEBUG
        if let fpsView = self.fpsView {
            fpsView.update()
        }
        #endif
        
        self.updateGrid(resolutionX: max(2, Int(size.width / 40.0)), resolutionY: max(2, Int(size.height / 40.0)))
        guard let resolution = self.resolution, let meshView = self.meshView else {
            return
        }
        
        if let cloneView = self.contentNodeSource.view.resizableSnapshotView(from: CGRect(origin: CGPoint(), size: size), afterScreenUpdates: false, withCapInsets: UIEdgeInsets()) {
            self.currentCloneView = cloneView
            meshView.contentView.addSubview(cloneView)
        }
        
        meshView.frame = CGRect(origin: CGPoint(), size: size)
        
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
        
        for i in 0 ..< self.debugLayers.count {
            self.debugLayers[i].bounds = instanceBounds[i]
            self.debugLayers[i].position = instancePositions[i]
            self.debugLayers[i].transform = instanceTransforms[i]
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
