import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData
import AccountContext
import GridMessageSelectionNode
import ChatControllerInteraction
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatMessageInteractiveMediaNode
import ChatControllerInteraction
import InvisibleInkDustNode
import TelegramUniversalVideoContent

public class ChatMessageMediaBubbleContentNode: ChatMessageBubbleContentNode {
    override public var supportsMosaic: Bool {
        return true
    }
    
    private let interactiveImageNode: ChatMessageInteractiveMediaNode
    private var selectionNode: GridMessageSelectionNode?
    private var highlightedState: Bool = false
    
    private var media: Media?
    private var mediaIndex: Int?
    private var automaticPlayback: Bool?
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            self.interactiveImageNode.visibility = self.visibility != .none
        }
    }
    
    required public init() {
        self.interactiveImageNode = ChatMessageInteractiveMediaNode()
        
        super.init()
        
        self.addSubnode(self.interactiveImageNode)
        
        self.interactiveImageNode.activateLocalContent = { [weak self] mode in
            guard let self, let item = self.item else {
                return
            }
            let openChatMessageMode: ChatControllerInteractionOpenMessageMode
            switch mode {
                case .default:
                    openChatMessageMode = .default
                case .stream:
                    openChatMessageMode = .stream
                case .automaticPlayback:
                    openChatMessageMode = .automaticPlayback
            }
            
            if !item.controllerInteraction.isOpeningMedia {
                let params = OpenMessageParams(mode: openChatMessageMode, mediaIndex: self.mediaIndex, progress: self.itemNode?.makeProgress())
                let _ = item.controllerInteraction.openMessage(item.message, params)
            }
        }
        
        self.interactiveImageNode.activateAgeRestrictedMedia = { [weak self] in
            guard let self, let item = self.item else {
                return
            }
            let _ = item.controllerInteraction.openAgeRestrictedMessageMedia(item.message, { [weak self] in
                self?.interactiveImageNode.reveal()
            })
        }
        
        self.interactiveImageNode.updateMessageReaction = { [weak self] message, value, force, sourceView in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(message, value, force, sourceView)
        }

        self.interactiveImageNode.activatePinch = { [weak self] sourceNode in
            guard let strongSelf = self, let _ = strongSelf.item else {
                return
            }
            strongSelf.item?.controllerInteraction.activateMessagePinch(sourceNode)
        }
        self.interactiveImageNode.playMessageEffect = { [weak self] message in
            guard let strongSelf = self, let _ = strongSelf.item else {
                return
            }
            strongSelf.item?.controllerInteraction.playMessageEffect(message)
        }
        self.interactiveImageNode.requestInlineUpdate = { [weak self] in
            guard let self else {
                return
            }
            self.requestInlineUpdate?()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let interactiveImageLayout = self.interactiveImageNode.asyncLayout()
        
        return { item, layoutConstants, preparePosition, selection, constrainedSize, _ in
            var selectedMedia: Media?
            var selectedMediaIndex: Int?
            var extendedMedia: TelegramExtendedMedia?
            var automaticDownload: InteractiveMediaNodeAutodownloadMode = .none
            var automaticPlayback: Bool = false
            var contentMode: InteractiveMediaNodeContentMode = .aspectFit
            
            if let updatingMedia = item.attributes.updatingMedia, case let .update(mediaReference) = updatingMedia.media {
                selectedMedia = mediaReference.media
            }
            if selectedMedia == nil {
                for media in item.message.media {
                    if let telegramImage = media as? TelegramMediaImage {
                        selectedMedia = telegramImage
                        if shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: telegramImage) {
                            automaticDownload = .full
                        }
                    } else if let telegramStory = media as? TelegramMediaStory {
                        selectedMedia = telegramStory
                        if let storyMedia = item.message.associatedStories[telegramStory.storyId], case let .item(storyItem) = storyMedia.get(Stories.StoredItem.self), let media = storyItem.media {
                            if let telegramImage = media as? TelegramMediaImage {
                                if shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: telegramImage) {
                                    automaticDownload = .full
                                }
                            } else if let telegramFile = media as? TelegramMediaFile {
                                if shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: telegramFile) {
                                    automaticDownload = .full
                                } else if shouldPredownloadMedia(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, media: telegramFile) {
                                    automaticDownload = .prefetch
                                }
                                
                                if !item.message.containsSecretMedia {
                                    if telegramFile.isAnimated && item.context.sharedContext.energyUsageSettings.autoplayGif {
                                        if case .full = automaticDownload {
                                            automaticPlayback = true
                                        } else {
                                            automaticPlayback = item.context.account.postbox.mediaBox.completedResourcePath(telegramFile.resource) != nil
                                        }
                                    } else if (telegramFile.isVideo && !telegramFile.isAnimated) && item.context.sharedContext.energyUsageSettings.autoplayVideo {
                                        if case .full = automaticDownload {
                                            automaticPlayback = true
                                        } else {
                                            automaticPlayback = item.context.account.postbox.mediaBox.completedResourcePath(telegramFile.resource) != nil
                                        }
                                    }
                                }
                                contentMode = .aspectFill
                            }
                        }
                    } else if let telegramFile = media as? TelegramMediaFile {
                        selectedMedia = telegramFile
                        if shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: telegramFile) {
                            automaticDownload = .full
                        } else if shouldPredownloadMedia(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, media: telegramFile) {
                            automaticDownload = .prefetch
                        }
                        
                        if !item.message.containsSecretMedia {
                            if telegramFile.isAnimated && item.context.sharedContext.energyUsageSettings.autoplayGif {
                                if case .full = automaticDownload {
                                    automaticPlayback = true
                                } else {
                                    automaticPlayback = item.context.account.postbox.mediaBox.completedResourcePath(telegramFile.resource) != nil
                                }
                            } else if (telegramFile.isVideo && !telegramFile.isAnimated) && item.context.sharedContext.energyUsageSettings.autoplayVideo {
                                if let _ = telegramFile.videoCover {
                                    automaticPlayback = false
                                } else if NativeVideoContent.isHLSVideo(file: telegramFile) {
                                    automaticPlayback = true
                                } else if case .full = automaticDownload {
                                    automaticPlayback = true
                                } else {
                                    automaticPlayback = item.context.account.postbox.mediaBox.completedResourcePath(telegramFile.resource) != nil
                                }
                            }
                        }
                        contentMode = .aspectFill
                    } else if let invoice = media as? TelegramMediaInvoice {
                        selectedMedia = invoice
                        extendedMedia = invoice.extendedMedia
                    } else if let paidContent = media as? TelegramMediaPaidContent {
                        selectedMedia = paidContent
                        if case let .mosaic(_, _, index) = preparePosition, let index {
                            extendedMedia = paidContent.extendedMedia[index]
                            selectedMediaIndex = index
                        } else {
                            extendedMedia = paidContent.extendedMedia.first
                        }
                    } else if let webFile = media as? TelegramMediaWebFile {
                        selectedMedia = webFile
                        if item.presentationData.isPreview {
                            automaticDownload = .full
                        }
                    }
                }
            }
                        
            if let extendedMedia, case let .full(media) = extendedMedia {
                if let telegramImage = media as? TelegramMediaImage {
                    if shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: telegramImage) {
                        automaticDownload = .full
                    }
                } else if let telegramFile = media as? TelegramMediaFile {
                    if shouldDownloadMediaAutomatically(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, authorPeerId: item.message.author?.id, contactsPeerIds: item.associatedData.contactsPeerIds, media: telegramFile) {
                        automaticDownload = .full
                    } else if shouldPredownloadMedia(settings: item.controllerInteraction.automaticMediaDownloadSettings, peerType: item.associatedData.automaticDownloadPeerType, networkType: item.associatedData.automaticDownloadNetworkType, media: telegramFile) {
                        automaticDownload = .prefetch
                    }
                    
                    if !item.message.containsSecretMedia {
                        if telegramFile.isAnimated && item.context.sharedContext.energyUsageSettings.autoplayGif {
                            if case .full = automaticDownload {
                                automaticPlayback = true
                            } else {
                                automaticPlayback = item.context.account.postbox.mediaBox.completedResourcePath(telegramFile.resource) != nil
                            }
                        } else if (telegramFile.isVideo && !telegramFile.isAnimated) && item.context.sharedContext.energyUsageSettings.autoplayVideo {
                            if let _ = telegramFile.videoCover {
                                automaticPlayback = false
                            } else if NativeVideoContent.isHLSVideo(file: telegramFile) {
                                automaticPlayback = true
                            } else if case .full = automaticDownload {
                                automaticPlayback = true
                            } else {
                                automaticPlayback = item.context.account.postbox.mediaBox.completedResourcePath(telegramFile.resource) != nil
                            }
                        }
                    }
                    contentMode = .aspectFill
                }
            }
            
            var hasReplyMarkup: Bool = false
            for attribute in item.message.attributes {
                if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    var isExtendedMedia = false
                    for media in item.message.media {
                        if let invoice = media as? TelegramMediaInvoice, let _ = invoice.extendedMedia {
                            isExtendedMedia = true
                            break
                        }
                    }
                    if isExtendedMedia {
                        var updatedRows: [ReplyMarkupRow] = []
                        for row in attribute.rows {
                            let updatedButtons = row.buttons.filter { button in
                                if case .payment = button.action {
                                    return false
                                } else {
                                    return true
                                }
                            }
                            if !updatedButtons.isEmpty {
                                updatedRows.append(ReplyMarkupRow(buttons: updatedButtons))
                            }
                        }
                        if !updatedRows.isEmpty {
                            hasReplyMarkup = true
                        }
                    } else {
                        hasReplyMarkup = true
                    }
                    break
                }
            }
            
            let bubbleInsets: UIEdgeInsets
            let sizeCalculation: InteractiveMediaNodeSizeCalculation
            
            switch preparePosition {
                case .linear:
                    if case .color = item.presentationData.theme.wallpaper {
                        let colors: PresentationThemeBubbleColorComponents
                        if item.message.effectivelyIncoming(item.context.account.peerId) {
                            colors = item.presentationData.theme.theme.chat.message.incoming.bubble.withoutWallpaper
                        } else {
                            colors = item.presentationData.theme.theme.chat.message.outgoing.bubble.withoutWallpaper
                        }
                        if colors.fill[0] == colors.stroke || colors.stroke.alpha.isZero {
                            bubbleInsets = UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
                        } else {
                            bubbleInsets = layoutConstants.bubble.strokeInsets
                        }
                    } else {
                        bubbleInsets = layoutConstants.image.bubbleInsets
                    }
                    
                    sizeCalculation = .constrained(CGSize(width: max(0.0, constrainedSize.width - bubbleInsets.left - bubbleInsets.right), height: constrainedSize.height))
                case .mosaic:
                    bubbleInsets = UIEdgeInsets()
                    sizeCalculation = .unconstrained
            }

            var edited = false
            if item.attributes.updatingMedia != nil {
                edited = true
            }
            var viewCount: Int?
            var dateReplies = 0
            var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.message)
            if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                dateReactionsAndPeers = ([], [])
            }
            for attribute in item.message.attributes {
                if let attribute = attribute as? EditedMessageAttribute {
                    if case .mosaic = preparePosition {
                    } else {
                        edited = !attribute.isHidden
                    }
                } else if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = attribute.count
                } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                    if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                        dateReplies = Int(attribute.count)
                    }
                }
            }
            
            let dateFormat: MessageTimestampStatusFormat
            if item.presentationData.isPreview {
                dateFormat = .full
            } else {
                dateFormat = .regular
            }
            let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)

            let statusType: ChatMessageDateAndStatusType?
            if case .customChatContents = item.associatedData.subject {
                statusType = nil
            } else if item.message.timestamp == 0 {
                statusType = nil
            } else {
                switch preparePosition {
                case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                    if item.message.effectivelyIncoming(item.context.account.peerId) {
                        statusType = .ImageIncoming
                    } else {
                        if item.message.flags.contains(.Failed) {
                            statusType = .ImageOutgoing(.Failed)
                        } else if (item.message.flags.isSending && !item.message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                            statusType = .ImageOutgoing(.Sending)
                        } else {
                            statusType = .ImageOutgoing(.Sent(read: item.read))
                        }
                    }
                case .mosaic:
                    statusType = nil
                default:
                    statusType = nil
                }
            }

            var isReplyThread = false
            if case .replyThread = item.chatLocation {
                isReplyThread = true
            }

            let dateAndStatus = statusType.flatMap { statusType -> ChatMessageDateAndStatus in
                ChatMessageDateAndStatus(
                    type: statusType,
                    edited: edited,
                    viewCount: viewCount,
                    dateReactions: dateReactionsAndPeers.reactions,
                    dateReactionPeers: dateReactionsAndPeers.peers,
                    dateReplies: dateReplies,
                    isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                    dateText: dateText
                )
            }
            
            let (unboundSize, initialWidth, refineLayout) = interactiveImageLayout(item.context, item.presentationData, item.presentationData.dateTimeFormat, item.message, item.associatedData, item.attributes, selectedMedia!, selectedMediaIndex, dateAndStatus, automaticDownload, item.associatedData.automaticDownloadPeerType, item.associatedData.automaticDownloadPeerId, sizeCalculation, layoutConstants, contentMode, item.controllerInteraction.presentationContext)
            
            let forceFullCorners = false
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 7.0, hidesBackground: .emptyWallpaper, forceFullCorners: forceFullCorners, forceAlignment: .none)
            
            return (contentProperties, unboundSize, initialWidth + bubbleInsets.left + bubbleInsets.right, { constrainedSize, position in
                var wideLayout = true
                if case let .mosaic(_, wide) = position {
                    wideLayout = wide
                    automaticPlayback = automaticPlayback && wide
                }
                
                var updatedPosition: ChatMessageBubbleContentPosition = position
                if forceFullCorners, case .linear = updatedPosition {
                    updatedPosition = .linear(top: .None(.None(.None)), bottom: .None(.None(.None)))
                } else if hasReplyMarkup, case let .linear(top, _) = updatedPosition {
                    updatedPosition = .linear(top: top, bottom: .BubbleNeighbour)
                }
                
                let imageCorners = chatMessageBubbleImageContentCorners(relativeContentPosition: updatedPosition, normalRadius: layoutConstants.image.defaultCornerRadius, mergedRadius: layoutConstants.image.mergedCornerRadius, mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius, layoutConstants: layoutConstants, chatPresentationData: item.presentationData)
                
                let (refinedWidth, finishLayout) = refineLayout(CGSize(width: constrainedSize.width - bubbleInsets.left - bubbleInsets.right, height: constrainedSize.height), automaticPlayback, wideLayout, imageCorners)
                
                return (refinedWidth + bubbleInsets.left + bubbleInsets.right, { boundingWidth in
                    let (imageSize, imageApply) = finishLayout(boundingWidth - bubbleInsets.left - bubbleInsets.right)
                    
                    let imageLayoutSize = CGSize(width: imageSize.width + bubbleInsets.left + bubbleInsets.right, height: imageSize.height + bubbleInsets.top + bubbleInsets.bottom)
                    
                    let layoutWidth = imageLayoutSize.width
                    
                    let layoutSize = CGSize(width: layoutWidth, height: imageLayoutSize.height)
                    
                    return (layoutSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            strongSelf.media = selectedMedia
                            strongSelf.mediaIndex = selectedMediaIndex
                            strongSelf.automaticPlayback = automaticPlayback
                            
                            let imageFrame = CGRect(origin: CGPoint(x: bubbleInsets.left, y: bubbleInsets.top), size: imageSize)
                            
                            animation.animator.updateFrame(layer: strongSelf.interactiveImageNode.layer, frame: imageFrame, completion: nil)
                            
                            imageApply(animation, synchronousLoads)
                            
                            if let selection = selection {
                                if let selectionNode = strongSelf.selectionNode {
                                    selectionNode.frame = imageFrame
                                    selectionNode.updateSelected(selection, animated: animation.isAnimated)
                                } else {
                                    let selectionNode = GridMessageSelectionNode(theme: item.presentationData.theme.theme, toggle: { value in
                                        item.controllerInteraction.toggleMessagesSelection([item.message.id], value)
                                    })
                                    strongSelf.selectionNode = selectionNode
                                    strongSelf.addSubnode(selectionNode)
                                    selectionNode.frame = imageFrame
                                    selectionNode.updateSelected(selection, animated: false)
                                    if animation.isAnimated {
                                        selectionNode.animateIn()
                                    }
                                }
                            } else if let selectionNode = strongSelf.selectionNode {
                                strongSelf.selectionNode = nil
                                if animation.isAnimated {
                                    selectionNode.animateOut(completion: { [weak selectionNode] in
                                        selectionNode?.removeFromSupernode()
                                    })
                                } else {
                                    selectionNode.removeFromSupernode()
                                }
                            }
                            
                            if let forwardInfo = item.message.forwardInfo, forwardInfo.flags.contains(.isImported) {
                                strongSelf.interactiveImageNode.dateAndStatusNode.pressed = {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    item.controllerInteraction.displayImportedMessageTooltip(strongSelf.interactiveImageNode.dateAndStatusNode)
                                }
                            }
                        }
                    })
                })
            })
        }
    }
    
    override public func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id == messageId, var currentMedia = self.media {
            if let invoice = currentMedia as? TelegramMediaInvoice, let extendedMedia = invoice.extendedMedia, case let .full(fullMedia) = extendedMedia {
                currentMedia = fullMedia
            }
            if let paidContent = currentMedia as? TelegramMediaPaidContent, case let .full(fullMedia) = paidContent.extendedMedia[self.mediaIndex ?? 0] {
                currentMedia = fullMedia
            }
            if currentMedia.isSemanticallyEqual(to: media) {
                return self.interactiveImageNode.transitionNode(adjustRect: adjustRect)
            }
        }
        return nil
    }
    
    override public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        var mediaHidden = false
        
        var currentMedia = self.media
        if let invoice = currentMedia as? TelegramMediaInvoice, let extendedMedia = invoice.extendedMedia, case let .full(fullMedia) = extendedMedia {
            currentMedia = fullMedia
        }
        if let paidContent = currentMedia as? TelegramMediaPaidContent, case let .full(fullMedia) = paidContent.extendedMedia[self.mediaIndex ?? 0] {
            currentMedia = fullMedia
        }
        if let currentMedia = currentMedia, let media = media {
            for item in media {
                if item.isSemanticallyEqual(to: currentMedia) {
                    mediaHidden = true
                    break
                }
            }
        }
        
        self.interactiveImageNode.isHidden = mediaHidden
        self.interactiveImageNode.updateIsHidden(mediaHidden)
        
        /*if let automaticPlayback = self.automaticPlayback {
            if !automaticPlayback {
                self.dateAndStatusNode.isHidden = false
            } else if self.dateAndStatusNode.isHidden != mediaHidden {
                if mediaHidden {
                    self.dateAndStatusNode.isHidden = true
                } else {
                    self.dateAndStatusNode.isHidden = false
                    self.dateAndStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }*/
        
        return mediaHidden
    }
    
    override public func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return self.interactiveImageNode.playMediaWithSound()
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.interactiveImageNode.ignoreTapActionAtPoint(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override public func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override public func updateHighlightedState(animated: Bool) -> Bool {
        guard let item = self.item else {
            return false
        }
        let highlighted = item.controllerInteraction.highlightedState?.messageStableId == item.message.stableId
        
        if self.highlightedState != highlighted {
            self.highlightedState = highlighted
            
            if highlighted {
                self.interactiveImageNode.setOverlayColor(item.presentationData.theme.theme.chat.message.mediaHighlightOverlayColor, animated: false)
            } else {
                self.interactiveImageNode.setOverlayColor(nil, animated: animated)
            }
        }
        
        return false
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.interactiveImageNode.dateAndStatusNode.isHidden {
            return self.interactiveImageNode.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if !self.interactiveImageNode.dateAndStatusNode.isHidden {
            return self.interactiveImageNode.dateAndStatusNode.messageEffectTargetView()
        }
        return nil
    }
    
    override public func getStatusNode() -> ASDisplayNode? {
        if !self.interactiveImageNode.dateAndStatusNode.isHidden {
            return self.interactiveImageNode.dateAndStatusNode
        }
        return nil
    }
}
