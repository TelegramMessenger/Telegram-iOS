import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TextFormat
import TelegramPresentationData
import InvisibleInkDustNode
import EmojiTextAttachmentView
import AccountContext
import TextFormat
import Pasteboard
import ChatTextLinkEditUI
import MobileCoreServices
import ImageTransparency
import ChatInputTextNode
import TextInputMenu
import ObjCRuntimeUtils
import MultilineTextComponent

public final class EmptyInputView: UIView, UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool {
        return true
    }
}

public final class TextFieldComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var isEditing: Bool = false
        public fileprivate(set) var hasText: Bool = false
        public fileprivate(set) var text: NSAttributedString = NSAttributedString()
        public fileprivate(set) var textLength: Int = 0
        public var initialText: NSAttributedString?
        
        public var hasTrackingView = false
        
        public var currentEmojiSuggestion: EmojiSuggestion?
        public var dismissedEmojiSuggestionPosition: EmojiSuggestion.Position?
        
        public var currentEmojiSearch: EmojiSearch?
        public var dismissedEmojiSearchPosition: EmojiSearch.Position?
        
        public init() {
        }
    }
    
    public final class EmojiSuggestion {
        public struct Position: Equatable {
            public var range: NSRange
            public var value: String
        }
        
        public var localPosition: CGPoint
        public var position: Position
        public var disposable: Disposable?
        public var value: Any?
        
        init(localPosition: CGPoint, position: Position) {
            self.localPosition = localPosition
            self.position = position
            self.disposable = nil
            self.value = nil
        }
    }
    
    public final class EmojiSearch {
        public struct Position: Equatable {
            public var range: NSRange
            public var value: String
        }
        
        public var localPosition: CGPoint
        public var position: Position
        public var disposable: Disposable?
        public var value: Any?
        
        init(localPosition: CGPoint, position: Position) {
            self.localPosition = localPosition
            self.position = position
            self.disposable = nil
            self.value = nil
        }
    }
    
    public enum PasteData {
        case sticker(image: UIImage, isMemoji: Bool)
        case images([UIImage])
        case video(Data)
        case gif(Data)
        case text(NSAttributedString)
    }
    
    
    public final class AnimationHint {
        public enum Kind: Equatable {
            case textChanged
            case textFocusChanged(isFocused: Bool)
        }
        
        public weak var view: View?
        public let kind: Kind
        
        public init(view: View?, kind: Kind) {
            self.view = view
            self.kind = kind
        }
    }
    
    public enum FormatMenuAvailability: Equatable {
        public enum Action: CaseIterable {
            case bold
            case italic
            case monospace
            case link
            case strikethrough
            case underline
            case spoiler
            case quote
            case code
            
            public static var all: [Action] = [
                .bold,
                .italic,
                .monospace,
                .link,
                .strikethrough,
                .underline,
                .spoiler,
                .quote,
                .code
            ]
        }
        case available([Action])
        case locked
        case none
    }
    
    public enum EmptyLineHandling {
        case allowed
        case oneConsecutive
        case notAllowed
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let externalState: ExternalState
    public let fontSize: CGFloat
    public let textColor: UIColor
    public let accentColor: UIColor
    public let insets: UIEdgeInsets
    public let hideKeyboard: Bool
    public let customInputView: UIView?
    public let placeholder: NSAttributedString?
    public let resetText: NSAttributedString?
    public let assumeIsEditing: Bool
    public let isOneLineWhenUnfocused: Bool
    public let characterLimit: Int?
    public let enableInlineAnimations: Bool
    public let emptyLineHandling: EmptyLineHandling
    public let externalHandlingForMultilinePaste: Bool
    public let formatMenuAvailability: FormatMenuAvailability
    public let returnKeyType: UIReturnKeyType
    public let lockedFormatAction: () -> Void
    public let present: (ViewController) -> Void
    public let paste: (PasteData) -> Void
    public let returnKeyAction: (() -> Void)?
    public let backspaceKeyAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        externalState: ExternalState,
        fontSize: CGFloat,
        textColor: UIColor,
        accentColor: UIColor,
        insets: UIEdgeInsets,
        hideKeyboard: Bool,
        customInputView: UIView?,
        placeholder: NSAttributedString? = nil,
        resetText: NSAttributedString?,
        assumeIsEditing: Bool = false,
        isOneLineWhenUnfocused: Bool,
        characterLimit: Int? = nil,
        enableInlineAnimations: Bool = true,
        emptyLineHandling: EmptyLineHandling = .allowed,
        externalHandlingForMultilinePaste: Bool = false,
        formatMenuAvailability: FormatMenuAvailability,
        returnKeyType: UIReturnKeyType = .default,
        lockedFormatAction: @escaping () -> Void,
        present: @escaping (ViewController) -> Void,
        paste: @escaping (PasteData) -> Void,
        returnKeyAction: (() -> Void)? = nil,
        backspaceKeyAction: (() -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.externalState = externalState
        self.fontSize = fontSize
        self.textColor = textColor
        self.accentColor = accentColor
        self.insets = insets
        self.hideKeyboard = hideKeyboard
        self.customInputView = customInputView
        self.placeholder = placeholder
        self.resetText = resetText
        self.assumeIsEditing = assumeIsEditing
        self.isOneLineWhenUnfocused = isOneLineWhenUnfocused
        self.characterLimit = characterLimit
        self.enableInlineAnimations = enableInlineAnimations
        self.emptyLineHandling = emptyLineHandling
        self.externalHandlingForMultilinePaste = externalHandlingForMultilinePaste
        self.formatMenuAvailability = formatMenuAvailability
        self.returnKeyType = returnKeyType
        self.lockedFormatAction = lockedFormatAction
        self.present = present
        self.paste = paste
        self.returnKeyAction = returnKeyAction
        self.backspaceKeyAction = backspaceKeyAction
    }
    
    public static func ==(lhs: TextFieldComponent, rhs: TextFieldComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.fontSize != rhs.fontSize {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.hideKeyboard != rhs.hideKeyboard {
            return false
        }
        if lhs.customInputView !== rhs.customInputView {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.resetText != rhs.resetText {
            return false
        }
        if lhs.assumeIsEditing != rhs.assumeIsEditing {
            return false
        }
        if lhs.isOneLineWhenUnfocused != rhs.isOneLineWhenUnfocused {
            return false
        }
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.enableInlineAnimations != rhs.enableInlineAnimations {
            return false
        }
        if lhs.emptyLineHandling != rhs.emptyLineHandling {
            return false
        }
        if lhs.externalHandlingForMultilinePaste != rhs.externalHandlingForMultilinePaste {
            return false
        }
        if lhs.formatMenuAvailability != rhs.formatMenuAvailability {
            return false
        }
        if lhs.returnKeyType != rhs.returnKeyType {
            return false
        }
        return true
    }
    
    public struct InputState {
        public var inputText: NSAttributedString
        public var selectionRange: Range<Int>
        
        public init(inputText: NSAttributedString, selectionRange: Range<Int>) {
            self.inputText = inputText
            self.selectionRange = selectionRange
        }
        
        public init(inputText: NSAttributedString) {
            self.inputText = inputText
            let length = inputText.length
            self.selectionRange = length ..< length
        }
    }
    
    public final class View: UIView, UIScrollViewDelegate, ChatInputTextNodeDelegate {
        private var placeholder: ComponentView<Empty>?
        private let textView: ChatInputTextView
        private let inputMenu: TextInputMenu
        
        private var spoilerView: InvisibleInkDustView?
        private var customEmojiContainerView: CustomEmojiContainerView?
        private var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
                
        private let ellipsisView = ComponentView<Empty>()
        
        public var inputState: InputState {
            let selectionRange: Range<Int> = self.textView.selectedRange.location ..< (self.textView.selectedRange.location + self.textView.selectedRange.length)
            return InputState(inputText: stateAttributedStringForText(self.textView.attributedText ?? NSAttributedString()), selectionRange: selectionRange)
        }
        
        private var component: TextFieldComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.textView = ChatInputTextView(disableTiling: false)
            self.textView.translatesAutoresizingMaskIntoConstraints = false
            self.textView.backgroundColor = nil
            self.textView.layer.isOpaque = false
            self.textView.indicatorStyle = .white
            self.textView.scrollIndicatorInsets = UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0)
            
            self.inputMenu = TextInputMenu(hasSpoilers: true, hasQuotes: true)
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            
            self.textView.customDelegate = self
            self.addSubview(self.textView)
            
            self.textView.typingAttributes = [
                NSAttributedString.Key.font: Font.regular(17.0),
                NSAttributedString.Key.foregroundColor: UIColor.white
            ]
            
            self.textView.toggleQuoteCollapse = { [weak self] range in
                guard let self else {
                    return
                }
                
                self.updateInputState { current in
                    let result = NSMutableAttributedString(attributedString: current.inputText)
                    var selectionRange = current.selectionRange
                    
                    if let _ = result.attribute(ChatTextInputAttributes.block, at: range.lowerBound, effectiveRange: nil) as? ChatTextInputTextQuoteAttribute {
                        let blockString = NSMutableAttributedString(attributedString: result.attributedSubstring(from: range))
                        blockString.removeAttribute(ChatTextInputAttributes.block, range: NSRange(location: 0, length: blockString.length))
                        
                        result.replaceCharacters(in: range, with: "")
                        result.insert(NSAttributedString(string: " ", attributes: [
                            ChatTextInputAttributes.collapsedBlock: blockString
                        ]), at: range.lowerBound)
                        
                        if selectionRange.lowerBound >= range.lowerBound && selectionRange.upperBound < range.upperBound {
                            selectionRange = range.lowerBound ..< range.lowerBound
                        } else if selectionRange.lowerBound >= range.upperBound {
                            let deltaLength = 1 - range.length
                            selectionRange = (selectionRange.lowerBound + deltaLength) ..< (selectionRange.lowerBound + deltaLength)
                        }
                    } else if let current = result.attribute(ChatTextInputAttributes.collapsedBlock, at: range.lowerBound, effectiveRange: nil) as? NSAttributedString {
                        result.replaceCharacters(in: range, with: "")
                        
                        let updatedBlockString = NSMutableAttributedString(attributedString: current)
                        updatedBlockString.addAttribute(ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false), range: NSRange(location: 0, length: updatedBlockString.length))
                        
                        result.insert(updatedBlockString, at: range.lowerBound)
                        
                        if selectionRange.lowerBound >= range.upperBound {
                            let deltaLength = updatedBlockString.length - 1
                            selectionRange = (selectionRange.lowerBound + deltaLength) ..< (selectionRange.lowerBound + deltaLength)
                        }
                    }
                    
                    let stateResult = stateAttributedStringForText(result)
                    if selectionRange.lowerBound < 0 {
                        selectionRange = 0 ..< selectionRange.upperBound
                    }
                    if selectionRange.upperBound > stateResult.length {
                        selectionRange = selectionRange.lowerBound ..< stateResult.length
                    }
                    
                    return InputState(
                        inputText: stateResult,
                        selectionRange: selectionRange
                    )
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func updateInputState(_ f: (InputState) -> InputState) {
            guard let component = self.component else {
                return
            }
            
            let inputState = f(self.inputState)
            
            let currentAttributedText = self.textView.attributedText
            let updatedAttributedText = textAttributedStringForStateText(context: component.context, stateText:  inputState.inputText, fontSize: component.fontSize, textColor: component.textColor, accentTextColor: component.accentColor, writingDirection: nil, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickersValue.keys), emojiViewProvider: self.emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
                return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
            })
            if currentAttributedText != updatedAttributedText {
                self.textView.attributedText = updatedAttributedText
            }
            self.textView.selectedRange = NSMakeRange(inputState.selectionRange.lowerBound, inputState.selectionRange.count)
            
            refreshChatTextInputAttributes(context: component.context, textView: self.textView, primaryTextColor: component.textColor, accentTextColor: component.accentColor, baseFontSize: component.fontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickersValue.keys), emojiViewProvider: self.emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
                return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
            })
            
            self.updateEntities()
            
            if currentAttributedText != updatedAttributedText && !self.isUpdating {
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textChanged)))
            }
        }
        
        public func hasFirstResponder() -> Bool {
            return self.textView.isFirstResponder
        }
        
        public func insertText(_ text: NSAttributedString) {
            guard let component = self.component else {
                return
            }
            
            self.updateInputState { state in
                if let characterLimit = component.characterLimit, state.inputText.string.count + text.string.count > characterLimit {
                    return state
                }
                return state.insertText(text)
            }
            if !self.isUpdating {
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textChanged)))
            }
        }
        
        public func deleteBackward() {
            self.textView.deleteBackward()
        }
        
        public func updateText(_ text: NSAttributedString, selectionRange: Range<Int>) {
            self.updateInputState { _ in
                return TextFieldComponent.InputState(inputText: text, selectionRange: selectionRange)
            }
            if !self.isUpdating {
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textChanged)))
            }
        }
        
        private func onPaste() -> Bool {
            guard let component = self.component else {
                return false
            }
            let pasteboard = UIPasteboard.general
                        
            var attributedString: NSAttributedString?
            if let data = pasteboard.data(forPasteboardType: kUTTypeRTF as String) {
                attributedString = chatInputStateStringFromRTF(data, type: NSAttributedString.DocumentType.rtf)
            } else if let data = pasteboard.data(forPasteboardType: "com.apple.flat-rtfd") {
                attributedString = chatInputStateStringFromRTF(data, type: NSAttributedString.DocumentType.rtfd)
            }
            
            if let attributedString = attributedString {
                let current = self.inputState
                let range = NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count)
                if component.externalHandlingForMultilinePaste, component.emptyLineHandling == .notAllowed, attributedString.string.contains("\n") {
                    component.paste(.text(attributedString))
                    return false
                }
                if !self.chatInputTextNode(shouldChangeTextIn: range, replacementText: attributedString.string) {
                    return false
                }
                
                self.updateInputState { current in
                    if let inputText = current.inputText.mutableCopy() as? NSMutableAttributedString {
                        inputText.replaceCharacters(in: NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count), with: attributedString)
                        let updatedRange = current.selectionRange.lowerBound + attributedString.length
                        return InputState(inputText: inputText, selectionRange: updatedRange ..< updatedRange)
                    } else {
                        return InputState(inputText: attributedString)
                    }
                }
                if !self.isUpdating {
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textChanged)))
                }
                component.paste(.text(attributedString))
                return false
            }
            
            if let data = pasteboard.data(forPasteboardType: "com.compuserve.gif") {
                component.paste(.gif(data))
                return false
            } else if let data = pasteboard.data(forPasteboardType: "public.mpeg-4") {
                component.paste(.video(data))
                return false
            } else {
                var images: [UIImage] = []
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
                
                if isPNG && images.count == 1, let image = images.first {
                    let maxSide = max(image.size.width, image.size.height)
                    if maxSide.isZero {
                        return false
                    }
                    let aspectRatio = min(image.size.width, image.size.height) / maxSide
                    if isMemoji || (imageHasTransparency(image) && aspectRatio > 0.2) {
                        component.paste(.sticker(image: image, isMemoji: isMemoji))
                        return false
                    }
                }
                
                if !images.isEmpty {
                    component.paste(.images(images))
                    return false
                }
            }
            
            component.paste(.text(NSAttributedString()))
            return true
        }
        
        public func chatInputTextNodeDidUpdateText() {
            guard let component = self.component else {
                return
            }
            refreshChatTextInputAttributes(context: component.context, textView: self.textView, primaryTextColor: component.textColor, accentTextColor: component.accentColor, baseFontSize: component.fontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickersValue.keys), emojiViewProvider: self.emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
                return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
            })
            refreshChatTextInputTypingAttributes(self.textView, textColor: component.textColor, baseFontSize: component.fontSize)
            self.textView.updateTextContainerInset()
            
            if self.spoilerIsDisappearing {
                self.spoilerIsDisappearing = false
                self.updateInternalSpoilersRevealed(false, animated: false)
            }
            
            self.updateEntities()
            if !self.isUpdating {
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textChanged)))
            }
        }
        
        public func chatInputTextNodeShouldReturn() -> Bool {
            guard let component = self.component else {
                return true
            }
            if let returnKeyAction = component.returnKeyAction {
                returnKeyAction()
                return false
            }
            return true
        }
        
        public func chatInputTextNodeDidChangeSelection(dueToEditing: Bool) {
            guard let _ = self.component else {
                return
            }
            
            self.updateSpoilersRevealed()
            self.updateEmojiSuggestion(transition: .immediate)
        }
        
        public func chatInputTextNodeDidBeginEditing() {
            guard let component = self.component else {
                return
            }
            if !self.isUpdating {
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.5, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textFocusChanged(isFocused: true))))
            }
            if component.isOneLineWhenUnfocused {
                Queue.mainQueue().justDispatch {
                    self.textView.selectedTextRange = self.textView.textRange(from: self.textView.endOfDocument, to: self.textView.endOfDocument)
                }
            }
        }
        
        public func chatInputTextNodeDidFinishEditing() {
            if !self.isUpdating {
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.5, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textFocusChanged(isFocused: false))))
            }
        }
        
        public func chatInputTextNodeBackspaceWhileEmpty() {
            guard let component = self.component else {
                return
            }
            component.backspaceKeyAction?()
        }
        
        @available(iOS 13.0, *)
        public func chatInputTextNodeMenu(forTextRange textRange: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu {
            let filteredActions: Set<String> = Set([
                "com.apple.menu.format",
                "com.apple.menu.replace"
            ])
            let suggestedActions = suggestedActions.filter {
                if let action = $0 as? UIMenu, filteredActions.contains(action.identifier.rawValue) {
                    return false
                } else {
                    return true
                }
            }
            guard let component = self.component, let attributedText = self.textView.attributedText, !attributedText.string.isEmpty, self.textView.selectedRange.length > 0 else {
                return UIMenu(children: suggestedActions)
            }
            let strings = component.strings
            
            if case .none = component.formatMenuAvailability {
                return UIMenu(children: suggestedActions)
            }
            
            if case .locked = component.formatMenuAvailability {
                var updatedActions = suggestedActions
                let formatAction = UIAction(title: strings.TextFormat_Format, image: nil) { [weak self] action in
                    if let self {
                        self.component?.lockedFormatAction()
                    }
                }
                updatedActions.insert(formatAction, at: 1)
                return UIMenu(children: updatedActions)
            }
            
            guard case let .available(availableActions) = component.formatMenuAvailability else {
                return UIMenu(children: suggestedActions)
            }
                        
            var actions: [UIAction] = []
            if availableActions.contains(.bold) {
                actions.append(UIAction(title: strings.TextFormat_Bold, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.bold)
                    }
                })
            }
            if availableActions.contains(.italic) {
                actions.append(UIAction(title: strings.TextFormat_Italic, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.italic)
                    }
                })
            }
            if availableActions.contains(.monospace) {
                actions.append(UIAction(title: strings.TextFormat_Monospace, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.monospace)
                    }
                })
            }
            if availableActions.contains(.link) {
                actions.append(UIAction(title: strings.TextFormat_Link, image: nil) { [weak self] action in
                    if let self {
                        self.openLinkEditing()
                    }
                })
            }
            if availableActions.contains(.strikethrough) {
                actions.append(UIAction(title: strings.TextFormat_Strikethrough, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.strikethrough)
                    }
                })
            }
            if availableActions.contains(.underline) {
                actions.append(UIAction(title: strings.TextFormat_Underline, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.underline)
                    }
                })
            }
            if availableActions.contains(.spoiler) {
                actions.append(UIAction(title: strings.TextFormat_Spoiler, image: nil) { [weak self] action in
                    if let self {
                        var animated = false
                        let attributedText = self.inputState.inputText
                        attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, _, _ in
                            if let _ = attributes[ChatTextInputAttributes.spoiler] {
                                animated = true
                            }
                        })
                        
                        self.toggleAttribute(key: ChatTextInputAttributes.spoiler)
                        
                        self.updateSpoilersRevealed(animated: animated)
                    }
                })
            }
            if availableActions.contains(.quote) {
                actions.insert(UIAction(title: strings.TextFormat_Quote, image: nil) { [weak self] action in
                    if let self {
                        var animated = false
                        let attributedText = self.inputState.inputText
                        attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, _, _ in
                            if let _ = attributes[ChatTextInputAttributes.block] {
                                animated = true
                            }
                        })
                        
                        self.toggleAttribute(key: ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false))
                        
                        self.updateSpoilersRevealed(animated: animated)
                    }
                }, at: 0)
            }
            if availableActions.contains(.code) {
                actions.append(UIAction(title: strings.TextFormat_Code, image: nil) { [weak self] action in
                    if let self {
                        var animated = false
                        let attributedText = self.inputState.inputText
                        attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, _, _ in
                            if let _ = attributes[ChatTextInputAttributes.block] {
                                animated = true
                            }
                        })
                        
                        self.toggleAttribute(key: ChatTextInputAttributes.block, value: ChatTextInputTextQuoteAttribute(kind: .code(language: nil), isCollapsed: false))
                        
                        self.updateSpoilersRevealed(animated: animated)
                    }
                })
            }
            
            var updatedActions = suggestedActions
            let formatMenu = UIMenu(title: strings.TextFormat_Format, image: nil, children: actions)
            updatedActions.insert(formatMenu, at: 1)
            
            return UIMenu(children: updatedActions)
        }
        
        public func chatInputTextNode(shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let component = self.component else {
                return true
            }
            
            if let characterLimit = component.characterLimit {
                let string = self.inputState.inputText.string as NSString
                let changingRangeString = string.substring(with: range)
                
                let deltaLength = text.count - changingRangeString.count
                let resultingLength = (string as String).count + deltaLength
                if resultingLength > characterLimit {
                    let availableLength = characterLimit - (string as String).count
                    if availableLength > 0 {
                        var insertString = ""
                        for i in 0 ..< availableLength {
                            if text.count <= i {
                                break
                            }
                            insertString.append(text[text.index(text.startIndex, offsetBy: i)])
                        }
                        
                        switch component.emptyLineHandling {
                        case .allowed:
                            break
                        case .oneConsecutive:
                            while insertString.range(of: "\n\n") != nil {
                                if let range = insertString.range(of: "\n\n") {
                                    insertString.replaceSubrange(range, with: "\n")
                                }
                            }
                        case .notAllowed:
                            insertString = insertString.replacingOccurrences(of: "\n", with: "")
                        }
                        
                        self.insertText(NSAttributedString(string: insertString))
                    } else if (range.length == 0 && text == "\n"), let returnKeyAction = component.returnKeyAction {
                        returnKeyAction()
                        return false
                    }
                    return false
                }
            }
            if text.count != 0 {
                switch component.emptyLineHandling {
                case .allowed:
                    break
                case .oneConsecutive:
                    let string = self.inputState.inputText.string as NSString
                    let updatedString = string.replacingCharacters(in: range, with: text)
                    if updatedString.range(of: "\n\n") != nil {
                        return false
                    }
                case .notAllowed:
                    if (range.length == 0 && text == "\n"), let returnKeyAction = component.returnKeyAction {
                        returnKeyAction()
                        return false
                    }
                    
                    if text.range(of: "\n") != nil {
                        let updatedText = text.replacingOccurrences(of: "\n", with: "")
                        if !updatedText.isEmpty {
                            self.insertText(NSAttributedString(string: updatedText))
                        }
                        return false
                    }
                }
            }
            
            return true
        }
        
        public func chatInputTextNodeShouldCopy() -> Bool {
            return true
        }
        
        public func chatInputTextNodeShouldPaste() -> Bool {
            return self.onPaste()
        }
        
        public func chatInputTextNodeShouldRespondToAction(action: Selector) -> Bool {
            if action == #selector(self.paste(_:)) {
                return true
            }
            return true
        }
        
        public func chatInputTextNodeTargetForAction(action: Selector) -> ChatInputTextNode.TargetForAction? {
            if action == makeSelectorFromString("_accessibilitySpeak:") {
                if case .format = self.inputMenu.state {
                    return ChatInputTextNode.TargetForAction(target: nil)
                } else if self.textView.selectedRange.length > 0 {
                    return ChatInputTextNode.TargetForAction(target: self)
                } else {
                    return ChatInputTextNode.TargetForAction(target: nil)
                }
            } else if action == makeSelectorFromString("_accessibilitySpeakSpellOut:") {
                if case .format = self.inputMenu.state {
                    return ChatInputTextNode.TargetForAction(target: nil)
                } else if self.textView.selectedRange.length > 0 {
                    return nil
                } else {
                    return ChatInputTextNode.TargetForAction(target: nil)
                }
            }
            else if action == makeSelectorFromString("_accessibilitySpeakLanguageSelection:") || action == makeSelectorFromString("_accessibilityPauseSpeaking:") || action == makeSelectorFromString("_accessibilitySpeakSentence:") {
                return ChatInputTextNode.TargetForAction(target: nil)
            } else if action == makeSelectorFromString("_showTextStyleOptions:") {
                if #available(iOS 16.0, *) {
                    return ChatInputTextNode.TargetForAction(target: nil)
                } else {
                    if case .general = self.inputMenu.state {
                        if self.textView.attributedText == nil || self.textView.attributedText!.length == 0 {
                            return ChatInputTextNode.TargetForAction(target: nil)
                        }
                        return ChatInputTextNode.TargetForAction(target: self)
                    } else {
                        return ChatInputTextNode.TargetForAction(target: nil)
                    }
                }
            } else if action == #selector(self.formatAttributesBold(_:)) || action == #selector(self.formatAttributesItalic(_:)) || action == #selector(self.formatAttributesMonospace(_:)) || action == #selector(self.formatAttributesStrikethrough(_:)) || action == #selector(self.formatAttributesUnderline(_:)) || action == #selector(self.formatAttributesSpoiler(_:)) || action == #selector(self.formatAttributesQuote(_:)) || action == #selector(self.formatAttributesCodeBlock(_:)) {
                if case .format = self.inputMenu.state {
                    if action == #selector(self.formatAttributesSpoiler(_:)) {
                        let selectedRange = self.textView.selectedRange
                        var intersectsMonospace = false
                        self.inputState.inputText.enumerateAttributes(in: selectedRange, options: [], using: { attributes, _, _ in
                            if let _ = attributes[ChatTextInputAttributes.monospace] {
                                intersectsMonospace = true
                            }
                        })
                        if !intersectsMonospace {
                            return ChatInputTextNode.TargetForAction(target: self)
                        } else {
                            return ChatInputTextNode.TargetForAction(target: nil)
                        }
                    } else if action == #selector(self.formatAttributesQuote(_:)) {
                        return ChatInputTextNode.TargetForAction(target: self)
                    } else if action == #selector(self.formatAttributesCodeBlock(_:)) {
                        return ChatInputTextNode.TargetForAction(target: self)
                    } else if action == #selector(self.formatAttributesMonospace(_:)) {
                        var intersectsSpoiler = false
                        self.inputState.inputText.enumerateAttributes(in: self.textView.selectedRange, options: [], using: { attributes, _, _ in
                            if let _ = attributes[ChatTextInputAttributes.spoiler] {
                                intersectsSpoiler = true
                            }
                        })
                        if !intersectsSpoiler {
                            return ChatInputTextNode.TargetForAction(target: self)
                        } else {
                            return ChatInputTextNode.TargetForAction(target: nil)
                        }
                    } else {
                        return ChatInputTextNode.TargetForAction(target: self)
                    }
                } else {
                    return ChatInputTextNode.TargetForAction(target: nil)
                }
            }
            if case .format = self.inputMenu.state {
                return ChatInputTextNode.TargetForAction(target: nil)
            }
            return nil
        }
        
        @objc func _showTextStyleOptions(_ sender: Any) {
            let selectionRect: CGRect
            if let selectedTextRange = self.textView.selectedTextRange {
                selectionRect = self.textView.firstRect(for: selectedTextRange)
            } else {
                selectionRect = self.textView.bounds
            }
            
            self.inputMenu.format(view: self.textView, rect: selectionRect.offsetBy(dx: 0.0, dy: -self.textView.contentOffset.y).insetBy(dx: 0.0, dy: -1.0))
        }
        
        @objc func formatAttributesBold(_ sender: Any) {
            self.inputMenu.back()
        }
        
        @objc func formatAttributesItalic(_ sender: Any) {
            self.inputMenu.back()
        }
        
        @objc func formatAttributesMonospace(_ sender: Any) {
            self.inputMenu.back()
        }
        
        @objc func formatAttributesStrikethrough(_ sender: Any) {
            self.inputMenu.back()
        }
        
        @objc func formatAttributesUnderline(_ sender: Any) {
            self.inputMenu.back()
        }
        
        @objc func formatAttributesQuote(_ sender: Any) {
            self.inputMenu.back()
        }
        
        @objc func formatAttributesCodeBlock(_ sender: Any) {
            self.inputMenu.back()
        }
        
        @objc func formatAttributesSpoiler(_ sender: Any) {
            self.inputMenu.back()
        }
        
        private func toggleAttribute(key: NSAttributedString.Key, value: Any? = nil) {
            self.updateInputState { state in
                return state.addFormattingAttribute(attribute: key, value: value)
            }
        }
                
        private func openLinkEditing() {
            guard let component = self.component else {
                return
            }
            let selectionRange = self.inputState.selectionRange
            let text = self.inputState.inputText.attributedSubstring(from: NSRange(location: selectionRange.startIndex, length: selectionRange.count))
            var link: String?
            text.enumerateAttributes(in: NSMakeRange(0, text.length)) { attributes, _, _ in
                if let linkAttribute = attributes[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                    link = linkAttribute.url
                }
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: component.theme)
            let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
            let controller = chatTextLinkEditController(sharedContext: component.context.sharedContext, updatedPresentationData: updatedPresentationData, account: component.context.account, text: text.string, link: link, allowEmpty: true, apply: { [weak self] link in
                if let self {
                    if let link {
                        if !link.isEmpty {
                            self.updateInputState { state in
                                return state.addLinkAttribute(selectionRange: selectionRange, url: link)
                            }
                        } else {
                            self.updateInputState { state in
                                return state.removeLinkAttribute(selectionRange: selectionRange)
                            }
                        }
                        self.textView.becomeFirstResponder()
                    }
                }
            })
            component.present(controller)
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            //print("didScroll \(scrollView.bounds)")
        }
        
        public func getInputState() -> TextFieldComponent.InputState {
            return self.inputState
        }
        
        public func getAttributedText() -> NSAttributedString {
            Keyboard.applyAutocorrection(textView: self.textView)
            return expandedInputStateAttributedString(self.inputState.inputText)
        }
        
        public func setAttributedText(_ string: NSAttributedString, updateState: Bool) {
            self.updateInputState { _ in
                return TextFieldComponent.InputState(inputText: string, selectionRange: string.length ..< string.length)
            }
            if updateState && !self.isUpdating {
                self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(view: self, kind: .textChanged)))
            }
        }
        
        public func activateInput() {
            self.textView.becomeFirstResponder()
        }
        
        public func deactivateInput() {
            self.textView.resignFirstResponder()
        }
        
        public var isActive: Bool {
            return self.textView.isFirstResponder
        }
        
        private var spoilersRevealed = false
        private var spoilerIsDisappearing = false
        private func updateSpoilersRevealed(animated: Bool = true) {
            let selectionRange = self.textView.selectedRange
            
            var revealed = false
            if let attributedText = self.textView.attributedText {
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
                self.spoilerIsDisappearing = true
                Queue.mainQueue().after(1.5, {
                    self.updateInternalSpoilersRevealed(false, animated: true)
                    self.spoilerIsDisappearing = false
                })
            }
        }
        
        private func updateInternalSpoilersRevealed(_ revealed: Bool, animated: Bool) {
            guard let component = self.component, self.spoilersRevealed == revealed else {
                return
            }
            
            self.textView.isScrollEnabled = false
            
            refreshChatTextInputAttributes(context: component.context, textView: self.textView, primaryTextColor: component.textColor, accentTextColor: component.accentColor, baseFontSize: component.fontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickersValue.keys), emojiViewProvider: self.emojiViewProvider, makeCollapsedQuoteAttachment: { text, attributes in
                return ChatInputTextCollapsedQuoteAttachmentImpl(text: text, attributes: attributes)
            })
            refreshChatTextInputTypingAttributes(self.textView, textColor: component.textColor, baseFontSize: component.fontSize)
            
            if self.textView.subviews.count > 1, animated {
                let containerView = self.textView.subviews[1]
                if let canvasView = containerView.subviews.first {
                    if let snapshotView = canvasView.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = canvasView.frame.offsetBy(dx: 0.0, dy: -self.textView.contentOffset.y)
                        self.insertSubview(snapshotView, at: 0)
                        canvasView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            self.textView.isScrollEnabled = false
                            snapshotView?.removeFromSuperview()
                            Queue.mainQueue().after(0.1) {
                                self.textView.isScrollEnabled = true
                            }
                        })
                    }
                }
            }
            Queue.mainQueue().after(0.1) {
                self.textView.isScrollEnabled = true
            }
            
            if let spoilerView = self.spoilerView {
                if animated {
                    let transition = ComponentTransition.easeInOut(duration: 0.3)
                    if revealed {
                        transition.setAlpha(view: spoilerView, alpha: 0.0)
                    } else {
                        transition.setAlpha(view: spoilerView, alpha: 1.0)
                    }
                } else {
                    spoilerView.alpha = revealed ? 0.0 : 1.0
                }
            }
        }
        
        func updateEntities() {
            guard let component = self.component else {
                return
            }

            var spoilerRects: [CGRect] = []
            var customEmojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute, CGFloat)] = []

            let textView = self.textView
            if let attributedText = textView.attributedText {
                let beginning = textView.beginningOfDocument
                attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                    if let _ = attributes[ChatTextInputAttributes.spoiler] {
                        func addSpoiler(startIndex: Int, endIndex: Int) {
                            if let start = textView.position(from: beginning, offset: startIndex), let end = textView.position(from: start, offset: endIndex - startIndex), let textRange = textView.textRange(from: start, to: end) {
                                let textRects = textView.selectionRects(for: textRange)
                                for textRect in textRects {
                                    if textRect.rect.width > 1.0 && textRect.rect.size.height > 1.0 {
                                        spoilerRects.append(textRect.rect.insetBy(dx: 1.0, dy: 1.0).offsetBy(dx: 0.0, dy: 1.0))
                                    }
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
                    
                    if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                        if let start = textView.position(from: beginning, offset: range.location), let end = textView.position(from: start, offset: range.length), let textRange = textView.textRange(from: start, to: end) {
                            var emojiFontSize = component.fontSize
                            if let font = attributes[.font] as? UIFont {
                                emojiFontSize = font.pointSize
                            }
                            let textRects = textView.selectionRects(for: textRange)
                            for textRect in textRects {
                                customEmojiRects.append((textRect.rect, value, emojiFontSize))
                                break
                            }
                        }
                    }
                })
            }
            
            if !spoilerRects.isEmpty {
                let spoilerView: InvisibleInkDustView
                if let current = self.spoilerView {
                    spoilerView = current
                } else {
                    spoilerView = InvisibleInkDustView(textNode: nil, enableAnimations: component.context.sharedContext.energyUsageSettings.fullTranslucency)
                    spoilerView.alpha = self.spoilersRevealed ? 0.0 : 1.0
                    spoilerView.isUserInteractionEnabled = false
                    self.textView.addSubview(spoilerView)
                    self.spoilerView = spoilerView
                }
                spoilerView.frame = CGRect(origin: CGPoint(), size: self.textView.contentSize)
                spoilerView.update(size: self.textView.contentSize, color: component.textColor, textColor: component.textColor, rects: spoilerRects, wordRects: spoilerRects)
            } else if let spoilerView = self.spoilerView {
                spoilerView.removeFromSuperview()
                self.spoilerView = nil
            }

            if !customEmojiRects.isEmpty {
                let customEmojiContainerView: CustomEmojiContainerView
                if let current = self.customEmojiContainerView {
                    customEmojiContainerView = current
                } else {
                    customEmojiContainerView = CustomEmojiContainerView(emojiViewProvider: { [weak self] emoji in
                        guard let strongSelf = self, let emojiViewProvider = strongSelf.emojiViewProvider else {
                            return nil
                        }
                        return emojiViewProvider(emoji)
                    })
                    customEmojiContainerView.isUserInteractionEnabled = false
                    self.textView.addSubview(customEmojiContainerView)
                    self.customEmojiContainerView = customEmojiContainerView
                }

                customEmojiContainerView.update(fontSize: component.fontSize, textColor: component.textColor, emojiRects: customEmojiRects)
                
                for (_, emojiView) in customEmojiContainerView.emojiLayers {
                    if let emojiView = emojiView as? EmojiTextAttachmentView {
                        if emojiView.isActive != component.enableInlineAnimations {
                            emojiView.isUnique = !component.enableInlineAnimations
                            emojiView.isActive = component.enableInlineAnimations
                            if !emojiView.isActive {
                                emojiView.resetToFirstFrame()
                            }
                        }
                    }
                }
            } else if let customEmojiContainerView = self.customEmojiContainerView {
                customEmojiContainerView.removeFromSuperview()
                self.customEmojiContainerView = nil
            }
        }
        
        public func updateEmojiSuggestion(transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
                        
            var hasTracking = false
            var hasTrackingView = false
            if let attributedText = self.textView.attributedText, self.textView.selectedRange.length == 0, self.textView.selectedRange.location > 0 {
                let selectedSubstring = attributedText.attributedSubstring(from: NSRange(location: 0, length: self.textView.selectedRange.location))
                if let lastCharacter = selectedSubstring.string.last, String(lastCharacter).isSingleEmoji {
                    let queryLength = (String(lastCharacter) as NSString).length
                    if selectedSubstring.attribute(ChatTextInputAttributes.customEmoji, at: selectedSubstring.length - queryLength, effectiveRange: nil) == nil {
                        let beginning = self.textView.beginningOfDocument
                        
                        let characterRange = NSRange(location: selectedSubstring.length - queryLength, length: queryLength)
                        
                        let start = self.textView.position(from: beginning, offset: selectedSubstring.length - queryLength)
                        let end = self.textView.position(from: beginning, offset: selectedSubstring.length)
                        
                        if let start = start, let end = end, let textRange = self.textView.textRange(from: start, to: end) {
                            let selectionRects = self.textView.selectionRects(for: textRange)
                            let emojiSuggestionPosition = EmojiSuggestion.Position(range: characterRange, value: String(lastCharacter))
                            
                            hasTracking = true
                            
                            if let trackingRect = selectionRects.first?.rect {
                                let trackingPosition = CGPoint(x: trackingRect.midX, y: trackingRect.minY)
                                if component.externalState.dismissedEmojiSuggestionPosition == emojiSuggestionPosition {
                                } else {
                                    hasTrackingView = true
                                    
                                    let emojiSuggestion: EmojiSuggestion
                                    if let current = component.externalState.currentEmojiSuggestion, current.position.value == emojiSuggestionPosition.value {
                                        emojiSuggestion = current
                                    } else {
                                        emojiSuggestion = EmojiSuggestion(localPosition: trackingPosition, position: emojiSuggestionPosition)
                                        component.externalState.currentEmojiSuggestion = emojiSuggestion
                                    }
                                    emojiSuggestion.localPosition = trackingPosition
                                    emojiSuggestion.position = emojiSuggestionPosition
                                    component.externalState.dismissedEmojiSuggestionPosition = nil
                                }
                            }
                        }
                    }
                } else {
                    if let index = selectedSubstring.string.range(of: ":", options: .backwards) {
                        let queryRange = index.upperBound ..< selectedSubstring.string.endIndex
                        let query = String(selectedSubstring.string[queryRange])
                        if !query.isEmpty && !query.contains(where: { c in
                            for s in c.unicodeScalars {
                                if CharacterSet.whitespacesAndNewlines.contains(s) {
                                    return true
                                }
                            }
                            return false
                        }) {
                            let beginning = self.textView.beginningOfDocument
                            let characterRange = NSRange(queryRange, in: selectedSubstring.string)
                            
                            let start = self.textView.position(from: beginning, offset: characterRange.location)
                            let end = self.textView.position(from: beginning, offset: characterRange.location + characterRange.length)
                            
                            if let start = start, let end = end, let textRange = self.textView.textRange(from: start, to: end) {
                                let selectionRects = self.textView.selectionRects(for: textRange)
                                let emojiSearchPosition = EmojiSearch.Position(range: characterRange, value: query)
                                
                                hasTracking = true
                                
                                if let trackingRect = selectionRects.first?.rect {
                                    let trackingPosition = CGPoint(x: trackingRect.midX, y: trackingRect.minY)
                                    if component.externalState.dismissedEmojiSearchPosition == emojiSearchPosition {
                                    } else {
                                        hasTrackingView = true
                                        
                                        let emojiSearch: EmojiSearch
                                        if let current = component.externalState.currentEmojiSearch, current.position.value == emojiSearchPosition.value {
                                            emojiSearch = current
                                        } else {
                                            emojiSearch = EmojiSearch(localPosition: trackingPosition, position: emojiSearchPosition)
                                            component.externalState.currentEmojiSearch = emojiSearch
                                        }
                                        emojiSearch.localPosition = trackingPosition
                                        emojiSearch.position = emojiSearchPosition
                                        component.externalState.dismissedEmojiSearchPosition = nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if !hasTracking {
                component.externalState.dismissedEmojiSuggestionPosition = nil
            }
            component.externalState.hasTrackingView = hasTrackingView
        }
        
        func rightmostPositionOfFirstLine() -> CGPoint? {
            let glyphRange = self.textView.layoutManager.glyphRange(for: self.textView.textContainer)
            
            if glyphRange.length == 0 { return nil }
                
            var lineRect = CGRect.zero
            var glyphIndexForStringStart = glyphRange.location
            var lineRange: NSRange = NSRange()
                
            repeat {
                lineRect = self.textView.layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndexForStringStart, effectiveRange: &lineRange)
                if NSMaxRange(lineRange) > glyphRange.length {
                    lineRange.length = glyphRange.length - lineRange.location
                }
                glyphIndexForStringStart = NSMaxRange(lineRange)
            } while glyphIndexForStringStart < NSMaxRange(glyphRange) && !NSLocationInRange(glyphRange.location, lineRange)
                
            let padding = self.textView.defaultTextContainerInset.left
            var rightmostX = lineRect.maxX + padding
            let rightmostY = lineRect.minY + self.textView.defaultTextContainerInset.top
            
            let nsString = (self.textView.text as NSString)
            let firstLineEndRange = NSMakeRange(lineRange.location + lineRange.length - 1, 1)
            if nsString.length > firstLineEndRange.location + firstLineEndRange.length {
                let lastChar = nsString.substring(with: firstLineEndRange)
                if lastChar == " " {
                    rightmostX -= 2.0
                }
            }
            
            return CGPoint(x: rightmostX, y: rightmostY)
        }
        
        func update(component: TextFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            if previousComponent?.theme !== component.theme {
                self.textView.keyboardAppearance = component.theme.overallDarkAppearance ? .dark : .light
                if #available(iOS 13.0, *) {
                    self.textView.overrideUserInterfaceStyle = component.theme.overallDarkAppearance ? .dark : .light
                }
            }
            
            if self.textView.returnKeyType != component.returnKeyType {
                self.textView.returnKeyType = component.returnKeyType
            }
            
            if let initialText = component.externalState.initialText {
                component.externalState.initialText = nil
                self.updateInputState { _ in
                    return TextFieldComponent.InputState(inputText: initialText)
                }
            } else if let resetText = component.resetText {
                self.updateInputState { _ in
                    return TextFieldComponent.InputState(inputText: resetText)
                }
            }
            
            if self.emojiViewProvider == nil {
                self.emojiViewProvider = { [weak self] emoji in
                    guard let component = self?.component else {
                        return UIView()
                    }
                    let pointSize = floor(24.0 * 1.3)
                    let emojiView = EmojiTextAttachmentView(context: component.context, userLocation: .other, emoji: emoji, file: emoji.file, cache: component.context.animationCache, renderer: component.context.animationRenderer, placeholderColor: UIColor.white.withAlphaComponent(0.12), pointSize: CGSize(width: pointSize, height: pointSize))
                    emojiView.updateTextColor(component.textColor)
                    return emojiView
                }
                
                self.chatInputTextNodeDidUpdateText()
            }
            
            let wasEditing = component.externalState.isEditing
            let isEditing = self.textView.isFirstResponder || component.assumeIsEditing
            
            var innerTextInsets = component.insets
            innerTextInsets.left = 0.0
            
            let textLeftInset = component.insets.left + 8.0
            
            if self.textView.defaultTextContainerInset != innerTextInsets {
                self.textView.defaultTextContainerInset = innerTextInsets
            }
            
            var availableSize = availableSize
            if !isEditing && component.isOneLineWhenUnfocused {
                availableSize.width += 32.0
            }
            
            let textHeight = self.textView.textHeightForWidth(availableSize.width - component.insets.left, rightInset: innerTextInsets.right)
            let size = CGSize(width: availableSize.width, height: min(textHeight, availableSize.height))
            
            let textFrame = CGRect(origin: CGPoint(x: textLeftInset, y: 0.0), size: CGSize(width: size.width - component.insets.left, height: size.height))
            
            var refreshScrolling = self.textView.bounds.size != textFrame.size
            if component.isOneLineWhenUnfocused && !isEditing && isEditing != wasEditing {
                refreshScrolling = true
            }
            
            self.textView.theme = ChatInputTextView.Theme(
                quote: ChatInputTextView.Theme.Quote(
                    background: component.textColor.withMultipliedAlpha(0.1),
                    foreground: component.textColor,
                    lineStyle: .solid(color: component.textColor),
                    codeBackground: component.textColor.withMultipliedAlpha(0.1),
                    codeForeground: component.textColor
                )
            )
            
            self.textView.frame = textFrame
            self.textView.updateLayout(size: textFrame.size)
            self.textView.panGestureRecognizer.isEnabled = isEditing
            
            if let placeholderValue = component.placeholder {
                var placeholderTransition = transition
                let placeholder: ComponentView<Empty>
                if let current = self.placeholder {
                    placeholder = current
                } else {
                    placeholderTransition = placeholderTransition.withAnimation(.none)
                    placeholder = ComponentView()
                    self.placeholder = placeholder
                }
                let placeholderSize = placeholder.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(placeholderValue)
                    )),
                    environment: {},
                    containerSize: textFrame.size
                )
                let placeholderFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: textFrame.minY + floor((textFrame.height - placeholderSize.height) * 0.5) - 1.0), size: placeholderSize)
                if let placeholderView = placeholder.view {
                    if placeholderView.superview == nil {
                        placeholderView.layer.anchorPoint = CGPoint()
                        self.insertSubview(placeholderView, belowSubview: self.textView)
                    }
                    placeholderTransition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                    placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                    
                    placeholderView.isHidden = self.textView.textStorage.length != 0
                }
            } else if let placeholder = self.placeholder {
                self.placeholder = nil
                placeholder.view?.removeFromSuperview()
            }
            
            self.updateEmojiSuggestion(transition: .immediate)
            
            if refreshScrolling {
                if isEditing {
                    if wasEditing || component.isOneLineWhenUnfocused {
                        self.textView.setContentOffset(CGPoint(x: 0.0, y: max(0.0, self.textView.contentSize.height - self.textView.bounds.height)), animated: false)
                    }
                } else {
                    self.textView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: true)
                }
            }
            
            component.externalState.hasText = self.textView.textStorage.length != 0
            component.externalState.isEditing = isEditing
            component.externalState.textLength = self.textView.textStorage.string.count
            component.externalState.text = NSAttributedString(attributedString: self.textView.textStorage)
            
            if let inputView = component.customInputView {
                if self.textView.inputView == nil {
                    self.textView.inputView = inputView
                    if self.textView.isFirstResponder {
                        // Avoid layout cycle
                        DispatchQueue.main.async { [weak self] in
                            self?.textView.reloadInputViews()
                        }
                    }
                }
            } else if component.hideKeyboard {
                if self.textView.inputView == nil {
                    self.textView.inputView = EmptyInputView()
                    if self.textView.isFirstResponder {
                        // Avoid layout cycle
                        DispatchQueue.main.async { [weak self] in
                            self?.textView.reloadInputViews()
                        }
                    }
                }
            } else {
                if self.textView.inputView != nil {
                    self.textView.inputView = nil
                    if self.textView.isFirstResponder {
                        // Avoid layout cycle
                        DispatchQueue.main.async { [weak self] in
                            self?.textView.reloadInputViews()
                        }
                    }
                }
            }
            
            if component.isOneLineWhenUnfocused, let position = self.rightmostPositionOfFirstLine() {
                let ellipsisSize = self.ellipsisView.update(
                    transition: transition,
                    component: AnyComponent(
                        Text(
                            text: "\u{2026}",
                            font: Font.regular(component.fontSize),
                            color: component.textColor
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                if let view = self.ellipsisView.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        view.isUserInteractionEnabled = false
                        self.textView.addSubview(view)
                    }
                    let ellipsisFrame = CGRect(origin: CGPoint(x: position.x - 8.0, y: position.y), size: ellipsisSize)
                    transition.setFrame(view: view, frame: ellipsisFrame)
                    
                    let hasMoreThanOneLine = ellipsisFrame.maxY < self.textView.contentSize.height - 12.0
                    
                    let ellipsisTransition: ComponentTransition
                    if isEditing {
                        ellipsisTransition = .easeInOut(duration: 0.2)
                    } else {
                        ellipsisTransition = .easeInOut(duration: 0.3)
                    }
                    ellipsisTransition.setAlpha(view: view, alpha: isEditing || !hasMoreThanOneLine ? 0.0 : 1.0)
                }
            } else {
                if let view = self.ellipsisView.view {
                    view.removeFromSuperview()
                }
            }
            
            self.updateEntities()
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

extension TextFieldComponent.InputState {
    public func insertText(_ text: NSAttributedString) -> TextFieldComponent.InputState {
        let inputText = NSMutableAttributedString(attributedString: self.inputText)
        let range = self.selectionRange
        
        inputText.replaceCharacters(in: NSMakeRange(range.lowerBound, range.count), with: text)
        
        let selectionPosition = range.lowerBound + (text.string as NSString).length
        return TextFieldComponent.InputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition)
    }
    
    public func addFormattingAttribute(attribute: NSAttributedString.Key, value: Any? = nil) -> TextFieldComponent.InputState {
        if !self.selectionRange.isEmpty {
            let nsRange = NSRange(location: self.selectionRange.lowerBound, length: self.selectionRange.count)
            var addAttribute = true
            var attributesToRemove: [NSAttributedString.Key] = []
            self.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, _ in
                for (key, _) in attributes {
                    if key == attribute {
                        addAttribute = false
                        attributesToRemove.append(key)
                    }
                }
            }
            
            var selectionRange = self.selectionRange
            
            let result = NSMutableAttributedString(attributedString: self.inputText)
            for attribute in attributesToRemove {
                if attribute == ChatTextInputAttributes.block {
                    var removeRange = nsRange
                    
                    var selectionIndex = nsRange.upperBound
                    if nsRange.upperBound != result.length && (result.string as NSString).character(at: nsRange.upperBound) != 0x0a {
                        result.insert(NSAttributedString(string: "\n"), at: nsRange.upperBound)
                        selectionIndex += 1
                        removeRange.length += 1
                    }
                    if nsRange.lowerBound != 0 && (result.string as NSString).character(at: nsRange.lowerBound - 1) != 0x0a {
                        result.insert(NSAttributedString(string: "\n"), at: nsRange.lowerBound)
                        selectionIndex += 1
                        removeRange.location += 1
                    } else if nsRange.lowerBound != 0 {
                        removeRange.location -= 1
                        removeRange.length += 1
                    }
                    
                    if removeRange.lowerBound > result.length {
                        removeRange = NSRange(location: result.length, length: 0)
                    } else if removeRange.upperBound > result.length {
                        removeRange = NSRange(location: removeRange.lowerBound, length: result.length - removeRange.lowerBound)
                    }
                    result.removeAttribute(attribute, range: removeRange)
                    
                    if selectionRange.lowerBound > result.length {
                        selectionRange = result.length ..< result.length
                    } else if selectionRange.upperBound > result.length {
                        selectionRange = selectionRange.lowerBound ..< result.length
                    }
                    
                    // Prevent merge back
                    result.enumerateAttributes(in: NSRange(location: selectionIndex, length: result.length - selectionIndex), options: .longestEffectiveRangeNotRequired) { attributes, range, _ in
                        for (key, value) in attributes {
                            if let value = value as? ChatTextInputTextQuoteAttribute {
                                result.removeAttribute(key, range: range)
                                result.addAttribute(key, value: ChatTextInputTextQuoteAttribute(kind: value.kind, isCollapsed: value.isCollapsed), range: range)
                            }
                        }
                    }
                    
                    selectionRange = selectionIndex ..< selectionIndex
                } else {
                    result.removeAttribute(attribute, range: nsRange)
                }
            }
            
            if addAttribute {
                if attribute == ChatTextInputAttributes.block {
                    result.addAttribute(attribute, value: value ?? ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false), range: nsRange)
                    var selectionIndex = nsRange.upperBound
                    if nsRange.upperBound != result.length && (result.string as NSString).character(at: nsRange.upperBound) != 0x0a {
                        result.insert(NSAttributedString(string: "\n"), at: nsRange.upperBound)
                        selectionIndex += 1
                    }
                    if nsRange.lowerBound != 0 && (result.string as NSString).character(at: nsRange.lowerBound - 1) != 0x0a {
                        result.insert(NSAttributedString(string: "\n"), at: nsRange.lowerBound)
                        selectionIndex += 1
                    }
                    selectionRange = selectionIndex ..< selectionIndex
                } else {
                    result.addAttribute(attribute, value: true as Bool, range: nsRange)
                }
            }
            if selectionRange.lowerBound > result.length {
                selectionRange = result.length ..< result.length
            } else if selectionRange.upperBound > result.length {
                selectionRange = selectionRange.lowerBound ..< result.length
            }
            
            return TextFieldComponent.InputState(inputText: result, selectionRange: selectionRange)
        } else {
            return self
        }
    }

    public func clearFormattingAttributes() -> TextFieldComponent.InputState {
        if !self.selectionRange.isEmpty {
            let nsRange = NSRange(location: self.selectionRange.lowerBound, length: self.selectionRange.count)
            var attributesToRemove: [NSAttributedString.Key] = []
            self.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
                for (key, _) in attributes {
                    attributesToRemove.append(key)
                }
            }
            
            let result = NSMutableAttributedString(attributedString: self.inputText)
            for attribute in attributesToRemove {
                result.removeAttribute(attribute, range: nsRange)
            }
            return TextFieldComponent.InputState(inputText: result, selectionRange: self.selectionRange)
        } else {
            return self
        }
    }

    public func addLinkAttribute(selectionRange: Range<Int>, url: String) -> TextFieldComponent.InputState {
        if !selectionRange.isEmpty {
            let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
            var linkRange = nsRange
            var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
            self.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
                for (key, _) in attributes {
                    if key == ChatTextInputAttributes.textUrl {
                        attributesToRemove.append((key, range))
                        linkRange = linkRange.union(range)
                    } else {
                        attributesToRemove.append((key, nsRange))
                    }
                }
            }

            let result = NSMutableAttributedString(attributedString: self.inputText)
            for (attribute, range) in attributesToRemove {
                result.removeAttribute(attribute, range: range)
            }
            result.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: url), range: nsRange)
            return TextFieldComponent.InputState(inputText: result, selectionRange: selectionRange)
        } else {
            return self
        }
    }
    
    public func removeLinkAttribute(selectionRange: Range<Int>) -> TextFieldComponent.InputState {
        if !selectionRange.isEmpty {
            let nsRange = NSRange(location: selectionRange.lowerBound, length: selectionRange.count)
            var attributesToRemove: [(NSAttributedString.Key, NSRange)] = []
            self.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
                for (key, _) in attributes {
                    if key == ChatTextInputAttributes.textUrl {
                        attributesToRemove.append((key, range))
                    } else {
                        attributesToRemove.append((key, nsRange))
                    }
                }
            }

            let result = NSMutableAttributedString(attributedString: self.inputText)
            for (attribute, range) in attributesToRemove {
                result.removeAttribute(attribute, range: range)
            }
            return TextFieldComponent.InputState(inputText: result, selectionRange: selectionRange)
        } else {
            return self
        }
    }
}
