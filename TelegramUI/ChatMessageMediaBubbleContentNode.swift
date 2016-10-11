import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatMessageMediaBubbleContentNode: ChatMessageBubbleContentNode {
    override var properties: ChatMessageBubbleContentProperties {
        return ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 5.0)
    }
    
    private let interactiveImageNode: ChatMessageInteractiveMediaNode
    
    private var item: ChatMessageItem?
    private var media: Media?
    
    required init() {
        self.interactiveImageNode = ChatMessageInteractiveMediaNode()
        
        super.init()
        
        self.addSubnode(self.interactiveImageNode)
        
        self.interactiveImageNode.activateLocalContent = { [weak self] in
            if let strongSelf = self {
                if let item = strongSelf.item, let controllerInteraction = strongSelf.controllerInteraction {
                    controllerInteraction.openMessage(item.message.id)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let interactiveImageLayout = self.interactiveImageNode.asyncLayout()
        
        return { item, layoutConstants, position, constrainedSize in
            var selectedMedia: Media?
            for media in item.message.media {
                if let telegramImage = media as? TelegramMediaImage {
                    selectedMedia = telegramImage
                } else if let telegramFile = media as? TelegramMediaFile {
                    selectedMedia = telegramFile
                }
            }
            
            let imageCorners = chatMessageBubbleImageContentCorners(relativeContentPosition: position, normalRadius: layoutConstants.image.defaultCornerRadius, mergedRadius: layoutConstants.image.mergedCornerRadius, mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius)
            
            let (initialWidth, refineLayout) = interactiveImageLayout(item.account, selectedMedia!, imageCorners, item.account.settings.automaticDownloadSettingsForPeerId(item.peerId).downloadPhoto, CGSize(width: constrainedSize.width, height: constrainedSize.height))
            
            return (initialWidth + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, { constrainedSize in
                let (refinedWidth, finishLayout) = refineLayout(constrainedSize)
                
                return (refinedWidth + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, { boundingWidth in
                    let (imageSize, imageApply) = finishLayout(boundingWidth - layoutConstants.image.bubbleInsets.left - layoutConstants.image.bubbleInsets.right)
                    
                    return (CGSize(width: imageSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, height: imageSize.height + layoutConstants.image.bubbleInsets.top + layoutConstants.image.bubbleInsets.bottom), { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.media = selectedMedia
                            
                            strongSelf.interactiveImageNode.frame = CGRect(origin: CGPoint(x: layoutConstants.image.bubbleInsets.left, y: layoutConstants.image.bubbleInsets.top), size: imageSize)
                            
                            imageApply()
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.interactiveImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.interactiveImageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.interactiveImageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func transitionNode(media: Media) -> ASDisplayNode? {
        if let currentMedia = self.media, currentMedia.isEqual(media) {
            return self.interactiveImageNode
        }
        return nil
    }
    
    override func updateHiddenMedia(_ media: [Media]?) {
        var mediaHidden = false
        if let currentMedia = self.media, let media = media {
            for item in media {
                if item.isEqual(currentMedia) {
                    mediaHidden = true
                    break
                }
            }
        }
        
        self.interactiveImageNode.isHidden = mediaHidden
    }
}
