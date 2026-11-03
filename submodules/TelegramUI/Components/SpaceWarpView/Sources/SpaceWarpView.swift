import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import MeshTransform
import simd

private let backdropLayerClass: NSObject? = {
    let name = ("CA" as NSString).appendingFormat("BackdropLayer")
    if let cls = NSClassFromString(name as String) as AnyObject as? NSObject {
        return cls
    }
    return nil
}()

private let displacementMapColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
private let displacementMapBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little)

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

private struct RippleDisplacement {
    var offset: CGPoint
    var zOffset: CGFloat
}

private func rippleOffset(
    position: CGPoint,
    origin: CGPoint,
    time: CGFloat,
    params: RippleParams
) -> RippleDisplacement {
    // The distance of the current pixel position from `origin`.
    let distance: CGFloat = length(position - origin)
    
    if distance < 1.0 {
        return RippleDisplacement(offset: CGPoint(), zOffset: 0.0)
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
    
    let nearRadius: CGFloat = 60.0
    let minScale: CGFloat = 0.3
    if distance < nearRadius {
        let t = max(0.0, min(1.0, distance / nearRadius))
        let smooth = t * t * (3.0 - 2.0 * t)
        let scale = minScale + (1.0 - minScale) * smooth
        rippleAmount *= scale
    }

    // A vector of length `amplitude` that points away from position.
    let n: CGPoint
    n = normalize(position - origin)

    // Scale `n` by the ripple amount at the current pixel position and add it
    // to the current pixel position.
    //
    // This new position moves toward or away from `origin` based on the
    // sign and magnitude of `rippleAmount`.
    return RippleDisplacement(
        offset: n * (-rippleAmount),
        zOffset: rippleAmount
    )
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
    private let transformContainerLayer: SimpleLayer
    private let displacementMapLayer: SimpleLayer?
    private let backdropLayer: CALayer?
    private let cornerOverlayLayer: SimpleLayer
    private let backdropLayerDelegate: BackdropLayerDelegate
    
    private var gradientLayer: SimpleGradientLayer?
    
    private var link: SharedDisplayLinkDriver.Link?
    
    private var shockwaves: [Shockwave] = []
    
    private var resolution: (x: Int, y: Int)?
    private var layoutParams: (size: CGSize, cornerRadius: CGFloat)?
    private var cornerOverlayImageRadius: CGFloat?
    
    private let cornerOverlayInset: CGFloat = 48.0
    private let displacementMapAmount: CGFloat = 32.0
    
    private var displacementMapPixelData: [UInt8] = []
    private var displacementMapOffsetBuffer: [Float] = []
    private var displacementMapCachedSize: CGSize?
    private var displacementMapCachedDimensions: (width: Int, height: Int)?
    private var displacementMapSampleX8: [SIMD8<Float>] = []
    private var displacementMapSampleY: [Float] = []
    
    override public init() {
        self.backdropLayerDelegate = BackdropLayerDelegate()
        self.transformContainerLayer = SimpleLayer()
        if #available(iOS 26.0, *) {
            let displacementMapLayer = SimpleLayer()
            displacementMapLayer.magnificationFilter = .trilinear
            self.displacementMapLayer = displacementMapLayer
        } else {
            self.displacementMapLayer = nil
        }
        self.backdropLayer = createBackdropLayer()
        
        self.cornerOverlayLayer = SimpleLayer()
        
        self.contentNodeSource = ASDisplayNode()
        self.contentNodeSource.layer.rasterizationScale = UIScreenScale
        
        self.backgroundView = UIView()
        self.backgroundView.backgroundColor = .black
        self.backgroundView.isHidden = true
        
        super.init()
        
        self.addSubnode(self.contentNodeSource)
        self.view.insertSubview(self.backgroundView, belowSubview: self.contentNodeSource.view)
        
        self.transformContainerLayer.masksToBounds = false
        self.transformContainerLayer.rasterizationScale = UIScreenScale
        self.layer.addSublayer(self.transformContainerLayer)
        
        if let backdropLayer = self.backdropLayer {
            self.transformContainerLayer.addSublayer(backdropLayer)
            backdropLayer.delegate = self.backdropLayerDelegate
            backdropLayer.isHidden = true
            
            invokeBackdropLayerSetScaleMethod(object: backdropLayer, scale: UIScreenScale)
            backdropLayer.rasterizationScale = UIScreenScale
            
            self.cornerOverlayLayer.isHidden = true
            self.cornerOverlayLayer.contentsScale = UIScreenScale
            self.cornerOverlayLayer.rasterizationScale = UIScreenScale
            self.cornerOverlayLayer.zPosition = 1.0
            self.transformContainerLayer.addSublayer(self.cornerOverlayLayer)
        }
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
    
    private func adaptiveDisplacementMapResolution(from baseResolution: (x: Int, y: Int)) -> (x: Int, y: Int) {
        let qualityScale: CGFloat
        switch self.shockwaves.count {
        case 0 ... 1:
            qualityScale = 1.0
        case 2 ... 3:
            qualityScale = 0.85
        case 4 ... 5:
            qualityScale = 0.75
        default:
            qualityScale = 0.65
        }
        
        return (
            x: max(2, Int((CGFloat(baseResolution.x) * qualityScale).rounded())),
            y: max(2, Int((CGFloat(baseResolution.y) * qualityScale).rounded()))
        )
    }
    
    private func ensureDisplacementMapStorage(width: Int, height: Int) {
        let pixelByteCount = width * height * 4
        if self.displacementMapPixelData.count != pixelByteCount {
            self.displacementMapPixelData = [UInt8](repeating: 0, count: pixelByteCount)
        }
        
        let offsetCount = width * height * 2
        if self.displacementMapOffsetBuffer.count != offsetCount {
            self.displacementMapOffsetBuffer = [Float](repeating: 0.0, count: offsetCount)
        } else {
            self.displacementMapOffsetBuffer.withUnsafeMutableBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else {
                    return
                }
                memset(baseAddress, 0, rawBuffer.count)
            }
        }
    }
    
    private func updateDisplacementMapCoordinateCache(size: CGSize, width: Int, height: Int) {
        if let cachedDimensions = self.displacementMapCachedDimensions,
           let cachedSize = self.displacementMapCachedSize,
           cachedDimensions.width == width, cachedDimensions.height == height,
           cachedSize == size {
            return
        }
        
        self.displacementMapCachedDimensions = (width: width, height: height)
        self.displacementMapCachedSize = size
        
        let widthScale = Float(size.width) / Float(width)
        let heightScale = Float(size.height) / Float(height)
        let halfPixel: Float = 0.5
        
        self.displacementMapSampleY = [Float](repeating: 0.0, count: height)
        for py in 0 ..< height {
            self.displacementMapSampleY[py] = (Float(py) + halfPixel) * heightScale
        }
        
        let xBlockCount = width / 8
        self.displacementMapSampleX8 = []
        self.displacementMapSampleX8.reserveCapacity(xBlockCount)
        for block in 0 ..< xBlockCount {
            let px = block * 8
            let baseX = (Float(px) + halfPixel) * widthScale
            self.displacementMapSampleX8.append(
                SIMD8<Float>(
                    baseX + widthScale * 0.0,
                    baseX + widthScale * 1.0,
                    baseX + widthScale * 2.0,
                    baseX + widthScale * 3.0,
                    baseX + widthScale * 4.0,
                    baseX + widthScale * 5.0,
                    baseX + widthScale * 6.0,
                    baseX + widthScale * 7.0
                )
            )
        }
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
        var zOffsets = Array(repeating: CGFloat(0.0), count: vertexCount)
        let zNormalization = max(1.0, max(size.width, size.height))
        for y in 0 ..< vertexHeight {
            let normalizedY = CGFloat(y) / CGFloat(resolution.y)
            for x in 0 ..< vertexWidth {
                let normalizedX = CGFloat(x) / CGFloat(resolution.x)
                let initialPosition = CGPoint(x: normalizedX * size.width, y: normalizedY * size.height)
                
                var displacedPosition = initialPosition
                var displacedZ: CGFloat = 0.0
                for shockwave in self.shockwaves {
                    let displacement = rippleOffset(position: initialPosition, origin: shockwave.startPoint, time: shockwave.timeValue, params: params)
                    displacedPosition = displacedPosition + displacement.offset
                    displacedZ += displacement.zOffset
                }
                
                let index = vertexIndex(x, y)
                positions[index] = displacedPosition
                zOffsets[index] = displacedZ / zNormalization
            }
        }
        
        let mesh = MeshTransform()
        for y in 0 ..< vertexHeight {
            let normalizedY = CGFloat(y) / CGFloat(resolution.y)
            for x in 0 ..< vertexWidth {
                let normalizedX = CGFloat(x) / CGFloat(resolution.x)
                let source = CGPoint(x: normalizedX, y: normalizedY)
                let index = vertexIndex(x, y)
                let displacedPosition = positions[index]
                let destination = MeshTransform.Point3D(
                    x: displacedPosition.x / size.width,
                    y: displacedPosition.y / size.height,
                    z: zOffsets[index]
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
    
    private func makeDisplacementMapImage(size: CGSize, resolution: (x: Int, y: Int), params: RippleParams) -> CGImage? {
        let resolutionXY = CGSize(width: CGFloat(resolution.x), height: CGFloat(resolution.y)).aspectFitted(CGSize(width: 128.0, height: 128.0))
        var width = max(2, Int(resolutionXY.width))
        let widthRemainder = width % 8
        if widthRemainder != 0 {
            width += 8 - widthRemainder
        }
        let height = max(2, Int(resolutionXY.height))
        
        self.ensureDisplacementMapStorage(width: width, height: height)
        self.updateDisplacementMapCoordinateCache(size: size, width: width, height: height)
        
        // Keep map values mostly in [-1, 1] using the filter amount as the primary scale.
        let normalization = Float(max(1.0, abs(self.displacementMapAmount)))
        
        let amplitude = Float(params.amplitude)
        let frequency = Float(params.frequency)
        let decay = Float(params.decay)
        let speed = max(1.0, Float(params.speed))
        
        let nearRadius: Float = 60.0
        let minScale: Float = 0.3
        
        let minClamp = SIMD8<Float>(repeating: -1.0)
        let maxClamp = SIMD8<Float>(repeating: 1.0)
        let zeroToOneMin = SIMD8<Float>(repeating: 0.0)
        let zeroToOneMax = SIMD8<Float>(repeating: 1.0)
        let half = SIMD8<Float>(repeating: 0.5)
        
        let xBlockCount = width / 8
        let sampleX8 = self.displacementMapSampleX8
        let sampleY = self.displacementMapSampleY
        guard sampleX8.count == xBlockCount, sampleY.count == height else {
            return nil
        }
        
        struct ActiveShockwave {
            let origin: SIMD2<Float>
            let waveTime: Float
        }
        
        let corners = [
            SIMD2<Float>(0.0, 0.0),
            SIMD2<Float>(Float(size.width), 0.0),
            SIMD2<Float>(0.0, Float(size.height)),
            SIMD2<Float>(Float(size.width), Float(size.height))
        ]
        let negligibleContributionThreshold: Float = 0.0005
        var activeShockwaves: [ActiveShockwave] = []
        activeShockwaves.reserveCapacity(self.shockwaves.count)
        for shockwave in self.shockwaves {
            let origin = SIMD2<Float>(Float(shockwave.startPoint.x), Float(shockwave.startPoint.y))
            let waveTime = Float(shockwave.timeValue)
            
            var maxDistance: Float = 0.0
            for corner in corners {
                maxDistance = max(maxDistance, simd_length(corner - origin))
            }
            
            let minLocalTime = max(0.0, waveTime - (maxDistance / speed))
            let upperBound = amplitude * exp(-decay * minLocalTime)
            if upperBound < negligibleContributionThreshold {
                continue
            }
            
            activeShockwaves.append(ActiveShockwave(origin: origin, waveTime: waveTime))
        }
        
        if activeShockwaves.isEmpty {
            return nil
        }
        
        @inline(__always)
        func linearIndex(_ x: Int, _ y: Int) -> Int {
            return y * width + x
        }
        
        @inline(__always)
        func bufferBaseIndex(_ x: Int, _ y: Int) -> Int {
            return linearIndex(x, y) * 2
        }
        
        // Pass 1: accumulate displacement contribution for each shockwave.
        self.displacementMapOffsetBuffer.withUnsafeMutableBytes { rawBuffer in
            guard let rawBase = rawBuffer.baseAddress else {
                return
            }
            
            let floatStride = MemoryLayout<Float>.stride
            for shockwave in activeShockwaves {
                let origin = shockwave.origin
                let waveTime = shockwave.waveTime
                
                for py in 0 ..< height {
                    let y = sampleY[py]
                    let dyScalar = y - origin.y
                    let dyVec = SIMD8<Float>(repeating: dyScalar)
                    
                    for block in 0 ..< xBlockCount {
                        let xVec = sampleX8[block]
                        let dxVec = xVec - SIMD8<Float>(repeating: origin.x)
                        let distanceSquaredVec = dxVec * dxVec + dyVec * dyVec
                        
                        var invDistanceVec = SIMD8<Float>(repeating: 0.0)
                        var rippleAmountVec = SIMD8<Float>(repeating: 0.0)
                        
                        for lane in 0 ..< 8 {
                            let distanceSquared = distanceSquaredVec[lane]
                            if distanceSquared < 1.0 {
                                continue
                            }
                            
                            let distance = sqrt(distanceSquared)
                            let delay = distance / speed
                            let localTime = max(0.0, waveTime - delay)
                            
                            var rippleAmount = amplitude * sin(frequency * localTime) * exp(-decay * localTime)
                            if distance < nearRadius {
                                let t = max(0.0, min(1.0, distance / nearRadius))
                                let smooth = t * t * (3.0 - 2.0 * t)
                                let scale = minScale + (1.0 - minScale) * smooth
                                rippleAmount *= scale
                            }
                            
                            invDistanceVec[lane] = 1.0 / distance
                            rippleAmountVec[lane] = rippleAmount
                        }
                        
                        let offsetXVec = (dxVec * invDistanceVec) * (-rippleAmountVec)
                        let offsetYVec = (dyVec * invDistanceVec) * (-rippleAmountVec)
                        let delta = SIMD16<Float>(
                            offsetXVec[0], offsetYVec[0],
                            offsetXVec[1], offsetYVec[1],
                            offsetXVec[2], offsetYVec[2],
                            offsetXVec[3], offsetYVec[3],
                            offsetXVec[4], offsetYVec[4],
                            offsetXVec[5], offsetYVec[5],
                            offsetXVec[6], offsetYVec[6],
                            offsetXVec[7], offsetYVec[7]
                        )
                        
                        let baseIndex = bufferBaseIndex(block * 8, py)
                        let byteOffset = baseIndex * floatStride
                        let dst = rawBase.advanced(by: byteOffset)
                        let current = dst.loadUnaligned(as: SIMD16<Float>.self)
                        dst.storeBytes(of: current + delta, as: SIMD16<Float>.self)
                    }
                }
            }
        }
        
        // Pass 2: map accumulated offsets into displacement-map pixels.
        let invNormalization: Float = 1.0 / normalization
        var image: CGImage?
        self.displacementMapPixelData.withUnsafeMutableBytes { pixelRawBuffer in
            guard let pixelBase = pixelRawBuffer.baseAddress else {
                return
            }
            
            self.displacementMapOffsetBuffer.withUnsafeBytes { offsetRawBuffer in
                guard let offsetBase = offsetRawBuffer.baseAddress else {
                    return
                }
                
                for py in 0 ..< height {
                    for block in 0 ..< xBlockCount {
                        let px = block * 8
                        let baseIndex = bufferBaseIndex(px, py)
                        let offsetByteIndex = baseIndex * MemoryLayout<Float>.stride
                        let interleaved = offsetBase.advanced(by: offsetByteIndex).loadUnaligned(as: SIMD16<Float>.self)
                        
                        let offsetXVec = SIMD8<Float>(
                            interleaved[0], interleaved[2], interleaved[4], interleaved[6],
                            interleaved[8], interleaved[10], interleaved[12], interleaved[14]
                        )
                        let offsetYVec = SIMD8<Float>(
                            interleaved[1], interleaved[3], interleaved[5], interleaved[7],
                            interleaved[9], interleaved[11], interleaved[13], interleaved[15]
                        )
                        
                        let normalizedX = simd_clamp(offsetXVec * invNormalization, minClamp, maxClamp)
                        let normalizedY = simd_clamp(offsetYVec * invNormalization, minClamp, maxClamp)
                        
                        // 0.5 is neutral, map -1...1 to 0...1.
                        let encodedX = simd_clamp(half + normalizedX * 0.5, zeroToOneMin, zeroToOneMax)
                        let encodedY = simd_clamp(half + normalizedY * 0.5, zeroToOneMin, zeroToOneMax)
                        let roundedX = (encodedX * 255.0).rounded(.toNearestOrAwayFromZero)
                        let roundedY = (encodedY * 255.0).rounded(.toNearestOrAwayFromZero)
                        
                        let r = SIMD8<UInt32>(
                            UInt32(clamping: Int(roundedX[0])),
                            UInt32(clamping: Int(roundedX[1])),
                            UInt32(clamping: Int(roundedX[2])),
                            UInt32(clamping: Int(roundedX[3])),
                            UInt32(clamping: Int(roundedX[4])),
                            UInt32(clamping: Int(roundedX[5])),
                            UInt32(clamping: Int(roundedX[6])),
                            UInt32(clamping: Int(roundedX[7]))
                        )
                        let g = SIMD8<UInt32>(
                            UInt32(clamping: Int(roundedY[0])),
                            UInt32(clamping: Int(roundedY[1])),
                            UInt32(clamping: Int(roundedY[2])),
                            UInt32(clamping: Int(roundedY[3])),
                            UInt32(clamping: Int(roundedY[4])),
                            UInt32(clamping: Int(roundedY[5])),
                            UInt32(clamping: Int(roundedY[6])),
                            UInt32(clamping: Int(roundedY[7]))
                        )
                        
                        // BGRA in memory (premultipliedFirst, byteOrder32Little):
                        // B = 0xFF, G = g, R = r, A = 0xFF
                        let packedPixels =
                            SIMD8<UInt32>(repeating: 0xFF0000FF) |
                            (r &* SIMD8<UInt32>(repeating: 0x00010000)) |
                            (g &* SIMD8<UInt32>(repeating: 0x00000100))
                        
                        let pixelByteIndex = linearIndex(px, py) * 4
                        pixelBase.advanced(by: pixelByteIndex).storeBytes(of: packedPixels, as: SIMD8<UInt32>.self)
                    }
                }
            }
            
            guard let context = CGContext(
                data: pixelBase,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: displacementMapColorSpace,
                bitmapInfo: displacementMapBitmapInfo.rawValue
            ) else {
                return
            }
            
            image = context.makeImage()
        }
        
        return image
    }
    
    private func updateCornerOverlayImage(cornerRadius: CGFloat) {
        let cornerRadius = max(0.0, cornerRadius)
        if let currentRadius = self.cornerOverlayImageRadius, abs(currentRadius - cornerRadius) < 0.001 {
            return
        }
        self.cornerOverlayImageRadius = cornerRadius
        
        let cornerExtent = max(1.0, ceil(cornerRadius + self.cornerOverlayInset))
        let imageSize = CGSize(width: cornerExtent * 2.0 + 1.0, height: cornerExtent * 2.0 + 1.0)
        
        let overlayImage = generateImage(imageSize, opaque: false, rotatedContext: { size, context in
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
        ASDisplayNodeSetResizableContents(self.cornerOverlayLayer, overlayImage)
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat, transition: ComponentTransition) {
        self.layoutParams = (size, cornerRadius)
        if size.width <= 0.0 || size.height <= 0.0 {
            return
        }
        
        self.contentNodeSource.frame = CGRect(origin: CGPoint(), size: size)
        transition.setFrame(layer: self.transformContainerLayer, frame: CGRect(origin: CGPoint(), size: size))
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        
        if let displacementMapLayer = self.displacementMapLayer {
            transition.setFrame(layer: displacementMapLayer, frame: CGRect(origin: CGPoint(), size: size))
        }
        
        let amplitude: CGFloat
        if #available(iOS 26.0, *) {
            amplitude = 30.0
        } else {
            amplitude = 10.0
        }
        
        let params = RippleParams(amplitude: amplitude, frequency: 15.0, decay: 5.5, speed: 1400.0)
        
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
                backdropLayer.isHidden = true
                
                if let displacementMapLayer = self.displacementMapLayer {
                    displacementMapLayer.contents = nil
                    displacementMapLayer.removeFromSuperlayer()
                }
            }
            self.transformContainerLayer.filters = nil
            self.transformContainerLayer.removeAnimation(forKey: "meshTransform")
            self.transformContainerLayer.setValue(nil, forKey: "meshTransform")
            self.cornerOverlayLayer.isHidden = true
            
            self.resolution = nil
            self.backgroundView.isHidden = true
            self.contentNodeSource.clipsToBounds = false
            
            if let gradientLayer = self.gradientLayer {
                self.gradientLayer = nil
                gradientLayer.removeFromSuperlayer()
            }
            
            return
        }
        
        self.backgroundView.isHidden = false
        self.contentNodeSource.clipsToBounds = true
        
        if let backdropLayer = self.backdropLayer {
            backdropLayer.isHidden = false
            transition.setFrame(layer: backdropLayer, frame: CGRect(origin: CGPoint(), size: size))
            
            self.cornerOverlayLayer.isHidden = false
            self.updateCornerOverlayImage(cornerRadius: cornerRadius)
            transition.setFrame(
                layer: self.cornerOverlayLayer,
                frame: CGRect(
                    x: -self.cornerOverlayInset,
                    y: -self.cornerOverlayInset,
                    width: size.width + self.cornerOverlayInset * 2.0,
                    height: size.height + self.cornerOverlayInset * 2.0
                )
            )
            
            if let displacementMapLayer = self.displacementMapLayer, displacementMapLayer.superlayer == nil {
                if let displacementMapFilter = CALayer.displacementMap() {
                    displacementMapLayer.name = "displacementMapLayer"
                    displacementMapLayer.zPosition = -1.0
                    self.transformContainerLayer.addSublayer(displacementMapLayer)
                    displacementMapFilter.setValue("displacementMapLayer", forKey: "inputSourceSublayerName")
                    displacementMapFilter.setValue((-self.displacementMapAmount) as NSNumber, forKey: "inputAmount")
                    displacementMapFilter.setValue(NSValue(cgPoint: CGPoint(x: 0.5, y: 0.5)), forKey: "inputOffset")
                    self.transformContainerLayer.filters = [displacementMapFilter]
                }
            }
        } else {
            self.cornerOverlayLayer.isHidden = true
            self.transformContainerLayer.filters = nil
            self.transformContainerLayer.setValue(nil, forKey: "meshTransform")
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
        
        if self.backdropLayer != nil {
            if let displacementMapLayer = self.displacementMapLayer {
                let baseMapResolution = (
                    x: max(2, resolution.x / 2),
                    y: max(2, resolution.y / 2)
                )
                let mapResolution = self.adaptiveDisplacementMapResolution(from: baseMapResolution)
                displacementMapLayer.contents = self.makeDisplacementMapImage(size: size, resolution: mapResolution, params: params)
                
                self.transformContainerLayer.setValue(nil, forKey: "meshTransform")
            } else {
                if let meshTransform = self.makeRippleMeshTransform(size: size, resolution: resolution, params: params) {
                    if !transition.animation.isImmediate {
                        self.transformContainerLayer.removeAnimation(forKey: "meshTransform")
                    }
                    self.transformContainerLayer.setValue(meshTransform, forKey: "meshTransform")
                } else {
                    self.transformContainerLayer.setValue(nil, forKey: "meshTransform")
                }
            }
        } else {
            self.cornerOverlayLayer.isHidden = true
            self.transformContainerLayer.filters = nil
            self.transformContainerLayer.setValue(nil, forKey: "meshTransform")
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
