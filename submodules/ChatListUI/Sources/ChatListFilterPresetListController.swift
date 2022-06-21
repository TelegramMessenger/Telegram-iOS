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
import ItemListPeerActionItem
import ChatListFilterSettingsHeaderItem

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
    case suggestedAddCustom
    case listHeader
    case preset(Int32)
    case addItem
    case listFooter
}

private struct PresetIndex: Equatable {
    let value: Int
    
    static func ==(lhs: PresetIndex, rhs: PresetIndex) -> Bool {
        return true
    }
}

private enum ChatListFilterPresetListEntry: ItemListNodeEntry {
    case screenHeader(String)
    case suggestedListHeader(String)
    case suggestedPreset(index: PresetIndex, title: String, label: String, preset: ChatListFilterData)
    case suggestedAddCustom(String)
    case listHeader(String)
    case preset(index: PresetIndex, title: String, label: String, preset: ChatListFilter, canBeReordered: Bool, canBeDeleted: Bool, isEditing: Bool)
    case addItem(text: String, isEditing: Bool)
    case listFooter(String)
    
    var section: ItemListSectionId {
        switch self {
        case .screenHeader:
            return ChatListFilterPresetListSection.screenHeader.rawValue
        case .suggestedListHeader, .suggestedPreset, .suggestedAddCustom:
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
        case let .preset(index, _, _, _, _, _, _):
            return 101 + index.value
        case .addItem:
            return 1000
        case .listFooter:
            return 1001
        case .suggestedListHeader:
            return 1002
        case let .suggestedPreset(index, _, _, _):
            return 1003 + index.value
        case .suggestedAddCustom:
            return 2000
        }
    }
    
    var stableId: ChatListFilterPresetListEntryStableId {
        switch self {
        case .screenHeader:
            return .screenHeader
        case .suggestedListHeader:
            return .suggestedListHeader
        case let .suggestedPreset(_, _, _, preset):
            return .suggestedPreset(preset)
        case .suggestedAddCustom:
            return .suggestedAddCustom
        case .listHeader:
            return .listHeader
        case let .preset(_, _, _, preset, _, _, _):
            return .preset(preset.id)
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
            return ChatListFilterSettingsHeaderItem(context: arguments.context, theme: presentationData.theme, text: text, animation: .folders, sectionId: self.section)
        case let .suggestedListHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .suggestedPreset(_, title, label, preset):
            return ChatListFilterPresetListSuggestedItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, installAction: {
                arguments.addSuggestedPresed(title, preset)
            }, tag: nil)
        case let .suggestedAddCustom(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: nil, title: text, sectionId: self.section, height: .generic, editing: false, action: {
                arguments.addNew()
            })
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

private func filtersWithAppliedOrder(filters: [(ChatListFilter, Int)], order: [Int32]?) -> [(ChatListFilter, Int)] {
    let sortedFilters: [(ChatListFilter, Int)]
    if let updatedFilterOrder = order {
        var updatedFilters: [(ChatListFilter, Int)] = []
        for id in updatedFilterOrder {
            if let index = filters.firstIndex(where: { $0.0.id == id }) {
                updatedFilters.append(filters[index])
            }
        }
        sortedFilters = updatedFilters
    } else {
        sortedFilters = filters
    }
    return sortedFilters
}

private func chatListFilterPresetListControllerEntries(presentationData: PresentationData, state: ChatListFilterPresetListControllerState, filters: [(ChatListFilter, Int)], updatedFilterOrder: [Int32]?, suggestedFilters: [ChatListFeaturedFilter], settings: ChatListFilterSettings) -> [ChatListFilterPresetListEntry] {
    var entries: [ChatListFilterPresetListEntry] = []

    entries.append(.screenHeader(presentationData.strings.ChatListFolderSettings_Info))
    
    let filteredSuggestedFilters = suggestedFilters.filter { suggestedFilter in
        for (filter, _) in filters {
            if filter.data == suggestedFilter.data {
                return false
            }
        }
        return true
    }
    
    if !filters.isEmpty || suggestedFilters.isEmpty {
        entries.append(.listHeader(presentationData.strings.ChatListFolderSettings_FoldersSection))
        
        for (filter, chatCount) in filtersWithAppliedOrder(filters: filters, order: updatedFilterOrder) {
            entries.append(.preset(index: PresetIndex(value: entries.count), title: filter.title, label: chatCount == 0 ? "" : "\(chatCount)", preset: filter, canBeReordered: filters.count > 1, canBeDeleted: true, isEditing: state.isEditing))
        }
        if filters.count < 10 {
            entries.append(.addItem(text: presentationData.strings.ChatListFolderSettings_NewFolder, isEditing: state.isEditing))
        }
        entries.append(.listFooter(presentationData.strings.ChatListFolderSettings_EditFoldersInfo))
    }
    
    if !filteredSuggestedFilters.isEmpty && filters.count < 10 {
        entries.append(.suggestedListHeader(presentationData.strings.ChatListFolderSettings_RecommendedFoldersSection))
        for filter in filteredSuggestedFilters {
            entries.append(.suggestedPreset(index: PresetIndex(value: entries.count), title: filter.title, label: filter.description, preset: filter.data))
        }
        if filters.isEmpty {
            entries.append(.suggestedAddCustom(presentationData.strings.ChatListFolderSettings_RecommendedNewFolder))
        }
    }
    
    return entries
}

public enum ChatListFilterPresetListControllerMode {
    case `default`
    case modal
}

public func chatListFilterPresetListController(context: AccountContext, mode: ChatListFilterPresetListControllerMode, dismissed: (() -> Void)? = nil) -> ViewController {
    let initialState = ChatListFilterPresetListControllerState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((ChatListFilterPresetListControllerState) -> ChatListFilterPresetListControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let arguments = ChatListFilterPresetListControllerArguments(context: context,
    addSuggestedPresed: { title, data in
        let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
            var filters = filters
            let id = context.engine.peers.generateNewChatListFilterId(filters: filters)
            filters.insert(ChatListFilter(id: id, title: title, emoticon: nil, data: data), at: 0)
            return filters
        }
        |> deliverOnMainQueue).start(next: { _ in
        })
    }, openPreset: { preset in
        pushControllerImpl?(chatListFilterPresetController(context: context, currentPreset: preset, updated: { _ in }))
    }, addNew: {
        pushControllerImpl?(chatListFilterPresetController(context: context, currentPreset: nil, updated: { _ in }))
    }, setItemWithRevealedOptions: { preset, fromPreset in
        updateState { state in
            var state = state
            if (preset == nil && fromPreset == state.revealedPreset) || (preset != nil && fromPreset == nil) {
                state.revealedPreset = preset
            }
            return state
        }
    }, removePreset: { id in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.ChatList_RemoveFolderConfirmation),
                ActionSheetButtonItem(title: presentationData.strings.ChatList_RemoveFolderAction, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    
                    let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                        var filters = filters
                        if let index = filters.firstIndex(where: { $0.id == id }) {
                            filters.remove(at: index)
                        }
                        return filters
                    }
                    |> deliverOnMainQueue).start()
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    })
    
    let filtersWithCountsSignal = context.engine.peers.updatedChatListFilters()
    |> distinctUntilChanged
    |> mapToSignal { filters -> Signal<[(ChatListFilter, Int)], NoError> in
        return .single(filters.map { filter -> (ChatListFilter, Int) in
            return (filter, 0)
        })
    }
    
    let featuredFilters = context.account.postbox.preferencesView(keys: [PreferencesKeys.chatListFiltersFeaturedState])
    |> map { preferences -> [ChatListFeaturedFilter] in
        guard let state = preferences.values[PreferencesKeys.chatListFiltersFeaturedState]?.get(ChatListFiltersFeaturedState.self) else {
            return []
        }
        return state.filters
    }
    |> distinctUntilChanged
    
    let filtersWithCounts = Promise<[(ChatListFilter, Int)]>()
    filtersWithCounts.set(filtersWithCountsSignal)
    
    let updatedFilterOrder = Promise<[Int32]?>(nil)
    
    let preferences = context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatListFilterSettings])
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        filtersWithCounts.get(),
        preferences,
        updatedFilterOrder.get(),
        featuredFilters
    )
    |> map { presentationData, state, filtersWithCountsValue, preferences, updatedFilterOrderValue, suggestedFilters -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let filterSettings = preferences.values[ApplicationSpecificPreferencesKeys.chatListFilterSettings]?.get(ChatListFilterSettings.self) ?? ChatListFilterSettings.default
        let leftNavigationButton: ItemListNavigationButton?
        switch mode {
        case .default:
            leftNavigationButton = nil
        case .modal:
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Close), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }
        let rightNavigationButton: ItemListNavigationButton?
        if state.isEditing {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                let _ = (updatedFilterOrder.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak updatedFilterOrder] updatedFilterOrderValue in
                    if let updatedFilterOrderValue = updatedFilterOrderValue {
                        let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                            var updatedFilters: [ChatListFilter] = []
                            for id in updatedFilterOrderValue {
                                if let index = filters.firstIndex(where: { $0.id == id }) {
                                    updatedFilters.append(filters[index])
                                }
                            }
                            for filter in filters {
                                if !updatedFilters.contains(where: { $0.id == filter.id }) {
                                    updatedFilters.append(filter)
                                }
                            }
                            
                            return updatedFilters
                        }
                        |> deliverOnMainQueue).start(next: { _ in
                            filtersWithCounts.set(filtersWithCountsSignal)
                            let _ = (filtersWithCounts.get()
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { _ in
                                updatedFilterOrder?.set(.single(nil))
                                
                                updateState { state in
                                    var state = state
                                    state.isEditing = false
                                    return state
                                }
                            })
                        })
                    } else {
                        updateState { state in
                            var state = state
                            state.isEditing = false
                            return state
                        }
                    }
                })
            })
        } else if !filtersWithCountsValue.isEmpty {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                updateState { state in
                    var state = state
                    state.isEditing = true
                    return state
                }
            })
        } else {
            rightNavigationButton = nil
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChatListFolderSettings_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetListControllerEntries(presentationData: presentationData, state: state, filters: filtersWithCountsValue, updatedFilterOrder: updatedFilterOrderValue, suggestedFilters: suggestedFilters, settings: filterSettings), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.isOpaqueWhenInOverlay = true
    controller.blocksBackgroundWhenInOverlay = true
    switch mode {
    case .default:
        controller.navigationPresentation = .default
    case .modal:
        controller.navigationPresentation = .modal
    }
    controller.didDisappear = { _ in
        dismissed?()
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [ChatListFilterPresetListEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .preset(_, _, _, fromPreset, _, _, _) = fromEntry else {
            return .single(false)
        }
        var referenceFilter: ChatListFilter?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
            case let .preset(_, _, _, preset, _, _, _):
                referenceFilter = preset
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

        return combineLatest(
            updatedFilterOrder.get() |> take(1),
            filtersWithCounts.get() |> take(1)
        )
        |> mapToSignal { updatedFilterOrderValue, filtersWithCountsValue -> Signal<Bool, NoError> in
            var filters = filtersWithAppliedOrder(filters: filtersWithCountsValue, order: updatedFilterOrderValue).map { $0.0 }
            let initialOrder = filters.map { $0.id }
            
            if let index = filters.firstIndex(where: { $0.id == fromPreset.id }) {
                filters.remove(at: index)
            }
            if let referenceFilter = referenceFilter {
                var inserted = false
                for i in 0 ..< filters.count {
                    if filters[i].id == referenceFilter.id {
                        if fromIndex < toIndex {
                            filters.insert(fromPreset, at: i + 1)
                        } else {
                            filters.insert(fromPreset, at: i)
                        }
                        inserted = true
                        break
                    }
                }
                if !inserted {
                    filters.append(fromPreset)
                }
            } else if beforeAll {
                filters.insert(fromPreset, at: 0)
            } else if afterAll {
                filters.append(fromPreset)
            }
            
            let updatedOrder = filters.map { $0.id }
            if initialOrder != updatedOrder {
                updatedFilterOrder.set(.single(updatedOrder))
                return .single(true)
            } else {
                return .single(false)
            }
        }
    })
    
    return controller
}
