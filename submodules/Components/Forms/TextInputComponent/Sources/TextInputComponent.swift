import Foundation
import UIKit
import ComponentFlow
import Display

public final class TextInputComponent: Component {
    public let text: String
    public let textColor: UIColor
    public let placeholder: String
    public let placeholderColor: UIColor
    public let updated: (String) -> Void
    
    public init(
        text: String,
        textColor: UIColor,
        placeholder: String,
        placeholderColor: UIColor,
        updated: @escaping (String) -> Void
    ) {
        self.text = text
        self.textColor = textColor
        self.placeholder = placeholder
        self.placeholderColor = placeholderColor
        self.updated = updated
    }
    
    public static func ==(lhs: TextInputComponent, rhs: TextInputComponent) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
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
    
    public final class View: UITextField, UITextFieldDelegate {
        private var component: TextInputComponent?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.delegate = self
            self.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func textFieldChanged(_ textField: UITextField) {
            self.component?.updated(self.text ?? "")
        }
        
        func update(component: TextInputComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.font = UIFont.systemFont(ofSize: 17.0)
            self.textColor = component.textColor
            
            if self.text != component.text {
                self.text = component.text
            }
            
            self.attributedPlaceholder = NSAttributedString(string: component.placeholder, font: self.font, textColor: component.placeholderColor)
            
            let size = CGSize(width: availableSize.width, height: 44.0)
            
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
