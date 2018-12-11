import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import LocalAuthentication

private final class PasscodeOptionsControllerArguments {
    let turnPasscodeOn: () -> Void
    let turnPasscodeOff: () -> Void
    let changePasscode: () -> Void
    let changePasscodeTimeout: () -> Void
    let changeTouchId: (Bool) -> Void
    let toggleSimplePasscode: (Bool) -> Void
    
    init(turnPasscodeOn: @escaping () -> Void, turnPasscodeOff: @escaping () -> Void, changePasscode: @escaping () -> Void, changePasscodeTimeout: @escaping () -> Void, changeTouchId: @escaping (Bool) -> Void, toggleSimplePasscode: @escaping (Bool) -> Void) {
        self.turnPasscodeOn = turnPasscodeOn
        self.turnPasscodeOff = turnPasscodeOff
        self.changePasscode = changePasscode
        self.changePasscodeTimeout = changePasscodeTimeout
        self.changeTouchId = changeTouchId
        self.toggleSimplePasscode = toggleSimplePasscode
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
    case simplePasscode(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .togglePasscode, .changePasscode, .settingInfo:
                return PasscodeOptionsSection.setting.rawValue
            case .autoLock, .touchId, .simplePasscode:
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
            case .simplePasscode:
                return 5
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
            case let .simplePasscode(lhsTheme, lhsText, lhsValue):
                if case let .simplePasscode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PasscodeOptionsEntry, rhs: PasscodeOptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: PasscodeOptionsControllerArguments) -> ListViewItem {
        switch self {
            case let .togglePasscode(theme, title, value):
                return ItemListActionItem(theme: theme, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if value {
                        arguments.turnPasscodeOff()
                    } else {
                        arguments.turnPasscodeOn()
                    }
                })
            case let .changePasscode(theme, title):
                return ItemListActionItem(theme: theme, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscode()
                })
            case let .settingInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .autoLock(theme, title, value):
                return ItemListDisclosureItem(theme: theme, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscodeTimeout()
                })
            case let .touchId(theme, title, value):
                return ItemListSwitchItem(theme: theme, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.changeTouchId(value)
                })
            case let .simplePasscode(theme, title, value):
                return ItemListSwitchItem(theme: theme, title: title, value: value, enableInteractiveChanges: false, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleSimplePasscode(value)
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
            var simplePasscode = false
            if case .numericalPassword = passcodeOptionsData.accessChallenge {
                simplePasscode = true
            }
            entries.append(.simplePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_SimplePasscode, simplePasscode))
    }
    
    return entries
}

func passcodeOptionsController(account: Account) -> ViewController {
    let initialState = PasscodeOptionsControllerState()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((PasscodeOptionsControllerState) -> PasscodeOptionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let passcodeOptionsDataPromise = Promise<PasscodeOptionsData>()
    passcodeOptionsDataPromise.set(combineLatest(account.postbox.transaction { transaction -> PostboxAccessChallengeData in
        return transaction.getAccessChallengeData()
    }, account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.presentationPasscodeSettings]) |> take(1)) |> map { accessChallenge, preferences -> PasscodeOptionsData in
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: (preferences.values[ApplicationSpecificPreferencesKeys.presentationPasscodeSettings] as? PresentationPasscodeSettings) ?? PresentationPasscodeSettings.defaultSettings)
    })
    
    let arguments = PasscodeOptionsControllerArguments(turnPasscodeOn: {
        var dismissImpl: (() -> Void)?
        
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        let legacyController = LegacyController(presentation: LegacyControllerPresentation.modal(animateIn: true), theme: presentationData.theme)
        let controller = TGPasscodeEntryController(context: legacyController.context, style: TGPasscodeEntryControllerStyleDefault, mode: TGPasscodeEntryControllerModeSetupSimple, cancelEnabled: true, allowTouchId: false, attemptData: nil, completion: { result in
            if let result = result {
                let challenge = PostboxAccessChallengeData.numericalPassword(value: result, timeout: nil, attempts: nil)
                let _ = account.postbox.transaction({ transaction -> Void in
                    transaction.setAccessChallengeData(challenge)
                    updatePresentationPasscodeSettingsInternal(transaction: transaction, { current in
                        return current.withUpdatedAutolockTimeout(1 * 60 * 60)
                    })
                }).start()
                
                let _ = (passcodeOptionsDataPromise.get()
                |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(challenge).withUpdatedPresentationSettings(data.presentationSettings.withUpdatedAutolockTimeout(1 * 60 * 60))))
                })
                
                dismissImpl?()
            } else {
                dismissImpl?()
            }
        })!
        legacyController.bind(controller: controller)
        legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
        legacyController.statusBar.statusBarStyle = .White
        presentControllerImpl?(legacyController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        dismissImpl = { [weak legacyController] in
            legacyController?.dismiss()
        }
    }, turnPasscodeOff: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.PasscodeSettings_TurnPasscodeOff, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let challenge = PostboxAccessChallengeData.none
                let _ = account.postbox.transaction({ transaction -> Void in
                    transaction.setAccessChallengeData(challenge)
                }).start()
                
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(challenge)))
                })
            })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, changePasscode: {
        let _ = (account.postbox.transaction({ transaction -> Bool in
            switch  transaction.getAccessChallengeData() {
                case .none, .numericalPassword:
                    return true
                case .plaintextPassword:
                    return false
            }
        })
        |> deliverOnMainQueue).start(next: { isSimple in
            var dismissImpl: (() -> Void)?
            
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            
            let legacyController = LegacyController(presentation: LegacyControllerPresentation.modal(animateIn: true), theme: presentationData.theme)
            let controller = TGPasscodeEntryController(context: legacyController.context, style: TGPasscodeEntryControllerStyleDefault, mode: isSimple ? TGPasscodeEntryControllerModeSetupSimple : TGPasscodeEntryControllerModeSetupComplex, cancelEnabled: true, allowTouchId: false, attemptData: nil, completion: { result in
                if let result = result {
                    let _ = account.postbox.transaction({ transaction -> Void in
                        var data = transaction.getAccessChallengeData()
                        data = PostboxAccessChallengeData.numericalPassword(value: result, timeout: data.autolockDeadline, attempts: nil)
                        transaction.setAccessChallengeData(data)
                    }).start()
                    
                    let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                        passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(PostboxAccessChallengeData.numericalPassword(value: result, timeout: nil, attempts: nil))))
                    })
                    
                    dismissImpl?()
                } else {
                    dismissImpl?()
                }
            })!
            legacyController.bind(controller: controller)
            legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
            legacyController.statusBar.statusBarStyle = .White
            presentControllerImpl?(legacyController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            dismissImpl = { [weak legacyController] in
                legacyController?.dismiss()
            }
        })
    }, changePasscodeTimeout: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        var items: [ActionSheetItem] = []
        let setAction: (Int32?) -> Void = { value in
            let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedAutolockTimeout(value))))
                
                let _ = updatePresentationPasscodeSettingsInteractively(postbox: account.postbox, { current in
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
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, changeTouchId: { value in
        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
            passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedEnableBiometrics(value))))
            
            let _ = updatePresentationPasscodeSettingsInteractively(postbox: account.postbox, { current in
                return current.withUpdatedEnableBiometrics(value)
            }).start()
        })
    }, toggleSimplePasscode: { value in
        var dismissImpl: (() -> Void)?
        
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        let legacyController = LegacyController(presentation: LegacyControllerPresentation.modal(animateIn: true), theme: presentationData.theme)
        let controller = TGPasscodeEntryController(context: legacyController.context, style: TGPasscodeEntryControllerStyleDefault, mode: value ? TGPasscodeEntryControllerModeSetupSimple : TGPasscodeEntryControllerModeSetupComplex, cancelEnabled: true, allowTouchId: false, attemptData: nil, completion: { result in
            if let result = result {
                let challenge = value ? PostboxAccessChallengeData.numericalPassword(value: result, timeout: nil, attempts: nil) : PostboxAccessChallengeData.plaintextPassword(value: result, timeout: nil, attempts: nil)
                let _ = account.postbox.transaction({ transaction -> Void in
                    transaction.setAccessChallengeData(challenge)
                    updatePresentationPasscodeSettingsInternal(transaction: transaction, { current in
                        return current.withUpdatedAutolockTimeout(1 * 60 * 60)
                    })
                }).start()
                
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(challenge).withUpdatedPresentationSettings(data.presentationSettings.withUpdatedAutolockTimeout(1 * 60 * 60))))
                })
                
                dismissImpl?()
            } else {
                dismissImpl?()
            }
        })!
        legacyController.bind(controller: controller)
        legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
        legacyController.statusBar.statusBarStyle = .White
        presentControllerImpl?(legacyController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        dismissImpl = { [weak legacyController] in
            legacyController?.dismiss()
        }
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), passcodeOptionsDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state, passcodeOptionsData -> (ItemListControllerState, (ItemListNodeState<PasscodeOptionsEntry>, PasscodeOptionsEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.PasscodeSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: passcodeOptionsControllerEntries(presentationData: presentationData, state: state, passcodeOptionsData: passcodeOptionsData), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    
    return controller
}

public func passcodeOptionsAccessController(account: Account, animateIn: Bool = true, completion: @escaping (Bool) -> Void) -> Signal<ViewController?, NoError> {
    return account.postbox.transaction { transaction -> PostboxAccessChallengeData in
        return transaction.getAccessChallengeData()
    }
    |> deliverOnMainQueue
    |> map { challenge -> ViewController? in
        if case .none = challenge {
            completion(true)
            return nil
        } else {
            var attemptData: TGPasscodeEntryAttemptData?
            if let attempts = challenge.attempts {
                attemptData = TGPasscodeEntryAttemptData(numberOfInvalidAttempts: Int(attempts.count), dateOfLastInvalidAttempt: Double(attempts.timestamp))
            }
            var dismissImpl: (() -> Void)?
            
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            
            let legacyController = LegacyController(presentation: LegacyControllerPresentation.modal(animateIn: true), theme: presentationData.theme)
            let mode: TGPasscodeEntryControllerMode
            switch challenge {
                case .none, .numericalPassword:
                    mode = TGPasscodeEntryControllerModeVerifySimple
                case .plaintextPassword:
                    mode = TGPasscodeEntryControllerModeVerifyComplex
            }
            let controller = TGPasscodeEntryController(context: legacyController.context, style: TGPasscodeEntryControllerStyleDefault, mode: mode, cancelEnabled: true, allowTouchId: false, attemptData: attemptData, completion: { value in
                if value != nil {
                    completion(false)
                }
                dismissImpl?()
            })!
            controller.checkCurrentPasscode = { value in
                if let value = value {
                    switch challenge {
                        case .none:
                            return true
                        case let .numericalPassword(code, _, _):
                            return value == code
                        case let .plaintextPassword(code, _, _):
                            return value == code
                    }
                } else {
                    return false
                }
            }
            controller.updateAttemptData = { attemptData in
                let _ = account.postbox.transaction({ transaction -> Void in
                    var attempts: AccessChallengeAttempts?
                    if let attemptData = attemptData {
                        attempts = AccessChallengeAttempts(count: Int32(attemptData.numberOfInvalidAttempts), timestamp: Int32(attemptData.dateOfLastInvalidAttempt))
                    }
                    var data = transaction.getAccessChallengeData()
                    switch data {
                        case .none:
                            break
                        case let .numericalPassword(value, timeout, _):
                            data = .numericalPassword(value: value, timeout: timeout, attempts: attempts)
                        case let .plaintextPassword(value, timeout, _):
                            data = .plaintextPassword(value: value, timeout: timeout, attempts: attempts)
                    }
                    transaction.setAccessChallengeData(data)
                }).start()
            }
            legacyController.bind(controller: controller)
            legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
            legacyController.statusBar.statusBarStyle = .White
            dismissImpl = { [weak legacyController] in
                legacyController?.dismiss()
            }
            return legacyController
        }
    }
}

public func passcodeEntryController(account: Account, animateIn: Bool = true, completion: @escaping (Bool) -> Void) -> Signal<ViewController?, NoError> {
    return account.postbox.transaction { transaction -> (PostboxAccessChallengeData, PresentationPasscodeSettings?) in
        let passcodeSettings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.presentationPasscodeSettings) as? PresentationPasscodeSettings
        return (transaction.getAccessChallengeData(), passcodeSettings)
    }
    |> deliverOnMainQueue
    |> map { (challenge, passcodeSettings) -> ViewController? in
        if case .none = challenge {
            completion(true)
            return nil
        } else {
            var attemptData: TGPasscodeEntryAttemptData?
            if let attempts = challenge.attempts {
                attemptData = TGPasscodeEntryAttemptData(numberOfInvalidAttempts: Int(attempts.count), dateOfLastInvalidAttempt: Double(attempts.timestamp))
            }
            var dismissImpl: (() -> Void)?
            
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            
            let legacyController = LegacyController(presentation: LegacyControllerPresentation.modal(animateIn: true), theme: presentationData.theme)
            let mode: TGPasscodeEntryControllerMode
            switch challenge {
                case .none, .numericalPassword:
                    mode = TGPasscodeEntryControllerModeVerifySimple
                case .plaintextPassword:
                    mode = TGPasscodeEntryControllerModeVerifyComplex
            }
            let controller = TGPasscodeEntryController(context: legacyController.context, style: TGPasscodeEntryControllerStyleDefault, mode: mode, cancelEnabled: true, allowTouchId: passcodeSettings?.enableBiometrics ?? false, attemptData: attemptData, completion: { value in
                completion(value != nil)
                dismissImpl?()
            })!
            if passcodeSettings?.enableBiometrics ?? false {
                controller.touchIdCompletion = {
                    completion(true)
                    dismissImpl?()
                }
            }
            controller.checkCurrentPasscode = { value in
                if let value = value {
                    switch challenge {
                        case .none:
                            return true
                        case let .numericalPassword(code, _, _):
                            return value == code
                        case let .plaintextPassword(code, _, _):
                            return value == code
                    }
                } else {
                    return false
                }
            }
            controller.updateAttemptData = { attemptData in
                let _ = account.postbox.transaction({ transaction -> Void in
                    var attempts: AccessChallengeAttempts?
                    if let attemptData = attemptData {
                        attempts = AccessChallengeAttempts(count: Int32(attemptData.numberOfInvalidAttempts), timestamp: Int32(attemptData.dateOfLastInvalidAttempt))
                    }
                    var data = transaction.getAccessChallengeData()
                    switch data {
                        case .none:
                            break
                        case let .numericalPassword(value, timeout, _):
                            data = .numericalPassword(value: value, timeout: timeout, attempts: attempts)
                        case let .plaintextPassword(value, timeout, _):
                            data = .plaintextPassword(value: value, timeout: timeout, attempts: attempts)
                    }
                    transaction.setAccessChallengeData(data)
                }).start()
            }
            legacyController.presentationCompleted = { [weak controller] in
                if passcodeSettings?.enableBiometrics ?? false {
                    controller?.refreshTouchId()
                }
            }
            legacyController.bind(controller: controller)
            legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
            legacyController.statusBar.statusBarStyle = .White
            dismissImpl = { [weak legacyController] in
                legacyController?.dismiss()
            }
            return legacyController
        }
    }
}
