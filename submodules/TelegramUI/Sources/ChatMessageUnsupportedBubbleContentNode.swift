import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

final class ChatMessageUnsupportedBubbleContentNode: ChatMessageBubbleContentNode {
    private var buttonNode: ChatMessageAttachedContentButtonNode
    
    required init() {
        self.buttonNode = ChatMessageAttachedContentButtonNode()
        
        super.init()
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.pressed = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.openAppStorePage()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let makeButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.buttonNode)
        
        return { item, layoutConstants, _, _, constrainedSize in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let message = item.message
                let incoming = message.effectivelyIncoming(item.context.account.peerId)
                let presentationData = item.presentationData
                let insets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 9.0, right: 12.0)
                
                let buttonImage: UIImage
                let buttonHighlightedImage: UIImage
                let titleColor: UIColor
                let titleHighlightedColor: UIColor
                if incoming {
                    buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonIncoming(presentationData.theme.theme)!
                    buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonIncoming(presentationData.theme.theme)!
                    titleColor = presentationData.theme.theme.chat.message.incoming.accentTextColor
                    let bubbleColor = bubbleColorComponents(theme: presentationData.theme.theme, incoming: true, wallpaper: !presentationData.theme.wallpaper.isEmpty)
                    titleHighlightedColor = bubbleColor.fill[0]
                } else {
                    buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonOutgoing(presentationData.theme.theme)!
                    buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonOutgoing(presentationData.theme.theme)!
                    titleColor = presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    let bubbleColor = bubbleColorComponents(theme: presentationData.theme.theme, incoming: false, wallpaper: !presentationData.theme.wallpaper.isEmpty)
                    titleHighlightedColor = bubbleColor.fill[0]
                }
                let (buttonWidth, continueActionButtonLayout) = makeButtonLayout(constrainedSize.width, buttonImage, buttonHighlightedImage, nil, nil, presentationData.strings.Conversation_UpdateTelegram, titleColor, titleHighlightedColor)
                
                let initialWidth = buttonWidth + insets.left + insets.right
                
                return (initialWidth, { boundingWidth in
                    var actionButtonSizeAndApply: ((CGSize, () -> ChatMessageAttachedContentButtonNode))?
                    let refinedButtonWidth = max(boundingWidth - insets.left - insets.right, buttonWidth)
                    
                    let (size, apply) = continueActionButtonLayout(refinedButtonWidth)
                    actionButtonSizeAndApply = (size, apply)
                    let adjustedBoundingSize = CGSize(width: refinedButtonWidth + insets.left + insets.right, height: insets.bottom + size.height)
                    
                    return (adjustedBoundingSize, { [weak self] animation, synchronousLoads in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            if let (size, apply) = actionButtonSizeAndApply {
                                _ = apply()
                                strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: insets.left, y: 0.0), size: size)
                            }
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
            if self.buttonNode.frame.contains(point) {
                return .ignore
            } else {
                return .none
            }
        }
        return .none
    }
}
