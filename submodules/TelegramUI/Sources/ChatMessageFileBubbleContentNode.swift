import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences

class ChatMessageFileBubbleContentNode: ChatMessageBubbleContentNode {
    let interactiveFileNode: ChatMessageInteractiveFileNode
    
    override var visibility: ListViewItemNodeVisibility {
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
    
    required init() {
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
                let _ = item.controllerInteraction.openMessage(item.message, .default)
            }
        }
        
        self.interactiveFileNode.requestUpdateLayout = { [weak self] _ in
            if let strongSelf = self, let item = strongSelf.item {
                let _ = item.controllerInteraction.requestMessageUpdate(item.message.id)
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
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let interactiveFileLayout = self.interactiveFileNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, selection, constrainedSize in
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
            
            let (initialWidth, refineLayout) = interactiveFileLayout(ChatMessageInteractiveFileNode.Arguments(
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
                displayReactions: true,
                messageSelection: item.message.groupingKey != nil ? selection : nil,
                constrainedSize: CGSize(width: constrainedSize.width - layoutConstants.file.bubbleInsets.left - layoutConstants.file.bubbleInsets.right, height: constrainedSize.height)
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
                    
                    return (CGSize(width: fileSize.width + layoutConstants.file.bubbleInsets.left + layoutConstants.file.bubbleInsets.right, height: fileSize.height + layoutConstants.file.bubbleInsets.top + bottomInset), { [weak self] animation, synchronousLoads in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            strongSelf.interactiveFileNode.frame = CGRect(origin: CGPoint(x: layoutConstants.file.bubbleInsets.left, y: layoutConstants.file.bubbleInsets.top), size: fileSize)
                            
                            fileApply(synchronousLoads, animation)
                        }
                    })
                })
            })
        }
    }
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id == messageId {
            return self.interactiveFileNode.transitionNode(media: media)
        } else {
            return nil
        }
    }
    
    override func updateHiddenMedia(_ media: [Media]?) -> Bool {
        return self.interactiveFileNode.updateHiddenMedia(media)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.interactiveFileNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.interactiveFileNode.dateAndStatusNode.supernode != nil, let _ = self.interactiveFileNode.dateAndStatusNode.hitTest(self.view.convert(point, to: self.interactiveFileNode.dateAndStatusNode.view), with: nil) {
            return .ignore
        }
        if self.interactiveFileNode.hasTapAction(at: self.view.convert(point, to: self.interactiveFileNode.view)) {
            return .ignore
        }
        return super.tapActionAtPoint(point, gesture: gesture, isEstimating: isEstimating)
    }
    
    override func reactionTargetView(value: String) -> UIView? {
        if !self.interactiveFileNode.dateAndStatusNode.isHidden {
            return self.interactiveFileNode.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
}
