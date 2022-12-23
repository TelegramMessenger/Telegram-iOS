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
import PtgSecretPasscodes

private final class SecretPasscodeControllerArguments {
    let changePasscode: () -> Void
    let changeTimeout: () -> Void
    let deletePasscode: () -> Void
    let addSecretChats: () -> Void
    let removeSecretChat: (PtgSecretChatId) -> Void
    
    init(changePasscode: @escaping () -> Void, changeTimeout: @escaping () -> Void, deletePasscode: @escaping () -> Void, addSecretChats: @escaping () -> Void, removeSecretChat: @escaping (PtgSecretChatId) -> Void) {
        self.changePasscode = changePasscode
        self.changeTimeout = changeTimeout
        self.deletePasscode = deletePasscode
        self.addSecretChats = addSecretChats
        self.removeSecretChat = removeSecretChat
    }
}

private enum SecretPasscodeControllerSection: Int32 {
    case state
    case timeout
    case secretChats
    case changePasscode
    case delete
}

private enum SecretPasscodeControllerEntry: ItemListNodeEntry {
    case state(String)
    case timeout(String, String)
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
        case .secretChatsHeader:
            return true
        case .secretChatsAdd:
            if case .secretChatsHeader = rhs {
                return false
            } else if case .secretChat = rhs {
                return true
            } else {
                assertionFailure()
                return false
            }
        case let .secretChat(lhsIndex, _, _, _):
            if case let .secretChat(rhsIndex, _, _, _) = rhs {
                return lhsIndex < rhsIndex
            } else {
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
        case let .secretChatsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
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

private func secretPasscodeControllerEntries(presentationData: PresentationData, state: SecretPasscodeControllerState, secretChatEntries: [SecretChatEntry]) -> [SecretPasscodeControllerEntry] {
    var entries: [SecretPasscodeControllerEntry] = []
    
    entries.append(.state(state.settings.active ? presentationData.strings.SecretPasscodeStatus_Revealed : presentationData.strings.SecretPasscodeStatus_Hidden))
    
    entries.append(.timeout(presentationData.strings.SecretPasscodeSettings_AutoHide, autolockStringForTimeout(strings: presentationData.strings, timeout: state.settings.timeout)))
    
    entries.append(.secretChatsHeader(presentationData.strings.Privacy_SecretChatsTitle.uppercased()))
    entries.append(.secretChatsAdd(presentationData.strings.SecretPasscode_AddSecretChats))
    
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

private struct SecretChatEntry: Equatable {
    let secretChatId: PtgSecretChatId
    let peer: EngineRenderedPeer
    let _peerItemContext: EquatableAccountContext // note that account may be hidden, use only for ItemListPeerItem
    let accountName: String
    let lastActivityOrStatus: String
}

private func _getAccountsIncludingHiddenOnes(context: AccountContext) -> Signal<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]), NoError> {
    return activeAccountsAndPeers(context: context, includePrimary: true)
}

private func getSecretChatEntries(currentContext: AccountContext, secretChats: Set<PtgSecretChatId>, presentationData: PresentationData) -> Signal<[SecretChatEntry], NoError> {
    return _getAccountsIncludingHiddenOnes(context: currentContext)
    |> mapToSignal { accountsAndPeers in
        let accounts = Dictionary(uniqueKeysWithValues: accountsAndPeers.1.map { ($0.0.account.id, ($0.0, $0.1)) })
        return combineLatest(secretChats.filter({ accounts[$0.accountRecordId] != nil }).map { secretChatId -> Signal<(PtgSecretChatId, EngineRenderedPeer?, EngineChatList.Item.Index?), NoError> in
            let context = accounts[secretChatId.accountRecordId]!.0
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
                guard case let .chatList(index) = index else {
                    return nil
                }
                return (secretChatId, peer, index)
            }
            .sorted {
                return ($1.2 ?? .absoluteLowerBound) < ($0.2 ?? .absoluteLowerBound)
            }
            .map { (secretChatId, peer, index) in
                let (peerItemContext, accountPeer) = accounts[secretChatId.accountRecordId]!
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
        let secretPasscode = ptgSecretPasscodes.secretPasscodes.first { $0.passcode == passcode } ?? PtgSecretPasscode(passcode: passcode)
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
    var popToControllerImpl: (() -> Void)?
    
    let arguments = SecretPasscodeControllerArguments(changePasscode: {
        let _ = (combineLatest(context.sharedContext.ptgSecretPasscodes, statePromise.get())
        |> take(1)
        |> deliverOnMainQueue).start(next: { ptgSecretPasscodes, state in
            let controller = PasscodeSetupController(context: context, mode: .secretSetup(.digits6))
            
            controller.validate = { newPasscode in
                if ptgSecretPasscodes.secretPasscodes.contains(where: { $0.passcode == newPasscode }) && newPasscode != state.settings.passcode {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    return presentationData.strings.PasscodeSettings_PasscodeInUse
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
    }, addSecretChats: {
        let openSecretChatsSelection: (AccountContext, ViewController?) -> Void = { context, pushToController in
            let _ = (combineLatest(statePromise.get(), context.engine.peers.currentChatListFilters())
            |> take(1)
            |> deliverOnMainQueue).start(next: { state, chatListFilters in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let selectedChats = Set(state.settings.secretChats.filter({ $0.accountRecordId == context.account.id }).map({ $0.peerId }))
                let inactiveSecretChatPeerIds = context.inactiveSecretChatPeerIds
                |> map { inactiveSecretChatPeerIds in
                    return inactiveSecretChatPeerIds.subtracting(selectedChats)
                }
                
                // this filter enables selection of archived chats
                let chatListFilter: ChatListFilter = .filter(id: -1, title: "", emoticon: nil, data: ChatListFilterData(categories: [.contacts, .nonContacts], excludeMuted: false, excludeRead: false, excludeArchived: false, includePeers: ChatListFilterIncludePeers(), excludePeers: []))
                
                let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(title: presentationData.strings.SecretPasscode_SecretChatsSelectionTitle, selectedChats: selectedChats, additionalCategories: nil, chatListFilters: chatListFilters, chatListNodeFilter: chatListFilter, chatListNodePeersFilter: [.excludeUsers, .excludeGroups, .excludeChannels, .excludeBots, .excludeSavedMessages], omitTokenList: true, inactiveSecretChatPeerIds: inactiveSecretChatPeerIds), options: [], filters: [], alwaysEnabled: true))

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

                    var secretChats = state.settings.secretChats.filter({ $0.accountRecordId != context.account.id })
                    
                    for peerId in peerIds {
                        if case let .peer(id) = peerId, id.namespace == Namespaces.Peer.SecretChat {
                            secretChats.insert(PtgSecretChatId(accountRecordId: context.account.id, peerId: id))
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

                    if let _ = pushToController {
                        popToControllerImpl?()
                    } else {
                        controller?.dismiss()
                    }
                })
            })
        }
        
        let _ = (activeAccountsAndPeers(context: context, includePrimary: true)
        |> take(1)
        |> deliverOnMainQueue).start(next: { accountsAndPeers in
            // don't need hidden accounts here
            let haveMultipleAccounts = accountsAndPeers.1.count > 1
            if haveMultipleAccounts {
                var accountSelectionCompleted: ((AccountContext) -> Void)?
                
                let accountsController = accountSelectionController(context: context, accountSelected: { selectedContext in
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
        return combineLatest(.single(presentationData), .single(state), getSecretChatEntries(currentContext: context, secretChats: state.settings.secretChats, presentationData: presentationData))
    }
    |> deliverOnMainQueue
    |> map { presentationData, state, secretChatEntries -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SecretPasscodeSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: secretPasscodeControllerEntries(presentationData: presentationData, state: state, secretChatEntries: secretChatEntries), style: .blocks)
        
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
    
    popToControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popToViewController(controller!, animated: true)
    }
    
    controller.isSensitiveUI = true
    
    return controller
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
}
