import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageAttachedContentButtonNode

public final class ChatMessageUnsupportedBubbleContentNode: ChatMessageBubbleContentNode {
    private var buttonNode: ChatMessageAttachedContentButtonNode
    
    required public init() {
        self.buttonNode = ChatMessageAttachedContentButtonNode()
        
        super.init()
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.pressed = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.openAppStorePage()
            }
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.buttonNode)
        
        return { item, layoutConstants, _, _, constrainedSize, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                let incoming = message.effectivelyIncoming(item.context.account.peerId)
                let presentationData = item.presentationData
                let insets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 9.0, right: 12.0)
                
                let titleColor: UIColor
                if incoming {
                    titleColor = presentationData.theme.theme.chat.message.incoming.accentTextColor
                } else {
                    titleColor = presentationData.theme.theme.chat.message.outgoing.accentTextColor
                }
                let (buttonWidth, continueActionButtonLayout) = makeButtonLayout(constrainedSize.width, nil, nil, false, presentationData.strings.Conversation_UpdateTelegram, titleColor, false, true)
                
                let initialWidth = buttonWidth + insets.left + insets.right
                
                return (initialWidth, { boundingWidth in
                    var actionButtonSizeAndApply: ((CGSize, (ListViewItemUpdateAnimation) -> ChatMessageAttachedContentButtonNode))?
                    let refinedButtonWidth = max(boundingWidth - insets.left - insets.right, buttonWidth)
                    
                    let (size, apply) = continueActionButtonLayout(refinedButtonWidth, 33.0)
                    actionButtonSizeAndApply = (size, apply)
                    let adjustedBoundingSize = CGSize(width: refinedButtonWidth + insets.left + insets.right, height: insets.bottom + size.height)
                    
                    return (adjustedBoundingSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            if let (size, apply) = actionButtonSizeAndApply {
                                _ = apply(animation)
                                strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: insets.left, y: 0.0), size: size)
                            }
                        }
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override public func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.bounds.contains(point) {
            if self.buttonNode.frame.contains(point) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            } else {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}
