import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import LocalAuthentication
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import LocalAuth
import PasscodeUI
import TelegramStringFormatting
import TelegramIntents

private final class PasscodeOptionsControllerArguments {
    let turnPasscodeOff: () -> Void
    let changePasscode: () -> Void
    let changePasscodeTimeout: () -> Void
    let changeTouchId: (Bool) -> Void
    
    init(turnPasscodeOff: @escaping () -> Void, changePasscode: @escaping () -> Void, changePasscodeTimeout: @escaping () -> Void, changeTouchId: @escaping (Bool) -> Void) {
        self.turnPasscodeOff = turnPasscodeOff
        self.changePasscode = changePasscode
        self.changePasscodeTimeout = changePasscodeTimeout
        self.changeTouchId = changeTouchId
    }
}

private enum PasscodeOptionsSection: Int32 {
    case setting
    case options
}

private enum PasscodeOptionsEntry: ItemListNodeEntry {
    case togglePasscode(PresentationTheme, String, Bool)
    case changePasscode(PresentationTheme, String)
    case settingInfo(PresentationTheme, String)
    
    case autoLock(PresentationTheme, String, String)
    case touchId(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .togglePasscode, .changePasscode, .settingInfo:
                return PasscodeOptionsSection.setting.rawValue
            case .autoLock, .touchId:
                return PasscodeOptionsSection.options.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .togglePasscode:
                return 0
            case .changePasscode:
                return 1
            case .settingInfo:
                return 2
            case .autoLock:
                return 3
            case .touchId:
                return 4
        }
    }
    
    static func ==(lhs: PasscodeOptionsEntry, rhs: PasscodeOptionsEntry) -> Bool {
        switch lhs {
            case let .togglePasscode(lhsTheme, lhsText, lhsValue):
                if case let .togglePasscode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .changePasscode(lhsTheme, lhsText):
                if case let .changePasscode(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .settingInfo(lhsTheme, lhsText):
                if case let .settingInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .autoLock(lhsTheme, lhsText, lhsValue):
                if case let .autoLock(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .touchId(lhsTheme, lhsText, lhsValue):
                if case let .touchId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PasscodeOptionsEntry, rhs: PasscodeOptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PasscodeOptionsControllerArguments
        switch self {
            case let .togglePasscode(_, title, value):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if value {
                        arguments.turnPasscodeOff()
                    }
                })
            case let .changePasscode(_, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscode()
                })
            case let .settingInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .autoLock(_, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscodeTimeout()
                })
            case let .touchId(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.changeTouchId(value)
                })
        }
    }
}

private struct PasscodeOptionsControllerState: Equatable {
    static func ==(lhs: PasscodeOptionsControllerState, rhs: PasscodeOptionsControllerState) -> Bool {
        return true
    }
}

private struct PasscodeOptionsData: Equatable {
    let accessChallenge: PostboxAccessChallengeData
    let presentationSettings: PresentationPasscodeSettings
    
    init(accessChallenge: PostboxAccessChallengeData, presentationSettings: PresentationPasscodeSettings) {
        self.accessChallenge = accessChallenge
        self.presentationSettings = presentationSettings
    }
    
    static func ==(lhs: PasscodeOptionsData, rhs: PasscodeOptionsData) -> Bool {
        return lhs.accessChallenge == rhs.accessChallenge && lhs.presentationSettings == rhs.presentationSettings
    }
    
    func withUpdatedAccessChallenge(_ accessChallenge: PostboxAccessChallengeData) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: self.presentationSettings)
    }
    
    func withUpdatedPresentationSettings(_ presentationSettings: PresentationPasscodeSettings) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: self.accessChallenge, presentationSettings: presentationSettings)
    }
}

private func autolockStringForTimeout(strings: PresentationStrings, timeout: Int32?) -> String {
    if let timeout = timeout {
        if timeout == 10 {
            return "If away for 10 seconds"
        } else if timeout == 1 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_1minute
        } else if timeout == 5 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_5minutes
        } else if timeout == 1 * 60 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_1hour
        } else if timeout == 5 * 60 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_5hours
        } else {
            return ""
        }
    } else {
        return strings.PasscodeSettings_AutoLock_Disabled
    }
}

private func passcodeOptionsControllerEntries(presentationData: PresentationData, state: PasscodeOptionsControllerState, passcodeOptionsData: PasscodeOptionsData) -> [PasscodeOptionsEntry] {
    var entries: [PasscodeOptionsEntry] = []
    
    switch passcodeOptionsData.accessChallenge {
        case .none:
            entries.append(.togglePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_TurnPasscodeOn, false))
            entries.append(.settingInfo(presentationData.theme, presentationData.strings.PasscodeSettings_Help))
        case .numericalPassword, .plaintextPassword:
            entries.append(.togglePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_TurnPasscodeOff, true))
            entries.append(.changePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_ChangePasscode))
            entries.append(.settingInfo(presentationData.theme, presentationData.strings.PasscodeSettings_Help))
            entries.append(.autoLock(presentationData.theme, presentationData.strings.PasscodeSettings_AutoLock, autolockStringForTimeout(strings: presentationData.strings, timeout: passcodeOptionsData.presentationSettings.autolockTimeout)))
            if let biometricAuthentication = LocalAuth.biometricAuthentication {
                switch biometricAuthentication {
                    case .touchId:
                        entries.append(.touchId(presentationData.theme, presentationData.strings.PasscodeSettings_UnlockWithTouchId, passcodeOptionsData.presentationSettings.enableBiometrics))
                    case .faceId:
                        entries.append(.touchId(presentationData.theme, presentationData.strings.PasscodeSettings_UnlockWithFaceId, passcodeOptionsData.presentationSettings.enableBiometrics))
                }
            }
    }
    
    return entries
}

func passcodeOptionsController(context: AccountContext) -> ViewController {
    let initialState = PasscodeOptionsControllerState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var popControllerImpl: (() -> Void)?
    var replaceTopControllerImpl: ((ViewController, Bool) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let passcodeOptionsDataPromise = Promise<PasscodeOptionsData>()
    passcodeOptionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> (PostboxAccessChallengeData, PresentationPasscodeSettings) in
        let passcodeSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings)?.get(PresentationPasscodeSettings.self) ?? PresentationPasscodeSettings.defaultSettings
        return (transaction.getAccessChallengeData(), passcodeSettings)
    }
    |> map { accessChallenge, passcodeSettings -> PasscodeOptionsData in
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: passcodeSettings)
    })
    
    let arguments = PasscodeOptionsControllerArguments(turnPasscodeOff: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.PasscodeSettings_TurnPasscodeOff, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let challenge = PostboxAccessChallengeData.none
                let _ = context.sharedContext.accountManager.transaction({ transaction -> Void in
                    transaction.setAccessChallengeData(challenge)
                }).start()
                
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(challenge)))
                })
                
                var innerReplaceTopControllerImpl: ((ViewController, Bool) -> Void)?
                let controller = PrivacyIntroController(context: context, mode: .passcode, proceedAction: {
                    let setupController = PasscodeSetupController(context: context, mode: .setup(change: false, .digits6))
                    setupController.complete = { passcode, numerical in
                        let _ = (context.sharedContext.accountManager.transaction({ transaction -> Void in
                            var data = transaction.getAccessChallengeData()
                            if numerical {
                                data = PostboxAccessChallengeData.numericalPassword(value: passcode)
                            } else {
                                data = PostboxAccessChallengeData.plaintextPassword(value: passcode)
                            }
                            transaction.setAccessChallengeData(data)
                            
                            updatePresentationPasscodeSettingsInternal(transaction: transaction, { $0.withUpdatedAutolockTimeout(1 * 60 * 60).withUpdatedBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState) })
                        }) |> deliverOnMainQueue).start(next: { _ in
                        }, error: { _ in
                        }, completed: {
                            innerReplaceTopControllerImpl?(passcodeOptionsController(context: context), true)
                        })
                    }
                    innerReplaceTopControllerImpl?(setupController, true)
                    innerReplaceTopControllerImpl = { [weak setupController] c, animated in
                        (setupController?.navigationController as? NavigationController)?.replaceTopController(c, animated: animated)
                    }
                })
                replaceTopControllerImpl?(controller, false)
                innerReplaceTopControllerImpl = { [weak controller] c, animated in
                    (controller?.navigationController as? NavigationController)?.replaceTopController(c, animated: animated)
                }
            })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, changePasscode: {
        let _ = (context.sharedContext.accountManager.transaction({ transaction -> Bool in
            switch transaction.getAccessChallengeData() {
                case .none, .numericalPassword:
                    return true
                case .plaintextPassword:
                    return false
            }
        })
        |> deliverOnMainQueue).start(next: { isSimple in
            let setupController = PasscodeSetupController(context: context, mode: .setup(change: true, .digits6))
            setupController.complete = { passcode, numerical in
                let _ = (context.sharedContext.accountManager.transaction({ transaction -> Void in
                    var data = transaction.getAccessChallengeData()
                    if numerical {
                        data = PostboxAccessChallengeData.numericalPassword(value: passcode)
                    } else {
                        data = PostboxAccessChallengeData.plaintextPassword(value: passcode)
                    }
                    transaction.setAccessChallengeData(data)
                }) |> deliverOnMainQueue).start(next: { _ in
                }, error: { _ in
                }, completed: {
                    popControllerImpl?()
                })
            }
            pushControllerImpl?(setupController)
        })
    }, changePasscodeTimeout: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        let setAction: (Int32?) -> Void = { value in
            let _ = (passcodeOptionsDataPromise.get()
            |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedAutolockTimeout(value))))
                
                let _ = updatePresentationPasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    return current.withUpdatedAutolockTimeout(value)
                }).start()
            })
        }
        var values: [Int32] = [0, 1 * 60, 5 * 60, 1 * 60 * 60, 5 * 60 * 60]
        
        #if DEBUG
            values.append(10)
            values.sort()
        #endif
        
        for value in values {
            var t: Int32?
            if value != 0 {
                t = value
            }
            items.append(ActionSheetButtonItem(title: autolockStringForTimeout(strings: presentationData.strings, timeout: t), color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                setAction(t)
            }))
        }
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, changeTouchId: { value in
        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
            passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedEnableBiometrics(value))))
            
            let _ = updatePresentationPasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current.withUpdatedEnableBiometrics(value)
            }).start()
        })
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), passcodeOptionsDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state, passcodeOptionsData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PasscodeSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: passcodeOptionsControllerEntries(presentationData: presentationData, state: state, passcodeOptionsData: passcodeOptionsData), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    popControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    replaceTopControllerImpl = { [weak controller] c, animated in
        (controller?.navigationController as? NavigationController)?.replaceTopController(c, animated: animated)
    }
    
    return controller
}

public func passcodeOptionsAccessController(context: AccountContext, animateIn: Bool = true, pushController: ((ViewController) -> Void)?, completion: @escaping (Bool) -> Void) -> Signal<ViewController?, NoError> {
    return context.sharedContext.accountManager.transaction { transaction -> PostboxAccessChallengeData in
        return transaction.getAccessChallengeData()
    }
    |> deliverOnMainQueue
    |> map { challenge -> ViewController? in
        if case .none = challenge {
            let controller = PrivacyIntroController(context: context, mode: .passcode, proceedAction: {
                let setupController = PasscodeSetupController(context: context, mode: .setup(change: false, .digits6))
                setupController.complete = { passcode, numerical in
                    let _ = (context.sharedContext.accountManager.transaction({ transaction -> Void in
                        var data = transaction.getAccessChallengeData()
                        if numerical {
                            data = PostboxAccessChallengeData.numericalPassword(value: passcode)
                        } else {
                            data = PostboxAccessChallengeData.plaintextPassword(value: passcode)
                        }
                        transaction.setAccessChallengeData(data)
                        
                        updatePresentationPasscodeSettingsInternal(transaction: transaction, { $0.withUpdatedAutolockTimeout(1 * 60 * 60).withUpdatedBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState) })
                    }) |> deliverOnMainQueue).start(next: { _ in
                    }, error: { _ in
                    }, completed: {
                        completion(true)
                        deleteAllSendMessageIntents()
                    })
                }
                pushController?(setupController)
            })
            return controller
        } else {
            let controller = PasscodeSetupController(context: context, mode: .entry(challenge))
            controller.check = { passcode in
                var succeed = false
                switch challenge {
                    case .none:
                        succeed = true
                    case let .numericalPassword(code):
                        succeed = passcode == normalizeArabicNumeralString(code, type: .western)
                    case let .plaintextPassword(code):
                        succeed = passcode == code
                }
                if succeed {
                    completion(true)
                }
                return succeed
            }
            return controller
        }
    }
}

public func passcodeEntryController(context: AccountContext, animateIn: Bool = true, modalPresentation: Bool = false, completion: @escaping (Bool) -> Void) -> Signal<ViewController?, NoError> {
    return context.sharedContext.accountManager.transaction { transaction -> PostboxAccessChallengeData in
        return transaction.getAccessChallengeData()
    }
    |> mapToSignal { accessChallengeData -> Signal<(PostboxAccessChallengeData, PresentationPasscodeSettings?), NoError> in
        return context.sharedContext.accountManager.transaction { transaction -> (PostboxAccessChallengeData, PresentationPasscodeSettings?) in
            let passcodeSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings)?.get(PresentationPasscodeSettings.self)
            return (accessChallengeData, passcodeSettings)
        }
    }
    |> deliverOnMainQueue
    |> map { (challenge, passcodeSettings) -> ViewController? in
        if case .none = challenge {
            completion(true)
            return nil
        } else {
            let biometrics: PasscodeEntryControllerBiometricsMode
            #if targetEnvironment(simulator)
            biometrics = .enabled(nil)
            #else
            if let passcodeSettings = passcodeSettings, passcodeSettings.enableBiometrics {
                biometrics = .enabled(context.sharedContext.applicationBindings.isMainApp ? passcodeSettings.biometricsDomainState : passcodeSettings.shareBiometricsDomainState)
            } else {
                biometrics = .none
            }
            #endif
            let controller = PasscodeEntryController(applicationBindings: context.sharedContext.applicationBindings, accountManager: context.sharedContext.accountManager, appLockContext: context.sharedContext.appLockContext, presentationData: context.sharedContext.currentPresentationData.with { $0 }, presentationDataSignal: context.sharedContext.presentationData, statusBarHost: context.sharedContext.mainWindow?.statusBarHost, challengeData: challenge, biometrics: biometrics, arguments: PasscodeEntryControllerPresentationArguments(animated: false, fadeIn: true, cancel: {
                completion(false)
            }, modalPresentation: modalPresentation))
            controller.presentationCompleted = { [weak controller] in
                Queue.mainQueue().after(0.5, { [weak controller] in
                    controller?.requestBiometrics()
                })
            }
            controller.completed = { [weak controller] in
                controller?.dismiss(completion: {
                    completion(true)
                })
            }
            return controller
        }
    }
}
