import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display

private func backgroundImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context -> Void in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(0x748391, 0.45).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
}

private let titleFont = UIFont.systemFont(ofSize: 13.0)

class ChatHoleItem: ListViewItem {
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        
        async {
            let node = ChatHoleItemNode()
            node.layoutForWidth(width, item: self, previousItem: previousItem, nextItem: nextItem)
            completion(node, {})
        }
    }
}

class ChatHoleItemNode: ListViewItemNode {
    let backgroundNode: ASImageNode
    let labelNode: TextNode
    
    init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        
        super.init(layerBacked: true)
        
        self.backgroundNode.image = backgroundImage(color: UIColor.blue)
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.labelNode)
        
        self.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0.0, 0.0, 1.0)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let (layout, apply) = self.asyncLayout()(width)
        apply()
        self.contentSize = layout.contentSize
        self.insets = layout.insets
    }
    
    func asyncLayout() -> (_ width: CGFloat) -> (ListViewItemNodeLayout, () -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        return { width in
            let (size, apply) = labelLayout(NSAttributedString(string: "Loading", font: titleFont, textColor: UIColor.white), nil, 1, .end, CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let backgroundSize = CGSize(width: size.size.width + 8.0 + 8.0, height: 20.0)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 20.0), insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)), { [weak self] in
                if let strongSelf = self {
                    let _ = apply()
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: strongSelf.backgroundNode.frame.origin.x + 8.0, y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0) - 1.0), size: size.size)
                }
            })
        }
    }
}
