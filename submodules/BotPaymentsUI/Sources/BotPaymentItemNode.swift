import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private func botPaymentListHasRoundedBlockLayout(_ width: CGFloat) -> Bool {
    return width >= 375.0
}

class BotPaymentItemNode: ASDisplayNode {
    private let needsBackground: Bool
    
    let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var theme: PresentationTheme?
    
    init(needsBackground: Bool) {
        self.needsBackground = needsBackground
        
        self.backgroundNode = ASDisplayNode()
        self.topSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode = ASDisplayNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init()
        
        if needsBackground {
            self.addSubnode(self.backgroundNode)
            self.addSubnode(self.topSeparatorNode)
            self.addSubnode(self.bottomSeparatorNode)
        }
    }
    
    func measureInset(theme: PresentationTheme, width: CGFloat) -> CGFloat {
        return 0.0
    }
    
    final func updateLayout(theme: PresentationTheme, width: CGFloat, sideInset: CGFloat, measuredInset: CGFloat, previousItemNode: BotPaymentItemNode?, nextItemNode: BotPaymentItemNode?, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
            self.topSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
            self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        }
        
        let height = self.layoutContents(theme: theme, width: width, sideInset: sideInset, measuredInset: measuredInset, transition: transition)
        
        var topSeparatorInset: CGFloat = 0.0
            
        if self.maskNode.supernode == nil {
            self.addSubnode(self.maskNode)
        }
        
        let hasCorners = botPaymentListHasRoundedBlockLayout(width)
        var hasTopCorners = false
        var hasBottomCorners = false
    
        if let previousItemNode = previousItemNode, previousItemNode.needsBackground {
            topSeparatorInset = 16.0
        } else {
            hasTopCorners = true
            self.topSeparatorNode.isHidden = hasCorners
        }
        if let nextItemNode = nextItemNode, nextItemNode.needsBackground {
            self.bottomSeparatorNode.isHidden = true
        } else {
            hasBottomCorners = true
            self.bottomSeparatorNode.isHidden = hasCorners
        }
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
        transition.updateFrame(node: self.maskNode, frame: self.backgroundNode.frame.insetBy(dx: sideInset, dy: 0.0))
        
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: topSeparatorInset + sideInset, y: 0.0), size: CGSize(width: width - topSeparatorInset - sideInset - sideInset, height: UIScreenPixel)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset - sideInset, height: UIScreenPixel)))
        
        return height
    }
    
    func layoutContents(theme: PresentationTheme, width: CGFloat, sideInset: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 0.0
    }
}
