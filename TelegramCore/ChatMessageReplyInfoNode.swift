import Foundation
import AsyncDisplayKit
import Postbox
import Display

private let titleFont: UIFont = {
    if #available(iOS 8.2, *) {
        return UIFont.systemFont(ofSize: 14.0, weight: UIFontWeightMedium)
    } else {
        return CTFontCreateWithName("HelveticaNeue-Medium", 14.0, nil)
    }
}()
private let textFont = Font.regular(14.0)

class ChatMessageReplyInfoNode: ASTransformLayerNode {
    private let contentNode: ASDisplayNode
    private let lineNode: ASDisplayNode
    private var titleNode: TextNode?
    private var textNode: TextNode?
    
    override init() {
        self.contentNode = ASDisplayNode()
        self.contentNode.displaysAsynchronously = true
        self.contentNode.isLayerBacked = true
        self.contentNode.shouldRasterizeDescendants = true
        self.contentNode.contentMode = .left
        self.contentNode.contentsScale = UIScreenScale
        
        self.lineNode = ASDisplayNode()
        self.lineNode.displaysAsynchronously = false
        self.lineNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.lineNode)
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageReplyInfoNode?) -> (incoming: Bool, message: Message, constrainedSize: CGSize) -> (CGSize, () -> ChatMessageReplyInfoNode) {
        
        let titleNodeLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let textNodeLayout = TextNode.asyncLayout(maybeNode?.textNode)
        
        return { incoming, message, constrainedSize in
            let titleString = message.author?.displayTitle ?? ""
            let textString = message.text
            let titleColor = incoming ? UIColor(0x007bff) : UIColor(0x00a516)
            
            let leftInset: CGFloat = 10.0
            let lineColor = incoming ? UIColor(0x3ca7fe) : UIColor(0x29cc10)
            
            let maximumTextWidth = max(0.0, constrainedSize.width - leftInset)
            
            let contrainedTextSize = CGSize(width: maximumTextWidth, height: constrainedSize.height)
            
            let (titleLayout, titleApply) = titleNodeLayout(attributedString: NSAttributedString(string: titleString, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: contrainedTextSize, cutout: nil)
            let (textLayout, textApply) = textNodeLayout(attributedString: NSAttributedString(string: textString, font: textFont, textColor: UIColor.black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: contrainedTextSize, cutout: nil)
            
            let size = CGSize(width: max(titleLayout.size.width, textLayout.size.width) + leftInset, height: titleLayout.size.height + textLayout.size.height)
            
            return (size, {
                let node: ChatMessageReplyInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageReplyInfoNode()
                }
                
                let titleNode = titleApply()
                let textNode = textApply()
                
                if node.titleNode == nil {
                    titleNode.isLayerBacked = true
                    node.titleNode = titleNode
                    node.contentNode.addSubnode(titleNode)
                }
                
                if node.textNode == nil {
                    textNode.isLayerBacked = true
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode)
                }
                
                titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: titleLayout.size)
                textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: titleLayout.size.height), size: textLayout.size)
                
                node.lineNode.backgroundColor = lineColor
                node.lineNode.frame = CGRect(origin: CGPoint(x: 1.0, y: 2.5), size: CGSize(width: 2.0, height: size.height - 3.0))
                
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                return node
            })
        }
    }
}
