import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

final class ItemListTextWithLabelItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let label: String
    let text: String
    let multiline: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let tag: Any?
    
    init(theme: PresentationTheme, label: String, text: String, multiline: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, tag: Any? = nil) {
        self.theme = theme
        self.label = label
        self.text = text
        self.multiline = multiline
        self.sectionId = sectionId
        self.action = action
        self.tag = tag
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListTextWithLabelItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListTextWithLabelItemNode {
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
    
    var selectable: Bool {
        return self.action != nil
    }
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let labelFont = Font.regular(14.0)
private let textFont = Font.regular(17.0)

class ItemListTextWithLabelItemNode: ListViewItemNode {
    let labelNode: TextNode
    let textNode: TextNode
    
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    var item: ItemListTextWithLabelItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (_ item: ItemListTextWithLabelItem, _ width: CGFloat, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let currentItem = self.item
        
        return { item, width, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let insets = itemListNeighborsPlainInsets(neighbors)
            let leftInset: CGFloat = 35.0
            let separatorHeight = UIScreenPixel
            
            let (labelLayout, labelApply) = makeLabelLayout(NSAttributedString(string: item.label, font: labelFont, textColor: item.theme.list.itemAccentColor), nil, 1, .end, CGSize(width: width - leftInset - 8.0, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            let (textLayout, textApply) = makeTextLayout(NSAttributedString(string: item.text, font: textFont, textColor: item.theme.list.itemPrimaryTextColor), nil, item.multiline ? 0 : 1, .end, CGSize(width: width - leftInset - 8.0, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            let contentSize = CGSize(width: width, height: textLayout.size.height + 39.0)
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = nodeLayout.size
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = labelApply()
                    let _ = textApply()
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: labelLayout.size)
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 31.0), size: textLayout.size)
                    
                    let leftInset: CGFloat
                    let style = ItemListStyle.plain
                    switch style {
                        case .plain:
                            leftInset = 35.0
                            
                            if strongSelf.backgroundNode.supernode != nil {
                                strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                            }
                            
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: width - leftInset, height: separatorHeight))
                        case .blocks:
                            leftInset = 16.0
                            
                            if strongSelf.backgroundNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                            }
                            if strongSelf.topStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                            }
                            switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topStripeNode.isHidden = true
                                default:
                                    strongSelf.topStripeNode.isHidden = false
                            }
                            let bottomStripeInset: CGFloat
                            let bottomStripeOffset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = 16.0
                                    bottomStripeOffset = -separatorHeight
                                default:
                                    bottomStripeInset = 0.0
                                    bottomStripeOffset = 0.0
                            }
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    var tag: Any? {
        return self.item?.tag
    }
}
