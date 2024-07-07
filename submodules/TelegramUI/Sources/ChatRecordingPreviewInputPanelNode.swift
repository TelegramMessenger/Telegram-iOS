import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import UniversalMediaPlayer
import AppBundle
import ContextUI
import AnimationUI
import ManagedAnimationNode
import ChatPresentationInterfaceState
import ChatSendButtonRadialStatusNode
import AudioWaveformNode
import ChatInputPanelNode
import TooltipUI
import TelegramNotices
import ComponentFlow
import MediaScrubberComponent

//Xcode 16
#if canImport(ContactProvider)
extension AudioWaveformNode: @retroactive CustomMediaPlayerScrubbingForegroundNode {
}
#else
extension AudioWaveformNode: CustomMediaPlayerScrubbingForegroundNode {
}
#endif

final class ChatRecordingPreviewViewForOverlayContent: UIView, ChatInputPanelViewForOverlayContent {
    let ignoreHit: (UIView, CGPoint) -> Bool
    
    init(ignoreHit: @escaping (UIView, CGPoint) -> Bool) {
        self.ignoreHit = ignoreHit
        
        super.init(frame: CGRect())
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func maybeDismissContent(point: CGPoint) {
        for subview in self.subviews.reversed() {
            if let _ = subview.hitTest(self.convert(point, to: subview), with: nil) {
                return
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in self.subviews.reversed() {
            if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                return result
            }
        }
        
        if event == nil || self.ignoreHit(self, point) {
            return nil
        }
        
        return nil
    }
}

final class ChatRecordingPreviewInputPanelNode: ChatInputPanelNode {
    let deleteButton: HighlightableButtonNode
    let binNode: AnimationNode
    let sendButton: HighlightTrackingButtonNode
    private var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    let playButton: HighlightableButtonNode
    private let playPauseIconNode: PlayPauseIconNode
    private let waveformButton: ASButtonNode
    let waveformBackgroundNode: ASImageNode
    
    let scrubber = ComponentView<Empty>()
    
    var viewOnce = false
    let viewOnceButton: ChatRecordingViewOnceButtonNode
    let recordMoreButton: ChatRecordingViewOnceButtonNode

    private let waveformNode: AudioWaveformNode
    private let waveformForegroundNode: AudioWaveformNode
    let waveformScrubberNode: MediaPlayerScrubbingNode
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var mediaPlayer: MediaPlayer?
    let durationLabel: MediaPlayerTimeTextNode
    
    private let statusDisposable = MetaDisposable()
    
    private(set) var gestureRecognizer: ContextGesture?
    
    init(theme: PresentationTheme) {
        self.deleteButton = HighlightableButtonNode()
        self.deleteButton.displaysAsynchronously = false
        
        self.binNode = AnimationNode(
            animation: "BinBlue",
            colors: [
                "Cap11.Cap2.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
                "Bin 5.Bin.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
                "Cap12.Cap1.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
                "Line15.Line1.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
                "Line13.Line3.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
                "Line14.Line2.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
                "Line13.Обводка 1": theme.chat.inputPanel.panelControlAccentColor,
            ]
        )
        
        self.sendButton = HighlightTrackingButtonNode()
        self.sendButton.displaysAsynchronously = false
        self.sendButton.isExclusiveTouch = true
        self.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(theme), for: [])
        
        self.viewOnceButton = ChatRecordingViewOnceButtonNode(icon: .viewOnce)
        self.recordMoreButton = ChatRecordingViewOnceButtonNode(icon: .recordMore)
    
        self.waveformBackgroundNode = ASImageNode()
        self.waveformBackgroundNode.isLayerBacked = true
        self.waveformBackgroundNode.displaysAsynchronously = false
        self.waveformBackgroundNode.displayWithoutProcessing = true
        self.waveformBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 33.0, color: theme.chat.inputPanel.actionControlFillColor)
        
        self.playButton = HighlightableButtonNode()
        self.playButton.displaysAsynchronously = false
        
        self.playPauseIconNode = PlayPauseIconNode()
        self.playPauseIconNode.enqueueState(.play, animated: false)
        self.playPauseIconNode.customColor = theme.chat.inputPanel.actionControlForegroundColor
        
        self.waveformButton = ASButtonNode()
        self.waveformButton.accessibilityTraits.insert(.startsMediaSession)
        
        self.waveformNode = AudioWaveformNode()
        self.waveformNode.isLayerBacked = true
        self.waveformForegroundNode = AudioWaveformNode()
        self.waveformForegroundNode.isLayerBacked = true
        
        self.waveformScrubberNode = MediaPlayerScrubbingNode(content: .custom(backgroundNode: self.waveformNode, foregroundContentNode: self.waveformForegroundNode))
        
        self.durationLabel = MediaPlayerTimeTextNode(textColor: theme.chat.inputPanel.actionControlForegroundColor)
        self.durationLabel.alignment = .right
        self.durationLabel.mode = .normal
        
        super.init()
        
        self.viewForOverlayContent = ChatRecordingPreviewViewForOverlayContent(
            ignoreHit: { [weak self] view, point in
                guard let strongSelf = self else {
                    return false
                }
                if strongSelf.view.hitTest(view.convert(point, to: strongSelf.view), with: nil) != nil {
                    return true
                }
                if view.convert(point, to: strongSelf.view).y > strongSelf.view.bounds.maxY {
                    return true
                }
                return false
            }
        )
        
        self.addSubnode(self.deleteButton)
        self.deleteButton.addSubnode(self.binNode)
        self.addSubnode(self.waveformBackgroundNode)
        self.addSubnode(self.sendButton)
        self.addSubnode(self.waveformScrubberNode)
        self.addSubnode(self.playButton)
        self.addSubnode(self.durationLabel)
        self.addSubnode(self.waveformButton)
        self.playButton.addSubnode(self.playPauseIconNode)
        
        self.sendButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.sendButton.layer.animateScale(from: 1.0, to: 0.75, duration: 0.4, removeOnCompletion: false)
                } else if let presentationLayer = strongSelf.sendButton.layer.presentation() {
                    strongSelf.sendButton.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                }
            }
        }
                
        self.deleteButton.addTarget(self, action: #selector(self.deletePressed), forControlEvents: [.touchUpInside])
        self.sendButton.addTarget(self, action: #selector(self.sendPressed), forControlEvents: [.touchUpInside])
        self.viewOnceButton.addTarget(self, action: #selector(self.viewOncePressed), forControlEvents: [.touchUpInside])
        self.recordMoreButton.addTarget(self, action: #selector(self.recordMorePressed), forControlEvents: [.touchUpInside])
        
        self.waveformButton.addTarget(self, action: #selector(self.waveformPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.mediaPlayer?.pause()
        self.statusDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = ContextGesture(target: nil, action: nil)
        self.sendButton.view.addGestureRecognizer(gestureRecognizer)
        self.gestureRecognizer = gestureRecognizer
        gestureRecognizer.shouldBegin = { [weak self] _ in
            if let self, self.viewOnce {
                return false
            }
            return true
        }
        gestureRecognizer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interfaceInteraction?.displaySendMessageOptions(strongSelf.sendButton, gesture)
        }
        
        if let viewForOverlayContent = self.viewForOverlayContent {
            viewForOverlayContent.addSubnode(self.viewOnceButton)
            viewForOverlayContent.addSubnode(self.recordMoreButton)
        }
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    private func maybePresentViewOnceTooltip() {
        guard let context = self.context else {
            return
        }
        let _ = (ApplicationSpecificNotice.getVoiceMessagesPlayOnceSuggestion(accountManager: context.sharedContext.accountManager)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
            guard let self, let interfaceState = self.presentationInterfaceState else {
                return
            }
            if counter >= 3 {
                return
            }

            Queue.mainQueue().after(0.3) {
                self.displayViewOnceTooltip(text: interfaceState.strings.Chat_TapToPlayVoiceMessageOnceTooltip, hasIcon: true)
            }
        
            let _ = ApplicationSpecificNotice.incrementVoiceMessagesPlayOnceSuggestion(accountManager: context.sharedContext.accountManager).startStandalone()
        })
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        var isFirstTime = false
        if self.presentationInterfaceState == nil {
            isFirstTime = true
        }
        if self.presentationInterfaceState != interfaceState {
            var updateWaveform = false
            if self.presentationInterfaceState?.interfaceState.mediaDraftState != interfaceState.interfaceState.mediaDraftState {
                updateWaveform = true
            }
            if self.presentationInterfaceState?.strings !== interfaceState.strings {
                self.deleteButton.accessibilityLabel = interfaceState.strings.VoiceOver_MessageContextDelete
                self.sendButton.accessibilityLabel = interfaceState.strings.VoiceOver_MessageContextSend
                self.waveformButton.accessibilityLabel = interfaceState.strings.VoiceOver_Chat_RecordPreviewVoiceMessage
            }
            
            self.presentationInterfaceState = interfaceState
                    
            if let recordedMediaPreview = interfaceState.interfaceState.mediaDraftState, let context = self.context {
                switch recordedMediaPreview {
                case let .audio(audio):
                    self.waveformButton.isHidden = false
                    self.waveformBackgroundNode.isHidden = false
                    self.waveformForegroundNode.isHidden = false
                    self.waveformScrubberNode.isHidden = false
                    self.playButton.isHidden = false
                    self.durationLabel.isHidden = false
                    
                    if let view = self.scrubber.view, view.superview != nil {
                        view.removeFromSuperview()
                    }
                    
                    if updateWaveform {
                        self.waveformNode.setup(color: interfaceState.theme.chat.inputPanel.actionControlForegroundColor.withAlphaComponent(0.5), gravity: .center, waveform: audio.waveform)
                        self.waveformForegroundNode.setup(color: interfaceState.theme.chat.inputPanel.actionControlForegroundColor, gravity: .center, waveform: audio.waveform)
                        if self.mediaPlayer != nil {
                            self.mediaPlayer?.pause()
                        }
                        let mediaManager = context.sharedContext.mediaManager
                        let mediaPlayer = MediaPlayer(audioSessionManager: mediaManager.audioSession, postbox: context.account.postbox, userLocation: .other, userContentType: .audio, resourceReference: .standalone(resource: audio.resource), streamable: .none, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true)
                        mediaPlayer.actionAtEnd = .action { [weak mediaPlayer] in
                            mediaPlayer?.seek(timestamp: 0.0)
                        }
                        self.mediaPlayer = mediaPlayer
                        self.durationLabel.defaultDuration = Double(audio.duration)
                        self.durationLabel.status = mediaPlayer.status
                        self.waveformScrubberNode.status = mediaPlayer.status
                        self.statusDisposable.set((mediaPlayer.status
                        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                            if let strongSelf = self {
                                switch status.status {
                                case .playing, .buffering(_, true, _, _):
                                    strongSelf.playPauseIconNode.enqueueState(.pause, animated: true)
                                default:
                                    strongSelf.playPauseIconNode.enqueueState(.play, animated: true)
                                }
                            }
                        }))
                    }
                case let .video(video):
                    self.waveformButton.isHidden = true
                    self.waveformBackgroundNode.isHidden = true
                    self.waveformForegroundNode.isHidden = true
                    self.waveformScrubberNode.isHidden = true
                    self.playButton.isHidden = true
                    self.durationLabel.isHidden = true
                    
                    let scrubberSize = self.scrubber.update(
                        transition: .immediate,
                        component: AnyComponent(
                            MediaScrubberComponent(
                                context: context,
                                style: .videoMessage,
                                theme: interfaceState.theme,
                                generationTimestamp: 0,
                                position: 0,
                                minDuration: 1.0,
                                maxDuration: 60.0,
                                isPlaying: false,
                                tracks: [
                                    MediaScrubberComponent.Track(
                                        id: 0,
                                        content: .video(frames: video.frames, framesUpdateTimestamp: video.framesUpdateTimestamp),
                                        duration: Double(video.duration),
                                        trimRange: video.trimRange,
                                        offset: nil,
                                        isMain: true
                                    )
                                ],
                                positionUpdated: { _, _ in },
                                trackTrimUpdated: { [weak self] _, start, end, updatedEnd, apply in
                                    if let self {
                                        self.interfaceInteraction?.updateVideoTrimRange(start, end, updatedEnd, apply)
                                    }
                                },
                                trackOffsetUpdated: { _, _, _ in },
                                trackLongPressed: { _, _ in }
                            )
                        ),
                        environment: {},
                        forceUpdate: false,
                        containerSize: CGSize(width: min(424, width - leftInset - rightInset - 45.0 * 2.0), height: 33.0)
                    )

                    if let view = self.scrubber.view {
                        if view.superview == nil {
                            self.view.addSubview(view)
                        }
                        view.bounds = CGRect(origin: .zero, size: scrubberSize)
                    }
                }
            }
        }
        
        if let view = self.scrubber.view {
            view.frame = CGRect(origin: CGPoint(x: max(leftInset + 45.0, floorToScreenPixels((width - view.bounds.width) / 2.0)), y: 7.0 - UIScreenPixel), size: view.bounds.size)
        }
                
        let panelHeight = defaultHeight(metrics: metrics)

        transition.updateFrame(node: self.deleteButton, frame: CGRect(origin: CGPoint(x: leftInset + 2.0 - UIScreenPixel, y: 1), size: CGSize(width: 40.0, height: 40)))
        transition.updateFrame(node: self.sendButton, frame: CGRect(origin: CGPoint(x: width - rightInset - 43.0 - UIScreenPixel, y: 2 - UIScreenPixel), size: CGSize(width: 44.0, height: 44)))
        self.binNode.frame = self.deleteButton.bounds
        
        var viewOnceOffset: CGFloat = 0.0
        if interfaceState.interfaceState.replyMessageSubject != nil {
            viewOnceOffset = -35.0
        }
        
        let viewOnceSize = self.viewOnceButton.update(theme: interfaceState.theme)
        let viewOnceButtonFrame = CGRect(origin: CGPoint(x: width - rightInset - 44.0 - UIScreenPixel, y: -64.0 - 53.0 + viewOnceOffset), size: viewOnceSize)
        transition.updateFrame(node: self.viewOnceButton, frame: viewOnceButtonFrame)
        
        let recordMoreSize = self.recordMoreButton.update(theme: interfaceState.theme)
        let recordMoreButtonFrame = CGRect(origin: CGPoint(x: width - rightInset - 44.0 - UIScreenPixel, y: -64.0 + viewOnceOffset), size: recordMoreSize)
        transition.updateFrame(node: self.recordMoreButton, frame: recordMoreButtonFrame)
        
        var isScheduledMessages = false
        if case .scheduledMessages = interfaceState.subject {
            isScheduledMessages = true
        }
        
        if let slowmodeState = interfaceState.slowmodeState, !isScheduledMessages {
            let sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode
            if let current = self.sendButtonRadialStatusNode {
                sendButtonRadialStatusNode = current
            } else {
                sendButtonRadialStatusNode = ChatSendButtonRadialStatusNode(color: interfaceState.theme.chat.inputPanel.panelControlAccentColor)
                sendButtonRadialStatusNode.alpha = self.sendButton.alpha
                self.sendButtonRadialStatusNode = sendButtonRadialStatusNode
                self.addSubnode(sendButtonRadialStatusNode)
            }
            
            transition.updateSublayerTransformScale(layer: self.sendButton.layer, scale: CGPoint(x: 0.7575, y: 0.7575))
            
            sendButtonRadialStatusNode.frame = CGRect(origin: CGPoint(x: self.sendButton.frame.midX - 33.0 / 2.0, y: self.sendButton.frame.midY - 33.0 / 2.0), size: CGSize(width: 33.0, height: 33.0))
            sendButtonRadialStatusNode.slowmodeState = slowmodeState
        } else {
            if let sendButtonRadialStatusNode = self.sendButtonRadialStatusNode {
                self.sendButtonRadialStatusNode = nil
                sendButtonRadialStatusNode.removeFromSupernode()
            }
            transition.updateSublayerTransformScale(layer: self.sendButton.layer, scale: CGPoint(x: 1.0, y: 1.0))
        }
        
        transition.updateFrame(node: self.playButton, frame: CGRect(origin: CGPoint(x: leftInset + 52.0, y: 10.0), size: CGSize(width: 26.0, height: 26.0)))
        self.playPauseIconNode.frame = CGRect(origin: CGPoint(x: -2.0, y: -1.0), size: CGSize(width: 26.0, height: 26.0))

        let waveformBackgroundFrame = CGRect(origin: CGPoint(x: leftInset + 45.0, y: 7.0 - UIScreenPixel), size: CGSize(width: width - leftInset - rightInset - 90.0, height: 33.0))
        transition.updateFrame(node: self.waveformBackgroundNode, frame: waveformBackgroundFrame)
        transition.updateFrame(node: self.waveformButton, frame: CGRect(origin: CGPoint(x: leftInset + 45.0, y: 0.0), size: CGSize(width: width - leftInset - rightInset - 90.0, height: panelHeight)))
        transition.updateFrame(node: self.waveformScrubberNode, frame: CGRect(origin: CGPoint(x: leftInset + 45.0 + 35.0, y: 7.0 + floor((33.0 - 13.0) / 2.0)), size: CGSize(width: width - leftInset - rightInset - 90.0 - 45.0 - 40.0, height: 13.0)))
        transition.updateFrame(node: self.durationLabel, frame: CGRect(origin: CGPoint(x: width - rightInset - 90.0 - 4.0, y: 15.0), size: CGSize(width: 35.0, height: 20.0)))
        
        prevInputPanelNode?.frame = CGRect(origin: .zero, size: CGSize(width: width, height: panelHeight))
        if let prevTextInputPanelNode = self.prevInputPanelNode as? ChatTextInputPanelNode {
            self.prevInputPanelNode = nil
            
            self.viewOnceButton.isHidden = prevTextInputPanelNode.viewOnceButton.isHidden
            self.viewOnce = prevTextInputPanelNode.viewOnce
            self.viewOnceButton.update(isSelected: self.viewOnce, animated: false)
            
            prevTextInputPanelNode.viewOnceButton.isHidden = true
            prevTextInputPanelNode.viewOnce = false
            
            self.recordMoreButton.isEnabled = false
            self.viewOnceButton.layer.animatePosition(from: prevTextInputPanelNode.viewOnceButton.position, to: self.viewOnceButton.position, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                prevTextInputPanelNode.viewOnceButton.isHidden = false
                prevTextInputPanelNode.viewOnceButton.update(isSelected: false, animated: false)
                
                Queue.mainQueue().after(0.3) {
                    self.recordMoreButton.isEnabled = true
                }
            })
            
            self.recordMoreButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.recordMoreButton.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            
            if let audioRecordingDotNode = prevTextInputPanelNode.audioRecordingDotNode {
                let startAlpha = CGFloat(audioRecordingDotNode.layer.presentation()?.opacity ?? 1.0)
                audioRecordingDotNode.layer.removeAllAnimations()
                audioRecordingDotNode.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false)
                audioRecordingDotNode.layer.animateAlpha(from: startAlpha, to: 0.0, duration: 0.15, removeOnCompletion: false)
            }
            
            if let audioRecordingTimeNode = prevTextInputPanelNode.audioRecordingTimeNode {
                audioRecordingTimeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
                audioRecordingTimeNode.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false)
                let timePosition = audioRecordingTimeNode.position
                audioRecordingTimeNode.layer.animatePosition(from: timePosition, to: CGPoint(x: timePosition.x - 20, y: timePosition.y), duration: 0.15, removeOnCompletion: false)
            }
            
            if let audioRecordingCancelIndicator = prevTextInputPanelNode.audioRecordingCancelIndicator {
                audioRecordingCancelIndicator.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
            }
            
            prevTextInputPanelNode.actionButtons.micButton.animateOut(true)
            
            if let view = self.scrubber.view {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                view.layer.animatePosition(from: CGPoint(x: 0.0, y: 64.0), to: .zero, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            
            self.deleteButton.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15)
            self.deleteButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            
            self.playButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3, delay: 0.1)
            self.playButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1)
                        
            self.durationLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, delay: 0.1)
            
            self.waveformScrubberNode.layer.animateScaleY(from: 0.1, to: 1.0, duration: 0.3, delay: 0.1)
            self.waveformScrubberNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1)
            
            self.waveformBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            self.waveformBackgroundNode.layer.animateFrame(
                from: self.sendButton.frame.insetBy(dx: 5.5, dy: 5.5),
                to: waveformBackgroundFrame,
                duration: 0.2,
                delay: 0.12,
                timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue,
                removeOnCompletion: false
            ) { [weak self, weak prevTextInputPanelNode] finished in
                if prevTextInputPanelNode?.supernode === self {
                    prevTextInputPanelNode?.removeFromSupernode()
                    prevTextInputPanelNode?.finishedTransitionToPreview = true
                    prevTextInputPanelNode?.requestLayout()
                }
            }
        }
        
        if isFirstTime, !self.viewOnceButton.isHidden {
            self.maybePresentViewOnceTooltip()
        }
        
        return panelHeight
    }
    
    override func canHandleTransition(from prevInputPanelNode: ChatInputPanelNode?) -> Bool {
        return prevInputPanelNode is ChatTextInputPanelNode
    }
    
    @objc func deletePressed() {
        self.viewOnce = false
        self.tooltipController?.dismiss()
        
        self.mediaPlayer?.pause()
        self.interfaceInteraction?.deleteRecordedMedia()
    }
    
    @objc func sendPressed() {
        self.tooltipController?.dismiss()
        
        self.interfaceInteraction?.sendRecordedMedia(false, self.viewOnce)
        
        self.viewOnce = false
    }
    
    private weak var tooltipController: TooltipScreen?
    @objc private func viewOncePressed() {
        guard let context = self.context, let interfaceState = self.presentationInterfaceState else {
            return
        }
        self.viewOnce = !self.viewOnce
    
        self.viewOnceButton.update(isSelected: self.viewOnce, animated: true)
        
        self.tooltipController?.dismiss()
        if self.viewOnce {
            self.displayViewOnceTooltip(text: interfaceState.strings.Chat_PlayVoiceMessageOnceTooltip, hasIcon: true)
            
            let _ = ApplicationSpecificNotice.incrementVoiceMessagesPlayOnceSuggestion(accountManager: context.sharedContext.accountManager, count: 3).startStandalone()
        }
    }
    
    @objc private func recordMorePressed() {
        self.tooltipController?.dismiss()
        
        self.interfaceInteraction?.resumeMediaRecording()
    }
    
    private func displayViewOnceTooltip(text: String, hasIcon: Bool) {
        guard let context = self.context, let parentController = self.interfaceInteraction?.chatController() else {
            return
        }
        
        let absoluteFrame = self.viewOnceButton.view.convert(self.viewOnceButton.bounds, to: parentController.view)
        let location = CGRect(origin: CGPoint(x: absoluteFrame.midX - 20.0, y: absoluteFrame.midY), size: CGSize())
        
        let tooltipController = TooltipScreen(
            account: context.account,
            sharedContext: context.sharedContext,
            text: .markdown(text: text),
            balancedTextLayout: true,
            constrainWidth: 240.0,
            style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
            arrowStyle: .small,
            icon: hasIcon ? .animation(name: "anim_autoremove_on", delay: 0.1, tintColor: nil) : nil,
            location: .point(location, .right),
            displayDuration: .default,
            inset: 8.0,
            cornerRadius: 8.0,
            shouldDismissOnTouch: { _, _ in
                return .ignore
            }
        )
        self.tooltipController = tooltipController
        
        parentController.present(tooltipController, in: .current)
    }
    
    @objc func waveformPressed() {
        self.mediaPlayer?.togglePlayPause()
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
    
    func frameForInputActionButton() -> CGRect? {
        return self.sendButton.frame
    }
}

private enum PlayPauseIconNodeState: Equatable {
    case play
    case pause
}

private final class PlayPauseIconNode: ManagedAnimationNode {
    private let duration: Double = 0.35
    private var iconState: PlayPauseIconNodeState = .pause
    
    init() {
        super.init(size: CGSize(width: 28.0, height: 28.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
    }
    
    func enqueueState(_ state: PlayPauseIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .pause:
                switch state {
                    case .play:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 83), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .pause:
                        break
                }
            case .play:
                switch state {
                    case .pause:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 41), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
                        }
                    case .play:
                        break
                }
        }
    }
}


final class ChatRecordingViewOnceButtonNode: HighlightTrackingButtonNode {
    enum Icon {
        case viewOnce
        case recordMore
    }
    
    private let icon: Icon
    
    private let backgroundNode: ASImageNode
    private let iconNode: ASImageNode
    
    private var theme: PresentationTheme?
        
    init(icon: Icon) {
        self.icon = icon
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isUserInteractionEnabled = false
        
        super.init(pointerStyle: .default)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let self, self.bounds.width > 0.0 {
                let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                
                if highlighted {
                    self.layer.removeAnimation(forKey: "sublayerTransform")
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                    transition.updateTransformScale(node: self, scale: topScale)
                } else {
                    let transition = ContainedViewLayoutTransition.immediate
                    transition.updateTransformScale(node: self, scale: 1.0)
                    
                    self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        
                        self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                    })
                }
            }
        }
    }
    
    private var innerIsSelected = false
    func update(isSelected: Bool, animated: Bool = false) {
        guard let theme = self.theme else {
            return
        }
        
        let updated = self.iconNode.image == nil || self.innerIsSelected != isSelected
        self.innerIsSelected = isSelected
        
        if animated, updated && self.iconNode.image != nil, let snapshot = self.iconNode.view.snapshotContentTree() {
            self.view.addSubview(snapshot)
            snapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                snapshot.removeFromSuperview()
            })
            
            self.iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        if updated {
            if case .viewOnce = self.icon {
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: self.innerIsSelected ? "Media Gallery/ViewOnceEnabled" : "Media Gallery/ViewOnce"), color: theme.chat.inputPanel.panelControlAccentColor)
            }
        }
    }
    
    func update(theme: PresentationTheme) -> CGSize {
        let size = CGSize(width: 44.0, height: 44.0)
        let innerSize = CGSize(width: 40.0, height: 40.0)
        
        if self.theme !== theme {
            self.theme = theme
            
            self.backgroundNode.image = generateFilledCircleImage(diameter: innerSize.width, color: theme.rootController.navigationBar.opaqueBackgroundColor, strokeColor: theme.chat.inputPanel.panelSeparatorColor, strokeWidth: 0.5, backgroundColor: nil)
            
            switch self.icon {
            case .viewOnce:
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: self.innerIsSelected ? "Media Gallery/ViewOnceEnabled" : "Media Gallery/ViewOnce"), color: theme.chat.inputPanel.panelControlAccentColor)
                
            case .recordMore:
                self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/IconMicrophone"), color: theme.chat.inputPanel.panelControlAccentColor)
            }
        }
        
        if let backgroundImage = self.backgroundNode.image {
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(size.width / 2.0 - backgroundImage.size.width / 2.0), y: floorToScreenPixels(size.height / 2.0 - backgroundImage.size.height / 2.0)), size: backgroundImage.size)
            self.backgroundNode.frame = backgroundFrame
        }

        if let iconImage = self.iconNode.image {
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(size.width / 2.0 - iconImage.size.width / 2.0), y: floorToScreenPixels(size.height / 2.0 - iconImage.size.height / 2.0)), size: iconImage.size)
            self.iconNode.frame = iconFrame
        }
        return size
    }
}
