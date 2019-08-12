import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

class BotPaymentItemNode: ASDisplayNode {
    private let needsBackground: Bool
    
    let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var theme: PresentationTheme?
    
    init(needsBackground: Bool) {
        self.needsBackground = needsBackground
        
        self.backgroundNode = ASDisplayNode()
        self.topSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode = ASDisplayNode()
        
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
    
    final func updateLayout(theme: PresentationTheme, width: CGFloat, measuredInset: CGFloat, previousItemNode: BotPaymentItemNode?, nextItemNode: BotPaymentItemNode?, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
            self.topSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
            self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        }
        
        let height = self.layoutContents(theme: theme, width: width, measuredInset: measuredInset, transition: transition)
        
        var topSeparatorInset: CGFloat = 0.0
    
        if let previousItemNode = previousItemNode, previousItemNode.needsBackground {
            topSeparatorInset = 16.0
        }
        
        if let nextItemNode = nextItemNode, nextItemNode.needsBackground {
            bottomSeparatorNode.isHidden = true
        } else {
            bottomSeparatorNode.isHidden = false
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: topSeparatorInset, y: 0.0), size: CGSize(width: width - topSeparatorInset, height: UIScreenPixel)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return height
    }
    
    func layoutContents(theme: PresentationTheme, width: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 0.0
    }
}
