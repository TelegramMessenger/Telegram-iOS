import Foundation
import UIKit
import AsyncDisplayKit
import Display

private let titleFont = Font.regular(17.0)
private let subtitleFont = Font.regular(13.0)

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

private protocol VoiceChatActionButtonBackgroundNodeState: NSObjectProtocol {
    var isAnimating: Bool { get }
    var type: VoiceChatActionButtonBackgroundNodeType { get }
    func updateAnimations()
}

private final class VoiceChatActionButtonBackgroundNodeConnectingState: NSObject, VoiceChatActionButtonBackgroundNodeState {
    var isAnimating: Bool {
        return true
    }
    
    var type: VoiceChatActionButtonBackgroundNodeType {
        return .connecting
    }
    
    func updateAnimations() {
    }
}

private final class VoiceChatActionButtonBackgroundNodeDisabledState: NSObject, VoiceChatActionButtonBackgroundNodeState {
    var isAnimating: Bool {
        return false
    }
    
    var type: VoiceChatActionButtonBackgroundNodeType {
        return .disabled
    }
    
    func updateAnimations() {
    }
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
    let scaleSpeed: CGFloat
    
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
    
    var loop: Bool = false {
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
        maxScale: CGFloat,
        scaleSpeed: CGFloat
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
        self.scaleSpeed = scaleSpeed

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
        var animate = false
        let timestamp = CACurrentMediaTime()

//        if let (startTime, duration) = self.gradientTransitionArguments, duration > 0.0 {
//            if let fromLoop = self.fromLoop {
//                if fromLoop {
//                    self.gradientTransition = max(0.0, min(1.0, CGFloat((timestamp - startTime) / duration)))
//                } else {
//                    self.gradientTransition = max(0.0, min(1.0, 1.0 - CGFloat((timestamp - startTime) / duration)))
//                }
//            }
//            if self.gradientTransition < 1.0 {
//                animate = true
//            } else {
//                self.gradientTransitionArguments = nil
//            }
//        }

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

//        let gradientMovementStartTime: Double
//        let gradientMovementDuration: Double
//        let gradientMovementReverse: Bool
//        if let (startTime, duration, reverse) = self.gradientMovementTransitionArguments, duration > 0.0 {
//            gradientMovementStartTime = startTime
//            gradientMovementDuration = duration
//            gradientMovementReverse = reverse
//        } else {
//            gradientMovementStartTime = CACurrentMediaTime()
//            gradientMovementDuration = 1.0
//            gradientMovementReverse = false
//            self.gradientMovementTransitionArguments = (gradientMovementStartTime, gradientMovementStartTime, gradientMovementReverse)
//        }
//        let movementT = CGFloat((timestamp - gradientMovementStartTime) / gradientMovementDuration)
//        self.gradientMovementTransition = gradientMovementReverse ? 1.0 - movementT : movementT
//        if gradientMovementReverse && self.gradientMovementTransition <= 0.0 {
//            self.gradientMovementTransitionArguments = (CACurrentMediaTime(), 1.0, false)
//        } else if !gradientMovementReverse && self.gradientMovementTransition >= 1.0 {
//            self.gradientMovementTransitionArguments = (CACurrentMediaTime(), 1.0, true)
//        }
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

private final class VoiceChatActionButtonBackgroundNodeBlobState: NSObject, VoiceChatActionButtonBackgroundNodeState {
    var isAnimating: Bool {
        return true
    }
    
    var type: VoiceChatActionButtonBackgroundNodeType {
        return .blob
    }
    
    typealias BlobRange = (min: CGFloat, max: CGFloat)
    let blobs: [Blob]
    
    var active: Bool
    var activeTransitionArguments: (startTime: Double, duration: Double)?
    
    init(size: CGSize, active: Bool) {
        self.active = active
        
        let mediumBlobRange: BlobRange = (0.69, 0.87)
        let bigBlobRange: BlobRange = (0.71, 1.00)
        
        let mediumBlob = Blob(size: size, alpha: 0.55, pointsCount: 8, minRandomness: 1, maxRandomness: 1, minSpeed: 1.5, maxSpeed: 7, minScale: mediumBlobRange.min, maxScale: mediumBlobRange.max, scaleSpeed: 0.2)
        let largeBlob = Blob(size: size, alpha: 0.35, pointsCount: 8, minRandomness: 1, maxRandomness: 1, minSpeed: 1.5, maxSpeed: 7, minScale: bigBlobRange.min, maxScale: bigBlobRange.max, scaleSpeed: 0.2)
 
        self.blobs = [largeBlob, mediumBlob]
    }
        
    func update(with state: VoiceChatActionButtonBackgroundNodeBlobState) {
        if self.active != state.active {
            self.active = state.active
            
            self.activeTransitionArguments = (CACurrentMediaTime(), 0.3)
        }
    }
    
    func updateAnimations() {
        for blob in self.blobs {
            blob.updateAnimations()
        }
    }
}

private final class VoiceChatActionButtonBackgroundNodeTransition {
    let startTime: Double
    let duration: Double
    let previousState: VoiceChatActionButtonBackgroundNodeState?
    
    init(startTime: Double, duration: Double, previousState: VoiceChatActionButtonBackgroundNodeState?) {
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
}

private class VoiceChatActionButtonBackgroundNodeDrawingState: NSObject {
    let timestamp: Double
    let state: VoiceChatActionButtonBackgroundNodeState
    let transition: VoiceChatActionButtonBackgroundNodeTransition?
    
    init(timestamp: Double, state: VoiceChatActionButtonBackgroundNodeState, transition: VoiceChatActionButtonBackgroundNodeTransition?) {
        self.timestamp = timestamp
        self.state = state
        self.transition = transition
    }
}

private class VoiceChatActionButtonBackgroundNode: ASDisplayNode {
    private var state: VoiceChatActionButtonBackgroundNodeState
    private var hasState = false
    private var transition: VoiceChatActionButtonBackgroundNodeTransition?
    
    var audioLevel: CGFloat = 0.0  {
        didSet {
            if let blobsState = self.state as? VoiceChatActionButtonBackgroundNodeBlobState {
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
        self.state = VoiceChatActionButtonBackgroundNodeConnectingState()
        
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = true
    }
    
    func update(state: VoiceChatActionButtonBackgroundNodeState, animated: Bool) {
        var animated = animated
        if !self.hasState {
            self.hasState = true
            animated = false
        }
        
        if state.type != self.state.type {
            if animated {
                self.transition = VoiceChatActionButtonBackgroundNodeTransition(startTime: CACurrentMediaTime(), duration: 0.3, previousState: self.state)
            }
            self.state = state
        } else if let blobState = self.state as? VoiceChatActionButtonBackgroundNodeBlobState, let nextState = state as? VoiceChatActionButtonBackgroundNodeBlobState {
            blobState.update(with: nextState)
        }
        
        self.updateAnimations()
    }
    
    private func updateAnimations() {
        var animate = false
        let timestamp = CACurrentMediaTime()
        
        self.presentationAudioLevel = self.presentationAudioLevel * 0.9 + max(0.1, self.audioLevel) * 0.1
        if let blobsState = self.state as? VoiceChatActionButtonBackgroundNodeBlobState {
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
        
        if self.state.isAnimating {
            animate = true
            self.state.updateAnimations()
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
            self.animator?.isPaused = true
        }
        
        self.setNeedsDisplay()
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return VoiceChatActionButtonBackgroundNodeDrawingState(timestamp: CACurrentMediaTime(), state: self.state, transition: self.transition)
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
        
        let blue = UIColor(rgb: 0x0078ff)
        let lightBlue = UIColor(rgb: 0x59c7f8)
        let green = UIColor(rgb: 0x33c659)

        var firstColor = lightBlue
        var secondColor = blue

        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var gradientCenter = CGPoint(x: bounds.size.width - 30.0, y: 50.0)
        let gradientStartRadius: CGFloat = 0.0
        let gradientEndRadius: CGFloat = 260.0
        
        if let blobsState = parameters.state as? VoiceChatActionButtonBackgroundNodeBlobState {
            var gradientTransition: CGFloat = blobsState.active ? 1.0 : 0.0
            if let transition = blobsState.activeTransitionArguments {
                gradientTransition = CGFloat((parameters.timestamp - transition.startTime) / transition.duration)
                if !blobsState.active {
                    gradientTransition = 1.0 - gradientTransition
                }
            }
            
            firstColor = firstColor.interpolateTo(blue, fraction: gradientTransition)!
            secondColor = secondColor.interpolateTo(green, fraction: gradientTransition)!
            
            let maskGradientStartRadius: CGFloat = 0.0
            var maskGradientEndRadius: CGFloat = bounds.size.width / 2.0
            if let transition = parameters.transition, transition.previousState is VoiceChatActionButtonBackgroundNodeConnectingState {
                maskGradientEndRadius *= transition.progress(time: parameters.timestamp)
            }

            let maskGradientCenter = CGPoint(x: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
            let colors: [CGColor] = [secondColor.withAlphaComponent(0.5).cgColor, secondColor.withAlphaComponent(0.0).cgColor]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            context.drawRadialGradient(gradient, startCenter: maskGradientCenter, startRadius: maskGradientStartRadius, endCenter: maskGradientCenter, endRadius: maskGradientEndRadius, options: .drawsAfterEndLocation)
            
//            context.setBlendMode(.clear)
//
//
//            let maskColors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff, alpha: 1.0).cgColor]
//            let maskGradient = CGGradient(colorsSpace: colorSpace, colors: maskColors as CFArray, locations: &locations)!
//
//            let maskGradientStartRadius: CGFloat = 0.0
//            let maskGradientEndRadius: CGFloat = bounds.size.width / 2.0
////            context.drawRadialGradient(maskGradient, startCenter: maskGradientCenter, startRadius: maskGradientStartRadius, endCenter: maskGradientCenter, endRadius: maskGradientEndRadius, options: .drawsAfterEndLocation)
//
//            context.setBlendMode(.normal)
        }
        
        
        let colors: [CGColor] = [firstColor.cgColor, secondColor.cgColor]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
//        center.x -= parameters.gradientMovement * 60.0
//        center.y += parameters.gradientMovement * 200.0

        
        context.saveGState()
        if let blobsState = parameters.state as? VoiceChatActionButtonBackgroundNodeBlobState {
            for blob in blobsState.blobs {
                if let path = blob.currentShape, let uiPath = path.copy() as? UIBezierPath {
                    let toOrigin = CGAffineTransform(translationX: -bounds.size.width / 2.0, y: -bounds.size.height / 2.0)
                    let fromOrigin = CGAffineTransform(translationX: bounds.size.width / 2.0, y: bounds.size.height / 2.0)
      
                    uiPath.apply(toOrigin)
                    uiPath.apply(CGAffineTransform(scaleX: blob.currentScale, y: blob.currentScale))
                    uiPath.apply(fromOrigin)
      
                    context.addPath(uiPath.cgPath)
                    context.clip()
                    
                    context.setAlpha(blob.alpha)
                    
                    context.drawRadialGradient(gradient, startCenter: gradientCenter, startRadius: gradientStartRadius, endCenter: gradientCenter, endRadius: gradientEndRadius, options: .drawsAfterEndLocation)
                }
            }
        }
        context.restoreGState()
        
        context.setFillColor(greyColor.cgColor)
        
        let buttonRect = bounds.insetBy(dx: (bounds.width - 144.0) / 2.0, dy: (bounds.height - 144.0) / 2.0)
        context.fillEllipse(in: buttonRect)

        var drawGradient = false
        let lineWidth = 3.0 + UIScreenPixel
        if parameters.state is VoiceChatActionButtonBackgroundNodeConnectingState || parameters.transition?.previousState is VoiceChatActionButtonBackgroundNodeConnectingState {
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
                var transitionProgress = transition.progress(time: parameters.timestamp)
                if parameters.state is VoiceChatActionButtonBackgroundNodeBlobState {
                    transitionProgress = min(1.0, transitionProgress / 0.5)
                    progress = progress + (2.0 - progress) * transitionProgress
                    if transitionProgress >= 1.0 {
                        skip = true
                    }
                } else if parameters.state is VoiceChatActionButtonBackgroundNodeDisabledState {
                    progress = progress + (1.0 - progress) * transition.progress(time: parameters.timestamp)
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
        
        var clearInside: CGFloat?
        if parameters.state is VoiceChatActionButtonBackgroundNodeBlobState {
            let path = CGMutablePath()
            path.addEllipse(in: buttonRect.insetBy(dx: -lineWidth / 2.0, dy: -lineWidth / 2.0))
            context.addPath(path)
            context.clip()
            if let transition = parameters.transition, transition.previousState is VoiceChatActionButtonBackgroundNodeConnectingState || transition.previousState is VoiceChatActionButtonBackgroundNodeDisabledState, transition.progress(time: parameters.timestamp) > 0.5 {
                let progress = (transition.progress(time: parameters.timestamp) - 0.5) / 0.5
                clearInside = progress
            }
            
            drawGradient = true
        }
        
        if drawGradient {
            context.drawRadialGradient(gradient, startCenter: gradientCenter, startRadius: gradientStartRadius, endCenter: gradientCenter, endRadius: gradientEndRadius, options: .drawsAfterEndLocation)
        }
        
        if let clearInside = clearInside {
            context.setFillColor(greyColor.cgColor)
            context.fillEllipse(in: buttonRect.insetBy(dx: clearInside * radius, dy: clearInside * radius))
        }
    }
}

final class VoiceChatActionButton: HighlightTrackingButtonNode {
    private let containerNode: ASDisplayNode
    private let backgroundNode: VoiceChatActionButtonBackgroundNode
    let iconNode: VoiceChatMicrophoneNode
    let titleLabel: ImmediateTextNode
    let subtitleLabel: ImmediateTextNode
    
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
        let maxLevel: CGFloat = 1.0
        let normalizedLevel = min(1, max(level / maxLevel, 0))

        self.backgroundNode.audioLevel = normalizedLevel
    }
    
    func update(size: CGSize, buttonSize: CGSize, state: VoiceChatActionButtonState, title: String, subtitle: String, animated: Bool = false) {
        let updatedTitle = self.currentParams?.title != title
        let updatedSubtitle = self.currentParams?.subtitle != subtitle

        self.currentParams = (size, buttonSize, state, title, subtitle)

        self.titleLabel.attributedText = NSAttributedString(string: title, font: titleFont, textColor: .white)
        self.subtitleLabel.attributedText = NSAttributedString(string: subtitle, font: subtitleFont, textColor: .white)

        var iconMuted = true
        var iconColor: UIColor = .white
        var backgroundState: VoiceChatActionButtonBackgroundNodeState
        switch state {
            case let .active(state):
                switch state {
                    case .on:
                        iconMuted = false
                        backgroundState = VoiceChatActionButtonBackgroundNodeBlobState(size: size, active: true)
                    case .muted:
                        backgroundState = VoiceChatActionButtonBackgroundNodeBlobState(size: size, active: false)
                    case .cantSpeak:
                        iconColor = UIColor(rgb: 0xff3b30)
                        backgroundState = VoiceChatActionButtonBackgroundNodeDisabledState()
                    default:
                        break
                }
            case .connecting:
                backgroundState = VoiceChatActionButtonBackgroundNodeConnectingState()
        }
        self.backgroundNode.update(state: backgroundState, animated: true)

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

        self.titleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor(size.height + 16.0 - totalHeight / 2.0) - 20.0), size: titleSize)
        self.subtitleLabel.frame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: self.titleLabel.frame.maxY + 1.0), size: subtitleSize)

        self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
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
