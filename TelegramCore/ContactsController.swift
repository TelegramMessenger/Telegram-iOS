import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit

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
    case peer(Peer)
    
    var stableId: ContactsControllerEntryId {
        switch self {
            case .search:
                return .search
            case .vcard:
                return .vcard
            case let .peer(peer):
                return .peerId(peer.id.toInt64())
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
        case let .peer(lhsPeer):
            switch rhs {
                case let .peer(rhsPeer):
                    return lhsPeer.id == rhsPeer.id
                default:
                    return false
            }
    }
}

private func <(lhs: ContactsEntry, rhs: ContactsEntry) -> Bool {
    return lhs.stableId < rhs.stableId
}

private func entriesForView(_ view: ContactPeersView) -> [ContactsEntry] {
    var entries: [ContactsEntry] = []
    entries.append(.search)
    if let peer = view.accountPeer {
        entries.append(.vcard(peer))
    }
    for peer in view.peers {
        entries.append(.peer(peer))
    }
    return entries
}

public class ContactsController: ViewController {
    private let queue = Queue()
    
    private let account: Account
    private let disposable = MetaDisposable()
    
    private var entries: [ContactsEntry] = []
    
    private var contactsNode: ContactsControllerNode {
        return self.displayNode as! ContactsControllerNode
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    
    public init(account: Account) {
        self.account = account
        
        super.init()
        
        self.title = "Contacts"
        self.tabBarItem.title = "Contacts"
        self.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconContacts")
        self.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconContactsSelected")
        
        self.disposable.set((account.postbox.contactPeersView(index: self.index, accountPeerId: account.peerId) |> deliverOn(self.queue)).start(next: { [weak self] view in
            self?.updateView(view)
        }))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self, !strongSelf.entries.isEmpty {
                strongSelf.contactsNode.listView.deleteAndInsertItems(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .Top, animated: true, curve: .Default, directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, completion: { _ in })
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
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
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
    
    private func updateView(_ view: ContactPeersView) {
        assert(self.queue.isCurrent())
        
        let previousEntries = self.entries
        let updatedEntries = entriesForView(view)
        
        let (deleteIndices, indicesAndItems) = mergeListsStable(leftList: previousEntries, rightList: updatedEntries)
        
        self.entries = updatedEntries
        
        var adjustedDeleteIndices: [ListViewDeleteItem] = []
        if deleteIndices.count != 0 {
            for index in deleteIndices {
                adjustedDeleteIndices.append(ListViewDeleteItem(index: index, directionHint: nil))
            }
        }
        
        var adjustedIndicesAndItems: [ListViewInsertItem] = []
        for (index, entry, previousIndex) in indicesAndItems {
            switch entry {
                case .search:
                    adjustedIndicesAndItems.append(ListViewInsertItem(index: index, previousIndex: previousIndex, item: ChatListSearchItem(placeholder: "Search contacts", activate: { [weak self] in
                        self?.activateSearch()
                    }), directionHint: nil))
                case let .vcard(peer):
                    adjustedIndicesAndItems.append(ListViewInsertItem(index: index, previousIndex: previousIndex, item: ContactsVCardItem(account: self.account, peer: peer, action: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.entrySelected(entry)
                            strongSelf.contactsNode.listView.clearHighlightAnimated(true)
                        }
                    }), directionHint: nil))
                case let .peer(peer):
                    adjustedIndicesAndItems.append(ListViewInsertItem(index: index, previousIndex: previousIndex, item: ContactsPeerItem(account: self.account, peer: peer, index: self.index, action: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.entrySelected(entry)
                            strongSelf.contactsNode.listView.clearHighlightAnimated(true)
                        }
                    }), directionHint: nil))
                }
        }
        
        DispatchQueue.main.async {
            let options: ListViewDeleteAndInsertOptions = []
            
            self.contactsNode.listView.deleteAndInsertItems(deleteIndices: adjustedDeleteIndices, insertIndicesAndItems: adjustedIndicesAndItems, updateIndicesAndItems: [], options: options, scrollToItem: nil, completion: { _ in
            })
        }
    }
    
    private func entrySelected(_ entry: ContactsEntry) {
        if case let .peer(peer) = entry {
            (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, peerId: peer.id))
        }
        if case let .vcard(peer) = entry {
            (self.navigationController as? NavigationController)?.pushViewController(ChatController(account: self.account, peerId: peer.id))
        }
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
