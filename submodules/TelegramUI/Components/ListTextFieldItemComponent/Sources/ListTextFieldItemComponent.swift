import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import MultilineTextComponent
import ListSectionComponent
import PlainButtonComponent
import BundleIconComponent

public final class ListTextFieldItemComponent: Component {
    public enum Style {
        case glass
        case legacy
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
    
    public let style: Style
    public let theme: PresentationTheme
    public let initialText: String
    public let resetText: ResetText?
    public let placeholder: String
    public let autocapitalizationType: UITextAutocapitalizationType
    public let autocorrectionType: UITextAutocorrectionType
    public let returnKeyType: UIReturnKeyType
    public let contentInsets: UIEdgeInsets
    public let updated: ((String) -> Void)?
    public let onReturn: (() -> Void)?
    public let tag: AnyObject?
    
    public init(
        style: Style = .legacy,
        theme: PresentationTheme,
        initialText: String,
        resetText: ResetText? = nil,
        placeholder: String,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default,
        returnKeyType: UIReturnKeyType = .default,
        contentInsets: UIEdgeInsets = .zero,
        updated: ((String) -> Void)?,
        onReturn: (() -> Void)? = nil,
        tag: AnyObject? = nil
    ) {
        self.style = style
        self.theme = theme
        self.initialText = initialText
        self.resetText = resetText
        self.placeholder = placeholder
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.returnKeyType = returnKeyType
        self.contentInsets = contentInsets
        self.updated = updated
        self.onReturn = onReturn
        self.tag = tag
    }
    
    public static func ==(lhs: ListTextFieldItemComponent, rhs: ListTextFieldItemComponent) -> Bool {
        if lhs.style != rhs.style {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.initialText != rhs.initialText {
            return false
        }
        if lhs.resetText !== rhs.resetText {
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
        if lhs.contentInsets != rhs.contentInsets {
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
        private let textField: TextField
        private let placeholder = ComponentView<Empty>()
        private let clearButton = ComponentView<Empty>()
        
        private var component: ListTextFieldItemComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        public var currentText: String {
            return self.textField.text ?? ""
        }
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var enumerateSiblings: (((UIView) -> Void) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        
        public override init(frame: CGRect) {
            self.textField = TextField()

            super.init(frame: CGRect())
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            self.component?.onReturn?()
            return true
        }
        
        @objc private func textDidChange() {
            if !self.isUpdating {
                self.state?.updated(transition: .immediate)
            }
            self.component?.updated?(self.currentText)
        }
        
        public func setText(text: String, updateState: Bool) {
            self.textField.text = text
            if updateState {
                self.state?.updated(transition: .immediate, isLocal: true)
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
            self.textField.becomeFirstResponder()
        }
        
        public func textFieldDidBeginEditing(_ textField: UITextField) {
            self.clearButton.view?.isHidden = false
        }
        
        public func textFieldDidEndEditing(_ textField: UITextField) {
            self.clearButton.view?.isHidden = true
        }
        
        func update(component: ListTextFieldItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
            if let resetText = component.resetText, previousComponent?.resetText !== component.resetText {
                self.textField.text = resetText.value
            }
            
            if self.textField.autocapitalizationType != component.autocapitalizationType {
                self.textField.autocapitalizationType = component.autocapitalizationType
            }
            if self.textField.autocorrectionType != component.autocorrectionType {
                self.textField.autocorrectionType = component.autocorrectionType
            }
            if self.textField.returnKeyType != component.returnKeyType {
                self.textField.returnKeyType = component.returnKeyType
            }
            
            let themeUpdated = component.theme !== previousComponent?.theme
            
            if themeUpdated {
                self.textField.font = Font.regular(17.0)
                self.textField.textColor = component.theme.list.itemPrimaryTextColor
            }
            
            var verticalInset: CGFloat = 12.0
            if case .glass = component.style {
                verticalInset = 16.0
            }
            let sideInset: CGFloat = 16.0
            
            self.textField.sideInset = sideInset
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.placeholder.isEmpty ? " " : component.placeholder, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 30.0 - component.contentInsets.left - component.contentInsets.right, height: 100.0)
            )
            let contentHeight: CGFloat = placeholderSize.height + verticalInset * 2.0
            let placeholderFrame = CGRect(origin: CGPoint(x: sideInset + component.contentInsets.left, y: floor((contentHeight - placeholderSize.height) * 0.5)), size: placeholderSize)
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
            
            transition.setFrame(view: self.textField, frame: CGRect(origin: CGPoint(x: component.contentInsets.left, y: 0.0), size: CGSize(width: availableSize.width - component.contentInsets.left - component.contentInsets.right, height: contentHeight)))
            
            let clearButtonSize = self.clearButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(BundleIconComponent(
                        name: "Components/Search Bar/Clear",
                        tintColor: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.4)
                    )),
                    effectAlignment: .center,
                    minSize: CGSize(width: 44.0, height: 44.0),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.setText(text: "", updateState: true)
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
                transition.setFrame(view: clearButtonView, frame: CGRect(origin: CGPoint(x: availableSize.width - clearButtonSize.width, y: floor((contentHeight - clearButtonSize.height) * 0.5)), size: clearButtonSize))
                clearButtonView.isHidden = self.currentText.isEmpty || !self.textField.isFirstResponder
            }
            
            self.separatorInset = 16.0 + component.contentInsets.left
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
