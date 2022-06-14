import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ItemListUI
import AccountContext
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem
import AvatarNode
import ChatListFilterSettingsHeaderItem
import PremiumUI

private enum FilterSection: Int32, Hashable {
    case include
    case exclude
}

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
    let expandSection: (FilterSection) -> Void
    
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
        focusOnName: @escaping () -> Void,
        expandSection: @escaping (FilterSection) -> Void
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
        self.expandSection = expandSection
    }
}

private enum ChatListFilterPresetControllerSection: Int32 {
    case screenHeader
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
    case includeExpand
    case excludeExpand
}

private enum ChatListFilterPresetEntrySortId: Comparable {
    case screenHeader
    case topIndex(Int)
    case includeIndex(Int)
    case excludeIndex(Int)
    
    static func <(lhs: ChatListFilterPresetEntrySortId, rhs: ChatListFilterPresetEntrySortId) -> Bool {
        switch lhs {
        case .screenHeader:
            switch rhs {
            case .screenHeader:
                return false
            default:
                return true
            }
        case let .topIndex(lhsIndex):
            switch rhs {
            case .screenHeader:
                return false
            case let .topIndex(rhsIndex):
                return lhsIndex < rhsIndex
            case .includeIndex:
                return true
            case .excludeIndex:
                return true
            }
        case let .includeIndex(lhsIndex):
            switch rhs {
            case .screenHeader:
                return false
            case .topIndex:
                return false
            case let .includeIndex(rhsIndex):
                return lhsIndex < rhsIndex
            case .excludeIndex:
                return true
            }
        case let .excludeIndex(lhsIndex):
            switch rhs {
            case .screenHeader:
                return false
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
    case groups
    case channels
    case bots
    
    var category: ChatListFilterPeerCategories {
        switch self {
        case .contacts:
            return .contacts
        case .nonContacts:
            return .nonContacts
        case .groups:
            return .groups
        case .channels:
            return .channels
        case .bots:
            return .bots
        }
    }
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .contacts:
            return strings.ChatListFolder_CategoryContacts
        case .nonContacts:
            return strings.ChatListFolder_CategoryNonContacts
        case .groups:
            return strings.ChatListFolder_CategoryGroups
        case .channels:
            return strings.ChatListFolder_CategoryChannels
        case .bots:
            return strings.ChatListFolder_CategoryBots
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
            return strings.ChatListFolder_CategoryMuted
        case .read:
            return strings.ChatListFolder_CategoryRead
        case .archived:
            return strings.ChatListFolder_CategoryArchived
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
        case .groups:
            self = .groups
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
    case screenHeader
    case nameHeader(String)
    case name(placeholder: String, value: String)
    case includePeersHeader(String)
    case addIncludePeer(title: String)
    case includeCategory(index: Int, category: ChatListFilterIncludeCategory, title: String, isRevealed: Bool)
    case includePeer(index: Int, peer: EngineRenderedPeer, isRevealed: Bool)
    case includePeerInfo(String)
    case excludePeersHeader(String)
    case addExcludePeer(title: String)
    case excludeCategory(index: Int, category: ChatListFilterExcludeCategory, title: String, isRevealed: Bool)
    case excludePeer(index: Int, peer: EngineRenderedPeer, isRevealed: Bool)
    case excludePeerInfo(String)
    case includeExpand(String)
    case excludeExpand(String)
    
    var section: ItemListSectionId {
        switch self {
        case .screenHeader:
            return ChatListFilterPresetControllerSection.screenHeader.rawValue
        case .nameHeader, .name:
            return ChatListFilterPresetControllerSection.name.rawValue
        case .includePeersHeader, .addIncludePeer, .includeCategory, .includePeer, .includePeerInfo, .includeExpand:
            return ChatListFilterPresetControllerSection.includePeers.rawValue
        case .excludePeersHeader, .addExcludePeer, .excludeCategory, .excludePeer, .excludePeerInfo, .excludeExpand:
            return ChatListFilterPresetControllerSection.excludePeers.rawValue
        }
    }
    
    var stableId: ChatListFilterPresetEntryStableId {
        switch self {
        case .screenHeader:
            return .index(0)
        case .nameHeader:
            return .index(1)
        case .name:
            return .index(2)
        case .includePeersHeader:
            return .index(3)
        case .addIncludePeer:
            return .index(4)
        case let .includeCategory(_, category, _, _):
            return .includeCategory(category)
        case .includeExpand:
            return .index(5)
        case .includePeerInfo:
            return .index(6)
        case .excludePeersHeader:
            return .index(7)
        case .addExcludePeer:
            return .index(8)
        case let .excludeCategory(_, category, _, _):
            return .excludeCategory(category)
        case .excludeExpand:
            return .index(9)
        case .excludePeerInfo:
            return .index(10)
        case let .includePeer(_, peer, _):
            return .peer(peer.peerId)
        case let .excludePeer(_, peer, _):
            return .peer(peer.peerId)
        }
    }
    
    private var sortIndex: ChatListFilterPresetEntrySortId {
        switch self {
        case .screenHeader:
            return .screenHeader
        case .nameHeader:
            return .topIndex(0)
        case .name:
            return .topIndex(1)
        case .includePeersHeader:
            return .includeIndex(0)
        case .addIncludePeer:
            return .includeIndex(1)
        case let .includeCategory(index, _, _, _):
            return .includeIndex(2 + index)
        case let .includePeer(index, _, _):
            return .includeIndex(200 + index)
        case .includeExpand:
            return .includeIndex(999)
        case .includePeerInfo:
            return .includeIndex(1000)
        case .excludePeersHeader:
            return .excludeIndex(0)
        case .addExcludePeer:
            return .excludeIndex(1)
        case let .excludeCategory(index, _, _, _):
            return .excludeIndex(2 + index)
        case let .excludePeer(index, _, _):
            return .excludeIndex(200 + index)
        case .excludeExpand:
            return .excludeIndex(999)
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
        case .screenHeader:
            return ChatListFilterSettingsHeaderItem(context: arguments.context, theme: presentationData.theme, text: "", animation: .newFolder, sectionId: self.section)
        case let .nameHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .name(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: placeholder, type: .regular(capitalization: true, autocorrection: false), clearType: .always, maxLength: 12, sectionId: self.section, textUpdated: { value in
                arguments.updateState { current in
                    var state = current
                    state.name = value
                    state.changedName = true
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
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.chatMainPeer!, height: .peerList, aliasHandling: .threatSelfAsSaved, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: isRevealed), revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                arguments.deleteIncludePeer(peer.peerId)
            })]), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
                arguments.setItemIdWithRevealedOptions(lhs.flatMap { .peer($0) }, rhs.flatMap { .peer($0) })
            }, removePeer: { id in
                arguments.deleteIncludePeer(id)
            })
        case let .excludePeer(_, peer, isRevealed):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.chatMainPeer!, height: .peerList, aliasHandling: .threatSelfAsSaved, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: isRevealed), revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                arguments.deleteExcludePeer(peer.peerId)
            })]), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
                arguments.setItemIdWithRevealedOptions(lhs.flatMap { .peer($0) }, rhs.flatMap { .peer($0) })
            }, removePeer: { id in
                arguments.deleteExcludePeer(id)
            })
        case let .includeExpand(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(presentationData.theme), title: text, sectionId: self.section, editing: false, action: {
                arguments.expandSection(.include)
            })
        case let .excludeExpand(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(presentationData.theme), title: text, sectionId: self.section, editing: false, action: {
                arguments.expandSection(.exclude)
            })
        }
    }
}

private struct ChatListFilterPresetControllerState: Equatable {
    var name: String
    var changedName: Bool
    var includeCategories: ChatListFilterPeerCategories
    var excludeMuted: Bool
    var excludeRead: Bool
    var excludeArchived: Bool
    var additionallyIncludePeers: [PeerId]
    var additionallyExcludePeers: [PeerId]
    
    var revealedItemId: ChatListFilterRevealedItemId?
    var expandedSections: Set<FilterSection>
    
    var isComplete: Bool {
        if self.name.isEmpty {
            return false
        }
        
        let defaultCategories: ChatListFilterPeerCategories = .all
        let defaultExcludeArchived = true
        let defaultExcludeMuted = false
        let defaultExcludeRead = false
        
        if self.includeCategories == defaultCategories &&
           self.excludeArchived == defaultExcludeArchived &&
           self.excludeMuted == defaultExcludeMuted &&
           self.excludeRead == defaultExcludeRead {
           return false
        }
        
        if self.includeCategories.isEmpty && self.additionallyIncludePeers.isEmpty {
            return false
        }
        
        return true
    }
}

private func chatListFilterPresetControllerEntries(presentationData: PresentationData, isNewFilter: Bool, state: ChatListFilterPresetControllerState, includePeers: [EngineRenderedPeer], excludePeers: [EngineRenderedPeer], isPremium: Bool, limit: Int32) -> [ChatListFilterPresetEntry] {
    var entries: [ChatListFilterPresetEntry] = []
    
    if isNewFilter {
        entries.append(.screenHeader)
    }
    
    entries.append(.nameHeader(presentationData.strings.ChatListFolder_NameSectionHeader))
    entries.append(.name(placeholder: presentationData.strings.ChatListFolder_NamePlaceholder, value: state.name))
    
    entries.append(.includePeersHeader(presentationData.strings.ChatListFolder_IncludedSectionHeader))
    if includePeers.count < limit {
        entries.append(.addIncludePeer(title: presentationData.strings.ChatListFolder_AddChats))
    }
    
    var includeCategoryIndex = 0
    for category in ChatListFilterIncludeCategory.allCases {
        if state.includeCategories.contains(category.category) {
            entries.append(.includeCategory(index: includeCategoryIndex, category: category, title: category.title(strings: presentationData.strings), isRevealed: state.revealedItemId == .includeCategory(category)))
        }
        includeCategoryIndex += 1
    }
    
    if !includePeers.isEmpty {
        var count = 0
        for peer in includePeers {
            entries.append(.includePeer(index: entries.count, peer: peer, isRevealed: state.revealedItemId == .peer(peer.peerId)))
            count += 1
            if includePeers.count >= 7 && count == 5 && !state.expandedSections.contains(.include) {
                break
            }
        }
        if count < includePeers.count {
            entries.append(.includeExpand(presentationData.strings.ChatListFilter_ShowMoreChats(Int32(includePeers.count - count))))
        }
    }
    
    entries.append(.includePeerInfo(presentationData.strings.ChatListFolder_IncludeSectionInfo))
    
    entries.append(.excludePeersHeader(presentationData.strings.ChatListFolder_ExcludedSectionHeader))
    entries.append(.addExcludePeer(title: presentationData.strings.ChatListFolder_AddChats))
    
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
    
    if !excludePeers.isEmpty {
        var count = 0
        for peer in excludePeers {
            entries.append(.excludePeer(index: entries.count, peer: peer, isRevealed: state.revealedItemId == .peer(peer.peerId)))
            count += 1
            if excludePeers.count >= 7 && count == 5 && !state.expandedSections.contains(.exclude) {
                break
            }
        }
        if count < excludePeers.count {
            entries.append(.excludeExpand(presentationData.strings.ChatListFilter_ShowMoreChats(Int32(excludePeers.count - count))))
        }
    }
    
    entries.append(.excludePeerInfo(presentationData.strings.ChatListFolder_ExcludeSectionInfo))
    
    return entries
}

private enum AdditionalCategoryId: Int {
    case contacts
    case nonContacts
    case groups
    case channels
    case bots
}

private enum AdditionalExcludeCategoryId: Int {
    case muted
    case read
    case archived
}

func chatListFilterAddChatsController(context: AccountContext, filter: ChatListFilter, allFilters: [ChatListFilter], limit: Int32, premiumLimit: Int32, isPremium: Bool) -> ViewController {
    return internalChatListFilterAddChatsController(context: context, filter: filter, allFilters: allFilters, applyAutomatically: true, limit: limit, premiumLimit: premiumLimit, isPremium: isPremium, updated: { _ in })
}
    
private func internalChatListFilterAddChatsController(context: AccountContext, filter: ChatListFilter, allFilters: [ChatListFilter], applyAutomatically: Bool, limit: Int32, premiumLimit: Int32, isPremium: Bool, updated: @escaping (ChatListFilter) -> Void) -> ViewController {
    guard case let .filter(_, _, _, filterData) = filter else {
        return ViewController(navigationBarPresentationData: nil)
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let additionalCategories: [ChatListNodeAdditionalCategory] = [
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.contacts.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: .white), color: .blue),
            title: presentationData.strings.ChatListFolder_CategoryContacts
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.nonContacts.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/UnknownUser"), color: .white), color: .yellow),
            title: presentationData.strings.ChatListFolder_CategoryNonContacts
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.groups.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Groups"), color: .white), color: .green),
            title: presentationData.strings.ChatListFolder_CategoryGroups
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.channels.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Channels"), color: .white), color: .red),
            title: presentationData.strings.ChatListFolder_CategoryChannels
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalCategoryId.bots.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: .white), color: .violet),
            title: presentationData.strings.ChatListFolder_CategoryBots
        )
    ]
    var selectedCategories = Set<Int>()
    let categoryMapping: [ChatListFilterPeerCategories: AdditionalCategoryId] = [
        .contacts: .contacts,
        .nonContacts: .nonContacts,
        .groups: .groups,
        .channels: .channels,
        .bots: .bots
    ]
    for (category, id) in categoryMapping {
        if filterData.categories.contains(category) {
            selectedCategories.insert(id.rawValue)
        }
    }
    
    var pushImpl: ((ViewController) -> Void)?
    
    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(title: presentationData.strings.ChatListFolder_IncludeChatsTitle, selectedChats: Set(filterData.includePeers.peers), additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories), chatListFilters: allFilters), options: [], filters: [], alwaysEnabled: true, limit: isPremium ? premiumLimit : limit, reachedLimit: { count in
        if count >= premiumLimit {
            let limitController = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: min(premiumLimit, count), action: {})
            pushImpl?(limitController)
            return
        } else if count >= limit && !isPremium {
            var replaceImpl: ((ViewController) -> Void)?
            let limitController = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: count, action: {
                let introController = PremiumIntroScreen(context: context, source: .chatsPerFolder)
                replaceImpl?(introController)
            })
            replaceImpl = { [weak limitController] c in
                limitController?.replace(with: c)
            }
            pushImpl?(limitController)
            
            return
        }
    }))
    controller.navigationPresentation = .modal
    
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    
    let _ = (controller.result
    |> take(1)
    |> deliverOnMainQueue)
    .start(next: { [weak controller] result in
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
            let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                var filters = filters
                for i in 0 ..< filters.count {
                    if filters[i].id == filter.id {
                        if case let .filter(id, title, emoticon, data) = filter {
                            var updatedData = data
                            updatedData.categories = categories
                            updatedData.includePeers.setPeers(includePeers)
                            updatedData.excludePeers = updatedData.excludePeers.filter { !updatedData.includePeers.peers.contains($0) }
                            filters[i] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
                        }
                    }
                }
                return filters
            }
            |> deliverOnMainQueue).start(next: { _ in
                controller?.dismiss()
            })
        } else {
            var filter = filter
            if case let .filter(id, title, emoticon, data) = filter {
                var updatedData = data
                updatedData.categories = categories
                updatedData.includePeers.setPeers(includePeers)
                updatedData.excludePeers = updatedData.excludePeers.filter { !updatedData.includePeers.peers.contains($0) }
                filter = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
            }
            updated(filter)
            controller?.dismiss()
        }
    })
    return controller
}

private func internalChatListFilterExcludeChatsController(context: AccountContext, filter: ChatListFilter, allFilters: [ChatListFilter], applyAutomatically: Bool, updated: @escaping (ChatListFilter) -> Void) -> ViewController {
    guard case let .filter(_, _, _, filterData) = filter else {
        return ViewController(navigationBarPresentationData: nil)
    }
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let additionalCategories: [ChatListNodeAdditionalCategory] = [
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.muted.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Muted"), color: .white), color: .red),
            title: presentationData.strings.ChatListFolder_CategoryMuted
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.read.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: .white), color: .blue),
            title: presentationData.strings.ChatListFolder_CategoryRead
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.archived.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Archive"), color: .white), color: .yellow),
            title: presentationData.strings.ChatListFolder_CategoryArchived
        ),
    ]
    var selectedCategories = Set<Int>()
    if filterData.excludeMuted {
        selectedCategories.insert(AdditionalExcludeCategoryId.muted.rawValue)
    }
    if filterData.excludeRead {
        selectedCategories.insert(AdditionalExcludeCategoryId.read.rawValue)
    }
    if filterData.excludeArchived {
        selectedCategories.insert(AdditionalExcludeCategoryId.archived.rawValue)
    }
    
    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(title: presentationData.strings.ChatListFolder_ExcludeChatsTitle, selectedChats: Set(filterData.excludePeers), additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories), chatListFilters: allFilters), options: [], filters: [], alwaysEnabled: true, limit: 100))
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
            let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                var filters = filters
                for i in 0 ..< filters.count {
                    if filters[i].id == filter.id {
                        if case let .filter(id, title, emoticon, data) = filter {
                            var updatedData = data
                            updatedData.excludeMuted = additionalCategoryIds.contains(AdditionalExcludeCategoryId.muted.rawValue)
                            updatedData.excludeRead = additionalCategoryIds.contains(AdditionalExcludeCategoryId.read.rawValue)
                            updatedData.excludeArchived = additionalCategoryIds.contains(AdditionalExcludeCategoryId.archived.rawValue)
                            updatedData.excludePeers = excludePeers
                            updatedData.includePeers.setPeers(updatedData.includePeers.peers.filter { !updatedData.excludePeers.contains($0) })
                            filters[i] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
                        }
                    }
                }
                return filters
            }
            |> deliverOnMainQueue).start(next: { _ in
                controller?.dismiss()
            })
        } else {
            var filter = filter
            if case let .filter(id, title, emoticon, data) = filter {
                var updatedData = data
                updatedData.excludeMuted = additionalCategoryIds.contains(AdditionalExcludeCategoryId.muted.rawValue)
                updatedData.excludeRead = additionalCategoryIds.contains(AdditionalExcludeCategoryId.read.rawValue)
                updatedData.excludeArchived = additionalCategoryIds.contains(AdditionalExcludeCategoryId.archived.rawValue)
                updatedData.excludePeers = excludePeers
                updatedData.includePeers.setPeers(updatedData.includePeers.peers.filter { !updatedData.excludePeers.contains($0) })
                filter = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
            }
            updated(filter)
            controller?.dismiss()
        }
    })
    return controller
}

enum ChatListFilterType {
    case generic
    case unmuted
    case unread
    case channels
    case groups
    case bots
    case contacts
    case nonContacts
}

func chatListFilterType(_ data: ChatListFilterData) -> ChatListFilterType {
    let filterType: ChatListFilterType
    
    if data.categories == .all {
        if data.excludeRead {
            filterType = .unread
        } else if data.excludeMuted {
            filterType = .unmuted
        } else {
            filterType = .generic
        }
    } else {
        if data.categories == .channels {
            filterType = .channels
        } else if data.categories == .groups {
            filterType = .groups
        } else if data.categories == .bots {
            filterType = .bots
        } else if data.categories == .contacts {
            filterType = .contacts
        } else if data.categories == .nonContacts {
            filterType = .nonContacts
        } else {
            filterType = .generic
        }
    }
    
    return filterType
}

private extension ChatListFilter {
    var title: String {
        if case let .filter(_, title, _, _) = self {
            return title
        } else {
            return ""
        }
    }
    
    var emoticon: String? {
        if case let .filter(_, _, emoticon, _) = self {
            return emoticon
        } else {
            return nil
        }
    }
    
    var data: ChatListFilterData? {
        if case let .filter(_, _, _, data) = self {
            return data
        } else {
            return nil
        }
    }
}

func chatListFilterPresetController(context: AccountContext, currentPreset: ChatListFilter?, updated: @escaping ([ChatListFilter]) -> Void) -> ViewController {
    let initialName: String
    if let currentPreset = currentPreset {
        initialName = currentPreset.title
    } else {
        initialName = ""
    }
    let initialState = ChatListFilterPresetControllerState(name: initialName, changedName: currentPreset != nil, includeCategories: currentPreset?.data?.categories ?? [], excludeMuted: currentPreset?.data?.excludeMuted ?? false, excludeRead: currentPreset?.data?.excludeRead ?? false, excludeArchived: currentPreset?.data?.excludeArchived ?? false, additionallyIncludePeers: currentPreset?.data?.includePeers.peers ?? [], additionallyExcludePeers: currentPreset?.data?.excludePeers ?? [], expandedSections: [])
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            var state = f(current)
            if !state.changedName {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var includePeers = ChatListFilterIncludePeers()
                includePeers.setPeers(state.additionallyIncludePeers)
                let filter: ChatListFilter = .filter(id: currentPreset?.id ?? -1, title: state.name, emoticon: currentPreset?.emoticon, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
                if let data = filter.data {
                    switch chatListFilterType(data) {
                    case .generic:
                        state.name = initialName
                    case .unmuted:
                        state.name = presentationData.strings.ChatListFolder_NameNonMuted
                    case .unread:
                        state.name = presentationData.strings.ChatListFolder_NameUnread
                    case .channels:
                        state.name = presentationData.strings.ChatListFolder_NameChannels
                    case .groups:
                        state.name = presentationData.strings.ChatListFolder_NameGroups
                    case .bots:
                        state.name = presentationData.strings.ChatListFolder_NameBots
                    case .contacts:
                        state.name = presentationData.strings.ChatListFolder_NameContacts
                    case .nonContacts:
                        state.name = presentationData.strings.ChatListFolder_NameNonContacts
                    }
                }
            }
            return state
        })
    }
    var skipStateAnimation = false
    
    let actionsDisposable = DisposableSet()
    
    let addPeerDisposable = MetaDisposable()
    actionsDisposable.add(addPeerDisposable)
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var focusOnNameImpl: (() -> Void)?
    
    let currentPeers = Atomic<[PeerId: EngineRenderedPeer]>(value: [:])
    let stateWithPeers = statePromise.get()
    |> mapToSignal { state -> Signal<(ChatListFilterPresetControllerState, [EngineRenderedPeer], [EngineRenderedPeer]), NoError> in
        let currentPeersValue = currentPeers.with { $0 }
        var included: [EngineRenderedPeer] = []
        var excluded: [EngineRenderedPeer] = []
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
            return context.engine.data.get(
                EngineDataMap(
                    state.additionallyIncludePeers.map { peerId -> TelegramEngine.EngineData.Item.Peer.RenderedPeer in
                        return TelegramEngine.EngineData.Item.Peer.RenderedPeer(id: peerId)
                    }
                ),
                EngineDataMap(
                    state.additionallyExcludePeers.map { peerId -> TelegramEngine.EngineData.Item.Peer.RenderedPeer in
                        return TelegramEngine.EngineData.Item.Peer.RenderedPeer(id: peerId)
                    }
                )
            )
            |> map { additionallyIncludePeers, additionallyExcludePeers -> (ChatListFilterPresetControllerState, [EngineRenderedPeer], [EngineRenderedPeer]) in
                var included: [EngineRenderedPeer] = []
                var excluded: [EngineRenderedPeer] = []
                var allPeers: [EnginePeer.Id: EngineRenderedPeer] = [:]
                for peerId in state.additionallyIncludePeers {
                    if let renderedPeerValue = additionallyIncludePeers[peerId], let renderedPeer = renderedPeerValue {
                        included.append(renderedPeer)
                        allPeers[renderedPeer.peerId] = renderedPeer
                    }
                }
                for peerId in state.additionallyExcludePeers {
                    if let renderedPeerValue = additionallyExcludePeers[peerId], let renderedPeer = renderedPeerValue {
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
    
    let arguments = ChatListFilterPresetControllerArguments(
        context: context,
        updateState: { f in
            updateState(f)
        },
        openAddIncludePeer: {
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                    TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                    TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
                ),
                stateWithPeers |> take(1)
            ).start(next: { result, state in
                let (accountPeer, limits, premiumLimits) = result
                let isPremium = accountPeer?.isPremium ?? false
                
                let (_, currentIncludePeers, _) = state

                let limit = limits.maxFolderChatsCount
                let premiumLimit = premiumLimits.maxFolderChatsCount
                
                if currentIncludePeers.count >= premiumLimit {
                    let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(currentIncludePeers.count), action: {})
                    pushControllerImpl?(controller)
                    return
                } else if currentIncludePeers.count >= limit && !isPremium {
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = PremiumLimitScreen(context: context, subject: .chatsPerFolder, count: Int32(currentIncludePeers.count), action: {
                        let controller = PremiumIntroScreen(context: context, source: .chatsPerFolder)
                        replaceImpl?(controller)
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    pushControllerImpl?(controller)
                    return
                }
                
                let state = stateValue.with { $0 }
                var includePeers = ChatListFilterIncludePeers()
                includePeers.setPeers(state.additionallyIncludePeers)
                let filter: ChatListFilter = .filter(id: currentPreset?.id ?? -1, title: state.name, emoticon: currentPreset?.emoticon, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
                
                let _ = (context.engine.peers.currentChatListFilters()
                |> deliverOnMainQueue).start(next: { filters in
                    let controller = internalChatListFilterAddChatsController(context: context, filter: filter, allFilters: filters, applyAutomatically: false, limit: limits.maxFolderChatsCount, premiumLimit: premiumLimits.maxFolderChatsCount, isPremium: isPremium, updated: { filter in
                        skipStateAnimation = true
                        updateState { state in
                            var state = state
                            state.additionallyIncludePeers = filter.data?.includePeers.peers ?? []
                            state.additionallyExcludePeers = filter.data?.excludePeers ?? []
                            state.includeCategories = filter.data?.categories ?? []
                            return state
                        }
                    })
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            })
        },
        openAddExcludePeer: {
            let state = stateValue.with { $0 }
            var includePeers = ChatListFilterIncludePeers()
            includePeers.setPeers(state.additionallyIncludePeers)
            let filter: ChatListFilter = .filter(id: currentPreset?.id ?? -1, title: state.name, emoticon: currentPreset?.emoticon, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
            
            let _ = (context.engine.peers.currentChatListFilters()
            |> deliverOnMainQueue).start(next: { filters in
                let controller = internalChatListFilterExcludeChatsController(context: context, filter: filter, allFilters: filters, applyAutomatically: false, updated: { filter in
                    skipStateAnimation = true
                    updateState { state in
                        var updatedState = state
                        updatedState.additionallyIncludePeers = filter.data?.includePeers.peers ?? []
                        updatedState.additionallyExcludePeers = filter.data?.excludePeers ?? []
                        updatedState.includeCategories = filter.data?.categories ?? []
                        updatedState.excludeRead = filter.data?.excludeRead ?? false
                        updatedState.excludeMuted = filter.data?.excludeMuted ?? false
                        updatedState.excludeArchived = filter.data?.excludeArchived ?? false
                        return updatedState
                    }
                })
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
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
        },
        expandSection: { section in
            updateState { state in
                var state = state
                state.expandedSections.insert(section)
                return state
            }
        }
    )
        
    var attemptNavigationImpl: (() -> Bool)?
    let applyImpl: (() -> Void)? = {
        let state = stateValue.with { $0 }
        let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
            var includePeers = ChatListFilterIncludePeers()
            includePeers.setPeers(state.additionallyIncludePeers)
            
            var filterId = currentPreset?.id ?? -1
            if currentPreset == nil {
                filterId = context.engine.peers.generateNewChatListFilterId(filters: filters)
            }
            var updatedFilter: ChatListFilter = .filter(id: filterId, title: state.name, emoticon: currentPreset?.emoticon, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
            
            var filters = filters
            if let _ = currentPreset {
                var found = false
                for i in 0 ..< filters.count {
                    if filters[i].id == updatedFilter.id, case let .filter(_, _, _, data) = filters[i] {
                        var updatedData = updatedFilter.data ?? data
                        var includePeers = data.includePeers
                        includePeers.setPeers(state.additionallyIncludePeers)
                        updatedData.includePeers = includePeers
                        updatedFilter = .filter(id: filterId, title: state.name, emoticon: currentPreset?.emoticon, data: updatedData)
                        filters[i] = updatedFilter
                        found = true
                    }
                }
                if !found {
                    filters = filters.filter { listFilter in
                        if listFilter.title == updatedFilter.title && listFilter.data == updatedFilter.data {
                            return false
                        }
                        return true
                    }
                    filters.append(updatedFilter)
                }
            } else {
                filters.append(updatedFilter)
            }
            return filters
        }
        |> deliverOnMainQueue).start(next: { filters in
            updated(filters)
            dismissImpl?()
        })
    }
    
    var previousState = stateValue.with { $0 }
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        stateWithPeers,
        context.account.postbox.peerView(id: context.account.peerId),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        )
    )
    |> deliverOnMainQueue
    |> map { presentationData, stateWithPeers, peerView, premiumLimits -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (state, includePeers, excludePeers) = stateWithPeers
        
        let isPremium = peerView.peers[peerView.peerId]?.isPremium ?? false
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            if attemptNavigationImpl?() ?? true {
                dismissImpl?()
            }
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(currentPreset == nil ? presentationData.strings.Common_Create : presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
            applyImpl?()
        })
        
        let previousStateValue = previousState
        previousState = state
        if previousStateValue.expandedSections != state.expandedSections {
            skipStateAnimation = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(currentPreset != nil ? presentationData.strings.ChatListFolder_TitleEdit : presentationData.strings.ChatListFolder_TitleCreate), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetControllerEntries(presentationData: presentationData, isNewFilter: currentPreset == nil, state: state, includePeers: includePeers, excludePeers: excludePeers, isPremium: isPremium, limit: premiumLimits.maxFolderChatsCount), style: .blocks, emptyStateItem: nil, animateChanges: !skipStateAnimation)
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
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
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
    controller.attemptNavigation = { _ in
        return attemptNavigationImpl?() ?? true
    }
    let displaySaveAlert: () -> Void = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.ChatListFolder_DiscardConfirmation, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.ChatListFolder_DiscardDiscard, action: {
                dismissImpl?()
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatListFolder_DiscardCancel, action: {
        })]), nil)
    }
    attemptNavigationImpl = {
        let state = stateValue.with { $0 }
        if let currentPreset = currentPreset, case let .filter(currentId, currentTitle, currentEmoticon, currentData) = currentPreset {
            var currentPresetWithoutPinnedPeers = currentPreset
            
            var currentIncludePeers = ChatListFilterIncludePeers()
            currentIncludePeers.setPeers(currentData.includePeers.peers)
            var currentPresetWithoutPinnedPeersData = currentData
            currentPresetWithoutPinnedPeersData.includePeers = currentIncludePeers
            currentPresetWithoutPinnedPeers = .filter(id: currentId, title: currentTitle, emoticon: currentEmoticon, data: currentPresetWithoutPinnedPeersData)
            
            var includePeers = ChatListFilterIncludePeers()
            includePeers.setPeers(state.additionallyIncludePeers)
            let filter: ChatListFilter = .filter(id: currentPreset.id, title: state.name, emoticon: currentPreset.emoticon, data: ChatListFilterData(categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
            if currentPresetWithoutPinnedPeers != filter {
                displaySaveAlert()
                return false
            }
        } else {
            if state.isComplete {
                displaySaveAlert()
                return false
            }
        }
        return true
    }
    
    return controller
}

