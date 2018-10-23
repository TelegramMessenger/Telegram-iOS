import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatMessageInstantVideoItemNode: ChatMessageItemView {
    private let interactiveVideoNode: ChatMessageInteractiveInstantVideoNode
    
    private var selectionNode: ChatMessageSelectionNode?
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var appliedItem: ChatMessageItem?
    
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var forwardBackgroundNode: ASImageNode?
    
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundNode: ASImageNode?
    
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            if self.visibility != oldValue {
                self.interactiveVideoNode.visibility = self.visibility
            }
        }
    }
    
    required init() {
        self.interactiveVideoNode = ChatMessageInteractiveInstantVideoNode()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.interactiveVideoNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
        
        let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
        replyRecognizer.shouldBegin = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if strongSelf.selectionNode != nil {
                    return false
                }
                return item.controllerInteraction.canSetupReply(item.message)
            }
            return false
        }
        self.view.addGestureRecognizer(replyRecognizer)
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let layoutConstants = self.layoutConstants
        
        let makeVideoLayout = self.interactiveVideoNode.asyncLayout()
        
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        
        let makeForwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let currentForwardBackgroundNode = self.forwardBackgroundNode
        
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        
        let currentItem = self.appliedItem
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let baseWidth = params.width - params.leftInset - params.rightInset
            let incoming = item.message.effectivelyIncoming(item.account.peerId)
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            switch item.chatLocation {
                case let .peer(peerId):
                    if peerId != item.account.peerId {
                        if peerId.isGroupOrChannel && item.message.author != nil {
                            var isBroadcastChannel = false
                            if let peer = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                                isBroadcastChannel = true
                            }
                            
                            if !isBroadcastChannel {
                                hasAvatar = true
                            }
                        }
                    } else if incoming {
                        hasAvatar = true
                    }
                case .group:
                    hasAvatar = true
            }
            
            if hasAvatar {
                avatarInset = layoutConstants.avatarDiameter
            } else {
                avatarInset = 0.0
            }
            
            var layoutInsets = layoutConstants.instantVideo.insets
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            let displaySize = CGSize(width: 212.0, height: 212.0)
            
            var automaticDownload = true
            for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    automaticDownload = shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, media: file)
                }
            }
            
            let (videoLayout, videoApply) = makeVideoLayout(ChatMessageBubbleContentItem(account: item.account, controllerInteraction: item.controllerInteraction, message: item.message, read: item.read, presentationData: item.presentationData, associatedData: item.associatedData), params.width - params.leftInset - params.rightInset - avatarInset, displaySize, .free, automaticDownload)
            
            let videoFrame = CGRect(origin: CGPoint(x: (incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (params.width - params.rightInset - videoLayout.contentSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left)), y: 0.0), size: videoLayout.contentSize)
            
            var replyInfoApply: (CGSize, () -> ChatMessageReplyInfoNode)?
            var updatedReplyBackgroundNode: ASImageNode?
            var replyBackgroundImage: UIImage?
            var replyMarkup: ReplyMarkupMessageAttribute?
            var inlineBotNameString: String?
            
            for attribute in item.message.attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[replyAttribute.messageId] {
                    let availableWidth = max(60.0, params.width - params.leftInset - params.rightInset - videoLayout.contentSize.width - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
                    replyInfoApply = makeReplyInfoLayout(item.presentationData.theme.theme, item.presentationData.strings, item.account, .standalone, replyMessage, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                    
                    if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                        updatedReplyBackgroundNode = currentReplyBackgroundNode
                    } else {
                        updatedReplyBackgroundNode = ASImageNode()
                    }
                    replyBackgroundImage = PresentationResourcesChat.chatServiceBubbleFillImage(item.presentationData.theme.theme)
                    break
                } else if let attribute = attribute as? InlineBotMessageAttribute {
                    if let peerId = attribute.peerId, let bot = item.message.peers[peerId] as? TelegramUser {
                        inlineBotNameString = bot.username
                    } else {
                        inlineBotNameString = attribute.title
                    }
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
            }
            
            let availableContentWidth = params.width - params.leftInset - params.rightInset - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left
            
            var forwardInfoSizeApply: (CGSize, () -> ChatMessageForwardInfoNode)?
            var updatedForwardBackgroundNode: ASImageNode?
            var forwardBackgroundImage: UIImage?
            if let forwardInfo = item.message.forwardInfo {
                let forwardSource: Peer
                let forwardAuthorSignature: String?
                
                if let source = forwardInfo.source {
                    forwardSource = source
                    if let authorSignature = forwardInfo.authorSignature {
                        forwardAuthorSignature = authorSignature
                    } else if forwardInfo.author.id != source.id {
                        forwardAuthorSignature = forwardInfo.author.displayTitle
                    } else {
                        forwardAuthorSignature = nil
                    }
                } else {
                    forwardSource = forwardInfo.author
                    forwardAuthorSignature = nil
                }
                let availableWidth = max(60.0, availableContentWidth - videoLayout.contentSize.width + 6.0)
                forwardInfoSizeApply = makeForwardInfoLayout(item.presentationData.theme.theme, item.presentationData.strings, .standalone, forwardSource, forwardAuthorSignature, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                
                if let currentForwardBackgroundNode = currentForwardBackgroundNode {
                    updatedForwardBackgroundNode = currentForwardBackgroundNode
                } else {
                    updatedForwardBackgroundNode = ASImageNode()
                }
                
                forwardBackgroundImage = PresentationResourcesChat.chatServiceBubbleFillImage(item.presentationData.theme.theme)
            }
            
            var maxContentWidth = videoLayout.contentSize.width
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animated: Bool) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(item.account, item.presentationData.theme.theme, item.presentationData.strings, replyMarkup, item.message, maxContentWidth)
                maxContentWidth = max(maxContentWidth, minWidth)
                actionButtonsFinalize = buttonsLayout
            }
            
            var actionButtonsSizeAndApply: (CGSize, (Bool) -> ChatMessageActionButtonsNode)?
            if let actionButtonsFinalize = actionButtonsFinalize {
                actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
            }
            
            var layoutSize = CGSize(width: params.width, height: videoLayout.contentSize.height)
            if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                layoutSize.height += actionButtonsSizeAndApply.0.height
            }
            
            return (ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.appliedItem = item
                
                    let transition: ContainedViewLayoutTransition
                    if animation.isAnimated {
                        transition = .animated(duration: 0.2, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    strongSelf.interactiveVideoNode.frame = videoFrame
                    let videoLayoutData: ChatMessageInstantVideoItemLayoutData
                    if incoming {
                        videoLayoutData = .constrained(left: 0.0, right: max(0.0, availableContentWidth - videoFrame.width))
                    } else {
                        videoLayoutData = .constrained(left: max(0.0, availableContentWidth - videoFrame.width), right: 0.0)
                    }
                    videoApply(videoLayoutData, transition)
                    
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
                        let replyInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 10.0) : (params.width - params.rightInset - replyInfoSize.width - layoutConstants.bubble.edgeInset - 10.0)), y: videoLayout.contentSize.height - replyInfoSize.height - 8.0), size: replyInfoSize)
                        replyInfoNode.frame = replyInfoFrame
                        strongSelf.replyBackgroundNode?.frame = CGRect(origin: CGPoint(x: replyInfoFrame.minX - 4.0, y: replyInfoFrame.minY - 2.0), size: CGSize(width: replyInfoFrame.size.width + 8.0, height: replyInfoFrame.size.height + 5.0))
                    } else if let replyInfoNode = strongSelf.replyInfoNode {
                        replyInfoNode.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    if let updatedForwardBackgroundNode = updatedForwardBackgroundNode {
                        if strongSelf.forwardBackgroundNode == nil {
                            strongSelf.forwardBackgroundNode = updatedForwardBackgroundNode
                            strongSelf.addSubnode(updatedForwardBackgroundNode)
                            updatedForwardBackgroundNode.image = forwardBackgroundImage
                        }
                    } else if let forwardBackgroundNode = strongSelf.forwardBackgroundNode {
                        forwardBackgroundNode.removeFromSupernode()
                        strongSelf.forwardBackgroundNode = nil
                    }
                    
                    if let (forwardInfoSize, forwardInfoApply) = forwardInfoSizeApply {
                        let forwardInfoNode = forwardInfoApply()
                        if strongSelf.forwardInfoNode == nil {
                            strongSelf.forwardInfoNode = forwardInfoNode
                            strongSelf.addSubnode(forwardInfoNode)
                        }
                        let forwardInfoFrame = CGRect(origin: CGPoint(x: (!incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + 12.0) : (params.width - params.rightInset - forwardInfoSize.width - layoutConstants.bubble.edgeInset - 12.0)), y: 8.0), size: forwardInfoSize)
                        forwardInfoNode.frame = forwardInfoFrame
                        strongSelf.forwardBackgroundNode?.frame = CGRect(origin: CGPoint(x: forwardInfoFrame.minX - 6.0, y: forwardInfoFrame.minY - 2.0), size: CGSize(width: forwardInfoFrame.size.width + 10.0, height: forwardInfoFrame.size.height + 4.0))
                    } else if let forwardInfoNode = strongSelf.forwardInfoNode {
                        forwardInfoNode.removeFromSupernode()
                        strongSelf.forwardInfoNode = nil
                    }
                    
                    if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                        var animated = false
                        if let _ = strongSelf.actionButtonsNode {
                            if case .System = animation {
                                animated = true
                            }
                        }
                        let actionButtonsNode = actionButtonsSizeAndApply.1(animated)
                        let previousFrame = actionButtonsNode.frame
                        let actionButtonsFrame = CGRect(origin: CGPoint(x: videoFrame.minX, y: videoFrame.maxY), size: actionButtonsSizeAndApply.0)
                        actionButtonsNode.frame = actionButtonsFrame
                        if actionButtonsNode !== strongSelf.actionButtonsNode {
                            strongSelf.actionButtonsNode = actionButtonsNode
                            actionButtonsNode.buttonPressed = { button in
                                if let strongSelf = self {
                                    strongSelf.performMessageButtonAction(button: button)
                                }
                            }
                            strongSelf.addSubnode(actionButtonsNode)
                        } else {
                            if case let .System(duration) = animation {
                                actionButtonsNode.layer.animateFrame(from: previousFrame, to: actionButtonsFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else if let actionButtonsNode = strongSelf.actionButtonsNode {
                        actionButtonsNode.removeFromSupernode()
                        strongSelf.actionButtonsNode = nil
                    }
                }
            })
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                    case .tap:
                        if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                            if let item = self.item, let author = item.content.firstMessage.author {
                                let navigate: ChatControllerInteractionNavigateToPeer
                                if item.content.firstMessage.id.peerId == item.account.peerId {
                                    navigate = .chat(textInputState: nil, messageId: nil)
                                } else {
                                    navigate = .info
                                }
                                item.controllerInteraction.openPeer(item.effectiveAuthorId ?? author.id, navigate, item.message)
                            }
                            return
                        }
                        
                        if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                            if let item = self.item {
                                for attribute in item.message.attributes {
                                    if let attribute = attribute as? ReplyMessageAttribute {
                                        item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId)
                                        return
                                    }
                                }
                            }
                        }
                        
                        if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                            if let item = self.item, let forwardInfo = item.message.forwardInfo {
                                if let sourceMessageId = forwardInfo.sourceMessageId {
                                    item.controllerInteraction.navigateToMessage(item.message.id, sourceMessageId)
                                } else {
                                    item.controllerInteraction.openPeer(forwardInfo.source?.id ?? forwardInfo.author.id, .chat(textInputState: nil, messageId: nil), nil)
                                }
                                return
                            }
                        }
                        
                        self.item?.controllerInteraction.clickThroughMessage()
                    case .longTap, .doubleTap:
                        if let item = self.item, let videoContentNode = self.interactiveVideoNode.videoContentNode(at: self.view.convert(location, to: self.interactiveVideoNode.view)) {
                            item.controllerInteraction.openMessageContextMenu(item.message, videoContentNode, videoContentNode.bounds)
                        }
                    case .hold:
                        break
                }
            }
        default:
            break
        }
    }
    
    @objc func swipeToReplyGesture(_ recognizer: ChatSwipeToReplyRecognizer) {
        switch recognizer.state {
        case .began:
            self.currentSwipeToReplyTranslation = 0.0
            if self.swipeToReplyFeedback == nil {
                self.swipeToReplyFeedback = HapticFeedback()
                self.swipeToReplyFeedback?.prepareImpact()
            }
            (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
        case .changed:
            let translation = recognizer.translation(in: self.view)
            var animateReplyNodeIn = false
            if (translation.x < -45.0) != (self.currentSwipeToReplyTranslation < -45.0) {
                if translation.x < -45.0, self.swipeToReplyNode == nil, let item = self.item {
                    self.swipeToReplyFeedback?.impact()
                    
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: item.presentationData.theme.theme.chat.bubble.shareButtonFillColor, strokeColor: item.presentationData.theme.theme.chat.bubble.shareButtonStrokeColor, foregroundColor: item.presentationData.theme.theme.chat.bubble.shareButtonForegroundColor)
                    self.swipeToReplyNode = swipeToReplyNode
                    self.addSubnode(swipeToReplyNode)
                    animateReplyNodeIn = true
                }
            }
            self.currentSwipeToReplyTranslation = translation.x
            var bounds = self.bounds
            bounds.origin.x = -translation.x
            self.bounds = bounds
            
            if let swipeToReplyNode = self.swipeToReplyNode {
                swipeToReplyNode.frame = CGRect(origin: CGPoint(x: bounds.size.width, y: floor((self.contentSize.height - 33.0) / 2.0)), size: CGSize(width: 33.0, height: 33.0))
                if animateReplyNodeIn {
                    swipeToReplyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                    swipeToReplyNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                }
            }
        case .cancelled, .ended:
            self.swipeToReplyFeedback = nil
            
            let translation = recognizer.translation(in: self.view)
            if case .ended = recognizer.state, translation.x < -45.0 {
                if let item = self.item {
                    item.controllerInteraction.setupReply(item.message.id)
                }
            }
            var bounds = self.bounds
            let previousBounds = bounds
            bounds.origin.x = 0.0
            self.bounds = bounds
            self.layer.animateBounds(from: previousBounds, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            if let swipeToReplyNode = self.swipeToReplyNode {
                self.swipeToReplyNode = nil
                swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                    swipeToReplyNode?.removeFromSupernode()
                })
                swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            }
        default:
            break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        if let selectionState = item.controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            
            selected = selectionState.selectedIds.contains(item.message.id)
            incoming = item.message.effectivelyIncoming(item.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: false)
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(theme: item.presentationData.theme.theme, toggle: { [weak self] value in
                    if let strongSelf = self, let item = strongSelf.item {
                        item.controllerInteraction.toggleMessagesSelection([item.message.id], value)
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}
