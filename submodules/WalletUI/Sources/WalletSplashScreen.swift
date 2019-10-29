import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import AlertUI
import LocalAuth
import AnimatedStickerNode
import WalletCore
import Markdown

public enum WalletSecureStorageResetReason {
    case notAvailable
    case changed
}

public enum WalletSplashMode {
    case intro
    case created(WalletInfo, [String]?)
    case success(WalletInfo)
    case restoreFailed
    case sending(WalletInfo, String, Int64, Data, Int64, Data)
    case sent(WalletInfo, Int64)
    case secureStorageNotAvailable
    case secureStorageReset(WalletSecureStorageResetReason)
}

public final class WalletSplashScreen: ViewController {
    private let context: WalletContext
    private var presentationData: WalletPresentationData
    private var mode: WalletSplashMode
    
    private let walletCreatedPreloadState: Promise<CombinedWalletStateResult?>?
    
    private let actionDisposable = MetaDisposable()
    
    public init(context: WalletContext, mode: WalletSplashMode, walletCreatedPreloadState: Promise<CombinedWalletStateResult?>?) {
        self.context = context
        self.mode = mode
        
        self.presentationData = context.presentationData
        
        let defaultTheme = self.presentationData.theme.navigationBar
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        switch mode {
        case let .created(walletInfo, _):
            if let walletCreatedPreloadState = walletCreatedPreloadState {
                self.walletCreatedPreloadState = walletCreatedPreloadState
            } else {
                self.walletCreatedPreloadState = Promise()
                self.walletCreatedPreloadState?.set(getCombinedWalletState(storage: context.storage, subject: .wallet(walletInfo), tonInstance: context.tonInstance)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<CombinedWalletStateResult?, NoError> in
                    return .single(nil)
                })
            }
        case let .success(walletInfo):
            if let walletCreatedPreloadState = walletCreatedPreloadState {
                self.walletCreatedPreloadState = walletCreatedPreloadState
            } else {
                self.walletCreatedPreloadState = Promise()
                self.walletCreatedPreloadState?.set(getCombinedWalletState(storage: context.storage, subject: .wallet(walletInfo), tonInstance: context.tonInstance)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<CombinedWalletStateResult?, NoError> in
                    return .single(nil)
                })
            }
        default:
            self.walletCreatedPreloadState = nil
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Wallet_Intro_NotNow, close: self.presentationData.strings.Wallet_Navigation_Close)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.statusBarStyle
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        switch self.mode {
        case let .intro: self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Wallet_Intro_ImportExisting, style: .plain, target: self, action: #selector(self.importPressed)), animated: false)
        case let .sending(walletInfo, address, amount, textMessage, randomId, serverSalt):
            self.navigationItem.setLeftBarButton(UIBarButtonItem(customDisplayNode: ASDisplayNode())!, animated: false)
            let _ = (self.context.keychain.decrypt(walletInfo.encryptedSecret)
            |> deliverOnMainQueue).start(next: { [weak self] decryptedSecret in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.sendGrams(walletInfo: walletInfo, decryptedSecret: decryptedSecret, address: address, amount: amount, textMessage: textMessage, forceIfDestinationNotInitialized: true, randomId: randomId, serverSalt: serverSalt)
            }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                if case .cancelled = error {
                    strongSelf.dismiss()
                } else {
                    let text = strongSelf.presentationData.strings.Wallet_Send_ErrorDecryptionFailed
                    let theme = strongSelf.context.presentationData.theme
                    let controller = textAlertController(alertContext: AlertControllerContext(theme: theme.alert, themeSignal: .single(theme.alert)), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                        self?.dismiss()
                    })])
                    strongSelf.present(controller, in: .window(.root))
                    strongSelf.dismiss()
                }
            })
        case .sent:
            self.navigationItem.setLeftBarButton(UIBarButtonItem(customDisplayNode: ASDisplayNode())!, animated: false)
        case .restoreFailed, .secureStorageNotAvailable, .secureStorageReset, .created:
            break
        case .success:
            break
        }
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    @objc private func importPressed() {
        self.push(WalletWordCheckScreen(context: self.context, mode: .import, walletCreatedPreloadState: nil))
    }
    
    private func sendGrams(walletInfo: WalletInfo, decryptedSecret: Data, address: String, amount: Int64, textMessage: Data, forceIfDestinationNotInitialized: Bool, randomId: Int64, serverSalt: Data) {
        let _ = (sendGramsFromWallet(storage: self.context.storage, tonInstance: self.context.tonInstance, walletInfo: walletInfo, decryptedSecret: decryptedSecret, localPassword: serverSalt, toAddress: address, amount: amount, textMessage: textMessage, forceIfDestinationNotInitialized: forceIfDestinationNotInitialized, timeout: 0, randomId: randomId)
        |> deliverOnMainQueue).start(next: { [weak self] sentTransaction in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.navigationItem.setRightBarButton(UIBarButtonItem(title: strongSelf.presentationData.strings.Wallet_WordImport_Continue, style: .plain, target: strongSelf, action: #selector(strongSelf.sendGramsContinuePressed)), animated: false)
            
            let check = getCombinedWalletState(storage: strongSelf.context.storage, subject: .wallet(walletInfo), tonInstance: strongSelf.context.tonInstance)
            |> mapToSignal { state -> Signal<Bool, GetCombinedWalletStateError> in
                switch state {
                case .cached:
                    return .complete()
                case let .updated(state):
                    if !state.pendingTransactions.contains(where: { $0.bodyHash == sentTransaction.bodyHash }) {
                        return .single(true)
                    } else {
                        return .complete()
                    }
                }
            }
            |> then(
                .complete()
                |> delay(3.0, queue: .concurrentDefaultQueue())
            )
            |> restart
            |> take(1)
            
            strongSelf.actionDisposable.set((check
            |> deliverOnMainQueue).start(error: { _ in
                guard let strongSelf = self else {
                    return
                }
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    let _ = (walletAddress(publicKey: walletInfo.publicKey, tonInstance: strongSelf.context.tonInstance)
                    |> deliverOnMainQueue).start(next: { [weak self] address in
                        guard let strongSelf = self else {
                            return
                        }
                        var controllers: [UIViewController] = []
                        for controller in navigationController.viewControllers {
                            if let controller = controller as? WalletInfoScreen {
                                let infoScreen = WalletInfoScreen(context: strongSelf.context, walletInfo: walletInfo, address: address, enableDebugActions: false)
                                infoScreen.navigationPresentation = controller.navigationPresentation
                                controllers.append(infoScreen)
                            } else {
                                controllers.append(controller)
                            }
                        }
                        controllers.append(WalletSplashScreen(context: strongSelf.context, mode: .sent(walletInfo, amount), walletCreatedPreloadState: nil))
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    })
                }
            }, completed: {
                guard let strongSelf = self else {
                    return
                }
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    let _ = (walletAddress(publicKey: walletInfo.publicKey, tonInstance: strongSelf.context.tonInstance)
                    |> deliverOnMainQueue).start(next: { [weak self] address in
                        guard let strongSelf = self else {
                            return
                        }
                        var controllers: [UIViewController] = []
                        for controller in navigationController.viewControllers {
                            if let controller = controller as? WalletInfoScreen {
                                let infoScreen = WalletInfoScreen(context: strongSelf.context, walletInfo: walletInfo, address: address, enableDebugActions: false)
                                infoScreen.navigationPresentation = controller.navigationPresentation
                                controllers.append(infoScreen)
                            } else {
                                controllers.append(controller)
                            }
                        }
                        controllers.append(WalletSplashScreen(context: strongSelf.context, mode: .sent(walletInfo, amount), walletCreatedPreloadState: nil))
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    })
                }
            }))
        }, error: { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            var title: String?
            let text: String
            switch error {
            case .generic:
                text = strongSelf.presentationData.strings.Wallet_UnknownError
            case .network:
                title = strongSelf.presentationData.strings.Wallet_Send_NetworkErrorTitle
                text = strongSelf.presentationData.strings.Wallet_Send_NetworkErrorText
            case .notEnoughFunds:
                title = strongSelf.presentationData.strings.Wallet_Send_ErrorNotEnoughFundsTitle
                text = strongSelf.presentationData.strings.Wallet_Send_ErrorNotEnoughFundsText
            case .messageTooLong:
                text = strongSelf.presentationData.strings.Wallet_UnknownError
            case .invalidAddress:
                text = strongSelf.presentationData.strings.Wallet_Send_ErrorInvalidAddress
            case .secretDecryptionFailed:
                text = strongSelf.presentationData.strings.Wallet_Send_ErrorDecryptionFailed
            case .destinationIsNotInitialized:
                if !forceIfDestinationNotInitialized {
                    text = strongSelf.presentationData.strings.Wallet_Send_UninitializedText
                    let theme = strongSelf.context.presentationData.theme
                    let controller = textAlertController(alertContext: AlertControllerContext(theme: theme.alert, themeSignal: .single(theme.alert)), title: strongSelf.presentationData.strings.Wallet_Send_UninitializedTitle, text: text, actions: [
                        TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Wallet_Navigation_Cancel, action: {
                            if let navigationController = strongSelf.navigationController as? NavigationController {
                                navigationController.popViewController(animated: true)
                            }
                        }),
                        TextAlertAction(type: .defaultAction, title: "Send Anyway", action: {
                            self?.sendGrams(walletInfo: walletInfo, decryptedSecret: decryptedSecret, address: address, amount: amount, textMessage: textMessage, forceIfDestinationNotInitialized: true, randomId: randomId, serverSalt: serverSalt)
                        })
                    ])
                    strongSelf.present(controller, in: .window(.root))
                    return
                } else {
                    text = strongSelf.presentationData.strings.Wallet_UnknownError
                }
            }
            let theme = strongSelf.presentationData.theme
            let controller = textAlertController(alertContext: AlertControllerContext(theme: theme.alert, themeSignal: .single(theme.alert)), title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    navigationController.popViewController(animated: true)
                }
            })])
            strongSelf.present(controller, in: .window(.root))
        })
    }
    
    @objc private func sendGramsContinuePressed() {
        switch self.mode {
            case let .sending(sending):
            if let navigationController = self.navigationController as? NavigationController {
                var controllers = navigationController.viewControllers
                controllers = controllers.filter { controller in
                    if controller is WalletSendScreen {
                        return false
                    }
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
                
                let _ = (walletAddress(publicKey: sending.0.publicKey, tonInstance: self.context.tonInstance)
                |> deliverOnMainQueue).start(next: { [weak self] address in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if !controllers.contains(where: { $0 is WalletInfoScreen }) {
                        let infoScreen = WalletInfoScreen(context: strongSelf.context, walletInfo: sending.0, address: address, enableDebugActions: false)
                        infoScreen.navigationPresentation = .modal
                        controllers.append(infoScreen)
                    }
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                })
            }
        default:
            break
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletSplashScreenNode(context: self.context, walletCreatedPreloadState: self.walletCreatedPreloadState, presentationData: self.presentationData, mode: self.mode, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case .intro:
                let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                let displayError: () -> Void = {
                    guard let strongSelf = self else {
                        return
                    }
                    controller.dismiss()
                    strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_Intro_CreateErrorTitle, text: strongSelf.presentationData.strings.Wallet_Intro_CreateErrorText, actions: [
                        TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                        })
                    ], actionLayout: .vertical), in: .window(.root))
                }
                strongSelf.present(controller, in: .window(.root))
                let _ = (strongSelf.context.getServerSalt()
                |> deliverOnMainQueue).start(next: { serverSalt in
                    let _ = (createWallet(storage: strongSelf.context.storage, tonInstance: strongSelf.context.tonInstance, keychain: strongSelf.context.keychain, localPassword: serverSalt)
                    |> deliverOnMainQueue).start(next: { walletInfo, wordList in
                        guard let strongSelf = self else {
                            return
                        }
                        controller.dismiss()
                        (strongSelf.navigationController as? NavigationController)?.replaceController(strongSelf, with: WalletSplashScreen(context: strongSelf.context, mode: .created(walletInfo, wordList), walletCreatedPreloadState: nil), animated: true)
                    }, error: { _ in
                        displayError()
                    })
                }, error: { _ in
                    displayError()
                })
            case let .created(walletInfo, wordList):
                if let wordList = wordList {
                    strongSelf.push(WalletWordDisplayScreen(context: strongSelf.context, walletInfo: walletInfo, wordList: wordList, mode: .check, walletCreatedPreloadState: strongSelf.walletCreatedPreloadState))
                } else {
                    let controller = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: nil))
                    strongSelf.present(controller, in: .window(.root))
                    
                    let context = strongSelf.context
                    let _ = (strongSelf.context.keychain.decrypt(walletInfo.encryptedSecret)
                    |> deliverOnMainQueue).start(next: { [weak controller] decryptedSecret in
                        let _ = (context.getServerSalt()
                        |> deliverOnMainQueue).start(next: { [weak controller] serverSalt in
                            let _ = (walletRestoreWords(tonInstance: context.tonInstance, publicKey: walletInfo.publicKey, decryptedSecret:  decryptedSecret, localPassword: serverSalt)
                            |> deliverOnMainQueue).start(next: { wordList in
                                controller?.dismiss()
                                
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.mode = .created(walletInfo, wordList)
                                strongSelf.push(WalletWordDisplayScreen(context: strongSelf.context, walletInfo: walletInfo, wordList: wordList, mode: .check, walletCreatedPreloadState: strongSelf.walletCreatedPreloadState))
                            }, error: { _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                controller?.dismiss()
                                
                                strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_Created_ExportErrorTitle, text: strongSelf.presentationData.strings.Wallet_Created_ExportErrorText, actions: [
                                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                                    })
                                ], actionLayout: .vertical), in: .window(.root))
                            })
                        }, error: { [weak controller] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            controller?.dismiss()
                            
                            strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_Created_ExportErrorTitle, text: strongSelf.presentationData.strings.Wallet_Created_ExportErrorText, actions: [
                                TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                                })
                            ], actionLayout: .vertical), in: .window(.root))
                        })
                    }, error: { [weak controller] error in
                        controller?.dismiss()
                        if case .cancelled = error {
                        } else {
                            strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_Created_ExportErrorTitle, text: strongSelf.presentationData.strings.Wallet_Created_ExportErrorText, actions: [
                                TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                                })
                            ], actionLayout: .vertical), in: .window(.root))
                        }
                    })
                }
            case let .success(walletInfo):
                let _ = (walletAddress(publicKey: walletInfo.publicKey, tonInstance: strongSelf.context.tonInstance)
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
                        controllers.append(WalletInfoScreen(context: strongSelf.context, walletInfo: walletInfo, address: address, enableDebugActions: false))
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    }
                })
            case let .sent(walletInfo, _):
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    var controllers = navigationController.viewControllers
                    controllers = controllers.filter { controller in
                        if controller is WalletSendScreen {
                            return false
                        }
                        if controller is WalletSplashScreen {
                            return false
                        }
                        if controller is WalletWordDisplayScreen {
                            return false
                        }
                        if controller is WalletWordCheckScreen {
                            return false
                        }
                        if controller is WalletTransactionInfoScreen {
                            return false
                        }
                        return true
                    }
                    
                    let _ = (walletAddress(publicKey: walletInfo.publicKey, tonInstance: strongSelf.context.tonInstance)
                    |> deliverOnMainQueue).start(next: { [weak self] address in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if !controllers.contains(where: { $0 is WalletInfoScreen }) {
                            let infoScreen = WalletInfoScreen(context: strongSelf.context, walletInfo: walletInfo, address: address, enableDebugActions: false)
                            infoScreen.navigationPresentation = .modal
                            controllers.append(infoScreen)
                        }
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    })
                }
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
                    controllers.append(WalletSplashScreen(context: strongSelf.context, mode: .intro, walletCreatedPreloadState: nil))
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                }
            case let .sending(sending):
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    var controllers = navigationController.viewControllers
                    controllers = controllers.filter { controller in
                        if controller is WalletSendScreen {
                            return false
                        }
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
                    
                    let _ = (walletAddress(publicKey: sending.0.publicKey, tonInstance: strongSelf.context.tonInstance)
                    |> deliverOnMainQueue).start(next: { [weak self] address in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if !controllers.contains(where: { $0 is WalletInfoScreen }) {
                            let infoScreen = WalletInfoScreen(context: strongSelf.context, walletInfo: sending.0, address: address, enableDebugActions: false)
                            infoScreen.navigationPresentation = .modal
                            controllers.append(infoScreen)
                        }
                        strongSelf.view.endEditing(true)
                        navigationController.setViewControllers(controllers, animated: true)
                    })
                }
            case .secureStorageNotAvailable:
                strongSelf.dismiss()
            case let .secureStorageReset(reason):
                switch reason {
                case .notAvailable:
                    strongSelf.dismiss()
                case .changed:
                    strongSelf.push(WalletWordCheckScreen(context: strongSelf.context, mode: .import, walletCreatedPreloadState: nil))
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
                    controllers.append(WalletSplashScreen(context: strongSelf.context, mode: .intro, walletCreatedPreloadState: nil))
                    strongSelf.view.endEditing(true)
                    navigationController.setViewControllers(controllers, animated: true)
                }
            default:
                strongSelf.push(WalletWordCheckScreen(context: strongSelf.context, mode: .import, walletCreatedPreloadState: nil))
            }
        }, openTerms: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let url = strongSelf.context.termsUrl {
                strongSelf.context.openUrl(url)
            }
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletSplashScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletSplashScreenNode: ViewControllerTracingNode {
    private var presentationData: WalletPresentationData
    private let mode: WalletSplashMode
    private let secondaryAction: () -> Void
    
    private let iconNode: ASImageNode
    private var animationSize: CGSize = CGSize()
    private var animationOffset: CGPoint = CGPoint()
    private let animationNode: AnimatedStickerNode
    private let alternativeAnimationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    let buttonNode: SolidRoundedButtonNode
    private let termsNode: ImmediateTextNode
    private let secondaryActionTitleNode: ImmediateTextNode
    private let secondaryActionButtonNode: HighlightTrackingButtonNode
    
    private var stateDisposable: Disposable?
    private var synchronizationProgressDisposable: Disposable?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var inProgress: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = !self.inProgress
            self.buttonNode.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(context: WalletContext, walletCreatedPreloadState: Promise<CombinedWalletStateResult?>?, presentationData: WalletPresentationData, mode: WalletSplashMode, action: @escaping () -> Void, secondaryAction: @escaping () -> Void, openTerms: @escaping () -> Void) {
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
        var buttonHidden: Bool = false
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
            if let _ = context.termsUrl {
                termsText = parseMarkdownIntoAttributedString(self.presentationData.strings.Wallet_Intro_Terms, attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
            } else {
                termsText = NSAttributedString(string: "")
            }
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "WalletIntroLoading", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 248, height: 248, mode: .direct)
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
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 250, height: 250, playbackMode: .once, mode: .direct)
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
            if let path = getAppBundle().path(forResource: "WalletDone", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 260, height: 260, playbackMode: .loop, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationOffset = CGPoint(x: 0.0, y: 0.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case .restoreFailed:
            title = self.presentationData.strings.Wallet_RestoreFailed_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_RestoreFailed_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Wallet_RestoreFailed_CreateWallet
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "WalletNotAvailable", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 260, height: 260, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = self.presentationData.strings.Wallet_RestoreFailed_EnterWords
        case .sending:
            title = self.presentationData.strings.Wallet_Sending_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_Sending_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Wallet_Sent_Title
            buttonHidden = true
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "SendingGrams", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 260, height: 260, mode: .direct)
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
            if let path = getAppBundle().path(forResource: "WalletDone", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 260, height: 260, playbackMode: .once, mode: .direct)
                self.animationSize = CGSize(width: 130.0, height: 130.0)
                self.animationOffset = CGPoint(x: 14.0, y: 0.0)
                self.animationNode.visibility = true
            }
            secondaryActionText = ""
        case .secureStorageNotAvailable:
            title = self.presentationData.strings.Wallet_SecureStorageNotAvailable_Title
            text = NSAttributedString(string: self.presentationData.strings.Wallet_SecureStorageNotAvailable_Text, font: textFont, textColor: textColor)
            buttonText = self.presentationData.strings.Wallet_Alert_OK
            termsText = NSAttributedString(string: "")
            self.iconNode.image = nil
            if let path = getAppBundle().path(forResource: "WalletKeyLock", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 280, height: 280, playbackMode: .once, mode: .direct)
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
                buttonText = self.presentationData.strings.Wallet_Alert_OK
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
            if let path = getAppBundle().path(forResource: "WalletNotAvailable", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 260, height: 260, playbackMode: .once, mode: .direct)
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
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.setup.buttonFillColor, foregroundColor: self.presentationData.theme.setup.buttonForegroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.buttonNode.isHidden = buttonText.isEmpty || buttonHidden
        
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
    
    deinit {
        self.stateDisposable?.dispose()
        self.synchronizationProgressDisposable?.dispose()
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
        self.validLayout = (layout, navigationHeight)
        
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
        var contentVerticalOrigin = floor((layout.size.height - contentHeight - iconSize.height / 2.0) / 2.0)
        
        let minimalBottomInset: CGFloat = 60.0
        let bottomInset = layout.intrinsicInsets.bottom + max(minimalBottomInset, termsSize.height + termsSpacing * 2.0)
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        var maxContentVerticalOrigin = buttonFrame.minY - 12.0 - contentHeight
        
        if !secondaryActionSize.width.isZero {
            let secondaryActionFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - secondaryActionSize.width) / 2.0), y: buttonFrame.minY - 20.0 - secondaryActionSize.height), size: secondaryActionSize)
            transition.updateFrameAdditive(node: self.secondaryActionTitleNode, frame: secondaryActionFrame)
            transition.updateFrame(node: self.secondaryActionButtonNode, frame: secondaryActionFrame.insetBy(dx: -10.0, dy: -10.0))
            
            maxContentVerticalOrigin = secondaryActionFrame.minY - 12.0 - contentHeight
        }
        
        contentVerticalOrigin = min(contentVerticalOrigin, maxContentVerticalOrigin)
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0) + self.animationOffset.x, y: contentVerticalOrigin + self.animationOffset.y), size: iconSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
        transition.updateFrameAdditive(node: self.iconNode, frame: iconFrame)
        self.animationNode.updateLayout(size: iconFrame.size)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        let termsFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - termsSize.width) / 2.0), y: buttonFrame.maxY + floor((layout.size.height - layout.intrinsicInsets.bottom - buttonFrame.maxY - termsSize.height) / 2.0)), size: termsSize)
        transition.updateFrameAdditive(node: self.termsNode, frame: termsFrame)
    }
}
