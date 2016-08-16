import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display

private func backgroundImage() -> UIImage? {
    return generateImage(CGSize(width: 1.0, height: 25.0), contextGenerator: { size, context -> Void in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(white: 0.0, alpha: 0.2).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: UIScreenPixel)))
        context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        context.setFillColor(UIColor(white: 1.0, alpha: 0.9).cgColor)
        context.fill(CGRect(x: 0.0, y: UIScreenPixel, width: size.width, height: size.height - UIScreenPixel - UIScreenPixel))
    })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
}

private let titleFont = UIFont.systemFont(ofSize: 13.0)

class ChatUnreadItem: ListViewItem {
    func nodeConfiguredForWidth(async: (() -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: (ListViewItemNode, () -> Void) -> Void) {
        
        async {
            let node = ChatUnreadItemNode()
            node.layoutForWidth(width, item: self, previousItem: previousItem, nextItem: nextItem)
            completion(node, {})
        }
    }
}

class ChatUnreadItemNode: ListViewItemNode {
    let backgroundNode: ASImageNode
    let labelNode: TextNode
    
    init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        
        super.init(layerBacked: true)
        
        self.backgroundNode.image = backgroundImage()
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.labelNode)
        
        self.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0.0, 0.0, 1.0)
        
        self.scrollPositioningInsets = UIEdgeInsets(top: 5.0, left: 0.0, bottom: 5.0, right: 0.0)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        super.animateInsertion(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        
        //self.transitionOffset = -self.bounds.size.height * 1.6
        //self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
        //self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height * 1.4, to: 0.0, duration: duration)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let (layout, apply) = self.asyncLayout()(width: width)
        apply()
        self.contentSize = layout.contentSize
        self.insets = layout.insets
    }
    
    func asyncLayout() -> (width: CGFloat) -> (ListViewItemNodeLayout, () -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        return { width in
            let (size, apply) = labelLayout(attributedString: NSAttributedString(string: "Unread", font: titleFont, textColor: UIColor(0x86868d)), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), cutout: nil)
            
            let backgroundSize = CGSize(width: width, height: 25.0)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 25.0), insets: UIEdgeInsets(top: 5.0, left: 0.0, bottom: 5.0, right: 0.0)), { [weak self] in
                if let strongSelf = self {
                    let _ = apply()
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backgroundSize)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - size.size.width) / 2.0), y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0) - 1.0), size: size.size)
                }
            })
        }
    }
}
