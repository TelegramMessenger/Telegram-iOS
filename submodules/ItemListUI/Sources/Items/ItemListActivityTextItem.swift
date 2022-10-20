import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ActivityIndicator

public class ItemListActivityTextItem: ListViewItem, ItemListItem {
    let displayActivity: Bool
    let presentationData: ItemListPresentationData
    let text: NSAttributedString
    public let sectionId: ItemListSectionId
    
    public let isAlwaysPlain: Bool = true
    
    public init(displayActivity: Bool, presentationData: ItemListPresentationData, text: NSAttributedString, sectionId: ItemListSectionId) {
        self.displayActivity = displayActivity
        self.presentationData = presentationData
        self.text = text
        self.sectionId = sectionId
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListActivityTextItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? ItemListActivityTextItemNode else {
                assertionFailure()
                return
            }
        
            let makeLayout = nodeValue.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

public class ItemListActivityTextItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let activityIndicator: ActivityIndicator
    
    private var item: ItemListActivityTextItem?
    
    public init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.activityIndicator = ActivityIndicator(type: ActivityIndicatorType.custom(.black, 16.0, 2.0, false))
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activityIndicator)
    }
    
    public func asyncLayout() -> (_ item: ItemListActivityTextItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 12.0 + params.leftInset
            let verticalInset: CGFloat = 7.0
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            
            var activityWidth: CGFloat = 0.0
            if item.displayActivity {
                activityWidth = 25.0
            }
            
            let titleString = NSMutableAttributedString(attributedString: item.text)
            let hasFont = titleString.attribute(.font, at: 0, effectiveRange: nil) != nil
            if !hasFont {
                titleString.removeAttribute(NSAttributedString.Key.font, range: NSMakeRange(0, titleString.length))
                titleString.addAttributes([NSAttributedString.Key.font: titleFont], range: NSMakeRange(0, titleString.length))
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - 20.0 - 22.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: TextNodeCutout(topLeft: CGSize(width: activityWidth, height: 22.0)), insets: UIEdgeInsets()))
            
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
                    strongSelf.activityIndicator.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((contentSize.height - 16.0) / 2.0)), size: CGSize(width: 16.0, height: 16.0))
                    
                    strongSelf.activityIndicator.type = .custom(item.presentationData.theme.list.itemAccentColor, 16.0, 2.0, false)
                    
                    if item.displayActivity {
                        strongSelf.activityIndicator.isHidden = false
                    } else {
                        strongSelf.activityIndicator.isHidden = true
                    }
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
