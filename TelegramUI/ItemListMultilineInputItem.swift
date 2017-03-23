import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class ItemListMultilineInputItem: ListViewItem, ItemListItem {
    let text: String
    let placeholder: String
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let action: () -> Void
    let textUpdated: (String) -> Void
    
    init(text: String, placeholder: String, sectionId: ItemListSectionId, style: ItemListStyle, textUpdated: @escaping (String) -> Void, action: @escaping () -> Void) {
        self.text = text
        self.placeholder = placeholder
        self.sectionId = sectionId
        self.style = style
        self.textUpdated = textUpdated
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListMultilineInputItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListMultilineInputItemNode {
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
}

private let titleFont = Font.regular(17.0)

class ItemListMultilineInputItemNode: ListViewItemNode, ASEditableTextNodeDelegate {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let textClippingNode: ASDisplayNode
    private let textNode: ASEditableTextNode
    private let measureTextNode: TextNode
    
    private var item: ItemListMultilineInputItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.bottomStripeNode.isLayerBacked = true
        
        self.textClippingNode = ASDisplayNode()
        self.textClippingNode.clipsToBounds = true
        
        self.textNode = ASEditableTextNode()
        self.measureTextNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.textClippingNode.addSubnode(self.textNode)
        self.addSubnode(self.textClippingNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textNode.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
        self.textNode.clipsToBounds = true
        self.textNode.delegate = self
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    func asyncLayout() -> (_ item: ItemListMultilineInputItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)
        
        return { item, width, neighbors in
            let leftInset: CGFloat
            switch item.style {
                case .blocks:
                    leftInset = 16.0
                case .plain:
                    leftInset = 35.0
            }
            
            var measureText = item.text
            if measureText.hasSuffix("\n") || measureText.isEmpty {
               measureText += "|"
            }
            let attributedMeasureText = NSAttributedString(string: measureText, font: Font.regular(17.0), textColor: .black)
            let attributedText = NSAttributedString(string: item.text, font: Font.regular(17.0), textColor: .black)
            let (textLayout, textApply) = makeTextLayout(attributedMeasureText, nil, 0, .end, CGSize(width: width - 8 - leftInset, height: CGFloat.greatestFiniteMagnitude), .natural, nil)
            
            let separatorHeight = UIScreenPixel
            
            let textTopInset: CGFloat = 11.0
            let textBottomInset: CGFloat = 11.0
            
            let contentSize = CGSize(width: width, height: textLayout.size.height + textTopInset + textBottomInset)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: UIColor(0x878787))
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = textApply()
                    if let currentText = strongSelf.textNode.attributedText {
                        if !currentText.isEqual(to: attributedText) {
                            strongSelf.textNode.attributedText = attributedText
                        }
                    } else {
                        strongSelf.textNode.attributedText = attributedText
                    }
                    
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
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset
                        default:
                            bottomStripeInset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    
                    if strongSelf.textNode.attributedPlaceholderText == nil || !strongSelf.textNode.attributedPlaceholderText!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.attributedPlaceholderText = attributedPlaceholderText
                    }
                    
                    strongSelf.textClippingNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTopInset), size: CGSize(width: width - leftInset, height: textLayout.size.height))
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width - leftInset - 8.0, height: textLayout.size.height))
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
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        let separatorHeight = UIScreenPixel
        let insets = self.insets
        let width = self.bounds.size.width
        let contentSize = CGSize(width: width, height: currentValue - insets.top - insets.bottom)
        
        if let item = self.item {
            let leftInset: CGFloat
            switch item.style {
                case .blocks:
                    leftInset = 16.0
                case .plain:
                    leftInset = 35.0
            }
            
            let textTopInset: CGFloat = 11.0
            let textBottomInset: CGFloat = 11.0
            
            self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
            self.bottomStripeNode.frame = CGRect(origin: CGPoint(x: self.bottomStripeNode.frame.minX, y: contentSize.height), size: CGSize(width: self.bottomStripeNode.frame.size.width, height: separatorHeight))
            
            self.textClippingNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTopInset), size: CGSize(width: max(0.0, width - leftInset), height: max(0.0, contentSize.height - textTopInset - textBottomInset)))
        }
    }
    
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        if let item = self.item {
            if let text = self.textNode.attributedText?.string {
                item.textUpdated(text)
            } else {
                item.textUpdated("")
            }
        }
    }
}
