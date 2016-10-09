import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

final class PeerInfoTextWithLabelItem: ListViewItem, PeerInfoItem {
    let label: String
    let text: String
    let multiline: Bool
    let sectionId: PeerInfoItemSectionId
    
    init(label: String, text: String, multiline: Bool, sectionId: PeerInfoItemSectionId) {
        self.label = label
        self.text = text
        self.multiline = multiline
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = PeerInfoTextWithLabelItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                apply()
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? PeerInfoTextWithLabelItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, peerInfoItemNeighbors(item: self, topItem: previousItem as? PeerInfoItem, bottomItem: nextItem as? PeerInfoItem))
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
        
    }
}

private let labelFont = Font.regular(14.0)
private let textFont = Font.regular(17.0)

class PeerInfoTextWithLabelItemNode: ListViewItemNode {
    let labelNode: TextNode
    let textNode: TextNode
    let separatorNode: ASDisplayNode
    
    init() {
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.backgroundColor = UIColor(0xc8c7cc)
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (_ item: PeerInfoTextWithLabelItem, _ width: CGFloat, _ insets: PeerInfoItemNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { item, width, neighbors in
            let insets = peerInfoItemNeighborsPlainInsets(neighbors)
            let leftInset: CGFloat = 35.0
            
            let (labelLayout, labelApply) = makeLabelLayout(NSAttributedString(string: item.label, font: labelFont, textColor: UIColor(0x1195f2)), nil, 1, .end, CGSize(width: width - leftInset - 8.0, height: CGFloat.greatestFiniteMagnitude), nil)
            let (textLayout, textApply) = makeTextLayout(NSAttributedString(string: item.text, font: textFont, textColor: UIColor.black), nil, item.multiline ? 0 : 1, .end, CGSize(width: width - leftInset - 8.0, height: CGFloat.greatestFiniteMagnitude), nil)
            let contentSize = CGSize(width: width, height: textLayout.size.height + 39.0)
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    let _ = labelApply()
                    let _ = textApply()
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: labelLayout.size)
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 31.0), size: textLayout.size)
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - UIScreenPixel), size: CGSize(width: width - leftInset, height: UIScreenPixel))
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.separatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
    }
}
