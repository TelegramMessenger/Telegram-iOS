import Foundation
import UIKit
import Display
import AsyncDisplayKit

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

private func generateGradient(size: CGSize, colors: [UIColor], positions: [CGPoint]) -> UIImage {
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

    let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: true, clear: false)
    let imageBytes = context.bytes.assumingMemoryBound(to: UInt8.self)

    for y in 0 ..< height {
        let directPixelY = Float(y) / Float(height)
        let centerDistanceY = directPixelY - 0.5
        let centerDistanceY2 = centerDistanceY * centerDistanceY

        let lineBytes = imageBytes.advanced(by: context.bytesPerRow * y)
        for x in 0 ..< width {
            let directPixelX = Float(x) / Float(width)

            let centerDistanceX = directPixelX - 0.5
            let centerDistance = sqrt(centerDistanceX * centerDistanceX + centerDistanceY2)
            
            let swirlFactor = 0.35 * centerDistance
            let theta = swirlFactor * swirlFactor * 0.8 * 8.0
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            let pixelX = max(0.0, min(1.0, 0.5 + centerDistanceX * cosTheta - centerDistanceY * sinTheta))
            let pixelY = max(0.0, min(1.0, 0.5 + centerDistanceX * sinTheta + centerDistanceY * cosTheta))

            var distanceSum: Float = 0.0

            var r: Float = 0.0
            var g: Float = 0.0
            var b: Float = 0.0

            for i in 0 ..< colors.count {
                let colorX = positionFloats[i * 2 + 0]
                let colorY = positionFloats[i * 2 + 1]

                let distanceX = pixelX - colorX
                let distanceY = pixelY - colorY

                var distance = max(0.0, 0.92 - sqrt(distanceX * distanceX + distanceY * distanceY))
                distance = distance * distance * distance
                distanceSum += distance

                r = r + distance * rgb[i * 3 + 0]
                g = g + distance * rgb[i * 3 + 1]
                b = b + distance * rgb[i * 3 + 2]
            }

            let pixelBytes = lineBytes.advanced(by: x * 4)
            pixelBytes.advanced(by: 0).pointee = UInt8(b / distanceSum * 255.0)
            pixelBytes.advanced(by: 1).pointee = UInt8(g / distanceSum * 255.0)
            pixelBytes.advanced(by: 2).pointee = UInt8(r / distanceSum * 255.0)
            pixelBytes.advanced(by: 3).pointee = 0xff
        }
    }

    return context.generateImage()!
}

final class SoftwareGradientBackgroundNode: ASDisplayNode, GradientBackgroundNode {
    private var phase: Int = 0

    private let contentView: UIImageView
    private var validPhase: Int?

    private var validLayout: CGSize?

    private var timer: Timer?

    private struct PhaseTransitionKey: Hashable {
        var width: Int
        var height: Int
        var fromPhase: Int
        var toPhase: Int
        var numberOfFrames: Int
        var curve: ContainedViewLayoutTransitionCurve
    }
    private var cachedPhaseTransition: [PhaseTransitionKey: [UIImage]] = [:]

    override public init() {
        self.contentView = UIImageView()

        super.init()

        self.view.addSubview(self.contentView)

        self.phase = 0

        self.backgroundColor = .white

        /*if #available(iOS 10.0, *) {
            let timer = Timer(timeInterval: 1.0, repeats: true, block: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.phase += 1
                if let size = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, transition: .animated(duration: 0.5, curve: .spring))
                }
            })
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }*/
    }

    deinit {
        self.timer?.invalidate()
    }

    private func generateAndCachePhaseTransition(key: PhaseTransitionKey) {
        DispatchQueue.global().async { [weak self] in
            let basePositions: [CGPoint] = [
                CGPoint(x: 0.80, y: 0.10),
                CGPoint(x: 0.60, y: 0.20),
                CGPoint(x: 0.35, y: 0.25),
                CGPoint(x: 0.25, y: 0.60),
                CGPoint(x: 0.20, y: 0.90),
                CGPoint(x: 0.40, y: 0.80),
                CGPoint(x: 0.65, y: 0.75),
                CGPoint(x: 0.75, y: 0.40)
            ]

            let colors: [UIColor] = [
                UIColor(rgb: 0x7FA381),
                UIColor(rgb: 0xFFF5C5),
                UIColor(rgb: 0x336F55),
                UIColor(rgb: 0xFBE37D)
            ]

            var images: [UIImage] = []

            let previousPositions = gatherPositions(shiftArray(array: basePositions, offset: key.fromPhase % 8))
            let positions = gatherPositions(shiftArray(array: basePositions, offset: key.toPhase % 8))

            let startTime = CFAbsoluteTimeGetCurrent()
            for i in 0 ..< key.numberOfFrames {
                let t = key.curve.solve(at: CGFloat(i) / CGFloat(key.numberOfFrames - 1))

                let morphedPositions = Array(zip(previousPositions, positions).map { previous, current -> CGPoint in
                    return interpolatePoints(previous, current, at: t)
                })

                images.append(generateGradient(size: CGSize(width: key.width, height: key.height), colors: colors, positions: morphedPositions))
            }
            print("Animation cached in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")

            DispatchQueue.main.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.cachedPhaseTransition.removeAll()
                strongSelf.cachedPhaseTransition[key] = images
            }
        }
    }

    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let sizeUpdated = self.validLayout != size
        self.validLayout = size

        let imageSize = size.fitted(CGSize(width: 80.0, height: 80.0)).integralFloor

        let basePositions: [CGPoint] = [
            CGPoint(x: 0.80, y: 0.10),
            CGPoint(x: 0.60, y: 0.20),
            CGPoint(x: 0.35, y: 0.25),
            CGPoint(x: 0.25, y: 0.60),
            CGPoint(x: 0.20, y: 0.90),
            CGPoint(x: 0.40, y: 0.80),
            CGPoint(x: 0.65, y: 0.75),
            CGPoint(x: 0.75, y: 0.40)
        ]

        let colors: [UIColor] = [
            UIColor(rgb: 0x7FA381),
            UIColor(rgb: 0xFFF5C5),
            UIColor(rgb: 0x336F55),
            UIColor(rgb: 0xFBE37D)
        ]

        let positions = gatherPositions(shiftArray(array: basePositions, offset: self.phase % 8))

        if let validPhase = self.validPhase {
            if validPhase != self.phase {
                self.validPhase = self.phase

                let previousPositions = gatherPositions(shiftArray(array: basePositions, offset: validPhase % 8))

                if case let .animated(duration, curve) = transition {
                    var images: [UIImage] = []

                    let cacheKey = PhaseTransitionKey(width: Int(imageSize.width), height: Int(imageSize.height), fromPhase: validPhase, toPhase: self.phase, numberOfFrames: Int(duration * 60), curve: curve)
                    if let current = self.cachedPhaseTransition[cacheKey] {
                        images = current
                    } else {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        let maxFrame = Int(duration * 30)
                        for i in 0 ..< maxFrame {
                            let t = curve.solve(at: CGFloat(i) / CGFloat(maxFrame - 1))

                            let morphedPositions = Array(zip(previousPositions, positions).map { previous, current -> CGPoint in
                                return interpolatePoints(previous, current, at: t)
                            })

                            images.append(generateGradient(size: imageSize, colors: colors, positions: morphedPositions))
                        }
                        print("Animation generated in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                    }

                    self.contentView.image = images.last
                    let animation = CAKeyframeAnimation(keyPath: "contents")
                    animation.values = images.map { $0.cgImage! }
                    animation.duration = duration * UIView.animationDurationFactor()
                    animation.calculationMode = .linear
                    self.contentView.layer.add(animation, forKey: "image")
                } else {
                    self.contentView.image = generateGradient(size: imageSize, colors: colors, positions: positions)
                }
            }
        } else if sizeUpdated {
            self.contentView.image = generateGradient(size: imageSize, colors: colors, positions: positions)
            self.validPhase = self.phase
        }

        transition.updateFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
    }

    public func animateEvent(transition: ContainedViewLayoutTransition) {
        self.phase = self.phase + 1
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: transition)
        }
    }
}
