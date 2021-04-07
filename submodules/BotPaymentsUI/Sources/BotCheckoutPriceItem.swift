import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

class BotCheckoutPriceItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let title: String
    let label: String
    let isFinal: Bool
    let sectionId: ItemListSectionId
    
    let requestsNoInset: Bool = true
    
    init(theme: PresentationTheme, title: String, label: String, isFinal: Bool, sectionId: ItemListSectionId) {
        self.theme = theme
        self.title = title
        self.label = label
        self.isFinal = isFinal
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = BotCheckoutPriceItemNode()
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? BotCheckoutPriceItemNode {
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
    
    let selectable: Bool = false
}

private let titleFont = Font.regular(17.0)
private let finalFont = Font.semibold(17.0)

private func priceItemInsets(_ neighbors: ItemListNeighbors) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    switch neighbors.top {
        case .otherSection:
            insets.top += 8.0
        case .none, .sameSection:
            break
    }
    switch neighbors.bottom {
        case .none, .otherSection:
            insets.bottom += 8.0
        case .sameSection:
            break
    }
    return insets
}

class BotCheckoutPriceItemNode: ListViewItemNode {
    let titleNode: TextNode
    let labelNode: TextNode
    
    private var item: BotCheckoutPriceItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
    }
    
    func asyncLayout() -> (_ item: BotCheckoutPriceItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { item, params, neighbors in
            let rightInset: CGFloat = 16.0 + params.rightInset
            
            let contentSize = CGSize(width: params.width, height: 34.0)
            let insets = priceItemInsets(neighbors)
            
            let textFont: UIFont
            let textColor: UIColor
            if item.isFinal {
                textFont = finalFont
                textColor = item.theme.list.itemPrimaryTextColor
            } else {
                textFont = titleFont
                textColor = item.theme.list.itemSecondaryTextColor
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    
                    let leftInset: CGFloat = 16.0 + params.leftInset
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - labelLayout.size.width, y: floor((contentSize.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
