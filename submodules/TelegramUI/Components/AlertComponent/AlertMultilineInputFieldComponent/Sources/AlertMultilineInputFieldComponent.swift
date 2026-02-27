import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AlertComponent
import TextFieldComponent
import MultilineTextComponent
import AccountContext
import TextFormat

public final class AlertMultilineInputFieldComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    public class ExternalState {
        public fileprivate(set) var value: NSAttributedString = NSAttributedString()
        public fileprivate(set) var animateError: () -> Void = {}
        public fileprivate(set) var activateInput: () -> Void = {}
        fileprivate let valuePromise = ValuePromise<NSAttributedString>(NSAttributedString())
        public var valueSignal: Signal<NSAttributedString, NoError> {
            return self.valuePromise.get()
        }
        
        public var textAndEntities: (String, [MessageTextEntity]) {
            let text = self.value.string
            let entities = generateChatInputTextEntities(self.value)
            return (text, entities)
        }
        
        public init() {
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
            
            var textFieldValue: TextFieldComponent.FormatMenuAvailability.Action {
                switch self {
                case .bold:
                    return .bold
                case .italic:
                    return .italic
                case .monospace:
                    return .monospace
                case .link:
                    return .link
                case .strikethrough:
                    return .strikethrough
                case .underline:
                    return .underline
                case .spoiler:
                    return .spoiler
                case .quote:
                    return .quote
                case .code:
                    return .code
                }
            }
        }
        case available([Action])
        case none
        
        var textFieldValue: TextFieldComponent.FormatMenuAvailability {
            switch self {
            case let .available(actions):
                return .available(actions.map { $0.textFieldValue })
            case .none:
                return .none
            }
        }
    }
    
    public enum EmptyLineHandling {
        case allowed
        case oneConsecutive
        case notAllowed
        
        var textFieldValue: TextFieldComponent.EmptyLineHandling {
            switch self {
            case .allowed:
                return .allowed
            case .oneConsecutive:
                return .oneConsecutive
            case .notAllowed:
                return .notAllowed
            }
        }
    }
        
    let context: AccountContext
    let initialValue: NSAttributedString?
    let placeholder: String
    let prefix: NSAttributedString?
    let characterLimit: Int?
    let returnKeyType: UIReturnKeyType
    let keyboardType: UIKeyboardType
    let autocapitalizationType: UITextAutocapitalizationType
    let autocorrectionType: UITextAutocorrectionType
    let formatMenuAvailability: FormatMenuAvailability
    let emptyLineHandling: EmptyLineHandling
    let isInitiallyFocused: Bool
    let externalState: ExternalState
    let present: (ViewController) -> Void
    let returnKeyAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        initialValue: NSAttributedString? = nil,
        placeholder: String,
        prefix: NSAttributedString? = nil,
        characterLimit: Int? = nil,
        returnKeyType: UIReturnKeyType = .default,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default,
        formatMenuAvailability: FormatMenuAvailability = .none,
        emptyLineHandling: EmptyLineHandling = .allowed,
        isInitiallyFocused: Bool = false,
        externalState: ExternalState,
        present: @escaping (ViewController) -> Void = { _ in },
        returnKeyAction: (() -> Void)? = nil
    ) {
        self.context = context
        self.initialValue = initialValue
        self.placeholder = placeholder
        self.prefix = prefix
        self.characterLimit = characterLimit
        self.returnKeyType = returnKeyType
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.formatMenuAvailability = formatMenuAvailability
        self.emptyLineHandling = emptyLineHandling
        self.isInitiallyFocused = isInitiallyFocused
        self.externalState = externalState
        self.present = present
        self.returnKeyAction = returnKeyAction
    }
    
    public static func ==(lhs: AlertMultilineInputFieldComponent, rhs: AlertMultilineInputFieldComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialValue != rhs.initialValue {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.prefix != rhs.prefix {
            return false
        }
        if lhs.returnKeyType != rhs.returnKeyType {
            return false
        }
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.keyboardType != rhs.keyboardType {
            return false
        }
        if lhs.autocapitalizationType != rhs.autocapitalizationType {
            return false
        }
        if lhs.autocorrectionType != rhs.autocorrectionType {
            return false
        }
        if lhs.formatMenuAvailability != rhs.formatMenuAvailability {
            return false
        }
        if lhs.emptyLineHandling != rhs.emptyLineHandling {
            return false
        }
        if lhs.isInitiallyFocused != rhs.isInitiallyFocused {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let background = ComponentView<Empty>()
        private let textField = ComponentView<Empty>()
        private let textFieldExternalState = TextFieldComponent.ExternalState()
        private let placeholder = ComponentView<Empty>()
        
        private var component: AlertMultilineInputFieldComponent?
        private weak var state: EmptyComponentState?
        
        func activateInput() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.activateInput()
            }
        }
        
        func animateError() {
            if let textFieldView = self.textField.view {
                textFieldView.layer.addShakeAnimation()
            }
            HapticFeedback().error()
        }
        
        func update(component: AlertMultilineInputFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            var resetText: NSAttributedString?
            if self.component == nil {
                resetText = component.initialValue
                component.externalState.animateError = { [weak self] in
                    self?.animateError()
                }
                component.externalState.activateInput = { [weak self] in
                    self?.activateInput()
                }
            }
            
            let isFirstTime = self.component == nil
            
            self.component = component
            self.state = state
            
            let environment = environment[AlertComponentEnvironment.self]
            
            let topInset: CGFloat = 15.0
            let horizontalInset: CGFloat = 4.0
            let verticalInset: CGFloat = 11.0 - UIScreenPixel
            
            let textFieldSize = self.textField.update(
                transition: transition,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    theme: environment.theme,
                    strings: environment.strings,
                    externalState: self.textFieldExternalState,
                    fontSize: 17.0,
                    textColor: environment.theme.actionSheet.primaryTextColor,
                    accentColor: environment.theme.actionSheet.controlAccentColor,
                    insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0),
                    hideKeyboard: false,
                    customInputView: nil,
                    resetText: resetText,
                    isOneLineWhenUnfocused: false,
                    characterLimit: component.characterLimit,
                    emptyLineHandling: component.emptyLineHandling.textFieldValue,
                    formatMenuAvailability: component.formatMenuAvailability.textFieldValue,
                    returnKeyType: component.returnKeyType,
                    keyboardType: component.keyboardType,
                    autocapitalizationType: component.autocapitalizationType,
                    autocorrectionType: component.autocorrectionType,
                    lockedFormatAction: {
                    },
                    present: { [weak self] c in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.present(c)
                    },
                    paste: { _ in
                    },
                    returnKeyAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.returnKeyAction?()
                    },
                    backspaceKeyAction: {
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width + horizontalInset * 2.0, height: availableSize.height)
            )
            component.externalState.value = self.textFieldExternalState.text
            component.externalState.valuePromise.set(component.externalState.value)
            
            let backgroundPadding: CGFloat = 14.0
            let size = CGSize(width: availableSize.width, height: max(50.0, floor(textFieldSize.height + verticalInset * 2.0)))
            
            let backgroundSize = self.background.update(
                transition: transition,
                component: AnyComponent(
                    FilledRoundedRectangleComponent(color: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.1), cornerRadius: .value(25.0), smoothCorners: false)
                ),
                environment: {},
                containerSize: CGSize(width: size.width + backgroundPadding * 2.0, height: size.height)
            )
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - backgroundSize.width) / 2.0), y: topInset ), size: backgroundSize)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let textFieldFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - textFieldSize.width) / 2.0), y: topInset + 11.0 - UIScreenPixel), size: textFieldSize)
            if let textFieldView = self.textField.view {
                if textFieldView.superview == nil {
                    self.addSubview(textFieldView)
                    self.textField.parentState = state
                }
                transition.setFrame(view: textFieldView, frame: textFieldFrame)
            }
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(
                        string: component.placeholder,
                        font: Font.regular(17.0),
                        textColor: environment.theme.actionSheet.primaryTextColor.withMultipliedAlpha(0.4)
                    )))
                ),
                environment: {},
                containerSize: CGSize(width: size.width, height: 50.0)
            )
            let placeholderFrame = CGRect(origin: CGPoint(x: 4.0, y: floorToScreenPixels(textFieldFrame.midY - placeholderSize.height / 2.0)), size: placeholderSize)
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.isUserInteractionEnabled = false
                    self.addSubview(placeholderView)
                }
                placeholderView.frame = placeholderFrame
                placeholderView.isHidden = self.textFieldExternalState.hasText
            }
            
            if isFirstTime && component.isInitiallyFocused {
                self.activateInput()
            }
            
            return CGSize(width: availableSize.width, height: size.height + topInset)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
