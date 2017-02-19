import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class ItemListActivityTextItem: ListViewItem, ItemListItem {
    let displayActivity: Bool
    let text: NSAttributedString
    let sectionId: ItemListSectionId
    
    let isAlwaysPlain: Bool = true
    
    init(displayActivity: Bool, text: NSAttributedString, sectionId: ItemListSectionId) {
        self.displayActivity = displayActivity
        self.text = text
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListActivityTextItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        guard let node = node as? ItemListActivityTextItemNode else {
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

class ItemListActivityTextItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private var activityIndicator: UIActivityIndicatorView?
    
    private var item: ItemListActivityTextItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        self.activityIndicator = activityIndicator
        self.view.addSubview(activityIndicator)
        activityIndicator.frame = CGRect(origin: CGPoint(x: 15.0, y: 6.0), size: activityIndicator.bounds.size)
        
        if let item = self.item {
            if item.displayActivity {
                activityIndicator.isHidden = false
                activityIndicator.startAnimating()
            } else {
                activityIndicator.isHidden = true
            }
        }
    }
    
    func asyncLayout() -> (_ item: ItemListActivityTextItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, width, neighbors in
            let leftInset: CGFloat = 15.0
            let verticalInset: CGFloat = 7.0
            
            var activityWidth: CGFloat = 0.0
            if item.displayActivity {
                activityWidth = 25.0
            }
            
            let titleString = NSMutableAttributedString(attributedString: item.text)
            titleString.removeAttribute(NSFontAttributeName, range: NSMakeRange(0, titleString.length))
            titleString.addAttributes([NSFontAttributeName: titleFont], range: NSMakeRange(0, titleString.length))
            
            let (titleLayout, titleApply) = makeTitleLayout(titleString, nil, 0, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), TextNodeCutout(position: .TopLeft, size: CGSize(width: activityWidth, height: 4.0)))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            
            contentSize = CGSize(width: width, height: titleLayout.size.height + verticalInset + verticalInset)
            insets = itemListNeighborsPlainInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                    
                    if let activityIndicator = strongSelf.activityIndicator, activityIndicator.isHidden != !item.displayActivity {
                        if item.displayActivity {
                            activityIndicator.isHidden = false
                            activityIndicator.startAnimating()
                        } else {
                            activityIndicator.isHidden = true
                            activityIndicator.stopAnimating()
                        }
                    }
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
