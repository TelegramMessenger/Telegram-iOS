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
import AccountUtils

public class ItemListControllerReactiveToPasscodeSwitch: ItemListController, ReactiveToPasscodeSwitch {
    private let onPasscodeSwitch: ((ViewController) -> Void)
    
    public init<ItemGenerationArguments>(context: AccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, onPasscodeSwitch: @escaping ((ViewController) -> Void)) {
        self.onPasscodeSwitch = onPasscodeSwitch
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(presentationData: ItemListPresentationData(presentationData), updatedPresentationData: context.sharedContext.presentationData |> map(ItemListPresentationData.init(_:)), state: state, tabBarItem: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func passcodeSwitched() {
        onPasscodeSwitch(self)
    }
}

private final class FakePasscodeOptionsControllerArguments {
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
    let accountActions: (FakePasscodeActionsAccount) -> Void
    let deletePasscode: () -> Void
    let dismissInput: () -> Void

    init(changeName: @escaping (String) -> Void, commitName: @escaping () -> Void,  changePasscode: @escaping () -> Void, allowLogin: @escaping (Bool) -> Void, clearAfterActivation: @escaping (Bool) -> Void, deleteOtherPasscodes: @escaping (Bool) -> Void, activationMessage: @escaping (String) -> Void, commitActivationMessage: @escaping () -> Void, badPasscodeActivation: @escaping () -> Void, smsActions: @escaping () -> Void, clearCache: @escaping (Bool) -> Void, clearProxies: @escaping (Bool) -> Void, accountActions: @escaping (FakePasscodeActionsAccount) -> Void, deletePasscode: @escaping () -> Void, dismissInput: @escaping () -> Void) {
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
        self.dismissInput = dismissInput
    }
}

private enum FakePasscodeOptionsTag: ItemListItemTag {
    case name
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? FakePasscodeOptionsTag, self == other {
            return true
        } else {
            return false
        }
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
    case changePasscode(PresentationTheme, String, String)
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
    case accountActions(PresentationTheme, FakePasscodeActionsAccount, Int)
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
            case let .accountActions(_, _, index):
                return 20 + Int32(index)
            case .accountsInfo:
                return 1000
            case .deletePasscode:
                return 1001
            case .deletePasscodeInfo:
                return 1002
         }
     }

    static func <(lhs: FakePasscodeOptionsEntry, rhs: FakePasscodeOptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! FakePasscodeOptionsControllerArguments
        switch self {
            case let .changeName(_, title, name):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: name, placeholder: title, type: .regular(capitalization: true, autocorrection: false), clearType: .onFocus, tag: FakePasscodeOptionsTag.name, sectionId: self.section, textUpdated: { value in
                    arguments.changeName(value)
                }, updatedFocus: { focused in
                    if !focused {
                        arguments.commitName()
                    }
                }, action: {
                    arguments.dismissInput()
                })
            case let .changePasscode(_, text, passcode):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, titleColor: .accent, label: passcode, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
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
            case let .accountActions(_, account, _):
                return ItemListDisclosureItem(presentationData: presentationData, icon: account.avatar, title: account.displayName, label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.accountActions(account)
                })
            case let .deletePasscode(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.deletePasscode()
                })
        }
    }
}

private struct FakePasscodeOptionsData: Equatable {
    let settings: FakePasscodeSettings

    func withUpdatedSettings(_ settings: FakePasscodeSettings) -> FakePasscodeOptionsData {
        return FakePasscodeOptionsData(settings: settings)
    }
}

private struct FakePasscodeOptionsControllerState: Equatable {
    var name: String?
    var activationMessage: String?
}

internal struct FakePasscodeActionsAccount: Equatable {
    let peerId: PeerId
    let recordId: AccountRecordId
    let displayName: String
    let avatar: UIImage?
}

private func fakePasscodeOptionsControllerEntries(presentationData: PresentationData, settings: FakePasscodeSettings, accounts: [FakePasscodeActionsAccount]) -> [FakePasscodeOptionsEntry] {
    var entries: [FakePasscodeOptionsEntry] = [
        .changeName(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChangeName, settings.name),
        .changePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeChange, settings.passcode ?? ""),
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
        .accountsHeader(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAccountsTitle.uppercased()),
    ]
    
    for (index, account) in accounts.enumerated() {
        entries.append(.accountActions(presentationData.theme, account, index))
    }
    
    entries.append(contentsOf: [
        .accountsInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeAccountsHelp),
        .deletePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeDelete),
        .deletePasscodeInfo(presentationData.theme, presentationData.strings.PasscodeSettings_FakePasscodeDeleteHelp)
    ])

    return entries
}

public func fakePasscodeOptionsController(context: AccountContext, uuid: UUID, updateParentDataPromise: @escaping (FakePasscodeSettingsHolder) -> Void) -> ViewController {
    let statePromise = ValuePromise(FakePasscodeOptionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: FakePasscodeOptionsControllerState())
    let updateState: ((FakePasscodeOptionsControllerState) -> FakePasscodeOptionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }

    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var popControllerImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var errorImpl: ((FakePasscodeOptionsTag) -> Void)?

    let actionsDisposable = DisposableSet()

    let passcodeOptionsDataPromise = Promise<FakePasscodeOptionsData>()
    passcodeOptionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> FakePasscodeSettings in
        let passcodeSettings = FakePasscodeSettingsHolder(transaction).settings.first(where: { $0.uuid == uuid })!
        return passcodeSettings
    }
    |> map { passcodeSettings -> FakePasscodeOptionsData in
        updateState { state in
            var state = state
            state.name = passcodeSettings.name
            state.activationMessage = passcodeSettings.activationMessage
            return state
        }
        return FakePasscodeOptionsData(settings: passcodeSettings)
    })

    let arguments = FakePasscodeOptionsControllerArguments(changeName: { value in
        updateState { state in
            var state = state
            state.name = value
            return state
        }
    }, commitName: {
        updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
            stateValue.with({ state in
                guard let name = state.name, !name.isEmpty else {
                    errorImpl?(.name)
                    return settings
                }
                let newSettings = settings.withUpdatedName(name)
                return newSettings
            })
        }
    }, changePasscode: {
        pushFakePasscodeSetupController(context: context, currentFakePasscodeUuid: uuid, pushController: pushControllerImpl, popController: popControllerImpl, challengeDataUpdate: { transaction, newPasscode, numerical in
            updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
                let newPasscodeData = PostboxAccessChallengeData(passcode: newPasscode, numerical: numerical)
                let newSettings = settings.withUpdatedPasscode(newPasscodeData.normalizedString())
                return newSettings
            }
        }, completed: {
            popControllerImpl?()
        })
    }, allowLogin: { enabled in
        updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
            return settings.withUpdatedAllowLogin(enabled)
        }
    }, clearAfterActivation: { enabled in
        updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
            return settings.withUpdatedClearAfterActivation(enabled)
        }
    }, deleteOtherPasscodes: { enabled in
        updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
            return settings.withUpdatedDeleteOtherPasscodes(enabled)
        }
    }, activationMessage: { message in
        updateState { state in
            var state = state
            state.activationMessage = message
            return state
        }
    }, commitActivationMessage: {
        updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
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
        updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
            return settings.withUpdatedClearCache(enabled)
        }
    }, clearProxies: { enabled in
        updateSettings(context: context, passcodeOptionsDataPromise, updateParentDataPromise) { settings in
            return settings.withUpdatedClearProxies(enabled)
        }
    }, accountActions: { account in
        let controller = fakePasscodeAccountActionsController(context: context, uuid: uuid, account: account)
        pushControllerImpl?(controller)
    }, deletePasscode: {
        let actionSheet = ActionSheetController(presentationData: presentationData)

        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                    popControllerImpl?()
                    let _ = updateFakePasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { holder in
                        let updatedHolder = holder.withDeletedSettingsItem(uuid)
                        updateParentDataPromise(updatedHolder)
                        return updatedHolder
                    }).start()
                    actionSheet?.dismissAnimated()
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    }, dismissInput: {
        dismissInputImpl?()
    })

    let accountsSignal = combineLatest(context.sharedContext.presentationData, activeAccountsAndPeers(context: context, includePrimary: true)) |> mapToSignal { presentationData, accountsAndPeers -> Signal<[FakePasscodeActionsAccount], NoError> in
        let (_, accounts) = accountsAndPeers
        let avatarSize = CGSize(width: 28.0, height: 28.0)
        let avatarSignals = accounts.map { account in
            return peerAvatarCompleteImage(account: account.0.account, peer: account.1, size: avatarSize)
        }
        return combineLatest(avatarSignals) |> take(1) |> map { avatars in
            return avatars.enumerated().map { (index, avatar) in
                let account = accounts[index]
                return FakePasscodeActionsAccount(peerId: account.0.account.peerId, recordId: account.0.account.id, displayName: account.1.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), avatar: avatar)
            }
        }
    }

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), passcodeOptionsDataPromise.get(), accountsSignal) |> deliverOnMainQueue
        |> map { presentationData, state, optionsData, accounts -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let title = optionsData.settings.name

            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: fakePasscodeOptionsControllerEntries(presentationData: presentationData, settings: optionsData.settings, accounts: accounts), style: .blocks, emptyStateItem: nil, animateChanges: false)

            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }

    let controller = ItemListControllerReactiveToPasscodeSwitch(context: context, state: signal, onPasscodeSwitch: { controller in
        controller.dismiss(animated: false)
    })
    presentControllerImpl = { [weak controller] c in
        if let controller = controller {
            controller.present(c, in: .window(.root))
        }
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    popControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    let hapticFeedback = HapticFeedback()
    errorImpl = { [weak controller] targetTag in
        hapticFeedback.error()
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode, let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                itemNode.animateError()
            }
        }
    }
    return controller
}

public func pushFakePasscodeSetupController(context: AccountContext, currentFakePasscodeUuid: UUID?, pushController: ((ViewController) -> Void)?, popController: (() -> Void)?, challengeDataUpdate: @escaping ((AccountManagerModifier<TelegramAccountManagerTypes>, String, Bool) -> Void), completed: (() -> Void)? = nil) {
    let _ = (context.sharedContext.accountManager.transaction({ transaction -> (PasscodeEntryFieldType, [String?]) in
        let existingFakePasscodes = FakePasscodeSettingsHolder(transaction).settings.filter({ $0.uuid != currentFakePasscodeUuid }).map({ $0.passcode })
        
        let data = transaction.getAccessChallengeData()
        switch data {
            case .none:
                assertionFailure()
                return (.alphanumeric, [])
            case .numericalPassword(let passcode):
                return (passcode.count == 6 ? .digits6 : .digits4, existingFakePasscodes + [passcode])
            case .plaintextPassword(let passcode):
                return (.alphanumeric, existingFakePasscodes + [passcode])
        }
    })
    |> deliverOnMainQueue).start(next: { (fieldType, existingPasscodes) in
        let setupController = PasscodeSetupController(context: context, mode: .setup(change: true, allowChangeType: false, fieldType))
        setupController.validate = { newPasscode in
            if existingPasscodes.contains(newPasscode) {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                return presentationData.strings.PasscodeSettings_PasscodeInUse
            }
            return nil
        }
        setupController.complete = { newPasscode, numerical in
            let _ = (context.sharedContext.accountManager.transaction({ transaction in
                challengeDataUpdate(transaction, newPasscode, numerical)
            }) |> deliverOnMainQueue).start(next: {
            }, error: { _ in
            }, completed: {
                completed?()
            })
        }
        pushController?(setupController)
    })
}

private func updateSettings(context: AccountContext, _ optionsDataPromise: Promise<FakePasscodeOptionsData>, _ updateParentDataPromise: @escaping (FakePasscodeSettingsHolder) -> Void, _ f: @escaping (FakePasscodeSettings) -> FakePasscodeSettings) {
    let _ = (optionsDataPromise.get() |> take(1)).start(next: { [weak optionsDataPromise] data in
        let updatedSettings = f(data.settings)
        optionsDataPromise?.set(.single(data.withUpdatedSettings(updatedSettings)))

        let _ = updateFakePasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { holder in
            let updatedHolder = holder.withUpdatedSettingsItem(updatedSettings)
            updateParentDataPromise(updatedHolder)
            return updatedHolder
        }).start()
    })
}
