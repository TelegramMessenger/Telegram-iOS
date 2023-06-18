import Foundation
import UIKit
import Display
import ComponentFlow
import TextFormat
import TelegramPresentationData

public final class TextFieldComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var isEditing: Bool = false
        public fileprivate(set) var hasText: Bool = false
        
        public init() {
        }
    }
    
    public final class AnimationHint {
        public enum Kind {
            case textChanged
            case textFocusChanged
        }
        
        public let kind: Kind
        
        fileprivate init(kind: Kind) {
            self.kind = kind
        }
    }
    
    public let strings: PresentationStrings
    public let externalState: ExternalState
    public let placeholder: String
    
    public init(
        strings: PresentationStrings,
        externalState: ExternalState,
        placeholder: String
    ) {
        self.strings = strings
        self.externalState = externalState
        self.placeholder = placeholder
    }
    
    public static func ==(lhs: TextFieldComponent, rhs: TextFieldComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        return true
    }
    
    public struct InputState {
        public var inputText: NSAttributedString
        public var selectionRange: Range<Int>
    }
    
    public final class View: UIView, UITextViewDelegate, UIScrollViewDelegate {
        private let placeholder = ComponentView<Empty>()
        
        private let textContainer: NSTextContainer
        private let textStorage: NSTextStorage
        private let layoutManager: NSLayoutManager
        private let textView: UITextView
        
        private var inputState = InputState(inputText: NSAttributedString(), selectionRange: 0 ..< 0)
        
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
            
            self.textView = UITextView(frame: CGRect(), textContainer: self.textContainer)
            self.textView.translatesAutoresizingMaskIntoConstraints = false
            self.textView.textContainerInset = UIEdgeInsets(top: 9.0, left: 8.0, bottom: 10.0, right: 8.0)
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
            
            self.textView.typingAttributes = [
                NSAttributedString.Key.font: Font.regular(17.0),
                NSAttributedString.Key.foregroundColor: UIColor.white
            ]
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func textViewDidChange(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
        }
        
        public func textViewDidBeginEditing(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textFocusChanged)))
        }
        
        public func textViewDidEndEditing(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textFocusChanged)))
        }
        
        @available(iOS 16.0, *)
        public func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let component = self.component, !textView.attributedText.string.isEmpty && textView.selectedRange.length > 0 else {
                return UIMenu(children: suggestedActions)
            }
            
            let strings = component.strings
            var actions: [UIAction] = [
                UIAction(title: strings.TextFormat_Bold, image: nil) { [weak self] (action) in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.bold)
                    }
                },
                UIAction(title: strings.TextFormat_Italic, image: nil) { [weak self] (action) in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.italic)
                    }
                },
                UIAction(title: strings.TextFormat_Monospace, image: nil) { [weak self] (action) in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.monospace)
                    }
                },
                UIAction(title: strings.TextFormat_Link, image: nil) { [weak self] (action) in
                    if let self {
                        let _ = self
                    }
                },
                UIAction(title: strings.TextFormat_Strikethrough, image: nil) { [weak self] (action) in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.strikethrough)
                    }
                },
                UIAction(title: strings.TextFormat_Underline, image: nil) { [weak self] (action) in
                    if let self {
                        self.toggleAttribute(key: ChatTextInputAttributes.underline)
                    }
                }
            ]
            actions.append(UIAction(title: strings.TextFormat_Spoiler, image: nil) { [weak self] (action) in
                if let self {
                    self.toggleAttribute(key: ChatTextInputAttributes.spoiler)
                }
            })
            
            var updatedActions = suggestedActions
            let formatMenu = UIMenu(title: strings.TextFormat_Format, image: nil, children: actions)
            updatedActions.insert(formatMenu, at: 3)
            
            return UIMenu(children: updatedActions)
        }
        
        private func toggleAttribute(key: NSAttributedString.Key) {
            
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            //print("didScroll \(scrollView.bounds)")
        }
        
        public func getAttributedText() -> NSAttributedString {
            Keyboard.applyAutocorrection(textView: self.textView)
            return self.inputState.inputText
        }
        
        public func setAttributedText(_ string: NSAttributedString) {
            self.textView.text = string.string
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
        }
        
        public func activateInput() {
            self.textView.becomeFirstResponder()
        }
        
        func updateEntities() {
//            var spoilerRects: [CGRect] = []
//            var customEmojiRects: [CGRect: ChatTextInputTextCustomEmojiAttribute] = []
//
//            if !spoilerRects.isEmpty {
//                let dustNode: InvisibleInkDustNode
//                if let current = self.dustNode {
//                    dustNode = current
//                } else {
//                    dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: self.context?.sharedContext.energyUsageSettings.fullTranslucency ?? true)
//                    dustNode.alpha = self.spoilersRevealed ? 0.0 : 1.0
//                    dustNode.isUserInteractionEnabled = false
//                    textInputNode.textView.addSubview(dustNode.view)
//                    self.dustNode = dustNode
//                }
//                dustNode.frame = CGRect(origin: CGPoint(), size: textInputNode.textView.contentSize)
//                dustNode.update(size: textInputNode.textView.contentSize, color: textColor, textColor: textColor, rects: rects, wordRects: rects)
//            } else if let dustNode = self.dustNode {
//                dustNode.removeFromSupernode()
//                self.dustNode = nil
//            }
//
//            if !customEmojiRects.isEmpty {
//                let customEmojiContainerView: CustomEmojiContainerView
//                if let current = self.customEmojiContainerView {
//                    customEmojiContainerView = current
//                } else {
//                    customEmojiContainerView = CustomEmojiContainerView(emojiViewProvider: { [weak self] emoji in
//                        guard let strongSelf = self, let emojiViewProvider = strongSelf.emojiViewProvider else {
//                            return nil
//                        }
//                        return emojiViewProvider(emoji)
//                    })
//                    customEmojiContainerView.isUserInteractionEnabled = false
//                    textInputNode.textView.addSubview(customEmojiContainerView)
//                    self.customEmojiContainerView = customEmojiContainerView
//                }
//
//                customEmojiContainerView.update(fontSize: fontSize, textColor: textColor, emojiRects: customEmojiRects)
//            } else if let customEmojiContainerView = self.customEmojiContainerView {
//                customEmojiContainerView.removeFromSuperview()
//                self.customEmojiContainerView = nil
//            }
        }
        
        func update(component: TextFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            self.textContainer.size = CGSize(width: availableSize.width - self.textView.textContainerInset.left - self.textView.textContainerInset.right, height: 10000000.0)
            self.layoutManager.ensureLayout(for: self.textContainer)
            
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: self.textStorage.length), in: self.textContainer)
            let size = CGSize(width: availableSize.width, height: min(200.0, ceil(boundingRect.height) + self.textView.textContainerInset.top + self.textView.textContainerInset.bottom))
            
            let refreshScrolling = self.textView.bounds.size != size
            self.textView.frame = CGRect(origin: CGPoint(), size: size)
            
            if refreshScrolling {
                self.textView.setContentOffset(CGPoint(x: 0.0, y: max(0.0, self.textView.contentSize.height - self.textView.bounds.height)), animated: false)
            }
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.placeholder, font: Font.regular(17.0), color: UIColor(white: 1.0, alpha: 0.25))),
                environment: {},
                containerSize: availableSize
            )
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.layer.anchorPoint = CGPoint()
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, belowSubview: self.textView)
                }
                
                let placeholderFrame = CGRect(origin: CGPoint(x: self.textView.textContainerInset.left + 5.0, y: self.textView.textContainerInset.top), size: placeholderSize)
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                
                placeholderView.isHidden = self.textStorage.length != 0
            }
            
            component.externalState.hasText = self.textStorage.length != 0
            component.externalState.isEditing = self.textView.isFirstResponder
            
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
