import Foundation
import AsyncDisplayKit
import Display
import Postbox

struct ChatMessageItemBubbleLayoutConstants {
    let edgeInset: CGFloat
    let defaultSpacing: CGFloat
    let mergedSpacing: CGFloat
    let maximumWidthFillFactor: CGFloat
    let minimumSize: CGSize
    let contentInsets: UIEdgeInsets
}

struct ChatMessageItemTextLayoutConstants {
    let bubbleInsets: UIEdgeInsets
}

struct ChatMessageItemImageLayoutConstants {
    let bubbleInsets: UIEdgeInsets
    let defaultCornerRadius: CGFloat
    let mergedCornerRadius: CGFloat
    let contentMergedCornerRadius: CGFloat
}

struct ChatMessageItemFileLayoutConstants {
    let bubbleInsets: UIEdgeInsets
}

struct ChatMessageItemLayoutConstants {
    let avatarDiameter: CGFloat
    
    let bubble: ChatMessageItemBubbleLayoutConstants
    let image: ChatMessageItemImageLayoutConstants
    let text: ChatMessageItemTextLayoutConstants
    let file: ChatMessageItemFileLayoutConstants
    
    init() {
        self.avatarDiameter = 37.0
        
        self.bubble = ChatMessageItemBubbleLayoutConstants(edgeInset: 4.0, defaultSpacing: 2.5, mergedSpacing: 0.0, maximumWidthFillFactor: 0.9, minimumSize: CGSize(width: 40.0, height: 33.0), contentInsets: UIEdgeInsets(top: 1.0, left: 6.0, bottom: 1.0, right: 1.0))
        self.text = ChatMessageItemTextLayoutConstants(bubbleInsets: UIEdgeInsets(top: 5.0, left: 9.0, bottom: 4.0, right: 9.0))
        self.image = ChatMessageItemImageLayoutConstants(bubbleInsets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0), defaultCornerRadius: 15.0, mergedCornerRadius: 4.0, contentMergedCornerRadius: 2.0)
        self.file = ChatMessageItemFileLayoutConstants(bubbleInsets: UIEdgeInsets(top: 15.0, left: 9.0, bottom: 15.0, right: 12.0))
    }
}

let defaultChatMessageItemLayoutConstants = ChatMessageItemLayoutConstants()

public class ChatMessageItemView: ListViewItemNode {
    let layoutConstants = defaultChatMessageItemLayoutConstants
    
    var item: ChatMessageItem?
    var controllerInteraction: ChatControllerInteraction?
    
    public required convenience init() {
        self.init(layerBacked: true)
    }
    
    public init(layerBacked: Bool) {
        super.init(layerBacked: layerBacked, dynamicBounce: true)
        
        self.transform = CATransform3DMakeRotation(CGFloat(M_PI), 0.0, 0.0, 1.0)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func reuse() {
        super.reuse()
        
        self.item = nil
        self.frame = CGRect()
    }
    
    func setupItem(_ item: ChatMessageItem) {
        self.item = item
    }
    
    override public func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ChatMessageItem {
            let doLayout = self.asyncLayout()
            let merged = item.mergedWithItems(top: previousItem, bottom: nextItem)
            let (layout, apply) = doLayout(item: item, width: width, mergedTop: merged.top, mergedBottom: merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    override public func layoutAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        if let avatarNode = accessoryItemNode as? ChatMessageAvatarAccessoryItemNode {
            avatarNode.frame = CGRect(origin: CGPoint(x: 3.0, y: self.bounds.height - 38.0 - self.insets.top + 1.0), size: CGSize(width: 38.0, height: 38.0))
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        super.animateInsertion(currentTimestamp, duration: duration)
        
        self.transitionOffset = -self.bounds.size.height * 1.6
        self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
        //self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height * 1.4, to: 0.0, duration: duration)
    }
    
    func asyncLayout() -> (item: ChatMessageItem, width: CGFloat, mergedTop: Bool, mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { _, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: 32.0, height: 32.0), insets: UIEdgeInsets()), { _ in
                
            })
        }
    }
    
    func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
}
