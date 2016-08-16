import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let separatorHeight = 1.0 / UIScreen.main.scale

protocol ListControllerGroupableItem: ListControllerItem {
    func setupNode(async: (() -> Void) -> Void, completion: (ListControllerGroupableItemNode) -> Void)
}

extension ListControllerGroupableItem {
    func nodeConfiguredForWidth(async: (() -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: (ListViewItemNode, () -> Void) -> Void) {
        self.setupNode(async: async, completion: { node in
            let asyncLayout = node.asyncLayout()
            let (layout, apply) = asyncLayout(item: self, width: width, groupedTop: previousItem is ListControllerGroupableItem, groupedBottom: nextItem is ListControllerGroupableItem)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            completion(node, apply)
        })
    }
    
    func updateNode(async: (() -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: (ListViewItemNodeLayout, () -> Void) -> Void) {
        if let node = node as? ListControllerGroupableItemNode {
            Queue.mainQueue().async {
                let asyncLayout = node.asyncLayout()
                async {
                    let (layout, apply) = asyncLayout(item: self, width: width, groupedTop: previousItem is ListControllerGroupableItem, groupedBottom: nextItem is ListControllerGroupableItem)
                    Queue.mainQueue().async {
                        completion(layout, apply)
                    }
                }
            }
        }
    }
}

class ListControllerGroupableItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor.white
        self.backgroundNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.bottomStripeNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topStripeNode)
        self.addSubnode(self.bottomStripeNode)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ListControllerGroupableItem {
            let layout = self.asyncLayout()
            let (_, apply) = layout(item: item, width: width, groupedTop: previousItem is ListControllerGroupableItem, groupedBottom: nextItem is ListControllerGroupableItem)
            apply()
        }
    }
    
    func updateBackgroundAndSeparatorsLayout(groupBottom: Bool) {
        let size = self.bounds.size
        let insets = self.insets
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top), size: CGSize(width: size.width, height: size.height))
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -separatorHeight), size: CGSize(width: size.width, height: size.height + separatorHeight - insets.top))
        self.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -insets.top), size: CGSize(width: size.width, height: separatorHeight))
        let bottomStripeInset: CGFloat = groupBottom ? 16.0 : 0.0
        self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: size.height - insets.top - separatorHeight), size: CGSize(width: size.width - bottomStripeInset, height: separatorHeight))
    }
    
    func asyncLayoutContent() -> (item: ListControllerGroupableItem, width: CGFloat) -> (CGSize, () -> Void) {
        return { _, width in
            return (CGSize(width: width, height: 0.0), {
            })
        }
    }
    
    private func asyncLayout() -> (item: ListControllerGroupableItem, width: CGFloat, groupedTop: Bool, groupedBottom: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let contentLayout = self.asyncLayoutContent()
        
        return { item, width, groupedTop, groupedBottom in
            let (contentSize, contentApply) = contentLayout(item: item, width: width)
            
            let insets = UIEdgeInsets(top: groupedTop ? 0.0 : separatorHeight, left: 0.0, bottom: separatorHeight, right: 0.0)
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: contentSize.height), insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    contentApply()
                    
                    strongSelf.topStripeNode.isHidden = groupedTop
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                    strongSelf.updateBackgroundAndSeparatorsLayout(groupBottom: groupedBottom)
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.bottomStripeNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
}
