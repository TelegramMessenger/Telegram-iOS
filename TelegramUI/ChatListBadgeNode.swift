import Foundation
import AsyncDisplayKit
import Display

final class ChatListBadgeNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let textNode: TextNode
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (CGSize, UIImage?, NSAttributedString?) -> (CGSize, () -> Void) {
        let textLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] boundingSize, backgroundImage, text in
             let (layout, apply) = textLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: boundingSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var badgeSize: CGFloat = 0.0
            if let backgroundImage = backgroundImage {
                badgeSize += max(backgroundImage.size.width, layout.size.width + 10.0) + 5.0
            }
//            if let currentMentionBadgeImage = currentMentionBadgeImage {
//                if !badgeSize.isZero {
//                    badgeSize += currentMentionBadgeImage.size.width + 4.0
//                } else {
//                    badgeSize += currentMentionBadgeImage.size.width + 5.0
//                }
//            }
            
            //badgeSize = max(badgeSize, reorderInset)
            
            return (CGSize(width: badgeSize, height: 20.0), {
                if let strongSelf = self {
                    let _ = apply()
                    if let backgroundImage = backgroundImage {
                        strongSelf.backgroundNode.image = backgroundImage
                    }
                    strongSelf.backgroundNode.isHidden = backgroundImage == nil
                    
                    let backgroundWidth = max(layout.size.width + 10.0, strongSelf.backgroundNode.image?.size.width ?? 0.0)
                    let backgroundFrame = CGRect(x: 0.0, y: 0.0, width: backgroundWidth, height: strongSelf.backgroundNode.image?.size.height ?? 0.0)
                    let badgeTextFrame = CGRect(origin: CGPoint(x: backgroundFrame.midX - layout.size.width / 2.0, y: backgroundFrame.minY + 2.0), size: layout.size)
                    
                    strongSelf.textNode.frame = badgeTextFrame
                    strongSelf.backgroundNode.frame = backgroundFrame
                }
            })
        }
    }
}
