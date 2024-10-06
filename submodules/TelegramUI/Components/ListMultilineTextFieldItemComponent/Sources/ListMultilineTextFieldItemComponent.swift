import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramPresentationData
import MultilineTextComponent
import ListSectionComponent
import TextFieldComponent
import LottieComponent
import PlainButtonComponent
import AccountContext

public final class ListMultilineTextFieldItemComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var hasText: Bool = false
        public fileprivate(set) var text: NSAttributedString = NSAttributedString()
        public fileprivate(set) var isEditing: Bool = false
        
        public var hasTrackingView = false
        
        public var currentEmojiSuggestion: TextFieldComponent.EmojiSuggestion?
        public var dismissedEmojiSuggestionPosition: TextFieldComponent.EmojiSuggestion.Position?
        
        public init() {
        }
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
    
    public enum InputMode {
        case keyboard
        case emoji
    }
        
    public enum EmptyLineHandling {
        case allowed
        case oneConsecutive
        case notAllowed
    }
    
    public let externalState: ExternalState?
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let initialText: String
    public let resetText: ResetText?
    public let placeholder: String
    public let autocapitalizationType: UITextAutocapitalizationType
    public let autocorrectionType: UITextAutocorrectionType
    public let returnKeyType: UIReturnKeyType
    public let characterLimit: Int?
    public let displayCharacterLimit: Bool
    public let emptyLineHandling: EmptyLineHandling
    public let formatMenuAvailability: TextFieldComponent.FormatMenuAvailability
    public let updated: ((String) -> Void)?
    public let returnKeyAction: (() -> Void)?
    public let backspaceKeyAction: (() -> Void)?
    public let textUpdateTransition: ComponentTransition
    public let inputMode: InputMode?
    public let toggleInputMode: (() -> Void)?
    public let tag: AnyObject?
    
    public init(
        externalState: ExternalState? = nil,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        initialText: String,
        resetText: ResetText? = nil,
        placeholder: String,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default,
        returnKeyType: UIReturnKeyType = .default,
        characterLimit: Int? = nil,
        displayCharacterLimit: Bool = false,
        emptyLineHandling: EmptyLineHandling = .allowed,
        formatMenuAvailability: TextFieldComponent.FormatMenuAvailability = .none,
        updated: ((String) -> Void)? = nil,
        returnKeyAction: (() -> Void)? = nil,
        backspaceKeyAction: (() -> Void)? = nil,
        textUpdateTransition: ComponentTransition = .immediate,
        inputMode: InputMode? = nil,
        toggleInputMode: (() -> Void)? = nil,
        tag: AnyObject? = nil
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.initialText = initialText
        self.resetText = resetText
        self.placeholder = placeholder
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.returnKeyType = returnKeyType
        self.characterLimit = characterLimit
        self.displayCharacterLimit = displayCharacterLimit
        self.emptyLineHandling = emptyLineHandling
        self.formatMenuAvailability = formatMenuAvailability
        self.updated = updated
        self.returnKeyAction = returnKeyAction
        self.backspaceKeyAction = backspaceKeyAction
        self.textUpdateTransition = textUpdateTransition
        self.inputMode = inputMode
        self.toggleInputMode = toggleInputMode
        self.tag = tag
    }
    
    public static func ==(lhs: ListMultilineTextFieldItemComponent, rhs: ListMultilineTextFieldItemComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.initialText != rhs.initialText {
            return false
        }
        if lhs.resetText != rhs.resetText {
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
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.displayCharacterLimit != rhs.displayCharacterLimit {
            return false
        }
        if lhs.emptyLineHandling != rhs.emptyLineHandling {
            return false
        }
        if lhs.formatMenuAvailability != rhs.formatMenuAvailability {
            return false
        }
        if (lhs.updated == nil) != (rhs.updated == nil) {
            return false
        }
        if lhs.inputMode != rhs.inputMode {
            return false
        }
        return true
    }
    
    public final class View: UIView, ListSectionComponent.ChildView, ComponentTaggedView {
        private let textField = ComponentView<Empty>()
        private let textFieldExternalState = TextFieldComponent.ExternalState()
        
        private var modeSelector: ComponentView<Empty>?
        
        private let placeholder = ComponentView<Empty>()
        private var customPlaceholder: ComponentView<Empty>?
        
        private var measureTextLimitLabel: ComponentView<Empty>?
        private var textLimitLabel: ComponentView<Empty>?
        
        private var component: ListMultilineTextFieldItemComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        public var currentText: String {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.inputState.inputText.string
            } else {
                return ""
            }
        }
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        
        public override init(frame: CGRect) {
            super.init(frame: CGRect())
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        public func setText(text: String, updateState: Bool) {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                //TODO
                let _ = textFieldView
            }
            
            if updateState {
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
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.activateInput()
            }
        }
        
        public func insertText(text: NSAttributedString) {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.insertText(text)
            }
        }
        
        public func backwardsDeleteText() {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                textFieldView.deleteBackward()
            }
        }
        
        public var textFieldView: TextFieldComponent.View? {
            return self.textField.view as? TextFieldComponent.View
        }
        
        func update(component: ListMultilineTextFieldItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let verticalInset: CGFloat = 12.0
            let leftInset: CGFloat = 16.0
            var rightInset: CGFloat = 16.0
            let modeSelectorSize = CGSize(width: 32.0, height: 32.0)
            
            if component.inputMode != nil {
                rightInset += 34.0
            }
            
            let textLimitFont = Font.regular(15.0)
            var measureTextLimitInset: CGFloat = 0.0
            if component.characterLimit != nil && component.displayCharacterLimit {
                let measureTextLimitLabel: ComponentView<Empty>
                if let current = self.measureTextLimitLabel {
                    measureTextLimitLabel = current
                } else {
                    measureTextLimitLabel = ComponentView()
                    self.measureTextLimitLabel = measureTextLimitLabel
                }
                let measureTextLimitSize = measureTextLimitLabel.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "000", font: textLimitFont))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                measureTextLimitInset = measureTextLimitSize.width + 4.0
            } else {
                self.measureTextLimitLabel = nil
            }
            
            let mappedEmptyLineHandling: TextFieldComponent.EmptyLineHandling
            switch component.emptyLineHandling {
            case .allowed:
                mappedEmptyLineHandling = .allowed
            case .oneConsecutive:
                mappedEmptyLineHandling = .oneConsecutive
            case .notAllowed:
                mappedEmptyLineHandling = .notAllowed
            }
            
            let textFieldSize = self.textField.update(
                transition: transition,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    externalState: self.textFieldExternalState,
                    fontSize: 17.0,
                    textColor: component.theme.list.itemPrimaryTextColor,
                    accentColor: component.theme.list.itemPrimaryTextColor,
                    insets: UIEdgeInsets(top: verticalInset, left: leftInset - 8.0, bottom: verticalInset, right: rightInset - 8.0 + measureTextLimitInset),
                    hideKeyboard: component.inputMode == .emoji,
                    customInputView: nil,
                    resetText: component.resetText.flatMap { resetText in
                        return NSAttributedString(string: resetText.value, font: Font.regular(17.0), textColor: component.theme.list.itemPrimaryTextColor)
                    },
                    isOneLineWhenUnfocused: false,
                    characterLimit: component.characterLimit,
                    emptyLineHandling: mappedEmptyLineHandling,
                    formatMenuAvailability: component.formatMenuAvailability,
                    returnKeyType: component.returnKeyType,
                    lockedFormatAction: {
                    },
                    present: { _ in
                    },
                    paste: { _ in
                    },
                    returnKeyAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.returnKeyAction?()
                    },
                    backspaceKeyAction: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.backspaceKeyAction?()
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let size = CGSize(width: textFieldSize.width, height: textFieldSize.height - 1.0)
            let textFieldFrame = CGRect(origin: CGPoint(), size: textFieldSize)
            
            if let textFieldView = self.textField.view {
                if textFieldView.superview == nil {
                    self.addSubview(textFieldView)
                    self.textField.parentState = state
                }
                transition.setFrame(view: textFieldView, frame: textFieldFrame)
            }
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.placeholder.isEmpty ? " " : component.placeholder, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            let placeholderFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: placeholderSize)
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.layer.anchorPoint = CGPoint()
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, at: 0)
                }
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                
                placeholderView.isHidden = self.textFieldExternalState.hasText
            }
            
            self.separatorInset = 16.0
            
            component.externalState?.hasText = self.textFieldExternalState.hasText
            component.externalState?.text = self.textFieldExternalState.text
            component.externalState?.isEditing = self.textFieldExternalState.isEditing
            component.externalState?.currentEmojiSuggestion = self.textFieldExternalState.currentEmojiSuggestion
            component.externalState?.dismissedEmojiSuggestionPosition = self.textFieldExternalState.dismissedEmojiSuggestionPosition
            component.externalState?.hasTrackingView = self.textFieldExternalState.hasTrackingView
            
            var displayRemainingLimit: Int?
            if let characterLimit = component.characterLimit, component.displayCharacterLimit {
                let remainingLimit = characterLimit - self.textFieldExternalState.text.length
                let displayThreshold = max(10, Int(Double(characterLimit) * 0.15))
                if remainingLimit <= displayThreshold {
                    displayRemainingLimit = remainingLimit
                }
            }
            if let displayRemainingLimit {
                let textLimitLabel: ComponentView<Empty>
                var textLimitLabelTransition = transition
                if let current = self.textLimitLabel {
                    textLimitLabel = current
                } else {
                    textLimitLabelTransition = textLimitLabelTransition.withAnimation(.none)
                    textLimitLabel = ComponentView()
                    self.textLimitLabel = textLimitLabel
                }
                
                let textLimitLabelSize = textLimitLabel.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(displayRemainingLimit)", font: textLimitFont, textColor: component.theme.list.itemSecondaryTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let textLimitLabelFrame = CGRect(origin: CGPoint(x: availableSize.width - textLimitLabelSize.width - leftInset + 5.0, y: verticalInset + 2.0), size: textLimitLabelSize)
                if let textLimitLabelView = textLimitLabel.view {
                    if textLimitLabelView.superview == nil {
                        textLimitLabelView.isUserInteractionEnabled = false
                        textLimitLabelView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
                        self.addSubview(textLimitLabelView)
                    }
                    textLimitLabelTransition.setPosition(view: textLimitLabelView, position: CGPoint(x: textLimitLabelFrame.maxX, y: textLimitLabelFrame.minY))
                    textLimitLabelView.bounds = CGRect(origin: CGPoint(), size: textLimitLabelFrame.size)
                }
            } else {
                if let textLimitLabel = self.textLimitLabel {
                    self.textLimitLabel = nil
                    textLimitLabel.view?.removeFromSuperview()
                }
            }
            
            if let inputMode = component.inputMode {
                var modeSelectorTransition = transition
                let modeSelector: ComponentView<Empty>
                if let current = self.modeSelector {
                    modeSelector = current
                } else {
                    modeSelectorTransition = modeSelectorTransition.withAnimation(.none)
                    modeSelector = ComponentView()
                    self.modeSelector = modeSelector
                }
                let animationName: String
                var playAnimation = false
                if let previousComponent, let previousInputMode = previousComponent.inputMode {
                    if previousInputMode != inputMode {
                        playAnimation = true
                    }
                }
                switch inputMode {
                case .keyboard:
                    animationName = "input_anim_keyToSmile"
                case .emoji:
                    animationName = "input_anim_smileToKey"
                }
                
                let _ = modeSelector.update(
                    transition: modeSelectorTransition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(LottieComponent(
                            content: LottieComponent.AppBundleContent(
                                name: animationName
                            ),
                            color: component.theme.chat.inputPanel.inputControlColor.blitOver(component.theme.list.itemBlocksBackgroundColor, alpha: 1.0),
                            size: modeSelectorSize
                        )),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.toggleInputMode?()
                        },
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: modeSelectorSize
                )
                let modeSelectorFrame = CGRect(origin: CGPoint(x: size.width - 4.0 - modeSelectorSize.width, y: floor((size.height - modeSelectorSize.height) * 0.5)), size: modeSelectorSize)
                if let modeSelectorView = modeSelector.view as? PlainButtonComponent.View {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    
                    if modeSelectorView.superview == nil {
                        self.addSubview(modeSelectorView)
                        ComponentTransition.immediate.setAlpha(view: modeSelectorView, alpha: 0.0)
                        ComponentTransition.immediate.setScale(view: modeSelectorView, scale: 0.001)
                    }
                    
                    if playAnimation, let animationView = modeSelectorView.contentView as? LottieComponent.View {
                        animationView.playOnce()
                    }
                    
                    modeSelectorTransition.setPosition(view: modeSelectorView, position: modeSelectorFrame.center)
                    modeSelectorTransition.setBounds(view: modeSelectorView, bounds: CGRect(origin: CGPoint(), size: modeSelectorFrame.size))
                    
                    if let externalState = component.externalState {
                        let displaySelector = externalState.isEditing
                        
                        alphaTransition.setAlpha(view: modeSelectorView, alpha: displaySelector ? 1.0 : 0.0)
                        alphaTransition.setScale(view: modeSelectorView, scale: displaySelector ? 1.0 : 0.001)
                    }
                }
            } else if let modeSelector = self.modeSelector {
                self.modeSelector = nil
                if let modeSelectorView = modeSelector.view {
                    if !transition.animation.isImmediate {
                        let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        alphaTransition.setAlpha(view: modeSelectorView, alpha: 0.0, completion: { [weak modeSelectorView] _ in
                            modeSelectorView?.removeFromSuperview()
                        })
                        alphaTransition.setScale(view: modeSelectorView, scale: 0.001)
                    } else {
                        modeSelectorView.removeFromSuperview()
                    }
                }
            }
            
            return size
        }
        
        public func updateCustomPlaceholder(value: String, size: CGSize, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            
            let verticalInset: CGFloat = 12.0
            let sideInset: CGFloat = 16.0
            
            if !value.isEmpty {
                let customPlaceholder: ComponentView<Empty>
                var customPlaceholderTransition = transition
                if let current = self.customPlaceholder {
                    customPlaceholder = current
                } else {
                    customPlaceholderTransition = customPlaceholderTransition.withAnimation(.none)
                    customPlaceholder = ComponentView()
                    self.customPlaceholder = customPlaceholder
                }
                
                let placeholderSize = customPlaceholder.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: value.isEmpty ? " " : value, font: Font.regular(17.0), textColor: component.theme.list.itemPlaceholderTextColor))
                    )),
                    environment: {},
                    containerSize: CGSize(width: size.width - sideInset * 2.0, height: 100.0)
                )
                let placeholderFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: placeholderSize)
                if let placeholderView = customPlaceholder.view {
                    if placeholderView.superview == nil {
                        placeholderView.layer.anchorPoint = CGPoint()
                        placeholderView.isUserInteractionEnabled = false
                        self.insertSubview(placeholderView, at: 0)
                    }
                    transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                    placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                    
                    placeholderView.isHidden = self.textFieldExternalState.hasText
                }
            } else if let customPlaceholder = self.customPlaceholder {
                self.customPlaceholder = nil
                customPlaceholder.view?.removeFromSuperview()
            }
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
