import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import ItemListPeerActionItem
import ChatListFilterSettingsHeaderItem
import PremiumUI
import UndoUI
import ChatFolderLinkPreviewScreen

private final class ChatListFilterPresetListControllerArguments {
    let context: AccountContext
    
    let addSuggestedPressed: (ChatFolderTitle, ChatListFilterData) -> Void
    let openPreset: (ChatListFilter) -> Void
    let addNew: () -> Void
    let setItemWithRevealedOptions: (Int32?, Int32?) -> Void
    let removePreset: (Int32) -> Void
    let updateDisplayTags: (Bool) -> Void
    let updateDisplayTagsLocked: () -> Void
    
    init(context: AccountContext, addSuggestedPressed: @escaping (ChatFolderTitle, ChatListFilterData) -> Void, openPreset: @escaping (ChatListFilter) -> Void, addNew: @escaping () -> Void, setItemWithRevealedOptions: @escaping (Int32?, Int32?) -> Void, removePreset: @escaping (Int32) -> Void, updateDisplayTags: @escaping (Bool) -> Void, updateDisplayTagsLocked: @escaping () -> Void) {
        self.context = context
        self.addSuggestedPressed = addSuggestedPressed
        self.openPreset = openPreset
        self.addNew = addNew
        self.setItemWithRevealedOptions = setItemWithRevealedOptions
        self.removePreset = removePreset
        self.updateDisplayTags = updateDisplayTags
        self.updateDisplayTagsLocked = updateDisplayTagsLocked
    }
}

private enum ChatListFilterPresetListSection: Int32 {
    case screenHeader
    case suggested
    case list
    case tags
}

public enum ChatListFilterPresetListEntryTag: ItemListItemTag {
    case displayTags
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? ChatListFilterPresetListEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}


private func stringForUserCount(_ peers: [EnginePeer.Id: SelectivePrivacyPeer], strings: PresentationStrings) -> String {
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
    case addItem
    case preset(Int32)
    case listFooter
    case displayTags
    case displayTagsFooter
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
    case suggestedPreset(index: PresetIndex, title: ChatFolderTitle, label: String, preset: ChatListFilterData)
    case suggestedAddCustom(String)
    case listHeader(String)
    case preset(index: PresetIndex, title: ChatFolderTitle, label: String, preset: ChatListFilter, canBeReordered: Bool, canBeDeleted: Bool, isEditing: Bool, isAllChats: Bool, isDisabled: Bool, displayTags: Bool)
    case addItem(text: String, isEditing: Bool)
    case listFooter(String)
    case displayTags(Bool?)
    case displayTagsFooter
    
    var section: ItemListSectionId {
        switch self {
        case .screenHeader:
            return ChatListFilterPresetListSection.screenHeader.rawValue
        case .suggestedListHeader, .suggestedPreset, .suggestedAddCustom:
            return ChatListFilterPresetListSection.suggested.rawValue
        case .listHeader, .preset, .addItem, .listFooter:
            return ChatListFilterPresetListSection.list.rawValue
        case .displayTags, .displayTagsFooter:
            return ChatListFilterPresetListSection.tags.rawValue
        }
    }
    
    var sortId: Int {
        switch self {
        case .screenHeader:
            return 0
        case .listHeader:
            return 100
        case .addItem:
            return 101
        case let .preset(index, _, _, _, _, _, _, _, _, _):
            return 102 + index.value
        case .listFooter:
            return 1001
        case .suggestedListHeader:
            return 1002
        case let .suggestedPreset(index, _, _, _):
            return 1003 + index.value
        case .suggestedAddCustom:
            return 2000
        case .displayTags:
            return 3000
        case .displayTagsFooter:
            return 3001
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
        case let .preset(_, _, _, preset, _, _, _, _, _, _):
            return .preset(preset.id)
        case .addItem:
            return .addItem
        case .listFooter:
            return .listFooter
        case .displayTags:
            return .displayTags
        case .displayTagsFooter:
            return .displayTagsFooter
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
            return ChatListFilterPresetListSuggestedItem(presentationData: presentationData, title: title.text, label: label, sectionId: self.section, style: .blocks, installAction: {
                arguments.addSuggestedPressed(title, preset)
            }, tag: nil)
        case let .suggestedAddCustom(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: nil, title: text, sectionId: self.section, height: .generic, editing: false, action: {
                arguments.addNew()
            })
        case let .listHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, multiline: true, sectionId: self.section)
        case let .preset(_, title, label, preset, canBeReordered, canBeDeleted, isEditing, isAllChats, isDisabled, displayTags):
            var resolvedColor: UIColor?
            if displayTags, case let .filter(_, _, _, data) = preset {
                let tagColor = data.color
                if let tagColor {
                    resolvedColor = arguments.context.peerNameColors.getChatFolderTag(tagColor, dark: presentationData.theme.overallDarkAppearance).main
                }
            }
            
            return ChatListFilterPresetListItem(context: arguments.context, presentationData: presentationData, preset: preset, title: title, label: label, tagColor: resolvedColor, editing: ChatListFilterPresetListItemEditing(editable: true, editing: isEditing, revealed: false), canBeReordered: canBeReordered, canBeDeleted: canBeDeleted, isAllChats: isAllChats, isDisabled: isDisabled, sectionId: self.section, action: {
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
        case let .displayTags(value):
            return ItemListSwitchItem(presentationData: presentationData, title: presentationData.strings.ChatListFilterList_ShowTags, value: value == true, enableInteractiveChanges: value != nil, enabled: true, displayLocked: value == nil, sectionId: self.section, style: .blocks, updated: { updatedValue in
                if value != nil {
                    arguments.updateDisplayTags(updatedValue)
                } else {
                    arguments.updateDisplayTagsLocked()
                }
            }, activatedWhileDisabled: {
                arguments.updateDisplayTagsLocked()
            }, tag: ChatListFilterPresetListEntryTag.displayTags)
        case .displayTagsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(presentationData.strings.ChatListFilterList_ShowTagsFooter), sectionId: self.section)
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

private func chatListFilterPresetListControllerEntries(presentationData: PresentationData, state: ChatListFilterPresetListControllerState, filters: [(ChatListFilter, Int)], updatedFilterOrder: [Int32]?, suggestedFilters: [ChatListFeaturedFilter], displayTags: Bool, isPremium: Bool, limits: EngineConfiguration.UserLimits, premiumLimits: EngineConfiguration.UserLimits) -> [ChatListFilterPresetListEntry] {
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
    
    
    entries.append(.listHeader(presentationData.strings.ChatListFolderSettings_FoldersSection))
    
    entries.append(.addItem(text: presentationData.strings.ChatListFilterList_CreateFolder, isEditing: state.isEditing))
    
    var effectiveDisplayTags: Bool?
    if isPremium {
        effectiveDisplayTags = displayTags
    }
    
    if !filters.isEmpty || suggestedFilters.isEmpty {
        var folderCount = 0
        for (filter, chatCount) in filtersWithAppliedOrder(filters: filters, order: updatedFilterOrder) {
            if case .allChats = filter {
                entries.append(.preset(index: PresetIndex(value: entries.count), title: ChatFolderTitle(text: "", entities: [], enableAnimations: true), label: "", preset: filter, canBeReordered: filters.count > 1, canBeDeleted: false, isEditing: state.isEditing, isAllChats: true, isDisabled: false, displayTags: effectiveDisplayTags == true))
            }
            if case let .filter(_, title, _, _) = filter {
                folderCount += 1
                entries.append(.preset(index: PresetIndex(value: entries.count), title: title, label: chatCount == 0 ? "" : "\(chatCount)", preset: filter, canBeReordered: filters.count > 1, canBeDeleted: true, isEditing: state.isEditing, isAllChats: false, isDisabled: !isPremium && folderCount > limits.maxFoldersCount, displayTags: effectiveDisplayTags == true))
            }
        }
        
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
    
    entries.append(.displayTags(effectiveDisplayTags))
    entries.append(.displayTagsFooter)
    
    return entries
}

public enum ChatListFilterPresetListControllerMode {
    case `default`
    case modal
}

public func chatListFilterPresetListController(context: AccountContext, mode: ChatListFilterPresetListControllerMode, scrollToTags: Bool = false, dismissed: (() -> Void)? = nil) -> ViewController {
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
    
    let animateNextShowHideTagsTransition = Atomic<Bool?>(value: nil)
    
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
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                    return true
                })
                pushControllerImpl?(controller)
                return
            } else if filters.count >= limit && !isPremium {
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                    let controller = PremiumIntroScreen(context: context, source: .folders)
                    replaceImpl?(controller)
                    return true
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
                filters.append(.filter(id: id, title: title, emoticon: nil, data: data))
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
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                    return true
                })
                pushControllerImpl?(controller)
                return
            } else if filters.count >= limit && !isPremium {
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumLimitScreen(context: context, subject: .folders, count: Int32(filters.count), action: {
                    let controller = PremiumIntroScreen(context: context, source: .folders)
                    replaceImpl?(controller)
                    return true
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
        let _ = (context.engine.peers.currentChatListFilters()
        |> take(1)
        |> deliverOnMainQueue).start(next: { filters in
            guard let filter = filters.first(where: { $0.id == id }) else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            if case let .filter(_, title, _, data) = filter, data.isShared {
                let _ = (combineLatest(
                    context.engine.data.get(
                        EngineDataList(data.includePeers.peers.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))),
                        EngineDataMap(data.includePeers.peers.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init(id:)))
                    ),
                    context.engine.peers.getExportedChatFolderLinks(id: id),
                    context.engine.peers.requestLeaveChatFolderSuggestions(folderId: id)
                )
                |> deliverOnMainQueue).start(next: { peerData, links, defaultSelectedPeerIds in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    
                    let peers = peerData.0
                    var memberCounts: [EnginePeer.Id: Int] = [:]
                    for (id, count) in peerData.1 {
                        if let count {
                            memberCounts[id] = count
                        }
                    }
                    
                    var hasLinks = false
                    if let links, !links.isEmpty {
                        hasLinks = true
                    }
                    
                    let confirmDeleteFolder: () -> Void = {
                        let filteredPeers = peers.compactMap { $0 }.filter { peer in
                            if case .channel = peer {
                                return true
                            } else {
                                return false
                            }
                        }
                        
                        if filteredPeers.isEmpty {
                            let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                                var filters = filters
                                if let index = filters.firstIndex(where: { $0.id == id }) {
                                    filters.remove(at: index)
                                }
                                return filters
                            }
                            |> deliverOnMainQueue).start()
                        } else {
                            let previewScreen = ChatFolderLinkPreviewScreen(
                                context: context,
                                subject: .remove(folderId: id, defaultSelectedPeerIds: defaultSelectedPeerIds),
                                contents: ChatFolderLinkContents(
                                    localFilterId: id,
                                    title: title,
                                    peers: filteredPeers,
                                    alreadyMemberPeerIds: Set(),
                                    memberCounts: memberCounts
                                )
                            )
                            pushControllerImpl?(previewScreen)
                        }
                    }
                    
                    if hasLinks {
                        presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatList_AlertDeleteFolderTitle, text: presentationData.strings.ChatList_AlertDeleteFolderText, actions: [
                            TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                                confirmDeleteFolder()
                            }),
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {
                            })
                        ]))
                    } else {
                        confirmDeleteFolder()
                    }
                })
            } else {
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
                            |> deliverOnMainQueue).startStandalone()
                        })
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                presentControllerImpl?(actionSheet)
            }
        })
    }, updateDisplayTags: { value in
        context.engine.peers.updateChatListFiltersDisplayTags(isEnabled: value)
    }, updateDisplayTagsLocked: {
        var replaceImpl: ((ViewController) -> Void)?
        let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .folderTags, forceDark: false, action: {
            let controller = context.sharedContext.makePremiumIntroController(context: context, source: .folderTags, forceDark: false, dismissed: nil)
            replaceImpl?(controller)
        }, dismissed: nil)
        replaceImpl = { [weak controller] c in
            controller?.replace(with: c)
        }
        pushControllerImpl?(controller)
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
    
    let previousDisplayTags = Atomic<Bool?>(value: nil)
    
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
        limits,
        context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.ChatList.FiltersDisplayTags()
        )
    )
    |> map { presentationData, state, filtersWithCountsValue, preferences, updatedFilterOrderValue, suggestedFilters, peer, allLimits, displayTags -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPremium = peer?.isPremium ?? false
        let limits = allLimits.0
        let premiumLimits = allLimits.1
        
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
                |> deliverOnMainQueue).startStandalone(next: { [weak updatedFilterOrder] updatedFilterOrderValue in
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
        
        let previousDisplayTagsValue = previousDisplayTags.swap(displayTags)
        if let previousDisplayTagsValue, previousDisplayTagsValue != displayTags {
            let _ = animateNextShowHideTagsTransition.swap(displayTags)
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChatListFolderSettings_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let entries = chatListFilterPresetListControllerEntries(presentationData: presentationData, state: state, filters: filtersWithCountsValue, updatedFilterOrder: updatedFilterOrderValue, suggestedFilters: suggestedFilters, displayTags: displayTags, isPremium: isPremium, limits: limits, premiumLimits: premiumLimits)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, initialScrollToItem: scrollToTags ? ListViewScrollToItem(index: entries.count - 1, position: .center(.bottom), animated: true, curve: .Spring(duration: 0.4), directionHint: .Down) : nil, animateChanges: true)
        
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
        guard case let .preset(_, _, _, fromPreset, _, _, _, _, _, _) = fromEntry else {
            return .single(false)
        }
        var referenceFilter: ChatListFilter?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
            case let .preset(_, _, _, preset, _, _, _, _, _, _):
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
                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_reorder", scale: 0.05, colors: [:], title: nil, text: presentationData.strings.ChatListFolderSettings_SubscribeToMoveAll, customUndoText: presentationData.strings.ChatListFolderSettings_SubscribeToMoveAllAction, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { action in
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
    controller.afterTransactionCompleted = { [weak controller] in
        guard let toggleDirection = animateNextShowHideTagsTransition.swap(nil) else {
            return
        }
        
        guard let controller else {
            return
        }
        var presetItemNodes: [ChatListFilterPresetListItemNode] = []
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatListFilterPresetListItemNode {
                presetItemNodes.append(itemNode)
            }
        }
        
        var delay: Double = 0.0
        for itemNode in presetItemNodes.reversed() {
            if toggleDirection {
                itemNode.animateTagColorIn(delay: delay)
            }
            delay += 0.02
        }
    }
    
    return controller
}
