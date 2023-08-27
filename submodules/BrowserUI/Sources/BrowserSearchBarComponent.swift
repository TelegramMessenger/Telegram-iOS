import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import AccountContext
import BundleIconComponent

final class SearchBarContentComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let performAction: ActionSlot<BrowserScreen.Action>
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        performAction: ActionSlot<BrowserScreen.Action>
    ) {
        self.theme = theme
        self.strings = strings
        self.performAction = performAction
    }
    
    static func ==(lhs: SearchBarContentComponent, rhs: SearchBarContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        return true
    }

    final class View: UIView, UITextFieldDelegate {
        private final class EmojiSearchTextField: UITextField {
            override func textRect(forBounds bounds: CGRect) -> CGRect {
                return bounds.integral
            }
        }
        
        private struct Params: Equatable {
            var theme: PresentationTheme
            var strings: PresentationStrings
            var size: CGSize
            
            static func ==(lhs: Params, rhs: Params) -> Bool {
                if lhs.theme !== rhs.theme {
                    return false
                }
                if lhs.strings !== rhs.strings {
                    return false
                }
                if lhs.size != rhs.size {
                    return false
                }
                return true
            }
        }
        
        private let activated: (Bool) -> Void = { _ in }
        private let deactivated: (Bool) -> Void = { _ in }
        private let updateQuery: (String?) -> Void = { _ in }
        
        private let backgroundLayer: SimpleLayer
        
        private let iconView: UIImageView
        
        private let clearIconView: UIImageView
        private let clearIconButton: HighlightTrackingButton
        
        private let cancelButtonTitle: ComponentView<Empty>
        private let cancelButton: HighlightTrackingButton
        
        private var placeholderContent = ComponentView<Empty>()
        
        private var textFrame: CGRect?
        private var textField: EmojiSearchTextField?
        
        private var tapRecognizer: UITapGestureRecognizer?
        
        private var params: Params?
        private var component: SearchBarContentComponent?
        
        public var wantsDisplayBelowKeyboard: Bool {
            return self.textField != nil
        }
        
        init() {
            self.backgroundLayer = SimpleLayer()
            
            self.iconView = UIImageView()
            
            self.clearIconView = UIImageView()
            self.clearIconButton = HighlightableButton()
            self.clearIconView.isHidden = true
            self.clearIconButton.isHidden = true
            
            self.cancelButtonTitle = ComponentView()
            self.cancelButton = HighlightTrackingButton()
            
            super.init(frame: CGRect())
            
            self.layer.addSublayer(self.backgroundLayer)
            
            self.addSubview(self.iconView)
            self.addSubview(self.clearIconView)
            self.addSubview(self.clearIconButton)
            
            self.addSubview(self.cancelButton)
            self.clipsToBounds = true
            
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
            self.tapRecognizer = tapRecognizer
            self.addGestureRecognizer(tapRecognizer)
            
            self.cancelButton.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        if let cancelButtonTitleView = strongSelf.cancelButtonTitle.view {
                            cancelButtonTitleView.layer.removeAnimation(forKey: "opacity")
                            cancelButtonTitleView.alpha = 0.4
                        }
                    } else {
                        if let cancelButtonTitleView = strongSelf.cancelButtonTitle.view {
                            cancelButtonTitleView.alpha = 1.0
                            cancelButtonTitleView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                        }
                    }
                }
            }
            self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
            
            self.clearIconButton.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.clearIconView.layer.removeAnimation(forKey: "opacity")
                        strongSelf.clearIconView.alpha = 0.4
                    } else {
                        strongSelf.clearIconView.alpha = 1.0
                        strongSelf.clearIconView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
            self.clearIconButton.addTarget(self, action: #selector(self.clearPressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.activateTextInput()
            }
        }

        private func activateTextInput() {
            if self.textField == nil, let textFrame = self.textFrame {
                let backgroundFrame = self.backgroundLayer.frame
                let textFieldFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - textFrame.minX, height: backgroundFrame.height))
                
                let textField = EmojiSearchTextField(frame: textFieldFrame)
                textField.autocorrectionType = .no
                textField.returnKeyType = .search
                self.textField = textField
                self.insertSubview(textField, belowSubview: self.clearIconView)
                textField.delegate = self
                textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
            }
            
            guard !(self.textField?.isFirstResponder ?? false) else {
                return
            }
                    
            self.activated(true)
            
            self.textField?.becomeFirstResponder()
        }
        
        @objc private func cancelPressed() {
            self.updateQuery(nil)
            
            self.clearIconView.isHidden = true
            self.clearIconButton.isHidden = true
                
            let textField = self.textField
            self.textField = nil
            
            self.deactivated(textField?.isFirstResponder ?? false)
            
            self.component?.performAction.invoke(.updateSearchActive(false))
            
            if let textField {
                textField.resignFirstResponder()
                textField.removeFromSuperview()
            }
        }
        
        @objc private func clearPressed() {
            self.updateQuery(nil)
            self.textField?.text = ""
            
            self.clearIconView.isHidden = true
            self.clearIconButton.isHidden = true
        }
        
        func deactivate() {
            if let text = self.textField?.text, !text.isEmpty {
                self.textField?.endEditing(true)
            } else {
                self.cancelPressed()
            }
        }
        
        public func textFieldDidBeginEditing(_ textField: UITextField) {
        }
        
        public func textFieldDidEndEditing(_ textField: UITextField) {
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.endEditing(true)
            return false
        }
        
        @objc private func textFieldChanged(_ textField: UITextField) {
            let text = textField.text ?? ""
            
            self.clearIconView.isHidden = text.isEmpty
            self.clearIconButton.isHidden = text.isEmpty
            self.placeholderContent.view?.isHidden = !text.isEmpty
            
            self.updateQuery(text)
            
            self.component?.performAction.invoke(.updateSearchQuery(text))
            
            if let params = self.params {
                self.update(theme: params.theme, strings: params.strings, size: params.size, transition: .immediate)
            }
        }
        
        func update(component: SearchBarContentComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            self.update(theme: component.theme, strings: component.strings, size: availableSize, transition: transition)
            self.activateTextInput()
            
            return availableSize
        }
        
        public func update(theme: PresentationTheme, strings: PresentationStrings, size: CGSize, transition: Transition) {
            let params = Params(
                theme: theme,
                strings: strings,
                size: size
            )
            
            if self.params == params {
                return
            }
            
            let isActiveWithText = true
            
            if self.params?.theme !== theme {
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Loupe"), color: .white)?.withRenderingMode(.alwaysTemplate)
                self.iconView.tintColor = theme.rootController.navigationSearchBar.inputIconColor
                self.clearIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: .white)?.withRenderingMode(.alwaysTemplate)
                self.clearIconView.tintColor = theme.rootController.navigationSearchBar.inputClearButtonColor
            }
            
            self.params = params
            
            let sideInset: CGFloat = 10.0
            let inputHeight: CGFloat = 36.0
            let topInset: CGFloat = (size.height - inputHeight) / 2.0
            
            let sideTextInset: CGFloat = sideInset + 4.0 + 17.0

            self.backgroundLayer.backgroundColor = theme.rootController.navigationSearchBar.inputFillColor.cgColor
            self.backgroundLayer.cornerRadius = 10.5
            
            let cancelTextSize = self.cancelButtonTitle.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: strings.Common_Cancel,
                    font: Font.regular(17.0),
                    color: theme.rootController.navigationBar.primaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: size.width - 32.0, height: 100.0)
            )
           
            let cancelButtonSpacing: CGFloat = 8.0
            
            var backgroundFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: CGSize(width: size.width - sideInset * 2.0, height: inputHeight))
            if isActiveWithText {
                backgroundFrame.size.width -= cancelTextSize.width + cancelButtonSpacing
            }
            transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
            
            transition.setFrame(view: self.cancelButton, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX, y: 0.0), size: CGSize(width: cancelButtonSpacing + cancelTextSize.width, height: size.height)))
            
            let textX: CGFloat = backgroundFrame.minX + sideTextInset
            let textFrame = CGRect(origin: CGPoint(x: textX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - textX, height: backgroundFrame.height))
            self.textFrame = textFrame
            
            if let image = self.iconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + 5.0, y: backgroundFrame.minY + floor((backgroundFrame.height - image.size.height) / 2.0)), size: image.size)
                transition.setFrame(view: self.iconView, frame: iconFrame)
            }
                    
            let placeholderSize = self.placeholderContent.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: strings.Common_Search, font: Font.regular(17.0), color: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
                ),
                environment: {},
                containerSize: size
            )
            if let placeholderContentView = self.placeholderContent.view {
                if placeholderContentView.superview == nil {
                    self.addSubview(placeholderContentView)
                }
                let placeholderContentFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: backgroundFrame.midY - placeholderSize.height / 2.0), size: placeholderSize)
                transition.setFrame(view: placeholderContentView, frame: placeholderContentFrame)
            }
            
            if let image = self.clearIconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - image.size.width - 4.0, y: backgroundFrame.minY + floor((backgroundFrame.height - image.size.height) / 2.0)), size: image.size)
                transition.setFrame(view: self.clearIconView, frame: iconFrame)
                transition.setFrame(view: self.clearIconButton, frame: iconFrame.insetBy(dx: -8.0, dy: -10.0))
            }
            
            if let cancelButtonTitleComponentView = self.cancelButtonTitle.view {
                if cancelButtonTitleComponentView.superview == nil {
                    self.addSubview(cancelButtonTitleComponentView)
                    cancelButtonTitleComponentView.isUserInteractionEnabled = false
                }
                transition.setFrame(view: cancelButtonTitleComponentView, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX + cancelButtonSpacing, y: floor((size.height - cancelTextSize.height) / 2.0)), size: cancelTextSize))
            }

            if let textField = self.textField {
                textField.textColor = theme.rootController.navigationSearchBar.inputTextColor
                transition.setFrame(view: textField, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + sideTextInset, y: backgroundFrame.minY - UIScreenPixel), size: CGSize(width: backgroundFrame.width - sideTextInset - 32.0, height: backgroundFrame.height)))
            }
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
