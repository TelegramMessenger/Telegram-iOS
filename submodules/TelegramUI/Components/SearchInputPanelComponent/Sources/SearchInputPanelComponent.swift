import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import AppBundle
import BundleIconComponent
import TelegramPresentationData
import MultilineTextComponent
import PlainButtonComponent
import GlassBackgroundComponent
import GlassBarButtonComponent
import EdgeEffect

public final class SearchInputPanelComponent: Component {    
    public final class ResetText: Equatable {
        public let value: String
        
        public init(value: String) {
            self.value = value
        }
        
        public static func ==(lhs: ResetText, rhs: ResetText) -> Bool {
            return lhs === rhs
        }
    }
    
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let metrics: LayoutMetrics
    public let safeInsets: UIEdgeInsets
    public let placeholder: String?
    public let resetText: ResetText?
    public let hasEdgeEffect: Bool
    public let updated: ((String) -> Void)
    public let cancel: () -> Void

    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        metrics: LayoutMetrics,
        safeInsets: UIEdgeInsets,
        placeholder: String? = nil,
        resetText: ResetText? = nil,
        hasEdgeEffect: Bool = true,
        updated: @escaping ((String) -> Void),
        cancel: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.metrics = metrics
        self.safeInsets = safeInsets
        self.placeholder = placeholder
        self.resetText = resetText
        self.hasEdgeEffect = hasEdgeEffect
        self.updated = updated
        self.cancel = cancel
    }
    
    public static func ==(lhs: SearchInputPanelComponent, rhs: SearchInputPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.metrics != rhs.metrics {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.resetText != rhs.resetText {
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
        private let edgeEffectView: EdgeEffectView
        private let containerView: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        
        private let icon = ComponentView<Empty>()
        private var placeholder = ComponentView<Empty>()
        
        private let textField: TextField
        private let clearButton = ComponentView<Empty>()
        
        private let cancelButton = ComponentView<Empty>()
                
        private var component: SearchInputPanelComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        public var currentText: String {
            return self.textField.text ?? ""
        }
                
        override init(frame: CGRect) {
            self.edgeEffectView = EdgeEffectView()
            
            self.containerView = GlassBackgroundContainerView()
            self.backgroundView = GlassBackgroundView()
            self.textField = TextField()
            
            super.init(frame: frame)
            
            self.addSubview(self.edgeEffectView)
            self.addSubview(self.containerView)
            self.containerView.contentView.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func textDidChange() {
            if !self.isUpdating {
                self.state?.updated(transition: .immediate)
            }
            self.component?.updated(self.currentText)
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if !self.currentText.isEmpty {
                self.textField.resignFirstResponder()
            }
            
            return true
        }
        
        public func setText(text: String, updateState: Bool) {
            self.textField.text = text
            if updateState {
                self.state?.updated(transition: .immediate, isLocal: true)
                self.component?.updated(self.currentText)
            } else {
                self.state?.updated(transition: .immediate, isLocal: true)
            }
        }
        
        public func activateInput() {
            self.textField.becomeFirstResponder()
        }
        
        public func deactivateInput() -> Bool {
            self.textField.resignFirstResponder()
            
            return self.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        func update(component: SearchInputPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            if self.textField.superview == nil {
                self.addSubview(self.textField)
                
                self.textField.accessibilityTraits = .searchField
                self.textField.autocorrectionType = .no
                self.textField.autocapitalizationType = .sentences
                self.textField.enablesReturnKeyAutomatically = true
                self.textField.returnKeyType = .search
                self.textField.delegate = self
                self.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
            }
            
            let themeUpdated = component.theme !== previousComponent?.theme
            
            if themeUpdated {
                self.textField.font = Font.regular(17.0)
                self.textField.textColor = component.theme.list.itemPrimaryTextColor
                self.textField.keyboardAppearance = component.theme.overallDarkAppearance ? .dark : .light
            }
        
            let backgroundColor = component.theme.list.plainBackgroundColor.withMultipliedAlpha(0.75)
            
            var edgeInsets = UIEdgeInsets(top: 10.0, left: 11.0 + component.safeInsets.left, bottom: 10.0, right: 11.0 + component.safeInsets.right)
            if case .regular = component.metrics.widthClass {
                edgeInsets.bottom += 18.0
            }
            let fieldHeight: CGFloat = 48.0
            let buttonSpacing: CGFloat = 10.0
            
            let fieldFrame = CGRect(origin: CGPoint(x: edgeInsets.left, y: edgeInsets.top), size: CGSize(width: availableSize.width - edgeInsets.left - edgeInsets.right - fieldHeight - buttonSpacing, height: fieldHeight))
            let cancelButtonFrame = CGRect(origin: CGPoint(x: edgeInsets.left + fieldFrame.width + buttonSpacing, y: edgeInsets.top), size: CGSize(width: fieldHeight, height: fieldHeight))
            
            self.backgroundView.update(size: fieldFrame.size, cornerRadius: fieldFrame.height * 0.5, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: fieldFrame)
        
            let fieldSideInset: CGFloat = 41.0
            self.textField.sideInset = fieldSideInset
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(name: "Components/Search Bar/Loupe", tintColor: component.theme.list.itemPrimaryTextColor)),
                environment: {},
                containerSize: CGSize(width: availableSize.width - fieldSideInset * 2.0 - 30.0, height: 100.0)
            )

            let iconFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + 11.0, y: fieldFrame.minY + floor((fieldFrame.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.layer.anchorPoint = CGPoint()
                    iconView.isUserInteractionEnabled = false
                    self.insertSubview(iconView, belowSubview: self.textField)
                }
                transition.setPosition(view: iconView, position: iconFrame.origin)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.placeholder ?? component.strings.Common_Search, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.6)))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - fieldSideInset * 2.0 - 30.0, height: 100.0)
            )

            let placeholderFrame = CGRect(origin: CGPoint(x: fieldFrame.minX + fieldSideInset, y: fieldFrame.minY + floor((fieldFrame.height - placeholderSize.height) * 0.5)), size: placeholderSize)
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
            
            transition.setFrame(view: self.textField, frame: fieldFrame)
            
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
                transition.setFrame(view: clearButtonView, frame: CGRect(origin: CGPoint(x: fieldFrame.maxX - clearButtonSize.width, y: fieldFrame.minY + floor((fieldFrame.height - clearButtonSize.height) * 0.5)), size: clearButtonSize))
                clearButtonView.isHidden = self.currentText.isEmpty
            }
            
            let _ = self.cancelButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: cancelButtonFrame.size,
                    backgroundColor: backgroundColor,
                    isDark: component.theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: component.theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = self.deactivateInput()
                        component.cancel()
                    }
                )),
                environment: {},
                containerSize: cancelButtonFrame.size
            )
            if let cancelButtonView = self.cancelButton.view {
                if cancelButtonView.superview == nil {
                    self.containerView.contentView.addSubview(cancelButtonView)
                }
                transition.setFrame(view: cancelButtonView, frame: cancelButtonFrame)
            }
            
            let size = CGSize(width: availableSize.width, height: edgeInsets.top + fieldHeight + edgeInsets.bottom)
            
            let edgeColor: UIColor = component.theme.overallDarkAppearance ? .clear : UIColor(rgb: 0x000000, alpha: 0.25)
            
            let edgeEffectHeight: CGFloat = 88.0 + 30.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - edgeEffectHeight + 30.0), size: CGSize(width: size.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: edgeColor, blur: true, rect: edgeEffectFrame, edge: .bottom, edgeSize: edgeEffectFrame.height, transition: transition)
            self.edgeEffectView.isHidden = !component.hasEdgeEffect
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: size))
            self.containerView.update(size: size, isDark: component.theme.overallDarkAppearance, transition: transition)
 
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
