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

public final class EmptyInputView: UIView, UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool {
        return true
    }
}

public final class TextFieldComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var isEditing: Bool = false
        public fileprivate(set) var hasText: Bool = false
        public fileprivate(set) var textLength: Int = 0
        public var initialText: NSAttributedString?
        
        public var hasTrackingView = false
        
        public var currentEmojiSuggestion: EmojiSuggestion?
        public var dismissedEmojiSuggestionPosition: EmojiSuggestion.Position?
        
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
    
    public enum PasteData {
        case sticker(image: UIImage, isMemoji: Bool)
        case images([UIImage])
        case video(Data)
        case gif(Data)
        case text
    }
    
    
    public final class AnimationHint {
        public enum Kind {
            case textChanged
            case textFocusChanged
        }
        
        public let kind: Kind
        
        public init(kind: Kind) {
            self.kind = kind
        }
    }
    
    public enum FormatMenuAvailability: Equatable {
        case available
        case locked
        case none
    }
    
    public let context: AccountContext
    public let strings: PresentationStrings
    public let externalState: ExternalState
    public let fontSize: CGFloat
    public let textColor: UIColor
    public let insets: UIEdgeInsets
    public let hideKeyboard: Bool
    public let customInputView: UIView?
    public let resetText: NSAttributedString?
    public let isOneLineWhenUnfocused: Bool
    public let formatMenuAvailability: FormatMenuAvailability
    public let lockedFormatAction: () -> Void
    public let present: (ViewController) -> Void
    public let paste: (PasteData) -> Void
    
    public init(
        context: AccountContext,
        strings: PresentationStrings,
        externalState: ExternalState,
        fontSize: CGFloat,
        textColor: UIColor,
        insets: UIEdgeInsets,
        hideKeyboard: Bool,
        customInputView: UIView?,
        resetText: NSAttributedString?,
        isOneLineWhenUnfocused: Bool,
        formatMenuAvailability: FormatMenuAvailability,
        lockedFormatAction: @escaping () -> Void,
        present: @escaping (ViewController) -> Void,
        paste: @escaping (PasteData) -> Void
    ) {
        self.context = context
        self.strings = strings
        self.externalState = externalState
        self.fontSize = fontSize
        self.textColor = textColor
        self.insets = insets
        self.hideKeyboard = hideKeyboard
        self.customInputView = customInputView
        self.resetText = resetText
        self.isOneLineWhenUnfocused = isOneLineWhenUnfocused
        self.formatMenuAvailability = formatMenuAvailability
        self.lockedFormatAction = lockedFormatAction
        self.present = present
        self.paste = paste
    }
    
    public static func ==(lhs: TextFieldComponent, rhs: TextFieldComponent) -> Bool {
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
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.hideKeyboard != rhs.hideKeyboard {
            return false
        }
        if lhs.customInputView !== rhs.customInputView {
            return false
        }
        if lhs.resetText != rhs.resetText {
            return false
        }
        if lhs.isOneLineWhenUnfocused != rhs.isOneLineWhenUnfocused {
            return false
        }
        if lhs.formatMenuAvailability != rhs.formatMenuAvailability {
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
    
    final class TextView: UITextView {
        var onPaste: () -> Bool = { return true }
        
        override func paste(_ sender: Any?) {
            if self.onPaste() {
                super.paste(sender)
            }
        }
        
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            if action == #selector(self.paste(_:)) {
                return true
            }
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    public final class View: UIView, UITextViewDelegate, UIScrollViewDelegate {
        private let textContainer: NSTextContainer
        private let textStorage: NSTextStorage
        private let layoutManager: NSLayoutManager
        private let textView: TextView
        
        private var spoilerView: InvisibleInkDustView?
        private var customEmojiContainerView: CustomEmojiContainerView?
        private var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
                
        private let ellipsisView = ComponentView<Empty>()
        
        private var inputState: InputState {
            let selectionRange: Range<Int> = self.textView.selectedRange.location ..< (self.textView.selectedRange.location + self.textView.selectedRange.length)
            return InputState(inputText: stateAttributedStringForText(self.textView.attributedText ?? NSAttributedString()), selectionRange: selectionRange)
        }
        
        private var component: TextFieldComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.textContainer = NSTextContainer(size: CGSize())
            self.textContainer.widthTracksTextView = false
            self.textContainer.heightTracksTextView = false
            self.textContainer.lineBreakMode = .byWordWrapping
            self.textContainer.lineFragmentPadding = 8.0
            
            self.textStorage = NSTextStorage()

            self.layoutManager = NSLayoutManager()
            self.layoutManager.allowsNonContiguousLayout = false
            self.layoutManager.addTextContainer(self.textContainer)
            self.textStorage.addLayoutManager(self.layoutManager)
            
            self.textView = TextView(frame: CGRect(), textContainer: self.textContainer)
            self.textView.translatesAutoresizingMaskIntoConstraints = false
            self.textView.backgroundColor = nil
            self.textView.layer.isOpaque = false
            self.textView.keyboardAppearance = .dark
            self.textView.indicatorStyle = .white
            self.textView.scrollIndicatorInsets = UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0)
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            
            self.textView.delegate = self
            self.addSubview(self.textView)
            
            self.textContainer.widthTracksTextView = false
            self.textContainer.heightTracksTextView = false
            
            if #available(iOS 13.0, *) {
                self.textView.overrideUserInterfaceStyle = .dark
            }
            
            self.textView.typingAttributes = [
                NSAttributedString.Key.font: Font.regular(17.0),
                NSAttributedString.Key.foregroundColor: UIColor.white
            ]
            
            self.textView.onPaste = { [weak self] in
                return self?.onPaste() ?? false
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
            
            self.textView.attributedText = textAttributedStringForStateText(inputState.inputText, fontSize: component.fontSize, textColor: component.textColor, accentTextColor: component.textColor, writingDirection: nil, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickers.keys), emojiViewProvider: self.emojiViewProvider)
            self.textView.selectedRange = NSMakeRange(inputState.selectionRange.lowerBound, inputState.selectionRange.count)
            
            refreshChatTextInputAttributes(textView: self.textView, primaryTextColor: component.textColor, accentTextColor: component.textColor, baseFontSize: component.fontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickers.keys), emojiViewProvider: self.emojiViewProvider)
            
            self.updateEntities()
        }
        
        public func hasFirstResponder() -> Bool {
            return self.textView.isFirstResponder
        }
        
        public func insertText(_ text: NSAttributedString) {
            self.updateInputState { state in
                return state.insertText(text)
            }
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
        }
        
        public func deleteBackward() {
            self.textView.deleteBackward()
        }
        
        public func updateText(_ text: NSAttributedString, selectionRange: Range<Int>) {
            self.updateInputState { _ in
                return TextFieldComponent.InputState(inputText: text, selectionRange: selectionRange)
            }
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
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
                self.updateInputState { current in
                    if let inputText = current.inputText.mutableCopy() as? NSMutableAttributedString {
                        inputText.replaceCharacters(in: NSMakeRange(current.selectionRange.lowerBound, current.selectionRange.count), with: attributedString)
                        let updatedRange = current.selectionRange.lowerBound + attributedString.length
                        return InputState(inputText: inputText, selectionRange: updatedRange ..< updatedRange)
                    } else {
                        return InputState(inputText: attributedString)
                    }
                }
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
                component.paste(.text)
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
                
                if isPNG && images.count == 1, let image = images.first, let cgImage = image.cgImage {
                    let maxSide = max(image.size.width, image.size.height)
                    if maxSide.isZero {
                        return false
                    }
                    let aspectRatio = min(image.size.width, image.size.height) / maxSide
                    if isMemoji || (imageHasTransparency(cgImage) && aspectRatio > 0.2) {
                        component.paste(.sticker(image: image, isMemoji: isMemoji))
                        return false
                    }
                }
                
                if !images.isEmpty {
                    component.paste(.images(images))
                    return false
                }
            }
            
            component.paste(.text)
            return true
        }
        
        public func textViewDidChange(_ textView: UITextView) {
            guard let component = self.component else {
                return
            }
            refreshChatTextInputAttributes(textView: self.textView, primaryTextColor: component.textColor, accentTextColor: component.textColor, baseFontSize: component.fontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickers.keys), emojiViewProvider: self.emojiViewProvider)
            refreshChatTextInputTypingAttributes(self.textView, textColor: component.textColor, baseFontSize: component.fontSize)
            
            if self.spoilerIsDisappearing {
                self.spoilerIsDisappearing = false
                self.updateInternalSpoilersRevealed(false, animated: false)
            }
            
            self.updateEntities()
            
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
        }
        
        public func textViewDidChangeSelection(_ textView: UITextView) {
            guard let _ = self.component else {
                return
            }
            
            self.updateSpoilersRevealed()
            self.updateEmojiSuggestion(transition: .immediate)
        }
        
        public func textViewDidBeginEditing(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.5, curve: .spring)).withUserData(AnimationHint(kind: .textFocusChanged)))
        }
        
        public func textViewDidEndEditing(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.5, curve: .spring)).withUserData(AnimationHint(kind: .textFocusChanged)))
        }
                
        @available(iOS 16.0, *)
        public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
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
            guard let component = self.component, !textView.attributedText.string.isEmpty && textView.selectedRange.length > 0 else {
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
                        
            var actions: [UIAction] = [
                UIAction(title: strings.TextFormat_Bold, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.bold)
                    }
                },
                UIAction(title: strings.TextFormat_Italic, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.italic)
                    }
                },
                UIAction(title: strings.TextFormat_Monospace, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.monospace)
                    }
                },
                UIAction(title: strings.TextFormat_Link, image: nil) { [weak self] action in
                    if let self {
                        self.openLinkEditing()
                    }
                },
                UIAction(title: strings.TextFormat_Strikethrough, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.strikethrough)
                    }
                },
                UIAction(title: strings.TextFormat_Underline, image: nil) { [weak self] action in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.underline)
                    }
                }
            ]
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
            
            var updatedActions = suggestedActions
            let formatMenu = UIMenu(title: strings.TextFormat_Format, image: nil, children: actions)
            updatedActions.insert(formatMenu, at: 1)
            
            return UIMenu(children: updatedActions)
        }
        
        private func toggleAttribute(key: NSAttributedString.Key) {
            self.updateInputState { state in
                return state.addFormattingAttribute(attribute: key)
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
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
            let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (presentationData, .single(presentationData))
            let controller = chatTextLinkEditController(sharedContext: component.context.sharedContext, updatedPresentationData: updatedPresentationData, account: component.context.account, text: text.string, link: link, apply: { [weak self] link in
                if let self {
                    if let link = link {
                        self.updateInputState { state in
                            return state.addLinkAttribute(selectionRange: selectionRange, url: link)
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
            return self.inputState.inputText
        }
        
        public func setAttributedText(_ string: NSAttributedString, updateState: Bool) {
            self.updateInputState { _ in
                return TextFieldComponent.InputState(inputText: string, selectionRange: string.length ..< string.length)
            }
            if updateState {
                self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
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
            
            refreshChatTextInputAttributes(textView: self.textView, primaryTextColor: component.textColor, accentTextColor: component.textColor, baseFontSize: component.fontSize, spoilersRevealed: self.spoilersRevealed, availableEmojis: Set(component.context.animatedEmojiStickers.keys), emojiViewProvider: self.emojiViewProvider)
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
                    let transition = Transition.easeInOut(duration: 0.3)
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
            var customEmojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute)] = []

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
                            let textRects = textView.selectionRects(for: textRange)
                            for textRect in textRects {
                                customEmojiRects.append((textRect.rect, value))
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
            } else if let customEmojiContainerView = self.customEmojiContainerView {
                customEmojiContainerView.removeFromSuperview()
                self.customEmojiContainerView = nil
            }
        }
        
        public func updateEmojiSuggestion(transition: Transition) {
            guard let component = self.component else {
                return
            }
                        
            var hasTracking = false
            var hasTrackingView = false
            if self.textView.selectedRange.length == 0 && self.textView.selectedRange.location > 0 {
                let selectedSubstring = self.textView.attributedText.attributedSubstring(from: NSRange(location: 0, length: self.textView.selectedRange.location))
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
                }
            }
            if !hasTracking {
                component.externalState.dismissedEmojiSuggestionPosition = nil
            }
            component.externalState.hasTrackingView = hasTrackingView
        }
        
        func rightmostPositionOfFirstLine() -> CGPoint? {
            let glyphRange = self.layoutManager.glyphRange(for: self.textContainer)
            
            if glyphRange.length == 0 { return nil }
                
            var lineRect = CGRect.zero
            var glyphIndexForStringStart = glyphRange.location
            var lineRange: NSRange = NSRange()
                
            repeat {
                lineRect = self.layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndexForStringStart, effectiveRange: &lineRange)
                if NSMaxRange(lineRange) > glyphRange.length {
                    lineRange.length = glyphRange.length - lineRange.location
                }
                glyphIndexForStringStart = NSMaxRange(lineRange)
            } while glyphIndexForStringStart < NSMaxRange(glyphRange) && !NSLocationInRange(glyphRange.location, lineRange)
                
            let padding = self.textView.textContainerInset.left
            var rightmostX = lineRect.maxX + padding
            let rightmostY = lineRect.minY + self.textView.textContainerInset.top
            
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
        
        func update(component: TextFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
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
                    return EmojiTextAttachmentView(context: component.context, userLocation: .other, emoji: emoji, file: emoji.file, cache: component.context.animationCache, renderer: component.context.animationRenderer, placeholderColor: UIColor.white.withAlphaComponent(0.12), pointSize: CGSize(width: pointSize, height: pointSize))
                }
            }
            
            if self.textView.textContainerInset != component.insets {
                self.textView.textContainerInset = component.insets
            }
            self.textContainer.size = CGSize(width: availableSize.width - self.textView.textContainerInset.left - self.textView.textContainerInset.right, height: 10000000.0)
            self.layoutManager.ensureLayout(for: self.textContainer)
            
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: self.textStorage.length), in: self.textContainer)
            let size = CGSize(width: availableSize.width, height: min(availableSize.height, ceil(boundingRect.height) + self.textView.textContainerInset.top + self.textView.textContainerInset.bottom))
            
            let wasEditing = component.externalState.isEditing
            let isEditing = self.textView.isFirstResponder
            
            var refreshScrolling = self.textView.bounds.size != size
            if component.isOneLineWhenUnfocused && !isEditing && isEditing != wasEditing {
                refreshScrolling = true
            }
            self.textView.frame = CGRect(origin: CGPoint(), size: size)
            self.textView.panGestureRecognizer.isEnabled = isEditing
            
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
            
            component.externalState.hasText = self.textStorage.length != 0
            component.externalState.isEditing = isEditing
            component.externalState.textLength = self.textStorage.string.count
            
            if let inputView = component.customInputView {
                if self.textView.inputView == nil {
                    self.textView.inputView = inputView
                    if self.textView.isFirstResponder {
                        self.textView.reloadInputViews()
                    }
                }
            } else if component.hideKeyboard {
                if self.textView.inputView == nil {
                    self.textView.inputView = EmptyInputView()
                    if self.textView.isFirstResponder {
                        self.textView.reloadInputViews()
                    }
                }
            } else {
                if self.textView.inputView != nil {
                    self.textView.inputView = nil
                    if self.textView.isFirstResponder {
                        self.textView.reloadInputViews()
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
                        self.textView.addSubview(view)
                    }
                    let ellipsisFrame = CGRect(origin: CGPoint(x: position.x - 8.0, y: position.y), size: ellipsisSize)
                    transition.setFrame(view: view, frame: ellipsisFrame)
                    
                    let hasMoreThanOneLine = ellipsisFrame.maxY < self.textView.contentSize.height - 12.0
                    
                    let ellipsisTransition: Transition
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
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
    
    public func addFormattingAttribute(attribute: NSAttributedString.Key) -> TextFieldComponent.InputState {
        if !self.selectionRange.isEmpty {
            let nsRange = NSRange(location: self.selectionRange.lowerBound, length: self.selectionRange.count)
            var addAttribute = true
            var attributesToRemove: [NSAttributedString.Key] = []
            self.inputText.enumerateAttributes(in: nsRange, options: .longestEffectiveRangeNotRequired) { attributes, range, stop in
                for (key, _) in attributes {
                    if key == attribute && range == nsRange {
                        addAttribute = false
                        attributesToRemove.append(key)
                    }
                }
            }
            
            let result = NSMutableAttributedString(attributedString: self.inputText)
            for attribute in attributesToRemove {
                result.removeAttribute(attribute, range: nsRange)
            }
            if addAttribute {
                result.addAttribute(attribute, value: true as Bool, range: nsRange)
            }
            return TextFieldComponent.InputState(inputText: result, selectionRange: self.selectionRange)
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
}
