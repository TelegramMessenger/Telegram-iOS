import Foundation
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
import ItemListPeerActionItem

private final class ChatListFilterPresetListControllerArguments {
    let context: AccountContext
    
    let addSuggestedPresed: (String, ChatListFilterData) -> Void
    let openPreset: (ChatListFilter) -> Void
    let addNew: () -> Void
    let setItemWithRevealedOptions: (Int32?, Int32?) -> Void
    let removePreset: (Int32) -> Void
    
    init(context: AccountContext, addSuggestedPresed: @escaping (String, ChatListFilterData) -> Void, openPreset: @escaping (ChatListFilter) -> Void, addNew: @escaping () -> Void, setItemWithRevealedOptions: @escaping (Int32?, Int32?) -> Void, removePreset: @escaping (Int32) -> Void) {
        self.context = context
        self.addSuggestedPresed = addSuggestedPresed
        self.openPreset = openPreset
        self.addNew = addNew
        self.setItemWithRevealedOptions = setItemWithRevealedOptions
        self.removePreset = removePreset
    }
}

private enum ChatListFilterPresetListSection: Int32 {
    case screenHeader
    case suggested
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
    case screenHeader
    case suggestedListHeader
    case suggestedPreset(ChatListFilterData)
    case listHeader
    case preset(Int32)
    case addItem
    case listFooter
}

private enum ChatListFilterPresetListEntry: ItemListNodeEntry {
    case screenHeader(String)
    case suggestedListHeader(String)
    case suggestedPreset(index: Int, title: String, label: String, preset: ChatListFilterData)
    case listHeader(String)
    case preset(index: Int, title: String, label: String, preset: ChatListFilter, canBeReordered: Bool, canBeDeleted: Bool, isEditing: Bool)
    case addItem(text: String, isEditing: Bool)
    case listFooter(String)
    
    var section: ItemListSectionId {
        switch self {
        case .screenHeader:
            return ChatListFilterPresetListSection.screenHeader.rawValue
        case .suggestedListHeader, .suggestedPreset:
            return ChatListFilterPresetListSection.suggested.rawValue
        case .listHeader, .preset, .addItem, .listFooter:
            return ChatListFilterPresetListSection.list.rawValue
        }
    }
    
    var sortId: Int {
        switch self {
        case .screenHeader:
            return 0
        case .listHeader:
            return 100
        case let .preset(preset):
            return 101 + preset.index
        case .addItem:
            return 1000
        case .listFooter:
            return 1001
        case .suggestedListHeader:
            return 1002
        case let .suggestedPreset(suggestedPreset):
            return 1003 + suggestedPreset.index
        }
    }
    
    var stableId: ChatListFilterPresetListEntryStableId {
        switch self {
        case .screenHeader:
            return .screenHeader
        case .suggestedListHeader:
            return .suggestedListHeader
        case let .suggestedPreset(suggestedPreset):
            return .suggestedPreset(suggestedPreset.preset)
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
        case let .screenHeader(text):
            return ChatListFilterSettingsHeaderItem(theme: presentationData.theme, text: text, sectionId: self.section)
        case let .suggestedListHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .suggestedPreset(_, title, label, preset):
            return ChatListFilterPresetListSuggestedItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, installAction: {
                arguments.addSuggestedPresed(title, preset)
            }, tag: nil)
        case let .listHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .preset(_, title, label, preset, canBeReordered, canBeDeleted, isEditing):
            return ChatListFilterPresetListItem(presentationData: presentationData, preset: preset, title: title, label: label, editing: ChatListFilterPresetListItemEditing(editable: true, editing: isEditing, revealed: false), canBeReordered: canBeReordered, canBeDeleted: canBeDeleted, sectionId: self.section, action: {
                arguments.openPreset(preset)
            }, setItemWithRevealedOptions: { lhs, rhs in
                arguments.setItemWithRevealedOptions(lhs, rhs)
            }, remove: {
                arguments.removePreset(preset.id)
            })
        case let .addItem(text, isEditing):
            return ItemListPeerActionItem(presentationData: presentationData, icon: nil, title: text, sectionId: self.section, height: .generic, editing: isEditing, action: {
                arguments.addNew()
            })
        case let .listFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct ChatListFilterPresetListControllerState: Equatable {
    var isEditing: Bool = false
    var revealedPreset: Int32? = nil
}

private func chatListFilterPresetListControllerEntries(presentationData: PresentationData, state: ChatListFilterPresetListControllerState, filters: [(ChatListFilter, Int)], suggestedFilters: [(String, String, ChatListFilterData)], settings: ChatListFilterSettings) -> [ChatListFilterPresetListEntry] {
    var entries: [ChatListFilterPresetListEntry] = []

    entries.append(.screenHeader("Create filters for different groups of chats and\nquickly switch between them."))
    
    let filteredSuggestedFilters = suggestedFilters.filter { _, _, data in
        for (filter, _) in filters {
            if filter.data == data {
                return false
            }
        }
        return true
    }
    
    entries.append(.listHeader("FILTERS"))
    for (filter, chatCount) in filters {
        entries.append(.preset(index: entries.count, title: filter.title, label: chatCount == 0 ? "" : "\(chatCount)", preset: filter, canBeReordered: filters.count > 1, canBeDeleted: true, isEditing: state.isEditing))
    }
    if filters.count < 10 {
        entries.append(.addItem(text: "Create New Filter", isEditing: state.isEditing))
    }
    entries.append(.listFooter("Tap \"Edit\" to change the order or delete filters."))
    
    if !filteredSuggestedFilters.isEmpty {
        entries.append(.suggestedListHeader("RECOMMENDED FILTERS"))
        for (title, label, data) in filteredSuggestedFilters {
            entries.append(.suggestedPreset(index: entries.count, title: title, label: label, preset: data))
        }
    }
    
    return entries
}

public func chatListFilterPresetListController(context: AccountContext, updated: @escaping ([ChatListFilter]) -> Void) -> ViewController {
    let initialState = ChatListFilterPresetListControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChatListFilterPresetListControllerState) -> ChatListFilterPresetListControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = ChatListFilterPresetListControllerArguments(context: context,
    addSuggestedPresed: { title, data in
        let _ = (updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.filters.insert(ChatListFilter(id: max(2, settings.filters.map({ $0.id + 1 }).max() ?? 2), title: title, data: data), at: 0)
            return settings
        })
        |> deliverOnMainQueue).start(next: { settings in
            updated(settings.filters)
            
            let _ = replaceRemoteChatListFilters(account: context.account).start()
        })
    }, openPreset: { preset in
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
            if let index = settings.filters.firstIndex(where: { $0.id == id }) {
                settings.filters.remove(at: index)
            }
            return settings
        })
        |> deliverOnMainQueue).start(next: { settings in
            updated(settings.filters)
            
            let _ = replaceRemoteChatListFilters(account: context.account).start()
        })
    })
    
    let chatCountCache = Atomic<[ChatListFilterData: Int]>(value: [:])
    
    let filtersWithCounts = context.account.postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    |> map { preferences -> [ChatListFilter] in
        let filtersState = preferences.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState ?? ChatListFiltersState.default
        return filtersState.filters
    }
    |> distinctUntilChanged
    |> mapToSignal { filters -> Signal<[(ChatListFilter, Int)], NoError> in
        return context.account.postbox.transaction { transaction -> [(ChatListFilter, Int)] in
            return filters.map { filter -> (ChatListFilter, Int) in
                let count: Int
                if let cachedValue = chatCountCache.with({ dict -> Int? in
                    return dict[filter.data]
                }) {
                    count = cachedValue
                } else {
                    count = transaction.getChatCountMatchingPredicate(chatListFilterPredicate(filter: filter.data))
                    let _ = chatCountCache.modify { dict in
                        var dict = dict
                        dict[filter.data] = count
                        return dict
                    }
                }
                return (filter, count)
            }
        }
    }
    
    let preferences = context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatListFilterSettings])
    
    let suggestedFilters: [(String, String, ChatListFilterData)] = [
        ("Unread", "All unread chats", ChatListFilterData(categories: .all, excludeMuted: false, excludeRead: true, excludeArchived: false, includePeers: [], excludePeers: [])),
        ("Personal", "Exclude large groups and channels", ChatListFilterData(categories: ChatListFilterPeerCategories.all.subtracting([.largeGroups, .channels]), excludeMuted: false, excludeRead: false, excludeArchived: false, includePeers: [], excludePeers: [])),
    ]
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        filtersWithCounts,
        preferences
    )
    |> map { presentationData, state, filtersWithCounts, preferences -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let filterSettings = preferences.values[ApplicationSpecificPreferencesKeys.chatListFilterSettings] as? ChatListFilterSettings ?? ChatListFilterSettings.default
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Close), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton: ItemListNavigationButton
        if state.isEditing {
             rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                updateState { state in
                    var state = state
                    state.isEditing = false
                    return state
                }
             })
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                updateState { state in
                    var state = state
                    state.isEditing = true
                    return state
                }
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Filters"), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetListControllerEntries(presentationData: presentationData, state: state, filters: filtersWithCounts, suggestedFilters: suggestedFilters, settings: filterSettings), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.willDisappear = { _ in
        let _ = replaceRemoteChatListFilters(account: context.account).start()
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [ChatListFilterPresetListEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .preset(fromFilter) = fromEntry else {
            return .single(false)
        }
        var referenceFilter: ChatListFilter?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
            case let .preset(toFilter):
                referenceFilter = toFilter.preset
            default:
                if entries[toIndex] < fromEntry {
                    beforeAll = true
                } else {
                    afterAll = true
                }
            }
        } else {
            afterAll = true
        }

        return updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { filtersState in
            var filtersState = filtersState
            if let index = filtersState.filters.firstIndex(where: { $0.id == fromFilter.preset.id }) {
                filtersState.filters.remove(at: index)
            }
            if let referenceFilter = referenceFilter {
                var inserted = false
                for i in 0 ..< filtersState.filters.count {
                    if filtersState.filters[i].id == referenceFilter.id {
                        if fromIndex < toIndex {
                            filtersState.filters.insert(fromFilter.preset, at: i + 1)
                        } else {
                            filtersState.filters.insert(fromFilter.preset, at: i)
                        }
                        inserted = true
                        break
                    }
                }
                if !inserted {
                    filtersState.filters.append(fromFilter.preset)
                }
            } else if beforeAll {
                filtersState.filters.insert(fromFilter.preset, at: 0)
            } else if afterAll {
                filtersState.filters.append(fromFilter.preset)
            }
            return filtersState
        })
        |> map { _ -> Bool in
            return false
        }
    })
    
    return controller
}

