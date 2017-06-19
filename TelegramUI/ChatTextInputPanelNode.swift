import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore

private let searchLayoutProgressImage = generateImage(CGSize(width: 22.0, height: 22.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(rgb: 0x9099A2, alpha: 0.6).cgColor)
    
    let lineWidth: CGFloat = 2.0
    let cutoutWidth: CGFloat = 4.0
    context.setLineWidth(lineWidth)
    
    context.strokeEllipse(in: CGRect(origin: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0), size: CGSize(width: size.width - lineWidth, height: size.height - lineWidth)))
    context.clear(CGRect(origin: CGPoint(x: (size.width - cutoutWidth) / 2.0, y: 0.0), size: CGSize(width: cutoutWidth, height: size.height / 2.0)))
})

enum ChatTextInputAccessoryItem: Equatable {
    case keyboard
    case stickers
    case inputButtons
    case messageAutoremoveTimeout(Int32?)
    
    static func ==(lhs: ChatTextInputAccessoryItem, rhs: ChatTextInputAccessoryItem) -> Bool {
        switch lhs {
            case .keyboard:
                if case .keyboard = rhs {
                    return true
                } else {
                    return false
                }
            case .stickers:
                if case .stickers = rhs {
                    return true
                } else {
                    return false
                }
            case .inputButtons:
                if case .inputButtons = rhs {
                    return true
                } else {
                    return false
                }
            case let .messageAutoremoveTimeout(lhsTimeout):
                if case let .messageAutoremoveTimeout(rhsTimeout) = rhs, lhsTimeout == rhsTimeout {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct ChatTextInputPanelAudioRecordingState: Equatable {
    let recorder: ManagedAudioRecorder
    
    init(recorder: ManagedAudioRecorder) {
        self.recorder = recorder
    }
    
    static func ==(lhs: ChatTextInputPanelAudioRecordingState, rhs: ChatTextInputPanelAudioRecordingState) -> Bool {
        return lhs.recorder === rhs.recorder
    }
}

struct ChatTextInputPanelState: Equatable {
    let accessoryItems: [ChatTextInputAccessoryItem]
    let contextPlaceholder: NSAttributedString?
    let audioRecordingState: ChatTextInputPanelAudioRecordingState?
    
    init(accessoryItems: [ChatTextInputAccessoryItem], contextPlaceholder: NSAttributedString?, audioRecordingState: ChatTextInputPanelAudioRecordingState?) {
        self.accessoryItems = accessoryItems
        self.contextPlaceholder = contextPlaceholder
        self.audioRecordingState = audioRecordingState
    }
    
    init() {
        self.accessoryItems = []
        self.contextPlaceholder = nil
        self.audioRecordingState = nil
    }
    
    static func ==(lhs: ChatTextInputPanelState, rhs: ChatTextInputPanelState) -> Bool {
        if lhs.accessoryItems != rhs.accessoryItems {
            return false
        }
        if let lhsContextPlaceholder = lhs.contextPlaceholder, let rhsContextPlaceholder = rhs.contextPlaceholder {
            return lhsContextPlaceholder.isEqual(to: rhsContextPlaceholder)
        } else if (lhs.contextPlaceholder != nil) != (rhs.contextPlaceholder != nil) {
            return false
        }
        if lhs.audioRecordingState != rhs.audioRecordingState {
            return false
        }
        return true
    }
    
    func withUpdatedAudioRecordingState(_ audioRecordingState: ChatTextInputPanelAudioRecordingState?) -> ChatTextInputPanelState {
        return ChatTextInputPanelState(accessoryItems: self.accessoryItems, contextPlaceholder: self.contextPlaceholder, audioRecordingState: audioRecordingState)
    }
}

private final class AccessoryItemIconButton: HighlightableButton {
    private let item: ChatTextInputAccessoryItem
    
    init(item: ChatTextInputAccessoryItem, theme: PresentationTheme, strings: PresentationStrings) {
        self.item = item
        
        super.init(frame: CGRect())
        
        switch item {
            case .keyboard:
                self.setImage(PresentationResourcesChat.chatInputTextFieldKeyboardImage(theme), for: [])
            case .stickers:
                self.setImage(PresentationResourcesChat.chatInputTextFieldStickersImage(theme), for: [])
            case .inputButtons:
                self.setImage(PresentationResourcesChat.chatInputTextFieldInputButtonsImage(theme), for: [])
            case let .messageAutoremoveTimeout(timeout):
                if let timeout = timeout {
                    self.setImage(nil, for: [])
                    self.titleLabel?.font = Font.regular(12.0)
                    self.setTitleColor(theme.chat.inputPanel.inputControlColor, for: [])
                    self.setTitle(shortTimeIntervalString(strings: strings, value: timeout), for: [])
                } else {
                    self.setImage(PresentationResourcesChat.chatInputTextFieldTimerImage(theme), for: [])
                    self.imageEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 1.0, right: 0.0)
                }
        }
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        switch self.item {
            case .keyboard:
                self.setImage(PresentationResourcesChat.chatInputTextFieldKeyboardImage(theme), for: [])
            case .stickers:
                self.setImage(PresentationResourcesChat.chatInputTextFieldStickersImage(theme), for: [])
            case .inputButtons:
                self.setImage(PresentationResourcesChat.chatInputTextFieldInputButtonsImage(theme), for: [])
            case let .messageAutoremoveTimeout(timeout):
                if let timeout = timeout {
                    self.setImage(nil, for: [])
                    self.titleLabel?.font = Font.regular(12.0)
                    self.setTitleColor(theme.chat.inputPanel.inputControlColor, for: [])
                    self.setTitle(shortTimeIntervalString(strings: strings, value: timeout), for: [])
                } else {
                    self.setImage(PresentationResourcesChat.chatInputTextFieldTimerImage(theme), for: [])
                    self.imageEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 1.0, right: 0.0)
                }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var buttonWidth: CGFloat {
        switch self.item {
            case .keyboard, .stickers, .inputButtons:
                return (self.image(for: [])?.size.width ?? 0.0) + CGFloat(8.0)
            case let .messageAutoremoveTimeout(timeout):
                return 24.0
        }
    }
}

class ChatTextInputPanelNode: ChatInputPanelNode, ASEditableTextNodeDelegate {
    var textPlaceholderNode: TextNode
    var contextPlaceholderNode: TextNode?
    var textInputNode: ASEditableTextNode?
    
    let textInputBackgroundView: UIImageView
    let micButton: ChatTextInputAudioRecordingButton
    let sendButton: HighlightableButton
    let attachmentButton: HighlightableButton
    let searchLayoutClearButton: HighlightableButton
    let searchLayoutProgressView: UIImageView
    var audioRecordingInfoContainerNode: ASDisplayNode?
    var audioRecordingDotNode: ASImageNode?
    var audioRecordingTimeNode: ChatTextInputAudioRecordingTimeNode?
    var audioRecordingCancelIndicator: ChatTextInputAudioRecordingCancelIndicator?
    
    private var accessoryItemButtons: [(ChatTextInputAccessoryItem, AccessoryItemIconButton)] = []
    
    var displayAttachmentMenu: () -> Void = { }
    var sendMessage: () -> Void = { }
    var updateHeight: () -> Void = { }
    
    var updateActivity: () -> Void = { }
    
    private var updatingInputState = false
    
    private var currentPlaceholder: String?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var keepSendButtonEnabled = false
    private var extendedSearchLayout = false
    
    private var theme: PresentationTheme?
    private var strings: PresentationStrings?
    
    var inputTextState: ChatTextInputState {
        if let textInputNode = self.textInputNode {
            let text = textInputNode.attributedText?.string ?? ""
            let selectionRange: Range<Int> = textInputNode.selectedRange.location ..< (textInputNode.selectedRange.location + textInputNode.selectedRange.length)
            return ChatTextInputState(inputText: text, selectionRange: selectionRange)
        } else {
            return ChatTextInputState()
        }
    }
    
    override var account: Account? {
        didSet {
            self.micButton.account = self.account
        }
    }
    
    func updateInputTextState(_ state: ChatTextInputState, keepSendButtonEnabled: Bool, extendedSearchLayout: Bool, animated: Bool) {
        if !state.inputText.isEmpty && self.textInputNode == nil {
            self.loadTextInputNode()
        }
        
        if let textInputNode = self.textInputNode {
            self.updatingInputState = true
            var textColor: UIColor = .black
            if let presentationInterfaceState = self.presentationInterfaceState {
                textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
            }
            textInputNode.attributedText = NSAttributedString(string: state.inputText, font: Font.regular(17.0), textColor: textColor)
            textInputNode.selectedRange = NSMakeRange(state.selectionRange.lowerBound, state.selectionRange.count)
            self.updatingInputState = false
            self.keepSendButtonEnabled = keepSendButtonEnabled
            self.extendedSearchLayout = extendedSearchLayout
            self.updateTextNodeText(animated: animated)
        }
    }
    
    func updateKeepSendButtonEnabled(keepSendButtonEnabled: Bool, extendedSearchLayout: Bool, animated: Bool) {
        if keepSendButtonEnabled != self.keepSendButtonEnabled || extendedSearchLayout != self.extendedSearchLayout {
            self.keepSendButtonEnabled = keepSendButtonEnabled
            self.extendedSearchLayout = extendedSearchLayout
            self.updateTextNodeText(animated: animated)
        }
    }
    
    var text: String {
        get {
            return self.textInputNode?.attributedText?.string ?? ""
        } set(value) {
            if let textInputNode = self.textInputNode {
                var textColor: UIColor = .black
                if let presentationInterfaceState = self.presentationInterfaceState {
                    textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
                }
                textInputNode.attributedText = NSAttributedString(string: value, font: Font.regular(17.0), textColor: textColor)
                self.editableTextNodeDidUpdateText(textInputNode)
            }
        }
    }
    
    let textFieldInsets = UIEdgeInsets(top: 6.0, left: 42.0, bottom: 6.0, right: 42.0)
    let textInputViewInternalInsets = UIEdgeInsets(top: 6.5, left: 13.0, bottom: 7.5, right: 13.0)
    let accessoryButtonSpacing: CGFloat = 0.0
    let accessoryButtonInset: CGFloat = 4.0 + UIScreenPixel
    
    override init() {
        self.textInputBackgroundView = UIImageView()
        self.textPlaceholderNode = TextNode()
        self.textPlaceholderNode.isLayerBacked = true
        self.attachmentButton = HighlightableButton()
        self.searchLayoutClearButton = HighlightableButton()
        self.searchLayoutProgressView = UIImageView(image: searchLayoutProgressImage)
        self.searchLayoutProgressView.isHidden = true
        self.micButton = ChatTextInputAudioRecordingButton()
        self.sendButton = HighlightableButton()
        
        super.init()
        
        self.attachmentButton.addTarget(self, action: #selector(self.attachmentButtonPressed), for: .touchUpInside)
        self.view.addSubview(self.attachmentButton)
        
        self.micButton.beginRecording = { [weak self] in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.beginAudioRecording()
            }
        }
        self.micButton.endRecording = { [weak self] sendAudio in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.finishAudioRecording(sendAudio)
            }
        }
        self.micButton.offsetRecordingControls = { [weak self] in
            if let strongSelf = self, let presentationInterfaceState = strongSelf.presentationInterfaceState {
                let _ = strongSelf.updateLayout(width: strongSelf.bounds.size.width, transition: .immediate, interfaceState: presentationInterfaceState)
            }
        }
        self.view.addSubview(self.micButton)
        
        self.sendButton.addTarget(self, action: #selector(self.sendButtonPressed), for: .touchUpInside)
        self.sendButton.alpha = 0.0
        self.view.addSubview(self.sendButton)
        
        self.searchLayoutClearButton.addTarget(self, action: #selector(self.searchLayoutClearButtonPressed), for: .touchUpInside)
        self.searchLayoutClearButton.alpha = 0.0
        
        self.searchLayoutClearButton.addSubview(self.searchLayoutProgressView)
        
        self.view.addSubview(self.textInputBackgroundView)
        
        self.addSubnode(self.textPlaceholderNode)
        
        self.view.addSubview(self.searchLayoutClearButton)
        
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
        var textColor: UIColor = .black
        var keyboardAppearance: UIKeyboardAppearance = UIKeyboardAppearance.default
        if let presentationInterfaceState = self.presentationInterfaceState {
            textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
            switch presentationInterfaceState.theme.chat.inputPanel.keyboardColor {
                case .light:
                    keyboardAppearance = .default
                case .dark:
                    keyboardAppearance = .dark
            }
        }
        textInputNode.typingAttributes = [NSFontAttributeName: Font.regular(17.0), NSForegroundColorAttributeName: textColor]
        textInputNode.clipsToBounds = true
        textInputNode.delegate = self
        textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        textInputNode.keyboardAppearance = keyboardAppearance
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
            
            if self.theme !== interfaceState.theme {
                if self.theme == nil || !self.theme!.chat.inputPanel.inputTextColor.isEqual(interfaceState.theme.chat.inputPanel.inputTextColor) {
                    let textColor = interfaceState.theme.chat.inputPanel.inputTextColor
                    
                    if let textInputNode = self.textInputNode {
                        if let text = textInputNode.attributedText?.string {
                            let range = textInputNode.selectedRange
                            textInputNode.attributedText = NSAttributedString(string: text, font: Font.regular(17.0), textColor: textColor)
                            textInputNode.selectedRange = range
                        }
                        textInputNode.typingAttributes = [NSFontAttributeName: Font.regular(17.0), NSForegroundColorAttributeName: textColor]
                    }
                }
                
                let keyboardAppearance: UIKeyboardAppearance
                switch interfaceState.theme.chat.inputPanel.keyboardColor {
                    case .light:
                        keyboardAppearance = .default
                    case .dark:
                        keyboardAppearance = .dark
                }
                self.textInputNode?.keyboardAppearance = keyboardAppearance
                
                self.theme = interfaceState.theme
                
                
                self.attachmentButton.setImage(PresentationResourcesChat.chatInputPanelAttachmentButtonImage(interfaceState.theme), for: [])
                self.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendButtonImage(interfaceState.theme), for: [])
                self.micButton.updateTheme(theme: interfaceState.theme)
                
                self.textInputBackgroundView.image = PresentationResourcesChat.chatInputTextFieldBackgroundImage(interfaceState.theme)
                
                self.searchLayoutClearButton.setImage(PresentationResourcesChat.chatInputTextFieldClearImage(interfaceState.theme), for: [])
                
                if let audioRecordingDotNode = self.audioRecordingDotNode {
                    audioRecordingDotNode.image = PresentationResourcesChat.chatInputPanelMediaRecordingDotImage(interfaceState.theme)
                }
                
                self.audioRecordingTimeNode?.updateTheme(theme: interfaceState.theme)
                self.audioRecordingCancelIndicator?.updateTheme(theme: interfaceState.theme)
                
                for (_, button) in self.accessoryItemButtons {
                    button.updateThemeAndStrings(theme: interfaceState.theme, strings: interfaceState.strings)
                }
            } else if self.strings !== interfaceState.strings {
                self.strings = interfaceState.strings
                
                for (_, button) in self.accessoryItemButtons {
                    button.updateThemeAndStrings(theme: interfaceState.theme, strings: interfaceState.strings)
                }
            }
            
            if let peer = interfaceState.peer, previousState?.peer == nil || !peer.isEqual(previousState!.peer!) {
                let placeholder: String
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    placeholder = interfaceState.strings.Conversation_InputTextBroadcastPlaceholder
                } else {
                    placeholder = interfaceState.strings.Conversation_InputTextPlaceholder
                }
                if self.currentPlaceholder != placeholder {
                    self.currentPlaceholder = placeholder
                    let placeholderLayout = TextNode.asyncLayout(self.textPlaceholderNode)
                    let (placeholderSize, placeholderApply) = placeholderLayout(NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: interfaceState.theme.chat.inputPanel.inputPlaceholderColor), nil, 1, .end, CGSize(width: 320.0, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
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
        if self.presentationInterfaceState?.inputTextPanelState.accessoryItems.count == self.accessoryItemButtons.count {
            for i in 0 ..< interfaceState.inputTextPanelState.accessoryItems.count {
                if interfaceState.inputTextPanelState.accessoryItems[i] != self.accessoryItemButtons[i].0 {
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
            for item in interfaceState.inputTextPanelState.accessoryItems {
                var itemAndButton: (ChatTextInputAccessoryItem, AccessoryItemIconButton)?
                for i in 0 ..< self.accessoryItemButtons.count {
                    if self.accessoryItemButtons[i].0 == item {
                        itemAndButton = self.accessoryItemButtons[i]
                        self.accessoryItemButtons.remove(at: i)
                        break
                    }
                }
                if itemAndButton == nil {
                    let button = AccessoryItemIconButton(item: item, theme: interfaceState.theme, strings: interfaceState.strings)
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
        
        var audioRecordingItemsVerticalOffset: CGFloat = 0.0
        if let audioRecordingState = interfaceState.inputTextPanelState.audioRecordingState {
            self.micButton.audioRecorder = audioRecordingState.recorder
            let audioRecordingInfoContainerNode: ASDisplayNode
            if let currentAudioRecordingInfoContainerNode = self.audioRecordingInfoContainerNode {
                audioRecordingInfoContainerNode = currentAudioRecordingInfoContainerNode
            } else {
                audioRecordingInfoContainerNode = ASDisplayNode()
                self.audioRecordingInfoContainerNode = audioRecordingInfoContainerNode
                self.insertSubnode(audioRecordingInfoContainerNode, at: 0)
            }
            
            audioRecordingItemsVerticalOffset = panelHeight * 2.0
            transition.updateAlpha(layer: self.textInputBackgroundView.layer, alpha: 0.0)
            if let textInputNode = self.textInputNode {
                transition.updateAlpha(node: textInputNode, alpha: 0.0)
            }
            for (_, button) in self.accessoryItemButtons {
                transition.updateAlpha(layer: button.layer, alpha: 0.0)
            }
            
            var animateCancelSlideIn = false
            let audioRecordingCancelIndicator: ChatTextInputAudioRecordingCancelIndicator
            if let currentAudioRecordingCancelIndicator = self.audioRecordingCancelIndicator {
                audioRecordingCancelIndicator = currentAudioRecordingCancelIndicator
            } else {
                animateCancelSlideIn = transition.isAnimated
                
                audioRecordingCancelIndicator = ChatTextInputAudioRecordingCancelIndicator(theme: interfaceState.theme, strings: interfaceState.strings)
                self.audioRecordingCancelIndicator = audioRecordingCancelIndicator
                self.insertSubnode(audioRecordingCancelIndicator, at: 0)
            }
            
            audioRecordingCancelIndicator.frame = CGRect(origin: CGPoint(x: floor((width - audioRecordingCancelIndicator.bounds.size.width) / 2.0) - self.micButton.controlsOffset, y: panelHeight - minimalHeight + floor((minimalHeight - audioRecordingCancelIndicator.bounds.size.height) / 2.0)), size: audioRecordingCancelIndicator.bounds.size)
            
            if animateCancelSlideIn {
                let position = audioRecordingCancelIndicator.layer.position
                audioRecordingCancelIndicator.layer.animatePosition(from: CGPoint(x: width + audioRecordingCancelIndicator.bounds.size.width, y: position.y), to: position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            }
            
            var animateTimeSlideIn = false
            let audioRecordingTimeNode: ChatTextInputAudioRecordingTimeNode
            if let currentAudioRecordingTimeNode = self.audioRecordingTimeNode {
                audioRecordingTimeNode = currentAudioRecordingTimeNode
            } else {
                audioRecordingTimeNode = ChatTextInputAudioRecordingTimeNode(theme: interfaceState.theme)
                self.audioRecordingTimeNode = audioRecordingTimeNode
                audioRecordingInfoContainerNode.addSubnode(audioRecordingTimeNode)
                
                if transition.isAnimated {
                    animateTimeSlideIn = true
                }
            }
            
            let audioRecordingTimeSize = audioRecordingTimeNode.measure(CGSize(width: 200.0, height: 100.0))
            
            audioRecordingInfoContainerNode.frame = CGRect(origin: CGPoint(x: min(0.0, audioRecordingCancelIndicator.frame.minX - audioRecordingTimeSize.width - 8.0 - 28.0), y: 0.0), size: CGSize(width: width, height: panelHeight))
            
            audioRecordingTimeNode.frame = CGRect(origin: CGPoint(x: 28.0, y: panelHeight - minimalHeight + floor((minimalHeight - audioRecordingTimeSize.height) / 2.0)), size: audioRecordingTimeSize)
            if animateTimeSlideIn {
                let position = audioRecordingTimeNode.layer.position
                audioRecordingTimeNode.layer.animatePosition(from: CGPoint(x: position.x - 28.0 - audioRecordingTimeSize.width, y: position.y), to: position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            }
            
            audioRecordingTimeNode.audioRecorder = audioRecordingState.recorder
            
            var animateDotSlideIn = false
            let audioRecordingDotNode: ASImageNode
            if let currentAudioRecordingDotNode = self.audioRecordingDotNode {
                audioRecordingDotNode = currentAudioRecordingDotNode
            } else {
                animateDotSlideIn = transition.isAnimated
                
                audioRecordingDotNode = ASImageNode()
                audioRecordingDotNode.image = PresentationResourcesChat.chatInputPanelMediaRecordingDotImage(interfaceState.theme)
                self.audioRecordingDotNode = audioRecordingDotNode
                audioRecordingInfoContainerNode.addSubnode(audioRecordingDotNode)
            }
            audioRecordingDotNode.frame = CGRect(origin: CGPoint(x: audioRecordingTimeNode.frame.minX - 17.0, y: panelHeight - minimalHeight + floor((minimalHeight - 9.0) / 2.0)), size: CGSize(width: 9.0, height: 9.0))
            if animateDotSlideIn {
                let position = audioRecordingDotNode.layer.position
                audioRecordingDotNode.layer.animatePosition(from: CGPoint(x: position.x - 9.0 - 51.0, y: position.y), to: position, duration: 0.7, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak audioRecordingDotNode] finished in
                    if finished {
                        let animation = CAKeyframeAnimation(keyPath: "opacity")
                        animation.values = [1.0 as NSNumber, 1.0 as NSNumber, 0.0 as NSNumber]
                        animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
                        animation.duration = 0.5
                        animation.autoreverses = true
                        animation.repeatCount = Float.infinity
                        
                        audioRecordingDotNode?.layer.add(animation, forKey: "recording")
                    }
                })
            }
        } else {
            self.micButton.audioRecorder = nil
            transition.updateAlpha(layer: self.textInputBackgroundView.layer, alpha: 1.0)
            if let textInputNode = self.textInputNode {
                transition.updateAlpha(node: textInputNode, alpha: 1.0)
            }
            for (_, button) in self.accessoryItemButtons {
                transition.updateAlpha(layer: button.layer, alpha: 1.0)
            }
            
            if let audioRecordingInfoContainerNode = self.audioRecordingInfoContainerNode {
                self.audioRecordingInfoContainerNode = nil
                transition.updateFrame(node: audioRecordingInfoContainerNode, frame: CGRect(origin: CGPoint(x: -width, y: 0.0), size: audioRecordingInfoContainerNode.bounds.size), completion: { [weak audioRecordingInfoContainerNode] _ in
                    audioRecordingInfoContainerNode?.removeFromSupernode()
                })
            }
            
            if let _ = self.audioRecordingDotNode {
                self.audioRecordingDotNode = nil
            }
            
            if let _ = self.audioRecordingTimeNode {
                self.audioRecordingTimeNode = nil
            }
            
            if let audioRecordingCancelIndicator = self.audioRecordingCancelIndicator {
                self.audioRecordingCancelIndicator = nil
                if transition.isAnimated {
                    let position = audioRecordingCancelIndicator.layer.position
                    audioRecordingCancelIndicator.layer.animatePosition(from: position, to: CGPoint(x: 0.0 - audioRecordingCancelIndicator.bounds.size.width, y: position.y), duration: 0.3, removeOnCompletion: false, completion: { [weak audioRecordingCancelIndicator] _ in
                        audioRecordingCancelIndicator?.removeFromSupernode()
                    })
                } else {
                    audioRecordingCancelIndicator.removeFromSupernode()
                }
            }
        }
        
        transition.updateFrame(layer: self.attachmentButton.layer, frame: CGRect(origin: CGPoint(x: 2.0 - UIScreenPixel, y: panelHeight - minimalHeight + audioRecordingItemsVerticalOffset), size: CGSize(width: 40.0, height: minimalHeight)))
        
        var composeButtonsOffset: CGFloat = 0.0
        var textInputBackgroundWidthOffset: CGFloat = 0.0
        if self.extendedSearchLayout {
            composeButtonsOffset = 44.0
            textInputBackgroundWidthOffset = 36.0
        }
        transition.updateFrame(layer: self.micButton.layer, frame: CGRect(origin: CGPoint(x: width - 43.0 - UIScreenPixel + composeButtonsOffset, y: panelHeight - minimalHeight - UIScreenPixel), size: CGSize(width: 44.0, height: minimalHeight)))
        transition.updateFrame(layer: self.sendButton.layer, frame: CGRect(origin: CGPoint(x: width - 43.0 - UIScreenPixel + composeButtonsOffset, y: panelHeight - minimalHeight - UIScreenPixel), size: CGSize(width: 44.0, height: minimalHeight)))
        
        let searchLayoutClearButtonSize = CGSize(width: 44.0, height: minimalHeight)
        transition.updateFrame(layer: self.searchLayoutClearButton.layer, frame: CGRect(origin: CGPoint(x: width - self.textFieldInsets.left - self.textFieldInsets.right + textInputBackgroundWidthOffset + 3.0, y: panelHeight - minimalHeight), size: searchLayoutClearButtonSize))

        let searchProgressSize = self.searchLayoutProgressView.bounds.size
        transition.updateFrame(layer: self.searchLayoutProgressView.layer, frame: CGRect(origin: CGPoint(x: floor((searchLayoutClearButtonSize.width - searchProgressSize.width) / 2.0), y: floor((searchLayoutClearButtonSize.height - searchProgressSize.height) / 2.0)), size: searchProgressSize))
        
        if let textInputNode = self.textInputNode {
            transition.updateFrame(node: textInputNode, frame: CGRect(x: self.textFieldInsets.left + self.textInputViewInternalInsets.left, y: self.textFieldInsets.top + self.textInputViewInternalInsets.top + audioRecordingItemsVerticalOffset, width: width - self.textFieldInsets.left - self.textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right - accessoryButtonsWidth, height: panelHeight - self.textFieldInsets.top - self.textFieldInsets.bottom - self.textInputViewInternalInsets.top - self.textInputViewInternalInsets.bottom))
        }
        
        if let contextPlaceholder = interfaceState.inputTextPanelState.contextPlaceholder {
            let placeholderLayout = TextNode.asyncLayout(self.contextPlaceholderNode)
            let (placeholderSize, placeholderApply) = placeholderLayout(contextPlaceholder, nil, 1, .end, CGSize(width: width - self.textFieldInsets.left - self.textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right - accessoryButtonsWidth, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            let contextPlaceholderNode = placeholderApply()
            if let currentContextPlaceholderNode = self.contextPlaceholderNode, currentContextPlaceholderNode !== contextPlaceholderNode {
                self.contextPlaceholderNode = nil
                currentContextPlaceholderNode.removeFromSupernode()
            }
            
            if self.contextPlaceholderNode !== contextPlaceholderNode {
                self.contextPlaceholderNode = contextPlaceholderNode
                self.insertSubnode(contextPlaceholderNode, aboveSubnode: self.textPlaceholderNode)
            }
            
            let _ = placeholderApply()
            
            contextPlaceholderNode.frame = CGRect(origin: CGPoint(x: self.textFieldInsets.left + self.textInputViewInternalInsets.left, y: self.textFieldInsets.top + self.textInputViewInternalInsets.top + 0.5 + audioRecordingItemsVerticalOffset), size: placeholderSize.size)
        } else if let contextPlaceholderNode = self.contextPlaceholderNode {
            self.contextPlaceholderNode = nil
            contextPlaceholderNode.removeFromSupernode()
        }
        
        transition.updateFrame(node: self.textPlaceholderNode, frame: CGRect(origin: CGPoint(x: self.textFieldInsets.left + self.textInputViewInternalInsets.left, y: self.textFieldInsets.top + self.textInputViewInternalInsets.top + 0.5 + audioRecordingItemsVerticalOffset), size: self.textPlaceholderNode.frame.size))
        
        transition.updateFrame(layer: self.textInputBackgroundView.layer, frame: CGRect(x: self.textFieldInsets.left, y: self.textFieldInsets.top + audioRecordingItemsVerticalOffset, width: width - self.textFieldInsets.left - self.textFieldInsets.right + textInputBackgroundWidthOffset, height: panelHeight - self.textFieldInsets.top - self.textFieldInsets.bottom))
        
        var nextButtonTopRight = CGPoint(x: width - self.textFieldInsets.right - accessoryButtonInset, y: panelHeight - self.textFieldInsets.bottom - minimalInputHeight + audioRecordingItemsVerticalOffset)
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
        if let _ = self.textInputNode {
            let inputTextState = self.inputTextState
            self.interfaceInteraction?.updateTextInputState({ _ in return inputTextState })
            self.updateTextNodeText(animated: true)
        }
    }
    
    private func updateTextNodeText(animated: Bool) {
        var hasText = false
        if let textInputNode = self.textInputNode, let attributedText = textInputNode.attributedText, attributedText.length != 0 {
            hasText = true
        }
        self.textPlaceholderNode.isHidden = hasText
        
        if self.extendedSearchLayout {
            if !self.sendButton.alpha.isZero {
                self.sendButton.alpha = 0.0
                if animated {
                    self.sendButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    self.sendButton.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2)
                }
            }
            if !self.micButton.alpha.isZero {
                self.micButton.alpha = 0.0
                if animated {
                    self.micButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    self.micButton.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2)
                }
            }
            if self.searchLayoutClearButton.alpha.isZero {
                self.searchLayoutClearButton.alpha = 1.0
                if animated {
                    self.searchLayoutClearButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                    self.searchLayoutClearButton.layer.animateScale(from: 0.8, to: 1.0, duration: 0.2)
                }
            }
        } else {
            var animateWithBounce = true
            if !self.searchLayoutClearButton.alpha.isZero {
                animateWithBounce = false
                self.searchLayoutClearButton.alpha = 0.0
                if animated {
                    self.searchLayoutClearButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    self.searchLayoutClearButton.layer.animateScale(from: 1.0, to: 0.8, duration: 0.2)
                }
            }
            
            if hasText || self.keepSendButtonEnabled {
                if self.sendButton.alpha.isZero {
                    self.sendButton.alpha = 1.0
                    if animated {
                        self.sendButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        if animateWithBounce {
                            self.sendButton.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                        } else {
                            self.sendButton.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25)
                        }
                    }
                }
                if !self.micButton.alpha.isZero {
                    self.micButton.alpha = 0.0
                    if animated {
                        self.micButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
            } else {
                if self.micButton.alpha.isZero {
                    self.micButton.alpha = 1.0
                    if animated {
                        self.micButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        if animateWithBounce {
                            self.micButton.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                        } else {
                            self.micButton.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25)
                        }
                    }
                }
                if !self.sendButton.alpha.isZero {
                    self.sendButton.alpha = 0.0
                    if animated {
                        self.sendButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
            }
        }
        
        let (_, textFieldHeight) = self.calculateTextFieldMetrics(width: self.bounds.size.width)
        let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight)
        if !self.bounds.size.height.isEqual(to: panelHeight) {
            self.updateHeight()
        }
    }
    
    @objc func editableTextNodeDidChangeSelection(_ editableTextNode: ASEditableTextNode, fromSelectedRange: NSRange, toSelectedRange: NSRange, dueToEditing: Bool) {
        if !dueToEditing && !updatingInputState {
            let inputTextState = self.inputTextState
            self.interfaceInteraction?.updateTextInputState({ _ in return inputTextState })
        }
    }
    
    @objc func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
            return (.text, state.keyboardButtonsMessage?.id)
        })
    }
    
    @objc func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        self.updateActivity()
        return true
    }
    
    @objc func sendButtonPressed() {
        self.sendMessage()
    }
    
    @objc func attachmentButtonPressed() {
        self.displayAttachmentMenu()
    }
    
    @objc func searchLayoutClearButtonPressed() {
        if let interfaceInteraction = self.interfaceInteraction {
            interfaceInteraction.updateTextInputState { textInputState in
                if let (_, type, queryRange) = textInputStateContextQueryRangeAndType(textInputState), type == [.contextRequest] {
                    if let queryRange = queryRange, !queryRange.isEmpty {
                        var inputText = textInputState.inputText
                        inputText.replaceSubrange(queryRange, with: "")
                        return ChatTextInputState(inputText: inputText)
                    } else {
                        return ChatTextInputState(inputText: "")
                    }
                }
                return textInputState
            }
        }
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
    
    @objc func accessoryItemButtonPressed(_ button: UIView) {
        for (item, currentButton) in self.accessoryItemButtons {
            if currentButton === button {
                switch item {
                    case .stickers:
                        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                            return (.media, state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
                        })
                    case .keyboard:
                        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                            return (.text, state.keyboardButtonsMessage?.id)
                        })
                    case .inputButtons:
                        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                            return (.inputButtons, nil)
                        })
                    case .messageAutoremoveTimeout:
                        self.interfaceInteraction?.setupMessageAutoremoveTimeout()
                }
                break
            }
        }
    }
}
