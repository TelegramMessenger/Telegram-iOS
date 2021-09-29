import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import MobileCoreServices
import TelegramPresentationData
import TextFormat
import AccountContext
import TouchDownGesture
import ActivityIndicator
import Speak

private let counterFont = Font.with(size: 14.0, design: .regular, traits: [.monospacedNumbers])
private let minInputFontSize = chatTextInputMinFontSize

private func calclulateTextFieldMinHeight(_ presentationInterfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
    let baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
    var result: CGFloat
    if baseFontSize.isEqual(to: 26.0) {
        result = 42.0
    } else if baseFontSize.isEqual(to: 23.0) {
        result = 38.0
    } else if baseFontSize.isEqual(to: 17.0) {
        result = 31.0
    } else if baseFontSize.isEqual(to: 19.0) {
        result = 33.0
    } else if baseFontSize.isEqual(to: 21.0) {
        result = 35.0
    } else {
        result = 31.0
    }
    
    if case .regular = metrics.widthClass {
        result = max(33.0, result)
    }
    
    return result
}

private func calculateTextFieldRealInsets(_ presentationInterfaceState: ChatPresentationInterfaceState) -> UIEdgeInsets {
    let baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
    let top: CGFloat
    let bottom: CGFloat
    if baseFontSize.isEqual(to: 14.0) {
        top = 2.0
        bottom = 1.0
    } else if baseFontSize.isEqual(to: 15.0) {
        top = 1.0
        bottom = 1.0
    } else if baseFontSize.isEqual(to: 16.0) {
        top = 0.5
        bottom = 0.0
    } else {
        top = 0.0
        bottom = 0.0
    }
    return UIEdgeInsets(top: 4.5 + top, left: 0.0, bottom: 5.5 + bottom, right: 0.0)
}

private var currentTextInputBackgroundImage: (UIColor, UIColor, CGFloat, UIImage)?
private func textInputBackgroundImage(backgroundColor: UIColor?, inputBackgroundColor: UIColor?, strokeColor: UIColor, diameter: CGFloat) -> UIImage? {
    if let backgroundColor = backgroundColor, let current = currentTextInputBackgroundImage {
        if current.0.isEqual(backgroundColor) && current.1.isEqual(strokeColor) && current.2.isEqual(to: diameter) {
            return current.3
        }
    }
    
    let image = generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))

        if let inputBackgroundColor = inputBackgroundColor {
            context.setBlendMode(.normal)
            context.setFillColor(inputBackgroundColor.cgColor)
        } else {
            context.setBlendMode(.clear)
            context.setFillColor(UIColor.clear.cgColor)
        }
        context.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter))
            
        context.setBlendMode(.normal)
        context.setStrokeColor(strokeColor.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: diameter - strokeWidth, height: diameter - strokeWidth))
    })?.stretchableImage(withLeftCapWidth: Int(diameter) / 2, topCapHeight: Int(diameter) / 2)
    if let image = image {
        if let backgroundColor = backgroundColor {
            currentTextInputBackgroundImage = (backgroundColor, strokeColor, diameter, image)
        }
        return image
    } else {
        return nil
    }
}

class PeerSelectionTextInputPanelNode: ChatInputPanelNode, ASEditableTextNodeDelegate {
    var textPlaceholderNode: ImmediateTextNode
    let textInputContainerBackgroundNode: ASImageNode
    let textInputContainer: ASDisplayNode
    var textInputNode: EditableTextNode?
    
    let textInputBackgroundNode: ASImageNode
    private var transparentTextInputBackgroundImage: UIImage?
    let actionButtons: ChatTextInputActionButtonsNode
    private let counterTextNode: ImmediateTextNode

    private var validLayout: (CGFloat, CGFloat, CGFloat, UIEdgeInsets, CGFloat, LayoutMetrics, Bool)?
    
    var sendMessage: (PeerSelectionControllerSendMode) -> Void = { _ in }
    var updateHeight: (Bool) -> Void = { _ in }

    private var updatingInputState = false
    
    private var currentPlaceholder: String?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    private var initializedPlaceholder = false
        
    private let inputMenu = ChatTextInputMenu()
    
    private var theme: PresentationTheme?
    private var strings: PresentationStrings?
    
    private let hapticFeedback = HapticFeedback()
    
    var inputTextState: ChatTextInputState {
        if let textInputNode = self.textInputNode {
            let selectionRange: Range<Int> = textInputNode.selectedRange.location ..< (textInputNode.selectedRange.location + textInputNode.selectedRange.length)
            return ChatTextInputState(inputText: stateAttributedStringForText(textInputNode.attributedText ?? NSAttributedString()), selectionRange: selectionRange)
        } else {
            return ChatTextInputState()
        }
    }
    
    var storedInputLanguage: String?
    var effectiveInputLanguage: String? {
        if let textInputNode = textInputNode, textInputNode.isFirstResponder() {
            return textInputNode.textInputMode.primaryLanguage
        } else {
            return self.storedInputLanguage
        }
    }
    
    var enablePredictiveInput: Bool = true {
        didSet {
            if let textInputNode = self.textInputNode {
                textInputNode.textView.autocorrectionType = self.enablePredictiveInput ? .default : .no
            }
        }
    }
    
    override var context: AccountContext? {
        didSet {
            self.actionButtons.micButton.account = self.context?.account
        }
    }

    var micButton: ChatTextInputMediaRecordingButton? {
        return self.actionButtons.micButton
    }
    
    func updateSendButtonEnabled(_ enabled: Bool, animated: Bool) {
        self.actionButtons.isUserInteractionEnabled = enabled
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
        transition.updateAlpha(node: self.actionButtons, alpha: enabled ? 1.0 : 0.3)
    }
        
    func updateInputTextState(_ state: ChatTextInputState, animated: Bool) {
        if state.inputText.length != 0 && self.textInputNode == nil {
            self.loadTextInputNode()
        }
        
        if let textInputNode = self.textInputNode, let _ = self.presentationInterfaceState {
            self.updatingInputState = true
            
            var textColor: UIColor = .black
            var accentTextColor: UIColor = .blue
            var baseFontSize: CGFloat = 17.0
            if let presentationInterfaceState = self.presentationInterfaceState {
                textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
                accentTextColor = presentationInterfaceState.theme.chat.inputPanel.panelControlAccentColor
                baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            }
            textInputNode.attributedText = textAttributedStringForStateText(state.inputText, fontSize: baseFontSize, textColor: textColor, accentTextColor: accentTextColor, writingDirection: nil)
            textInputNode.selectedRange = NSMakeRange(state.selectionRange.lowerBound, state.selectionRange.count)
            self.updatingInputState = false
            self.updateTextNodeText(animated: animated)
        }
    }
    
    var text: String {
        get {
            return self.textInputNode?.attributedText?.string ?? ""
        } set(value) {
            if let textInputNode = self.textInputNode {
                var textColor: UIColor = .black
                var baseFontSize: CGFloat = 17.0
                if let presentationInterfaceState = self.presentationInterfaceState {
                    textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
                    baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
                }
                textInputNode.attributedText = NSAttributedString(string: value, font: Font.regular(baseFontSize), textColor: textColor)
                self.editableTextNodeDidUpdateText(textInputNode)
            }
        }
    }
    
    private let textInputViewInternalInsets = UIEdgeInsets(top: 1.0, left: 13.0, bottom: 1.0, right: 13.0)
    
    init(presentationInterfaceState: ChatPresentationInterfaceState, presentController: @escaping (ViewController) -> Void) {
        self.textInputContainerBackgroundNode = ASImageNode()
        self.textInputContainerBackgroundNode.isUserInteractionEnabled = false
        self.textInputContainerBackgroundNode.displaysAsynchronously = false
        
        self.textInputContainer = ASDisplayNode()
        self.textInputContainer.addSubnode(self.textInputContainerBackgroundNode)
        self.textInputContainer.clipsToBounds = true
        
        self.textInputBackgroundNode = ASImageNode()
        self.textInputBackgroundNode.displaysAsynchronously = false
        self.textInputBackgroundNode.displayWithoutProcessing = true
        self.textPlaceholderNode = ImmediateTextNode()
        self.textPlaceholderNode.maximumNumberOfLines = 1
        self.textPlaceholderNode.isUserInteractionEnabled = false
        
        self.actionButtons = ChatTextInputActionButtonsNode(presentationInterfaceState: presentationInterfaceState, presentationContext: nil, presentController: presentController)
        self.counterTextNode = ImmediateTextNode()
        self.counterTextNode.textAlignment = .center
        
        super.init()
        
        self.actionButtons.sendButtonLongPressed = { [weak self] node, gesture in
            self?.interfaceInteraction?.displaySendMessageOptions(node, gesture)
        }
        
        self.actionButtons.sendButton.addTarget(self, action: #selector(self.sendButtonPressed), forControlEvents: .touchUpInside)
        self.actionButtons.sendButton.alpha = 1.0
        self.actionButtons.micButton.alpha = 0.0
        self.actionButtons.expandMediaInputButton.alpha = 0.0
        self.actionButtons.updateAccessibility()
        
        self.addSubnode(self.textInputContainer)
        self.addSubnode(self.textInputBackgroundNode)
        
        self.addSubnode(self.textPlaceholderNode)
        
        self.addSubnode(self.actionButtons)
        self.addSubnode(self.counterTextNode)
                
        self.textInputBackgroundNode.clipsToBounds = true
        let recognizer = TouchDownGestureRecognizer(target: self, action: #selector(self.textInputBackgroundViewTap(_:)))
        recognizer.touchDown = { [weak self] in
            if let strongSelf = self {
                strongSelf.ensureFocused()
            }
        }
        self.textInputBackgroundNode.isUserInteractionEnabled = true
        self.textInputBackgroundNode.view.addGestureRecognizer(recognizer)
        
        self.updateSendButtonEnabled(false, animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func loadTextInputNodeIfNeeded() {
        if self.textInputNode == nil {
            self.loadTextInputNode()
        }
    }
    
    private func loadTextInputNode() {
        let textInputNode = EditableTextNode()
        textInputNode.initialPrimaryLanguage = self.presentationInterfaceState?.interfaceState.inputLanguage
        var textColor: UIColor = .black
        var tintColor: UIColor = .blue
        var baseFontSize: CGFloat = 17.0
        var keyboardAppearance: UIKeyboardAppearance = UIKeyboardAppearance.default
        if let presentationInterfaceState = self.presentationInterfaceState {
            textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
            tintColor = presentationInterfaceState.theme.list.itemAccentColor
            baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            keyboardAppearance = presentationInterfaceState.theme.rootController.keyboardColor.keyboardAppearance
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.0
        paragraphStyle.lineHeightMultiple = 1.0
        paragraphStyle.paragraphSpacing = 1.0
        paragraphStyle.maximumLineHeight = 20.0
        paragraphStyle.minimumLineHeight = 20.0
        
        textInputNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(max(minInputFontSize, baseFontSize)), NSAttributedString.Key.foregroundColor.rawValue: textColor, NSAttributedString.Key.paragraphStyle.rawValue: paragraphStyle]
        textInputNode.clipsToBounds = false
        textInputNode.textView.clipsToBounds = false
        textInputNode.delegate = self
        textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        textInputNode.keyboardAppearance = keyboardAppearance
        textInputNode.tintColor = tintColor
        textInputNode.textView.scrollIndicatorInsets = UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: -13.0)
        self.textInputContainer.addSubnode(textInputNode)
        textInputNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.textInputNode = textInputNode
        
        if let presentationInterfaceState = self.presentationInterfaceState {
            refreshChatTextInputTypingAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize)
            textInputNode.textContainerInset = calculateTextFieldRealInsets(presentationInterfaceState)
        }
        
        if !self.textInputContainer.bounds.size.width.isZero {
            let textInputFrame = self.textInputContainer.frame
            
            textInputNode.frame = CGRect(origin: CGPoint(x: self.textInputViewInternalInsets.left, y: self.textInputViewInternalInsets.top), size: CGSize(width: textInputFrame.size.width - (self.textInputViewInternalInsets.left + self.textInputViewInternalInsets.right), height: textInputFrame.size.height - self.textInputViewInternalInsets.top - self.textInputViewInternalInsets.bottom))
        }
        
        self.textInputBackgroundNode.isUserInteractionEnabled = false
        self.textInputBackgroundNode.view.removeGestureRecognizer(self.textInputBackgroundNode.view.gestureRecognizers![0])
        
        let recognizer = TouchDownGestureRecognizer(target: self, action: #selector(self.textInputBackgroundViewTap(_:)))
        recognizer.touchDown = { [weak self] in
            if let strongSelf = self {
                strongSelf.ensureFocused()
            }
        }
        textInputNode.view.addGestureRecognizer(recognizer)
        
        textInputNode.textView.accessibilityHint = self.textPlaceholderNode.attributedText?.string
    }
    
    private func textFieldMaxHeight(_ maxHeight: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        let textFieldInsets = self.textFieldInsets(metrics: metrics)
        return max(33.0, maxHeight - (textFieldInsets.top + textFieldInsets.bottom + self.textInputViewInternalInsets.top + self.textInputViewInternalInsets.bottom))
    }
    
    private func calculateTextFieldMetrics(width: CGFloat, maxHeight: CGFloat, metrics: LayoutMetrics) -> (accessoryButtonsWidth: CGFloat, textFieldHeight: CGFloat) {
        let textFieldInsets = self.textFieldInsets(metrics: metrics)
        
        let fieldMaxHeight = textFieldMaxHeight(maxHeight, metrics: metrics)
        
        var textFieldMinHeight: CGFloat = 35.0
        if let presentationInterfaceState = self.presentationInterfaceState {
            textFieldMinHeight = calclulateTextFieldMinHeight(presentationInterfaceState, metrics: metrics)
        }
        
        let textFieldHeight: CGFloat
        if let textInputNode = self.textInputNode {
            let maxTextWidth = width - textFieldInsets.left - textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right
            let measuredHeight = textInputNode.measure(CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude))
            let unboundTextFieldHeight = max(textFieldMinHeight, ceil(measuredHeight.height))
            
            let maxNumberOfLines = min(12, (Int(fieldMaxHeight - 11.0) - 33) / 22)
            
            let updatedMaxHeight = (CGFloat(maxNumberOfLines) * (22.0 + 2.0) + 10.0)
            
            textFieldHeight = max(textFieldMinHeight, min(updatedMaxHeight, unboundTextFieldHeight))
        } else {
            textFieldHeight = textFieldMinHeight
        }
        
        return (0.0, textFieldHeight)
    }
    
    private func textFieldInsets(metrics: LayoutMetrics) -> UIEdgeInsets {
        var insets = UIEdgeInsets(top: 6.0, left: 6.0, bottom: 6.0, right: 42.0)
        if case .regular = metrics.widthClass, case .regular = metrics.heightClass {
            insets.top += 1.0
            insets.bottom += 1.0
        }
        return insets
    }
    
    private func panelHeight(textFieldHeight: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        let textFieldInsets = self.textFieldInsets(metrics: metrics)
        let result = textFieldHeight + textFieldInsets.top + textFieldInsets.bottom + self.textInputViewInternalInsets.top + self.textInputViewInternalInsets.bottom
        return result
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        let textFieldMinHeight = calclulateTextFieldMinHeight(interfaceState, metrics: metrics)
        var minimalHeight: CGFloat = 14.0 + textFieldMinHeight
        if case .regular = metrics.widthClass, case .regular = metrics.heightClass {
            minimalHeight += 2.0
        }
        return minimalHeight
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        let previousAdditionalSideInsets = self.validLayout?.3
        self.validLayout = (width, leftInset, rightInset, additionalSideInsets, maxHeight, metrics, isSecondary)
    
        var transition = transition
        if let previousAdditionalSideInsets = previousAdditionalSideInsets, previousAdditionalSideInsets.right != additionalSideInsets.right {
            
            if case .animated = transition {
                transition = .animated(duration: 0.2, curve: .easeInOut)
            }
        }
                                
        if self.presentationInterfaceState != interfaceState {
            let previousState = self.presentationInterfaceState
            self.presentationInterfaceState = interfaceState
            
            let themeUpdated = previousState?.theme !== interfaceState.theme
            
            var updateSendButtonIcon = false
            if (previousState?.interfaceState.editMessage != nil) != (interfaceState.interfaceState.editMessage != nil) {
                updateSendButtonIcon = true
            }
            if self.theme !== interfaceState.theme {
                updateSendButtonIcon = true
                
                if self.theme == nil || !self.theme!.chat.inputPanel.inputTextColor.isEqual(interfaceState.theme.chat.inputPanel.inputTextColor) {
                    let textColor = interfaceState.theme.chat.inputPanel.inputTextColor
                    let baseFontSize = max(minInputFontSize, interfaceState.fontSize.baseDisplaySize)
                    
                    if let textInputNode = self.textInputNode {
                        if let text = textInputNode.attributedText?.string {
                            let range = textInputNode.selectedRange
                            textInputNode.attributedText = NSAttributedString(string: text, font: Font.regular(baseFontSize), textColor: textColor)
                            textInputNode.selectedRange = range
                        }
                        textInputNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(baseFontSize), NSAttributedString.Key.foregroundColor.rawValue: textColor]
                    }
                }
                
                let keyboardAppearance = interfaceState.theme.rootController.keyboardColor.keyboardAppearance
                if let textInputNode = self.textInputNode, textInputNode.keyboardAppearance != keyboardAppearance, textInputNode.isFirstResponder() {
                    if textInputNode.isCurrentlyEmoji() {
                        textInputNode.initialPrimaryLanguage = "emoji"
                        textInputNode.resetInitialPrimaryLanguage()
                    }
                    textInputNode.keyboardAppearance = keyboardAppearance
                }
                
                self.theme = interfaceState.theme

                self.actionButtons.updateTheme(theme: interfaceState.theme, wallpaper: interfaceState.chatWallpaper)
                
                let textFieldMinHeight = calclulateTextFieldMinHeight(interfaceState, metrics: metrics)
                let minimalInputHeight: CGFloat = 2.0 + textFieldMinHeight
                
                let backgroundColor: UIColor
                if case let .color(color) = interfaceState.chatWallpaper, UIColor(rgb: color).isEqual(interfaceState.theme.chat.inputPanel.panelBackgroundColorNoWallpaper) {
                    backgroundColor = interfaceState.theme.chat.inputPanel.panelBackgroundColorNoWallpaper
                } else {
                    backgroundColor = interfaceState.theme.chat.inputPanel.panelBackgroundColor
                }
                
                self.textInputBackgroundNode.image = textInputBackgroundImage(backgroundColor: backgroundColor, inputBackgroundColor: nil, strokeColor: interfaceState.theme.chat.inputPanel.inputStrokeColor, diameter: minimalInputHeight)
                self.transparentTextInputBackgroundImage = textInputBackgroundImage(backgroundColor: nil, inputBackgroundColor: interfaceState.theme.chat.inputPanel.inputBackgroundColor, strokeColor: interfaceState.theme.chat.inputPanel.inputStrokeColor, diameter: minimalInputHeight)
                self.textInputContainerBackgroundNode.image = generateStretchableFilledCircleImage(diameter: minimalInputHeight, color: interfaceState.theme.chat.inputPanel.inputBackgroundColor)
            } else {
                if self.strings !== interfaceState.strings {
                    self.strings = interfaceState.strings
                    self.inputMenu.updateStrings(interfaceState.strings)
                }
            }
  
            if themeUpdated || !self.initializedPlaceholder {
                self.initializedPlaceholder = true
                
                let placeholder = interfaceState.strings.Conversation_InputTextPlaceholder
               
                if self.currentPlaceholder != placeholder || themeUpdated {
                    self.currentPlaceholder = placeholder
                    let baseFontSize = max(minInputFontSize, interfaceState.fontSize.baseDisplaySize)
                    self.textPlaceholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(baseFontSize), textColor: interfaceState.theme.chat.inputPanel.inputPlaceholderColor)
                    self.textInputNode?.textView.accessibilityHint = placeholder
                    let placeholderSize = self.textPlaceholderNode.updateLayout(CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude))
                    if transition.isAnimated, let snapshotLayer = self.textPlaceholderNode.layer.snapshotContentTree() {
                        self.textPlaceholderNode.supernode?.layer.insertSublayer(snapshotLayer, above: self.textPlaceholderNode.layer)
                        snapshotLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.22, removeOnCompletion: false, completion: { [weak snapshotLayer] _ in
                            snapshotLayer?.removeFromSuperlayer()
                        })
                        self.textPlaceholderNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                    }
                    self.textPlaceholderNode.frame = CGRect(origin: self.textPlaceholderNode.frame.origin, size: placeholderSize)
                }
                
                self.actionButtons.sendButtonLongPressEnabled = true
            }
            
            let sendButtonHasApplyIcon = interfaceState.interfaceState.editMessage != nil
            
            if updateSendButtonIcon {
                if !self.actionButtons.animatingSendButton {
                    let imageNode = self.actionButtons.sendButton.imageNode
                    
                    if transition.isAnimated && !self.actionButtons.sendButton.alpha.isZero && self.actionButtons.sendButton.layer.animation(forKey: "opacity") == nil, let previousImage = imageNode.image {
                        let tempView = UIImageView(image: previousImage)
                        self.actionButtons.sendButton.view.addSubview(tempView)
                        tempView.frame = imageNode.frame
                        tempView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak tempView] _ in
                            tempView?.removeFromSuperview()
                        })
                        tempView.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2, removeOnCompletion: false)
                        
                        imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        imageNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.2)
                    }
                    self.actionButtons.sendButtonHasApplyIcon = sendButtonHasApplyIcon
                    if self.actionButtons.sendButtonHasApplyIcon {
                        self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelApplyButtonImage(interfaceState.theme), for: [])
                    } else {
                        self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(interfaceState.theme), for: [])
                    }
                }
            }
        }
        
        var textFieldMinHeight: CGFloat = 33.0
        if let presentationInterfaceState = self.presentationInterfaceState {
            textFieldMinHeight = calclulateTextFieldMinHeight(presentationInterfaceState, metrics: metrics)
        }
        let minimalHeight: CGFloat = 14.0 + textFieldMinHeight
        
        let baseWidth = width - leftInset - rightInset
        let (_, textFieldHeight) = self.calculateTextFieldMetrics(width: baseWidth, maxHeight: maxHeight, metrics: metrics)
        let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight, metrics: metrics)
                                    
        let composeButtonsOffset: CGFloat = 0.0
        let textInputBackgroundWidthOffset: CGFloat = 0.0
        
        self.updateCounterTextNode(transition: transition)
       
        let actionButtonsFrame = CGRect(origin: CGPoint(x: width - rightInset - 43.0 - UIScreenPixel + composeButtonsOffset, y: panelHeight - minimalHeight), size: CGSize(width: 44.0, height: minimalHeight))
        transition.updateFrame(node: self.actionButtons, frame: actionButtonsFrame)
        
        if let presentationInterfaceState = self.presentationInterfaceState {
            self.actionButtons.updateLayout(size: CGSize(width: 44.0, height: minimalHeight), transition: transition, interfaceState: presentationInterfaceState)
        }

        var textFieldInsets = self.textFieldInsets(metrics: metrics)
        if additionalSideInsets.right > 0.0 {
            textFieldInsets.right += additionalSideInsets.right / 3.0
        }

        var textInputViewRealInsets = UIEdgeInsets()
        if let presentationInterfaceState = self.presentationInterfaceState {
            textInputViewRealInsets = calculateTextFieldRealInsets(presentationInterfaceState)
        }
        
        let textInputFrame = CGRect(x: leftInset + textFieldInsets.left, y: textFieldInsets.top, width: baseWidth - textFieldInsets.left - textFieldInsets.right + textInputBackgroundWidthOffset, height: panelHeight - textFieldInsets.top - textFieldInsets.bottom)
        transition.updateFrame(node: self.textInputContainer, frame: textInputFrame)
        transition.updateFrame(node: self.textInputContainerBackgroundNode, frame: CGRect(origin: CGPoint(), size: textInputFrame.size))
        
        if let textInputNode = self.textInputNode {
            let textFieldFrame = CGRect(origin: CGPoint(x: self.textInputViewInternalInsets.left, y: self.textInputViewInternalInsets.top), size: CGSize(width: textInputFrame.size.width - (self.textInputViewInternalInsets.left + self.textInputViewInternalInsets.right), height: textInputFrame.size.height - self.textInputViewInternalInsets.top - textInputViewInternalInsets.bottom))
            let shouldUpdateLayout = textFieldFrame.size != textInputNode.frame.size
            transition.updateFrame(node: textInputNode, frame: textFieldFrame)
            if shouldUpdateLayout {
                textInputNode.layout()
            }
        }
        
        var inputHasText = false
        if let textInputNode = self.textInputNode, let attributedText = textInputNode.attributedText, attributedText.length != 0 {
            inputHasText = true
        }
        
        self.textPlaceholderNode.isHidden = inputHasText
          
        transition.updateFrame(node: self.textPlaceholderNode, frame: CGRect(origin: CGPoint(x: leftInset + textFieldInsets.left + self.textInputViewInternalInsets.left, y: textFieldInsets.top + self.textInputViewInternalInsets.top + textInputViewRealInsets.top + UIScreenPixel), size: self.textPlaceholderNode.frame.size))
        transition.updateFrame(layer: self.textInputBackgroundNode.layer, frame: CGRect(x: leftInset + textFieldInsets.left, y: textFieldInsets.top, width: baseWidth - textFieldInsets.left - textFieldInsets.right + textInputBackgroundWidthOffset, height: panelHeight - textFieldInsets.top - textFieldInsets.bottom))
        
        self.actionButtons.updateAccessibility()
        
        if let prevInputPanelNode = self.prevInputPanelNode {
            prevInputPanelNode.frame = CGRect(origin: .zero, size: prevInputPanelNode.frame.size)
        }
        
        return panelHeight
    }
    
    override func canHandleTransition(from prevInputPanelNode: ChatInputPanelNode?) -> Bool {
        return false
    }
    
    @objc func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let textInputNode = self.textInputNode, let presentationInterfaceState = self.presentationInterfaceState {
            let baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            refreshChatTextInputAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize)
            refreshChatTextInputTypingAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize)
            
            let inputTextState = self.inputTextState
            
            self.interfaceInteraction?.updateTextInputStateAndMode({ _, inputMode in return (inputTextState, inputMode) })
            self.interfaceInteraction?.updateInputLanguage({ _ in return textInputNode.textInputMode.primaryLanguage })
            self.updateTextNodeText(animated: true)
            
            self.updateCounterTextNode(transition: .immediate)
        }
    }
    
    private func updateCounterTextNode(transition: ContainedViewLayoutTransition) {
        if let textInputNode = self.textInputNode, let presentationInterfaceState = self.presentationInterfaceState, let editMessage = presentationInterfaceState.interfaceState.editMessage, let inputTextMaxLength = editMessage.inputTextMaxLength {
            let textCount = Int32(textInputNode.textView.text.count)
            let counterColor: UIColor = textCount > inputTextMaxLength ? presentationInterfaceState.theme.chat.inputPanel.panelControlDestructiveColor : presentationInterfaceState.theme.chat.inputPanel.panelControlColor
            
            let remainingCount = max(-999, inputTextMaxLength - textCount)
            let counterText = remainingCount >= 5 ? "" : "\(remainingCount)"
            self.counterTextNode.attributedText = NSAttributedString(string: counterText, font: counterFont, textColor: counterColor)
        } else {
            self.counterTextNode.attributedText = NSAttributedString(string: "", font: counterFont, textColor: .black)
        }
        
        if let (width, leftInset, rightInset, _, maxHeight, metrics, _) = self.validLayout {
            let composeButtonsOffset: CGFloat = 0.0
            
            let (_, textFieldHeight) = self.calculateTextFieldMetrics(width: width - leftInset - rightInset, maxHeight: maxHeight, metrics: metrics)
            let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight, metrics: metrics)
            var textFieldMinHeight: CGFloat = 33.0
            if let presentationInterfaceState = self.presentationInterfaceState {
                textFieldMinHeight = calclulateTextFieldMinHeight(presentationInterfaceState, metrics: metrics)
            }
            let minimalHeight: CGFloat = 14.0 + textFieldMinHeight
            
            let counterSize = self.counterTextNode.updateLayout(CGSize(width: 44.0, height: 44.0))
            let actionButtonsOriginX = width - rightInset - 43.0 - UIScreenPixel + composeButtonsOffset
            let counterFrame = CGRect(origin: CGPoint(x: actionButtonsOriginX, y: panelHeight - minimalHeight - counterSize.height + 3.0), size: CGSize(width: width - actionButtonsOriginX - rightInset, height: counterSize.height))
            transition.updateFrame(node: self.counterTextNode, frame: counterFrame)
        }
    }
    
    private func updateTextNodeText(animated: Bool) {
        var inputHasText = false
        if let textInputNode = self.textInputNode, let attributedText = textInputNode.attributedText, attributedText.length != 0 {
            inputHasText = true
        }
        
        if let _ = self.presentationInterfaceState {
            self.textPlaceholderNode.isHidden = inputHasText
        }
        
        self.updateTextHeight(animated: animated)
    }
    
    private func updateTextHeight(animated: Bool) {
        if let (width, leftInset, rightInset, additionalSideInsets, maxHeight, metrics, _) = self.validLayout {
            let (_, textFieldHeight) = self.calculateTextFieldMetrics(width: width - leftInset - rightInset - additionalSideInsets.right, maxHeight: maxHeight, metrics: metrics)
            let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight, metrics: metrics)
            if !self.bounds.size.height.isEqual(to: panelHeight) {
                self.updateHeight(animated)
            }
        }
    }
    
    @objc func editableTextNodeShouldReturn(_ editableTextNode: ASEditableTextNode) -> Bool {
        if self.actionButtons.sendButton.supernode != nil && !self.actionButtons.sendButton.isHidden && !self.actionButtons.sendButton.alpha.isZero {
            self.sendButtonPressed()
        }
        return false
    }
    
    private func applyUpdateSendButtonIcon() {
        if let interfaceState = self.presentationInterfaceState {
            let sendButtonHasApplyIcon = interfaceState.interfaceState.editMessage != nil
            
            if sendButtonHasApplyIcon != self.actionButtons.sendButtonHasApplyIcon {
                self.actionButtons.sendButtonHasApplyIcon = sendButtonHasApplyIcon
                if self.actionButtons.sendButtonHasApplyIcon {
                    self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelApplyButtonImage(interfaceState.theme), for: [])
                } else {
                    if case .scheduledMessages = interfaceState.subject {
                        self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelScheduleButtonImage(interfaceState.theme), for: [])
                    } else {
                        self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(interfaceState.theme), for: [])
                    }
                }
            }
        }
    }
    
    @objc func editableTextNodeDidChangeSelection(_ editableTextNode: ASEditableTextNode, fromSelectedRange: NSRange, toSelectedRange: NSRange, dueToEditing: Bool) {
        if !dueToEditing && !self.updatingInputState {
            let inputTextState = self.inputTextState
            self.interfaceInteraction?.updateTextInputStateAndMode({ _, inputMode in return (inputTextState, inputMode) })
        }
        
        if let textInputNode = self.textInputNode, let presentationInterfaceState = self.presentationInterfaceState {
            if case .format = self.inputMenu.state {
                self.inputMenu.deactivate()
                UIMenuController.shared.update()
            }
            
            let baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            refreshChatTextInputTypingAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize)
        }
    }
    
    @objc func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
            return (.text, state.keyboardButtonsMessage?.id)
        })
        self.inputMenu.activate()
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.storedInputLanguage = editableTextNode.textInputMode.primaryLanguage
        self.inputMenu.deactivate()
    }
    
    func editableTextNodeTarget(forAction action: Selector) -> ASEditableTextNodeTargetForAction? {
        if action == Selector(("_accessibilitySpeak:")) {
            if case .format = self.inputMenu.state {
                return ASEditableTextNodeTargetForAction(target: nil)
            } else if let textInputNode = self.textInputNode, textInputNode.selectedRange.length > 0 {
                return ASEditableTextNodeTargetForAction(target: self)
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        } else if action == Selector(("_accessibilitySpeakSpellOut:")) {
            if case .format = self.inputMenu.state {
                return ASEditableTextNodeTargetForAction(target: nil)
            } else if let textInputNode = self.textInputNode, textInputNode.selectedRange.length > 0 {
                return nil
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        }
        else if action == Selector("_accessibilitySpeakLanguageSelection:") || action == Selector("_accessibilityPauseSpeaking:") || action == Selector("_accessibilitySpeakSentence:") {
            return ASEditableTextNodeTargetForAction(target: nil)
        } else if action == Selector(("_showTextStyleOptions:")) {
            if case .general = self.inputMenu.state {
                if let textInputNode = self.textInputNode, textInputNode.attributedText == nil || textInputNode.attributedText!.length == 0 || textInputNode.selectedRange.length == 0 {
                    return ASEditableTextNodeTargetForAction(target: nil)
                }
                return ASEditableTextNodeTargetForAction(target: self)
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        } else if action == #selector(self.formatAttributesBold(_:)) || action == #selector(self.formatAttributesItalic(_:)) || action == #selector(self.formatAttributesMonospace(_:)) || action == #selector(self.formatAttributesLink(_:)) || action == #selector(self.formatAttributesStrikethrough(_:)) || action == #selector(self.formatAttributesUnderline(_:)) {
            if case .format = self.inputMenu.state {
                return ASEditableTextNodeTargetForAction(target: self)
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        }
        if case .format = self.inputMenu.state {
            return ASEditableTextNodeTargetForAction(target: nil)
        }
        return nil
    }
    
    @objc func _accessibilitySpeak(_ sender: Any) {
        var text = ""
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            text = current.inputText.attributedSubstring(from: NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count)).string
            return (current, inputMode)
        }
        speakText(text)
        
        if #available(iOS 13.0, *) {
            UIMenuController.shared.hideMenu()
        } else {
            UIMenuController.shared.isMenuVisible = false
            UIMenuController.shared.update()
        }
    }
    
    @objc func _showTextStyleOptions(_ sender: Any) {
        if let textInputNode = self.textInputNode {
            self.inputMenu.format(view: textInputNode.view, rect: textInputNode.selectionRect.offsetBy(dx: 0.0, dy: -textInputNode.textView.contentOffset.y).insetBy(dx: 0.0, dy: -1.0))
        }
    }
    
    @objc func formatAttributesBold(_ sender: Any) {
        self.inputMenu.back()
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.bold), inputMode)
        }
    }
    
    @objc func formatAttributesItalic(_ sender: Any) {
        self.inputMenu.back()
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.italic), inputMode)
        }
    }
    
    @objc func formatAttributesMonospace(_ sender: Any) {
        self.inputMenu.back()
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.monospace), inputMode)
        }
    }
    
    @objc func formatAttributesLink(_ sender: Any) {
        self.inputMenu.back()
        self.interfaceInteraction?.openLinkEditing()
    }
    
    @objc func formatAttributesStrikethrough(_ sender: Any) {
        self.inputMenu.back()
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.strikethrough), inputMode)
        }
    }
    
    @objc func formatAttributesUnderline(_ sender: Any) {
        self.inputMenu.back()
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.underline), inputMode)
        }
    }
    
    @objc func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        var cleanText = text
        let removeSequences: [String] = ["\u{202d}", "\u{202c}"]
        for sequence in removeSequences {
            inner: while true {
                if let range = cleanText.range(of: sequence) {
                    cleanText.removeSubrange(range)
                } else {
                    break inner
                }
            }
        }
                
        if cleanText != text {
            let string = NSMutableAttributedString(attributedString: editableTextNode.attributedText ?? NSAttributedString())
            var textColor: UIColor = .black
            var accentTextColor: UIColor = .blue
            var baseFontSize: CGFloat = 17.0
            if let presentationInterfaceState = self.presentationInterfaceState {
                textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
                accentTextColor = presentationInterfaceState.theme.chat.inputPanel.panelControlAccentColor
                baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            }
            let cleanReplacementString = textAttributedStringForStateText(NSAttributedString(string: cleanText), fontSize: baseFontSize, textColor: textColor, accentTextColor: accentTextColor, writingDirection: nil)
            string.replaceCharacters(in: range, with: cleanReplacementString)
            self.textInputNode?.attributedText = string
            self.textInputNode?.selectedRange = NSMakeRange(range.lowerBound + cleanReplacementString.length, 0)
            self.updateTextNodeText(animated: true)
            return false
        }
        return true
    }
    
    @objc func editableTextNodeShouldCopy(_ editableTextNode: ASEditableTextNode) -> Bool {
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            storeInputTextInPasteboard(current.inputText.attributedSubstring(from: NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count)))
            return (current, inputMode)
        }
        return false
    }
    
    @objc func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool {
        let pasteboard = UIPasteboard.general
        
        var attributedString: NSAttributedString?
        if let data = pasteboard.data(forPasteboardType: kUTTypeRTF as String) {
            attributedString = chatInputStateStringFromRTF(data, type: NSAttributedString.DocumentType.rtf)
        } else if let data = pasteboard.data(forPasteboardType: "com.apple.flat-rtfd") {
            attributedString = chatInputStateStringFromRTF(data, type: NSAttributedString.DocumentType.rtfd)
        }
        
        if let attributedString = attributedString {
            self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                if let inputText = current.inputText.mutableCopy() as? NSMutableAttributedString {
                    inputText.replaceCharacters(in: NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count), with: attributedString)
                    let updatedRange = current.selectionRange.lowerBound + attributedString.length
                    return (ChatTextInputState(inputText: inputText, selectionRange: updatedRange ..< updatedRange), inputMode)
                } else {
                    return (ChatTextInputState(inputText: attributedString), inputMode)
                }
            }
            return false
        }
        return true
    }
    
    @objc func sendButtonPressed() {
        if let textInputNode = self.textInputNode, let presentationInterfaceState = self.presentationInterfaceState, let editMessage = presentationInterfaceState.interfaceState.editMessage, let inputTextMaxLength = editMessage.inputTextMaxLength {
            let textCount = Int32(textInputNode.textView.text.count)
            let remainingCount = inputTextMaxLength - textCount

            if remainingCount < 0 {
                textInputNode.layer.addShakeAnimation()
                self.hapticFeedback.error()
                return
            }
        }
    
        self.sendMessage(.generic)
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

    func frameForInputActionButton() -> CGRect? {
        if !self.actionButtons.alpha.isZero {
            if self.actionButtons.micButton.alpha.isZero {
                return self.actionButtons.frame.insetBy(dx: 0.0, dy: 6.0).offsetBy(dx: 4.0, dy: 0.0)
            } else {
                return self.actionButtons.frame.insetBy(dx: 0.0, dy: 6.0).offsetBy(dx: 2.0, dy: 0.0)
            }
        }
        return nil
    }
}
