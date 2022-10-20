import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListAddressItem
import SwiftSignalKit
import AccountContext
import Postbox
import PeerInfoUI
import ItemListUI

final class PeerInfoScreenCallListItem: PeerInfoScreenItem {
    let id: AnyHashable
    let messages: [Message]
    
    init(
        id: AnyHashable,
        messages: [Message]
    ) {
        self.id = id
        self.messages = messages
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenCallListItemNode()
    }
}

private final class PeerInfoScreenCallListItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var item: PeerInfoScreenCallListItem?
    private var itemNode: ItemListCallListItemNode?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        self.selectionNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenCallListItem else {
            return 10.0
        }
        
        self.item = item
        
        self.selectionNode.pressed = nil
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let addressItem = ItemListCallListItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, messages: item.messages, sectionId: 0, style: .blocks, displayDecorations: false)
        
        let params = ListViewItemLayoutParams(width: width, leftInset: safeInsets.left, rightInset: safeInsets.right, availableHeight: 1000.0)
        
        let itemNode: ItemListCallListItemNode
        if let current = self.itemNode {
            itemNode = current
            addressItem.updateNode(async: { $0() }, node: {
                return itemNode
            }, params: params, previousItem: nil, nextItem: nil, animation: .None, completion: { (layout, apply) in
                let nodeFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: layout.size.height))
                
                itemNode.contentSize = layout.contentSize
                itemNode.insets = layout.insets
                itemNode.frame = nodeFrame
                
                apply(ListViewItemApply(isOnScreen: true))
            })
        } else {
            var itemNodeValue: ListViewItemNode?
            addressItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                itemNodeValue = node
                apply().1(ListViewItemApply(isOnScreen: true))
            })
            itemNode = itemNodeValue as! ItemListCallListItemNode
            itemNode.isUserInteractionEnabled = false
            self.itemNode = itemNode
            self.addSubnode(itemNode)
        }
        
        let height = itemNode.contentSize.height
        
        transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(), size: itemNode.bounds.size))
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
}
