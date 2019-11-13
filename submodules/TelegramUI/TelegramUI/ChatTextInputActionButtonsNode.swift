import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ContextUI

final class ChatTextInputActionButtonsNode: ASDisplayNode {
    private let strings: PresentationStrings
    
    let micButton: ChatTextInputMediaRecordingButton
    let sendButton: HighlightTrackingButtonNode
    var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    var sendButtonHasApplyIcon = false
    var animatingSendButton = false
    let expandMediaInputButton: HighlightableButtonNode
    
    var sendButtonLongPressed: ((ASDisplayNode, ContextGesture) -> Void)?
    
    private var gestureRecognizer: ContextGesture?
    var sendButtonLongPressEnabled = false {
        didSet {
            self.gestureRecognizer?.isEnabled = self.sendButtonLongPressEnabled
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, presentController: @escaping (ViewController) -> Void) {
        self.strings = strings
        
        self.micButton = ChatTextInputMediaRecordingButton(theme: theme, presentController: presentController)
        self.sendButton = HighlightTrackingButtonNode()
        //self.sendButton.adjustsImageWhenHighlighted = false
        //self.sendButton.adjustsImageWhenDisabled = false
        
        self.expandMediaInputButton = HighlightableButtonNode()
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button, .notEnabled]
        
        self.sendButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if strongSelf.sendButtonHasApplyIcon || !strongSelf.sendButtonLongPressEnabled {
                    if highlighted {
                        strongSelf.layer.removeAnimation(forKey: "opacity")
                        strongSelf.alpha = 0.4
                    } else {
                        strongSelf.alpha = 1.0
                        strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                } else {
                    if highlighted {
                        strongSelf.sendButton.layer.animateScale(from: 1.0, to: 0.75, duration: 0.4, removeOnCompletion: false)
                    } else if let presentationLayer = strongSelf.sendButton.layer.presentation() {
                        strongSelf.sendButton.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                    }
                }
            }
        }
        
        self.view.addSubview(self.micButton)
        self.addSubnode(self.sendButton)
        self.addSubnode(self.expandMediaInputButton)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = ContextGesture(target: nil, action: nil)
        self.gestureRecognizer = gestureRecognizer
        self.sendButton.view.addGestureRecognizer(gestureRecognizer)
        gestureRecognizer.activated = { [weak self] recognizer in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.sendButtonHasApplyIcon {
                strongSelf.sendButtonLongPressed?(strongSelf.sendButton, recognizer)
            }
        }
    }
    
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if !self.sendButtonHasApplyIcon && gestureRecognizer.state == .began {
            //self.sendButtonLongPressed?()
        }
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.micButton.updateTheme(theme: theme)
        self.expandMediaInputButton.setImage(PresentationResourcesChat.chatInputPanelExpandButtonImage(theme), for: [])
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        transition.updateFrame(layer: self.micButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        self.micButton.layoutItems()
        
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        
        if let slowmodeState = interfaceState.slowmodeState, !interfaceState.isScheduledMessages && interfaceState.editMessageState == nil {
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
            
            let defaultSendButtonSize: CGFloat = 25.0
            let defaultOriginX = floorToScreenPixels((self.sendButton.bounds.width - defaultSendButtonSize) / 2.0)
            let defaultOriginY = floorToScreenPixels((self.sendButton.bounds.height - defaultSendButtonSize) / 2.0)
            
            let radialStatusFrame = CGRect(origin: CGPoint(x: defaultOriginX - 4.0, y: defaultOriginY - 4.0), size: CGSize(width: 33.0, height: 33.0))
            sendButtonRadialStatusNode.frame = radialStatusFrame
            sendButtonRadialStatusNode.slowmodeState = slowmodeState
        } else {
            if let sendButtonRadialStatusNode = self.sendButtonRadialStatusNode {
                self.sendButtonRadialStatusNode = nil
                sendButtonRadialStatusNode.removeFromSupernode()
            }
            transition.updateSublayerTransformScale(layer: self.sendButton.layer, scale: CGPoint(x: 1.0, y: 1.0))
        }
        
        transition.updateFrame(node: self.expandMediaInputButton, frame: CGRect(origin: CGPoint(), size: size))
        var expanded = false
        if case let .media(_, maybeExpanded) = interfaceState.inputMode, maybeExpanded != nil {
            expanded = true
        }
        transition.updateSublayerTransformScale(node: self.expandMediaInputButton, scale: CGPoint(x: 1.0, y: expanded ? 1.0 : -1.0))
    }
    
    func updateAccessibility() {
        if !self.micButton.alpha.isZero {
            self.accessibilityTraits = .button
            switch self.micButton.mode {
                case .audio:
                    self.accessibilityLabel = self.strings.VoiceOver_Chat_RecordModeVoiceMessage
                    self.accessibilityHint = self.strings.VoiceOver_Chat_RecordModeVoiceMessageInfo
                case .video:
                    self.accessibilityLabel = self.strings.VoiceOver_Chat_RecordModeVideoMessage
                    self.accessibilityHint = self.strings.VoiceOver_Chat_RecordModeVideoMessageInfo
            }
        } else {
            self.accessibilityTraits = .button
            self.accessibilityLabel = self.strings.MediaPicker_Send
            self.accessibilityHint = nil
        }
    }
}
