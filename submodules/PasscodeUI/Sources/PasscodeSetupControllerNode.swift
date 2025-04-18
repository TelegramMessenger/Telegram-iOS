import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import PasscodeInputFieldNode

enum PasscodeSetupInitialState {
    case createPasscode
    case changePassword(current: String, hasRecoveryEmail: Bool, hasSecureValues: Bool)
}

enum PasscodeSetupStateKind: Int32 {
    case enterPasscode
    case confirmPasscode
}

private func generateFieldBackground(backgroundColor: UIColor, borderColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 1.0, height: 48.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        context.setFillColor(backgroundColor.cgColor)
        context.fill(bounds)
        
        context.setFillColor(borderColor.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: UIScreenPixel)))
        context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: 1.0, height: UIScreenPixel)))
    })
}

final class PasscodeSetupControllerNode: ASDisplayNode {
    private var presentationData: PresentationData
    private var mode: PasscodeSetupControllerMode
    
    private let wrapperNode: ASDisplayNode
    
    private let titleNode: ASTextNode
    private let subtitleNode: ASTextNode
    private let inputFieldNode: PasscodeInputFieldNode
    private let inputFieldBackgroundNode: ASImageNode
    private let modeButtonNode: HighlightableButtonNode
    
    var previousPasscode: String?
    var currentPasscode: String {
        return self.inputFieldNode.text
    }
    
    var selectPasscodeMode: (() -> Void)?
    var checkPasscode: ((String) -> Bool)?
    var complete: ((String, Bool) -> Void)?
    var updateNextAction: ((Bool) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var maxBottomInset: CGFloat?
    
    init(presentationData: PresentationData, mode: PasscodeSetupControllerMode) {
        self.presentationData = presentationData
        self.mode = mode
        
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
                switch challenge {
                    case let .numericalPassword(value):
                        passcodeType = value.count == 6 ? .digits6 : .digits4
                    default:
                        passcodeType = .alphanumeric
                }
            case .setup:
                passcodeType = .digits6
        }
        
        self.inputFieldNode = PasscodeInputFieldNode(color: self.presentationData.theme.list.itemPrimaryTextColor, accentColor: self.presentationData.theme.list.itemAccentColor, fieldType: passcodeType, keyboardAppearance: self.presentationData.theme.rootController.keyboardColor.keyboardAppearance)
        self.inputFieldBackgroundNode = ASImageNode()
        self.inputFieldBackgroundNode.alpha = passcodeType == .alphanumeric ? 1.0 : 0.0
        self.inputFieldBackgroundNode.contentMode = .scaleToFill
        self.inputFieldBackgroundNode.image = generateFieldBackground(backgroundColor: self.presentationData.theme.list.itemBlocksBackgroundColor, borderColor: self.presentationData.theme.list.itemBlocksSeparatorColor)
        
        self.modeButtonNode = HighlightableButtonNode()
        self.modeButtonNode.setTitle(self.presentationData.strings.PasscodeSettings_PasscodeOptions, with: Font.regular(17.0), with: self.presentationData.theme.list.itemAccentColor, for: .normal)
      
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.addSubnode(self.wrapperNode)
        
        self.wrapperNode.addSubnode(self.titleNode)
        self.wrapperNode.addSubnode(self.subtitleNode)
        self.wrapperNode.addSubnode(self.inputFieldBackgroundNode)
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
            self?.activateNext()
        }
        
        self.modeButtonNode.addTarget(self, action: #selector(self.modePressed), forControlEvents: .touchUpInside)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        if let maxBottomInset = self.maxBottomInset {
            if maxBottomInset > insets.bottom {
                insets.bottom = maxBottomInset
            } else {
                self.maxBottomInset = insets.bottom
            }
        } else {
            self.maxBottomInset = insets.bottom
        }
        
        self.wrapperNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        
        let inputFieldFrame = self.inputFieldNode.updateLayout(size: layout.size, topOffset: floor(insets.top + navigationBarHeight + (layout.size.height - navigationBarHeight - insets.top - insets.bottom - 24.0) / 2.0), transition: transition)
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        transition.updateFrame(node: self.inputFieldBackgroundNode, frame: CGRect(x: 0.0, y: inputFieldFrame.minY - 6.0, width: layout.size.width, height: 48.0))
        
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
    
    func updateMode(_ mode: PasscodeSetupControllerMode) {
        self.mode = mode
        self.inputFieldNode.reset()
        
        if case let .setup(_, type) = mode {
            self.inputFieldNode.updateFieldType(type, animated: true)
            
            let fieldBackgroundAlpha: CGFloat
            if case .alphanumeric = type {
                fieldBackgroundAlpha = 1.0
                self.updateNextAction?(true)
            } else {
                fieldBackgroundAlpha = 0.0
                self.updateNextAction?(false)
            }
            let previousAlpha = self.inputFieldBackgroundNode.alpha
            self.inputFieldBackgroundNode.alpha = fieldBackgroundAlpha
            self.inputFieldBackgroundNode.layer.animateAlpha(from: previousAlpha, to: fieldBackgroundAlpha, duration: 0.25)
            self.subtitleNode.isHidden = true
        }
    }
    
    func activateNext() {
        guard !self.currentPasscode.isEmpty else {
            self.animateError()
            return
        }
        
        switch self.mode {
            case .entry:
                if !(self.checkPasscode?(self.currentPasscode) ?? false) {
                    self.animateError()
                }
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
        self.inputFieldNode.activateInput()
        
        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: self.titleNode.attributedText?.string)
    }
    
    func animateError() {
        self.inputFieldNode.reset()
        self.inputFieldNode.layer.addShakeAnimation(amplitude: -30.0, duration: 0.5, count: 6, decay: true)
        
        self.hapticFeedback.error()
    }
    
    @objc func modePressed() {
        self.selectPasscodeMode?()
    }
}
