import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore

public enum ContactMultiselectionControllerMode {
    case groupCreation
}

public class ContactMultiselectionController: ViewController {
    private let account: Account
    private let mode: ContactMultiselectionControllerMode
    
    private let titleView: CounterContollerTitleView
    
    private var contactsNode: ContactMultiselectionControllerNode {
        return self.displayNode as! ContactMultiselectionControllerNode
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let _result = Promise<[PeerId]>()
    public var result: Signal<[PeerId], NoError> {
        return self._result.get()
    }
    
    private var rightNavigationButton: UIBarButtonItem?
    
    public init(account: Account, mode: ContactMultiselectionControllerMode) {
        self.account = account
        self.mode = mode
        
        self.titleView = CounterContollerTitleView()
        
        super.init()
        
        switch mode {
            case .groupCreation:
                self.titleView.title = CounterContollerTitle(title: "New Group", counter: "0/5000")
                let rightNavigationButton = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
                rightNavigationButton.isEnabled = false
        }
        
        self.navigationItem.titleView = self.titleView
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.contactsNode.contactListNode.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ContactMultiselectionControllerNode(account: self.account)
        self._ready.set(self.contactsNode.contactListNode.ready)
        
        self.contactsNode.openPeer = { [weak self] peer in
            if let strongSelf = self {
                var updatedCount: Int?
                var addedToken: EditableTokenListToken?
                var removedTokenId: AnyHashable?
                
                var selectionState: ContactListNodeGroupSelectionState?
                strongSelf.contactsNode.contactListNode.updateSelectionState { state in
                    if let state = state {
                        let updatedState = state.withToggledPeerId(peer.id)
                        if updatedState.selectedPeerIndices[peer.id] == nil {
                            removedTokenId = peer.id
                        } else {
                            addedToken = EditableTokenListToken(id: peer.id, title: peer.displayTitle)
                        }
                        updatedCount = updatedState.selectedPeerIndices.count
                        selectionState = updatedState
                        return updatedState
                    } else {
                        return nil
                    }
                }
                if let searchResultsNode = strongSelf.contactsNode.searchResultsNode {
                    searchResultsNode.updateSelectionState { _ in
                        return selectionState
                    }
                }
                
                if let updatedCount = updatedCount {
                    strongSelf.rightNavigationButton?.isEnabled = updatedCount != 0
                    strongSelf.titleView.title = CounterContollerTitle(title: "New Group", counter: "\(updatedCount)/5000")
                }
                
                if let addedToken = addedToken {
                    strongSelf.contactsNode.editableTokens.append(addedToken)
                } else if let removedTokenId = removedTokenId {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return token.id != removedTokenId
                    }
                }
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
            }
        }
        
        self.contactsNode.removeSelectedPeer = { [weak self] peerId in
            if let strongSelf = self {
                var updatedCount: Int?
                var removedTokenId: AnyHashable?
                
                var selectionState: ContactListNodeGroupSelectionState?
                strongSelf.contactsNode.contactListNode.updateSelectionState { state in
                    if let state = state {
                        let updatedState = state.withToggledPeerId(peerId)
                        if updatedState.selectedPeerIndices[peerId] == nil {
                            removedTokenId = peerId
                        }
                        updatedCount = updatedState.selectedPeerIndices.count
                        selectionState = updatedState
                        return updatedState
                    } else {
                        return nil
                    }
                }
                if let searchResultsNode = strongSelf.contactsNode.searchResultsNode {
                    searchResultsNode.updateSelectionState { _ in
                        return selectionState
                    }
                }
                
                if let updatedCount = updatedCount {
                    strongSelf.rightNavigationButton?.isEnabled = updatedCount != 0
                    strongSelf.titleView.title = CounterContollerTitle(title: "New Group", counter: "\(updatedCount)/5000")
                }
                
                if let removedTokenId = removedTokenId {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return token.id != removedTokenId
                    }
                }
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func rightNavigationButtonPressed() {
        var peerIds: [PeerId] = []
        self.contactsNode.contactListNode.updateSelectionState { state in
            if let state = state {
                peerIds = Array(state.selectedPeerIndices.keys)
            }
            return state
        }
        self._result.set(.single(peerIds))
    }
}
