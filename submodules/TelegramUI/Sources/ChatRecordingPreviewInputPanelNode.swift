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

extension AudioWaveformNode: CustomMediaPlayerScrubbingForegroundNode {
    
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
    
    private let waveformNode: AudioWaveformNode
    private let waveformForegroundNode: AudioWaveformNode
    let waveformScubberNode: MediaPlayerScrubbingNode
    
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
        self.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(theme), for: [])
        
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
        
        self.waveformScubberNode = MediaPlayerScrubbingNode(content: .custom(backgroundNode: self.waveformNode, foregroundContentNode: self.waveformForegroundNode))
        
        self.durationLabel = MediaPlayerTimeTextNode(textColor: theme.chat.inputPanel.actionControlForegroundColor)
        self.durationLabel.alignment = .right
        self.durationLabel.mode = .normal
        
        super.init()
        
        self.addSubnode(self.deleteButton)
        self.deleteButton.addSubnode(self.binNode)
        self.addSubnode(self.waveformBackgroundNode)
        self.addSubnode(self.sendButton)
        self.addSubnode(self.waveformScubberNode)
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
        gestureRecognizer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interfaceInteraction?.displaySendMessageOptions(strongSelf.sendButton, gesture)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            var updateWaveform = false
            if self.presentationInterfaceState?.recordedMediaPreview != interfaceState.recordedMediaPreview {
                updateWaveform = true
            }
            if self.presentationInterfaceState?.strings !== interfaceState.strings {
                self.deleteButton.accessibilityLabel = interfaceState.strings.VoiceOver_MessageContextDelete
                self.sendButton.accessibilityLabel = interfaceState.strings.VoiceOver_MessageContextSend
                self.waveformButton.accessibilityLabel = interfaceState.strings.VoiceOver_Chat_RecordPreviewVoiceMessage
            }
            self.presentationInterfaceState = interfaceState
            
            if let recordedMediaPreview = interfaceState.recordedMediaPreview, updateWaveform {
                self.waveformNode.setup(color: interfaceState.theme.chat.inputPanel.actionControlForegroundColor.withAlphaComponent(0.5), gravity: .center, waveform: recordedMediaPreview.waveform)
                self.waveformForegroundNode.setup(color: interfaceState.theme.chat.inputPanel.actionControlForegroundColor, gravity: .center, waveform: recordedMediaPreview.waveform)
                
                if self.mediaPlayer != nil {
                    self.mediaPlayer?.pause()
                }
                if let context = self.context {
                    let mediaManager = context.sharedContext.mediaManager
                    let mediaPlayer = MediaPlayer(audioSessionManager: mediaManager.audioSession, postbox: context.account.postbox, resourceReference: .standalone(resource: recordedMediaPreview.resource), streamable: .none, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true)
                    mediaPlayer.actionAtEnd = .action{ [weak mediaPlayer] in
                        mediaPlayer?.seek(timestamp: 0.0)
                    }
                    self.mediaPlayer = mediaPlayer
                    self.durationLabel.defaultDuration = Double(recordedMediaPreview.duration)
                    self.durationLabel.status = mediaPlayer.status
                    self.waveformScubberNode.status = mediaPlayer.status
                    self.statusDisposable.set((mediaPlayer.status
                        |> deliverOnMainQueue).start(next: { [weak self] status in
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
            }
        }
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        transition.updateFrame(node: self.deleteButton, frame: CGRect(origin: CGPoint(x: leftInset + 2.0 - UIScreenPixel, y: 1), size: CGSize(width: 40.0, height: 40)))
        transition.updateFrame(node: self.sendButton, frame: CGRect(origin: CGPoint(x: width - rightInset - 43.0 - UIScreenPixel, y: 2 - UIScreenPixel), size: CGSize(width: 44.0, height: 44)))
        self.binNode.frame = self.deleteButton.bounds
        
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
        transition.updateFrame(node: self.waveformScubberNode, frame: CGRect(origin: CGPoint(x: leftInset + 45.0 + 35.0, y: 7.0 + floor((33.0 - 13.0) / 2.0)), size: CGSize(width: width - leftInset - rightInset - 90.0 - 45.0 - 40.0, height: 13.0)))
        transition.updateFrame(node: self.durationLabel, frame: CGRect(origin: CGPoint(x: width - rightInset - 90.0 - 4.0, y: 15.0), size: CGSize(width: 35.0, height: 20.0)))
        
        prevInputPanelNode?.frame = CGRect(origin: .zero, size: CGSize(width: width, height: panelHeight))
        if let prevTextInputPanelNode = self.prevInputPanelNode as? ChatTextInputPanelNode {
            self.prevInputPanelNode = nil
            
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
            
            self.deleteButton.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15)
            self.deleteButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            
            self.playButton.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3, delay: 0.1)
            self.playButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1)
                        
            self.durationLabel.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, delay: 0.1)
            
            self.waveformScubberNode.layer.animateScaleY(from: 0.1, to: 1.0, duration: 0.3, delay: 0.1)
            self.waveformScubberNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.1)
            
            self.waveformBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            self.waveformBackgroundNode.layer.animateFrame(
                from: self.sendButton.frame.insetBy(dx: 5.5, dy: 5.5),
                to: waveformBackgroundFrame,
                duration: 0.2,
                delay: 0.12,
                timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue,
                removeOnCompletion: false
            ) { [weak self, weak prevTextInputPanelNode] finished in
                if finished, prevTextInputPanelNode?.supernode === self {
                    prevTextInputPanelNode?.removeFromSupernode()
                }
            }
        }
        
        return panelHeight
    }
    
    override func canHandleTransition(from prevInputPanelNode: ChatInputPanelNode?) -> Bool {
        return prevInputPanelNode is ChatTextInputPanelNode
    }
    
    @objc func deletePressed() {
        self.mediaPlayer?.pause()
        self.interfaceInteraction?.deleteRecordedMedia()
    }
    
    @objc func sendPressed() {
        self.interfaceInteraction?.sendRecordedMedia(false)
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
