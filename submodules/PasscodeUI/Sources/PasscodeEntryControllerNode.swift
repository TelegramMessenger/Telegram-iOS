import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import LocalAuth
import AppBundle
import PasscodeInputFieldNode
import MonotonicTime
import GradientBackground

private let titleFont = Font.regular(20.0)
private let subtitleFont = Font.regular(15.0)
private let buttonFont = Font.regular(17.0)

final class PasscodeEntryControllerNode: ASDisplayNode {
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private var presentationData: PresentationData
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    private var wallpaper: TelegramWallpaper
    private let passcodeType: PasscodeEntryFieldType
    private let biometricsType: LocalAuthBiometricAuthentication?
    private let arguments: PasscodeEntryControllerPresentationArguments
    private var background: PasscodeBackground?
    
    private let modalPresentation: Bool
    
    private var backgroundCustomNode: ASDisplayNode?
    private let backgroundDimNode: ASDisplayNode
    private let backgroundImageNode: ASImageNode
    private let iconNode: PasscodeLockIconNode
    private let titleNode: PasscodeEntryLabelNode
    private let inputFieldNode: PasscodeInputFieldNode
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
    
    init(accountManager: AccountManager<TelegramAccountManagerTypes>, presentationData: PresentationData, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, passcodeType: PasscodeEntryFieldType, biometricsType: LocalAuthBiometricAuthentication?, arguments: PasscodeEntryControllerPresentationArguments, modalPresentation: Bool) {
        self.accountManager = accountManager
        self.presentationData = presentationData
        self.theme = theme
        self.strings = strings
        self.wallpaper = wallpaper
        self.passcodeType = passcodeType
        self.biometricsType = biometricsType
        self.arguments = arguments
        self.modalPresentation = modalPresentation
        
        self.backgroundImageNode = ASImageNode()
        self.backgroundImageNode.contentMode = .scaleToFill

        self.backgroundDimNode = ASDisplayNode()
        self.backgroundDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.15)
        self.backgroundDimNode.isHidden = true
        
        self.iconNode = PasscodeLockIconNode()
        self.titleNode = PasscodeEntryLabelNode()
        self.inputFieldNode = PasscodeInputFieldNode(color: .white, accentColor: .white, fieldType: passcodeType, keyboardAppearance: .dark, useCustomNumpad: true)
        self.subtitleNode = PasscodeEntryLabelNode()
        self.keyboardNode = PasscodeEntryKeyboardNode()
        self.cancelButtonNode = HighlightableButtonNode()
        self.deleteButtonNode = HighlightableButtonNode()
        self.deleteButtonNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: -16.0, bottom: -10.0, right: -16.0)
        self.biometricButtonNode = HighlightableButtonNode()
        self.effectView = UIVisualEffectView(effect: nil)
            
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = .clear
        self.iconNode.unlockedColor = theme.rootController.navigationBar.primaryTextColor
        
        self.keyboardNode.charactedEntered = { [weak self] character in
            if let strongSelf = self {
                strongSelf.inputFieldNode.append(character)
                if let gradientNode = strongSelf.backgroundCustomNode as? GradientBackgroundNode {
                    gradientNode.animateEvent(transition: .animated(duration: 0.55, curve: .spring), extendAnimation: false, backwards: false, completion: {})
                }
            }
        }
        self.keyboardNode.backspace = { [weak self] in
            if let strongSelf = self {
                let _ = strongSelf.inputFieldNode.delete()
                if let gradientNode = strongSelf.backgroundCustomNode as? GradientBackgroundNode {
                    gradientNode.animateEvent(transition: .animated(duration: 0.55, curve: .spring), extendAnimation: false, backwards: true, completion: {})
                }
            }
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
        
        self.addSubnode(self.backgroundImageNode)
        self.addSubnode(self.backgroundDimNode)
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
        
        self.view.disablesInteractiveKeyboardGestureRecognizer = true
        
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
        let result = self.inputFieldNode.delete()
        if result, let gradientNode = self.backgroundCustomNode as? GradientBackgroundNode {
            gradientNode.animateEvent(transition: .animated(duration: 0.55, curve: .spring), extendAnimation: false, backwards: true, completion: {})
        }
    }
    
    @objc private func biometricsPressed() {
        self.requestBiometrics?()
    }
    
    func activateInput() {
        self.inputFieldNode.activateInput()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
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
        
        let size = validLayout.size
        if let background = self.background, background.size == size {
            return
        }
        
        switch self.wallpaper {
            case let .color(colorValue):
                let color = UIColor(argb: colorValue)
                let baseColor: UIColor
                let lightness = color.lightness
                if lightness < 0.1 || lightness > 0.9 {
                    baseColor = self.theme.chat.message.outgoing.bubble.withoutWallpaper.fill[0]
                } else{
                    baseColor = color
                }
                
                let color1: UIColor
                let color2: UIColor
                let color3: UIColor
                let color4: UIColor
                if self.theme.overallDarkAppearance {
                    color1 = baseColor.withMultiplied(hue: 1.034, saturation: 0.819, brightness: 0.214)
                    color2 = baseColor.withMultiplied(hue: 1.029, saturation: 0.77, brightness: 0.132)
                    color3 = color1
                    color4 = color2
                } else {
                    color1 = baseColor.withMultiplied(hue: 1.029, saturation: 0.312, brightness: 1.26)
                    color2 = baseColor.withMultiplied(hue: 1.034, saturation: 0.729, brightness: 0.942)
                    color3 = baseColor.withMultiplied(hue: 1.029, saturation: 0.729, brightness: 1.231)
                    color4 = baseColor.withMultiplied(hue: 1.034, saturation: 0.583, brightness: 1.043)
                }
                self.background = CustomPasscodeBackground(size: size, colors: [color1, color2, color3, color4], inverted: false)
            case let .gradient(gradient):
                self.background = CustomPasscodeBackground(size: size, colors: gradient.colors.compactMap { UIColor(rgb: $0) }, inverted: (gradient.settings.intensity ?? 0) < 0)
            case .image, .file:
                if let image = chatControllerBackgroundImage(theme: self.theme, wallpaper: self.wallpaper, mediaBox: self.accountManager.mediaBox, composed: false, knockoutMode: false) {
                    self.background = ImageBasedPasscodeBackground(image: image, size: size)
                } else {
                    if case let .file(file) = self.wallpaper, !file.settings.colors.isEmpty {
                        self.background = CustomPasscodeBackground(size: size, colors: file.settings.colors.compactMap { UIColor(rgb: $0) }, inverted: (file.settings.intensity ?? 0) < 0)
                    } else {
                        self.background = GradientPasscodeBackground(size: size, backgroundColors: self.theme.passcode.backgroundColors.colors, buttonColor: self.theme.passcode.buttonColor)
                    }
                }
            default:
                self.background = GradientPasscodeBackground(size: size, backgroundColors: self.theme.passcode.backgroundColors.colors, buttonColor: self.theme.passcode.buttonColor)
        }
        
        if let background = self.background {
            self.backgroundCustomNode?.removeFromSupernode()
            self.backgroundCustomNode = nil
            
            if let backgroundImage = background.backgroundImage {
                self.backgroundImageNode.image = backgroundImage
                self.backgroundDimNode.isHidden = true
            } else if let customBackgroundNode = background.makeBackgroundNode() {
                self.backgroundCustomNode = customBackgroundNode
                self.insertSubnode(customBackgroundNode, aboveSubnode: self.backgroundImageNode)
                if let background = background as? CustomPasscodeBackground, background.inverted {
                    self.backgroundDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.75)
                } else {
                    self.backgroundDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.15)
                }
                self.backgroundDimNode.isHidden = false
            }
            self.keyboardNode.updateBackground(self.presentationData, background)
            self.inputFieldNode.updateBackground(background)
        }
    }
    
    private let waitInterval: Int32 = 60
    private func shouldWaitBeforeNextAttempt() -> Bool {
        if let attempts = self.invalidAttempts {
            if attempts.count >= 6 {
                var bootTimestamp: Int32 = 0
                let uptime = getDeviceUptimeSeconds(&bootTimestamp)
                
                if attempts.bootTimestamp != bootTimestamp {
                    return true
                }
                
                if uptime - attempts.uptime < waitInterval {
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
                let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                    if let strongSelf = self {
                        if !strongSelf.shouldWaitBeforeNextAttempt() {
                            strongSelf.updateInvalidAttempts(strongSelf.invalidAttempts, animated: true)
                            strongSelf.timer?.invalidate()
                            strongSelf.timer = nil
                        }
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
        self.biometricButtonNode.layer.animateScale(from: 1.0, to: 0.00001, duration: 0.25, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { [weak self] _ in
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
            self.backgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            if let gradientNode = self.backgroundCustomNode as? GradientBackgroundNode {
                gradientNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                self.backgroundDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                gradientNode.animateEvent(transition: .animated(duration: 1.0, curve: .spring), extendAnimation: true, backwards: false, completion: {})
            }
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
        self.backgroundImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        if let gradientNode = self.backgroundCustomNode as? GradientBackgroundNode {
            gradientNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            gradientNode.animateEvent(transition: .animated(duration: 0.35, curve: .spring), extendAnimation: false, backwards: false, completion: {})
            self.backgroundDimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        if !iconFrame.isEmpty {
            self.iconNode.animateIn(fromScale: 0.416)
            self.iconNode.layer.animatePosition(from: iconFrame.center.offsetBy(dx: 6.0, dy: 6.0), to: self.iconNode.layer.position, duration: 0.45)
            
            Queue.mainQueue().after(0.45) {
                self.hapticFeedback.impact(.medium)
            }
        }
        
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
            
            if let gradientNode = self.backgroundCustomNode as? GradientBackgroundNode {
                gradientNode.animateEvent(transition: .animated(duration: 1.0, curve: .spring), extendAnimation: false, backwards: false, completion: {})
            }
            self.inputFieldNode.animateIn()
            self.keyboardNode.animateIn()
            var biometricDelay = 0.3
            if case .alphanumeric = self.passcodeType {
                biometricDelay = 0.0
            } else {
                self.cancelButtonNode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                self.deleteButtonNode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            }
            self.biometricButtonNode.layer.animateScale(from: 0.0001, to: 1.0, duration: 0.25, delay: biometricDelay, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            
            Queue.mainQueue().after(1.5, {
                self.titleNode.setAttributedText(NSAttributedString(string: self.strings.EnterPasscode_EnterPasscode, font: titleFont, textColor: .white), animation: .crossFade)
                if let validLayout = self.validLayout {
                    self.containerLayoutUpdated(validLayout, navigationBarHeight: 0.0, transition: .animated(duration: 0.5, curve: .easeInOut))
                }
            })
            
            completion()
        })
    }
    
    func animateOut(down: Bool = false, completion: @escaping () -> Void = {}) {
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
        
        if let gradientNode = self.backgroundCustomNode as? GradientBackgroundNode {
            gradientNode.animateEvent(transition: .animated(duration: 1.5, curve: .spring), extendAnimation: true, backwards: true, completion: {})
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        self.updateBackground()
            
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(node: self.backgroundImageNode, frame: bounds)
        transition.updateFrame(node: self.backgroundDimNode, frame: bounds)
        if let backgroundCustomNode = self.backgroundCustomNode {
            transition.updateFrame(node: backgroundCustomNode, frame: bounds)
            if let gradientBackgroundNode = backgroundCustomNode as? GradientBackgroundNode {
                gradientBackgroundNode.updateLayout(size: bounds.size, transition: transition, extendAnimation: false, backwards: false, completion: {})
            }
        }
        transition.updateFrame(view: self.effectView, frame: bounds)
        
        switch self.passcodeType {
            case .digits6, .digits4:
                self.keyboardNode.alpha = 1.0
                self.deleteButtonNode.alpha = 1.0
            case .alphanumeric:
                self.keyboardNode.alpha = 0.0
                self.deleteButtonNode.alpha = 0.0
        }
        
        let isLandscape = layout.orientation == .landscape && layout.deviceMetrics.type != .tablet
        let keyboardHidden = self.keyboardNode.alpha == 0.0
        
        let layoutSize: CGSize
        if isLandscape {
            if keyboardHidden {
                layoutSize = CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: layout.size.height)
            } else {
                layoutSize = CGSize(width: layout.size.width / 2.0, height: layout.size.height)
            }
        } else {
            layoutSize = layout.size
        }
        
        if layout.size.width == 320.0 || (isLandscape && keyboardHidden) {
            self.iconNode.alpha = 0.0
        } else {
            self.iconNode.alpha = 1.0
        }
                
        let passcodeLayout = PasscodeLayout(layout: layout, modalPresentation: self.modalPresentation)
        let inputFieldOffset: CGFloat
        if isLandscape {
            let bottomInset = layout.inputHeight ?? 0.0
            if !keyboardHidden || bottomInset == 0.0 {
                inputFieldOffset = floor(layoutSize.height / 2.0 + 12.0)
            } else {
                inputFieldOffset = floor(layoutSize.height - bottomInset) / 2.0 - 40.0
            }
        } else {
            inputFieldOffset = passcodeLayout.inputFieldOffset
        }
        
        let inputFieldFrame = self.inputFieldNode.updateLayout(size: layoutSize, topOffset: inputFieldOffset, transition: transition)
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left, y: 0.0), size: layoutSize))
                
        let titleFrame: CGRect
        if isLandscape {
            let titleSize = self.titleNode.updateLayout(size: CGSize(width: layoutSize.width, height: layout.size.height), transition: transition)
            titleFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: inputFieldFrame.minY - titleSize.height - 16.0), size: titleSize)
        } else {
            let titleSize = self.titleNode.updateLayout(size: layout.size, transition: transition)
            titleFrame = CGRect(origin: CGPoint(x: 0.0, y: passcodeLayout.titleOffset), size: titleSize)
        }
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let iconSize = CGSize(width: 35.0, height: 37.0)
        let iconFrame: CGRect
        if isLandscape {
            iconFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left + floor((layoutSize.width - iconSize.width) / 2.0) + 6.0, y: titleFrame.minY - iconSize.height - 14.0), size: iconSize)
        } else {
            iconFrame = CGRect(origin: CGPoint(x: floor((layoutSize.width - iconSize.width) / 2.0) + 6.0, y: layout.insets(options: .statusBar).top + 15.0), size: iconSize)
        }
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
        
        var subtitleOffset = passcodeLayout.subtitleOffset
        if case .alphanumeric = self.passcodeType {
            subtitleOffset = 16.0
        }
        let subtitleSize = self.subtitleNode.updateLayout(size: layoutSize, transition: transition)
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left, y: inputFieldFrame.maxY + subtitleOffset), size: subtitleSize))
        
        let (keyboardFrame, keyboardButtonSize) = self.keyboardNode.updateLayout(layout: passcodeLayout, transition: transition)
        transition.updateFrame(node: self.keyboardNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: layout.size))
                
        let bottomInset = layout.inputHeight ?? 0.0
        
        let cancelSize = self.cancelButtonNode.measure(layout.size)
        var bottomButtonY = layout.size.height - layout.intrinsicInsets.bottom - cancelSize.height - passcodeLayout.keyboard.deleteOffset
        var cancelX = floor(keyboardFrame.minX + keyboardButtonSize.width / 2.0 - cancelSize.width / 2.0)
        var cancelY = bottomButtonY
        if bottomInset > 0 && keyboardHidden {
            cancelX = floor((layout.size.width - cancelSize.width) / 2.0)
            cancelY = layout.size.height - bottomInset - cancelSize.height - 15.0 - layout.intrinsicInsets.bottom
        } else if isLandscape {
            bottomButtonY = keyboardFrame.maxY - keyboardButtonSize.height + floor((keyboardButtonSize.height - cancelSize.height) / 2.0)
            cancelY = bottomButtonY
        }
        
        transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: cancelX, y: cancelY), size: cancelSize))
        
        let deleteSize = self.deleteButtonNode.measure(layout.size)
        transition.updateFrame(node: self.deleteButtonNode, frame: CGRect(origin: CGPoint(x: floor(keyboardFrame.maxX - keyboardButtonSize.width / 2.0 - deleteSize.width / 2.0), y: bottomButtonY), size: deleteSize))
        
        if let biometricIcon = self.biometricButtonNode.image(for: .normal) {
            var biometricX = layout.safeInsets.left + floor((layoutSize.width - biometricIcon.size.width) / 2.0)
            var biometricY: CGFloat = 0.0
            if isLandscape {
                if bottomInset > 0 && keyboardHidden {
                    biometricX = cancelX + cancelSize.width + 64.0
                }
                biometricY = cancelY + floor((cancelSize.height - biometricIcon.size.height) / 2.0)
            } else {
                if bottomInset > 0 && keyboardHidden {
                    biometricY = inputFieldFrame.maxY + floor((layout.size.height - bottomInset - inputFieldFrame.maxY - biometricIcon.size.height) / 2.0)
                } else {
                    biometricY = keyboardFrame.maxY + passcodeLayout.keyboard.biometricsOffset
                }
            }
            transition.updateFrame(node: self.biometricButtonNode, frame: CGRect(origin: CGPoint(x: biometricX, y: biometricY), size: biometricIcon.size))
        }
    }
}
