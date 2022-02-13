import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ContextUI
import ChatPresentationInterfaceState

final class AttachmentTextInputActionButtonsNode: ASDisplayNode {
    private let strings: PresentationStrings
    
    let sendContainerNode: ASDisplayNode
    let backgroundNode: ASDisplayNode
    let sendButton: HighlightTrackingButtonNode
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
        
    private var validLayout: CGSize?
    
    init(presentationInterfaceState: ChatPresentationInterfaceState, presentController: @escaping (ViewController) -> Void) {
        let theme = presentationInterfaceState.theme
        let strings = presentationInterfaceState.strings
        self.strings = strings
                 
        self.sendContainerNode = ASDisplayNode()
        self.sendContainerNode.layer.allowsGroupOpacity = true
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.actionControlFillColor
        self.backgroundNode.clipsToBounds = true
        self.sendButton = HighlightTrackingButtonNode(pointerStyle: .lift)
        
        self.expandMediaInputButton = HighlightableButtonNode(pointerStyle: .default)
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button, .notEnabled]
        
        self.sendButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if strongSelf.sendButtonHasApplyIcon || !strongSelf.sendButtonLongPressEnabled {
                    if highlighted {
                        strongSelf.sendContainerNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.sendContainerNode.alpha = 0.4
                    } else {
                        strongSelf.sendContainerNode.alpha = 1.0
                        strongSelf.sendContainerNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                } else {
                    if highlighted {
                        strongSelf.sendContainerNode.layer.animateScale(from: 1.0, to: 0.75, duration: 0.4, removeOnCompletion: false)
                    } else if let presentationLayer = strongSelf.sendButton.layer.presentation() {
                        strongSelf.sendContainerNode.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                    }
                }
            }
        }
        
        self.addSubnode(self.sendContainerNode)
        self.sendContainerNode.addSubnode(self.backgroundNode)
        self.sendContainerNode.addSubnode(self.sendButton)
        self.addSubnode(self.expandMediaInputButton)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let gestureRecognizer = ContextGesture(target: nil, action: nil)
        self.gestureRecognizer = gestureRecognizer
        self.sendButton.view.addGestureRecognizer(gestureRecognizer)
        gestureRecognizer.activated = { [weak self] recognizer, _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.sendButtonHasApplyIcon {
                strongSelf.sendButtonLongPressed?(strongSelf.sendContainerNode, recognizer)
            }
        }
    }
    
    func updateTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper) {
        self.expandMediaInputButton.setImage(PresentationResourcesChat.chatInputPanelExpandButtonImage(theme), for: [])
        
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.actionControlFillColor
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = size
        
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.sendContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let backgroundSize = CGSize(width: 33.0, height: 33.0)
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize))
        self.backgroundNode.cornerRadius = backgroundSize.width / 2.0
        
        transition.updateFrame(node: self.expandMediaInputButton, frame: CGRect(origin: CGPoint(), size: size))
        var expanded = false
        if case let .media(_, maybeExpanded, _) = interfaceState.inputMode, maybeExpanded != nil {
            expanded = true
        }
        transition.updateSublayerTransformScale(node: self.expandMediaInputButton, scale: CGPoint(x: 1.0, y: expanded ? 1.0 : -1.0))
    }
    
    func updateAccessibility() {
        self.accessibilityTraits = .button
        self.accessibilityLabel = self.strings.MediaPicker_Send
        self.accessibilityHint = nil
    }
}
