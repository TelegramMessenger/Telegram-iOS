import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import AccountContext
import AppBundle
import SwiftSignalKit
import AnimatedAvatarSetNode
import AudioBlob

func textForTimeout(value: Int32) -> String {
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

private let titleFont = Font.semibold(15.0)
private let subtitleFont = Font.regular(13.0)

public enum GroupCallPanelSource {
    case none
    case all
    case peer(PeerId)
}

public final class GroupCallPanelData {
    public let peerId: PeerId
    public let isChannel: Bool
    public let info: GroupCallInfo
    public let topParticipants: [GroupCallParticipantsContext.Participant]
    public let participantCount: Int
    public let activeSpeakers: Set<PeerId>
    public let groupCall: PresentationGroupCall?
    
    public init(
        peerId: PeerId,
        isChannel: Bool,
        info: GroupCallInfo,
        topParticipants: [GroupCallParticipantsContext.Participant],
        participantCount: Int,
        activeSpeakers: Set<PeerId>,
        groupCall: PresentationGroupCall?
    ) {
        self.peerId = peerId
        self.isChannel = isChannel
        self.info = info
        self.topParticipants = topParticipants
        self.participantCount = participantCount
        self.activeSpeakers = activeSpeakers
        self.groupCall = groupCall
    }
}

private final class FakeAudioLevelGenerator {
    private var isFirstTime: Bool = true
    private var nextTarget: Float = 0.0
    private var nextTargetProgress: Float = 0.0
    private var nextTargetProgressNorm: Float = 1.0
    
    func get() -> Float {
        let wasFirstTime = self.isFirstTime
        self.isFirstTime = false
        
        self.nextTargetProgress *= 0.82
        if self.nextTargetProgress <= 0.01 {
            if Int.random(in: 0 ... 4) <= 1 && !wasFirstTime {
                self.nextTarget = 0.0
                self.nextTargetProgressNorm = Float.random(in: 0.1 ..< 0.3)
            } else {
                self.nextTarget = Float.random(in: 0.0 ..< 20.0)
                self.nextTargetProgressNorm = Float.random(in: 0.2 ..< 0.7)
            }
            self.nextTargetProgress = self.nextTargetProgressNorm
            return self.nextTarget
        } else {
            let value = self.nextTarget * max(0.0, self.nextTargetProgress / self.nextTargetProgressNorm)
            return value
        }
    }
}

public final class GroupCallNavigationAccessoryPanel: ASDisplayNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var dateTimeFormat: PresentationDateTimeFormat
    
    private let tapAction: () -> Void
    
    private let contentNode: ASDisplayNode
    
    private let tapButton: HighlightTrackingButtonNode
    
    private let joinButton: HighlightableButtonNode
    private let joinButtonTitleNode: ImmediateTextNode
    private let joinButtonBackgroundNode: ASImageNode
    
    private var audioLevelView: VoiceBlobView?
    
    private let micButton: HighlightTrackingButtonNode
    private let micButtonForegroundNode: VoiceChatMicrophoneNode
    private let micButtonBackgroundNode: ASImageNode
    private var micButtonBackgroundNodeIsMuted: Bool?
    
    let titleNode: ImmediateTextNode
    let textNode: ImmediateTextNode
    private var textIsActive = false
    private let muteIconNode: ASImageNode
    
    private var isScheduled = false
    private var isLate = false
    private var currentText: String = ""
    private var updateTimer: SwiftSignalKit.Timer?
    
    private let avatarsContext: AnimatedAvatarSetContext
    private var avatarsContent: AnimatedAvatarSetContext.Content?
    private let avatarsNode: AnimatedAvatarSetNode
    private var audioLevelGenerators: [PeerId: FakeAudioLevelGenerator] = [:]
    private var audioLevelGeneratorTimer: SwiftSignalKit.Timer?

    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    private let membersDisposable = MetaDisposable()
    private let isMutedDisposable = MetaDisposable()
    private let audioLevelDisposable = MetaDisposable()
    
    private var callState: PresentationGroupCallState?
    
    private let hapticFeedback = HapticFeedback()
    
    private var currentData: GroupCallPanelData?
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    public init(context: AccountContext, presentationData: PresentationData, tapAction: @escaping () -> Void) {
        self.context = context
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.dateTimeFormat = presentationData.dateTimeFormat
        
        self.tapAction = tapAction
        
        self.contentNode = ASDisplayNode()
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.joinButton = HighlightableButtonNode()
        self.joinButtonTitleNode = ImmediateTextNode()
        self.joinButtonBackgroundNode = ASImageNode()
        self.joinButtonBackgroundNode.clipsToBounds = true
        self.joinButtonBackgroundNode.displaysAsynchronously = false
        self.joinButtonBackgroundNode.cornerRadius = 14.0
        
        self.micButton = HighlightTrackingButtonNode()
        self.micButtonForegroundNode = VoiceChatMicrophoneNode()
        self.micButtonBackgroundNode = ASImageNode()
        
        self.titleNode = ImmediateTextNode()
        self.textNode = ImmediateTextNode()
        
        self.muteIconNode = ASImageNode()
        
        self.avatarsContext = AnimatedAvatarSetContext()
        self.avatarsNode = AnimatedAvatarSetNode()

        self.backgroundNode = ASDisplayNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()

        self.addSubnode(self.contentNode)

        self.contentNode.addSubnode(self.backgroundNode)
        
        self.tapButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.contentNode.addSubnode(self.titleNode)
        self.contentNode.addSubnode(self.textNode)
        
        self.contentNode.addSubnode(self.avatarsNode)
        
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.contentNode.addSubnode(self.tapButton)
        
        self.joinButton.addSubnode(self.joinButtonBackgroundNode)
        self.joinButton.addSubnode(self.joinButtonTitleNode)
        self.contentNode.addSubnode(self.joinButton)
        self.joinButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        
        self.micButton.addSubnode(self.micButtonBackgroundNode)
        self.micButton.addSubnode(self.micButtonForegroundNode)
        self.contentNode.addSubnode(self.micButton)
        self.micButton.addTarget(self, action: #selector(self.micTapped), forControlEvents: [.touchUpInside])
        
        self.contentNode.addSubnode(self.separatorNode)
        
        self.updatePresentationData(presentationData)
    }
    
    deinit {
        self.membersDisposable.dispose()
        self.isMutedDisposable.dispose()
        self.audioLevelGeneratorTimer?.invalidate()
        self.updateTimer?.invalidate()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.micButtonPressGesture(_:)))
        longTapRecognizer.minimumPressDuration = 0.01
        self.micButton.view.addGestureRecognizer(longTapRecognizer)
    }
    
    @objc private func tapped() {
        self.tapAction()
    }
    
    @objc private func micTapped() {
        guard let call = self.currentData?.groupCall else {
            return
        }
        call.toggleIsMuted()
    }
    
    private var actionButtonPressGestureStartTime: Double = 0.0
    
    @objc private func micButtonPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let call = self.currentData?.groupCall, let callState = self.callState else {
            return
        }
        switch gestureRecognizer.state {
            case .began:
                self.hapticFeedback.impact(.veryLight)
                
                self.actionButtonPressGestureStartTime = CACurrentMediaTime()
                if callState.muteState != nil {
                    call.setIsMuted(action: .muted(isPushToTalkActive: true))
                }
            case .ended, .cancelled:
                self.hapticFeedback.impact(.veryLight)
                
                let timestamp = CACurrentMediaTime()
                if callState.muteState != nil || timestamp - self.actionButtonPressGestureStartTime < 0.1 {
                    call.toggleIsMuted()
                } else {
                    call.setIsMuted(action: .muted(isPushToTalkActive: false))
                }
            default:
                break
        }
    }
    
    public func updatePresentationData(_ presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.dateTimeFormat = presentationData.dateTimeFormat

        self.separatorNode.backgroundColor = presentationData.theme.chat.historyNavigation.strokeColor
        
        self.joinButtonTitleNode.attributedText = NSAttributedString(string: self.joinButtonTitleNode.attributedText?.string ?? "", font: Font.with(size: 15.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: self.isScheduled ? .white : presentationData.theme.chat.inputPanel.actionControlForegroundColor)
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: presentationData.theme.chat.inputPanel.secondaryTextColor)
        
        self.muteIconNode.image = PresentationResourcesChat.chatTitleMuteIcon(presentationData.theme)
        
        self.updateJoinButton()
        
        if let (size, leftInset, rightInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
        }
    }
    
    private func updateJoinButton() {
        if self.isScheduled {
            let purple = UIColor(rgb: 0x5d4ed1)
            let pink = UIColor(rgb: 0xea436f)
            let latePurple = UIColor(rgb: 0xaa56a6)
            let latePink = UIColor(rgb: 0xef476f)
            let colors: [UIColor]
            if self.isLate {
                colors = [latePurple, latePink]
            } else {
                colors = [purple, pink]
            }
            if self.joinButtonBackgroundNode.image != nil, let snapshotView = self.joinButtonBackgroundNode.view.snapshotContentTree() {
                self.joinButtonBackgroundNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.joinButtonBackgroundNode.view)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 1.0, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
            }
            
            self.joinButtonBackgroundNode.image = generateGradientImage(size: CGSize(width: 100.0, height: 1.0), colors: colors, locations: [0.0, 1.0], direction: .horizontal)
            self.joinButtonBackgroundNode.backgroundColor = nil
        } else {
            self.joinButtonBackgroundNode.image = nil
            self.joinButtonBackgroundNode.backgroundColor = self.theme.chat.inputPanel.actionControlFillColor
        }
    }
    
    private func animateTextChange() {
        if let snapshotView = self.textNode.view.snapshotContentTree() {
            let offset: CGFloat = self.textIsActive ? -7.0 : 7.0
            self.textNode.view.superview?.insertSubview(snapshotView, belowSubview: self.textNode.view)

            snapshotView.frame = self.textNode.frame
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
            snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -offset), duration: 0.2, removeOnCompletion: false, additive: true)
            
            self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.2, additive: true)
        }
    }
    
    public func update(data: GroupCallPanelData) {
        let previousData = self.currentData
        self.currentData = data
        
        var updateAudioLevels = false
        
        if previousData?.groupCall !== data.groupCall {
            let membersText: String
            if data.participantCount == 0 {
                membersText = self.strings.VoiceChat_Panel_TapToJoin
            } else if let groupCall = data.groupCall, groupCall.isStream {
                membersText = self.strings.LiveStream_ViewerCount(Int32(data.participantCount))
            } else {
                membersText = self.strings.VoiceChat_Panel_Members(Int32(data.participantCount))
            }
            self.currentText = membersText
            
            if data.info.isStream {
                self.avatarsContent = self.avatarsContext.update(peers: [], animated: false)
            } else {
                self.avatarsContent = self.avatarsContext.update(peers: data.topParticipants.map { EnginePeer($0.peer) }, animated: false)
            }
            
            self.textNode.attributedText = NSAttributedString(string: membersText, font: Font.regular(13.0), textColor: self.theme.chat.inputPanel.secondaryTextColor)
            
            self.callState = nil
            
            self.membersDisposable.set(nil)
            self.isMutedDisposable.set(nil)
            
            if let groupCall = data.groupCall {
                self.membersDisposable.set((groupCall.summaryState
                |> deliverOnMainQueue).start(next: { [weak self] summaryState in
                    guard let strongSelf = self, let summaryState = summaryState else {
                        return
                    }
                    
                    let membersText: String
                    if summaryState.participantCount == 0 {
                        membersText = strongSelf.strings.VoiceChat_Panel_TapToJoin
                    } else if let info = summaryState.info, info.isStream {
                        membersText = strongSelf.strings.LiveStream_ViewerCount(Int32(summaryState.participantCount))
                    } else {
                        membersText = strongSelf.strings.VoiceChat_Panel_Members(Int32(summaryState.participantCount))
                    }
                    strongSelf.currentText = membersText
                                                    
                    if let info = summaryState.info, info.isStream {
                        strongSelf.avatarsContent = strongSelf.avatarsContext.update(peers: [], animated: false)
                    } else {
                        strongSelf.avatarsContent = strongSelf.avatarsContext.update(peers: summaryState.topParticipants.map { EnginePeer($0.peer) }, animated: false)
                    }
                    
                    if let (size, leftInset, rightInset) = strongSelf.validLayout {
                        strongSelf.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                    }
                }))
                
                self.isMutedDisposable.set((groupCall.state
                |> deliverOnMainQueue).start(next: { [weak self] callState in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var transition: ContainedViewLayoutTransition = .immediate
                    if strongSelf.callState != nil {
                        transition = .animated(duration: 0.3, curve: .spring)
                    }
                    
                    strongSelf.callState = callState
                    
                    if let (size, leftInset, rightInset) = strongSelf.validLayout {
                        strongSelf.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: transition)
                    }
                }))
                
                self.audioLevelDisposable.set((groupCall.myAudioLevel
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if strongSelf.audioLevelView == nil {
                        let blobFrame = CGRect(origin: CGPoint(), size: CGSize(width: 36.0, height: 36.0)).insetBy(dx: -12.0, dy: -12.0)
                        
                        let audioLevelView = VoiceBlobView(
                            frame: blobFrame,
                            maxLevel: 0.3,
                            smallBlobRange: (0, 0),
                            mediumBlobRange: (0.7, 0.8),
                            bigBlobRange: (0.8, 0.9)
                        )
                        
                        let maskRect = CGRect(origin: .zero, size: blobFrame.size)
                        let playbackMaskLayer = CAShapeLayer()
                        playbackMaskLayer.frame = maskRect
                        playbackMaskLayer.fillRule = .evenOdd
                        let maskPath = UIBezierPath()
                        maskPath.append(UIBezierPath(roundedRect: maskRect.insetBy(dx: 12, dy: 12), cornerRadius: 22))
                        maskPath.append(UIBezierPath(rect: maskRect))
                        playbackMaskLayer.path = maskPath.cgPath
                        audioLevelView.layer.mask = playbackMaskLayer
                        
                        audioLevelView.setColor(UIColor(rgb: 0x30B251))
                        strongSelf.audioLevelView = audioLevelView
                        
                        strongSelf.micButton.view.insertSubview(audioLevelView, at: 0)
                    }
                    
                    strongSelf.audioLevelView?.updateLevel(CGFloat(value) * 2.0)
                    if value > 0.0 {
                        strongSelf.audioLevelView?.startAnimating()
                    } else {
                        strongSelf.audioLevelView?.stopAnimating(duration: 0.5)
                    }
                }))
            }
        } else if data.groupCall == nil {
            self.audioLevelDisposable.set(nil)
            
            let membersText: String
            if data.participantCount == 0 {
                membersText = self.strings.VoiceChat_Panel_TapToJoin
            } else if data.info.isStream {
                membersText = self.strings.LiveStream_ViewerCount(Int32(data.participantCount))
            } else {
                membersText = self.strings.VoiceChat_Panel_Members(Int32(data.participantCount))
            }
            self.currentText = membersText
            
            if data.info.isStream {
                self.avatarsContent = self.avatarsContext.update(peers: [], animated: false)
            } else {
                self.avatarsContent = self.avatarsContext.update(peers: data.topParticipants.map { EnginePeer($0.peer) }, animated: false)
            }
            
            updateAudioLevels = true
        }
        
        if let (size, leftInset, rightInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
        
        if updateAudioLevels {
            for peerId in data.activeSpeakers {
                if self.audioLevelGenerators[peerId] == nil {
                    self.audioLevelGenerators[peerId] = FakeAudioLevelGenerator()
                }
            }
            var removeGenerators: [PeerId] = []
            for peerId in self.audioLevelGenerators.keys {
                if !data.activeSpeakers.contains(peerId) {
                    removeGenerators.append(peerId)
                }
            }
            for peerId in removeGenerators {
                self.audioLevelGenerators.removeValue(forKey: peerId)
            }
            
            if self.audioLevelGenerators.isEmpty {
                self.audioLevelGeneratorTimer?.invalidate()
                self.audioLevelGeneratorTimer = nil
                self.avatarsNode.updateAudioLevels(color: self.theme.chat.inputPanel.actionControlFillColor, backgroundColor: self.theme.chat.inputPanel.actionControlFillColor, levels: [:])
            } else if self.audioLevelGeneratorTimer == nil {
                let audioLevelGeneratorTimer = SwiftSignalKit.Timer(timeout: 1.0 / 30.0, repeat: true, completion: { [weak self] in
                    self?.sampleAudioGenerators()
                }, queue: .mainQueue())
                self.audioLevelGeneratorTimer = audioLevelGeneratorTimer
                audioLevelGeneratorTimer.start()
            }
        }
    }
    
    private func sampleAudioGenerators() {
        var levels: [PeerId: Float] = [:]
        for (peerId, generator) in self.audioLevelGenerators {
            levels[peerId] = generator.get()
        }
        self.avatarsNode.updateAudioLevels(color: self.theme.chat.inputPanel.actionControlFillColor, backgroundColor: self.theme.chat.inputPanel.actionControlFillColor, levels: levels)
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset)
        
        let staticTransition: ContainedViewLayoutTransition = .immediate
        
        let panelHeight = size.height
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: size))
        
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width - 7.0 - 36.0 - 7.0, height: panelHeight))
        
        if let avatarsContent = self.avatarsContent {
            let avatarsSize = self.avatarsNode.update(context: self.context, content: avatarsContent, itemSize: CGSize(width: 32.0, height: 32.0), animated: true, synchronousLoad: true)
            transition.updateFrame(node: self.avatarsNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - avatarsSize.width) / 2.0), y: floor((size.height - avatarsSize.height) / 2.0)), size: avatarsSize))
        }
        
        var joinText = self.strings.VoiceChat_PanelJoin
        var title = self.strings.VoiceChat_Title
        var isChannel = false
        if let currentData = self.currentData {
            if currentData.isChannel || currentData.info.isStream {
                title = self.strings.VoiceChatChannel_Title
                isChannel = true
            }
        }
        var text = self.currentText
        var isScheduled = false
        var isLate = false
        if let scheduleTime = self.currentData?.info.scheduleTimestamp {
            isScheduled = true
            if let voiceChatTitle = self.currentData?.info.title {
                title = voiceChatTitle
                text = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: scheduleTime, alwaysShowTime: true, format: HumanReadableStringFormat(dateFormatString: { isChannel ? self.strings.Conversation_ScheduledLiveStreamStartsOn($0) : self.strings.Conversation_ScheduledVoiceChatStartsOn($0) }, tomorrowFormatString: { isChannel ? self.strings.Conversation_ScheduledLiveStreamStartsTomorrow($0) : self.strings.Conversation_ScheduledVoiceChatStartsTomorrow($0) }, todayFormatString: { isChannel ? self.strings.Conversation_ScheduledLiveStreamStartsToday($0) : self.strings.Conversation_ScheduledVoiceChatStartsToday($0) })).string
            } else {
                title = isChannel ? self.strings.Conversation_ScheduledLiveStream : self.strings.Conversation_ScheduledVoiceChat
                text = humanReadableStringForTimestamp(strings: self.strings, dateTimeFormat: self.dateTimeFormat, timestamp: scheduleTime, alwaysShowTime: true, format: HumanReadableStringFormat(dateFormatString: { self.strings.Conversation_ScheduledVoiceChatStartsOnShort($0) }, tomorrowFormatString: { self.strings.Conversation_ScheduledVoiceChatStartsTomorrowShort($0) }, todayFormatString: { self.strings.Conversation_ScheduledVoiceChatStartsTodayShort($0) })).string
            }
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let elapsedTime = scheduleTime - currentTime
            if elapsedTime >= 86400 {
                joinText = scheduledTimeIntervalString(strings: strings, value: elapsedTime)
            } else if elapsedTime < 0 {
                joinText = "-\(textForTimeout(value: abs(elapsedTime)))"
                isLate = true
            } else {
                joinText = textForTimeout(value: elapsedTime)
            }
            
            if self.updateTimer == nil {
                let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                    if let strongSelf = self, let (size, leftInset, rightInset) = strongSelf.validLayout {
                        strongSelf.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                    }
                }, queue: Queue.mainQueue())
                self.updateTimer = timer
                timer.start()
            }
        } else {
            if let timer = self.updateTimer {
                self.updateTimer = nil
                timer.invalidate()
            }
            if let voiceChatTitle = self.currentData?.info.title, voiceChatTitle.count < 15 {
                title = voiceChatTitle
            }
        }
        
        if self.isScheduled != isScheduled || self.isLate != isLate {
            self.isScheduled = isScheduled
            self.isLate = isLate
            self.updateJoinButton()
        }
        
        self.joinButtonTitleNode.attributedText = NSAttributedString(string: joinText.uppercased(), font: Font.with(size: 15.0, design: .round, weight: .semibold, traits: [.monospacedNumbers]), textColor: isScheduled ? .white : self.theme.chat.inputPanel.actionControlForegroundColor)
        
        let joinButtonTitleSize = self.joinButtonTitleNode.updateLayout(CGSize(width: 150.0, height: .greatestFiniteMagnitude))
        let joinButtonSize = CGSize(width: joinButtonTitleSize.width + 20.0, height: 28.0)
        let joinButtonFrame = CGRect(origin: CGPoint(x: size.width - rightInset - 7.0 - joinButtonSize.width, y: floor((panelHeight - joinButtonSize.height) / 2.0)), size: joinButtonSize)
        staticTransition.updateFrame(node: self.joinButton, frame: joinButtonFrame)
        staticTransition.updateFrame(node: self.joinButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: joinButtonFrame.size))
        staticTransition.updateFrame(node: self.joinButtonTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((joinButtonFrame.width - joinButtonTitleSize.width) / 2.0), y: floorToScreenPixels((joinButtonFrame.height - joinButtonTitleSize.height) / 2.0)), size: joinButtonTitleSize))
        
        let micButtonSize = CGSize(width: 36.0, height: 36.0)
        let micButtonFrame = CGRect(origin: CGPoint(x: size.width - rightInset - 7.0 - micButtonSize.width, y: floor((panelHeight - micButtonSize.height) / 2.0)), size: micButtonSize)
        staticTransition.updateFrame(node: self.micButton, frame: micButtonFrame)
        staticTransition.updateFrame(node: self.micButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: micButtonFrame.size))
        
        let animationSize = CGSize(width: 36.0, height: 36.0)
        staticTransition.updateFrame(node: self.micButtonForegroundNode, frame: CGRect(origin: CGPoint(x: floor((micButtonFrame.width - animationSize.width) / 2.0), y: floor((micButtonFrame.height - animationSize.height) / 2.0)), size: animationSize))
        
        var isMuted = true
        if let _ = self.callState?.muteState {
            isMuted = true
        } else {
            isMuted = false
        }
        self.micButtonForegroundNode.update(state: VoiceChatMicrophoneNode.State(muted: isMuted, filled: false, color: UIColor.white), animated: transition.isAnimated)
        
        if isMuted != self.micButtonBackgroundNodeIsMuted {
            self.micButtonBackgroundNodeIsMuted = isMuted
            let updatedImage = generateStretchableFilledCircleImage(diameter: 36.0, color: isMuted ? UIColor(rgb: 0xb6b6bb) : UIColor(rgb: 0x30b251))
            
            if let updatedImage = updatedImage, let previousImage = self.micButtonBackgroundNode.image?.cgImage, transition.isAnimated {
                self.micButtonBackgroundNode.image = updatedImage
                self.micButtonBackgroundNode.layer.animate(from: previousImage, to: updatedImage.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.25, delay: 0.0)
            } else {
                self.micButtonBackgroundNode.image = updatedImage
            }
        }
                
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(15.0), textColor: self.theme.chat.inputPanel.primaryTextColor)
        
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(13.0), textColor: self.theme.chat.inputPanel.secondaryTextColor)
        
        var constrainedWidth = size.width / 2.0 - 56.0
        if isScheduled {
            constrainedWidth = size.width - 100.0
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: constrainedWidth, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        
        let titleFrame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: 9.0), size: titleSize)
        staticTransition.updateFrame(node: self.titleNode, frame: titleFrame)
        staticTransition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: leftInset + 16.0, y: titleFrame.maxY + 1.0), size: textSize))
        
        if let image = self.muteIconNode.image {
            staticTransition.updateFrame(node: self.muteIconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: titleFrame.minY + 5.0), size: image.size))
        }
        self.muteIconNode.isHidden = self.currentData?.groupCall != nil
        self.joinButton.isHidden = self.currentData?.groupCall != nil
        self.micButton.isHidden = self.currentData?.groupCall == nil
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: panelHeight)))
    }
    
    public func animateIn(_ transition: ContainedViewLayoutTransition) {
        self.clipsToBounds = true
        let contentPosition = self.contentNode.layer.position
        transition.animatePosition(node: self.contentNode, from: CGPoint(x: contentPosition.x, y: contentPosition.y - 50.0), completion: { [weak self] _ in
            self?.clipsToBounds = false
        })

        guard let (size, _, _) = self.validLayout else {
            return
        }

        transition.animatePositionAdditive(node: self.separatorNode, offset: CGPoint(x: 0.0, y: size.height))
    }
    
    public func animateOut(_ transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.clipsToBounds = true
        let contentPosition = self.contentNode.layer.position
        transition.animatePosition(node: self.contentNode, to: CGPoint(x: contentPosition.x, y: contentPosition.y - 50.0), removeOnCompletion: false, completion: { [weak self] _ in
            self?.clipsToBounds = false
            completion()
        })

        guard let (size, _, _) = self.validLayout else {
            return
        }

        transition.updatePosition(node: self.separatorNode, position: self.separatorNode.position.offsetBy(dx: 0.0, dy: size.height))
    }
    
    func rightButtonSnapshotViews() -> (background: UIView, foreground: UIView)? {
        if !self.joinButton.isHidden {
            if let foregroundView = self.joinButtonTitleNode.view.snapshotContentTree() {
                let backgroundFrame = self.joinButtonBackgroundNode.view.convert(self.joinButtonBackgroundNode.bounds, to: nil)
                let foregroundFrame = self.joinButtonTitleNode.view.convert(self.joinButtonTitleNode.bounds, to: nil)
                
                let backgroundView = UIView()
                backgroundView.backgroundColor = self.theme.chat.inputPanel.actionControlFillColor
                backgroundView.frame = backgroundFrame
                backgroundView.layer.cornerRadius = backgroundFrame.height / 2.0
                    
                foregroundView.frame = foregroundFrame
                return (backgroundView, foregroundView)
            }
        } else if !self.micButton.isHidden {
            if let foregroundView = self.micButtonForegroundNode.view.snapshotContentTree() {
                let backgroundFrame = self.micButtonBackgroundNode.view.convert(self.micButtonBackgroundNode.bounds, to: nil)
                let foregroundFrame = self.micButtonForegroundNode.view.convert(self.micButtonForegroundNode.bounds, to: nil)
                
                let backgroundView = UIView()
                backgroundView.backgroundColor = (self.micButtonBackgroundNodeIsMuted ?? true) ? UIColor(rgb: 0xb6b6bb) : UIColor(rgb: 0x30b251)
                backgroundView.frame = backgroundFrame
                backgroundView.layer.cornerRadius = backgroundFrame.height / 2.0
                    
                foregroundView.frame = foregroundFrame
                return (backgroundView, foregroundView)
            }
        }
        
        return nil
    }
}
