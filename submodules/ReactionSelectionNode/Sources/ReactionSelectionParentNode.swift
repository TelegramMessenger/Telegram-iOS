/*import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData

public final class ReactionSelectionParentNode: ASDisplayNode {
    private let account: Account
    private let theme: PresentationTheme
    
    private var currentNode: ReactionSelectionNode?
    private var currentLocation: (CGPoint, CGFloat, CGPoint)?
    
    private var validLayout: (size: CGSize, insets: UIEdgeInsets)?
    
    public init(account: Account, theme: PresentationTheme) {
        self.account = account
        self.theme = theme
        
        super.init()
    }
    
    func displayReactions(_ reactions: [ReactionGestureItem], at point: CGPoint, touchPoint: CGPoint) {
        if let currentNode = self.currentNode {
            currentNode.removeFromSupernode()
            self.currentNode = nil
        }
        
        let reactionNode = ReactionSelectionNode(account: self.account, theme: self.theme, reactions: reactions)
        self.addSubnode(reactionNode)
        self.currentNode = reactionNode
        self.currentLocation = (point, point.x, touchPoint)
        
        if let (size, insets) = self.validLayout {
            self.update(size: size, insets: insets, isInitial: true)
            
            reactionNode.animateIn()
        }
    }
    
    func selectedReaction() -> ReactionGestureItem? {
        if let currentNode = self.currentNode {
            return currentNode.selectedReaction()
        }
        return nil
    }
    
    func dismissReactions(into targetNode: ASDisplayNode?, hideTarget: Bool) {
        if let currentNode = self.currentNode {
            currentNode.animateOut(into: targetNode, hideTarget: hideTarget, completion: { [weak currentNode] in
                currentNode?.removeFromSupernode()
            })
            self.currentNode = nil
        }
    }
    
    func updateReactionsAnchor(point: CGPoint, touchPoint: CGPoint) {
        if let (currentPoint, _, _) = self.currentLocation {
            self.currentLocation = (currentPoint, point.x, touchPoint)
            
            if let (size, insets) = self.validLayout {
                self.update(size: size, insets: insets, isInitial: false)
            }
        }
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets)
        
        self.update(size: size, insets: insets, isInitial: false)
    }
    
    private func update(size: CGSize, insets: UIEdgeInsets, isInitial: Bool) {
        if let currentNode = self.currentNode, let (point, offset, touchPoint) = self.currentLocation {
            currentNode.updateLayout(constrainedSize: size, startingPoint: CGPoint(x: size.width - 32.0, y: point.y), offsetFromStart: offset, isInitial: isInitial, touchPoint: touchPoint)
            currentNode.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}


*/
