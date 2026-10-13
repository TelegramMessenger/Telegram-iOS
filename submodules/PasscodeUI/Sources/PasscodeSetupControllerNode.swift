import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import PasscodeInputFieldNode
import ComponentFlow
import WalletSendKeyboardComponent

enum PasscodeSetupInitialState {
    case createPasscode
    case changePassword(current: String, hasRecoveryEmail: Bool, hasSecureValues: Bool)
}

enum PasscodeSetupStateKind: Int32 {
    case enterPasscode
    case confirmPasscode
}

final class PasscodeSetupControllerNode: ASDisplayNode {
    private var presentationData: PresentationData
    private var mode: PasscodeSetupControllerMode
    private let useCustomNumericKeyboard: Bool
    private let keyboard = ComponentView<Empty>()
    private var isCustomInputActive = true
    private var previousDisplaysCustomKeyboard: Bool?

    private var displaysCustomKeyboard: Bool {
        guard self.useCustomNumericKeyboard else { return false }
        switch self.mode {
        case let .setup(_, type):
            return type != .alphanumeric
        case let .entry(challenge):
            switch challenge.passcodeKind {
            case .digits4, .digits6:
                return true
            default:
                return false
            }
        }
    }
    
    private let wrapperNode: ASDisplayNode
    
    private let titleNode: ASTextNode
    private let subtitleNode: ASTextNode
    private let inputFieldNode: PasscodeInputFieldNode
    private let modeButtonNode: HighlightableButtonNode
    
    var previousPasscode: String?
    var currentPasscode: String {
        return self.inputFieldNode.text
    }
    
    var selectPasscodeMode: ((HighlightableButtonNode) -> Void)?
    var checkPasscode: ((String) -> Void)?
    var complete: ((String, Bool) -> Void)?
    var updateNextAction: ((Bool) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    private var authenticationInputEnabled = true
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(presentationData: PresentationData, mode: PasscodeSetupControllerMode, useCustomNumericKeyboard: Bool) {
        self.presentationData = presentationData
        self.mode = mode
        self.useCustomNumericKeyboard = useCustomNumericKeyboard
        
        self.wrapperNode = ASDisplayNode()
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = ASTextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        let passcodeType: PasscodeEntryFieldType
        switch self.mode {
            case let .entry(challenge):
                switch challenge.passcodeKind {
                case .digits4: passcodeType = .digits4
                case .digits6: passcodeType = .digits6
                default: passcodeType = .alphanumeric
                }
            case let .setup(_, type):
                passcodeType = type
        }
        
        self.inputFieldNode = PasscodeInputFieldNode(color: self.presentationData.theme.list.itemPrimaryTextColor, accentColor: self.presentationData.theme.list.itemAccentColor, fieldType: passcodeType, keyboardAppearance: self.presentationData.theme.rootController.keyboardColor.keyboardAppearance, useCustomNumpad: self.useCustomNumericKeyboard && passcodeType != .alphanumeric, fieldBackgroundColor: self.presentationData.theme.list.itemBlocksBackgroundColor)
        
        self.modeButtonNode = HighlightableButtonNode()
        self.modeButtonNode.setTitle(self.presentationData.strings.PasscodeSettings_PasscodeOptions, with: Font.regular(17.0), with: self.presentationData.theme.list.itemAccentColor, for: .normal)
      
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.clipsToBounds = self.useCustomNumericKeyboard
        
        self.addSubnode(self.wrapperNode)
        
        self.wrapperNode.addSubnode(self.titleNode)
        self.wrapperNode.addSubnode(self.subtitleNode)
        self.wrapperNode.addSubnode(self.inputFieldNode)
        self.wrapperNode.addSubnode(self.modeButtonNode)
        
        let text: String
        switch self.mode {
            case .entry:
                self.modeButtonNode.isHidden = true
                self.modeButtonNode.isAccessibilityElement = false
                text = self.presentationData.strings.EnterPasscode_EnterPasscode
            case let .setup(change, _):
                if change {
                    text = self.presentationData.strings.EnterPasscode_EnterNewPasscodeChange
                } else {
                    text = self.presentationData.strings.EnterPasscode_EnterNewPasscodeNew
                }
        }
        self.titleNode.attributedText = NSAttributedString(string: text, font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        
        self.inputFieldNode.complete = { [weak self] passcode in
            guard let self, self.currentPasscode == passcode else { return }
            self.activateNext()
        }
        
        self.modeButtonNode.addTarget(self, action: #selector(self.modePressed), forControlEvents: .touchUpInside)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        self.updateCustomKeyboard(layout: layout, transition: transition)
        
        let standardInputHeight = layout.deviceMetrics.standardInputHeight(inLandscape: layout.orientation == .landscape)
        var insets = layout.insets(options: [.statusBar])
        if self.displaysCustomKeyboard {
            insets.bottom = standardInputHeight + layout.additionalInsets.bottom
        } else {
            let keyboardHeight = max(layout.inputHeight ?? 0.0, standardInputHeight)
            insets.bottom = max(insets.bottom, keyboardHeight)
        }
        
        self.wrapperNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        let inputFieldFrame = self.inputFieldNode.updateLayout(size: layout.size, topOffset: floor(insets.top + navigationBarHeight + (layout.size.height - navigationBarHeight - insets.top - insets.bottom - 24.0) / 2.0), transition: transition)
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: inputFieldFrame.minY - titleSize.height - 20.0), size: titleSize))
        
        let subtitleSize = self.subtitleNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - subtitleSize.width) / 2.0), y: inputFieldFrame.maxY + 20.0), size: subtitleSize))
        
        transition.updateFrame(node: self.modeButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - insets.bottom - 53.0), size: CGSize(width: layout.size.width, height: 44.0)))
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.disablesInteractiveKeyboardGestureRecognizer = true
    }

    private func updateCustomKeyboard(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let isVisible = self.displaysCustomKeyboard
        let visibilityChanged = self.previousDisplaysCustomKeyboard.map { $0 != isVisible } ?? false
        self.previousDisplaysCustomKeyboard = isVisible
        guard isVisible || self.keyboard.view != nil else { return }

        var minimumKeyboardHeight = layout.deviceMetrics.standardInputHeight(inLandscape: layout.orientation == .landscape) - 49.0
        if UIDevice.current.userInterfaceIdiom == .pad {
            minimumKeyboardHeight = min(minimumKeyboardHeight, 270.0)
        }
        let isEnabled = isVisible && self.authenticationInputEnabled && self.isCustomInputActive
        let keyboardSize = self.keyboard.update(
            transition: .immediate,
            component: AnyComponent(WalletSendKeyboardComponent(
                theme: self.presentationData.theme,
                safeInsets: layout.safeInsets,
                isLandscape: layout.size.width > layout.size.height && layout.metrics.widthClass == .compact,
                minimumHeight: minimumKeyboardHeight,
                mode: .numeric,
                deleteTitle: self.presentationData.strings.Common_Delete,
                isEnabled: isEnabled,
                action: { [weak self] action in
                    guard let self, self.displaysCustomKeyboard, self.authenticationInputEnabled, self.isCustomInputActive, self.view.isUserInteractionEnabled else { return }
                    self.hapticFeedback.impact(.light)
                    switch action {
                    case let .insertText(text):
                        self.inputFieldNode.append(text)
                    case .deleteBackward:
                        let _ = self.inputFieldNode.delete()
                    }
                }
            )),
            environment: {},
            containerSize: layout.size
        )
        if let keyboardView = self.keyboard.view {
            if keyboardView.superview == nil {
                self.view.addSubview(keyboardView)
                keyboardView.frame = CGRect(x: 0.0, y: layout.size.height, width: keyboardSize.width, height: keyboardSize.height)
            }
            if isVisible {
                keyboardView.isHidden = false
            }
            keyboardView.isUserInteractionEnabled = isEnabled
            keyboardView.accessibilityElementsHidden = !isEnabled
            let keyboardFrame = CGRect(
                x: 0.0,
                y: isVisible ? layout.size.height - layout.additionalInsets.bottom - keyboardSize.height : layout.size.height,
                width: keyboardSize.width,
                height: keyboardSize.height
            )
            // Input activation and system keyboard updates can repeat the same target during the slide.
            if keyboardView.frame != keyboardFrame {
                var keyboardTransition = transition
                if visibilityChanged || (!transition.isAnimated && keyboardView.layer.animation(forKey: "position") != nil) {
                    keyboardTransition = .animated(duration: 0.25, curve: .easeInOut)
                }
                keyboardTransition.updateFrame(view: keyboardView, frame: keyboardFrame, beginWithCurrentState: true, completion: { [weak self, weak keyboardView] completed in
                    guard completed, let self, let keyboardView,
                          !self.displaysCustomKeyboard, keyboardView.frame == keyboardFrame else { return }
                    keyboardView.isHidden = true
                })
            }
        }
    }

    func deactivateCustomInput() {
        guard self.useCustomNumericKeyboard else { return }
        self.isCustomInputActive = false
        self.inputFieldNode.isInputEnabled = false
        self.inputFieldNode.cancelPendingCompletion()
        if let validLayout = self.validLayout {
            self.updateCustomKeyboard(layout: validLayout.0, transition: .immediate)
        }
    }

    func updateInputEnabled(_ enabled: Bool) {
        self.authenticationInputEnabled = enabled
        self.inputFieldNode.isInputEnabled = enabled && (!self.useCustomNumericKeyboard || self.isCustomInputActive)
        self.modeButtonNode.isUserInteractionEnabled = enabled
        if let validLayout = self.validLayout {
            self.updateCustomKeyboard(layout: validLayout.0, transition: .immediate)
        }
    }
    
    func updateMode(_ mode: PasscodeSetupControllerMode) {
        (self.keyboard.view as? WalletSendKeyboardComponent.View)?.cancelKeyPresses()
        self.mode = mode
        self.inputFieldNode.reset()
        
        if case let .setup(_, type) = mode {
            self.inputFieldNode.updateFieldType(type, animated: true, useCustomNumpad: self.displaysCustomKeyboard)
            
            if case .alphanumeric = type {
                self.updateNextAction?(true)
            } else {
                self.updateNextAction?(false)
            }
            self.subtitleNode.isHidden = true
        }
        if let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout.0, navigationBarHeight: validLayout.1, transition: .animated(duration: 0.25, curve: .easeInOut))
        }
    }
    
    func activateNext() {
        guard self.authenticationInputEnabled else { return }
        if self.useCustomNumericKeyboard && !self.isCustomInputActive {
            return
        }
        if case let .setup(_, type) = self.mode, let maxLength = type.maxLength, self.currentPasscode.count != maxLength {
            return
        }
        (self.keyboard.view as? WalletSendKeyboardComponent.View)?.cancelKeyPresses()
        guard !self.currentPasscode.isEmpty else {
            self.animateError()
            return
        }
        
        switch self.mode {
            case .entry:
                self.checkPasscode?(self.currentPasscode)
            case .setup:
                if let previousPasscode = self.previousPasscode {
                    if self.currentPasscode == previousPasscode {
                        var numerical = false
                        if case let .setup(_, type) = mode {
                            if case .alphanumeric = type {
                            } else {
                                numerical = true
                            }
                        }
                        self.complete?(self.currentPasscode, numerical)
                    } else {
                        self.previousPasscode = nil
                        
                        if let snapshotView = self.wrapperNode.view.snapshotContentTree() {
                            snapshotView.frame = self.wrapperNode.frame
                            self.wrapperNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.wrapperNode.view)
                            snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: self.wrapperNode.bounds.width, y: 0.0), duration: 0.25, removeOnCompletion: false, additive: true, completion : { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            self.wrapperNode.layer.animatePosition(from: CGPoint(x: -self.wrapperNode.bounds.width, y: 0.0), to: CGPoint(), duration: 0.25, additive: true)
                            
                            self.inputFieldNode.reset(animated: false)
                            self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.EnterPasscode_EnterNewPasscodeChange, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                            self.subtitleNode.isHidden = false
                            self.subtitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.PasscodeSettings_DoNotMatch, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                            self.modeButtonNode.isHidden = false
                            self.modeButtonNode.isAccessibilityElement = true
                            
                            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: self.presentationData.strings.PasscodeSettings_DoNotMatch)
                            
                            if let validLayout = self.validLayout {
                                self.containerLayoutUpdated(validLayout.0, navigationBarHeight: validLayout.1, transition: .immediate)
                            }
                        }
                    }
                } else {
                    self.previousPasscode = self.currentPasscode
                    
                    if let snapshotView = self.wrapperNode.view.snapshotContentTree() {
                        snapshotView.frame = self.wrapperNode.frame
                        self.wrapperNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.wrapperNode.view)
                        snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -self.wrapperNode.bounds.width, y: 0.0), duration: 0.25, removeOnCompletion: false, additive: true, completion : { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                        self.wrapperNode.layer.animatePosition(from: CGPoint(x: self.wrapperNode.bounds.width, y: 0.0), to: CGPoint(), duration: 0.25, additive: true)
                        
                        self.inputFieldNode.reset(animated: false)
                        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.EnterPasscode_RepeatNewPasscode, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                        self.subtitleNode.isHidden = true
                        self.modeButtonNode.isHidden = true
                        self.modeButtonNode.isAccessibilityElement = false
                        
                        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: self.presentationData.strings.EnterPasscode_RepeatNewPasscode)
                        
                        if let validLayout = self.validLayout {
                            self.containerLayoutUpdated(validLayout.0, navigationBarHeight: validLayout.1, transition: .immediate)
                        }
                    }
                }
        }
    }
    
    func activateInput() {
        guard self.authenticationInputEnabled else { return }
        self.isCustomInputActive = true
        self.inputFieldNode.isInputEnabled = true
        self.inputFieldNode.activateInput()
        if let validLayout = self.validLayout {
            self.updateCustomKeyboard(layout: validLayout.0, transition: .immediate)
        }
        
        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: self.titleNode.attributedText?.string)
    }
    
    func animateError() {
        self.inputFieldNode.reset()
        self.inputFieldNode.layer.addShakeAnimation(amplitude: -30.0, duration: 0.5, count: 6, decay: true)
        
        self.hapticFeedback.error()
    }

    func updateAuthenticationState(_ state: SettingsPasscodeAuthentication.State) {
        self.updateInputEnabled(state == .ready)
        self.inputFieldNode.isUserInteractionEnabled = self.authenticationInputEnabled
        let message: String?
        switch state {
        case .ready: message = ""
        case .cooldown:
            message = self.presentationData.strings.PasscodeSettings_TryAgainIn1Minute
            self.inputFieldNode.reset(animated: false)
        case .checking: message = nil
        case .finished:
            message = ""
            self.inputFieldNode.reset(animated: false)
            self.view.endEditing(true)
        }
        if let message {
            self.subtitleNode.attributedText = NSAttributedString(string: message, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            self.subtitleNode.isHidden = message.isEmpty
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(validLayout.0, navigationBarHeight: validLayout.1, transition: .immediate)
            }
        }
    }
    
    @objc func modePressed() {
        self.deactivateCustomInput()
        self.selectPasscodeMode?(self.modeButtonNode)
    }
}
