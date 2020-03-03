import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem
import AvatarNode

private final class ChatListFilterPresetControllerArguments {
    let context: AccountContext
    let updateState: ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void
    let openAddIncludePeer: () -> Void
    let openAddExcludePeer: () -> Void
    let deleteIncludePeer: (PeerId) -> Void
    let deleteExcludePeer: (PeerId) -> Void
    let setItemIdWithRevealedOptions: (ChatListFilterRevealedItemId?, ChatListFilterRevealedItemId?) -> Void
    let deleteIncludeCategory: (ChatListFilterIncludeCategory) -> Void
    let deleteExcludeCategory: (ChatListFilterExcludeCategory) -> Void
    let focusOnName: () -> Void
    
    init(
        context: AccountContext,
        updateState: @escaping ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void,
        openAddIncludePeer: @escaping () -> Void,
        openAddExcludePeer: @escaping () -> Void,
        deleteIncludePeer: @escaping (PeerId) -> Void,
        deleteExcludePeer: @escaping (PeerId) -> Void,
        setItemIdWithRevealedOptions: @escaping (ChatListFilterRevealedItemId?, ChatListFilterRevealedItemId?) -> Void,
        deleteIncludeCategory: @escaping (ChatListFilterIncludeCategory) -> Void,
        deleteExcludeCategory: @escaping (ChatListFilterExcludeCategory) -> Void,
        focusOnName: @escaping () -> Void
    ) {
        self.context = context
        self.updateState = updateState
        self.openAddIncludePeer = openAddIncludePeer
        self.openAddExcludePeer = openAddExcludePeer
        self.deleteIncludePeer = deleteIncludePeer
        self.deleteExcludePeer = deleteExcludePeer
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
        self.deleteIncludeCategory = deleteIncludeCategory
        self.deleteExcludeCategory = deleteExcludeCategory
        self.focusOnName = focusOnName
    }
}

private enum ChatListFilterPresetControllerSection: Int32 {
    case name
    case includePeers
    case excludePeers
}

private enum ChatListFilterPresetEntryStableId: Hashable {
    case index(Int)
    case peer(PeerId)
    case includePeerInfo
    case excludePeerInfo
    case includeCategory(ChatListFilterIncludeCategory)
    case excludeCategory(ChatListFilterExcludeCategory)
}

private enum ChatListFilterPresetEntrySortId: Comparable {
    case topIndex(Int)
    case includeIndex(Int)
    case excludeIndex(Int)
    
    static func <(lhs: ChatListFilterPresetEntrySortId, rhs: ChatListFilterPresetEntrySortId) -> Bool {
        switch lhs {
        case let .topIndex(lhsIndex):
            switch rhs {
            case let .topIndex(rhsIndex):
                return lhsIndex < rhsIndex
            case .includeIndex:
                return true
            case .excludeIndex:
                return true
            }
        case let .includeIndex(lhsIndex):
            switch rhs {
            case .topIndex:
                return false
            case let .includeIndex(rhsIndex):
                return lhsIndex < rhsIndex
            case .excludeIndex:
                return true
            }
        case let .excludeIndex(lhsIndex):
            switch rhs {
            case .topIndex:
                return false
            case .includeIndex:
                return false
            case let .excludeIndex(rhsIndex):
                return lhsIndex < rhsIndex
            }
        }
    }
}

private enum ChatListFilterIncludeCategory: Int32, CaseIterable {
    case contacts
    case nonContacts
    case smallGroups
    case largeGroups
    case channels
    case bots
    
    var category: ChatListFilterPeerCategories {
        switch self {
        case .contacts:
            return .contacts
        case .nonContacts:
            return .nonContacts
        case .smallGroups:
            return .smallGroups
        case .largeGroups:
            return .largeGroups
        case .channels:
            return .channels
        case .bots:
            return .bots
        }
    }
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .contacts:
            return "Contacts"
        case .nonContacts:
            return "Non-Contacts"
        case .smallGroups:
            return "Small Groups"
        case .largeGroups:
            return "Large Groups"
        case .channels:
            return "Channels"
        case .bots:
            return "Bots"
        }
    }
}

private enum ChatListFilterExcludeCategory: Int32, CaseIterable {
    case muted
    case read
    case archived
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .muted:
            return "Muted"
        case .read:
            return "Read"
        case .archived:
            return "Archived"
        }
    }
}

private extension ChatListFilterCategoryIcon {
    init(category: ChatListFilterIncludeCategory) {
        switch category {
        case .contacts:
            self = .contacts
        case .nonContacts:
            self = .nonContacts
        case .smallGroups:
            self = .smallGroups
        case .largeGroups:
            self = .largeGroups
        case .channels:
            self = .channels
        case .bots:
            self = .bots
        }
    }
    
    init(category: ChatListFilterExcludeCategory) {
        switch category {
        case .muted:
            self = .muted
        case .read:
            self = .read
        case .archived:
            self = .archived
        }
    }
}

private enum ChatListFilterRevealedItemId: Equatable {
    case peer(PeerId)
    case includeCategory(ChatListFilterIncludeCategory)
    case excludeCategory(ChatListFilterExcludeCategory)
}

private enum ChatListFilterPresetEntry: ItemListNodeEntry {
    case nameHeader(String)
    case name(placeholder: String, value: String)
    case includePeersHeader(String)
    case addIncludePeer(title: String)
    case includeCategory(index: Int, category: ChatListFilterIncludeCategory, title: String, isRevealed: Bool)
    case includePeer(index: Int, peer: RenderedPeer, isRevealed: Bool)
    case includePeerInfo(String)
    case excludePeersHeader(String)
    case addExcludePeer(title: String)
    case excludeCategory(index: Int, category: ChatListFilterExcludeCategory, title: String, isRevealed: Bool)
    case excludePeer(index: Int, peer: RenderedPeer, isRevealed: Bool)
    case excludePeerInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .nameHeader, .name:
            return ChatListFilterPresetControllerSection.name.rawValue
        case .includePeersHeader, .addIncludePeer, .includeCategory, .includePeer, .includePeerInfo:
            return ChatListFilterPresetControllerSection.includePeers.rawValue
        case .excludePeersHeader, .addExcludePeer, .excludeCategory, .excludePeer, .excludePeerInfo:
            return ChatListFilterPresetControllerSection.includePeers.rawValue
        }
    }
    
    var stableId: ChatListFilterPresetEntryStableId {
        switch self {
        case .nameHeader:
            return .index(0)
        case .name:
            return .index(1)
        case .includePeersHeader:
            return .index(2)
        case .addIncludePeer:
            return .index(3)
        case let .includeCategory(includeCategory):
            return .includeCategory(includeCategory.category)
        case .includePeerInfo:
            return .index(4)
        case .excludePeersHeader:
            return .index(5)
        case .addExcludePeer:
            return .index(6)
        case let .excludeCategory(excludeCategory):
            return .excludeCategory(excludeCategory.category)
        case .excludePeerInfo:
            return .index(7)
        case let .includePeer(peer):
            return .peer(peer.peer.peerId)
        case let .excludePeer(peer):
            return .peer(peer.peer.peerId)
        }
    }
    
    private var sortIndex: ChatListFilterPresetEntrySortId {
        switch self {
        case .nameHeader:
            return .topIndex(0)
        case .name:
            return .topIndex(1)
        case .includePeersHeader:
            return .includeIndex(0)
        case .addIncludePeer:
            return .includeIndex(1)
        case let .includeCategory(includeCategory):
            return .includeIndex(2 + includeCategory.index)
        case let .includePeer(includePeer):
            return .includeIndex(200 + includePeer.index)
        case .includePeerInfo:
            return .includeIndex(1000)
        case .excludePeersHeader:
            return .excludeIndex(0)
        case .addExcludePeer:
            return .excludeIndex(1)
        case let .excludeCategory(excludeCategory):
            return .excludeIndex(2 + excludeCategory.index)
        case let .excludePeer(excludePeer):
            return .excludeIndex(200 + excludePeer.index)
        case .excludePeerInfo:
            return .excludeIndex(1000)
        }
    }
    
    static func <(lhs: ChatListFilterPresetEntry, rhs: ChatListFilterPresetEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChatListFilterPresetControllerArguments
        switch self {
        case let .nameHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .name(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: placeholder, type: .regular(capitalization: true, autocorrection: false), clearType: .always, sectionId: self.section, textUpdated: { value in
                arguments.updateState { current in
                    var state = current
                    state.name = value
                    return state
                }
            }, action: {}, cleared: {
                arguments.focusOnName()
            })
        case .includePeersHeader(let text), .excludePeersHeader(let text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case .includePeerInfo(let text), .excludePeerInfo(let text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .addIncludePeer(title):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: title, alwaysPlain: false, sectionId: self.section, height: .peerList, editing: false, action: {
                arguments.openAddIncludePeer()
            })
        case let .includeCategory(_, category, title, isRevealed):
            return ChatListFilterPresetCategoryItem(
                presentationData: presentationData,
                title: title,
                icon: ChatListFilterCategoryIcon(category: category),
                isRevealed: isRevealed,
                sectionId: self.section,
                updatedRevealedOptions: { reveal in
                    if reveal {
                        arguments.setItemIdWithRevealedOptions(.includeCategory(category), nil)
                    } else {
                        arguments.setItemIdWithRevealedOptions(nil, .includeCategory(category))
                    }
                },
                remove: {
                    arguments.deleteIncludeCategory(category)
                }
            )
        case let .addExcludePeer(title):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: title, alwaysPlain: false, sectionId: self.section, height: .peerList, editing: false, action: {
                arguments.openAddExcludePeer()
            })
        case let .excludeCategory(_, category, title, isRevealed):
            return ChatListFilterPresetCategoryItem(
                presentationData: presentationData,
                title: title,
                icon: ChatListFilterCategoryIcon(category: category),
                isRevealed: isRevealed,
                sectionId: self.section,
                updatedRevealedOptions: { reveal in
                    if reveal {
                        arguments.setItemIdWithRevealedOptions(.excludeCategory(category), nil)
                    } else {
                        arguments.setItemIdWithRevealedOptions(nil, .excludeCategory(category))
                    }
                },
                remove: {
                    arguments.deleteExcludeCategory(category)
                }
            )
        case let .includePeer(_, peer, isRevealed):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .monthFirst, dateSeparator: ".", decimalSeparator: ".", groupingSeparator: "."), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.chatMainPeer!, height: .peerList, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: isRevealed), revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                arguments.deleteIncludePeer(peer.peerId)
            })]), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
                arguments.setItemIdWithRevealedOptions(lhs.flatMap { .peer($0) }, rhs.flatMap { .peer($0) })
            }, removePeer: { id in
                arguments.deleteIncludePeer(id)
            })
        case let .excludePeer(_, peer, isRevealed):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(timeFormat: .regular, dateFormat: .monthFirst, dateSeparator: ".", decimalSeparator: ".", groupingSeparator: "."), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.chatMainPeer!, height: .peerList, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: isRevealed), revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                arguments.deleteExcludePeer(peer.peerId)
            })]), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
                arguments.setItemIdWithRevealedOptions(lhs.flatMap { .peer($0) }, rhs.flatMap { .peer($0) })
            }, removePeer: { id in
                arguments.deleteExcludePeer(id)
            })
        }
    }
}

private struct ChatListFilterPresetControllerState: Equatable {
    var name: String
    var includeCategories: ChatListFilterPeerCategories
    var excludeMuted: Bool
    var excludeRead: Bool
    var excludeArchived: Bool
    var additionallyIncludePeers: [PeerId]
    var additionallyExcludePeers: [PeerId]
    
    var revealedItemId: ChatListFilterRevealedItemId?
    
    var isComplete: Bool {
        if self.name.isEmpty {
            return false
        }
        return true
    }
}

//TODO:localization
private func chatListFilterPresetControllerEntries(presentationData: PresentationData, state: ChatListFilterPresetControllerState, includePeers: [RenderedPeer], excludePeers: [RenderedPeer]) -> [ChatListFilterPresetEntry] {
    var entries: [ChatListFilterPresetEntry] = []
    
    entries.append(.nameHeader("FILTER NAME"))
    entries.append(.name(placeholder: "Filter Name", value: state.name))
    
    entries.append(.includePeersHeader("INCLUDED CHATS"))
    entries.append(.addIncludePeer(title: "Add Chats"))
    
    var includeCategoryIndex = 0
    for category in ChatListFilterIncludeCategory.allCases {
        if state.includeCategories.contains(category.category) {
            entries.append(.includeCategory(index: includeCategoryIndex, category: category, title: category.title(strings: presentationData.strings), isRevealed: state.revealedItemId == .includeCategory(category)))
        }
        includeCategoryIndex += 1
    }
    
    for peer in includePeers {
        entries.append(.includePeer(index: entries.count, peer: peer, isRevealed: state.revealedItemId == .peer(peer.peerId)))
    }
    
    entries.append(.includePeerInfo("Choose chats and types of chats that will appear in this filter."))
    
    entries.append(.excludePeersHeader("EXCLUDED CHATS"))
    entries.append(.addExcludePeer(title: "Add Chats"))
    
    var excludeCategoryIndex = 0
    for category in ChatListFilterExcludeCategory.allCases {
        let isExcluded: Bool
        switch category {
        case .read:
            isExcluded = state.excludeRead
        case .muted:
            isExcluded = state.excludeMuted
        case .archived:
            isExcluded = state.excludeArchived
        }
        
        if isExcluded {
            entries.append(.excludeCategory(index: excludeCategoryIndex, category: category, title: category.title(strings: presentationData.strings), isRevealed: state.revealedItemId == .excludeCategory(category)))
        }
        excludeCategoryIndex += 1
    }
    
    for peer in excludePeers {
        entries.append(.excludePeer(index: entries.count, peer: peer, isRevealed: state.revealedItemId == .peer(peer.peerId)))
    }
    
    entries.append(.excludePeerInfo("Choose chats and types of chats that will never appear in the filter."))
    
    return entries
}

private enum AdditionalCategoryId: Int {
    case contacts
    case nonContacts
    case smallGroups
    case largeGroups
    case channels
    case bots
}

private enum AdditionalExcludeCategoryId: Int {
    case muted
    case read
    case archived
}

func chatListFilterAddChatsController(context: AccountContext, filter: ChatListFilter) -> ViewController {
    return internalChatListFilterAddChatsController(context: context, filter: filter, applyAutomatically: true, updated: { _ in })
}
    
private func internalChatListFilterAddChatsController(context: AccountContext, filter: ChatListFilter, applyAutomatically: Bool, updated: @escaping (ChatListFilter) -> Void) -> ViewController {
    let additionalCategories: [ChatListNodeAdditionalCategory] = [
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.contacts.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: .white), color: .blue),
            title: "Contacts"
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.nonContacts.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/UnknownUser"), color: .white), color: .yellow),
            title: "Non-Contacts"
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.smallGroups.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Groups"), color: .white), color: .green),
            title: "Small Groups"
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.largeGroups.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/LargeGroup"), color: .white), color: .purple),
            title: "Large Groups"
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.channels.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: .white), color: .red),
            title: "Channels"
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.bots.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: .white), color: .violet),
            title: "Bots"
        )
    ]
    var selectedCategories = Set<Int>()
    let categoryMapping: [ChatListFilterPeerCategories: AdditionalCategoryId] = [
        .contacts: .contacts,
        .nonContacts: .nonContacts,
        .smallGroups: .smallGroups,
        .largeGroups: .largeGroups,
        .channels: .channels,
        .bots: .bots
    ]
    for (category, id) in categoryMapping {
        if filter.data.categories.contains(category) {
            selectedCategories.insert(id.rawValue)
        }
    }
    
    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(selectedChats: Set(filter.data.includePeers), additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories)), options: [], alwaysEnabled: true))
    controller.navigationPresentation = .modal
    let _ = (controller.result
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak controller] result in
        guard case let .result(peerIds, additionalCategoryIds) = result else {
            controller?.dismiss()
            return
        }
        
        var includePeers: [PeerId] = []
        for peerId in peerIds {
            switch peerId {
            case let .peer(id):
                includePeers.append(id)
            default:
                break
            }
        }
        includePeers.sort()
        
        var categories: ChatListFilterPeerCategories = []
        for id in additionalCategoryIds {
            if let index = categoryMapping.firstIndex(where: { $0.1.rawValue == id }) {
                categories.insert(categoryMapping[index].0)
            } else {
                assertionFailure()
            }
        }
        
        if applyAutomatically {
            let _ = (updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                for i in 0 ..< settings.filters.count {
                    if settings.filters[i].id == filter.id {
                        settings.filters[i].data.categories = categories
                        settings.filters[i].data.includePeers = includePeers
                        settings.filters[i].data.excludePeers = settings.filters[i].data.excludePeers.filter { !settings.filters[i].data.includePeers.contains($0) }
                    }
                }
                return settings
            })
            |> deliverOnMainQueue).start(next: { settings in
                controller?.dismiss()
                
                let _ = replaceRemoteChatListFilters(account: context.account).start()
            })
        } else {
            var filter = filter
            filter.data.categories = categories
            filter.data.includePeers = includePeers
            filter.data.excludePeers = filter.data.excludePeers.filter { !filter.data.includePeers.contains($0) }
            updated(filter)
            controller?.dismiss()
        }
    })
    return controller
}

private func internalChatListFilterExcludeChatsController(context: AccountContext, filter: ChatListFilter, applyAutomatically: Bool, updated: @escaping (ChatListFilter) -> Void) -> ViewController {
    let additionalCategories: [ChatListNodeAdditionalCategory] = [
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.muted.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Muted"), color: .white), color: .red),
            title: "Muted"
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.read.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: .white), color: .blue),
            title: "Read"
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.archived.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Archive"), color: .white), color: .yellow),
            title: "Archived"
        ),
    ]
    var selectedCategories = Set<Int>()
    if filter.data.excludeMuted {
        selectedCategories.insert(AdditionalExcludeCategoryId.muted.rawValue)
    }
    if filter.data.excludeRead {
        selectedCategories.insert(AdditionalExcludeCategoryId.read.rawValue)
    }
    if filter.data.excludeArchived {
        selectedCategories.insert(AdditionalExcludeCategoryId.archived.rawValue)
    }
    
    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(selectedChats: Set(filter.data.excludePeers), additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories)), options: [], alwaysEnabled: true))
    controller.navigationPresentation = .modal
    let _ = (controller.result
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak controller] result in
        guard case let .result(peerIds, additionalCategoryIds) = result else {
            controller?.dismiss()
            return
        }
        
        var excludePeers: [PeerId] = []
        for peerId in peerIds {
            switch peerId {
            case let .peer(id):
                excludePeers.append(id)
            default:
                break
            }
        }
        excludePeers.sort()
        
        if applyAutomatically {
            let _ = (updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                for i in 0 ..< settings.filters.count {
                    if settings.filters[i].id == filter.id {
                        settings.filters[i].data.excludeMuted = additionalCategoryIds.contains(AdditionalExcludeCategoryId.muted.rawValue)
                        settings.filters[i].data.excludeRead = additionalCategoryIds.contains(AdditionalExcludeCategoryId.read.rawValue)
                        settings.filters[i].data.excludeArchived = additionalCategoryIds.contains(AdditionalExcludeCategoryId.archived.rawValue)
                        settings.filters[i].data.excludePeers = excludePeers
                        settings.filters[i].data.includePeers = settings.filters[i].data.includePeers.filter { !settings.filters[i].data.excludePeers.contains($0) }
                    }
                }
                return settings
            })
            |> deliverOnMainQueue).start(next: { settings in
                controller?.dismiss()
                
                let _ = replaceRemoteChatListFilters(account: context.account).start()
            })
        } else {
            var filter = filter
            filter.data.excludeMuted = additionalCategoryIds.contains(AdditionalExcludeCategoryId.muted.rawValue)
            filter.data.excludeRead = additionalCategoryIds.contains(AdditionalExcludeCategoryId.read.rawValue)
            filter.data.excludeArchived = additionalCategoryIds.contains(AdditionalExcludeCategoryId.archived.rawValue)
            filter.data.excludePeers = excludePeers
            filter.data.includePeers = filter.data.includePeers.filter { !filter.data.excludePeers.contains($0) }
            updated(filter)
            controller?.dismiss()
        }
    })
    return controller
}

func chatListFilterPresetController(context: AccountContext, currentPreset: ChatListFilter?, updated: @escaping ([ChatListFilter]) -> Void) -> ViewController {
    let initialName: String
    if let currentPreset = currentPreset {
        initialName = currentPreset.title
    } else {
        initialName = "New Filter"
    }
    let initialState = ChatListFilterPresetControllerState(name: initialName, includeCategories: currentPreset?.data.categories ?? .all, excludeMuted: currentPreset?.data.excludeMuted ?? false, excludeRead: currentPreset?.data.excludeRead ?? false, excludeArchived: currentPreset?.data.excludeArchived ?? false, additionallyIncludePeers: currentPreset?.data.includePeers ?? [], additionallyExcludePeers: currentPreset?.data.excludePeers ?? [])
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    var skipStateAnimation = false
    
    let actionsDisposable = DisposableSet()
    
    let addPeerDisposable = MetaDisposable()
    actionsDisposable.add(addPeerDisposable)
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    var focusOnNameImpl: (() -> Void)?
    
    let arguments = ChatListFilterPresetControllerArguments(
        context: context,
        updateState: { f in
            updateState(f)
        },
        openAddIncludePeer: {
            let state = stateValue.with { $0 }
            let filter = ChatListFilter(id: currentPreset?.id ?? -1, title: state.name, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: state.additionallyIncludePeers, excludePeers: state.additionallyExcludePeers))
            
            let controller = internalChatListFilterAddChatsController(context: context, filter: filter, applyAutomatically: false, updated: { filter in
                skipStateAnimation = true
                updateState { state in
                    var state = state
                    state.additionallyIncludePeers = filter.data.includePeers
                    state.additionallyExcludePeers = filter.data.excludePeers
                    state.includeCategories = filter.data.categories
                    return state
                }
            })
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        },
        openAddExcludePeer: {
            let state = stateValue.with { $0 }
            let filter = ChatListFilter(id: currentPreset?.id ?? -1, title: state.name, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: state.additionallyIncludePeers, excludePeers: state.additionallyExcludePeers))
            
            let controller = internalChatListFilterExcludeChatsController(context: context, filter: filter, applyAutomatically: false, updated: { filter in
                skipStateAnimation = true
                updateState { state in
                    var state = state
                    state.additionallyIncludePeers = filter.data.includePeers
                    state.additionallyExcludePeers = filter.data.excludePeers
                    state.includeCategories = filter.data.categories
                    state.excludeRead = filter.data.excludeRead
                    state.excludeMuted = filter.data.excludeMuted
                    state.excludeArchived = filter.data.excludeArchived
                    return state
                }
            })
            presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        },
        deleteIncludePeer: { peerId in
            updateState { state in
                var state = state
                if let index = state.additionallyIncludePeers.firstIndex(of: peerId) {
                    state.additionallyIncludePeers.remove(at: index)
                }
                return state
            }
        },
        deleteExcludePeer: { peerId in
            updateState { state in
                var state = state
                if let index = state.additionallyExcludePeers.firstIndex(of: peerId) {
                    state.additionallyExcludePeers.remove(at: index)
                }
                return state
            }
        },
        setItemIdWithRevealedOptions: { itemId, fromItemId in
            updateState { state in
                var state = state
                if (itemId == nil && fromItemId == state.revealedItemId) || (itemId != nil && fromItemId == nil) {
                    state.revealedItemId = itemId
                }
                return state
            }
        },
        deleteIncludeCategory: { category in
            updateState { state in
                var state = state
                state.includeCategories.remove(category.category)
                return state
            }
        },
        deleteExcludeCategory: { category in
            updateState { state in
                var state = state
                switch category {
                case .muted:
                    state.excludeMuted = false
                case .read:
                    state.excludeRead = false
                case .archived:
                    state.excludeArchived = false
                }
                return state
            }
        },
        focusOnName: {
            focusOnNameImpl?()
        }
    )
    
    let currentPeers = Atomic<[PeerId: RenderedPeer]>(value: [:])
    let stateWithPeers = statePromise.get()
    |> mapToSignal { state -> Signal<(ChatListFilterPresetControllerState, [RenderedPeer], [RenderedPeer]), NoError> in
        let currentPeersValue = currentPeers.with { $0 }
        var included: [RenderedPeer] = []
        var excluded: [RenderedPeer] = []
        var missingPeers = false
        for peerId in state.additionallyIncludePeers {
            if let peer = currentPeersValue[peerId] {
                included.append(peer)
            } else {
                missingPeers = true
            }
        }
        for peerId in state.additionallyExcludePeers {
            if let peer = currentPeersValue[peerId] {
                excluded.append(peer)
            } else {
                missingPeers = true
            }
        }
        if missingPeers {
            return context.account.postbox.transaction { transaction -> (ChatListFilterPresetControllerState, [RenderedPeer], [RenderedPeer]) in
                var included: [RenderedPeer] = []
                var excluded: [RenderedPeer] = []
                var allPeers: [PeerId: RenderedPeer] = [:]
                for peerId in state.additionallyIncludePeers {
                    if let peer = transaction.getPeer(peerId) {
                        let renderedPeer = RenderedPeer(peer: peer)
                        included.append(renderedPeer)
                        allPeers[renderedPeer.peerId] = renderedPeer
                    }
                }
                for peerId in state.additionallyExcludePeers {
                    if let peer = transaction.getPeer(peerId) {
                        let renderedPeer = RenderedPeer(peer: peer)
                        excluded.append(renderedPeer)
                        allPeers[renderedPeer.peerId] = renderedPeer
                    }
                }
                let _ = currentPeers.swap(allPeers)
                return (state, included, excluded)
            }
        } else {
            return .single((state, included, excluded))
        }
    }
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        stateWithPeers
    )
    |> deliverOnMainQueue
    |> map { presentationData, stateWithPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (state, includePeers, excludePeers) = stateWithPeers
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(currentPreset == nil ? presentationData.strings.Common_Create : presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
            let state = stateValue.with { $0 }
            let preset = ChatListFilter(id: currentPreset?.id ?? -1, title: state.name, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: state.additionallyIncludePeers, excludePeers: state.additionallyExcludePeers))
            let _ = (updateChatListFilterSettingsInteractively(postbox: context.account.postbox, { settings in
                var preset = preset
                if currentPreset == nil {
                    preset.id = max(2, settings.filters.map({ $0.id + 1 }).max() ?? 2)
                }
                var settings = settings
                if let _ = currentPreset {
                    var found = false
                    for i in 0 ..< settings.filters.count {
                        if settings.filters[i].id == preset.id {
                            settings.filters[i] = preset
                            found = true
                        }
                    }
                    if !found {
                        settings.filters.append(preset)
                    }
                } else {
                    settings.filters.append(preset)
                }
                return settings
            })
            |> deliverOnMainQueue).start(next: { settings in
                updated(settings.filters)
                dismissImpl?()
                
                let _ = replaceRemoteChatListFilters(account: context.account).start()
            })
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(currentPreset != nil ? "Filter" : "Create Filter"), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetControllerEntries(presentationData: presentationData, state: state, includePeers: includePeers, excludePeers: excludePeers), style: .blocks, emptyStateItem: nil, animateChanges: !skipStateAnimation)
        skipStateAnimation = false
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, d in
        controller?.present(c, in: .window(.root), with: d)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    focusOnNameImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListSingleLineInputItemNode {
                itemNode.focus()
            }
        }
    }
    
    return controller
}

