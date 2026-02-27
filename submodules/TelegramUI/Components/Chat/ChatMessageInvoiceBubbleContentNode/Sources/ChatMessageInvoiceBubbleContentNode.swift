import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import TelegramStringFormatting
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageAttachedContentNode

private let titleFont: UIFont = Font.semibold(15.0)
private let textFont: UIFont = Font.regular(15.0)

public final class ChatMessageInvoiceBubbleContentNode: ChatMessageBubbleContentNode {
    private var invoice: TelegramMediaInvoice?
    
    private let contentNode: ChatMessageAttachedContentNode
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            self.contentNode.visibility = self.visibility
        }
    }
    
    required public init() {
        self.contentNode = ChatMessageAttachedContentNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let contentNodeLayout = self.contentNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, _, constrainedSize, _ in
            var invoice: TelegramMediaInvoice?
            for media in item.message.media {
                if let media = media as? TelegramMediaInvoice {
                    invoice = media
                    break
                }
            }
            
            var title: String?
            var subtitle: NSAttributedString? = nil
            var text: String?
            var mediaAndFlags: ([Media], ChatMessageAttachedContentNodeMediaFlags)?
            
            var automaticDownloadSettings = item.controllerInteraction.automaticMediaDownloadSettings
            if let invoice = invoice {
                title = invoice.title
                text = invoice.description
                
                if let image = invoice.photo {
                    automaticDownloadSettings = MediaAutoDownloadSettings.defaultSettings
                    mediaAndFlags = ([image], [.preferMediaBeforeText])
                } else if invoice.currency != "XTR" {
                    let invoiceLabel = item.presentationData.strings.Message_InvoiceLabel
                    var invoiceText = "\(formatCurrencyAmount(invoice.totalAmount, currency: invoice.currency)) "
                    invoiceText += invoiceLabel
                    if invoice.flags.contains(.isTest) {
                        invoiceText += " (Test)"
                    }
                    
                    let string = NSMutableAttributedString(string: invoiceText, attributes: [.font: textFont])
                    string.addAttribute(.font, value: titleFont, range: NSMakeRange(0, invoiceLabel.count))
                    subtitle = string
                }
            }
            
            let (initialWidth, continueLayout) = contentNodeLayout(item.presentationData, automaticDownloadSettings, item.associatedData, item.attributes, item.context, item.controllerInteraction, item.message, item.read, item.chatLocation, title, nil, subtitle, text, nil, mediaAndFlags, nil, nil, nil, false, layoutConstants, preparePosition, constrainedSize, item.controllerInteraction.presentationContext.animationCache, item.controllerInteraction.presentationContext.animationRenderer)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth, { constrainedSize, position in
                let (refinedWidth, finalizeLayout) = continueLayout(constrainedSize, position)
                
                return (refinedWidth, { boundingWidth in
                    let (size, apply) = finalizeLayout(boundingWidth)
                    
                    return (size, { [weak self] animation, synchronousLoads, applyInfo in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.invoice = invoice
                            
                            apply(animation, synchronousLoads, applyInfo)
                            
                            strongSelf.contentNode.frame = CGRect(origin: CGPoint(), size: size)
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
            /*if let webPage = self.webPage, case let .Loaded(content) = webPage.content {
             if content.instantPage != nil {
             return .instantPage
             }
             }*/
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    override public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return self.contentNode.updateHiddenMedia(media)
    }
    
    override public func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id != messageId {
            return nil
        }
        return self.contentNode.transitionNode(media: media)
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if let statusNode = self.contentNode.statusNode, !statusNode.isHidden {
            return statusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if let statusNode = self.contentNode.statusNode, !statusNode.isHidden {
            return statusNode.messageEffectTargetView()
        }
        return nil
    }
}
