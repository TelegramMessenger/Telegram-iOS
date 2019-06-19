import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class ChatTextInputActionButtonsNode: ASDisplayNode {
    let micButton: ChatTextInputMediaRecordingButton
    let sendButton: HighlightableButton
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
