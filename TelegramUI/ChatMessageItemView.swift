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
    let statusInsets: UIEdgeInsets
    let defaultCornerRadius: CGFloat
    let mergedCornerRadius: CGFloat
    let contentMergedCornerRadius: CGFloat
    let maxDimensions: CGSize
}

struct ChatMessageItemInstantVideoConstants {
    let insets: UIEdgeInsets
    let dimensions: CGSize
}

struct ChatMessageItemFileLayoutConstants {
    let bubbleInsets: UIEdgeInsets
}

struct ChatMessageItemLayoutConstants {
    let avatarDiameter: CGFloat
    let timestampHeaderHeight: CGFloat
    
    let bubble: ChatMessageItemBubbleLayoutConstants
    let image: ChatMessageItemImageLayoutConstants
    let text: ChatMessageItemTextLayoutConstants
    let file: ChatMessageItemFileLayoutConstants
    let instantVideo: ChatMessageItemInstantVideoConstants
    
    init() {
        self.avatarDiameter = 37.0
        self.timestampHeaderHeight = 34.0
        
        self.bubble = ChatMessageItemBubbleLayoutConstants(edgeInset: 4.0, defaultSpacing: 2.0 + UIScreenPixel, mergedSpacing: 1.0, maximumWidthFillFactor: 0.85, minimumSize: CGSize(width: 40.0, height: 35.0), contentInsets: UIEdgeInsets(top: 1.0, left: 7.0, bottom: 1.0, right: 1.0))
        self.text = ChatMessageItemTextLayoutConstants(bubbleInsets: UIEdgeInsets(top: 6.0 + UIScreenPixel, left: 12.0, bottom: 6.0 - UIScreenPixel, right: 12.0))
        self.image = ChatMessageItemImageLayoutConstants(bubbleInsets: UIEdgeInsets(top: 0.5, left: 0.5, bottom: 0.5, right: 0.5), statusInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 6.0, right: 6.0), defaultCornerRadius: 17.0, mergedCornerRadius: 5.0, contentMergedCornerRadius: 5.0, maxDimensions: CGSize(width: 260.0, height: 260.0))
        self.file = ChatMessageItemFileLayoutConstants(bubbleInsets: UIEdgeInsets(top: 15.0, left: 9.0, bottom: 15.0, right: 12.0))
        self.instantVideo = ChatMessageItemInstantVideoConstants(insets: UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0), dimensions: CGSize(width: 212.0, height: 212.0))
    }
}

let defaultChatMessageItemLayoutConstants = ChatMessageItemLayoutConstants()

public class ChatMessageItemView: ListViewItemNode {
    let layoutConstants = defaultChatMessageItemLayoutConstants
    
    var item: ChatMessageItem?
    var controllerInteraction: ChatControllerInteraction?
    
    private var content: ChatMessageItemContent?
    
    public required convenience init() {
        self.init(layerBacked: true)
    }
    
    public init(layerBacked: Bool) {
        super.init(layerBacked: layerBacked, dynamicBounce: true, rotated: true)
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
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
            let (layout, apply) = doLayout(item, width, merged.top, merged.bottom, merged.dateAtBottom)
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        if short {
            self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height, to: 0.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        } else {
            self.transitionOffset = -self.bounds.size.height * 1.6
            self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
        }
    }
    
    func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { _, _, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: 32.0, height: 32.0), insets: UIEdgeInsets()), { _ in
                
            })
        }
    }
    
    func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
    
    func updateSelectionState(animated: Bool) {
    }
    
    func updateHighlightedState(animated: Bool) {
    }
    
    func updateAutomaticMediaDownloadSettings() {
    }
    
    override public func header() -> ListViewItemHeader? {
        if let item = self.item {
            return item.header
        } else {
            return nil
        }
    }
}
