import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramLegacyComponents

private final class PasscodeOptionsControllerArguments {
    let turnPasscodeOn: () -> Void
    let turnPasscodeOff: () -> Void
    let changePasscode: () -> Void
    let changePasscodeTimeout: () -> Void
    let changeTouchId: (Bool) -> Void
    
    init(turnPasscodeOn: @escaping () -> Void, turnPasscodeOff: @escaping () -> Void, changePasscode: @escaping () -> Void, changePasscodeTimeout: @escaping () -> Void, changeTouchId: @escaping (Bool) -> Void) {
        self.turnPasscodeOn = turnPasscodeOn
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
    case togglePasscode(String, Bool)
    case changePasscode(String)
    case settingInfo(String)
    
    case autoLock(String, String)
    case touchId(String, Bool)
    
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
            case let .togglePasscode(text, value):
                if case .togglePasscode(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .changePasscode(text):
                if case .changePasscode(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .settingInfo(text):
                if case .settingInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .autoLock(text, value):
                if case .autoLock(text, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .touchId(text, value):
                if case .touchId(text, value) = rhs {
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
            case let .togglePasscode(title, value):
                return ItemListActionItem(title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if value {
                        arguments.turnPasscodeOff()
                    } else {
                        arguments.turnPasscodeOn()
                    }
                })
            case let .changePasscode(title):
                return ItemListActionItem(title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscode()
                })
            case let .settingInfo(text):
                return ItemListTextItem(text: .plain(text), sectionId: self.section)
            case let .autoLock(title, value):
                return ItemListDisclosureItem(title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscodeTimeout()
                })
            case let .touchId(title, value):
                return ItemListSwitchItem(title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
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

private func autolockStringForTimeout(_ timeout: Int32?) -> String {
    if let timeout = timeout {
        if timeout == 10 {
            return "If away for 10 seconds"
        } else if timeout == 1 * 60 {
            return "If away for 1 min"
        } else if timeout == 5 * 60 {
            return "If away for 5 min"
        } else if timeout == 1 * 60 * 60 {
            return "If away for 1 hour"
        } else if timeout == 5 * 60 * 60 {
            return "If away for 5 hours"
        } else {
            return ""
        }
    } else {
        return "Disabled"
    }
}

private func passcodeOptionsControllerEntries(state: PasscodeOptionsControllerState, passcodeOptionsData: PasscodeOptionsData) -> [PasscodeOptionsEntry] {
    var entries: [PasscodeOptionsEntry] = []
    
    switch passcodeOptionsData.accessChallenge {
        case .none:
            entries.append(.togglePasscode("Turn Passcode On", false))
            entries.append(.settingInfo("When you set up an additional passcode, a lock icon will appear on the chats page. Tap it to lock and unlock the app.\n\nNote: if you forget the passcode, you'll need to delete and reinstall the app. All secret chats will be lost."))
        case .numericalPassword, .plaintextPassword:
            entries.append(.togglePasscode("Turn Passcode Off", true))
            entries.append(.changePasscode("Change Passcode"))
            entries.append(.settingInfo("When you set up an additional passcode, a lock icon will appear on the chats page. Tap it to lock and unlock the app.\n\nNote: if you forget the passcode, you'll need to delete and reinstall the app. All secret chats will be lost."))
            entries.append(.autoLock("Auto-Lock", autolockStringForTimeout(passcodeOptionsData.presentationSettings.autolockTimeout)))
            entries.append(.touchId("Unlock with Touch ID", passcodeOptionsData.presentationSettings.enableBiometrics))
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
    passcodeOptionsDataPromise.set(combineLatest(account.postbox.modify { modifier -> PostboxAccessChallengeData in
        return modifier.getAccessChallengeData()
    }, account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.presentationPasscodeSettings]) |> take(1)) |> map { accessChallenge, preferences -> PasscodeOptionsData in
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: (preferences.values[ApplicationSpecificPreferencesKeys.presentationPasscodeSettings] as? PresentationPasscodeSettings) ?? PresentationPasscodeSettings.defaultSettings)
    })
    
    let arguments = PasscodeOptionsControllerArguments(turnPasscodeOn: {
        var dismissImpl: (() -> Void)?
        let controller = TGPasscodeEntryController(style: TGPasscodeEntryControllerStyleDefault, mode: TGPasscodeEntryControllerModeSetupSimple, cancelEnabled: true, allowTouchId: false, attemptData: nil, completion: { result in
            if let result = result {
                let challenge = PostboxAccessChallengeData.numericalPassword(value: result, timeout: nil, attempts: nil)
                let _ = account.postbox.modify({ modifier -> Void in
                    modifier.setAccessChallengeData(challenge)
                }).start()
                
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(challenge)))
                })
                
                dismissImpl?()
            } else {
                dismissImpl?()
            }
        })!
        let legacyController = LegacyController(legacyController: controller, presentation: LegacyControllerPresentation.modal(animateIn: true))
        legacyController.supportedOrientations = .portrait
        legacyController.statusBar.statusBarStyle = .White
        presentControllerImpl?(legacyController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        dismissImpl = { [weak legacyController] in
            legacyController?.dismiss()
        }
    }, turnPasscodeOff: {
        let actionSheet = ActionSheetController()
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: "Turn Passcode Off", color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let challenge = PostboxAccessChallengeData.none
                let _ = account.postbox.modify({ modifier -> Void in
                    modifier.setAccessChallengeData(challenge)
                }).start()
                
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(challenge)))
                })
            })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, changePasscode: {
        var dismissImpl: (() -> Void)?
        let controller = TGPasscodeEntryController(style: TGPasscodeEntryControllerStyleDefault, mode: TGPasscodeEntryControllerModeSetupSimple, cancelEnabled: true, allowTouchId: false, attemptData: nil, completion: { result in
            if let result = result {
                let _ = account.postbox.modify({ modifier -> Void in
                    var data = modifier.getAccessChallengeData()
                    data = PostboxAccessChallengeData.numericalPassword(value: result, timeout: data.autolockDeadline, attempts: nil)
                    modifier.setAccessChallengeData(data)
                }).start()
                
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(PostboxAccessChallengeData.numericalPassword(value: result, timeout: nil, attempts: nil))))
                })
                
                dismissImpl?()
            } else {
                dismissImpl?()
            }
        })!
        let legacyController = LegacyController(legacyController: controller, presentation: LegacyControllerPresentation.modal(animateIn: true))
        legacyController.supportedOrientations = .portrait
        legacyController.statusBar.statusBarStyle = .White
        presentControllerImpl?(legacyController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        dismissImpl = { [weak legacyController] in
            legacyController?.dismiss()
        }
    }, changePasscodeTimeout: {
        let actionSheet = ActionSheetController()
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
            items.append(ActionSheetButtonItem(title: autolockStringForTimeout(t), color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                setAction(t)
            }))
        }
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
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
    })
    
    let signal = combineLatest(statePromise.get(), passcodeOptionsDataPromise.get()) |> deliverOnMainQueue
        |> map { state, passcodeOptionsData -> (ItemListControllerState, (ItemListNodeState<PasscodeOptionsEntry>, PasscodeOptionsEntry.ItemGenerationArguments)) in
            
            let controllerState = ItemListControllerState(title: .text("Passcode Lock"), leftNavigationButton: nil, rightNavigationButton: nil, animateChanges: false)
            let listState = ItemListNodeState(entries: passcodeOptionsControllerEntries(state: state, passcodeOptionsData: passcodeOptionsData), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    
    return controller
}

public func passcodeOptionsAccessController(account: Account, animateIn: Bool = true, completion: @escaping (Bool) -> Void) -> Signal<ViewController?, NoError> {
    return account.postbox.modify { modifier -> PostboxAccessChallengeData in
        return modifier.getAccessChallengeData()
    } |> deliverOnMainQueue
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
            let controller = TGPasscodeEntryController(style: TGPasscodeEntryControllerStyleDefault, mode: TGPasscodeEntryControllerModeVerifySimple, cancelEnabled: true, allowTouchId: false, attemptData: attemptData, completion: { value in
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
                let _ = account.postbox.modify({ modifier -> Void in
                    var attempts: AccessChallengeAttempts?
                    if let attemptData = attemptData {
                        attempts = AccessChallengeAttempts(count: Int32(attemptData.numberOfInvalidAttempts), timestamp: Int32(attemptData.dateOfLastInvalidAttempt))
                    }
                    var data = modifier.getAccessChallengeData()
                    switch data {
                        case .none:
                            break
                        case let .numericalPassword(value, timeout, _):
                            data = .numericalPassword(value: value, timeout: timeout, attempts: attempts)
                        case let .plaintextPassword(value, timeout, _):
                            data = .plaintextPassword(value: value, timeout: timeout, attempts: attempts)
                    }
                    modifier.setAccessChallengeData(data)
                }).start()
            }
            let legacyController = LegacyController(legacyController: controller, presentation: LegacyControllerPresentation.modal(animateIn: animateIn))
            legacyController.supportedOrientations = .portrait
            legacyController.statusBar.statusBarStyle = .White
            dismissImpl = { [weak legacyController] in
                legacyController?.dismiss()
            }
            return legacyController
        }
    }
}
