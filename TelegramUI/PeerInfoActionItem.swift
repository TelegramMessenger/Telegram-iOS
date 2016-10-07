import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

enum PeerInfoActionKind {
    case generic
    case destructive
}

class PeerInfoActionItem: ListViewItem, PeerInfoItem {
    let title: String
    let kind: PeerInfoActionKind
    let sectionId: PeerInfoItemSectionId
    let action: () -> Void
    
    init(title: String, kind: PeerInfoActionKind, sectionId: PeerInfoItemSectionId, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.sectionId = sectionId
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = PeerInfoActionItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, peerInfoItemInsets(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply()
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? PeerInfoActionItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, peerInfoItemInsets(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.regular(17.0)

class PeerInfoActionItemNode: ListViewItemNode {
    let titleNode: TextNode
    let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.backgroundColor = UIColor(0xc8c7cc)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
    }
    
    func asyncLayout() -> (_ item: PeerInfoActionItem, _ width: CGFloat, _ insets: UIEdgeInsets) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, width, insets in
            let sectionInset: CGFloat = 22.0
            
            let (titleLayout, titleApply) = makeTitleLayout(NSAttributedString(string: item.title, font: titleFont, textColor: item.kind == .destructive ? UIColor(0xff3b30) : UIColor(0x1195f2)), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let contentSize = CGSize(width: width, height: 44.0)
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    let _ = titleApply()
                    
                    let leftInset: CGFloat = 35.0
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: titleLayout.size)
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: 44.0 + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
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
