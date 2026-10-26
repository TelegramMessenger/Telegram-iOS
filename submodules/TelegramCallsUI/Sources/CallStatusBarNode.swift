import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AnimatedCountLabelNode
import ComponentFlow
import ReactionSelectionNode

private let blue = UIColor(rgb: 0x007fff)
private let lightBlue = UIColor(rgb: 0x00affe)
private let green = UIColor(rgb: 0x33c659)
private let activeBlue = UIColor(rgb: 0x00a0b9)
private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)
private let latePurple = UIColor(rgb: 0xaa56a6)
private let latePink = UIColor(rgb: 0xef476f)

private func textForTimeout(value: Int32) -> String {
    if value < 3600 {
        let minutes = value / 60
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(minutes):\(secondsPadding)\(seconds)"
    } else {
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let minutesPadding = minutes < 10 ? "0" : ""
        let seconds = value % 60
        let secondsPadding = seconds < 10 ? "0" : ""
        return "\(hours):\(minutesPadding)\(minutes):\(secondsPadding)\(seconds)"
    }
}

private class CallStatusBarBackgroundNode: ASDisplayNode {
    enum State {
        case connecting
        case cantSpeak
        case late
        case active
        case speaking
    }
    private let wavesLayer: CallStatusBarWavesLayer
    private let initialTimestamp = CACurrentMediaTime()
    
    var audioLevel: Float = 0.0  {
        didSet {
            self.wavesLayer.updateAudioLevel(CGFloat(self.audioLevel))
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
    
    var isDarkAppearance: Bool = false {
        didSet {
            self.wavesLayer.isDarkAppearance = self.isDarkAppearance
        }
    }
    
    private func updateGradientColors() {
        let targetColors: (UIColor, UIColor)
        switch self.state {
            case .connecting:
                targetColors = (self.connectingColor, self.connectingColor)
            case .active:
                targetColors = (blue, lightBlue)
            case .speaking:
                targetColors = (green, activeBlue)
            case .cantSpeak:
                targetColors = (purple, pink)
            case .late:
                targetColors = (latePurple, latePink)
        }
        self.wavesLayer.updateColors(targetColors, animated: CACurrentMediaTime() - self.initialTimestamp > 0.1)
    }
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    
    var animationsEnabled: Bool = false {
        didSet {
            self.wavesLayer.isFlat = !self.animationsEnabled
        }
    }

    override init() {
        self.wavesLayer = CallStatusBarWavesLayer(colors: (blue, lightBlue))
        
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()
        
        self.addSubnode(self.hierarchyTrackingNode)
        
        self.isOpaque = false
        
        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.wavesLayer.isInWindow = value
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.addSublayer(self.wavesLayer)
    }
    
    override func layout() {
        super.layout()
        
        let wavesFrame = CGRect(origin: CGPoint(), size: CGSize(width: self.bounds.width, height: self.bounds.height + CallStatusBarWavesLayer.bottomOverflow))
        if self.wavesLayer.frame != wavesFrame {
            self.wavesLayer.frame = wavesFrame
            self.wavesLayer.update(barHeight: self.bounds.height)
        }
    }
}

public class CallStatusBarNodeImpl: CallStatusBarNode {
    public enum Content: Equatable {
        case call(SharedAccountContext, Account, PresentationCall)
        case groupCall(SharedAccountContext, Account, PresentationGroupCall)
        
        var sharedContext: SharedAccountContext {
            switch self {
            case let .call(sharedContext, _, _), let .groupCall(sharedContext, _, _):
                return sharedContext
            }
        }
        
        public static func ==(lhs: Content, rhs: Content) -> Bool {
            switch lhs {
            case let .call(sharedContext, account, call):
                if case let .call(rhsSharedContext, rhsAccount, rhsCall) = rhs, sharedContext === rhsSharedContext, account === rhsAccount, call === rhsCall {
                    return true
                } else {
                    return false
                }
            case let .groupCall(sharedContext, account, groupCall):
                if case let .groupCall(rhsSharedContext, rhsAccount, rhsGroupCall) = rhs, sharedContext === rhsSharedContext, account === rhsAccount, groupCall === rhsGroupCall {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    private let backgroundNode: CallStatusBarBackgroundNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateAnimatedCountLabelNode
    private let speakerNode: ImmediateTextNode
    private var messageView: ComponentView<Empty>?
    
    private let audioLevelDisposable = MetaDisposable()
    private let stateDisposable = MetaDisposable()
    private weak var didSetupDataForCall: AnyObject?
    
    private var currentSize: CGSize?
    private var currentContent: Content?
    
    private var presentationData: PresentationData?
    private let presentationDataDisposable = MetaDisposable()
    
    private var currentPeer: EnginePeer?
    private var currentCallTimer: SwiftSignalKit.Timer?
    private var currentCallState: PresentationCallState?
    private var currentGroupCallState: PresentationGroupCallSummaryState?
    private var currentIsMuted = true
    private var currentCantSpeak = false
    private var currentScheduleTimestamp: Int32?
    private var currentMembers: PresentationGroupCallMembers?
    private var currentIsConnected = true

    private var reactionItems: [ReactionItem]?
    private var messagesState: GroupCallMessagesContext.State?
    private let messagesStateDisposable = MetaDisposable()
    private var currentMessageId: GroupCallMessagesContext.Message.Id?
    
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
        self.messagesStateDisposable.dispose()
        self.currentCallTimer?.invalidate()
    }
    
    public func update(content: Content) {
        if self.currentContent != content {
            self.currentContent = content
            self.backgroundNode.animationsEnabled = content.sharedContext.energyUsageSettings.fullTranslucency
            if self.isCurrentlyInHierarchy {
                self.update()
            }
        }
    }
    
    public override var bottomOverhang: CGFloat {
        return CallStatusBarWavesLayer.bottomOverflow
    }
    
    public override func update(size: CGSize) {
        self.currentSize = size
        self.update()
    }

    private let callTextFont = Font.with(size: 13.0, design: .regular, weight: .regular, traits: [.monospacedNumbers])
    private let groupCallTextFont = Font.with(size: 13.0, design: .regular, weight: .regular, traits: [])
    
    private func update() {
        guard let size = self.currentSize, let content = self.currentContent else {
            return
        }
        
        let wasEmpty = (self.titleNode.attributedText?.string ?? "").isEmpty
        
        let textFont: UIFont
        let setupDataForCall: AnyObject?
        switch content {
        case let .call(_, _, call):
            setupDataForCall = call
            textFont = callTextFont
        case let .groupCall(_, _, call):
            setupDataForCall = call
            textFont = groupCallTextFont
        }
        
        if self.didSetupDataForCall !== setupDataForCall {
            self.didSetupDataForCall = setupDataForCall
            switch content {
                case let .call(sharedContext, account, call):
                    // The node is reused when a group call is followed by a 1:1 call; nothing of the group call may
                    // show while the new call's state is on its way (its peer may never arrive if it is not stored).
                    self.currentPeer = nil
                    self.currentCallState = nil
                    self.currentIsMuted = true
                    self.currentIsConnected = false
                    self.currentGroupCallState = nil
                    self.currentMembers = nil
                    self.currentCantSpeak = false
                    self.currentScheduleTimestamp = nil
                    self.messagesStateDisposable.set(nil)
                    self.messagesState = nil
                    self.backgroundNode.audioLevel = 0.0
                    
                    self.presentationData = sharedContext.currentPresentationData.with { $0 }
                    self.presentationDataDisposable.set((sharedContext.presentationData
                    |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                        if let strongSelf = self, strongSelf.presentationData !== presentationData {
                            strongSelf.presentationData = presentationData
                            strongSelf.update()
                        }
                    }))
                    let callPeer = TelegramEngine(account: account).data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: call.peerId))
                    |> mapToSignal { peer -> Signal<EnginePeer, NoError> in
                        if let peer {
                            return .single(peer)
                        } else {
                            return .never()
                        }
                    }
                    self.stateDisposable.set(
                        (combineLatest(
                            callPeer,
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
                        if let strongSelf = self, strongSelf.presentationData !== presentationData {
                            strongSelf.presentationData = presentationData
                            strongSelf.update()
                        }
                    }))
                    let callPeerView: Signal<EnginePeer?, NoError>
                    if let peerId = call.peerId {
                        callPeerView = TelegramEngine(account: account).data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    } else {
                        callPeerView = .single(nil)
                    }
                    self.stateDisposable.set(
                        (combineLatest(
                            callPeerView,
                            call.summaryState,
                            call.isMuted,
                            call.members
                        )
                    |> deliverOnMainQueue).start(next: { [weak self] view, state, isMuted, members in
                        if let strongSelf = self {
                            if let view {
                                strongSelf.currentPeer = view
                            } else {
                                strongSelf.currentPeer = nil
                            }
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
                            audioLevels.append((EnginePeer.Id(0), 0, myAudioLevel, true))
                        }
                        effectiveLevel = audioLevels.map { $0.2 }.max() ?? 0.0
                        strongSelf.backgroundNode.audioLevel = effectiveLevel
                    }))
                
                    if let groupCall = call as? PresentationGroupCallImpl {
                        let _ = (allowedStoryReactions(engine: TelegramEngine(account: account))
                        |> deliverOnMainQueue).start(next: { [weak self] reactionItems in
                            self?.reactionItems = reactionItems
                        })
                        
                        self.messagesStateDisposable.set((groupCall.messagesState
                        |> deliverOnMainQueue).start(next: { [weak self] messagesState in
                            guard let self else {
                                return
                            }
                            if self.messagesState != messagesState {
                                self.messagesState = messagesState
                                
                                if self.isCurrentlyInHierarchy {
                                    self.update()
                                }
                            }
                        }))
                    }
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
                title = currentPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
            var membersCount: Int32?
            if let groupCallState = self.currentGroupCallState {
                membersCount = Int32(max(1, groupCallState.participantCount))
            } else if let content = self.currentContent, case .groupCall = content {
                membersCount = 1
            }
            
            var speakingPeer: EnginePeer?
            if let members = currentMembers {
                var speakingPeers: [EnginePeer] = []
                for member in members.participants {
                    if let memberPeer = member.peer, members.speakingParticipants.contains(memberPeer.id) {
                        speakingPeers.append(memberPeer)
                    }
                }
                speakingPeer = speakingPeers.first
            }

            if let speakingPeer = speakingPeer {
                speakerSubtitle = speakingPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
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
            self.backgroundNode.isDarkAppearance = presentationData.theme.overallDarkAppearance
            
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
        
        let contentHeight: CGFloat = 24.0
        let verticalOrigin: CGFloat = size.height - contentHeight
        
        var isDisplayingMessage = false
        let componentTransition: ComponentTransition = .easeInOut(duration: 0.25)
        if case let .groupCall(_, account, call) = self.currentContent, let message = self.messagesState?.messages.last(where: { $0.author?.id != account.peerId }), let author = message.author, let groupCall = call as? PresentationGroupCallImpl {
            if self.currentMessageId != message.id {
                self.currentMessageId = message.id
                
                if let messageView = self.messageView?.view {
                    self.messageView = nil
                    componentTransition.setAlpha(view: messageView, alpha: 0.0, completion: { _ in
                        messageView.removeFromSuperview()
                    })
                }
            }
            let messageView: ComponentView<Empty>
            if let current = self.messageView {
                messageView = current
            } else {
                messageView = ComponentView<Empty>()
                self.messageView = messageView
            }
            
            let messageSize = messageView.update(
                transition: .immediate,
                component: AnyComponent(
                    MessageItemComponent(
                        context: groupCall.accountContext,
                        icon: .peer(author),
                        style: .status,
                        text: message.text,
                        entities: message.entities,
                        availableReactions: self.reactionItems,
                        openPeer: nil
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - 140.0, height: contentHeight)
            )
            if let view = messageView.view {
                if view.superview == nil {
                    view.transform = CGAffineTransformMakeScale(1.0, -1.0)
                    self.view.addSubview(view)
                    componentTransition.animateAlpha(view: view, from: 0.0, to: 1.0)
                }
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - messageSize.width) / 2.0), y: verticalOrigin + floor((contentHeight - messageSize.height) / 2.0) + 1.0), size: messageSize)
            }
            isDisplayingMessage = true
        } else if let messageView = self.messageView?.view {
            self.messageView = nil
            componentTransition.setAlpha(view: messageView, alpha: 0.0, completion: { _ in
                messageView.removeFromSuperview()
            })
        }
        
        let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        alphaTransition.updateAlpha(node: self.titleNode, alpha: isDisplayingMessage ? 0.0 : 1.0)
        alphaTransition.updateAlpha(node: self.subtitleNode, alpha: displaySpeakerSubtitle || isDisplayingMessage ? 0.0 : 1.0)
        alphaTransition.updateAlpha(node: self.speakerNode, alpha: displaySpeakerSubtitle && !isDisplayingMessage ? 1.0 : 0.0)
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(13.0), textColor: .white)
        
        if displaySpeakerSubtitle {
            self.speakerNode.attributedText = NSAttributedString(string: speakerSubtitle, font: Font.regular(13.0), textColor: .white)
        }
        
        let spacing: CGFloat = 5.0
        let titleSize = self.titleNode.updateLayout(CGSize(width: 150.0, height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(size: CGSize(width: 150.0, height: size.height), animated: true)
        let speakerSize = self.speakerNode.updateLayout(CGSize(width: 150.0, height: size.height))
        
        var totalWidth = titleSize.width
        if totalWidth > 0.0 {
            totalWidth += spacing
        }
        totalWidth += subtitleSize.width
        let horizontalOrigin: CGFloat = floor((size.width - totalWidth) / 2.0)
        
        let sizeChanged = self.titleNode.frame.size.width != titleSize.width
        
        let transition: ContainedViewLayoutTransition = wasEmpty || sizeChanged ? .immediate : .animated(duration: 0.2, curve: .easeInOut)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin + floor((contentHeight - titleSize.height) / 2.0)), size: titleSize))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: horizontalOrigin + titleSize.width + spacing, y: verticalOrigin + floor((contentHeight - subtitleSize.height) / 2.0)), size: subtitleSize))
        
        if displaySpeakerSubtitle {
            let speakerOriginX: CGFloat = title.isEmpty ? floor((size.width - speakerSize.width) / 2.0) : horizontalOrigin + titleSize.width + spacing
            self.speakerNode.frame = CGRect(origin: CGPoint(x: speakerOriginX, y: verticalOrigin + floor((contentHeight - speakerSize.height) / 2.0)), size: speakerSize)
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
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
    }
}
