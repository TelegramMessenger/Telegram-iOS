import Display
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import AccountContext
import ContactListUI

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
    
    private let context: AccountContext
    
    private var containerLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((ContactListPeerId) -> Void)?
    var openPeer: ((ContactListPeer) -> Void)?
    var removeSelectedPeer: ((ContactListPeerId) -> Void)?
    
    var editableTokens: [EditableTokenListToken] = []
    
    private let searchResultsReadyDisposable = MetaDisposable()
    var dismiss: (() -> Void)?
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, mode: ContactMultiselectionControllerMode, options: [ContactListAdditionalOption], filters: [ContactListFilter]) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let placeholder: String
        var includeChatList = false
        switch mode {
            case let .peerSelection(_, searchGroups):
                includeChatList = searchGroups
                if searchGroups {
                    placeholder = self.presentationData.strings.Contacts_SearchUsersAndGroupsLabel
                } else {
                    placeholder = self.presentationData.strings.Contacts_SearchLabel
                }
            default:
                placeholder = self.presentationData.strings.Compose_TokenListPlaceholder
        }
        
        self.contactListNode = ContactListNode(context: context, presentation: .single(.natural(options: options, includeChatList: includeChatList)), filters: filters, selectionState: ContactListNodeGroupSelectionState())
        self.tokenListNode = EditableTokenListNode(theme: EditableTokenListNodeTheme(backgroundColor: self.presentationData.theme.rootController.navigationBar.backgroundColor, separatorColor: self.presentationData.theme.rootController.navigationBar.separatorColor, placeholderTextColor: self.presentationData.theme.list.itemPlaceholderTextColor, primaryTextColor: self.presentationData.theme.list.itemPrimaryTextColor, selectedTextColor: self.presentationData.theme.list.itemAccentColor, accentColor: self.presentationData.theme.list.itemAccentColor, keyboardColor: self.presentationData.theme.rootController.keyboardColor), placeholder: placeholder)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.contactListNode)
        self.addSubnode(self.tokenListNode)
        
        self.contactListNode.openPeer = { [weak self] peer in
            self?.openPeer?(peer)
        }
        
        let searchText = ValuePromise<String>()
        
        self.tokenListNode.deleteToken = { [weak self] id in
            self?.removeSelectedPeer?(ContactListPeerId.peer(id as! PeerId))
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
                        var searchChatList = false
                        var searchGroups = false
                        if case let .peerSelection(peerSelection) = mode {
                            searchChatList = peerSelection.searchChatList
                            searchGroups = peerSelection.searchGroups
                        }
                        let searchResultsNode = ContactListNode(context: context, presentation: .single(.search(signal: searchText.get(), searchChatList: searchChatList, searchDeviceContacts: false, searchGroups: searchGroups)), filters: filters, selectionState: selectionState)
                        searchResultsNode.openPeer = { peer in
                            self?.tokenListNode.setText("")
                            self?.openPeer?(peer)
                        }
                        strongSelf.searchResultsNode = searchResultsNode
                        searchResultsNode.enableUpdates = true
                        searchResultsNode.backgroundColor = strongSelf.presentationData.theme.chatList.backgroundColor
                        if let (layout, navigationBarHeight, actualNavigationBarHeight) = strongSelf.containerLayout {
                            var insets = layout.insets(options: [.input])
                            insets.top += navigationBarHeight
                            insets.top += strongSelf.tokenListNode.bounds.size.height
                            
                            var headerInsets = layout.insets(options: [.input])
                            headerInsets.top += actualNavigationBarHeight
                            headerInsets.top += strongSelf.tokenListNode.bounds.size.height
                            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: .immediate)
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
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
    }
    
    deinit {
        self.searchResultsReadyDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight, actualNavigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
                
        let tokenListHeight = self.tokenListNode.updateLayout(tokens: self.editableTokens, width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
        
        transition.updateFrame(node: self.tokenListNode, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: tokenListHeight)))
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        
        insets.top += tokenListHeight
        headerInsets.top += tokenListHeight
        
        self.contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: transition)
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if let searchResultsNode = self.searchResultsNode {
            searchResultsNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: transition)
            searchResultsNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)?) {
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
                completion?()
            }
        })
    }
}
