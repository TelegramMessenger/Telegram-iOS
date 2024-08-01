import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import BundleIconComponent
import MultilineTextComponent
import UrlEscaping

final class AddressBarContentComponent: Component {
    public typealias EnvironmentType = BrowserNavigationBarEnvironment
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let metrics: LayoutMetrics
    let url: String
    let isSecure: Bool
    let isExpanded: Bool
    let performAction: ActionSlot<BrowserScreen.Action>
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        metrics: LayoutMetrics,
        url: String,
        isSecure: Bool,
        isExpanded: Bool,
        performAction: ActionSlot<BrowserScreen.Action>
    ) {
        self.theme = theme
        self.strings = strings
        self.metrics = metrics
        self.url = url
        self.isSecure = isSecure
        self.isExpanded = isExpanded
        self.performAction = performAction
    }
    
    static func ==(lhs: AddressBarContentComponent, rhs: AddressBarContentComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.url != rhs.url {
            return false
        }
        if lhs.isSecure != rhs.isSecure {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        return true
    }

    final class View: UIView, UITextFieldDelegate {
        private final class TextField: UITextField {
            override func textRect(forBounds bounds: CGRect) -> CGRect {
                return bounds.integral
            }
            
            override var canBecomeFirstResponder: Bool {
                var canBecomeFirstResponder = super.canBecomeFirstResponder
                if !canBecomeFirstResponder && self.alpha.isZero {
                    canBecomeFirstResponder = true
                }
                return canBecomeFirstResponder
            }
        }
        
        private struct Params: Equatable {
            var theme: PresentationTheme
            var strings: PresentationStrings
            var size: CGSize
            var isActive: Bool
            var title: String
            var isSecure: Bool
            var collapseFraction: CGFloat
            var isTablet: Bool
            
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
                if lhs.isActive != rhs.isActive {
                    return false
                }
                if lhs.title != rhs.title {
                    return false
                }
                if lhs.isSecure != rhs.isSecure {
                    return false
                }
                if lhs.collapseFraction != rhs.collapseFraction {
                    return false
                }
                if lhs.isTablet != rhs.isTablet {
                    return false
                }
                return true
            }
        }
        
        private let activated: (Bool) -> Void = { _ in }
        private let deactivated: (Bool) -> Void = { _ in }
    
        private let backgroundLayer: SimpleLayer
        
        private let iconView: UIImageView
        
        private let clearIconView: UIImageView
        private let clearIconButton: HighlightTrackingButton
        
        private let cancelButtonTitle: ComponentView<Empty>
        private let cancelButton: HighlightTrackingButton
        
        private var placeholderContent = ComponentView<Empty>()
        private var titleContent = ComponentView<Empty>()
        
        private var textFrame: CGRect?
        private var textField: TextField?
                
        private var tapRecognizer: UITapGestureRecognizer?
        
        private var params: Params?
        private var component: AddressBarContentComponent?
        
        public var wantsDisplayBelowKeyboard: Bool {
            return self.textField != nil
        }
        
        init() {
            self.backgroundLayer = SimpleLayer()
            
            self.iconView = UIImageView()
            
            self.clearIconView = UIImageView()
            self.clearIconButton = HighlightableButton()
            self.clearIconView.isHidden = false
            self.clearIconButton.isHidden = false
            
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
            if case .ended = recognizer.state, let component = self.component, !component.isExpanded {
                component.performAction.invoke(.openAddressBar)
            }
        }

        private func activateTextInput() {
            self.activated(true)
            if let textField = self.textField {
                textField.becomeFirstResponder()
                Queue.mainQueue().after(0.3, {
                    textField.selectAll(nil)
                })
            }
        }
        
        private func deactivateTextInput() {
            self.textField?.endEditing(true)
        }
        
        @objc private func cancelPressed() {
            self.deactivated(self.textField?.isFirstResponder ?? false)
            
            self.component?.performAction.invoke(.closeAddressBar)
        }
        
        @objc private func clearPressed() {
            guard let textField = self.textField else {
                return
            }
            textField.text = ""
            self.textFieldChanged(textField)
        }
                
        public func textFieldDidBeginEditing(_ textField: UITextField) {
        }
        
        public func textFieldDidEndEditing(_ textField: UITextField) {
        }
                
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let component = self.component {
                let finalUrl = explicitUrl(textField.text ?? "")
                component.performAction.invoke(.navigateTo(finalUrl, true))
            }
            textField.endEditing(true)
            return false
        }
        
        @objc private func textFieldChanged(_ textField: UITextField) {
            let text = textField.text ?? ""
            
            self.clearIconView.isHidden = text.isEmpty
            self.clearIconButton.isHidden = text.isEmpty
            self.placeholderContent.view?.isHidden = !text.isEmpty
            
            if let params = self.params {
                self.update(theme: params.theme, strings: params.strings, size: params.size, isActive: params.isActive, title: params.title, isSecure: params.isSecure, collapseFraction: params.collapseFraction, isTablet: params.isTablet, transition: .immediate)
            }
        }
        
        func update(component: AddressBarContentComponent, availableSize: CGSize, environment: Environment<BrowserNavigationBarEnvironment>, transition: ComponentTransition) -> CGSize {
            let collapseFraction = environment[BrowserNavigationBarEnvironment.self].fraction
            
            let wasExpanded = self.component?.isExpanded ?? false
            self.component = component
            
            if !wasExpanded && component.isExpanded {
                self.activateTextInput()
            }
            if wasExpanded && !component.isExpanded {
                self.deactivateTextInput()
            }
            let isActive = self.textField?.isFirstResponder ?? false
            
            let title = getDisplayUrl(component.url, hostOnly: true)
            self.update(theme: component.theme, strings: component.strings, size: availableSize, isActive: isActive, title: title.lowercased(), isSecure: component.isSecure, collapseFraction: collapseFraction, isTablet: component.metrics.isTablet, transition: transition)
            
            return availableSize
        }
        
        public func update(theme: PresentationTheme, strings: PresentationStrings, size: CGSize, isActive: Bool, title: String, isSecure: Bool, collapseFraction: CGFloat, isTablet: Bool, transition: ComponentTransition) {
            let params = Params(
                theme: theme,
                strings: strings,
                size: size,
                isActive: isActive,
                title: title,
                isSecure: isSecure,
                collapseFraction: collapseFraction,
                isTablet: isTablet
            )
            
            if self.params == params {
                return
            }
            
            let isActiveWithText = self.component?.isExpanded ?? false
            
            if self.params?.theme !== theme {
                self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Media Grid/Lock"), color: .white)?.withRenderingMode(.alwaysTemplate)
                self.iconView.tintColor = theme.rootController.navigationSearchBar.inputIconColor
                self.clearIconView.image = generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: .white)?.withRenderingMode(.alwaysTemplate)
                self.clearIconView.tintColor = theme.rootController.navigationSearchBar.inputClearButtonColor
            }
            
            self.params = params
            
            let sideInset: CGFloat = 10.0
            let inputHeight: CGFloat = 36.0
            let topInset: CGFloat = (size.height - inputHeight) / 2.0
            
            self.backgroundLayer.backgroundColor = theme.rootController.navigationSearchBar.inputFillColor.cgColor
            self.backgroundLayer.cornerRadius = 10.5
            transition.setAlpha(layer: self.backgroundLayer, alpha: max(0.0, min(1.0, 1.0 - collapseFraction * 1.5)))
            
            let cancelTextSize = self.cancelButtonTitle.update(
                transition: .immediate,
                component: AnyComponent(Text(
                    text: strings.Common_Cancel,
                    font: Font.regular(17.0),
                    color: theme.rootController.navigationBar.accentTextColor
                )),
                environment: {},
                containerSize: CGSize(width: size.width - 32.0, height: 100.0)
            )
           
            let cancelButtonSpacing: CGFloat = 8.0
            
            var backgroundFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset), size: CGSize(width: size.width - sideInset * 2.0, height: inputHeight))
            if isActiveWithText && !isTablet {
                backgroundFrame.size.width -= cancelTextSize.width + cancelButtonSpacing
            }
            transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
            
            transition.setFrame(view: self.cancelButton, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX, y: 0.0), size: CGSize(width: cancelButtonSpacing + cancelTextSize.width, height: size.height)))
            self.cancelButton.isUserInteractionEnabled = isActiveWithText && !isTablet
            
            let textX: CGFloat = backgroundFrame.minX + sideInset
            let textFrame = CGRect(origin: CGPoint(x: textX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - textX, height: backgroundFrame.height))
                                
            let placeholderSize = self.placeholderContent.update(
                transition: transition,
                component: AnyComponent(
                    Text(text: strings.WebBrowser_AddressPlaceholder, font: Font.regular(17.0), color: theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
                ),
                environment: {},
                containerSize: size
            )
            if let placeholderContentView = self.placeholderContent.view {
                if placeholderContentView.superview == nil {
                    placeholderContentView.alpha = 0.0
                    placeholderContentView.isHidden = true
                    self.addSubview(placeholderContentView)
                }
                let placeholderContentFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: backgroundFrame.midY - placeholderSize.height / 2.0), size: placeholderSize)
                transition.setFrame(view: placeholderContentView, frame: placeholderContentFrame)
                transition.setAlpha(view: placeholderContentView, alpha: isActiveWithText ? 1.0 : 0.0)
            }
            
            let titleSize = self.titleContent.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: title, font: Font.regular(17.0), textColor: theme.rootController.navigationSearchBar.inputTextColor)),
                        horizontalAlignment: .center,
                        truncationType: .end,
                        maximumNumberOfLines: 1
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - 36.0, height: size.height)
            )
            var titleContentFrame = CGRect(origin: CGPoint(x: isActiveWithText ? textFrame.minX : backgroundFrame.midX - titleSize.width / 2.0, y: backgroundFrame.midY - titleSize.height / 2.0), size: titleSize)
            if isSecure && !isActiveWithText {
                titleContentFrame.origin.x += 7.0
            }
            var titleSizeChanged = false
            if let titleContentView = self.titleContent.view {
                if titleContentView.superview == nil {
                    self.addSubview(titleContentView)
                }
                if titleContentView.frame.width != titleContentFrame.size.width {
                    titleSizeChanged = true
                }
                transition.setPosition(view: titleContentView, position: titleContentFrame.center)
                titleContentView.bounds = CGRect(origin: .zero, size: titleContentFrame.size)
                transition.setAlpha(view: titleContentView, alpha: isActiveWithText ? 0.0 : 1.0)
            }
            
            if let image = self.iconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: titleContentFrame.minX - image.size.width - 3.0, y: backgroundFrame.minY + floor((backgroundFrame.height - image.size.height) / 2.0)), size: image.size)
                var iconTransition = transition
                if titleSizeChanged {
                    iconTransition = .immediate
                }
                iconTransition.setFrame(view: self.iconView, frame: iconFrame)
                transition.setAlpha(view: self.iconView, alpha: isActiveWithText || !isSecure ? 0.0 : 1.0)
            }
            
            if let image = self.clearIconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - image.size.width - 4.0, y: backgroundFrame.minY + floor((backgroundFrame.height - image.size.height) / 2.0)), size: image.size)
                transition.setFrame(view: self.clearIconView, frame: iconFrame)
                transition.setFrame(view: self.clearIconButton, frame: iconFrame.insetBy(dx: -8.0, dy: -10.0))
                transition.setAlpha(view: self.clearIconView, alpha: isActiveWithText ? 1.0 : 0.0)
                self.clearIconButton.isUserInteractionEnabled = isActiveWithText
            }
            
            if let cancelButtonTitleComponentView = self.cancelButtonTitle.view {
                if cancelButtonTitleComponentView.superview == nil {
                    self.addSubview(cancelButtonTitleComponentView)
                    cancelButtonTitleComponentView.isUserInteractionEnabled = false
                }
                transition.setFrame(view: cancelButtonTitleComponentView, frame: CGRect(origin: CGPoint(x: backgroundFrame.maxX + cancelButtonSpacing, y: floor((size.height - cancelTextSize.height) / 2.0)), size: cancelTextSize))
                transition.setAlpha(view: cancelButtonTitleComponentView, alpha: isActiveWithText && !isTablet ? 1.0 : 0.0)
            }
                        
            let textFieldFrame = CGRect(origin: CGPoint(x: textFrame.minX, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.maxX - textFrame.minX, height: backgroundFrame.height))
            
            let textField: TextField
            if let current = self.textField {
                textField = current
            } else {
                textField = TextField(frame: textFieldFrame)
                textField.autocapitalizationType = .none
                textField.autocorrectionType = .no
                textField.keyboardType = .URL
                textField.returnKeyType = .go
                self.insertSubview(textField, belowSubview: self.clearIconView)
                self.textField = textField
                
                textField.delegate = self
                textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
            }
            
            let address = getDisplayUrl(self.component?.url ?? "", trim: false)
            if textField.text != address {
                textField.text = address
                self.clearIconView.isHidden = address.isEmpty
                self.clearIconButton.isHidden = address.isEmpty
                self.placeholderContent.view?.isHidden = !address.isEmpty
            }
            
            textField.textColor = theme.rootController.navigationSearchBar.inputTextColor
            transition.setFrame(view: textField, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + sideInset, y: backgroundFrame.minY - UIScreenPixel), size: CGSize(width: backgroundFrame.width - sideInset - 32.0, height: backgroundFrame.height)))
            transition.setAlpha(view: textField, alpha: isActiveWithText ? 1.0 : 0.0)
            textField.isUserInteractionEnabled = isActiveWithText
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<BrowserNavigationBarEnvironment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}
