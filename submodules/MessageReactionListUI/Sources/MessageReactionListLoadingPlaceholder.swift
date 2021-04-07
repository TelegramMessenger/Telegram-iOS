import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TelegramCore
import SyncCore

final class MessageReactionListLoadingPlaceholder: ASDisplayNode {
    private let theme: PresentationTheme
    private let itemHeight: CGFloat
    private let itemImage: UIImage?
    
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightNode: ASImageNode
    private var itemNodes: [ASImageNode] = []
    
    init(theme: PresentationTheme, itemHeight: CGFloat) {
        self.theme = theme
        self.itemHeight = itemHeight
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor(white: 0.92, alpha: 1.0)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.list.itemPlainSeparatorColor
        
        self.highlightNode = ASImageNode()
        self.highlightNode.displaysAsynchronously = false
        self.highlightNode.displayWithoutProcessing = true
        
        let leftInset: CGFloat = 15.0
        let avatarSize: CGFloat = 40.0
        let avatarSpacing: CGFloat = 11.0
        let contentWidth: CGFloat = 4.0
        let contentHeight: CGFloat = 14.0
        let rightInset: CGFloat = 54.0
        self.itemImage = generateImage(CGSize(width: leftInset + avatarSize + avatarSpacing + contentWidth + rightInset, height: itemHeight), rotatedContext: { size, context in
            context.setFillColor(theme.actionSheet.opaqueItemBackgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.list.itemPlainSeparatorColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: UIScreenPixel)))
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: leftInset, y: floor((itemHeight - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize)))
            let contentOrigin = leftInset + avatarSize + avatarSpacing
            context.fill(CGRect(origin: CGPoint(x: contentOrigin, y: floor((size.height - contentHeight) / 2.0)), size: CGSize(width: size.width - contentOrigin - rightInset, height: contentHeight)))
        })?.stretchableImage(withLeftCapWidth: Int(leftInset + avatarSize + avatarSpacing + 1), topCapHeight: 0)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.highlightNode)
        self.addSubnode(self.separatorNode)
    }
    
    func updateLayout(size: CGSize) {
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        
        var verticalOffset: CGFloat = 0.0
        var index = 0
        while verticalOffset < size.height - 1.0 {
            if self.itemNodes.count >= index {
                let itemNode = ASImageNode()
                itemNode.image = self.itemImage
                self.itemNodes.append(itemNode)
                self.addSubnode(itemNode)
            }
            self.itemNodes[index].frame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: size.width, height: self.itemHeight))
            verticalOffset += self.itemHeight
            index += 1
        }
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: size.width, height: UIScreenPixel))
        if index < self.itemNodes.count {
            for i in index ..< self.itemNodes.count {
                self.itemNodes[i].removeFromSupernode()
            }
            self.itemNodes.removeLast(self.itemNodes.count - index)
        }
    }
}
