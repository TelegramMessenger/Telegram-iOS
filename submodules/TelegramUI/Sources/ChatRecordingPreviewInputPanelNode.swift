import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import UniversalMediaPlayer
import AppBundle
import ContextUI

private func generatePauseIcon(_ theme: PresentationTheme) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPause"), color: theme.chat.inputPanel.actionControlForegroundColor)
}

private func generatePlayIcon(_ theme: PresentationTheme) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPlay"), color: theme.chat.inputPanel.actionControlForegroundColor)
}

final class ChatRecordingPreviewInputPanelNode: ChatInputPanelNode {
    private let deleteButton: HighlightableButtonNode
    let sendButton: HighlightTrackingButtonNode
    private var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    private let playButton: HighlightableButtonNode
    private let pauseButton: HighlightableButtonNode
    private let waveformButton: ASButtonNode
    private let waveformBackgroundNode: ASImageNode
    
    private let waveformNode: AudioWaveformNode
    private let waveformForegroundNode: AudioWaveformNode
    private let waveformScubberNode: MediaPlayerScrubbingNode
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var mediaPlayer: MediaPlayer?
    private let durationLabel: MediaPlayerTimeTextNode
    
    private let statusDisposable = MetaDisposable()
    
    private var gestureRecognizer: ContextGesture?
    
    init(theme: PresentationTheme) {
        self.deleteButton = HighlightableButtonNode()
        self.deleteButton.displaysAsynchronously = false
        self.deleteButton.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor), for: [])
        
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
        self.playButton.setImage(generatePlayIcon(theme), for: [])
        self.playButton.isUserInteractionEnabled = false
        self.pauseButton = HighlightableButtonNode()
        self.pauseButton.displaysAsynchronously = false
        self.pauseButton.setImage(generatePauseIcon(theme), for: [])
        self.pauseButton.isHidden = true
        self.pauseButton.isUserInteractionEnabled = false
        
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
        self.addSubnode(self.sendButton)
        self.addSubnode(self.waveformBackgroundNode)
        self.addSubnode(self.waveformScubberNode)
        self.addSubnode(self.playButton)
        self.addSubnode(self.pauseButton)
        self.addSubnode(self.durationLabel)
        self.addSubnode(self.waveformButton)
        
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
        gestureRecognizer.activated = { [weak self] gesture in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interfaceInteraction?.displaySendMessageOptions(strongSelf.sendButton, gesture)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
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
                self.waveformNode.setup(color: interfaceState.theme.chat.inputPanel.actionControlForegroundColor.withAlphaComponent(0.5), waveform: recordedMediaPreview.waveform)
                self.waveformForegroundNode.setup(color: interfaceState.theme.chat.inputPanel.actionControlForegroundColor, waveform: recordedMediaPreview.waveform)
                
                if self.mediaPlayer != nil {
                    self.mediaPlayer?.pause()
                }
                if let context = self.context {
                    let mediaManager = context.sharedContext.mediaManager
                    let mediaPlayer = MediaPlayer(audioSessionManager: mediaManager.audioSession, postbox: context.account.postbox, resourceReference: .standalone(resource: recordedMediaPreview.resource), streamable: .none, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true)
                    self.mediaPlayer = mediaPlayer
                    self.durationLabel.defaultDuration = Double(recordedMediaPreview.duration)
                    self.durationLabel.status = mediaPlayer.status
                    self.waveformScubberNode.status = mediaPlayer.status
                    self.statusDisposable.set((mediaPlayer.status
                        |> deliverOnMainQueue).start(next: { [weak self] status in
                        if let strongSelf = self {
                            switch status.status {
                                case .playing, .buffering(_, true):
                                    strongSelf.playButton.isHidden = true
                                default:
                                    strongSelf.playButton.isHidden = false
                            }
                            strongSelf.pauseButton.isHidden = !strongSelf.playButton.isHidden
                        }
                    }))
                }
            }
        }
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        transition.updateFrame(node: self.deleteButton, frame: CGRect(origin: CGPoint(x: leftInset, y: -1.0), size: CGSize(width: 48.0, height: panelHeight)))
        transition.updateFrame(node: self.sendButton, frame: CGRect(origin: CGPoint(x: width - rightInset - 43.0 - UIScreenPixel, y: -UIScreenPixel), size: CGSize(width: 44.0, height: panelHeight)))
        
        if let slowmodeState = interfaceState.slowmodeState, !interfaceState.isScheduledMessages {
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
        transition.updateFrame(node: self.pauseButton, frame: CGRect(origin: CGPoint(x: leftInset + 50.0, y: 10.0), size: CGSize(width: 26.0, height: 26.0)))
        transition.updateFrame(node: self.waveformBackgroundNode, frame: CGRect(origin: CGPoint(x: leftInset + 45.0, y: 7.0 - UIScreenPixel), size: CGSize(width: width - leftInset - rightInset - 90.0, height: 33.0)))
        transition.updateFrame(node: self.waveformButton, frame: CGRect(origin: CGPoint(x: leftInset + 45.0, y: 0.0), size: CGSize(width: width - leftInset - rightInset - 90.0, height: panelHeight)))
        transition.updateFrame(node: self.waveformScubberNode, frame: CGRect(origin: CGPoint(x: leftInset + 45.0 + 35.0, y: 7.0 + floor((33.0 - 13.0) / 2.0)), size: CGSize(width: width - leftInset - rightInset - 90.0 - 45.0 - 40.0, height: 13.0)))
        transition.updateFrame(node: self.durationLabel, frame: CGRect(origin: CGPoint(x: width - rightInset - 90.0 - 4.0, y: 15.0), size: CGSize(width: 35.0, height: 20.0)))
        
        return panelHeight
    }
    
    @objc func deletePressed() {
        self.interfaceInteraction?.deleteRecordedMedia()
    }
    
    @objc func sendPressed() {
        self.interfaceInteraction?.sendRecordedMedia()
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.deleteButton.frame.contains(point) {
            return self.deleteButton.view
        }
        if self.sendButton.frame.contains(point) {
           return self.sendButton.view
        }
        return super.hitTest(point, with: event)
    }
}

