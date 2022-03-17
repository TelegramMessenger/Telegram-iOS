import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LocalAuthentication
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramStringFormatting
import PasscodeUI
import FakePasscode

private final class FakePasscodeOptionsControllerArguments {
    let changeName: (String) -> Void
    let changePasscode: () -> Void
    let allowLogin: (Bool) -> Void
    let clearAfterActivation: (Bool) -> Void
    let deleteOtherPasscodes: (Bool) -> Void
    let activationMessage: () -> Void
    let badPasscodeActivation: () -> Void
    let fakePasscodeSms: () -> Void
    let clearCache: (Bool) -> Void
    let clearProxies: (Bool) -> Void
    let accountAction: () -> Void
    let deletePasscode: () -> Void

    init(changeName: @escaping (String) -> Void, changePasscode: @escaping () -> Void, allowLogin: @escaping (Bool) -> Void, clearAfterActivation: @escaping (Bool) -> Void, deleteOtherPasscodes: @escaping (Bool) -> Void, activationMessage: @escaping () -> Void, badPasscodeActivation: @escaping () -> Void, fakePasscodeSms: @escaping () -> Void, clearCache: @escaping (Bool) -> Void, clearProxies: @escaping (Bool) -> Void, accountAction: @escaping () -> Void, deletePasscode: @escaping () -> Void) {
        self.changeName = changeName
        self.changePasscode = changePasscode
        self.allowLogin = allowLogin
        self.clearAfterActivation = clearAfterActivation
        self.deleteOtherPasscodes = deleteOtherPasscodes
        self.activationMessage = activationMessage
        self.badPasscodeActivation = badPasscodeActivation
        self.fakePasscodeSms = fakePasscodeSms
        self.clearCache = clearCache
        self.clearProxies = clearProxies
        self.accountAction = accountAction
        self.deletePasscode = deletePasscode
    }
}

private enum FakePasscodeOptionsSection: Int32 {
    case change
    case allowLogin
    case clearAfterActivation
    case activationMessage
    case badPasscodeActivation
    case actions
    case accounts
    case delete
}

private enum FakePasscodeOptionsEntry: ItemListNodeEntry, Equatable {
    case changeName(PresentationTheme, String, String)
    case changePasscode(PresentationTheme, String)
    case changeInfo(PresentationTheme, String)
    case allowLogin(PresentationTheme, String, Bool)
    case allowLoginInfo(PresentationTheme, String)
    case clearAfterActivation(PresentationTheme, String, Bool)
    case clearAfterActivationInfo(PresentationTheme, String)
    case deleteOtherPasscodes(PresentationTheme, String, Bool)
    case deleteOtherPasscodesInfo(PresentationTheme, String)
    case activationMessage(PresentationTheme, String, String)
    case activationMessageInfo(PresentationTheme, String)
    case badPasscodeActivation(PresentationTheme, String, String)
    case badPasscodeActivationInfo(PresentationTheme, String)
    case actionsHeader(PresentationTheme, String)
    case fakePasscodeSms(PresentationTheme, String, Int)
    case clearCache(PresentationTheme, String, Bool)
    case clearProxies(PresentationTheme, String, Bool)
    case actionsInfo(PresentationTheme, String)
    case accountsHeader(PresentationTheme, String)
    case accountAction(PresentationTheme, String)
    case accountsInfo(PresentationTheme, String)
    case deletePasscode(PresentationTheme, String)
    case deletePasscodeInfo(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
            case .changeName, .changePasscode, .changeInfo:
                return FakePasscodeOptionsSection.change.rawValue
            case .allowLogin, .allowLoginInfo:
                return FakePasscodeOptionsSection.allowLogin.rawValue
            case .clearAfterActivation, .clearAfterActivationInfo:
                return FakePasscodeOptionsSection.clearAfterActivation.rawValue
            case .deleteOtherPasscodes, .deleteOtherPasscodesInfo:
                return FakePasscodeOptionsSection.clearAfterActivation.rawValue
            case .activationMessage, .activationMessageInfo:
                return FakePasscodeOptionsSection.clearAfterActivation.rawValue
            case .badPasscodeActivation, .badPasscodeActivationInfo:
                return FakePasscodeOptionsSection.clearAfterActivation.rawValue
            case .actionsHeader, .fakePasscodeSms, .clearCache, .clearProxies, .actionsInfo:
                return FakePasscodeOptionsSection.actions.rawValue
            case .accountsHeader, .accountAction, .accountsInfo:
                return FakePasscodeOptionsSection.accounts.rawValue
            case .deletePasscode, .deletePasscodeInfo:
                return FakePasscodeOptionsSection.delete.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
            case .changeName:
                return 1
            case .changePasscode:
                return 2
            case .changeInfo:
                return 3
            case .allowLogin:
                return 4
            case .allowLoginInfo:
                return 5
            case .clearAfterActivation:
                return 6
            case .clearAfterActivationInfo:
                return 7
            case .deleteOtherPasscodes:
                return 8
            case .deleteOtherPasscodesInfo:
                return 9
            case .activationMessage:
                return 10
            case .activationMessageInfo:
                return 11
            case .badPasscodeActivation:
                return 12
            case .badPasscodeActivationInfo:
                return 13
            case .actionsHeader:
                return 14
            case .fakePasscodeSms:
                return 15
            case .clearCache:
                return 16
            case .clearProxies:
                return 17
            case .actionsInfo:
                return 18
            case .accountsHeader:
                return 19
            case .accountAction:
                return 20
            case .accountsInfo:
                return 21
            case .deletePasscode:
                return 22
            case .deletePasscodeInfo:
                return 23
         }
     }

    static func <(lhs: FakePasscodeOptionsEntry, rhs: FakePasscodeOptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FakePasscodeOptionsControllerArguments
        switch self {
            case let .changeName(_, title, name):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: name, placeholder: title, type: .regular(capitalization: true, autocorrection: false), clearType: .always, maxLength: 12, sectionId: self.section, textUpdated: { value in
                    arguments.changeName(value)
                    // FIXME use custom state to avoid unncecessary updates look at ResetPasswordController
                }, action: {}, cleared: {})
            case let .changePasscode(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscode()
                })
            case let .changeInfo(_, text), let .allowLoginInfo(_, text), let .clearAfterActivationInfo(_, text), let .deleteOtherPasscodesInfo(_, text), let .activationMessageInfo(_, text), let .badPasscodeActivationInfo(_, text), let .actionsInfo(_, text), let .accountsInfo(_, text), let .deletePasscodeInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .allowLogin(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.allowLogin(updatedValue)
                })
            case let .clearAfterActivation(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.clearAfterActivation(updatedValue)
                })
            case let .deleteOtherPasscodes(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.deleteOtherPasscodes(updatedValue)
                })
            case let .activationMessage(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.activationMessage()
                })
            case let .badPasscodeActivation(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.badPasscodeActivation()
                })
            case let .actionsHeader(_, text), let .accountsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .fakePasscodeSms(_, text, count):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: count.description, sectionId: self.section, style: .blocks, action: {
                    arguments.fakePasscodeSms()
                })
            case let .clearCache(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.clearCache(updatedValue)
                })
            case let .clearProxies(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.clearProxies(updatedValue)
                })
            case let .accountAction(_, text):
                let avatarImage = UIImage(bundleImageName: "Avatar/ArchiveAvatarIcon")?.precomposed() // TODO replace with actual avatar
                return ItemListDisclosureItem(presentationData: presentationData, icon: avatarImage, title: text, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.accountAction()
                })
            case let .deletePasscode(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.deletePasscode()
                })
        }
    }
}

private struct FakePasscodeOptionsData: Equatable {
    let accessChallenge: PostboxAccessChallengeData
    let presentationSettings: FakePasscodeSettings

    init(accessChallenge: PostboxAccessChallengeData, presentationSettings: FakePasscodeSettings) {
        self.accessChallenge = accessChallenge
        self.presentationSettings = presentationSettings
    }

    static func ==(lhs: FakePasscodeOptionsData, rhs: FakePasscodeOptionsData) -> Bool {
        return lhs.accessChallenge == rhs.accessChallenge && lhs.presentationSettings == rhs.presentationSettings
    }

    func withUpdatedAccessChallenge(_ accessChallenge: PostboxAccessChallengeData) -> FakePasscodeOptionsData {
        return FakePasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: self.presentationSettings)
    }

    func withUpdatedPresentationSettings(_ presentationSettings: FakePasscodeSettings) -> FakePasscodeOptionsData {
        return FakePasscodeOptionsData(accessChallenge: self.accessChallenge, presentationSettings: presentationSettings)
    }
}

private struct FakePasscodeOptionsControllerState: Equatable {
    static func ==(lhs: FakePasscodeOptionsControllerState, rhs: FakePasscodeOptionsControllerState) -> Bool {
        return true
    }
}

private func fakePasscodeOptionsControllerEntries(presentationData: PresentationData, state: FakePasscodeOptionsControllerState, index: Int) -> [FakePasscodeOptionsEntry] {
    let entries: [FakePasscodeOptionsEntry] = [
        .changeName(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChangeName, "Fake passcode \(index)"),
        .changePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChange),
        .changeInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChangeHelp),
        .allowLogin(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAllowLogin, false),
        .allowLoginInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAllowLoginHelp),
        .clearAfterActivation(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeClearAfterActivation, false),
        .clearAfterActivationInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeClearAfterActivationHelp),
        .deleteOtherPasscodes(presentationData.theme, presentationData.strings.PasscodeSettings_DeleteOtherPasscodesAfterActivation, false),
        .deleteOtherPasscodesInfo(presentationData.theme, presentationData.strings.PasscodeSettings_DeleteOtherPasscodesAfterActivationHelp),
        .activationMessage(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActivationMessage, "Message"),
        .activationMessageInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActivationMessageHelp),
        .badPasscodeActivation(presentationData.theme, presentationData.strings.PasscodeSettings_BadPasscodeTriesToActivate, "Message"),
        .badPasscodeActivationInfo(presentationData.theme, presentationData.strings.PasscodeSettings_BadPasscodeTriesToActivateHelp),
        .actionsHeader(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActionsTitle),
        .fakePasscodeSms(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeSmsActionTitle, 0),
        .clearCache(presentationData.theme, presentationData.strings.PasscodeSettings_ClearTelegramCache, false),
        .clearProxies(presentationData.theme, presentationData.strings.PasscodeSettings_ClearTelegramCache, false),
        .actionsInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActionsHelp),
        .accountsHeader(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAccountsTitle),
        .accountAction(presentationData.theme, "Usename"),
        .accountsInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAccountsHelp),
        .deletePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeDelete),
        .deletePasscodeInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeDeleteHelp)
    ]

    return entries
}

public func fakePasscodeOptionsController(context: AccountContext, index: Int) -> ViewController {
    let initialState = FakePasscodeOptionsControllerState()

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)

    var pushControllerImpl: ((ViewController) -> Void)?
    var popControllerImpl: (() -> Void)?

    let actionsDisposable = DisposableSet()

    let passcodeOptionsDataPromise = Promise<FakePasscodeOptionsData>()
    passcodeOptionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> (PostboxAccessChallengeData, FakePasscodeSettings) in
        let passcodeSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.fakePasscodeSettings)?.get(FakePasscodeSettingsHolder.self)?.settings[index] ?? FakePasscodeSettings.defaultSettings
        return (transaction.getAccessChallengeData(), passcodeSettings)
    }
    |> map { accessChallenge, passcodeSettings -> FakePasscodeOptionsData in
        return FakePasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: passcodeSettings)
    })

    let arguments = FakePasscodeOptionsControllerArguments(changeName: { value in
        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
            passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedName(value))))

            let _ = updateFakePasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, index: index, { current in
                return current.withUpdatedName(value)
            }).start()
        })
    }, changePasscode: {
        fakePasscodeSetupController(context: context, pushController: pushControllerImpl, popController: popControllerImpl) { transaction, oldChallengeData, newPasscode, numerical in
            switch oldChallengeData {
                case .none:
                    assertionFailure("Fake passcodes shouldn't be available without the 'regular' passcode enabled")
                    return oldChallengeData
                case .numericalPassword(let code, var fakes), .plaintextPassword(let code, var fakes):
                    fakes[index] = newPasscode
                    if numerical {
                        return PostboxAccessChallengeData.numericalPassword(value: code, fakeValue: fakes)
                    } else {
                        return PostboxAccessChallengeData.plaintextPassword(value: code, fakeValue: fakes)
                    }
            }
        }
    }, allowLogin: { enabled in
        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
            passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedAllowLogin(enabled))))

            let _ = updateFakePasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, index: index, { current in
                return current.withUpdatedAllowLogin(enabled)
            }).start()
        })
    }, clearAfterActivation: { enabled in
        // TODO implement
    }, deleteOtherPasscodes: { enabled in
        // TODO implement
    }, activationMessage: {
        // TODO implement
    }, badPasscodeActivation: {
        // TODO implement
    }, fakePasscodeSms: {
        // TODO implement
    }, clearCache: { enabled in
        // TODO implement
    }, clearProxies: { enabled in
        // TODO implement
    }, accountAction: {
        // TODO implement
    }, deletePasscode: {
        // TODO implement
    })

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let title = presentationData.strings.PasscodeSettings_FakePasscode(index + 1).string // TODO replace with actual name
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: fakePasscodeOptionsControllerEntries(presentationData: presentationData, state: state, index: index), style: .blocks, emptyStateItem: nil, animateChanges: false)

            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    popControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    return controller
}

public func fakePasscodeSetupController(context: AccountContext, pushController: ((ViewController) -> Void)?, popController: (() -> Void)?, challengeDataUpdate: @escaping (AccountManagerModifier<TelegramAccountManagerTypes>, PostboxAccessChallengeData, String, Bool) -> PostboxAccessChallengeData) {
    let _ = (context.sharedContext.accountManager.transaction({ transaction -> (PasscodeEntryFieldType, [String]) in
        let data = transaction.getAccessChallengeData()
        switch data {
            case .none:
                assertionFailure()
                return (.alphanumeric, [])
            case .numericalPassword(let passcode, let fakePasscodes):
                return (passcode.count == 6 ? .digits6 : .digits4, fakePasscodes + [passcode])
            case .plaintextPassword(let passcode, let fakePasscodes):
                return (.alphanumeric, fakePasscodes + [passcode])
        }
    })
    |> deliverOnMainQueue).start(next: { (fieldType, reserved) in
        let setupController = PasscodeSetupController(context: context, mode: .setup(change: true, allowChangeType: false, fieldType))
        setupController.validate = { newPasscode in
            if reserved.contains(newPasscode) {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                return presentationData.strings.PasscodeSettings_PasscodeInUse
            }
            return nil
        }
        setupController.complete = { newPasscode, numerical in
            let _ = (context.sharedContext.accountManager.transaction({ transaction -> Void in
                let data = transaction.getAccessChallengeData()
                let updatedData = challengeDataUpdate(transaction, data, newPasscode, numerical)
                transaction.setAccessChallengeData(updatedData)
            }) |> deliverOnMainQueue).start(next: { _ in
            }, error: { _ in
            }, completed: {
                popController?()
            })
        }
        pushController?(setupController)
    })
}
