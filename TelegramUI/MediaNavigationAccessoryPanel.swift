import Foundation
import Display
import AsyncDisplayKit

final class MediaNavigationAccessoryPanel: ASDisplayNode {
    private let containerNode: MediaNavigationAccessoryContainerNode
    
    var close: (() -> Void)?
    
    override init() {
        self.containerNode = MediaNavigationAccessoryContainerNode()
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        containerNode.headerNode.close = { [weak self] in
            if let strongSelf = self, let close = strongSelf.close {
                close()
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        self.containerNode.updateLayout(size: size, transition: transition)
    }
    
    func animateIn(transition: ContainedViewLayoutTransition) {
        self.clipsToBounds = true
        let contentPosition = self.containerNode.layer.position
        transition.animatePosition(node: self.containerNode, from: CGPoint(x: contentPosition.x, y: contentPosition.y - self.containerNode.frame.size.height), completion: { [weak self] _ in
            self?.clipsToBounds = false
        })
    }
    
    func animateOut(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.clipsToBounds = true
        let contentPosition = self.containerNode.layer.position
        transition.animatePosition(node: self.containerNode, to: CGPoint(x: contentPosition.x, y: contentPosition.y - self.containerNode.frame.size.height), removeOnCompletion: false, completion: { [weak self] _ in
            self?.clipsToBounds = false
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
}
