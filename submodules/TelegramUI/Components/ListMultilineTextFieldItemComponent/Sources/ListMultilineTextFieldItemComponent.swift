import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import MultilineTextComponent
import ListSectionComponent
import TextFieldComponent
import AccountContext

public final class ListMultilineTextFieldItemComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var hasText: Bool = false
        
        public init() {
        }
    }
    
    public final class ResetText: Equatable {
        public let value: String
        
        public init(value: String) {
            self.value = value
        }
        
        public static func ==(lhs: ResetText, rhs: ResetText) -> Bool {
            return lhs === rhs
        }
    }
    
    public let externalState: ExternalState?
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let initialText: String
    public let resetText: ResetText?
    public let placeholder: String
    public let autocapitalizationType: UITextAutocapitalizationType
    public let autocorrectionType: UITextAutocorrectionType
    public let characterLimit: Int?
    public let allowEmptyLines: Bool
    public let updated: ((String) -> Void)?
    public let textUpdateTransition: Transition
    public let tag: AnyObject?
    
    public init(
        externalState: ExternalState? = nil,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        initialText: String,
        resetText: ResetText? = nil,
        placeholder: String,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default,
        characterLimit: Int? = nil,
        allowEmptyLines: Bool = true,
        updated: ((String) -> Void)?,
        textUpdateTransition: Transition = .immediate,
        tag: AnyObject? = nil
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.initialText = initialText
        self.resetText = resetText
        self.placeholder = placeholder
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.characterLimit = characterLimit
        self.allowEmptyLines = allowEmptyLines
        self.updated = updated
        self.textUpdateTransition = textUpdateTransition
        self.tag = tag
    }
    
    public static func ==(lhs: ListMultilineTextFieldItemComponent, rhs: ListMultilineTextFieldItemComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.initialText != rhs.initialText {
            return false
        }
        if lhs.resetText != rhs.resetText {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.autocapitalizationType != rhs.autocapitalizationType {
            return false
        }
        if lhs.autocorrectionType != rhs.autocorrectionType {
            return false
        }
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.allowEmptyLines != rhs.allowEmptyLines {
            return false
        }
        if (lhs.updated == nil) != (rhs.updated == nil) {
            return false
        }
        return true
    }
    
    private final class TextField: UITextField {
        var sideInset: CGFloat = 0.0
        
        override func textRect(forBounds bounds: CGRect) -> CGRect {
            return CGRect(origin: CGPoint(x: self.sideInset, y: 0.0), size: CGSize(width: bounds.width - self.sideInset * 2.0, height: bounds.height))
        }
        
        override func editingRect(forBounds bounds: CGRect) -> CGRect {
            return CGRect(origin: CGPoint(x: self.sideInset, y: 0.0), size: CGSize(width: bounds.width - self.sideInset * 2.0, height: bounds.height))
        }
    }
    
    public final class View: UIView, UITextFieldDelegate, ListSectionComponent.ChildView, ComponentTaggedView {
        private let textField = ComponentView<Empty>()
        private let textFieldExternalState = TextFieldComponent.ExternalState()
        
        private let placeholder = ComponentView<Empty>()
        
        private var component: ListMultilineTextFieldItemComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        public var currentText: String {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.inputState.inputText.string
            } else {
                return ""
            }
        }
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        
        public override init(frame: CGRect) {
            super.init(frame: CGRect())
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            return true
        }
        
        @objc private func textDidChange() {
            if !self.isUpdating {
                self.state?.updated(transition: self.component?.textUpdateTransition ?? .immediate)
            }
            self.component?.updated?(self.currentText)
        }
        
        public func setText(text: String, updateState: Bool) {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                //TODO
                let _ = textFieldView
            }
            
            if updateState {
                self.component?.updated?(self.currentText)
            } else {
                self.state?.updated(transition: .immediate, isLocal: true)
            }
        }
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        func update(component: ListMultilineTextFieldItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let verticalInset: CGFloat = 12.0
            let sideInset: CGFloat = 16.0
            
            let textFieldSize = self.textField.update(
                transition: transition,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    strings: component.strings,
                    externalState: self.textFieldExternalState,
                    fontSize: 17.0,
                    textColor: component.theme.list.itemPrimaryTextColor,
                    insets: UIEdgeInsets(top: verticalInset, left: sideInset - 8.0, bottom: verticalInset, right: sideInset - 8.0),
                    hideKeyboard: false,
                    customInputView: nil,
                    resetText: component.resetText.flatMap { resetText in
                        return NSAttributedString(string: resetText.value, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor)
                    },
                    isOneLineWhenUnfocused: false,
                    characterLimit: component.characterLimit,
                    allowEmptyLines: component.allowEmptyLines,
                    formatMenuAvailability: .none,
                    lockedFormatAction: {
                    },
                    present: { _ in
                    },
                    paste: { _ in
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let size = CGSize(width: textFieldSize.width, height: textFieldSize.height - 1.0)
            let textFieldFrame = CGRect(origin: CGPoint(), size: textFieldSize)
            
            if let textFieldView = self.textField.view {
                if textFieldView.superview == nil {
                    self.addSubview(textFieldView)
                    self.textField.parentState = state
                }
                transition.setFrame(view: textFieldView, frame: textFieldFrame)
            }
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.placeholder.isEmpty ? " " : component.placeholder, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let placeholderFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: placeholderSize)
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.layer.anchorPoint = CGPoint()
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, at: 0)
                }
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                
                placeholderView.isHidden = self.textFieldExternalState.hasText
            }
            
            self.separatorInset = 16.0
            
            component.externalState?.hasText = self.textFieldExternalState.hasText
            
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
