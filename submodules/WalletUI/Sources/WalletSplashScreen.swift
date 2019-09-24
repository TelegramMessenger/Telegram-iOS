import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SolidRoundedButtonNode
import AnimationUI
import SwiftSignalKit
import OverlayStatusController
import ItemListUI
import AlertUI
import TextFormat

public enum WalletSplashMode {
    case intro
    case created(WalletInfo, [String])
    case success(WalletInfo)
    case restoreFailed
    case sending(WalletInfo, String, Int64, String)
    case sent(WalletInfo, Int64)
}

public final class WalletSplashScreen: ViewController {
    private let context: AccountContext
    private let tonContext: TonContext
    private var presentationData: PresentationData
    private let mode: WalletSplashMode
    
    public init(context: AccountContext, tonContext: TonContext, mode: WalletSplashMode) {
        self.context = context
        self.tonContext = tonContext
        self.mode = mode
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let defaultNavigationPresentationData = NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultNavigationPresentationData.theme.buttonColor, disabledButtonColor: defaultNavigationPresentationData.theme.disabledButtonColor, primaryTextColor: defaultNavigationPresentationData.theme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultNavigationPresentationData.theme.badgeBackgroundColor, badgeStrokeColor: defaultNavigationPresentationData.theme.badgeStrokeColor, badgeTextColor: defaultNavigationPresentationData.theme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: defaultNavigationPresentationData.strings))
        
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        switch self.mode {
        case .intro:
            self.navigationItem.setLeftBarButton(UIBarButtonItem(title: "Not Now", style: .plain, target: self, action: #selector(self.backPressed)), animated: false)
            self.navigationItem.setRightBarButton(UIBarButtonItem(title: "Import existing wallet", style: .plain, target: self, action: #selector(self.importPressed)), animated: false)
        case let .sending(walletInfo, address, amount, textMessage):
            self.navigationItem.setLeftBarButton(UIBarButtonItem(customDisplayNode: ASDisplayNode())!, animated: false)
            
            let _ = (sendGramsFromWallet(network: self.context.account.network, tonInstance: self.tonContext.instance, keychain: self.tonContext.keychain, walletInfo: walletInfo, toAddress: address, amount: amount, textMessage: textMessage)
            |> deliverOnMainQueue).start(error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                let controller = textAlertController(context: strongSelf.context, title: nil, text: "Error", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {
                    if let navigationController = strongSelf.navigationController as? NavigationController {
                        navigationController.popViewController(animated: true)
                    }
                })])
                strongSelf.present(controller, in: .window(.root))
            }, completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    var controllers = navigationController.viewControllers
                    controllers = controllers.filter { controller in
                        if controller is WalletSplashScreen {
                            return false
                        }
                        if controller is WalletSendScreen {
                            return false
                        }
                        if controller is WalletInfoScreen {
                            return false
                        }
                        return true
                    }
                    controllers.append(WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .sent(walletInfo, amount)))
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                }
            })
        case .sent:
            self.navigationItem.setLeftBarButton(UIBarButtonItem(customDisplayNode: ASDisplayNode())!, animated: false)
        case .created, .success, .restoreFailed:
            break
        }
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    @objc private func importPressed() {
        self.push(WalletWordCheckScreen(context: self.context, tonContext: self.tonContext, mode: .import))
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletSplashScreenNode(account: self.context.account, presentationData: self.presentationData, mode: self.mode, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case .intro:
                let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, type: .loading(cancelled: nil))
                strongSelf.present(controller, in: .window(.root))
                let _ = (createWallet(postbox: strongSelf.context.account.postbox, network: strongSelf.context.account.network, tonInstance: strongSelf.tonContext.instance, keychain: strongSelf.tonContext.keychain)
                |> deliverOnMainQueue).start(next: { walletInfo, wordList in
                    guard let strongSelf = self else {
                        return
                    }
                    controller.dismiss()
                    (strongSelf.navigationController as? NavigationController)?.replaceController(strongSelf, with: WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .created(walletInfo, wordList)), animated: true)
                })
            case let .created(walletInfo, wordList):
                strongSelf.push(WalletWordDisplayScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, walletInfo: walletInfo, wordList: wordList))
            case let .success(walletInfo), let .sent(walletInfo, _):
                let _ = (walletAddress(publicKey: walletInfo.publicKey, tonInstance: strongSelf.tonContext.instance)
                |> deliverOnMainQueue).start(next: { address in
                    guard let strongSelf = self else {
                        return
                    }
                    if let navigationController = strongSelf.navigationController as? NavigationController {
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { controller in
                            if controller is WalletSplashScreen {
                                return false
                            }
                            if controller is WalletWordDisplayScreen {
                                return false
                            }
                            if controller is WalletWordCheckScreen {
                                return false
                            }
                            return true
                        }
                        controllers.append(WalletInfoScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, walletInfo: walletInfo, address: address))
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    }
                })
            case .restoreFailed:
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    var controllers = navigationController.viewControllers
                    controllers = controllers.filter { controller in
                        if controller is WalletSplashScreen {
                            return false
                        }
                        if controller is WalletWordDisplayScreen {
                            return false
                        }
                        if controller is WalletWordCheckScreen {
                            return false
                        }
                        return true
                    }
                    controllers.append(WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .intro))
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                }
            case .sending:
                break
            }
        }, secondaryAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.push(WalletWordCheckScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .import))
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletSplashScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletSplashScreenNode: ViewControllerTracingNode {
    private var presentationData: PresentationData
    private let mode: WalletSplashMode
    private let secondaryAction: () -> Void
    
    private let iconNode: ASImageNode
    private let animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let buttonNode: SolidRoundedButtonNode
    private let termsNode: ImmediateTextNode
    private let secondaryActionTitleNode: ImmediateTextNode
    private let secondaryActionButtonNode: HighlightTrackingButtonNode
    
    var inProgress: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = !self.inProgress
            self.buttonNode.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(account: Account, presentationData: PresentationData, mode: WalletSplashMode, action: @escaping () -> Void, secondaryAction: @escaping () -> Void) {
        self.presentationData = presentationData
        self.mode = mode
        self.secondaryAction = secondaryAction
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.animationNode = AnimatedStickerNode()
        
        let title: String
        let text: NSAttributedString
        let buttonText: String
        let termsText: String
        let secondaryActionText: String
        
        let textFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        
        switch mode {
        case .intro:
            title = "Gram Wallet"
            text = NSAttributedString(string: "Gram wallet allows you to make fast and secure blockchain-based payments without intermediaries.", font: textFont, textColor: textColor)
            buttonText = "Create My Wallet"
            termsText = "By creating the wallet you accept\nTerms of Conditions."
            self.iconNode.image = UIImage(bundleImageName: "Settings/Wallet/IntroIcon")
            secondaryActionText = ""
        case .created:
            title = "Congratulations"
            text = NSAttributedString(string: "Your Gram wallet has just been created. Only you control it.\n\nTo be able to always have access to it, please write down secret words and\nset up a secure passcode.", font: textFont, textColor: textColor)
            buttonText = "Proceed"
            termsText = ""
            self.iconNode.image = UIImage(bundleImageName: "Settings/Wallet/CreatedIcon")
            secondaryActionText = ""
        case .success:
            title = "Ready to go!"
            text = NSAttributedString(string: "You’re all set. Now you have a wallet that only you control - directly, without middlemen or bankers. ", font: textFont, textColor: textColor)
            buttonText = "View My Wallet"
            termsText = ""
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "celebrate", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 280, height: 280, mode: .direct)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case .restoreFailed:
            title = "Too Bad"
            text = NSAttributedString(string: "Without the secret words, you can't'nrestore access to the wallet.", font: textFont, textColor: textColor)
            buttonText = "Create a New Wallet"
            termsText = ""
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "sad", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 280, height: 280, mode: .direct)
                self.animationNode.visibility = true
            }
            secondaryActionText = "Enter 24 words"
        case .sending:
            title = "Sending Grams"
            text = NSAttributedString(string: "Please wait a few seconds for your transaction to be processed...", font: textFont, textColor: textColor)
            buttonText = ""
            termsText = ""
            self.iconNode.image = UIImage(bundleImageName: "Settings/Wallet/SendingIcon")
            secondaryActionText = ""
        case let .sent(_, amount):
            title = "Done!"
            let bodyAttributes = MarkdownAttributeSet(font: textFont, textColor: textColor)
            let boldAttributes = MarkdownAttributeSet(font: Font.semibold(16.0), textColor: textColor)
            text = parseMarkdownIntoAttributedString("**\(formatBalanceText(amount, decimalSeparator: self.presentationData.dateTimeFormat.decimalSeparator)) Grams** have been sent.", attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }), textAlignment: .center)
            buttonText = "View My Wallet"
            termsText = ""
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "celebrate", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 280, height: 280, mode: .direct)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = text
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.termsNode = ImmediateTextNode()
        self.termsNode.displaysAsynchronously = false
        self.termsNode.attributedText = NSAttributedString(string: termsText, font: Font.regular(13.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
        self.termsNode.maximumNumberOfLines = 0
        self.termsNode.textAlignment = .center
        
        self.secondaryActionTitleNode = ImmediateTextNode()
        self.secondaryActionTitleNode.displaysAsynchronously = false
        self.secondaryActionTitleNode.attributedText = NSAttributedString(string: secondaryActionText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemAccentColor)
        
        self.secondaryActionButtonNode = HighlightTrackingButtonNode()
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 50.0, cornerRadius: 10.0, gloss: true)
        self.buttonNode.isHidden = buttonText.isEmpty
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.termsNode)
        self.addSubnode(self.secondaryActionTitleNode)
        self.addSubnode(self.secondaryActionButtonNode)
        
        self.buttonNode.pressed = {
            action()
        }
        
        self.secondaryActionButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.secondaryActionTitleNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.secondaryActionTitleNode.alpha = 0.4
            } else {
                strongSelf.secondaryActionTitleNode.alpha = 1.0
                strongSelf.secondaryActionTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.secondaryActionButtonNode.addTarget(self, action: #selector(self.secondaryActionPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func secondaryActionPressed() {
        self.secondaryAction()
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 5.0
        let titleSpacing: CGFloat = 19.0
        let termsSpacing: CGFloat = 11.0
        let buttonHeight: CGFloat = 50.0
        
        let iconSize: CGSize
        var iconOffset = CGPoint()
        switch self.mode {
        case .success:
            iconSize = CGSize(width: 140.0, height: 140.0)
            iconOffset.x = 10.0
        default:
            iconSize = self.iconNode.image?.size ?? CGSize(width: 140.0, height: 140.0)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let termsSize = self.termsNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let secondaryActionSize = self.secondaryActionTitleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        
        let contentHeight = iconSize.height + iconSpacing + titleSize.height + titleSpacing + textSize.height
        let contentVerticalOrigin = floor((layout.size.height - contentHeight - iconSize.height / 2.0) / 2.0)
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
        transition.updateFrameAdditive(node: self.iconNode, frame: iconFrame)
        self.animationNode.updateLayout(size: iconFrame.size)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        let minimalBottomInset: CGFloat = 60.0
        let bottomInset = layout.intrinsicInsets.bottom + max(minimalBottomInset, termsSize.height + termsSpacing * 2.0)
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        if !secondaryActionSize.width.isZero {
            let secondaryActionFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - secondaryActionSize.width) / 2.0), y: buttonFrame.minY - 20.0 - secondaryActionSize.height), size: secondaryActionSize)
            transition.updateFrameAdditive(node: self.secondaryActionTitleNode, frame: secondaryActionFrame)
            transition.updateFrame(node: self.secondaryActionButtonNode, frame: secondaryActionFrame.insetBy(dx: -10.0, dy: -10.0))
        }
        
        let termsFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - termsSize.width) / 2.0), y: buttonFrame.maxY + floor((layout.size.height - layout.intrinsicInsets.bottom - buttonFrame.maxY - termsSize.height) / 2.0)), size: termsSize)
        transition.updateFrameAdditive(node: self.termsNode, frame: termsFrame)
    }
}
