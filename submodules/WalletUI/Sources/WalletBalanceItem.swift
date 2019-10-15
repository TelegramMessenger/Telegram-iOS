import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Markdown

class WalletBalanceItem: ListViewItem, ItemListItem {
    let theme: WalletTheme
    let title: String
    let value: String
    let insufficient: Bool
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let isAlwaysPlain: Bool = true
    
    init(theme: WalletTheme, title: String, value: String, insufficient: Bool, sectionId: ItemListSectionId, style: ItemListStyle = .blocks) {
        self.theme = theme
        self.title = title
        self.value = value
        self.insufficient = insufficient
        self.sectionId = sectionId
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WalletBalanceItemNode()
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
            guard let nodeValue = node() as? WalletBalanceItemNode else {
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

private let titleFont = Font.regular(14.0)
private let transactionIcon = UIImage(bundleImageName: "Wallet/TransactionGem")?.precomposed()

class WalletBalanceItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let valueNode: TextNode
    private let iconNode: ASImageNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: WalletBalanceItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.valueNode = TextNode()
        self.valueNode.isUserInteractionEnabled = false
        self.valueNode.contentMode = .left
        self.valueNode.contentsScale = UIScreen.main.scale
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.valueNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: WalletBalanceItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeValueLayout = TextNode.asyncLayout(self.valueNode)
                
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: WalletTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let leftInset: CGFloat = 15.0 + params.leftInset
            let verticalInset: CGFloat = 7.0
            
            let iconImage: UIImage? = transactionIcon
            let iconSize = CGSize(width: 12.0, height: 10.0)
            
            let textColor = item.insufficient ? item.theme.list.freeTextErrorColor : item.theme.list.freeTextColor
            
            let attributedTitle = NSAttributedString(string: item.title, font: titleFont, textColor: textColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedTitle, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let attributedValue = NSAttributedString(string: item.value, font: titleFont, textColor: textColor)
            let (valueLayout, valueApply) = makeValueLayout(TextNodeLayoutArguments(attributedString: attributedValue, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + verticalInset + verticalInset)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    
                    if let _ = updatedTheme {
                        strongSelf.iconNode.image = iconImage
                    }
                    
                    let accessibilityLabel = item.title + item.value
                    strongSelf.activateArea.accessibilityLabel = accessibilityLabel
                    
                    strongSelf.accessibilityLabel = accessibilityLabel
                    
                    let _ = titleApply()
                    let _ = valueApply()
                    
                    let iconSpacing: CGFloat = 3.0
                    let valueSpacing: CGFloat = 2.0
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                    strongSelf.valueNode.frame = CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + iconSpacing + iconSize.width + valueSpacing, y: verticalInset), size: valueLayout.size)
                    strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + iconSpacing, y: verticalInset + 3.0), size: iconSize)
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
