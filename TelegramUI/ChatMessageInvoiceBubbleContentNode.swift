import Foundation
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class ChatMessageInvoiceBubbleContentNode: ChatMessageBubbleContentNode {
    private var invoice: TelegramMediaInvoice?
    
    private let contentNode: ChatMessageAttachedContentNode
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.contentNode.visibility = self.visibility
        }
    }
    
    required init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, _, _, constrainedSize in
            var invoice: TelegramMediaInvoice?
            for media in item.message.media {
                if let media = media as? TelegramMediaInvoice {
                    invoice = media
                    break
                }
            }
            
            var title: String?
            let subtitle: String? = nil
            var text: String?
            var mediaAndFlags: (Media, ChatMessageAttachedContentNodeMediaFlags)?
            
            if let invoice = invoice {
                title = invoice.title
                text = invoice.description
                
                if let image = invoice.photo {
                    mediaAndFlags = (image, [.preferMediaBeforeText])
                }
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, item.controllerInteraction.automaticMediaDownloadSettings, item.account, item.message, item.read, title, subtitle, text, nil, mediaAndFlags, nil, nil, false, layoutConstants, constrainedSize)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackgroundForEmptyWallpapers: false, forceFullCorners: false)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.invoice = invoice
                            
                            apply(animation)
                            
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
    
    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        if self.bounds.contains(point) {
            /*if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
             if content.instantPage != nil {
             return .instantPage
             }
             }*/
        }
        return .none
    }
    
    override func updateHiddenMedia(_ media: [Media]?) {
        self.contentNode.updateHiddenMedia(media)
    }
    
    override func transitionNode(messageId: MessageId, media: Media) -> ASDisplayNode? {
        if self.item?.message.id != messageId {
            return nil
        }
        return self.contentNode.transitionNode(media: media)
    }
}
