import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class ItemListSingleLineInputItem: ListViewItem, ItemListItem {
    let title: NSAttributedString
    let text: String
    let placeholder: String
    let sectionId: ItemListSectionId
    let action: () -> Void
    let textUpdated: (String) -> Void
    
    init(title: NSAttributedString, text: String, placeholder: String, sectionId: ItemListSectionId, textUpdated: @escaping (String) -> Void, action: @escaping () -> Void) {
        self.title = title
        self.text = text
        self.placeholder = placeholder
        self.sectionId = sectionId
        self.textUpdated = textUpdated
        self.action = action
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListSingleLineInputItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListSingleLineInputItemNode {
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

class ItemListSingleLineInputItemNode: ListViewItemNode, UITextFieldDelegate {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let titleNode: TextNode
    private let textNode: TextFieldNode
    
    private var item: ItemListSingleLineInputItem?
    
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
        
        self.titleNode = TextNode()
        self.textNode = TextFieldNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.textNode.textField.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
        self.textNode.textField.font = Font.regular(17.0)
        self.textNode.textField.textColor = .black
        self.textNode.clipsToBounds = true
        self.textNode.textField.delegate = self
        self.textNode.textField.addTarget(self, action: #selector(self.textFieldTextChanged(_:)), for: .editingChanged)
        self.textNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
    }
    
    func asyncLayout() -> (_ item: ItemListSingleLineInputItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, width, neighbors in
            let leftInset: CGFloat = 16.0
            
            let titleString = NSMutableAttributedString(attributedString: item.title)
            titleString.removeAttribute(NSFontAttributeName, range: NSMakeRange(0, titleString.length))
            titleString.addAttributes([NSFontAttributeName: Font.regular(17.0)], range: NSMakeRange(0, titleString.length))
            
            let (titleLayout, titleApply) = makeTitleLayout(titleString, nil, 0, .end, CGSize(width: width - 32 - leftInset, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let separatorHeight = UIScreenPixel
            
            let contentSize = CGSize(width: width, height: 44.0)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            let attributedPlaceholderText = NSAttributedString(string: item.placeholder, font: Font.regular(17.0), textColor: UIColor(0x878787))
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((layout.contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    
                    if let currentText = strongSelf.textNode.textField.text {
                        if currentText != item.text {
                            strongSelf.textNode.textField.text = item.text
                        }
                    } else {
                        strongSelf.textNode.textField.text = item.text
                    }
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width, y: floor((layout.contentSize.height - 40.0) / 2.0)), size: CGSize(width: max(1.0, width - (leftInset + titleLayout.size.width)), height: 40.0))
                    
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
                    
                    if strongSelf.textNode.textField.attributedPlaceholder == nil || !strongSelf.textNode.textField.attributedPlaceholder!.isEqual(to: attributedPlaceholderText) {
                        strongSelf.textNode.textField.attributedPlaceholder = attributedPlaceholderText
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
    
    @objc func textFieldTextChanged(_ textField: UITextField) {
        if let item = self.item {
            if let text = self.textNode.textField.text {
                item.textUpdated(text)
            } else {
                item.textUpdated("")
            }
        }
    }
}
