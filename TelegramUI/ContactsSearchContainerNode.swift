import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private struct ContactListSearchEntry: Identifiable, Comparable {
    let index: Int
    let peer: Peer
    let enabled: Bool
    
    var stableId: PeerId {
        return self.peer.id
    }
    
    static func ==(lhs: ContactListSearchEntry, rhs: ContactListSearchEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
        if !arePeersEqual(lhs.peer, rhs.peer) {
            return false
        }
        if lhs.enabled != rhs.enabled {
            return false
        }
        return true
    }
    
    static func <(lhs: ContactListSearchEntry, rhs: ContactListSearchEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, theme: PresentationTheme, strings: PresentationStrings, openPeer: @escaping (Peer) -> Void) -> ListViewItem {
        return ContactsPeerItem(theme: theme, strings: strings, account: account, peerMode: .peer, peer: peer, chatPeer: peer, status: .none, enabled: self.enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { peer in
            openPeer(peer)
        })
    }
}

struct ContactListSearchContainerTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let isSearching: Bool
}

private func contactListSearchContainerPreparedRecentTransition(from fromEntries: [ContactListSearchEntry], to toEntries: [ContactListSearchEntry], isSearching: Bool, account: Account, theme: PresentationTheme, strings: PresentationStrings, openPeer: @escaping (Peer) -> Void) -> ContactListSearchContainerTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, openPeer: openPeer), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, theme: theme, strings: strings, openPeer: openPeer), directionHint: nil) }
    
    return ContactListSearchContainerTransition(deletions: deletions, insertions: insertions, updates: updates, isSearching: isSearching)
}

final class ContactsSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openPeer: (PeerId) -> Void
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    private var containerViewLayout: (ContainerViewLayout, CGFloat)?
    private var enqueuedTransitions: [ContactListSearchContainerTransition] = []
    
    init(account: Account, onlyWriteable: Bool, filter: ContactListFilter = [.excludeSelf], openPeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.openPeer = openPeer
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.listNode = ListView()
        self.listNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.listNode.isHidden = true
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
        
        let themeAndStringsPromise = self.themeAndStringsPromise
        
        let searchItems = searchQuery.get()
            |> mapToSignal { query -> Signal<[ContactListSearchEntry]?, NoError> in
                if let query = query, !query.isEmpty {
                    let foundLocalContacts = account.postbox.searchContacts(query: query.lowercased())
                    let foundRemoteContacts: Signal<([FoundPeer], [FoundPeer]), NoError> =
                    .single(([], []))
                    |> then(
                        searchPeers(account: account, query: query)
                        |> map { ($0.0, $0.1) }
                        |> delay(0.2, queue: Queue.concurrentDefaultQueue())
                    )
                    
                    return combineLatest(foundLocalContacts, foundRemoteContacts, themeAndStringsPromise.get())
                        |> delay(0.1, queue: Queue.concurrentDefaultQueue())
                        |> map { localPeers, remotePeers, themeAndStrings -> [ContactListSearchEntry] in
                            var entries: [ContactListSearchEntry] = []
                            var existingPeerIds = Set<PeerId>()
                            if filter.contains(.excludeSelf) {
                                existingPeerIds.insert(account.peerId)
                            }
                            var index = 0
                            for peer in localPeers {
                                if existingPeerIds.contains(peer.id) {
                                    continue
                                }
                                existingPeerIds.insert(peer.id)
                                var enabled = true
                                if onlyWriteable {
                                    enabled = canSendMessagesToPeer(peer)
                                }
                                entries.append(ContactListSearchEntry(index: index, peer: peer, enabled: enabled))
                                index += 1
                            }
                            for peer in remotePeers.1 {
                                if !existingPeerIds.contains(peer.peer.id) {
                                    existingPeerIds.insert(peer.peer.id)
                                    var enabled = true
                                    if onlyWriteable {
                                        enabled = canSendMessagesToPeer(peer.peer)
                                    }
                                    
                                    entries.append(ContactListSearchEntry(index: index, peer: peer.peer, enabled: enabled))
                                    index += 1
                                }
                            }
                            for peer in remotePeers.0 {
                                if !existingPeerIds.contains(peer.peer.id) {
                                    existingPeerIds.insert(peer.peer.id)
                                    
                                    var enabled = true
                                    if onlyWriteable {
                                        enabled = canSendMessagesToPeer(peer.peer)
                                    }
                                    
                                    entries.append(ContactListSearchEntry(index: index, peer: peer.peer, enabled: enabled))
                                    index += 1
                                }
                            }
                            return entries
                        }
                } else {
                    return .single(nil)
                }
        }
        
        let previousSearchItems = Atomic<[ContactListSearchEntry]>(value: [])
        
        self.searchDisposable.set((searchItems
            |> deliverOnMainQueue).start(next: { [weak self] items in
                if let strongSelf = self {
                    let previousItems = previousSearchItems.swap(items ?? [])
                    
                    let transition = contactListSearchContainerPreparedRecentTransition(from: previousItems, to: items ?? [], isSearching: items != nil, account: account, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, openPeer: { peer in
                        if let openPeer = self?.openPeer {
                            self?.listNode.clearHighlightAnimated(true)
                            openPeer(peer.id)
                        }
                    })
                    
                    /*var listItems: [ListViewItem] = []
                    for item in items {
                        switch item {
                            case let .peer(peer, theme, strings):

                                
                                listItems.append(ContactsPeerItem(theme: theme, strings: strings, account: account, peerMode: .peer, peer: peer, chatPeer: peer, status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { [weak self] peer in
                                    if let openPeer = self?.openPeer {
                                        self?.listNode.clearHighlightAnimated(true)
                                        openPeer(peer.id)
                                    }
                                }))
                        }
                    }*/
                    
                    strongSelf.enqueueTransition(transition)
                }
            }))
        
        self.listNode.beganInteractiveDragging = { [weak self] in
            self?.dismissInput?()
        }
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
        } else {
            self.searchQuery.set(.single(text))
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        let hadValidLayout = self.containerViewLayout != nil
        self.containerViewLayout = (layout, navigationBarHeight)
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0), duration: 0.0, curve: .Default), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func enqueueTransition(_ transition: ContactListSearchContainerTransition) {
        self.enqueuedTransitions.append(transition)
        
        if self.containerViewLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let transition = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.PreferSynchronousDrawing)
            
            let isSearching = transition.isSearching
            self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                self?.listNode.isHidden = !isSearching
                self?.dimNode.isHidden = isSearching
            })
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}
