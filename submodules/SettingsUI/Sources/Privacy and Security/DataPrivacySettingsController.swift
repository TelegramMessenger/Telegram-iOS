import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices
import UndoUI

private final class DataPrivacyControllerArguments {
    let account: Account
    let clearPaymentInfo: () -> Void
    let updateSecretChatLinkPreviews: (Bool) -> Void
    let deleteContacts: () -> Void
    let updateSyncContacts: (Bool) -> Void
    let updateSuggestFrequentContacts: (Bool) -> Void
    let deleteCloudDrafts: () -> Void
    
    init(account: Account, clearPaymentInfo: @escaping () -> Void, updateSecretChatLinkPreviews: @escaping (Bool) -> Void, deleteContacts: @escaping () -> Void, updateSyncContacts: @escaping (Bool) -> Void, updateSuggestFrequentContacts: @escaping (Bool) -> Void, deleteCloudDrafts: @escaping () -> Void) {
        self.account = account
        self.clearPaymentInfo = clearPaymentInfo
        self.updateSecretChatLinkPreviews = updateSecretChatLinkPreviews
        self.deleteContacts = deleteContacts
        self.updateSyncContacts = updateSyncContacts
        self.updateSuggestFrequentContacts = updateSuggestFrequentContacts
        self.deleteCloudDrafts = deleteCloudDrafts
    }
}

private enum PrivacyAndSecuritySection: Int32 {
    case contacts
    case frequentContacts
    case chats
    case payments
    case secretChats
}

private enum PrivacyAndSecurityEntry: ItemListNodeEntry {
    case contactsHeader(PresentationTheme, String)
    case deleteContacts(PresentationTheme, String, Bool)
    case syncContacts(PresentationTheme, String, Bool)
    case syncContactsInfo(PresentationTheme, String)
    
    case frequentContacts(PresentationTheme, String, Bool)
    case frequentContactsInfo(PresentationTheme, String)
    
    case chatsHeader(PresentationTheme, String)
    case deleteCloudDrafts(PresentationTheme, String, Bool)
    
    case paymentHeader(PresentationTheme, String)
    case clearPaymentInfo(PresentationTheme, String, Bool)
    case paymentInfo(PresentationTheme, String)
    
    case secretChatLinkPreviewsHeader(PresentationTheme, String)
    case secretChatLinkPreviews(PresentationTheme, String, Bool)
    case secretChatLinkPreviewsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .contactsHeader, .deleteContacts, .syncContacts, .syncContactsInfo:
                return PrivacyAndSecuritySection.contacts.rawValue
            case .frequentContacts, .frequentContactsInfo:
                return PrivacyAndSecuritySection.frequentContacts.rawValue
            case .chatsHeader, .deleteCloudDrafts:
                return PrivacyAndSecuritySection.chats.rawValue
            case .paymentHeader, .clearPaymentInfo, .paymentInfo:
                return PrivacyAndSecuritySection.payments.rawValue
            case .secretChatLinkPreviewsHeader, .secretChatLinkPreviews, .secretChatLinkPreviewsInfo:
                return PrivacyAndSecuritySection.secretChats.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .contactsHeader:
                return 0
            case .deleteContacts:
                return 1
            case .syncContacts:
                return 2
            case .syncContactsInfo:
                return 3
            
            case .frequentContacts:
                return 4
            case .frequentContactsInfo:
                return 5
            
            case .chatsHeader:
                return 6
            case .deleteCloudDrafts:
                return 7
            
            case .paymentHeader:
                return 8
            case .clearPaymentInfo:
                return 9
            case .paymentInfo:
                return 10
            
            case .secretChatLinkPreviewsHeader:
                return 11
            case .secretChatLinkPreviews:
                return 12
            case .secretChatLinkPreviewsInfo:
                return 13
        }
    }
    
    static func ==(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        switch lhs {
            case let .contactsHeader(lhsTheme, lhsText):
                if case let .contactsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .deleteContacts(lhsTheme, lhsText, lhsEnabled):
                if case let .deleteContacts(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .syncContacts(lhsTheme, lhsText, lhsEnabled):
                if case let .syncContacts(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .syncContactsInfo(lhsTheme, lhsText):
                if case let .syncContactsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .frequentContacts(lhsTheme, lhsText, lhsEnabled):
                if case let .frequentContacts(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .frequentContactsInfo(lhsTheme, lhsText):
                if case let .frequentContactsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .chatsHeader(lhsTheme, lhsText):
                if case let .chatsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .deleteCloudDrafts(lhsTheme, lhsText, lhsEnabled):
                if case let .deleteCloudDrafts(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .paymentHeader(lhsTheme, lhsText):
                if case let .paymentHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .clearPaymentInfo(lhsTheme, lhsText, lhsEnabled):
                if case let .clearPaymentInfo(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .paymentInfo(lhsTheme, lhsText):
                if case let .paymentInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .secretChatLinkPreviewsHeader(lhsTheme, lhsText):
                if case let .secretChatLinkPreviewsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .secretChatLinkPreviews(lhsTheme, lhsText, lhsEnabled):
                if case let .secretChatLinkPreviews(rhsTheme, rhsText, rhsEnabled) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .secretChatLinkPreviewsInfo(lhsTheme, lhsText):
                if case let .secretChatLinkPreviewsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PrivacyAndSecurityEntry, rhs: PrivacyAndSecurityEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DataPrivacyControllerArguments
        switch self {
            case let .contactsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .deleteContacts(_, text, value):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: value ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.deleteContacts()
                })
            case let .syncContacts(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSyncContacts(updatedValue)
                })
            case let .syncContactsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .frequentContacts(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: !value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSuggestFrequentContacts(updatedValue)
                })
            case let .frequentContactsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .chatsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .deleteCloudDrafts(_, text, value):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: value ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.deleteCloudDrafts()
                })
            case let .paymentHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .clearPaymentInfo(_, text, enabled):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.clearPaymentInfo()
                })
            case let .paymentInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .secretChatLinkPreviewsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .secretChatLinkPreviews(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateSecretChatLinkPreviews(updatedValue)
                })
            case let .secretChatLinkPreviewsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct DataPrivacyControllerState: Equatable {
    var clearingPaymentInfo: Bool = false
    var deletingContacts: Bool = false
    var updatedSuggestFrequentContacts: Bool? = nil
    var deletingCloudDrafts: Bool = false
}

private func dataPrivacyControllerEntries(presentationData: PresentationData, state: DataPrivacyControllerState, secretChatLinkPreviews: Bool?, synchronizeDeviceContacts: Bool, frequentContacts: Bool) -> [PrivacyAndSecurityEntry] {
    var entries: [PrivacyAndSecurityEntry] = []
    
    entries.append(.contactsHeader(presentationData.theme, presentationData.strings.Privacy_ContactsTitle))
    entries.append(.deleteContacts(presentationData.theme, presentationData.strings.Privacy_ContactsReset, !state.deletingContacts))
    entries.append(.syncContacts(presentationData.theme, presentationData.strings.Privacy_ContactsSync, synchronizeDeviceContacts))
    entries.append(.syncContactsInfo(presentationData.theme, presentationData.strings.Privacy_ContactsSyncHelp))
    
    entries.append(.frequentContacts(presentationData.theme, presentationData.strings.Privacy_TopPeers, frequentContacts))
    entries.append(.frequentContactsInfo(presentationData.theme, presentationData.strings.Privacy_TopPeersHelp))
    
    entries.append(.chatsHeader(presentationData.theme, presentationData.strings.Privacy_ChatsTitle))
    entries.append(.deleteCloudDrafts(presentationData.theme, presentationData.strings.Privacy_DeleteDrafts, !state.deletingCloudDrafts))
    entries.append(.paymentHeader(presentationData.theme, presentationData.strings.Privacy_PaymentsTitle))
    entries.append(.clearPaymentInfo(presentationData.theme, presentationData.strings.Privacy_PaymentsClearInfo, !state.clearingPaymentInfo))
    entries.append(.paymentInfo(presentationData.theme, presentationData.strings.Privacy_PaymentsClearInfoHelp))
    
    entries.append(.secretChatLinkPreviewsHeader(presentationData.theme, presentationData.strings.Privacy_SecretChatsTitle))
    entries.append(.secretChatLinkPreviews(presentationData.theme, presentationData.strings.Privacy_SecretChatsLinkPreviews, secretChatLinkPreviews ?? true))
    entries.append(.secretChatLinkPreviewsInfo(presentationData.theme, presentationData.strings.Privacy_SecretChatsLinkPreviewsHelp))
    
    return entries
}

public func dataPrivacyController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(DataPrivacyControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: DataPrivacyControllerState())
    let updateState: ((DataPrivacyControllerState) -> DataPrivacyControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let currentInfoDisposable = MetaDisposable()
    actionsDisposable.add(currentInfoDisposable)
    
    let clearPaymentInfoDisposable = MetaDisposable()
    actionsDisposable.add(clearPaymentInfoDisposable)
    
    let arguments = DataPrivacyControllerArguments(account: context.account, clearPaymentInfo: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        
        var values = [true, true]
        
        let toggleCheck: (Int) -> Void = { [weak controller] itemIndex in
            controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
                if let item = item as? ActionSheetCheckboxItem {
                    values[itemIndex] = !item.value
                    return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                }
                return item
            })
            
            controller?.updateItem(groupIndex: 0, itemIndex: 2, { item in
                if let item = item as? ActionSheetButtonItem {
                    let disabled = !values[0] && !values[1]
                    return ActionSheetButtonItem(title: item.title, color: disabled ? .disabled : .accent, enabled: !disabled, action: item.action)
                }
                return item
            })
        }
        
        var items: [ActionSheetItem] = []
        
        items.append(ActionSheetCheckboxItem(title: presentationData.strings.Privacy_PaymentsClear_PaymentInfo, label: "", value: true, action: { value in
            toggleCheck(0)
        }))

        items.append(ActionSheetCheckboxItem(title: presentationData.strings.Privacy_PaymentsClear_ShippingInfo, label: "", value: true, action: { value in
            toggleCheck(1)
        }))
        
        items.append(ActionSheetButtonItem(title: presentationData.strings.Cache_ClearNone, action: {
            var clear = false
            updateState { state in
                var state = state
                if !state.clearingPaymentInfo {
                    clear = true
                    state.clearingPaymentInfo = true
                }
                return state
            }
            if clear {
                var info = BotPaymentInfo()
                if values[0] {
                    info.insert(.paymentInfo)
                }
                if values[1] {
                    info.insert(.shippingInfo)
                }
                
                clearPaymentInfoDisposable.set((context.engine.payments.clearBotPaymentInfo(info: info)
                    |> deliverOnMainQueue).start(completed: {
                        updateState { state in
                            var state = state
                            state.clearingPaymentInfo = false
                            return state
                        }
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let text: String?
                        if info.contains([.paymentInfo, .shippingInfo]) {
                            text = presentationData.strings.Privacy_PaymentsClear_AllInfoCleared
                        } else if info.contains(.paymentInfo) {
                            text = presentationData.strings.Privacy_PaymentsClear_PaymentInfoCleared
                        } else if info.contains(.shippingInfo) {
                            text = presentationData.strings.Privacy_PaymentsClear_ShippingInfoCleared
                        } else {
                            text = nil
                        }
                        if let text = text {
                            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: text), elevatedLayout: false, action: { _ in return false }))
                        }
                    }))
            }
            dismissAction()
        }))
        
        controller.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
        presentControllerImpl?(controller)
    }, updateSecretChatLinkPreviews: { value in
        let _ = ApplicationSpecificNotice.setSecretChatLinkPreviews(accountManager: context.sharedContext.accountManager, value: value).start()
    }, deleteContacts: {
        var canBegin = false
        updateState { state in
            if !state.deletingContacts {
                canBegin = true
            }
            return state
        }
        if canBegin {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_ContactsResetConfirmation, actions: [TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                var begin = false
                updateState { state in
                    var state = state
                    if !state.deletingContacts {
                        state.deletingContacts = true
                        begin = true
                    }
                    return state
                }
                
                if !begin {
                    return
                }
                
                let _ = context.engine.contacts.updateIsContactSynchronizationEnabled(isContactSynchronizationEnabled: false).start()
                
                actionsDisposable.add((context.engine.contacts.deleteAllContacts()
                |> deliverOnMainQueue).start(completed: {
                    updateState { state in
                        var state = state
                        state.deletingContacts = false
                        return state
                    }
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.Privacy_ContactsReset_ContactsDeleted), elevatedLayout: false, action: { _ in return false }))
                }))
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})]))
        }
    }, updateSyncContacts: { value in
        let _ = context.engine.contacts.updateIsContactSynchronizationEnabled(isContactSynchronizationEnabled: value).start()
    }, updateSuggestFrequentContacts: { value in
        let apply: () -> Void = {
            updateState { state in
                var state = state
                state.updatedSuggestFrequentContacts = value
                return state
            }
            let _ = context.engine.peers.updateRecentPeersEnabled(enabled: value).start()
        }
        if !value {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Privacy_TopPeersWarning, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                apply()
            })]))
        } else {
            apply()
        }
    }, deleteCloudDrafts: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Privacy_DeleteDrafts, color: .destructive, action: {
                    var clear = false
                    updateState { state in
                        var state = state
                        if !state.deletingCloudDrafts {
                            clear = true
                            state.deletingCloudDrafts = true
                        }
                        return state
                    }
                    if clear {
                        clearPaymentInfoDisposable.set((context.engine.messages.clearCloudDraftsInteractively()
                            |> deliverOnMainQueue).start(completed: {
                                updateState { state in
                                    var state = state
                                    state.deletingCloudDrafts = false
                                    return state
                                }
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .succeed(text: presentationData.strings.Privacy_DeleteDrafts_DraftsDeleted), elevatedLayout: false, action: { _ in return false }))
                            }))
                    }
                    dismissAction()
                })
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
        presentControllerImpl?(controller)
    })
    
    actionsDisposable.add(context.engine.peers.managedUpdatedRecentPeers().start())
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.secretChatLinkPreviewsKey()), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]), context.account.postbox.preferencesView(keys: [PreferencesKeys.contactsSettings]), context.engine.peers.recentPeers())
    |> map { presentationData, state, noticeView, sharedData, preferences, recentPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let secretChatLinkPreviews = noticeView.value.flatMap({ ApplicationSpecificNotice.getSecretChatLinkPreviews($0) })
        
        let settings: ContactsSettings = preferences.values[PreferencesKeys.contactsSettings]?.get(ContactsSettings.self) ?? ContactsSettings.defaultSettings
        
        let synchronizeDeviceContacts: Bool = settings.synchronizeContacts
        
        let suggestRecentPeers: Bool
        if let updatedSuggestFrequentContacts = state.updatedSuggestFrequentContacts {
            suggestRecentPeers = updatedSuggestFrequentContacts
        } else {
            switch recentPeers {
                case .peers:
                    suggestRecentPeers = true
                case .disabled:
                    suggestRecentPeers = false
            }
        }
        
        let rightNavigationButton: ItemListNavigationButton? = nil
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PrivateDataSettings_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        
        let animateChanges = false
        
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: dataPrivacyControllerEntries(presentationData: presentationData, state: state, secretChatLinkPreviews: secretChatLinkPreviews, synchronizeDeviceContacts: synchronizeDeviceContacts, frequentContacts: suggestRecentPeers), style: .blocks, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    
    return controller
}
