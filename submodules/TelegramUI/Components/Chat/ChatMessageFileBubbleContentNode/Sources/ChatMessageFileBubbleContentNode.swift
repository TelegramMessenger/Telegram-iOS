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
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageInteractiveFileNode
import ChatControllerInteraction

public class ChatMessageFileBubbleContentNode: ChatMessageBubbleContentNode {
    public let interactiveFileNode: ChatMessageInteractiveFileNode
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            var wasVisible = false
            if case .visible = oldValue {
                wasVisible = true
            }
            var isVisible = false
            if case .visible = self.visibility {
                isVisible = true
            }
            if wasVisible != isVisible {
                self.interactiveFileNode.visibility = isVisible
            }
        }
    }
    
    required public init() {
        self.interactiveFileNode = ChatMessageInteractiveFileNode()
        
        super.init()
        
        self.addSubnode(self.interactiveFileNode)
        
        self.interactiveFileNode.toggleSelection = { [weak self] value in
            if let strongSelf = self, let item = strongSelf.item {
                item.controllerInteraction.toggleMessagesSelection([item.message.id], value)
            }
        }
        
        self.interactiveFileNode.activateLocalContent = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
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
        
        self.interactiveFileNode.dateAndStatusNode.reactionSelected = { [weak self] _, value, sourceView in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(item.topMessage, .reaction(value), false, sourceView)
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
        
    override public func accessibilityActivate() -> Bool {
        if let item = self.item {
            let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
        }
        return true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let interactiveFileLayout = self.interactiveFileNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, selection, constrainedSize, _ in
            var selectedFile: TelegramMediaFile?
            for media in item.message.media {
                if let telegramFile = media as? TelegramMediaFile {
                    selectedFile = telegramFile
                }
            }
            
            var incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
                incoming = false
            }
            let statusType: ChatMessageDateAndStatusType?
            if case .customChatContents = item.associatedData.subject {
                statusType = nil
            } else if item.message.timestamp == 0 {
                statusType = nil
            } else {
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
            }
            
            let automaticDownload = shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: selectedFile!)
            
            let (initialWidth, refineLayout) = interactiveFileLayout(ChatMessageInteractiveFileNode.Arguments(
                context: item.context,
                presentationData: item.presentationData,
                customTintColor: nil,
                message: item.message,
                topMessage: item.topMessage,
                associatedData: item.associatedData,
                chatLocation: item.chatLocation,
                attributes: item.attributes,
                isPinned: item.isItemPinned,
                forcedIsEdited: item.isItemEdited,
                file: selectedFile!,
                automaticDownload: automaticDownload,
                incoming: incoming,
                isRecentActions: item.associatedData.isRecentActions,
                forcedResourceStatus: item.associatedData.forcedResourceStatus,
                dateAndStatusType: statusType,
                displayReactions: true,
                messageSelection: item.message.groupingKey != nil ? selection : nil,
                isAttachedContentBlock: false,
                layoutConstants: layoutConstants,
                constrainedSize: CGSize(width: constrainedSize.width - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right, height: constrainedSize.height),
                controllerInteraction: item.controllerInteraction
            ))
            
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, initialWidth + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, { constrainedSize, position in
                let (refinedWidth, finishLayout) = refineLayout(CGSize(width: constrainedSize.width - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right, height: constrainedSize.height))
                
                return (refinedWidth + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, { boundingWidth in
                    let (fileSize, fileApply) = finishLayout(boundingWidth - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right)
                    
                    var bottomInset = layoutConstants.file.bubbleInsets.bottom
                    
                    if case let .linear(_, bottom) = position {
                        if case .Neighbour(_, _, .condensed) = bottom {
                            if selectedFile?.isMusic ?? false {
                                bottomInset -= 14.0
                            } else {
                                bottomInset -= 7.0
                            }
                        }
                    }
                    
                    return (CGSize(width: fileSize.width + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, height: fileSize.height + layoutConstants.file.bubbleInsets.top + bottomInset), { [weak self] animation, synchronousLoads, applyInfo in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            strongSelf.interactiveFileNode.frame = CGRect(origin: CGPoint(x: layoutConstants.file.bubbleInsets.left, y: layoutConstants.file.bubbleInsets.top), size: fileSize)
                            
                            fileApply(synchronousLoads, animation, applyInfo)
                        }
                    })
                })
            })
        }
    }
    
    override public func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id == messageId {
            return self.interactiveFileNode.transitionNode(media: media)
        } else {
            return nil
        }
    }
    
    override public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return self.interactiveFileNode.updateHiddenMedia(media)
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        self.interactiveFileNode.willUpdateIsExtractedToContextPreview(value)
    }
    
    override public func updateIsExtractedToContextPreview(_ value: Bool) {
        self.interactiveFileNode.updateIsExtractedToContextPreview(value)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.interactiveFileNode.dateAndStatusNode.supernode != nil, let _ = self.interactiveFileNode.dateAndStatusNode.hitTest(self.view.convert(point, to: self.interactiveFileNode.dateAndStatusNode.view), with: nil) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        if self.interactiveFileNode.hasTapAction(at: self.view.convert(point, to: self.interactiveFileNode.view)) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return super.tapActionAtPoint(point, gesture: gesture, isEstimating: isEstimating)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.interactiveFileNode.hitTest(self.view.convert(point, to: self.interactiveFileNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.interactiveFileNode.dateAndStatusNode.isHidden {
            return self.interactiveFileNode.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if !self.interactiveFileNode.dateAndStatusNode.isHidden {
            return self.interactiveFileNode.dateAndStatusNode.messageEffectTargetView()
        }
        return nil
    }
}
