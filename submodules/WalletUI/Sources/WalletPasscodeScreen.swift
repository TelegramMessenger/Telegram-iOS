/*import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import AnimationUI
import SwiftSignalKit
import OverlayStatusController
import PasscodeInputFieldNode

public enum WalletPasscodeMode {
    case setup
    case authorizeTransfer(WalletInfo, String, Int64, Data)
}

public final class WalletPasscodeScreen: ViewController {
    private let context: WalletContext
    private var presentationData: WalletPresentationData
    private let mode: WalletPasscodeMode
    private let randomId: Int64
    
    public init(context: WalletContext, mode: WalletPasscodeMode) {
        self.context = context
        self.mode = mode
        
        self.randomId = arc4random64()
        
        self.presentationData = context.presentationData
        
        let defaultNavigationPresentationData = NavigationBarPresentationData(WalletTheme: self.presentationData.theme, WalletStrings: self.presentationData.strings)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultNavigationPresentationData.theme.buttonColor, disabledButtonColor: defaultNavigationPresentationData.theme.disabledButtonColor, primaryTextColor: defaultNavigationPresentationData.theme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultNavigationPresentationData.theme.badgeBackgroundColor, badgeStrokeColor: defaultNavigationPresentationData.theme.badgeStrokeColor, badgeTextColor: defaultNavigationPresentationData.theme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: defaultNavigationPresentationData.strings))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.backPressed)), animated: false)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func backPressed() {
        self.view.endEditing(true)
        self.dismiss()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletPasscodeScreenNode(account: self.context.account, WalletPresentationData: self.presentationData, mode: self.mode, proceed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
                case .setup:
                    break
                case let .authorizeTransfer(walletInfo, address, amount, comment):
                    if let navigationController = strongSelf.navigationController as? NavigationController {
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { controller in
                            if controller is WalletSplashScreen {
                                return false
                            }
                            if controller is WalletSendScreen {
                                return false
                            }
                            if controller is WalletPasscodeScreen {
                                return false
                            }
                            return true
                        }
                        controllers.append(WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .sending(walletInfo, address, amount, comment, strongSelf.randomId, Data()), walletCreatedPreloadState: nil))
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    }
            }
        }, requestBiometrics: {
            
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        (self.displayNode as! WalletPasscodeScreenNode).activateInput()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        (self.displayNode as! WalletPasscodeScreenNode).activateInput()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletPasscodeScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletPasscodeScreenNode: ViewControllerTracingNode {
    private var presentationData: WalletPresentationData
    private let mode: WalletPasscodeMode
    private let requestBiometrics: () -> Void
    
    private let iconNode: ASImageNode
    private let animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let biometricsActionTitleNode: ImmediateTextNode
    private let biometricsActionButtonNode: HighlightTrackingButtonNode
    private let inputFieldNode: PasscodeInputFieldNode
    
    private let hapticFeedback = HapticFeedback()
    
    init(account: Account, presentationData: WalletPresentationData, mode: WalletPasscodeMode, proceed: @escaping () -> Void, requestBiometrics: @escaping () -> Void) {
        self.presentationData = WalletPresentationData
        self.mode = mode
        self.requestBiometrics = requestBiometrics
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.animationNode = AnimatedStickerNode()
        
        let title: String
        let biometricsActionText: String
        
        title = "Enter Passcode"
        biometricsActionText = "Use Face ID"
        
        self.iconNode.image = UIImage(bundleImageName: "Settings/Wallet/PasscodeIcon")
       
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.biometricsActionTitleNode = ImmediateTextNode()
        self.biometricsActionTitleNode.displaysAsynchronously = false
        self.biometricsActionTitleNode.attributedText = NSAttributedString(string: biometricsActionText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemAccentColor, paragraphAlignment: .center)
        self.biometricsActionTitleNode.textAlignment = .center
        
        self.biometricsActionButtonNode = HighlightTrackingButtonNode()
        
        self.inputFieldNode = PasscodeInputFieldNode(color: self.presentationData.theme.list.itemPrimaryTextColor, accentColor: self.presentationData.theme.list.itemAccentColor, fieldType: .digits4, keyboardAppearance: self.presentationData.theme.rootController.keyboardColor.keyboardAppearance)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.biometricsActionTitleNode)
        self.addSubnode(self.biometricsActionButtonNode)
        self.addSubnode(self.inputFieldNode)
        
        self.biometricsActionButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.biometricsActionTitleNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.biometricsActionTitleNode.alpha = 0.4
            } else {
                strongSelf.biometricsActionTitleNode.alpha = 1.0
                strongSelf.biometricsActionTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.biometricsActionButtonNode.addTarget(self, action: #selector(self.biometricsActionPressed), forControlEvents: .touchUpInside)
        
        self.inputFieldNode.complete = { [weak self] passcode in
            if passcode == "1111" {
                proceed()
            } else {
                self?.animateError()
            }
        }
    }
    
    @objc private func biometricsActionPressed() {
        self.requestBiometrics()
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 21.0
        let titleSpacing: CGFloat = 60.0
        let biometricsSpacing: CGFloat = 44.0
        let buttonHeight: CGFloat = 50.0
        let inputFieldHeight: CGFloat = 34.0
        
        let iconSize = self.iconNode.image?.size ?? CGSize(width: 140.0, height: 140.0)
        var iconOffset = CGPoint()
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let biometricsActionSize = self.biometricsActionTitleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        
        let insets = layout.insets(options: [.input])
        let contentHeight = iconSize.height + iconSpacing + titleSize.height + titleSpacing + inputFieldHeight
        let contentVerticalOrigin = floor((layout.size.height - contentHeight - iconSize.height / 2.0 - insets.bottom) / 2.0)
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
        transition.updateFrameAdditive(node: self.iconNode, frame: iconFrame)
        self.animationNode.updateLayout(size: iconFrame.size)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        
        let inputFieldFrame = self.inputFieldNode.updateLayout(layout: layout, topOffset: titleFrame.maxY + titleSpacing, transition: transition)
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let minimalBottomInset: CGFloat = 60.0
        let bottomInset = layout.intrinsicInsets.bottom + max(minimalBottomInset, biometricsActionSize.height + biometricsSpacing * 2.0)
        
        if !biometricsActionSize.width.isZero {
            let biometricsActionFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - biometricsActionSize.width) / 2.0), y: inputFieldFrame.maxY + floor((layout.size.height - insets.bottom - inputFieldFrame.maxY - biometricsActionSize.height) / 2.0)), size: biometricsActionSize)
            transition.updateFrameAdditive(node: self.biometricsActionTitleNode, frame: biometricsActionFrame)
            transition.updateFrame(node: self.biometricsActionButtonNode, frame: biometricsActionFrame.insetBy(dx: -10.0, dy: -10.0))
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
}
*/
