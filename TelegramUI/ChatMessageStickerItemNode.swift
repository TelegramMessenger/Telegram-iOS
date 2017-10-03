import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatMessageStickerItemNode: ChatMessageItemView {
    let imageNode: TransformImageNode
    var progressNode: RadialProgressNode?
    var tapRecognizer: UITapGestureRecognizer?
    
    private var selectionNode: ChatMessageSelectionNode?
    
    var telegramFile: TelegramMediaFile?
    
    private let fetchDisposable = MetaDisposable()
    
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundNode: ASImageNode?
    
    private var highlightedState: Bool = false
    
    required init() {
        self.imageNode = TransformImageNode()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        super.init(layerBacked: false)
        
        self.imageNode.displaysAsynchronously = false
        self.addSubnode(self.imageNode)
        self.addSubnode(self.dateAndStatusNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    override func setupItem(_ item: ChatMessageItem) {
        super.setupItem(item)
        
        for media in item.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if self.telegramFile != telegramFile {
                    self.telegramFile = telegramFile
                    
                    let signal = chatMessageSticker(account: item.account, file: telegramFile, small: false)
                    self.imageNode.setSignal(account: item.account, signal: signal)
                    self.fetchDisposable.set(freeMediaFileInteractiveFetched(account: item.account, file: telegramFile).start())
                }
                
                break
            }
        }
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let displaySize = CGSize(width: 200.0, height: 200.0)
        let telegramFile = self.telegramFile
        let layoutConstants = self.layoutConstants
        let imageLayout = self.imageNode.asyncLayout()
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        
        return { item, width, mergedTop, mergedBottom, dateHeaderAtBottom in
            let incoming = item.message.effectivelyIncoming
            var imageSize: CGSize = CGSize(width: 100.0, height: 100.0)
            if let telegramFile = telegramFile {
                if let dimensions = telegramFile.dimensions {
                    imageSize = dimensions.aspectFitted(displaySize)
                } else if let thumbnailSize = telegramFile.previewRepresentations.first?.dimensions {
                    imageSize = thumbnailSize.aspectFitted(displaySize)
                }
            }
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            if item.peerId.isGroupOrChannel && item.message.author != nil {
                var isBroadcastChannel = false
                if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                    isBroadcastChannel = true
                }
                
                if !isBroadcastChannel {
                    hasAvatar = true
                }
            }
            
            if hasAvatar {
                avatarInset = layoutConstants.avatarDiameter
            } else {
                avatarInset = 0.0
            }
            
            var layoutInsets = UIEdgeInsets(top: mergedTop ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            let displayLeftInset = layoutConstants.bubble.edgeInset + avatarInset
            
            let imageFrame = CGRect(origin: CGPoint(x: (incoming ? (layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (width - imageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left)), y: 0.0), size: imageSize)
            
            let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageFrame.size, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets())
            
            let imageApply = imageLayout(arguments)
            
            let statusType: ChatMessageDateAndStatusType
            if item.message.effectivelyIncoming {
                statusType = .FreeIncoming
            } else {
                if item.message.flags.contains(.Failed) {
                    statusType = .FreeOutgoing(.Failed)
                } else if item.message.flags.isSending {
                    statusType = .FreeOutgoing(.Sending)
                } else {
                    statusType = .FreeOutgoing(.Sent(read: item.read))
                }
            }
            
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
            
            let (dateAndStatusSize, dateAndStatusApply) = makeDateAndStatusLayout(item.theme, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
            
            var replyInfoApply: (CGSize, () -> ChatMessageReplyInfoNode)?
            var updatedReplyBackgroundNode: ASImageNode?
            var replyBackgroundImage: UIImage?
            for attribute in item.message.attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[replyAttribute.messageId] {
                    let availableWidth = max(60.0, width - imageSize.width - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
                    replyInfoApply = makeReplyInfoLayout(item.theme, item.account, .standalone, replyMessage, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                    
                    if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                        updatedReplyBackgroundNode = currentReplyBackgroundNode
                    } else {
                        updatedReplyBackgroundNode = ASImageNode()
                    }
                    replyBackgroundImage = PresentationResourcesChat.chatFreeformContentAdditionalInfoBackgroundImage(item.theme)
                    break
                }
            }
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: imageSize.height), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.imageNode.frame = imageFrame
                    strongSelf.progressNode?.position = strongSelf.imageNode.position
                    imageApply()
                    
                    dateAndStatusApply(false)
                    strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: max(displayLeftInset, imageFrame.maxX - dateAndStatusSize.width - 4.0), y: imageFrame.maxY - dateAndStatusSize.height), size: dateAndStatusSize)
                    
                    if let updatedReplyBackgroundNode = updatedReplyBackgroundNode {
                        if strongSelf.replyBackgroundNode == nil {
                            strongSelf.replyBackgroundNode = updatedReplyBackgroundNode
                            strongSelf.addSubnode(updatedReplyBackgroundNode)
                            updatedReplyBackgroundNode.image = replyBackgroundImage
                        }
                    } else if let replyBackgroundNode = strongSelf.replyBackgroundNode {
                        replyBackgroundNode.removeFromSupernode()
                        strongSelf.replyBackgroundNode = nil
                    }
                    
                    if let (replyInfoSize, replyInfoApply) = replyInfoApply {
                        let replyInfoNode = replyInfoApply()
                        if strongSelf.replyInfoNode == nil {
                            strongSelf.replyInfoNode = replyInfoNode
                            strongSelf.addSubnode(replyInfoNode)
                        }
                        let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (layoutConstants.bubble.edgeInset + 10.0) : (width - replyInfoSize.width - layoutConstants.bubble.edgeInset - 10.0)), y: imageSize.height - replyInfoSize.height - 8.0), size: replyInfoSize)
                        replyInfoNode.frame = replyInfoFrame
                        strongSelf.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: replyInfoFrame.minX - 4.0, y: replyInfoFrame.minY - 2.0), size: CGSize(width: replyInfoFrame.size.width + 8.0, height: replyInfoFrame.size.height + 5.0))
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                                if let item = self.item, let author = item.message.author {
                                    self.controllerInteraction?.openPeer(author.id, .info, item.message.id)
                                }
                                return
                            }
                            /*if let nameNode = self.nameNode, nameNode.frame.contains(location) {
                                if let item = self.item {
                                    for attribute in item.message.attributes {
                                        if let attribute = attribute as? InlineBotMessageAttribute, let botPeer = item.message.peers[attribute.peerId], let addressName = botPeer.addressName {
                                            self.controllerInteraction?.updateInputState { textInputState in
                                                return ChatTextInputState(inputText: "@" + addressName + " ")
                                            }
                                            return
                                        }
                                    }
                                }
                            } else */
                            
                            if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                                if let item = self.item {
                                    for attribute in item.message.attributes {
                                        if let attribute = attribute as? ReplyMessageAttribute {
                                            self.controllerInteraction?.navigateToMessage(item.message.id, attribute.messageId)
                                            return
                                        }
                                    }
                                }
                            }
                            
                            /*if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                                if let item = self.item, let forwardInfo = item.message.forwardInfo {
                                    if let sourceMessageId = forwardInfo.sourceMessageId {
                                        self.controllerInteraction?.navigateToMessage(item.message.id, sourceMessageId)
                                    } else {
                                        self.controllerInteraction?.openPeer(forwardInfo.source?.id ?? forwardInfo.author.id, .chat(textInputState: nil))
                                    }
                                    return
                                }
                            }*/
                        
                            if let item = self.item, self.imageNode.frame.contains(location) {
                                self.controllerInteraction?.openMessage(item.message.id)
                                return
                            }
                        
                            self.controllerInteraction?.clickThroughMessage()
                        case .longTap, .doubleTap:
                            if let item = self.item, self.imageNode.frame.contains(location) {
                                self.controllerInteraction?.openMessageContextMenu(item.message.id, self, self.imageNode.frame)
                            }
                        case .hold:
                            break
                    }
                }
            default:
                break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return super.hitTest(point, with: event)
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let controllerInteraction = self.controllerInteraction else {
            return
        }
        
        if let selectionState = controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            if let item = self.item {
                selected = selectionState.selectedIds.contains(item.message.id)
                incoming = item.message.effectivelyIncoming
            }
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: false)
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(toggle: { [weak self] in
                    if let strongSelf = self, let item = strongSelf.item {
                        strongSelf.controllerInteraction?.toggleMessageSelection(item.message.id)
                    }
                })
                
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.addSubnode(selectionNode)
                self.selectionNode = selectionNode
                selectionNode.updateSelected(selected, animated: false)
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
                if animated {
                    selectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4)
                    
                    if !incoming {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: CGPoint(x: position.x - 42.0, y: position.y), to: position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
            }
        } else {
            if let selectionNode = self.selectionNode {
                self.selectionNode = nil
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DIdentity
                if animated {
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4, completion: { [weak selectionNode]_ in
                        selectionNode?.removeFromSupernode()
                    })
                    selectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                    if CGFloat(0.0).isLessThanOrEqualTo(selectionNode.frame.origin.x) {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: position, to: CGPoint(x: position.x - 42.0, y: position.y), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    }
                } else {
                    selectionNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func updateHighlightedState(animated: Bool) {
        if let controllerInteraction = self.controllerInteraction, let item = self.item {
            var highlighted = false
            if let highlightedState = controllerInteraction.highlightedState {
                if highlightedState.messageStableId == item.message.stableId {
                    highlighted = true
                }
            }
            
            if self.highlightedState != highlighted {
                self.highlightedState = highlighted
                
                if highlighted {
                    self.imageNode.setOverlayColor(UIColor(white: 0.0, alpha: 0.2), animated: false)
                } else {
                    self.imageNode.setOverlayColor(nil, animated: animated)
                }
            }
        }
    }
}
