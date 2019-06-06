import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

enum ItemListSectionHeaderAccessoryTextColor {
    case generic
    case destructive
}

struct ItemListSectionHeaderAccessoryText: Equatable {
    let value: String
    let color: ItemListSectionHeaderAccessoryTextColor
}

class ItemListSectionHeaderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let text: String
    let multiline: Bool
    let accessoryText: ItemListSectionHeaderAccessoryText?
    let sectionId: ItemListSectionId
    
    let isAlwaysPlain: Bool = true
    
    init(theme: PresentationTheme, text: String, multiline: Bool = false, accessoryText: ItemListSectionHeaderAccessoryText? = nil, sectionId: ItemListSectionId) {
        self.theme = theme
        self.text = text
        self.multiline = multiline
        self.accessoryText = accessoryText
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListSectionHeaderItemNode()
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
            guard let nodeValue = node() as? ItemListSectionHeaderItemNode else {
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

class ItemListSectionHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let accessoryTextNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.accessoryTextNode = TextNode()
        self.accessoryTextNode.isUserInteractionEnabled = false
        self.accessoryTextNode.contentMode = .left
        self.accessoryTextNode.contentsScale = UIScreen.main.scale
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = UIAccessibilityTraitStaticText | UIAccessibilityTraitHeader
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.accessoryTextNode)
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: ItemListSectionHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeAccessoryTextLayout = TextNode.asyncLayout(self.accessoryTextNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 15.0 + params.leftInset
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.text, font: titleFont, textColor: item.theme.list.sectionHeaderTextColor), backgroundColor: nil, maximumNumberOfLines: item.multiline ? 0 : 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            var accessoryTextString: NSAttributedString?
            if let accessoryText = item.accessoryText {
                let color: UIColor
                switch accessoryText.color {
                    case .generic:
                        color = item.theme.list.sectionHeaderTextColor
                    case .destructive:
                        color = item.theme.list.freeTextErrorColor
                }
                accessoryTextString = NSAttributedString(string: accessoryText.value, font: titleFont, textColor: color)
            }
            let (accessoryLayout, accessoryApply) = makeAccessoryTextLayout(TextNodeLayoutArguments(attributedString: accessoryTextString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            var insets = UIEdgeInsets()
            
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + 13.0)
            switch neighbors.top {
                case .none:
                    insets.top += 24.0
                case .otherSection:
                    insets.top += 28.0
                default:
                    break
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    let _ = titleApply()
                    let _ = accessoryApply()
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = item.text
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 7.0), size: titleLayout.size)
                    strongSelf.accessoryTextNode.frame = CGRect(origin: CGPoint(x: params.width - leftInset - accessoryLayout.size.width, y: 7.0), size: accessoryLayout.size)
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
