import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore

private enum ContactsControllerEntryId: Hashable {
    case search
    case vcard
    case peerId(Int64)
    
    var hashValue: Int {
        switch self {
            case .search:
                return 0
            case .vcard:
                return 1
            case let .peerId(peerId):
                return peerId.hashValue
        }
    }
}

private func <(lhs: ContactsControllerEntryId, rhs: ContactsControllerEntryId) -> Bool {
    return lhs.hashValue < rhs.hashValue
}

private func ==(lhs: ContactsControllerEntryId, rhs: ContactsControllerEntryId) -> Bool {
    switch lhs {
        case .search:
            switch rhs {
                case .search:
                    return true
                default:
                    return false
            }
        case .vcard:
            switch rhs {
                case .vcard:
                    return true
                default:
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

private enum ContactsEntry: Comparable, Identifiable {
    case search
    case vcard(Peer)
    case peer(Peer, PeerPresence?)
    
    var stableId: ContactsControllerEntryId {
        switch self {
            case .search:
                return .search
            case .vcard:
                return .vcard
            case let .peer(peer, _):
                return .peerId(peer.id.toInt64())
        }
    }
    
    func item(account: Account, index: PeerNameIndex, interaction: ContactsControllerInteraction) -> ListViewItem {
        switch self {
            case .search:
                return ChatListSearchItem(placeholder: "Search contacts", activate: {
                    interaction.activateSearch()
                })
            case let .vcard(peer):
                return ContactsVCardItem(account: account, peer: peer, action: { peer in
                    interaction.openPeer(peer.id)
                })
            case let .peer(peer, presence):
                let status: ContactsPeerItemStatus
                if let presence = presence {
                    status = .presence(presence)
                } else {
                    status = .none
                }
                return ContactsPeerItem(account: account, peer: peer, status: status, index: nil, header: nil, action: { _ in
                    interaction.openPeer(peer.id)
                })
        }
    }
}

private func ==(lhs: ContactsEntry, rhs: ContactsEntry) -> Bool {
    switch lhs {
        case .search:
            switch rhs {
                case .search:
                    return true
                default:
                    return false
            }
        case let .vcard(lhsPeer):
            switch rhs {
                case let .vcard(rhsPeer):
                    return lhsPeer.id == rhsPeer.id
                default:
                    return false
            }
        case let .peer(lhsPeer, lhsPresence):
            switch rhs {
                case let .peer(rhsPeer, rhsPresence):
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
                    return true
                default:
                    return false
            }
    }
}

private func <(lhs: ContactsEntry, rhs: ContactsEntry) -> Bool {
    switch lhs {
        case .search:
            return true
        case .vcard:
            switch rhs {
                case .search, .vcard:
                    return false
                case .peer:
                    return true
            }
        case let .peer(lhsPeer, lhsPresence):
            switch rhs {
                case .search:
                    return false
                case .vcard:
                    return false
                case let .peer(rhsPeer, rhsPresence):
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
            }
    }
}

private func contactListEntries(_ view: ContactPeersView) -> [ContactsEntry] {
    var entries: [ContactsEntry] = []
    entries.append(.search)
    if let peer = view.accountPeer {
        entries.append(.vcard(peer))
    }
    for peer in view.peers {
        entries.append(.peer(peer, view.peerPresences[peer.id]))
    }
    entries.sort()
    return entries
}

private struct ContactsListTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private final class ContactsControllerInteraction {
    let openPeer: (PeerId) -> Void
    let activateSearch: () -> Void
    
    init(openPeer: @escaping (PeerId) -> Void, activateSearch: @escaping () -> Void) {
        self.openPeer = openPeer
        self.activateSearch = activateSearch
    }
}

private func preparedContactsListTransition(account: Account, index: PeerNameIndex, from fromEntries: [ContactsEntry], to toEntries: [ContactsEntry], interaction: ContactsControllerInteraction) -> ContactsListTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, index: index, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, index: index, interaction: interaction), directionHint: nil) }
    
    return ContactsListTransition(deletions: deletions, insertions: insertions, updates: updates)
}

public class ContactsController: ViewController {
    private let queue = Queue()
    
    private let account: Account
    private let transitionDisposable = MetaDisposable()
    
    private var contactsNode: ContactsControllerNode {
        return self.displayNode as! ContactsControllerNode
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let previousEntries = Atomic<[ContactsEntry]?>(value: nil)
    
    public init(account: Account) {
        self.account = account
        
        super.init()
        
        self.title = "Contacts"
        self.tabBarItem.title = "Contacts"
        self.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconContacts")
        self.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconContactsSelected")
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.contactsNode.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .Top, animated: true, curve: .Default, directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.transitionDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ContactsControllerNode(account: self.account)
        
        self.contactsNode.navigationBar = self.navigationBar
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { [weak self] peerId in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let interaction = ContactsControllerInteraction(openPeer: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.contactsNode.listView.clearHighlightAnimated(true)
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId))
            }
        }, activateSearch: { [weak self] in
            self?.activateSearch()
        })
        
        let account = self.account
        let index = self.index
        let previousEntries = self.previousEntries
        let transition = account.postbox.contactPeersView(index: self.index, accountPeerId: account.peerId)
            |> map { view -> (ContactsListTransition, Bool, Bool) in
                let entries = contactListEntries(view)
                let previous = previousEntries.swap(entries)
                return (preparedContactsListTransition(account: account, index: index, from: previous ?? [], to: entries, interaction: interaction), previous == nil, previous != nil)
            }
            |> deliverOnMainQueue
        
        self.transitionDisposable.set(transition.start(next: { [weak self] (transition, firstTime, animated) in
            self?.enqueueTransition(transition, firstTime: firstTime, animated: animated)
        }))
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.transitionDisposable.set(nil)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func enqueueTransition(_ transition: ContactsListTransition, firstTime: Bool, animated: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else if animated {
            options.insert(.AnimateInsertion)
        }
        self.contactsNode.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
            if let strongSelf = self {
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf._ready.set(.single(true))
                }
            }
        })
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.contactsNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.contactsNode.deactivateSearch()
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
}
