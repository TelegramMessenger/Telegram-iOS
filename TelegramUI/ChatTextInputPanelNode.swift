import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore

private let textInputViewBackground: UIImage = {
    let diameter: CGFloat = 35.0
    UIGraphicsBeginImageContextWithOptions(CGSize(width: diameter, height: diameter), true, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setFillColor(UIColor(0xF5F6F8).cgColor)
    context.fill(CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
    context.setStrokeColor(UIColor(0xC9CDD1).cgColor)
    let strokeWidth: CGFloat = 0.5
    context.setLineWidth(strokeWidth)
    context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: diameter - strokeWidth, height: diameter - strokeWidth))
    let image = UIGraphicsGetImageFromCurrentImageContext()!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
    UIGraphicsEndImageContext()
    
    return image
}()

private let attachmentIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/IconAttachment"), color: UIColor(0x9099A2))
private let micIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Text/IconMicrophone"), color: UIColor(0x9099A2))
private let sendIcon = UIImage(bundleImageName: "Chat/Input/Text/IconSend")?.precomposed()

enum ChatTextInputAccessoryItem {
    case keyboard
    case stickers
    case inputButtons
}

struct ChatTextInputPanelState: Equatable {
    let accessoryItems: [ChatTextInputAccessoryItem]
    
    init(accessoryItems: [ChatTextInputAccessoryItem]) {
        self.accessoryItems = accessoryItems
    }
    
    init() {
        self.accessoryItems = []
    }
    
    static func ==(lhs: ChatTextInputPanelState, rhs: ChatTextInputPanelState) -> Bool {
        if lhs.accessoryItems != rhs.accessoryItems {
            return false
        }
        return true
    }
}

private let keyboardImage = UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconKeyboard")?.precomposed()
private let stickersImage = UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconStickers")?.precomposed()
private let inputButtonsImage = UIImage(bundleImageName: "Chat/Input/Text/AccessoryIconInputButtons")?.precomposed()

private final class AccessoryItemIconButton: UIButton {
    init(item: ChatTextInputAccessoryItem) {
        super.init(frame: CGRect())
        
        switch item {
            case .keyboard:
                self.setImage(keyboardImage, for: [])
            case .stickers:
                self.setImage(stickersImage, for: [])
            case .inputButtons:
                self.setImage(inputButtonsImage, for: [])
        }
        
        //self.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var buttonWidth: CGFloat {
        return (self.image(for: [])?.size.width ?? 0.0) + CGFloat(8.0)
    }
}

class ChatTextInputPanelNode: ChatInputPanelNode, ASEditableTextNodeDelegate {
    var textPlaceholderNode: TextNode
    var textInputNode: ASEditableTextNode?
    
    let textInputBackgroundView: UIImageView
    let micButton: UIButton
    let sendButton: UIButton
    let attachmentButton: UIButton
    
    private var accessoryItemButtons: [(ChatTextInputAccessoryItem, AccessoryItemIconButton)] = []
    
    var displayAttachmentMenu: () -> Void = { }
    var sendMessage: () -> Void = { }
    var updateHeight: () -> Void = { }
    
    private var updatingInputState = false
    
    private var currentPlaceholder: String?
    
    private var presentationInterfaceState = ChatPresentationInterfaceState()
    
    var inputTextState: ChatTextInputState {
        get {
            if let textInputNode = self.textInputNode {
                let text = textInputNode.attributedText?.string ?? ""
                let selectionRange: Range<Int> = textInputNode.selectedRange.location ..< (textInputNode.selectedRange.location + textInputNode.selectedRange.length)
                return ChatTextInputState(inputText: text, selectionRange: selectionRange)
            } else {
                return ChatTextInputState()
            }
        } set(value) {
            if let textInputNode = self.textInputNode {
                self.updatingInputState = true
                textInputNode.attributedText = NSAttributedString(string: value.inputText, font: Font.regular(17.0), textColor: UIColor.black)
                textInputNode.selectedRange = NSMakeRange(value.selectionRange.lowerBound, value.selectionRange.count)
                self.updatingInputState = false
            }
        }
    }
    
    var text: String {
        get {
            return self.textInputNode?.attributedText?.string ?? ""
        } set(value) {
            if let textInputNode = self.textInputNode {
                textInputNode.attributedText = NSAttributedString(string: value, font: Font.regular(17.0), textColor: UIColor.black)
                self.editableTextNodeDidUpdateText(textInputNode)
            }
        }
    }
    
    let textFieldInsets = UIEdgeInsets(top: 6.0, left: 42.0, bottom: 6.0, right: 42.0)
    let textInputViewInternalInsets = UIEdgeInsets(top: 6.5, left: 13.0, bottom: 7.5, right: 13.0)
    let accessoryButtonSpacing: CGFloat = 0.0
    let accessoryButtonInset: CGFloat = 4.0 + UIScreenPixel
    
    override init() {
        self.textInputBackgroundView = UIImageView(image: textInputViewBackground)
        self.textPlaceholderNode = TextNode()
        self.textPlaceholderNode.isLayerBacked = true
        self.attachmentButton = UIButton()
        self.micButton = UIButton()
        self.sendButton = UIButton()
        
        super.init()
        
        self.attachmentButton.setImage(attachmentIcon, for: [])
        self.attachmentButton.addTarget(self, action: #selector(self.attachmentButtonPressed), for: .touchUpInside)
        self.view.addSubview(self.attachmentButton)
        
        self.micButton.setImage(micIcon, for: [])
        self.micButton.addTarget(self, action: #selector(self.micButtonPressed), for: .touchUpInside)
        self.view.addSubview(self.micButton)
        
        self.sendButton.setImage(sendIcon, for: [])
        self.sendButton.addTarget(self, action: #selector(self.sendButtonPressed), for: .touchUpInside)
        self.sendButton.alpha = 0.0
        self.view.addSubview(self.sendButton)
        
        self.view.addSubview(self.textInputBackgroundView)
        
        let placeholderLayout = TextNode.asyncLayout(self.textPlaceholderNode)
        let (placeholderSize, placeholderApply) = placeholderLayout(NSAttributedString(string: "Message", font: Font.regular(17.0), textColor: UIColor(0xC8C8CE)), nil, 1, .end, CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), nil)
        self.textPlaceholderNode.frame = CGRect(origin: CGPoint(), size: placeholderSize.size)
        let _ = placeholderApply()
        self.addSubnode(self.textPlaceholderNode)
        
        self.textInputBackgroundView.clipsToBounds = true
        let recognizer = TouchDownGestureRecognizer(target: self, action: #selector(self.textInputBackgroundViewTap(_:)))
        recognizer.touchDown = { [weak self] in
            if let strongSelf = self {
                strongSelf.ensureFocused()
            }
        }
        self.textInputBackgroundView.addGestureRecognizer(recognizer)
        self.textInputBackgroundView.isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func loadTextInputNode() {
        let textInputNode = ASEditableTextNode()
        textInputNode.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
        textInputNode.clipsToBounds = true
        textInputNode.delegate = self
        textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.addSubnode(textInputNode)
        self.textInputNode = textInputNode
        
        textInputNode.frame = CGRect(x: self.textFieldInsets.left + self.textInputViewInternalInsets.left, y: self.textFieldInsets.top + self.textInputViewInternalInsets.top, width: self.frame.size.width - self.textFieldInsets.left - self.textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right, height: self.frame.size.height - self.textFieldInsets.top - self.textFieldInsets.bottom - self.textInputViewInternalInsets.top - self.textInputViewInternalInsets.bottom)
        
        self.textInputBackgroundView.isUserInteractionEnabled = false
        self.textInputBackgroundView.removeGestureRecognizer(self.textInputBackgroundView.gestureRecognizers![0])
        
        let recognizer = TouchDownGestureRecognizer(target: self, action: #selector(self.textInputBackgroundViewTap(_:)))
        recognizer.touchDown = { [weak self] in
            if let strongSelf = self {
                strongSelf.ensureFocused()
            }
        }
        textInputNode.view.addGestureRecognizer(recognizer)
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> (accessoryButtonsWidth: CGFloat, textFieldHeight: CGFloat) {
        let accessoryButtonInset = self.accessoryButtonInset
        let accessoryButtonSpacing = self.accessoryButtonSpacing
        
        var accessoryButtonsWidth: CGFloat = 0.0
        var firstButton = true
        for (_, button) in self.accessoryItemButtons {
            if firstButton {
                firstButton = false
                accessoryButtonsWidth += accessoryButtonInset
            } else {
                accessoryButtonsWidth += accessoryButtonSpacing
            }
            accessoryButtonsWidth += button.buttonWidth
        }
        
        let textFieldHeight: CGFloat
        if let textInputNode = self.textInputNode {
            textFieldHeight = min(115.0, max(21.0, ceil(textInputNode.measure(CGSize(width: width - self.textFieldInsets.left - self.textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right - accessoryButtonsWidth, height: CGFloat.greatestFiniteMagnitude)).height)))
        } else {
            textFieldHeight = 21.0
        }
        
        return (accessoryButtonsWidth, textFieldHeight)
    }
    
    private func panelHeight(textFieldHeight: CGFloat) -> CGFloat {
        return textFieldHeight + self.textFieldInsets.top + self.textFieldInsets.bottom + self.textInputViewInternalInsets.top + self.textInputViewInternalInsets.bottom
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            let previousState = self.presentationInterfaceState
            self.presentationInterfaceState = interfaceState
            
            if let peer = interfaceState.peer, previousState.peer == nil || !peer.isEqual(previousState.peer!) {
                let placeholder: String
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    placeholder = "Broadcast"
                } else {
                    placeholder = "Message"
                }
                if self.currentPlaceholder != placeholder {
                    self.currentPlaceholder = placeholder
                    let placeholderLayout = TextNode.asyncLayout(self.textPlaceholderNode)
                    let (placeholderSize, placeholderApply) = placeholderLayout(NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: UIColor(0xbebec0)), nil, 1, .end, CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), nil)
                    self.textPlaceholderNode.frame = CGRect(origin: self.textPlaceholderNode.frame.origin, size: placeholderSize.size)
                    let _ = placeholderApply()
                }
            }
        }
        
        let minimalHeight: CGFloat = 47.0
        let minimalInputHeight: CGFloat = 35.0
        
        var animatedTransition = true
        if case .immediate = transition {
            animatedTransition = false
        }
        
        var updateAccessoryButtons = false
        if self.presentationInterfaceState.inputTextPanelState.accessoryItems.count == self.accessoryItemButtons.count {
            for i in 0 ..< self.presentationInterfaceState.inputTextPanelState.accessoryItems.count {
                if self.presentationInterfaceState.inputTextPanelState.accessoryItems[i] != self.accessoryItemButtons[i].0 {
                    updateAccessoryButtons = true
                    break
                }
            }
        } else {
            updateAccessoryButtons = true
        }
        
        var removeAccessoryButtons: [AccessoryItemIconButton]?
        if updateAccessoryButtons {
            var updatedButtons: [(ChatTextInputAccessoryItem, AccessoryItemIconButton)] = []
            for item in self.presentationInterfaceState.inputTextPanelState.accessoryItems {
                var itemAndButton: (ChatTextInputAccessoryItem, AccessoryItemIconButton)?
                for i in 0 ..< self.accessoryItemButtons.count {
                    if self.accessoryItemButtons[i].0 == item {
                        itemAndButton = self.accessoryItemButtons[i]
                        self.accessoryItemButtons.remove(at: i)
                        break
                    }
                }
                if itemAndButton == nil {
                    let button = AccessoryItemIconButton(item: item)
                    button.addTarget(self, action: #selector(self.accessoryItemButtonPressed(_:)), for: [.touchUpInside])
                    itemAndButton = (item, button)
                }
                updatedButtons.append(itemAndButton!)
            }
            for (_, button) in self.accessoryItemButtons {
                if animatedTransition {
                    if removeAccessoryButtons == nil {
                        removeAccessoryButtons = []
                    }
                    removeAccessoryButtons!.append(button)
                } else {
                    button.removeFromSuperview()
                }
            }
            self.accessoryItemButtons = updatedButtons
        }
        
        let (accessoryButtonsWidth, textFieldHeight) = self.calculateTextFieldMetrics(width: width)
        let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight)
        
        transition.updateFrame(layer: self.attachmentButton.layer, frame: CGRect(origin: CGPoint(x: 2.0 - UIScreenPixel, y: panelHeight - minimalHeight), size: CGSize(width: 40.0, height: minimalHeight)))
        transition.updateFrame(layer: self.micButton.layer, frame: CGRect(origin: CGPoint(x: width - 43.0 - UIScreenPixel, y: panelHeight - minimalHeight - UIScreenPixel), size: CGSize(width: 44.0, height: minimalHeight)))
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(x: width - 43.0 - UIScreenPixel, y: panelHeight - minimalHeight - UIScreenPixel), size: CGSize(width: 44.0, height: minimalHeight)))
        
        if let textInputNode = self.textInputNode {
            transition.updateFrame(node: textInputNode, frame: CGRect(x: self.textFieldInsets.left + self.textInputViewInternalInsets.left, y: self.textFieldInsets.top + self.textInputViewInternalInsets.top, width: width - self.textFieldInsets.left - self.textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right - accessoryButtonsWidth, height: panelHeight - self.textFieldInsets.top - self.textFieldInsets.bottom - self.textInputViewInternalInsets.top - self.textInputViewInternalInsets.bottom))
        }
        
        transition.updateFrame(node: self.textPlaceholderNode, frame: CGRect(origin: CGPoint(x: self.textFieldInsets.left + self.textInputViewInternalInsets.left, y: self.textFieldInsets.top + self.textInputViewInternalInsets.top + 0.5), size: self.textPlaceholderNode.frame.size))
        
        transition.updateFrame(layer: self.textInputBackgroundView.layer, frame: CGRect(x: self.textFieldInsets.left, y: self.textFieldInsets.top, width: width -  self.textFieldInsets.left - self.textFieldInsets.right, height: panelHeight - self.textFieldInsets.top - self.textFieldInsets.bottom))
        
        var nextButtonTopRight = CGPoint(x: width - self.textFieldInsets.right - accessoryButtonInset, y: panelHeight - self.textFieldInsets.bottom - minimalInputHeight)
        for (_, button) in self.accessoryItemButtons.reversed() {
            let buttonSize = CGSize(width: button.buttonWidth, height: minimalInputHeight)
            let buttonFrame = CGRect(origin: CGPoint(x: nextButtonTopRight.x - buttonSize.width, y: nextButtonTopRight.y + floor((minimalInputHeight - buttonSize.height) / 2.0)), size: buttonSize)
            if button.superview == nil {
                self.view.addSubview(button)
                button.frame = buttonFrame
                transition.updateFrame(layer: button.layer, frame: buttonFrame)
                if animatedTransition {
                    button.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    button.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25)
                }
            } else {
                transition.updateFrame(layer: button.layer, frame: buttonFrame)
            }
            nextButtonTopRight.x -= buttonSize.width
            nextButtonTopRight.x -= accessoryButtonSpacing
        }
        
        if let removeAccessoryButtons = removeAccessoryButtons {
            for button in removeAccessoryButtons {
                let buttonFrame = CGRect(origin: CGPoint(x: button.frame.origin.x, y: panelHeight - self.textFieldInsets.bottom - minimalInputHeight), size: button.frame.size)
                transition.updateFrame(layer: button.layer, frame: buttonFrame)
                button.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
                button.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak button] _ in
                    button?.removeFromSuperview()
                })
            }
        }
        
        return panelHeight
    }
    
    @objc func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let textInputNode = self.textInputNode {
            self.textPlaceholderNode.isHidden = editableTextNode.attributedText?.length ?? 0 != 0
            
            if let text = self.textInputNode?.attributedText, text.length != 0 {
                if self.sendButton.alpha.isZero {
                    self.sendButton.alpha = 1.0
                    self.micButton.alpha = 0.0
                    self.sendButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                    self.sendButton.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                    self.micButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            } else {
                if self.micButton.alpha.isZero {
                    self.micButton.alpha = 1.0
                    self.sendButton.alpha = 0.0
                    self.micButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                    self.micButton.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                    self.sendButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
            
            self.interfaceInteraction?.updateTextInputState(self.inputTextState)
            
            let (accessoryButtonsWidth, textFieldHeight) = self.calculateTextFieldMetrics(width: self.bounds.size.width)
            let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight)
            if !self.bounds.size.height.isEqual(to: panelHeight) {
                self.updateHeight()
            }
        }
    }
    
    @objc func editableTextNodeDidChangeSelection(_ editableTextNode: ASEditableTextNode, fromSelectedRange: NSRange, toSelectedRange: NSRange, dueToEditing: Bool) {
        if !dueToEditing && !updatingInputState {
            self.interfaceInteraction?.updateTextInputState(self.inputTextState)
        }
    }
    
    @objc func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.interfaceInteraction?.updateInputMode({ _ in .text })
    }
    
    @objc func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        /*self.interfaceInteraction?.updateInputMode({ mode in
            if case .text = mode {
                return .none
            } else {
                return mode
            }
        })*/
    }
    
    @objc func sendButtonPressed() {
        let text = self.textInputNode?.attributedText?.string ?? ""
        if !text.isEmpty {
            self.sendMessage()
        }
    }
    
    @objc func attachmentButtonPressed() {
        self.displayAttachmentMenu()
    }
    
    @objc func micButtonPressed() {
    }
    
    @objc func textInputBackgroundViewTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.ensureFocused()
        }
    }
    
    var isFocused: Bool {
        return self.textInputNode?.isFirstResponder() ?? false
    }
    
    func ensureUnfocused() {
        self.textInputNode?.resignFirstResponder()
    }
    
    func ensureFocused() {
        if self.textInputNode == nil {
            self.loadTextInputNode()
        }
        
        self.textInputNode?.becomeFirstResponder()
    }
    
    func animateTextSend() {
        /*if let textInputNode = self.textInputNode {
            let snapshot = textInputNode.view.snapshotViewAfterScreenUpdates(false)
            snapshot.frame = self.textInputBackgroundView.convertRect(textInputNode.view.bounds, fromView: textInputNode.view)
            self.textInputBackgroundView.addSubview(snapshot)
            UIView.animateWithDuration(0.3, animations: {
                snapshot.alpha = 0.0
                snapshot.transform = CGAffineTransformMakeTranslation(0.0, -20.0)
            }, completion: { _ in
                snapshot.removeFromSuperview()
            })
        }*/
    }
    
    @objc func accessoryItemButtonPressed(_ button: UIView) {
        for (item, currentButton) in self.accessoryItemButtons {
            if currentButton === button {
                switch item {
                    case .inputButtons:
                        break
                    case .stickers:
                        self.interfaceInteraction?.updateInputMode({ _ in .media })
                    case .keyboard:
                        self.interfaceInteraction?.updateInputMode({ _ in .text })
                }
                break
            }
        }
    }
}
