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
import ImageTransparency
import ActivityIndicator
import AnimationUI
import Speak
import ObjCRuntimeUtils
import AvatarNode
import ContextUI
import InvisibleInkDustNode
import TextInputMenu
import Pasteboard
import ChatPresentationInterfaceState
import ManagedAnimationNode
import AttachmentUI
import EditableChatTextNode
import EmojiTextAttachmentView

private let accessoryButtonFont = Font.medium(14.0)
private let counterFont = Font.with(size: 14.0, design: .regular, traits: [.monospacedNumbers])

private final class AccessoryItemIconButtonNode: HighlightTrackingButtonNode {
    private let item: ChatTextInputAccessoryItem
    private var width: CGFloat
    private var imageEdgeInsets = UIEdgeInsets()
    
    init(item: ChatTextInputAccessoryItem, theme: PresentationTheme, strings: PresentationStrings) {
        self.item = item
        
        let (image, text, accessibilityLabel, alpha, insets) = AccessoryItemIconButtonNode.imageAndInsets(item: item, theme: theme, strings: strings)
        
        self.width = AccessoryItemIconButtonNode.calculateWidth(item: item, image: image, text: text, strings: strings)
        
        super.init()
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button]
        
        self.addSubnode(self.imageNode)
        
        if let text = text {
            self.setAttributedTitle(NSAttributedString(string: text, font: accessoryButtonFont, textColor: theme.chat.inputPanel.inputControlColor), for: .normal)
        } else {
            self.setAttributedTitle(NSAttributedString(), for: .normal)
        }
        
        self.imageNode.image = image
        self.imageNode.alpha = alpha
        self.imageEdgeInsets = insets
        
        self.accessibilityLabel = accessibilityLabel
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        let (image, text, accessibilityLabel, alpha, insets) = AccessoryItemIconButtonNode.imageAndInsets(item: item, theme: theme, strings: strings)
        
        self.width = AccessoryItemIconButtonNode.calculateWidth(item: item, image: image, text: text, strings: strings)
        
        if let text = text {
            self.setAttributedTitle(NSAttributedString(string: text, font: accessoryButtonFont, textColor: theme.chat.inputPanel.inputControlColor), for: .normal)
        } else {
            self.setAttributedTitle(NSAttributedString(), for: .normal)
        }
        
        self.imageNode.image = image
        self.imageEdgeInsets = insets
        self.imageNode.alpha = alpha
        
        self.accessibilityLabel = accessibilityLabel
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func imageAndInsets(item: ChatTextInputAccessoryItem, theme: PresentationTheme, strings: PresentationStrings) -> (UIImage?, String?, String, CGFloat, UIEdgeInsets) {
        switch item {
            case .keyboard:
                return (PresentationResourcesChat.chatInputTextFieldKeyboardImage(theme), nil, strings.VoiceOver_Keyboard, 1.0, UIEdgeInsets())
            case let .stickers(enabled):
                return (PresentationResourcesChat.chatInputTextFieldStickersImage(theme), nil, strings.VoiceOver_Stickers, enabled ? 1.0 : 0.4, UIEdgeInsets())
            case .inputButtons:
                return (PresentationResourcesChat.chatInputTextFieldInputButtonsImage(theme), nil, strings.VoiceOver_BotKeyboard, 1.0, UIEdgeInsets())
            case .commands:
                return (PresentationResourcesChat.chatInputTextFieldCommandsImage(theme), nil, strings.VoiceOver_BotCommands, 1.0, UIEdgeInsets())
            case let .silentPost(value):
                if value {
                    return (PresentationResourcesChat.chatInputTextFieldSilentPostOnImage(theme), nil, strings.VoiceOver_SilentPostOn, 1.0, UIEdgeInsets())
                } else {
                    return (PresentationResourcesChat.chatInputTextFieldSilentPostOffImage(theme), nil, strings.VoiceOver_SilentPostOff, 1.0, UIEdgeInsets())
                }
            case let .messageAutoremoveTimeout(timeout):
                if let timeout = timeout {
                    return (nil, shortTimeIntervalString(strings: strings, value: timeout), strings.VoiceOver_SelfDestructTimerOn(timeIntervalString(strings: strings, value: timeout)).string, 1.0, UIEdgeInsets())
                } else {
                    return (PresentationResourcesChat.chatInputTextFieldTimerImage(theme), nil, strings.VoiceOver_SelfDestructTimerOff, 1.0, UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0))
                }
            case .scheduledMessages:
                return (PresentationResourcesChat.chatInputTextFieldScheduleImage(theme), nil, strings.VoiceOver_ScheduledMessages, 1.0, UIEdgeInsets())
        }
    }
    
    static func calculateWidth(item: ChatTextInputAccessoryItem, image: UIImage?, text: String?, strings: PresentationStrings) -> CGFloat {
        switch item {
            case .keyboard, .stickers, .inputButtons, .silentPost, .commands, .scheduledMessages:
                return (image?.size.width ?? 0.0) + CGFloat(8.0)
            case let .messageAutoremoveTimeout(timeout):
                var imageWidth = (image?.size.width ?? 0.0) + CGFloat(8.0)
                if let _ = timeout, let text = text {
                    imageWidth = ceil((text as NSString).size(withAttributes: [.font: accessoryButtonFont]).width) + 10.0
                }
                
                return max(imageWidth, 24.0)
        }
    }
    
    func updateLayout(size: CGSize) {
        if let image = self.imageNode.image {
            let bottomInset: CGFloat = 0.0
            let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0) - bottomInset), size: image.size)
            self.imageNode.frame = imageFrame
        }
    }
    
    var buttonWidth: CGFloat {
        return self.width
    }
}

let chatTextInputMinFontSize: CGFloat = 5.0

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

enum ChatTextInputPanelPasteData {
    case images([UIImage])
    case video(Data)
    case gif(Data)
    case sticker(UIImage, Bool)
}

class ChatTextInputPanelNode: ChatInputPanelNode, ASEditableTextNodeDelegate {
    let clippingNode: ASDisplayNode
    var textPlaceholderNode: ImmediateTextNode
    var contextPlaceholderNode: TextNode?
    var slowmodePlaceholderNode: ChatTextInputSlowmodePlaceholderNode?
    let textInputContainerBackgroundNode: ASImageNode
    let textInputContainer: ASDisplayNode
    var textInputNode: EditableTextNode?
    var dustNode: InvisibleInkDustNode?
    
    let textInputBackgroundNode: ASImageNode
    private var transparentTextInputBackgroundImage: UIImage?
    let actionButtons: ChatTextInputActionButtonsNode
    var mediaRecordingAccessibilityArea: AccessibilityAreaNode?
    private let counterTextNode: ImmediateTextNode
    
    let menuButton: HighlightTrackingButtonNode
    private let menuButtonBackgroundNode: ASDisplayNode
    private let menuButtonClippingNode: ASDisplayNode
    private let menuButtonIconNode: MenuIconNode
    private let menuButtonTextNode: ImmediateTextNode
    
    let sendAsAvatarButtonNode: HighlightableButtonNode
    let sendAsAvatarReferenceNode: ContextReferenceContentNode
    let sendAsAvatarContainerNode: ContextControllerSourceNode
    private let sendAsAvatarNode: AvatarNode
    
    let attachmentButton: HighlightableButtonNode
    let attachmentButtonDisabledNode: HighlightableButtonNode
    let searchLayoutClearButton: HighlightableButton
    private let searchLayoutClearImageNode: ASImageNode
    private var searchActivityIndicator: ActivityIndicator?
    var audioRecordingInfoContainerNode: ASDisplayNode?
    var audioRecordingDotNode: AnimationNode?
    var audioRecordingDotNodeDismissed = false
    var audioRecordingTimeNode: ChatTextInputAudioRecordingTimeNode?
    var audioRecordingCancelIndicator: ChatTextInputAudioRecordingCancelIndicator?
    var animatingBinNode: AnimationNode?
    
    private var accessoryItemButtons: [(ChatTextInputAccessoryItem, AccessoryItemIconButtonNode)] = []
    
    private var validLayout: (CGFloat, CGFloat, CGFloat, CGFloat, UIEdgeInsets, CGFloat, LayoutMetrics, Bool)?
    private var leftMenuInset: CGFloat = 0.0
    
    var displayAttachmentMenu: () -> Void = { }
    var sendMessage: () -> Void = { }
    var paste: (ChatTextInputPanelPasteData) -> Void = { _ in }
    var updateHeight: (Bool) -> Void = { _ in }
    
    var updateActivity: () -> Void = { }
    
    private var updatingInputState = false
    
    private var currentPlaceholder: String?
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    private var initializedPlaceholder = false
    
    private var keepSendButtonEnabled = false
    private var extendedSearchLayout = false
    
    var isMediaDeleted: Bool = false
    
    private let inputMenu: TextInputMenu
    
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
    
    private let statusDisposable = MetaDisposable()
    override var interfaceInteraction: ChatPanelInterfaceInteraction? {
        didSet {
            if let statuses = self.interfaceInteraction?.statuses {
                self.statusDisposable.set((statuses.inlineSearch
                |> distinctUntilChanged
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    self?.updateIsProcessingInlineRequest(value)
                }))
            }
        }
    }
    
    func updateInputTextState(_ state: ChatTextInputState, keepSendButtonEnabled: Bool, extendedSearchLayout: Bool, accessoryItems: [ChatTextInputAccessoryItem], animated: Bool) {
        if state.inputText.length != 0 && self.textInputNode == nil {
            self.loadTextInputNode()
        }
        
        if let textInputNode = self.textInputNode, let currentState = self.presentationInterfaceState {
            self.updatingInputState = true
            
            var updateAccessoryButtons = false
            if accessoryItems.count == self.accessoryItemButtons.count {
                for i in 0 ..< accessoryItems.count {
                    if accessoryItems[i] != self.accessoryItemButtons[i].0 {
                        updateAccessoryButtons = true
                        break
                    }
                }
            } else {
                updateAccessoryButtons = true
            }
            
            if updateAccessoryButtons {
                var updatedButtons: [(ChatTextInputAccessoryItem, AccessoryItemIconButtonNode)] = []
                for item in accessoryItems {
                    var itemAndButton: (ChatTextInputAccessoryItem, AccessoryItemIconButtonNode)?
                    for i in 0 ..< self.accessoryItemButtons.count {
                        if self.accessoryItemButtons[i].0 == item {
                            itemAndButton = self.accessoryItemButtons[i]
                            self.accessoryItemButtons.remove(at: i)
                            break
                        }
                    }
                    if itemAndButton == nil {
                        let button = AccessoryItemIconButtonNode(item: item, theme: currentState.theme, strings: currentState.strings)
                        button.addTarget(self, action: #selector(self.accessoryItemButtonPressed(_:)), forControlEvents: .touchUpInside)
                        itemAndButton = (item, button)
                    }
                    updatedButtons.append(itemAndButton!)
                }
                for (_, button) in self.accessoryItemButtons {
                    button.removeFromSupernode()
                }
                self.accessoryItemButtons = updatedButtons
            }
            
            var textColor: UIColor = .black
            var accentTextColor: UIColor = .blue
            var baseFontSize: CGFloat = 17.0
            if let presentationInterfaceState = self.presentationInterfaceState {
                textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
                accentTextColor = presentationInterfaceState.theme.chat.inputPanel.panelControlAccentColor
                baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            }
            textInputNode.attributedText = textAttributedStringForStateText(state.inputText, fontSize: baseFontSize, textColor: textColor, accentTextColor: accentTextColor, writingDirection: nil, spoilersRevealed: self.spoilersRevealed, availableEmojis: (self.context?.animatedEmojiStickers.keys).flatMap(Set.init) ?? Set(), emojiViewProvider: self.emojiViewProvider)
            textInputNode.selectedRange = NSMakeRange(state.selectionRange.lowerBound, state.selectionRange.count)
            
            if let presentationInterfaceState = self.presentationInterfaceState {
                refreshChatTextInputAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: (self.context?.animatedEmojiStickers.keys).flatMap(Set.init) ?? Set(), emojiViewProvider: self.emojiViewProvider)
            }
            
            self.updatingInputState = false
            self.keepSendButtonEnabled = keepSendButtonEnabled
            self.extendedSearchLayout = extendedSearchLayout
            self.updateTextNodeText(animated: animated)
            self.updateSpoiler()
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
    private let accessoryButtonSpacing: CGFloat = 0.0
    private let accessoryButtonInset: CGFloat = 2.0
    
    private var spoilersRevealed = false
    
    private var touchDownGestureRecognizer: TouchDownGestureRecognizer?
    
    private var emojiViewProvider: ((String) -> UIView)?
    
    init(presentationInterfaceState: ChatPresentationInterfaceState, presentationContext: ChatPresentationContext?, presentController: @escaping (ViewController) -> Void) {
        self.presentationInterfaceState = presentationInterfaceState

        var hasSpoilers = true
        if presentationInterfaceState.chatLocation.peerId?.namespace == Namespaces.Peer.SecretChat {
            hasSpoilers = false
        }
        self.inputMenu = TextInputMenu(hasSpoilers: hasSpoilers)
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
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
        
        self.menuButton = HighlightTrackingButtonNode()
        self.menuButton.clipsToBounds = true
        self.menuButton.cornerRadius = 16.0
        self.menuButton.accessibilityLabel = presentationInterfaceState.strings.Conversation_InputMenu
        self.menuButtonBackgroundNode = ASDisplayNode()
        self.menuButtonClippingNode = ASDisplayNode()
        self.menuButtonClippingNode.clipsToBounds = true
        
        self.menuButtonIconNode = MenuIconNode()
        self.menuButtonIconNode.customColor = presentationInterfaceState.theme.chat.inputPanel.actionControlForegroundColor
        self.menuButtonTextNode = ImmediateTextNode()
        
        self.sendAsAvatarButtonNode = HighlightableButtonNode()
        self.sendAsAvatarReferenceNode = ContextReferenceContentNode()
        self.sendAsAvatarContainerNode = ContextControllerSourceNode()
        self.sendAsAvatarContainerNode.animateScale = false
        self.sendAsAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 16.0))
        
        self.attachmentButton = HighlightableButtonNode(pointerStyle: .circle)
        self.attachmentButton.accessibilityLabel = presentationInterfaceState.strings.VoiceOver_AttachMedia
        self.attachmentButton.accessibilityTraits = [.button]
        self.attachmentButton.isAccessibilityElement = true
        self.attachmentButtonDisabledNode = HighlightableButtonNode()
        self.searchLayoutClearButton = HighlightableButton()
        self.searchLayoutClearImageNode = ASImageNode()
        self.searchLayoutClearImageNode.isUserInteractionEnabled = false
        self.searchLayoutClearButton.addSubnode(self.searchLayoutClearImageNode)
        
        self.actionButtons = ChatTextInputActionButtonsNode(presentationInterfaceState: presentationInterfaceState, presentationContext: presentationContext, presentController: presentController)
        self.counterTextNode = ImmediateTextNode()
        self.counterTextNode.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.clippingNode)
        
        self.sendAsAvatarContainerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.interfaceInteraction?.openSendAsPeer(strongSelf.sendAsAvatarReferenceNode, gesture)
        }
        
        self.sendAsAvatarButtonNode.addTarget(self, action: #selector(self.sendAsAvatarButtonPressed), forControlEvents: .touchUpInside)
        self.sendAsAvatarButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.sendAsAvatarButtonNode, scale: 0.85)
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.sendAsAvatarButtonNode, scale: 1.0)
                }
            }
        }
        
        self.menuButton.addTarget(self, action: #selector(self.menuButtonPressed), forControlEvents: .touchUpInside)
        self.menuButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.menuButton, scale: 0.85)
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                    transition.updateTransformScale(node: strongSelf.menuButton, scale: 1.0)
                }
            }
        }
        
        self.attachmentButton.addTarget(self, action: #selector(self.attachmentButtonPressed), forControlEvents: .touchUpInside)
        self.attachmentButtonDisabledNode.addTarget(self, action: #selector(self.attachmentButtonPressed), forControlEvents: .touchUpInside)
  
        self.actionButtons.sendButtonLongPressed = { [weak self] node, gesture in
            self?.interfaceInteraction?.displaySendMessageOptions(node, gesture)
        }
        
        self.actionButtons.micButton.recordingDisabled = { [weak self] in
            self?.interfaceInteraction?.displayRestrictedInfo(.mediaRecording, .tooltip)
        }
        
        self.actionButtons.micButton.beginRecording = { [weak self] in
            if let strongSelf = self, let presentationInterfaceState = strongSelf.presentationInterfaceState, let interfaceInteraction = strongSelf.interfaceInteraction {
                let isVideo: Bool
                switch presentationInterfaceState.interfaceState.mediaRecordingMode {
                    case .audio:
                        isVideo = false
                    case .video:
                        isVideo = true
                }
                interfaceInteraction.beginMediaRecording(isVideo)
            }
        }
        self.actionButtons.micButton.endRecording = { [weak self] sendMedia in
            if let strongSelf = self, let interfaceState = strongSelf.presentationInterfaceState, let interfaceInteraction = strongSelf.interfaceInteraction {
                if let _ = interfaceState.inputTextPanelState.mediaRecordingState {
                    if sendMedia {
                        interfaceInteraction.finishMediaRecording(.send)
                    } else {
                        interfaceInteraction.finishMediaRecording(.dismiss)
                    }
                } else {
                    interfaceInteraction.finishMediaRecording(.dismiss)
                }
            }
        }
        self.actionButtons.micButton.offsetRecordingControls = { [weak self] in
            if let strongSelf = self, let presentationInterfaceState = strongSelf.presentationInterfaceState {
                if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary) = strongSelf.validLayout {
                    let _ = strongSelf.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: presentationInterfaceState, metrics: metrics)
                }
            }
        }
        self.actionButtons.micButton.updateCancelTranslation = { [weak self] in
            if let strongSelf = self, let presentationInterfaceState = strongSelf.presentationInterfaceState {
                if let (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary) = strongSelf.validLayout {
                    let _ = strongSelf.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, additionalSideInsets: additionalSideInsets, maxHeight: maxHeight, isSecondary: isSecondary, transition: .immediate, interfaceState: presentationInterfaceState, metrics: metrics)
                }
            }
        }
        self.actionButtons.micButton.stopRecording = { [weak self] in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.stopMediaRecording()
            }
        }
        self.actionButtons.micButton.updateLocked = { [weak self] _ in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.lockMediaRecording()
            }
        }
        self.actionButtons.micButton.switchMode = { [weak self] in
            if let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction {
                interfaceInteraction.switchMediaRecordingMode()
            }
        }
        
        self.actionButtons.sendButton.addTarget(self, action: #selector(self.sendButtonPressed), forControlEvents: .touchUpInside)
        self.actionButtons.sendContainerNode.alpha = 0.0
        self.actionButtons.updateAccessibility()
        
        self.actionButtons.expandMediaInputButton.addTarget(self, action: #selector(self.expandButtonPressed), forControlEvents: .touchUpInside)
        self.actionButtons.expandMediaInputButton.alpha = 0.0
        
        self.searchLayoutClearButton.addTarget(self, action: #selector(self.searchLayoutClearButtonPressed), for: .touchUpInside)
        self.searchLayoutClearButton.alpha = 0.0
        
        self.clippingNode.addSubnode(self.textInputContainer)
        self.clippingNode.addSubnode(self.textInputBackgroundNode)
        
        self.clippingNode.addSubnode(self.textPlaceholderNode)
        
        self.menuButton.addSubnode(self.menuButtonBackgroundNode)
        self.menuButton.addSubnode(self.menuButtonClippingNode)
        self.menuButtonClippingNode.addSubnode(self.menuButtonTextNode)
        self.menuButton.addSubnode(self.menuButtonIconNode)
        
        self.sendAsAvatarContainerNode.addSubnode(self.sendAsAvatarReferenceNode)
        self.sendAsAvatarReferenceNode.addSubnode(self.sendAsAvatarNode)
        self.sendAsAvatarButtonNode.addSubnode(self.sendAsAvatarContainerNode)
        self.clippingNode.addSubnode(self.sendAsAvatarButtonNode)
        
        self.clippingNode.addSubnode(self.menuButton)
        self.clippingNode.addSubnode(self.attachmentButton)
        self.clippingNode.addSubnode(self.attachmentButtonDisabledNode)
          
        self.clippingNode.addSubnode(self.actionButtons)
        self.clippingNode.addSubnode(self.counterTextNode)
        
        self.clippingNode.view.addSubview(self.searchLayoutClearButton)
        
        self.textInputBackgroundNode.clipsToBounds = true
        let recognizer = TouchDownGestureRecognizer(target: self, action: #selector(self.textInputBackgroundViewTap(_:)))
        recognizer.touchDown = { [weak self] in
            if let strongSelf = self {
                strongSelf.ensureFocused()
            }
        }
        self.textInputBackgroundNode.isUserInteractionEnabled = true
        self.textInputBackgroundNode.view.addGestureRecognizer(recognizer)
        
        /*if let presentationContext = presentationContext {
            self.emojiViewProvider = { [weak self, weak presentationContext] emoji in
                guard let strongSelf = self, let presentationContext = presentationContext, let presentationInterfaceState = strongSelf.presentationInterfaceState, let context = strongSelf.context, let file = strongSelf.context?.animatedEmojiStickers[emoji]?.first?.file else {
                    return UIView()
                }
                
                return EmojiTextAttachmentView(context: context, file: file, cache: presentationContext.animationCache, renderer: presentationContext.animationRenderer, placeholderColor: presentationInterfaceState.theme.chat.inputPanel.inputTextColor.withAlphaComponent(0.12))
            }
        }*/
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.statusDisposable.dispose()
    }
    
    func loadTextInputNodeIfNeeded() {
        if self.textInputNode == nil {
            self.loadTextInputNode()
        }
    }
    
    private func loadTextInputNode() {
        let textInputNode = EditableChatTextNode()
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
            
            textInputNode.frame = CGRect(origin: CGPoint(x: self.textInputViewInternalInsets.left, y: self.textInputViewInternalInsets.top), size: CGSize(width: textInputFrame.size.width - (self.textInputViewInternalInsets.left + self.textInputViewInternalInsets.right), height: textInputFrame.size.height - self.textInputViewInternalInsets.top - self.textInputViewInternalInsets.bottom))
            textInputNode.view.layoutIfNeeded()
            self.updateSpoiler()
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
        self.touchDownGestureRecognizer = recognizer
        
        textInputNode.textView.accessibilityHint = self.textPlaceholderNode.attributedText?.string
    }
    
    private func textFieldMaxHeight(_ maxHeight: CGFloat, metrics: LayoutMetrics) -> CGFloat {
        let textFieldInsets = self.textFieldInsets(metrics: metrics)
        return max(33.0, maxHeight - (textFieldInsets.top + textFieldInsets.bottom + self.textInputViewInternalInsets.top + self.textInputViewInternalInsets.bottom))
    }
    
    private func calculateTextFieldMetrics(width: CGFloat, maxHeight: CGFloat, metrics: LayoutMetrics) -> (accessoryButtonsWidth: CGFloat, textFieldHeight: CGFloat) {
        let accessoryButtonInset = self.accessoryButtonInset
        let accessoryButtonSpacing = self.accessoryButtonSpacing
        
        let textFieldInsets = self.textFieldInsets(metrics: metrics)
        
        let fieldMaxHeight = textFieldMaxHeight(maxHeight, metrics: metrics)
        
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
        
        return (accessoryButtonsWidth, textFieldHeight)
    }
    
    private func textFieldInsets(metrics: LayoutMetrics) -> UIEdgeInsets {
        var insets = UIEdgeInsets(top: 6.0, left: 42.0, bottom: 6.0, right: 42.0)
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
    
    private var absoluteRect: (CGRect, CGSize)?
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)

        if !self.actionButtons.frame.width.isZero {
            self.actionButtons.updateAbsoluteRect(CGRect(origin: rect.origin.offsetBy(dx: self.actionButtons.frame.minX, dy: self.actionButtons.frame.minY), size: self.actionButtons.frame.size), within: containerSize, transition: transition)
        }
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        let previousAdditionalSideInsets = self.validLayout?.4
        self.validLayout = (width, leftInset, rightInset, bottomInset, additionalSideInsets, maxHeight, metrics, isSecondary)
        
        let textFieldWaitsForTouchUp: Bool
        if case .regular = metrics.widthClass, bottomInset.isZero {
            textFieldWaitsForTouchUp = true
        } else {
            textFieldWaitsForTouchUp = false
        }
        self.touchDownGestureRecognizer?.waitForTouchUp = textFieldWaitsForTouchUp
    
        var transition = transition
        var additionalOffset: CGFloat = 0.0
        if let previousAdditionalSideInsets = previousAdditionalSideInsets, previousAdditionalSideInsets.right != additionalSideInsets.right {
            additionalOffset = (previousAdditionalSideInsets.right - additionalSideInsets.right) / 3.0
            
            if case .animated = transition {
                transition = .animated(duration: 0.2, curve: .easeInOut)
            }
        }
        
        var wasEditingMedia = false
        if let interfaceState = self.presentationInterfaceState, let editMessageState = interfaceState.editMessageState {
            if case let .media(value) = editMessageState.content {
                wasEditingMedia = !value.isEmpty
            }
        }
                
        var isMediaEnabled = true
        var isEditingMedia = false
        if let editMessageState = interfaceState.editMessageState {
            if case let .media(value) = editMessageState.content {
                isEditingMedia = !value.isEmpty
                isMediaEnabled = !value.isEmpty
            } else {
                isMediaEnabled = false
            }
        }
        var isRecording = false
        if let _ = interfaceState.inputTextPanelState.mediaRecordingState {
            isRecording = true
        }
        
        var isScheduledMessages = false
        if case .scheduledMessages = interfaceState.subject {
            isScheduledMessages = true
        }
        
        var isSlowmodeActive = false
        if interfaceState.slowmodeState != nil && !isScheduledMessages {
            isSlowmodeActive = true
            if !isEditingMedia {
                isMediaEnabled = false
            }
        }
        transition.updateAlpha(layer: self.attachmentButton.layer, alpha: isMediaEnabled ? 1.0 : 0.4)
        self.attachmentButton.isEnabled = isMediaEnabled && !isRecording
        self.attachmentButton.accessibilityTraits = (!isSlowmodeActive || isMediaEnabled) ? [.button] : [.button, .notEnabled]
        self.attachmentButtonDisabledNode.isHidden = !isSlowmodeActive || isMediaEnabled
        
        var buttonTitleUpdated = false
        var menuTextSize = self.menuButtonTextNode.frame.size
        if self.presentationInterfaceState != interfaceState {
            let previousState = self.presentationInterfaceState
            self.presentationInterfaceState = interfaceState
            
            if case .webView = interfaceState.botMenuButton, self.menuButtonIconNode.iconState == .menu {
                self.menuButtonIconNode.enqueueState(.app, animated: false)
            } else if case .commands = interfaceState.botMenuButton, self.menuButtonIconNode.iconState == .app {
                self.menuButtonIconNode.enqueueState(.menu, animated: false)
            }
            let themeUpdated = previousState?.theme !== interfaceState.theme
            if themeUpdated {
                self.menuButtonIconNode.customColor = interfaceState.theme.chat.inputPanel.actionControlForegroundColor
            }
            if let sendAsPeers = interfaceState.sendAsPeers, !sendAsPeers.isEmpty {
                self.menuButtonIconNode.enqueueState(.close, animated: false)
            } else if case .webView = interfaceState.botMenuButton, let previousShowWebView = previousState?.showWebView, previousShowWebView != interfaceState.showWebView {
                if interfaceState.showWebView {
                    self.menuButtonIconNode.enqueueState(.close, animated: true)
                } else {
                    self.menuButtonIconNode.enqueueState(.app, animated: true)
                }
            } else if let previousShowCommands = previousState?.showCommands, previousShowCommands != interfaceState.showCommands {
                if interfaceState.showCommands {
                    self.menuButtonIconNode.enqueueState(.close, animated: true)
                } else {
                    self.menuButtonIconNode.enqueueState(.menu, animated: true)
                }
            }
            
            let buttonTitle: String
            if case let .webView(title, _) = interfaceState.botMenuButton {
                buttonTitle = title
            } else {
                buttonTitle = interfaceState.strings.Conversation_InputMenu
            }
            
            buttonTitleUpdated = self.menuButtonTextNode.attributedText != nil && self.menuButtonTextNode.attributedText?.string != buttonTitle
            
            self.menuButtonTextNode.attributedText = NSAttributedString(string: buttonTitle, font: Font.with(size: 16.0, design: .round, weight: .medium, traits: []), textColor: interfaceState.theme.chat.inputPanel.actionControlForegroundColor)
            self.menuButton.accessibilityLabel = self.menuButtonTextNode.attributedText?.string
            
            if buttonTitleUpdated, let buttonTextSnapshotView = self.menuButtonTextNode.view.snapshotView(afterScreenUpdates: false) {
                buttonTextSnapshotView.frame = self.menuButtonTextNode.view.frame
                self.menuButtonTextNode.view.superview?.addSubview(buttonTextSnapshotView)
                buttonTextSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak buttonTextSnapshotView] _ in
                    buttonTextSnapshotView?.removeFromSuperview()
                })
                self.menuButtonTextNode.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            menuTextSize = self.menuButtonTextNode.updateLayout(CGSize(width: width / 2.0 - 60.0, height: 44.0))
            
            var updateSendButtonIcon = false
            if (previousState?.interfaceState.editMessage != nil) != (interfaceState.interfaceState.editMessage != nil) {
                updateSendButtonIcon = true
            }
            if self.theme !== interfaceState.theme {
                updateSendButtonIcon = true
                
                if self.theme == nil || !self.theme!.chat.inputPanel.inputTextColor.isEqual(interfaceState.theme.chat.inputPanel.inputTextColor) {
                    let textColor = interfaceState.theme.chat.inputPanel.inputTextColor
                    let tintColor = interfaceState.theme.list.itemAccentColor
                    let baseFontSize = max(minInputFontSize, interfaceState.fontSize.baseDisplaySize)
                    
                    if let textInputNode = self.textInputNode {
                        if let text = textInputNode.attributedText?.string {
                            let range = textInputNode.selectedRange
                            textInputNode.attributedText = NSAttributedString(string: text, font: Font.regular(baseFontSize), textColor: textColor)
                            textInputNode.selectedRange = range
                        }
                        textInputNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(baseFontSize), NSAttributedString.Key.foregroundColor.rawValue: textColor]
                        textInputNode.tintColor = tintColor
                        
                        self.updateSpoiler()
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
                
                self.menuButtonBackgroundNode.backgroundColor = interfaceState.theme.chat.inputPanel.actionControlFillColor
                
                if isEditingMedia {
                    self.attachmentButton.setImage(PresentationResourcesChat.chatInputPanelEditAttachmentButtonImage(interfaceState.theme), for: [])
                } else {
                    self.attachmentButton.setImage(PresentationResourcesChat.chatInputPanelAttachmentButtonImage(interfaceState.theme), for: [])
                }
               
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
                
                self.searchLayoutClearImageNode.image = PresentationResourcesChat.chatInputTextFieldClearImage(interfaceState.theme)
                
                self.audioRecordingTimeNode?.updateTheme(theme: interfaceState.theme)
                self.audioRecordingCancelIndicator?.updateTheme(theme: interfaceState.theme)
                
                for (_, button) in self.accessoryItemButtons {
                    button.updateThemeAndStrings(theme: interfaceState.theme, strings: interfaceState.strings)
                }
            } else {
                if self.strings !== interfaceState.strings {
                    self.strings = interfaceState.strings
                    self.inputMenu.updateStrings(interfaceState.strings)
                    
                    for (_, button) in self.accessoryItemButtons {
                        button.updateThemeAndStrings(theme: interfaceState.theme, strings: interfaceState.strings)
                    }
                }
                
                if wasEditingMedia != isEditingMedia {
                    if isEditingMedia {
                        self.attachmentButton.setImage(PresentationResourcesChat.chatInputPanelEditAttachmentButtonImage(interfaceState.theme), for: [])
                    } else {
                        self.attachmentButton.setImage(PresentationResourcesChat.chatInputPanelAttachmentButtonImage(interfaceState.theme), for: [])
                    }
                }
            }

            let dismissedButtonMessageUpdated = interfaceState.interfaceState.messageActionsState.dismissedButtonKeyboardMessageId != previousState?.interfaceState.messageActionsState.dismissedButtonKeyboardMessageId
            let replyMessageUpdated = interfaceState.interfaceState.replyMessageId != previousState?.interfaceState.replyMessageId
            
            if let peer = interfaceState.renderedPeer?.peer, previousState?.renderedPeer?.peer == nil || !peer.isEqual(previousState!.renderedPeer!.peer!) || previousState?.interfaceState.silentPosting != interfaceState.interfaceState.silentPosting || themeUpdated || !self.initializedPlaceholder || previousState?.keyboardButtonsMessage?.id != interfaceState.keyboardButtonsMessage?.id || previousState?.keyboardButtonsMessage?.visibleReplyMarkupPlaceholder != interfaceState.keyboardButtonsMessage?.visibleReplyMarkupPlaceholder || dismissedButtonMessageUpdated || replyMessageUpdated {
                self.initializedPlaceholder = true
                
                var placeholder: String
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    if interfaceState.interfaceState.silentPosting {
                        placeholder = interfaceState.strings.Conversation_InputTextSilentBroadcastPlaceholder
                    } else {
                        placeholder = interfaceState.strings.Conversation_InputTextBroadcastPlaceholder
                    }
                } else if let channel = peer as? TelegramChannel, case .group = channel.info, channel.hasPermission(.canBeAnonymous) {
                    placeholder = interfaceState.strings.Conversation_InputTextAnonymousPlaceholder
                } else if case let .replyThread(replyThreadMessage) = interfaceState.chatLocation {
                    if replyThreadMessage.isChannelPost {
                        placeholder = interfaceState.strings.Conversation_InputTextPlaceholderComment
                    } else {
                        placeholder = interfaceState.strings.Conversation_InputTextPlaceholderReply
                    }
                } else {
                    placeholder = interfaceState.strings.Conversation_InputTextPlaceholder
                }

                if let keyboardButtonsMessage = interfaceState.keyboardButtonsMessage, interfaceState.interfaceState.messageActionsState.dismissedButtonKeyboardMessageId != keyboardButtonsMessage.id {
                    if keyboardButtonsMessage.requestsSetupReply && keyboardButtonsMessage.id != interfaceState.interfaceState.replyMessageId {
                    } else {
                        if let placeholderValue = interfaceState.keyboardButtonsMessage?.visibleReplyMarkupPlaceholder, !placeholderValue.isEmpty {
                            placeholder = placeholderValue
                        }
                    }
                }

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
                
                self.actionButtons.sendButtonLongPressEnabled = !isScheduledMessages
            }
            
            let sendButtonHasApplyIcon = interfaceState.interfaceState.editMessage != nil
            
            if updateSendButtonIcon {
                if !self.actionButtons.animatingSendButton {
                    let imageNode = self.actionButtons.sendButton.imageNode
                    
                    if transition.isAnimated && !self.actionButtons.sendContainerNode.alpha.isZero && self.actionButtons.sendButton.layer.animation(forKey: "opacity") == nil, let previousImage = imageNode.image {
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
                        self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelApplyIconImage(interfaceState.theme), for: [])
                    } else {
                        if isScheduledMessages {
                            self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelScheduleButtonImage(interfaceState.theme), for: [])
                        } else {
                            self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendIconImage(interfaceState.theme), for: [])
                        }
                    }
                }
            }
        }
        
        var textFieldMinHeight: CGFloat = 33.0
        if let presentationInterfaceState = self.presentationInterfaceState {
            textFieldMinHeight = calclulateTextFieldMinHeight(presentationInterfaceState, metrics: metrics)
        }
        let minimalHeight: CGFloat = 14.0 + textFieldMinHeight
        let minimalInputHeight: CGFloat = 2.0 + textFieldMinHeight
        
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
        
        var removeAccessoryButtons: [AccessoryItemIconButtonNode]?
        if updateAccessoryButtons {
            var updatedButtons: [(ChatTextInputAccessoryItem, AccessoryItemIconButtonNode)] = []
            for item in interfaceState.inputTextPanelState.accessoryItems {
                var itemAndButton: (ChatTextInputAccessoryItem, AccessoryItemIconButtonNode)?
                for i in 0 ..< self.accessoryItemButtons.count {
                    if self.accessoryItemButtons[i].0 == item {
                        itemAndButton = self.accessoryItemButtons[i]
                        self.accessoryItemButtons.remove(at: i)
                        break
                    }
                }
                if itemAndButton == nil {
                    let button = AccessoryItemIconButtonNode(item: item, theme: interfaceState.theme, strings: interfaceState.strings)
                    button.addTarget(self, action: #selector(self.accessoryItemButtonPressed(_:)), forControlEvents: .touchUpInside)
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
                    button.removeFromSupernode()
                }
            }
            self.accessoryItemButtons = updatedButtons
        }
        
        let mediaRecordingState = interfaceState.inputTextPanelState.mediaRecordingState
        
        var inputHasText = false
        if let textInputNode = self.textInputNode, let attributedText = textInputNode.attributedText, attributedText.length != 0 {
            inputHasText = true
        }
        
        var hasMenuButton = false
        var menuButtonExpanded = false
        var isSendAsButton = false
        
        var shouldDisplayMenuButton = false
        if interfaceState.hasBotCommands {
            shouldDisplayMenuButton = true
        } else if case .webView = interfaceState.botMenuButton {
            shouldDisplayMenuButton = true
        }
        
        if let sendAsPeers = interfaceState.sendAsPeers, !sendAsPeers.isEmpty && interfaceState.editMessageState == nil {
            hasMenuButton = true
            menuButtonExpanded = false
            isSendAsButton = true
            self.sendAsAvatarNode.isHidden = false
            
            var currentPeer = sendAsPeers.first(where: { $0.peer.id == interfaceState.currentSendAsPeerId})?.peer
            if currentPeer == nil {
                currentPeer = sendAsPeers.first?.peer
            }
            if let context = self.context, let peer = currentPeer {
                self.sendAsAvatarNode.setPeer(context: context, theme: interfaceState.theme, peer: EnginePeer(peer), emptyColor: interfaceState.theme.list.mediaPlaceholderColor)
            }
        } else if let peer = interfaceState.renderedPeer?.peer as? TelegramUser, let _ = peer.botInfo, shouldDisplayMenuButton && interfaceState.editMessageState == nil {
            hasMenuButton = true
            
            if !inputHasText {
                switch interfaceState.inputMode {
                case .none, .inputButtons:
                    menuButtonExpanded = true
                default:
                    break
                }
            }
            self.sendAsAvatarNode.isHidden = true
        } else {
            self.sendAsAvatarNode.isHidden = true
        }
        if mediaRecordingState != nil {
            hasMenuButton = false
        }
        
        let leftMenuInset: CGFloat
        let menuButtonHeight: CGFloat = 33.0
        let menuCollapsedButtonWidth: CGFloat = isSendAsButton ? menuButtonHeight : 38.0
        let menuButtonWidth = menuTextSize.width + 47.0
        if hasMenuButton {
            let menuButtonSpacing: CGFloat = 10.0
            if menuButtonExpanded {
                leftMenuInset = menuButtonWidth + menuButtonSpacing
            } else {
                leftMenuInset = menuCollapsedButtonWidth + menuButtonSpacing
            }
        } else {
            leftMenuInset = 0.0
        }
        self.leftMenuInset = leftMenuInset
        
        if buttonTitleUpdated && !transition.isAnimated {
            transition = .animated(duration: 0.3, curve: .easeInOut)
        }
        
        let baseWidth = width - leftInset - leftMenuInset - rightInset
        let (accessoryButtonsWidth, textFieldHeight) = self.calculateTextFieldMetrics(width: baseWidth, maxHeight: maxHeight, metrics: metrics)
        let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight, metrics: metrics)
                
        let menuButtonFrame = CGRect(x: leftInset + 10.0, y: panelHeight - minimalHeight + floorToScreenPixels((minimalHeight - menuButtonHeight) / 2.0), width: menuButtonExpanded ? menuButtonWidth : menuCollapsedButtonWidth, height: menuButtonHeight)
        transition.updateFrameAsPositionAndBounds(node: self.menuButton, frame: menuButtonFrame)
        transition.updateFrame(node: self.menuButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: menuButtonFrame.size))
        transition.updateFrame(node: self.menuButtonClippingNode, frame: CGRect(origin: CGPoint(x: 19.0, y: 0.0), size: CGSize(width: menuButtonWidth - 19.0, height: menuButtonFrame.height)))
        var buttonTitlteTransition = transition
        if buttonTitleUpdated {
            buttonTitlteTransition = .immediate
        }
        buttonTitlteTransition.updateFrame(node: self.menuButtonTextNode, frame: CGRect(origin: CGPoint(x: 16.0, y: 7.0 - UIScreenPixel), size: menuTextSize))
        transition.updateAlpha(node: self.menuButtonTextNode, alpha: menuButtonExpanded ? 1.0 : 0.0)
        transition.updateFrame(node: self.menuButtonIconNode, frame: CGRect(x: isSendAsButton ? 1.0 + UIScreenPixel : (4.0 + UIScreenPixel), y: 1.0 + UIScreenPixel, width: 30.0, height: 30.0))
        
        transition.updateFrame(node: self.sendAsAvatarButtonNode, frame: menuButtonFrame)
        transition.updateFrame(node: self.sendAsAvatarContainerNode, frame: CGRect(origin: CGPoint(), size: menuButtonFrame.size))
        transition.updateFrame(node: self.sendAsAvatarReferenceNode, frame: CGRect(origin: CGPoint(), size: menuButtonFrame.size))
        transition.updateFrame(node: self.sendAsAvatarNode, frame: CGRect(origin: CGPoint(), size: menuButtonFrame.size))
        
        let showMenuButton = hasMenuButton && interfaceState.recordedMediaPreview == nil
        if isSendAsButton {
            if interfaceState.showSendAsPeers {
                transition.updateTransformScale(node: self.menuButton, scale: 1.0)
                transition.updateAlpha(node: self.menuButton, alpha: 1.0)
                
                transition.updateTransformScale(node: self.sendAsAvatarButtonNode, scale: 0.001)
                transition.updateAlpha(node: self.sendAsAvatarButtonNode, alpha: 0.0)
            } else {
                transition.updateTransformScale(node: self.menuButton, scale: 0.001)
                transition.updateAlpha(node: self.menuButton, alpha: 0.0)
                
                transition.updateTransformScale(node: self.sendAsAvatarButtonNode, scale: showMenuButton ? 1.0 : 0.001)
                transition.updateAlpha(node: self.sendAsAvatarButtonNode, alpha: showMenuButton ? 1.0 : 0.0)
            }
        } else {
            transition.updateTransformScale(node: self.menuButton, scale: showMenuButton ? 1.0 : 0.001)
            transition.updateAlpha(node: self.menuButton, alpha: showMenuButton ? 1.0 : 0.0)
            
            transition.updateTransformScale(node: self.sendAsAvatarButtonNode, scale: 0.001)
            transition.updateAlpha(node: self.sendAsAvatarButtonNode, alpha: 0.0)
        }
        self.menuButton.isUserInteractionEnabled = hasMenuButton
        self.sendAsAvatarButtonNode.isUserInteractionEnabled = hasMenuButton && isSendAsButton
                    
        self.actionButtons.micButton.updateMode(mode: interfaceState.interfaceState.mediaRecordingMode, animated: transition.isAnimated)
        
        var hideMicButton = false
        var audioRecordingItemsAlpha: CGFloat = 1
        if mediaRecordingState != nil || interfaceState.recordedMediaPreview != nil {
            audioRecordingItemsAlpha = 0
        
            let audioRecordingInfoContainerNode: ASDisplayNode
            if let currentAudioRecordingInfoContainerNode = self.audioRecordingInfoContainerNode {
                audioRecordingInfoContainerNode = currentAudioRecordingInfoContainerNode
            } else {
                audioRecordingInfoContainerNode = ASDisplayNode()
                self.audioRecordingInfoContainerNode = audioRecordingInfoContainerNode
                self.clippingNode.insertSubnode(audioRecordingInfoContainerNode, at: 0)
            }
            
            var animateTimeSlideIn = false
            let audioRecordingTimeNode: ChatTextInputAudioRecordingTimeNode
            if let currentAudioRecordingTimeNode = self.audioRecordingTimeNode {
                audioRecordingTimeNode = currentAudioRecordingTimeNode
            } else {
                audioRecordingTimeNode = ChatTextInputAudioRecordingTimeNode(theme: interfaceState.theme)
                self.audioRecordingTimeNode = audioRecordingTimeNode
                audioRecordingInfoContainerNode.addSubnode(audioRecordingTimeNode)
                
                if transition.isAnimated && mediaRecordingState != nil {
                    animateTimeSlideIn = true
                }
            }
            
            var animateCancelSlideIn = false
            let audioRecordingCancelIndicator: ChatTextInputAudioRecordingCancelIndicator
            if let currentAudioRecordingCancelIndicator = self.audioRecordingCancelIndicator {
                audioRecordingCancelIndicator = currentAudioRecordingCancelIndicator
            } else {
                animateCancelSlideIn = transition.isAnimated && mediaRecordingState != nil
                
                audioRecordingCancelIndicator = ChatTextInputAudioRecordingCancelIndicator(theme: interfaceState.theme, strings: interfaceState.strings, cancel: { [weak self] in
                    self?.interfaceInteraction?.finishMediaRecording(.dismiss)
                })
                self.audioRecordingCancelIndicator = audioRecordingCancelIndicator
                self.clippingNode.insertSubnode(audioRecordingCancelIndicator, at: 0)
            }
            
            let isLocked = mediaRecordingState?.isLocked ?? (interfaceState.recordedMediaPreview != nil)
            var hideInfo = false
            
            if let mediaRecordingState = mediaRecordingState {
                switch mediaRecordingState {
                case let .audio(recorder, _):
                    self.actionButtons.micButton.audioRecorder = recorder
                    audioRecordingTimeNode.audioRecorder = recorder
                case let .video(status, _):
                    switch status {
                    case let .recording(recordingStatus):
                        audioRecordingTimeNode.videoRecordingStatus = recordingStatus
                        self.actionButtons.micButton.videoRecordingStatus = recordingStatus
                        if isLocked {
                            audioRecordingCancelIndicator.layer.animateAlpha(from: audioRecordingCancelIndicator.alpha, to: 0, duration: 0.15, delay: 0, removeOnCompletion: false)
                        }
                    case .editing:
                        audioRecordingTimeNode.videoRecordingStatus = nil
                        self.actionButtons.micButton.videoRecordingStatus = nil
                        hideMicButton = true
                        hideInfo = true
                    }
                case .waitingForPreview:
                    break
                }
            }
            
            transition.updateAlpha(layer: self.textInputBackgroundNode.layer, alpha: 0.0)
            if let textInputNode = self.textInputNode {
                transition.updateAlpha(node: textInputNode, alpha: 0.0)
            }
            for (_, button) in self.accessoryItemButtons {
                transition.updateAlpha(layer: button.layer, alpha: 0.0)
            }
            
            let cancelTransformThreshold: CGFloat = 8.0
            
            let indicatorTranslation = max(0.0, self.actionButtons.micButton.cancelTranslation - cancelTransformThreshold)
            
            let audioRecordingCancelIndicatorFrame = CGRect(
                origin: CGPoint(
                    x: leftInset + floor((baseWidth - audioRecordingCancelIndicator.bounds.size.width - indicatorTranslation) / 2.0),
                    y: panelHeight - minimalHeight + floor((minimalHeight - audioRecordingCancelIndicator.bounds.size.height) / 2.0)),
                size: audioRecordingCancelIndicator.bounds.size)
            audioRecordingCancelIndicator.frame = audioRecordingCancelIndicatorFrame
            if self.actionButtons.micButton.cancelTranslation > cancelTransformThreshold {
                //let progress = 1 - (self.actionButtons.micButton.cancelTranslation - cancelTransformThreshold) / 80
                let progress: CGFloat = max(0.0, min(1.0, (audioRecordingCancelIndicatorFrame.minX - 100.0) / 10.0))
                audioRecordingCancelIndicator.alpha = progress
            } else {
                audioRecordingCancelIndicator.alpha = 1
            }
            
            if animateCancelSlideIn {
                let position = audioRecordingCancelIndicator.layer.position
                audioRecordingCancelIndicator.layer.animatePosition(from: CGPoint(x: width + audioRecordingCancelIndicator.bounds.size.width, y: position.y), to: position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            }
            
            audioRecordingCancelIndicator.updateIsDisplayingCancel(isLocked, animated: !animateCancelSlideIn && mediaRecordingState != nil)
            
            if isLocked || self.actionButtons.micButton.cancelTranslation > cancelTransformThreshold {
                var deltaOffset: CGFloat = 0.0
                if audioRecordingCancelIndicator.layer.animation(forKey: "slide_juggle") != nil, let presentationLayer = audioRecordingCancelIndicator.layer.presentation() {
                    let translation = CGPoint(x: presentationLayer.transform.m41, y: presentationLayer.transform.m42)
                    deltaOffset = translation.x
                }
                audioRecordingCancelIndicator.layer.removeAnimation(forKey: "slide_juggle")
                if !deltaOffset.isZero {
                    audioRecordingCancelIndicator.layer.animatePosition(from: CGPoint(x: deltaOffset, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
                }
            } else if audioRecordingCancelIndicator.layer.animation(forKey: "slide_juggle") == nil, baseWidth > 320 {
                let slideJuggleAnimation = CABasicAnimation(keyPath: "transform")
                slideJuggleAnimation.toValue = CATransform3DMakeTranslation(6, 0, 0)
                slideJuggleAnimation.duration = 1
                slideJuggleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                slideJuggleAnimation.autoreverses = true
                slideJuggleAnimation.repeatCount = Float.infinity
                audioRecordingCancelIndicator.layer.add(slideJuggleAnimation, forKey: "slide_juggle")
            }
            
            let audioRecordingTimeSize = audioRecordingTimeNode.measure(CGSize(width: 200.0, height: 100.0))
            
            audioRecordingInfoContainerNode.frame = CGRect(
                origin: CGPoint(
                    x: min(leftInset, width - audioRecordingTimeSize.width - 8.0 - 28.0),
                    y: 0.0
                ),
                size: CGSize(width: baseWidth, height: panelHeight)
            )
            
            audioRecordingTimeNode.frame = CGRect(origin: CGPoint(x: 40.0, y: panelHeight - minimalHeight + floor((minimalHeight - audioRecordingTimeSize.height) / 2.0)), size: audioRecordingTimeSize)
            if animateTimeSlideIn {
                let position = audioRecordingTimeNode.layer.position
                audioRecordingTimeNode.layer.animatePosition(from: CGPoint(x: position.x - 10.0, y: position.y), to: position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
                audioRecordingTimeNode.layer.animateAlpha(from: 0, to: 1, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            }
            
            var animateDotAppearing = false
            let audioRecordingDotNode: AnimationNode
            if let currentAudioRecordingDotNode = self.audioRecordingDotNode, !currentAudioRecordingDotNode.didPlay {
                audioRecordingDotNode = currentAudioRecordingDotNode
            } else {
                self.audioRecordingDotNode?.removeFromSupernode()
                audioRecordingDotNode = AnimationNode(animation: "BinRed")
                self.audioRecordingDotNode = audioRecordingDotNode
                self.audioRecordingDotNodeDismissed = false
                self.clippingNode.insertSubnode(audioRecordingDotNode, belowSubnode: self.menuButton)
                self.animatingBinNode?.removeFromSupernode()
                self.animatingBinNode = nil
            }
            
            animateDotAppearing = transition.isAnimated && !hideInfo
            if let mediaRecordingState = mediaRecordingState, case .waitingForPreview = mediaRecordingState {
                animateDotAppearing = false
            }
            
            audioRecordingDotNode.frame = CGRect(origin: CGPoint(x: leftInset + 2.0 - UIScreenPixel, y: audioRecordingTimeNode.frame.midY - 20), size: CGSize(width: 40.0, height: 40))
            if animateDotAppearing {
                audioRecordingDotNode.layer.animateScale(from: 0.3, to: 1, duration: 0.15, delay: 0, removeOnCompletion: false)
                audioRecordingTimeNode.started = { [weak audioRecordingDotNode] in
                    if let audioRecordingDotNode = audioRecordingDotNode, audioRecordingDotNode.layer.animation(forKey: "recording") == nil {
                        audioRecordingDotNode.layer.animateAlpha(from: CGFloat(audioRecordingDotNode.layer.presentation()?.opacity ?? 0), to: 1, duration: 0.15, delay: 0, completion: { [weak audioRecordingDotNode] finished in
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
                }
                self.attachmentButton.layer.animateAlpha(from: CGFloat(self.attachmentButton.layer.presentation()?.opacity ?? 1), to: 0, duration: 0.15, delay: 0, removeOnCompletion: false)
                self.attachmentButton.layer.animateScale(from: 1, to: 0.3, duration: 0.15, delay: 0, removeOnCompletion: false)
            }
            
            if hideInfo {
                audioRecordingDotNode.layer.removeAllAnimations()
                audioRecordingDotNode.layer.animateAlpha(from: CGFloat(audioRecordingDotNode.layer.presentation()?.opacity ?? 1), to: 0, duration: 0.15, delay: 0, removeOnCompletion: false)
                audioRecordingTimeNode.layer.animateAlpha(from: CGFloat(audioRecordingTimeNode.layer.presentation()?.opacity ?? 1), to: 0, duration: 0.15, delay: 0, removeOnCompletion: false)
                audioRecordingCancelIndicator.layer.animateAlpha(from: CGFloat(audioRecordingCancelIndicator.layer.presentation()?.opacity ?? 1), to: 0, duration: 0.15, delay: 0, removeOnCompletion: false)
            }
        } else {
            var update = self.actionButtons.micButton.audioRecorder != nil || self.actionButtons.micButton.videoRecordingStatus != nil
            self.actionButtons.micButton.audioRecorder = nil
            self.actionButtons.micButton.videoRecordingStatus = nil
            transition.updateAlpha(layer: self.textInputBackgroundNode.layer, alpha: 1.0)
            if let textInputNode = self.textInputNode {
                transition.updateAlpha(node: textInputNode, alpha: 1.0)
            }
            for (_, button) in self.accessoryItemButtons {
                transition.updateAlpha(layer: button.layer, alpha: 1.0)
            }
            
            if let audioRecordingInfoContainerNode = self.audioRecordingInfoContainerNode {
                self.audioRecordingInfoContainerNode = nil
                transition.updateAlpha(node: audioRecordingInfoContainerNode, alpha: 0) { [weak audioRecordingInfoContainerNode] _ in
                    audioRecordingInfoContainerNode?.removeFromSupernode()
                }
            }
            
            if let audioRecordingDotNode = self.audioRecordingDotNode {
                let dismissDotNode = { [weak audioRecordingDotNode, weak self] in
                    guard let audioRecordingDotNode = audioRecordingDotNode, audioRecordingDotNode === self?.audioRecordingDotNode else { return }
                    
                    self?.audioRecordingDotNode = nil
                    
                    audioRecordingDotNode.layer.animateScale(from: 1, to: 0.3, duration: 0.15, delay: 0, removeOnCompletion: false)
                    audioRecordingDotNode.layer.animateAlpha(from: CGFloat(audioRecordingDotNode.layer.presentation()?.opacity ?? 1), to: 0.0, duration: 0.15, delay: 0, removeOnCompletion: false) { [weak audioRecordingDotNode] _ in
                        audioRecordingDotNode?.removeFromSupernode()
                    }
                    
                    self?.attachmentButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
                    self?.attachmentButton.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
                }
                
                if update && !self.audioRecordingDotNodeDismissed {
                    audioRecordingDotNode.layer.removeAllAnimations()
                }
                
                if self.isMediaDeleted {
                    if self.prevInputPanelNode is ChatRecordingPreviewInputPanelNode {
                        self.audioRecordingDotNode?.removeFromSupernode()
                        self.audioRecordingDotNode = nil
                    } else {
                        if !self.audioRecordingDotNodeDismissed {
                            audioRecordingDotNode.layer.removeAllAnimations()
                        }
                        audioRecordingDotNode.completion = dismissDotNode
                        audioRecordingDotNode.play()
                        update = true
                    }
                } else {
                    dismissDotNode()
                }
                
                if update && !self.audioRecordingDotNodeDismissed {
                    self.audioRecordingDotNode?.layer.animatePosition(from: CGPoint(), to: CGPoint(x: leftMenuInset, y: 0.0), duration: 0.15, removeOnCompletion: false, additive: true)
                    self.audioRecordingDotNodeDismissed = true
                }
            }
            
            if let audioRecordingTimeNode = self.audioRecordingTimeNode {
                self.audioRecordingTimeNode = nil
                
                let timePosition = audioRecordingTimeNode.position
                transition.updatePosition(node: audioRecordingTimeNode, position: CGPoint(x: timePosition.x - audioRecordingTimeNode.bounds.width / 2.0, y: timePosition.y))
                transition.updateTransformScale(node: audioRecordingTimeNode, scale: 0.1)
            }
            
            if let audioRecordingCancelIndicator = self.audioRecordingCancelIndicator {
                self.audioRecordingCancelIndicator = nil
                if transition.isAnimated {
                    audioRecordingCancelIndicator.layer.animateAlpha(from: audioRecordingCancelIndicator.alpha, to: 0.0, duration: 0.25, completion: { [weak audioRecordingCancelIndicator] _ in
                        audioRecordingCancelIndicator?.removeFromSupernode()
                    })
                } else {
                    audioRecordingCancelIndicator.removeFromSupernode()
                }
            }
        }
        
        var leftInset = leftInset
        leftInset += leftMenuInset
        
        transition.updateFrame(layer: self.attachmentButton.layer, frame: CGRect(origin: CGPoint(x: leftInset + 2.0 - UIScreenPixel, y: panelHeight - minimalHeight), size: CGSize(width: 40.0, height: minimalHeight)))
        transition.updateFrame(node: self.attachmentButtonDisabledNode, frame: self.attachmentButton.frame)
        
        var composeButtonsOffset: CGFloat = 0.0
        var textInputBackgroundWidthOffset: CGFloat = 0.0
        if self.extendedSearchLayout {
            composeButtonsOffset = 44.0
            textInputBackgroundWidthOffset = 36.0
        }
        
        self.updateCounterTextNode(transition: transition)
       
        let actionButtonsFrame = CGRect(origin: CGPoint(x: width - rightInset - 43.0 - UIScreenPixel + composeButtonsOffset, y: panelHeight - minimalHeight), size: CGSize(width: 44.0, height: minimalHeight))
        transition.updateFrame(node: self.actionButtons, frame: actionButtonsFrame)
        if let (rect, containerSize) = self.absoluteRect {
            self.actionButtons.updateAbsoluteRect(CGRect(x: rect.origin.x + actionButtonsFrame.origin.x, y: rect.origin.y + actionButtonsFrame.origin.y, width: actionButtonsFrame.width, height: actionButtonsFrame.height), within: containerSize, transition: transition)
        }
        
        if let presentationInterfaceState = self.presentationInterfaceState {
            self.actionButtons.updateLayout(size: CGSize(width: 44.0, height: minimalHeight), transition: transition, interfaceState: presentationInterfaceState)
        }
        
        if let _ = interfaceState.inputTextPanelState.mediaRecordingState {
            let text: String = interfaceState.strings.VoiceOver_MessageContextSend
            let mediaRecordingAccessibilityArea: AccessibilityAreaNode
            var added = false
            if let current = self.mediaRecordingAccessibilityArea {
                mediaRecordingAccessibilityArea = current
            } else {
                added = true
                mediaRecordingAccessibilityArea = AccessibilityAreaNode()
                mediaRecordingAccessibilityArea.accessibilityLabel = text
                mediaRecordingAccessibilityArea.accessibilityTraits = [.button, .startsMediaSession]
                self.mediaRecordingAccessibilityArea = mediaRecordingAccessibilityArea
                mediaRecordingAccessibilityArea.activate = { [weak self] in
                    self?.interfaceInteraction?.finishMediaRecording(.send)
                    return true
                }
                self.clippingNode.insertSubnode(mediaRecordingAccessibilityArea, aboveSubnode: self.actionButtons)
            }
            self.actionButtons.isAccessibilityElement = false
            let size: CGFloat = 120.0
            mediaRecordingAccessibilityArea.frame = CGRect(origin: CGPoint(x: actionButtonsFrame.midX - size / 2.0, y: actionButtonsFrame.midY - size / 2.0), size: CGSize(width: size, height: size))
            if added {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.4, execute: {
                    [weak mediaRecordingAccessibilityArea] in
                    UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: mediaRecordingAccessibilityArea?.view)
                })
            }
        } else {
            self.actionButtons.isAccessibilityElement = true
            if let mediaRecordingAccessibilityArea = self.mediaRecordingAccessibilityArea {
                self.mediaRecordingAccessibilityArea = nil
                mediaRecordingAccessibilityArea.removeFromSupernode()
            }
        }
        
        let searchLayoutClearButtonSize = CGSize(width: 44.0, height: minimalHeight)
        var textFieldInsets = self.textFieldInsets(metrics: metrics)
        if additionalSideInsets.right > 0.0 {
            textFieldInsets.right += additionalSideInsets.right / 3.0
        }
        self.actionButtons.micButton.isHidden = additionalSideInsets.right > 0.0

        transition.updateFrame(layer: self.searchLayoutClearButton.layer, frame: CGRect(origin: CGPoint(x: width - rightInset - textFieldInsets.left - textFieldInsets.right + textInputBackgroundWidthOffset + 3.0, y: panelHeight - minimalHeight), size: searchLayoutClearButtonSize))
        if let image = self.searchLayoutClearImageNode.image {
            self.searchLayoutClearImageNode.frame = CGRect(origin: CGPoint(x: floor((searchLayoutClearButtonSize.width - image.size.width) / 2.0), y: floor((searchLayoutClearButtonSize.height - image.size.height) / 2.0)), size: image.size)
        }

        var textInputViewRealInsets = UIEdgeInsets()
        if let presentationInterfaceState = self.presentationInterfaceState {
            textInputViewRealInsets = calculateTextFieldRealInsets(presentationInterfaceState)
        }
        
        let textInputFrame = CGRect(x: leftInset + textFieldInsets.left, y: textFieldInsets.top, width: baseWidth - textFieldInsets.left - textFieldInsets.right + textInputBackgroundWidthOffset, height: panelHeight - textFieldInsets.top - textFieldInsets.bottom)
        transition.updateFrame(node: self.textInputContainer, frame: textInputFrame)
        transition.updateFrame(node: self.textInputContainerBackgroundNode, frame: CGRect(origin: CGPoint(), size: textInputFrame.size))
        transition.updateAlpha(node: self.textInputContainer, alpha: audioRecordingItemsAlpha)
        
        if let textInputNode = self.textInputNode {
            let textFieldFrame = CGRect(origin: CGPoint(x: self.textInputViewInternalInsets.left, y: self.textInputViewInternalInsets.top), size: CGSize(width: textInputFrame.size.width - (self.textInputViewInternalInsets.left + self.textInputViewInternalInsets.right), height: textInputFrame.size.height - self.textInputViewInternalInsets.top - textInputViewInternalInsets.bottom))
            let shouldUpdateLayout = textFieldFrame.size != textInputNode.frame.size
            transition.updateFrame(node: textInputNode, frame: textFieldFrame)
            if shouldUpdateLayout {
                textInputNode.layout()
            }
        }
        
        if interfaceState.slowmodeState == nil || isScheduledMessages, let contextPlaceholder = interfaceState.inputTextPanelState.contextPlaceholder {
            let placeholderLayout = TextNode.asyncLayout(self.contextPlaceholderNode)
            let (placeholderSize, placeholderApply) = placeholderLayout(TextNodeLayoutArguments(attributedString: contextPlaceholder, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - leftInset - rightInset - textFieldInsets.left - textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right - accessoryButtonsWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let contextPlaceholderNode = placeholderApply()
            if let currentContextPlaceholderNode = self.contextPlaceholderNode, currentContextPlaceholderNode !== contextPlaceholderNode {
                self.contextPlaceholderNode = nil
                currentContextPlaceholderNode.removeFromSupernode()
            }
            
            if self.contextPlaceholderNode !== contextPlaceholderNode {
                contextPlaceholderNode.displaysAsynchronously = false
                contextPlaceholderNode.isUserInteractionEnabled = false
                self.contextPlaceholderNode = contextPlaceholderNode
                self.clippingNode.insertSubnode(contextPlaceholderNode, aboveSubnode: self.textPlaceholderNode)
            }
            
            let _ = placeholderApply()
            
            contextPlaceholderNode.frame = CGRect(origin: CGPoint(x: leftInset + textFieldInsets.left + self.textInputViewInternalInsets.left, y: textFieldInsets.top + self.textInputViewInternalInsets.top + textInputViewRealInsets.top + UIScreenPixel), size: placeholderSize.size)
            contextPlaceholderNode.alpha = audioRecordingItemsAlpha
        } else if let contextPlaceholderNode = self.contextPlaceholderNode {
            self.contextPlaceholderNode = nil
            contextPlaceholderNode.removeFromSupernode()
            self.textPlaceholderNode.alpha = 1.0
        }
        
        if let slowmodeState = interfaceState.slowmodeState, !isScheduledMessages {
            let slowmodePlaceholderNode: ChatTextInputSlowmodePlaceholderNode
            if let current = self.slowmodePlaceholderNode {
                slowmodePlaceholderNode = current
            } else {
                slowmodePlaceholderNode = ChatTextInputSlowmodePlaceholderNode(theme: interfaceState.theme)
                self.slowmodePlaceholderNode = slowmodePlaceholderNode
                self.clippingNode.insertSubnode(slowmodePlaceholderNode, aboveSubnode: self.textPlaceholderNode)
            }
            let placeholderFrame = CGRect(origin: CGPoint(x: leftInset + textFieldInsets.left + self.textInputViewInternalInsets.left, y: textFieldInsets.top + self.textInputViewInternalInsets.top + textInputViewRealInsets.top + UIScreenPixel), size: CGSize(width: width - leftInset - rightInset - textFieldInsets.left - textFieldInsets.right - self.textInputViewInternalInsets.left - self.textInputViewInternalInsets.right - accessoryButtonsWidth, height: 30.0))
            slowmodePlaceholderNode.updateState(slowmodeState)
            slowmodePlaceholderNode.frame = placeholderFrame
            slowmodePlaceholderNode.alpha = audioRecordingItemsAlpha
            slowmodePlaceholderNode.updateLayout(size: placeholderFrame.size)
        } else if let slowmodePlaceholderNode = self.slowmodePlaceholderNode {
            self.slowmodePlaceholderNode = nil
            slowmodePlaceholderNode.removeFromSupernode()
        }

        if (interfaceState.slowmodeState != nil && !isScheduledMessages && interfaceState.editMessageState == nil) || interfaceState.inputTextPanelState.contextPlaceholder != nil {
            self.textPlaceholderNode.isHidden = true
            self.slowmodePlaceholderNode?.isHidden = inputHasText
        } else {
            self.textPlaceholderNode.isHidden = inputHasText
            self.slowmodePlaceholderNode?.isHidden = true
        }
        
        var nextButtonTopRight = CGPoint(x: width - rightInset - textFieldInsets.right - accessoryButtonInset, y: minimalHeight - textFieldInsets.bottom - minimalInputHeight)
        for (_, button) in self.accessoryItemButtons.reversed() {
            let buttonSize = CGSize(width: button.buttonWidth, height: minimalInputHeight)
            button.updateLayout(size: buttonSize)
            let buttonFrame = CGRect(origin: CGPoint(x: nextButtonTopRight.x - buttonSize.width, y: nextButtonTopRight.y + floor((minimalInputHeight - buttonSize.height) / 2.0)), size: buttonSize)
            if button.supernode == nil {
                self.clippingNode.addSubnode(button)
                button.frame = buttonFrame.offsetBy(dx: -additionalOffset, dy: 0.0)
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
        
        let textInputBackgroundFrame = CGRect(x: leftInset + textFieldInsets.left, y: textFieldInsets.top, width: baseWidth - textFieldInsets.left - textFieldInsets.right + textInputBackgroundWidthOffset, height: panelHeight - textFieldInsets.top - textFieldInsets.bottom)
        transition.updateFrame(layer: self.textInputBackgroundNode.layer, frame: textInputBackgroundFrame)
        transition.updateAlpha(node: self.textInputBackgroundNode, alpha: audioRecordingItemsAlpha)
        
        transition.updateFrame(node: self.textPlaceholderNode, frame: CGRect(origin: CGPoint(x: leftInset + textFieldInsets.left + self.textInputViewInternalInsets.left, y: textFieldInsets.top + self.textInputViewInternalInsets.top + textInputViewRealInsets.top + UIScreenPixel), size: self.textPlaceholderNode.frame.size))
        
        var textPlaceholderAlpha: CGFloat = audioRecordingItemsAlpha
        if self.textPlaceholderNode.frame.width > (nextButtonTopRight.x - textInputBackgroundFrame.minX) - 32.0 {
            textPlaceholderAlpha = 0.0
        }
        transition.updateAlpha(node: self.textPlaceholderNode, alpha: textPlaceholderAlpha)
        
        if let removeAccessoryButtons = removeAccessoryButtons {
            for button in removeAccessoryButtons {
                let buttonFrame = CGRect(origin: CGPoint(x: button.frame.origin.x + additionalOffset, y: panelHeight - textFieldInsets.bottom - minimalInputHeight), size: button.frame.size)
                transition.updateFrame(layer: button.layer, frame: buttonFrame)
                button.layer.animateScale(from: 1.0, to: 0.2, duration: 0.25, removeOnCompletion: false)
                button.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak button] _ in
                    button?.removeFromSupernode()
                })
            }
        }
        
        if inputHasText || self.extendedSearchLayout {
            hideMicButton = true
        }
        
        let mediaInputDisabled: Bool
        if interfaceState.hasActiveGroupCall {
            mediaInputDisabled = true
        } else if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, channel.hasBannedPermission(.banSendMedia) != nil {
            mediaInputDisabled = true
        } else if let group = interfaceState.renderedPeer?.peer as? TelegramGroup, group.hasBannedPermission(.banSendMedia) {
            mediaInputDisabled = true
        } else {
            mediaInputDisabled = false
        }
        self.actionButtons.micButton.fadeDisabled = mediaInputDisabled
        
        self.updateActionButtons(hasText: inputHasText, hideMicButton: hideMicButton, animated: transition.isAnimated)
        
        if let prevInputPanelNode = self.prevInputPanelNode {
            prevInputPanelNode.frame = CGRect(origin: .zero, size: prevInputPanelNode.frame.size)
        }
        if let prevPreviewInputPanelNode = self.prevInputPanelNode as? ChatRecordingPreviewInputPanelNode {
            self.prevInputPanelNode = nil
            
            prevPreviewInputPanelNode.gestureRecognizer?.isEnabled = false
            prevPreviewInputPanelNode.isUserInteractionEnabled = false
            
            if self.isMediaDeleted {
                func animatePosition(for previewSubnode: ASDisplayNode) {
                    previewSubnode.layer.animatePosition(
                        from: previewSubnode.position,
                        to: CGPoint(x: leftMenuInset.isZero ? previewSubnode.position.x - 20 : leftMenuInset + previewSubnode.frame.width / 2.0, y: previewSubnode.position.y),
                        duration: 0.15
                    )
                }
                
                animatePosition(for: prevPreviewInputPanelNode.waveformBackgroundNode)
                animatePosition(for: prevPreviewInputPanelNode.waveformScubberNode)
                animatePosition(for: prevPreviewInputPanelNode.durationLabel)
                animatePosition(for: prevPreviewInputPanelNode.playButton)
            }
            
            func animateAlpha(for previewSubnode: ASDisplayNode) {
                previewSubnode.layer.animateAlpha(
                    from: 1.0,
                    to: 0.0,
                    duration: 0.15,
                    removeOnCompletion: false
                )
            }
            animateAlpha(for: prevPreviewInputPanelNode.waveformBackgroundNode)
            animateAlpha(for: prevPreviewInputPanelNode.waveformScubberNode)
            animateAlpha(for: prevPreviewInputPanelNode.durationLabel)
            animateAlpha(for: prevPreviewInputPanelNode.playButton)
            
            let binNode = prevPreviewInputPanelNode.binNode
            self.animatingBinNode = binNode
            let dismissBin = { [weak self, weak prevPreviewInputPanelNode, weak binNode] in
                if binNode?.supernode != nil {
                    prevPreviewInputPanelNode?.deleteButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, delay: 0, removeOnCompletion: false) { [weak prevPreviewInputPanelNode] _ in
                        if prevPreviewInputPanelNode?.supernode === self {
                            prevPreviewInputPanelNode?.removeFromSupernode()
                        }
                    }
                    prevPreviewInputPanelNode?.deleteButton.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, delay: 0, removeOnCompletion: false)
                    
                    self?.attachmentButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
                    self?.attachmentButton.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
                } else if prevPreviewInputPanelNode?.supernode === self {
                   prevPreviewInputPanelNode?.removeFromSupernode()
                }
            }
            
            if self.isMediaDeleted {
                binNode.completion = dismissBin
                binNode.play()
            } else {
                dismissBin()
            }
            
            prevPreviewInputPanelNode.deleteButton.layer.animatePosition(from: CGPoint(), to: CGPoint(x: leftMenuInset, y: 0.0), duration: 0.15, removeOnCompletion: false, additive: true)

            prevPreviewInputPanelNode.sendButton.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false)
            prevPreviewInputPanelNode.sendButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
            
            self.actionButtons.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
            self.actionButtons.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
            
            if hasMenuButton {
                if isSendAsButton {
                    
                } else {
                    self.menuButton.alpha = 1.0
                    self.menuButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
                    self.menuButton.transform = CATransform3DIdentity
                    self.menuButton.layer.animateScale(from: 0.3, to: 1.0, duration: 0.15, delay: 0, removeOnCompletion: false)
                }
            }
        }
        
        var clippingDelta: CGFloat = 0.0
        if case let .media(_, _, focused) = interfaceState.inputMode, focused {
            clippingDelta = -panelHeight
        }
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: panelHeight)))
        transition.updateSublayerTransformOffset(layer: self.clippingNode.layer, offset: CGPoint(x: 0.0, y: clippingDelta))
        
        return panelHeight
    }
    
    override func canHandleTransition(from prevInputPanelNode: ChatInputPanelNode?) -> Bool {
        return prevInputPanelNode is ChatRecordingPreviewInputPanelNode
    }
    
    @objc func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let textInputNode = self.textInputNode, let presentationInterfaceState = self.presentationInterfaceState {
            let baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            refreshChatTextInputAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: (self.context?.animatedEmojiStickers.keys).flatMap(Set.init) ?? Set(), emojiViewProvider: self.emojiViewProvider)
            refreshChatTextInputTypingAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize)
            
            self.updateSpoiler()
            
            let inputTextState = self.inputTextState
            
            self.interfaceInteraction?.updateTextInputStateAndMode({ _, inputMode in return (inputTextState, inputMode) })
            self.interfaceInteraction?.updateInputLanguage({ _ in return textInputNode.textInputMode.primaryLanguage })
            self.updateTextNodeText(animated: true)
            
            self.updateCounterTextNode(transition: .immediate)
        }
    }
    
    private func updateSpoiler() {
        guard let textInputNode = self.textInputNode, let presentationInterfaceState = self.presentationInterfaceState else {
            return
        }
        
        let textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
        
        var rects: [CGRect] = []
        
        if let attributedText = textInputNode.attributedText {
            let beginning = textInputNode.textView.beginningOfDocument
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                if let _ = attributes[ChatTextInputAttributes.spoiler] {
                    func addSpoiler(startIndex: Int, endIndex: Int) {
                        if let start = textInputNode.textView.position(from: beginning, offset: startIndex), let end = textInputNode.textView.position(from: start, offset: endIndex - startIndex), let textRange = textInputNode.textView.textRange(from: start, to: end) {
                            let textRects = textInputNode.textView.selectionRects(for: textRange)
                            for textRect in textRects {
                                rects.append(textRect.rect.insetBy(dx: 1.0, dy: 1.0).offsetBy(dx: 0.0, dy: 1.0))
                            }
                        }
                    }
                    
                    var startIndex: Int?
                    var currentIndex: Int?
                    
                    let nsString = (attributedText.string as NSString)
                    nsString.enumerateSubstrings(in: range, options: .byComposedCharacterSequences) { substring, range, _, _ in
                        if let substring = substring, substring.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                            if let currentStartIndex = startIndex {
                                startIndex = nil
                                let endIndex = range.location
                                addSpoiler(startIndex: currentStartIndex, endIndex: endIndex)
                            }
                        } else if startIndex == nil {
                            startIndex = range.location
                        }
                        currentIndex = range.location + range.length
                    }
                    
                    if let currentStartIndex = startIndex, let currentIndex = currentIndex {
                        startIndex = nil
                        let endIndex = currentIndex
                        addSpoiler(startIndex: currentStartIndex, endIndex: endIndex)
                    }
                }
            })
        }
        
        if !rects.isEmpty {
            let dustNode: InvisibleInkDustNode
            if let current = self.dustNode {
                dustNode = current
            } else {
                dustNode = InvisibleInkDustNode(textNode: nil)
                dustNode.alpha = self.spoilersRevealed ? 0.0 : 1.0
                dustNode.isUserInteractionEnabled = false
                textInputNode.textView.addSubview(dustNode.view)
                self.dustNode = dustNode
            }
            dustNode.frame = CGRect(origin: CGPoint(), size: textInputNode.textView.contentSize)
            dustNode.update(size: textInputNode.textView.contentSize, color: textColor, textColor: textColor, rects: rects, wordRects: rects)
        } else if let dustNode = self.dustNode {
            dustNode.removeFromSupernode()
            self.dustNode = nil
        }
    }
    
    private func updateSpoilersRevealed(animated: Bool = true) {
        guard let textInputNode = self.textInputNode else {
            return
        }
        
        let selectionRange = textInputNode.textView.selectedRange
        
        var revealed = false
        if let attributedText = textInputNode.attributedText {
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                if let _ = attributes[ChatTextInputAttributes.spoiler] {
                    if let _ = selectionRange.intersection(range) {
                        revealed = true
                    }
                }
            })
        }
            
        guard self.spoilersRevealed != revealed else {
            return
        }
        self.spoilersRevealed = revealed
        
        if revealed {
            self.updateInternalSpoilersRevealed(true, animated: animated)
        } else {
            Queue.mainQueue().after(1.5, {
                self.updateInternalSpoilersRevealed(false, animated: true)
            })
        }
    }
    
    private func updateInternalSpoilersRevealed(_ revealed: Bool, animated: Bool) {
        guard self.spoilersRevealed == revealed, let textInputNode = self.textInputNode, let presentationInterfaceState = self.presentationInterfaceState else {
            return
        }
        
        let textColor = presentationInterfaceState.theme.chat.inputPanel.inputTextColor
        let accentTextColor = presentationInterfaceState.theme.chat.inputPanel.panelControlAccentColor
        let baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
        
        textInputNode.textView.isScrollEnabled = false
        
        refreshChatTextInputAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: (self.context?.animatedEmojiStickers.keys).flatMap(Set.init) ?? Set(), emojiViewProvider: self.emojiViewProvider)
        
        textInputNode.attributedText = textAttributedStringForStateText(self.inputTextState.inputText, fontSize: baseFontSize, textColor: textColor, accentTextColor: accentTextColor, writingDirection: nil, spoilersRevealed: self.spoilersRevealed, availableEmojis: (self.context?.animatedEmojiStickers.keys).flatMap(Set.init) ?? Set(), emojiViewProvider: self.emojiViewProvider)
        
        if textInputNode.textView.subviews.count > 1, animated {
            let containerView = textInputNode.textView.subviews[1]
            if let canvasView = containerView.subviews.first {
                if let snapshotView = canvasView.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = canvasView.frame.offsetBy(dx: 0.0, dy: -textInputNode.textView.contentOffset.y)
                    textInputNode.view.insertSubview(snapshotView, at: 0)
                    canvasView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView, weak textInputNode] _ in
                        textInputNode?.textView.isScrollEnabled = false
                        snapshotView?.removeFromSuperview()
                        Queue.mainQueue().after(0.1) {
                            textInputNode?.textView.isScrollEnabled = true
                        }
                    })
                }
            }
        }
        Queue.mainQueue().after(0.1) {
            textInputNode.textView.isScrollEnabled = true
        }
        
        if animated {
            if revealed {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
                if let dustNode = self.dustNode {
                    transition.updateAlpha(node: dustNode, alpha: 0.0)
                }
            } else {
                let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
                if let dustNode = self.dustNode {
                    transition.updateAlpha(node: dustNode, alpha: 1.0)
                }
            }
        } else if let dustNode = self.dustNode {
            dustNode.alpha = revealed ? 0.0 : 1.0
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
        
        if let (width, leftInset, rightInset, _, _, maxHeight, metrics, _) = self.validLayout {
            var composeButtonsOffset: CGFloat = 0.0
            if self.extendedSearchLayout {
                composeButtonsOffset = 44.0
            }
            
            let (_, textFieldHeight) = self.calculateTextFieldMetrics(width: width - leftInset - rightInset - self.leftMenuInset, maxHeight: maxHeight, metrics: metrics)
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
        var hideMicButton = false
        if let textInputNode = self.textInputNode, let attributedText = textInputNode.attributedText, attributedText.length != 0 {
            inputHasText = true
            hideMicButton = true
        }
        
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState?.subject {
            isScheduledMessages = true
        }
        
        if let interfaceState = self.presentationInterfaceState {
            if (interfaceState.slowmodeState != nil && !isScheduledMessages && interfaceState.editMessageState == nil) || interfaceState.inputTextPanelState.contextPlaceholder != nil {
                self.textPlaceholderNode.isHidden = true
                self.slowmodePlaceholderNode?.isHidden = inputHasText
            } else {
                self.textPlaceholderNode.isHidden = inputHasText
                self.slowmodePlaceholderNode?.isHidden = true
            }
        }
        
        self.updateActionButtons(hasText: inputHasText, hideMicButton: hideMicButton, animated: animated)
        self.updateTextHeight(animated: animated)
    }
    
    private func updateActionButtons(hasText: Bool, hideMicButton: Bool, animated: Bool) {
        var hideMicButton = hideMicButton
        
        var mediaInputIsActive = false
        if let presentationInterfaceState = self.presentationInterfaceState {
            if let mediaRecordingState = presentationInterfaceState.inputTextPanelState.mediaRecordingState {
                if case .video(.editing, false) = mediaRecordingState {
                    hideMicButton = true
                }
            }
            if case .media = presentationInterfaceState.inputMode {
                mediaInputIsActive = true
            }
        }
        
        var animateWithBounce = false
        if self.extendedSearchLayout {
            hideMicButton = true
            
            if !self.actionButtons.sendContainerNode.alpha.isZero {
                self.actionButtons.sendContainerNode.alpha = 0.0
                self.actionButtons.sendButtonRadialStatusNode?.alpha = 0.0
                self.actionButtons.updateAccessibility()
                if animated {
                    self.actionButtons.animatingSendButton = true
                    self.actionButtons.sendContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.actionButtons.animatingSendButton = false
                            strongSelf.applyUpdateSendButtonIcon()
                        }
                    })
                    self.actionButtons.sendContainerNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2)
                    
                    self.actionButtons.sendButtonRadialStatusNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    self.actionButtons.sendButtonRadialStatusNode?.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2)
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
            animateWithBounce = true
            if !self.searchLayoutClearButton.alpha.isZero {
                animateWithBounce = false
                self.searchLayoutClearButton.alpha = 0.0
                if animated {
                    self.searchLayoutClearButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    self.searchLayoutClearButton.layer.animateScale(from: 1.0, to: 0.8, duration: 0.2)
                }
            }
            
            if (hasText || self.keepSendButtonEnabled && !mediaInputIsActive) {
                hideMicButton = true
                if self.actionButtons.sendContainerNode.alpha.isZero {
                    self.actionButtons.sendContainerNode.alpha = 1.0
                    self.actionButtons.sendButtonRadialStatusNode?.alpha = 1.0
                    self.actionButtons.updateAccessibility()
                    if animated {
                        self.actionButtons.sendContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        self.actionButtons.sendButtonRadialStatusNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        if animateWithBounce {
                            self.actionButtons.sendContainerNode.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                            self.actionButtons.sendButtonRadialStatusNode?.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                        } else {
                            self.actionButtons.sendContainerNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25)
                            self.actionButtons.sendButtonRadialStatusNode?.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25)
                        }
                    }
                }
            } else {
                if !self.actionButtons.sendContainerNode.alpha.isZero {
                    self.actionButtons.sendContainerNode.alpha = 0.0
                    self.actionButtons.sendButtonRadialStatusNode?.alpha = 0.0
                    self.actionButtons.updateAccessibility()
                    if animated {
                        self.actionButtons.animatingSendButton = true
                        self.actionButtons.sendContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                            if let strongSelf = self {
                                strongSelf.actionButtons.animatingSendButton = false
                                strongSelf.applyUpdateSendButtonIcon()
                            }
                        })
                        self.actionButtons.sendButtonRadialStatusNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
            }
        }
        
        if mediaInputIsActive {
            hideMicButton = true
        }
        
        if hideMicButton {
            if !self.actionButtons.micButton.alpha.isZero {
                self.actionButtons.micButton.alpha = 0.0
                if animated {
                    self.actionButtons.micButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        } else {
            let micAlpha: CGFloat = self.actionButtons.micButton.fadeDisabled ? 0.5 : 1.0
            if !self.actionButtons.micButton.alpha.isEqual(to: micAlpha) {
                self.actionButtons.micButton.alpha = micAlpha
                if animated {
                    self.actionButtons.micButton.layer.animateAlpha(from: 0.0, to: micAlpha, duration: 0.1)
                    if animateWithBounce {
                        self.actionButtons.micButton.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                    } else {
                        self.actionButtons.micButton.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25)
                    }
                }
            }
        }
        
        if mediaInputIsActive {
            if self.actionButtons.expandMediaInputButton.alpha.isZero {
                self.actionButtons.expandMediaInputButton.alpha = 1.0
                if animated {
                    self.actionButtons.expandMediaInputButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                    if animateWithBounce {
                        self.actionButtons.expandMediaInputButton.layer.animateSpring(from: NSNumber(value: Float(0.1)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
                    } else {
                        self.actionButtons.expandMediaInputButton.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25)
                    }
                }
            }
        } else {
            if !self.actionButtons.expandMediaInputButton.alpha.isZero {
                self.actionButtons.expandMediaInputButton.alpha = 0.0
                if animated {
                    self.actionButtons.expandMediaInputButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        
        self.actionButtons.updateAccessibility()
    }
    
    private func updateTextHeight(animated: Bool) {
        if let (width, leftInset, rightInset, _, additionalSideInsets, maxHeight, metrics, _) = self.validLayout {
            let (_, textFieldHeight) = self.calculateTextFieldMetrics(width: width - leftInset - rightInset - additionalSideInsets.right - self.leftMenuInset, maxHeight: maxHeight, metrics: metrics)
            let panelHeight = self.panelHeight(textFieldHeight: textFieldHeight, metrics: metrics)
            if !self.bounds.size.height.isEqual(to: panelHeight) {
                self.updateHeight(animated)
            }
        }
    }
    
    func updateIsProcessingInlineRequest(_ value: Bool) {
        if value {
            if self.searchActivityIndicator == nil, let currentState = self.presentationInterfaceState {
                let searchActivityIndicator = ActivityIndicator(type: .custom(currentState.theme.list.itemAccentColor, 20.0, 1.5, true))
                searchActivityIndicator.isUserInteractionEnabled = false
                self.searchActivityIndicator = searchActivityIndicator
                let indicatorSize = searchActivityIndicator.measure(CGSize(width: 100.0, height: 100.0))
                let size = self.searchLayoutClearButton.bounds.size
                searchActivityIndicator.frame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0) + 0.0, y: floor((size.height - indicatorSize.height) / 2.0) - 0.0), size: indicatorSize)
                //self.searchLayoutClearImageNode.isHidden = true
                self.searchLayoutClearButton.addSubnode(searchActivityIndicator)
            }
        } else if let searchActivityIndicator = self.searchActivityIndicator {
            self.searchActivityIndicator = nil
            //self.searchLayoutClearImageNode.isHidden = false
            searchActivityIndicator.removeFromSupernode()
        }
    }
    
    @objc func editableTextNodeShouldReturn(_ editableTextNode: ASEditableTextNode) -> Bool {
        if self.actionButtons.sendButton.supernode != nil && !self.actionButtons.sendButton.isHidden && !self.actionButtons.sendContainerNode.alpha.isZero {
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
                    self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelApplyIconImage(interfaceState.theme), for: [])
                } else {
                    if case .scheduledMessages = interfaceState.subject {
                        self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelScheduleIconImage(interfaceState.theme), for: [])
                    } else {
                        self.actionButtons.sendButton.setImage(PresentationResourcesChat.chatInputPanelSendIconImage(interfaceState.theme), for: [])
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
                self.inputMenu.hide()
            }
            
            let baseFontSize = max(minInputFontSize, presentationInterfaceState.fontSize.baseDisplaySize)
            refreshChatTextInputTypingAttributes(textInputNode, theme: presentationInterfaceState.theme, baseFontSize: baseFontSize)
            
            self.updateSpoilersRevealed()
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
        
        if let presentationInterfaceState = self.presentationInterfaceState, let peer = presentationInterfaceState.renderedPeer?.peer as? TelegramUser, peer.botInfo != nil {
            self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId { _ in
                return (.inputButtons, nil)
            }
        }
    }
    
    func editableTextNodeTarget(forAction action: Selector) -> ASEditableTextNodeTargetForAction? {
        if action == makeSelectorFromString("_accessibilitySpeak:") {
            if case .format = self.inputMenu.state {
                return ASEditableTextNodeTargetForAction(target: nil)
            } else if let textInputNode = self.textInputNode, textInputNode.selectedRange.length > 0 {
                return ASEditableTextNodeTargetForAction(target: self)
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        } else if action == makeSelectorFromString("_accessibilitySpeakSpellOut:") {
            if case .format = self.inputMenu.state {
                return ASEditableTextNodeTargetForAction(target: nil)
            } else if let textInputNode = self.textInputNode, textInputNode.selectedRange.length > 0 {
                return nil
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        }
        else if action == makeSelectorFromString("_accessibilitySpeakLanguageSelection:") || action == makeSelectorFromString("_accessibilityPauseSpeaking:") || action == makeSelectorFromString("_accessibilitySpeakSentence:") {
            return ASEditableTextNodeTargetForAction(target: nil)
        } else if action == makeSelectorFromString("_showTextStyleOptions:") {
            if case .general = self.inputMenu.state {
                if let textInputNode = self.textInputNode, textInputNode.attributedText == nil || textInputNode.attributedText!.length == 0 || textInputNode.selectedRange.length == 0 {
                    return ASEditableTextNodeTargetForAction(target: nil)
                }
                return ASEditableTextNodeTargetForAction(target: self)
            } else {
                return ASEditableTextNodeTargetForAction(target: nil)
            }
        } else if action == #selector(self.formatAttributesBold(_:)) || action == #selector(self.formatAttributesItalic(_:)) || action == #selector(self.formatAttributesMonospace(_:)) || action == #selector(self.formatAttributesLink(_:)) || action == #selector(self.formatAttributesStrikethrough(_:)) || action == #selector(self.formatAttributesUnderline(_:)) || action == #selector(self.formatAttributesSpoiler(_:)) {
            if case .format = self.inputMenu.state {
                if action == #selector(self.formatAttributesSpoiler(_:)), let selectedRange = self.textInputNode?.selectedRange {
                    var intersectsMonospace = false
                    self.inputTextState.inputText.enumerateAttributes(in: selectedRange, options: [], using: { attributes, _, _ in
                        if let _ = attributes[ChatTextInputAttributes.monospace] {
                            intersectsMonospace = true
                        }
                    })
                    if !intersectsMonospace {
                        return ASEditableTextNodeTargetForAction(target: self)
                    } else {
                        return ASEditableTextNodeTargetForAction(target: nil)
                    }
                } else if action == #selector(self.formatAttributesMonospace(_:)), let selectedRange = self.textInputNode?.selectedRange {
                    var intersectsSpoiler = false
                    self.inputTextState.inputText.enumerateAttributes(in: selectedRange, options: [], using: { attributes, _, _ in
                        if let _ = attributes[ChatTextInputAttributes.spoiler] {
                            intersectsSpoiler = true
                        }
                    })
                    if !intersectsSpoiler {
                        return ASEditableTextNodeTargetForAction(target: self)
                    } else {
                        return ASEditableTextNodeTargetForAction(target: nil)
                    }
                } else {
                    return ASEditableTextNodeTargetForAction(target: self)
                }
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
        if let context = self.context {
            let _ = speakText(context: context, text: text)
        }
        
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
    
    @objc func formatAttributesSpoiler(_ sender: Any) {
        self.inputMenu.back()
        
        var animated = false
        if let attributedText = self.textInputNode?.attributedText {
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, _, _ in
                if let _ = attributes[ChatTextInputAttributes.spoiler] {
                    animated = true
                }
            })
        }
        
        self.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.spoiler), inputMode)
        }
        
        self.updateSpoilersRevealed(animated: animated)
    }
    
    @objc func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        self.updateActivity()
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
            let cleanReplacementString = textAttributedStringForStateText(NSAttributedString(string: cleanText), fontSize: baseFontSize, textColor: textColor, accentTextColor: accentTextColor, writingDirection: nil, spoilersRevealed: self.spoilersRevealed, availableEmojis: (self.context?.animatedEmojiStickers.keys).flatMap(Set.init) ?? Set(), emojiViewProvider: self.emojiViewProvider)
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
        
        var images: [UIImage] = []
        if let data = pasteboard.data(forPasteboardType: "com.compuserve.gif") {
            self.paste(.gif(data))
            return false
        } else if let data = pasteboard.data(forPasteboardType: "public.mpeg-4") {
            self.paste(.video(data))
            return false
        } else {
            var isPNG = false
            var isMemoji = false
            for item in pasteboard.items {
                if let image = item["com.apple.png-sticker"] as? UIImage {
                    images.append(image)
                    isPNG = true
                    isMemoji = true
                } else if let image = item[kUTTypePNG as String] as? UIImage {
                    images.append(image)
                    isPNG = true
                } else if let image = item["com.apple.uikit.image"] as? UIImage {
                    images.append(image)
                    isPNG = true
                } else if let image = item[kUTTypeJPEG as String] as? UIImage {
                    images.append(image)
                } else if let image = item[kUTTypeGIF as String] as? UIImage {
                    images.append(image)
                }
            }
            
            if isPNG && images.count == 1, let image = images.first, let cgImage = image.cgImage {
                let maxSide = max(image.size.width, image.size.height)
                if maxSide.isZero {
                    return false
                }
                let aspectRatio = min(image.size.width, image.size.height) / maxSide
                if isMemoji || (imageHasTransparency(cgImage) && aspectRatio > 0.85) {
                    self.paste(.sticker(image, isMemoji))
                    return true
                }
            }
            
            if !images.isEmpty {
                self.paste(.images(images))
                return false
            }
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
    
        self.sendMessage()
    }
    
    @objc func sendAsAvatarButtonPressed() {
        self.interfaceInteraction?.openSendAsPeer(self.sendAsAvatarReferenceNode, nil)
    }
    
    @objc func menuButtonPressed() {
        self.hapticFeedback.impact(.light)
        guard let presentationInterfaceState = self.presentationInterfaceState else {
            return
        }
        
        if let sendAsPeers = presentationInterfaceState.sendAsPeers, !sendAsPeers.isEmpty {
            self.interfaceInteraction?.updateShowSendAsPeers { value in
                return !value
            }
        } else if case let .webView(title, url) = presentationInterfaceState.botMenuButton {
            let willShow = !(self.presentationInterfaceState?.showWebView ?? false)
            if willShow {
                self.interfaceInteraction?.openWebView(title, url, false, true)
            } else {
                self.interfaceInteraction?.updateShowWebView { _ in
                    return false
                }
            }
        } else {
            self.interfaceInteraction?.updateShowCommands { value in
                return !value
            }
        }
    }

    @objc func attachmentButtonPressed() {
        self.displayAttachmentMenu()
    }
    
    @objc func searchLayoutClearButtonPressed() {
        if let interfaceInteraction = self.interfaceInteraction {
            interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                var mentionQueryRange: NSRange?
                inner: for (_, type, queryRange) in textInputStateContextQueryRangeAndType(textInputState) {
                    if type == [.contextRequest] {
                        mentionQueryRange = queryRange
                        break inner
                    }
                }
                if let mentionQueryRange = mentionQueryRange, mentionQueryRange.length > 0 {
                    let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                    
                    let rangeLower = mentionQueryRange.lowerBound
                    let rangeUpper = mentionQueryRange.upperBound
                    
                    inputText.replaceCharacters(in: NSRange(location: rangeLower, length: rangeUpper - rangeLower), with: "")
                    
                    return (ChatTextInputState(inputText: inputText), inputMode)
                } else {
                    return (ChatTextInputState(inputText: NSAttributedString(string: "")), inputMode)
                }
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
    
    @objc func expandButtonPressed() {
        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
            if case let .media(mode, expanded, focused) = state.inputMode {
                if let _ = expanded {
                    return (.media(mode: mode, expanded: nil, focused: focused), state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
                } else {
                    return (.media(mode: mode, expanded: .content, focused: focused), state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
                }
            } else {
                return (state.inputMode, state.interfaceState.messageActionsState.closedButtonKeyboardMessageId)
            }
        })
    }
    
    @objc func accessoryItemButtonPressed(_ button: UIView) {
        for (item, currentButton) in self.accessoryItemButtons {
            if currentButton === button {
                switch item {
                    case let .stickers(enabled):
                        if enabled {
                            self.interfaceInteraction?.openStickers()
                        } else {
                            self.interfaceInteraction?.displayRestrictedInfo(.stickers, .tooltip)
                        }
                    case .keyboard:
                        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                            return (.text, state.keyboardButtonsMessage?.id)
                        })
                    case .inputButtons:
                        self.interfaceInteraction?.updateInputModeAndDismissedButtonKeyboardMessageId({ state in
                            return (.inputButtons, nil)
                        })
                    case .commands:
                        self.interfaceInteraction?.updateTextInputStateAndMode { _, inputMode in
                            return (ChatTextInputState(inputText: NSAttributedString(string: "/")), .text)
                        }
                    case .silentPost:
                        self.interfaceInteraction?.toggleSilentPost()
                    case .messageAutoremoveTimeout:
                        self.interfaceInteraction?.setupMessageAutoremoveTimeout()
                    case .scheduledMessages:
                        self.interfaceInteraction?.openScheduledMessages()
                }
                break
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let audioRecordingCancelIndicator = self.audioRecordingCancelIndicator {
            if let result = audioRecordingCancelIndicator.hitTest(point.offsetBy(dx: -audioRecordingCancelIndicator.frame.minX, dy: -audioRecordingCancelIndicator.frame.minY), with: event) {
                return result
            }
        }
        let result = super.hitTest(point, with: event)
        return result
    }
    
    func frameForAccessoryButton(_ item: ChatTextInputAccessoryItem) -> CGRect? {
        for (buttonItem, buttonNode) in self.accessoryItemButtons {
            if buttonItem == item {
                return buttonNode.frame
            }
        }
        return nil
    }
    
    func frameForAttachmentButton() -> CGRect? {
        if !self.attachmentButton.alpha.isZero {
            return self.attachmentButton.frame.insetBy(dx: 0.0, dy: 6.0).offsetBy(dx: 2.0, dy: 0.0)
        }
        return nil
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
    
    func frameForStickersButton() -> CGRect? {
        for (item, button) in self.accessoryItemButtons {
            if case .stickers = item {
                return button.frame.insetBy(dx: 0.0, dy: 6.0)
            }
        }
        return nil
    }

    func makeSnapshotForTransition() -> ChatMessageTransitionNode.Source.TextInput? {
        guard let backgroundImage = self.transparentTextInputBackgroundImage else {
            return nil
        }
        guard let textInputNode = self.textInputNode else {
            return nil
        }

        let backgroundView = UIImageView(image: backgroundImage)
        backgroundView.frame = self.textInputBackgroundNode.frame

        let caretColor = textInputNode.textView.tintColor
        textInputNode.textView.tintColor = .clear

        guard let contentView = textInputNode.view.snapshotView(afterScreenUpdates: true) else {
            textInputNode.textView.tintColor = caretColor
            return nil
        }

        textInputNode.textView.tintColor = caretColor

        contentView.frame = textInputNode.frame

        return ChatMessageTransitionNode.Source.TextInput(
            backgroundView: backgroundView,
            contentView: contentView,
            sourceRect: self.view.convert(self.bounds, to: nil),
            scrollOffset: textInputNode.textView.contentOffset.y
        )
    }
    
    func makeAttachmentMenuTransition(accessoryPanelNode: ASDisplayNode?) -> AttachmentController.InputPanelTransition {
        return AttachmentController.InputPanelTransition(inputNode: self, accessoryPanelNode: accessoryPanelNode, menuButtonNode: self.menuButton, menuButtonBackgroundNode: self.menuButtonBackgroundNode, menuIconNode: self.menuButtonIconNode, menuTextNode: self.menuButtonTextNode, prepareForDismiss: { self.menuButtonIconNode.enqueueState(.app, animated: false) })
    }
}

private enum MenuIconNodeState: Equatable {
    case menu
    case app
    case close
}

private final class MenuIconNode: ManagedAnimationNode {
    private let duration: Double = 0.33
    fileprivate var iconState: MenuIconNodeState = .menu
    
    init() {
        super.init(size: CGSize(width: 30.0, height: 30.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
    }
    
    func enqueueState(_ state: MenuIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .close:
                switch state {
                    case .menu:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_closemenu"), frames: .range(startFrame: 0, endFrame: 20), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .app:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 0, endFrame: 22), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 22, endFrame: 22), duration: 0.01))
                        }
                    case .close:
                        break
                }
            case .menu:
                switch state {
                    case .close:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 20), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 20, endFrame: 20), duration: 0.01))
                        }
                    case .app:
                        self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 22, endFrame: 22), duration: 0.01))
                    case .menu:
                        break
                }
            case .app:
                switch state {
                    case .close:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 22, endFrame: 0), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .menu:
                        self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 20), duration: 0.01))
                    case .app:
                        break
            }
        }
    }
}
