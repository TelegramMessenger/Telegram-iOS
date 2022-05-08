import Foundation
import UIKit
import ComponentFlow
import Display
import Stripe

public final class CreditCardInputComponent: Component {
    public enum DataType {
        case cardNumber
        case expirationDate
    }
    
    public let dataType: DataType
    public let text: String
    public let textColor: UIColor
    public let errorTextColor: UIColor
    public let placeholder: String
    public let placeholderColor: UIColor
    public let updated: (String) -> Void
    
    public init(
        dataType: DataType,
        text: String,
        textColor: UIColor,
        errorTextColor: UIColor,
        placeholder: String,
        placeholderColor: UIColor,
        updated: @escaping (String) -> Void
    ) {
        self.dataType = dataType
        self.text = text
        self.textColor = textColor
        self.errorTextColor = errorTextColor
        self.placeholder = placeholder
        self.placeholderColor = placeholderColor
        self.updated = updated
    }
    
    public static func ==(lhs: CreditCardInputComponent, rhs: CreditCardInputComponent) -> Bool {
        if lhs.dataType != rhs.dataType {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.errorTextColor != rhs.errorTextColor {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        return true
    }
    
    public final class View: UIView, STPFormTextFieldDelegate, UITextFieldDelegate {
        private let textField: STPFormTextField
        
        private var component: CreditCardInputComponent?
        private let viewModel: STPPaymentCardTextFieldViewModel
        
        override init(frame: CGRect) {
            self.textField = STPFormTextField(frame: CGRect())
            
            self.viewModel = STPPaymentCardTextFieldViewModel()
            
            super.init(frame: frame)
            
            self.textField.backgroundColor = .clear
            self.textField.keyboardType = .phonePad
            
            self.textField.formDelegate = self
            self.textField.validText = true
            
            self.addSubview(self.textField)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func textFieldChanged(_ textField: UITextField) {
            self.component?.updated(self.textField.text ?? "")
        }
        
        public func formTextFieldDidBackspace(onEmpty formTextField: STPFormTextField) {
        }
        
        public func formTextField(_ formTextField: STPFormTextField, modifyIncomingTextChange input: NSAttributedString) -> NSAttributedString {
            guard let component = self.component else {
                return input
            }
            
            switch component.dataType {
            case .cardNumber:
                self.viewModel.cardNumber = input.string
                return NSAttributedString(string: self.viewModel.cardNumber ?? "", attributes: self.textField.defaultTextAttributes)
            case .expirationDate:
                self.viewModel.rawExpiration = input.string
                return NSAttributedString(string: self.viewModel.rawExpiration ?? "", attributes: self.textField.defaultTextAttributes)
            }
        }
        
        public func formTextFieldTextDidChange(_ textField: STPFormTextField) {
            guard let component = self.component else {
                return
            }
            
            component.updated(self.textField.text ?? "")
            
            let state: STPCardValidationState
            switch component.dataType {
            case .cardNumber:
                state = self.viewModel.validationState(for: .number)
            case .expirationDate:
                state = self.viewModel.validationState(for: .expiration)
            }
            self.textField.validText = true
            switch state {
            case .invalid:
                self.textField.validText = false
            case .incomplete:
                break
            case .valid:
                break
            @unknown default:
                break
            }
        }
        
        func update(component: CreditCardInputComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            switch component.dataType {
            case .cardNumber:
                self.textField.autoFormattingBehavior = .cardNumbers
            case .expirationDate:
                self.textField.autoFormattingBehavior = .expiration
            }
            
            self.textField.font = UIFont.systemFont(ofSize: 17.0)
            self.textField.defaultColor = component.textColor
            self.textField.errorColor = .red
            self.textField.placeholderColor = component.placeholderColor
            
            if self.textField.text != component.text {
                self.textField.text = component.text
            }
            
            self.textField.attributedPlaceholder = NSAttributedString(string: component.placeholder, font: self.textField.font, textColor: component.placeholderColor)
            
            let size = CGSize(width: availableSize.width, height: 44.0)
            
            transition.setFrame(view: self.textField, frame: CGRect(origin: CGPoint(), size: size), completion: nil)
            
            self.component = component
            
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
