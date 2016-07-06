import UIKit
import AsyncDisplayKit

private let groupSpacing: CGFloat = 16.0

final class ActionSheetItemGroupsContainerNode: ASDisplayNode {
    private var groupNodes: [ActionSheetItemGroupNode] = []
    
    override init() {
        super.init()
    }
    
    func setGroups(_ groups: [ActionSheetItemGroup]) {
        for groupNode in self.groupNodes {
            groupNode.removeFromSupernode()
        }
        self.groupNodes.removeAll()
        
        for group in groups {
            let groupNode = ActionSheetItemGroupNode()
            groupNode.updateItemNodes(group.items.map({ $0.node() }), leadingVisibleNodeCount: group.leadingVisibleNodeCount ?? 1000.0)
            self.groupNodes.append(groupNode)
            self.addSubnode(groupNode)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        var groupsHeight: CGFloat = 0.0
        
        for groupNode in self.groupNodes.reversed() {
            if CGFloat(0.0).isLess(than: groupsHeight) {
                groupsHeight += groupSpacing
            }
            
            let size = groupNode.measure(CGSize(width: constrainedSize.width, height: max(0.0, constrainedSize.height - groupsHeight)))
            groupsHeight += size.height
        }
        
        return CGSize(width: constrainedSize.width, height: min(groupsHeight, constrainedSize.height))
    }
    
    override func layout() {
        var groupsHeight: CGFloat = 0.0
        for i in 0 ..< self.groupNodes.count {
            let groupNode = self.groupNodes[i]
            
            let size = groupNode.calculatedSize
            
            if i != 0 {
                groupsHeight += groupSpacing
                self.groupNodes[i - 1].trailingDimView.frame = CGRect(x: 0.0, y: groupNodes[i - 1].bounds.size.height, width: size.width, height: groupSpacing)
            }
            
            groupNode.frame = CGRect(origin: CGPoint(x: 0.0, y: groupsHeight), size: size)
            groupNode.trailingDimView.frame = CGRect()
            
            groupsHeight += size.height
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
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
}
