import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AlertComponent
import MultilineTextComponent
import AccountContext
import TextFormat
import PlainButtonComponent
import BundleIconComponent

public final class AlertInputFieldComponent: Component {
    public typealias EnvironmentType = AlertComponentEnvironment
    
    public class ExternalState {
        public fileprivate(set) var value: String = ""
        public fileprivate(set) var animateError: () -> Void = {}
        public fileprivate(set) var activateInput: () -> Void = {}
        fileprivate let valuePromise = ValuePromise<String>("")
        public var valueSignal: Signal<String, NoError> {
            return self.valuePromise.get()
        }
        
        public init() {
        }
    }
    
    let context: AccountContext
    let initialValue: String?
    let placeholder: String
    let characterLimit: Int?
    let hasClearButton: Bool
    let isSecureTextEntry: Bool
    let returnKeyType: UIReturnKeyType
    let keyboardType: UIKeyboardType
    let autocapitalizationType: UITextAutocapitalizationType
    let autocorrectionType: UITextAutocorrectionType
    let isInitiallyFocused: Bool
    let externalState: ExternalState
    let shouldChangeText: ((String) -> Bool)?
    let returnKeyAction: (() -> Void)?
    
    public init(
        context: AccountContext,
        initialValue: String? = nil,
        placeholder: String,
        characterLimit: Int? = nil,
        hasClearButton: Bool = false,
        isSecureTextEntry: Bool = false,
        returnKeyType: UIReturnKeyType = .done,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default,
        isInitiallyFocused: Bool = false,
        externalState: ExternalState,
        shouldChangeText: ((String) -> Bool)? = nil,
        returnKeyAction: (() -> Void)? = nil
    ) {
        self.context = context
        self.initialValue = initialValue
        self.placeholder = placeholder
        self.characterLimit = characterLimit
        self.hasClearButton = hasClearButton
        self.isSecureTextEntry = isSecureTextEntry
        self.returnKeyType = returnKeyType
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.isInitiallyFocused = isInitiallyFocused
        self.externalState = externalState
        self.shouldChangeText = shouldChangeText
        self.returnKeyAction = returnKeyAction
    }
    
    public static func ==(lhs: AlertInputFieldComponent, rhs: AlertInputFieldComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialValue != rhs.initialValue {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.hasClearButton != rhs.hasClearButton {
            return false
        }
        if lhs.isSecureTextEntry != rhs.isSecureTextEntry {
            return false
        }
        if lhs.returnKeyType != rhs.returnKeyType {
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
        if lhs.isInitiallyFocused != rhs.isInitiallyFocused {
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
    
    public final class View: UIView, UITextFieldDelegate {
        private let background = ComponentView<Empty>()
        private let textField = TextField()
        private let placeholder = ComponentView<Empty>()
        private let clearButton = ComponentView<Empty>()
        
        private var component: AlertInputFieldComponent?
        private weak var state: EmptyComponentState?
        
        private var isUpdating = false
        
        var currentText: String {
            return self.textField.text ?? ""
        }
        
        private var clearOnce: Bool = false
        
        func activateInput() {
            self.textField.becomeFirstResponder()
        }
        
        func animateError() {
            if let component = self.component, component.isInitiallyFocused {
                self.clearOnce = true
            }
            self.textField.layer.addShakeAnimation()
        
            HapticFeedback().error()
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            self.component?.returnKeyAction?()
            return false
        }
        
        @objc private func textDidChange() {
            if !self.isUpdating {
                self.state?.updated(transition: .immediate)
            }
        }
        
        public func textFieldDidBeginEditing(_ textField: UITextField) {
            self.clearButton.view?.isHidden = self.currentText.isEmpty
        }
        
        public func textFieldDidEndEditing(_ textField: UITextField) {
            self.clearButton.view?.isHidden = true
        }
        
        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let component = self.component else {
                return true
            }
            
            if self.clearOnce {
                self.clearOnce = false
                if range.length > string.count {
                    textField.text = ""
                    return false
                }
            }
            
            let updatedText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
            if let shouldChangeText = component.shouldChangeText {
                return shouldChangeText(updatedText)
            }
            return true
        }
    
        public func setText(text: String) {
            self.textField.text = text
            if !self.isUpdating {
                self.state?.updated(transition: .immediate, isLocal: true)
            }
        }
        
        func update(component: AlertInputFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<AlertComponentEnvironment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            var resetText: String?
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
            
            if self.textField.superview == nil {
                self.addSubview(self.textField)
                self.textField.delegate = self
                self.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
            }
            if self.textField.autocapitalizationType != component.autocapitalizationType {
                self.textField.autocapitalizationType = component.autocapitalizationType
            }
            if self.textField.autocorrectionType != component.autocorrectionType {
                self.textField.autocorrectionType = component.autocorrectionType
            }
            if self.textField.isSecureTextEntry != component.isSecureTextEntry {
                self.textField.isSecureTextEntry = component.isSecureTextEntry
            }
            if self.textField.returnKeyType != component.returnKeyType {
                self.textField.returnKeyType = component.returnKeyType
            }
            self.textField.keyboardAppearance = environment.theme.overallDarkAppearance ? .dark : .light
            if let resetText {
                self.textField.text = resetText
            }
            
            self.textField.font = Font.regular(17.0)
            self.textField.textColor = environment.theme.actionSheet.primaryTextColor
            self.textField.tintColor = environment.theme.actionSheet.controlAccentColor
            self.textField.sideInset = 16.0
            
            let backgroundPadding: CGFloat = 14.0
            let size = CGSize(width: availableSize.width, height: 50.0)
            
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
            
            let textFieldSize = CGSize(width: availableSize.width - 24.0, height: 50.0)
            let textFieldFrame = CGRect(origin: CGPoint(x: -12.0, y: topInset), size: textFieldSize)
            transition.setFrame(view: self.textField, frame: textFieldFrame)
            
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
                placeholderView.isHidden = !self.currentText.isEmpty
            }
            
            if component.hasClearButton {
                let clearButtonSize = self.clearButton.update(
                    transition: transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(BundleIconComponent(
                            name: "Components/Search Bar/Clear",
                            tintColor: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.4)
                        )),
                        effectAlignment: .center,
                        minSize: CGSize(width: 44.0, height: 44.0),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.setText(text: "")
                        },
                        animateAlpha: false,
                        animateScale: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: 44.0, height: 44.0)
                )
                if let clearButtonView = self.clearButton.view {
                    if clearButtonView.superview == nil {
                        self.addSubview(clearButtonView)
                    }
                    transition.setFrame(view: clearButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - clearButtonSize.width + 11.0, y: topInset + floor((size.height - clearButtonSize.height) * 0.5)), size: clearButtonSize))
                    clearButtonView.isHidden = self.currentText.isEmpty || !self.textField.isFirstResponder
                }
            } else if let clearButtonView = self.clearButton.view, clearButtonView.superview != nil {
                clearButtonView.removeFromSuperview()
            }
            
            if isFirstTime && component.isInitiallyFocused {
                self.activateInput()
            }
            
            component.externalState.value = self.currentText
            component.externalState.valuePromise.set(self.currentText)
            
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
