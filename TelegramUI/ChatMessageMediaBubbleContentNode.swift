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
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    
    private var item: ChatMessageItem?
    private var media: Media?
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            self.interactiveImageNode.visibility = self.visibility
        }
    }
    
    required init() {
        self.interactiveImageNode = ChatMessageInteractiveMediaNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.addSubnode(self.interactiveImageNode)
        
        self.interactiveImageNode.activateLocalContent = { [weak self] in
            if let strongSelf = self {
                if let item = strongSelf.item, let controllerInteraction = strongSelf.controllerInteraction, !item.message.containsSecretMedia {
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
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        
        return { item, layoutConstants, position, constrainedSize in
            var selectedMedia: Media?
            for media in item.message.media {
                if let telegramImage = media as? TelegramMediaImage {
                    selectedMedia = telegramImage
                } else if let telegramFile = media as? TelegramMediaFile {
                    selectedMedia = telegramFile
                }
            }
            
            let initialImageCorners = chatMessageBubbleImageContentCorners(relativeContentPosition: position, normalRadius: layoutConstants.image.defaultCornerRadius, mergedRadius: layoutConstants.image.mergedCornerRadius, mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius)
            
            let (initialWidth, _, refineLayout) = interactiveImageLayout(item.account, item, selectedMedia!, initialImageCorners, item.account.settings.automaticDownloadSettingsForPeerId(item.peerId).downloadPhotos, CGSize(width: constrainedSize.width, height: constrainedSize.height), layoutConstants)
            
            return (initialWidth + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, { constrainedSize in
                let (refinedWidth, finishLayout) = refineLayout(constrainedSize)
                
                return (refinedWidth + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, { boundingWidth in
                    let (imageSize, imageApply) = finishLayout(boundingWidth - layoutConstants.image.bubbleInsets.left - layoutConstants.image.bubbleInsets.right)
                    
                    var t = Int(item.message.timestamp)
                    var timeinfo = tm()
                    localtime_r(&t, &timeinfo)
                    
                    var edited = false
                    var sentViaBot = false
                    var viewCount: Int?
                    for attribute in item.message.attributes {
                        if let _ = attribute as? EditedMessageAttribute {
                            edited = true
                        } else if let attribute = attribute as? ViewCountMessageAttribute {
                            viewCount = attribute.count
                        } else if let _ = attribute as? InlineBotMessageAttribute {
                            sentViaBot = true
                        }
                    }
                    
                    var dateText = String(format: "%02d:%02d", arguments: [Int(timeinfo.tm_hour), Int(timeinfo.tm_min)])
                    
                    if let author = item.message.author as? TelegramUser {
                        if author.botInfo != nil {
                            sentViaBot = true
                        }
                        if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            dateText = "\(author.displayTitle), \(dateText)"
                        }
                    }
                    
                    let statusType: ChatMessageDateAndStatusType?
                    if case .None = position.bottom {
                        if item.message.effectivelyIncoming {
                            statusType = .ImageIncoming
                        } else {
                            if item.message.flags.contains(.Failed) {
                                statusType = .ImageOutgoing(.Failed)
                            } else if item.message.flags.isSending {
                                statusType = .ImageOutgoing(.Sending)
                            } else {
                                statusType = .ImageOutgoing(.Sent(read: item.read))
                            }
                        }
                    } else {
                        statusType = nil
                    }
                    
                    let imageLayoutSize = CGSize(width: imageSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, height: imageSize.height + layoutConstants.image.bubbleInsets.top + layoutConstants.image.bubbleInsets.bottom)
                    
                    var statusSize = CGSize()
                    var statusApply: ((Bool) -> Void)?
                    
                    if let statusType = statusType {
                        let (size, apply) = statusLayout(item.theme, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: imageLayoutSize.width, height: CGFloat.greatestFiniteMagnitude))
                        statusSize = size
                        statusApply = apply
                    }
                    
                    let layoutSize = CGSize(width: max(imageLayoutSize.width, statusSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right + layoutConstants.image.statusInsets.left + layoutConstants.image.statusInsets.right), height: imageLayoutSize.height)
                    
                    return (layoutSize, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.media = selectedMedia
                            
                            strongSelf.interactiveImageNode.frame = CGRect(origin: CGPoint(x: layoutConstants.image.bubbleInsets.left, y: layoutConstants.image.bubbleInsets.top), size: imageSize)
                            
                            if let statusApply = statusApply {
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                    strongSelf.interactiveImageNode.addSubnode(strongSelf.dateAndStatusNode)
                                }
                                var hasAnimation = true
                                if case .None = animation {
                                    hasAnimation = false
                                }
                                statusApply(hasAnimation)
                                strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: layoutSize.width - layoutConstants.image.bubbleInsets.right - layoutConstants.image.statusInsets.right - statusSize.width, y: layoutSize.height -  layoutConstants.image.bubbleInsets.bottom - layoutConstants.image.statusInsets.bottom - statusSize.height), size: statusSize)
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
                            }
                            
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
    
    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        if self.interactiveImageNode.frame.contains(point) {
            if let item = self.item, item.message.containsSecretMedia {
                return .holdToPreviewSecretMedia
            }
        }
        return .none
    }
}
