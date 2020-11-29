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
    let transitionArguments: (startTime: Double, duration: Double)?
    
    init(timestamp: Double, amplitude: CGFloat, phase: CGFloat, speaking: Bool, transitionArguments: (Double, Double)?) {
        self.timestamp = timestamp
        self.amplitude = amplitude
        self.phase = phase
        self.speaking = speaking
        self.transitionArguments = transitionArguments
    }
}

private class CallStatusBarBackgroundNode: ASDisplayNode {
    var muted = true
    
    var audioLevel: Float = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    var phase: CGFloat = 0.0
    
    var transitionArguments: (Double, Double)?
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
        return CallStatusBarBackgroundNodeDrawingState(timestamp: CACurrentMediaTime(), amplitude: self.presentationAudioLevel, phase: self.phase, speaking: self.speaking, transitionArguments: self.transitionArguments)
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
        
        var gradientTransition: CGFloat = 0.0
        gradientTransition = parameters.speaking ? 1.0 : 0.0
        if let transition = parameters.transitionArguments {
            gradientTransition = CGFloat((parameters.timestamp - transition.startTime) / transition.duration)
            if !parameters.speaking {
                gradientTransition = 1.0 - gradientTransition
            }
        }
    
        let leftColor = UIColor(rgb: 0x007fff).interpolateTo(UIColor(rgb: 0x2bb76b), fraction: gradientTransition)!
        let rightColor = UIColor(rgb: 0x00afff).interpolateTo(UIColor(rgb: 0x007fff), fraction: gradientTransition)!
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
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
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
