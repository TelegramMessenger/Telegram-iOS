import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import ChatListSearchRecentPeersNode
import ContextUI
import AccountContext

class ChatListRecentPeersListItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let context: AccountContext
    let peers: [Peer]
    let peerSelected: (Peer) -> Void
    let peerContextAction: (Peer, ASDisplayNode, ContextGesture?) -> Void
    
    let header: ListViewItemHeader?
    
    init(theme: PresentationTheme, strings: PresentationStrings, context: AccountContext, peers: [Peer], peerSelected: @escaping (Peer) -> Void, peerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void) {
        self.theme = theme
        self.strings = strings
        self.context = context
        self.peers = peers
        self.peerSelected = peerSelected
        self.peerContextAction = peerContextAction
        self.header = nil
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListRecentPeersListItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem != nil)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatListRecentPeersListItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem != nil)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { info in
                            apply().1(info)
                        })
                    }
                }
            }
        }
    }
}

class ChatListRecentPeersListItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private var peersNode: ChatListSearchRecentPeersNode?
    
    private var item: ChatListRecentPeersListItem?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, nextItem == nil)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    func asyncLayout() -> (_ item: ChatListRecentPeersListItem, _ params: ListViewItemLayoutParams, _ last: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        return { [weak self] item, params, last in
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 124.0), insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.theme !== item.theme {
                    updatedTheme = item.theme
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                        }
                        
                        let peersNode: ChatListSearchRecentPeersNode
                        if let currentPeersNode = strongSelf.peersNode {
                            peersNode = currentPeersNode
                            peersNode.updateThemeAndStrings(theme: item.theme, strings: item.strings)
                        } else {
                            peersNode = ChatListSearchRecentPeersNode(context: item.context, theme: item.theme, mode: .list, strings: item.strings, peerSelected: { peer in
                                self?.item?.peerSelected(peer)
                            }, peerContextAction: { peer, node, gesture in
                                self?.item?.peerContextAction(peer, node, gesture)
                            }, isPeerSelected: { _ in
                                return false
                            })
                            strongSelf.peersNode = peersNode
                            strongSelf.addSubnode(peersNode)
                        }
                        
                        peersNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                        peersNode.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        
                        let separatorHeight = UIScreenPixel
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = true
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func header() -> ListViewItemHeader? {
        if let item = self.item {
            return item.header
        } else {
            return nil
        }
    }
    
    func viewAndPeerAtPoint(_ point: CGPoint) -> (UIView, PeerId)? {
        if let peersNode = self.peersNode {
            let adjustedLocation = self.convert(point, to: peersNode)
            if let result = peersNode.viewAndPeerAtPoint(adjustedLocation) {
                return result
            }
        }
        return nil
    }
}
