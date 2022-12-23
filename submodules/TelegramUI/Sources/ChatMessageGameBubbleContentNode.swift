import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class ChatMessageGameBubbleContentNode: ChatMessageBubbleContentNode {
    private var game: TelegramMediaGame?
    
    private let contentNode: ChatMessageAttachedContentNode
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.contentNode.visibility = visibility
        }
    }
    
    required init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.contentNode.openMedia = { [weak self] _ in
            if let strongSelf = self, let item = strongSelf.item {
                item.controllerInteraction.requestMessageActionCallback(item.message.id, nil, true, false)
            }
        }
    }
    
    override func accessibilityActivate() -> Bool {
        if let item = self.item {
            item.controllerInteraction.requestMessageActionCallback(item.message.id, nil, true, false)
        }
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, _, constrainedSize, _ in
            var game: TelegramMediaGame?
            var messageEntities: [MessageTextEntity]?
            
            for media in item.message.media {
                if let media = media as? TelegramMediaGame {
                    game = media
                    break
                }
            }
            
            for attribute in item.message.attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    messageEntities = attribute.entities
                    break
                }
            }
            
            var title: String?
            var text: String?
            var mediaAndFlags: (Media, ChatMessageAttachedContentNodeMediaFlags)?
            
            if let game = game {
                title = game.title
                text = game.description
                
                if let file = game.file {
                    mediaAndFlags = (file, [.preferMediaBeforeText])
                } else if let image = game.image {
                    mediaAndFlags = (image, [.preferMediaBeforeText])
                }
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, item.controllerInteraction.automaticMediaDownloadSettings, item.associatedData, item.attributes, item.context, item.controllerInteraction, item.message, item.read, .peer(id: item.message.id.peerId), title, nil, item.message.text.isEmpty ? text : item.message.text, item.message.text.isEmpty ? nil : messageEntities, mediaAndFlags, nil, nil, nil, true, layoutConstants, preparePosition, constrainedSize, item.controllerInteraction.presentationContext.animationCache, item.controllerInteraction.presentationContext.animationRenderer)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation, synchronousLoads, applyInfo in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.game = game
                            
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
            /*if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
                if content.instantPage != nil {
                    return .instantPage
                }
            }*/
        }
        return .none
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
    
    override func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.contentNode.statusNode.isHidden {
            return self.contentNode.statusNode.reactionView(value: value)
        }
        return nil
    }
}
