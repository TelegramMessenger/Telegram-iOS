import Display
import AsyncDisplayKit
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit

private struct SearchResultEntry: Identifiable {
    let index: Int
    let peer: Peer
    
    var stableId: Int64 {
        return self.peer.id.toInt64()
    }
    
    static func ==(lhs: SearchResultEntry, rhs: SearchResultEntry) -> Bool {
        return lhs.index == rhs.index && lhs.peer.isEqual(rhs.peer)
    }
    
    static func <(lhs: SearchResultEntry, rhs: SearchResultEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

final class ContactMultiselectionControllerNode: ASDisplayNode {
    let contactListNode: ContactListNode
    let tokenListNode: EditableTokenListNode
    var searchResultsNode: ContactListNode?
    
    private let account: Account
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((PeerId) -> Void)?
    var openPeer: ((Peer) -> Void)?
    var removeSelectedPeer: ((PeerId) -> Void)?
    
    var editableTokens: [EditableTokenListToken] = []
    
    private let searchResultsReadyDisposable = MetaDisposable()
    
    var dismiss: (() -> Void)?
    
    init(account: Account) {
        self.account = account
        self.contactListNode = ContactListNode(account: account, presentation: .natural(displaySearch: false, options: []), selectionState: ContactListNodeGroupSelectionState())
        self.tokenListNode = EditableTokenListNode()
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = UIColor.white
        
        self.addSubnode(self.contactListNode)
        self.addSubnode(self.tokenListNode)
        
        self.contactListNode.openPeer = { [weak self] peer in
            self?.openPeer?(peer)
        }
        
        let searchText = ValuePromise<String>()
        
        self.tokenListNode.deleteToken = { [weak self] id in
            self?.removeSelectedPeer?(id as! PeerId)
        }
        
        self.tokenListNode.textUpdated = { [weak self] text in
            if let strongSelf = self {
                searchText.set(text)
                if text.isEmpty {
                    if let searchResultsNode = strongSelf.searchResultsNode {
                        searchResultsNode.removeFromSupernode()
                        strongSelf.searchResultsNode = nil
                    }
                } else {
                    if strongSelf.searchResultsNode == nil {
                        var selectionState: ContactListNodeGroupSelectionState?
                        strongSelf.contactListNode.updateSelectionState { state in
                            selectionState = state
                            return state
                        }
                        let searchResultsNode = ContactListNode(account: account, presentation: ContactListPresentation.search(searchText.get()), selectionState: selectionState)
                        searchResultsNode.openPeer = { peer in
                            self?.tokenListNode.setText("")
                            self?.openPeer?(peer)
                        }
                        strongSelf.searchResultsNode = searchResultsNode
                        searchResultsNode.enableUpdates = true
                        searchResultsNode.backgroundColor = .white
                        if let (layout, navigationBarHeight) = strongSelf.containerLayout {
                            var insets = layout.insets(options: [.input])
                            insets.top += navigationBarHeight
                            insets.top += strongSelf.tokenListNode.bounds.size.height
                            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, intrinsicInsets: insets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight), transition: .immediate)
                            searchResultsNode.frame = CGRect(origin: CGPoint(), size: layout.size)
                        }
                        
                        strongSelf.searchResultsReadyDisposable.set((searchResultsNode.ready |> deliverOnMainQueue).start(next: { _ in
                            if let strongSelf = self, let searchResultsNode = strongSelf.searchResultsNode {
                                strongSelf.insertSubnode(searchResultsNode, aboveSubnode: strongSelf.contactListNode)
                            }
                        }))
                    }
                }
            }
        }
    }
    
    deinit {
        self.searchResultsReadyDisposable.dispose()
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        let tokenListHeight = self.tokenListNode.updateLayout(tokens: self.editableTokens, width: layout.size.width, transition: transition)
        
        transition.updateFrame(node: self.tokenListNode, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: tokenListHeight)))
        
        insets.top += tokenListHeight
        
        self.contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, intrinsicInsets: insets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight), transition: transition)
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if let searchResultsNode = self.searchResultsNode {
            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, intrinsicInsets: insets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight), transition: transition)
            searchResultsNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut() {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
            }
        })
    }
}
