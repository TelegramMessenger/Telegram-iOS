import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData

private let titleFont = Font.regular(20.0)
private let subtitleFont = Font.regular(15.0)
private let buttonFont = Font.regular(17.0)

final class PasscodeEntryControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var wallpaper: TelegramWallpaper
    private let passcodeType: PasscodeEntryFieldType
    private let biometricsType: LocalAuthBiometricAuthentication?
    private let arguments: PasscodeEntryControllerPresentationArguments
    private var background: PasscodeBackground?
    
    private let statusBar: StatusBar
    
    private let backgroundNode: ASImageNode
    private let iconNode: PasscodeLockIconNode
    private let titleNode: PasscodeEntryLabelNode
    private let inputFieldNode: PasscodeEntryInputFieldNode
    private let subtitleNode: PasscodeEntryLabelNode
    private let keyboardNode: PasscodeEntryKeyboardNode
    private let cancelButtonNode: HighlightableButtonNode
    private let deleteButtonNode: HighlightableButtonNode
    private let biometricButtonNode: HighlightableButtonNode
    private let effectView: UIVisualEffectView
    
    private var invalidAttempts: AccessChallengeAttempts?
    private var timer: SwiftSignalKit.Timer?
    
    private let hapticFeedback = HapticFeedback()
    
    private var validLayout: ContainerViewLayout?
    
    var checkPasscode: ((String) -> Void)?
    var requestBiometrics: (() -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, passcodeType: PasscodeEntryFieldType, biometricsType: LocalAuthBiometricAuthentication?, arguments: PasscodeEntryControllerPresentationArguments, statusBar: StatusBar) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.wallpaper = wallpaper
        self.passcodeType = passcodeType
        self.biometricsType = biometricsType
        self.arguments = arguments
        self.statusBar = statusBar
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.contentMode = .scaleToFill

        self.iconNode = PasscodeLockIconNode()
        self.titleNode = PasscodeEntryLabelNode()
        self.inputFieldNode = PasscodeEntryInputFieldNode(color: .white, accentColor: .white, fieldType: passcodeType, keyboardAppearance: .dark, useCustomNumpad: true)
        self.subtitleNode = PasscodeEntryLabelNode()
        self.keyboardNode = PasscodeEntryKeyboardNode()
        self.cancelButtonNode = HighlightableButtonNode()
        self.deleteButtonNode = HighlightableButtonNode()
        self.biometricButtonNode = HighlightableButtonNode()
        self.effectView = UIVisualEffectView(effect: nil)
            
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = .clear
        self.iconNode.unlockedColor = theme.rootController.navigationBar.primaryTextColor
        
        self.keyboardNode.charactedEntered = { [weak self] character in
            self?.inputFieldNode.append(character)
        }
        self.inputFieldNode.complete = { [weak self] passcode in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.shouldWaitBeforeNextAttempt() {
                strongSelf.animateError()
            } else {
                strongSelf.checkPasscode?(passcode)
            }
        }
        
        self.cancelButtonNode.setTitle(strings.Common_Cancel, with: buttonFont, with: .white, for: .normal)
        self.deleteButtonNode.setTitle(strings.Common_Delete, with: buttonFont, with: .white, for: .normal)
    
        if let biometricsType = self.biometricsType {
            switch biometricsType {
                case .touchId:
                    self.biometricButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/PasscodeTouchId"), color: .white), for: .normal)
                case .faceId:
                    self.biometricButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Settings/PasscodeFaceId"), color: .white), for: .normal)
            }
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.inputFieldNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.keyboardNode)
        self.addSubnode(self.deleteButtonNode)
        self.addSubnode(self.biometricButtonNode)
        
        if self.arguments.cancel != nil {
            self.addSubnode(self.cancelButtonNode)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.insertSubview(self.effectView, at: 0)
        
        if self.arguments.cancel != nil {
            self.cancelButtonNode.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        }
        self.deleteButtonNode.addTarget(self, action: #selector(self.deletePressed), forControlEvents: .touchUpInside)
        self.biometricButtonNode.addTarget(self, action: #selector(self.biometricsPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func cancelPressed() {
        self.animateOut(down: true)
        self.arguments.cancel?()
    }
    
    @objc private func deletePressed() {
        self.hapticFeedback.tap()
        self.inputFieldNode.delete()
    }
    
    @objc private func biometricsPressed() {
        self.requestBiometrics?()
    }
    
    func activateInput() {
        self.inputFieldNode.activateInput()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        self.wallpaper = presentationData.chatWallpaper
        
        self.deleteButtonNode.setTitle(self.strings.Common_Delete, with: buttonFont, with: .white, for: .normal)
        if let validLayout = self.validLayout {
            self.containerLayoutUpdated(validLayout, navigationBarHeight: 0.0, transition: .immediate)
        }
    }
    
    func updateBackground() {
        guard let validLayout = self.validLayout else {
            return
        }
        
        var size = validLayout.size
        if case .compact = validLayout.metrics.widthClass, size.width > size.height {
            size = CGSize(width: size.height, height: size.width)
        }
        
        if let background = self.background, background.size == size {
            return
        }
        
        switch self.wallpaper {
            case .image, .file:
                if let image = chatControllerBackgroundImage(wallpaper: self.wallpaper, mediaBox: self.context.sharedContext.accountManager.mediaBox, composed: false) {
                    self.background = ImageBasedPasscodeBackground(image: image, size: size)
                } else {
                    self.background = GradientPasscodeBackground(size: size, backgroundColors: self.theme.passcode.backgroundColors.colors, buttonColor: self.theme.passcode.buttonColor)
                }
            default:
                self.background = GradientPasscodeBackground(size: size, backgroundColors: self.theme.passcode.backgroundColors.colors, buttonColor: self.theme.passcode.buttonColor)
        }
        
        if let background = self.background {
            self.backgroundNode.image = background.backgroundImage
            self.keyboardNode.updateBackground(background)
            self.inputFieldNode.updateBackground(background)
        }
    }
    
    private let waitInterval: Int32 = 60
    private func shouldWaitBeforeNextAttempt() -> Bool {
        if let attempts = self.invalidAttempts {
            if attempts.count >= 6 {
                if Int32(CFAbsoluteTimeGetCurrent()) - attempts.timestamp < waitInterval {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    func updateInvalidAttempts(_ attempts: AccessChallengeAttempts?, animated: Bool = false) {
        self.invalidAttempts = attempts
        if let attempts = attempts {
            var text = NSAttributedString(string: "")
            if attempts.count >= 6 && self.shouldWaitBeforeNextAttempt() {
                text = NSAttributedString(string: self.strings.PasscodeSettings_TryAgainIn1Minute, font: subtitleFont, textColor: .white)
                
                self.timer?.invalidate()
                let timer = SwiftSignalKit.Timer(timeout: Double(attempts.timestamp + waitInterval - Int32(CFAbsoluteTimeGetCurrent())), repeat: false, completion: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.timer = nil
                        strongSelf.updateInvalidAttempts(strongSelf.invalidAttempts, animated: true)
                    }
                }, queue: Queue.mainQueue())
                self.timer = timer
                timer.start()
            }
            self.subtitleNode.setAttributedText(text, animation: animated ? .crossFade : .none, completion: {})
        } else {
            self.subtitleNode.setAttributedText(NSAttributedString(string: ""), animation: animated ? .crossFade : .none, completion: {})
        }
    }
    
    func hideBiometrics() {
        self.biometricButtonNode.layer.animateScale(from: 1.0, to: 0.00001, duration: 0.25, delay: 0.0, timingFunction: kCAMediaTimingFunctionEaseOut, completion: { [weak self] _ in
            self?.biometricButtonNode.isHidden = true
        })
        self.animateError()
    }
    
    func initialAppearance(fadeIn: Bool = false) {
        if fadeIn {
            let effect = self.theme.overallDarkAppearance ? UIBlurEffect(style: .dark) : UIBlurEffect(style: .light)
            UIView.animate(withDuration: 0.3, animations: {
                if #available(iOS 9.0, *) {
                    self.effectView.effect = effect
                } else {
                    self.effectView.alpha = 1.0
                }
            })
            self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        self.titleNode.setAttributedText(NSAttributedString(string: self.strings.EnterPasscode_EnterPasscode, font: titleFont, textColor: .white), animation: .none)
    }
    
    func animateIn(iconFrame: CGRect, completion: @escaping () -> Void = {}) {
        let effect = self.theme.overallDarkAppearance ? UIBlurEffect(style: .dark) : UIBlurEffect(style: .light)
        UIView.animate(withDuration: 0.3, animations: {
            if #available(iOS 9.0, *) {
                self.effectView.effect = effect
            } else {
                self.effectView.alpha = 1.0
            }
        })
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        if !iconFrame.isEmpty {
            self.iconNode.animateIn(fromScale: 0.416)
            self.iconNode.layer.animatePosition(from: iconFrame.center.offsetBy(dx: 6.0, dy: 6.0), to: self.iconNode.layer.position, duration: 0.45)
        }
        
        self.statusBar.layer.removeAnimation(forKey: "opacity")
        self.statusBar.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        self.subtitleNode.isHidden = true
        self.inputFieldNode.isHidden = true
        self.keyboardNode.isHidden = true
        self.cancelButtonNode.isHidden = true
        self.deleteButtonNode.isHidden = true
        self.biometricButtonNode.isHidden = true
        
        self.titleNode.setAttributedText(NSAttributedString(string: self.strings.Passcode_AppLockedAlert.replacingOccurrences(of: "\n", with: " "), font: titleFont, textColor: .white), animation: .slideIn, completion: {
            self.subtitleNode.isHidden = false
            self.inputFieldNode.isHidden = false
            self.keyboardNode.isHidden = false
            self.cancelButtonNode.isHidden = false
            self.deleteButtonNode.isHidden = false
            self.biometricButtonNode.isHidden = false
            
            self.subtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            
            self.inputFieldNode.animateIn()
            self.keyboardNode.animateIn()
            var biometricDelay = 0.3
            if case .alphanumeric = self.passcodeType {
                biometricDelay = 0.0
            } else {
                self.cancelButtonNode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: 0.15, timingFunction: kCAMediaTimingFunctionEaseOut)
                self.deleteButtonNode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: 0.15, timingFunction: kCAMediaTimingFunctionEaseOut)
            }
            self.biometricButtonNode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: biometricDelay, timingFunction: kCAMediaTimingFunctionEaseOut)
            
            Queue.mainQueue().after(1.5, {
                self.titleNode.setAttributedText(NSAttributedString(string: self.strings.EnterPasscode_EnterPasscode, font: titleFont, textColor: .white), animation: .crossFade)
            })
            
            completion()
        })
    }
    
    func animateOut(down: Bool = false, completion: @escaping () -> Void = {}) {
        self.statusBar.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: down ? self.bounds.size.height : -self.bounds.size.height), duration: 0.2, removeOnCompletion: false, additive: true, completion: { _ in
            completion()
        })
    }
    
    func animateSuccess() {
        self.iconNode.animateUnlock()
        self.inputFieldNode.animateSuccess()
    }
    
    func animateError() {
        self.inputFieldNode.reset()
        self.inputFieldNode.layer.addShakeAnimation(amplitude: -30.0, duration: 0.5, count: 6, decay: true)
        self.iconNode.layer.addShakeAnimation(amplitude: -8.0, duration: 0.5, count: 6, decay: true)
        
        self.hapticFeedback.error()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        self.updateBackground()
        
        if layout.size.width == 320.0 {
            self.iconNode.alpha = 0.0
        }
        
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(node: self.backgroundNode, frame: bounds)
        transition.updateFrame(view: self.effectView, frame: bounds)
        
        let iconSize = CGSize(width: 35.0, height: 37.0)
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0) + 6.0, y: layout.insets(options: .statusBar).top + 15.0), size: iconSize))
        
        let passcodeLayout = PasscodeLayout(layout: layout)
        
        let inputFieldFrame = self.inputFieldNode.updateLayout(layout: passcodeLayout, transition: transition)
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.updateLayout(layout: layout, transition: transition)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: passcodeLayout.titleOffset), size: titleSize))
        
        var subtitleOffset = passcodeLayout.subtitleOffset
        if case .alphanumeric = self.passcodeType {
            subtitleOffset = 16.0
        }
        let subtitleSize = self.subtitleNode.updateLayout(layout: layout, transition: transition)
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: inputFieldFrame.maxY + subtitleOffset), size: subtitleSize))
        
        let (keyboardFrame, keyboardButtonSize) = self.keyboardNode.updateLayout(layout: passcodeLayout, transition: transition)
        transition.updateFrame(node: self.keyboardNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        switch self.passcodeType {
        case .digits6, .digits4:
            self.keyboardNode.alpha = 1.0
            self.deleteButtonNode.alpha = 1.0
        case .alphanumeric:
            self.keyboardNode.alpha = 0.0
            self.deleteButtonNode.alpha = 0.0
        }
        
        let bottomInset = layout.inputHeight ?? 0.0
        
        let cancelSize = self.cancelButtonNode.measure(layout.size)
        var cancelY: CGFloat = layout.size.height - layout.intrinsicInsets.bottom - cancelSize.height - passcodeLayout.keyboard.deleteOffset
        if bottomInset > 0 && self.keyboardNode.alpha < 1.0 {
            cancelY = layout.size.height - bottomInset - cancelSize.height - 20.0
        }
        
        transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: floor(keyboardFrame.minX + keyboardButtonSize.width / 2.0 - cancelSize.width / 2.0), y: cancelY), size: cancelSize))
        
        let deleteSize = self.deleteButtonNode.measure(layout.size)
        transition.updateFrame(node: self.deleteButtonNode, frame: CGRect(origin: CGPoint(x: floor(keyboardFrame.maxX - keyboardButtonSize.width / 2.0 - deleteSize.width / 2.0), y: layout.size.height - layout.intrinsicInsets.bottom - deleteSize.height - passcodeLayout.keyboard.deleteOffset), size: deleteSize))
        
        if let biometricIcon = self.biometricButtonNode.image(for: .normal) {
            var biometricY: CGFloat = 0.0
            if bottomInset > 0 && self.keyboardNode.alpha < 1.0 {
                biometricY = inputFieldFrame.maxY + floor((layout.size.height - bottomInset - inputFieldFrame.maxY - biometricIcon.size.height) / 2.0)
            } else {
                biometricY = keyboardFrame.maxY + passcodeLayout.keyboard.biometricsOffset
            }
            transition.updateFrame(node: self.biometricButtonNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - biometricIcon.size.width) / 2.0), y: biometricY), size: biometricIcon.size))
        }
    }
}
