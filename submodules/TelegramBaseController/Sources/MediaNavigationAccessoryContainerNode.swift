import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext

final class MediaNavigationAccessoryContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    let backgroundNode: ASDisplayNode
    let headerNode: MediaNavigationAccessoryHeaderNode
    
    private let currentHeaderHeight: CGFloat = MediaNavigationAccessoryHeaderNode.minimizedHeight
    
    private var presentationData: PresentationData
    
    init(context: AccountContext) {
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.backgroundNode = ASDisplayNode()
        self.headerNode = MediaNavigationAccessoryHeaderNode(presentationData: self.presentationData)
        
        super.init()
        
        self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.headerNode)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.headerNode.updatePresentationData(presentationData)
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: self.currentHeaderHeight)))
        
        let headerHeight = self.currentHeaderHeight
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: headerHeight)))
        self.headerNode.updateLayout(size: CGSize(width: size.width, height: headerHeight), leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.headerNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
