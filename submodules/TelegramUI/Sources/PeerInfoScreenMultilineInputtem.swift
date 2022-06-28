import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI

final class PeerInfoScreenMultilineInputItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    let placeholder: String
    let textUpdated: (String) -> Void
    let action: () -> Void
    let maxLength: Int?
    
    init(
        id: AnyHashable,
        text: String,
        placeholder: String,
        textUpdated: @escaping (String) -> Void,
        action: @escaping () -> Void,
        maxLength: Int?
    ) {
        self.id = id
        self.text = text
        self.placeholder = placeholder
        self.textUpdated = textUpdated
        self.action = action
        self.maxLength = maxLength
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenMultilineInputItemNode()
    }
}

final class PeerInfoScreenMultilineInputItemNode: PeerInfoScreenItemNode {
    private let bottomSeparatorNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var item: PeerInfoScreenMultilineInputItem?
    private var itemNode: ItemListMultilineInputItemNode?
    
    override init() {
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.bottomSeparatorNode)
    }
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenMultilineInputItem else {
            return 10.0
        }
        
        self.item = item
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let inputItem = ItemListMultilineInputItem(presentationData: ItemListPresentationData(presentationData), text: item.text, placeholder: item.placeholder, maxLength: item.maxLength.flatMap { ItemListMultilineInputItemTextLimit(value: $0, display: true) }, sectionId: 0, style: .blocks, returnKeyType: .done, textUpdated: { updatedText in
            item.textUpdated(updatedText)
        }, action: {
            item.action()
        }, noInsets: true)
            
        let params = ListViewItemLayoutParams(width: width, leftInset: safeInsets.left, rightInset: safeInsets.right, availableHeight: 1000.0)
           
        let itemNode: ItemListMultilineInputItemNode
        if let current = self.itemNode {
            itemNode = current
            inputItem.updateNode(async: { $0() }, node: {
                return itemNode
            }, params: params, previousItem: nil, nextItem: nil, animation: .None, completion: { (layout, apply) in
                let nodeFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: layout.size.height))
                
                itemNode.contentSize = layout.contentSize
                itemNode.insets = layout.insets
                itemNode.frame = nodeFrame
                
                apply(ListViewItemApply(isOnScreen: true))
            })
        } else {
            var itemNodeValue: ListViewItemNode?
            inputItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                itemNodeValue = node
                apply().1(ListViewItemApply(isOnScreen: true))
            })
            itemNode = itemNodeValue as! ItemListMultilineInputItemNode
            self.itemNode = itemNode
            self.addSubnode(itemNode)
        }
           
        let height = itemNode.contentSize.height
           
        transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(), size: itemNode.bounds.size))
        
        var separatorInset: CGFloat = sideInset
        if bottomItem != nil {
            separatorInset += 49.0
        }
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        if self.maskNode.supernode == nil {
            self.addSubnode(self.maskNode)
        }
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
    
    func animateErrorIfNeeded() {
        self.itemNode?.animateErrorIfNeeded()
    }
}
