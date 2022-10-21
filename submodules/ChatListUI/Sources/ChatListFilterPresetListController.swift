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
import PremiumUI
import UndoUI

private final class ChatListFilterPresetListControllerArguments {
    let context: AccountContext
    
    let addSuggestedPressed: (String, ChatListFilterData) -> Void
    let openPreset: (ChatListFilter) -> Void
    let addNew: () -> Void
    let setItemWithRevealedOptions: (Int32?, Int32?) -> Void
    let removePreset: (Int32) -> Void
    
    init(context: AccountContext, addSuggestedPressed: @escaping (String, ChatListFilterData) -> Void, openPreset: @escaping (ChatListFilter) -> Void, addNew: @escaping () -> Void, setItemWithRevealedOptions: @escaping (Int32?, Int32?) -> Void, removePreset: @escaping (Int32) -> Void) {
        self.context = context
        self.addSuggestedPressed = addSuggestedPressed
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
    case preset(index: PresetIndex, title: String, label: String, preset: ChatListFilter, canBeReordered: Bool, canBeDeleted: Bool, isEditing: Bool, isAllChats: Bool, isDisabled: Bool)
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
        case let .preset(index, _, _, _, _, _, _, _, _):
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
        case let .preset(_, _, _, preset, _, _, _, _, _):
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
                arguments.addSuggestedPressed(title, preset)
            }, tag: nil)
        case let .suggestedAddCustom(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: nil, title: text, sectionId: self.section, height: .generic, editing: false, action: {
                arguments.addNew()
            })
        case let .listHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .preset(_, title, label, preset, canBeReordered, canBeDeleted, isEditing, isAllChats, isDisabled):
            return ChatListFilterPresetListItem(presentationData: presentationData, preset: preset, title: title, label: label, editing: ChatListFilterPresetListItemEditing(editable: true, editing: isEditing, revealed: false), canBeReordered: canBeReordered, canBeDeleted: canBeDeleted, isAllChats: isAllChats, isDisabled: isDisabled, sectionId: self.section, action: {
                if isDisabled {
                    arguments.addNew()
                } else {
                    arguments.openPreset(preset)
                }
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

private func chatListFilterPresetListControllerEntries(presentationData: PresentationData, state: ChatListFilterPresetListControllerState, filters: [(ChatListFilter, Int)], updatedFilterOrder: [Int32]?, suggestedFilters: [ChatListFeaturedFilter], settings: ChatListFilterSettings, isPremium: Bool, limits: EngineConfiguration.UserLimits, premiumLimits: EngineConfiguration.UserLimits) -> [ChatListFilterPresetListEntry] {
    var entries: [ChatListFilterPresetListEntry] = []

    entries.append(.screenHeader(presentationData.strings.ChatListFolderSettings_Info))
    
    let filteredSuggestedFilters = suggestedFilters.filter { suggestedFilter in
        for (filter, _) in filters {
            if case let .filter(_, _, _, data) = filter {
                if data == suggestedFilter.data {
                    return false
                }
            }
        }
        return true
    }
    
    let actualFilters = filters.filter { filter in
        if case .allChats = filter.0 {
            return false
        }
        return true
    }
    
    if !filters.isEmpty || suggestedFilters.isEmpty {
        entries.append(.listHeader(presentationData.strings.ChatListFolderSettings_FoldersSection))
        
        var folderCount = 0
        for (filter, chatCount) in filtersWithAppliedOrder(filters: filters, order: updatedFilterOrder) {
            if case .allChats = filter {
                entries.append(.preset(index: PresetIndex(value: entries.count), title: "", label: "", preset: filter, canBeReordered: filters.count > 1, canBeDeleted: false, isEditing: state.isEditing, isAllChats: true, isDisabled: false))
            }
            if case let .filter(_, title, _, _) = filter {
                folderCount += 1
                entries.append(.preset(index: PresetIndex(value: entries.count), title: title, label: chatCount == 0 ? "" : "\(chatCount)", preset: filter, canBeReordered: filters.count > 1, canBeDeleted: true, isEditing: state.isEditing, isAllChats: false, isDisabled: !isPremium && folderCount > limits.maxFoldersCount))
            }
        }
        
        entries.append(.addItem(text: presentationData.strings.ChatListFolderSettings_NewFolder, isEditing: state.isEditing))
        
        entries.append(.listFooter(presentationData.strings.ChatListFolderSettings_EditFoldersInfo))
    }
    
    if !filteredSuggestedFilters.isEmpty && actualFilters.count < limits.maxFoldersCount {
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
    
    let filtersWithCountsSignal = context.engine.peers.updatedChatListFilters()
    |> distinctUntilChanged
    |> mapToSignal { filters -> Signal<[(ChatListFilter, Int)], NoError> in
        return .single(filters.map { filter -> (ChatListFilter, Int) in
            return (filter, 0)
        })
    }
    
    let filtersWithCounts = Promise<[(ChatListFilter, Int)]>()
    filtersWithCounts.set(filtersWithCountsSignal)
    
    let arguments = ChatListFilterPresetListControllerArguments(context: context,
    addSuggestedPressed: { title, data in
        let _ = combineLatest(
            queue: Queue.mainQueue(),
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            ),
            filtersWithCounts.get() |> take(1)
        ).start(next: { result, filters in
            let (accountPeer, limits, premiumLimits) = result
            let isPremium = accountPeer?.isPremium ?? false
            
            let filters = filters.filter { filter in
                if case .allChats = filter.0 {
                    return false
                }
                return true
            }
            
            let limit = limits.maxFoldersCount
            let premiumLimit = premiumLimits.maxFoldersCount
            if filters.count >= premiumLimit {
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {})
                pushControllerImpl?(controller)
                return
            } else if filters.count >= limit && !isPremium {
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                    let controller = PremiumIntroScreen(context: context, source: .folders)
                    replaceImpl?(controller)
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                pushControllerImpl?(controller)
                return
            }
            let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                var filters = filters
                let id = context.engine.peers.generateNewChatListFilterId(filters: filters)
                filters.insert(.filter(id: id, title: title, emoticon: nil, data: data), at: 0)
                return filters
            }
            |> deliverOnMainQueue).start(next: { _ in
            })
        })
    }, openPreset: { preset in
        pushControllerImpl?(chatListFilterPresetController(context: context, currentPreset: preset, updated: { _ in }))
    }, addNew: {
        let _ = combineLatest(
            queue: Queue.mainQueue(),
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            ),
            filtersWithCounts.get() |> take(1)
        ).start(next: { result, filters in
            let (accountPeer, limits, premiumLimits) = result
            let isPremium = accountPeer?.isPremium ?? false
            
            let filters = filters.filter { filter in
                if case .allChats = filter.0 {
                    return false
                }
                return true
            }
            
            let limit = limits.maxFoldersCount
            let premiumLimit = premiumLimits.maxFoldersCount
            if filters.count >= premiumLimit {
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {})
                pushControllerImpl?(controller)
                return
            } else if filters.count >= limit && !isPremium {
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                    let controller = PremiumIntroScreen(context: context, source: .folders)
                    replaceImpl?(controller)
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                pushControllerImpl?(controller)
                return
            }
            pushControllerImpl?(chatListFilterPresetController(context: context, currentPreset: nil, updated: { _ in }))
        })
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
        
    let featuredFilters = context.account.postbox.preferencesView(keys: [PreferencesKeys.chatListFiltersFeaturedState])
    |> map { preferences -> [ChatListFeaturedFilter] in
        guard let state = preferences.values[PreferencesKeys.chatListFiltersFeaturedState]?.get(ChatListFiltersFeaturedState.self) else {
            return []
        }
        return state.filters
    }
    |> distinctUntilChanged
        
    let updatedFilterOrder = Promise<[Int32]?>(nil)
    
    let preferences = context.account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.chatListFilterSettings])
    
    let limits = context.engine.data.get(
        TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
        TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
    )
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        filtersWithCounts.get(),
        preferences,
        updatedFilterOrder.get(),
        featuredFilters,
        context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
        limits
    )
    |> map { presentationData, state, filtersWithCountsValue, preferences, updatedFilterOrderValue, suggestedFilters, peer, allLimits -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPremium = peer?.isPremium ?? false
        let limits = allLimits.0
        let premiumLimits = allLimits.1
        
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
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetListControllerEntries(presentationData: presentationData, state: state, filters: filtersWithCountsValue, updatedFilterOrder: updatedFilterOrderValue, suggestedFilters: suggestedFilters, settings: filterSettings, isPremium: isPremium, limits: limits, premiumLimits: premiumLimits), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
    }
    
    var previousOrder: [Int32]?
    
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
        guard case let .preset(_, _, _, fromPreset, _, _, _, _, _) = fromEntry else {
            return .single(false)
        }
        var referenceFilter: ChatListFilter?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
            case let .preset(_, _, _, preset, _, _, _, _, _):
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
    controller.setReorderCompleted({ (entries: [ChatListFilterPresetListEntry]) -> Void in
        let _ = (combineLatest(
            updatedFilterOrder.get() |> take(1),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        )
        |> deliverOnMainQueue).start(next: { order, peer in
            let isPremium = peer?.isPremium ?? false
            if !isPremium, let order = order, order.first != 0 {
                updatedFilterOrder.set(.single(previousOrder))

                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_reorder", scale: 0.05, colors: [:], title: nil, text: presentationData.strings.ChatListFolderSettings_SubscribeToMoveAll, customUndoText: presentationData.strings.ChatListFolderSettings_SubscribeToMoveAllAction), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                    if case .undo = action {
                        pushControllerImpl?(PremiumIntroScreen(context: context, source: .folders))
                    }
                    return false })
                )
            } else {
                previousOrder = order
            }
        })
    })
    
    return controller
}
