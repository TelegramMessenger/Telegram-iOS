import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let backgroundImage = generateInstantVideoBackground(incoming: true)

class ChatMessageInstantVideoItemNode: ChatMessageItemView {
    let backgroundNode: ASImageNode
    let videoNode: ManagedVideoNode
    var progressNode: RadialProgressNode?
    var tapRecognizer: UITapGestureRecognizer?
    
    private var selectionNode: ChatMessageSelectionNode?
    
    var telegramFile: TelegramMediaFile?
    
    private let fetchDisposable = MetaDisposable()
    
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundNode: ASImageNode?
    
    required init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.videoNode = ManagedVideoNode()
        
        super.init(layerBacked: false)
        
        self.backgroundNode.image = backgroundImage
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.videoNode)
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
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ width: CGFloat, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let displaySize = CGSize(width: 210.0, height: 210.0)
        let previousFile = self.telegramFile
        let layoutConstants = self.layoutConstants
        
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        
        return { item, width, mergedTop, mergedBottom, dateHeaderAtBottom in
            let incoming = item.message.effectivelyIncoming
            let imageSize = displaySize
            
            var updatedFile: TelegramMediaFile?
            var updatedMedia = false
            for media in item.message.media {
                if let file = media as? TelegramMediaFile {
                    updatedFile = file
                    if let previousFile = previousFile {
                        updatedMedia = !previousFile.isEqual(file)
                    } else if previousFile == nil {
                        updatedMedia = true
                    }
                }
            }
            
            let avatarInset: CGFloat = (item.peerId.isGroupOrChannel && item.message.author != nil) ? layoutConstants.avatarDiameter : 0.0
            
            var layoutInsets = layoutConstants.instantVideo.insets
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            let videoFrame = CGRect(origin: CGPoint(x: (incoming ? (layoutConstants.bubble.edgeInset + avatarInset + layoutConstants.bubble.contentInsets.left) : (width - imageSize.width - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left)), y: 0.0), size: imageSize)
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: videoFrame.size.width / 2.0), imageSize: videoFrame.size, boundingSize: videoFrame.size, intrinsicInsets: UIEdgeInsets())
            
            var replyInfoApply: (CGSize, () -> ChatMessageReplyInfoNode)?
            var updatedReplyBackgroundNode: ASImageNode?
            var replyBackgroundImage: UIImage?
            for attribute in item.message.attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[replyAttribute.messageId] {
                    let availableWidth = max(60.0, width - imageSize.width - 20.0 - layoutConstants.bubble.edgeInset * 2.0 - avatarInset - layoutConstants.bubble.contentInsets.left)
                    replyInfoApply = makeReplyInfoLayout(item.account, .standalone, replyMessage, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                    
                    if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                        updatedReplyBackgroundNode = currentReplyBackgroundNode
                    } else {
                        updatedReplyBackgroundNode = ASImageNode()
                    }
                    replyBackgroundImage = backgroundImage
                    break
                }
            }
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: imageSize.height), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.telegramFile = updatedFile
                    
                    strongSelf.videoNode.frame = videoFrame
                    strongSelf.videoNode.transformArguments = arguments
                    
                    strongSelf.backgroundNode.frame = videoFrame.insetBy(dx: -2.0, dy: -2.0)
                    
                    if let telegramFile = updatedFile, updatedMedia, let context = item.account.applicationContext as? TelegramApplicationContext {
                        strongSelf.videoNode.acquireContext(account: item.account, mediaManager: context.mediaManager, id: PeerMessageManagedMediaId(messageId: item.message.id), resource: telegramFile.resource)
                    }
                    
                    strongSelf.progressNode?.position = strongSelf.videoNode.position
                    
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
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
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
                    
                    if let item = self.item, self.videoNode.frame.contains(location) {
                        self.controllerInteraction?.openMessage(item.message.id)
                        return
                    }
                    
                    self.controllerInteraction?.clickThroughMessage()
                case .longTap, .doubleTap:
                    if let item = self.item, self.videoNode.frame.contains(location) {
                        self.controllerInteraction?.openMessageContextMenu(item.message.id, self, self.videoNode.frame)
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
}
