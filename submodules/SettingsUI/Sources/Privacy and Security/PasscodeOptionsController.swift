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
import FakePasscode
import FakePasscodeUI
import ItemListPeerActionItem


private final class PasscodeOptionsControllerArguments {
    let turnPasscodeOff: () -> Void
    let changePasscode: () -> Void
    let changePasscodeTimeout: () -> Void
    let changeTouchId: (Bool) -> Void
    let openFakePasscodeOptions: (UUID) -> Void
    let addFakePasscode: () -> Void
    let openBadPasscodeAttempts: () -> Void
    
    init(turnPasscodeOff: @escaping () -> Void, changePasscode: @escaping () -> Void, changePasscodeTimeout: @escaping () -> Void, changeTouchId: @escaping (Bool) -> Void, openFakePasscodeOptions: @escaping (UUID) -> Void, addFakePasscode: @escaping () -> Void, openBadPasscodeAttempts: @escaping () -> Void) {
        self.turnPasscodeOff = turnPasscodeOff
        self.changePasscode = changePasscode
        self.changePasscodeTimeout = changePasscodeTimeout
        self.changeTouchId = changeTouchId
        self.openFakePasscodeOptions = openFakePasscodeOptions
        self.addFakePasscode = addFakePasscode
        self.openBadPasscodeAttempts = openBadPasscodeAttempts
    }
}

private enum PasscodeOptionsSection: Int32 {
    case setting
    case options
    // partisan settings:
    case fakePasscodes
    case badPasscodeAttempts
}

private enum PasscodeOptionsEntry: ItemListNodeEntry {
    enum StableId: Hashable, Comparable {
        case togglePasscode
        case changePasscode
        case settingInfo
        case autoLock
        case touchId
        case openFakePasscodeOptions(Int)
        case addFakePasscode
        case fakePasscodeInfo
        case badPasscodeAttempts
        case badPasscodeAttemptsInfo

        private var order: Int32 {
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
                case .openFakePasscodeOptions(_):
                    return 5
                case .addFakePasscode:
                    return 6
                case .fakePasscodeInfo:
                    return 7
                case .badPasscodeAttempts:
                    return 8
                case .badPasscodeAttemptsInfo:
                    return 9
            }
        }

        static func <(lsid: StableId, rsid: StableId) -> Bool {
            switch (lsid, rsid) {
            case (.openFakePasscodeOptions(let lidx), .openFakePasscodeOptions(let ridx)):
                return lidx < ridx
            default:
                return lsid.order < rsid.order
            }
        }
    }

    case togglePasscode(PresentationTheme, String, Bool)
    case changePasscode(PresentationTheme, String)
    case settingInfo(PresentationTheme, String)
    
    case autoLock(PresentationTheme, String, String)
    case touchId(PresentationTheme, String, Bool)

    case openFakePasscodeOptions(PresentationTheme, String, Int, UUID, String)
    case addFakePasscode(PresentationTheme, String)
    case fakePasscodeInfo(PresentationTheme, String)
    
    case badPasscodeAttempts(PresentationTheme, String, Int)
    case badPasscodeAttemptsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .togglePasscode, .changePasscode, .settingInfo:
                return PasscodeOptionsSection.setting.rawValue
            case .autoLock, .touchId:
                return PasscodeOptionsSection.options.rawValue
            case .openFakePasscodeOptions, .fakePasscodeInfo, .addFakePasscode:
                return PasscodeOptionsSection.fakePasscodes.rawValue
            case .badPasscodeAttempts, .badPasscodeAttemptsInfo:
                return PasscodeOptionsSection.badPasscodeAttempts.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
            case .togglePasscode:
                return .togglePasscode
            case .changePasscode:
                return .changePasscode
            case .settingInfo:
                return .settingInfo
            case .autoLock:
                return .autoLock
            case .touchId:
                return .touchId
            case .addFakePasscode:
                return .addFakePasscode
            case .openFakePasscodeOptions(_, _, let index, _, _):
                return .openFakePasscodeOptions(index)
            case .fakePasscodeInfo:
                return .fakePasscodeInfo
            case .badPasscodeAttempts:
                return .badPasscodeAttempts
            case .badPasscodeAttemptsInfo:
                return .badPasscodeAttemptsInfo
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
            case let .openFakePasscodeOptions(lhsTheme, lhsText, lhsIdx, lhsUuid, lhsPasscode):
                if case let .openFakePasscodeOptions(rhsTheme, rhsText, rhsIdx, rhsUuid, rhsPasscode) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsIdx == rhsIdx, lhsUuid == rhsUuid, lhsPasscode == rhsPasscode {
                    return true
                } else {
                    return false
                }
            case let .addFakePasscode(lhsTheme, lhsText):
                if case let .addFakePasscode(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .fakePasscodeInfo(lhsTheme, lhsText):
                if case let .fakePasscodeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .badPasscodeAttempts(lhsTheme, lhsText, lhsValue):
                if case let .badPasscodeAttempts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .badPasscodeAttemptsInfo(lhsTheme, lhsText):
                if case let .badPasscodeAttemptsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .openFakePasscodeOptions(_, title, _, uuid, _):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.openFakePasscodeOptions(uuid)
                })
            case let .addFakePasscode(_, title):
            return ItemListPeerActionItem(presentationData: presentationData, icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: presentationData.theme.list.itemAccentColor), title: title, sectionId: self.section, height: .generic, action: {
                    arguments.addFakePasscode()
                })
            case let .fakePasscodeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .badPasscodeAttempts(_, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: title, enabled: value > 0, label: "\(value)", sectionId: self.section, style: .blocks, action: {
                    arguments.openBadPasscodeAttempts()
                })
            case let .badPasscodeAttemptsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
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
    let fakePasscodeHolder: FakePasscodeSettingsHolder
    let badPasscodeAttempts: BadPasscodeAttempts
    
    init(accessChallenge: PostboxAccessChallengeData, presentationSettings: PresentationPasscodeSettings, fakePasscodeHolder: FakePasscodeSettingsHolder, badPasscodeAttempts: BadPasscodeAttempts) {
        self.accessChallenge = accessChallenge
        self.presentationSettings = presentationSettings
        self.fakePasscodeHolder = fakePasscodeHolder
        self.badPasscodeAttempts = badPasscodeAttempts
    }
    
    static func ==(lhs: PasscodeOptionsData, rhs: PasscodeOptionsData) -> Bool {
        return lhs.accessChallenge == rhs.accessChallenge && lhs.presentationSettings == rhs.presentationSettings && lhs.fakePasscodeHolder == rhs.fakePasscodeHolder && lhs.badPasscodeAttempts == rhs.badPasscodeAttempts
    }
    
    func withUpdatedAccessChallenge(_ accessChallenge: PostboxAccessChallengeData) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: self.presentationSettings, fakePasscodeHolder: self.fakePasscodeHolder, badPasscodeAttempts: self.badPasscodeAttempts)
    }
    
    func withUpdatedPresentationSettings(_ presentationSettings: PresentationPasscodeSettings) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: self.accessChallenge, presentationSettings: presentationSettings, fakePasscodeHolder: self.fakePasscodeHolder, badPasscodeAttempts: self.badPasscodeAttempts)
    }
    
    func withUpdatedFakePasscodeSettingsHolder(_ fakePasscodeHolder: FakePasscodeSettingsHolder) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: self.accessChallenge, presentationSettings: self.presentationSettings, fakePasscodeHolder: fakePasscodeHolder, badPasscodeAttempts: self.badPasscodeAttempts)
    }
    
    func withUpdatedBadPasscodeAttempts(_ badPasscodeAttempts: BadPasscodeAttempts) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: self.accessChallenge, presentationSettings: self.presentationSettings, fakePasscodeHolder: self.fakePasscodeHolder, badPasscodeAttempts: badPasscodeAttempts)
    }
}

public func autolockStringForTimeout(strings: PresentationStrings, timeout: Int32?) -> String {
    if let timeout = timeout {
        if timeout == 10 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_10seconds
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

            if !passcodeOptionsData.fakePasscodeHolder.unlockedWithFakePasscode() {
                for (index, s) in passcodeOptionsData.fakePasscodeHolder.settings.enumerated() {
                    entries.append(.openFakePasscodeOptions(presentationData.theme, s.name, index, s.uuid, s.passcode ?? ""))
                }
                entries.append(.addFakePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_AddFakePasscode))
                entries.append(.fakePasscodeInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeHelp))
                
                entries.append(.badPasscodeAttempts(presentationData.theme, presentationData.strings.PasscodeSettings_BadAttempts, passcodeOptionsData.badPasscodeAttempts.badPasscodeAttempts.count))
                entries.append(.badPasscodeAttemptsInfo(presentationData.theme, presentationData.strings.PasscodeSettings_BadAttempts_Help))
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
    passcodeOptionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> (PostboxAccessChallengeData, PresentationPasscodeSettings, FakePasscodeSettingsHolder, BadPasscodeAttempts) in
        let passcodeSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings)?.get(PresentationPasscodeSettings.self) ?? PresentationPasscodeSettings.defaultSettings
        let fakePasscodeHolder = FakePasscodeSettingsHolder(transaction)
        let badPasscodeAttempts = BadPasscodeAttempts(transaction)
        return (transaction.getAccessChallengeData(), passcodeSettings, fakePasscodeHolder, badPasscodeAttempts)
    }
    |> map { accessChallenge, passcodeSettings, fakePasscodeHolder, badPasscodeAttempts -> PasscodeOptionsData in
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: passcodeSettings, fakePasscodeHolder: fakePasscodeHolder, badPasscodeAttempts: badPasscodeAttempts)
    })
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let arguments = PasscodeOptionsControllerArguments(turnPasscodeOff: {
        let _ = (context.sharedContext.accountManager.transaction({ transaction -> FakePasscodeSettingsHolder in
            return FakePasscodeSettingsHolder(transaction)
        })
        |> deliverOnMainQueue).start(next: { fakePasscodeHolder in
            let actionSheet = ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items:
                 ((!fakePasscodeHolder.unlockedWithFakePasscode() && !fakePasscodeHolder.settings.isEmpty) ? [ActionSheetTextItem(title: presentationData.strings.PasscodeSettings_AllFakePasscodesWillBeDeleted)] : []) +
                [ActionSheetButtonItem(title: presentationData.strings.PasscodeSettings_TurnPasscodeOff, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    let challenge = PostboxAccessChallengeData.none
                    let _ = context.sharedContext.accountManager.transaction({ transaction -> Void in
                        transaction.setAccessChallengeData(challenge)
                        
                        let updatedFakePasscodeHolder = FakePasscodeSettingsHolder(transaction).withUpdatedAccessChallenge(challenge)
                        updateFakePasscodeSettingsInternal(transaction: transaction) { _ in
                            return updatedFakePasscodeHolder
                        }
                        
                        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                            passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(challenge).withUpdatedFakePasscodeSettingsHolder(updatedFakePasscodeHolder)))
                        })
                    }).start()
                    
                    var innerReplaceTopControllerImpl: ((ViewController, Bool) -> Void)?
                    let controller = PrivacyIntroController(context: context, mode: .passcode, proceedAction: {
                        let setupController = PasscodeSetupController(context: context, mode: .setup(change: false, allowChangeType: true, .digits6))
                        setupController.complete = { passcode, numerical in
                            let _ = (context.sharedContext.accountManager.transaction({ transaction -> Void in
                                var data = transaction.getAccessChallengeData()
                                if numerical {
                                    data = PostboxAccessChallengeData.numericalPassword(value: passcode)
                                } else {
                                    data = PostboxAccessChallengeData.plaintextPassword(value: passcode)
                                }
                                transaction.setAccessChallengeData(data)
                                
                                updateFakePasscodeSettingsInternal(transaction: transaction) { holder in
                                    return holder.withUpdatedAccessChallenge(data)
                                }
                                
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
        })
    }, changePasscode: {
        let _ = (context.sharedContext.accountManager.transaction({ transaction -> FakePasscodeSettingsHolder in
            return FakePasscodeSettingsHolder(transaction)
        })
        |> deliverOnMainQueue).start(next: { fakePasscodeHolder in
            let showPasscodeSetup = {
                let setupController = PasscodeSetupController(context: context, mode: .setup(change: true, allowChangeType: true, .digits6))
                setupController.complete = { passcode, numerical in
                    let _ = (context.sharedContext.accountManager.transaction({ transaction -> Void in
                        var updatedData: PostboxAccessChallengeData
                        if numerical {
                            updatedData = PostboxAccessChallengeData.numericalPassword(value: passcode)
                        } else {
                            updatedData = PostboxAccessChallengeData.plaintextPassword(value: passcode)
                        }
                        transaction.setAccessChallengeData(updatedData)
                        
                        let updatedFakePasscodeHolder = FakePasscodeSettingsHolder(transaction).withUpdatedAccessChallenge(updatedData)
                        updateFakePasscodeSettingsInternal(transaction: transaction) { _ in
                            return updatedFakePasscodeHolder
                        }
                        
                        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                            passcodeOptionsDataPromise?.set(.single(data.withUpdatedAccessChallenge(updatedData).withUpdatedFakePasscodeSettingsHolder(updatedFakePasscodeHolder)))
                        })
                    }) |> deliverOnMainQueue).start(next: { _ in
                    }, error: { _ in
                    }, completed: {
                        popControllerImpl?()
                    })
                }
                pushControllerImpl?(setupController)
            }
            if !fakePasscodeHolder.unlockedWithFakePasscode() && !fakePasscodeHolder.settings.isEmpty {
                let actionSheet = ActionSheetController(presentationData: presentationData)
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetTextItem(title: presentationData.strings.PasscodeSettings_AllFakePasscodesWillBeDeleted),
                        ActionSheetButtonItem(title: presentationData.strings.PasscodeSettings_ChangePasscode, color: .destructive, action: { [weak actionSheet] in
                            showPasscodeSetup()
                            actionSheet?.dismissAnimated()
                        })
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else {
                showPasscodeSetup()
            }
        })
    }, changePasscodeTimeout: {
        let _ = (context.sharedContext.accountManager.transaction({ transaction -> FakePasscodeSettingsHolder in
            return FakePasscodeSettingsHolder(transaction)
        })
        |> deliverOnMainQueue).start(next: { fakePasscodeHolder in
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
            let values: [Int32] = [0, 10, 1 * 60, 5 * 60, 1 * 60 * 60, 5 * 60 * 60]
            
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
        })
    }, changeTouchId: { value in
        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
            passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedEnableBiometrics(value))))
            
            let _ = updatePresentationPasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current.withUpdatedEnableBiometrics(value)
            }).start()
        })
    }, openFakePasscodeOptions: { uuid in
        let fakeOptionsController = fakePasscodeOptionsController(context: context, uuid: uuid, passcodeOptionsDataPromise: passcodeOptionsDataPromise)
        pushControllerImpl?(fakeOptionsController)
    }, addFakePasscode: {
        var newFakePasscodeUuid: UUID?
        pushFakePasscodeSetupController(context: context, currentFakePasscodeUuid: nil, pushController: pushControllerImpl, popController: popControllerImpl, challengeDataUpdate: { transaction, newPasscode, numerical in
            updateFakePasscodeSettingsInternal(transaction: transaction) { fakePasscodeHolder in
                let newPasscodeData = PostboxAccessChallengeData(passcode: newPasscode, numerical: numerical)
                
                let newItem = FakePasscodeSettings(name: presentationData.strings.PasscodeSettings_FakePasscode(Int(fakePasscodeHolder.fakePasscodeIndex) + 1).string, passcode: newPasscodeData.normalizedString())
                
                let updatedFakePasscodeHolder = fakePasscodeHolder.withAddedSettingsItem(newItem)
                
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                    passcodeOptionsDataPromise?.set(.single(data.withUpdatedFakePasscodeSettingsHolder(updatedFakePasscodeHolder)))
                })
                
                newFakePasscodeUuid = newItem.uuid

                return updatedFakePasscodeHolder
            }
        }, completed: {
            let fakeOptionsController = fakePasscodeOptionsController(context: context, uuid: newFakePasscodeUuid!, passcodeOptionsDataPromise: passcodeOptionsDataPromise)
            replaceTopControllerImpl?(fakeOptionsController, true)
        })
    }, openBadPasscodeAttempts: {
        let bpaController = BadPasscodeAttemptsController(context: context)
        bpaController.clear = {
            let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                passcodeOptionsDataPromise?.set(.single(data.withUpdatedBadPasscodeAttempts(data.badPasscodeAttempts.withUpdatedBadPasscodeAttempts([]))))
                
                let _ = updateBadPasscodeAttemptsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    return current.withUpdatedBadPasscodeAttempts([])
                }).start()
            })
            
            popControllerImpl?()
        }
        
        pushControllerImpl?(bpaController)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), passcodeOptionsDataPromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state, passcodeOptionsData -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PasscodeSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: passcodeOptionsControllerEntries(presentationData: presentationData, state: state, passcodeOptionsData: passcodeOptionsData), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListControllerReactiveToPasscodeSwitch(context: context, state: signal, onPasscodeSwitch: { controller in
        let _ = (context.sharedContext.accountManager.transaction { transaction in
            return FakePasscodeSettingsHolder(transaction)
        }).start(next: { fakePasscodeHolder in
            let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                passcodeOptionsDataPromise?.set(.single(data.withUpdatedFakePasscodeSettingsHolder(fakePasscodeHolder)))
            })
        })
    })
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
    return context.sharedContext.accountManager.transaction { transaction -> (PostboxAccessChallengeData, FakePasscodeSettingsHolder) in
        let fakePasscodeHolder = FakePasscodeSettingsHolder(transaction)
        return (transaction.getAccessChallengeData(), fakePasscodeHolder)
    }
    |> deliverOnMainQueue
    |> map { (challenge, fakePasscodeHolder) -> ViewController? in
        if case .none = challenge {
            let controller = PrivacyIntroController(context: context, mode: .passcode, proceedAction: {
                let setupController = PasscodeSetupController(context: context, mode: .setup(change: false, allowChangeType: true, .digits6))
                setupController.complete = { passcode, numerical in
                    let _ = (context.sharedContext.accountManager.transaction({ transaction -> Void in
                        var data = transaction.getAccessChallengeData()
                        if numerical {
                            data = PostboxAccessChallengeData.numericalPassword(value: passcode)
                        } else {
                            data = PostboxAccessChallengeData.plaintextPassword(value: passcode)
                        }
                        transaction.setAccessChallengeData(data)
                        
                        updateFakePasscodeSettingsInternal(transaction: transaction) { holder in
                            return holder.withUpdatedAccessChallenge(data)
                        }
                        
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
                let (succeed, _, _) = ptgCheckPasscode(passcode: passcode, secondaryUnlock: true, accessChallenge: challenge, fakePasscodeHolder: fakePasscodeHolder)
                
                if succeed {
                    if fakePasscodeHolder.unlockedWithFakePasscode() {
                        addBadPasscodeAttempt(accountManager: context.sharedContext.accountManager, bpa: BadPasscodeAttempt(type: BadPasscodeAttempt.PasscodeSettingsType, isFakePasscode: true))
                    }
                } else {
                    addBadPasscodeAttempt(accountManager: context.sharedContext.accountManager, bpa: BadPasscodeAttempt(type: BadPasscodeAttempt.PasscodeSettingsType, isFakePasscode: false))
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

private func fakePasscodeOptionsController(context: AccountContext, uuid: UUID, passcodeOptionsDataPromise: Promise<PasscodeOptionsData>) -> ViewController {
    let controller = fakePasscodeOptionsController(context: context, uuid: uuid, updateParentDataPromise: { fakePasscodeHolder in
        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
            passcodeOptionsDataPromise?.set(.single(data.withUpdatedFakePasscodeSettingsHolder(fakePasscodeHolder)))
        })
    })
    return controller
}
