import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext

private class CallStatusBarBackgroundNodeDrawingState: NSObject {
    let timestamp: Double
    let amplitude: CGFloat
    let phase: CGFloat
    let speaking: Bool
    let gradientTransition: CGFloat
    let gradientMovement: CGFloat
    
    init(timestamp: Double, amplitude: CGFloat, phase: CGFloat, speaking: Bool, gradientTransition: CGFloat, gradientMovement: CGFloat) {
        self.timestamp = timestamp
        self.amplitude = amplitude
        self.phase = phase
        self.speaking = speaking
        self.gradientTransition = gradientTransition
        self.gradientMovement = gradientMovement
    }
}

private final class Curve {
    let pointsCount: Int
    let smoothness: CGFloat

    let minRandomness: CGFloat
    let maxRandomness: CGFloat

    let minSpeed: CGFloat
    let maxSpeed: CGFloat

    let size: CGSize
    var currentOffset: CGFloat = 1.0
    var minOffset: CGFloat = 0.0
    var maxOffset: CGFloat = 2.0
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
            self.currentOffset = self.minOffset + (self.maxOffset - self.minOffset) * self.level
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
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minOffset: CGFloat,
        maxOffset: CGFloat,
        scaleSpeed: CGFloat
    ) {
        self.size = size
//        self.alpha = alpha
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minOffset = minOffset
        self.maxOffset = maxOffset
        self.scaleSpeed = scaleSpeed

        let angle = (CGFloat.pi * 2) / CGFloat(pointsCount)
        self.smoothness = ((4 / 3) * tan(angle / 4)) / sin(angle / 2) / 2

        self.currentOffset = minOffset
        
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
            self.fromPoints = generateNextCurve(for: self.size)
        }
        if self.toPoints == nil {
            self.toPoints = generateNextCurve(for: self.size)
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
    }
    
    private func generateNextCurve(for size: CGSize) -> [CGPoint] {
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

private class CallStatusBarBackgroundNode: ASDisplayNode {
    var muted = true
    
    var audioLevel: Float = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    var phase: CGFloat = 0.0
    
    private var gradientMovementArguments: (from: CGFloat, to: CGFloat, startTime: Double, duration: Double)?
    private var gradientMovement: CGFloat = 0.0
    
    var transitionArguments: (startTime: Double, duration: Double)?
    var speaking = false {
        didSet {
            if self.speaking != oldValue {
                self.transitionArguments = (CACurrentMediaTime(), 0.3)
            }
        }
    }
    
    private var animator: ConstantDisplayLinkAnimator?
    
    override init() {
        super.init()
                
        self.isOpaque = false
        
        self.updateAnimations()
    }
    
    func updateAnimations() {
        self.presentationAudioLevel = self.presentationAudioLevel * 0.9 + max(0.1, CGFloat(self.audioLevel)) * 0.1
        
        if self.gradientMovementArguments == nil {
            self.gradientMovementArguments = (0.0, 0.7, CACurrentMediaTime(), 1.0)
        }
        
        let timestamp = CACurrentMediaTime()
        if let (from, to, startTime, duration) = self.gradientMovementArguments, duration > 0.0 {
            let progress = max(0.0, min(1.0, CGFloat((timestamp - startTime) / duration)))
            self.gradientMovement = from + (to - from) * progress
            if progress < 1.0 {
            } else {
                var nextTo: CGFloat
                if to > 0.5 {
                    nextTo = CGFloat.random(in: 0.0 ..< 0.3)
                } else {
                    if self.presentationAudioLevel > 0.3 {
                        nextTo = CGFloat.random(in: 0.75 ..< 1.0)
                    } else {
                        nextTo = CGFloat.random(in: 0.5 ..< 1.0)
                    }
                }
                self.gradientMovementArguments = (to, nextTo, timestamp, Double.random(in: 0.8 ..< 1.5))
            }
        }
        
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
        
        self.phase -= 0.05
        self.setNeedsDisplay()
    }
    
    override public func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        let timestamp = CACurrentMediaTime()
        
        var gradientTransition: CGFloat = 0.0
        gradientTransition = self.speaking ? 1.0 : 0.0
        if let transition = self.transitionArguments {
            gradientTransition = CGFloat((timestamp - transition.startTime) / transition.duration)
            if !self.speaking {
                gradientTransition = 1.0 - gradientTransition
            }
        }
        
        return CallStatusBarBackgroundNodeDrawingState(timestamp: timestamp, amplitude: self.presentationAudioLevel, phase: self.phase, speaking: self.speaking, gradientTransition: gradientTransition, gradientMovement: self.gradientMovement)
    }

    @objc override public class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }

        guard let parameters = parameters as? CallStatusBarBackgroundNodeDrawingState else {
            return
        }
        
        var locations: [CGFloat] = [0.0, 1.0]
        let leftColor = UIColor(rgb: 0x007fff).interpolateTo(UIColor(rgb: 0x2bb76b), fraction: parameters.gradientTransition)!
        let rightColor = UIColor(rgb: 0x00afff).interpolateTo(UIColor(rgb: 0x007fff), fraction: parameters.gradientTransition)!
        let colors: [CGColor] = [leftColor.cgColor, rightColor.cgColor]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
       
        let position: CGFloat = bounds.height - 6.0
        let maxAmplitude: CGFloat = 12.0
        
        let amplitude = max(0.35, parameters.amplitude)
        
        func drawWave(_ index: Int, maxAmplitude: CGFloat, normalizedAmplitude: CGFloat) {
            let path = UIBezierPath()
            let mid = bounds.width / 2.0
            
            var offset: CGFloat = 0.0
            if index > 0 {
                offset = 3.0 * parameters.amplitude * CGFloat(index)
            }
            
            let frequency: CGFloat = 3.5
            let density: CGFloat = 2.0
            for x in stride(from: 0.0, to: bounds.width + density, by: density) {
                let scaling = -pow(1 / mid * (x - mid), 2) + 1
                let y = scaling * maxAmplitude * normalizedAmplitude * sin(CGFloat(2 * Double.pi) * frequency * (x / bounds.width)  + parameters.phase) + position + offset
                if x == 0 {
                    path.move(to: CGPoint())
                }
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: bounds.width, y: 0.0))
            path.close()
            
            context.addPath(path.cgPath)
            context.clip()
        }
        
        for i in (0 ..< 3).reversed() {
            let progress = 1.0 - CGFloat(i) / 3.0
            var normalizedAmplitude = (1.5 * progress - 0.8) * amplitude
            if i == 1 {
                normalizedAmplitude *= -1.0
            }
        
            context.saveGState()
            drawWave(i, maxAmplitude: maxAmplitude, normalizedAmplitude: normalizedAmplitude)
            
            if i == 1 {
                context.setFillColor(UIColor(rgb: 0x007fff, alpha: 0.3).cgColor)
                context.fill(bounds)
            } else {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: bounds.width + parameters.gradientMovement * bounds.width, y: 0.0), options: CGGradientDrawingOptions())
            }
            context.restoreGState()
        }
    }
}

public class CallStatusBarNodeImpl: CallStatusBarNode {
    public enum Content {
        case call(SharedAccountContext, Account, PresentationCall)
        case groupCall(SharedAccountContext, Account, PresentationGroupCall)
    }
    
    private let backgroundNode: CallStatusBarBackgroundNode
    private let microphoneNode: VoiceChatMicrophoneNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private let audioLevelDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private var didSetupData = false
    
    private var currentSize: CGSize?
    private var currentContent: Content?
    
    private var strings: PresentationStrings?
    private var nameDisplayOrder: PresentationPersonNameOrder = .firstLast
    private var currentPeer: Peer?
    private var currentCallTimer: SwiftSignalKit.Timer?
    private var currentCallState: PresentationCallState?
    private var currentGroupCallState: PresentationGroupCallSummaryState?
    private var currentIsMuted = true
    
    public override init() {
        self.backgroundNode = CallStatusBarBackgroundNode()
        self.microphoneNode = VoiceChatMicrophoneNode()
        self.titleNode = ImmediateTextNode()
        self.subtitleNode = ImmediateTextNode()
        
        super.init()
                
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.microphoneNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    deinit {
        self.audioLevelDisposable.dispose()
        self.stateDisposable.dispose()
        self.currentCallTimer?.invalidate()
    }
    
    public func update(content: Content) {
        self.currentContent = content
        self.update()
    }
    
    public override func update(size: CGSize) {
        self.currentSize = size
        self.update()
    }
    
    private func update() {
        guard let size = self.currentSize, let content = self.currentContent else {
            return
        }
        
        if !self.didSetupData {
            switch content {
                case let .call(sharedContext, account, call):
                    let presentationData = sharedContext.currentPresentationData.with { $0 }
                    self.strings = presentationData.strings
                    self.nameDisplayOrder = presentationData.nameDisplayOrder
                    self.stateDisposable.set(
                        (combineLatest(
                            account.postbox.loadedPeerWithId(call.peerId),
                            call.state,
                            call.isMuted
                        )
                    |> deliverOnMainQueue).start(next: { [weak self] peer, state, isMuted in
                        if let strongSelf = self {
                            strongSelf.currentPeer = peer
                            strongSelf.currentCallState = state
                            strongSelf.currentIsMuted = isMuted
                            strongSelf.update()
                        }
                    }))
                case let .groupCall(sharedContext, account, call):
                    let presentationData = sharedContext.currentPresentationData.with { $0 }
                    self.strings = presentationData.strings
                    self.nameDisplayOrder = presentationData.nameDisplayOrder
                    self.stateDisposable.set(
                        (combineLatest(
                            account.postbox.loadedPeerWithId(call.peerId),
                            call.summaryState,
                            call.isMuted
                        )
                    |> deliverOnMainQueue).start(next: { [weak self] peer, state, isMuted in
                        if let strongSelf = self {
                            strongSelf.currentPeer = peer
                            strongSelf.currentGroupCallState = state
                            strongSelf.currentIsMuted = isMuted
                            strongSelf.update()
                        }
                    }))
                    self.audioLevelDisposable.set((call.myAudioLevel
                    |> deliverOnMainQueue).start(next: { [weak self] level in
                        guard let strongSelf = self else {
                            return
                        }
                        var effectiveLevel: Float = 0.0
                        if !strongSelf.currentIsMuted {
                            effectiveLevel = level
                        }
                        strongSelf.backgroundNode.audioLevel = max(0.0, min(1.0, effectiveLevel / 8.0))
                    }))
            }
            self.didSetupData = true
        }
        
        var title: String = ""
        var subtitle: String = ""
        
        if let strings = self.strings {
            if let currentPeer = self.currentPeer {
                title = currentPeer.displayTitle(strings: strings, displayOrder: self.nameDisplayOrder)
            }
            if let groupCallState = self.currentGroupCallState {
                if groupCallState.numberOfActiveSpeakers != 0 {
                    subtitle = strings.VoiceChat_Panel_MembersSpeaking(Int32(groupCallState.numberOfActiveSpeakers))
                } else {
                    subtitle = strings.VoiceChat_Panel_Members(Int32(max(1, groupCallState.participantCount)))
                }
            }
        }
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(13.0), textColor: .white)
        self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: .white)
        
        let animationSize: CGFloat = 25.0
        let iconSpacing: CGFloat = 0.0
        let spacing: CGFloat = 5.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: 160.0, height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: 160.0, height: size.height))
        
        let totalWidth = animationSize + iconSpacing + titleSize.width + spacing + subtitleSize.width
        let horizontalOrigin: CGFloat = floor((size.width - totalWidth) / 2.0)
        
        let contentHeight: CGFloat = 24.0
        let verticalOrigin: CGFloat = size.height - contentHeight
        
        self.microphoneNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin + floor((contentHeight - animationSize) / 2.0)), size: CGSize(width: animationSize, height: animationSize))
        self.microphoneNode.update(state: VoiceChatMicrophoneNode.State(muted: self.currentIsMuted, color: UIColor.white), animated: true)
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin + animationSize + iconSpacing, y: verticalOrigin + floor((contentHeight - titleSize.height) / 2.0)), size: titleSize)
        self.subtitleNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin + animationSize + iconSpacing + titleSize.width + spacing, y: verticalOrigin + floor((contentHeight - subtitleSize.height) / 2.0)), size: subtitleSize)
        
        self.backgroundNode.speaking = !self.currentIsMuted
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + 7.0))
    }
}
