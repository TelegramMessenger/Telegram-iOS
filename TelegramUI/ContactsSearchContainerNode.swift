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
    
    private let dimNode: ASDisplayNode
    private let listNode: ListView
    
    private let searchQuery = Promise<String?>()
    private let searchDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    init(account: Account, onlyWriteable: Bool, openPeer: @escaping (PeerId) -> Void) {
        self.account = account
        self.openPeer = openPeer
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        self.listNode = ListView()
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.dimNode)
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
                                var enabled = true
                                if onlyWriteable {
                                    enabled = canSendMessagesToPeer(peer)
                                }
                                
                                listItems.append(ContactsPeerItem(theme: theme, strings: strings, account: account, peer: peer, chatPeer: peer, status: .none, enabled: enabled, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { [weak self] peer in
                                    if let openPeer = self?.openPeer {
                                        self?.listNode.clearHighlightAnimated(true)
                                        openPeer(peer.id)
                                    }
                                }))
                        }
                    }
                    
                    let isEmpty = listItems.isEmpty
                    
                    strongSelf.listNode.transaction(deleteIndices: (0 ..< previousItems.count).map({ ListViewDeleteItem(index: $0, directionHint: nil) }), insertIndicesAndItems: (0 ..< listItems.count).map({ ListViewInsertItem(index: $0, previousIndex: nil, item: listItems[$0], directionHint: .Down) }), updateIndicesAndItems: [], options: [], updateOpaqueState: nil, completion: { _ in
                        if let strongSelf = self {
                            strongSelf.listNode.isHidden = isEmpty
                            strongSelf.backgroundColor = isEmpty ? UIColor.black.withAlphaComponent(0.5) : strongSelf.presentationData.theme.chatList.backgroundColor
                        }
                    })
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
        
        let topInset = navigationBarHeight
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: layout.size.height - topInset)))
        
        self.listNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0), duration: 0.0, curve: .Default), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
}
