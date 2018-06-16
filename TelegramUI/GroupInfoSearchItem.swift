import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class GroupInfoSearchItem: ItemListControllerSearch {
    let account: Account
    let peerId: PeerId
    let cancel: () -> Void
    let openPeer: (Peer) -> Void
    
    init(account: Account, peerId: PeerId, cancel: @escaping () -> Void, openPeer: @escaping (Peer) -> Void) {
        self.account = account
        self.peerId = peerId
        self.cancel = cancel
        self.openPeer = openPeer
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? GroupInfoSearchItem {
            if self.account !== to.account {
                return false
            }
            if self.peerId != to.peerId {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        if let current = current as? GroupInfoSearchNavigationContentNode {
            return current
        } else {
            let presentationData = self.account.telegramApplicationContext.currentPresentationData.with { $0 }
            return GroupInfoSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, cancel: self.cancel)
        }
    }
    
    func node(current: ItemListControllerSearchNode?) -> ItemListControllerSearchNode {
        return GroupInfoSearchItemNode(account: self.account, peerId: self.peerId, openPeer: self.openPeer, cancel: self.cancel)
    }
}

private final class GroupInfoSearchItemNode: ItemListControllerSearchNode {
    private let containerNode: ChannelMembersSearchContainerNode
    
    init(account: Account, peerId: PeerId, openPeer: @escaping (Peer) -> Void, cancel: @escaping () -> Void) {
        self.containerNode = ChannelMembersSearchContainerNode(account: account, peerId: peerId, mode: .searchMembers, openPeer: { peer, _ in
            openPeer(peer)
        })
        self.containerNode.cancel = {
            cancel()
        }
        
        super.init()
        
        self.addSubnode(self.containerNode)
    }
    
    override func queryUpdated(_ query: String) {
        self.containerNode.searchTextUpdated(text: query)
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)))
        self.containerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.containerNode.hitTest(self.view.convert(point, to: self.containerNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}
