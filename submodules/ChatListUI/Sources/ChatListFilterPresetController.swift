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
import InviteLinksUI
import QrCodeUI
import ContextUI
import AsyncDisplayKit
import UndoUI

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
    let clearFocus: () -> Void
    let focusOnName: () -> Void
    let expandSection: (FilterSection) -> Void
    let createLink: () -> Void
    let openLink: (ExportedChatFolderLink) -> Void
    let removeLink: (ExportedChatFolderLink) -> Void
    let linkContextAction: (ExportedChatFolderLink?, ASDisplayNode, ContextGesture?) -> Void
    let peerContextAction: (EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?) -> Void
    
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
        clearFocus: @escaping () -> Void,
        focusOnName: @escaping () -> Void,
        expandSection: @escaping (FilterSection) -> Void,
        createLink: @escaping () -> Void,
        openLink: @escaping (ExportedChatFolderLink) -> Void,
        removeLink: @escaping (ExportedChatFolderLink) -> Void,
        linkContextAction: @escaping (ExportedChatFolderLink?, ASDisplayNode, ContextGesture?) -> Void,
        peerContextAction: @escaping (EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?) -> Void
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
        self.clearFocus = clearFocus
        self.focusOnName = focusOnName
        self.expandSection = expandSection
        self.createLink = createLink
        self.openLink = openLink
        self.removeLink = removeLink
        self.linkContextAction = linkContextAction
        self.peerContextAction = peerContextAction
    }
}

private enum ChatListFilterPresetControllerSection: Int32 {
    case screenHeader
    case name
    case includePeers
    case excludePeers
    case inviteLinks
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
    case inviteLink(String)
}

private enum ChatListFilterPresetEntrySortId: Comparable {
    case screenHeader
    case topIndex(Int)
    case includeIndex(Int)
    case excludeIndex(Int)
    case bottomIndex(Int)
    case inviteLink(Int)
    case inviteLinkFooter
    
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
            case .bottomIndex:
                return true
            case .inviteLink:
                return true
            case .inviteLinkFooter:
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
            case .bottomIndex:
                return true
            case .inviteLink:
                return true
            case .inviteLinkFooter:
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
            case .bottomIndex:
                return true
            case .inviteLink:
                return true
            case .inviteLinkFooter:
                return true
            }
        case let .bottomIndex(lhsIndex):
            switch rhs {
            case .screenHeader:
                return false
            case .topIndex:
                return false
            case .includeIndex:
                return false
            case .excludeIndex:
                return false
            case let .bottomIndex(rhsIndex):
                return lhsIndex < rhsIndex
            case .inviteLink:
                return true
            case .inviteLinkFooter:
                return true
            }
        case let .inviteLink(lhsIndex):
            switch rhs {
            case .screenHeader:
                return false
            case .topIndex:
                return false
            case .includeIndex:
                return false
            case .excludeIndex:
                return false
            case .bottomIndex:
                return false
            case let .inviteLink(rhsIndex):
                return lhsIndex < rhsIndex
            case .inviteLinkFooter:
                return true
            }
        case .inviteLinkFooter:
            switch rhs {
            case .screenHeader:
                return false
            case .topIndex:
                return false
            case .includeIndex:
                return false
            case .excludeIndex:
                return false
            case .bottomIndex:
                return false
            case .inviteLink:
                return false
            case .inviteLinkFooter:
                return false
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
    case inviteLinkHeader(hasLinks: Bool)
    case inviteLinkCreate(hasLinks: Bool)
    case inviteLink(Int, ExportedChatFolderLink)
    case inviteLinkInfo(text: String)
    
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
        case .inviteLinkHeader, .inviteLinkCreate, .inviteLink, .inviteLinkInfo:
            return ChatListFilterPresetControllerSection.inviteLinks.rawValue
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
        case .inviteLinkHeader:
            return .index(11)
        case .inviteLinkCreate:
            return .index(12)
        case let .inviteLink(_, link):
            return .inviteLink(link.link)
        case .inviteLinkInfo:
            return .index(13)
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
        case .inviteLinkHeader:
            return .bottomIndex(0)
        case .inviteLinkCreate:
            return .bottomIndex(1)
        case let .inviteLink(index, _):
            return .inviteLink(index)
        case .inviteLinkInfo:
            return .inviteLinkFooter
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
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: value, placeholder: placeholder, type: .regular(capitalization: true, autocorrection: false), returnKeyType: .done, clearType: .always, maxLength: 12, sectionId: self.section, textUpdated: { value in
                arguments.updateState { current in
                    var state = current
                    state.name = value
                    state.changedName = true
                    return state
                }
            }, action: {
                arguments.clearFocus()
            }, cleared: {
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
            }, contextAction: { sourceNode, gesture in
                guard let peer = peer.peer else {
                    gesture?.cancel()
                    return
                }
                arguments.peerContextAction(peer, sourceNode, gesture, nil)
            })
        case let .excludePeer(_, peer, isRevealed):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer.chatMainPeer!, height: .peerList, aliasHandling: .threatSelfAsSaved, presence: nil, text: .none, label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: isRevealed), revealOptions: ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                arguments.deleteExcludePeer(peer.peerId)
            })]), switchValue: nil, enabled: true, selectable: false, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
                arguments.setItemIdWithRevealedOptions(lhs.flatMap { .peer($0) }, rhs.flatMap { .peer($0) })
            }, removePeer: { id in
                arguments.deleteExcludePeer(id)
            }, contextAction: { sourceNode, gesture in
                guard let peer = peer.peer else {
                    gesture?.cancel()
                    return
                }
                arguments.peerContextAction(peer, sourceNode, gesture, nil)
            })
        case let .includeExpand(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(presentationData.theme), title: text, sectionId: self.section, editing: false, action: {
                arguments.expandSection(.include)
            })
        case let .excludeExpand(text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(presentationData.theme), title: text, sectionId: self.section, editing: false, action: {
                arguments.expandSection(.exclude)
            })
        case let .inviteLinkHeader(hasLinks):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.ChatListFilter_SectionShare, badge: hasLinks ? nil : presentationData.strings.ChatList_ContextMenuBadgeNew, sectionId: self.section)
        case let .inviteLinkCreate(hasLinks):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.linkIcon(presentationData.theme), title: hasLinks ? presentationData.strings.ChatListFilter_CreateLink : presentationData.strings.ChatListFilter_CreateLinkNew, sectionId: self.section, editing: false, action: {
                arguments.createLink()
            })
        case let .inviteLink(_, link):
            return ItemListFolderInviteLinkListItem(presentationData: presentationData, invite: link, share: false, sectionId: self.section, style: .blocks, tapAction: { invite in
                arguments.openLink(invite)
            }, removeAction: { invite in
                arguments.removeLink(invite)
            }, contextAction: { link, node, gesture in
                arguments.linkContextAction(link, node, gesture)
            })
        case let .inviteLinkInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
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

private func chatListFilterPresetControllerEntries(presentationData: PresentationData, isNewFilter: Bool, currentPreset: ChatListFilter?, state: ChatListFilterPresetControllerState, includePeers: [EngineRenderedPeer], excludePeers: [EngineRenderedPeer], isPremium: Bool, limit: Int32, inviteLinks: [ExportedChatFolderLink]?, hadLinks: Bool) -> [ChatListFilterPresetEntry] {
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
    
    if let currentPreset, let data = currentPreset.data, data.isShared {
    } else {
        entries.append(.excludePeersHeader(presentationData.strings.ChatListFolder_ExcludedSectionHeader))
        entries.append(.addExcludePeer(title: presentationData.strings.ChatListFilter_ExcludeChatsAction))
        
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
    }
    
    var hasLinks = false
    if let inviteLinks, !inviteLinks.isEmpty {
        hasLinks = true
    }
    if let currentPreset, let data = currentPreset.data, data.hasSharedLinks {
        hasLinks = true
    }
    
    entries.append(.inviteLinkHeader(hasLinks: hasLinks || hadLinks))
    entries.append(.inviteLinkCreate(hasLinks: hasLinks))
    
    if let inviteLinks {
        var index = 0
        for link in inviteLinks {
            entries.append(.inviteLink(index, link))
            index += 1
        }
    }
    
    entries.append(.inviteLinkInfo(text: hasLinks ? presentationData.strings.ChatListFilter_LinkListInfo : presentationData.strings.ChatListFilter_LinkListInfoNew))
    
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

func chatListFilterAddChatsController(context: AccountContext, filter: ChatListFilter, allFilters: [ChatListFilter], limit: Int32, premiumLimit: Int32, isPremium: Bool, presentUndo: @escaping (UndoOverlayContent) -> Void) -> ViewController {
    return internalChatListFilterAddChatsController(context: context, filter: filter, allFilters: allFilters, applyAutomatically: true, limit: limit, premiumLimit: premiumLimit, isPremium: isPremium, updated: { _ in }, presentUndo: presentUndo)
}
    
private func internalChatListFilterAddChatsController(context: AccountContext, filter: ChatListFilter, allFilters: [ChatListFilter], applyAutomatically: Bool, limit: Int32, premiumLimit: Int32, isPremium: Bool, updated: @escaping (ChatListFilter) -> Void, presentUndo: @escaping (UndoOverlayContent) -> Void) -> ViewController {
    guard case let .filter(_, _, _, filterData) = filter else {
        return ViewController(navigationBarPresentationData: nil)
    }
    
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    var additionalCategories: [ChatListNodeAdditionalCategory] = []
    var selectedCategories = Set<Int>()
    let categoryMapping: [ChatListFilterPeerCategories: AdditionalCategoryId] = [
        .contacts: .contacts,
        .nonContacts: .nonContacts,
        .groups: .groups,
        .channels: .channels,
        .bots: .bots
    ]
    
    if let data = filter.data, data.isShared {
    } else {
        additionalCategories = [
            ChatListNodeAdditionalCategory(
                id: AdditionalCategoryId.contacts.rawValue,
                icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Contact"), color: .white), cornerRadius: 12.0, color: .blue),
                smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Contact"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .blue),
                title: presentationData.strings.ChatListFolder_CategoryContacts
            ),
            ChatListNodeAdditionalCategory(
                id: AdditionalCategoryId.nonContacts.rawValue,
                icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), cornerRadius: 12.0, color: .yellow),
                smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/User"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .yellow),
                title: presentationData.strings.ChatListFolder_CategoryNonContacts
            ),
            ChatListNodeAdditionalCategory(
                id: AdditionalCategoryId.groups.rawValue,
                icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Group"), color: .white), cornerRadius: 12.0, color: .green),
                smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Group"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .green),
                title: presentationData.strings.ChatListFolder_CategoryGroups
            ),
            ChatListNodeAdditionalCategory(
                id: AdditionalCategoryId.channels.rawValue,
                icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Channel"), color: .white), cornerRadius: 12.0, color: .red),
                smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Channel"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .red),
                title: presentationData.strings.ChatListFolder_CategoryChannels
            ),
            ChatListNodeAdditionalCategory(
                id: AdditionalCategoryId.bots.rawValue,
                icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Bot"), color: .white), cornerRadius: 12.0, color: .violet),
                smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Bot"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .violet),
                title: presentationData.strings.ChatListFolder_CategoryBots
            )
        ]
        
        for (category, id) in categoryMapping {
            if filterData.categories.contains(category) {
                selectedCategories.insert(id.rawValue)
            }
        }
    }
    
    var pushImpl: ((ViewController) -> Void)?
    
    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
        title: presentationData.strings.ChatListFolder_IncludeChatsTitle,
        searchPlaceholder: presentationData.strings.ChatListFilter_AddChatsSearchPlaceholder,
        selectedChats: Set(filterData.includePeers.peers),
        additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories),
        chatListFilters: allFilters
    )), options: [], filters: [], alwaysEnabled: true, limit: isPremium ? premiumLimit : limit, reachedLimit: { count in
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
        
        if filter.id > 1, case let .filter(_, _, _, data) = filter, data.hasSharedLinks {
            let newPeers = includePeers.filter({ !(filter.data?.includePeers.peers.contains($0) ?? false) })
            var removedPeers: [PeerId] = []
            if let data = filter.data {
                removedPeers = data.includePeers.peers.filter({ !includePeers.contains($0) })
            }
            if newPeers.count != 0 {
                let title: String = presentationData.strings.ChatListFilter_ToastChatsAddedTitle(Int32(newPeers.count))
                let text: String = presentationData.strings.ChatListFilter_ToastChatsAddedText
                
                presentUndo(.universal(animation: "anim_add_to_folder", scale: 0.1, colors: ["__allcolors__": UIColor.white], title: title, text: text, customUndoText: nil, timeout: nil))
            } else if removedPeers.count != 0 {
                let title: String = presentationData.strings.ChatListFilter_ToastChatsRemovedTitle(Int32(newPeers.count))
                let text: String = presentationData.strings.ChatListFilter_ToastChatsRemovedText
                
                presentUndo(.universal(animation: "anim_remove_from_folder", scale: 0.1, colors: ["__allcolors__": UIColor.white], title: title, text: text, customUndoText: nil, timeout: nil))
            }
        }
        
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
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Muted"), color: .white), cornerRadius: 12.0, color: .red),
            smallIcon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Muted"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .red),
            title: presentationData.strings.ChatListFolder_CategoryMuted
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.read.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Read"), color: .white), cornerRadius: 12.0, color: .blue),
            smallIcon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Read"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .blue),
            title: presentationData.strings.ChatListFolder_CategoryRead
        ),
        ChatListNodeAdditionalCategory(
            id: AdditionalExcludeCategoryId.archived.rawValue,
            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Archive"), color: .white), cornerRadius: 12.0, color: .yellow),
            smallIcon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Archive"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .yellow),
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
    
    let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
        title: presentationData.strings.ChatListFolder_ExcludeChatsTitle,
        searchPlaceholder: presentationData.strings.ChatListFilter_AddChatsSearchPlaceholder,
        selectedChats: Set(filterData.excludePeers),
        additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: selectedCategories),
        chatListFilters: allFilters
    )), options: [], filters: [], alwaysEnabled: true, limit: 100))
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

func chatListFilterPresetController(context: AccountContext, currentPreset initialPreset: ChatListFilter?, updated: @escaping ([ChatListFilter]) -> Void) -> ViewController {
    let initialName: String
    if let initialPreset {
        initialName = initialPreset.title
    } else {
        initialName = ""
    }
    let initialState = ChatListFilterPresetControllerState(name: initialName, changedName: initialPreset != nil, includeCategories: initialPreset?.data?.categories ?? [], excludeMuted: initialPreset?.data?.excludeMuted ?? false, excludeRead: initialPreset?.data?.excludeRead ?? false, excludeArchived: initialPreset?.data?.excludeArchived ?? false, additionallyIncludePeers: initialPreset?.data?.includePeers.peers ?? [], additionallyExcludePeers: initialPreset?.data?.excludePeers ?? [], expandedSections: [])
    
    let updatedCurrentPreset: Signal<ChatListFilter?, NoError>
    if let initialPreset {
        updatedCurrentPreset = context.engine.peers.updatedChatListFilters()
        |> map { filters -> ChatListFilter? in
            return filters.first(where: { $0.id == initialPreset.id })
        }
        |> distinctUntilChanged
    } else {
        updatedCurrentPreset = .single(nil)
    }
    
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ChatListFilterPresetControllerState) -> ChatListFilterPresetControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            var state = f(current)
            if !state.changedName {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var includePeers = ChatListFilterIncludePeers()
                includePeers.setPeers(state.additionallyIncludePeers)
                let filter: ChatListFilter = .filter(id: initialPreset?.id ?? -1, title: state.name, emoticon: initialPreset?.emoticon, data: ChatListFilterData(isShared: initialPreset?.data?.isShared ?? false, hasSharedLinks: initialPreset?.data?.hasSharedLinks ?? false, categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
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
    var clearFocusImpl: (() -> Void)?
    var applyImpl: ((Bool, @escaping () -> Void) -> Void)?
    var getControllerImpl: (() -> ViewController?)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var pushPremiumController: ((ViewController) -> Void)?
    
    let sharedLinks = Promise<[ExportedChatFolderLink]?>(nil)
    if let initialPreset {
        sharedLinks.set(Signal<[ExportedChatFolderLink]?, NoError>.single(nil) |> then(context.engine.peers.getExportedChatFolderLinks(id: initialPreset.id)))
    }
    
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
                stateWithPeers |> take(1),
                updatedCurrentPreset |> take(1)
            ).start(next: { result, state, currentPreset in
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
                let filter: ChatListFilter = .filter(id: currentPreset?.id ?? -1, title: state.name, emoticon: currentPreset?.emoticon, data: ChatListFilterData(isShared: currentPreset?.data?.isShared ?? false, hasSharedLinks: currentPreset?.data?.hasSharedLinks ?? false, categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
                
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
                    }, presentUndo: { content in
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                    })
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            })
        },
        openAddExcludePeer: {
            let _ = (updatedCurrentPreset
            |> take(1)
            |> deliverOnMainQueue).start(next: { currentPreset in
                let state = stateValue.with { $0 }
                var includePeers = ChatListFilterIncludePeers()
                includePeers.setPeers(state.additionallyIncludePeers)
                let filter: ChatListFilter = .filter(id: currentPreset?.id ?? -1, title: state.name, emoticon: currentPreset?.emoticon, data: ChatListFilterData(isShared: currentPreset?.data?.isShared ?? false, hasSharedLinks: currentPreset?.data?.hasSharedLinks ?? false, categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
                
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
            
            let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
                if let currentPreset, let data = currentPreset.data, data.hasSharedLinks {
                    let title: String
                    let text: String
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    
                    title = presentationData.strings.ChatListFilter_ToastChatsRemovedTitle(1)
                    text = presentationData.strings.ChatListFilter_ToastChatsRemovedText
                    
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_remove_from_folder", scale: 0.1, colors: ["__allcolors__": UIColor.white], title: title, text: text, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                }
            })
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
        clearFocus: {
            clearFocusImpl?()
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
        },
        createLink: {
            if initialPreset == nil {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text = presentationData.strings.ChatListFilter_AlertCreateFolderBeforeSharingText
                presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            } else {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let state = stateValue.with({ $0 })
                if state.additionallyIncludePeers.isEmpty {
                    let text = presentationData.strings.ChatListFilter_ErrorShareInvalidFolder
                    presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                    
                    return
                }
                
                let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                presentControllerImpl?(statusController, nil)
                
                applyImpl?(true, { [weak statusController] in
                    let state = stateValue.with({ $0 })
                    
                    let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
                        if let currentPreset, let data = currentPreset.data {
                            var unavailableText: String?
                            if !data.categories.isEmpty {
                                unavailableText = presentationData.strings.ChatListFilter_ErrorShareInvalidFolder
                            } else if data.excludeArchived || data.excludeRead || data.excludeMuted {
                                unavailableText = presentationData.strings.ChatListFilter_ErrorShareInvalidFolder
                            } else if !data.excludePeers.isEmpty {
                                unavailableText = presentationData.strings.ChatListFilter_ErrorShareInvalidFolder
                            }
                            if let unavailableText {
                                statusController?.dismiss()
                                
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentControllerImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: unavailableText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                
                                return
                            }
                            
                            var statusController = statusController
                            
                            var previousLink: ExportedChatFolderLink?
                            openCreateChatListFolderLink(context: context, folderId: currentPreset.id, checkIfExists: false, title: currentPreset.title, peerIds: state.additionallyIncludePeers, pushController: { c in
                                pushControllerImpl?(c)
                            }, presentController: { c in
                                presentControllerImpl?(c, nil)
                            }, pushPremiumController: { c in
                                pushPremiumController?(c)
                            }, completed: {
                                statusController?.dismiss()
                                statusController = nil
                            }, linkUpdated: { updatedLink in
                                let previousLinkValue = previousLink
                                previousLink = updatedLink
                                
                                let _ = (sharedLinks.get() |> take(1) |> deliverOnMainQueue).start(next: { links in
                                    var links = links ?? []
                                    
                                    if let updatedLink {
                                        if let index = links.firstIndex(where: { $0.link == updatedLink.link }) {
                                            links[index] = updatedLink
                                        } else {
                                            links.insert(updatedLink, at: 0)
                                        }
                                    } else if let previousLinkValue {
                                        if let index = links.firstIndex(where: { $0.link == previousLinkValue.link }) {
                                            links.remove(at: index)
                                        }
                                    }
                                    sharedLinks.set(.single(links))
                                })
                            })
                        } else {
                            statusController?.dismiss()
                        }
                    })
                })
            }
        }, openLink: { link in
            let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
                if let currentPreset, let _ = currentPreset.data {
                    applyImpl?(false, {
                        let state = stateValue.with({ $0 })
                        pushControllerImpl?(folderInviteLinkListController(context: context, filterId: currentPreset.id, title: currentPreset.title, allPeerIds: state.additionallyIncludePeers, currentInvitation: link, linkUpdated: { updatedLink in
                            if updatedLink != link {
                                let _ = (sharedLinks.get() |> take(1) |> deliverOnMainQueue).start(next: { links in
                                    var links = links ?? []
                                    
                                    if let updatedLink {
                                        if let index = links.firstIndex(where: { $0.link == link.link }) {
                                            links[index] = updatedLink
                                        } else {
                                            links.insert(updatedLink, at: 0)
                                        }
                                        sharedLinks.set(.single(links))
                                    } else {
                                        if let index = links.firstIndex(where: { $0.link == link.link }) {
                                            links.remove(at: index)
                                            sharedLinks.set(.single(links))
                                        }
                                    }
                                })
                            }
                        }, presentController: { c in
                            presentControllerImpl?(c, nil)
                        }))
                    })
                }
            })
        },
        removeLink: { link in
            let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
                if let currentPreset {
                    let _ = (sharedLinks.get() |> take(1) |> deliverOnMainQueue).start(next: { links in
                        var links = links ?? []
                        
                        if let index = links.firstIndex(where: { $0.link == link.link }) {
                            links.remove(at: index)
                        }
                        sharedLinks.set(.single(links))
                        
                        actionsDisposable.add(context.engine.peers.deleteChatFolderLink(filterId: currentPreset.id, link: link).start())
                    })
                }
            })
        },
        linkContextAction: { invite, node, gesture in
            let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
                guard let node = node as? ContextExtractedContentContainingNode, let controller = getControllerImpl?(), let invite = invite, let currentPreset else {
                    return
                }
                
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                var items: [ContextMenuItem] = []
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextCopy, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.default)
                    
                    //dismissTooltipsImpl?()
                    
                    UIPasteboard.general.string = invite.link
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.InviteLink_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextGetQRCode, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    presentControllerImpl?(QrCodeScreen(context: context, updatedPresentationData: nil, subject: .chatFolder(slug: invite.slug)), nil)
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.InviteLink_ContextRevoke, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    let _ = (sharedLinks.get() |> take(1) |> deliverOnMainQueue).start(next: { links in
                        var links = links ?? []
                        if let index = links.firstIndex(where: { $0.link == invite.link }) {
                            links.remove(at: index)
                        }
                        sharedLinks.set(.single(links))
                    })
                    
                    let _ = (context.engine.peers.editChatFolderLink(filterId: currentPreset.id, link: invite, title: nil, peerIds: nil, revoke: true)
                             |> deliverOnMainQueue).start(completed: {
                        let _ = (context.engine.peers.deleteChatFolderLink(filterId: currentPreset.id, link: invite)
                                 |> deliverOnMainQueue).start(completed: {
                        })
                    })
                })))
                
                let contextController = ContextController(account: context.account, presentationData: presentationData, source: .extracted(InviteLinkContextExtractedContentSource(controller: controller, sourceNode: node, keepInPlace: false, blurBackground: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                presentInGlobalOverlayImpl?(contextController)
            })
        },
        peerContextAction: { peer, node, gesture, location in
            let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(previewing: true))
            chatController.canReadHistory.set(false)
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChatList_Context_RemoveFromFolder, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { _, f in
                f(.dismissWithoutContent)
                
                updateState { state in
                    var state = state
                    if let index = state.additionallyExcludePeers.firstIndex(of: peer.id) {
                        state.additionallyExcludePeers.remove(at: index)
                    }
                    if let index = state.additionallyIncludePeers.firstIndex(of: peer.id) {
                        state.additionallyIncludePeers.remove(at: index)
                    }
                    return state
                }
            
                let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
                    if let currentPreset, let data = currentPreset.data, data.hasSharedLinks {
                        let title: String
                        let text: String
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        
                        title = presentationData.strings.ChatListFilter_ToastChatsRemovedTitle(1)
                        text = presentationData.strings.ChatListFilter_ToastChatsRemovedText
                        
                        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_remove_from_folder", scale: 0.1, colors: ["__allcolors__": UIColor.white], title: title, text: text, customUndoText: nil, timeout: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                    }
                })
            })))
            
            let contextController = ContextController(account: context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            presentInGlobalOverlayImpl?(contextController)
        }
    )
        
    var attemptNavigationImpl: ((@escaping (Bool) -> Void) -> Void)?
    applyImpl = { waitForSync, completed in
        let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
            let state = stateValue.with { $0 }
            
            var includePeers = ChatListFilterIncludePeers()
            includePeers.setPeers(state.additionallyIncludePeers)
            
            let _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
                var filterId = currentPreset?.id ?? -1
                if currentPreset == nil {
                    filterId = context.engine.peers.generateNewChatListFilterId(filters: filters)
                }
                var updatedFilter: ChatListFilter = .filter(id: filterId, title: state.name, emoticon: currentPreset?.emoticon, data: ChatListFilterData(isShared: currentPreset?.data?.isShared ?? false, hasSharedLinks: currentPreset?.data?.hasSharedLinks ?? false, categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
                
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
                    //currentPreset = updatedFilter
                } else {
                    filters.append(updatedFilter)
                }
                return filters
            }
            |> deliverOnMainQueue).start(next: { filters in
                updated(filters)
                
                if waitForSync {
                    let _ = (context.engine.peers.chatListFiltersAreSynced()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { _ in
                        completed()
                    })
                } else {
                    completed()
                }
            })
        })
    }
    
    var previousState = stateValue.with { $0 }
    var previousSharedLinks: [ExportedChatFolderLink]?
    var hadLinks: Bool = false
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        stateWithPeers,
        context.account.postbox.peerView(id: context.account.peerId),
        context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        ),
        sharedLinks.get(),
        updatedCurrentPreset
    )
    |> deliverOnMainQueue
    |> map { presentationData, stateWithPeers, peerView, premiumLimits, sharedLinks, currentPreset -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (state, includePeers, excludePeers) = stateWithPeers
        
        let isPremium = peerView.peers[peerView.peerId]?.isPremium ?? false
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            if let attemptNavigationImpl {
                attemptNavigationImpl({ value in
                    if value {
                        dismissImpl?()
                    }
                })
            } else {
                dismissImpl?()
            }
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(currentPreset == nil ? presentationData.strings.Common_Create : presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
            applyImpl?(false, {
                dismissImpl?()
            })
        })
        
        let previousStateValue = previousState
        previousState = state
        if previousStateValue.expandedSections != state.expandedSections {
            skipStateAnimation = true
        }
        var crossfadeAnimation = false
        if previousSharedLinks == nil && sharedLinks != nil {
            skipStateAnimation = true
            crossfadeAnimation = true
        }
        previousSharedLinks = sharedLinks
        
        if let sharedLinks, !sharedLinks.isEmpty {
            hadLinks = true
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(currentPreset != nil ? presentationData.strings.ChatListFolder_TitleEdit : presentationData.strings.ChatListFolder_TitleCreate), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: chatListFilterPresetControllerEntries(presentationData: presentationData, isNewFilter: currentPreset == nil, currentPreset: currentPreset, state: state, includePeers: includePeers, excludePeers: excludePeers, isPremium: isPremium, limit: premiumLimits.maxFolderChatsCount, inviteLinks: sharedLinks, hadLinks: hadLinks), style: .blocks, emptyStateItem: nil, crossfadeState: crossfadeAnimation, animateChanges: !skipStateAnimation)
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
    clearFocusImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.view.endEditing(true)
    }
    controller.attemptNavigation = { _ in
        if let attemptNavigationImpl {
            attemptNavigationImpl({ value in
                if value {
                    dismissImpl?()
                }
            })
            return false
        } else {
            return true
        }
    }
    let displaySaveAlert: () -> Void = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.ChatListFolder_DiscardConfirmation, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.ChatListFolder_DiscardDiscard, action: {
                dismissImpl?()
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatListFilter_SaveAlertActionSave, action: {
                applyImpl?(false, {
                    dismissImpl?()
                })
        })]), nil)
    }
    getControllerImpl = { [weak controller] in
        return controller
    }
    presentInGlobalOverlayImpl = { [weak controller] c in
        if let controller = controller {
            controller.presentInGlobalOverlay(c)
        }
    }
    pushPremiumController = { [weak controller] c in
        if let controller = controller {
            controller.replace(with: c)
        }
    }
    attemptNavigationImpl = { f in
        let _ = (updatedCurrentPreset |> take(1) |> deliverOnMainQueue).start(next: { currentPreset in
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
                let filter: ChatListFilter = .filter(id: currentPreset.id, title: state.name, emoticon: currentPreset.emoticon, data: ChatListFilterData(isShared: currentPreset.data?.isShared ?? false, hasSharedLinks: currentPreset.data?.hasSharedLinks ?? false, categories: state.includeCategories, excludeMuted: state.excludeMuted, excludeRead: state.excludeRead, excludeArchived: state.excludeArchived, includePeers: includePeers, excludePeers: state.additionallyExcludePeers))
                if currentPresetWithoutPinnedPeers != filter {
                    displaySaveAlert()
                    f(false)
                    return
                }
            } else {
                if currentPreset != nil, state.isComplete {
                    displaySaveAlert()
                    f(false)
                    return
                }
            }
            f(true)
        })
    }
    
    return controller
}

func openCreateChatListFolderLink(context: AccountContext, folderId: Int32, checkIfExists: Bool, title: String, peerIds: [EnginePeer.Id], pushController: @escaping (ViewController) -> Void, presentController: @escaping (ViewController) -> Void, pushPremiumController: @escaping (ViewController) -> Void, completed: @escaping () -> Void, linkUpdated: @escaping (ExportedChatFolderLink?) -> Void) {
    if peerIds.isEmpty {
        completed()
        return
    }
    
    let existingLink: Signal<ExportedChatFolderLink?, NoError>
    if checkIfExists {
        existingLink = combineLatest(
            context.engine.peers.getExportedChatFolderLinks(id: folderId),
            context.engine.data.get(
                EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            )
        )
        |> map { result, peers -> ExportedChatFolderLink? in
            var enabledPeerIds: [EnginePeer.Id] = []
            for peer in peers {
                if case let .legacyGroup(group) = peer, group.migrationReference != nil {
                    continue
                }
                if let peer, canShareLinkToPeer(peer: peer) {
                    enabledPeerIds.append(peer.id)
                }
            }
            
            guard let result else {
                return nil
            }
            
            for link in result {
                if Set(link.peerIds) == Set(enabledPeerIds) {
                    return link
                }
            }
            
            return nil
        }
    } else {
        existingLink = .single(nil)
    }
    
    let _ = (existingLink
    |> deliverOnMainQueue).start(next: { existingLink in
        if let existingLink {
            completed()
            pushController(folderInviteLinkListController(context: context, filterId: folderId, title: title, allPeerIds: peerIds, currentInvitation: existingLink, linkUpdated: linkUpdated, presentController: { c in
                presentController(c)
            }))
            
            return
        }
        
        let _ = (context.engine.data.get(
            EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
        )
        |> deliverOnMainQueue).start(next: { peers in
            let peers = peers.compactMap({ peer -> EnginePeer? in
                guard let peer else {
                    return nil
                }
                if case let .legacyGroup(group) = peer, group.migrationReference != nil {
                    return nil
                }
                return peer
            })
            if peers.allSatisfy({ !canShareLinkToPeer(peer: $0) }) {
                completed()
                pushController(folderInviteLinkListController(context: context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: nil, linkUpdated: linkUpdated, presentController: { c in
                    presentController(c)
                }))
            } else {
                var enabledPeerIds: [EnginePeer.Id] = []
                for peer in peers {
                    if canShareLinkToPeer(peer: peer) {
                        enabledPeerIds.append(peer.id)
                    }
                }
                
                let _ = (context.engine.peers.exportChatFolder(filterId: folderId, title: "", peerIds: enabledPeerIds)
                |> deliverOnMainQueue).start(next: { link in
                    completed()
                    linkUpdated(link)
                    
                    pushController(folderInviteLinkListController(context: context, filterId: folderId, title: title, allPeerIds: peers.map(\.id), currentInvitation: link, linkUpdated: linkUpdated, presentController: { c in
                        presentController(c)
                    }))
                }, error: { error in
                    completed()
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    
                    let text: String
                    switch error {
                    case .generic:
                        text = presentationData.strings.ChatListFilter_CreateLinkUnknownError
                    case let .sharedFolderLimitExceeded(limit, _):
                        let limitController = context.sharedContext.makePremiumLimitController(context: context, subject: .membershipInSharedFolders, count: limit, action: {
                            pushPremiumController(PremiumIntroScreen(context: context, source: .membershipInSharedFolders))
                        })
                        pushController(limitController)
                        
                        return
                    case let .limitExceeded(limit, _):
                        let limitController = context.sharedContext.makePremiumLimitController(context: context, subject: .linksPerSharedFolder, count: limit, action: {
                            pushPremiumController(PremiumIntroScreen(context: context, source: .linksPerSharedFolder))
                        })
                        pushController(limitController)
                        
                        return
                    case let .tooManyChannels(limit, _):
                        let limitController = context.sharedContext.makePremiumLimitController(context: context, subject: .linksPerSharedFolder, count: limit, action: {
                            pushPremiumController(PremiumIntroScreen(context: context, source: .groupsAndChannels))
                        })
                        pushController(limitController)
                        
                        return
                    case let .tooManyChannelsInAccount(limit, _):
                        let limitController = context.sharedContext.makePremiumLimitController(context: context, subject: .channels, count: limit, action: {
                            pushPremiumController(PremiumIntroScreen(context: context, source: .groupsAndChannels))
                        })
                        pushController(limitController)
                        
                        return
                    case .someUserTooManyChannels:
                        text = presentationData.strings.ChatListFilter_CreateLinkErrorSomeoneHasChannelLimit
                    }
                    presentController(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                })
            }
        })
    })
}

private final class InviteLinkContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceNode: ASDisplayNode?
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = true
    
    init(controller: ViewController, sourceNode: ASDisplayNode?) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceNode = self.sourceNode
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceNode] in
            if let sourceNode = sourceNode {
                return (sourceNode.view, sourceNode.bounds)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
    }
}
