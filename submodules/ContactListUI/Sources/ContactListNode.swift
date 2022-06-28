import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
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

private enum ContactListNodeEntryId: Hashable {
    case search
    case sort
    case permission(action: Bool)
    case option(index: Int)
    case peerId(Int64)
    case deviceContact(DeviceContactStableId)
    
    static func <(lhs: ContactListNodeEntryId, rhs: ContactListNodeEntryId) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }

    static func ==(lhs: ContactListNodeEntryId, rhs: ContactListNodeEntryId) -> Bool {
        switch lhs {
            case .search:
                switch rhs {
                    case .search:
                        return true
                    default:
                        return false
                }
            case .sort:
                switch rhs {
                    case .sort:
                        return true
                    default:
                        return false
                }
            case let .permission(action):
                if case .permission(action) = rhs {
                    return true
                } else {
                    return false
                }
            case let .option(index):
                if case .option(index) = rhs {
                    return true
                } else {
                    return false
                }
            case let .peerId(lhsId):
                switch rhs {
                    case let .peerId(rhsId):
                        return lhsId == rhsId
                    default:
                        return false
                }
            case let .deviceContact(id):
                if case .deviceContact(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private final class ContactListNodeInteraction {
    fileprivate let activateSearch: () -> Void
    fileprivate let authorize: () -> Void
    fileprivate let suppressWarning: () -> Void
    fileprivate let openPeer: (ContactListPeer, ContactListAction) -> Void
    fileprivate let contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?) -> Void)?
    
    let itemHighlighting = ContactItemHighlighting()
    
    init(activateSearch: @escaping () -> Void, authorize: @escaping () -> Void, suppressWarning: @escaping () -> Void, openPeer: @escaping (ContactListPeer, ContactListAction) -> Void, contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?) -> Void)?) {
        self.activateSearch = activateSearch
        self.authorize = authorize
        self.suppressWarning = suppressWarning
        self.openPeer = openPeer
        self.contextAction = contextAction
    }
}

enum ContactListAnimation {
    case none
    case `default`
    case insertion
}

private enum ContactListNodeEntry: Comparable, Identifiable {
    case search(PresentationTheme, PresentationStrings)
    case sort(PresentationTheme, PresentationStrings, ContactsSortOrder)
    case permissionInfo(PresentationTheme, String, String, Bool)
    case permissionEnable(PresentationTheme, String)
    case option(Int, ContactListAdditionalOption, ListViewItemHeader?, PresentationTheme, PresentationStrings)
    case peer(Int, ContactListPeer, EnginePeer.Presence?, ListViewItemHeader?, ContactsPeerItemSelection, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PresentationPersonNameOrder, Bool, Bool)
    
    var stableId: ContactListNodeEntryId {
        switch self {
            case .search:
                return .search
            case .sort:
                return .sort
            case .permissionInfo:
                return .permission(action: false)
            case .permissionEnable:
                return .permission(action: true)
            case let .option(index, _, _, _, _):
                return .option(index: index)
            case let .peer(_, peer, _, _, _, _, _, _, _, _, _, _):
                switch peer {
                    case let .peer(peer, _, _):
                        return .peerId(peer.id.toInt64())
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
            case let .option(_, option, header, _, _):
                return ContactListActionItem(presentationData: ItemListPresentationData(presentationData), title: option.title, icon: option.icon, clearHighlightAutomatically: option.clearHighlightAutomatically, header: header, action: option.action)
            case let .peer(_, peer, presence, header, selection, _, strings, dateTimeFormat, nameSortOrder, nameDisplayOrder, displayCallIcons, enabled):
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
                                status = .custom(string: strings.Conversation_StatusMembers(Int32(group.participantCount)), multiline: false)
                            } else if let channel = peer as? TelegramChannel {
                                if case .group = channel.info {
                                    if let participantCount = participantCount, participantCount != 0 {
                                        status = .custom(string: strings.Conversation_StatusMembers(participantCount), multiline: false)
                                    } else {
                                        status = .custom(string: strings.Group_Status, multiline: false)
                                    }
                                } else {
                                    if let participantCount = participantCount, participantCount != 0 {
                                        status = .custom(string: strings.Conversation_StatusSubscribers(participantCount), multiline: false)
                                    } else {
                                        status = .custom(string: strings.Channel_Status, multiline: false)
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
                var itemContextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
                if isContextActionEnabled, let contextAction = interaction.contextAction {
                    itemContextAction = { node, gesture in
                        switch itemPeer {
                        case let .peer(peer, _):
                            if let peer = peer {
                                contextAction(peer, node, gesture)
                            }
                        case .deviceContact:
                            break
                        }
                    }
                }
                
                var additionalActions: [ContactsPeerItemAction] = []
                if displayCallIcons {
                    additionalActions = [ContactsPeerItemAction(icon: .voiceCall, action: { _ in
                        interaction.openPeer(peer, .voiceCall)
                    }), ContactsPeerItemAction(icon: .videoCall, action: { _ in
                        interaction.openPeer(peer, .videoCall)
                    })]
                }
                
                return ContactsPeerItem(presentationData: ItemListPresentationData(presentationData), sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, context: context, peerMode: isSearch ? .generalSearch : .peer, peer: itemPeer, status: status, enabled: enabled, selection: selection, selectionPosition: .left, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), additionalActions: additionalActions, index: nil, header: header, action: { _ in
                    interaction.openPeer(peer, .generic)
                }, itemHighlighting: interaction.itemHighlighting, contextAction: itemContextAction)
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
            case let .option(lhsIndex, lhsOption, lhsHeader, lhsTheme, lhsStrings):
                if case let .option(rhsIndex, rhsOption, rhsHeader, rhsTheme, rhsStrings) = rhs, lhsIndex == rhsIndex, lhsOption == rhsOption, lhsHeader?.id == rhsHeader?.id, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsPeer, lhsPresence, lhsHeader, lhsSelection, lhsTheme, lhsStrings, lhsTimeFormat, lhsSortOrder, lhsDisplayOrder, lhsDisplayCallIcons, lhsEnabled):
                switch rhs {
                    case let .peer(rhsIndex, rhsPeer, rhsPresence, rhsHeader, rhsSelection, rhsTheme, rhsStrings, rhsTimeFormat, rhsSortOrder, rhsDisplayOrder, rhsDisplayCallIcons, rhsEnabled):
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
                        if lhsEnabled != rhsEnabled {
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
            case let .option(lhsIndex, _, _, _, _):
                switch rhs {
                    case .search, .sort, .permissionInfo, .permissionEnable:
                            return false
                        case let .option(rhsIndex, _, _, _, _):
                            return lhsIndex < rhsIndex
                        case .peer:
                            return true
                }
            case let .peer(lhsIndex, _, _, _, _, _, _, _, _, _, _, _):
                switch rhs {
                    case .search, .sort, .permissionInfo, .permissionEnable, .option:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
}

private extension EnginePeer.IndexName {
    func isLessThan(other: EnginePeer.IndexName, ordering: PresentationPersonNameOrder) -> ComparisonResult {
        switch self {
        case let .title(lhsTitle, _):
            let rhsString: String
            switch other {
            case let .title(title, _):
                rhsString = title
            case let .personName(first, last, _, _):
                switch ordering {
                case .firstLast:
                    if first.isEmpty {
                        rhsString = last
                    } else {
                        rhsString = first + last
                    }
                case .lastFirst:
                    if last.isEmpty {
                        rhsString = first
                    } else {
                        rhsString = last + first
                    }
                }
            }
            return lhsTitle.caseInsensitiveCompare(rhsString)
        case let .personName(lhsFirst, lhsLast, _, _):
            let lhsString: String
            switch ordering {
            case .firstLast:
                if lhsFirst.isEmpty {
                    lhsString = lhsLast
                } else {
                    lhsString = lhsFirst + lhsLast
                }
            case .lastFirst:
                if lhsLast.isEmpty {
                    lhsString = lhsFirst
                } else {
                    lhsString = lhsLast + lhsFirst
                }
            }
            let rhsString: String
            switch other {
            case let .title(title, _):
                rhsString = title
            case let .personName(first, last, _, _):
                switch ordering {
                case .firstLast:
                    if first.isEmpty {
                        rhsString = last
                    } else {
                        rhsString = first + last
                    }
                case .lastFirst:
                    if last.isEmpty {
                        rhsString = first
                    } else {
                        rhsString = last + first
                    }
                }
            }
            return lhsString.caseInsensitiveCompare(rhsString)
        }
    }
}

private func contactListNodeEntries(accountPeer: EnginePeer?, peers: [ContactListPeer], presences: [EnginePeer.Id: EnginePeer.Presence], presentation: ContactListPresentation, selectionState: ContactListNodeGroupSelectionState?, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, sortOrder: PresentationPersonNameOrder, displayOrder: PresentationPersonNameOrder, disabledPeerIds: Set<EnginePeer.Id>, authorizationStatus: AccessType, warningSuppressed: (Bool, Bool), displaySortOptions: Bool, displayCallIcons: Bool) -> [ContactListNodeEntry] {
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
    
    if addHeader {
        commonHeader = ChatListSearchItemHeader(type: .contacts, theme: theme, strings: strings, actionTitle: nil, action: nil)
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
        case let .natural(options, _):
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
    
    
    var index: Int = 0
    
    var existingPeerIds = Set<ContactListPeerId>()
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
            
            entries.append(.peer(index, peer, presence, nil, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, displayCallIcons, enabled))
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
        let enabled: Bool
        switch peer {
            case let .peer(peer, _, _):
                enabled = !disabledPeerIds.contains(peer.id)
            default:
                enabled = true
        }
        entries.append(.peer(index, peer, presence, header, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, displayCallIcons, enabled))
        index += 1
    }
    return entries
}

private func preparedContactListNodeTransition(context: AccountContext, presentationData: PresentationData, from fromEntries: [ContactListNodeEntry], to toEntries: [ContactListNodeEntry], interaction: ContactListNodeInteraction, firstTime: Bool, isEmpty: Bool, generateIndexSections: Bool, animation: ContactListAnimation, isSearch: Bool) -> ContactsListNodeTransition {
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
                case let .peer(_, _, _, header, _, _, _, _, _, _, _, _):
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
    
    return ContactsListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, indexSections: indexSections, firstTime: firstTime, isEmpty: isEmpty, scrollToItem: scrollToItem, animation: animation)
}

private struct ContactsListNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let indexSections: [String]
    let firstTime: Bool
    let isEmpty: Bool
    let scrollToItem: ListViewScrollToItem?
    let animation: ContactListAnimation
}

public enum ContactListPresentation {
    case orderedByPresence(options: [ContactListAdditionalOption])
    case natural(options: [ContactListAdditionalOption], includeChatList: Bool)
    case search(signal: Signal<String, NoError>, searchChatList: Bool, searchDeviceContacts: Bool, searchGroups: Bool, searchChannels: Bool, globalSearch: Bool)
    
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
    
    public let listNode: ListView
    private var indexNode: CollectionIndexNode
    private var indexSections: [String]?
    
    private var queuedTransitions: [ContactsListNodeTransition] = []
    private var validLayout: (ContainerViewLayout, UIEdgeInsets)?
    
    private var _ready = ValuePromise<Bool>()
    public var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    private var didSetReady = false
    
    private let contactPeersViewPromise = Promise<(EngineContactList, EnginePeer?)>()
    
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
    
    private var interaction: ContactListNodeInteraction?
    
    private var enableUpdatesValue = false
    public var enableUpdates: Bool {
        get {
            return self.enableUpdatesValue
        } set(value) {
            if value != self.enableUpdatesValue {
                self.enableUpdatesValue = value
                if value {
                    self.contactPeersViewPromise.set(self.context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Contacts.List(includePresences: true),
                        TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.engine.account.peerId)
                    )
                    |> mapToThrottled { next -> Signal<(EngineContactList, EnginePeer?), NoError> in
                        return .single(next)
                        |> then(
                            .complete()
                            |> delay(5.0, queue: Queue.concurrentDefaultQueue())
                        )
                    })
                } else {
                    self.contactPeersViewPromise.set(self.context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Contacts.List(includePresences: true),
                        TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.engine.account.peerId)
                    )
                    |> take(1))
                }
            }
        }
    }
    
    public var contentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)?
    public var contentScrollingEnded: ((ListView) -> Bool)?
    
    public var activateSearch: (() -> Void)?
    public var openPeer: ((ContactListPeer, ContactListAction) -> Void)?
    public var openPrivacyPolicy: (() -> Void)?
    public var suppressPermissionWarning: (() -> Void)?
    private let contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?) -> Void)?
    
    private let previousEntries = Atomic<[ContactListNodeEntry]?>(value: nil)
    private let disposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let presentationDataPromise: Promise<PresentationData>
    
    private var authorizationNode: PermissionContentNode
    private let displayPermissionPlaceholder: Bool
    
    public var multipleSelection = false
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, presentation: Signal<ContactListPresentation, NoError>, filters: [ContactListFilter] = [.excludeSelf], selectionState: ContactListNodeGroupSelectionState? = nil, displayPermissionPlaceholder: Bool = true, displaySortOptions: Bool = false, displayCallIcons: Bool = false, contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?) -> Void)? = nil, isSearch: Bool = false, multipleSelection: Bool = false) {
        self.context = context
        self.filters = filters
        self.displayPermissionPlaceholder = displayPermissionPlaceholder
        self.contextAction = contextAction
        self.multipleSelection = multipleSelection
        
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
        })
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
        
        let interaction = ContactListNodeInteraction(activateSearch: { [weak self] in
            self?.activateSearch?()
        }, authorize: {
            authorizeImpl?()
        }, suppressWarning: { [weak self] in
            self?.suppressPermissionWarning?()
        }, openPeer: { [weak self] peer, action in
            if let strongSelf = self {
                if multipleSelection {
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
                        strongSelf.openPeer?(peer, action)
                    }
                } else {
                    strongSelf.openPeer?(peer, action)
                }
            }
        }, contextAction: contextAction)
        
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
                    case let .peer(_, _, _, header, _, _, _, _, _, _, _, _):
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
        let transition: Signal<ContactsListNodeTransition, NoError>
        let presentationDataPromise = self.presentationDataPromise
        
        transition = presentation
        |> mapToSignal { presentation in
            var generateSections = false
            var includeChatList = false
            if case let .natural(_, includeChatListValue) = presentation {
                generateSections = true
                includeChatList = includeChatListValue
            }
            
            if case let .search(query, searchChatList, searchDeviceContacts, searchGroups, searchChannels, globalSearch) = presentation {
                return query
                |> mapToSignal { query in
                    let foundLocalContacts: Signal<([FoundPeer], [EnginePeer.Id: EnginePeer.Presence]), NoError>
                    if searchChatList {
                        let foundChatListPeers = context.account.postbox.searchPeers(query: query.lowercased())
                        foundLocalContacts = foundChatListPeers
                        |> mapToSignal { peers -> Signal<([FoundPeer], [EnginePeer.Id: EnginePeer.Presence]), NoError> in
                            var resultPeers: [FoundPeer] = []
                            
                            for peer in peers {
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
                                    resultPeers.append(FoundPeer(peer: mainPeer, subscribers: nil))
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
                    
                    return combineLatest(accountPeer, foundLocalContacts, foundRemoteContacts, foundDeviceContacts, selectionStateSignal, presentationDataPromise.get())
                    |> mapToQueue { accountPeer, localPeersAndStatuses, remotePeers, deviceContacts, selectionState, presentationData -> Signal<ContactsListNodeTransition, NoError> in
                        let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                            var existingPeerIds = Set<EnginePeer.Id>()
                            var disabledPeerIds = Set<EnginePeer.Id>()

                            var existingNormalizedPhoneNumbers = Set<DeviceContactNormalizedPhoneNumber>()
                            var excludeSelf = false
                            for filter in filters {
                                switch filter {
                                    case .excludeSelf:
                                        excludeSelf = true
                                        existingPeerIds.insert(context.account.peerId)
                                    case let .exclude(peerIds):
                                        existingPeerIds = existingPeerIds.union(peerIds)
                                    case let .disable(peerIds):
                                        disabledPeerIds = disabledPeerIds.union(peerIds)
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
                                if !existingPeerIds.contains(peer.peer.id) {
                                    existingPeerIds.insert(peer.peer.id)
                                    peers.append(.peer(peer: peer.peer, isGlobal: false, participantCount: peer.subscribers))
                                    if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                        existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                    }
                                }
                            }
                            for peer in remotePeers.0 {
                                let matches: Bool
                                if peer.peer is TelegramUser {
                                    matches = true
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
                                    if !existingPeerIds.contains(peer.peer.id) {
                                        existingPeerIds.insert(peer.peer.id)
                                        peers.append(.peer(peer: peer.peer, isGlobal: true, participantCount: peer.subscribers))
                                        if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                            existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                        }
                                    }
                                }
                            }
                            for peer in remotePeers.1 {
                                let matches: Bool
                                if peer.peer is TelegramUser {
                                    matches = true
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
                                    if !existingPeerIds.contains(peer.peer.id) {
                                        existingPeerIds.insert(peer.peer.id)
                                        peers.append(.peer(peer: peer.peer, isGlobal: true, participantCount: peer.subscribers))
                                        if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                            existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                        }
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
                            
                            let entries = contactListNodeEntries(accountPeer: nil, peers: peers, presences: localPeersAndStatuses.1, presentation: presentation, selectionState: selectionState, theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, disabledPeerIds: disabledPeerIds, authorizationStatus: .allowed, warningSuppressed: (true, true), displaySortOptions: false, displayCallIcons: displayCallIcons)
                            let previous = previousEntries.swap(entries)
                            return .single(preparedContactListNodeTransition(context: context, presentationData: presentationData, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, isEmpty: false, generateIndexSections: generateSections, animation: .none, isSearch: isSearch))
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
                                case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                                    if let peer = renderedPeer.peer {
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
                                case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                                    if let peer = renderedPeer.peer {
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
                
                return (combineLatest(self.contactPeersViewPromise.get(), chatListSignal, selectionStateSignal, presentationDataPromise.get(), contactsAuthorization.get(), contactsWarningSuppressed.get())
                |> mapToQueue { view, chatListPeers, selectionState, presentationData, authorizationStatus, warningSuppressed -> Signal<ContactsListNodeTransition, NoError> in
                    let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                        var peers = view.0.peers.map({ ContactListPeer.peer(peer: $0._asPeer(), isGlobal: false, participantCount: nil) })
                        for (peer, memberCount) in chatListPeers {
                            peers.append(.peer(peer: peer._asPeer(), isGlobal: false, participantCount: memberCount))
                        }
                        var existingPeerIds = Set<EnginePeer.Id>()
                        var disabledPeerIds = Set<EnginePeer.Id>()
                        for filter in filters {
                            switch filter {
                                case .excludeSelf:
                                    existingPeerIds.insert(context.account.peerId)
                                case let .exclude(peerIds):
                                    existingPeerIds = existingPeerIds.union(peerIds)
                                case let .disable(peerIds):
                                    disabledPeerIds = disabledPeerIds.union(peerIds)
                            }
                        }
                        
                        peers = peers.filter { contact in
                            switch contact {
                                case let .peer(peer, _, _):
                                    return !existingPeerIds.contains(peer.id)
                                default:
                                    return true
                            }
                        }
                        
                        var isEmpty = false
                        if (authorizationStatus == .notDetermined || authorizationStatus == .denied) && peers.isEmpty {
                            isEmpty = true
                        }
                        let entries = contactListNodeEntries(accountPeer: view.1, peers: peers, presences: view.0.presences, presentation: presentation, selectionState: selectionState, theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, sortOrder: presentationData.nameSortOrder, displayOrder: presentationData.nameDisplayOrder, disabledPeerIds: disabledPeerIds, authorizationStatus: authorizationStatus, warningSuppressed: warningSuppressed, displaySortOptions: displaySortOptions, displayCallIcons: displayCallIcons)
                        let previous = previousEntries.swap(entries)
                        let previousSelection = previousSelectionState.swap(selectionState)
                        
                        var hadPermissionInfo = false
                        if let previous = previous {
                            for entry in previous {
                                if case .permissionInfo = entry {
                                    hadPermissionInfo = true
                                    break
                                }
                            }
                        }
                        var hasPermissionInfo = false
                        for entry in entries {
                            if case .permissionInfo = entry {
                                hasPermissionInfo = true
                                break
                            }
                        }
                        
                        let animation: ContactListAnimation
                        if (previousSelection == nil) != (selectionState == nil) {
                            animation = .insertion
                        } else if hadPermissionInfo != hasPermissionInfo {
                            animation = .insertion
                        } else {
                            animation = .none
                        }
                        
                        return .single(preparedContactListNodeTransition(context: context, presentationData: presentationData, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, isEmpty: isEmpty, generateIndexSections: generateSections, animation: animation, isSearch: isSearch))
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
                    })
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
                    
                    if let (validLayout, headerInsets) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(validLayout, headerInsets: headerInsets, transition: .immediate)
                    }
                }
            }
        })
        
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
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, headerInsets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, headerInsets)
        
        var insets = layout.insets(options: [.input])
        insets.left = layout.safeInsets.left
        insets.right = layout.safeInsets.right
        
        var headerInsets = headerInsets
        if !hadValidLayout {
            headerInsets.top -= navigationBarSearchContentHeight
        }
        
        transition.updateFrame(node: self.listNode, frame: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, headerInsets: headerInsets, duration: duration, curve: curve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
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
                if let (layout, _) = self.validLayout {
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
                
                self.listNode.isHidden = self.displayPermissionPlaceholder && transition.isEmpty
                self.authorizationNode.isHidden = !transition.isEmpty || !self.displayPermissionPlaceholder
            }
        }
    }
    
    public func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
