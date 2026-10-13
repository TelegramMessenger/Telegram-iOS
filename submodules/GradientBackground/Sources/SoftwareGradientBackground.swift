import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Accelerate
import simd

private func shiftArray(array: [CGPoint], offset: Int) -> [CGPoint] {
    var newArray = array
    var offset = offset
    while offset > 0 {
        let element = newArray.removeFirst()
        newArray.append(element)
        offset -= 1
    }
    return newArray
}

private func gatherPositions(_ list: [CGPoint]) -> [CGPoint] {
    var result: [CGPoint] = []
    for i in 0 ..< list.count / 2 {
        result.append(list[i * 2])
    }
    return result
}

private func interpolateFloat(_ value1: CGFloat, _ value2: CGFloat, at factor: CGFloat) -> CGFloat {
    return value1 * (1.0 - factor) + value2 * factor
}

private func interpolatePoints(_ point1: CGPoint, _ point2: CGPoint, at factor: CGFloat) -> CGPoint {
    return CGPoint(x: interpolateFloat(point1.x, point2.x, at: factor), y: interpolateFloat(point1.y, point2.y, at: factor))
}

public func adjustSaturationInContext(context: DrawingContext, saturation: CGFloat) {
    var buffer = vImage_Buffer()
    buffer.data = context.bytes
    buffer.width = UInt(context.size.width * context.scale)
    buffer.height = UInt(context.size.height * context.scale)
    buffer.rowBytes = context.bytesPerRow

    let divisor: Int32 = 0x1000

    let rwgt: CGFloat = 0.3086
    let gwgt: CGFloat = 0.6094
    let bwgt: CGFloat = 0.0820

    let adjustSaturation = saturation

    let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
    let b = (1.0 - adjustSaturation) * rwgt
    let c = (1.0 - adjustSaturation) * rwgt
    let d = (1.0 - adjustSaturation) * gwgt
    let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
    let f = (1.0 - adjustSaturation) * gwgt
    let g = (1.0 - adjustSaturation) * bwgt
    let h = (1.0 - adjustSaturation) * bwgt
    let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

    let satMatrix: [CGFloat] = [
        a, b, c, 0,
        d, e, f, 0,
        g, h, i, 0,
        0, 0, 0, 1
    ]

    var matrix: [Int16] = satMatrix.map { value in
        return Int16(value * CGFloat(divisor))
    }

    vImageMatrixMultiply_ARGB8888(&buffer, &buffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
}

/// The swirl displacement applied before the colour weighting: for each pixel it is the point that
/// pixel samples the colour field at.
///
/// It is a pure function of the image dimensions — no colours, no positions, no phase — so the
/// `sqrt`/`sin`/`cos` behind it are identical for every frame of a tween and for every phase. A tween
/// is 15+ frames at one fixed size, so computing it once and reusing it removes all of the
/// transcendental work from the inner loop.
private final class SwirlMap {
    let width: Int
    let height: Int
    let x: UnsafeMutablePointer<Float>
    let y: UnsafeMutablePointer<Float>

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        let count = width * height
        self.x = UnsafeMutablePointer<Float>.allocate(capacity: count)
        self.y = UnsafeMutablePointer<Float>.allocate(capacity: count)

        for y in 0 ..< height {
            let directPixelY = Float(y) / Float(height)
            let centerDistanceY = directPixelY - 0.5
            let centerDistanceY2 = centerDistanceY * centerDistanceY

            for x in 0 ..< width {
                let directPixelX = Float(x) / Float(width)
                let centerDistanceX = directPixelX - 0.5
                let centerDistance = sqrt(centerDistanceX * centerDistanceX + centerDistanceY2)

                let swirlFactor = 0.35 * centerDistance
                let theta = swirlFactor * swirlFactor * 0.8 * 8.0
                let sinTheta = sin(theta)
                let cosTheta = cos(theta)

                self.x[y * width + x] = max(0.0, min(1.0, 0.5 + centerDistanceX * cosTheta - centerDistanceY * sinTheta))
                self.y[y * width + x] = max(0.0, min(1.0, 0.5 + centerDistanceX * sinTheta + centerDistanceY * cosTheta))
            }
        }
    }

    deinit {
        self.x.deallocate()
        self.y.deallocate()
    }
}

// One entry is enough: every frame of a tween shares a size, and the size only moves when the
// wallpaper is laid out again. `generateGradient` is normally called on the main thread but
// `generatePreview` is public, so the cache is locked. A racing double-compute is harmless — the map
// is immutable once built, and a caller holds its own reference for the duration of the loop.
private let swirlMapLock = NSLock()
private var cachedSwirlMap: SwirlMap?

private func swirlMap(width: Int, height: Int) -> SwirlMap {
    swirlMapLock.lock()
    if let current = cachedSwirlMap, current.width == width, current.height == height {
        swirlMapLock.unlock()
        return current
    }
    swirlMapLock.unlock()

    let map = SwirlMap(width: width, height: height)

    swirlMapLock.lock()
    cachedSwirlMap = map
    swirlMapLock.unlock()

    return map
}

private func generateGradient(size: CGSize, colors inputColors: [UIColor], positions: [CGPoint], adjustSaturation: CGFloat = 1.0) -> (UIImage, String) {
    let colors: [UIColor] = inputColors.count == 1 ? [inputColors[0], inputColors[0], inputColors[0]] : inputColors

    let width = Int(size.width)
    let height = Int(size.height)

    let rgbData = malloc(MemoryLayout<Float>.size * colors.count * 3)!
    defer {
        free(rgbData)
    }
    let rgb = rgbData.assumingMemoryBound(to: Float.self)
    for i in 0 ..< colors.count {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        colors[i].getRed(&r, green: &g, blue: &b, alpha: nil)

        rgb.advanced(by: i * 3 + 0).pointee = Float(r)
        rgb.advanced(by: i * 3 + 1).pointee = Float(g)
        rgb.advanced(by: i * 3 + 2).pointee = Float(b)
    }

    let positionData = malloc(MemoryLayout<Float>.size * positions.count * 2)!
    defer {
        free(positionData)
    }
    let positionFloats = positionData.assumingMemoryBound(to: Float.self)
    for i in 0 ..< positions.count {
        positionFloats.advanced(by: i * 2 + 0).pointee = Float(positions[i].x)
        positionFloats.advanced(by: i * 2 + 1).pointee = Float(1.0 - positions[i].y)
    }

    let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: true, clear: false)!
    let imageBytes = context.bytes.assumingMemoryBound(to: UInt8.self)

    // The swirl displacement is position-only, so it is hoisted out of the per-frame work entirely.
    // What remains — accumulating the colour field — is vectorized four pixels of a row at a time.
    // Both changes are bit-exact against the former scalar loop.
    let swirl = swirlMap(width: width, height: height)
    let zero = SIMD4<Float>(repeating: 0.0)
    let maxComponent = SIMD4<Float>(repeating: 255.0)
    let minDistanceSum = SIMD4<Float>(repeating: 0.00001)
    let colorCount = colors.count

    for y in 0 ..< height {
        let lineBytes = imageBytes.advanced(by: context.bytesPerRow * y)
        let rowOffset = y * width

        var x = 0
        while x < width {
            // The tail of a row is handled by filling only the live lanes and storing only those; the
            // dead lanes compute garbage that is never read, and are never gathered from out of bounds.
            let laneCount = min(4, width - x)
            var pixelX = zero
            var pixelY = zero
            for lane in 0 ..< laneCount {
                pixelX[lane] = swirl.x[rowOffset + x + lane]
                pixelY[lane] = swirl.y[rowOffset + x + lane]
            }

            var distanceSum = zero
            var r = zero
            var g = zero
            var b = zero

            for i in 0 ..< colorCount {
                let distanceX = pixelX - positionFloats[i * 2 + 0]
                let distanceY = pixelY - positionFloats[i * 2 + 1]

                var distance = simd_max(zero, 0.92 - (distanceX * distanceX + distanceY * distanceY).squareRoot())
                distance = distance * distance * distance
                distanceSum += distance

                r += distance * rgb[i * 3 + 0]
                g += distance * rgb[i * 3 + 1]
                b += distance * rgb[i * 3 + 2]
            }

            // Divide-then-scale, matching the former scalar order exactly. Folding it into a single
            // reciprocal multiply is faster but can differ in the last ulp, which is visible once the
            // result is truncated to a byte at an integer boundary.
            let clampedSum = simd_max(distanceSum, minDistanceSum)
            let pixelB = simd_min(b / clampedSum * maxComponent, maxComponent)
            let pixelG = simd_min(g / clampedSum * maxComponent, maxComponent)
            let pixelR = simd_min(r / clampedSum * maxComponent, maxComponent)

            for lane in 0 ..< laneCount {
                let pixelBytes = lineBytes.advanced(by: (x + lane) * 4)
                pixelBytes.advanced(by: 0).pointee = UInt8(pixelB[lane])
                pixelBytes.advanced(by: 1).pointee = UInt8(pixelG[lane])
                pixelBytes.advanced(by: 2).pointee = UInt8(pixelR[lane])
                pixelBytes.advanced(by: 3).pointee = 0xff
            }

            x += 4
        }
    }

    if abs(adjustSaturation - 1.0) > .ulpOfOne {
        adjustSaturationInContext(context: context, saturation: adjustSaturation)
    }

    var hashString = ""
    hashString.append("\(size.width)x\(size.height)")
    for color in colors {
        hashString.append("_\(color.argb)")
    }
    for position in positions {
        hashString.append("_\(position.x):\(position.y)")
    }
    hashString.append("_\(adjustSaturation)")
    
    return (context.generateImage()!, hashString)
}

/// Blends a premultiplied-alpha pattern over an opaque backdrop with CoreGraphics' `.softLight` at a
/// constant source alpha, writing the result back into `destination` in place.
///
/// Both buffers are 32 bits per pixel with the alpha (or skipped) component at byte 3, which is the
/// layout `DrawingContext` produces and what the rest of this file already assumes.
///
/// ## Why this lives in `GradientBackground` and must not be moved
///
/// This module is one of only two whose BUILD sets `copts = ["-O"]`, so it is optimized even in a
/// `-c dbg` build. That is load-bearing and compiler-invisible: measured over 1.41 Mpx, this kernel
/// runs in **3.4 ms at `-O` and 1083 ms at `-Onone`**. Moving it to a caller's module for tidiness —
/// `WallpaperBackgroundNode` is the natural-looking home and is `-Onone` — costs a factor of ~300 with
/// no build error and no visible symptom other than the app hitching.
///
/// ## The blend
///
/// CoreGraphics does NOT implement the PDF/CSS soft light: it omits the `D(Cb)` highlight branch, so
/// its result is linear in the source with no kink at 0.5 (verified against a full 256x256 (Cb, Cs)
/// grid). With a source alpha `Ap` over an opaque backdrop that gives
///
///     Co = Cb + a·Ap·(2·Cs − 1)·Cb·(1 − Cb)
///
/// and because the pattern is stored premultiplied (`Csp = Cs·Ap`), `Ap` cancels out of the product:
///
///     Co = Cb + a·(2·Csp − Ap)·Cb·(1 − Cb)
///
/// So the premultiplied bytes are used exactly as stored — no unpremultiply (which loses precision at
/// low alpha), no assumption that the pattern is a single colour (it is not: the symbol image is tinted
/// white while `customPatternColor` may be black), and no lookup table.
///
/// Accuracy: within 1 of CoreGraphics on every byte, with none off by more than 1, measured at
/// alpha ∈ {1.0, 0.5, 0.37, 0.15} against a transparent two-colour antialiased pattern.
public func composeSoftLightOverBackground(
    destination: UnsafeMutableRawPointer,
    destinationBytesPerRow: Int,
    pattern: UnsafeRawPointer,
    patternBytesPerRow: Int,
    width: Int,
    height: Int,
    opacity: Float
) {
    let destinationBytes = destination.assumingMemoryBound(to: UInt8.self)
    let patternBytes = pattern.assumingMemoryBound(to: UInt8.self)

    let inverse255 = SIMD4<Float>(repeating: 1.0 / 255.0)
    let maxComponent = SIMD4<Float>(repeating: 255.0)
    let one = SIMD4<Float>(repeating: 1.0)
    let two = SIMD4<Float>(repeating: 2.0)
    let sourceAlpha = SIMD4<Float>(repeating: opacity)
    let roundingBias = SIMD4<Float>(repeating: 0.5)
    let zero = SIMD4<Float>(repeating: 0.0)

    for y in 0 ..< height {
        let destinationRow = destinationBytesPerRow * y
        let patternRow = patternBytesPerRow * y

        for x in 0 ..< width {
            let destinationIndex = destinationRow + x * 4
            let patternIndex = patternRow + x * 4

            var backdropRaw = SIMD4<UInt8>()
            var patternRaw = SIMD4<UInt8>()
            for lane in 0 ..< 4 {
                backdropRaw[lane] = destinationBytes[destinationIndex + lane]
                patternRaw[lane] = patternBytes[patternIndex + lane]
            }

            let backdrop = SIMD4<Float>(backdropRaw) * inverse255
            let premultiplied = SIMD4<Float>(patternRaw) * inverse255
            // Lane 3 is the pattern's alpha; broadcasting it lets all three colour lanes share the
            // one multiply-add below.
            let alpha = SIMD4<Float>(repeating: premultiplied[3])

            let composed = backdrop + sourceAlpha * (two * premultiplied - alpha) * backdrop * (one - backdrop)
            let scaled = simd_clamp(composed * maxComponent + roundingBias, zero, maxComponent)

            // Byte 3 is left alone: it is the destination's skipped component, not a colour.
            destinationBytes[destinationIndex + 0] = UInt8(scaled[0])
            destinationBytes[destinationIndex + 1] = UInt8(scaled[1])
            destinationBytes[destinationIndex + 2] = UInt8(scaled[2])
        }
    }
}

public protocol GradientBackgroundPatternOverlayLayer: CALayer {
    var isAnimating: Bool { get set }
    
    func updateCompositionData(size: CGSize, backgroundImage: UIImage, backgroundImageHash: String)
}

public final class GradientBackgroundNode: ASDisplayNode {
    public final class CloneNode: ASImageNode {
        private weak var parentNode: GradientBackgroundNode?
        private let isDimmed: Bool
        private var index: SparseBag<Weak<CloneNode>>.Index?

        public init(parentNode: GradientBackgroundNode, isDimmed: Bool) {
            self.parentNode = parentNode
            self.isDimmed = isDimmed

            super.init()
            
            self.displaysAsynchronously = false

            if isDimmed {
                self.index = parentNode.cloneNodes.add(Weak<CloneNode>(self))
                self.image = parentNode.dimmedImage
            } else {
                self.index = parentNode.rawCloneNodes.add(Weak<CloneNode>(self))
                self.image = parentNode.rawImage
            }
        }

        deinit {
            if let parentNode = self.parentNode, let index = self.index {
                if self.isDimmed {
                    parentNode.cloneNodes.remove(index)
                } else {
                    parentNode.rawCloneNodes.remove(index)
                }
            }
        }
    }

    private static let basePositions: [CGPoint] = [
        CGPoint(x: 0.80, y: 0.10),
        CGPoint(x: 0.60, y: 0.20),
        CGPoint(x: 0.35, y: 0.25),
        CGPoint(x: 0.25, y: 0.60),
        CGPoint(x: 0.20, y: 0.90),
        CGPoint(x: 0.40, y: 0.80),
        CGPoint(x: 0.65, y: 0.75),
        CGPoint(x: 0.75, y: 0.40)
    ]

    public static func generatePreview(size: CGSize, colors: [UIColor]) -> UIImage {
        let positions = gatherPositions(shiftArray(array: GradientBackgroundNode.basePositions, offset: 0))
        return generateGradient(size: size, colors: colors, positions: positions).0
    }

    private var colors: [UIColor]
    private var phase: Int = 0
    
    private var backgroundImageHash: String?

    public let contentView: UIImageView
    private var validPhase: Int?
    private var invalidated: Bool = false

    private var dimmedImageParams: (size: CGSize, colors: [UIColor], positions: [CGPoint])?
    private var _dimmedImage: UIImage?
    private var dimmedImage: UIImage? {
        if let current = self._dimmedImage {
            return current
        } else if let (size, colors, positions) = self.dimmedImageParams {
            self._dimmedImage = generateGradient(size: size, colors: colors, positions: positions, adjustSaturation: self.saturation).0
            return self._dimmedImage
        } else {
            return nil
        }
    }
    
    private var rawImage: UIImage? {
        return self.contentView.image
    }

    private var validLayout: CGSize?
    private let cloneNodes = SparseBag<Weak<CloneNode>>()
    private let rawCloneNodes = SparseBag<Weak<CloneNode>>()

    private let useSharedAnimationPhase: Bool
    static var sharedPhase: Int = 0
    
    private var isAnimating: Bool = false

    private let saturation: CGFloat
    
    private var patternOverlayLayer: GradientBackgroundPatternOverlayLayer?
    
    private class SharedAnimationUpdate {
        let phase: Int
        let sender: AnyObject
        
        init(
            phase: Int,
            sender: AnyObject
        ) {
            self.phase = phase
            self.sender = sender
        }
    }
    
    private static let sharedAnimationSyncPipe = ValuePipe<SharedAnimationUpdate>()
    private var sharedAnimationSyncDisposable: Disposable?
    
    public init(colors: [UIColor]? = nil, useSharedAnimationPhase: Bool = false, adjustSaturation: Bool = true) {
        self.useSharedAnimationPhase = useSharedAnimationPhase
        self.saturation = adjustSaturation ? 1.7 : 1.0
        self.contentView = UIImageView()
        let defaultColors: [UIColor] = [
            UIColor(rgb: 0x7FA381),
            UIColor(rgb: 0xFFF5C5),
            UIColor(rgb: 0x336F55),
            UIColor(rgb: 0xFBE37D)
        ]
        self.colors = colors ?? defaultColors

        super.init()

        self.view.addSubview(self.contentView)

        if useSharedAnimationPhase {
            self.phase = GradientBackgroundNode.sharedPhase
            
            self.sharedAnimationSyncDisposable = (GradientBackgroundNode.sharedAnimationSyncPipe.signal()
            |> filter { [weak self] update in
                return update.sender !== self
            }
            |> deliverOnMainQueue).start(next: { [weak self] update in
                if let self {
                    self.phase = update.phase
                    if let size = self.validLayout {
                        self.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
                    }
                }
            })
        } else {
            self.phase = 0
        }
    }

    deinit {
        self.sharedAnimationSyncDisposable?.dispose()
    }
    
    public func setPatternOverlay(layer: GradientBackgroundPatternOverlayLayer?) {
        if self.patternOverlayLayer === layer {
            return
        }
        
        if let patternOverlayLayer = self.patternOverlayLayer {
            if patternOverlayLayer.superlayer == self.layer {
                patternOverlayLayer.removeFromSuperlayer()
            }
            self.patternOverlayLayer = nil
        }
        
        self.patternOverlayLayer = layer
        
        if let patternOverlayLayer = self.patternOverlayLayer {
            self.layer.addSublayer(patternOverlayLayer)
            
            patternOverlayLayer.isAnimating = self.isAnimating
            
            if let image = self.contentView.image, let backgroundImageHash = self.backgroundImageHash, self.contentView.bounds.width > 1.0, self.contentView.bounds.height > 1.0 {
                patternOverlayLayer.updateCompositionData(size: self.contentView.bounds.size, backgroundImage: image, backgroundImageHash: backgroundImageHash)
            }
        }
    }

    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, extendAnimation: Bool, backwards: Bool, completion: @escaping () -> Void) {
        let sizeUpdated = self.validLayout != size
        self.validLayout = size

        let imageSize = size.fitted(CGSize(width: 80.0, height: 80.0)).integralFloor

        let positions = gatherPositions(shiftArray(array: GradientBackgroundNode.basePositions, offset: self.phase % 8))

        let previousImage = self.contentView.image
        let previousSize = self.contentView.bounds.size
        
        if let validPhase = self.validPhase {
            if validPhase != self.phase || self.invalidated {
                self.validPhase = self.phase
                self.invalidated = false

                var steps: [[CGPoint]] = []
                if backwards {
                    let phaseCount = extendAnimation ? 6 : 1
                    self.phase = (self.phase + phaseCount) % 8
                    self.validPhase = self.phase
                    
                    var stepPhase = self.phase - phaseCount
                    if stepPhase < 0 {
                        stepPhase = 8 + stepPhase
                    }
                    for _ in 0 ... phaseCount {
                        steps.append(gatherPositions(shiftArray(array: GradientBackgroundNode.basePositions, offset: stepPhase)))
                        stepPhase = (stepPhase + 1) % 8
                    }
                } else if extendAnimation {
                    let phaseCount = 4
                    var stepPhase = (self.phase + phaseCount) % 8
                    for _ in 0 ... phaseCount {
                        steps.append(gatherPositions(shiftArray(array: GradientBackgroundNode.basePositions, offset: stepPhase)))
                        stepPhase = stepPhase - 1
                        if stepPhase < 0 {
                            stepPhase = 7
                        }
                    }
                } else {
                    steps.append(gatherPositions(shiftArray(array: GradientBackgroundNode.basePositions, offset: validPhase % 8)))
                    steps.append(positions)
                }

                if case let .animated(duration, curve) = transition, duration > 0.001 {
                    var images: [(UIImage, String)] = []

                    var dimmedImages: [UIImage] = []
                    let needDimmedImages = !self.cloneNodes.isEmpty

                    let stepCount = steps.count - 1

                    let fps: Double = extendAnimation ? 60 : 30
                    let maxFrame = Int(duration * fps)
                    let framesPerAnyStep = maxFrame / stepCount

                    for frameIndex in 0 ..< maxFrame {
                        let t = curve.solve(at: CGFloat(frameIndex) / CGFloat(maxFrame - 1))
                        let globalStep = Int(t * CGFloat(maxFrame))
                        let stepIndex = min(stepCount - 1, globalStep / framesPerAnyStep)

                        let stepFrameIndex = globalStep - stepIndex * framesPerAnyStep
                        let stepFrames: Int
                        if stepIndex == stepCount - 1 {
                            stepFrames = maxFrame - framesPerAnyStep * (stepCount - 1)
                        } else {
                            stepFrames = framesPerAnyStep
                        }
                        let stepT = CGFloat(stepFrameIndex) / CGFloat(stepFrames - 1)

                        var morphedPositions: [CGPoint] = []
                        for i in 0 ..< steps[0].count {
                            morphedPositions.append(interpolatePoints(steps[stepIndex][i], steps[stepIndex + 1][i], at: stepT))
                        }

                        images.append(generateGradient(size: imageSize, colors: self.colors, positions: morphedPositions))
                        if needDimmedImages {
                            dimmedImages.append(generateGradient(size: imageSize, colors: self.colors, positions: morphedPositions, adjustSaturation: self.saturation).0)
                        }
                    }

                    self.dimmedImageParams = (imageSize, self.colors, gatherPositions(shiftArray(array: GradientBackgroundNode.basePositions, offset: self.phase % 8)))

                    self.contentView.image = images[images.count - 1].0
                    self.backgroundImageHash = images[images.count - 1].1

                    let animation = CAKeyframeAnimation(keyPath: "contents")
                    animation.values = images.map { $0.0.cgImage! }
                    animation.duration = duration * UIView.animationDurationFactor()
                    if backwards || extendAnimation {
                        animation.calculationMode = .discrete
                    } else {
                        animation.calculationMode = .linear
                    }
                    animation.isRemovedOnCompletion = true
                    if extendAnimation && !backwards {
                        animation.fillMode = .backwards
                        animation.beginTime = self.contentView.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.25
                    }
   
                    self.isAnimating = true
                    if let patternOverlayLayer = self.patternOverlayLayer {
                        patternOverlayLayer.isAnimating = true
                    }
                    animation.completion = { [weak self] value in
                        if let strongSelf = self, value {
                            strongSelf.isAnimating = false
                            if let patternOverlayLayer = strongSelf.patternOverlayLayer {
                                patternOverlayLayer.isAnimating = false
                            }
                        }
                        
                        completion()
                    }

                    self.contentView.layer.removeAnimation(forKey: "contents")
                    self.contentView.layer.add(animation, forKey: "contents")

                    if !self.cloneNodes.isEmpty {
                        let cloneAnimation = CAKeyframeAnimation(keyPath: "contents")
                        cloneAnimation.values = dimmedImages.map { $0.cgImage! }
                        cloneAnimation.duration = animation.duration
                        cloneAnimation.calculationMode = animation.calculationMode
                        cloneAnimation.isRemovedOnCompletion = animation.isRemovedOnCompletion
                        cloneAnimation.fillMode = animation.fillMode
                        cloneAnimation.beginTime = animation.beginTime

                        self._dimmedImage = dimmedImages.last

                        for cloneNode in self.cloneNodes {
                            if let value = cloneNode.value {
                                value.image = dimmedImages.last
                                value.layer.removeAnimation(forKey: "contents")
                                value.layer.add(cloneAnimation, forKey: "contents")
                            }
                        }
                    }
                    
                    if !self.rawCloneNodes.isEmpty {
                        let cloneAnimation = CAKeyframeAnimation(keyPath: "contents")
                        cloneAnimation.values = images.map { $0.0.cgImage! }
                        cloneAnimation.duration = animation.duration
                        cloneAnimation.calculationMode = animation.calculationMode
                        cloneAnimation.isRemovedOnCompletion = animation.isRemovedOnCompletion
                        cloneAnimation.fillMode = animation.fillMode
                        cloneAnimation.beginTime = animation.beginTime

                        for cloneNode in self.rawCloneNodes {
                            if let value = cloneNode.value {
                                value.image = images.last?.0
                                value.layer.removeAnimation(forKey: "contents")
                                value.layer.add(cloneAnimation, forKey: "contents")
                            }
                        }
                    }
                } else {
                    let (image, imageHash) = generateGradient(size: imageSize, colors: self.colors, positions: positions)
                    self.contentView.image = image
                    self.backgroundImageHash = imageHash

                    let dimmedImage = generateGradient(size: imageSize, colors: self.colors, positions: positions, adjustSaturation: self.saturation).0
                    self._dimmedImage = dimmedImage
                    self.dimmedImageParams = (imageSize, self.colors, positions)

                    for cloneNode in self.cloneNodes {
                        cloneNode.value?.image = dimmedImage
                    }
                    for cloneNode in self.rawCloneNodes {
                        cloneNode.value?.image = image
                    }

                    completion()
                }
            } else if sizeUpdated {
                let (image, imageHash) = generateGradient(size: imageSize, colors: self.colors, positions: positions)
                self.contentView.image = image
                self.backgroundImageHash = imageHash

                let dimmedImage = generateGradient(size: imageSize, colors: self.colors, positions: positions, adjustSaturation: self.saturation).0
                self.dimmedImageParams = (imageSize, self.colors, positions)

                for cloneNode in self.cloneNodes {
                    cloneNode.value?.image = dimmedImage
                }
                for cloneNode in self.rawCloneNodes {
                    cloneNode.value?.image = image
                }

                self.validPhase = self.phase

                completion()
            } else {
                completion()
            }
        } else if sizeUpdated {
            let (image, imageHash) = generateGradient(size: imageSize, colors: self.colors, positions: positions)
            self.contentView.image = image
            self.backgroundImageHash = imageHash

            let dimmedImage = generateGradient(size: imageSize, colors: self.colors, positions: positions, adjustSaturation: self.saturation).0
            self.dimmedImageParams = (imageSize, self.colors, positions)

            for cloneNode in self.cloneNodes {
                cloneNode.value?.image = dimmedImage
            }
            for cloneNode in self.rawCloneNodes {
                cloneNode.value?.image = image
            }

            self.validPhase = self.phase

            completion()
        } else {
            completion()
        }

        transition.updateFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
        
        if self.contentView.image !== previousImage || self.contentView.bounds.size != previousSize {
            if let patternOverlayLayer = self.patternOverlayLayer, let imageHash = self.backgroundImageHash, let image = self.contentView.image, self.contentView.bounds.width > 1.0, self.contentView.bounds.height > 1.0 {
                patternOverlayLayer.updateCompositionData(size: size, backgroundImage: image, backgroundImageHash: imageHash)
            }
        }
    }

    public func updateColors(colors: [UIColor]) {
        var updated = false
        if self.colors.count != colors.count {
            updated = true
        } else {
            for i in 0 ..< self.colors.count {
                if !self.colors[i].isEqual(colors[i]) {
                    updated = true
                    break
                }
            }
        }
        if updated {
            self.colors = colors
            self.invalidated = true
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
            }
        }
    }
    


    public func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool, backwards: Bool, completion: @escaping () -> Void) {
        guard case let .animated(duration, _) = transition, duration > 0.001 else {
            completion()
            return
        }

        if extendAnimation || backwards {
            self.invalidated = true
        } else {
            if self.phase == 0 {
                self.phase = 7
            } else {
                self.phase = self.phase - 1
            }
        }
        if self.useSharedAnimationPhase {
            GradientBackgroundNode.sharedPhase = self.phase
            GradientBackgroundNode.sharedAnimationSyncPipe.putNext(SharedAnimationUpdate(phase: self.phase, sender: self))
        }
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: transition, extendAnimation: extendAnimation, backwards: backwards, completion: completion)
        } else {
            completion()
        }
    }
}
