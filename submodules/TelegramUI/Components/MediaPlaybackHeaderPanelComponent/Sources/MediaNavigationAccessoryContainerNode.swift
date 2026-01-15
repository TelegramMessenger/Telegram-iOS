import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class MediaNavigationAccessoryContainerNode: ASDisplayNode, ASGestureRecognizerDelegate {
    public let headerNode: MediaNavigationAccessoryHeaderNode
    private var presentationData: PresentationData
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.headerNode = MediaNavigationAccessoryHeaderNode(context: context, presentationData: presentationData)
        
        super.init()
        
        self.addSubnode(self.headerNode)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.headerNode.updatePresentationData(presentationData)
    }

    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        self.headerNode.updateLayout(size: CGSize(width: size.width, height: size.height), leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.headerNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
