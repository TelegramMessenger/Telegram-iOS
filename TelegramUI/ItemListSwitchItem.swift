import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

class ItemListSwitchItem: ListViewItem, ItemListItem {
    let title: String
    let value: Bool
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let updated: (Bool) -> Void
    
    init(title: String, value: Bool, sectionId: ItemListSectionId, style: ItemListStyle, updated: @escaping (Bool) -> Void) {
        self.title = title
        self.value = value
        self.sectionId = sectionId
        self.style = style
        self.updated = updated
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListSwitchItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(false) })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListSwitchItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            var animated = true
                            if case .None = animation {
                                animated = false
                            }
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
}

private let titleFont = Font.regular(17.0)

class ItemListSwitchItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let titleNode: TextNode
    private var switchNode: SwitchNode
    
    private var item: ItemListSwitchItem?
    
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
        self.titleNode.isLayerBacked = true
        self.switchNode = SwitchNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.switchNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        (self.switchNode.view as? UISwitch)?.addTarget(self, action: #selector(self.switchValueChanged(_:)), for: .valueChanged)
    }
    
    func asyncLayout() -> (_ item: ItemListSwitchItem, _ width: CGFloat, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, width, neighbors in
            let sectionInset: CGFloat = 22.0
            let rightInset: CGFloat = 80.0
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            switch item.style {
                case .plain:
                    contentSize = CGSize(width: width, height: 44.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    contentSize = CGSize(width: width, height: 44.0)
                    insets = itemListNeighborsGroupedInsets(neighbors)
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(NSAttributedString(string: item.title, font: titleFont, textColor: UIColor.black), nil, 1, .end, CGSize(width: width - 20, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    
                    let leftInset: CGFloat
                    
                    switch item.style {
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
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = 16.0
                                default:
                                    bottomStripeInset = 0.0
                            }
                            
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: titleLayout.size)
                    if let switchView = strongSelf.switchNode.view as? UISwitch {
                        if strongSelf.switchNode.bounds.size.width.isZero {
                            switchView.sizeToFit()
                        }
                        let switchSize = switchView.bounds.size
                        
                        strongSelf.switchNode.frame = CGRect(origin: CGPoint(x: width - switchSize.width - 15.0, y:6.0), size: switchSize)
                        if switchView.isOn != item.value {
                            switchView.setOn(item.value, animated: animated)
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
    
    @objc func switchValueChanged(_ switchView: UISwitch) {
        if let item = self.item {
            item.updated(switchView.isOn)
        }
    }
}
