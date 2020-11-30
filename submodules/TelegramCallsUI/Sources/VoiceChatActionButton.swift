import Foundation
import UIKit
import AsyncDisplayKit
import Display

private let titleFont = Font.regular(17.0)
private let subtitleFont = Font.regular(13.0)

private let blue = UIColor(rgb: 0x0078ff)
private let lightBlue = UIColor(rgb: 0x59c7f8)
private let green = UIColor(rgb: 0x33c659)

private let deviceScale = UIScreen.main.scale

private let radialMaskImage = generateImage(CGSize(width: 100.0, height: 100.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var locations: [CGFloat] = [0.0, 1.0]
    let maskColors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: 0.75).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
    let maskGradient = CGGradient(colorsSpace: colorSpace, colors: maskColors as CFArray, locations: &locations)!
    let maskGradientCenter = CGPoint(x: size.width / 2.0, y: size.height / 2.0)

    context.drawRadialGradient(maskGradient, startCenter: maskGradientCenter, startRadius: 0.0, endCenter: maskGradientCenter, endRadius: size.width / 2.0, options: .drawsAfterEndLocation)
}, opaque: false, scale: deviceScale)!

enum VoiceChatActionButtonState {
    enum ActiveState {
        case cantSpeak
        case muted
        case on
    }

    case connecting
    case active(state: ActiveState)
}

private enum VoiceChatActionButtonBackgroundNodeType {
    case connecting
    case disabled
    case blob
}

private protocol VoiceChatActionButtonBackgroundNodeContext {
    var type: VoiceChatActionButtonBackgroundNodeType { get }
    var frameInterval: Int { get }
    var isAnimating: Bool { get }
    
    func updateAnimations()
    func drawingState(transition: VoiceChatActionButtonBackgroundNodeTransitionState?) -> VoiceChatActionButtonBackgroundNodeState
}

private protocol VoiceChatActionButtonBackgroundNodeState: NSObjectProtocol {
    var blueGradient: UIImage? { get set }
    var greenGradient: UIImage? { get set }
}

private final class VoiceChatActionButtonBackgroundNodeConnectingContext: VoiceChatActionButtonBackgroundNodeContext {
    var blueGradient: UIImage?
    
    init(blueGradient: UIImage?) {
        self.blueGradient = blueGradient
    }
    
    var isAnimating: Bool {
        return true
    }
    
    var frameInterval: Int {
        return 1
    }
    
    var type: VoiceChatActionButtonBackgroundNodeType {
        return .connecting
    }
    
    func updateAnimations() {
    }
    
    func drawingState(transition: VoiceChatActionButtonBackgroundNodeTransitionState?) -> VoiceChatActionButtonBackgroundNodeState {
        return VoiceChatActionButtonBackgroundNodeConnectingState(blueGradient: self.blueGradient)
    }
}

private final class VoiceChatActionButtonBackgroundNodeConnectingState: NSObject, VoiceChatActionButtonBackgroundNodeState {
    var blueGradient: UIImage?
    var greenGradient: UIImage?
    
    init(blueGradient: UIImage?) {
        self.blueGradient = blueGradient
    }
}

private final class VoiceChatActionButtonBackgroundNodeDisabledContext: VoiceChatActionButtonBackgroundNodeContext {
    var isAnimating: Bool {
        return false
    }
    
    var frameInterval: Int {
        return 1
    }
    
    var type: VoiceChatActionButtonBackgroundNodeType {
        return .disabled
    }
    
    func updateAnimations() {
    }
    
    func drawingState(transition: VoiceChatActionButtonBackgroundNodeTransitionState?) -> VoiceChatActionButtonBackgroundNodeState {
        return VoiceChatActionButtonBackgroundNodeDisabledState()
    }
}

private final class VoiceChatActionButtonBackgroundNodeDisabledState: NSObject, VoiceChatActionButtonBackgroundNodeState {
    var blueGradient: UIImage?
    var greenGradient: UIImage?
}

private final class Blob {
    let size: CGSize
    let alpha: CGFloat
    
    let pointsCount: Int
    let smoothness: CGFloat

    let minRandomness: CGFloat
    let maxRandomness: CGFloat

    let minSpeed: CGFloat
    let maxSpeed: CGFloat

    var currentScale: CGFloat = 1.0
    var minScale: CGFloat
    var maxScale: CGFloat
    
    private var speedLevel: CGFloat = 0.0
    private var lastSpeedLevel: CGFloat = 0.0

    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?
    
    private var currentPoints: [CGPoint]? {
        guard let fromPoints = self.fromPoints, let toPoints = self.toPoints else { return nil }

        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(x: fromPoint.x + (toPoint.x - fromPoint.x) * transition, y: fromPoint.y + (toPoint.y - fromPoint.y) * transition)
        }
    }

    var currentShape: UIBezierPath?
    private var transition: CGFloat = 0 {
        didSet {
            if let currentPoints = self.currentPoints {
                self.currentShape = UIBezierPath.smoothCurve(through: currentPoints, length: size.width, smoothness: smoothness)
            }
        }
    }
    
    var level: CGFloat = 0.0 {
        didSet {
            self.currentScale = self.minScale + (self.maxScale - self.minScale) * self.level
        }
    }
    
    private var transitionArguments: (startTime: Double, duration: Double)?
    
    var loop: Bool = true {
        didSet {
            if let _ = transitionArguments {
            } else {
                self.animateToNewShape()
            }
        }
    }
    
    init(
        size: CGSize,
        alpha: CGFloat,
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat
    ) {
        self.size = size
        self.alpha = alpha
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale

        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2

        self.currentScale = minScale
        
        self.animateToNewShape()
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        self.speedLevel = max(self.speedLevel, newSpeedLevel)

        if abs(lastSpeedLevel - newSpeedLevel) > 0.3 {
            animateToNewShape()
        }
    }
    
    private func animateToNewShape() {
        if let _ = self.transitionArguments {
            self.fromPoints = self.currentPoints
            self.toPoints = nil
            self.transition = 0.0
            self.transitionArguments = nil
        }

        if self.fromPoints == nil {
            self.fromPoints = generateNextBlob(for: self.size)
        }
        if self.toPoints == nil {
            self.toPoints = generateNextBlob(for: self.size)
        }

        let duration: Double = 1.0 / Double(minSpeed + (maxSpeed - minSpeed) * speedLevel)
        self.transitionArguments = (CACurrentMediaTime(), duration)

        self.lastSpeedLevel = self.speedLevel
        self.speedLevel = 0

        self.updateAnimations()
    }
    
    func updateAnimations() {
        let timestamp = CACurrentMediaTime()
        if let (startTime, duration) = self.transitionArguments, duration > 0.0 {
            self.transition = max(0.0, min(1.0, CGFloat((timestamp - startTime) / duration)))
            if self.transition < 1.0 {
            } else {
                if self.loop {
                    self.animateToNewShape()
                } else {
                    self.fromPoints = self.currentPoints
                    self.toPoints = nil
                    self.transition = 0.0
                    self.transitionArguments = nil
                }
            }
        }
    }
    
    private func generateNextBlob(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return blob(pointsCount: pointsCount, randomness: randomness).map {
            return CGPoint(x: size.width / 2.0 + $0.x * CGFloat(size.width), y: size.height / 2.0 + $0.y * CGFloat(size.height))
        }
    }

    private func blob(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)

        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1.0 / (1.0 + randomness / 10.0)

        let startAngle = angle * CGFloat(arc4random_uniform(100)) / CGFloat(100)

        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let angleRandomness: CGFloat = angle * 0.1
            let randAngle = angle + angle * ((angleRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - angleRandomness * 0.5)
            let pointX = sin(startAngle + CGFloat(i) * randAngle)
            let pointY = cos(startAngle + CGFloat(i) * randAngle)
            return CGPoint(x: pointX * randPointOffset, y: pointY * randPointOffset)
        }

        return points
    }
}

private final class VoiceChatActionButtonBackgroundNodeBlobContext: VoiceChatActionButtonBackgroundNodeContext {
    var blueGradient: UIImage?
    var greenGradient: UIImage?
    
    var isAnimating: Bool {
        return true
    }
    
    var frameInterval: Int {
        return 2
    }
    
    var type: VoiceChatActionButtonBackgroundNodeType {
        return .blob
    }
    
    let size: CGSize
    var active: Bool
    var activeTransitionArguments: (startTime: Double, duration: Double)?
    
    typealias BlobRange = (min: CGFloat, max: CGFloat)
    let blobs: [Blob]
    
    init(size: CGSize, active: Bool, blueGradient: UIImage, greenGradient: UIImage) {
        self.size = size
        self.active = active
        self.blueGradient = blueGradient
        self.greenGradient = greenGradient
        
        let mediumBlobRange: BlobRange = (0.69, 0.87)
        let bigBlobRange: BlobRange = (0.71, 1.00)
        
        let mediumBlob = Blob(size: size, alpha: 0.55, pointsCount: 8, minRandomness: 1, maxRandomness: 1, minSpeed: 1.5, maxSpeed: 7, minScale: mediumBlobRange.min, maxScale: mediumBlobRange.max)
        let largeBlob = Blob(size: size, alpha: 0.35, pointsCount: 8, minRandomness: 1, maxRandomness: 1, minSpeed: 1.5, maxSpeed: 7, minScale: bigBlobRange.min, maxScale: bigBlobRange.max)
 
        self.blobs = [largeBlob, mediumBlob]
    }
    
    func update(with state: VoiceChatActionButtonBackgroundNodeBlobContext) {
        if self.active != state.active {
            self.active = state.active
            
            self.activeTransitionArguments = (CACurrentMediaTime(), 0.3)
        }
    }
    
    func updateAnimations() {
        let timestamp = CACurrentMediaTime()
        
        if let (startTime, duration) = self.activeTransitionArguments, duration > 0.0 {
            let transition = max(0.0, min(1.0, CGFloat((timestamp - startTime) / duration)))
            if transition < 1.0 {
            } else {
                self.activeTransitionArguments = nil
            }
        }
        
        for blob in self.blobs {
            blob.updateAnimations()
        }
    }
    
    func drawingState(transition: VoiceChatActionButtonBackgroundNodeTransitionState?) -> VoiceChatActionButtonBackgroundNodeState {
        var blobs: [BlobDrawingState] = []
        for blob in self.blobs {
            if let path = blob.currentShape?.copy() as? UIBezierPath {
                let size = CGSize(width: 300.0, height: 300.0)
                var appearanceProgress: CGFloat = 1.0
                if let transition = transition, transition.previousState == .connecting || transition.previousState == .disabled {
                    appearanceProgress = transition.transition
                }
                let offset = (size.width - blob.size.width) / 2.0
                let toOrigin = CGAffineTransform(translationX: -size.width / 2.0 + offset, y: -size.height / 2.0 + offset)
                let fromOrigin = CGAffineTransform(translationX: size.width / 2.0, y: size.height / 2.0)
    
                path.apply(toOrigin)
                path.apply(CGAffineTransform(scaleX: blob.currentScale * appearanceProgress, y: blob.currentScale * appearanceProgress))
                path.apply(fromOrigin)

                blobs.append(BlobDrawingState(size: blob.size, path: path.cgPath, scale: blob.currentScale, alpha: blob.alpha))
            }
        }
        return VoiceChatActionButtonBackgroundNodeBlobState(size: self.size, active: self.active, activeTransitionArguments: self.activeTransitionArguments, blueGradient: self.blueGradient, greenGradient: self.greenGradient, blobs: blobs)
    }
}

private class BlobDrawingState: NSObject {
    let size: CGSize
    let path: CGPath
    let scale: CGFloat
    let alpha: CGFloat
    
    init(size: CGSize, path: CGPath, scale: CGFloat, alpha: CGFloat) {
        self.size = size
        self.path = path
        self.scale = scale
        self.alpha = alpha
    }
}

private final class VoiceChatActionButtonBackgroundNodeBlobState: NSObject, VoiceChatActionButtonBackgroundNodeState {
    var blueGradient: UIImage?
    var greenGradient: UIImage?
        
    let active: Bool
    let activeTransitionArguments: (startTime: Double, duration: Double)?
    
    let blobs: [BlobDrawingState]
    
    init(size: CGSize, active: Bool, activeTransitionArguments: (startTime: Double, duration: Double)?, blueGradient: UIImage?, greenGradient: UIImage?, blobs: [BlobDrawingState]) {
        self.active = active
        self.activeTransitionArguments = activeTransitionArguments
        self.blueGradient = blueGradient
        self.greenGradient = greenGradient
        self.blobs = blobs
    }
}

private final class VoiceChatActionButtonBackgroundNodeTransitionState: NSObject {
    let startTime: Double
    let transition: CGFloat
    let previousState: VoiceChatActionButtonBackgroundNodeType
    
    init(startTime: Double, transition: CGFloat, previousState: VoiceChatActionButtonBackgroundNodeType) {
        self.startTime = startTime
        self.transition = transition
        self.previousState = previousState
    }
}


private final class VoiceChatActionButtonBackgroundNodeTransitionContext {
    let startTime: Double
    let duration: Double
    let previousState: VoiceChatActionButtonBackgroundNodeContext
    
    init(startTime: Double, duration: Double, previousState: VoiceChatActionButtonBackgroundNodeContext) {
        self.startTime = startTime
        self.duration = duration
        self.previousState = previousState
    }
    
    func progress(time: Double) -> CGFloat {
        if duration > 0.0 {
            return CGFloat(max(0.0, min(1.0, (time - startTime) / duration)))
        } else {
            return 0.0
        }
    }
    
    func drawingTransitionState(time: Double) -> VoiceChatActionButtonBackgroundNodeTransitionState {
        let transition = CGFloat(max(0.0, min(1.0, (time - startTime) / duration)))
        return VoiceChatActionButtonBackgroundNodeTransitionState(startTime: self.startTime, transition: transition, previousState: previousState.type)
    }
}

private class VoiceChatActionButtonBackgroundNodeDrawingState: NSObject {
    let timestamp: Double
    let state: VoiceChatActionButtonBackgroundNodeState
    let simplified: Bool
    let gradientMovement: CGPoint
    let transition: VoiceChatActionButtonBackgroundNodeTransitionState?
    
    init(timestamp: Double, state: VoiceChatActionButtonBackgroundNodeState, simplified: Bool, gradientMovement: CGPoint, transition: VoiceChatActionButtonBackgroundNodeTransitionState?) {
        self.timestamp = timestamp
        self.state = state
        self.simplified = simplified
        self.gradientMovement = gradientMovement
        self.transition = transition
    }
}

private class VoiceChatActionButtonBackgroundNode: ASDisplayNode {
    private var state: VoiceChatActionButtonBackgroundNodeContext
    private var hasState = false
    private var transition: VoiceChatActionButtonBackgroundNodeTransitionContext?
    private var simplified = false
    
    private var gradientMovementArguments: (from: CGPoint, to: CGPoint, startTime: Double, duration: Double)?
    private var gradientMovement = CGPoint()
    
    var audioLevel: CGFloat = 0.0  {
        didSet {
            if let blobsState = self.state as? VoiceChatActionButtonBackgroundNodeBlobContext {
                for blob in blobsState.blobs {
                    blob.loop = audioLevel.isZero
                    blob.updateSpeedLevel(to: self.audioLevel)
                }
            }
        }
    }
    private var presentationAudioLevel: CGFloat = 0.0
    
    private var animator: ConstantDisplayLinkAnimator?
    
    override init() {
        self.state = VoiceChatActionButtonBackgroundNodeConnectingContext(blueGradient: nil)
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
    }
    
    func update(state: VoiceChatActionButtonBackgroundNodeContext, simplified: Bool, animated: Bool) {
        var animated = animated
        var hadState = true
        if !self.hasState {
            hadState = false
            self.hasState = true
            animated = false
        }
        
        self.simplified = simplified
        
        if state.type != self.state.type || !hadState {
            if animated {
                self.transition = VoiceChatActionButtonBackgroundNodeTransitionContext(startTime: CACurrentMediaTime(), duration: 0.3, previousState: self.state)
            }
            self.state = state
        } else if let blobState = self.state as? VoiceChatActionButtonBackgroundNodeBlobContext, let nextState = state as? VoiceChatActionButtonBackgroundNodeBlobContext {
            blobState.update(with: nextState)
        }
        
        self.updateAnimations()
    }
    
    var isCurrentlyInHierarchy = false
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimations()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimations()
    }
    
    private func updateAnimations() {
        var animate = false
        let timestamp = CACurrentMediaTime()
        
        self.presentationAudioLevel = self.presentationAudioLevel * 0.9 + max(0.1, self.audioLevel) * 0.1
        if let blobsState = self.state as? VoiceChatActionButtonBackgroundNodeBlobContext {
            for blob in blobsState.blobs {
                blob.level = self.presentationAudioLevel
            }
        }
        
        if let transition = self.transition {
            if transition.startTime + transition.duration < timestamp {
                self.transition = nil
            } else {
                animate = true
            }
        }
        
        if self.gradientMovementArguments == nil {
            self.gradientMovementArguments = (CGPoint(), CGPoint(x: 0.25, y: 0.25), CACurrentMediaTime(), 1.5)
        }
        if let (from, to, startTime, duration) = self.gradientMovementArguments, duration > 0.0 {
            let progress = max(0.0, min(1.0, CGFloat((timestamp - startTime) / duration)))
            self.gradientMovement = CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
            
            if progress < 1.0 {
            } else {
                var nextTo: CGPoint
                if presentationAudioLevel > 0.3 {
                    nextTo = CGPoint(x: CGFloat.random(in: 0.0 ..< 0.1), y: CGFloat.random(in: 0.0 ..< 0.9))
                } else {
                    if to.x > 0.5 {
                        nextTo = CGPoint(x: CGFloat.random(in: 0.0 ..< 0.4), y: CGFloat.random(in: 0.0 ..< 0.6))
                    } else {
                        nextTo = CGPoint(x: CGFloat.random(in: 0.5 ..< 1.0), y: CGFloat.random(in: 0.0 ..< 0.7))
                    }
                }
                self.gradientMovementArguments = (to, nextTo, timestamp, Double.random(in: 1.2 ..< 2.0))
            }
        }
        
        if self.state.isAnimating {
            animate = true
            self.state.updateAnimations()
        }
        
        if !self.isCurrentlyInHierarchy {
            animate = false
        }
                
        if animate {
            let animator: ConstantDisplayLinkAnimator
            if let current = self.animator {
                animator = current
            } else {
                animator = ConstantDisplayLinkAnimator(update: { [weak self] in
                    self?.updateAnimations()
                })
                self.animator = animator
            }
            animator.isPaused = false
            if self.transition == nil {
                animator.frameInterval = state.frameInterval
            }
        } else {
            self.animator?.isPaused = true
        }
        
        self.setNeedsDisplay()
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        let timestamp = CACurrentMediaTime()
        let transitionState = self.transition?.drawingTransitionState(time: timestamp)
        return VoiceChatActionButtonBackgroundNodeDrawingState(timestamp: timestamp, state: self.state.drawingState(transition: transitionState), simplified: self.simplified, gradientMovement: self.gradientMovement, transition: transitionState)
    }

    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }

        guard let parameters = parameters as? VoiceChatActionButtonBackgroundNodeDrawingState else {
            return
        }
        
        let greyColor = UIColor(rgb: 0x1c1c1e)
        let buttonSize = CGSize(width: 144.0, height: 144.0)
        let radius = buttonSize.width / 2.0
        
        var gradientCenter = CGPoint(x: bounds.size.width, y: 50.0)
        gradientCenter.x -= 90.0 * parameters.gradientMovement.x
        gradientCenter.y += 120.0 * parameters.gradientMovement.y
        
        var gradientTransition: CGFloat = 0.0
        var gradientImage: UIImage? = parameters.state.blueGradient
        var simpleColor: UIColor = blue
        let gradientSize: CGFloat = bounds.width * 2.0
        
        context.interpolationQuality = .low
        
        var appearanceProgress: CGFloat = 1.0
        var glowScale: CGFloat = 0.75
        if let transition = parameters.transition, transition.previousState == .connecting || transition.previousState == .disabled {
            appearanceProgress = transition.transition
        }
        
        if let blobsState = parameters.state as? VoiceChatActionButtonBackgroundNodeBlobState {
            gradientTransition = blobsState.active ? 1.0 : 0.0
            if let transition = blobsState.activeTransitionArguments {
                gradientTransition = CGFloat((parameters.timestamp - transition.startTime) / transition.duration)
                if !blobsState.active {
                    gradientTransition = 1.0 - gradientTransition
                }
            }
            glowScale += gradientTransition * 0.3
            
            simpleColor = blue.interpolateTo(green, fraction: gradientTransition)!
                        
            if !parameters.simplified {
                gradientImage = gradientTransition.isZero ? blobsState.blueGradient : blobsState.greenGradient
                if gradientTransition > 0.0 && gradientTransition < 1.0 {
                    gradientImage = generateImage(CGSize(width: 100.0, height: 100.0), contextGenerator: { size, context in
                        context.interpolationQuality = .low
                        if let image = blobsState.blueGradient?.cgImage {
                            context.draw(image, in: CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 100.0)))
                        }
                        
                        context.setAlpha(gradientTransition)
                        if let image = blobsState.greenGradient?.cgImage {
                            context.draw(image, in: CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 100.0)))
                        }
                    }, opaque: true, scale: deviceScale)!
                }
            }
            
            context.saveGState()

            let progress = 1.0 - (appearanceProgress * glowScale)
            let maskBounds = bounds.insetBy(dx: bounds.width / 3.0 * progress,  dy: bounds.width / 3.0 * progress)
            
            context.clip(to: maskBounds, mask: radialMaskImage.cgImage!)
            
            if parameters.simplified {
                context.setFillColor(simpleColor.cgColor)
                context.fill(bounds)
            } else if let gradient = gradientImage?.cgImage {
                context.draw(gradient, in: CGRect(origin: CGPoint(x: gradientCenter.x - gradientSize / 2.0, y: gradientCenter.y - gradientSize / 2.0), size: CGSize(width: gradientSize, height: gradientSize)))
            }
            context.restoreGState()
        }

        context.saveGState()
        
        if let blobsState = parameters.state as? VoiceChatActionButtonBackgroundNodeBlobState {
            for blob in blobsState.blobs {
                context.addPath(blob.path)
                context.clip()

                context.setAlpha(blob.alpha)

                if parameters.simplified {
                    context.setFillColor(simpleColor.cgColor)
                    context.fill(bounds)
                } else if let gradient = gradientImage?.cgImage {
                    context.draw(gradient, in: CGRect(origin: CGPoint(x: gradientCenter.x - gradientSize / 2.0, y: gradientCenter.y - gradientSize / 2.0), size: CGSize(width: gradientSize, height: gradientSize)))
                }
            }
        }
        context.restoreGState()
        
        context.setFillColor(greyColor.cgColor)
        
        let buttonRect = bounds.insetBy(dx: (bounds.width - 144.0) / 2.0, dy: (bounds.height - 144.0) / 2.0)
        context.fillEllipse(in: buttonRect)

        var drawGradient = false
        let lineWidth = 3.0 + UIScreenPixel
        if parameters.state is VoiceChatActionButtonBackgroundNodeConnectingState || parameters.transition?.previousState == .connecting {
            var globalAngle: CGFloat = CGFloat(parameters.timestamp.truncatingRemainder(dividingBy: Double.pi * 2.0))
            globalAngle *= 4.0
            globalAngle = CGFloat(globalAngle.truncatingRemainder(dividingBy: CGFloat.pi * 2.0))
            
            var timestamp = parameters.timestamp
            if let transition = parameters.transition {
                timestamp = transition.startTime
            }
            
            var skip = false
            var progress = CGFloat(1.0 + timestamp.remainder(dividingBy: 2.0))
            if let transition = parameters.transition {
                var transitionProgress = transition.transition
                if parameters.state is VoiceChatActionButtonBackgroundNodeBlobState {
                    transitionProgress = min(1.0, transitionProgress / 0.5)
                    progress = progress + (2.0 - progress) * transitionProgress
                    if transitionProgress >= 1.0 {
                        skip = true
                    }
                } else if parameters.state is VoiceChatActionButtonBackgroundNodeDisabledState {
                    progress = progress + (1.0 - progress) * transition.transition
                    if transitionProgress >= 1.0 {
                        skip = true
                    }
                }
            }
            
            if !skip {
                var startAngle = -CGFloat.pi / 2.0 + globalAngle
                var endAngle = CGFloat(progress) * 2.0 * CGFloat.pi + startAngle
                if progress > 1.0 {
                    let tmp = startAngle
                    startAngle = endAngle
                    endAngle = 2.0 * CGFloat.pi + tmp
                }
                
                let path = CGMutablePath()
                path.addArc(center: CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0), radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)

                let filledPath = path.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .miter, miterLimit: 10)
                context.addPath(filledPath)
                context.clip()
                
                drawGradient = true
            }
        }
        
        var clearInsideTransition: CGFloat?
        if parameters.state is VoiceChatActionButtonBackgroundNodeBlobState {
            let path = CGMutablePath()
            path.addEllipse(in: buttonRect.insetBy(dx: -lineWidth / 2.0, dy: -lineWidth / 2.0))
            context.addPath(path)
            context.clip()
            if let transition = parameters.transition {
                if transition.previousState == .connecting, transition.transition > 0.5  {
                    clearInsideTransition = (transition.transition - 0.5) / 0.5
                } else if transition.previousState == .disabled {
                    clearInsideTransition = transition.transition
                }
            }
            
            drawGradient = true
        }
        
        if drawGradient {
            if parameters.simplified {
                context.setFillColor(simpleColor.cgColor)
                context.fill(bounds)
            } else if let gradient = gradientImage?.cgImage {
                context.draw(gradient, in: CGRect(origin: CGPoint(x: gradientCenter.x - gradientSize / 2.0, y: gradientCenter.y - gradientSize / 2.0), size: CGSize(width: gradientSize, height: gradientSize)))
            }
        }
        
        if let transition = clearInsideTransition {
            context.setFillColor(greyColor.cgColor)
            context.fillEllipse(in: buttonRect.insetBy(dx: transition * radius, dy: transition * radius))
        }
    }
}

final class VoiceChatActionButton: HighlightTrackingButtonNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: VoiceChatActionButtonBackgroundNode
    let iconNode: VoiceChatMicrophoneNode
    let titleLabel: ImmediateTextNode
    let subtitleLabel: ImmediateTextNode
    
    let blueGradient: UIImage
    let greenGradient: UIImage
    
    private var currentParams: (size: CGSize, buttonSize: CGSize, state: VoiceChatActionButtonState, title: String, subtitle: String)?
    
    var pressing: Bool = false {
        didSet {
            if self.pressing {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                transition.updateTransformScale(node: self.containerNode, scale: 0.9)
            } else {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                transition.updateTransformScale(node: self.containerNode, scale: 1.0)
            }
        }
    }
        
    init() {
        self.containerNode = ASDisplayNode()
        self.backgroundNode = VoiceChatActionButtonBackgroundNode()
        self.iconNode = VoiceChatMicrophoneNode()
        
        self.titleLabel = ImmediateTextNode()
        self.subtitleLabel = ImmediateTextNode()
        
        self.blueGradient = generateImage(CGSize(width: 180.0, height: 180.0), contextGenerator: { size, context in
            let firstColor = lightBlue
            let secondColor = blue

            var locations: [CGFloat] = [0.0, 1.0]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            let gradientCenter = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let gradientStartRadius: CGFloat = 0.0
            let gradientEndRadius: CGFloat = 85.0
            
            let colors: [CGColor] = [firstColor.cgColor, secondColor.cgColor]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            context.drawRadialGradient(gradient, startCenter: gradientCenter, startRadius: gradientStartRadius, endCenter: gradientCenter, endRadius: gradientEndRadius, options: .drawsAfterEndLocation)
        }, opaque: true, scale: min(2.0, deviceScale))!
        
        self.greenGradient = generateImage(CGSize(width: 180.0, height: 180.0), contextGenerator: { size, context in
            let firstColor = blue
            let secondColor = green

            var locations: [CGFloat] = [0.0, 1.0]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            let gradientCenter = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let gradientStartRadius: CGFloat = 0.0
            let gradientEndRadius: CGFloat = 85.0
            
            let colors: [CGColor] = [firstColor.cgColor, secondColor.cgColor]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            context.drawRadialGradient(gradient, startCenter: gradientCenter, startRadius: gradientStartRadius, endCenter: gradientCenter, endRadius: gradientEndRadius, options: .drawsAfterEndLocation)
        }, opaque: true, scale: min(2.0, deviceScale))!
        
        super.init()
    
        self.addSubnode(self.titleLabel)
        self.addSubnode(self.subtitleLabel)

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.iconNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.containerNode, scale: 0.9)
                } else if !strongSelf.pressing {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.containerNode, scale: 1.0)
                }
            }
        }
    }
    
    func updateLevel(_ level: CGFloat) {
        let maxLevel: CGFloat = 6.0
        let normalizedLevel = min(1, max(level / maxLevel, 0))

        self.backgroundNode.audioLevel = normalizedLevel
    }
    
    func update(size: CGSize, buttonSize: CGSize, state: VoiceChatActionButtonState, title: String, subtitle: String, simplified: Bool, animated: Bool = false) {
        let updatedTitle = self.currentParams?.title != title
        let updatedSubtitle = self.currentParams?.subtitle != subtitle

        self.currentParams = (size, buttonSize, state, title, subtitle)

        self.titleLabel.attributedText = NSAttributedString(string: title, font: titleFont, textColor: .white)
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, font: subtitleFont, textColor: .white)

        let blobSize: CGSize = CGSize(width: 244.0, height: 244.0)
        
        var iconMuted = true
        var iconColor: UIColor = .white
        var backgroundState: VoiceChatActionButtonBackgroundNodeContext
        switch state {
            case let .active(state):
                switch state {
                    case .on:
                        iconMuted = false
                        backgroundState = VoiceChatActionButtonBackgroundNodeBlobContext(size: blobSize, active: true, blueGradient: self.blueGradient, greenGradient: self.greenGradient)
                    case .muted:
                        backgroundState = VoiceChatActionButtonBackgroundNodeBlobContext(size: blobSize, active: false, blueGradient: self.blueGradient, greenGradient: self.greenGradient)
                    case .cantSpeak:
                        iconColor = UIColor(rgb: 0xff3b30)
                        backgroundState = VoiceChatActionButtonBackgroundNodeDisabledContext()
                }
            case .connecting:
                backgroundState = VoiceChatActionButtonBackgroundNodeConnectingContext(blueGradient: self.blueGradient)
        }
        self.backgroundNode.update(state: backgroundState, simplified: simplified, animated: true)

        if animated {
            if let snapshotView = self.titleLabel.view.snapshotContentTree(), updatedTitle {
                self.titleLabel.view.superview?.insertSubview(snapshotView, belowSubview: self.titleLabel.view)
                snapshotView.frame = self.titleLabel.frame
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.titleLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            if let snapshotView = self.subtitleLabel.view.snapshotContentTree(), updatedSubtitle {
                self.subtitleLabel.view.superview?.insertSubview(snapshotView, belowSubview: self.subtitleLabel.view)
                snapshotView.frame = self.subtitleLabel.frame
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.subtitleLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
        }

        let titleSize = self.titleLabel.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleLabel.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        let totalHeight = titleSize.height + subtitleSize.height + 1.0

        self.titleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor(size.height + 16.0 - totalHeight / 2.0) - 56.0), size: titleSize)
        self.subtitleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: self.titleLabel.frame.maxY + 1.0), size: subtitleSize)

        self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
        
        self.backgroundNode.bounds = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        if simplified {
            self.backgroundNode.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
        } else {
            self.backgroundNode.transform = CATransform3DIdentity
        }
        
        let iconSize = CGSize(width: 90.0, height: 90.0)
        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)

        self.iconNode.update(state: VoiceChatMicrophoneNode.State(muted: iconMuted, color: iconColor), animated: true)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var hitRect = self.bounds
        if let (_, buttonSize, _, _, _) = self.currentParams {
            hitRect = self.bounds.insetBy(dx: (self.bounds.width - buttonSize.width) / 2.0, dy: (self.bounds.height - buttonSize.height) / 2.0)
        }
        let result = super.hitTest(point, with: event)
        if !hitRect.contains(point) {
            return nil
        }
        return result
    }
}

extension UIBezierPath {
    static func smoothCurve(through points: [CGPoint], length: CGFloat, smoothness: CGFloat, curve: Bool = false) -> UIBezierPath {
        var smoothPoints = [SmoothPoint]()
        for index in (0 ..< points.count) {
            let prevIndex = index - 1
            let prev = points[prevIndex >= 0 ? prevIndex : points.count + prevIndex]
            let curr = points[index]
            let next = points[(index + 1) % points.count]

            let angle: CGFloat = {
                let dx = next.x - prev.x
                let dy = -next.y + prev.y
                let angle = atan2(dy, dx)
                if angle < 0 {
                    return abs(angle)
                } else {
                    return 2 * .pi - angle
                }
            }()

            smoothPoints.append(
                SmoothPoint(
                    point: curr,
                    inAngle: angle + .pi,
                    inLength: smoothness * distance(from: curr, to: prev),
                    outAngle: angle,
                    outLength: smoothness * distance(from: curr, to: next)
                )
            )
        }

        let resultPath = UIBezierPath()
        if curve {
            resultPath.move(to: CGPoint())
            resultPath.addLine(to: smoothPoints[0].point)
        } else {
            resultPath.move(to: smoothPoints[0].point)
        }

        let smoothCount = curve ? smoothPoints.count - 1 : smoothPoints.count
        for index in (0 ..< smoothCount) {
            let curr = smoothPoints[index]
            let next = smoothPoints[(index + 1) % points.count]
            let currSmoothOut = curr.smoothOut()
            let nextSmoothIn = next.smoothIn()
            resultPath.addCurve(to: next.point, controlPoint1: currSmoothOut, controlPoint2: nextSmoothIn)
        }
        if curve {
            resultPath.addLine(to: CGPoint(x: length, y: 0.0))
        }
        resultPath.close()
        return resultPath
    }

    static private func distance(from fromPoint: CGPoint, to toPoint: CGPoint) -> CGFloat {
        return sqrt((fromPoint.x - toPoint.x) * (fromPoint.x - toPoint.x) + (fromPoint.y - toPoint.y) * (fromPoint.y - toPoint.y))
    }

    struct SmoothPoint {
        let point: CGPoint

        let inAngle: CGFloat
        let inLength: CGFloat

        let outAngle: CGFloat
        let outLength: CGFloat

        func smoothIn() -> CGPoint {
            return smooth(angle: inAngle, length: inLength)
        }

        func smoothOut() -> CGPoint {
            return smooth(angle: outAngle, length: outLength)
        }

        private func smooth(angle: CGFloat, length: CGFloat) -> CGPoint {
            return CGPoint(
                x: point.x + length * cos(angle),
                y: point.y + length * sin(angle)
            )
        }
    }
}
