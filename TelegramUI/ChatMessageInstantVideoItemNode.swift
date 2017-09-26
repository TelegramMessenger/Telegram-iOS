import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

class ChatMessageInstantVideoItemNode: ChatMessageItemView {
    var hostedVideoNode: InstantVideoNode?
    var tapRecognizer: UITapGestureRecognizer?
    
    private var statusNode: RadialStatusNode?
    private var videoFrame: CGRect?
    
    private var selectionNode: ChatMessageSelectionNode?
    
    private var appliedItem: ChatMessageItem?
    var telegramFile: TelegramMediaFile?
    
    private let fetchDisposable = MetaDisposable()
    
    private var replyInfoNode: ChatMessageReplyInfoNode?
    private var replyBackgroundNode: ASImageNode?
    
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let muteIconNode: ASImageNode
    
    private let playbackStatusDisposable = MetaDisposable()
    
    private var shouldAcquireVideoContext: Bool {
        if case .visible = self.visibility {
            return true
        } else {
            return false
        }
    }
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            if self.visibility != oldValue {
                self.hostedVideoNode?.setShouldAcquireContext(self.shouldAcquireVideoContext)
            }
        }
    }
    
    required init() {
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.muteIconNode = ASImageNode()
        self.muteIconNode.isLayerBacked = true
        self.muteIconNode.displayWithoutProcessing = true
        self.muteIconNode.displaysAsynchronously = false
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.dateAndStatusNode)
        self.addSubnode(self.muteIconNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.playbackStatusDisposable.dispose()
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
        let displaySize = CGSize(width: 212.0, height: 212.0)
        let previousFile = self.telegramFile
        let layoutConstants = self.layoutConstants
        
        let makeReplyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let currentReplyBackgroundNode = self.replyBackgroundNode
        
        let currentItem = self.appliedItem
        
        let makeDateAndStatusLayout = self.dateAndStatusNode.asyncLayout()
        
        return { item, width, mergedTop, mergedBottom, dateHeaderAtBottom in
            var updatedTheme: PresentationTheme?
            
            var updatedMuteIconImage: UIImage?
            if item.theme !== currentItem?.theme {
                updatedTheme = item.theme
                updatedMuteIconImage = PresentationResourcesChat.chatInstantMessageMuteIconImage(item.theme)
            }
            
            let theme = item.theme
            let isSecretMedia = item.message.containsSecretMedia
            
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
            
            var updatedPlaybackStatus: Signal<FileMediaResourceStatus, NoError>?
            if let updatedFile = updatedFile, updatedMedia {
                updatedPlaybackStatus = combineLatest(fileMediaResourceStatus(account: item.account, file: updatedFile, message: item.message), item.account.pendingMessageManager.pendingMessageStatus(item.message.id))
                    |> map { resourceStatus, pendingStatus -> FileMediaResourceStatus in
                        if let pendingStatus = pendingStatus {
                            var progress = pendingStatus.progress
                            if pendingStatus.isRunning {
                                progress = max(progress, 0.27)
                            }
                            return .fetchStatus(.Fetching(progress: progress))
                        } else {
                            return resourceStatus
                        }
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
                    replyInfoApply = makeReplyInfoLayout(item.theme, item.account, .standalone, replyMessage, CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude))
                    
                    if let currentReplyBackgroundNode = currentReplyBackgroundNode {
                        updatedReplyBackgroundNode = currentReplyBackgroundNode
                    } else {
                        updatedReplyBackgroundNode = ASImageNode()
                    }
                    replyBackgroundImage = PresentationResourcesChat.chatServiceBubbleFillImage(item.theme)
                    break
                }
            }
            
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
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: imageSize.height), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.appliedItem = item
                    strongSelf.videoFrame = videoFrame
                    
                    if let updatedMuteIconImage = updatedMuteIconImage {
                        strongSelf.muteIconNode.image = updatedMuteIconImage
                    }
                    
                    strongSelf.telegramFile = updatedFile
                    
                    if let image = strongSelf.muteIconNode.image {
                        strongSelf.muteIconNode.frame = CGRect(origin: CGPoint(x: floor(videoFrame.minX + (videoFrame.size.width - image.size.width) / 2.0), y: videoFrame.maxY - image.size.height - 8.0), size: image.size)
                    }
                    
                    if let updatedPlaybackStatus = updatedPlaybackStatus {
                        strongSelf.playbackStatusDisposable.set((updatedPlaybackStatus |> deliverOnMainQueue).start(next: { status in
                            if let strongSelf = self, let videoFrame = strongSelf.videoFrame {
                                let displayMute: Bool
                                switch status {
                                    case let .fetchStatus(fetchStatus):
                                        switch fetchStatus {
                                            case .Local:
                                                displayMute = true
                                            default:
                                                displayMute = false
                                        }
                                    case .playbackStatus:
                                        displayMute = false
                                }
                                if displayMute != (!strongSelf.muteIconNode.alpha.isZero) {
                                    if displayMute {
                                        strongSelf.muteIconNode.alpha = 1.0
                                        strongSelf.muteIconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                        strongSelf.muteIconNode.layer.animateScale(from: 0.4, to: 1.0, duration: 0.15)
                                    } else {
                                        strongSelf.muteIconNode.alpha = 0.0
                                        strongSelf.muteIconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
                                        strongSelf.muteIconNode.layer.animateScale(from: 1.0, to: 0.4, duration: 0.15)
                                    }
                                }
                                
                                var progressRequired = false
                                if case let .fetchStatus(fetchStatus) = status {
                                    if case .Local = fetchStatus {
                                        if let file = updatedFile, file.isVideo {
                                            progressRequired = true
                                        } else if isSecretMedia {
                                            progressRequired = true
                                        }
                                    } else {
                                        progressRequired = true
                                    }
                                }
                                
                                if progressRequired {
                                    if strongSelf.statusNode == nil {
                                        let statusNode = RadialStatusNode(backgroundNodeColor: theme.chat.bubble.mediaOverlayControlBackgroundColor)
                                        statusNode.frame = CGRect(origin: CGPoint(x: videoFrame.origin.x + floor((videoFrame.size.width - 50.0) / 2.0), y: videoFrame.origin.y + floor((videoFrame.size.height - 50.0) / 2.0)), size: CGSize(width: 50.0, height: 50.0))
                                        strongSelf.statusNode = statusNode
                                        strongSelf.addSubnode(statusNode)
                                    } else if let _ = updatedTheme {
                                        
                                        //strongSelf.progressNode?.updateTheme(RadialProgressTheme(backgroundColor: theme.chat.bubble.mediaOverlayControlBackgroundColor, foregroundColor: theme.chat.bubble.mediaOverlayControlForegroundColor, icon: nil))
                                    }
                                } else {
                                    if let statusNode = strongSelf.statusNode {
                                        statusNode.transitionToState(.none, completion: { [weak statusNode] in
                                            statusNode?.removeFromSupernode()
                                        })
                                        strongSelf.statusNode = nil
                                    }
                                }
                                
                                var state: RadialStatusNodeState
                                let bubbleTheme = theme.chat.bubble
                                switch status {
                                    case let .fetchStatus(fetchStatus):
                                        switch fetchStatus {
                                            case let .Fetching(progress):
                                                state = .progress(color: bubbleTheme.mediaOverlayControlForegroundColor, value: CGFloat(progress), cancelEnabled: true)
                                            case .Local:
                                                state = .none
                                                /*if isSecretMedia && secretProgressIcon != nil {
                                                    state = .customIcon(secretProgressIcon!)
                                                } else */
                                            case .Remote:
                                                state = .download(bubbleTheme.mediaOverlayControlForegroundColor)
                                        }
                                    default:
                                        state = .none
                                        break
                                }
                                if let statusNode = strongSelf.statusNode {
                                    if state == .none {
                                        strongSelf.statusNode = nil
                                    }
                                    statusNode.transitionToState(state, completion: { [weak statusNode] in
                                        if state == .none {
                                            statusNode?.removeFromSupernode()
                                        }
                                    })
                                }
                            }
                        }))
                    }
                    
                    dateAndStatusApply(false)
                    strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: min(floor(videoFrame.midX) + 70.0, width - dateAndStatusSize.width - 4.0), y: videoFrame.maxY - dateAndStatusSize.height), size: dateAndStatusSize)
                    
                    if let telegramFile = updatedFile, updatedMedia, let context = item.account.applicationContext as? TelegramApplicationContext {
                        if let hostedVideoNode = strongSelf.hostedVideoNode {
                            hostedVideoNode.removeFromSupernode()
                        }
                        let hostedVideoNode = InstantVideoNode(theme: item.theme, manager: context.mediaManager, account: item.account, source: .messageMedia(stableId: item.message.stableId, file: telegramFile), priority: 1, withSound: false)
                        hostedVideoNode.tapped = {
                            if let strongSelf = self {
                                if let item = strongSelf.item {
                                    if strongSelf.muteIconNode.alpha.isZero {
                                        item.account.telegramApplicationContext.mediaManager.playlistPlayerControl(.stop)
                                    } else {
                                        strongSelf.controllerInteraction?.openMessage(item.message.id)
                                    }
                                }
                            }
                        }
                        strongSelf.hostedVideoNode = hostedVideoNode
                        strongSelf.insertSubnode(hostedVideoNode, belowSubnode: strongSelf.dateAndStatusNode)
                        hostedVideoNode.setShouldAcquireContext(strongSelf.shouldAcquireVideoContext)
                    }
                    
                    if let hostedVideoNode = strongSelf.hostedVideoNode {
                        hostedVideoNode.frame = videoFrame
                        hostedVideoNode.updateLayout(arguments.boundingSize)
                    }
                    
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
                        if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                            if let item = self.item, let author = item.message.author {
                                self.controllerInteraction?.openPeer(author.id, .info, item.message.id)
                            }
                            return
                        }
                        
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
                        
                        if let item = self.item, let hostedVideoNode = self.hostedVideoNode, hostedVideoNode.frame.contains(location) {
                            self.controllerInteraction?.openMessage(item.message.id)
                            return
                        }
                        
                        self.controllerInteraction?.clickThroughMessage()
                    case .longTap, .doubleTap:
                        if let item = self.item, let hostedVideoNode = self.hostedVideoNode, hostedVideoNode.frame.contains(location) {
                            self.controllerInteraction?.openMessageContextMenu(item.message.id, self, hostedVideoNode.frame)
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
