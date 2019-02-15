import Foundation
import AsyncDisplayKit
import Display

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
        if self.sendButton.alpha.isZero {
            self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled
            self.accessibilityLabel = "Send"
        } else {
            self.accessibilityTraits = UIAccessibilityTraitButton
            self.accessibilityLabel = "Send"
        }
    }
}
