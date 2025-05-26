import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import MergeLists
import ItemListUI
import PresentationDataUtils
import MediaResources
import AccountContext
import TelegramPermissions
import TelegramNotices
import ContactsPeerItem
import ChatListSearchItemNode
import ChatListSearchItemHeader
import SearchUI
import TelegramPermissionsUI
import AppBundle
import ContextUI
import PhoneNumberFormat
import LocalizedPeerData
import ContextUI

private let dropDownIcon = { () -> UIImage in
    UIGraphicsBeginImageContextWithOptions(CGSize(width: 12.0, height: 12.0), false, 0.0)
    let context = UIGraphicsGetCurrentContext()!
    context.setBlendMode(.copy)
    context.setFillColor(UIColor.black.cgColor)
    context.move(to: CGPoint(x: 0.0, y: 3.0))
    context.addLine(to: CGPoint(x: 12.0, y: 3.0))
    context.addLine(to: CGPoint(x: 6.0, y: 9.0))
    context.fillPath()
    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return image
}()

private enum ContactListNodeEntrySection: Int {
    case stories = 0
    case contacts = 1
}

private enum ContactListNodeEntryId: Hashable {
    case search
    case sort
    case permission(index: Int)
    case option(index: Int)
    case peerId(peerId: Int64, section: ContactListNodeEntrySection)
    case deviceContact(DeviceContactStableId)
}

private final class ContactListNodeInteraction {
    fileprivate let activateSearch: () -> Void
    fileprivate let authorize: () -> Void
    fileprivate let suppressWarning: () -> Void
    fileprivate let openPeer: (ContactListPeer, ContactListAction, ASDisplayNode?, ContextGesture?) -> Void
    fileprivate let openDisabledPeer: (EnginePeer, ChatListDisabledPeerReason) -> Void
    fileprivate let contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?, Bool) -> Void)?
    fileprivate let openStories: (EnginePeer, ASDisplayNode) -> Void
    fileprivate let deselectAll: () -> Void
    fileprivate let toggleSelection: ([EnginePeer], Bool) -> Void
    fileprivate let openContactAccessPicker: () -> Void
    
    let itemHighlighting = ContactItemHighlighting()
    
    init(activateSearch: @escaping () -> Void, authorize: @escaping () -> Void, suppressWarning: @escaping () -> Void, openPeer: @escaping (ContactListPeer, ContactListAction, ASDisplayNode?, ContextGesture?) -> Void, openDisabledPeer: @escaping (EnginePeer, ChatListDisabledPeerReason) -> Void, contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?, Bool) -> Void)?, openStories: @escaping (EnginePeer, ASDisplayNode) -> Void, deselectAll: @escaping () -> Void, toggleSelection: @escaping ([EnginePeer], Bool) -> Void, openContactAccessPicker: @escaping () -> Void) {
        self.activateSearch = activateSearch
        self.authorize = authorize
        self.suppressWarning = suppressWarning
        self.openPeer = openPeer
        self.openDisabledPeer = openDisabledPeer
        self.contextAction = contextAction
        self.openStories = openStories
        self.deselectAll = deselectAll
        self.toggleSelection = toggleSelection
        self.openContactAccessPicker = openContactAccessPicker
    }
}

enum ContactListAnimation {
    case none
    case `default`
    case insertion
}

private enum ContactListNodeEntry: Comparable, Identifiable {
    struct StoryData: Equatable {
        var count: Int
        var unseenCount: Int
        var hasUnseenCloseFriends: Bool
    }
    
    case search(PresentationTheme, PresentationStrings)
    case sort(PresentationTheme, PresentationStrings, ContactsSortOrder)
    case permissionInfo(PresentationTheme, String, String, Bool)
    case permissionEnable(PresentationTheme, String)
    case permissionLimited(PresentationTheme, PresentationStrings)
    case option(Int, ContactListAdditionalOption, ListViewItemHeader?, PresentationTheme, PresentationStrings)
    case peer(Int, ContactListPeer, EnginePeer.Presence?, ListViewItemHeader?, ContactsPeerItemSelection, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PresentationPersonNameOrder, Bool, Bool, Bool, StoryData?, Bool, String?)
    
    var stableId: ContactListNodeEntryId {
        switch self {
            case .search:
                return .search
            case .sort:
                return .sort
            case .permissionInfo:
                return .permission(index: 0)
            case .permissionEnable:
                return .permission(index: 1)
            case .permissionLimited:
                return .permission(index: 2)
            case let .option(index, _, _, _, _):
                return .option(index: index)
            case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _, _, storyData, _, _):
                switch peer {
                    case let .peer(peer, _, _):
                        return .peerId(peerId: peer.id.toInt64(), section: storyData != nil ? .stories : .contacts)
                    case let .deviceContact(id, _):
                        return .deviceContact(id)
                }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, interaction: ContactListNodeInteraction, isSearch: Bool) -> ListViewItem {
        switch self {
            case let .search(theme, strings):
                return ChatListSearchItem(theme: theme, placeholder: strings.Contacts_SearchLabel, activate: {
                    interaction.activateSearch()
                })
            case let .sort(_, strings, sortOrder):
                var text = strings.Contacts_SortedByName
                if case .presence = sortOrder {
                    text = strings.Contacts_SortedByPresence
                }
                return ContactListActionItem(presentationData: ItemListPresentationData(presentationData), title: text, icon: .inline(dropDownIcon, .right), highlight: .alpha, accessible: false, header: nil, action: {
            })
            case let .permissionInfo(_, title, text, suppressed):
                return InfoListItem(presentationData: ItemListPresentationData(presentationData), title: title, text: .plain(text), style: .plain, closeAction: suppressed ? nil : {
                    interaction.suppressWarning()
                })
            case let .permissionEnable(_, text):
                return ContactListActionItem(presentationData: ItemListPresentationData(presentationData), title: text, icon: .none, header: nil, action: {
                    interaction.authorize()
                })
            case .permissionLimited:
                return LimitedPermissionItem(presentationData: ItemListPresentationData(presentationData), text: presentationData.strings.Contacts_LimitedAccess_Text, action: {
                    interaction.openContactAccessPicker()
                })
            case let .option(_, option, header, _, _):
                let style: ContactListActionItem.Style
                let height: ContactListActionItem.Height
                switch option.style {
                case .accent:
                    style = .accent
                    height = .generic
                case .generic:
                    style = .generic
                    height = .tall
                }
                return ContactListActionItem(presentationData: ItemListPresentationData(presentationData), title: option.title, subtitle: option.subtitle, icon: option.icon, style: style, height: height, clearHighlightAutomatically: option.clearHighlightAutomatically, header: header, action: option.action)
            case let .peer(_, peer, presence, header, selection, _, strings, dateTimeFormat, nameSortOrder, nameDisplayOrder, displayCallIcons, hasMoreButton, enabled, storyData, requiresPremiumForMessaging, customSubtitle):
                var status: ContactsPeerItemStatus
                let itemPeer: ContactsPeerItemPeer
                var isContextActionEnabled = false
                switch peer {
                    case let .peer(peer, isGlobal, participantCount):
                        isContextActionEnabled = true
                        if isGlobal, let _ = peer.addressName {
                            status = .addressName("")
                        } else {
                            if let _ = peer as? TelegramUser {
                                status = .presence(presence ?? EnginePeer.Presence(status: .longTimeAgo, lastActivity: 0), dateTimeFormat)
                            } else if let group = peer as? TelegramGroup {
                                status = .custom(string: NSAttributedString(string: strings.Conversation_StatusMembers(Int32(group.participantCount))), multiline: false, isActive: false, icon: nil)
                            } else if let channel = peer as? TelegramChannel {
                                if case .group = channel.info {
                                    if let participantCount = participantCount, participantCount != 0 {
                                        status = .custom(string: NSAttributedString(string: strings.Conversation_StatusMembers(participantCount)), multiline: false, isActive: false, icon: nil)
                                    } else {
                                        status = .custom(string: NSAttributedString(string: strings.Group_Status), multiline: false, isActive: false, icon: nil)
                                    }
                                } else {
                                    if let participantCount = participantCount, participantCount != 0 {
                                        status = .custom(string: NSAttributedString(string: strings.Conversation_StatusSubscribers(participantCount)), multiline: false, isActive: false, icon: nil)
                                    } else {
                                        status = .custom(string: NSAttributedString(string: strings.Channel_Status), multiline: false, isActive: false, icon: nil)
                                    }
                                }
                            } else {
                                status = .none
                            }
                        }
                        itemPeer = .peer(peer: EnginePeer(peer), chatPeer: EnginePeer(peer))
                    case let .deviceContact(id, contact):
                        status = .none
                        itemPeer = .deviceContact(stableId: id, contact: contact)
                }
                if isSearch {
                    status = .none
                }
                var itemContextAction: ((ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
                if isContextActionEnabled, let contextAction = interaction.contextAction {
                    itemContextAction = { node, gesture, location in
                        switch itemPeer {
                        case let .peer(peer, _):
                            if let peer = peer {
                                contextAction(peer, node, gesture, location, storyData != nil)
                            }
                        case .deviceContact:
                            break
                        case .thread:
                            break
                        }
                    }
                }
                
                var additionalActions: [ContactsPeerItemAction] = []
                if hasMoreButton {
                    additionalActions = [ContactsPeerItemAction(icon: .more, action: { _, sourceNode, gesture in
                        interaction.openPeer(peer, .more, sourceNode, gesture)
                    })]
                } else if displayCallIcons {
                    additionalActions = [ContactsPeerItemAction(icon: .voiceCall, action: { _, sourceNode, gesture  in
                        interaction.openPeer(peer, .voiceCall, sourceNode, gesture)
                    }), ContactsPeerItemAction(icon: .videoCall, action: { _, sourceNode, gesture in
                        interaction.openPeer(peer, .videoCall, sourceNode, gesture)
                    })]
                }
                
                if let customSubtitle {
                    status = .custom(string: NSAttributedString(string: customSubtitle), multiline: false, isActive: false, icon: nil)
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: isSearch ? .generalSearch(isSavedMessages: false) : .peer, peer: itemPeer, status: status, requiresPremiumForMessaging: requiresPremiumForMessaging, enabled: enabled, selection: selection, selectionPosition: .left, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), additionalActions: additionalActions, index: nil, header: header, action: { _ in
                        interaction.openPeer(peer, .generic, nil, nil)
                }, disabledAction: { _ in
                    if case let .peer(peer, _, _) = peer {
                        interaction.openDisabledPeer(EnginePeer(peer), requiresPremiumForMessaging ? .premiumRequired : .generic)
                    }
                }, itemHighlighting: interaction.itemHighlighting, contextAction: itemContextAction, storyStats: nil, openStories: { peer, sourceNode in
                    if case let .peer(peerValue, _) = peer, let peerValue {
                        interaction.openStories(peerValue, sourceNode)
                    }
                })
        }
    }

    static func ==(lhs: ContactListNodeEntry, rhs: ContactListNodeEntry) -> Bool {
        switch lhs {
            case let .search(lhsTheme, lhsStrings):
                if case let .search(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .sort(lhsTheme, lhsStrings, lhsSortOrder):
                if case let .sort(rhsTheme, rhsStrings, rhsSortOrder) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsSortOrder == rhsSortOrder {
                    return true
                } else {
                    return false
                }
            case let .permissionInfo(lhsTheme, lhsTitle, lhsText, lhsSuppressed):
                if case let .permissionInfo(rhsTheme, rhsTitle, rhsText, rhsSuppressed) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsSuppressed == rhsSuppressed {
                    return true
                } else {
                    return false
                }
            case let .permissionEnable(lhsTheme, lhsText):
                if case let .permissionEnable(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .permissionLimited(lhsTheme, lhsStrings):
                if case let .permissionLimited(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .option(lhsIndex, lhsOption, lhsHeader, lhsTheme, lhsStrings):
                if case let .option(rhsIndex, rhsOption, rhsHeader, rhsTheme, rhsStrings) = rhs, lhsIndex == rhsIndex, lhsOption == rhsOption, lhsHeader?.id == rhsHeader?.id, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsPeer, lhsPresence, lhsHeader, lhsSelection, lhsTheme, lhsStrings, lhsTimeFormat, lhsSortOrder, lhsDisplayOrder, lhsDisplayCallIcons, lhsHasMoreButton, lhsEnabled, lhsStoryData, lhsRequiresPremiumForMessaging, lhsCustomSubtitle):
                switch rhs {
                    case let .peer(rhsIndex, rhsPeer, rhsPresence, rhsHeader, rhsSelection, rhsTheme, rhsStrings, rhsTimeFormat, rhsSortOrder, rhsDisplayOrder, rhsDisplayCallIcons, rhsHasMoreButton, rhsEnabled, rhsStoryData, rhsRequiresPremiumForMessaging, rhsCustomSubtitle):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsPeer != rhsPeer {
                            return false
                        }
                        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                            if lhsPresence != rhsPresence {
                                return false
                            }
                        } else if (lhsPresence != nil) != (rhsPresence != nil) {
                            return false
                        }
                        if lhsHeader?.id != rhsHeader?.id {
                            return false
                        }
                        if lhsSelection != rhsSelection {
                            return false
                        }
                        if lhsTheme !== rhsTheme {
                            return false
                        }
                        if lhsStrings !== rhsStrings {
                            return false
                        }
                        if lhsTimeFormat != rhsTimeFormat {
                            return false
                        }
                        if lhsSortOrder != rhsSortOrder {
                            return false
                        }
                        if lhsDisplayOrder != rhsDisplayOrder {
                            return false
                        }
                        if lhsDisplayCallIcons != rhsDisplayCallIcons {
                            return false
                        }
                        if lhsHasMoreButton != rhsHasMoreButton {
                            return false
                        }
                        if lhsEnabled != rhsEnabled {
                            return false
                        }
                        if lhsStoryData != rhsStoryData {
                            return false
                        }
                        if lhsRequiresPremiumForMessaging != rhsRequiresPremiumForMessaging {
                            return false
                        }
                        if lhsCustomSubtitle != rhsCustomSubtitle {
                            return false
                        }
                        return true
                    default:
                        return false
                }
        }
    }

    static func <(lhs: ContactListNodeEntry, rhs: ContactListNodeEntry) -> Bool {
        switch lhs {
            case .search:
                return true
            case .sort:
                switch rhs {
                    case .search:
                        return false
                    default:
                        return true
                }
            case .permissionInfo:
                switch rhs {
                    case .search, .sort:
                        return false
                    default:
                        return true
                }
            case .permissionEnable:
                switch rhs {
                    case .search, .sort, .permissionInfo:
                        return false
                    default:
                        return true
                }
            case .permissionLimited:
                switch rhs {
                    case .search, .sort, .permissionInfo, .permissionEnable:
                        return false
                    default:
                        return true
                }
            case let .option(lhsIndex, _, _, _, _):
                switch rhs {
                    case .search, .sort, .permissionInfo, .permissionEnable, .permissionLimited:
                            return false
                        case let .option(rhsIndex, _, _, _, _):
                            return lhsIndex < rhsIndex
                        case .peer:
                            return true
                }
            case let .peer(lhsIndex, _, _, _, _, _, _, _, _, _, _, _, _, lhsStoryData, _, _):
                switch rhs {
                    case .search, .sort, .permissionInfo, .permissionEnable, .permissionLimited, .option:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _, _, _, _, _, _, _, rhsStoryData, _, _):
                        if (lhsStoryData == nil) != (rhsStoryData == nil) {
                            if lhsStoryData != nil {
                                return true
                            } else {
                                return false
                            }
                        }
                        return lhsIndex < rhsIndex
                }
        }
    }
}

private func contactListNodeEntries(accountPeer: EnginePeer?, peers: [ContactListPeer], presences: [EnginePeer.Id: EnginePeer.Presence], presentation: ContactListPresentation, selectionState: ContactListNodeGroupSelectionState?, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, sortOrder: PresentationPersonNameOrder, displayOrder: PresentationPersonNameOrder, disabledPeerIds: Set<EnginePeer.Id>, peerRequiresPremiumForMessaging: [EnginePeer.Id: Bool], peersWithStories: [EnginePeer.Id: PeerStoryStats], authorizationStatus: AccessType, warningSuppressed: (Bool, Bool), displaySortOptions: Bool, displayCallIcons: Bool, storySubscriptions: EngineStorySubscriptions?, topPeers: [EnginePeer], topPeersPresentation: ContactListPresentation.TopPeers, isPeerEnabled: ((EnginePeer) -> Bool)?, interaction: ContactListNodeInteraction) -> [ContactListNodeEntry] {
    var entries: [ContactListNodeEntry] = []
    
    var commonHeader: ListViewItemHeader?
    var orderedPeers: [ContactListPeer]
    var headers: [ContactListPeerId: ContactListNameIndexHeader] = [:]
        
    var addHeader = false
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        let (suppressed, syncDisabled) = warningSuppressed
        if !peers.isEmpty && !syncDisabled {
            let title = strings.Contacts_PermissionsTitle
            let text = strings.Contacts_PermissionsText
            switch authorizationStatus {
                case .limited:
                    if displaySortOptions {
                        entries.append(.permissionLimited(theme, strings))
                    }
                case .denied:
                    entries.append(.permissionInfo(theme, title, text, suppressed))
                    entries.append(.permissionEnable(theme, strings.Permissions_ContactsAllowInSettings_v0))
                    addHeader = true
                case .notDetermined:
                    entries.append(.permissionInfo(theme, title, text, false))
                    entries.append(.permissionEnable(theme, strings.Permissions_ContactsAllow_v0))
                    addHeader = true
            default:
                break
            }
        }
    }
    
    if let storySubscriptions, !storySubscriptions.items.isEmpty {
        addHeader = true
    }
    
    if addHeader {
        commonHeader = ChatListSearchItemHeader(type: .text(strings.Contacts_SortedByPresence.uppercased(), AnyHashable(1)), theme: theme, strings: strings, actionTitle: nil, action: nil)
    }
    
    switch presentation {
        case let .orderedByPresence(options):
            orderedPeers = peers.sorted(by: { lhs, rhs in
                if case let .peer(lhsPeer, _, _) = lhs, case let .peer(rhsPeer, _, _) = rhs {
                    let lhsPresence = presences[lhsPeer.id]
                    let rhsPresence = presences[rhsPeer.id]
                    if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                        if lhsPresence.status < rhsPresence.status {
                            return false
                        } else if lhsPresence.status > rhsPresence.status {
                            return true
                        }
                    } else if let _ = lhsPresence {
                        return true
                    } else if let _ = rhsPresence {
                        return false
                    }
                    return lhsPeer.id < rhsPeer.id
                } else if case .peer = lhs {
                    return true
                } else {
                    return false
                }
            })
            for i in 0 ..< options.count {
                entries.append(.option(i, options[i], commonHeader, theme, strings))
            }
        case let .natural(options, _, _):
            let sortedPeers = peers.sorted(by: { lhs, rhs in
                let result = EnginePeer.IndexName(lhs.indexName).isLessThan(other: EnginePeer.IndexName(rhs.indexName), ordering: sortOrder)
                if result == .orderedSame {
                    if case let .peer(lhsPeer, _, _) = lhs, case let .peer(rhsPeer, _, _) = rhs {
                        return lhsPeer.id < rhsPeer.id
                    } else if case let .deviceContact(lhsId, _) = lhs, case let .deviceContact(rhsId, _) = rhs {
                        return lhsId < rhsId
                    } else if case .peer = lhs {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return result == .orderedAscending
                }
            })
            var headerCache: [unichar: ContactListNameIndexHeader] = [:]
            var startsWithLetter: [ContactListPeer] = []
            var startsWithOther: [ContactListPeer] = []
            let hashHeader = "#".utf16.first!
            
            for peer in sortedPeers {
                var indexHeader: unichar = 35
                switch peer.indexName {
                    case let .title(title, _):
                        if let c = title.folding(options: .diacriticInsensitive, locale: .current).uppercased().utf16.first {
                            indexHeader = c
                        }
                    case let .personName(first, last, _, _):
                        switch sortOrder {
                            case .firstLast:
                                if let c = first.folding(options: .diacriticInsensitive, locale: .current).uppercased().utf16.first {
                                    indexHeader = c
                                } else if let c = last.folding(options: .diacriticInsensitive, locale: .current).uppercased().utf16.first {
                                    indexHeader = c
                                }
                            case .lastFirst:
                                if let c = last.folding(options: .diacriticInsensitive, locale: .current).uppercased().utf16.first {
                                    indexHeader = c
                                } else if let c = first.folding(options: .diacriticInsensitive, locale: .current).uppercased().utf16.first {
                                    indexHeader = c
                                }
                        }
                }
                if let scalar = UnicodeScalar(indexHeader) {
                    if !NSCharacterSet.uppercaseLetters.contains(scalar) {
                        indexHeader = hashHeader
                        startsWithOther.append(peer)
                    } else {
                        startsWithLetter.append(peer)
                    }
                } else {
                    indexHeader = hashHeader
                    startsWithOther.append(peer)
                }
                let header: ContactListNameIndexHeader
                if let cached = headerCache[indexHeader] {
                    header = cached
                } else {
                    header = ContactListNameIndexHeader(theme: theme, letter: indexHeader)
                    headerCache[indexHeader] = header
                }
                headers[peer.id] = header
            }
            for i in 0 ..< options.count {
                entries.append(.option(i, options[i], nil, theme, strings))
            }
            orderedPeers = startsWithLetter + startsWithOther
        case .search:
            orderedPeers = peers
    }
    
    var removeIndices: [Int] = []
    for i in 0 ..< orderedPeers.count {
        switch orderedPeers[i].indexName {
            case let .title(title, _):
                if title.isEmpty {
                    removeIndices.append(i)
                }
            case let .personName(first, last, _, _):
                if first.isEmpty && last.isEmpty {
                    removeIndices.append(i)
                }
        }
    }
    if !removeIndices.isEmpty {
        for index in removeIndices.reversed() {
            orderedPeers.remove(at: index)
        }
    }
    
    var existingPeerIds = Set<ContactListPeerId>()
    switch topPeersPresentation {
    case .recent:
        if !topPeers.isEmpty {
            let hasDeselectAll = !(selectionState?.selectedPeerIndices ?? [:]).isEmpty
            
            let header: ListViewItemHeader? = ChatListSearchItemHeader(type: .text(strings.Premium_Gift_ContactSelection_FrequentContacts.uppercased(), AnyHashable(hasDeselectAll ? 1 : 0)), theme: theme, strings: strings, actionTitle: hasDeselectAll ? strings.Premium_Gift_ContactSelection_DeselectAll.uppercased() : nil, action: { _ in
                interaction.deselectAll()
            })
            
            var index: Int = 0
            for peer in topPeers.prefix(15) {
                if peer.isDeleted {
                    continue
                }
                existingPeerIds.insert(.peer(peer.id))
                
                let selection: ContactsPeerItemSelection
                if let selectionState = selectionState {
                    selection = .selectable(selected: selectionState.selectedPeerIndices[.peer(peer.id)] != nil)
                } else {
                    selection = .none
                }
                
                let presence = presences[peer.id]
                entries.append(.peer(index, .peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil), presence, header, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, false, false, true, nil, false, nil))
                
                index += 1
            }
        }
    case let .custom(showSelf, selfSubtitle, sections):
        if !topPeers.isEmpty {
            var index: Int = 0
                        
            var sectionId: Int = 2
            for (title, peerIds, hasActions) in sections {
                var allSelected = true
                if let selectedPeerIndices = selectionState?.selectedPeerIndices, !selectedPeerIndices.isEmpty {
                    for peerId in peerIds {
                        if selectedPeerIndices[.peer(peerId)] == nil {
                            allSelected = false
                            break
                        }
                    }
                } else {
                    allSelected = false
                }
                var actionTitle: String?
                if !"".isEmpty, peerIds.count > 1 {
                    actionTitle = allSelected ? strings.Premium_Gift_ContactSelection_DeselectAll.uppercased() : strings.Premium_Gift_ContactSelection_SelectAll.uppercased()
                }
                let header: ListViewItemHeader? = ChatListSearchItemHeader(type: .text(title.uppercased(), AnyHashable(10 * sectionId + (allSelected ? 1 : 0))), theme: theme, strings: strings, actionTitle: actionTitle, action: { _ in
                    var existingPeerIds = Set<EnginePeer.Id>()
                    var peers: [EnginePeer] = []
                    for peer in topPeers {
                        if !existingPeerIds.contains(peer.id) {
                            if peerIds.contains(peer.id) {
                                peers.append(peer)
                                existingPeerIds.insert(peer.id)
                            }
                        }
                    }
                    interaction.toggleSelection(peers, !allSelected)
                })
                
                for peerId in peerIds {
                    if let peer = topPeers.first(where: { $0.id == peerId }) {
                        if peer.isDeleted {
                            continue
                        }
                        if existingPeerIds.contains(.peer(peer.id)) {
                            continue
                        }
                        existingPeerIds.insert(.peer(peer.id))
                        
                        let selection: ContactsPeerItemSelection
                        if let selectionState = selectionState {
                            selection = .selectable(selected: selectionState.selectedPeerIndices[.peer(peer.id)] != nil)
                        } else {
                            selection = .none
                        }
                        
                        let presence = presences[peer.id]
                        entries.append(.peer(index, .peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil), presence, header, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, false, hasActions, true, nil, false, nil))
                        
                        index += 1
                    }
                }
                sectionId += 1
            }
            
            if showSelf, let accountPeer {
                if let peer = topPeers.first(where: { $0.id == accountPeer.id }) {
                    let header = ChatListSearchItemHeader(type: .text(strings.Premium_Gift_ContactSelection_ThisIsYou.uppercased(), AnyHashable(10)), theme: theme, strings: strings)
                    entries.append(.peer(index, .peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil), nil, header, .none, theme, strings, dateTimeFormat, sortOrder, displayOrder, false, false, true, nil, false, selfSubtitle))
                    existingPeerIds.insert(.peer(peer.id))
                }
            }
            
            var hasDeselectAll = !(selectionState?.selectedPeerIndices ?? [:]).isEmpty
            if !sections.isEmpty, let selectionState {
                var hasNonBirthdayPeers = false
                var allBirthdayPeerIds = Set<EnginePeer.Id>()
                for (_, peerIds, _) in sections {
                    for peerId in peerIds {
                        allBirthdayPeerIds.insert(peerId)
                    }
                }
                for id in selectionState.selectedPeerIndices.keys {
                    if case let .peer(peerId) = id, !allBirthdayPeerIds.contains(peerId) {
                        hasNonBirthdayPeers = true
                        break
                    }
                }
                if !hasNonBirthdayPeers {
                    hasDeselectAll = false
                }
            }
            
            let header: ListViewItemHeader? = ChatListSearchItemHeader(type: .text(strings.Premium_Gift_ContactSelection_FrequentContacts.uppercased(), AnyHashable(hasDeselectAll ? 1 : 0)), theme: theme, strings: strings, actionTitle: hasDeselectAll ? strings.Premium_Gift_ContactSelection_DeselectAll.uppercased() : nil, action: { _ in
                interaction.deselectAll()
            })
            
            for peer in topPeers.prefix(15) {
                if peer.isDeleted {
                    continue
                }
                if existingPeerIds.contains(.peer(peer.id)) {
                    continue
                }
                existingPeerIds.insert(.peer(peer.id))
                
                let selection: ContactsPeerItemSelection
                if let selectionState = selectionState {
                    selection = .selectable(selected: selectionState.selectedPeerIndices[.peer(peer.id)] != nil)
                } else {
                    selection = .none
                }
                
                let presence = presences[peer.id]
                entries.append(.peer(index, .peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil), presence, header, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, false, false, true, peersWithStories[peer.id].flatMap {
                    ContactListNodeEntry.StoryData(count: $0.totalCount, unseenCount: $0.unseenCount, hasUnseenCloseFriends: $0.hasUnseenCloseFriends)
                }, false, nil))
                
                index += 1
            }
        }
    case .none:
        break
    }
    
    if let storySubscriptions {
        let _ = storySubscriptions
        /*var index: Int = 0
        
        let header: ListViewItemHeader? = ChatListSearchItemHeader(type: .text("HIDDEN STORIES", AnyHashable(0)), theme: theme, strings: strings)
        
        for item in storySubscriptions.items {
            entries.append(.peer(index, .peer(peer: item.peer._asPeer(), isGlobal: false, participantCount: nil), nil, header, .none, theme, strings, dateTimeFormat, sortOrder, displayOrder, false, true, ContactListNodeEntry.StoryData(count: item.storyCount, unseenCount: item.unseenCount, hasUnseenCloseFriends: item.hasUnseenCloseFriends)))
            index += 1
        }*/
    }
    
    var index: Int = 0
    
    if let selectionState = selectionState {
        for peer in selectionState.foundPeers {
            if existingPeerIds.contains(peer.id) {
                continue
            }
            existingPeerIds.insert(peer.id)
            
            let selection: ContactsPeerItemSelection = .selectable(selected: selectionState.selectedPeerIndices[peer.id] != nil)
            
            var presence: EnginePeer.Presence?
            if case let .peer(peer, _, _) = peer {
                presence = presences[peer.id]
            }
            let enabled: Bool
            switch peer {
                case let .peer(peer, _, _):
                    enabled = !disabledPeerIds.contains(peer.id)
                default:
                    enabled = true
            }
            
            var storyData: ContactListNodeEntry.StoryData?
            if case let .peer(id) = peer.id {
                storyData = peersWithStories[id].flatMap {
                    ContactListNodeEntry.StoryData(count: $0.totalCount, unseenCount: $0.unseenCount, hasUnseenCloseFriends: $0.hasUnseenCloseFriends)
                }
            }
            
            entries.append(.peer(index, peer, presence, nil, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, displayCallIcons, false, enabled, storyData, false, nil))
            index += 1
        }
    }
    
    for i in 0 ..< orderedPeers.count {
        let peer = orderedPeers[i]
        if existingPeerIds.contains(peer.id) {
            continue
        }
        existingPeerIds.insert(peer.id)
        
        let selection: ContactsPeerItemSelection
        if let selectionState = selectionState {
            selection = .selectable(selected: selectionState.selectedPeerIndices[peer.id] != nil)
        } else {
            selection = .none
        }
        let header: ListViewItemHeader?
        switch presentation {
            case .orderedByPresence:
                header = commonHeader
            default:
                header = headers[peer.id]
        }
        var presence: EnginePeer.Presence?
        if case let .peer(peer, _, _) = peer {
            presence = presences[peer.id]
        }
        var enabled: Bool
        var requiresPremiumForMessaging = false
        switch peer {
        case let .peer(peer, _, _):
            enabled = !disabledPeerIds.contains(peer.id)
            
            if let value = peerRequiresPremiumForMessaging[peer.id], value {
                requiresPremiumForMessaging = true
            }
            
            if requiresPremiumForMessaging {
                enabled = false
            }
            
            if let isPeerEnabled, !isPeerEnabled(EnginePeer(peer)) {
                enabled = false
            }
        default:
            enabled = true
        }
        
        var storyData: ContactListNodeEntry.StoryData?
        if case let .peer(id) = peer.id {
            storyData = peersWithStories[id].flatMap {
                ContactListNodeEntry.StoryData(count: $0.totalCount, unseenCount: $0.unseenCount, hasUnseenCloseFriends: $0.hasUnseenCloseFriends)
            }
        }
        
        entries.append(.peer(index, peer, presence, header, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, displayCallIcons, false, enabled, storyData, requiresPremiumForMessaging, nil))
        index += 1
    }
    return entries
}

private func preparedContactListNodeTransition(context: AccountContext, presentationData: PresentationData, from fromEntries: [ContactListNodeEntry], to toEntries: [ContactListNodeEntry], interaction: ContactListNodeInteraction, firstTime: Bool, isEmpty: Bool, hasOptions: Bool, generateIndexSections: Bool, animation: ContactListAnimation, isSearch: Bool) -> ContactsListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction, isSearch: isSearch), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, interaction: interaction, isSearch: isSearch), directionHint: nil) }
    
    var shouldFixScroll = false
    var indexSections: [String] = []
    if generateIndexSections {
        var existingSections = Set<unichar>()
        for entry in toEntries {
            switch entry {
                case .sort:
                    shouldFixScroll = true
                case .search:
                    //indexSections.apend(CollectionIndexNode.searchIndex)
                    break
                case let .peer(_, _, _, header, _, _, _, _, _, _, _, _, _, _, _, _):
                    if let header = header as? ContactListNameIndexHeader {
                        if !existingSections.contains(header.letter) {
                            existingSections.insert(header.letter)
                            if let scalar = UnicodeScalar(header.letter) {
                                let title = "\(Character(scalar))"
                                indexSections.append(title)
                            }
                        }
                    }
                default:
                    break
            }
        }
    } else {
        outer: for entry in toEntries {
            switch entry {
                case .sort:
                    shouldFixScroll = true
                    break outer
                default:
                    break
            }
        }
    }
    
    var scrollToItem: ListViewScrollToItem?
    if firstTime && shouldFixScroll && toEntries.count >= 1 {
        scrollToItem = ListViewScrollToItem(index: 0, position: .top(-50.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
    }
    
    return ContactsListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, indexSections: indexSections, firstTime: firstTime, isEmpty: isEmpty, hasOptions: hasOptions, scrollToItem: scrollToItem, animation: animation)
}

private struct ContactsListNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let indexSections: [String]
    let firstTime: Bool
    let isEmpty: Bool
    let hasOptions: Bool
    let scrollToItem: ListViewScrollToItem?
    let animation: ContactListAnimation
}

public enum ContactListPresentation {
    public struct Search {
        public var signal: Signal<String, NoError>
        public var searchChatList: Bool
        public var searchDeviceContacts: Bool
        public var searchGroups: Bool
        public var searchChannels: Bool
        public var globalSearch: Bool
        public var displaySavedMessages: Bool
        
        public init(signal: Signal<String, NoError>, searchChatList: Bool, searchDeviceContacts: Bool, searchGroups: Bool, searchChannels: Bool, globalSearch: Bool, displaySavedMessages: Bool) {
            self.signal = signal
            self.searchChatList = searchChatList
            self.searchDeviceContacts = searchDeviceContacts
            self.searchGroups = searchGroups
            self.searchChannels = searchChannels
            self.globalSearch = globalSearch
            self.displaySavedMessages = displaySavedMessages
        }
    }
    
    public enum TopPeers {
        case none
        case recent
        case custom(showSelf: Bool, selfSubtitle: String?, sections: [(title: String, peerIds: [EnginePeer.Id], hasActions: Bool)])
    }
    
    case orderedByPresence(options: [ContactListAdditionalOption])
    case natural(options: [ContactListAdditionalOption], includeChatList: Bool, topPeers: TopPeers)
    case search(Search)
    
    public var sortOrder: ContactsSortOrder? {
        switch self {
            case .orderedByPresence:
                return .presence
            case .natural:
                return .natural
            default:
                return nil
        }
    }
}

public struct ContactListNodeGroupSelectionState: Equatable {
    public let selectedPeerIndices: [ContactListPeerId: Int]
    public let foundPeers: [ContactListPeer]
    public let selectedPeerMap: [ContactListPeerId: ContactListPeer]
    public let nextSelectionIndex: Int
    
    private init(selectedPeerIndices: [ContactListPeerId: Int], foundPeers: [ContactListPeer], selectedPeerMap: [ContactListPeerId: ContactListPeer], nextSelectionIndex: Int) {
        self.selectedPeerIndices = selectedPeerIndices
        self.foundPeers = foundPeers
        self.selectedPeerMap = selectedPeerMap
        self.nextSelectionIndex = nextSelectionIndex
    }
    
    public init() {
        self.selectedPeerIndices = [:]
        self.foundPeers = []
        self.selectedPeerMap = [:]
        self.nextSelectionIndex = 0
    }
    
    public func withToggledPeerId(_ peerId: ContactListPeerId) -> ContactListNodeGroupSelectionState {
        var updatedIndices = self.selectedPeerIndices
        if let _ = updatedIndices[peerId] {
            updatedIndices.removeValue(forKey: peerId)
            return ContactListNodeGroupSelectionState(selectedPeerIndices: updatedIndices, foundPeers: self.foundPeers, selectedPeerMap: self.selectedPeerMap, nextSelectionIndex: self.nextSelectionIndex)
        } else {
            updatedIndices[peerId] = self.nextSelectionIndex
            return ContactListNodeGroupSelectionState(selectedPeerIndices: updatedIndices, foundPeers: self.foundPeers, selectedPeerMap: self.selectedPeerMap, nextSelectionIndex: self.nextSelectionIndex + 1)
        }
    }
    
    public func withFoundPeers(_ foundPeers: [ContactListPeer]) -> ContactListNodeGroupSelectionState {
        return ContactListNodeGroupSelectionState(selectedPeerIndices: self.selectedPeerIndices, foundPeers: foundPeers, selectedPeerMap: self.selectedPeerMap, nextSelectionIndex: self.nextSelectionIndex)
    }
    
    public func withSelectedPeerMap(_ selectedPeerMap: [ContactListPeerId: ContactListPeer]) -> ContactListNodeGroupSelectionState {
        return ContactListNodeGroupSelectionState(selectedPeerIndices: self.selectedPeerIndices, foundPeers: self.foundPeers, selectedPeerMap: selectedPeerMap, nextSelectionIndex: self.nextSelectionIndex)
    }
 }

public final class ContactListNode: ASDisplayNode {
    private let context: AccountContext
    private var presentation: ContactListPresentation?
    private let filters: [ContactListFilter]
    private let onlyWriteable: Bool
    
    public let listNode: ListView
    private var indexNode: CollectionIndexNode
    private var indexSections: [String]?
    
    private var queuedTransitions: [ContactsListNodeTransition] = []
    private var validLayout: (ContainerViewLayout, UIEdgeInsets, CGFloat)?
    
    private var _ready = ValuePromise<Bool>()
    public var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    private var didSetReady = false
    
    private let contactPeersViewPromise = Promise<(EngineContactList, EnginePeer?, [EnginePeer.Id: Bool], [EnginePeer.Id: PeerStoryStats])>()
    let storySubscriptions = Promise<EngineStorySubscriptions?>(nil)
    
    private let selectionStatePromise = Promise<ContactListNodeGroupSelectionState?>(nil)
    private var selectionStateValue: ContactListNodeGroupSelectionState? {
        didSet {
            self.selectionStatePromise.set(.single(self.selectionStateValue))
            self.selectionStateUpdated?(self.selectionStateValue)
        }
    }
    public var selectionState: ContactListNodeGroupSelectionState? {
        return self.selectionStateValue
    }
    public var selectionStateSignal: Signal<ContactListNodeGroupSelectionState?, NoError> {
        return self.selectionStatePromise.get()
    }
    public var selectionStateUpdated: ((ContactListNodeGroupSelectionState?) -> Void)?
    
    public var selectedPeers: [ContactListPeer] {
        if let selectionState = self.selectionState {
            var selectedPeers: [ContactListPeer] = []
            var selectedIndices: [(Int, ContactListPeerId)] = []
            for (id, index) in selectionState.selectedPeerIndices {
                selectedIndices.append((index, id))
            }
            selectedIndices.sort(by: { lhs, rhs in
                return lhs.0 < rhs.0
            })
            for (_, id) in selectedIndices {
                if let peer = selectionState.selectedPeerMap[id] {
                    selectedPeers.append(peer)
                }
            }
            return selectedPeers
        } else {
            return []
        }
    }
    
    private let pendingRemovalPeerIdsPromise = ValuePromise<Set<EnginePeer.Id>>(Set())
    private var pendingRemovalPeerIds = Set<EnginePeer.Id>() {
        didSet {
            self.pendingRemovalPeerIdsPromise.set(self.pendingRemovalPeerIds)
        }
    }
    
    private var interaction: ContactListNodeInteraction?
    
    private var enableUpdatesValue = false
    public var enableUpdates: Bool {
        get {
            return self.enableUpdatesValue
        } set(value) {
            if value != self.enableUpdatesValue {
                self.enableUpdatesValue = value
                
                let context = self.context
                let contactsWithPremiumRequired: Signal<[EnginePeer.Id: Bool], NoError>
                if self.onlyWriteable {
                    contactsWithPremiumRequired = self.context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Contacts.List(includePresences: false)
                    )
                    |> map { contacts -> Set<EnginePeer.Id> in
                        var result = Set<EnginePeer.Id>()
                        for peer in contacts.peers {
                            if case let .user(user) = peer, user.flags.contains(.requirePremium) {
                                result.insert(peer.id)
                            }
                        }
                        return result
                    }
                    |> distinctUntilChanged
                    |> mapToSignal { peerIds -> Signal<[EnginePeer.Id: Bool], NoError> in
                        return context.engine.data.subscribe(
                            EngineDataMap(
                                peerIds.map(TelegramEngine.EngineData.Item.Peer.IsPremiumRequiredForMessaging.init(id:))
                            )
                        )
                    }
                } else {
                    contactsWithPremiumRequired = .single([:])
                }
                
                let contactsWithStories: Signal<[EnginePeer.Id: PeerStoryStats], NoError> = self.context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Contacts.List(includePresences: false)
                )
                |> map { contacts -> Set<EnginePeer.Id> in
                    var result = Set<EnginePeer.Id>()
                    for peer in contacts.peers {
                        result.insert(peer.id)
                    }
                    return result
                }
                |> distinctUntilChanged
                |> mapToSignal { peerIds -> Signal<[EnginePeer.Id: PeerStoryStats], NoError> in
                    return context.engine.data.subscribe(
                        EngineDataMap(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.StoryStats.init(id:))
                        )
                    )
                    |> map { result -> [EnginePeer.Id: PeerStoryStats] in
                        var filtered: [EnginePeer.Id: PeerStoryStats] = [:]
                        for (id, value) in result {
                            if let value {
                                filtered[id] = value
                            }
                        }
                        return filtered
                    }
                }
                    
                if value {
                    self.contactPeersViewPromise.set(combineLatest(
                        self.context.engine.data.subscribe(
                            TelegramEngine.EngineData.Item.Contacts.List(includePresences: true),
                            TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.engine.account.peerId)
                        ),
                        contactsWithPremiumRequired,
                        contactsWithStories
                    )
                    |> mapToThrottled { next, contactsWithPremiumRequired, contactsWithStories -> Signal<(EngineContactList, EnginePeer?, [EnginePeer.Id: Bool], [EnginePeer.Id: PeerStoryStats]), NoError> in
                        return .single((next.0, next.1, contactsWithPremiumRequired, contactsWithStories))
                        |> then(
                            .complete()
                            |> delay(5.0, queue: Queue.concurrentDefaultQueue())
                        )
                    })
                } else {
                    self.contactPeersViewPromise.set(combineLatest(self.context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Contacts.List(includePresences: true),
                        TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.engine.account.peerId)
                    ),
                    contactsWithPremiumRequired, contactsWithStories)
                    |> map { next, contactsWithPremiumRequired, contactsWithStories -> (EngineContactList, EnginePeer?, [EnginePeer.Id: Bool], [EnginePeer.Id: PeerStoryStats]) in
                        return (next.0, next.1, contactsWithPremiumRequired, contactsWithStories)
                    }
                    |> take(1))
                }
            }
        }
    }
    
    public var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    public var contentScrollingEnded: ((ListView) -> Bool)?
    
    public var activateSearch: (() -> Void)?
    public var openPeer: ((ContactListPeer, ContactListAction, ASDisplayNode?, ContextGesture?) -> Void)?
    public var openDisabledPeer: ((EnginePeer, ChatListDisabledPeerReason) -> Void)?
    public var deselectedAll: (() -> Void)?
    public var updatedSelection: (([EnginePeer], Bool) -> Void)?
    public var openPrivacyPolicy: (() -> Void)?
    public var suppressPermissionWarning: (() -> Void)?
    private let contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?, Bool) -> Void)?
    public var openStories: ((EnginePeer, ASDisplayNode) -> Void)?
    public var openContactAccessPicker: (() -> Void)?
    
    private let previousEntries = Atomic<[ContactListNodeEntry]?>(value: nil)
    private let disposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let presentationDataPromise: Promise<PresentationData>
    
    private var authorizationNode: PermissionContentNode
    private let displayPermissionPlaceholder: Bool
    
    public var multipleSelection = false
    
    private let isPeerEnabled: ((EnginePeer) -> Bool)?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, presentation: Signal<ContactListPresentation, NoError>, filters: [ContactListFilter] = [.excludeSelf], onlyWriteable: Bool, isGroupInvitation: Bool, isPeerEnabled: ((EnginePeer) -> Bool)? = nil, selectionState: ContactListNodeGroupSelectionState? = nil, displayPermissionPlaceholder: Bool = true, displaySortOptions: Bool = false, displayCallIcons: Bool = false, contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?, Bool) -> Void)? = nil, isSearch: Bool = false, multipleSelection: Bool = false) {
        self.context = context
        self.filters = filters
        self.displayPermissionPlaceholder = displayPermissionPlaceholder
        self.contextAction = contextAction
        self.multipleSelection = multipleSelection
        self.isPeerEnabled = isPeerEnabled
        self.onlyWriteable = onlyWriteable
        
        let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        
        self.listNode = ListView()
        self.listNode.dynamicBounceEnabled = false
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.indexNode = CollectionIndexNode()
        
        self.presentationDataPromise = Promise(self.presentationData)
        
        let contactsAuthorization = Promise<AccessType>()
        contactsAuthorization.set(.single(.allowed)
        |> then(DeviceAccess.authorizationStatus(subject: .contacts)))
        
        let contactsWarningSuppressed = Promise<(Bool, Bool)>()
        contactsWarningSuppressed.set(.single((false, false))
        |> then(
            combineLatest(context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .contacts)!), context.account.postbox.preferencesView(keys: [PreferencesKeys.contactsSettings]))
            |> map { noticeView, preferences -> (Bool, Bool) in
                let settings: ContactsSettings = preferences.values[PreferencesKeys.contactsSettings]?.get(ContactsSettings.self) ?? ContactsSettings.defaultSettings
                let synchronizeDeviceContacts: Bool = settings.synchronizeContacts
                let suppressed: Bool
                let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if let timestamp = timestamp, timestamp > 0 {
                    suppressed = true
                } else {
                    suppressed = false
                }
                return (suppressed, !synchronizeDeviceContacts)
            }
        ))
        
        var authorizeImpl: (() -> Void)?
        var openPrivacyPolicyImpl: (() -> Void)?
        
        self.authorizationNode = PermissionContentNode(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, kind: PermissionKind.contacts.rawValue, icon: .image(UIImage(bundleImageName: "Settings/Permissions/Contacts")), title: self.presentationData.strings.Contacts_PermissionsTitle, text: self.presentationData.strings.Contacts_PermissionsText, buttonTitle: self.presentationData.strings.Contacts_PermissionsAllow, buttonAction: {
            authorizeImpl?()
        }, openPrivacyPolicy: {
            openPrivacyPolicyImpl?()
        }, filterHitTest: true)
        self.authorizationNode.isHidden = true
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        
        self.selectionStateValue = selectionState
        self.selectionStatePromise.set(.single(selectionState))
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.indexNode)
        self.addSubnode(self.authorizationNode)
        
        let processingQueue = Queue()
        let previousEntries = Atomic<[ContactListNodeEntry]?>(value: nil)
        let previousSelectionState = Atomic<ContactListNodeGroupSelectionState?>(value: nil)
        let previousPendingRemovalPeerIds = Atomic<Set<EnginePeer.Id>?>(value: nil)
        
        let interaction = ContactListNodeInteraction(activateSearch: { [weak self] in
            self?.activateSearch?()
        }, authorize: {
            authorizeImpl?()
        }, suppressWarning: { [weak self] in
            self?.suppressPermissionWarning?()
        }, openPeer: { [weak self] peer, action, sourceNode, gesture in
            if let strongSelf = self {
                if strongSelf.multipleSelection {
                    var updated = false
                    strongSelf.updateSelectionState({ state in
                        if let state = state {
                            updated = true
                            var selectedPeerMap = state.selectedPeerMap
                            selectedPeerMap[peer.id] = peer
                            return state.withToggledPeerId(peer.id).withSelectedPeerMap(selectedPeerMap)
                        } else {
                            return nil
                        }
                    })
                    if !updated {
                        strongSelf.openPeer?(peer, action, sourceNode, gesture)
                    }
                } else {
                    strongSelf.openPeer?(peer, action, sourceNode, gesture)
                }
            }
        }, openDisabledPeer: { [weak self] peer, reason in
            guard let self else {
                return
            }
            self.openDisabledPeer?(peer, reason)
        }, contextAction: contextAction, openStories: { [weak self] peer, sourceNode in
            guard let self else {
                return
            }
            self.openStories?(peer, sourceNode)
        }, deselectAll: { [weak self] in
            guard let self else {
                return
            }
            self.updateSelectionState({ state in
                return ContactListNodeGroupSelectionState()
            })
            self.deselectedAll?()
        }, toggleSelection: { [weak self] peers, value in
            guard let self = self else {
                return
            }
            self.updateSelectionState({ state in
                var state = state ?? ContactListNodeGroupSelectionState()
                var selectedPeerMap = state.selectedPeerMap
                for peer in peers {
                    let id: ContactListPeerId = .peer(peer.id)
                    if (state.selectedPeerIndices[id] != nil) != value  {
                        state = state.withToggledPeerId(.peer(peer.id))
                    }
                    if value {
                        selectedPeerMap[id] = .peer(peer: peer._asPeer(), isGlobal: false, participantCount: nil)
                    } else {
                        selectedPeerMap.removeValue(forKey: id)
                    }
                }
                state = state.withSelectedPeerMap(selectedPeerMap)
                return state
            })
            self.updatedSelection?(peers, value)
        }, openContactAccessPicker: { [weak self] in
            self?.openContactAccessPicker?()
        })
        
        self.indexNode.indexSelected = { [weak self] section in
            guard let strongSelf = self, let layout = strongSelf.validLayout, let entries = previousEntries.with({ $0 }) else {
                return
            }
            
            var insets = layout.0.insets(options: [.input])
            insets.left = layout.0.safeInsets.left
            insets.right = layout.0.safeInsets.right
            
            var headerInsets = layout.1
            if headerInsets.top == insets.top {
                headerInsets.top -= navigationBarSearchContentHeight
            }
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.0.size, insets: insets, headerInsets: headerInsets, duration: 0.0, curve: .Default(duration: nil))
            
            var index = 0
            var peerIndex = 0
            loop: for entry in entries {
                switch entry {
                    case .search:
                        if section == CollectionIndexNode.searchIndex {
                            strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.PreferSynchronousDrawing, .PreferSynchronousResourceLoading], scrollToItem: ListViewScrollToItem(index: index, position: .top(-navigationBarSearchContentHeight), animated: false, curve: .Default(duration: nil), directionHint: .Down), additionalScrollDistance: 0.0, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                            break loop
                        }
                    case let .peer(_, _, _, header, _, _, _, _, _, _, _, _, _, _, _, _):
                        if let header = header as? ContactListNameIndexHeader {
                            if let scalar = UnicodeScalar(header.letter) {
                                let title = "\(Character(scalar))"
                                if title == section {
                                    strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.PreferSynchronousDrawing, .PreferSynchronousResourceLoading], scrollToItem: ListViewScrollToItem(index: peerIndex == 0 ? 0 : index, position: .top(peerIndex == 0 ? 0.0 : -navigationBarSearchContentHeight), animated: false, curve: .Default(duration: nil), directionHint: .Down), additionalScrollDistance: 0.0, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                                    break loop
                                }
                            }
                        }
                        peerIndex += 1
                    default:
                        break
                }
                index += 1
            }
        }
        
        self.interaction = interaction
        
        let context = self.context
        var firstTime: Int32 = 1
        let selectionStateSignal = self.selectionStatePromise.get()
        let pendingRemovalPeerIdsSignal = self.pendingRemovalPeerIdsPromise.get()
        let transition: Signal<ContactsListNodeTransition, NoError>
        let presentationDataPromise = self.presentationDataPromise
        
        transition = presentation
        |> mapToSignal { presentation in
            var generateSections = false
            var includeChatList = false
            var displayTopPeers: ContactListPresentation.TopPeers = .none
            if case let .natural(_, includeChatListValue, topPeersValue) = presentation {
                generateSections = true
                includeChatList = includeChatListValue
                displayTopPeers = topPeersValue
            }
            
            if case let .search(search) = presentation {
                let query = search.signal
                let searchChatList = search.searchChatList
                let searchDeviceContacts = search.searchDeviceContacts
                let searchGroups = search.searchGroups
                let searchChannels = search.searchChannels
                let globalSearch = search.globalSearch
                let displaySavedMessages = search.displaySavedMessages
                
                return query
                |> mapToSignal { query in
                    let foundLocalContacts: Signal<([FoundPeer], [EnginePeer.Id: EnginePeer.Presence]), NoError>
                    if searchChatList {
                        let foundChatListPeers = context.account.postbox.searchPeers(query: query.lowercased())
                        foundLocalContacts = foundChatListPeers
                        |> mapToSignal { peers -> Signal<([FoundPeer], [EnginePeer.Id: EnginePeer.Presence]), NoError> in
                            var resultPeers: [FoundPeer] = []
                            
                            for peer in peers {
                                if !displaySavedMessages {
                                    if peer.peerId == context.account.peerId {
                                        continue
                                    }
                                }
                                
                                if searchGroups || searchChannels {
                                    let mainPeer = peer.chatMainPeer
                                    if let _ = mainPeer as? TelegramUser {
                                    } else if let _ = mainPeer as? TelegramGroup {
                                    } else if let channel = mainPeer as? TelegramChannel {
                                        if case .broadcast = channel.info {
                                            if !searchChannels {
                                                continue
                                            }
                                        }
                                    } else {
                                        continue
                                    }
                                } else {
                                    if peer.peerId.namespace != Namespaces.Peer.CloudUser {
                                        continue
                                    }
                                }
                                if let mainPeer = peer.chatMainPeer {
                                    var matches = true
                                    if let isPeerEnabled = isPeerEnabled {
                                        matches = isPeerEnabled(EnginePeer(mainPeer))
                                    }
                                    if matches {
                                        resultPeers.append(FoundPeer(peer: mainPeer, subscribers: nil))
                                    }
                                }
                            }
                            
                            return context.engine.data.get(
                                EngineDataMap(resultPeers.map(\.peer.id).map(TelegramEngine.EngineData.Item.Peer.Presence.init)),
                                EngineDataMap(resultPeers.map(\.peer.id).map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                            )
                            |> map { presenceMap, participantCountMap -> ([FoundPeer], [EnginePeer.Id: EnginePeer.Presence]) in
                                var resultPresences: [EnginePeer.Id: EnginePeer.Presence] = [:]
                                var mappedPeers: [FoundPeer] = []
                                for peer in resultPeers {
                                    if let maybePresence = presenceMap[peer.peer.id], let presence = maybePresence {
                                        resultPresences[peer.peer.id] = presence
                                    }
                                    if let _ = peer.peer as? TelegramChannel {
                                        var subscribers: Int32?
                                        if let maybeMemberCount = participantCountMap[peer.peer.id], let memberCount = maybeMemberCount {
                                            subscribers = Int32(memberCount)
                                        }
                                        mappedPeers.append(FoundPeer(peer: peer.peer, subscribers: subscribers))
                                    } else {
                                        mappedPeers.append(peer)
                                    }
                                }
                                return (mappedPeers, resultPresences)
                            }
                        }
                    } else {
                        foundLocalContacts = context.engine.contacts.searchContacts(query: query.lowercased())
                        |> map { peers, presences -> ([FoundPeer], [EnginePeer.Id: EnginePeer.Presence]) in
                            return (peers.map({ FoundPeer(peer: $0._asPeer(), subscribers: nil) }), presences)
                        }
                    }
                    var foundRemoteContacts: Signal<([FoundPeer], [FoundPeer]), NoError> = .single(([], []))
                    if globalSearch {
                        foundRemoteContacts = foundRemoteContacts
                        |> then(
                            context.engine.contacts.searchRemotePeers(query: query)
                            |> map { ($0.0, $0.1) }
                            |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                        )
                    }
                    let foundDeviceContacts: Signal<[DeviceContactStableId: (DeviceContactBasicData, EnginePeer.Id?)], NoError>
                    if searchDeviceContacts {
                        foundDeviceContacts = context.sharedContext.contactDataManager?.search(query: query) ?? .single([:])
                    } else {
                        foundDeviceContacts = .single([:])
                    }
                    
                    let accountPeer = context.account.postbox.loadedPeerWithId(context.account.peerId)
                    |> take(1)
                    
                    struct FoundPeers {
                        var foundLocalContacts: ([FoundPeer], [EnginePeer.Id: EnginePeer.Presence])
                        var foundRemoteContacts: ([FoundPeer], [FoundPeer])
                    }
                    
                    let foundPeers = Promise<FoundPeers>()
                    foundPeers.set(combineLatest(
                        foundLocalContacts,
                        foundRemoteContacts
                    )
                   |> map { foundLocalContacts, foundRemoteContacts -> FoundPeers in
                        return FoundPeers(
                            foundLocalContacts: foundLocalContacts,
                            foundRemoteContacts: foundRemoteContacts
                        )
                    })
                    
                    let peerRequiresPremiumForMessaging: Signal<[EnginePeer.Id: Bool], NoError>
                    if onlyWriteable && !isGroupInvitation {
                        peerRequiresPremiumForMessaging = foundPeers.get()
                        |> map { foundPeers -> Set<EnginePeer.Id> in
                            var result = Set<EnginePeer.Id>()
                            
                            for peer in foundPeers.foundLocalContacts.0 {
                                if let user = peer.peer as? TelegramUser, user.flags.contains(.requirePremium) {
                                    result.insert(user.id)
                                }
                            }
                            
                            for peer in foundPeers.foundRemoteContacts.0 {
                                if let user = peer.peer as? TelegramUser, user.flags.contains(.requirePremium) {
                                    result.insert(user.id)
                                }
                            }
                            for peer in foundPeers.foundRemoteContacts.1 {
                                if let user = peer.peer as? TelegramUser, user.flags.contains(.requirePremium) {
                                    result.insert(user.id)
                                }
                            }
                            
                            return result
                        }
                        |> distinctUntilChanged
                        |> mapToSignal { peerIds -> Signal<[EnginePeer.Id: Bool], NoError> in
                            return context.engine.data.subscribe(
                                EngineDataMap(
                                    peerIds.map(TelegramEngine.EngineData.Item.Peer.IsPremiumRequiredForMessaging.init(id:))
                                )
                            )
                        }
                    } else {
                        peerRequiresPremiumForMessaging = .single([:])
                    }
                    
                    return combineLatest(accountPeer, foundPeers.get(), peerRequiresPremiumForMessaging, foundDeviceContacts, selectionStateSignal, pendingRemovalPeerIdsSignal, presentationDataPromise.get())
                    |> mapToQueue { accountPeer, foundPeers, peerRequiresPremiumForMessaging, deviceContacts, selectionState, pendingRemovalPeerIds, presentationData -> Signal<ContactsListNodeTransition, NoError> in
                        let localPeersAndStatuses = foundPeers.foundLocalContacts
                        let remotePeers = foundPeers.foundRemoteContacts
                        
                        let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                            if !peerRequiresPremiumForMessaging.isEmpty {
                                context.account.viewTracker.refreshCanSendMessagesForPeerIds(peerIds: Array(peerRequiresPremiumForMessaging.keys))
                            }
                            
                            var existingPeerIds = Set<EnginePeer.Id>()
                            var disabledPeerIds = Set<EnginePeer.Id>()

                            var existingNormalizedPhoneNumbers = Set<DeviceContactNormalizedPhoneNumber>()
                            var excludeSelf = false
                            var requirePhoneNumbers = false
                            for filter in filters {
                                switch filter {
                                case .excludeSelf:
                                    excludeSelf = true
                                    existingPeerIds.insert(context.account.peerId)
                                case let .exclude(peerIds):
                                    existingPeerIds = existingPeerIds.union(peerIds)
                                case let .disable(peerIds):
                                    disabledPeerIds = disabledPeerIds.union(peerIds)
                                case .excludeWithoutPhoneNumbers:
                                    requirePhoneNumbers = true
                                case .excludeBots:
                                    break
                                }
                            }
                            
                            var peers: [ContactListPeer] = []
                            
                            if let selectionState = selectionState {
                                for peer in selectionState.foundPeers {
                                    if case let .peer(peer, _, _) = peer {
                                        existingPeerIds.insert(peer.id)
                                    }
                                    peers.append(peer)
                                }
                            }
                            
                            if !excludeSelf && !existingPeerIds.contains(accountPeer.id) {
                                let lowercasedQuery = query.lowercased()
                                if presentationData.strings.DialogList_SavedMessages.lowercased().hasPrefix(lowercasedQuery) || "saved messages".hasPrefix(lowercasedQuery) {
                                    existingPeerIds.insert(accountPeer.id)
                                    peers.append(.peer(peer: accountPeer, isGlobal: false, participantCount: nil))
                                }
                            }
                            
                            for peer in localPeersAndStatuses.0 {
                                if existingPeerIds.contains(peer.peer.id) || pendingRemovalPeerIds.contains(peer.peer.id) {
                                    continue
                                }
                                existingPeerIds.insert(peer.peer.id)
                                peers.append(.peer(peer: peer.peer, isGlobal: false, participantCount: peer.subscribers))
                                if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                    existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                }
                            }
                            for peer in remotePeers.0 {
                                let matches: Bool
                                if let user = peer.peer as? TelegramUser {
                                    let phone = user.phone ?? ""
                                    if requirePhoneNumbers && phone.isEmpty {
                                        matches = false
                                    } else {
                                        matches = true
                                    }
                                } else if searchGroups || searchChannels {
                                    if peer.peer is TelegramGroup && searchGroups {
                                        matches = true
                                    } else if let channel = peer.peer as? TelegramChannel {
                                        if case .group = channel.info {
                                            matches = searchGroups
                                        } else {
                                            matches = searchChannels
                                        }
                                    } else {
                                        matches = false
                                    }
                                } else {
                                    matches = false
                                }
                                
                                if matches {
                                    if existingPeerIds.contains(peer.peer.id) || pendingRemovalPeerIds.contains(peer.peer.id) {
                                        continue
                                    }
                                    existingPeerIds.insert(peer.peer.id)
                                    peers.append(.peer(peer: peer.peer, isGlobal: true, participantCount: peer.subscribers))
                                    if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                        existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                    }
                                }
                            }
                            for peer in remotePeers.1 {
                                let matches: Bool
                                if let user = peer.peer as? TelegramUser {
                                    let phone = user.phone ?? ""
                                    if requirePhoneNumbers && phone.isEmpty {
                                        matches = false
                                    } else {
                                        matches = true
                                    }
                                } else if searchGroups || searchChannels {
                                    if peer.peer is TelegramGroup {
                                        matches = searchGroups
                                    } else if let channel = peer.peer as? TelegramChannel {
                                        if case .group = channel.info {
                                            matches = searchGroups
                                        } else {
                                            matches = searchChannels
                                        }
                                    } else {
                                        matches = false
                                    }
                                } else {
                                    matches = false
                                }
                                
                                if matches {
                                    if existingPeerIds.contains(peer.peer.id) || pendingRemovalPeerIds.contains(peer.peer.id) {
                                        continue
                                    }
                                    existingPeerIds.insert(peer.peer.id)
                                    peers.append(.peer(peer: peer.peer, isGlobal: true, participantCount: peer.subscribers))
                                    if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                        existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                    }
                                }
                            }
                            
                            outer: for (stableId, contact) in deviceContacts {
                                inner: for phoneNumber in contact.0.phoneNumbers {
                                    let normalizedNumber = DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phoneNumber.value))
                                    if existingNormalizedPhoneNumbers.contains(normalizedNumber) {
                                        continue outer
                                    }
                                }
                                if let peerId = contact.1 {
                                    if existingPeerIds.contains(peerId) {
                                        continue outer
                                    }
                                }
                                peers.append(.deviceContact(stableId, contact.0))
                            }
                            
                            let entries = contactListNodeEntries(accountPeer: nil, peers: peers, presences: localPeersAndStatuses.1, presentation: presentation, selectionState: selectionState, theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, disabledPeerIds: disabledPeerIds, peerRequiresPremiumForMessaging: peerRequiresPremiumForMessaging, peersWithStories: [:], authorizationStatus: .allowed, warningSuppressed: (true, true), displaySortOptions: false, displayCallIcons: displayCallIcons, storySubscriptions: nil, topPeers: [], topPeersPresentation: .none, isPeerEnabled: isPeerEnabled, interaction: interaction)
                            let previous = previousEntries.swap(entries)
                            return .single(preparedContactListNodeTransition(context: context, presentationData: presentationData, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, isEmpty: false, hasOptions: false, generateIndexSections: generateSections, animation: .none, isSearch: isSearch))
                        }
                        
                        if OSAtomicCompareAndSwap32(1, 0, &firstTime) {
                            return signal |> runOn(Queue.mainQueue())
                        } else {
                            return signal |> runOn(processingQueue)
                        }
                    }
                }
            } else {
                let chatListSignal: Signal<[(EnginePeer, Int32)], NoError>
                if includeChatList {
                    chatListSignal = self.context.account.viewTracker.tailChatListView(groupId: .root, count: 100)
                    |> take(1)
                    |> mapToSignal { view, _ -> Signal<[(EnginePeer, Int32)], NoError> in
                        return context.engine.data.get(EngineDataMap(
                            view.entries.compactMap { entry -> EnginePeer.Id? in
                                switch entry {
                                case let .MessageEntry(entryData):
                                    if let peer = entryData.renderedPeer.peer {
                                        if let channel = peer as? TelegramChannel, case .group = channel.info {
                                            return peer.id
                                        }
                                    }
                                default:
                                    break
                                }
                                return nil
                            }.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init)
                        ))
                        |> map { participantCountMap -> [(EnginePeer, Int32)] in
                            var peers: [(EnginePeer, Int32)] = []
                            for entry in view.entries {
                                switch entry {
                                case let .MessageEntry(entryData):
                                    if let peer = entryData.renderedPeer.peer {
                                        if peer is TelegramGroup {
                                            peers.append((EnginePeer(peer), 0))
                                        } else if let channel = peer as? TelegramChannel, case .group = channel.info {
                                            var memberCount: Int32 = 0
                                            if let maybeParticipantCount = participantCountMap[peer.id], let participantCount = maybeParticipantCount {
                                                memberCount = Int32(participantCount)
                                            }
                                            peers.append((EnginePeer(peer), memberCount))
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            return peers
                        }
                    }
                } else {
                    chatListSignal = .single([])
                }
                
                struct TopPeer {
                    let peer: EnginePeer
                    let presence: EnginePeer.Presence?
                }
                
                let topPeers: Signal<[TopPeer], NoError>
                switch displayTopPeers {
                case .recent:
                    topPeers = context.engine.peers.recentPeers()
                    |> mapToSignal { recentPeers -> Signal<[TopPeer], NoError> in
                        if case let .peers(peers) = recentPeers {
                            let topPeers = peers.map(EnginePeer.init)
                            return context.engine.data.subscribe(
                                EngineDataMap(peers.map(\.id).map(TelegramEngine.EngineData.Item.Peer.Presence.init))
                            )
                            |> map { presences -> [TopPeer] in
                                var result: [TopPeer] = []
                                for peer in topPeers {
                                    var presence: EnginePeer.Presence?
                                    if let maybePresence = presences[peer.id], let presenceValue = maybePresence {
                                        presence = presenceValue
                                    }
                                    result.append(TopPeer(peer: peer, presence: presence))
                                }
                                return result
                            }
                        } else {
                            return .single([])                      
                        }
                    }
                case let .custom(showSelf, _, sections):
                    var peerIds: [EnginePeer.Id] = []
                    if showSelf {
                        peerIds.append(context.account.peerId)
                    }
                    for (_, sectionPeers, _) in sections {
                        peerIds.append(contentsOf: sectionPeers)
                    }
                    topPeers = combineLatest(
                        context.engine.data.get(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))),
                        context.engine.peers.recentPeers()
                        |> mapToSignal { recentPeers -> Signal<[TopPeer], NoError> in
                            if case let .peers(peers) = recentPeers {
                                let topPeers = peers.map(EnginePeer.init)
                                return context.engine.data.subscribe(
                                    EngineDataMap(peers.map(\.id).map(TelegramEngine.EngineData.Item.Peer.Presence.init))
                                )
                                |> map { presences -> [TopPeer] in
                                    var result: [TopPeer] = []
                                    for peer in topPeers {
                                        var presence: EnginePeer.Presence?
                                        if let maybePresence = presences[peer.id], let presenceValue = maybePresence {
                                            presence = presenceValue
                                        }
                                        result.append(TopPeer(peer: peer, presence: presence))
                                    }
                                    return result
                                }
                            } else {
                                return .single([])
                            }
                        }
                    ) |> map { peers, recentPeers in
                        var result: [TopPeer] = []
                        for peer in peers.values {
                            if let peer {
                                result.append(TopPeer(peer: peer, presence: nil))
                            }
                        }
                        result.append(contentsOf: recentPeers)
                        return result
                    }
                case .none:
                    topPeers = .single([])
                }
                
                return (combineLatest(
                    self.contactPeersViewPromise.get(),
                    chatListSignal,
                    selectionStateSignal,
                    pendingRemovalPeerIdsSignal,
                    presentationDataPromise.get(),
                    contactsAuthorization.get(),
                    contactsWarningSuppressed.get(),
                    self.storySubscriptions.get(),
                    topPeers
                )
                |> mapToQueue { view, chatListPeers, selectionState, pendingRemovalPeerIds, presentationData, authorizationStatus, warningSuppressed, storySubscriptions, topPeers -> Signal<ContactsListNodeTransition, NoError> in
                    let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                        if !view.2.isEmpty {
                            context.account.viewTracker.refreshCanSendMessagesForPeerIds(peerIds: Array(view.2.keys))
                        }
                        
                        var peers = view.0.peers.map({ ContactListPeer.peer(peer: $0._asPeer(), isGlobal: false, participantCount: nil) })
                        for (peer, memberCount) in chatListPeers {
                            peers.append(.peer(peer: peer._asPeer(), isGlobal: false, participantCount: memberCount))
                        }
                        var existingPeerIds = Set<EnginePeer.Id>()
                        var disabledPeerIds = Set<EnginePeer.Id>()
                        var requirePhoneNumbers = false
                        for filter in filters {
                            switch filter {
                            case .excludeSelf:
                                existingPeerIds.insert(context.account.peerId)
                            case let .exclude(peerIds):
                                existingPeerIds = existingPeerIds.union(peerIds)
                            case let .disable(peerIds):
                                disabledPeerIds = disabledPeerIds.union(peerIds)
                            case .excludeWithoutPhoneNumbers:
                                requirePhoneNumbers = true
                            case .excludeBots:
                                break
                            }
                        }
                        
                        peers = peers.filter { contact in
                            switch contact {
                            case let .peer(peer, _, _):
                                if requirePhoneNumbers, let user = peer as? TelegramUser {
                                    let phone = user.phone ?? ""
                                    if phone.isEmpty {
                                        return false
                                    }
                                }
                                return !existingPeerIds.contains(peer.id) && !pendingRemovalPeerIds.contains(peer.id)
                            default:
                                return true
                            }
                        }
                        
                        var presences = view.0.presences
                        for peer in topPeers {
                            if let presence = peer.presence {
                                presences[peer.peer.id] = presence
                            }
                        }
                        
                        var isEmpty = false
                        if (authorizationStatus == .notDetermined || authorizationStatus == .denied) && peers.isEmpty && topPeers.isEmpty {
                            isEmpty = true
                        }
                        
                        let entries = contactListNodeEntries(accountPeer: view.1, peers: peers, presences: presences, presentation: presentation, selectionState: selectionState, theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, disabledPeerIds: disabledPeerIds, peerRequiresPremiumForMessaging: view.2, peersWithStories: view.3, authorizationStatus: authorizationStatus, warningSuppressed: warningSuppressed, displaySortOptions: displaySortOptions, displayCallIcons: displayCallIcons, storySubscriptions: storySubscriptions, topPeers: topPeers.map { $0.peer }, topPeersPresentation: displayTopPeers, isPeerEnabled: isPeerEnabled, interaction: interaction)
                        let previous = previousEntries.swap(entries)
                        let previousSelection = previousSelectionState.swap(selectionState)
                        let previousPendingRemovalPeerIds = previousPendingRemovalPeerIds.swap(pendingRemovalPeerIds)
                        
                        var hadPermissionInfo = false
                        var previousOptionsCount = 0
                        if let previous = previous {
                            for entry in previous {
                                if case .permissionInfo = entry {
                                    hadPermissionInfo = true
                                }
                                if case .option = entry {
                                    previousOptionsCount += 1
                                }
                            }
                        }
                        var hasPermissionInfo = false
                        var optionsCount = 0
                        for entry in entries {
                            if case .permissionInfo = entry {
                                hasPermissionInfo = true
                            }
                            if case .option = entry {
                                optionsCount += 1
                            }
                        }
                        
                        let animation: ContactListAnimation
                        if (previousSelection == nil) != (selectionState == nil) {
                            animation = .insertion
                        } else if previousPendingRemovalPeerIds != pendingRemovalPeerIds {
                            animation = .insertion
                        } else if hadPermissionInfo != hasPermissionInfo {
                            animation = .insertion
                        } else if optionsCount < previousOptionsCount {
                            animation = .insertion
                        } else {
                            animation = .none
                        }
                        
                        return .single(preparedContactListNodeTransition(context: context, presentationData: presentationData, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, isEmpty: isEmpty, hasOptions: optionsCount != 0, generateIndexSections: generateSections, animation: animation, isSearch: isSearch))
                    }
            
                    if OSAtomicCompareAndSwap32(1, 0, &firstTime) {
                        return signal |> runOn(Queue.mainQueue())
                    } else {
                        return signal |> runOn(processingQueue)
                    }
                })
                |> deliverOnMainQueue
            }
        }
        self.disposable.set((transition
        |> deliverOnMainQueue).start(next: { [weak self] transition in
            self?.enqueueTransition(transition)
        }))
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.backgroundColor = presentationData.theme.chatList.backgroundColor
                    strongSelf.listNode.verticalScrollIndicatorColor = presentationData.theme.list.scrollIndicatorColor
                    strongSelf.presentationDataPromise.set(.single(presentationData))
                    
                    let authorizationPreviousHidden = strongSelf.authorizationNode.isHidden
                    strongSelf.authorizationNode.removeFromSupernode()
                    strongSelf.authorizationNode = PermissionContentNode(context: strongSelf.context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, kind: PermissionKind.contacts.rawValue, icon: .image(UIImage(bundleImageName: "Settings/Permissions/Contacts")), title: strongSelf.presentationData.strings.Contacts_PermissionsTitle, text: strongSelf.presentationData.strings.Contacts_PermissionsText, buttonTitle: strongSelf.presentationData.strings.Contacts_PermissionsAllow, buttonAction: {
                        authorizeImpl?()
                    }, openPrivacyPolicy: {
                        openPrivacyPolicyImpl?()
                    }, filterHitTest: true)
                    strongSelf.authorizationNode.isHidden = authorizationPreviousHidden
                    strongSelf.addSubnode(strongSelf.authorizationNode)
                    
                    strongSelf.listNode.dynamicBounceEnabled = false
                    
                    strongSelf.listNode.forEachAccessoryItemNode({ accessoryItemNode in
                        if let accessoryItemNode = accessoryItemNode as? ContactsSectionHeaderAccessoryItemNode {
                            accessoryItemNode.updateTheme(theme: presentationData.theme)
                        }
                    })
                    
                    strongSelf.listNode.forEachItemHeaderNode({ itemHeaderNode in
                        if let itemHeaderNode = itemHeaderNode as? ContactListNameIndexHeaderNode {
                            itemHeaderNode.updateTheme(theme: presentationData.theme)
                        } else if let itemHeaderNode = itemHeaderNode as? ChatListSearchItemHeaderNode {
                            itemHeaderNode.updateTheme(theme: presentationData.theme)
                        }
                    })
                    
                    if let (validLayout, headerInsets, storiesInset) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(validLayout, headerInsets: headerInsets, storiesInset: storiesInset, transition: .immediate)
                    }
                }
            }
        }).strict()
        
        self.listNode.didEndScrolling = { [weak self] _ in
            if let strongSelf = self {
                let _ = strongSelf.contentScrollingEnded?(strongSelf.listNode)
            }
        }
        
        self.listNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                strongSelf.contentOffsetChanged?(offset)
            }
        }
        
        authorizeImpl = {
            let _ = (DeviceAccess.authorizationStatus(subject: .contacts)
            |> take(1)
            |> deliverOnMainQueue).start(next: { status in
                switch status {
                    case .notDetermined:
                        DeviceAccess.authorizeAccess(to: .contacts)
                    case .denied, .restricted:
                        context.sharedContext.applicationBindings.openSettings()
                    default:
                        break
                }
            })
        }
        
        openPrivacyPolicyImpl = { [weak self] in
            self?.openPrivacyPolicy?()
        }
        
        self.enableUpdates = true
    }
    
    public func updateSelectedChatLocation(_ chatLocation: ChatLocation?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        self.interaction?.itemHighlighting.chatLocation = chatLocation
        self.interaction?.itemHighlighting.progress = progress
        
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ContactsPeerItemNode {
                itemNode.updateIsHighlighted(transition: transition)
            }
        }
    }
    
    deinit {
        self.disposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
        
    public func updateSelectionState(_ f: (ContactListNodeGroupSelectionState?) -> ContactListNodeGroupSelectionState?) {
        let updatedSelectionState = f(self.selectionStateValue)
        if updatedSelectionState != self.selectionStateValue {
            self.selectionStateValue = updatedSelectionState
        }
    }
    
    public func updatePendingRemovalPeerIds(_ f: (Set<EnginePeer.Id>) -> Set<EnginePeer.Id>) {
        let updatedPendingRemovalPeerIds = f(self.pendingRemovalPeerIds)
        if updatedPendingRemovalPeerIds != self.pendingRemovalPeerIds {
            self.pendingRemovalPeerIds = updatedPendingRemovalPeerIds
        }
    }
    
    private var previousStoriesInset: CGFloat?
    public var ignoreStoryInsetAdjustment: Bool = false
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, headerInsets: UIEdgeInsets, storiesInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, headerInsets, storiesInset)
        
        var insets = layout.insets(options: [.input])
        insets.left = layout.safeInsets.left
        insets.right = layout.safeInsets.right
        
        var headerInsets = headerInsets
        if !hadValidLayout {
            headerInsets.top -= navigationBarSearchContentHeight
        }
        
        var additionalScrollDistance: CGFloat = 0.0
        
        if let previousStoriesInset = self.previousStoriesInset {
            if self.ignoreStoryInsetAdjustment {
            } else {
                additionalScrollDistance += previousStoriesInset - storiesInset
            }
        }
        self.previousStoriesInset = storiesInset
        
        transition.updateFrame(node: self.listNode, frame: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: headerInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, additionalScrollDistance: additionalScrollDistance, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        if let indexSections = self.indexSections {
            var insets = layout.insets(options: [.input])
            if let inputHeight = layout.inputHeight {
                insets.bottom -= inputHeight
            }
            insets.left = layout.safeInsets.left
            insets.right = layout.safeInsets.right
            
            let indexNodeFrame = CGRect(origin: CGPoint(x: layout.size.width - insets.right - 20.0, y: insets.top), size: CGSize(width: 20.0, height: layout.size.height - insets.top - insets.bottom))
            transition.updateFrame(node: indexNode, frame: indexNodeFrame)
            self.indexNode.update(size: indexNodeFrame.size, color: self.presentationData.theme.list.itemAccentColor, sections: indexSections, transition: transition)
        }
        
        if self.multipleSelection {
            let permissionSize = CGSize(width: layout.size.width, height: layout.size.height - 160.0)
            var permissionInsets = insets
            permissionInsets.bottom += 100.0
            self.authorizationNode.updateLayout(size: permissionSize, insets: permissionInsets, transition: transition)
        } else {
            self.authorizationNode.updateLayout(size: layout.size, insets: insets, transition: transition)
        }
        transition.updateFrame(node: self.authorizationNode, frame: self.bounds)
            
        if !hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: ContactsListNodeTransition) {
        self.queuedTransitions.append(transition)
        
        if self.validLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        if self.validLayout != nil {
            while !self.queuedTransitions.isEmpty {
                let transition = self.queuedTransitions.removeFirst()
                
                var options = ListViewDeleteAndInsertOptions()
                if transition.firstTime {
                    options.insert(.Synchronous)
                    options.insert(.LowLatency)
                    options.insert(.PreferSynchronousDrawing)
                    options.insert(.PreferSynchronousResourceLoading)
                } else if transition.animation != .none {
                    if transition.animation == .insertion {
                        options.insert(.AnimateInsertion)
                    } else if let presentation = self.presentation, case .orderedByPresence = presentation {
                        options.insert(.AnimateCrossfade)
                    }
                }
                if let (layout, _, _) = self.validLayout {
                    self.indexSections = transition.indexSections
                    
                    var insets = layout.insets(options: [.input])
                    insets.left = layout.safeInsets.left
                    insets.right = layout.safeInsets.right
                    
                    if let inputHeight = layout.inputHeight {
                        insets.bottom -= inputHeight
                    }
                    
                    let indexNodeFrame = CGRect(origin: CGPoint(x: layout.size.width - insets.right - 20.0, y: insets.top), size: CGSize(width: 20.0, height: layout.size.height - insets.top - insets.bottom))
                    self.indexNode.frame = indexNodeFrame

                    self.indexNode.update(size: CGSize(width: 20.0, height: layout.size.height - insets.top - insets.bottom), color: self.presentationData.theme.list.itemAccentColor, sections: transition.indexSections, transition: .animated(duration: 0.2, curve: .easeInOut))
                    self.indexNode.isUserInteractionEnabled = !transition.indexSections.isEmpty
                }
                
                self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: transition.scrollToItem, updateOpaqueState: nil, completion: { [weak self] _ in
                    if let strongSelf = self {
                        if !strongSelf.didSetReady {
                            strongSelf.didSetReady = true
                            strongSelf._ready.set(true)
                        }
                    }
                })
                
                self.listNode.isHidden = self.displayPermissionPlaceholder && (transition.isEmpty && !transition.hasOptions)
                self.authorizationNode.isHidden = !transition.isEmpty || !self.displayPermissionPlaceholder
            }
        }
    }
    
    public func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
