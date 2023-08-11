import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent

public final class NavigationSearchComponent: Component {
    public struct Colors: Equatable {
        public var background: UIColor
        public var inactiveForeground: UIColor
        public var foreground: UIColor
        public var button: UIColor

        public init(
            background: UIColor,
            inactiveForeground: UIColor,
            foreground: UIColor,
            button: UIColor
        ) {
            self.background = background
            self.inactiveForeground = inactiveForeground
            self.foreground = foreground
            self.button = button
        }
    }

    public let colors: Colors
    public let cancel: String
    public let placeholder: String
    public let isSearchActive: Bool
    public let collapseFraction: CGFloat
    public let activateSearch: () -> Void
    public let deactivateSearch: () -> Void
    public let updateQuery: (String) -> Void
    
    public init(
        colors: Colors,
        cancel: String,
        placeholder: String,
        isSearchActive: Bool,
        collapseFraction: CGFloat,
        activateSearch: @escaping () -> Void,
        deactivateSearch: @escaping () -> Void,
        updateQuery: @escaping (String) -> Void
    ) {
        self.colors = colors
        self.cancel = cancel
        self.placeholder = placeholder
        self.isSearchActive = isSearchActive
        self.collapseFraction = collapseFraction
        self.activateSearch = activateSearch
        self.deactivateSearch = deactivateSearch
        self.updateQuery = updateQuery
    }
    
    public static func ==(lhs: NavigationSearchComponent, rhs: NavigationSearchComponent) -> Bool {
        if lhs.colors != rhs.colors {
            return false
        }
        if lhs.cancel != rhs.cancel {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.isSearchActive != rhs.isSearchActive {
            return false
        }
        if lhs.collapseFraction != rhs.collapseFraction {
            return false
        }
        return true
    }
    
    public final class View: UIView, UITextFieldDelegate {
        private var component: NavigationSearchComponent?
        private weak var state: EmptyComponentState?
        
        private let backgroundView: UIView
        private let searchIconView: UIImageView
        private let placeholderText = ComponentView<Empty>()
        
        private let clearButton: HighlightableButton
        private let clearIconView: UIImageView
        
        private var button: ComponentView<Empty>?
        
        private var textField: UITextField?
        
        override init(frame: CGRect) {
            self.backgroundView = UIView()
            self.backgroundView.layer.cornerRadius = 10.0
            
            self.searchIconView = UIImageView(image: UIImage(bundleImageName: "Components/Search Bar/Loupe")?.withRenderingMode(.alwaysTemplate))
            
            self.clearButton = HighlightableButton()
            self.clearIconView = UIImageView(image: UIImage(bundleImageName: "Components/Search Bar/Clear")?.withRenderingMode(.alwaysTemplate))
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.searchIconView)
            
            self.addSubview(self.clearButton)
            self.clearButton.addSubview(self.clearIconView)
            self.clearButton.isHidden = true
            
            self.backgroundView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.backgroundTapGesture(_:))))
            
            self.clearButton.addTarget(self, action: #selector(self.clearPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc private func backgroundTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                if self.textField == nil {
                    let textField = UITextField()
                    self.textField = textField
                    textField.delegate = self
                    textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
                    self.addSubview(textField)
                    textField.keyboardAppearance = .dark
                    textField.returnKeyType = .done
                }
                
                self.textField?.becomeFirstResponder()
            }
        }
        
        public func textFieldDidBeginEditing(_ textField: UITextField) {
            guard let component = self.component else {
                return
            }
            if !component.isSearchActive {
                component.activateSearch()
            }
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return false
        }
        
        @objc private func textChanged() {
            self.updateText(updateComponent: true)
        }
        
        @objc private func clearPressed() {
            self.textField?.text = ""
            self.updateText(updateComponent: true)
        }
        
        @objc private func updateText(updateComponent: Bool) {
            let isEmpty = self.textField?.text?.isEmpty ?? true
            self.placeholderText.view?.isHidden = !isEmpty
            
            self.clearButton.isHidden = isEmpty
            
            if updateComponent, let component = self.component {
                component.updateQuery(self.textField?.text ?? "")
            }
        }
        
        func update(component: NavigationSearchComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.state = state
            
            let baseHeight: CGFloat = 52.0
            let size = CGSize(width: availableSize.width, height: baseHeight)
            
            let sideInset: CGFloat = 16.0
            let fieldHeight: CGFloat = 36.0
            let fieldSideInset: CGFloat = 8.0
            let searchIconSpacing: CGFloat = 4.0
            let buttonSpacing: CGFloat = 8.0
            
            let rightInset: CGFloat
            if component.isSearchActive {
                var buttonTransition = transition
                let button: ComponentView<Empty>
                if let current = self.button {
                    button = current
                } else {
                    buttonTransition = buttonTransition.withAnimation(.none)
                    button = ComponentView()
                    self.button = button
                }
                
                let buttonSize = button.update(
                    transition: buttonTransition,
                    component: AnyComponent(Button(
                        content: AnyComponent(Text(text: component.cancel, font: Font.regular(17.0), color: component.colors.button)),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.deactivateSearch()
                        }
                    ).minSize(CGSize(width: 8.0, height: baseHeight))),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                let buttonFrame = CGRect(origin: CGPoint(x: size.width - sideInset - buttonSize.width, y: floor((size.height - buttonSize.height) * 0.5)), size: buttonSize)
                if let buttonView = button.view {
                    var animateIn = false
                    if buttonView.superview == nil {
                        animateIn = true
                        self.addSubview(buttonView)
                    }
                    buttonTransition.setFrame(view: buttonView, frame: buttonFrame)
                    if animateIn {
                        transition.animatePosition(view: buttonView, from: CGPoint(x: size.width - buttonFrame.minX, y: 0.0), to: CGPoint(), additive: true)
                    }
                }
                
                rightInset = sideInset + buttonSize.width + buttonSpacing
            } else {
                if let button = self.button {
                    self.button = nil
                    
                    if let buttonView = button.view {
                        transition.setFrame(view: buttonView, frame: CGRect(origin: CGPoint(x: size.width, y: buttonView.frame.minY), size: buttonView.bounds.size))
                    }
                }
                
                rightInset = sideInset
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((size.height - fieldHeight) * 0.5)), size: CGSize(width: availableSize.width - sideInset - rightInset, height: fieldHeight))
            transition.setFrame(view: self.backgroundView, frame: backgroundFrame)
            if previousComponent?.colors.background != component.colors.background {
                self.backgroundView.backgroundColor = component.colors.background
            }
            if previousComponent?.colors.inactiveForeground != component.colors.inactiveForeground {
                self.searchIconView.tintColor = component.colors.inactiveForeground
                self.clearIconView.tintColor = component.colors.inactiveForeground
            }
            
            let placeholderSize = self.placeholderText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.placeholder, font: Font.regular(17.0), color: component.colors.inactiveForeground)),
                environment: {},
                containerSize: CGSize(width: backgroundFrame.width - fieldSideInset * 2.0, height: backgroundFrame.height)
            )
            
            let searchIconSize = self.searchIconView.image?.size ?? CGSize(width: 20.0, height: 20.0)
            //let searchPlaceholderCombinedWidth = searchIconSize.width + searchIconSpacing + placeholderSize.width
            
            let placeholderTextFrame = CGRect(origin: CGPoint(x: component.isSearchActive ? (backgroundFrame.minX + fieldSideInset + searchIconSize.width + searchIconSpacing) : floor(backgroundFrame.midX - placeholderSize.width * 0.5), y: backgroundFrame.minY + floor((fieldHeight - placeholderSize.height) * 0.5)), size: placeholderSize)
            var placeholderDeltaX: CGFloat = 0.0
            if let placeholderTextView = self.placeholderText.view {
                if placeholderTextView.superview == nil {
                    placeholderTextView.layer.anchorPoint = CGPoint()
                    placeholderTextView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderTextView, aboveSubview: self.searchIconView)
                } else {
                    placeholderDeltaX = placeholderTextFrame.minX - placeholderTextView.frame.minX
                }
                transition.setPosition(view: placeholderTextView, position: placeholderTextFrame.origin)
                transition.setBounds(view: placeholderTextView, bounds: CGRect(origin: CGPoint(), size: placeholderTextFrame.size))
            }
            
            let searchIconFrame = CGRect(origin: CGPoint(x: placeholderTextFrame.minX - searchIconSpacing - searchIconSize.width, y: backgroundFrame.minY + floor((fieldHeight - searchIconSize.height) * 0.5)), size: searchIconSize)
            transition.setFrame(view: self.searchIconView, frame: searchIconFrame)
            
            if let image = self.clearIconView.image {
                let clearSize = image.size
                let clearFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - 6.0 - clearSize.width, y: backgroundFrame.minY + floor((backgroundFrame.height - clearSize.height) / 2.0)), size: clearSize)
                
                let clearButtonFrame = CGRect(origin: CGPoint(x: clearFrame.minX - 4.0, y: backgroundFrame.minY), size: CGSize(width: clearFrame.width + 8.0, height: backgroundFrame.height))
                transition.setFrame(view: self.clearButton, frame: clearButtonFrame)
                transition.setFrame(view: self.clearIconView, frame: clearFrame.offsetBy(dx: -clearButtonFrame.minX, dy: -clearButtonFrame.minY))
            }
            
            if let textField = self.textField {
                var textFieldTransition = transition
                var animateIn = false
                if textField.bounds.isEmpty {
                    textFieldTransition = textFieldTransition.withAnimation(.none)
                    animateIn = true
                }
                
                if textField.textColor != component.colors.foreground {
                    textField.textColor = component.colors.foreground
                    textField.font = Font.regular(17.0)
                }
                
                let textLeftInset: CGFloat = fieldSideInset + searchIconSize.width + searchIconSpacing
                let textRightInset: CGFloat = 8.0 + 30.0
                textFieldTransition.setFrame(view: textField, frame: CGRect(origin: CGPoint(x: placeholderTextFrame.minX, y: backgroundFrame.minY - 1.0), size: CGSize(width: backgroundFrame.width - textLeftInset - textRightInset, height: backgroundFrame.height)))
                
                if animateIn {
                    transition.animatePosition(view: textField, from: CGPoint(x: -placeholderDeltaX, y: 0.0), to: CGPoint(), additive: true)
                }
            }
            
            if let textField = self.textField {
                if !component.isSearchActive {
                    if !(textField.text?.isEmpty ?? true) {
                        textField.text = ""
                        self.updateText(updateComponent: false)
                    }
                    
                    if textField.isFirstResponder {
                        DispatchQueue.main.async { [weak textField] in
                            textField?.resignFirstResponder()
                        }
                    }
                }
            }
            
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
