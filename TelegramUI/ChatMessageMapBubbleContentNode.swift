import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let titleFont = Font.medium(14.0)
private let liveTitleFont = Font.medium(16.0)
private let textFont = Font.regular(14.0)

class ChatMessageMapBubbleContentNode: ChatMessageBubbleContentNode {
    private let imageNode: TransformImageNode
    private let pinNode: ChatMessageLiveLocationPositionNode
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private var liveTimerNode: ChatMessageLiveLocationTimerNode?
    private var liveTextNode: ChatMessageLiveLocationTextNode?
    
    private var media: TelegramMediaMap?
    
    required init() {
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.pinNode = ChatMessageLiveLocationPositionNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.titleNode = TextNode()
        self.textNode = TextNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.pinNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.imageTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let makePinLayout = self.pinNode.asyncLayout()
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let previousMedia = self.media
        
        return { item, layoutConstants, preparePosition, _, constrainedSize in
            var selectedMedia: TelegramMediaMap?
            var activeLiveBroadcastingTimeout: Int32?
            for media in item.message.media {
                if let telegramMap = media as? TelegramMediaMap {
                    selectedMedia = telegramMap
                    if let liveBroadcastingTimeout = telegramMap.liveBroadcastingTimeout {
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        if item.message.timestamp + liveBroadcastingTimeout > timestamp {
                            activeLiveBroadcastingTimeout = liveBroadcastingTimeout
                        }
                    }
                }
            }
            
            let bubbleInsets: UIEdgeInsets
            if case .color = item.presentationData.wallpaper {
                bubbleInsets = UIEdgeInsets()
            } else {
                bubbleInsets = layoutConstants.image.bubbleInsets
            }
            
            var titleString: NSAttributedString?
            var textString: NSAttributedString?
            
            let imageSize: CGSize
            if let selectedMedia = selectedMedia {
                if activeLiveBroadcastingTimeout != nil {
                    let fitWidth: CGFloat = min(constrainedSize.width, layoutConstants.image.maxDimensions.width)
                    
                    imageSize = CGSize(width: fitWidth, height: floor(fitWidth * 0.5))
                    
                    textString = NSAttributedString(string: " ", font: textFont, textColor: item.message.effectivelyIncoming(item.account.peerId) ? item.presentationData.theme.chat.bubble.incomingSecondaryTextColor : item.presentationData.theme.chat.bubble.outgoingSecondaryTextColor)
                } else if let venue = selectedMedia.venue {
                    imageSize = CGSize(width: 75.0, height: 75.0)
                    titleString = NSAttributedString(string: venue.title, font: titleFont, textColor: item.message.effectivelyIncoming(item.account.peerId) ? item.presentationData.theme.chat.bubble.incomingPrimaryTextColor : item.presentationData.theme.chat.bubble.outgoingPrimaryTextColor)
                    if let address = venue.address, !address.isEmpty {
                        textString = NSAttributedString(string: address, font: textFont, textColor: item.message.effectivelyIncoming(item.account.peerId) ? item.presentationData.theme.chat.bubble.incomingSecondaryTextColor : item.presentationData.theme.chat.bubble.outgoingSecondaryTextColor)
                    }
                } else {
                    let fitWidth: CGFloat = min(constrainedSize.width, layoutConstants.image.maxDimensions.width)
                    
                    imageSize = CGSize(width: fitWidth, height: floor(fitWidth * 0.5))
                }
                
                if selectedMedia.liveBroadcastingTimeout != nil {
                    titleString = NSAttributedString(string: item.presentationData.strings.Message_LiveLocation, font: liveTitleFont, textColor: item.message.effectivelyIncoming(item.account.peerId) ? item.presentationData.theme.chat.bubble.incomingPrimaryTextColor : item.presentationData.theme.chat.bubble.outgoingPrimaryTextColor)
                }
            } else {
                imageSize = CGSize(width: 75.0, height: 75.0)
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if let selectedMedia = selectedMedia, previousMedia == nil || !previousMedia!.isEqual(selectedMedia) {
                var updated = true
                if let previousMedia = previousMedia {
                    if previousMedia.latitude.isEqual(to: selectedMedia.latitude) && previousMedia.longitude.isEqual(to: selectedMedia.longitude) {
                        updated = false
                    }
                }
                if updated {
                    updateImageSignal = chatMapSnapshotImage(account: item.account, resource: MapSnapshotMediaResource(latitude: selectedMedia.latitude, longitude: selectedMedia.longitude, width: Int32(imageSize.width), height: Int32(imageSize.height)))
                }
            }
            
            let maximumWidth: CGFloat
            if activeLiveBroadcastingTimeout != nil {
                maximumWidth = imageSize.width + bubbleInsets.left + bubbleInsets.right
            } else if selectedMedia?.venue != nil {
                maximumWidth = CGFloat.greatestFiniteMagnitude
            } else {
                maximumWidth = imageSize.width + bubbleInsets.left + bubbleInsets.right
            }
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 5.0, hidesBackgroundForEmptyWallpapers: activeLiveBroadcastingTimeout == nil && selectedMedia?.venue == nil, forceFullCorners: false)
            
            var pinPeer: Peer?
            var pinLiveLocationActive: Bool?
            if let selectedMedia = selectedMedia {
                if selectedMedia.liveBroadcastingTimeout != nil {
                    pinPeer = item.message.author
                    pinLiveLocationActive = activeLiveBroadcastingTimeout != nil
                }
            }
            let (pinSize, pinApply) = makePinLayout(item.account, item.presentationData.theme, pinPeer, pinLiveLocationActive)
            
            return (contentProperties, nil, maximumWidth, { constrainedSize, position in
                let imageCorners: ImageCorners
                let maxTextWidth: CGFloat
                
                if activeLiveBroadcastingTimeout != nil {
                    imageCorners = chatMessageBubbleImageContentCorners(relativeContentPosition: position, normalRadius: layoutConstants.image.defaultCornerRadius, mergedRadius: layoutConstants.image.mergedCornerRadius, mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius)
                    
                    maxTextWidth = constrainedSize.width - bubbleInsets.left + bubbleInsets.right - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right - 40.0
                } else {
                    maxTextWidth = constrainedSize.width - imageSize.width - bubbleInsets.left + bubbleInsets.right - layoutConstants.text.bubbleInsets.right
                    
                    if let _ = selectedMedia?.venue {
                        imageCorners = ImageCorners(radius: 14.0)
                    } else {
                        imageCorners = chatMessageBubbleImageContentCorners(relativeContentPosition: position, normalRadius: layoutConstants.image.defaultCornerRadius, mergedRadius: layoutConstants.image.mergedCornerRadius, mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius)
                    }
                }
                
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, maxTextWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: max(1.0, maxTextWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
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
                
                if let selectedMedia = selectedMedia {
                    if selectedMedia.liveBroadcastingTimeout != nil {
                        edited = false
                    }
                }
                
                var dateText = stringForMessageTimestamp(timestamp: item.message.timestamp, timeFormat: item.presentationData.timeFormat)
                
                if let author = item.message.author as? TelegramUser {
                    if author.botInfo != nil {
                        sentViaBot = true
                    }
                    if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                        dateText = "\(author.displayTitle), \(dateText)"
                    }
                }
                
                let statusType: ChatMessageDateAndStatusType?
                switch position {
                    case .linear(_, .None):
                        if selectedMedia?.venue != nil || activeLiveBroadcastingTimeout != nil {
                            if item.message.effectivelyIncoming(item.account.peerId) {
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
                            if item.message.effectivelyIncoming(item.account.peerId) {
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
                    default:
                        statusType = nil
                }
                
                var statusSize = CGSize()
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = statusType {
                    let (size, apply) = statusLayout(item.presentationData.theme, item.presentationData.strings, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: constrainedSize.width, height: CGFloat.greatestFiniteMagnitude))
                    statusSize = size
                    statusApply = apply
                }
              
                let contentWidth: CGFloat
                if let selectedMedia = selectedMedia, selectedMedia.liveBroadcastingTimeout != nil {
                    contentWidth = imageSize.width + bubbleInsets.left + bubbleInsets.right
                } else if selectedMedia?.venue != nil {
                    contentWidth = imageSize.width + max(statusSize.width, max(titleLayout.size.width, textLayout.size.width)) +  layoutConstants.text.bubbleInsets.right + 8.0
                    
                } else {
                    contentWidth = imageSize.width + bubbleInsets.left + bubbleInsets.right
                }
                
                return (contentWidth, { boundingWidth in
                    let arguments = TransformImageArguments(corners: imageCorners, imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                    
                    let imageLayoutSize = CGSize(width: imageSize.width + bubbleInsets.left + bubbleInsets.right, height: imageSize.height + bubbleInsets.top + bubbleInsets.bottom)
                    
                    let layoutSize: CGSize
                    let statusFrame: CGRect
                    
                    let baseImageFrame = CGRect(origin: CGPoint(x: -arguments.insets.left, y: -arguments.insets.top), size: arguments.drawingSize)
                    
                    let imageFrame: CGRect
                    
                    if activeLiveBroadcastingTimeout != nil {
                        layoutSize = CGSize(width: imageLayoutSize.width + bubbleInsets.left, height: imageLayoutSize.height + 1.0 + titleLayout.size.height + 1.0 + textLayout.size.height + 10.0)

                        imageFrame = baseImageFrame.offsetBy(dx: bubbleInsets.left, dy: bubbleInsets.top)
                        
                        statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width - layoutConstants.text.bubbleInsets.right, y: layoutSize.height - statusSize.height - 5.0 - 4.0), size: statusSize)
                    } else {
                        if selectedMedia?.venue != nil {
                            layoutSize = CGSize(width: contentWidth, height: imageLayoutSize.height + 10.0)
                            statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width - layoutConstants.text.bubbleInsets.right, y: layoutSize.height - statusSize.height - 5.0 - 4.0), size: statusSize)
                            imageFrame = baseImageFrame.offsetBy(dx: 5.0, dy: 5.0)
                        } else {
                            layoutSize = CGSize(width: max(imageLayoutSize.width, statusSize.width + bubbleInsets.left + bubbleInsets.right + layoutConstants.image.statusInsets.left + layoutConstants.image.statusInsets.right), height: imageLayoutSize.height)
                            statusFrame = CGRect(origin: CGPoint(x: layoutSize.width - bubbleInsets.right - layoutConstants.image.statusInsets.right - statusSize.width, y: layoutSize.height -  bubbleInsets.bottom - layoutConstants.image.statusInsets.bottom - statusSize.height), size: statusSize)
                            imageFrame = baseImageFrame.offsetBy(dx: bubbleInsets.left, dy: bubbleInsets.top)
                        }
                    }
                    
                    let imageApply = makeImageLayout(arguments)
                    
                    return (layoutSize, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.media = selectedMedia
                            
                            strongSelf.imageNode.frame = imageFrame
                            
                            var transition: ContainedViewLayoutTransition = .immediate
                            if case let .System(duration) = animation {
                                transition = .animated(duration: duration, curve: .spring)
                            }
                            
                            let _ = titleApply()
                            let _ = textApply()
                            
                            transition.updateAlpha(node: strongSelf.dateAndStatusNode, alpha: activeLiveBroadcastingTimeout != nil ? 0.0 : 1.0)
                            
                            if let selectedMedia = selectedMedia, selectedMedia.liveBroadcastingTimeout != nil {
                                strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: imageFrame.minX + 7.0, y: imageFrame.maxY + 6.0), size: titleLayout.size)
                                strongSelf.textNode.frame = CGRect(origin: CGPoint(x: imageFrame.minX + 7.0, y: imageFrame.maxY + 6.0 + titleLayout.size.height), size: textLayout.size)
                                transition.updateAlpha(node: strongSelf.titleNode, alpha: activeLiveBroadcastingTimeout != nil ? 1.0 : 0.0)
                                transition.updateAlpha(node: strongSelf.textNode, alpha: activeLiveBroadcastingTimeout != nil ? 1.0 : 0.0)
                            } else {
                                strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: imageFrame.maxX + 7.0, y: imageFrame.minY + 1.0), size: titleLayout.size)
                                strongSelf.textNode.frame = CGRect(origin: CGPoint(x: imageFrame.maxX + 7.0, y: imageFrame.minY + 19.0), size: textLayout.size)
                            }
                            
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
                                strongSelf.imageNode.setSignal(updateImageSignal)
                            }
                            
                            if let activeLiveBroadcastingTimeout = activeLiveBroadcastingTimeout {
                                if strongSelf.liveTimerNode == nil {
                                    let liveTimerNode = ChatMessageLiveLocationTimerNode()
                                    strongSelf.liveTimerNode = liveTimerNode
                                    strongSelf.addSubnode(liveTimerNode)
                                }
                                let timerSize = CGSize(width: 28.0, height: 28.0)
                                strongSelf.liveTimerNode?.frame = CGRect(origin: CGPoint(x: imageFrame.maxX - 10.0 - timerSize.width, y: imageFrame.maxY + 11.0), size: timerSize)
                                
                                let timerForegroundColor: UIColor = item.message.effectivelyIncoming(item.account.peerId) ? item.presentationData.theme.chat.bubble.incomingAccentControlColor : item.presentationData.theme.chat.bubble.outgoingAccentControlColor
                                let timerTextColor: UIColor = item.message.effectivelyIncoming(item.account.peerId) ? item.presentationData.theme.chat.bubble.incomingAccentTextColor : item.presentationData.theme.chat.bubble.outgoingAccentTextColor
                                strongSelf.liveTimerNode?.update(backgroundColor: timerForegroundColor.withAlphaComponent(0.4), foregroundColor: timerForegroundColor, textColor: timerTextColor, beginTimestamp: Double(item.message.timestamp), timeout: Double(activeLiveBroadcastingTimeout), strings: item.presentationData.strings)
                                
                                if strongSelf.liveTextNode == nil {
                                    let liveTextNode = ChatMessageLiveLocationTextNode()
                                    strongSelf.liveTextNode = liveTextNode
                                    strongSelf.addSubnode(liveTextNode)
                                }
                                strongSelf.liveTextNode?.frame = CGRect(origin: CGPoint(x: imageFrame.minX + 7.0, y: imageFrame.maxY + 6.0 + titleLayout.size.height), size: CGSize(width: imageFrame.size.width - 14.0 - 40.0, height: 18.0))
                                
                                var updateTimestamp = item.message.timestamp
                                for attribute in item.message.attributes {
                                    if let attribute = attribute as? EditedMessageAttribute {
                                        updateTimestamp = attribute.date
                                        break
                                    }
                                }
                                
                                strongSelf.liveTextNode?.update(color: timerTextColor, timestamp: Double(updateTimestamp), strings: item.presentationData.strings, timeFormat: item.presentationData.timeFormat)
                            } else {
                                if let liveTimerNode = strongSelf.liveTimerNode {
                                    strongSelf.liveTimerNode = nil
                                    transition.updateAlpha(node: liveTimerNode, alpha: 0.0, completion: { [weak liveTimerNode] _ in
                                        liveTimerNode?.removeFromSupernode()
                                    })
                                }
                                
                                if let liveTextNode = strongSelf.liveTextNode {
                                    strongSelf.liveTextNode = nil
                                    transition.updateAlpha(node: liveTextNode, alpha: 0.0, completion: { [weak liveTextNode] _ in
                                        liveTextNode?.removeFromSupernode()
                                    })
                                }
                            }
                            
                            imageApply()
                            
                            strongSelf.pinNode.frame = CGRect(origin: CGPoint(x: imageFrame.minX + floor((imageFrame.size.width - pinSize.width) / 2.0), y: imageFrame.minY + floor(imageFrame.size.height * 0.5 - 10.0 - pinSize.height / 2.0)), size: pinSize)
                            
                            pinApply()
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
    
    override func transitionNode(messageId: MessageId, media: Media) -> ASDisplayNode? {
        if self.item?.message.id == messageId, let currentMedia = self.media, currentMedia.isEqual(media) {
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
                item.controllerInteraction.openMessage(item.message.id)
            }
        }
    }
}
