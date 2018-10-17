import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class ItemListActivityTextItem: ListViewItem, ItemListItem {
    let displayActivity: Bool
    let theme: PresentationTheme
    let text: NSAttributedString
    let sectionId: ItemListSectionId
    
    let isAlwaysPlain: Bool = true
    
    init(displayActivity: Bool, theme: PresentationTheme, text: NSAttributedString, sectionId: ItemListSectionId) {
        self.displayActivity = displayActivity
        self.theme = theme
        self.text = text
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListActivityTextItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? ItemListActivityTextItemNode else {
                assertionFailure()
                return
            }
        
            let makeLayout = nodeValue.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
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
    private let activityIndicator: ActivityIndicator
    
    private var item: ItemListActivityTextItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.activityIndicator = ActivityIndicator(type: ActivityIndicatorType.custom(.black, 16.0, 2.0, false))
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activityIndicator)
    }
    
    func asyncLayout() -> (_ item: ItemListActivityTextItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 12.0 + params.leftInset
            let verticalInset: CGFloat = 7.0
            
            var activityWidth: CGFloat = 0.0
            if item.displayActivity {
                activityWidth = 25.0
            }
            
            let titleString = NSMutableAttributedString(attributedString: item.text)
            let hasFont = titleString.attribute(.font, at: 0, effectiveRange: nil) != nil
            if !hasFont {
                titleString.removeAttribute(NSAttributedStringKey.font, range: NSMakeRange(0, titleString.length))
                titleString.addAttributes([NSAttributedStringKey.font: titleFont], range: NSMakeRange(0, titleString.length))
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - 22.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: TextNodeCutout(topLeft: CGSize(width: activityWidth, height: 4.0)), insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + verticalInset + verticalInset)
            insets = itemListNeighborsPlainInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                    strongSelf.activityIndicator.frame = CGRect(origin: CGPoint(x: leftInset, y: 7.0), size: CGSize(width: 16.0, height: 16.0))
                    
                    strongSelf.activityIndicator.type = .custom(item.theme.list.itemAccentColor, 16.0, 2.0, false)
                    
                    if item.displayActivity {
                        strongSelf.activityIndicator.isHidden = false
                    } else {
                        strongSelf.activityIndicator.isHidden = true
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
