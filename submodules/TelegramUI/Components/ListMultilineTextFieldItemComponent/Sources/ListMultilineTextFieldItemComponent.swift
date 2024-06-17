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
        public fileprivate(set) var text: NSAttributedString = NSAttributedString()
        public fileprivate(set) var isEditing: Bool = false
        
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
    
    public enum EmptyLineHandling {
        case allowed
        case oneConsecutive
        case notAllowed
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
    public let returnKeyType: UIReturnKeyType
    public let characterLimit: Int?
    public let displayCharacterLimit: Bool
    public let emptyLineHandling: EmptyLineHandling
    public let updated: ((String) -> Void)?
    public let returnKeyAction: (() -> Void)?
    public let backspaceKeyAction: (() -> Void)?
    public let textUpdateTransition: ComponentTransition
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
        returnKeyType: UIReturnKeyType = .default,
        characterLimit: Int? = nil,
        displayCharacterLimit: Bool = false,
        emptyLineHandling: EmptyLineHandling = .allowed,
        updated: ((String) -> Void)? = nil,
        returnKeyAction: (() -> Void)? = nil,
        backspaceKeyAction: (() -> Void)? = nil,
        textUpdateTransition: ComponentTransition = .immediate,
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
        self.returnKeyType = returnKeyType
        self.characterLimit = characterLimit
        self.displayCharacterLimit = displayCharacterLimit
        self.emptyLineHandling = emptyLineHandling
        self.updated = updated
        self.returnKeyAction = returnKeyAction
        self.backspaceKeyAction = backspaceKeyAction
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
        if lhs.returnKeyType != rhs.returnKeyType {
            return false
        }
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.displayCharacterLimit != rhs.displayCharacterLimit {
            return false
        }
        if lhs.emptyLineHandling != rhs.emptyLineHandling {
            return false
        }
        if (lhs.updated == nil) != (rhs.updated == nil) {
            return false
        }
        return true
    }
    
    public final class View: UIView, ListSectionComponent.ChildView, ComponentTaggedView {
        private let textField = ComponentView<Empty>()
        private let textFieldExternalState = TextFieldComponent.ExternalState()
        
        private let placeholder = ComponentView<Empty>()
        private var customPlaceholder: ComponentView<Empty>?
        
        private var measureTextLimitLabel: ComponentView<Empty>?
        private var textLimitLabel: ComponentView<Empty>?
        
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
        
        public func activateInput() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.activateInput()
            }
        }
        
        func update(component: ListMultilineTextFieldItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let verticalInset: CGFloat = 12.0
            let sideInset: CGFloat = 16.0
            
            let textLimitFont = Font.regular(15.0)
            var measureTextLimitInset: CGFloat = 0.0
            if component.characterLimit != nil && component.displayCharacterLimit {
                let measureTextLimitLabel: ComponentView<Empty>
                if let current = self.measureTextLimitLabel {
                    measureTextLimitLabel = current
                } else {
                    measureTextLimitLabel = ComponentView()
                    self.measureTextLimitLabel = measureTextLimitLabel
                }
                let measureTextLimitSize = measureTextLimitLabel.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "000", font: textLimitFont))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                measureTextLimitInset = measureTextLimitSize.width + 4.0
            } else {
                self.measureTextLimitLabel = nil
            }
            
            let mappedEmptyLineHandling: TextFieldComponent.EmptyLineHandling
            switch component.emptyLineHandling {
            case .allowed:
                mappedEmptyLineHandling = .allowed
            case .oneConsecutive:
                mappedEmptyLineHandling = .oneConsecutive
            case .notAllowed:
                mappedEmptyLineHandling = .notAllowed
            }
            
            let textFieldSize = self.textField.update(
                transition: transition,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    externalState: self.textFieldExternalState,
                    fontSize: 17.0,
                    textColor: component.theme.list.itemPrimaryTextColor,
                    accentColor: component.theme.list.itemPrimaryTextColor,
                    insets: UIEdgeInsets(top: verticalInset, left: sideInset - 8.0, bottom: verticalInset, right: sideInset - 8.0 + measureTextLimitInset),
                    hideKeyboard: false,
                    customInputView: nil,
                    resetText: component.resetText.flatMap { resetText in
                        return NSAttributedString(string: resetText.value, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor)
                    },
                    isOneLineWhenUnfocused: false,
                    characterLimit: component.characterLimit,
                    emptyLineHandling: mappedEmptyLineHandling,
                    formatMenuAvailability: .none,
                    returnKeyType: component.returnKeyType,
                    lockedFormatAction: {
                    },
                    present: { _ in
                    },
                    paste: { _ in
                    },
                    returnKeyAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.returnKeyAction?()
                    },
                    backspaceKeyAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.backspaceKeyAction?()
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
            component.externalState?.text = self.textFieldExternalState.text
            component.externalState?.isEditing = self.textFieldExternalState.isEditing
            
            var displayRemainingLimit: Int?
            if let characterLimit = component.characterLimit, component.displayCharacterLimit {
                let remainingLimit = characterLimit - self.textFieldExternalState.text.length
                let displayThreshold = max(10, Int(Double(characterLimit) * 0.15))
                if remainingLimit <= displayThreshold {
                    displayRemainingLimit = remainingLimit
                }
            }
            if let displayRemainingLimit {
                let textLimitLabel: ComponentView<Empty>
                var textLimitLabelTransition = transition
                if let current = self.textLimitLabel {
                    textLimitLabel = current
                } else {
                    textLimitLabelTransition = textLimitLabelTransition.withAnimation(.none)
                    textLimitLabel = ComponentView()
                    self.textLimitLabel = textLimitLabel
                }
                
                let textLimitLabelSize = textLimitLabel.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(displayRemainingLimit)", font: textLimitFont, textColor: component.theme.list.itemSecondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let textLimitLabelFrame = CGRect(origin: CGPoint(x: availableSize.width - textLimitLabelSize.width - sideInset, y: verticalInset + 2.0), size: textLimitLabelSize)
                if let textLimitLabelView = textLimitLabel.view {
                    if textLimitLabelView.superview == nil {
                        textLimitLabelView.isUserInteractionEnabled = false
                        textLimitLabelView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                        self.addSubview(textLimitLabelView)
                    }
                    textLimitLabelTransition.setPosition(view: textLimitLabelView, position: CGPoint(x: textLimitLabelFrame.maxX, y: textLimitLabelFrame.minY))
                    textLimitLabelView.bounds = CGRect(origin: CGPoint(), size: textLimitLabelFrame.size)
                }
            } else {
                if let textLimitLabel = self.textLimitLabel {
                    self.textLimitLabel = nil
                    textLimitLabel.view?.removeFromSuperview()
                }
            }
            
            return size
        }
        
        public func updateCustomPlaceholder(value: String, size: CGSize, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            
            let verticalInset: CGFloat = 12.0
            let sideInset: CGFloat = 16.0
            
            if !value.isEmpty {
                let customPlaceholder: ComponentView<Empty>
                var customPlaceholderTransition = transition
                if let current = self.customPlaceholder {
                    customPlaceholder = current
                } else {
                    customPlaceholderTransition = customPlaceholderTransition.withAnimation(.none)
                    customPlaceholder = ComponentView()
                    self.customPlaceholder = customPlaceholder
                }
                
                let placeholderSize = customPlaceholder.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: value.isEmpty ? " " : value, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: size.width - sideInset * 2.0, height: 100.0)
                )
                let placeholderFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: placeholderSize)
                if let placeholderView = customPlaceholder.view {
                    if placeholderView.superview == nil {
                        placeholderView.layer.anchorPoint = CGPoint()
                        placeholderView.isUserInteractionEnabled = false
                        self.insertSubview(placeholderView, at: 0)
                    }
                    transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                    placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                    
                    placeholderView.isHidden = self.textFieldExternalState.hasText
                }
            } else if let customPlaceholder = self.customPlaceholder {
                self.customPlaceholder = nil
                customPlaceholder.view?.removeFromSuperview()
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
