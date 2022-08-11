import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class ChatMessageEventLogPreviousMessageContentNode: ChatMessageBubbleContentNode {
    private let contentNode: ChatMessageAttachedContentNode
    
    required init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, _, constrainedSize in
            var messageEntities: [MessageTextEntity]?
            
            for attribute in item.message.attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    messageEntities = attribute.entities
                    break
                }
            }
            
            let title: String = item.presentationData.strings.Channel_AdminLog_MessagePreviousMessage
            let text: String
            if item.message.text.isEmpty {
                text = item.presentationData.strings.Channel_AdminLog_EmptyMessageText
            } else {
                text = item.message.text
            }
            let mediaAndFlags: (Media, ChatMessageAttachedContentNodeMediaFlags)? = nil
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, item.controllerInteraction.automaticMediaDownloadSettings, item.associatedData, item.attributes, item.context, item.controllerInteraction, item.message, true, .peer(id: item.message.id.peerId), title, nil, text, messageEntities, mediaAndFlags, nil, nil, nil, true, layoutConstants, preparePosition, constrainedSize)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation, synchronousLoads, applyInfo in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            apply(animation, synchronousLoads, applyInfo)
                            
                            strongSelf.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.bounds.contains(point) {
            let contentNodeFrame = self.contentNode.frame
            return self.contentNode.tapActionAtPoint(point.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY), gesture: gesture, isEstimating: isEstimating)
        }
        return .none
    }
    
    override func updateTouchesAtPoint(_ point: CGPoint?) {
        let contentNodeFrame = self.contentNode.frame
        self.contentNode.updateTouchesAtPoint(point.flatMap { $0.offsetBy(dx: -contentNodeFrame.minX, dy: -contentNodeFrame.minY) })
    }
    
    override func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return self.contentNode.updateHiddenMedia(media)
    }
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id != messageId {
            return nil
        }
        return self.contentNode.transitionNode(media: media)
    }
}

