import UIKit
import AsyncDisplayKit

private let groupSpacing: CGFloat = 8.0

final class ActionSheetItemGroupsContainerNode: ASDisplayNode {
    var theme: ActionSheetControllerTheme {
        didSet {
            self.setGroups(self.groups)
            if let size = self.validSize {
                let _ = self.updateLayout(constrainedSize: size, transition: .immediate)
            }
        }
    }
    
    private var highlightedItemIndex: Int? = nil
    
    private var groups: [ActionSheetItemGroup] = []
    var groupNodes: [ActionSheetItemGroupNode] = []
    
    var requestLayout: (() -> Void)?
    
    private var validSize: CGSize?
    
    init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        super.init()
    }
    
    func setHighlightedItemIndex(_ index: Int?, update: Bool = false) {
        self.highlightedItemIndex = index
        
        if update {
            var groupIndex = 0
            var i = 0
            for _ in self.groups {
                for itemNode in self.groupNodes[groupIndex].itemNodes {
                    if i == index {
                        itemNode.setHighlighted(true, animated: false)
                    } else {
                        itemNode.setHighlighted(false, animated: false)
                    }
                    i += 1
                }
                groupIndex += 1
            }
        }
    }
    
    func decreaseHighlightedIndex() {
        let currentHighlightedIndex = self.highlightedItemIndex ?? 0
        
        self.setHighlightedItemIndex(max(0, currentHighlightedIndex - 1), update: true)
    }
    
    func increaseHighlightedIndex() {
        let currentHighlightedIndex = self.highlightedItemIndex ?? -1
        
        var groupIndex = 0
        var maxAvailabledIndex = 0
        for _ in self.groups {
            for _ in self.groupNodes[groupIndex].itemNodes {
                maxAvailabledIndex += 1
            }
            groupIndex += 1
        }
        
        self.setHighlightedItemIndex(min(maxAvailabledIndex - 1, currentHighlightedIndex + 1), update: true)
    }
    
    func performHighlightedAction() {
        guard let highlightedItemIndex = self.highlightedItemIndex else {
            return
        }
        
        var i = 0
        var groupIndex = 0
        for _ in self.groups {
            for itemNode in self.groupNodes[groupIndex].itemNodes {
                if i == highlightedItemIndex {
                    itemNode.performAction()
                    return
                }
                i += 1
            }
            groupIndex += 1
        }
    }
        
    func setGroups(_ groups: [ActionSheetItemGroup]) {
        self.groups = groups
        
        for groupNode in self.groupNodes {
            groupNode.removeFromSupernode()
        }
        self.groupNodes.removeAll()
        
        var i = 0
        for group in groups {
            let groupNode = ActionSheetItemGroupNode(theme: self.theme)
            let itemNodes = group.items.map({ $0.node(theme: self.theme) })
                
            for node in itemNodes {
                node.requestLayout = { [weak self] in
                    self?.requestLayout?()
                }
                let index = i
                node.highlightedUpdated = { [weak self] highlighted in
                    if highlighted {
                        self?.highlightedItemIndex = index
                    }
                }
                i += 1
            }
            groupNode.updateItemNodes(itemNodes, leadingVisibleNodeCount: group.leadingVisibleNodeCount ?? 1000.0)
            self.groupNodes.append(groupNode)
            self.addSubnode(groupNode)
        }
    }
    
    func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validSize = constrainedSize
        
        var groupsHeight: CGFloat = 0.0
        
        var calculatedSizes: [CGSize] = []
        for groupNode in self.groupNodes.reversed() {
            if CGFloat(0.0).isLess(than: groupsHeight) {
                groupsHeight += groupSpacing
            }
            
            let size = groupNode.updateLayout(constrainedSize: CGSize(width: constrainedSize.width, height: max(0.0, constrainedSize.height - groupsHeight)), transition: transition)
            calculatedSizes.insert(size, at: 0)
            
            groupsHeight += size.height
        }
        
        var itemGroupsHeight: CGFloat = 0.0
        for i in 0 ..< self.groupNodes.count {
            let groupNode = self.groupNodes[i]
                        
            let size = calculatedSizes[i]
            if i != 0 {
                itemGroupsHeight += groupSpacing
                transition.updateFrame(view: self.groupNodes[i - 1].trailingDimView, frame: CGRect(x: 0.0, y: groupNodes[i - 1].bounds.size.height, width: size.width, height: groupSpacing))
            }
            transition.updateFrame(node: groupNode, frame: CGRect(origin: CGPoint(x: 0.0, y: itemGroupsHeight), size: size))
            transition.updateFrame(view: groupNode.trailingDimView, frame: CGRect())
            
            itemGroupsHeight += size.height
        }
        return CGSize(width: constrainedSize.width, height: min(groupsHeight, constrainedSize.height))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.isUserInteractionEnabled else {
            return nil
        }
        for groupNode in self.groupNodes {
            if groupNode.frame.contains(point) {
                return groupNode.hitTest(self.convert(point, to: groupNode), with: event)
            }
        }
        return nil
    }
    
    func animateDimViewsAlpha(from: CGFloat, to: CGFloat, duration: Double) {
        for node in self.groupNodes {
            node.animateDimViewsAlpha(from: from, to: to, duration: duration)
        }
    }
    
    public func updateItem(groupIndex: Int, itemIndex: Int, _ f: (ActionSheetItem) -> ActionSheetItem) {
        var item = self.groups[groupIndex].items[itemIndex]
        let itemNode = self.groupNodes[groupIndex].itemNode(at: itemIndex)
        item = f(item)
        item.updateNode(itemNode)
        
        var groupItems = self.groups[groupIndex].items
        groupItems[itemIndex] = item
        
        self.groups[groupIndex] = ActionSheetItemGroup(items: groupItems)
    }
    
    func setItemGroupOverlayNode(groupIndex: Int, node: ActionSheetGroupOverlayNode) {
        self.groupNodes[groupIndex].setOverlayNode(node)
    }
}
