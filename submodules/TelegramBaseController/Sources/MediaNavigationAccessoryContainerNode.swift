import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext

public final class MediaNavigationAccessoryContainerNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private let displayBackground: Bool

    public let backgroundNode: ASDisplayNode
    public let separatorNode: ASDisplayNode
    public let headerNode: MediaNavigationAccessoryHeaderNode
    
    private let currentHeaderHeight: CGFloat = MediaNavigationAccessoryHeaderNode.minimizedHeight
    
    private var presentationData: PresentationData
    
    init(context: AccountContext, presentationData: PresentationData, displayBackground: Bool) {
        self.displayBackground = displayBackground

        self.presentationData = presentationData
        
        self.backgroundNode = ASDisplayNode()
        self.separatorNode = ASDisplayNode()
        self.headerNode = MediaNavigationAccessoryHeaderNode(context: context, presentationData: presentationData)
        
        super.init()

        if self.displayBackground {
            self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
            self.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        }
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.headerNode)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData

        if self.displayBackground {
            self.backgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
            self.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        }

        self.headerNode.updatePresentationData(presentationData)
    }

    func animateIn(transition: ContainedViewLayoutTransition) {
        self.headerNode.animateIn(transition: transition)
    }

    func animateOut(transition: ContainedViewLayoutTransition) {
        self.headerNode.animateOut(transition: transition)
    }

    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: self.currentHeaderHeight)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.currentHeaderHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        let headerHeight = self.currentHeaderHeight
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: headerHeight)))
        self.headerNode.updateLayout(size: CGSize(width: size.width, height: headerHeight), leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.headerNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
