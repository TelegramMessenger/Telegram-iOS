//
//  DoubleBottomFlowContext.swift
//  TelegramUI#shared

import UIKit
import Display
import SwiftSignalKit
import Postbox
import SyncCore
import PasscodeUI
import AccountContext
import TelegramUIPreferences
import LocalAuth
import TelegramCore
import WidgetKit

public class FlowViewController: ViewController {
    weak var nextController: ViewController?
}

final class DoubleBottomFlowContext {
    private let accountContext: SharedAccountContext
    private let context: AuthorizedApplicationContext
    
    var mainPasscode: (String, Bool)?
    var secretPasscode: (String, Bool)?
    var shouldEnableNotification: Bool = true
    
    var flowIsReady: Bool = false
    var doubleBottomAddAccountFlowInProgress: Bool {
        get {
            UserDefaults.standard.bool(forKey: "TG_DoubleBottom_AddAccountFlowInProgress")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TG_DoubleBottom_AddAccountFlowInProgress")
        }
    }
    
    init(accountContext: SharedAccountContext, context: AuthorizedApplicationContext) {
        self.accountContext = accountContext
        self.context = context
    }
    
    func setMainPasscodeInNeeded() {
        guard let passcode = mainPasscode?.0, let numerical = mainPasscode?.1 else { return }
        
        let _ = (accountContext.accountManager.transaction({ transaction -> Void in
            var data = transaction.getAccessChallengeData()
            if numerical {
                data = PostboxAccessChallengeData.numericalPassword(value: passcode)
            } else {
                data = PostboxAccessChallengeData.plaintextPassword(value: passcode)
            }
            
            transaction.setAccessChallengeData(data)
            
            updatePresentationPasscodeSettingsInternal(transaction: transaction, { $0.withUpdatedAutolockTimeout(60).withUpdatedBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState) })
            
            updatePushNotificationsSettingsAfterOnMasterPasscode(transaction: transaction)
        }) |> deliverOnMainQueue).start()
    }
    
    func setSecretPasscode() {
        guard let passcode = secretPasscode?.0, let numerical = secretPasscode?.1 else { return }
        
        let _ = (accountContext.accountManager.transaction({ transaction -> Void in
            var data = transaction.getAccessChallengeData()
            if numerical {
                data = PostboxAccessChallengeData.numericalPassword(value: passcode)
            } else {
                data = PostboxAccessChallengeData.plaintextPassword(value: passcode)
            }
            
            if let (id, _) = transaction.getCurrent() {
                setAccountRecordAccessChallengeData(transaction: transaction, id: id, accessChallengeData: data)
                
                updatePresentationPasscodeSettingsInternal(transaction: transaction, { $0.withUpdatedAutolockTimeout(60).withUpdatedBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState) })
            }
        }) |> deliverOnMainQueue).start()
    }
    
    func setNotificationsSettings() {
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.context.account.postbox, { [weak self] settings in
            guard let strongSelf = self else { return settings }
            
            var settings = settings
            settings.channels.enabled = strongSelf.shouldEnableNotification
            settings.groupChats.enabled = strongSelf.shouldEnableNotification
            settings.privateChats.enabled = strongSelf.shouldEnableNotification
            return settings
        }).start()
            
        if shouldEnableNotification {
            let _ = updateSelectiveAccountPrivacySettings(account: context.context.account, type: .voiceCalls, settings: .enableEveryone(disableFor: [:])).start()
        } else {
            let _ = updateSelectiveAccountPrivacySettings(account: context.context.account, type: .voiceCalls, settings: .disableEveryone(enableFor: [:])).start()
        }
    }
}

final class DoubleBottomFlow {
    private lazy var doneController: DoubleBottomSplashScreen = {
        let doneController = createDoubleBottomScreen(withMode: .accountWasHidden)
        doneController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        doneController.buttonPressed = { [weak self] _ in
            self?.blockInterface()
        }
        return doneController
    }()
    
    private lazy var lockExplanationController: DoubleBottomSplashScreen = {
        let lockExplanationController = createDoubleBottomScreen(withMode: .lockExplanation) { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.hideCurrentAccount()
        }
        lockExplanationController.nextController = doneController
        return lockExplanationController
    }()
    
    private lazy var disableNotificationsController: DoubleBottomSplashScreen = {
        let disableNotificationsController = createDoubleBottomScreen(withMode: .disableNotifications)
        disableNotificationsController.buttonPressedWithEnabledSwitch = { [weak doubleBottomContext] enabled in
            doubleBottomContext?.shouldEnableNotification = enabled
        }
        disableNotificationsController.nextController = lockExplanationController
        return disableNotificationsController
    }()
    
    private lazy var secretPasscodeIntroController: DoubleBottomSplashScreen = {
        let secretPasscodeIntroController = createDoubleBottomScreen(withMode: .setSecretPasscode) { [weak self] in
            guard let strongSelf = self, let doubleBottomContext = strongSelf.doubleBottomContext else { return }
            
            let secretPasscodeSetupController = strongSelf.createSecretPasscodeSetupController(accountContext: strongSelf.accountContext, doubleBottomContext: doubleBottomContext, nextController: strongSelf.disableNotificationsController)
            
            strongSelf.context.rootController.pushViewController(secretPasscodeSetupController, animated: true)
        }
        return secretPasscodeIntroController
    }()
    
    private lazy var mainPasscodeIntroController: DoubleBottomSplashScreen = {
        let mainPasscodeIntroController = createDoubleBottomScreen(withMode: .setMasterPasscode) { [weak self] in
            guard let strongSelf = self else { return }
            
            let mainPasscodeSetupController = PasscodeSetupController(context: strongSelf.accountContext, mode: .setup(change: false, .digits6), isOpaqueNavigationBar: true)
            mainPasscodeSetupController.complete = { [weak self] passcode, numerical in
                guard let strongSelf = self, let doubleBottomContext = strongSelf.doubleBottomContext else { return }
                
                doubleBottomContext.mainPasscode = (passcode, numerical)
                
                strongSelf.context.rootController.pushViewController(strongSelf.secretPasscodeIntroController, animated: true) { [weak strongSelf] in
                    guard let root = strongSelf?.context.rootController, let top = root.viewControllers.last else { return }
                    
                    root.setViewControllers(Array(root.viewControllers.dropLast(2)) + [top], animated: false)
                }
            }
            
            strongSelf.context.rootController.pushViewController(mainPasscodeSetupController, animated: true)
        }
        return mainPasscodeIntroController
    }()
    
    private lazy var addMainAccountController: DoubleBottomSplashScreen = {
        let addMainAccountController = createDoubleBottomScreen(withMode: .addOneMoreAccount) { [weak context, weak doubleBottomContext] in
            guard let context = context, let doubleBottomContext = doubleBottomContext else { return }

            doubleBottomContext.doubleBottomAddAccountFlowInProgress = true
            let isTestingEnvironment = context.context.account.testingEnvironment
            context.sharedApplicationContext.sharedContext.beginNewAuthAndContinueDoubleBottomFlow(testingEnvironment: isTestingEnvironment)
        }
        return addMainAccountController
    }()
    
    private lazy var hideAccountController: DoubleBottomSplashScreen = {
        return createDoubleBottomScreen(withMode: .hideAccount)
    }()
    
    private(set) var doubleBottomContext: DoubleBottomFlowContext?
    
    private let finish: () -> Void
    
    let context: AuthorizedApplicationContext
    let accountContext: SharedAccountContext
    
    init(context: AuthorizedApplicationContext, finish: @escaping () -> Void) {
        self.context = context
        self.accountContext = context.sharedApplicationContext.sharedContext
        self.finish = finish
        self.doubleBottomContext = DoubleBottomFlowContext(accountContext: accountContext, context: context)
    }
    
    func hideCurrentAccount() {
        doubleBottomContext?.setMainPasscodeInNeeded()
        doubleBottomContext?.setSecretPasscode()
        doubleBottomContext?.setNotificationsSettings()
        
        doubleBottomContext?.flowIsReady = true
    }
    
    func blockInterface() {
        let accountContext = context.sharedApplicationContext.sharedContext
        
        accountContext.appLockContext.lock()
        context.rootController.allowInteractiveDismissal = true
        doubleBottomContext = nil
        _ = (accountContext.appLockContext.lockingIsCompletePromise
            .get()
            |> distinctUntilChanged
            |> mapToSignal { [weak accountContext, weak self] complete -> Signal<Void, NoError> in
                guard complete, let accountContext = accountContext else { return .single(()) }
                
                return accountContext.accountManager.transaction({ transaction -> Void in
                    if let publicId = transaction.getRecords().first(where: { $0.isPublic })?.id {
                        transaction.setCurrentId(publicId)
                    }
                    if #available(iOS 14.0, *) {
                        #if arch(arm64) || arch(i386) || arch(x86_64)
                        WidgetCenter.shared.reloadAllTimelines()
                        #endif
                    }
                    self?.finish()
                })
            }
            |> deliverOnMainQueue).start()
    }
    
    func blockInterfaceInNeeded() {
        if doubleBottomContext?.flowIsReady ?? false {
            blockInterface()
        }
    }
    
    func start() {
        doubleBottomContext = DoubleBottomFlowContext(accountContext: accountContext, context: context)
        
        let _ = (context.sharedApplicationContext.sharedContext.accountManager.transaction { [weak doubleBottomContext] transaction -> (Bool, Bool) in
            let hasMoreThanOnePublic = transaction.getRecords().filter({ $0.isPublic }).count > 1
            
            let accessChallengeData = transaction.getAccessChallengeData()
            doubleBottomContext?.mainPasscode = accessChallengeData.convert()
            
            let hasMainPasscode = accessChallengeData != .none
            
            return (hasMoreThanOnePublic, hasMainPasscode)
            } |> deliverOnMainQueue)
            .start(next: { [weak self] hasMoreThanOnePublic, hasMainPasscode in
                guard let strongSelf = self else { return }
                
                switch (hasMoreThanOnePublic, hasMainPasscode) {
                case (true, true):
                    strongSelf.hideAccountController.nextController = strongSelf.secretPasscodeIntroController
                    
                case (true, false):
                    strongSelf.hideAccountController.nextController = strongSelf.mainPasscodeIntroController
                    
                case (false, true):
                    strongSelf.hideAccountController.nextController = strongSelf.addMainAccountController
                    
                case (false, false):
                    strongSelf.hideAccountController.nextController = strongSelf.addMainAccountController
                }
                
                strongSelf.doubleBottomContext?.doubleBottomAddAccountFlowInProgress = false
                strongSelf.context.rootController.pushViewController(strongSelf.hideAccountController, animated: true)
        })
    }
    
    func continueAfterAddingAccount(with accountId: AccountRecordId) {
        let _ = (context.sharedApplicationContext.sharedContext.accountManager.transaction { [weak doubleBottomContext] transaction -> (Bool, Bool) in
            let hasMoreThanOnePublic = transaction.getRecords().filter({ $0.isPublic }).count > 1
            
            let accessChallengeData = transaction.getAccessChallengeData()
            doubleBottomContext?.mainPasscode = accessChallengeData.convert()
            
            let hasMainPasscode = accessChallengeData != .none
            
            return (hasMoreThanOnePublic, hasMainPasscode)
            } |> deliverOnMainQueue)
            .start(next: { [weak self] hasMoreThanOnePublic, hasMainPasscode in
                guard let strongSelf = self else { return }
                
                var viewController: DoubleBottomSplashScreen?
                
                switch (hasMoreThanOnePublic, hasMainPasscode) {
                case (true, true):
                    viewController = strongSelf.secretPasscodeIntroController
                    
                case (true, false):
                    viewController = strongSelf.mainPasscodeIntroController
                    
                case (false, true): break
                    
                case (false, false): break
                    
                }
                
                if let viewController = viewController {
                    viewController.poppedInteractively = { [weak strongSelf] in
                        guard let strongSelf = self else { return }
                        
                        strongSelf.doubleBottomContext?.doubleBottomAddAccountFlowInProgress = false
                        let _ = (logoutFromAccount(id: accountId, accountManager: strongSelf.context.sharedApplicationContext.sharedContext.accountManager, alreadyLoggedOutRemotely: false) |> deliverOnMainQueue).start()
                    }
                    viewController.backPressed = { [weak strongSelf] in
                        guard let strongSelf = self else { return }
                        
                        viewController.poppedInteractively?()
                        strongSelf.context.rootController.popViewController(animated: true)
                    }
                    strongSelf.context.rootController.pushViewController(viewController, animated: true) { [weak strongSelf] in
                        guard let strongSelf = self else { return }
                        
                        let root = strongSelf.context.rootController
                        
                        guard let top = root.viewControllers.last else { return }
                        
                        let viewControllers = Array(root.viewControllers.prefix(4)) + [top]
                        root.setViewControllers(viewControllers, animated: false)
                    }
                }
        })
    }
}

private extension DoubleBottomFlow {
    func createDoubleBottomScreen(withMode mode: DoubleBottomSplashMode, action: (() -> Void)? = nil) -> DoubleBottomSplashScreen {
        let presentationData = context.context.sharedContext.currentPresentationData.with { $0 }
        let controller = DoubleBottomSplashScreen(presentationData: presentationData, mode: mode)
        controller.buttonPressed = { [weak context] nextController in
            if let next = nextController {
                context?.rootController.pushViewController(next, animated: true)
            }
            
            action?()
        }
        return controller
    }
    
    func createSecretPasscodeSetupController(accountContext: SharedAccountContext, doubleBottomContext: DoubleBottomFlowContext, nextController: ViewController) -> ViewController {
        assert(doubleBottomContext.mainPasscode != nil)
        
        let passcodeType: PasscodeEntryFieldType
        if doubleBottomContext.mainPasscode!.1 {
            passcodeType = doubleBottomContext.mainPasscode!.0.count == 6 ? .digits6 : .digits4
        } else {
            passcodeType = .alphanumeric
        }
        
        let secretPasscodeSetupController = PasscodeSetupController(context: accountContext, mode: .setup(change: false, passcodeType), isChangeModeAllowed: false, isOpaqueNavigationBar: true)
        secretPasscodeSetupController.checkSetupPasscode = { passcode in
            return doubleBottomContext.mainPasscode?.0 != passcode
        }
        secretPasscodeSetupController.complete = { [weak self] passcode, numerical in
            guard let strongSelf = self else { return }
            
            strongSelf.doubleBottomContext?.secretPasscode = (passcode, numerical)
            
            strongSelf.context.rootController.pushViewController(nextController, animated: true) { [weak strongSelf] in
                guard let root = strongSelf?.context.rootController, let top = root.viewControllers.last else { return }
                
                root.setViewControllers(Array(root.viewControllers.dropLast(2)) + [top], animated: false)
            }
        }
        return secretPasscodeSetupController
    }
}

fileprivate extension AccountRecord {
    var isPublic: Bool {
        !attributes.contains(where: { $0 is HiddenAccountAttribute }) && !attributes.contains(where: { $0 is LoggedOutAccountAttribute })
    }
}

fileprivate extension PostboxAccessChallengeData {
    func convert() -> (String, Bool)? {
        switch self {
        case .none: return nil
            
        case .numericalPassword(let value): return (value, true)
            
        case .plaintextPassword(let value): return (value, false)
        }
    }
}
