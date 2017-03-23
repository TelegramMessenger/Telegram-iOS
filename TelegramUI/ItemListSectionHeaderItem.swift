import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class ItemListSectionHeaderItem: ListViewItem, ItemListItem {
    let text: String
    let sectionId: ItemListSectionId
    
    let isAlwaysPlain: Bool = true
    
    init(text: String, sectionId: ItemListSectionId) {
        self.text = text
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListSectionHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        guard let node = node as? ItemListSectionHeaderItemNode else {
            assertionFailure()
            return
        }
        
        Queue.mainQueue().async {
            let makeLayout = node.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, {
                        apply()
                    })
                }
            }
        }
    }
}

private let titleFont = Font.regular(14.0)

class ItemListSectionHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
    }
    
    func asyncLayout() -> (_ item: ItemListSectionHeaderItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, width, neighbors in
            let leftInset: CGFloat = 15.0
            
            let (titleLayout, titleApply) = makeTitleLayout(NSAttributedString(string: item.text, font: titleFont, textColor: UIColor(0x6d6d72)), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            
            let contentSize: CGSize
            var insets = UIEdgeInsets()
            let separatorHeight = UIScreenPixel
            
            contentSize = CGSize(width: width, height: 30.0)
            switch neighbors.top {
                case .none:
                    insets.top += 24.0
                case .otherSection:
                    insets.top += 28.0
                default:
                    break
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    let _ = titleApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 7.0), size: titleLayout.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
