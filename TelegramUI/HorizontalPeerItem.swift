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
    let longTapAction: (Peer) -> Void
    let isPeerSelected: (PeerId) -> Bool
    let customWidth: CGFloat?
    
    init(theme: PresentationTheme, strings: PresentationStrings, mode: HorizontalPeerItemMode, account: Account, peer: Peer, action: @escaping (Peer) -> Void, longTapAction: @escaping (Peer) -> Void, isPeerSelected: @escaping (PeerId) -> Bool, customWidth: CGFloat?) {
        self.theme = theme
        self.strings = strings
        self.mode = mode
        self.account = account
        self.peer = peer
        self.action = action
        self.longTapAction = longTapAction
        self.isPeerSelected = isPeerSelected
        self.customWidth = customWidth
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = HorizontalPeerItemNode()
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            completion(node, {
                return (nil, {
                    apply(false)
                })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        assert(node is HorizontalPeerItemNode)
        if let node = node as? HorizontalPeerItemNode {
            Queue.mainQueue().async {
                let layout = node.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
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
        self.peerNode.longTapAction = { [weak self] in
            if let item = self?.item {
                item.longTapAction(item.peer)
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func asyncLayout() -> (HorizontalPeerItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        return { [weak self] item, params in
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 92.0, height: item.customWidth ?? 80.0), insets: UIEdgeInsets())
            
            let itemTheme: SelectablePeerNodeTheme
            switch item.mode {
                case .list:
                    itemTheme = SelectablePeerNodeTheme(textColor: item.theme.list.itemPrimaryTextColor, secretTextColor: .green, selectedTextColor: item.theme.list.itemAccentColor, checkBackgroundColor: item.theme.list.plainBackgroundColor, checkFillColor: item.theme.list.itemAccentColor, checkColor: item.theme.list.plainBackgroundColor)
                case .actionSheet:
                    itemTheme = SelectablePeerNodeTheme(textColor: item.theme.actionSheet.primaryTextColor, secretTextColor: .green, selectedTextColor: item.theme.actionSheet.controlAccentColor, checkBackgroundColor: item.theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: item.theme.actionSheet.controlAccentColor, checkColor: item.theme.actionSheet.opaqueItemBackgroundColor)
            }
            
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.peerNode.theme = itemTheme
                    strongSelf.peerNode.setup(account: item.account, strings: item.strings, peer: item.peer, chatPeer: nil, numberOfLines: 1)
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

