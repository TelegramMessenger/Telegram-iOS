import Foundation
import Display
import Postbox
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit

enum HorizontalPeerItemMode {
    case list
    case actionSheet
}

final class HorizontalPeerItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let mode: HorizontalPeerItemMode
    let account: Account
    let peer: Peer
    let action: (Peer) -> Void
    let isPeerSelected: (PeerId) -> Bool
    let customWidth: CGFloat?
    
    init(theme: PresentationTheme, strings: PresentationStrings, mode: HorizontalPeerItemMode, account: Account, peer: Peer, action: @escaping (Peer) -> Void, isPeerSelected: @escaping (PeerId) -> Bool, customWidth: CGFloat?) {
        self.theme = theme
        self.strings = strings
        self.mode = mode
        self.account = account
        self.peer = peer
        self.action = action
        self.isPeerSelected = isPeerSelected
        self.customWidth = customWidth
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = HorizontalPeerItemNode()
            
            let (nodeLayout, apply) = node.asyncLayout()(self, width)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            completion(node, {
                return (nil, {
                    apply(false)
                })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        assert(node is HorizontalPeerItemNode)
        if let node = node as? HorizontalPeerItemNode {
            Queue.mainQueue().async {
                let layout = node.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, width)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
}

final class HorizontalPeerItemNode: ListViewItemNode {
    private(set) var peerNode: SelectablePeerNode
    
    private(set) var item: HorizontalPeerItem?
    
    init() {
        self.peerNode = SelectablePeerNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.peerNode)
        self.peerNode.toggleSelection = { [weak self] in
            if let item = self?.item {
                item.action(item.peer)
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func asyncLayout() -> (HorizontalPeerItem, CGFloat) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        return { [weak self] item, width in
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 92.0, height: item.customWidth ?? 80.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                let textColor: UIColor
                switch item.mode {
                    case .list:
                        textColor = item.theme.list.itemPrimaryTextColor
                    case .actionSheet:
                        textColor = .black
                }
                
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.peerNode.textColor = textColor
                    strongSelf.peerNode.setup(account: item.account, peer: item.peer, chatPeer: nil, numberOfLines: 1)
                    strongSelf.peerNode.frame = CGRect(origin: CGPoint(), size: itemLayout.size)
                    strongSelf.peerNode.updateSelection(selected: item.isPeerSelected(item.peer.id), animated: false)
                }
            })
        }
    }
    
    func updateSelection(animated: Bool) {
        if let item = self.item {
            self.peerNode.updateSelection(selected: item.isPeerSelected(item.peer.id), animated: animated)
        }
    }
}

