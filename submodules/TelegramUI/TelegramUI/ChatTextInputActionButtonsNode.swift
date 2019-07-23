import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class ChatTextInputActionButtonsNode: ASDisplayNode {
    let micButton: ChatTextInputMediaRecordingButton
    let sendButton: HighlightableButton
    var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    var sendButtonHasApplyIcon = false
    var animatingSendButton = false
    let expandMediaInputButton: HighlightableButtonNode
    
    init(theme: PresentationTheme, presentController: @escaping (ViewController) -> Void) {
        self.micButton = ChatTextInputMediaRecordingButton(theme: theme, presentController: presentController)
        self.sendButton = HighlightableButton()
        self.expandMediaInputButton = HighlightableButtonNode()
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled
        
        self.view.addSubview(self.micButton)
        self.view.addSubview(self.sendButton)
        self.addSubnode(self.expandMediaInputButton)
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.micButton.updateTheme(theme: theme)
        self.expandMediaInputButton.setImage(PresentationResourcesChat.chatInputPanelExpandButtonImage(theme), for: [])
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        transition.updateFrame(layer: self.micButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        self.micButton.layoutItems()
        
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        
        if let slowmodeState = interfaceState.slowmodeState {
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
        
        transition.updateFrame(node: self.expandMediaInputButton, frame: CGRect(origin: CGPoint(), size: size))
        var expanded = false
        if case let .media(_, maybeExpanded) = interfaceState.inputMode, maybeExpanded != nil {
            expanded = true
        }
        transition.updateSublayerTransformScale(node: self.expandMediaInputButton, scale: CGPoint(x: 1.0, y: expanded ? 1.0 : -1.0))
    }
    
    func updateAccessibility() {
        if !self.micButton.alpha.isZero {
            self.accessibilityTraits = UIAccessibilityTraitButton
            switch self.micButton.mode {
                case .audio:
                    self.accessibilityLabel = "Voice Message"
                    self.accessibilityHint = "Double tap and hold to record voice message. Slide up to pin recording, slide left to cancel. Double tap to switch to video."
                case .video:
                    self.accessibilityLabel = "Video Message"
                    self.accessibilityHint = "Double tap and hold to record voice message. Slide up to pin recording, slide left to cancel. Double tap to switch to audio."
            }
        } else {
            self.accessibilityTraits = UIAccessibilityTraitButton
            self.accessibilityLabel = "Send"
            self.accessibilityHint = nil
        }
    }
}
