import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import CheckNode
import ListSectionComponent
import ComponentFlow
import TextFieldComponent
import AccountContext
import MultilineTextComponent
import PresentationDataUtils
import LottieComponent
import PlainButtonComponent
import SwiftSignalKit

public final class ListComposePollOptionComponent: Component {
    public final class ResetText: Equatable {
        public let value: NSAttributedString
        
        public init(value: NSAttributedString) {
            self.value = value
        }
        
        public static func ==(lhs: ResetText, rhs: ResetText) -> Bool {
            return lhs === rhs
        }
    }
    
    public final class Selection: Equatable {
        public let isSelected: Bool
        public let toggle: () -> Void
        
        public init(isSelected: Bool, toggle: @escaping () -> Void) {
            self.isSelected = isSelected
            self.toggle = toggle
        }
        
        public static func ==(lhs: Selection, rhs: Selection) -> Bool {
            if lhs.isSelected != rhs.isSelected {
                return false
            }
            return true
        }
    }
    
    public enum InputMode {
        case keyboard
        case emoji
    }
    
    public final class EmojiSuggestion {
        public struct Position: Equatable {
            public var range: NSRange
            public var value: String
        }
        
        public var localPosition: CGPoint
        public var position: Position
        public var disposable: Disposable?
        public var value: Any?
        
        init(localPosition: CGPoint, position: Position) {
            self.localPosition = localPosition
            self.position = position
            self.disposable = nil
            self.value = nil
        }
    }
    
    public let externalState: TextFieldComponent.ExternalState?
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let placeholder: NSAttributedString?
    public let resetText: ResetText?
    public let assumeIsEditing: Bool
    public let characterLimit: Int?
    public let enableInlineAnimations: Bool
    public let emptyLineHandling: TextFieldComponent.EmptyLineHandling
    public let returnKeyAction: (() -> Void)?
    public let backspaceKeyAction: (() -> Void)?
    public let selection: Selection?
    public let inputMode: InputMode?
    public let alwaysDisplayInputModeSelector: Bool
    public let toggleInputMode: (() -> Void)?
    public let tag: AnyObject?
    
    public init(
        externalState: TextFieldComponent.ExternalState?,
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        placeholder: NSAttributedString? = nil,
        resetText: ResetText? = nil,
        assumeIsEditing: Bool = false,
        characterLimit: Int,
        enableInlineAnimations: Bool = true,
        emptyLineHandling: TextFieldComponent.EmptyLineHandling,
        returnKeyAction: (() -> Void)?,
        backspaceKeyAction: (() -> Void)?,
        selection: Selection?,
        inputMode: InputMode?,
        alwaysDisplayInputModeSelector: Bool = false,
        toggleInputMode: (() -> Void)?,
        tag: AnyObject? = nil
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.strings = strings
        self.placeholder = placeholder
        self.resetText = resetText
        self.assumeIsEditing = assumeIsEditing
        self.characterLimit = characterLimit
        self.enableInlineAnimations = enableInlineAnimations
        self.emptyLineHandling = emptyLineHandling
        self.returnKeyAction = returnKeyAction
        self.backspaceKeyAction = backspaceKeyAction
        self.selection = selection
        self.inputMode = inputMode
        self.alwaysDisplayInputModeSelector = alwaysDisplayInputModeSelector
        self.toggleInputMode = toggleInputMode
        self.tag = tag
    }
    
    public static func ==(lhs: ListComposePollOptionComponent, rhs: ListComposePollOptionComponent) -> Bool {
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
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.resetText != rhs.resetText {
            return false
        }
        if lhs.assumeIsEditing != rhs.assumeIsEditing {
            return false
        }
        if lhs.characterLimit != rhs.characterLimit {
            return false
        }
        if lhs.enableInlineAnimations != rhs.enableInlineAnimations {
            return false
        }
        if lhs.emptyLineHandling != rhs.emptyLineHandling {
            return false
        }
        if lhs.selection != rhs.selection {
            return false
        }
        if lhs.inputMode != rhs.inputMode {
            return false
        }
        if lhs.alwaysDisplayInputModeSelector != rhs.alwaysDisplayInputModeSelector {
            return false
        }

        return true
    }
    
    private final class CheckView: HighlightTrackingButton {
        private var checkLayer: CheckLayer?
        private var theme: PresentationTheme?
        
        var action: (() -> Void)?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.highligthedChanged = { [weak self] highlighted in
                if let self, self.bounds.width > 0.0 {
                    let animateScale = true
                    
                    let topScale: CGFloat = (self.bounds.width - 8.0) / self.bounds.width
                    let maxScale: CGFloat = (self.bounds.width + 2.0) / self.bounds.width
                    
                    if highlighted {
                        self.layer.removeAnimation(forKey: "opacity")
                        self.layer.removeAnimation(forKey: "transform.scale")
                        
                        if animateScale {
                            let transition = ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut))
                            transition.setScale(layer: self.layer, scale: topScale)
                        }
                    } else {
                        if animateScale {
                            let transition = ComponentTransition(animation: .none)
                            transition.setScale(layer: self.layer, scale: 1.0)
                            
                            self.layer.animateScale(from: topScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                self.layer.animateScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                            })
                        }
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.action?()
        }
        
        func update(size: CGSize, theme: PresentationTheme, isSelected: Bool, transition: ComponentTransition) {
            let checkLayer: CheckLayer
            if let current = self.checkLayer {
                checkLayer = current
            } else {
                checkLayer = CheckLayer(theme: CheckNodeTheme(theme: theme, style: .plain), content: .check)
                self.checkLayer = checkLayer
                self.layer.addSublayer(checkLayer)
            }
            
            if self.theme !== theme {
                self.theme = theme
                
                checkLayer.theme = CheckNodeTheme(theme: theme, style: .plain)
            }
            
            checkLayer.frame = CGRect(origin: CGPoint(), size: size)
            checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
        }
    }
    
    public final class View: UIView, ListSectionComponent.ChildView, ComponentTaggedView {
        private let textField = ComponentView<Empty>()
        
        private var modeSelector: ComponentView<Empty>?
        
        private var checkView: CheckView?
        
        private var customPlaceholder: ComponentView<Empty>?
        
        private var component: ListComposePollOptionComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        public var currentText: String {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.inputState.inputText.string
            } else {
                return ""
            }
        }
        
        public var currentAttributedText: NSAttributedString {
            if let textFieldView = self.textField.view as? TextFieldComponent.View {
                return textFieldView.inputState.inputText
            } else {
                return NSAttributedString(string: "")
            }
        }
        
        public var textFieldView: TextFieldComponent.View? {
            return self.textField.view as? TextFieldComponent.View
        }
        
        public var currentTag: AnyObject? {
            return self.component?.tag
        }
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public private(set) var separatorInset: CGFloat = 0.0
        
        public override init(frame: CGRect) {
            super.init(frame: CGRect())
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
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
        
        func update(component: ListComposePollOptionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let verticalInset: CGFloat = 12.0
            var leftInset: CGFloat = 16.0
            var rightInset: CGFloat = 16.0
            let modeSelectorSize = CGSize(width: 32.0, height: 32.0)
            
            if component.selection != nil {
                leftInset += 34.0
            }
            
            if component.inputMode != nil {
                rightInset += 34.0
            }
            
            let textFieldSize = self.textField.update(
                transition: transition,
                component: AnyComponent(TextFieldComponent(
                    context: component.context,
                    theme: component.theme,
                    strings: component.strings,
                    externalState: component.externalState ?? TextFieldComponent.ExternalState(),
                    fontSize: 17.0,
                    textColor: component.theme.list.itemPrimaryTextColor,
                    accentColor: component.theme.list.itemPrimaryTextColor,
                    insets: UIEdgeInsets(top: verticalInset, left: 8.0, bottom: verticalInset, right: 8.0),
                    hideKeyboard: component.inputMode == .emoji,
                    customInputView: nil,
                    placeholder: component.placeholder,
                    resetText: component.resetText.flatMap { resetText in
                        let result = NSMutableAttributedString(attributedString: resetText.value)
                        result.addAttributes([
                            .font: Font.regular(17.0),
                            .foregroundColor: component.theme.list.itemPrimaryTextColor
                        ], range: NSRange(location: 0, length: result.length))
                        return result
                    },
                    isOneLineWhenUnfocused: false,
                    characterLimit: component.characterLimit,
                    enableInlineAnimations: component.enableInlineAnimations,
                    emptyLineHandling: component.emptyLineHandling,
                    formatMenuAvailability: .none,
                    returnKeyType: .next,
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
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset + 8.0 * 2.0, height: availableSize.height)
            )
            
            let size = CGSize(width: availableSize.width, height: textFieldSize.height - 1.0)
            let textFieldFrame = CGRect(origin: CGPoint(x: leftInset - 16.0, y: 0.0), size: textFieldSize)
            
            if let textFieldView = self.textField.view {
                if textFieldView.superview == nil {
                    self.addSubview(textFieldView)
                    self.textField.parentState = state
                }
                transition.setFrame(view: textFieldView, frame: textFieldFrame)
            }
            
            if let selection = component.selection {
                let checkView: CheckView
                var animateIn = false
                if let current = self.checkView {
                    checkView = current
                } else {
                    animateIn = true
                    checkView = CheckView()
                    self.checkView = checkView
                    self.addSubview(checkView)
                    
                    checkView.action = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.selection?.toggle()
                    }
                }
                let checkSize = CGSize(width: 22.0, height: 22.0)
                let checkFrame = CGRect(origin: CGPoint(x: floor((leftInset - checkSize.width) * 0.5), y: floor((size.height - checkSize.height) * 0.5)), size: checkSize)
                
                if animateIn {
                    checkView.frame = CGRect(origin: CGPoint(x: -checkSize.width, y: self.bounds.height == 0.0 ? checkFrame.minY : floor((self.bounds.height - checkSize.height) * 0.5)), size: checkFrame.size)
                    transition.setPosition(view: checkView, position: checkFrame.center)
                    transition.setBounds(view: checkView, bounds: CGRect(origin: CGPoint(), size: checkFrame.size))
                    checkView.update(size: checkFrame.size, theme: component.theme, isSelected: selection.isSelected, transition: .immediate)
                } else {
                    transition.setPosition(view: checkView, position: checkFrame.center)
                    transition.setBounds(view: checkView, bounds: CGRect(origin: CGPoint(), size: checkFrame.size))
                    checkView.update(size: checkFrame.size, theme: component.theme, isSelected: selection.isSelected, transition: transition)
                }
            } else if let checkView = self.checkView {
                self.checkView = nil
                transition.setPosition(view: checkView, position: CGPoint(x: -checkView.bounds.width * 0.5, y: size.height * 0.5), completion: { [weak checkView] _ in
                    checkView?.removeFromSuperview()
                })
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
                    
                    if let animationView = modeSelectorView.contentView as? LottieComponent.View {
                        if playAnimation {
                            animationView.playOnce()
                        }
                    }
                    
                    modeSelectorTransition.setPosition(view: modeSelectorView, position: modeSelectorFrame.center)
                    modeSelectorTransition.setBounds(view: modeSelectorView, bounds: CGRect(origin: CGPoint(), size: modeSelectorFrame.size))
                    
                    if let externalState = component.externalState {
                        let displaySelector = externalState.isEditing || component.alwaysDisplayInputModeSelector
                        
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
            
            self.separatorInset = leftInset
            
            return size
        }
        
        public func updateCustomPlaceholder(value: String, size: CGSize, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            
            let verticalInset: CGFloat = 12.0
            var leftInset: CGFloat = 16.0
            let rightInset: CGFloat = 16.0
            
            if component.selection != nil {
                leftInset += 34.0
            }
            
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
                    containerSize: CGSize(width: size.width - leftInset - rightInset, height: 100.0)
                )
                let placeholderFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: placeholderSize)
                if let placeholderView = customPlaceholder.view {
                    if placeholderView.superview == nil {
                        placeholderView.layer.anchorPoint = CGPoint()
                        placeholderView.isUserInteractionEnabled = false
                        self.insertSubview(placeholderView, at: 0)
                    }
                    transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                    placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                    
                    if let externalState = component.externalState {
                        placeholderView.isHidden = externalState.hasText
                    }
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
