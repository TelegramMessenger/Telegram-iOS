import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

class ChannelMembersSearchControllerNode: ASDisplayNode {
    private let account: Account
    private let peerId: PeerId
    
    let listNode: ListView
    var navigationBar: NavigationBar?
    
    private(set) var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var requestActivateSearch: (() -> Void)?
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((Peer) -> Void)?
    
    var themeAndStrings: (PresentationTheme, PresentationStrings)

    private var disposable: Disposable?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, peerId: PeerId) {
        self.account = account
        self.listNode = ListView()
        self.peerId = peerId
        
        self.themeAndStrings = (theme, strings)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.chatList.backgroundColor
        
        self.addSubnode(self.listNode)
        
        self.disposable = (channelMembers(postbox: account.postbox, network: account.network, peerId: peerId)
            |> deliverOnMainQueue).start(next: { [weak self] participants in
                if let strongSelf = self {
                    var items: [ListViewItem] = []
                    items.append(ChatListSearchItem(theme: theme, placeholder: strings.Common_Search, activate: {
                        if let strongSelf = self {
                            strongSelf.requestActivateSearch?()
                        }
                    }))
                    
                    for participant in participants {
                        items.append(ContactsPeerItem(theme: theme, strings: strings, account: account, peer: participant.peer, chatPeer: nil, status: .none, enabled: true, selection: .none, editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false), index: nil, header: nil, action: { peer in
                            if let strongSelf = self {
                                strongSelf.requestOpenPeerFromSearch?(peer)
                            }
                        }))
                    }
                    
                    var insertItems: [ListViewInsertItem] = []
                    for i in 0 ..< items.count {
                        insertItems.append(ListViewInsertItem(index: i, previousIndex: nil, item: items[i], directionHint: nil))
                    }
                    
                    strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: insertItems, updateIndicesAndItems: [], options: [], updateOpaqueState: nil)
                }
            })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.themeAndStrings = (theme, strings)
        self.searchDisplayController?.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        
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
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch() {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar else {
            return
        }
        
        var maybePlaceholderNode: SearchBarPlaceholderNode?
        self.listNode.forEachItemNode { node in
            if let node = node as? ChatListSearchItemNode {
                maybePlaceholderNode = node.searchBarNode
            }
        }
        
        if let _ = self.searchDisplayController {
            return
        }
        
        if let placeholderNode = maybePlaceholderNode {
            self.searchDisplayController = SearchDisplayController(theme: self.themeAndStrings.0, strings: self.themeAndStrings.1, contentNode: ChannelMembersSearchContainerNode(account: self.account, peerId: self.peerId, openPeer: { [weak self] peer in
                if let requestOpenPeerFromSearch = self?.requestOpenPeerFromSearch {
                    requestOpenPeerFromSearch(peer)
                }
            }), cancel: { [weak self] in
                if let requestDeactivateSearch = self?.requestDeactivateSearch {
                    requestDeactivateSearch()
                }
            })
            
            self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { subnode in
                self.insertSubnode(subnode, belowSubnode: navigationBar)
            }, placeholder: placeholderNode)
        }
    }
    
    func deactivateSearch(animated: Bool) {
        if let searchDisplayController = self.searchDisplayController {
            var maybePlaceholderNode: SearchBarPlaceholderNode?
            self.listNode.forEachItemNode { node in
                if let node = node as? ChatListSearchItemNode {
                    maybePlaceholderNode = node.searchBarNode
                }
            }
            
            searchDisplayController.deactivate(placeholder: maybePlaceholderNode, animated: animated)
            self.searchDisplayController = nil
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
}
