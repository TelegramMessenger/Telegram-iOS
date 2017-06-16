import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let titleFont = Font.medium(14.0)
private let textFont = Font.regular(14.0)

class ChatMessageMapBubbleContentNode: ChatMessageBubbleContentNode {
    override var properties: ChatMessageBubbleContentProperties {
        return ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 5.0)
    }
    
    private let imageNode: TransformImageNode
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var item: ChatMessageItem?
    private var media: TelegramMediaMap?
    
    required init() {
        self.imageNode = TransformImageNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.titleNode = TextNode()
        self.textNode = TextNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.imageTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ position: ChatMessageBubbleContentPosition, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let previousMedia = self.media
        
        return { item, layoutConstants, position, constrainedSize in
            var selectedMedia: TelegramMediaMap?
            for media in item.message.media {
                if let telegramImage = media as? TelegramMediaMap {
                    selectedMedia = telegramImage
                }
            }
            
            let imageCorners: ImageCorners
            
            var titleString: NSAttributedString?
            var textString: NSAttributedString?
            
            let imageSize: CGSize
            if let venue = selectedMedia?.venue {
                imageCorners = ImageCorners(radius: 14.0)
                imageSize = CGSize(width: 75.0, height: 75.0)
                titleString = NSAttributedString(string: venue.title, font: titleFont, textColor: item.message.effectivelyIncoming ? item.theme.chat.bubble.incomingPrimaryTextColor : item.theme.chat.bubble.outgoingPrimaryTextColor)
                if let address = venue.address, !address.isEmpty {
                    textString = NSAttributedString(string: address, font: textFont, textColor: item.message.effectivelyIncoming ? item.theme.chat.bubble.incomingAccentColor : item.theme.chat.bubble.outgoingAccentColor)
                }
            } else {
                imageCorners = chatMessageBubbleImageContentCorners(relativeContentPosition: position, normalRadius: layoutConstants.image.defaultCornerRadius, mergedRadius: layoutConstants.image.mergedCornerRadius, mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius)
                imageSize = CGSize(width: 160.0, height: 100.0)
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let selectedMedia = selectedMedia, previousMedia == nil || !previousMedia!.isEqual(selectedMedia) {
                updateImageSignal = chatMapSnapshotImage(account: item.account, resource: MapSnapshotMediaResource(latitude: selectedMedia.latitude, longitude: selectedMedia.longitude, width: 160, height: 100))
            }
            
            let maximumWidth: CGFloat
            if let _ = titleString {
                maximumWidth = CGFloat.greatestFiniteMagnitude
            } else {
                maximumWidth = imageSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right
            }
            
            return (maximumWidth, { constrainedSize in
                let (titleLayout, titleApply) = makeTitleLayout(titleString, nil, 1, .end, CGSize(width: max(1.0, constrainedSize.width - imageSize.width - layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right - layoutConstants.text.bubbleInsets.right), height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
                let (textLayout, textApply) = makeTextLayout(textString, nil, 2, .end, CGSize(width: max(1.0, constrainedSize.width - imageSize.width - layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right - layoutConstants.text.bubbleInsets.right), height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
                
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
                    if let _ = titleString {
                        if item.message.effectivelyIncoming {
                            statusType = .BubbleIncoming
                        } else {
                            if item.message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if item.message.flags.isSending {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: item.read))
                            }
                        }
                    } else {
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
                    }
                } else {
                    statusType = nil
                }
                
                var statusSize = CGSize()
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = statusType {
                    let (size, apply) = statusLayout(item.theme, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: constrainedSize.width, height: CGFloat.greatestFiniteMagnitude))
                    statusSize = size
                    statusApply = apply
                }
              
                let contentWidth: CGFloat
                if let _ = titleString {
                    contentWidth = imageSize.width + max(statusSize.width, max(titleLayout.size.width, textLayout.size.width)) +  layoutConstants.text.bubbleInsets.right + 8.0
                    
                } else {
                    contentWidth = imageSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right
                }
                
                return (contentWidth, { boundingWidth in
                    let arguments = TransformImageArguments(corners: imageCorners, imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                    
                    let imageLayoutSize = CGSize(width: imageSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, height: imageSize.height + layoutConstants.image.bubbleInsets.top + layoutConstants.image.bubbleInsets.bottom)
                    
                    let layoutSize: CGSize
                    let statusFrame: CGRect
                    
                    let baseImageFrame = CGRect(origin: CGPoint(x: -arguments.insets.left, y: -arguments.insets.top), size: arguments.drawingSize)
                    
                    let imageFrame: CGRect
                    
                    if let _ = titleString {
                        layoutSize = CGSize(width: contentWidth, height: imageLayoutSize.height + 10.0)
                        statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width - layoutConstants.text.bubbleInsets.right, y: layoutSize.height - statusSize.height - 5.0 - 4.0), size: statusSize)
                        imageFrame = baseImageFrame.offsetBy(dx: 5.0, dy: 5.0)
                    } else {
                        layoutSize = CGSize(width: max(imageLayoutSize.width, statusSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right + layoutConstants.image.statusInsets.left + layoutConstants.image.statusInsets.right), height: imageLayoutSize.height)
                        statusFrame = CGRect(origin: CGPoint(x: layoutSize.width - layoutConstants.image.bubbleInsets.right - layoutConstants.image.statusInsets.right - statusSize.width, y: layoutSize.height -  layoutConstants.image.bubbleInsets.bottom - layoutConstants.image.statusInsets.bottom - statusSize.height), size: statusSize)
                        imageFrame = baseImageFrame.offsetBy(dx: layoutConstants.image.bubbleInsets.left, dy: layoutConstants.image.bubbleInsets.top)
                    }
                    
                    let imageApply = makeImageLayout(arguments)
                    
                    return (layoutSize, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.media = selectedMedia
                            
                            strongSelf.imageNode.frame = imageFrame
                            
                            let _ = titleApply()
                            let _ = textApply()
                            
                            strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: imageFrame.maxX + 7.0, y: imageFrame.minY + 1.0), size: titleLayout.size)
                            strongSelf.textNode.frame = CGRect(origin: CGPoint(x: imageFrame.maxX + 7.0, y: imageFrame.minY + 19.0), size: textLayout.size)
                            
                            if let statusApply = statusApply {
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                    strongSelf.imageNode.addSubnode(strongSelf.dateAndStatusNode)
                                }
                                var hasAnimation = true
                                if case .None = animation {
                                    hasAnimation = false
                                }
                                statusApply(hasAnimation)
                                strongSelf.dateAndStatusNode.frame = statusFrame
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
                            }
                            
                            if let _ = titleString {
                                if strongSelf.titleNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.titleNode)
                                }
                                if strongSelf.textNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.textNode)
                                }
                            } else {
                                if strongSelf.titleNode.supernode != nil {
                                    strongSelf.titleNode.removeFromSupernode()
                                }
                                if strongSelf.textNode.supernode != nil {
                                    strongSelf.textNode.removeFromSupernode()
                                }
                            }
                            
                            if let updateImageSignal = updateImageSignal {
                                strongSelf.imageNode.setSignal(account: item.account, signal: updateImageSignal)
                            }
                            
                            imageApply()
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func transitionNode(media: Media) -> ASDisplayNode? {
        if let currentMedia = self.media, currentMedia.isEqual(media) {
            return self.imageNode
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
        
        self.imageNode.isHidden = mediaHidden
    }
    
    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        return .none
    }
    
    @objc func imageTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
                self.controllerInteraction?.openMessage(item.message.id)
            }
        }
    }
}
