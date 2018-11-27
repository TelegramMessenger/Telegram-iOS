import Foundation
import AsyncDisplayKit

final class ListViewReorderingItemNode: ASDisplayNode {
    weak var itemNode: ListViewItemNode?
    
    var currentState: (Int, Int)?
    
    private let copyView: UIView?
    private let initialLocation: CGPoint
    
    init(itemNode: ListViewItemNode, initialLocation: CGPoint) {
        self.itemNode = itemNode
        self.copyView = itemNode.view.snapshotView(afterScreenUpdates: false)
        self.initialLocation = initialLocation
        
        super.init()
        
        if let copyView = self.copyView {
            self.view.addSubview(copyView)
            copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x, y: initialLocation.y), size: copyView.bounds.size)
            copyView.bounds = itemNode.bounds
        }
    }
    
    func updateOffset(offset: CGFloat) {
        if let copyView = self.copyView {
            copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x, y: initialLocation.y + offset), size: copyView.bounds.size)
        }
    }
    
    func currentOffset() -> CGFloat? {
        if let copyView = self.copyView {
            return copyView.center.y
        }
        return nil
    }
    
    func animateCompletion(completion: @escaping () -> Void) {
        if let copyView = self.copyView, let itemNode = self.itemNode {
            itemNode.isHidden = false
            itemNode.transitionOffset = itemNode.apparentFrame.midY - copyView.frame.midY
            itemNode.addTransitionOffsetAnimation(0.0, duration: 0.2, beginAt: CACurrentMediaTime())
            completion()
        } else {
            completion()
        }
    }
}
