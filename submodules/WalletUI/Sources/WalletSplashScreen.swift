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
import LocalAuth

public enum WalletSecureStorageResetReason {
    case notAvailable
    case changed
}

public enum WalletSplashMode {
    case intro
    case created(WalletInfo, [String])
    case success(WalletInfo)
    case restoreFailed
    case sending(WalletInfo, String, Int64, String, Int64)
    case sent(WalletInfo, Int64)
    case secureStorageNotAvailable
    case secureStorageReset(WalletSecureStorageResetReason)
}

public final class WalletSplashScreen: ViewController {
    private let context: AccountContext
    private let tonContext: TonContext
    private var presentationData: PresentationData
    private let mode: WalletSplashMode
    
    private let walletCreatedPreloadState: Promise<CombinedWalletStateResult>?
    
    public init(context: AccountContext, tonContext: TonContext, mode: WalletSplashMode, walletCreatedPreloadState: Promise<CombinedWalletStateResult>?) {
        self.context = context
        self.tonContext = tonContext
        self.mode = mode
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let defaultNavigationPresentationData = NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultNavigationPresentationData.theme.buttonColor, disabledButtonColor: defaultNavigationPresentationData.theme.disabledButtonColor, primaryTextColor: defaultNavigationPresentationData.theme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultNavigationPresentationData.theme.badgeBackgroundColor, badgeStrokeColor: defaultNavigationPresentationData.theme.badgeStrokeColor, badgeTextColor: defaultNavigationPresentationData.theme.badgeTextColor)
        
        switch mode {
        case let .created(walletInfo, _):
            if let walletCreatedPreloadState = walletCreatedPreloadState {
                self.walletCreatedPreloadState = walletCreatedPreloadState
            } else {
                self.walletCreatedPreloadState = Promise()
                self.walletCreatedPreloadState?.set(getCombinedWalletState(postbox: context.account.postbox, walletInfo: walletInfo, tonInstance: tonContext.instance)
                |> `catch` { _ -> Signal<CombinedWalletStateResult, NoError> in
                    return .complete()
                })
            }
        case let .success(walletInfo):
            if let walletCreatedPreloadState = walletCreatedPreloadState {
                self.walletCreatedPreloadState = walletCreatedPreloadState
            } else {
                self.walletCreatedPreloadState = Promise()
                self.walletCreatedPreloadState?.set(getCombinedWalletState(postbox: context.account.postbox, walletInfo: walletInfo, tonInstance: tonContext.instance)
                |> `catch` { _ -> Signal<CombinedWalletStateResult, NoError> in
                    return .complete()
                })
            }
        default:
            self.walletCreatedPreloadState = nil
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: defaultNavigationPresentationData.strings))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        switch self.mode {
        case .intro:
            self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Wallet_Intro_NotNow, style: .plain, target: self, action: #selector(self.backPressed)), animated: false)
            self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Wallet_Intro_ImportExisting, style: .plain, target: self, action: #selector(self.importPressed)), animated: false)
        case let .sending(walletInfo, address, amount, textMessage, randomId):
            self.navigationItem.setLeftBarButton(UIBarButtonItem(customDisplayNode: ASDisplayNode())!, animated: false)
            
            let _ = (sendGramsFromWallet(network: self.context.account.network, tonInstance: self.tonContext.instance, keychain: self.tonContext.keychain, walletInfo: walletInfo, toAddress: address, amount: amount, textMessage: textMessage, randomId: randomId)
            |> deliverOnMainQueue).start(error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                let text: String
                switch error {
                case .generic:
                    text = strongSelf.presentationData.strings.Login_UnknownError
                case .invalidAddress:
                    text = strongSelf.presentationData.strings.Wallet_Send_ErrorInvalidAddress
                case .secretDecryptionFailed:
                    text = strongSelf.presentationData.strings.Wallet_Send_ErrorDecryptionFailed
                }
                let controller = textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
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
                    controllers.append(WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .sent(walletInfo, amount), walletCreatedPreloadState: strongSelf.walletCreatedPreloadState))
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                }
            })
        case .sent, .created:
            self.navigationItem.setLeftBarButton(UIBarButtonItem(customDisplayNode: ASDisplayNode())!, animated: false)
        case .restoreFailed, .secureStorageNotAvailable, .secureStorageReset:
            break
        case .success:
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
        self.push(WalletWordCheckScreen(context: self.context, tonContext: self.tonContext, mode: .import, walletCreatedPreloadState: nil))
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
                    (strongSelf.navigationController as? NavigationController)?.replaceController(strongSelf, with: WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .created(walletInfo, wordList), walletCreatedPreloadState: nil), animated: true)
                }, error: { _ in
                    guard let strongSelf = self else {
                        return
                    }
                    controller.dismiss()
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: strongSelf.presentationData.strings.Wallet_Intro_CreateErrorTitle, text: strongSelf.presentationData.strings.Wallet_Intro_CreateErrorText, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                        })
                    ], actionLayout: .vertical), in: .window(.root))
                })
            case let .created(walletInfo, wordList):
                strongSelf.push(WalletWordDisplayScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, walletInfo: walletInfo, wordList: wordList, mode: .check, walletCreatedPreloadState: strongSelf.walletCreatedPreloadState))
            case let .success(walletInfo), let .sent(walletInfo, _):
                let _ = (walletAddress(publicKey: walletInfo.publicKey, tonInstance: strongSelf.tonContext.instance)
                |> deliverOnMainQueue).start(next: { address in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    var stateSignal: Signal<Bool, NoError>
                    if let walletCreatedPreloadState = strongSelf.walletCreatedPreloadState {
                        stateSignal = walletCreatedPreloadState.get()
                        |> map { state -> Bool in
                            if case .updated = state {
                                return true
                            } else {
                                return false
                            }
                        }
                        |> filter { $0 }
                    } else {
                        stateSignal = .single(true)
                    }
                    
                    let presentationData = strongSelf.presentationData
                    let progressSignal = Signal<Never, NoError> { subscriber in
                        let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings,  type: .loading(cancelled: nil))
                        self?.present(controller, in: .window(.root))
                        return ActionDisposable { [weak controller] in
                            Queue.mainQueue().async() {
                                controller?.dismiss()
                            }
                        }
                    }
                    |> runOn(Queue.mainQueue())
                    |> delay(0.15, queue: Queue.mainQueue())
                    let progressDisposable = progressSignal.start()
                    
                    stateSignal = stateSignal
                    |> afterDisposed {
                        Queue.mainQueue().async {
                            progressDisposable.dispose()
                        }
                    }
                    let _ = (stateSignal
                    |> deliverOnMainQueue).start(next: { _ in
                        guard let strongSelf = self else {
                            return
                        }
                        progressDisposable.dispose()
                        
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
                    controllers.append(WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .intro, walletCreatedPreloadState: nil))
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                }
            case .sending:
                break
            case .secureStorageNotAvailable:
                strongSelf.dismiss()
            case let .secureStorageReset(reason):
                switch reason {
                case .notAvailable:
                    strongSelf.dismiss()
                case .changed:
                    strongSelf.push(WalletWordCheckScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .import, walletCreatedPreloadState: nil))
                }
            }
        }, secondaryAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case .secureStorageNotAvailable, .secureStorageReset:
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
                    controllers.append(WalletSplashScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .intro, walletCreatedPreloadState: nil))
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                }
            default:
                strongSelf.push(WalletWordCheckScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, mode: .import, walletCreatedPreloadState: nil))
            }
        }, openTerms: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var url = strongSelf.presentationData.strings.Wallet_Intro_TermsUrl
            if url.isEmpty {
                url = "https://telegram.org/tos/wallet"
            }
            strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.presentationData, navigationController: strongSelf.navigationController as? NavigationController, dismissInput: {})
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
    private var animationSize: CGSize = CGSize()
    private let animationNode: AnimatedStickerNode
    private let alternativeAnimationNode: AnimatedStickerNode
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
    
    init(account: Account, presentationData: PresentationData, mode: WalletSplashMode, action: @escaping () -> Void, secondaryAction: @escaping () -> Void, openTerms: @escaping () -> Void) {
        self.presentationData = presentationData
        self.mode = mode
        self.secondaryAction = secondaryAction
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.animationNode = AnimatedStickerNode()
        self.alternativeAnimationNode = AnimatedStickerNode()
        
        let title: String
        let text: NSAttributedString
        let buttonText: String
        let termsText: NSAttributedString
        let secondaryActionText: String
        
        let textFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        
        switch mode {
        case .intro:
            title = self.presentationData.strings.Wallet_Intro_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_Intro_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Wallet_Intro_CreateWallet
            let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor, additionalAttributes: [:])
            let link = MarkdownAttributeSet(font: Font.regular(13.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor, additionalAttributes: [NSAttributedString.Key.underlineStyle.rawValue: NSUnderlineStyle.single.rawValue as NSNumber])
            termsText = parseMarkdownIntoAttributedString(self.presentationData.strings.Wallet_Intro_Terms, attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "WalletIntroLoading", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 248, height: 248, mode: .direct)
                self.animationSize = CGSize(width: 124.0, height: 124.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case .created:
            title = self.presentationData.strings.Wallet_Created_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_Created_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Wallet_Created_Proceed
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "WalletCreated", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 250, height: 250, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 125.0, height: 125.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case .success:
            title = self.presentationData.strings.Wallet_Completed_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_Completed_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Wallet_Completed_ViewWallet
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "celebrate", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 260, height: 260, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case .restoreFailed:
            title = self.presentationData.strings.Wallet_RestoreFailed_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_RestoreFailed_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Wallet_RestoreFailed_CreateWallet
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "sad", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 260, height: 260, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = self.presentationData.strings.Wallet_RestoreFailed_EnterWords
        case .sending:
            title = self.presentationData.strings.Wallet_Sending_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_Sending_Text, font: textFont, textColor: textColor)
            buttonText = ""
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "SendingGrams", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 260, height: 260, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case let .sent(_, amount):
            title = self.presentationData.strings.Wallet_Sent_Title
            let bodyAttributes = MarkdownAttributeSet(font: textFont, textColor: textColor)
            let boldAttributes = MarkdownAttributeSet(font: Font.semibold(16.0), textColor: textColor)
            text = parseMarkdownIntoAttributedString(self.presentationData.strings.Wallet_Sent_Text(formatBalanceText(amount, decimalSeparator: self.presentationData.dateTimeFormat.decimalSeparator)).0, attributes: MarkdownAttributes(body: bodyAttributes, bold: boldAttributes, link: bodyAttributes, linkAttribute: { _ in return nil }), textAlignment: .center)
            buttonText = self.presentationData.strings.Wallet_Sent_ViewWallet
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "celebrate", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 260, height: 260, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case .secureStorageNotAvailable:
            title = self.presentationData.strings.Wallet_SecureStorageNotAvailable_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_SecureStorageNotAvailable_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Common_OK
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "WalletKeyLock", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 280, height: 280, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 140.0, height: 140.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case let .secureStorageReset(reason):
            title = self.presentationData.strings.Wallet_SecureStorageReset_Title
            
            let biometricTypeString: String?
            if let type = LocalAuth.biometricAuthentication {
                switch type {
                case .faceId:
                    biometricTypeString = self.presentationData.strings.Wallet_SecureStorageReset_BiometryFaceId
                case .touchId:
                    biometricTypeString = self.presentationData.strings.Wallet_SecureStorageReset_BiometryTouchId
                }
            } else {
                biometricTypeString = nil
            }
            
            switch reason {
            case .notAvailable:
                let string: String
                if let biometricTypeString = biometricTypeString {
                    string = self.presentationData.strings.Wallet_SecureStorageReset_BiometryText(biometricTypeString).0
                } else {
                    string = self.presentationData.strings.Wallet_SecureStorageReset_PasscodeText
                }
                text = NSAttributedString(string: string, font: textFont, textColor: textColor)
                buttonText = self.presentationData.strings.Common_OK
                secondaryActionText = ""
            case .changed:
                let string: String
                if let biometricTypeString = biometricTypeString {
                    string = self.presentationData.strings.Wallet_SecureStorageChanged_BiometryText(biometricTypeString).0
                } else {
                    string = self.presentationData.strings.Wallet_SecureStorageChanged_PasscodeText
                }
                text = NSAttributedString(string: string, font: textFont, textColor: textColor)
                buttonText = self.presentationData.strings.Wallet_SecureStorageChanged_ImportWallet
                secondaryActionText = self.presentationData.strings.Wallet_SecureStorageChanged_CreateWallet
            }
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "sad", ofType: "tgs") {
                self.animationNode.setup(account: account, resource: .localFile(path), width: 260, height: 260, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationNode.visibility = true
            }
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
        self.termsNode.attributedText = termsText
        self.termsNode.maximumNumberOfLines = 0
        self.termsNode.textAlignment = .center
        
        self.secondaryActionTitleNode = ImmediateTextNode()
        self.secondaryActionTitleNode.displaysAsynchronously = false
        self.secondaryActionTitleNode.attributedText = NSAttributedString(string: secondaryActionText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemAccentColor)
        
        self.secondaryActionButtonNode = HighlightTrackingButtonNode()
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 50.0, cornerRadius: 10.0, gloss: false)
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
        
        self.termsNode.linkHighlightColor = self.presentationData.theme.list.itemSecondaryTextColor.withAlphaComponent(0.5)
        self.termsNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key.underlineStyle] {
                return NSAttributedString.Key.underlineStyle
            } else {
                return nil
            }
        }
        self.termsNode.tapAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key.underlineStyle] {
                openTerms()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        switch self.mode {
        case .created, .sending, .sent:
            self.view.disablesInteractiveTransitionGestureRecognizer = true
        default:
            break
        }
    }
    
    @objc private func secondaryActionPressed() {
        self.secondaryAction()
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 8.0
        let titleSpacing: CGFloat = 19.0
        let termsSpacing: CGFloat = 11.0
        let buttonHeight: CGFloat = 50.0
        
        let iconSize: CGSize = self.animationSize
        var iconOffset = CGPoint()
        switch self.mode {
        case .success:
            iconOffset.x = 10.0
        default:
            break
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
