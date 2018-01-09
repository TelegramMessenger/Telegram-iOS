import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ContactListNodeEntryId: Hashable {
    case search
    case option(index: Int)
    case peerId(Int64)
    
    var hashValue: Int {
        switch self {
            case .search:
                return 0
            case let .option(index):
                return (index + 2).hashValue
            case let .peerId(peerId):
                return peerId.hashValue
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
        }
    }
}

private final class ContactListNodeInteraction {
    let activateSearch: () -> Void
    let openPeer: (Peer) -> Void
    
    init(activateSearch: @escaping () -> Void, openPeer: @escaping (Peer) -> Void) {
        self.activateSearch = activateSearch
        self.openPeer = openPeer
    }
}

private enum ContactListNodeEntry: Comparable, Identifiable {
    case search(PresentationTheme, PresentationStrings)
    case option(Int, ContactListAdditionalOption, PresentationTheme, PresentationStrings)
    case peer(Int, Peer, PeerPresence?, ContactListNameIndexHeader?, ContactsPeerItemSelection, PresentationTheme, PresentationStrings)
    
    var stableId: ContactListNodeEntryId {
        switch self {
            case .search:
                return .search
            case let .option(index, _, _, _):
                return .option(index: index)
            case let .peer(_, peer, _, _, _, _, _):
                return .peerId(peer.id.toInt64())
        }
    }
    
    func item(account: Account, interaction: ContactListNodeInteraction) -> ListViewItem {
        switch self {
            case let .search(theme, strings):
                return ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                    interaction.activateSearch()
                })
            case let .option(_, option, theme, strings):
                return ContactListActionItem(theme: theme, title: option.title, icon: option.icon, action: option.action)
            case let .peer(_, peer, presence, header, selection, theme, strings):
                let status: ContactsPeerItemStatus
                if let presence = presence {
                    status = .presence(presence)
                } else {
                    status = .none
                }
                return ContactsPeerItem(theme: theme, strings: strings, account: account, peer: peer, chatPeer: peer, status: status, enabled: true, selection: selection, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: header, action: { _ in
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
            case let .option(lhsIndex, lhsOption, lhsTheme, lhsStrings):
                if case let .option(rhsIndex, rhsOption, rhsTheme, rhsStrings) = rhs, lhsIndex == rhsIndex, lhsOption == rhsOption, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsIndex, lhsPeer, lhsPresence, lhsHeader, lhsSelection, lhsTheme, lhsStrings):
                switch rhs {
                    case let .peer(rhsIndex, rhsPeer, rhsPresence, rhsHeader, rhsSelection, rhsTheme, rhsStrings):
                        if lhsIndex != rhsIndex {
                            return false
                        }
                        if lhsPeer.id != rhsPeer.id {
                            return false
                        }
                        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                            if !lhsPresence.isEqual(to: rhsPresence) {
                                return false
                            }
                        } else if (lhsPresence != nil) != (rhsPresence != nil) {
                            return false
                        }
                        if lhsHeader != rhsHeader {
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
            case let .option(lhsIndex, _, _, _):
                switch rhs {
                    case .search:
                        return false
                    case let .option(rhsIndex, _, _, _):
                        return lhsIndex < rhsIndex
                    case .peer:
                        return true
                }
            case let .peer(lhsIndex, _, _, _, _, _, _):
                switch rhs {
                    case .search, .option:
                        return false
                    case let .peer(rhsIndex, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
}

private extension PeerIndexNameRepresentation {
    func isLessThan(other: PeerIndexNameRepresentation) -> ComparisonResult {
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

private func contactListNodeEntries(accountPeer: Peer?, peers: [Peer], presences: [PeerId: PeerPresence], presentation: ContactListPresentation, selectionState: ContactListNodeGroupSelectionState?, theme: PresentationTheme, strings: PresentationStrings) -> [ContactListNodeEntry] {
    var entries: [ContactListNodeEntry] = []
    
    var orderedPeers: [Peer]
    var headers: [PeerId: ContactListNameIndexHeader] = [:]
    
    switch presentation {
        case .orderedByPresence:
            entries.append(.search(theme, strings))
            orderedPeers = peers.sorted(by: { lhs, rhs in
                let lhsPresence = presences[lhs.id]
                let rhsPresence = presences[rhs.id]
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
                return lhs.id < rhs.id
            })
        case let .natural(displaySearch, options):
            orderedPeers = peers.sorted(by: { lhs, rhs in
                let result = lhs.indexName.isLessThan(other: rhs.indexName)
                if result == .orderedSame {
                    return lhs.id < rhs.id
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
                        if let c = last.utf16.first {
                            indexHeader = c
                        } else if let c = first.utf16.first {
                            indexHeader = c
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
                entries.append(.option(i, options[i], theme, strings))
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
        entries.append(.peer(i, orderedPeers[i], presences[orderedPeers[i].id], headers[orderedPeers[i].id], selection, theme, strings))
    }
    return entries
}

private func preparedContactListNodeTransition(account: Account, from fromEntries: [ContactListNodeEntry], to toEntries: [ContactListNodeEntry], interaction: ContactListNodeInteraction, firstTime: Bool, animated: Bool) -> ContactsListNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction), directionHint: nil) }
    
    return ContactsListNodeTransition(deletions: deletions, insertions: insertions, updates: updates, firstTime: firstTime, animated: animated)
}

private struct ContactsListNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let firstTime: Bool
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
    case orderedByPresence
    case natural(displaySearch: Bool, options: [ContactListAdditionalOption])
    case search(Signal<String, NoError>)
}

struct ContactListNodeGroupSelectionState: Equatable {
    let selectedPeerIndices: [PeerId: Int]
    let nextSelectionIndex: Int
    
    private init(selectedPeerIndices: [PeerId: Int], nextSelectionIndex: Int) {
        self.selectedPeerIndices = selectedPeerIndices
        self.nextSelectionIndex = nextSelectionIndex
    }
    
    init() {
        self.selectedPeerIndices = [:]
        self.nextSelectionIndex = 0
    }
    
    func withToggledPeerId(_ peerId: PeerId) -> ContactListNodeGroupSelectionState {
        var updatedIndices = self.selectedPeerIndices
        if let _ = updatedIndices[peerId] {
            updatedIndices.removeValue(forKey: peerId)
            return ContactListNodeGroupSelectionState(selectedPeerIndices: updatedIndices, nextSelectionIndex: self.nextSelectionIndex)
        } else {
            updatedIndices[peerId] = self.nextSelectionIndex
            return ContactListNodeGroupSelectionState(selectedPeerIndices: updatedIndices, nextSelectionIndex: self.nextSelectionIndex + 1)
        }
    }
    
    static func ==(lhs: ContactListNodeGroupSelectionState, rhs: ContactListNodeGroupSelectionState) -> Bool {
        return lhs.selectedPeerIndices == rhs.selectedPeerIndices && lhs.nextSelectionIndex == rhs.nextSelectionIndex
    }
}

final class ContactListNode: ASDisplayNode {
    private let account: Account
    
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
                    self.contactPeersViewPromise.set(self.account.postbox.contactPeersView(accountPeerId: self.account.peerId))
                } else {
                    self.contactPeersViewPromise.set(self.account.postbox.contactPeersView(accountPeerId: self.account.peerId) |> take(1))
                }
            }
        }
    }
    
    var activateSearch: (() -> Void)?
    var openPeer: ((Peer) -> Void)?
    
    private let previousEntries = Atomic<[ContactListNodeEntry]?>(value: nil)
    private let disposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    init(account: Account, presentation: ContactListPresentation, selectionState: ContactListNodeGroupSelectionState? = nil) {
        self.account = account
        
        self.listNode = ListView()
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.selectionStateValue = selectionState
        self.selectionStatePromise.set(.single(selectionState))
        
        self.addSubnode(self.listNode)
        
        let processingQueue = Queue()
        let previousEntries = Atomic<[ContactListNodeEntry]?>(value: nil)
        
        let interaction = ContactListNodeInteraction(activateSearch: { [weak self] in
            self?.activateSearch?()
        }, openPeer: { [weak self] peer in
            self?.openPeer?(peer)
        })
        
        let account = self.account
        var firstTime: Int32 = 1
        let selectionStateSignal = self.selectionStatePromise.get()
        let transition: Signal<ContactsListNodeTransition, NoError>
        let themeAndStringsPromise = self.themeAndStringsPromise
        if case let .search(query) = presentation {
            transition = query
                |> mapToSignal { query in
                    return combineLatest(account.postbox.searchContacts(query: query), selectionStateSignal, themeAndStringsPromise.get())
                        |> mapToQueue { peers, selectionState, themeAndStrings -> Signal<ContactsListNodeTransition, NoError> in
                            let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                                let entries = contactListNodeEntries(accountPeer: nil, peers: peers, presences: [:], presentation: presentation, selectionState: selectionState, theme: themeAndStrings.0, strings: themeAndStrings.1)
                                let previous = previousEntries.swap(entries)
                                return .single(preparedContactListNodeTransition(account: account, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, animated: false))
                            }
                            
                            if OSAtomicCompareAndSwap32(1, 0, &firstTime) {
                                return signal |> runOn(Queue.mainQueue())
                            } else {
                                return signal |> runOn(processingQueue)
                            }
                        }
                }
        } else {
            transition = (combineLatest(self.contactPeersViewPromise.get(), selectionStateSignal, themeAndStringsPromise.get())
                |> mapToQueue { view, selectionState, themeAndStrings -> Signal<ContactsListNodeTransition, NoError> in
                    let signal = deferred { () -> Signal<ContactsListNodeTransition, NoError> in
                        let entries = contactListNodeEntries(accountPeer: view.accountPeer, peers: view.peers, presences: view.peerPresences, presentation: presentation, selectionState: selectionState, theme: themeAndStrings.0, strings: themeAndStrings.1)
                        let previous = previousEntries.swap(entries)
                        let animated: Bool
                        if let previous = previous {
                            animated = (entries.count - previous.count) < 20
                        } else {
                            animated = false
                        }
                        return .single(preparedContactListNodeTransition(account: account, from: previous ?? [], to: entries, interaction: interaction, firstTime: previous == nil, animated: animated))
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
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.backgroundColor = presentationData.theme.chatList.backgroundColor
                        strongSelf.themeAndStringsPromise.set(.single((presentationData.theme, presentationData.strings)))
                    }
                }
            })
        
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
            listViewCurve = .Default
        }
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: layout.size, insets: insets, duration: duration, curve: listViewCurve)
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
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
                    options.insert(.AnimateInsertion)
                }
                self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
                    if let strongSelf = self {
                        if !strongSelf.didSetReady {
                            strongSelf.didSetReady = true
                            strongSelf._ready.set(true)
                        }
                    }
                })
            }
        }
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default, directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
