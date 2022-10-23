import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import ComponentFlow
import AudioTranscriptionButtonComponent

class ChatMessageInstantVideoBubbleContentNode: ChatMessageBubbleContentNode {
    let interactiveFileNode: ChatMessageInteractiveFileNode
    let interactiveVideoNode: ChatMessageInteractiveInstantVideoNode
    
    private let maskLayer = SimpleLayer()
    private let maskForeground = SimpleLayer()
    
    private let backdropMaskLayer = SimpleLayer()
    private let backdropMaskForeground = BubbleMaskLayer()
    
    private var isExpanded = false
    
    private var audioTranscriptionState: AudioTranscriptionButtonComponent.TranscriptionState = .collapsed
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            var wasVisible = false
            if case .visible = oldValue {
                wasVisible = true
            }
            let isVisible = self.isContentVisible
            if wasVisible != isVisible {
                if !isVisible {
                    Queue.mainQueue().after(0.05) {
                        if isVisible == self.isContentVisible {
                            self.interactiveVideoNode.visibility = isVisible
                        }
                    }
                } else {
                    self.interactiveVideoNode.visibility = isVisible
                }
            }
        }
    }
    
    private var isContentVisible: Bool  {
        var isVisible = false
        if case .visible = self.visibility {
            isVisible = true
        }
        return isVisible
    }
    
    required init() {
        self.interactiveFileNode = ChatMessageInteractiveFileNode()
        self.interactiveVideoNode = ChatMessageInteractiveInstantVideoNode()
                
        super.init()
        
        self.maskForeground.backgroundColor = UIColor.white.cgColor
        self.maskForeground.masksToBounds = true
        self.maskLayer.addSublayer(self.maskForeground)
            
        self.addSubnode(self.interactiveFileNode)
        self.addSubnode(self.interactiveVideoNode)
                
        self.interactiveVideoNode.requestUpdateLayout = { [weak self] _ in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, false)
            }
        }
        self.interactiveVideoNode.updateTranscriptionExpanded = { [weak self] state in
            if let strongSelf = self, let item = strongSelf.item {
                let previous = strongSelf.audioTranscriptionState
                strongSelf.audioTranscriptionState = state
                strongSelf.interactiveFileNode.audioTranscriptionState = state
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, state != .inProgress && previous != state)
            }
        }
        self.interactiveVideoNode.updateTranscriptionText = { [weak self] text in
            if let strongSelf = self, let item = strongSelf.item {
                strongSelf.interactiveFileNode.forcedAudioTranscriptionText = text
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, false)
            }
        }
        self.interactiveFileNode.updateTranscriptionExpanded = { [weak self] state in
            if let strongSelf = self, let item = strongSelf.item {
                let previous = strongSelf.audioTranscriptionState
                strongSelf.audioTranscriptionState = state
                strongSelf.interactiveVideoNode.audioTranscriptionState = state
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, previous != state)
            }
        }
        
        self.interactiveFileNode.toggleSelection = { [weak self] value in
            if let strongSelf = self, let item = strongSelf.item {
                item.controllerInteraction.toggleMessagesSelection([item.message.id], value)
            }
        }
        
        self.interactiveFileNode.activateLocalContent = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.openMessage(item.message, .default)
            }
        }
        
        self.interactiveFileNode.requestUpdateLayout = { [weak self] _ in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id, false)
            }
        }
        
        self.interactiveFileNode.displayImportedTooltip = { [weak self] sourceNode in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.displayImportedMessageTooltip(sourceNode)
            }
        }
        
        self.interactiveFileNode.dateAndStatusNode.reactionSelected = { [weak self] value in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(item.message, .reaction(value))
        }
        
        self.interactiveFileNode.dateAndStatusNode.openReactionPreview = { [weak self] gesture, sourceNode, value in
            guard let strongSelf = self, let item = strongSelf.item else {
                gesture?.cancel()
                return
            }
            
            item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceNode, gesture, value)
        }
        
        self.interactiveFileNode.updateIsTextSelectionActive = { [weak self] value in
            self?.updateIsTextSelectionActive?(value)
        }
    }
    
    override func accessibilityActivate() -> Bool {
        if let item = self.item {
            let _ = item.controllerInteraction.openMessage(item.message, .default)
        }
        return true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let interactiveVideoLayout = self.interactiveVideoNode.asyncLayout()
        let interactiveFileLayout = self.interactiveFileNode.asyncLayout()
        
        let currentExpanded = self.isExpanded
        let audioTranscriptionState = self.audioTranscriptionState
        let didSetupFileNode = self.item != nil
        
        return { item, layoutConstants, preparePosition, selection, constrainedSize, avatarInset in
            var selectedFile: TelegramMediaFile?
            for media in item.message.media {
                if let telegramFile = media as? TelegramMediaFile {
                    selectedFile = telegramFile
                }
            }
            
            let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            let statusType: ChatMessageDateAndStatusType?
            switch preparePosition {
            case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                    if incoming {
                        statusType = .BubbleIncoming
                    } else {
                        if item.message.flags.contains(.Failed) {
                            statusType = .BubbleOutgoing(.Failed)
                        } else if (item.message.flags.isSending && !item.message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                    }
                default:
                    statusType = nil
            }
            
            let automaticDownload = shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: selectedFile!)
            
            let (_, refineLayout) = interactiveFileLayout(ChatMessageInteractiveFileNode.Arguments(
                context: item.context,
                presentationData: item.presentationData,
                message: item.message,
                topMessage: item.topMessage,
                associatedData: item.associatedData,
                chatLocation: item.chatLocation,
                attributes: item.attributes,
                isPinned: item.isItemPinned,
                forcedIsEdited: item.isItemEdited,
                file: selectedFile!,
                automaticDownload: automaticDownload,
                incoming: item.message.effectivelyIncoming(item.context.account.peerId),
                isRecentActions: item.associatedData.isRecentActions,
                forcedResourceStatus: item.associatedData.forcedResourceStatus,
                dateAndStatusType: statusType,
                displayReactions: false,
                messageSelection: item.message.groupingKey != nil ? selection : nil,
                layoutConstants: layoutConstants,
                constrainedSize: CGSize(width: constrainedSize.width - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right, height: constrainedSize.height),
                controllerInteraction: item.controllerInteraction
            ))
            
            var isReplyThread = false
            if case .replyThread = item.chatLocation {
                isReplyThread = true
            }
                        
            var isExpanded = false
            if case .expanded = audioTranscriptionState {
                isExpanded = true
            }
            
            var isPlaying = false
            let normalDisplaySize = layoutConstants.instantVideo.dimensions
            var displaySize = normalDisplaySize
            let maximumDisplaySize = CGSize(width: min(404, constrainedSize.width - 2.0), height: min(404, constrainedSize.width - 2.0))
            if item.associatedData.currentlyPlayingMessageId == item.message.index {
                isPlaying = true
                if !isExpanded {
                    displaySize = maximumDisplaySize
                }
            }
            
            let leftInset: CGFloat = 0.0
            let rightInset: CGFloat = 0.0
        
            let (videoLayout, videoApply) = interactiveVideoLayout(ChatMessageBubbleContentItem(context: item.context, controllerInteraction: item.controllerInteraction, message: item.message, topMessage: item.message, read: item.read, chatLocation: item.chatLocation, presentationData: item.presentationData, associatedData: item.associatedData, attributes: item.attributes, isItemPinned: item.message.tags.contains(.pinned) && !isReplyThread, isItemEdited: false), constrainedSize.width - leftInset - rightInset - avatarInset, displaySize, maximumDisplaySize, isPlaying ? 1.0 : 0.0, .free, automaticDownload, avatarInset)
            
            let videoFrame = CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: videoLayout.contentSize)
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none, shareButtonOffset: isExpanded ? nil : CGPoint(x: displaySize.width + 4.0, y: -25.0), hidesHeaders: !isExpanded, avatarOffset: !isExpanded && isPlaying ? -100.0 : 0.0)
            
            let width = videoFrame.width + 2.0
            
            return (contentProperties, nil, width, { constrainedSize, position in
                var refinedWidth = videoFrame.width + 2.0
                var finishLayout: ((CGFloat) -> (CGSize, (Bool, ListViewItemUpdateAnimation, ListViewItemApply?) -> Void))?
                
                if isExpanded || !didSetupFileNode {
                    (refinedWidth, finishLayout) = refineLayout(CGSize(width: constrainedSize.width - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right, height: constrainedSize.height))
                    refinedWidth += layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right
                }
                
                if !isExpanded {
                    refinedWidth = videoFrame.width + 2.0
                }
                
                return (refinedWidth, { boundingWidth in
                    var finalSize: CGSize
                    var finalFileSize: CGSize?
                    var finalFileApply: ((Bool, ListViewItemUpdateAnimation, ListViewItemApply?) -> Void)?
                    if let finishLayout = finishLayout {
                        let (fileSize, fileApply) = finishLayout(boundingWidth - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right)
                        if isExpanded {
                            finalSize = CGSize(width: fileSize.width + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, height: fileSize.height + layoutConstants.file.bubbleInsets.top + layoutConstants.file.bubbleInsets.bottom)
                        } else {
                            finalSize = CGSize(width: boundingWidth, height: videoFrame.height + 2.0)
                        }
                        finalFileSize = fileSize
                        finalFileApply = fileApply
                    } else {
                        finalSize = CGSize(width: boundingWidth, height: videoFrame.height + 2.0)
                    }
                    
                    return (finalSize, { [weak self] animation, synchronousLoads, applyInfo in
                        if let strongSelf = self {
                            let firstTime = strongSelf.item == nil
                            strongSelf.item = item
                            strongSelf.isExpanded = isExpanded
                            
                            if firstTime {
                                strongSelf.interactiveFileNode.isHidden = true
                            }
                            
                            strongSelf.bubbleBackgroundNode?.layer.mask = strongSelf.maskLayer
                            if let bubbleBackdropNode = strongSelf.bubbleBackdropNode, bubbleBackdropNode.hasImage && strongSelf.backdropMaskForeground.superlayer == nil {
                                strongSelf.bubbleBackdropNode?.overrideMask = true
                                strongSelf.bubbleBackdropNode?.maskView?.layer.addSublayer(strongSelf.backdropMaskForeground)
                            }
                            
                            strongSelf.maskLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 640.0, height: 640.0))
                            strongSelf.backdropMaskLayer.frame = strongSelf.maskLayer.frame
                                          
                            let bubbleSize = strongSelf.bubbleBackgroundNode?.backgroundFrame.size ?? finalSize
                            
                            let radius: CGFloat = displaySize.width / 2.0
                            let maskCornerRadius = isExpanded ? 1.0 : radius
                            let maskFrame = CGRect(origin: CGPoint(x: isExpanded ? 1.0 : (incoming ? 7.0 : 1.0), y: isExpanded ? 0.0 : 1.0), size: isExpanded ? bubbleSize : CGSize(width: radius * 2.0, height: radius * 2.0))
                            animation.animator.updateCornerRadius(layer: strongSelf.maskForeground, cornerRadius: maskCornerRadius, completion: nil)
                            animation.animator.updateFrame(layer: strongSelf.maskForeground, frame: maskFrame, completion: nil)
                            
                            let backdropMaskFrame = CGRect(origin: CGPoint(x: isExpanded ? (incoming ? 8.0 : 2.0) : (incoming ? 8.0 : 2.0), y: isExpanded ? 2.0 : 2.0), size: isExpanded ? CGSize(width: bubbleSize.width - 8.0, height: bubbleSize.height - 3.0) : CGSize(width: radius * 2.0, height: radius * 2.0))
                           
                            let topLeftCornerRadius: CGFloat
                            let topRightCornerRadius: CGFloat
                            let bottomLeftCornerRadius: CGFloat
                            let bottomRightCornerRadius: CGFloat
                            if let bubbleCorners = strongSelf.bubbleBackgroundNode?.currentCorners(bubbleCorners: item.presentationData.chatBubbleCorners) {
                                topLeftCornerRadius = isExpanded ? bubbleCorners.topLeftRadius : radius
                                topRightCornerRadius = isExpanded ? bubbleCorners.topRightRadius : radius
                                bottomLeftCornerRadius = isExpanded ? bubbleCorners.bottomLeftRadius : radius
                                bottomRightCornerRadius = isExpanded ? bubbleCorners.bottomRightRadius : radius
                            } else {
                                let backdropRadius = isExpanded ? item.presentationData.chatBubbleCorners.mainRadius : radius
                                topLeftCornerRadius = backdropRadius
                                topRightCornerRadius = backdropRadius
                                bottomLeftCornerRadius = backdropRadius
                                bottomRightCornerRadius = backdropRadius
                            }
                            
                            strongSelf.backdropMaskForeground.update(
                                size: backdropMaskFrame.size,
                                topLeftCornerRadius: topLeftCornerRadius,
                                topRightCornerRadius: topRightCornerRadius,
                                bottomLeftCornerRadius: bottomLeftCornerRadius,
                                bottomRightCornerRadius: bottomRightCornerRadius,
                                animator: animation.animator
                            )
                            animation.animator.updateFrame(layer: strongSelf.backdropMaskForeground, frame: backdropMaskFrame, completion: nil)
                                                        
                            let videoLayoutData: ChatMessageInstantVideoItemLayoutData
                            if incoming {
                                videoLayoutData = .constrained(left: 0.0, right: 0.0) //max(0.0, availableContentWidth - videoFrame.width))
                            } else {
                                videoLayoutData = .constrained(left: 0.0, right: 0.0)
                            }
                            
                            var videoAnimation = animation
                            var fileAnimation = animation
                            if currentExpanded != isExpanded {
                                videoAnimation = .None
                                fileAnimation = .None
                            }

                            animation.animator.updateFrame(layer: strongSelf.interactiveVideoNode.layer, frame: videoFrame, completion: nil)
                            videoApply(videoLayoutData, videoAnimation)
                            
                            if let fileSize = finalFileSize {
                                strongSelf.interactiveFileNode.frame = CGRect(origin: CGPoint(x: layoutConstants.file.bubbleInsets.left, y: layoutConstants.file.bubbleInsets.top), size: fileSize)
                                finalFileApply?(synchronousLoads, fileAnimation, applyInfo)
                            }
                            
                            if currentExpanded != isExpanded {
                                if isExpanded {
                                    strongSelf.interactiveVideoNode.animateTo(strongSelf.interactiveFileNode, animator: animation.animator)
                                } else {
                                    strongSelf.interactiveVideoNode.animateFrom(strongSelf.interactiveFileNode, animator: animation.animator)
                                }
                            }
                        }
                    })
                })
            })
        }
    }
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    override func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return false
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.interactiveVideoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.interactiveVideoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.interactiveVideoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func willUpdateIsExtractedToContextPreview(_ value: Bool) {
//        self.interactiveFileNode.willUpdateIsExtractedToContextPreview(value)
    }
    
    override func updateIsExtractedToContextPreview(_ value: Bool) {
//        self.interactiveFileNode.updateIsExtractedToContextPreview(value)
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if !self.interactiveFileNode.isHidden {
            if self.interactiveFileNode.dateAndStatusNode.supernode != nil, let _ = self.interactiveFileNode.dateAndStatusNode.hitTest(self.view.convert(point, to: self.interactiveFileNode.dateAndStatusNode.view), with: nil) {
                return .ignore
            }
            if self.interactiveFileNode.hasTapAction(at: self.view.convert(point, to: self.interactiveFileNode.view)) {
                return .ignore
            }
        }
        if !self.interactiveVideoNode.isHidden {
            if self.interactiveVideoNode.dateAndStatusNode.supernode != nil, let _ = self.interactiveVideoNode.dateAndStatusNode.hitTest(self.view.convert(point, to: self.interactiveVideoNode.dateAndStatusNode.view), with: nil) {
                return .ignore
            }
            if let audioTranscriptionButton = self.interactiveVideoNode.audioTranscriptionButton, let _ = audioTranscriptionButton.hitTest(self.view.convert(point, to: audioTranscriptionButton), with: nil) {
                return .ignore
            }
        }
        return super.tapActionAtPoint(point, gesture: gesture, isEstimating: isEstimating)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.isExpanded, let result = self.interactiveFileNode.hitTest(self.view.convert(point, to: self.interactiveFileNode.view), with: event) {
            return result
        }
        if !self.isExpanded, let result = self.interactiveVideoNode.hitTest(self.view.convert(point, to: self.interactiveVideoNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
    
    override func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.interactiveVideoNode.dateAndStatusNode.isHidden {
            return self.interactiveVideoNode.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override var disablesClipping: Bool {
        return true
    }
}

private class BubbleMaskLayer: SimpleLayer {
    private class CornerLayer: SimpleLayer {
        private let contentLayer = SimpleLayer()
        
        override init(layer: Any) {
            super.init(layer: layer)
        }
        
        init(cornerMask: CACornerMask) {
            super.init()
            self.masksToBounds = true
            
            self.contentLayer.backgroundColor = UIColor.white.cgColor
            self.contentLayer.masksToBounds = true
            self.contentLayer.maskedCorners = cornerMask
            self.addSublayer(self.contentLayer)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(size: CGSize, cornerRadius: CGFloat, animator: ControlledTransitionAnimator) {
            animator.updateCornerRadius(layer: self.contentLayer, cornerRadius: cornerRadius, completion: nil)
            
            let mask = self.contentLayer.maskedCorners
            var origin = CGPoint()
            if mask == .layerMinXMinYCorner {
                origin = .zero
            } else if mask == .layerMaxXMinYCorner {
                origin = CGPoint(x: -size.width / 2.0, y: 0.0)
            } else if mask == .layerMinXMaxYCorner {
                origin = CGPoint(x: 0.0, y: -size.height / 2.0)
            } else if mask == .layerMaxXMaxYCorner {
                origin = CGPoint(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            animator.updateFrame(layer: self.contentLayer, frame: CGRect(origin: origin, size: size), completion: nil)
        }
    }
    
    private let topLeft = CornerLayer(cornerMask: [.layerMinXMinYCorner])
    private let topRight = CornerLayer(cornerMask: [.layerMaxXMinYCorner])
    private let bottomLeft = CornerLayer(cornerMask: [.layerMinXMaxYCorner])
    private let bottomRight = CornerLayer(cornerMask: [.layerMaxXMaxYCorner])
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    override init() {
        super.init()
        
        self.addSublayer(self.topLeft)
        self.addSublayer(self.topRight)
        self.addSublayer(self.bottomLeft)
        self.addSublayer(self.bottomRight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(
        size: CGSize,
        topLeftCornerRadius: CGFloat,
        topRightCornerRadius: CGFloat,
        bottomLeftCornerRadius: CGFloat,
        bottomRightCornerRadius: CGFloat,
        animator: ControlledTransitionAnimator
    ) {
        var size = CGSize(width: floor(size.width), height: floor(size.height))
        if Int(size.width) % 2 != 0 {
            size.width += 1.0
        }
        if Int(size.height) % 2 != 0 {
            size.height += 1.0
        }
        animator.updateFrame(layer: self.topLeft, frame: CGRect(origin: .zero, size: CGSize(width: size.width / 2.0, height: size.height / 2.0)), completion: nil)
        animator.updateFrame(layer: self.topRight, frame: CGRect(origin: CGPoint(x: size.width / 2.0, y: 0.0), size: CGSize(width: size.width / 2.0, height: size.height / 2.0)), completion: nil)
        animator.updateFrame(layer: self.bottomLeft, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height / 2.0), size: CGSize(width: size.width / 2.0, height: size.height / 2.0)), completion: nil)
        animator.updateFrame(layer: self.bottomRight, frame: CGRect(origin: CGPoint(x: size.width / 2.0, y: size.height / 2.0), size: CGSize(width: size.width / 2.0, height: size.height / 2.0)), completion: nil)
        
        self.topLeft.update(size: size, cornerRadius: topLeftCornerRadius, animator: animator)
        self.topRight.update(size: size, cornerRadius: topRightCornerRadius, animator: animator)
        self.bottomLeft.update(size: size, cornerRadius: bottomLeftCornerRadius, animator: animator)
        self.bottomRight.update(size: size, cornerRadius: bottomRightCornerRadius, animator: animator)
    }
}
