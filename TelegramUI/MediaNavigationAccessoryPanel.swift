import Foundation
import Display
import AsyncDisplayKit
import TelegramCore

final class MediaNavigationAccessoryPanel: ASDisplayNode {
    let containerNode: MediaNavigationAccessoryContainerNode
    
    var close: (() -> Void)?
    var toggleRate: (() -> Void)?
    var togglePlayPause: (() -> Void)?
    var tapAction: (() -> Void)?
    
    init(context: AccountContext) {
        self.containerNode = MediaNavigationAccessoryContainerNode(context: context)
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        containerNode.headerNode.close = { [weak self] in
            if let strongSelf = self, let close = strongSelf.close {
                close()
            }
        }
        containerNode.headerNode.toggleRate = { [weak self] in
            self?.toggleRate?()
        }
        containerNode.headerNode.togglePlayPause = { [weak self] in
            if let strongSelf = self, let togglePlayPause = strongSelf.togglePlayPause {
                togglePlayPause()
            }
        }
        containerNode.headerNode.tapAction = { [weak self] in
            if let strongSelf = self, let tapAction = strongSelf.tapAction {
                tapAction()
            }
        }
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        self.containerNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    func animateIn(transition: ContainedViewLayoutTransition) {
        self.clipsToBounds = true
        let contentPosition = self.containerNode.layer.position
        transition.animatePosition(node: self.containerNode, from: CGPoint(x: contentPosition.x, y: contentPosition.y - 37.0), completion: { [weak self] _ in
            self?.clipsToBounds = false
        })
    }
    
    func animateOut(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.clipsToBounds = true
        let contentPosition = self.containerNode.layer.position
        transition.animatePosition(node: self.containerNode, to: CGPoint(x: contentPosition.x, y: contentPosition.y - 37.0), removeOnCompletion: false, completion: { [weak self] _ in
            self?.clipsToBounds = false
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.containerNode.hitTest(point, with: event)
    }
}
