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
import AnimatedCountLabelNode

private let blue = UIColor(rgb: 0x007fff)
private let lightBlue = UIColor(rgb: 0x00affe)
private let green = UIColor(rgb: 0x33c659)
private let activeBlue = UIColor(rgb: 0x00a0b9)
private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)
private let latePurple = UIColor(rgb: 0xaa56a6)
private let latePink = UIColor(rgb: 0xef476f)

private class CallStatusBarBackgroundNode: ASDisplayNode {
    enum State {
        case connecting
        case cantSpeak
        case late
        case active
        case speaking
    }
    private let foregroundView: UIView
    private let foregroundGradientLayer: CAGradientLayer
    private let maskCurveView: VoiceCurveView
    private let initialTimestamp = CACurrentMediaTime()
    
    var audioLevel: Float = 0.0  {
        didSet {
            self.maskCurveView.updateLevel(CGFloat(audioLevel))
        }
    }
    
    var connectingColor: UIColor = UIColor(rgb: 0xb6b6bb) {
        didSet {
            if self.connectingColor.rgb != oldValue.rgb {
                self.updateGradientColors()
            }
        }
    }
    
    var state: State = .connecting {
        didSet {
            if self.state != oldValue {
                self.updateGradientColors()
            }
        }
    }
    
    private func updateGradientColors() {
        let initialColors = self.foregroundGradientLayer.colors
        let targetColors: [CGColor]
        switch self.state {
            case .connecting:
                targetColors = [connectingColor.cgColor, connectingColor.cgColor]
            case .active:
                targetColors = [blue.cgColor, lightBlue.cgColor]
            case .speaking:
                targetColors = [green.cgColor, activeBlue.cgColor]
            case .cantSpeak:
                targetColors = [purple.cgColor, pink.cgColor]
            case .late:
                targetColors = [latePurple.cgColor, latePink.cgColor]
        }

        if CACurrentMediaTime() - self.initialTimestamp > 0.1 {
            self.foregroundGradientLayer.colors = targetColors
            self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.foregroundGradientLayer.colors = targetColors
            CATransaction.commit()
        }
    }
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true

    override init() {
        self.foregroundView = UIView()
        self.foregroundGradientLayer = CAGradientLayer()
        self.maskCurveView = VoiceCurveView(frame: CGRect(), maxLevel: 1.5, smallCurveRange: (0.0, 0.0), mediumCurveRange: (0.1, 0.55), bigCurveRange: (0.1, 1.0))
        self.maskCurveView.setColor(UIColor(rgb: 0xffffff))
        
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()
        
        self.addSubnode(self.hierarchyTrackingNode)
        
        self.foregroundGradientLayer.colors = [blue.cgColor, lightBlue.cgColor]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 2.0, y: 0.5)
        
        self.foregroundView.mask = self.maskCurveView
        
        self.isOpaque = false
        
        self.updateAnimations()
        
        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
                strongSelf.updateAnimations()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.foregroundView)
        self.foregroundView.layer.addSublayer(self.foregroundGradientLayer)
    }
    
    override func layout() {
        super.layout()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if self.maskCurveView.frame != self.bounds {
            self.foregroundView.frame = self.bounds
            self.foregroundGradientLayer.frame = self.bounds
            self.maskCurveView.frame = self.bounds
        }
        CATransaction.commit()
    }
    
    private func setupGradientAnimations() {
        /*if let _ = self.foregroundGradientLayer.animation(forKey: "movement") {
        } else {
            let previousValue = self.foregroundGradientLayer.startPoint
            let newValue: CGPoint
            if self.maskCurveView.presentationAudioLevel > 0.1 {
                newValue = CGPoint(x: CGFloat.random(in: 1.0 ..< 1.3), y: 0.5)
            } else {
                newValue = CGPoint(x: CGFloat.random(in: 0.85 ..< 1.2), y: 0.5)
            }
            self.foregroundGradientLayer.startPoint = newValue
            
            CATransaction.begin()
            
            let animation = CABasicAnimation(keyPath: "endPoint")
            animation.duration = Double.random(in: 0.8 ..< 1.4)
            animation.fromValue = previousValue
            animation.toValue = newValue
            
            CATransaction.setCompletionBlock { [weak self] in
                self?.setupGradientAnimations()
            }
            
            self.foregroundGradientLayer.add(animation, forKey: "movement")
            CATransaction.commit()
        }*/
    }
    
    func updateAnimations() {
        if !isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
            self.maskCurveView.stopAnimating()
            return
        }
        self.setupGradientAnimations()
        if isCurrentlyInHierarchy {
            self.maskCurveView.startAnimating()
        }
    }
}

public class CallStatusBarNodeImpl: CallStatusBarNode {
    public enum Content {
        case call(SharedAccountContext, Account, PresentationCall)
        case groupCall(SharedAccountContext, Account, PresentationGroupCall)
    }
    
    private let backgroundNode: CallStatusBarBackgroundNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateAnimatedCountLabelNode
    private let speakerNode: ImmediateTextNode
    
    private let audioLevelDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private var didSetupData = false
    
    private var currentSize: CGSize?
    private var currentContent: Content?
    
    private var presentationData: PresentationData?
    private let presentationDataDisposable = MetaDisposable()
    
    private var currentPeer: Peer?
    private var currentCallTimer: SwiftSignalKit.Timer?
    private var currentCallState: PresentationCallState?
    private var currentGroupCallState: PresentationGroupCallSummaryState?
    private var currentIsMuted = true
    private var currentCantSpeak = false
    private var currentScheduleTimestamp: Int32?
    private var currentMembers: PresentationGroupCallMembers?
    private var currentIsConnected = true

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true
    
    public override init() {
        self.backgroundNode = CallStatusBarBackgroundNode()
        self.titleNode = ImmediateTextNode()
        self.subtitleNode = ImmediateAnimatedCountLabelNode()
        self.subtitleNode.reverseAnimationDirection = true
        self.speakerNode = ImmediateTextNode()

        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()

        self.addSubnode(self.hierarchyTrackingNode)
                
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.speakerNode)

        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
                if value {
                    strongSelf.update()
                }
            }
        }
    }
    
    deinit {
        self.presentationDataDisposable.dispose()
        self.audioLevelDisposable.dispose()
        self.stateDisposable.dispose()
        self.currentCallTimer?.invalidate()
    }
    
    public func update(content: Content) {
        self.currentContent = content
        if self.isCurrentlyInHierarchy {
            self.update()
        }
    }
    
    public override func update(size: CGSize) {
        self.currentSize = size
        self.update()
    }

    private let textFont = Font.with(size: 13.0, design: .regular, weight: .regular, traits: [.monospacedNumbers])
    
    private func update() {
        guard let size = self.currentSize, let content = self.currentContent else {
            return
        }
        
        let wasEmpty = (self.titleNode.attributedText?.string ?? "").isEmpty
        
        if !self.didSetupData {
            self.didSetupData = true
            switch content {
                case let .call(sharedContext, account, call):
                    self.presentationData = sharedContext.currentPresentationData.with { $0 }
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
                            
                            let currentIsConnected: Bool
                            switch state.state {
                                case .active, .terminating, .terminated:
                                    currentIsConnected = true
                                default:
                                    currentIsConnected = false
                            }
                        
                            strongSelf.currentIsConnected = currentIsConnected
                            
                            strongSelf.update()
                        }
                    }))
                    self.audioLevelDisposable.set((call.audioLevel
                    |> deliverOnMainQueue).start(next: { [weak self] audioLevel in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.backgroundNode.audioLevel = audioLevel
                    }))
                case let .groupCall(sharedContext, account, call):
                    self.presentationData = sharedContext.currentPresentationData.with { $0 }
                    self.presentationDataDisposable.set((sharedContext.presentationData
                    |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                        if let strongSelf = self {
                            strongSelf.presentationData = presentationData
                            strongSelf.update()
                        }
                    }))
                    self.stateDisposable.set(
                        (combineLatest(
                            account.postbox.peerView(id: call.peerId),
                            call.summaryState,
                            call.isMuted,
                            call.members
                        )
                    |> deliverOnMainQueue).start(next: { [weak self] view, state, isMuted, members in
                        if let strongSelf = self {
                            strongSelf.currentPeer = view.peers[view.peerId]
                            strongSelf.currentGroupCallState = state
                            strongSelf.currentMembers = members
                                
                            var isMuted = isMuted
                            var cantSpeak = false
                            if let state = state, let muteState = state.callState.muteState {
                                if !muteState.canUnmute {
                                    isMuted = true
                                    cantSpeak = true
                                }
                            }
                            if state?.callState.scheduleTimestamp != nil {
                                cantSpeak = true
                            }
                            strongSelf.currentIsMuted = isMuted
                            strongSelf.currentCantSpeak = cantSpeak
                            strongSelf.currentScheduleTimestamp = state?.callState.scheduleTimestamp
                            
                            let currentIsConnected: Bool
                            if let state = state, case .connected = state.callState.networkState {
                                currentIsConnected = true
                            } else if state?.callState.scheduleTimestamp != nil {
                                currentIsConnected = true
                            } else {
                                currentIsConnected = false
                            }
                            strongSelf.currentIsConnected = currentIsConnected

                            if strongSelf.isCurrentlyInHierarchy {
                                strongSelf.update()
                            }
                        }
                    }))
                    self.audioLevelDisposable.set((combineLatest(call.myAudioLevel, .single([]) |> then(call.audioLevels))
                    |> deliverOnMainQueue).start(next: { [weak self] myAudioLevel, audioLevels in
                        guard let strongSelf = self else {
                            return
                        }
                        var effectiveLevel: Float = 0.0
                        var audioLevels = audioLevels
                        if !strongSelf.currentIsMuted {
                            audioLevels.append((PeerId(0), 0, myAudioLevel, true))
                        }
                        effectiveLevel = audioLevels.map { $0.2 }.max() ?? 0.0
                        strongSelf.backgroundNode.audioLevel = effectiveLevel
                    }))
            }
        }
        
        var title: String = ""
        var speakerSubtitle: String = ""

        let textColor = UIColor.white
        var segments: [AnimatedCountLabelNode.Segment] = []
        var displaySpeakerSubtitle = false
        var isLate = false
        
        if let presentationData = self.presentationData {
            if let voiceChatTitle = self.currentGroupCallState?.info?.title, !voiceChatTitle.isEmpty {
                title = voiceChatTitle
            } else if let currentPeer = self.currentPeer {
                title = EnginePeer(currentPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
            var membersCount: Int32?
            if let groupCallState = self.currentGroupCallState {
                membersCount = Int32(max(1, groupCallState.participantCount))
            } else if let content = self.currentContent, case .groupCall = content {
                membersCount = 1
            }
            
            var speakingPeer: Peer?
            if let members = currentMembers {
                var speakingPeers: [Peer] = []
                for member in members.participants {
                    if members.speakingParticipants.contains(member.peer.id) {
                        speakingPeers.append(member.peer)
                    }
                }
                speakingPeer = speakingPeers.first
            }
            
            if let speakingPeer = speakingPeer {
                speakerSubtitle = EnginePeer(speakingPeer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
            displaySpeakerSubtitle = speakerSubtitle != title && !speakerSubtitle.isEmpty
            
            var requiresTimer = false
            if let scheduleTime = self.currentGroupCallState?.info?.scheduleTimestamp {
                requiresTimer = true
                
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                let elapsedTime = scheduleTime - currentTime
                let timerText: String
                if elapsedTime >= 86400 {
                    timerText = presentationData.strings.VoiceChat_StatusStartsIn(scheduledTimeIntervalString(strings: presentationData.strings, value: elapsedTime)).string
                } else if elapsedTime < 0 {
                    isLate = true
                    timerText = presentationData.strings.VoiceChat_StatusLateBy(textForTimeout(value: abs(elapsedTime))).string
                } else {
                    timerText = presentationData.strings.VoiceChat_StatusStartsIn(textForTimeout(value: elapsedTime)).string
                }
                segments.append(.text(0, NSAttributedString(string: timerText, font: textFont, textColor: textColor)))
            } else if let membersCount = membersCount {
                var membersPart = presentationData.strings.VoiceChat_Status_Members(membersCount)
                if membersPart.contains("[") && membersPart.contains("]") {
                    if let startIndex = membersPart.firstIndex(of: "["), let endIndex = membersPart.firstIndex(of: "]") {
                        membersPart.removeSubrange(startIndex ... endIndex)
                    }
                } else {
                    membersPart = membersPart.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789-,."))
                }
                
                let rawTextAndRanges = presentationData.strings.VoiceChat_Status_MembersFormat("\(membersCount)", membersPart)

                var textIndex = 0
                var latestIndex = 0
                for rangeItem in rawTextAndRanges.ranges {
                    let index = rangeItem.index
                    let range = rangeItem.range
                    var lowerSegmentIndex = range.lowerBound
                    if index != 0 {
                        lowerSegmentIndex = min(lowerSegmentIndex, latestIndex)
                    } else {
                        if latestIndex < range.lowerBound {
                            let part = String(rawTextAndRanges.string[rawTextAndRanges.string.index(rawTextAndRanges.string.startIndex, offsetBy: latestIndex) ..< rawTextAndRanges.string.index(rawTextAndRanges.string.startIndex, offsetBy: range.lowerBound)])
                            segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: textColor)))
                            textIndex += 1
                        }
                    }
                    latestIndex = range.upperBound
                    
                    let part = String(rawTextAndRanges.string[rawTextAndRanges.string.index(rawTextAndRanges.string.startIndex, offsetBy: lowerSegmentIndex) ..< rawTextAndRanges.string.index(rawTextAndRanges.string.startIndex, offsetBy: range.upperBound)])
                    if index == 0 {
                        segments.append(.number(Int(membersCount), NSAttributedString(string: part, font: textFont, textColor: textColor)))
                    } else {
                        segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: textColor)))
                        textIndex += 1
                    }
                }
                if latestIndex < rawTextAndRanges.string.count {
                    let part = String(rawTextAndRanges.string[rawTextAndRanges.string.index(rawTextAndRanges.string.startIndex, offsetBy: latestIndex)...])
                    segments.append(.text(textIndex, NSAttributedString(string: part, font: textFont, textColor: textColor)))
                    textIndex += 1
                }
            }
            
            let sourceColor = presentationData.theme.chatList.unreadBadgeInactiveBackgroundColor
            let color: UIColor
            if sourceColor.alpha < 1.0 {
                color = presentationData.theme.chatList.unreadBadgeInactiveBackgroundColor.mixedWith(sourceColor.withAlphaComponent(1.0), alpha: sourceColor.alpha)
            } else {
                color = sourceColor
            }
            
            self.backgroundNode.connectingColor = color
            
            if requiresTimer {
                if self.currentCallTimer == nil {
                    let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        self?.update()
                    }, queue: Queue.mainQueue())
                    timer.start()
                    self.currentCallTimer = timer
                }
            } else if let currentCallTimer = self.currentCallTimer {
                self.currentCallTimer = nil
                currentCallTimer.invalidate()
            }
        }
        
        if self.subtitleNode.segments != segments && !displaySpeakerSubtitle {
            self.subtitleNode.segments = segments
        }
        
        let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        alphaTransition.updateAlpha(node: self.subtitleNode, alpha: displaySpeakerSubtitle ? 0.0 : 1.0)
        alphaTransition.updateAlpha(node: self.speakerNode, alpha: displaySpeakerSubtitle ? 1.0 : 0.0)
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(13.0), textColor: .white)
        
        if displaySpeakerSubtitle {
            self.speakerNode.attributedText = NSAttributedString(string: speakerSubtitle, font: Font.regular(13.0), textColor: .white)
        }
        
        let spacing: CGFloat = 5.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: 150.0, height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(size: CGSize(width: 150.0, height: size.height), animated: true)
        let speakerSize = self.speakerNode.updateLayout(CGSize(width: 150.0, height: size.height))
        
        let totalWidth = titleSize.width + spacing + subtitleSize.width
        let horizontalOrigin: CGFloat = floor((size.width - totalWidth) / 2.0)
        
        let contentHeight: CGFloat = 24.0
        let verticalOrigin: CGFloat = size.height - contentHeight
        
        let sizeChanged = self.titleNode.frame.size.width != titleSize.width
        
        let transition: ContainedViewLayoutTransition = wasEmpty || sizeChanged ? .immediate : .animated(duration: 0.2, curve: .easeInOut)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin + floor((contentHeight - titleSize.height) / 2.0)), size: titleSize))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: horizontalOrigin + titleSize.width + spacing, y: verticalOrigin + floor((contentHeight - subtitleSize.height) / 2.0)), size: subtitleSize))
        
        if displaySpeakerSubtitle {
            self.speakerNode.frame = CGRect(origin: CGPoint(x: horizontalOrigin + titleSize.width + spacing, y: verticalOrigin + floor((contentHeight - speakerSize.height) / 2.0)), size: speakerSize)
        }
        
        let state: CallStatusBarBackgroundNode.State
        if self.currentIsConnected {
            if self.currentCantSpeak {
                state = isLate ? .late : .cantSpeak
            } else if self.currentIsMuted {
                state = .active
            } else {
                state = .speaking
            }
        } else {
            state = .connecting
        }
        self.backgroundNode.state = state
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + 18.0))
    }
}

private final class VoiceCurveView: UIView {
    private let smallCurve: CurveView
    private let mediumCurve: CurveView
    private let bigCurve: CurveView
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    
    private(set) var isAnimating = false
    
    public typealias CurveRange = (min: CGFloat, max: CGFloat)
    
    public init(
        frame: CGRect,
        maxLevel: CGFloat,
        smallCurveRange: CurveRange,
        mediumCurveRange: CurveRange,
        bigCurveRange: CurveRange
    ) {
        self.maxLevel = maxLevel
        
        self.smallCurve = CurveView(
            pointsCount: 8,
            minRandomness: 1,
            maxRandomness: 1.3,
            minSpeed: 0.9,
            maxSpeed: 3.2,
            minOffset: smallCurveRange.min,
            maxOffset: smallCurveRange.max
        )
        self.mediumCurve = CurveView(
            pointsCount: 8,
            minRandomness: 1.2,
            maxRandomness: 1.5,
            minSpeed: 1.0,
            maxSpeed: 4.4,
            minOffset: mediumCurveRange.min,
            maxOffset: mediumCurveRange.max
        )
        self.bigCurve = CurveView(
            pointsCount: 8,
            minRandomness: 1.2,
            maxRandomness: 1.7,
            minSpeed: 1.0,
            maxSpeed: 5.8,
            minOffset: bigCurveRange.min,
            maxOffset: bigCurveRange.max
        )
        
        super.init(frame: frame)
        
        addSubview(bigCurve)
        addSubview(mediumCurve)
        addSubview(smallCurve)
        
        displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
            
            strongSelf.smallCurve.level = strongSelf.presentationAudioLevel
            strongSelf.mediumCurve.level = strongSelf.presentationAudioLevel
            strongSelf.bigCurve.level = strongSelf.presentationAudioLevel
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
        smallCurve.setColor(color.withAlphaComponent(1.0))
        mediumCurve.setColor(color.withAlphaComponent(0.55))
        bigCurve.setColor(color.withAlphaComponent(0.35))
    }
    
    public func updateLevel(_ level: CGFloat) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        smallCurve.updateSpeedLevel(to: normalizedLevel)
        mediumCurve.updateSpeedLevel(to: normalizedLevel)
        bigCurve.updateSpeedLevel(to: normalizedLevel)
        
        audioLevel = normalizedLevel
    }
    
    public func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        updateCurvesState()
        
        displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        isAnimating = false
        
        updateCurvesState()
        
        displayLinkAnimator?.isPaused = true
    }
    
    private func updateCurvesState() {
        if isAnimating {
            if smallCurve.frame.size != .zero {
                smallCurve.startAnimating()
                mediumCurve.startAnimating()
                bigCurve.startAnimating()
            }
        } else {
            smallCurve.stopAnimating()
            mediumCurve.stopAnimating()
            bigCurve.stopAnimating()
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        smallCurve.frame = bounds
        mediumCurve.frame = bounds
        bigCurve.frame = bounds
        
        updateCurvesState()
    }
}

final class CurveView: UIView {
    let pointsCount: Int
    let smoothness: CGFloat
    
    let minRandomness: CGFloat
    let maxRandomness: CGFloat
    
    let minSpeed: CGFloat
    let maxSpeed: CGFloat
    
    let minOffset: CGFloat
    let maxOffset: CGFloat
        
    var level: CGFloat = 0 {
        didSet {
            guard self.minOffset > 0.0 else {
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let lv = self.minOffset + (self.maxOffset - self.minOffset) * self.level
            self.shapeLayer.transform = CATransform3DMakeTranslation(0.0, lv * 16.0, 0.0)
            CATransaction.commit()
        }
    }
    
    private var speedLevel: CGFloat = 0
    private var lastSpeedLevel: CGFloat = 0
    
    private let shapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = nil
        return layer
    }()
    
    
    override var frame: CGRect {
        didSet {
            if self.frame.size != oldValue.size {
                self.shapeLayer.path = nil
                self.animateToNewShape()
            }
        }
    }
    
    init(
        pointsCount: Int,
        minRandomness: CGFloat,
        maxRandomness: CGFloat,
        minSpeed: CGFloat,
        maxSpeed: CGFloat,
        minOffset: CGFloat,
        maxOffset: CGFloat
    ) {
        self.pointsCount = pointsCount
        self.minRandomness = minRandomness
        self.maxRandomness = maxRandomness
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minOffset = minOffset
        self.maxOffset = maxOffset
        
        self.smoothness = 0.35
        
        super.init(frame: .zero)
        
        self.layer.addSublayer(self.shapeLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setColor(_ color: UIColor) {
        self.shapeLayer.fillColor = color.cgColor
    }
    
    func updateSpeedLevel(to newSpeedLevel: CGFloat) {
        speedLevel = max(speedLevel, newSpeedLevel)
        
//        if abs(lastSpeedLevel - newSpeedLevel) > 0.45 {
//            animateToNewShape()
//        }
    }
    
    func startAnimating() {
        self.animateToNewShape()
    }
    
    func stopAnimating() {
        self.shapeLayer.removeAnimation(forKey: "path")
    }
    
    private func animateToNewShape() {
        if self.shapeLayer.path == nil {
            let points = self.generateNextCurve(for: self.bounds.size)
            self.shapeLayer.path = UIBezierPath.smoothCurve(through: points, length: bounds.width, smoothness: self.smoothness, curve: true).cgPath
        }
        
        let nextPoints = self.generateNextCurve(for: self.bounds.size)
        let nextPath = UIBezierPath.smoothCurve(through: nextPoints, length: bounds.width, smoothness: self.smoothness, curve: true).cgPath
        
        let animation = CABasicAnimation(keyPath: "path")
        let previousPath = self.shapeLayer.path
        self.shapeLayer.path = nextPath
        animation.duration = CFTimeInterval(1 / (self.minSpeed + (self.maxSpeed - self.minSpeed) * self.speedLevel))
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fromValue = previousPath
        animation.toValue = nextPath
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.completion = { [weak self] finished in
            if finished {
                self?.animateToNewShape()
            }
        }
        self.shapeLayer.add(animation, forKey: "path")
        
        self.lastSpeedLevel = self.speedLevel
        self.speedLevel = 0
    }
    
    private func generateNextCurve(for size: CGSize) -> [CGPoint] {
        let randomness = minRandomness + (maxRandomness - minRandomness) * speedLevel
        return curve(pointsCount: pointsCount, randomness: randomness).map {
            return CGPoint(x: $0.x * CGFloat(size.width), y: size.height - 18.0 + $0.y * 12.0)
        }
    }

    private func curve(pointsCount: Int, randomness: CGFloat) -> [CGPoint] {
        let segment = 1.0 / CGFloat(pointsCount - 1)

        let rgen = { () -> CGFloat in
            let accuracy: UInt32 = 1000
            let random = arc4random_uniform(accuracy)
            return CGFloat(random) / CGFloat(accuracy)
        }
        let rangeStart: CGFloat = 1.0 / (1.0 + randomness / 10.0)

        let points = (0 ..< pointsCount).map { i -> CGPoint in
            let randPointOffset = (rangeStart + CGFloat(rgen()) * (1 - rangeStart)) / 2
            let segmentRandomness: CGFloat = randomness
            
            let pointX: CGFloat
            let pointY: CGFloat
            let randomXDelta: CGFloat
            if i == 0 {
                pointX = 0.0
                pointY = 0.0
                randomXDelta = 0.0
            } else if i == pointsCount - 1 {
                pointX = 1.0
                pointY = 0.0
                randomXDelta = 0.0
            } else {
                pointX = segment * CGFloat(i)
                pointY = ((segmentRandomness * CGFloat(arc4random_uniform(100)) / CGFloat(100)) - segmentRandomness * 0.5) * randPointOffset
                randomXDelta = segment - segment * randPointOffset
            }

            return CGPoint(x: pointX + randomXDelta, y: pointY)
        }

        return points
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.shapeLayer.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
        self.shapeLayer.bounds = self.bounds
        CATransaction.commit()
    }
}
