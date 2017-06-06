import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private enum ContactListSearchEntry {
    case peer(Peer, PresentationTheme, PresentationStrings)
}

final class ContactsSearchContainerNode: SearchDisplayControllerContentNode {
    private let account: Account
    private let openPeer: (PeerId) -> Void
    
    private let listNode: ListView
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    init(account: Account, openPeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.openPeer = openPeer
        
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.themeAndStringsPromise = Promise((presentationData.theme, presentationData.strings))
        
        self.listNode = ListView()
        
        super.init()
        
        self.backgroundColor = presentationData.theme.chatList.backgroundColor
        self.addSubnode(self.listNode)
        
        self.listNode.isHidden = true
        
        let themeAndStringsPromise = self.themeAndStringsPromise
        
        let searchItems = searchQuery.get()
            |> mapToSignal { query -> Signal<[ContactListSearchEntry], NoError> in
                if let query = query, !query.isEmpty {
                    return combineLatest(account.postbox.searchContacts(query: query.lowercased()), themeAndStringsPromise.get())
                        |> delay(0.1, queue: Queue.concurrentDefaultQueue())
                        |> map { peers, themeAndStrings -> [ContactListSearchEntry] in
                            return peers.map({ .peer($0, themeAndStrings.0, themeAndStrings.1) })
                        }
                } else {
                    return .single([])
                }
        }
        
        let previousSearchItems = Atomic<[ContactListSearchEntry]>(value: [])
        
        self.searchDisposable.set((searchItems
            |> deliverOnMainQueue).start(next: { [weak self] items in
                if let strongSelf = self {
                    let previousItems = previousSearchItems.swap(items)
                    
                    var listItems: [ListViewItem] = []
                    for item in items {
                        switch item {
                            case let .peer(peer, theme, strings):
                                listItems.append(ContactsPeerItem(theme: theme, strings: strings, account: account, peer: peer, chatPeer: peer, status: .none, selection: .none, index: nil, header: nil, action: { [weak self] peer in
                                    if let openPeer = self?.openPeer {
                                        self?.listNode.clearHighlightAnimated(true)
                                        openPeer(peer.id)
                                    }
                                }))
                        }
                    }
                    
                    strongSelf.listNode.transaction(deleteIndices: (0 ..< previousItems.count).map({ ListViewDeleteItem(index: $0, directionHint: nil) }), insertIndicesAndItems: (0 ..< listItems.count).map({ ListViewInsertItem(index: $0, previousIndex: nil, item: listItems[$0], directionHint: .Down) }), updateIndicesAndItems: [], options: [], updateOpaqueState: nil)
                }
            }))
    }
    
    deinit {
        self.searchDisposable.dispose()
    }
    
    override func searchTextUpdated(text: String) {
        if text.isEmpty {
            self.searchQuery.set(.single(nil))
            self.listNode.isHidden = true
        } else {
            self.searchQuery.set(.single(text))
            self.listNode.isHidden = false
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: navigationBarHeight, left: 0.0, bottom: 0.0, right: 0.0), duration: 0.0, curve: .Default), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
}
