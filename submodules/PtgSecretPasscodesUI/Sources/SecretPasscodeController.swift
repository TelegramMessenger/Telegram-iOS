import Foundation
import UIKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import SwiftSignalKit
import Display
import ItemListUI
import TelegramPresentationData
import AccountContext
import SettingsUI
import PasscodeUI
import ItemListPeerActionItem
import ItemListPeerItem
import TelegramStringFormatting
import AccountUtils
import UndoUI
import TelegramIntents
import WidgetKit
import GeneratedSources
import PresentationDataUtils
import PtgSecretPasscodes

private final class SecretPasscodeControllerArguments {
    let changePasscode: () -> Void
    let changeTimeout: () -> Void
    let deletePasscode: () -> Void
    let addAccount: () -> Void
    let removeAccount: (AccountRecordId) -> Void
    let addSecretChats: () -> Void
    let removeSecretChat: (PtgSecretChatId) -> Void
    
    init(changePasscode: @escaping () -> Void, changeTimeout: @escaping () -> Void, deletePasscode: @escaping () -> Void, addAccount: @escaping () -> Void, removeAccount: @escaping (AccountRecordId) -> Void, addSecretChats: @escaping () -> Void, removeSecretChat: @escaping (PtgSecretChatId) -> Void) {
        self.changePasscode = changePasscode
        self.changeTimeout = changeTimeout
        self.deletePasscode = deletePasscode
        self.addAccount = addAccount
        self.removeAccount = removeAccount
        self.addSecretChats = addSecretChats
        self.removeSecretChat = removeSecretChat
    }
}

private enum SecretPasscodeControllerSection: Int32 {
    case state
    case timeout
    case accounts
    case secretChats
    case changePasscode
    case delete
}

private enum SecretPasscodeControllerEntry: ItemListNodeEntry {
    case state(String)
    case timeout(String, String)
    case accountsHeader(String)
    case accountsAdd(String)
    case account(Int32, PresentationDateTimeFormat, PresentationPersonNameOrder, AccountEntry)
    case secretChatsHeader(String)
    case secretChatsAdd(String)
    case secretChat(Int32, PresentationDateTimeFormat, PresentationPersonNameOrder, SecretChatEntry)
    case changePasscode(String)
    case delete(String)
    
    var section: ItemListSectionId {
        switch self {
        case .state:
            return SecretPasscodeControllerSection.state.rawValue
        case .timeout:
            return SecretPasscodeControllerSection.timeout.rawValue
        case .accountsHeader, .accountsAdd, .account:
            return SecretPasscodeControllerSection.accounts.rawValue
        case .secretChatsHeader, .secretChatsAdd, .secretChat:
            return SecretPasscodeControllerSection.secretChats.rawValue
        case .changePasscode:
            return SecretPasscodeControllerSection.changePasscode.rawValue
        case .delete:
            return SecretPasscodeControllerSection.delete.rawValue
        }
    }
    
    enum StableId: Hashable {
        case state
        case timeout
        case accountsHeader
        case accountsAdd
        case account(AccountRecordId)
        case secretChatsHeader
        case secretChatsAdd
        case secretChat(PtgSecretChatId)
        case changePasscode
        case delete
    }
    
    var stableId: StableId {
        switch self {
        case .state:
            return .state
        case .timeout:
            return .timeout
        case .accountsHeader:
            return .accountsHeader
        case .accountsAdd:
            return .accountsAdd
        case let .account(_, _, _, entry):
            return .account(entry.accountId)
        case .secretChatsHeader:
            return .secretChatsHeader
        case .secretChatsAdd:
            return .secretChatsAdd
        case let .secretChat(_, _, _, entry):
            return .secretChat(entry.secretChatId)
        case .changePasscode:
            return .changePasscode
        case .delete:
            return .delete
        }
    }
    
    static func <(lhs: SecretPasscodeControllerEntry, rhs: SecretPasscodeControllerEntry) -> Bool {
        if lhs.section != rhs.section {
            return lhs.section < rhs.section
        }
        
        switch lhs {
        case .accountsHeader, .secretChatsHeader:
            return true
        case .accountsAdd, .secretChatsAdd:
            switch rhs {
            case .accountsHeader, .secretChatsHeader:
                return false
            case .account, .secretChat:
                return true
            default:
                assertionFailure()
                return false
            }
        case let .account(lhsIndex, _, _, _), let .secretChat(lhsIndex, _, _, _):
            switch rhs {
            case let .account(rhsIndex, _, _, _), let .secretChat(rhsIndex, _, _, _):
                return lhsIndex < rhsIndex
            default:
                return false
            }
        default:
            assertionFailure()
            return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SecretPasscodeControllerArguments
        switch self {
        case let .state(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .timeout(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.changeTimeout()
            })
        case let .accountsHeader(text), let .secretChatsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .accountsAdd(title):
            return ItemListPeerActionItem(presentationData: presentationData, icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: presentationData.theme.list.itemAccentColor), title: title, sectionId: self.section, action: {
                    arguments.addAccount()
                })
        case let .account(_, dateTimeFormat, nameDisplayOrder, entry):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: entry._peerItemContext.context, peer: entry.peer, nameStyle: .plain, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: nil), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in
                arguments.removeAccount(entry.accountId)
            })
        case let .secretChatsAdd(title):
            return ItemListPeerActionItem(presentationData: presentationData, icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Add"), color: presentationData.theme.list.itemAccentColor), title: title, sectionId: self.section, action: {
                    arguments.addSecretChats()
                })
        case let .secretChat(_, dateTimeFormat, nameDisplayOrder, entry):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: entry._peerItemContext.context, peer: entry.peer.chatMainPeer!, nameColor: .secret, presence: nil, text: .text(entry.accountName, .secondary), label: .text(entry.lastActivityOrStatus, .standard), editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: nil), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in
                arguments.removeSecretChat(entry.secretChatId)
            })
        case let .changePasscode(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.changePasscode()
            })
        case let .delete(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.deletePasscode()
            })
        }
    }
}

private struct SecretPasscodeControllerState: Equatable {
    let settings: PtgSecretPasscode
    
    func withUpdated(settings: PtgSecretPasscode) -> SecretPasscodeControllerState {
        return SecretPasscodeControllerState(settings: settings)
    }
}

private func secretPasscodeControllerEntries(presentationData: PresentationData, state: SecretPasscodeControllerState, accountEntries: [AccountEntry], secretChatEntries: [SecretChatEntry]) -> [SecretPasscodeControllerEntry] {
    var entries: [SecretPasscodeControllerEntry] = []
    
    entries.append(.state(state.settings.active ? presentationData.strings.SecretPasscodeStatus_Revealed : presentationData.strings.SecretPasscodeStatus_Hidden))
    
    entries.append(.timeout(presentationData.strings.SecretPasscodeSettings_AutoHide, autolockStringForTimeout(strings: presentationData.strings, timeout: state.settings.timeout)))
    
    entries.append(.accountsHeader(presentationData.strings.SecretPasscodeSettings_AccountsHeader.uppercased()))
    entries.append(.accountsAdd(presentationData.strings.SecretPasscodeSettings_AddAccount))
    
    for (index, value) in accountEntries.enumerated() {
        entries.append(.account(Int32(index), presentationData.dateTimeFormat, presentationData.nameDisplayOrder, value))
    }
    
    entries.append(.secretChatsHeader(presentationData.strings.SecretPasscodeSettings_SecretChatsHeader.uppercased()))
    entries.append(.secretChatsAdd(presentationData.strings.SecretPasscodeSettings_AddSecretChats))
    
    for (index, value) in secretChatEntries.enumerated() {
        entries.append(.secretChat(Int32(index), presentationData.dateTimeFormat, presentationData.nameDisplayOrder, value))
    }
    
    entries.append(.changePasscode(presentationData.strings.PasscodeSettings_ChangePasscode))
    
    entries.append(.delete(presentationData.strings.SecretPasscodeSettings_DeleteSecretPasscode))
    
    return entries
}

struct EquatableAccountContext: Equatable {
    let context: AccountContext
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.context.account.id == rhs.context.account.id
    }
}

private struct AccountEntry: Equatable {
    let accountId: AccountRecordId
    let peer: EnginePeer
    let _peerItemContext: EquatableAccountContext // note that account may be hidden, use only for ItemListPeerItem
}

private struct SecretChatEntry: Equatable {
    let secretChatId: PtgSecretChatId
    let peer: EngineRenderedPeer
    let _peerItemContext: EquatableAccountContext // note that account may be hidden, use only for ItemListPeerItem
    let accountName: String
    let lastActivityOrStatus: String
}

private func _getAccountsIncludingHiddenOnes(sharedContext: SharedAccountContext) -> Signal<[(AccountContext, EnginePeer)], NoError> {
    return sharedContext.activeAccountContexts
    |> mapToSignal { activeAccountContexts in
        let contexts = activeAccountContexts.accounts.map({ $0.1 }) + activeAccountContexts.inactiveAccounts.map({ $0.1 })
        return combineLatest(contexts.map { context in
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer in
                return peer.flatMap { (context, $0) }
            }
        })
        |> map { accounts in
            return accounts.compactMap { $0 }
        }
    }
}

private func getAccountEntries(sharedContext: SharedAccountContext, accountIds: Set<AccountRecordId>) -> Signal<[AccountEntry], NoError> {
    return _getAccountsIncludingHiddenOnes(sharedContext: sharedContext)
    |> map { accountsAndPeers in
        return accountsAndPeers.filter {
            return accountIds.contains($0.0.account.id)
        }
        .map {
            return AccountEntry(accountId: $0.0.account.id, peer: $0.1, _peerItemContext: EquatableAccountContext(context: $0.0))
        }
    }
}

private func getSecretChatEntries(sharedContext: SharedAccountContext, secretChats: Set<PtgSecretChatId>, presentationData: PresentationData) -> Signal<[SecretChatEntry], NoError> {
    return _getAccountsIncludingHiddenOnes(sharedContext: sharedContext)
    |> mapToSignal { accountsAndPeers in
        let accounts = Dictionary(uniqueKeysWithValues: accountsAndPeers.map { ($0.0.account.id, ($0.0, $0.1)) })
        return combineLatest(secretChats.filter({ accounts[$0.accountId] != nil }).map { secretChatId -> Signal<(PtgSecretChatId, EngineRenderedPeer?, EngineChatList.Item.Index?), NoError> in
            let context = accounts[secretChatId.accountId]!.0
            return combineLatest(
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.RenderedPeer(id: secretChatId.peerId)),
                context.engine.data.get(TelegramEngine.EngineData.Item.Messages.ChatListIndex(id: secretChatId.peerId)))
            |> map { (secretChatId, $0, $1) }
        })
        |> map { chatPeersAndIndices in
            return chatPeersAndIndices.compactMap { (secretChatId, peer, index) -> (PtgSecretChatId, EngineRenderedPeer, ChatListIndex?)? in
                guard let peer = peer else {
                    return nil
                }
                var chatListIndex: ChatListIndex?
                if case let .chatList(index) = index {
                    chatListIndex = index
                }
                return (secretChatId, peer, chatListIndex)
            }
            .sorted {
                return ($1.2 ?? .absoluteLowerBound) < ($0.2 ?? .absoluteLowerBound)
            }
            .map { (secretChatId, peer, index) in
                let (peerItemContext, accountPeer) = accounts[secretChatId.accountId]!
                let accountName = accountPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                
                var lastActivityOrStatus: String = ""
                if let index = index {
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    lastActivityOrStatus = stringForRelativeTimestamp(strings: presentationData.strings, relativeTimestamp: index.messageIndex.timestamp, relativeTo: timestamp, dateTimeFormat: presentationData.dateTimeFormat)
                } else if case let .secretChat(secretChat) = peer.peer, secretChat.embeddedState == .terminated {
                    lastActivityOrStatus = presentationData.strings.SecretPasscode_SecretChatDeleted
                }
                
                return SecretChatEntry(secretChatId: secretChatId, peer: peer, _peerItemContext: EquatableAccountContext(context: peerItemContext), accountName: accountName, lastActivityOrStatus: lastActivityOrStatus)
            }
        }
    }
}

public func secretPasscodeController(context: AccountContext, passcode: String) -> ViewController {
    let statePromise = Promise<SecretPasscodeControllerState>()
    statePromise.set(context.sharedContext.ptgSecretPasscodes
    |> take(1)
    |> map { ptgSecretPasscodes in
        let secretPasscode = ptgSecretPasscodes.secretPasscodes.first(where: { $0.passcode == passcode })!
        return SecretPasscodeControllerState(settings: secretPasscode)
    })
    
    let updateState: (@escaping (SecretPasscodeControllerState) -> SecretPasscodeControllerState) -> Void = { f in
        let _ = (statePromise.get()
        |> take(1)).start(next: { [weak statePromise] state in
            statePromise?.set(.single(f(state)))
        })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var popControllerImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    var presentControllerInCurrentImpl: ((ViewController) -> Void)?
    var popToControllerImpl: (() -> Void)?
    
    let hapticFeedback = HapticFeedback()
    
    let arguments = SecretPasscodeControllerArguments(changePasscode: {
        let _ = (combineLatest(context.sharedContext.ptgSecretPasscodes, statePromise.get())
        |> take(1)
        |> deliverOnMainQueue).start(next: { ptgSecretPasscodes, state in
            let controller = PasscodeSetupController(context: context, mode: .secretSetup(.digits6))
            
            controller.validate = { [weak controller] newPasscode in
                guard let passcodeAttemptAccounter = context.sharedContext.passcodeAttemptAccounter else {
                    return ""
                }
                
                if let waitTime = passcodeAttemptAccounter.preAttempt() {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    controller?.present(UndoOverlayController(presentationData: presentationData, content: .banned(text: passcodeAttemptWaitString(strings: presentationData.strings, waitTime: waitTime)), elevatedLayout: false, action: { _ in return false }), in: .current)
                    return ""
                }
                
                if ptgSecretPasscodes.secretPasscodes.contains(where: { $0.passcode == newPasscode }) && newPasscode != state.settings.passcode {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    return presentationData.strings.PasscodeSettings_PasscodeInUse
                }
                
                if newPasscode != state.settings.passcode {
                    passcodeAttemptAccounter.attemptMissed()
                }
                
                return nil
            }
            
            controller.complete = { newPasscode, numerical in
                updateState { state in
                    let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                        return current.withUpdatedItem(passcode: state.settings.passcode) { sp in
                            return sp.withUpdated(passcode: newPasscode)
                        }
                    }).start()
                    
                    return state.withUpdated(settings: state.settings.withUpdated(passcode: newPasscode))
                }
                
                popControllerImpl?()
            }
            
            pushControllerImpl?(controller)
        })
    }, changeTimeout: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        let setAction: (Int32?) -> Void = { value in
            updateState { state in
                let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                    return current.withUpdatedItem(passcode: state.settings.passcode) { sp in
                        return sp.withUpdated(timeout: value)
                    }
                }).start()
                
                return state.withUpdated(settings: state.settings.withUpdated(timeout: value))
            }
        }
        
        let values: [Int32] = [/*0, */10, 1 * 60, 5 * 60, 1 * 60 * 60, 5 * 60 * 60]
        
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
    }, deletePasscode: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.SecretPasscodeSettings_DeleteSecretPasscodeNotice),
                ActionSheetButtonItem(title: presentationData.strings.SecretPasscodeSettings_DeleteSecretPasscode, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    let _ = (statePromise.get()
                    |> take(1)).start(next: { state in
                        let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                            let updated = current.secretPasscodes.filter { $0.passcode != state.settings.passcode }
                            return PtgSecretPasscodes(secretPasscodes: updated)
                        }).start()
                    })
                    
                    popControllerImpl?()
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        
        presentControllerImpl?(actionSheet, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, addAccount: {
        let _ = (combineLatest(activeAccountsAndPeers(context: context, includePrimary: true), context.sharedContext.allHidableAccountIds, statePromise.get())
        |> take(1)
        |> deliverOnMainQueue).start(next: { accountsAndPeers, allHidableAccountIds, state in
            // don't need hidden accounts here
            let notIncludedAccounts = accountsAndPeers.1.filter({ (context, _, _) in
                return !allHidableAccountIds.contains(context.account.id)
            })
            let notIncludedAccountsInThisSecretPasscode = accountsAndPeers.1.filter({ (context, _, _) in
                return !state.settings.accountIds.contains(context.account.id)
            })
            if notIncludedAccountsInThisSecretPasscode.count > 1 {
                var accountSelectionCompleted: ((AccountContext) -> Void)?
                
                let accountsController = accountSelectionController(context: context, areItemsDisclosable: false, excludeAccountIds: state.settings.accountIds, accountSelected: { selectedContext in
                    accountSelectionCompleted?(selectedContext)
                })
                
                accountSelectionCompleted = { [weak accountsController] selectedContext in
                    if notIncludedAccounts.count == 1 && selectedContext.account.id == notIncludedAccounts.first?.0.account.id {
                        accountsController?.dismiss()
                        presentWarningAtLeastOneAccountMustRemainUnhidden()
                        return
                    }
                    
                    updateState { state in
                        let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                            return current.withUpdatedItem(passcode: state.settings.passcode) { sp in
                                return sp
                                    .withUpdated(accountIds: sp.accountIds.union([selectedContext.account.id]))
                                    .withUpdated(secretChats: sp.secretChats.filter({ $0.accountId != selectedContext.account.id }))
                            }
                        }).start(completed: {
                            if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
                                WidgetCenter.shared.reloadAllTimelines()
                            }
                        })
                        
                        return state.withUpdated(settings: state.settings
                            .withUpdated(accountIds: state.settings.accountIds.union([selectedContext.account.id]))
                            .withUpdated(secretChats: state.settings.secretChats.filter({ $0.accountId != selectedContext.account.id }))
                        )
                    }
                    
                    let _ = (updateIntentsSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                        if current.account == selectedContext.account.peerId {
                            return current.withUpdatedAccount(nil)
                        } else {
                            return current
                        }
                    }).start()
                    
                    deleteAllSendMessageIntents()
                    
                    context.sharedContext.applicationBindings.clearAllNotifications()
                    
                    // reset imported contacts that are not in contact list, it does not delete existing contacts
                    let _ = selectedContext.engine.contacts.resetSavedContacts().start()
                    
                    let _ = (areThereAnyWidgetsContainingChatsFromAccount(id: selectedContext.account.id)
                    |> deliverOnMainQueue).start(next: { result in
                        if result {
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let alert = textAlertController(context: context, title: nil, text: presentationData.strings.SecretPasscode_SomeWidgetContainsChatsFromJustAddedAccount, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                            presentControllerImpl?(alert, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                        }
                    })
                    
                    accountsController?.dismiss()
                }
                
                presentControllerImpl?(accountsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else {
                presentWarningAtLeastOneAccountMustRemainUnhidden()
            }
            
            func presentWarningAtLeastOneAccountMustRemainUnhidden() {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerInCurrentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.SecretPasscodeSettings_AtLeastOneAccountMustRemainUnhidden, timeout: nil), elevatedLayout: false, action: { _ in return false }))
                hapticFeedback.warning()
            }
        })
    }, removeAccount: { accountId in
        updateState { state in
            let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                return current.withUpdatedItem(passcode: state.settings.passcode) { sp in
                    return sp.withUpdated(accountIds: sp.accountIds.filter({ $0 != accountId }))
                }
            }).start()
            
            return state.withUpdated(settings: state.settings.withUpdated(accountIds: state.settings.accountIds.filter({ $0 != accountId })))
        }
    }, addSecretChats: {
        let openSecretChatsSelection: (AccountContext, ViewController?) -> Void = { context, pushToController in
            let _ = (combineLatest(statePromise.get(), context.engine.peers.currentChatListFilters())
            |> take(1)
            |> deliverOnMainQueue).start(next: { state, chatListFilters in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let selectedChats = Set(state.settings.secretChats.filter({ $0.accountId == context.account.id }).map({ $0.peerId }))
                let inactiveSecretChatPeerIds = context.inactiveSecretChatPeerIds
                |> map { inactiveSecretChatPeerIds in
                    return inactiveSecretChatPeerIds.subtracting(selectedChats)
                }
                
                // this filter enables selection of archived chats
                let chatListFilter: ChatListFilter = .filter(id: -1, title: "", emoticon: nil, data: ChatListFilterData(isShared: false, hasSharedLinks: false, categories: [.contacts, .nonContacts], excludeMuted: false, excludeRead: false, excludeArchived: false, includePeers: ChatListFilterIncludePeers(), excludePeers: []))
                
                let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(title: presentationData.strings.SecretPasscode_SecretChatsSelectionTitle, searchPlaceholder: presentationData.strings.ChatListFilter_AddChatsTitle, selectedChats: selectedChats, additionalCategories: nil, chatListFilters: chatListFilters, chatListNodeFilter: chatListFilter, chatListNodePeersFilter: [.excludeUsers, .excludeGroups, .excludeChannels, .excludeBots, .excludeSavedMessages], omitTokenList: true, inactiveSecretChatPeerIds: inactiveSecretChatPeerIds)), options: [], filters: [], alwaysEnabled: true))

                controller.isSensitiveUI = true

                if let pushToController = pushToController {
                    (pushToController.navigationController as? NavigationController)?.pushViewController(controller)
                } else {
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }

                let _ = (controller.result
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak controller, weak pushToController] result in
                    guard case let .result(peerIds, _) = result else {
                        controller?.dismiss()
                        return
                    }

                    var secretChats = state.settings.secretChats.filter({ $0.accountId != context.account.id })
                    
                    for peerId in peerIds {
                        if case let .peer(id) = peerId, id.namespace == Namespaces.Peer.SecretChat {
                            secretChats.insert(PtgSecretChatId(accountId: context.account.id, peerId: id))
                        }
                    }

                    updateState { state in
                        let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                            return current.withUpdatedItem(passcode: state.settings.passcode) { sp in
                                return sp.withUpdated(secretChats: secretChats)
                            }
                        }).start()

                        return state.withUpdated(settings: state.settings.withUpdated(secretChats: secretChats))
                    }

                    let addedPeerIds = Set(secretChats.filter({ $0.accountId == context.account.id }).map({ $0.peerId })).subtracting(selectedChats)
                    if !addedPeerIds.isEmpty {
                        context.sharedContext.applicationBindings.clearPeerNotifications(addedPeerIds)
                    }
                    
                    if let _ = pushToController {
                        popToControllerImpl?()
                    } else {
                        controller?.dismiss()
                    }
                })
            })
        }
        
        let _ = (combineLatest(activeAccountsAndPeers(context: context, includePrimary: true), statePromise.get(), _getAccountsIncludingHiddenOnes(sharedContext: context.sharedContext))
        |> take(1)
        |> deliverOnMainQueue).start(next: { accountsAndPeers, state, _accountsIncludingHiddenOnes in
            let existingKnownAccountIds = state.settings.accountIds.intersection(_accountsIncludingHiddenOnes.map({ $0.0.account.id })).union(accountsAndPeers.1.map({ $0.0.account.id }))
            
            if existingKnownAccountIds.count > 1 {
                var accountSelectionCompleted: ((AccountContext) -> Void)?
                
                let accountsController = accountSelectionController(context: context, areItemsDisclosable: true, excludeAccountIds: state.settings.accountIds, accountSelected: { selectedContext in
                    accountSelectionCompleted?(selectedContext)
                })
                
                accountSelectionCompleted = { [weak accountsController] selectedContext in
                    openSecretChatsSelection(selectedContext, accountsController)
                }
                
                presentControllerImpl?(accountsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else {
                openSecretChatsSelection(accountsAndPeers.1.first!.0, nil)
            }
        })
    }, removeSecretChat: { secretChatId in
        updateState { state in
            let _ = updatePtgSecretPasscodes(context.sharedContext.accountManager, { current in
                return current.withUpdatedItem(passcode: state.settings.passcode) { sp in
                    return sp.withUpdated(secretChats: sp.secretChats.filter({ $0 != secretChatId }))
                }
            }).start()
            
            return state.withUpdated(settings: state.settings.withUpdated(secretChats: state.settings.secretChats.filter({ $0 != secretChatId })))
        }
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> mapToSignal { presentationData, state in
        return combineLatest(.single(presentationData), .single(state), getAccountEntries(sharedContext: context.sharedContext, accountIds: state.settings.accountIds), getSecretChatEntries(sharedContext: context.sharedContext, secretChats: state.settings.secretChats, presentationData: presentationData))
    }
    |> deliverOnMainQueue
    |> map { presentationData, state, accountEntries, secretChatEntries -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SecretPasscodeSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: secretPasscodeControllerEntries(presentationData: presentationData, state: state, accountEntries: accountEntries, secretChatEntries: secretChatEntries), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    
    popControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    
    presentControllerImpl = { [weak controller] c, p in
        controller?.present(c, in: .window(.root), with: p)
    }
    
    presentControllerInCurrentImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    
    popToControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popToViewController(controller!, animated: true)
    }
    
    controller.isSensitiveUI = true
    
    controller.tag = "SecretPasscodeController"
    
    return controller
}

extension ItemListController {
    private static var tagKey: Int?
    
    public var tag: String? {
        get {
            return objc_getAssociatedObject(self, &Self.tagKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &Self.tagKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension PtgSecretPasscode {
    public init(passcode: String, active: Bool) {
        self.init(passcode: passcode, active: active, timeout: 5 * 60, accountIds: [], secretChats: [])
    }
    
    public func withUpdated(passcode: String) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: passcode, active: self.active, timeout: self.timeout, accountIds: self.accountIds, secretChats: self.secretChats)
    }
    
    public func withUpdated(timeout: Int32?) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: self.active, timeout: timeout, accountIds: self.accountIds, secretChats: self.secretChats)
    }
    
    public func withUpdated(accountIds: Set<AccountRecordId>) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: self.active, timeout: self.timeout, accountIds: accountIds, secretChats: self.secretChats)
    }
    
    public func withUpdated(secretChats: Set<PtgSecretChatId>) -> PtgSecretPasscode {
        return PtgSecretPasscode(passcode: self.passcode, active: self.active, timeout: self.timeout, accountIds: self.accountIds, secretChats: secretChats)
    }
}

extension PtgSecretPasscodes {
    public func withUpdatedItem(passcode: String, _ f: (PtgSecretPasscode) -> PtgSecretPasscode) -> PtgSecretPasscodes {
        if let ind = self.secretPasscodes.firstIndex(where: { $0.passcode == passcode }) {
            var updated = self.secretPasscodes
            updated[ind] = f(self.secretPasscodes[ind])
            return PtgSecretPasscodes(secretPasscodes: updated)
        }
        return self
    }
    
    public func activeSecretChatPeerIds(accountId: AccountRecordId) -> Set<PeerId> {
        var result = Set<PeerId>()
        for secretPasscode in self.secretPasscodes {
            if secretPasscode.active {
                for secretChat in secretPasscode.secretChats {
                    if secretChat.accountId == accountId {
                        result.insert(secretChat.peerId)
                    }
                }
            }
        }
        return result
    }
    
    public func inactiveSecretChatPeerIdsForAllAccounts() -> Set<PeerId> {
        var active = Set<PeerId>()
        var inactive = Set<PeerId>()
        for secretPasscode in self.secretPasscodes {
            for secretChat in secretPasscode.secretChats {
                if secretPasscode.active {
                    active.insert(secretChat.peerId)
                } else {
                    inactive.insert(secretChat.peerId)
                }
            }
        }
        return inactive.subtracting(active)
    }
    
    public func allSecretChatPeerIdsForAllAccounts() -> Set<PeerId> {
        var result = Set<PeerId>()
        for secretPasscode in self.secretPasscodes {
            for secretChat in secretPasscode.secretChats {
                result.insert(secretChat.peerId)
            }
        }
        return result
    }
}

public func passcodeAttemptWaitString(strings: PresentationStrings, waitTime: Int32) -> String {
    let timeString = timeIntervalString(strings: strings, value: waitTime, usage: .afterTime)
    return strings.PasscodeAttempts_TryAgainIn(timeString).string.replacingOccurrences(of: #"\.\.$"#, with: ".", options: .regularExpression)
}

public func hideAllSecrets(accountManager: AccountManager<TelegramAccountManagerTypes>) {
    let _ = updatePtgSecretPasscodes(accountManager, { current in
        let updated = current.secretPasscodes.map { $0.withUpdated(active: false) }
        return PtgSecretPasscodes(secretPasscodes: updated)
    }).start()
}

private func areThereAnyWidgetsContainingChatsFromAccount(id accountId: AccountRecordId) -> Signal<Bool, NoError> {
    if #available(iOSApplicationExtension 14.0, iOS 14.0, *) {
        return Signal { subscriber in
            WidgetCenter.shared.getCurrentConfigurations { result in
                func friendAccountId(_ item: Friend) -> AccountRecordId? {
                    guard let identifier = item.identifier else {
                        return nil
                    }
                    guard let index = identifier.firstIndex(of: ":") else {
                        return nil
                    }
                    guard let accountIdValue = Int64(identifier[identifier.startIndex ..< index]) else {
                        return nil
                    }
                    return AccountRecordId(rawValue: accountIdValue)
                }
                
                var found = false
                
                if case let .success(infos) = result {
                    outer: for info in infos {
                        if let configuration = info.configuration as? SelectFriendsIntent {
                            if let items = configuration.friends {
                                for item in items {
                                    if friendAccountId(item) == accountId {
                                        found = true
                                        break outer
                                    }
                                }
                            }
                        } else if let configuration = info.configuration as? SelectAvatarFriendsIntent {
                            if let items = configuration.friends {
                                for item in items {
                                    if friendAccountId(item) == accountId {
                                        found = true
                                        break outer
                                    }
                                }
                            }
                        }
                    }
                }
                
                subscriber.putNext(found)
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        }
    } else {
        return .single(false)
    }
}
