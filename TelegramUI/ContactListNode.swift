import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ContactListNodeEntryId: Hashable {
    case search
    case permission(action: Bool)
    case option(index: Int)
    case peerId(Int64)
    case deviceContact(DeviceContactStableId)
    
    var hashValue: Int {
        switch self {
            case .search:
                return 0
            case let .permission(action):
                return (action ? 3 : 2).hashValue
            case let .option(index):
                return (index + 4).hashValue
            case let .peerId(peerId):
                return peerId.hashValue
            case let .deviceContact(id):
                return id.hashValue
        }
    }
    
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
    let activateSearch: () -> Void
    let authorize: () -> Void
    let openPeer: (ContactListPeer) -> Void
    
    init(activateSearch: @escaping () -> Void, authorize: @escaping () -> Void, openPeer: @escaping (ContactListPeer) -> Void) {
        self.activateSearch = activateSearch
        self.authorize = authorize
        self.openPeer = openPeer
    }
}

enum ContactListPeerId: Hashable {
    case peer(PeerId)
    case deviceContact(DeviceContactStableId)
}

enum ContactListPeer: Equatable {
    case peer(peer: Peer, isGlobal: Bool)
    case deviceContact(DeviceContactStableId, DeviceContactBasicData)
    
    var id: ContactListPeerId {
        switch self {
            case let .peer(peer, _):
                return .peer(peer.id)
            case let .deviceContact(id, _):
                return .deviceContact(id)
        }
    }
    
    var indexName: PeerIndexNameRepresentation {
        switch self {
            case let .peer(peer, _):
                return peer.indexName
            case let .deviceContact(_, contact):
                return .personName(first: contact.firstName, last: contact.lastName, addressName: "", phoneNumber: "")
        }
    }
    
    static func ==(lhs: ContactListPeer, rhs: ContactListPeer) -> Bool {
        switch lhs {
            case let .peer(lhsPeer, lhsIsGlobal):
                if case let .peer(rhsPeer, rhsIsGlobal) = rhs, lhsPeer.isEqual(rhsPeer), lhsIsGlobal == rhsIsGlobal {
                    return true
                } else {
                    return false
                }
            case let .deviceContact(id, contact):
                if case .deviceContact(id, contact) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum ContactListNodeEntry: Comparable, Identifiable {
    case search(PresentationTheme, PresentationStrings)
    case permissionInfo(PresentationTheme, PresentationStrings)
    case permissionEnable(PresentationTheme, String)
    case option(Int, ContactListAdditionalOption, ListViewItemHeader?, PresentationTheme, PresentationStrings)
    case peer(Int, ContactListPeer, PeerPresence?, ListViewItemHeader?, ContactsPeerItemSelection, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PresentationPersonNameOrder, Bool)
    
    var stableId: ContactListNodeEntryId {
        switch self {
            case .search:
                return .search
            case .permissionInfo:
                return .permission(action: false)
            case .permissionEnable:
                return .permission(action: true)
            case let .option(index, _, _, _, _):
                return .option(index: index)
            case let .peer(_, peer, _, _, _, _, _, _, _, _, _):
                switch peer {
                    case let .peer(peer, _):
                        return .peerId(peer.id.toInt64())
                    case let .deviceContact(id, _):
                        return .deviceContact(id)
                }
        }
    }
    
    func item(account: Account, interaction: ContactListNodeInteraction) -> ListViewItem {
        switch self {
            case let .search(theme, strings):
                return ChatListSearchItem(theme: theme, placeholder: strings.Contacts_SearchLabel, activate: {
                    interaction.activateSearch()
                })
            case let .permissionInfo(theme, strings):
                return PermissionInfoItem(theme: theme, strings: strings, subject: .contacts)
            case let .permissionEnable(theme, text):
                return ContactListActionItem(theme: theme, title: text, icon: nil, header: nil, action: {
                    interaction.authorize()
                })
            case let .option(_, option, header, theme, _):
                return ContactListActionItem(theme: theme, title: option.title, icon: option.icon, header: header, action: option.action)
            case let .peer(_, peer, presence, header, selection, theme, strings, dateTimeFormat, nameSortOrder, nameDisplayOrder, enabled):
                let status: ContactsPeerItemStatus
                let itemPeer: ContactsPeerItemPeer
                switch peer {
                    case let .peer(peer, isGlobal):
                        if isGlobal, let _ = peer.addressName {
                            status = .addressName("")
                        } else {
                            let presence = presence ?? TelegramUserPresence(status: .none, lastActivity: 0)
                            status = .presence(presence, dateTimeFormat)
                        }
                        itemPeer = .peer(peer: peer, chatPeer: peer)
                    case let .deviceContact(id, contact):
                        status = .none
                        itemPeer = .deviceContact(stableId: id, contact: contact)
                }
                return ContactsPeerItem(theme: theme, strings: strings, sortOrder: nameSortOrder, displayOrder: nameDisplayOrder, account: account, peerMode: .peer, peer: itemPeer, status: status, enabled: enabled, selection: selection, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { _ in
                    interaction.openPeer(peer)
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
            case let .permissionInfo(lhsTheme, lhsStrings):
                if case let .permissionInfo(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
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
            case let .peer(lhsIndex, lhsPeer, lhsPresence, lhsHeader, lhsSelection, lhsTheme, lhsStrings, lhsTimeFormat, lhsSortOrder, lhsDisplayOrder, lhsEnabled):
                switch rhs {
                    case let .peer(rhsIndex, rhsPeer, rhsPresence, rhsHeader, rhsSelection, rhsTheme, rhsStrings, rhsTimeFormat, rhsSortOrder, rhsDisplayOrder, rhsEnabled):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsPeer != rhsPeer {
                            return false
                        }
                        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                            if !lhsPresence.isEqual(to: rhsPresence) {
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
            case .permissionInfo:
                switch rhs {
                    case .search:
                        return false
                    default:
                        return true
                }
            case .permissionEnable:
                switch rhs {
                    case .search, .permissionInfo:
                        return false
                    default:
                        return true
                }
            case let .option(lhsIndex, _, _, _, _):
                switch rhs {
                    case .search, .permissionInfo, .permissionEnable:
                            return false
                        case let .option(rhsIndex, _, _, _, _):
                            return lhsIndex < rhsIndex
                        case .peer:
                            return true
                }
            case let .peer(lhsIndex, _, _, _, _, _, _, _, _, _, _):
                switch rhs {
                    case .search, .permissionInfo, .permissionEnable, .option:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
}

private extension PeerIndexNameRepresentation {
    func isLessThan(other: PeerIndexNameRepresentation, ordering: PresentationPersonNameOrder) -> ComparisonResult {
        switch self {
            case let .title(lhsTitle, _):
                switch other {
                    case let .title(title, _):
                        return lhsTitle.compare(title)
                    case let .personName(_, last, _, _):
                        let lastResult = lhsTitle.compare(last)
                        if lastResult == .orderedSame {
                            return .orderedAscending
                        } else {
                            return lastResult
                        }
                }
            case let .personName(lhsFirst, lhsLast, _, _):
                switch other {
                    case let .title(title, _):
                        let lastResult = lhsFirst.compare(title)
                        if lastResult == .orderedSame {
                            return .orderedDescending
                        } else {
                            return lastResult
                        }
                    case let .personName(first, last, _, _):
                        switch ordering {
                            case .firstLast:
                                let firstResult = lhsFirst.compare(first)
                                if firstResult == .orderedSame {
                                    return lhsLast.compare(last)
                                } else {
                                    return firstResult
                                }
                            case .lastFirst:
                                let lastResult = lhsLast.compare(last)
                                if lastResult == .orderedSame {
                                    return lhsFirst.compare(first)
                                } else {
                                    return lastResult
                                }
                        }
                }
        }
    }
}

private func contactListNodeEntries(accountPeer: Peer?, peers: [ContactListPeer], presences: [PeerId: PeerPresence], presentation: ContactListPresentation, selectionState: ContactListNodeGroupSelectionState?, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, sortOrder: PresentationPersonNameOrder, displayOrder: PresentationPersonNameOrder, disabledPeerIds:Set<PeerId>, authorizationStatus: AccessType) -> [ContactListNodeEntry] {
    var entries: [ContactListNodeEntry] = []
    
    var commonHeader: ListViewItemHeader?
    var orderedPeers: [ContactListPeer]
    var headers: [ContactListPeerId: ContactListNameIndexHeader] = [:]
    
    switch presentation {
        case let .orderedByPresence(options):
            entries.append(.search(theme, strings))
            
            var addHeader = false
            if !peers.isEmpty {
                switch authorizationStatus {
                    case .denied:
                        entries.append(.permissionInfo(theme, strings))
                        entries.append(.permissionEnable(theme, strings.Permissions_ContactsAllowInSettings))
                        addHeader = true
                    case .notDetermined:
                        entries.append(.permissionInfo(theme, strings))
                        entries.append(.permissionEnable(theme, strings.Permissions_ContactsAllow))
                        addHeader = true
                    default:
                        break
                }
            }
            
            if addHeader {
                commonHeader = ChatListSearchItemHeader(type: .contacts, theme: theme, strings: strings, actionTitle: nil, action: nil)
            }
            
            orderedPeers = peers.sorted(by: { lhs, rhs in
                if case let .peer(lhsPeer, _) = lhs, case let .peer(rhsPeer, _) = rhs {
                    let lhsPresence = presences[lhsPeer.id]
                    let rhsPresence = presences[rhsPeer.id]
                    if let lhsPresence = lhsPresence as? TelegramUserPresence, let rhsPresence = rhsPresence as? TelegramUserPresence {
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
        case let .natural(displaySearch, options):
            orderedPeers = peers.sorted(by: { lhs, rhs in
                let result = lhs.indexName.isLessThan(other: rhs.indexName, ordering: sortOrder)
                if result == .orderedSame {
                    if case let .peer(lhsPeer, _) = lhs, case let .peer(rhsPeer, _) = rhs {
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
            for peer in orderedPeers {
                var indexHeader: unichar = 35
                switch peer.indexName {
                    case let .title(title, _):
                        if let c = title.utf16.first {
                            indexHeader = c
                        }
                    case let .personName(first, last, _, _):
                        switch sortOrder {
                            case .firstLast:
                                if let c = first.utf16.first {
                                    indexHeader = c
                                } else if let c = last.utf16.first {
                                    indexHeader = c
                                }
                            case .lastFirst:
                                if let c = last.utf16.first {
                                    indexHeader = c
                                } else if let c = first.utf16.first {
                                    indexHeader = c
                                }
                        }
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
            if displaySearch {
                entries.append(.search(theme, strings))
            }
            for i in 0 ..< options.count {
                entries.append(.option(i, options[i], commonHeader, theme, strings))
            }
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
    
    for i in 0 ..< orderedPeers.count {
        let selection: ContactsPeerItemSelection
        if let selectionState = selectionState {
            selection = .selectable(selected: selectionState.selectedPeerIndices[orderedPeers[i].id] != nil)
        } else {
            selection = .none
        }
        let header: ListViewItemHeader?
        switch presentation {
            case .orderedByPresence:
                header = commonHeader
            default:
                header = headers[orderedPeers[i].id]
        }
        var presence: PeerPresence?
        if case let .peer(peer, _) = orderedPeers[i] {
            presence = presences[peer.id]
        }
        let enabled: Bool
        switch orderedPeers[i] {
            case let .peer(peer, _):
                enabled = !disabledPeerIds.contains(peer.id)
            default:
                enabled = true
        }
        entries.append(.peer(i, orderedPeers[i], presence, header, selection, theme, strings, dateTimeFormat, sortOrder, displayOrder, enabled))
    }
    return entries
}

private func preparedContactListNodeTransition(account: Account, from fromEntries: [ContactListNodeEntry], to toEntries: [ContactListNodeEntry], interaction: ContactListNodeInteraction, firstTime: Bool, isEmpty: Bool, animated: Bool) -> ContactsListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction), directionHint: nil) }
    
    return ContactsListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, isEmpty: isEmpty, animated: animated)
}

private struct ContactsListNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let firstTime: Bool
    let isEmpty: Bool
    let animated: Bool
}

public struct ContactListAdditionalOption: Equatable {
    public let title: String
    public let icon: UIImage?
    public let action: () -> Void
    
    public static func ==(lhs: ContactListAdditionalOption, rhs: ContactListAdditionalOption) -> Bool {
        return lhs.title == rhs.title && lhs.icon === rhs.icon
    }
}

enum ContactListPresentation {
    case orderedByPresence(options: [ContactListAdditionalOption])
    case natural(displaySearch: Bool, options: [ContactListAdditionalOption])
    case search(signal: Signal<String, NoError>, searchChatList: Bool, searchDeviceContacts: Bool)
}

struct ContactListNodeGroupSelectionState: Equatable {
    let selectedPeerIndices: [ContactListPeerId: Int]
    let nextSelectionIndex: Int
    
    private init(selectedPeerIndices: [ContactListPeerId: Int], nextSelectionIndex: Int) {
        self.selectedPeerIndices = selectedPeerIndices
        self.nextSelectionIndex = nextSelectionIndex
    }
    
    init() {
        self.selectedPeerIndices = [:]
        self.nextSelectionIndex = 0
    }
    
    func withToggledPeerId(_ peerId: ContactListPeerId) -> ContactListNodeGroupSelectionState {
        var updatedIndices = self.selectedPeerIndices
        if let _ = updatedIndices[peerId] {
            updatedIndices.removeValue(forKey: peerId)
            return ContactListNodeGroupSelectionState(selectedPeerIndices: updatedIndices, nextSelectionIndex: self.nextSelectionIndex)
        } else {
            updatedIndices[peerId] = self.nextSelectionIndex
            return ContactListNodeGroupSelectionState(selectedPeerIndices: updatedIndices, nextSelectionIndex: self.nextSelectionIndex + 1)
        }
    }
}

enum ContactListFilter {
    case excludeSelf
    case exclude([PeerId])
    case disable([PeerId])
}

final class ContactListNode: ASDisplayNode {
    private let account: Account
    private let presentation: ContactListPresentation
    private let filters: [ContactListFilter]
    
    let listNode: ListView
    
    private var queuedTransitions: [ContactsListNodeTransition] = []
    private var hasValidLayout = false
    
    private var _ready = ValuePromise<Bool>()
    var ready: Signal<Bool, NoError> {
        return self._ready.get()
    }
    private var didSetReady = false
    
    private let contactPeersViewPromise = Promise<ContactPeersView>()
    
    private let selectionStatePromise = Promise<ContactListNodeGroupSelectionState?>(nil)
    private var selectionStateValue: ContactListNodeGroupSelectionState? {
        didSet {
            self.selectionStatePromise.set(.single(self.selectionStateValue))
        }
    }
    
    private var enableUpdatesValue = false
    var enableUpdates: Bool {
        get {
            return self.enableUpdatesValue
        } set(value) {
            if value != self.enableUpdatesValue {
                self.enableUpdatesValue = value
                if value {
                    self.contactPeersViewPromise.set(self.account.postbox.contactPeersView(accountPeerId: self.account.peerId, includePresences: true) |> mapToThrottled { next -> Signal<ContactPeersView, NoError> in
                        return .single(next) |> then(.complete() |> delay(5.0, queue: Queue.concurrentDefaultQueue()))
                    })
                } else {
                    self.contactPeersViewPromise.set(self.account.postbox.contactPeersView(accountPeerId: self.account.peerId, includePresences: true) |> take(1))
                }
            }
        }
    }
    
    var activateSearch: (() -> Void)?
    var openPeer: ((ContactListPeer) -> Void)?
    var openPrivacyPolicy: (() -> Void)?
    
    private let previousEntries = Atomic<[ContactListNodeEntry]?>(value: nil)
    private let disposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, PresentationPersonNameOrder, Bool)>
    
    private let authorizationPromise: Promise<AccessType>
    private var authorizationDisposable: Disposable?
    
    private var authorizationNode: PermissionContentNode
    
    init(account: Account, presentation: ContactListPresentation, filters: [ContactListFilter] = [.excludeSelf], selectionState: ContactListNodeGroupSelectionState? = nil) {
        self.account = account
        self.presentation = presentation
        self.filters = filters
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.listNode = ListView()
        self.listNode.dynamicBounceEnabled = !self.presentationData.disableAnimations
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings, self.presentationData.dateTimeFormat, self.presentationData.nameSortOrder, self.presentationData.nameDisplayOrder, self.presentationData.disableAnimations))
        
        self.authorizationPromise = Promise(AccessType.allowed)
        
        var authorizeImpl: (() -> Void)?
        var openPrivacyPolicyImpl: (() -> Void)?
        
        self.authorizationNode = PermissionContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, kind: .contacts, icon: UIImage(bundleImageName: "Settings/Permissions/Contacts"), title: self.presentationData.strings.Permissions_ContactsTitle, text: self.presentationData.strings.Permissions_ContactsText, buttonTitle: self.presentationData.strings.Contacts_PermissionsAllow, buttonAction: {
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
        self.addSubnode(self.authorizationNode)
        
        let processingQueue = Queue()
        let previousEntries = Atomic<[ContactListNodeEntry]?>(value: nil)
        
        let interaction = ContactListNodeInteraction(activateSearch: { [weak self] in
            self?.activateSearch?()
        }, authorize: {
            authorizeImpl?()
        }, openPeer: { [weak self] peer in
            self?.openPeer?(peer)
        })
        
        let account = self.account
        var firstTime: Int32 = 1
        let selectionStateSignal = self.selectionStatePromise.get()
        let transition: Signal<ContactsListNodeTransition, NoError>
        let themeAndStringsPromise = self.themeAndStringsPromise
        let authorizationsPromise = self.authorizationPromise
        if case let .search(query, searchChatList, searchDeviceContacts) = presentation {
            transition = query
            |> mapToSignal { query in
                let foundLocalContacts: Signal<([Peer], [PeerId : PeerPresence]), NoError>
                if searchChatList {
                    let foundChatListPeers = account.postbox.searchPeers(query: query.lowercased(), groupId: nil)
                    foundLocalContacts = foundChatListPeers
                    |> mapToSignal { peers -> Signal<([Peer], [PeerId : PeerPresence]), NoError> in
                        var resultPeers: [Peer] = []
                        for peer in peers {
                            if peer.peerId.namespace != Namespaces.Peer.CloudUser {
                                continue
                            }
                            if let mainPeer = peer.chatMainPeer {
                                resultPeers.append(mainPeer)
                            }
                        }
                        return account.postbox.transaction { transaction -> ([Peer], [PeerId : PeerPresence]) in
                            var resultPresences: [PeerId: PeerPresence] = [:]
                            for peer in resultPeers {
                                if let presence = transaction.getPeerPresence(peerId: peer.id) {
                                    resultPresences[peer.id] = presence
                                }
                            }
                            return (resultPeers, resultPresences)
                        }
                    }
                } else {
                    foundLocalContacts = account.postbox.searchContacts(query: query.lowercased())
                }
                let foundRemoteContacts: Signal<([FoundPeer], [FoundPeer]), NoError> = .single(([], []))
                |> then(
                    searchPeers(account: account, query: query)
                    |> map { ($0.0, $0.1) }
                    |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                )
                let foundDeviceContacts: Signal<[DeviceContactStableId: DeviceContactBasicData], NoError>
                if searchDeviceContacts {
                    foundDeviceContacts = account.telegramApplicationContext.contactDataManager.search(query: query)
                } else {
                    foundDeviceContacts = .single([:])
                }
                
                return combineLatest(foundLocalContacts, foundRemoteContacts, foundDeviceContacts, selectionStateSignal, themeAndStringsPromise.get())
                |> mapToQueue { localPeersAndStatuses, remotePeers, deviceContacts, selectionState, themeAndStrings -> Signal<ContactsListNodeTransition, NoError> in
                    let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                        var existingPeerIds = Set<PeerId>()
                        var disabledPeerIds = Set<PeerId>()

                        var existingNormalizedPhoneNumbers = Set<DeviceContactNormalizedPhoneNumber>()
                        for filter in filters {
                            switch filter {
                                case .excludeSelf:
                                    existingPeerIds.insert(account.peerId)
                                case let .exclude(peerIds):
                                    existingPeerIds = existingPeerIds.union(peerIds)
                                case let .disable(peerIds):
                                    disabledPeerIds = disabledPeerIds.union(peerIds)
                            }
                        }
                        
                        var peers: [ContactListPeer] = []
                        for peer in localPeersAndStatuses.0 {
                            if !existingPeerIds.contains(peer.id) {
                                existingPeerIds.insert(peer.id)
                                peers.append(.peer(peer: peer, isGlobal: false))
                                if searchDeviceContacts, let user = peer as? TelegramUser, let phone = user.phone {
                                    existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                }
                            }
                        }
                        for peer in remotePeers.0 {
                            if peer.peer is TelegramUser {
                                if !existingPeerIds.contains(peer.peer.id) {
                                    existingPeerIds.insert(peer.peer.id)
                                    peers.append(.peer(peer: peer.peer, isGlobal: true))
                                    if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                        existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                    }
                                }
                            }
                        }
                        for peer in remotePeers.1 {
                            if peer.peer is TelegramUser {
                                if !existingPeerIds.contains(peer.peer.id) {
                                    existingPeerIds.insert(peer.peer.id)
                                    peers.append(.peer(peer: peer.peer, isGlobal: true))
                                    if searchDeviceContacts, let user = peer.peer as? TelegramUser, let phone = user.phone {
                                        existingNormalizedPhoneNumbers.insert(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone)))
                                    }
                                }
                            }
                        }
                        
                        outer: for (stableId, contact) in deviceContacts {
                            inner: for phoneNumber in contact.phoneNumbers {
                                let normalizedNumber = DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phoneNumber.value))
                                if existingNormalizedPhoneNumbers.contains(normalizedNumber) {
                                    continue outer
                                }
                            }
                            peers.append(.deviceContact(stableId, contact))
                        }
                        
                        let entries = contactListNodeEntries(accountPeer: nil, peers: peers, presences: localPeersAndStatuses.1, presentation: presentation, selectionState: selectionState, theme: themeAndStrings.0, strings: themeAndStrings.1, dateTimeFormat: themeAndStrings.2, sortOrder: themeAndStrings.3, displayOrder: themeAndStrings.4, disabledPeerIds: disabledPeerIds, authorizationStatus: .allowed)
                        let previous = previousEntries.swap(entries)
                        return .single(preparedContactListNodeTransition(account: account, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, isEmpty: false, animated: false))
                    }
                    
                    if OSAtomicCompareAndSwap32(1, 0, &firstTime) {
                        return signal |> runOn(Queue.mainQueue())
                    } else {
                        return signal |> runOn(processingQueue)
                    }
                }
            }
        } else {
            transition = (combineLatest(self.contactPeersViewPromise.get(), selectionStateSignal, themeAndStringsPromise.get(), authorizationsPromise.get())
                |> mapToQueue { view, selectionState, themeAndStrings, authorizationStatus -> Signal<ContactsListNodeTransition, NoError> in
                    let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                        var peers = view.peers.map({ ContactListPeer.peer(peer: $0, isGlobal: false) })
                        var existingPeerIds = Set<PeerId>()
                        var disabledPeerIds = Set<PeerId>()
                        for filter in filters {
                            switch filter {
                            case .excludeSelf:
                                existingPeerIds.insert(account.peerId)
                            case let .exclude(peerIds):
                                existingPeerIds = existingPeerIds.union(peerIds)
                            case let .disable(peerIds):
                                disabledPeerIds = disabledPeerIds.union(peerIds)
                            }
                        }
                        
                        peers = peers.filter { contact in
                            switch contact {
                            case let .peer(peer, _):
                                return !existingPeerIds.contains(peer.id)
                            default:
                                return true
                            }
                        }
                        
                        var isEmpty = false
                        if (authorizationStatus == .notDetermined || authorizationStatus == .denied) && peers.isEmpty {
                            isEmpty = true
                        }
                        let entries = contactListNodeEntries(accountPeer: view.accountPeer, peers: peers, presences: view.peerPresences, presentation: presentation, selectionState: selectionState, theme: themeAndStrings.0, strings: themeAndStrings.1, dateTimeFormat: themeAndStrings.2, sortOrder: themeAndStrings.3, displayOrder: themeAndStrings.4, disabledPeerIds: disabledPeerIds, authorizationStatus: authorizationStatus)
                        let previous = previousEntries.swap(entries)
                        let animated: Bool
                        if let previous = previous, !themeAndStrings.5 {
                            animated = (entries.count - previous.count) < 20
                        } else {
                            animated = false
                        }
                        return .single(preparedContactListNodeTransition(account: account, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, isEmpty: isEmpty, animated: animated))
                    }
            
                    if OSAtomicCompareAndSwap32(1, 0, &firstTime) {
                        return signal |> runOn(Queue.mainQueue())
                    } else {
                        return signal |> runOn(processingQueue)
                    }
                })
                |> deliverOnMainQueue
        }
        self.disposable.set(transition.start(next: { [weak self] transition in
            self?.enqueueTransition(transition)
        }))
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                let previousDisableAnimations = strongSelf.presentationData.disableAnimations
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings || previousDisableAnimations != presentationData.disableAnimations {
                    strongSelf.backgroundColor = presentationData.theme.chatList.backgroundColor
                    strongSelf.listNode.verticalScrollIndicatorColor = presentationData.theme.list.scrollIndicatorColor
                    strongSelf.themeAndStringsPromise.set(.single((presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameSortOrder, presentationData.nameDisplayOrder, presentationData.disableAnimations)))
                    
                    let authorizationPreviousHidden = strongSelf.authorizationNode.isHidden
                    strongSelf.authorizationNode.removeFromSupernode()
                    strongSelf.authorizationNode = PermissionContentNode(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, kind: .contacts, icon: UIImage(bundleImageName: "Settings/Permissions/Contacts"), title: strongSelf.presentationData.strings.Permissions_ContactsTitle, text: strongSelf.presentationData.strings.Permissions_ContactsText, buttonTitle: strongSelf.presentationData.strings.Contacts_PermissionsAllow, buttonAction: {
                        authorizeImpl?()
                    }, openPrivacyPolicy: {
                        openPrivacyPolicyImpl?()
                    })
                    strongSelf.authorizationNode.isHidden = authorizationPreviousHidden
                    strongSelf.addSubnode(strongSelf.authorizationNode)
                    
                    strongSelf.listNode.dynamicBounceEnabled = !presentationData.disableAnimations
                    
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
                }
            }
        })
        
        self.authorizationDisposable = (DeviceAccess.authorizationStatus(account: account, subject: .contacts)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                strongSelf.authorizationPromise.set(.single(status))
            }
        })
        
        self.listNode.didEndScrolling = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            fixSearchableListNodeScrolling(strongSelf.listNode)
        }
        
        authorizeImpl = { [weak self] in
            if let strongSelf = self {
                let _ = (DeviceAccess.authorizationStatus(account: account, subject: .contacts)
                |> take(1)
                |> deliverOnMainQueue).start(next: { status in
                    switch status {
                        case .notDetermined:
                            DeviceAccess.authorizeAccess(to: .contacts, presentationData: strongSelf.presentationData, present: { _, _ in }, openSettings: {}, { _ in })
                        case .denied, .restricted:
                            account.telegramApplicationContext.applicationBindings.openSettings()
                        default:
                            break
                    }
                })
            }
        }
        
        openPrivacyPolicyImpl = { [weak self] in
            self?.openPrivacyPolicy?()
        }
        
        self.enableUpdates = true
    }
    
    deinit {
        self.disposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    func updateSelectionState(_ f: (ContactListNodeGroupSelectionState?) -> ContactListNodeGroupSelectionState?) {
        let updatedSelectionState = f(self.selectionStateValue)
        if updatedSelectionState != self.selectionStateValue {
            self.selectionStateValue = updatedSelectionState
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.input])
        insets.left += layout.safeInsets.left
        insets.right += layout.safeInsets.right
        
        self.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.listNode.position = CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0)
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
            case .immediate:
                break
            case let .animated(animationDuration, animationCurve):
                duration = animationDuration
                switch animationCurve {
                    case .easeInOut:
                        break
                    case .spring:
                        curve = 7
                }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        //if let authorizationNode = self.authorizationNode {
            authorizationNode.updateLayout(size: layout.size, insets: insets, transition: transition)
            transition.updateFrame(node: authorizationNode, frame: self.bounds)
        //}
            
        if !self.hasValidLayout {
            self.hasValidLayout = true
            self.dequeueTransitions()
        }
    }
    
    private func enqueueTransition(_ transition: ContactsListNodeTransition) {
        self.queuedTransitions.append(transition)
        
        if self.hasValidLayout {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        if self.hasValidLayout {
            while !self.queuedTransitions.isEmpty {
                let transition = self.queuedTransitions.removeFirst()
                
                var options = ListViewDeleteAndInsertOptions()
                if transition.firstTime {
                    options.insert(.Synchronous)
                    options.insert(.LowLatency)
                } else if transition.animated {
                    if case .orderedByPresence = self.presentation {
                        options.insert(.AnimateCrossfade)
                    }
                }
                self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
                    if let strongSelf = self {
                        if !strongSelf.didSetReady {
                            strongSelf.didSetReady = true
                            strongSelf._ready.set(true)
                        }
                    }
                })
                
                self.listNode.isHidden = transition.isEmpty
                self.authorizationNode.isHidden = !transition.isEmpty
            }
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
