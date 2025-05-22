import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatMessageItemCommon

private let titleFont = UIFont.systemFont(ofSize: 13.0)

public class ChatUnreadItem: ListViewItem {
    public let index: MessageIndex
    public let presentationData: ChatPresentationData
    public let controllerInteraction: ChatControllerInteraction
    public let header: ChatMessageDateHeader
    
    public init(index: MessageIndex, presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction, context: AccountContext) {
        self.index = index
        self.presentationData = presentationData
        self.controllerInteraction = controllerInteraction
        self.header = ChatMessageDateHeader(timestamp: index.timestamp, separableThreadId: nil, scheduled: false, displayHeader: nil, presentationData: presentationData, controllerInteraction: controllerInteraction, context: context)
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatUnreadItemNode()
            
            let dateAtBottom = !chatItemsHaveCommonDateHeader(self, nextItem)
            let (layout, apply) = node.asyncLayout()(self, params, dateAtBottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(.None)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatUnreadItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let dateAtBottom = !chatItemsHaveCommonDateHeader(self, nextItem)
                    
                    let (layout, apply) = nodeLayout(self, params, dateAtBottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
}

public class ChatUnreadItemNode: ListViewItemNode {
    public var item: ChatUnreadItem?
    public let backgroundNode: ASImageNode
    public let labelNode: TextNode
    
    public let activateArea: AccessibilityAreaNode
    
    private var wallpaperBackgroundNode: WallpaperBackgroundNode?
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var theme: ChatPresentationThemeData?
    
    private let layoutConstants = ChatMessageItemLayoutConstants.default
    
    public init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.labelNode)
        
        self.addSubnode(self.activateArea)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.scrollPositioningInsets = UIEdgeInsets(top: 5.0, left: 0.0, bottom: 6.0, right: 0.0)
        self.canBeUsedAsScrollToItemAnchor = false
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        super.animateInsertion(currentTimestamp, duration: duration, options: options)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ChatUnreadItem {
            let dateAtBottom = !chatItemsHaveCommonDateHeader(item, nextItem)
            let (layout, apply) = self.asyncLayout()(item, params, dateAtBottom)
            apply(.None)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
        }
    }
    
    public func asyncLayout() -> (_ item: ChatUnreadItem, _ params: ListViewItemLayoutParams, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let layoutConstants = self.layoutConstants
        let currentTheme = self.theme
        
        return { [weak self] item, params, dateAtBottom in
            var updatedBackgroundImage: UIImage?
            if currentTheme != item.presentationData.theme {
                updatedBackgroundImage = PresentationResourcesChat.chatUnreadBarBackgroundImage(item.presentationData.theme.theme)
            }
            
            let string = item.presentationData.strings.Conversation_UnreadMessages
            let (size, apply) = labelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: string, font: titleFont, textColor: item.presentationData.theme.theme.chat.serviceMessage.unreadBarTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let backgroundSize = CGSize(width: params.width, height: 25.0)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 25.0), insets: UIEdgeInsets(top: 6.0 + (dateAtBottom ? layoutConstants.timestampHeaderHeight : 0.0), left: 0.0, bottom: 5.0, right: 0.0)), { animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.theme = item.presentationData.theme
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    let _ = apply()
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: backgroundSize)
                    strongSelf.activateArea.accessibilityLabel = string
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backgroundSize)
                    
                    let labelFrame = CGRect(origin: CGPoint(x: params.leftInset + floorToScreenPixels((backgroundSize.width - params.leftInset - params.rightInset - size.size.width) / 2.0), y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0)), size: size.size)
                    animation.animator.updatePosition(layer: strongSelf.labelNode.layer, position: labelFrame.center, completion: nil)
                    strongSelf.labelNode.bounds = CGRect(origin: CGPoint(), size: labelFrame.size)
                    
                    if item.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                        if strongSelf.backgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                            backgroundContent.clipsToBounds = true

                            strongSelf.backgroundContent = backgroundContent
                            strongSelf.insertSubnode(backgroundContent, at: 0)
                        }
                    } else {
                        strongSelf.backgroundContent?.removeFromSupernode()
                        strongSelf.backgroundContent = nil
                    }
                    
                    if let backgroundContent = strongSelf.backgroundContent {
                        strongSelf.backgroundNode.isHidden = true
                        backgroundContent.frame = strongSelf.backgroundNode.frame
                        if let (rect, containerSize) = strongSelf.absolutePosition {
                            strongSelf.updateAbsoluteRect(rect, within: containerSize)
                        }
                    } else {
                        strongSelf.backgroundNode.isHidden = false
                    }
                }
            })
        }
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        super.updateAbsoluteRect(rect, within: containerSize)
        
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += containerSize.height - rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return [item.header]
        } else {
            return nil
        }
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
