import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ContextUI
import ChatPresentationInterfaceState
import ChatMessageBackground

final class ChatTextInputActionButtonsNode: ASDisplayNode {
    private let presentationContext: ChatPresentationContext?
    private let strings: PresentationStrings
    
    let micButton: ChatTextInputMediaRecordingButton
    let sendContainerNode: ASDisplayNode
    let backdropNode: ChatMessageBubbleBackdrop
    let backgroundNode: ASDisplayNode
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
    
    var micButtonPointerInteraction: PointerInteraction?
    
    private var validLayout: CGSize?
    
    init(presentationInterfaceState: ChatPresentationInterfaceState, presentationContext: ChatPresentationContext?, presentController: @escaping (ViewController) -> Void) {
        self.presentationContext = presentationContext
        let theme = presentationInterfaceState.theme
        let strings = presentationInterfaceState.strings
        self.strings = strings
         
        self.micButton = ChatTextInputMediaRecordingButton(theme: theme, strings: strings, presentController: presentController)
        
        self.sendContainerNode = ASDisplayNode()
        self.sendContainerNode.layer.allowsGroupOpacity = true
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.actionControlFillColor
        self.backgroundNode.clipsToBounds = true
        self.backdropNode = ChatMessageBubbleBackdrop()
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
        
        self.view.addSubview(self.micButton)
            
        self.addSubnode(self.sendContainerNode)
        self.sendContainerNode.addSubnode(self.backgroundNode)
        if let presentationContext = presentationContext {
            let graphics = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: presentationInterfaceState.chatWallpaper, bubbleCorners: presentationInterfaceState.bubbleCorners)
            self.backdropNode.setType(type: .outgoing(.None), theme: ChatPresentationThemeData(theme: theme, wallpaper: presentationInterfaceState.chatWallpaper), essentialGraphics: graphics, maskMode: true, backgroundNode: presentationContext.backgroundNode)
            self.backgroundNode.addSubnode(self.backdropNode)
        }
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
        
        self.micButtonPointerInteraction = PointerInteraction(view: self.micButton, style: .circle)
    }
    
    func updateTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper) {
        self.micButton.updateTheme(theme: theme)
        self.expandMediaInputButton.setImage(PresentationResourcesChat.chatInputPanelExpandButtonImage(theme), for: [])
        
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.actionControlFillColor
        
        if [.day, .night].contains(theme.referenceTheme.baseTheme) && !theme.chat.message.outgoing.bubble.withWallpaper.hasSingleFillColor {
            self.backdropNode.isHidden = false
        } else {
            self.backdropNode.isHidden = true
        }
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: theme, wallpaper: wallpaper, bubbleCorners: .init(mainRadius: 1, auxiliaryRadius: 1, mergeBubbleCorners: false))
        self.backdropNode.setType(type: .outgoing(.None), theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), essentialGraphics: graphics, maskMode: false, backgroundNode: self.presentationContext?.backgroundNode)
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
        self.backdropNode.update(rect: rect, within: containerSize, transition: transition)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = size
        transition.updateFrame(layer: self.micButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        self.micButton.layoutItems()
        
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.sendContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let backgroundSize = CGSize(width: 33.0, height: 33.0)
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize))
        self.backgroundNode.cornerRadius = backgroundSize.width / 2.0
        
        transition.updateFrame(node: self.backdropNode, frame: CGRect(origin: CGPoint(x: -2.0, y: -2.0), size: CGSize(width: size.width + 12.0, height: size.height + 2.0)))
        if let (rect, containerSize) = self.absoluteRect {
            self.backdropNode.update(rect: rect, within: containerSize)
        }
        
        var isScheduledMessages = false
        if case .scheduledMessages = interfaceState.subject {
            isScheduledMessages = true
        }
        
        if let slowmodeState = interfaceState.slowmodeState, !isScheduledMessages && interfaceState.editMessageState == nil {
            let sendButtonRadialStatusNode: ChatSendButtonRadialStatusNode
            if let current = self.sendButtonRadialStatusNode {
                sendButtonRadialStatusNode = current
            } else {
                sendButtonRadialStatusNode = ChatSendButtonRadialStatusNode(color: interfaceState.theme.chat.inputPanel.panelControlAccentColor)
                sendButtonRadialStatusNode.alpha = self.sendContainerNode.alpha
                self.sendButtonRadialStatusNode = sendButtonRadialStatusNode
                self.addSubnode(sendButtonRadialStatusNode)
            }
            
            transition.updateSublayerTransformScale(layer: self.sendContainerNode.layer, scale: CGPoint(x: 0.7575, y: 0.7575))
            
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
            transition.updateSublayerTransformScale(layer: self.sendContainerNode.layer, scale: CGPoint(x: 1.0, y: 1.0))
        }
        
        transition.updateFrame(node: self.expandMediaInputButton, frame: CGRect(origin: CGPoint(), size: size))
        var expanded = false
        if case let .media(_, maybeExpanded, _) = interfaceState.inputMode, maybeExpanded != nil {
            expanded = true
        }
        transition.updateSublayerTransformScale(node: self.expandMediaInputButton, scale: CGPoint(x: 1.0, y: expanded ? 1.0 : -1.0))
    }
    
    func updateAccessibility() {
        self.accessibilityTraits = .button
        if !self.micButton.alpha.isZero {
            switch self.micButton.mode {
                case .audio:
                    self.accessibilityLabel = self.strings.VoiceOver_Chat_RecordModeVoiceMessage
                    self.accessibilityHint = self.strings.VoiceOver_Chat_RecordModeVoiceMessageInfo
                case .video:
                    self.accessibilityLabel = self.strings.VoiceOver_Chat_RecordModeVideoMessage
                    self.accessibilityHint = self.strings.VoiceOver_Chat_RecordModeVideoMessageInfo
            }
        } else {
            self.accessibilityLabel = self.strings.MediaPicker_Send
            self.accessibilityHint = nil
        }
    }
}
