import Foundation
import UIKit
import AsyncDisplayKit
import Display

private extension UIBezierPath {
    static func smoothCurve(through points: [CGPoint], length: CGFloat, smoothness: CGFloat) -> UIBezierPath {
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
        resultPath.move(to: smoothPoints[0].point)
        for index in (0 ..< smoothPoints.count) {
            let curr = smoothPoints[index]
            let next = smoothPoints[(index + 1) % points.count]
            let currSmoothOut = curr.smoothOut()
            let nextSmoothIn = next.smoothIn()
            resultPath.addCurve(to: next.point, controlPoint1: currSmoothOut, controlPoint2: nextSmoothIn)
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

private final class BlobNodeDrawingState: NSObject {
    let scale: CGFloat
    let shape: CGPath?
    let gradientTransition: CGFloat
    let gradientMovement: CGFloat
   
    init(scale: CGFloat, shape: CGPath?, gradientTransition: CGFloat, gradientMovement: CGFloat) {
        self.scale = scale
        self.shape = shape
        self.gradientTransition = gradientTransition
        self.gradientMovement = gradientMovement
        
        super.init()
    }
}

private class BlobNode: ASDisplayNode {
    let size: CGSize
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    var minScale: CGFloat
    var maxScale: CGFloat
    let scaleSpeed: CGFloat
    
    let isCircle: Bool
    
    var currentScale: CGFloat = 1.0

    var level: CGFloat = 0.0 {
        didSet {
            var effectiveMaxScale = maxScale
            var effectiveMinScale = minScale
            if !self.loop {
                effectiveMaxScale *= self.isCircle ? 0.97 : 1.1
                effectiveMinScale *= self.isCircle ? 0.97 : 1.1
            }
            
            self.currentScale = effectiveMinScale + (effectiveMaxScale - effectiveMinScale) * self.level
        }
    }
    
    private var speedLevel: CGFloat = 0.0    
    private var lastSpeedLevel: CGFloat = 0.0
        
    private var fromPoints: [CGPoint]?
    private var toPoints: [CGPoint]?
    
    var fromLoop: Bool?
    var loop = false {
        didSet {
            if self.loop != oldValue {
                self.fromLoop = oldValue
                gradientTransitionArguments = (CACurrentMediaTime(), 0.4)
            }
        }
    }
    
    private var currentPoints: [CGPoint]? {
        guard let fromPoints = fromPoints, let toPoints = toPoints else { return nil }
        
        return fromPoints.enumerated().map { offset, fromPoint in
            let toPoint = toPoints[offset]
            return CGPoint(x: fromPoint.x + (toPoint.x - fromPoint.x) * transition, y: fromPoint.y + (toPoint.y - fromPoint.y) * transition)
        }
    }
    
    private var currentShape: CGPath?
    private var transition: CGFloat = 0 {
        didSet {
            if let currentPoints = self.currentPoints {
                self.currentShape = UIBezierPath.smoothCurve(through: currentPoints, length: bounds.width, smoothness: smoothness).cgPath
            }
        }
    }
    
    private var gradientTransition: CGFloat = 0.0
    private var gradientTransitionArguments: (startTime: Double, duration: Double)?
    
    private var gradientMovementTransition: CGFloat = 0.0
    private var gradientMovementTransitionArguments: (startTime: Double, duration: Double, reverse: Bool)?
    
    private var animator: ConstantDisplayLinkAnimator?
    private var transitionArguments: (startTime: Double, duration: Double)?
    
    init(
        size: CGSize,
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minScale: CGFloat,
        maxScale: CGFloat,
        scaleSpeed: CGFloat,
        isCircle: Bool
    ) {
        self.size = size
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minScale = minScale
        self.maxScale = maxScale
        self.scaleSpeed = scaleSpeed
        self.isCircle = isCircle
        
        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
        
        self.currentScale = minScale
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)
        
        if abs(lastSpeedLevel - newSpeedLevel) > 0.3 {
            animateToNewShape()
        }
    }
    
    func startAnimating() {
        animateToNewShape()
    }
    
    func stopAnimating() {
        fromPoints = currentPoints
        toPoints = nil
        pop_removeAnimation(forKey: "blob")
    }
    
    private func updateAnimations() {
        var animate = false
        let timestamp = CACurrentMediaTime()
        
        if let (startTime, duration) = self.gradientTransitionArguments, duration > 0.0 {
            if let fromLoop = self.fromLoop {
                if fromLoop {
                    self.gradientTransition = max(0.0, min(1.0, CGFloat((timestamp - startTime) / duration)))
                } else {
                    self.gradientTransition = max(0.0, min(1.0, 1.0 - CGFloat((timestamp - startTime) / duration)))
                }
            }
            if self.gradientTransition < 1.0 {
                animate = true
            } else {
                self.gradientTransitionArguments = nil
            }
        }
        
        if let (startTime, duration) = self.transitionArguments, duration > 0.0 {
            self.transition = max(0.0, min(1.0, CGFloat((timestamp - startTime) / duration)))
            if self.transition < 1.0 {
                animate = true
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
        
        let gradientMovementStartTime: Double
        let gradientMovementDuration: Double
        let gradientMovementReverse: Bool
        if let (startTime, duration, reverse) = self.gradientMovementTransitionArguments, duration > 0.0 {
            gradientMovementStartTime = startTime
            gradientMovementDuration = duration
            gradientMovementReverse = reverse
        } else {
            gradientMovementStartTime = CACurrentMediaTime()
            gradientMovementDuration = 1.0
            gradientMovementReverse = false
            self.gradientMovementTransitionArguments = (gradientMovementStartTime, gradientMovementStartTime, gradientMovementReverse)
        }
        let movementT = CGFloat((timestamp - gradientMovementStartTime) / gradientMovementDuration)
        self.gradientMovementTransition = gradientMovementReverse ? 1.0 - movementT : movementT
        if gradientMovementReverse && self.gradientMovementTransition <= 0.0 {
            self.gradientMovementTransitionArguments = (CACurrentMediaTime(), 1.0, false)
        } else if !gradientMovementReverse && self.gradientMovementTransition >= 1.0 {
            self.gradientMovementTransitionArguments = (CACurrentMediaTime(), 1.0, true)
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
        } else {
//            self.animator?.isPaused = true
        }
        
        self.setNeedsDisplay()
    }
    
    private func animateToNewShape() {
        if let _ = self.transitionArguments {
            self.fromPoints = self.currentPoints
            self.toPoints = nil
            self.transition = 0.0
            self.transitionArguments = nil
        }

        if self.fromPoints == nil {
            self.fromPoints = generateNextBlob(for: self.bounds.size)
        }
        if self.toPoints == nil {
            self.toPoints = generateNextBlob(for: self.bounds.size)
        }
        
        let duration: Double = 1.0 / Double(minSpeed + (maxSpeed - minSpeed) * speedLevel)
        self.transitionArguments = (CACurrentMediaTime(), duration)
        
        self.lastSpeedLevel = self.speedLevel
        self.speedLevel = 0
        
        self.updateAnimations()
    }
    
    private func generateNextBlob(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return blob(pointsCount: pointsCount, randomness: randomness).map {
            return CGPoint(x: size.width / 2.0 + $0.x * CGFloat(size.width), y: size.height / 2.0 + $0.y * CGFloat(size.height))
        }
    }
    
    func blob(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
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
    
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
//        var transitionState: SemanticStatusNodeTransitionDrawingState?
//        var transitionFraction: CGFloat = 1.0
//        var appearanceBackgroundTransitionFraction: CGFloat = 1.0
//        var appearanceForegroundTransitionFraction: CGFloat = 1.0
//
//        if let transitionContext = self.transitionContext {
//            let timestamp = CACurrentMediaTime()
//            var t = CGFloat((timestamp - transitionContext.startTime) / transitionContext.duration)
//            t = min(1.0, max(0.0, t))
//
//            if let _ = transitionContext.previousStateContext {
//                transitionFraction = t
//            }
//            var foregroundTransitionFraction: CGFloat = 1.0
//            if let previousContext = transitionContext.previousAppearanceContext {
//                if previousContext.backgroundImage != self.appearanceContext.backgroundImage {
//                    appearanceBackgroundTransitionFraction = t
//                }
//                if previousContext.cutout != self.appearanceContext.cutout {
//                    appearanceForegroundTransitionFraction = t
//                    foregroundTransitionFraction = 1.0 - t
//                }
//            }
//            transitionState = SemanticStatusNodeTransitionDrawingState(transition: t, drawingState: transitionContext.previousStateContext?.drawingState(transitionFraction: 1.0 - t), appearanceState: transitionContext.previousAppearanceContext?.drawingState(backgroundTransitionFraction: 1.0, foregroundTransitionFraction: foregroundTransitionFraction))
//        }
        
        return BlobNodeDrawingState(scale: self.currentScale, shape: self.currentShape, gradientTransition: self.gradientTransition, gradientMovement: self.gradientMovementTransition)
    }
    
    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        guard let parameters = parameters as? BlobNodeDrawingState else {
            return
        }
    
        if let path = parameters.shape {
            var uiPath = UIBezierPath(cgPath: path)
            let toOrigin = CGAffineTransform(translationX: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
            let fromOrigin = CGAffineTransform(translationX: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
            
            uiPath.apply(toOrigin)
            uiPath.apply(CGAffineTransform(scaleX: parameters.scale, y: parameters.scale))
            uiPath.apply(fromOrigin)
            
            context.addPath(uiPath.cgPath)
            context.clip()
            
            let blue = UIColor(rgb: 0x0078ff)
            let lightBlue = UIColor(rgb: 0x59c7f8)
            let green = UIColor(rgb: 0x33c659)
            
            let firstColor = lightBlue.interpolateTo(blue, fraction: parameters.gradientTransition)!
            let secondColor = blue.interpolateTo(green, fraction: parameters.gradientTransition)!
            
            var locations: [CGFloat] = [0.0, 1.0]
            let colors: [CGColor] = [firstColor.cgColor, secondColor.cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            var center: CGPoint = CGPoint(x: bounds.size.width - 30.0, y: 50.0)
            center.x -= parameters.gradientMovement * 60.0
            center.y += parameters.gradientMovement * 200.0
            
            let startRadius: CGFloat = 0.0
            let endRadius: CGFloat = 260.0
            
            context.drawRadialGradient(gradient, startCenter: center, startRadius: startRadius, endCenter: center, endRadius: endRadius, options: .drawsAfterEndLocation)
        }
        
//        if let transitionAppearanceState = parameters.transitionState?.appearanceState {
//            transitionAppearanceState.drawBackground(context: context, size: bounds.size)
//        }
//        parameters.appearanceState.drawBackground(context: context, size: bounds.size)
//
//        if let transitionDrawingState = parameters.transitionState?.drawingState {
//            transitionDrawingState.draw(context: context, size: bounds.size, foregroundColor: parameters.appearanceState.effectiveForegroundColor)
//        }
//        parameters.drawingState.draw(context: context, size: bounds.size, foregroundColor: parameters.appearanceState.effectiveForegroundColor)
//
//        if let transitionAppearanceState = parameters.transitionState?.appearanceState {
//            transitionAppearanceState.drawForeground(context: context, size: bounds.size)
//        }
//        parameters.appearanceState.drawForeground(context: context, size: bounds.size)
    }
}

private let titleFont = Font.regular(17.0)
private let subtitleFont = Font.regular(13.0)

final class VoiceChatActionButton: HighlightTrackingButtonNode {
    enum State {
        enum ActiveState {
            case cantSpeak
            case muted
            case on
        }
        
        case connecting
        case active(state: ActiveState)
    }
    
//    private final class SemanticStatusNodeTransitionContext {
//        let startTime: Double
//        let duration: Double
//        let previousStateContext: SemanticStatusNodeStateContext?
//        let completion: () -> Void
//
//        init(startTime: Double, duration: Double, previousStateContext: SemanticStatusNodeStateContext?, previousAppearanceContext: SemanticStatusNodeAppearanceContext?, completion: @escaping () -> Void) {
//            self.startTime = startTime
//            self.duration = duration
//            self.previousStateContext = previousStateContext
//            self.previousAppearanceContext = previousAppearanceContext
//            self.completion = completion
//        }
//    }
    
    private let smallBlob: BlobNode
    private let mediumBlob: BlobNode
    private let bigBlob: BlobNode
    
    private let iconNode: ASImageNode
    
    private let maxLevel: CGFloat
    
    private let glowNode: ASImageNode
    
    let titleLabel: ImmediateTextNode
    let subtitleLabel: ImmediateTextNode
    
    private var currentParams: (size: CGSize, state: State, title: String, subtitle: String)?
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0.6
    private var presentationAudioLevel: CGFloat = 0
    
    typealias BlobRange = (min: CGFloat, max: CGFloat)
    
    var imitateVoice = false
    var previousImitateTimestamp: Double?
    
    init(size: CGSize) {
        let smallBlobRange: BlobRange = (0.6, 0.62)
        let mediumBlobRange: BlobRange = (0.62, 0.87)
        let bigBlobRange: BlobRange = (0.65, 1.00)
        
        self.maxLevel = 4.0
        
        self.glowNode = ASImageNode()
        self.glowNode.alpha = 0.5
        self.glowNode.image = generateImage(CGSize(width: 360.0, height: 360.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let blue = UIColor(rgb: 0x0078ff)
            
            var locations: [CGFloat] = [0.0, 0.4, 1.0]
            let colors: [CGColor] = [blue.cgColor, blue.cgColor, blue.withAlphaComponent(0.0).cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            let center: CGPoint = CGPoint(x: 180.0, y: 180.0)

            let startRadius: CGFloat = 0.0
            let endRadius: CGFloat = 200.0
            
            context.drawRadialGradient(gradient, startCenter: center, startRadius: startRadius, endCenter: center, endRadius: endRadius, options: .drawsAfterEndLocation)
        })
        self.glowNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 360.0, height: 360.0))
        
        self.iconNode = ASImageNode()
        
        
        self.titleLabel = ImmediateTextNode()
        self.subtitleLabel = ImmediateTextNode()
        
        self.smallBlob = BlobNode(
            size: size,
            pointsCount: 8,
            minRandomness: 0.1,
            maxRandomness: 0.1,
            minSpeed: 0.2,
            maxSpeed: 0.6,
            minScale: smallBlobRange.min,
            maxScale: smallBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: true
        )
        self.smallBlob.alpha = 1.0
        
        self.mediumBlob = BlobNode(
            size: size,
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.5,
            maxSpeed: 7,
            minScale: mediumBlobRange.min,
            maxScale: mediumBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )
        self.mediumBlob.alpha = 0.65
        
        self.bigBlob = BlobNode(
            size: size,
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1,
            minSpeed: 1.5,
            maxSpeed: 7,
            minScale: bigBlobRange.min,
            maxScale: bigBlobRange.max,
            scaleSpeed: 0.2,
            isCircle: false
        )
        self.bigBlob.alpha = 0.45
        
        super.init()
        
        self.addSubnode(self.glowNode)
        self.addSubnode(self.titleLabel)
        self.addSubnode(self.subtitleLabel)
        
        self.addSubnode(self.bigBlob)
        self.addSubnode(self.mediumBlob)
        self.addSubnode(self.smallBlob)
        
        self.iconNode.image = UIImage(bundleImageName: "Call/VoiceChatMicOff")
        self.addSubnode(self.iconNode)
        
        self.displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }
            
            if strongSelf.imitateVoice {
                let timestamp = CACurrentMediaTime()
                if let previousTimestamp = strongSelf.previousImitateTimestamp {
                    if timestamp - previousTimestamp > 0.05 {
                        strongSelf.previousImitateTimestamp = timestamp
                        strongSelf.updateLevel(CGFloat(Float.random(in: 0.3 ..< 4.0)))
                    }
                } else {
                    strongSelf.previousImitateTimestamp = timestamp
                }
            } else {
                strongSelf.previousImitateTimestamp = nil
                strongSelf.audioLevel = 0.6
            }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.smallBlob.level = strongSelf.presentationAudioLevel
            strongSelf.mediumBlob.level = strongSelf.presentationAudioLevel
            strongSelf.bigBlob.level = strongSelf.presentationAudioLevel
        }
    }
    
    private(set) var isAnimating = false
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        mediumBlob.layer.animateScale(from: 0.5, to: 1, duration: 0.15, removeOnCompletion: false)
        bigBlob.layer.animateScale(from: 0.5, to: 1, duration: 0.15, removeOnCompletion: false)
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = false
    }
    
    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        
        mediumBlob.layer.animateScale(from: 1.0, to: 0.5, duration: 0.15, removeOnCompletion: false)
        bigBlob.layer.animateScale(from: 1.0, to: 0.5, duration: 0.15, removeOnCompletion: false)
        
        updateBlobsState()
        
        displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        if self.isAnimating {
            if smallBlob.frame.size != .zero {
                smallBlob.startAnimating()
                mediumBlob.startAnimating()
                bigBlob.startAnimating()
            }
        } else {
            smallBlob.stopAnimating()
            mediumBlob.stopAnimating()
            bigBlob.stopAnimating()
        }
    }
    
    func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        smallBlob.updateSpeedLevel(to: normalizedLevel)
        mediumBlob.updateSpeedLevel(to: normalizedLevel)
        bigBlob.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
    }
    
    func update(size: CGSize, state: State, title: String, subtitle: String, animated: Bool = false) {
        let updatedTitle = self.currentParams?.title != title
        let updatedSubtitle = self.currentParams?.subtitle != subtitle

        self.currentParams = (size, state, title, subtitle)
        
        self.smallBlob.frame = CGRect(origin: CGPoint(), size: size)
        self.mediumBlob.frame = CGRect(origin: CGPoint(), size: size)
        self.bigBlob.frame = CGRect(origin: CGPoint(), size: size)
        self.updateBlobsState()
        
        self.titleLabel.attributedText = NSAttributedString(string: title, font: titleFont, textColor: .white)
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, font: subtitleFont, textColor: .white)
        
        if case let .active(state) = state {
            if state == .muted {
                self.smallBlob.loop = true
                self.mediumBlob.loop = true
                self.bigBlob.loop = true
                self.imitateVoice = false
            } else {
                self.smallBlob.loop = false
                self.mediumBlob.loop = false
                self.bigBlob.loop = false
                self.imitateVoice = true
            }
        }
        
        if animated {
            if let snapshotView = self.titleLabel.view.snapshotContentTree(), updatedTitle {
                self.titleLabel.view.insertSubview(snapshotView, belowSubview: self.titleLabel.view)
                snapshotView.frame = self.titleLabel.frame
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.titleLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            if let snapshotView = self.subtitleLabel.view.snapshotContentTree(), updatedSubtitle {
                self.subtitleLabel.view.insertSubview(snapshotView, belowSubview: self.subtitleLabel.view)
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
        
        self.titleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor(size.height + 16.0 - totalHeight / 2.0) - 20.0), size: titleSize)
        self.subtitleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: self.titleLabel.frame.maxY + 1.0), size: subtitleSize)
        
        self.glowNode.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
    }
    
//    func updateLayout(size: CGSize, isOn: Bool) {
//        if self.validSize != size {
//            self.validSize = size
//
//            self.backgroundNode.image = generateFilledCircleImage(diameter: size.width, color: UIColor(rgb: 0x1C1C1E))
//        }
//        if self.isOn != isOn {
//            self.isOn = isOn
//            self.foregroundNode.image = UIImage(bundleImageName: isOn ? "Call/VoiceChatMicOn" : "Call/VoiceChatMicOff")
//        }
//        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
//
//        if let image = self.foregroundNode.image {
//            self.foregroundNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
//        }
//    }
}
