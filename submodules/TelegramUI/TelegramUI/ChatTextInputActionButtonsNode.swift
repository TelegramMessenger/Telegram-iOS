import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class ChatTextInputActionButtonsNode: ASDisplayNode {
    let micButton: ChatTextInputMediaRecordingButton
    let sendButton: HighlightTrackingButton
    var sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode?
    var sendButtonHasApplyIcon = false
    var animatingSendButton = false
    let expandMediaInputButton: HighlightableButtonNode
    
    var sendButtonLongPressed: (() -> Void)?
    
    private var gestureRecognizer: UILongPressGestureRecognizer?
    var sendButtonLongPressEnabled = false {
        didSet {
            self.gestureRecognizer?.isEnabled = self.sendButtonLongPressEnabled
        }
    }
    
    init(theme: PresentationTheme, presentController: @escaping (ViewController) -> Void) {
        self.micButton = ChatTextInputMediaRecordingButton(theme: theme, presentController: presentController)
        self.sendButton = HighlightTrackingButton()
        self.sendButton.adjustsImageWhenHighlighted = false
        self.sendButton.adjustsImageWhenDisabled = false
        
        self.expandMediaInputButton = HighlightableButtonNode()
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled
        
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
        self.view.addSubview(self.sendButton)
        self.addSubnode(self.expandMediaInputButton)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress(_:)))
        gestureRecognizer.minimumPressDuration = 0.4
        self.gestureRecognizer = gestureRecognizer
        self.sendButton.addGestureRecognizer(gestureRecognizer)
    }
    
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if !self.sendButtonHasApplyIcon && gestureRecognizer.state == .began {
            self.sendButtonLongPressed?()
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
        
        if let slowmodeState = interfaceState.slowmodeState, interfaceState.editMessageState == nil {
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
