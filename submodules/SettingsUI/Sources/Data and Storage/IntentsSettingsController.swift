import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import AppIntents

private final class IntentsSettingsControllerArguments {
    let context: AccountContext
    let updateSettings: (@escaping (IntentsSettings) -> IntentsSettings) -> Void
    let resetAll: () -> Void
    
    init(context: AccountContext, updateSettings: @escaping (@escaping (IntentsSettings) -> IntentsSettings) -> Void, resetAll: @escaping () -> Void) {
        self.context = context
        self.updateSettings = updateSettings
        self.resetAll = resetAll
    }
}

private enum IntentsSettingsSection: Int32 {
    case account
    case chats
    case suggest
    case reset
}

private enum IntentsSettingsControllerEntry: ItemListNodeEntry {
    case accountHeader(PresentationTheme, String)
    case account(PresentationTheme, Peer, Bool, Int32)
    case accountInfo(PresentationTheme, String)
    
    case chatsHeader(PresentationTheme, String)
    case contacts(PresentationTheme, String, Bool)
    case savedMessages(PresentationTheme, String, Bool)
    case privateChats(PresentationTheme, String, Bool)
    case groups(PresentationTheme, String, Bool)
    case chatsInfo(PresentationTheme, String)
    
    case suggestHeader(PresentationTheme, String)
    case suggestAll(PresentationTheme, String, Bool)
    case suggestOnlyShared(PresentationTheme, String, Bool)
    
    case resetAll(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .accountHeader, .account, .accountInfo:
                return IntentsSettingsSection.account.rawValue
            case .chatsHeader, .contacts, .savedMessages, .privateChats, .groups, .chatsInfo:
                   return IntentsSettingsSection.chats.rawValue
            case .suggestHeader, .suggestAll, .suggestOnlyShared:
                return IntentsSettingsSection.suggest.rawValue
            case .resetAll:
                return IntentsSettingsSection.reset.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .accountHeader:
                return 0
            case let .account(_, _, _, index):
                return 1 + index
            case .accountInfo:
                return 1000
            case .chatsHeader:
                return 1001
            case .contacts:
                return 1002
            case .savedMessages:
                return 1003
            case .privateChats:
                return 1004
            case .groups:
                return 1005
            case .chatsInfo:
                return 1006
            case .suggestHeader:
                return 1007
            case .suggestAll:
                return 1008
            case .suggestOnlyShared:
                return 1009
            case .resetAll:
                return 1010
        }
    }
    
    static func ==(lhs: IntentsSettingsControllerEntry, rhs: IntentsSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .accountHeader(lhsTheme, lhsText):
                if case let .accountHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .account(lhsTheme, lhsPeer, lhsSelected, lhsIndex):
                if case let .account(rhsTheme, rhsPeer, rhsSelected, rhsIndex) = rhs, lhsTheme === rhsTheme, arePeersEqual(lhsPeer, rhsPeer), lhsSelected == rhsSelected, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .accountInfo(lhsTheme, lhsText):
                if case let .accountInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .contacts(lhsTheme, lhsText, lhsValue):
                if case let .contacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .savedMessages(lhsTheme, lhsText, lhsValue):
                if case let .savedMessages(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .privateChats(lhsTheme, lhsText, lhsValue):
                if case let .privateChats(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groups(lhsTheme, lhsText, lhsValue):
                if case let .groups(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .chatsInfo(lhsTheme, lhsText):
                if case let .chatsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            
            case let .suggestHeader(lhsTheme, lhsText):
                if case let .suggestHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .suggestAll(lhsTheme, lhsText, lhsValue):
                if case let .suggestAll(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .suggestOnlyShared(lhsTheme, lhsText, lhsValue):
                if case let .suggestOnlyShared(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .resetAll(lhsTheme, lhsText):
                if case let .resetAll(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: IntentsSettingsControllerEntry, rhs: IntentsSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: Any) -> ListViewItem {
        let arguments = arguments as! IntentsSettingsControllerArguments
        switch self {
            case let .accountHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            //            case let .browser(theme, title, application, identifier, selected, _):
            //                return WebBrowserItem(account: arguments.context.account, theme: theme, title: title, application: application, checked: selected, sectionId: self.section) {
            //                    arguments.updateDefaultBrowser(identifier)
            //                }
            case let .account(theme, peer, selected, _):
                return ItemListTextItem(theme: theme, text: .plain(""), sectionId: self.section)
            case let .accountInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .chatsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .contacts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateSettings { $0.withUpdatedContacts(value) }
                })
            case let .savedMessages(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateSettings { $0.withUpdatedSavedMessages(value) }
                })
            case let .privateChats(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateSettings { $0.withUpdatedPrivateChats(value) }
                })
            case let .groups(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateSettings { $0.withUpdatedGroups(value) }
                })
            case let .chatsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .suggestHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .suggestAll(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateSettings { $0.withUpdatedOnlyShared(false) }
                })
            case let .suggestOnlyShared(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateSettings { $0.withUpdatedOnlyShared(true) }
                })

            case let .resetAll(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.resetAll()
                })
        }
    }
}

private func intentsSettingsControllerEntries(context: AccountContext, presentationData: PresentationData, settings: IntentsSettings) -> [IntentsSettingsControllerEntry] {
    var entries: [IntentsSettingsControllerEntry] = []
    
    entries.append(.accountHeader(presentationData.theme, presentationData.strings.IntentsSettings_MainAccount.uppercased()))
    
    var index: Int32 = 0
//    for option in options {
//        entries.append(.browser(presentationData.theme, option.title, option.application, option.identifier, option.identifier == selectedBrowser, index))
//        index += 1
//    }
    
    //entries.append(.accountInfo(presentationData.theme, presentationData.strings.IntentsSettings_MainAccountInfo))
    
    entries.append(.chatsHeader(presentationData.theme, presentationData.strings.IntentsSettings_SuggestedChats.uppercased()))
    entries.append(.contacts(presentationData.theme, presentationData.strings.IntentsSettings_SuggestedChatsContacts, settings.contacts))
    entries.append(.savedMessages(presentationData.theme, presentationData.strings.IntentsSettings_SuggestedChatsSavedMessages, settings.savedMessages))
    entries.append(.privateChats(presentationData.theme, presentationData.strings.IntentsSettings_SuggestedChatsPrivateChats, settings.privateChats))
    entries.append(.groups(presentationData.theme, presentationData.strings.IntentsSettings_SuggestedChatsGroups, settings.groups))
    
    entries.append(.chatsInfo(presentationData.theme, presentationData.strings.IntentsSettings_SuggestedChatsInfo))
    
    entries.append(.suggestHeader(presentationData.theme, presentationData.strings.IntentsSettings_SuggestBy.uppercased()))
    entries.append(.suggestAll(presentationData.theme, presentationData.strings.IntentsSettings_SuggestByAll, !settings.onlyShared))
    entries.append(.suggestOnlyShared(presentationData.theme, presentationData.strings.IntentsSettings_SuggestByShare, settings.onlyShared))
    
    entries.append(.resetAll(presentationData.theme, presentationData.strings.IntentsSettings_ResetAll))
    
    return entries
}

public func intentsSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let updateDisposable = MetaDisposable()
    let arguments = IntentsSettingsControllerArguments(context: context, updateSettings: { f in
        let _ = updateIntentsSettingsInteractively(accountManager: context.sharedContext.accountManager, f).start()
    }, resetAll: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.IntentsSettings_Reset, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                deleteAllSendMessageIntents()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.intentsSettings]))
    |> deliverOnMainQueue
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.intentsSettings] as? IntentsSettings) ?? IntentsSettings.defaultSettings
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.IntentsSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: intentsSettingsControllerEntries(context: context, presentationData: presentationData, settings: settings), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
