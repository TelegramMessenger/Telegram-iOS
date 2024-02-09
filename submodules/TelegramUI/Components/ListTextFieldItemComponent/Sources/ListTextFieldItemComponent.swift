import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import MultilineTextComponent

public final class ListTextFieldItemComponent: Component {
    public let theme: PresentationTheme
    public let initialText: String
    public let placeholder: String
    public let updated: ((String) -> Void)?
    
    public init(
        theme: PresentationTheme,
        initialText: String,
        placeholder: String,
        updated: ((String) -> Void)?
    ) {
        self.theme = theme
        self.initialText = initialText
        self.placeholder = placeholder
        self.updated = updated
    }
    
    public static func ==(lhs: ListTextFieldItemComponent, rhs: ListTextFieldItemComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.initialText != rhs.initialText {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
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
    
    public final class View: UIView, UITextFieldDelegate {
        private let textField: TextField
        private let placeholder = ComponentView<Empty>()
        
        private var component: ListTextFieldItemComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        public var currentText: String {
            return self.textField.text ?? ""
        }
        
        public override init(frame: CGRect) {
            self.textField = TextField()

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
                self.state?.updated(transition: .immediate)
            }
        }
        
        func update(component: ListTextFieldItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            self.textField.isEnabled = component.updated != nil
            
            if self.textField.superview == nil {
                self.textField.text = component.initialText
                self.addSubview(self.textField)
                self.textField.delegate = self
                self.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
            }
            
            let themeUpdated = component.theme !== previousComponent?.theme
            
            if themeUpdated {
                self.textField.font = Font.regular(17.0)
                self.textField.textColor = component.theme.list.itemPrimaryTextColor
            }
            
            let verticalInset: CGFloat = 12.0
            let sideInset: CGFloat = 16.0
            
            self.textField.sideInset = sideInset
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.placeholder.isEmpty ? " " : component.placeholder, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let contentHeight: CGFloat = placeholderSize.height + verticalInset * 2.0
            let placeholderFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((contentHeight - placeholderSize.height) * 0.5)), size: placeholderSize)
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.layer.anchorPoint = CGPoint()
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, belowSubview: self.textField)
                }
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                
                placeholderView.isHidden = !self.currentText.isEmpty
            }
            
            transition.setFrame(view: self.textField, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
