/*import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext

private final class ChatListFilterPresetListControllerArguments {
    let context: AccountContext
    
    let openPreset: (ChatListFilter) -> Void
    let addNew: () -> Void
    let setItemWithRevealedOptions: (Int32?, Int32?) -> Void
    let removePreset: (Int32) -> Void
    
    init(context: AccountContext, openPreset: @escaping (ChatListFilter) -> Void, addNew: @escaping () -> Void, setItemWithRevealedOptions: @escaping (Int32?, Int32?) -> Void, removePreset: @escaping (Int32) -> Void) {
        self.context = context
        self.openPreset = openPreset
        self.addNew = addNew
        self.setItemWithRevealedOptions = setItemWithRevealedOptions
        self.removePreset = removePreset
    }
}

private enum ChatListFilterPresetListSection: Int32 {
    case list
}

private func stringForUserCount(_ peers: [PeerId: SelectivePrivacyPeer], strings: PresentationStrings) -> String {
    if peers.isEmpty {
        return strings.PrivacyLastSeenSettings_EmpryUsersPlaceholder
    } else {
        var result = 0
        for (_, peer) in peers {
            result += peer.userCount
        }
        return strings.UserCount(Int32(result))
    }
}

private enum ChatListFilterPresetListEntryStableId: Hashable {
    case listHeader
    case preset(Int32)
    case addItem
    case listFooter
}

private enum ChatListFilterPresetListEntry: ItemListNodeEntry {
    case listHeader(String)
    case preset(index: Int, title: String?, preset: ChatListFilter, canBeReordered: Bool, canBeDeleted: Bool)
    case addItem(String)
    case listFooter(String)
    
    var section: ItemListSectionId {
        switch self {
        case .listHeader, .preset, .addItem, .listFooter:
            return ChatListFilterPresetListSection.list.rawValue
        }
    }
    
    var sortId: Int {
        switch self {
        case .listHeader:
            return 0
        case let .preset(preset):
            return 1 + preset.index
        case .addItem:
            return 1000
        case .listFooter:
            return 1001
        }
    }
    
    var stableId: ChatListFilterPresetListEntryStableId {
        switch self {
        case .listHeader:
            return .listHeader
        case let .preset(preset):
            return .preset(preset.preset.id)
        case .addItem:
            return .addItem
        case .listFooter:
            return .listFooter
        }
    }
    
    static func <(lhs: ChatListFilterPresetListEntry, rhs: ChatListFilterPresetListEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatListFilterPresetListControllerArguments
        switch self {
        case let .listHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .preset(index, title, preset, canBeReordered, canBeDeleted):
            return ChatListFilterPresetListItem(presentationData: presentationData, preset: preset, title: title ?? "", editing: ChatListFilterPresetListItemEditing(editable: true, editing: false, revealed: false), canBeReordered: canBeReordered, canBeDeleted: canBeDeleted, sectionId: self.section, action: {
                arguments.openPreset(preset)
            }, setItemWithRevealedOptions: { lhs, rhs in
                arguments.setItemWithRevealedOptions(lhs, rhs)
            }, remove: {
                arguments.removePreset(preset.id)
            })
        case let .addItem(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addNew()
            })
        case let .listFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct ChatListFilterPresetListControllerState: Equatable {
    var revealedPreset: Int32? = nil
}

private func chatListFilterPresetListControllerEntries(presentationData: PresentationData, state: ChatListFilterPresetListControllerState, settings: ChatListFiltersState) -> [ChatListFilterPresetListEntry] {
    var entries: [ChatListFilterPresetListEntry] = []

    entries.append(.listHeader("FILTERS"))
    for preset in settings.filters {
        entries.append(.preset(index: entries.count, title: preset.title, preset: preset, canBeReordered: settings.filters.count > 1, canBeDeleted: true))
    }
    entries.append(.addItem("Add New"))
    entries.append(.listFooter("Add custom presets"))
    
    return entries
}

func chatListFilterPresetListController(context: AccountContext, updated: @escaping ([ChatListFilter]) -> Void) -> ViewController {
    let initialState = ChatListFilterPresetListControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChatListFilterPresetListControllerState) -> ChatListFilterPresetListControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    
    let arguments = ChatListFilterPresetListControllerArguments(context: context, openPreset: { preset in
        pushControllerImpl?(chatListFilterPresetController(context: context, currentPreset: preset, updated: updated))
    }, addNew: {
        pushControllerImpl?(chatListFilterPresetController(context: context, currentPreset: nil, updated: updated))
    }, setItemWithRevealedOptions: { preset, fromPreset in
        updateState { state in
            var state = state
            if (preset == nil && fromPreset == state.revealedPreset) || (preset != nil && fromPreset == nil) {
                state.revealedPreset = preset
            }
            return state
        }
    }, removePreset: { id in
        let _ = (updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            if let index = settings.filters.index(where: { $0.id == id }) {
                settings.filters.remove(at: index)
            }
            return settings
        })
        |> deliverOnMainQueue).start(next: { settings in
            updated(settings.filters)
        })
    })
    
    let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        preferences
    )
    |> map { presentationData, state, preferences -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = preferences.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState ?? ChatListFiltersState.default
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Close), style: .regular, enabled: true, action: {
            let _ = replaceRemoteChatListFilters(account: context.account).start()
            dismissImpl?()
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Filter Presets"), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetListControllerEntries(presentationData: presentationData, state: state, settings: settings), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
*/
