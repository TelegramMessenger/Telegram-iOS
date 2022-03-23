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
import AvatarNode
import LocalMediaResources

private final class FakePasscodeOptionsControllerArguments {
    let account: Account
    let changeName: (String) -> Void
    let commitName: () -> Void
    let changePasscode: () -> Void
    let allowLogin: (Bool) -> Void
    let clearAfterActivation: (Bool) -> Void
    let deleteOtherPasscodes: (Bool) -> Void
    let activationMessage: (String) -> Void
    let commitActivationMessage: () -> Void
    let badPasscodeActivation: () -> Void
    let smsActions: () -> Void
    let clearCache: (Bool) -> Void
    let clearProxies: (Bool) -> Void
    let accountActions: () -> Void
    let deletePasscode: () -> Void

    init(account: Account, changeName: @escaping (String) -> Void, commitName: @escaping () -> Void,  changePasscode: @escaping () -> Void, allowLogin: @escaping (Bool) -> Void, clearAfterActivation: @escaping (Bool) -> Void, deleteOtherPasscodes: @escaping (Bool) -> Void, activationMessage: @escaping (String) -> Void, commitActivationMessage: @escaping () -> Void, badPasscodeActivation: @escaping () -> Void, smsActions: @escaping () -> Void, clearCache: @escaping (Bool) -> Void, clearProxies: @escaping (Bool) -> Void, accountActions: @escaping () -> Void, deletePasscode: @escaping () -> Void) {
        self.account = account
        self.changeName = changeName
        self.commitName = commitName
        self.changePasscode = changePasscode
        self.allowLogin = allowLogin
        self.clearAfterActivation = clearAfterActivation
        self.deleteOtherPasscodes = deleteOtherPasscodes
        self.activationMessage = activationMessage
        self.commitActivationMessage = commitActivationMessage
        self.badPasscodeActivation = badPasscodeActivation
        self.smsActions = smsActions
        self.clearCache = clearCache
        self.clearProxies = clearProxies
        self.accountActions = accountActions
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
    case smsActions(PresentationTheme, String, Int)
    case clearCache(PresentationTheme, String, Bool)
    case clearProxies(PresentationTheme, String, Bool)
    case actionsInfo(PresentationTheme, String)
    case accountsHeader(PresentationTheme, String)
    case accountActions(PresentationTheme, String, UIImage?)
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
            case .actionsHeader, .smsActions, .clearCache, .clearProxies, .actionsInfo:
                return FakePasscodeOptionsSection.actions.rawValue
            case .accountsHeader, .accountActions, .accountsInfo:
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
            case .smsActions:
                return 15
            case .clearCache:
                return 16
            case .clearProxies:
                return 17
            case .actionsInfo:
                return 18
            case .accountsHeader:
                return 19
            case .accountActions:
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
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: name, placeholder: title, type: .regular(capitalization: true, autocorrection: false), clearType: .always, sectionId: self.section, textUpdated: { value in
                    arguments.changeName(value)
                }, updatedFocus: { focused in
                    if !focused {
                        arguments.commitName()
                    }
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
            case let .activationMessage(_, title, value):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: value, placeholder: title, type: .regular(capitalization: true, autocorrection: false), clearType: .always, sectionId: self.section, textUpdated: { value in
                    arguments.activationMessage(value)
                }, updatedFocus: { focused in
                    if !focused {
                        arguments.commitActivationMessage()
                    }
                }, action: {}, cleared: {})
            case let .badPasscodeActivation(_, text, value):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.badPasscodeActivation()
                })
            case let .actionsHeader(_, text), let .accountsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .smsActions(_, text, count):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: count.description, sectionId: self.section, style: .blocks, action: {
                    arguments.smsActions()
                })
            case let .clearCache(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.clearCache(updatedValue)
                })
            case let .clearProxies(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.clearProxies(updatedValue)
                })
            case let .accountActions(_, username, avatar):
                return ItemListDisclosureItem(presentationData: presentationData, icon: avatar, title: username, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.accountActions()
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
    let settings: FakePasscodeSettings

    init(accessChallenge: PostboxAccessChallengeData, presentationSettings: FakePasscodeSettings) {
        self.accessChallenge = accessChallenge
        self.settings = presentationSettings
    }

    static func ==(lhs: FakePasscodeOptionsData, rhs: FakePasscodeOptionsData) -> Bool {
        return lhs.accessChallenge == rhs.accessChallenge && lhs.settings == rhs.settings
    }

    func withUpdatedAccessChallenge(_ accessChallenge: PostboxAccessChallengeData) -> FakePasscodeOptionsData {
        return FakePasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: self.settings)
    }

    func withUpdatedSettings(_ presentationSettings: FakePasscodeSettings) -> FakePasscodeOptionsData {
        return FakePasscodeOptionsData(accessChallenge: self.accessChallenge, presentationSettings: presentationSettings)
    }
}

private struct FakePasscodeOptionsControllerState: Equatable {
    var name: String?
    var activationMessage: String?
}

private func fakePasscodeOptionsControllerEntries(presentationData: PresentationData, settings: FakePasscodeSettings, displayName: String, avatar: UIImage?) -> [FakePasscodeOptionsEntry] {
    let entries: [FakePasscodeOptionsEntry] = [
        .changeName(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChangeName, settings.name),
        .changePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChange),
        .changeInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChangeHelp),
        // TODO uncomment sections bellow once implemented
        // .allowLogin(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAllowLogin, settings.allowLogin),
        // .allowLoginInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAllowLoginHelp),
        // .clearAfterActivation(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeClearAfterActivation, settings.clearAfterActivation),
        // .clearAfterActivationInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeClearAfterActivationHelp),
        // .deleteOtherPasscodes(presentationData.theme, presentationData.strings.PasscodeSettings_DeleteOtherPasscodesAfterActivation, settings.deleteOtherPasscodes),
        // .deleteOtherPasscodesInfo(presentationData.theme, presentationData.strings.PasscodeSettings_DeleteOtherPasscodesAfterActivationHelp),
        // .activationMessage(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActivationMessage, settings.activationMessage ?? ""),
        // .activationMessageInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActivationMessageHelp),
        // .badPasscodeActivation(presentationData.theme, presentationData.strings.PasscodeSettings_BadPasscodeTriesToActivate, String(settings.activationAttempts)),
        // .badPasscodeActivationInfo(presentationData.theme, presentationData.strings.PasscodeSettings_BadPasscodeTriesToActivateHelp),
        // .actionsHeader(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActionsTitle),
        // .smsActions(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeSmsActionTitle, 0 /* TODO implement */),
        // .clearCache(presentationData.theme, presentationData.strings.PasscodeSettings_ClearTelegramCache, settings.clearCache),
        // .clearProxies(presentationData.theme, presentationData.strings.PasscodeSettings_ClearTelegramCache, settings.clearProxies),
        // .actionsInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeActionsHelp),
        // .accountsHeader(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAccountsTitle),
        // .accountActions(presentationData.theme, displayName, avatar),
        // .accountsInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAccountsHelp),
        // .deletePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeDelete),
        // .deletePasscodeInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeDeleteHelp)
    ]

    return entries
}

public func fakePasscodeOptionsController(context: AccountContext, index: Int, updatedSettingsName: @escaping (Int, FakePasscodeSettings) -> Void) -> ViewController {
    let statePromise = ValuePromise(FakePasscodeOptionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: FakePasscodeOptionsControllerState())
    let updateState: ((FakePasscodeOptionsControllerState) -> FakePasscodeOptionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var pushControllerImpl: ((ViewController) -> Void)?
    var popControllerImpl: (() -> Void)?

    let actionsDisposable = DisposableSet()

    let passcodeOptionsDataPromise = Promise<FakePasscodeOptionsData>()
    passcodeOptionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> (PostboxAccessChallengeData, FakePasscodeSettings) in
        let passcodeSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.fakePasscodeSettings)?.get(FakePasscodeSettingsHolder.self)?.settings[index] ?? FakePasscodeSettings.defaultSettings
        return (transaction.getAccessChallengeData(), passcodeSettings)
    }
    |> map { accessChallenge, passcodeSettings -> FakePasscodeOptionsData in
        updateState { state in
            var state = state
            state.name = passcodeSettings.name
            state.activationMessage = passcodeSettings.activationMessage
            return state
        }
        return FakePasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: passcodeSettings)
    })

    let arguments = FakePasscodeOptionsControllerArguments(account: context.account, changeName: { value in
        updateState { state in
            var state = state
            state.name = value
            return state
        }
    }, commitName: {
        updateSettings(context: context, index: index, passcodeOptionsDataPromise) { settings in
            stateValue.with({ state in
                guard let name = state.name else {
                    return settings
                }
                let newSettings = settings.withUpdatedName(name)
                updatedSettingsName(index, newSettings)
                return newSettings
            })
        }
    }, changePasscode: {
        pushFakePasscodeSetupController(context: context, pushController: pushControllerImpl, popController: popControllerImpl, challengeDataUpdate: { transaction, oldChallengeData, newPasscode, numerical in
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
        })
    }, allowLogin: { enabled in
        updateSettings(context: context, index: index, passcodeOptionsDataPromise) { settings in
            return settings.withUpdatedAllowLogin(enabled)
        }
    }, clearAfterActivation: { enabled in
        updateSettings(context: context, index: index, passcodeOptionsDataPromise) { settings in
            return settings.withUpdatedClearAfterActivation(enabled)
        }
    }, deleteOtherPasscodes: { enabled in
        updateSettings(context: context, index: index, passcodeOptionsDataPromise) { settings in
            return settings.withUpdatedDeleteOtherPasscodes(enabled)
        }
    }, activationMessage: { message in
        updateState { state in
            var state = state
            state.activationMessage = message
            return state
        }
    }, commitActivationMessage: {
        updateSettings(context: context, index: index, passcodeOptionsDataPromise) { settings in
            stateValue.with({ state in
                guard let message = state.activationMessage else {
                    return settings
                }
                return settings.withUpdatedActivationMessage(message)
            })
        }
    }, badPasscodeActivation: {
        // TODO implement
    }, smsActions: {
        // TODO implement SMS Actions screen and open it here
    }, clearCache: { enabled in
        updateSettings(context: context, index: index, passcodeOptionsDataPromise) { settings in
            return settings.withUpdatedClearCache(enabled)
        }
    }, clearProxies: { enabled in
        updateSettings(context: context, index: index, passcodeOptionsDataPromise) { settings in
            return settings.withUpdatedClearProxies(enabled)
        }
    }, accountActions: {
        // TODO implement Account Actions screen and open it here
    }, deletePasscode: {
        // TODO delete fake passcode
    })

    let accountPeerSignal = context.account.postbox.loadedPeerWithId(context.account.peerId)
    |> take(1)

    let accountAvatarSignal = accountPeerSignal |> deliverOnMainQueue |> mapToSignal { accountPeer -> Signal<(UIImage, UIImage)?, NoError> in
        let peer = EnginePeer(accountPeer)
        let peerRef = PeerReference(peer._asPeer())
        let avatarSignal = peerAvatarImage(account: context.account, peerReference: peerRef, authorOfMessage: nil, representation: peer.profileImageRepresentations.last) ?? .single(nil)

        return avatarSignal
    }

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), passcodeOptionsDataPromise.get(), accountPeerSignal, accountAvatarSignal) |> deliverOnMainQueue
        |> map { presentationData, state, optionsData, accountPeer, accountAvatar -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let title = optionsData.settings.name

            let peer = EnginePeer(accountPeer)
            let displayName = peer.compactDisplayTitle

            let avatarSize: CGFloat = 32.0
            let avatar = resizedImage(accountAvatar?.1, for: CGSize(width: avatarSize, height: avatarSize))

            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: fakePasscodeOptionsControllerEntries(presentationData: presentationData, settings: optionsData.settings, displayName: displayName, avatar: avatar), style: .blocks, emptyStateItem: nil, animateChanges: false)

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

public func pushFakePasscodeSetupController(context: AccountContext, pushController: ((ViewController) -> Void)?, popController: (() -> Void)?, challengeDataUpdate: @escaping ((AccountManagerModifier<TelegramAccountManagerTypes>, PostboxAccessChallengeData, String, Bool) -> PostboxAccessChallengeData), completed: (() -> Void)? = nil) {
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
            let _ = (context.sharedContext.accountManager.transaction({ transaction in
                let data = transaction.getAccessChallengeData()
                let updatedData = challengeDataUpdate(transaction, data, newPasscode, numerical)
                transaction.setAccessChallengeData(updatedData)
            }) |> deliverOnMainQueue).start(next: {
            }, error: { _ in
            }, completed: {
                completed?()
            })
        }
        pushController?(setupController)
    })
}

private func updateSettings(context: AccountContext, index: Int, _ optionsDataPromise: Promise<FakePasscodeOptionsData>, _ f: @escaping (FakePasscodeSettings) -> FakePasscodeSettings) {
    let _ = (optionsDataPromise.get() |> take(1)).start(next: { [weak optionsDataPromise] data in
        optionsDataPromise?.set(.single(data.withUpdatedSettings(f(data.settings))))

        let _ = updateFakePasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, index: index, { current in
            return f(current)
        }).start()
    })
}
