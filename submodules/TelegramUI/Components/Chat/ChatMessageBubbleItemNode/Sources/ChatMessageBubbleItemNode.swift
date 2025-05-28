import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import TemporaryCachedPeerDataManager
import LocalizedPeerData
import ContextUI
import TelegramUniversalVideoContent
import MosaicLayout
import TextSelectionNode
import PlatformRestrictionMatching
import Emoji
import PersistentStringHash
import GridMessageSelectionNode
import AppBundle
import Markdown
import WallpaperBackgroundNode
import ChatPresentationInterfaceState
import ChatMessageBackground
import AnimationCache
import MultiAnimationRenderer
import ComponentFlow
import EmojiStatusComponent
import ChatControllerInteraction
import ChatMessageForwardInfoNode
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ChatHistoryEntry
import ChatMessageTextBubbleContentNode
import ChatMessageItemCommon
import ChatMessageReplyInfoNode
import ChatMessageCallBubbleContentNode
import ChatMessageInteractiveFileNode
import ChatMessageFileBubbleContentNode
import ChatMessageWebpageBubbleContentNode
import ChatMessagePollBubbleContentNode
import ChatMessageItem
import ChatMessageItemView
import ChatMessageSwipeToReplyNode
import ChatMessageSelectionNode
import ChatMessageDeliveryFailedNode
import ChatMessageShareButton
import ChatMessageThreadInfoNode
import ChatMessageActionButtonsNode
import ChatSwipeToReplyRecognizer
import ChatMessageReactionsFooterContentNode
import ChatMessageInstantVideoBubbleContentNode
import ChatMessageCommentFooterContentNode
import ChatMessageActionBubbleContentNode
import ChatMessageContactBubbleContentNode
import ChatMessageEventLogPreviousDescriptionContentNode
import ChatMessageEventLogPreviousLinkContentNode
import ChatMessageEventLogPreviousMessageContentNode
import ChatMessageGameBubbleContentNode
import ChatMessageInvoiceBubbleContentNode
import ChatMessageMapBubbleContentNode
import ChatMessageMediaBubbleContentNode
import ChatMessageProfilePhotoSuggestionContentNode
import ChatMessageRestrictedBubbleContentNode
import ChatMessageStoryMentionContentNode
import ChatMessageUnsupportedBubbleContentNode
import ChatMessageWallpaperBubbleContentNode
import ChatMessageGiftBubbleContentNode
import ChatMessageGiveawayBubbleContentNode
import ChatMessageJoinedChannelBubbleContentNode
import ChatMessageFactCheckBubbleContentNode
import ChatMessageUnlockMediaNode
import ChatMessageStarsMediaInfoNode
import UIKitRuntimeUtils
import ChatMessageTransitionNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import LottieMetal
import AvatarNode

private struct BubbleItemAttributes {
    var index: Int?
    var isAttachment: Bool
    var neighborType: ChatMessageBubbleRelativePosition.NeighbourType
    var neighborSpacing: ChatMessageBubbleRelativePosition.NeighbourSpacing
    
    init(index: Int? = nil, isAttachment: Bool, neighborType: ChatMessageBubbleRelativePosition.NeighbourType, neighborSpacing: ChatMessageBubbleRelativePosition.NeighbourSpacing) {
        self.index = index
        self.isAttachment = isAttachment
        self.neighborType = neighborType
        self.neighborSpacing = neighborSpacing
    }
}

private final class ChatMessageBubbleClippingNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = self.view.hitTest(point, with: event)
        if result === self.view {
            return nil
        } else {
            return result
        }
    }
}

private func contentNodeMessagesAndClassesForItem(_ item: ChatMessageItem) -> ([(Message, AnyClass, ChatMessageEntryAttributes, BubbleItemAttributes)], Bool, Bool) {
    var result: [(Message, AnyClass, ChatMessageEntryAttributes, BubbleItemAttributes)] = []
    var skipText = false
    var messageWithCaptionToAdd: (Message, ChatMessageEntryAttributes)?
    var messageWithFactCheckToAdd: (Message, ChatMessageEntryAttributes)?
    var isUnsupportedMedia = false
    var isStoryWithText = false
    var isAction = false
    
    var previousItemIsFile = false
    var hasFiles = false
    
    var needReactions = true
    
    let hideAllAdditionalInfo = item.presentationData.isPreview
    
    var hasSeparateCommentsButton = false
    
    var addedPriceInfo = false
    
    outer: for (message, itemAttributes) in item.content {
        for attribute in message.attributes {
            if let attribute = attribute as? RestrictedContentMessageAttribute, attribute.platformText(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) != nil {
                result.append((message, ChatMessageRestrictedBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
                break outer
            } else if let _ = attribute as? PaidStarsMessageAttribute, !addedPriceInfo, message.id.peerId.namespace == Namespaces.Peer.CloudUser {
                result.append((message, ChatMessageActionBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                addedPriceInfo = true
            }
        }
        
        var messageMedia = message.media
        if let updatingMedia = itemAttributes.updatingMedia, messageMedia.isEmpty, case let .update(media) = updatingMedia.media {
            messageMedia.append(media.media)
        }
        
        var isFile = false
        inner: for media in messageMedia {
            if let media = media as? TelegramMediaPaidContent {
                var index = 0
                for _ in media.extendedMedia {
                    result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes, BubbleItemAttributes(index: index, isAttachment: false, neighborType: .media, neighborSpacing: .default)))
                    index += 1
                }
            } else if let _ = media as? TelegramMediaImage {
                if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported), message.text.isEmpty {
                    messageWithCaptionToAdd = (message, itemAttributes)
                }
                result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .media, neighborSpacing: .default)))
            } else if let _ = media as? TelegramMediaWebFile {
                result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .media, neighborSpacing: .default)))
            } else if let story = media as? TelegramMediaStory {
                if story.isMention {
                    if let storyItem = message.associatedStories[story.storyId], storyItem.data.isEmpty {
                        result.append((message, ChatMessageActionBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                    } else {
                        result.append((message, ChatMessageStoryMentionContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                    }
                } else {
                    var hideStory = false
                    if let peer = message.peers[story.storyId.peerId] as? TelegramChannel, peer.username == nil, peer.usernames.isEmpty {
                        switch peer.participationStatus {
                        case .member:
                            break
                        case .kicked, .left:
                            hideStory = true
                        }
                    }
                    
                    if !hideStory {
                        if let storyItem = message.associatedStories[story.storyId], storyItem.data.isEmpty {
                        } else {
                            result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .media, neighborSpacing: .default)))
                        }
                        
                        if let storyItem = message.associatedStories[story.storyId], let storedItem = storyItem.get(Stories.StoredItem.self), case let .item(item) = storedItem {
                            if !item.text.isEmpty {
                                isStoryWithText = true
                            }
                        }
                    }
                }
            } else if let file = media as? TelegramMediaFile {
                let isVideo = file.isVideo || (file.isAnimated && file.dimensions != nil)
                if isVideo {
                    if file.isInstantVideo {
                        hasSeparateCommentsButton = true
                        result.append((message, ChatMessageInstantVideoBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                    } else {
                        if let forwardInfo = message.forwardInfo, forwardInfo.flags.contains(.isImported), message.text.isEmpty {
                            messageWithCaptionToAdd = (message, itemAttributes)
                        }
                        result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .media, neighborSpacing: .default)))
                    }
                } else {
                    var neighborSpacing: ChatMessageBubbleRelativePosition.NeighbourSpacing = .default
                    if previousItemIsFile {
                        neighborSpacing = .overlap(file.isMusic ? 14.0 : 4.0)
                    }
                    isFile = true
                    hasFiles = true
                    result.append((message, ChatMessageFileBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: neighborSpacing)))
                    needReactions = false
                }
            } else if let action = media as? TelegramMediaAction {
                isAction = true
                if case .phoneCall = action.action {
                    result.append((message, ChatMessageCallBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .conferenceCall = action.action {
                    result.append((message, ChatMessageCallBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .giftPremium = action.action {
                    result.append((message, ChatMessageGiftBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .giftStars = action.action {
                    result.append((message, ChatMessageGiftBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .starGift = action.action {
                    result.append((message, ChatMessageGiftBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                    skipText = true
                } else if case .starGiftUnique = action.action {
                    result.append((message, ChatMessageGiftBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                    skipText = true
                } else if case .suggestedProfilePhoto = action.action {
                    result.append((message, ChatMessageProfilePhotoSuggestionContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .setChatWallpaper = action.action {
                    result.append((message, ChatMessageWallpaperBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .giftCode = action.action {
                    result.append((message, ChatMessageGiftBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .prizeStars = action.action {
                    result.append((message, ChatMessageGiftBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                } else if case .joinedChannel = action.action {
                    result.append((message, ChatMessageJoinedChannelBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                    needReactions = false
                } else {
                    if !canAddMessageReactions(message: message) {
                        needReactions = false
                    }
                    result.append((message, ChatMessageActionBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                }
            } else if let _ = media as? TelegramMediaMap {
                result.append((message, ChatMessageMapBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .media, neighborSpacing: .default)))
            } else if let _ = media as? TelegramMediaGame {
                skipText = true
                result.append((message, ChatMessageGameBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
                break inner
            } else if let invoice = media as? TelegramMediaInvoice {
                if let _ = invoice.extendedMedia {
                    result.append((message, ChatMessageMediaBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .media, neighborSpacing: .default)))
                } else {
                    skipText = true
                    result.append((message, ChatMessageInvoiceBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                }
                needReactions = false
                break inner
            } else if let _ = media as? TelegramMediaContact {
                result.append((message, ChatMessageContactBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
            } else if let _ = media as? TelegramMediaExpiredContent {
                result.removeAll()
                result.append((message, ChatMessageActionBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                return (result, false, true)
            } else if let _ = media as? TelegramMediaPoll {
                result.append((message, ChatMessagePollBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
            } else if let _ = media as? TelegramMediaGiveaway {
                result.append((message, ChatMessageGiveawayBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
            } else if let _ = media as? TelegramMediaGiveawayResults {
                result.append((message, ChatMessageGiveawayBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
            } else if let _ = media as? TelegramMediaUnsupported {
                isUnsupportedMedia = true
                needReactions = false
            }
            previousItemIsFile = isFile
        }
        
        var messageText = message.text
        if let updatingMedia = itemAttributes.updatingMedia {
            messageText = updatingMedia.text
        }
        
        if !messageText.isEmpty || isUnsupportedMedia || isStoryWithText {
            if !skipText {
                if case .group = item.content, !isFile {
                    messageWithCaptionToAdd = (message, itemAttributes)
                    skipText = true
                } else {
                    var isMediaInverted = false
                    if let updatingMedia = itemAttributes.updatingMedia {
                        isMediaInverted = updatingMedia.invertMediaAttribute != nil
                    } else if let _ = message.attributes.first(where: { $0 is InvertMediaMessageAttribute }) {
                        isMediaInverted = true
                    }
                    
                    if isMediaInverted {
                        result.insert((message, ChatMessageTextBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: isFile ? .condensed : .default)), at: addedPriceInfo ? 1 : 0)
                    } else {
                        result.append((message, ChatMessageTextBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: isFile ? .condensed : .default)))
                        needReactions = false
                    }
                }
            } else {
                if case .group = item.content {
                    messageWithCaptionToAdd = nil
                }
            }
        }
        
        if let attribute = message.factCheckAttribute, case .Loaded = attribute.content, messageWithFactCheckToAdd == nil {
            messageWithFactCheckToAdd = (message, itemAttributes)
        }
        
        inner: for media in message.media {
            if let webpage = media as? TelegramMediaWebpage {
                if case let .Loaded(content) = webpage.content {
                    if let story = content.story {
                        if let storyItem = message.associatedStories[story.storyId], !storyItem.data.isEmpty {
                        } else {
                            break inner
                        }
                    }
                    
                    if let attribute = message.attributes.first(where: { $0 is WebpagePreviewMessageAttribute }) as? WebpagePreviewMessageAttribute, attribute.leadingPreview {
                        result.insert((message, ChatMessageWebpageBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)), at: addedPriceInfo ? 1 : 0)
                    } else {
                        result.append((message, ChatMessageWebpageBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                    }
                    needReactions = false
                }
                break inner
            }
        }
        
        if message.adAttribute != nil {
            result.removeAll()

            result.append((message, ChatMessageWebpageBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
            needReactions = false
        }
        
        if isUnsupportedMedia {
            result.append((message, ChatMessageUnsupportedBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
            needReactions = false
        }
    }
    
    if let (messageWithCaptionToAdd, itemAttributes) = messageWithCaptionToAdd {
        var isMediaInverted = false
        if let updatingMedia = itemAttributes.updatingMedia {
            isMediaInverted = updatingMedia.invertMediaAttribute != nil
        } else if let _ = messageWithCaptionToAdd.attributes.first(where: { $0 is InvertMediaMessageAttribute }) {
            isMediaInverted = true
        }
        
        if isMediaInverted {
            if result.isEmpty {
                needReactions = false
            }
            result.insert((messageWithCaptionToAdd, ChatMessageTextBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)), at: addedPriceInfo ? 1 : 0)
        } else {
            result.append((messageWithCaptionToAdd, ChatMessageTextBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
            needReactions = false
        }
    }
    
    if let (messageWithFactCheckToAdd, itemAttributes) = messageWithFactCheckToAdd, !hasSeparateCommentsButton {
        result.append((messageWithFactCheckToAdd, ChatMessageFactCheckBubbleContentNode.self, itemAttributes, BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
        needReactions = false
    }
    
    if let additionalContent = item.additionalContent {
        switch additionalContent {
            case let .eventLogPreviousMessage(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousMessageContentNode.self, ChatMessageEntryAttributes(), BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
            case let .eventLogPreviousDescription(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousDescriptionContentNode.self, ChatMessageEntryAttributes(), BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
            case let .eventLogPreviousLink(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousLinkContentNode.self, ChatMessageEntryAttributes(), BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)))
                needReactions = false
            case .eventLogGroupedMessages:
                break
        }
    }
    
    let firstMessage = item.content.firstMessage
    
    let reactionsAreInline: Bool
    reactionsAreInline = shouldDisplayInlineDateReactions(message: firstMessage, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions)
    if reactionsAreInline {
        needReactions = false
    }
    
    if !isAction && !hasSeparateCommentsButton && !Namespaces.Message.allNonRegular.contains(firstMessage.id.namespace) && !hideAllAdditionalInfo {
        if hasCommentButton(item: item) {
            result.append((firstMessage, ChatMessageCommentFooterContentNode.self, ChatMessageEntryAttributes(), BubbleItemAttributes(isAttachment: true, neighborType: .footer, neighborSpacing: .default)))
        }
    }
    
    if !reactionsAreInline && !hideAllAdditionalInfo, let reactionsAttribute = mergedMessageReactions(attributes: firstMessage.attributes, isTags: firstMessage.areReactionsTags(accountPeerId: item.context.account.peerId)), !reactionsAttribute.reactions.isEmpty {
        if result.last?.1 == ChatMessageTextBubbleContentNode.self {
        } else {
            if result.last?.1 == ChatMessagePollBubbleContentNode.self ||
               result.last?.1 == ChatMessageContactBubbleContentNode.self ||
               result.last?.1 == ChatMessageGameBubbleContentNode.self ||
               result.last?.1 == ChatMessageInvoiceBubbleContentNode.self ||
               result.last?.1 == ChatMessageGiveawayBubbleContentNode.self {
                result.append((firstMessage, ChatMessageReactionsFooterContentNode.self, ChatMessageEntryAttributes(), BubbleItemAttributes(isAttachment: true, neighborType: .reactions, neighborSpacing: .default)))
                needReactions = false
            } else if result.last?.1 == ChatMessageCommentFooterContentNode.self {
                if result.count >= 2 {
                    if result[result.count - 2].1 == ChatMessagePollBubbleContentNode.self ||
                        result[result.count - 2].1 == ChatMessageContactBubbleContentNode.self ||
                        result[result.count - 2].1 == ChatMessageGiveawayBubbleContentNode.self {
                        result.insert((firstMessage, ChatMessageReactionsFooterContentNode.self, ChatMessageEntryAttributes(), BubbleItemAttributes(isAttachment: true, neighborType: .reactions, neighborSpacing: .default)), at: result.count - 1)
                    }
                }
            }
        }
    }
    
    var needSeparateContainers = false
    if case .group = item.content, hasFiles {
        needSeparateContainers = true
        needReactions = false
    }
    
    return (result, needSeparateContainers, needReactions)
}

private enum ContentNodeOperation {
    case remove(index: Int)
    case insert(index: Int, node: ChatMessageBubbleContentNode)
}

private func mapVisibility(_ visibility: ListViewItemNodeVisibility, boundsSize: CGSize, insets: UIEdgeInsets, to contentNode: ChatMessageBubbleContentNode) -> ListViewItemNodeVisibility {
    switch visibility {
    case .none:
        return .none
    case let .visible(fraction, subRect):
        var subRect = subRect
        subRect.origin.x = 0.0
        subRect.size.width = 10000.0
        
        subRect.origin.y = boundsSize.height - insets.bottom - (subRect.origin.y + subRect.height)
        
        let contentNodeFrame = contentNode.frame
        if contentNodeFrame.intersects(subRect) {
            let intersectionRect = contentNodeFrame.intersection(subRect)
            return .visible(fraction, intersectionRect.offsetBy(dx: 0.0, dy: -contentNodeFrame.minY))
        } else {
            return .visible(fraction, CGRect())
        }
    }
}

public class ChatMessageBubbleItemNode: ChatMessageItemView, ChatMessagePreviewItemNode {
    public class ContentContainer {
        public let contentMessageStableId: UInt32
        public let sourceNode: ContextExtractedContentContainingNode
        public let containerNode: ContextControllerSourceNode
        public var backgroundWallpaperNode: ChatMessageBubbleBackdrop?
        public var backgroundNode: ChatMessageBackground?
        public var selectionBackgroundNode: ASDisplayNode?
        
        private var currentParams: (size: CGSize, contentOrigin: CGPoint, presentationData: ChatPresentationData, graphics: PrincipalThemeEssentialGraphics, backgroundType: ChatMessageBackgroundType, presentationContext: ChatPresentationContext, mediaBox: MediaBox, messageSelection: Bool?, selectionInsets: UIEdgeInsets)?
        
        public init(contentMessageStableId: UInt32) {
            self.contentMessageStableId = contentMessageStableId
            
            self.sourceNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
        }
        
        fileprivate var absoluteRect: (CGRect, CGSize)?
        fileprivate func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
            self.absoluteRect = (rect, containerSize)
            guard let backgroundWallpaperNode = self.backgroundWallpaperNode else {
                return
            }
            guard !self.sourceNode.isExtractedToContextPreview else {
                return
            }
            let mappedRect = CGRect(origin: CGPoint(x: rect.minX + backgroundWallpaperNode.frame.minX, y: rect.minY + backgroundWallpaperNode.frame.minY), size: rect.size)
            backgroundWallpaperNode.update(rect: mappedRect, within: containerSize)
        }
        
        fileprivate func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
            guard let backgroundWallpaperNode = self.backgroundWallpaperNode else {
                return
            }
            backgroundWallpaperNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
        
        fileprivate func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
            guard let backgroundWallpaperNode = self.backgroundWallpaperNode else {
                return
            }
            backgroundWallpaperNode.offsetSpring(value: value, duration: duration, damping: damping)
        }
        
        fileprivate func willUpdateIsExtractedToContextPreview(isExtractedToContextPreview: Bool, transition: ContainedViewLayoutTransition) {
            if isExtractedToContextPreview {
                var offset: CGFloat = 0.0
                var inset: CGFloat = 0.0
                var type: ChatMessageBackgroundType
                if let currentParams = self.currentParams, case .incoming = currentParams.backgroundType {
                    type = .incoming(.Extracted)
                    offset = -5.0
                    inset = 5.0
                } else {
                    type = .outgoing(.Extracted)
                    inset = 5.0
                }
                
                if let _ = self.backgroundNode {
                } else if let currentParams = self.currentParams {
                    let backgroundWallpaperNode = ChatMessageBubbleBackdrop()
                    backgroundWallpaperNode.alpha = 0.0
                    
                    let backgroundNode = ChatMessageBackground()
                    backgroundNode.alpha = 0.0
                                        
                    self.sourceNode.contentNode.insertSubnode(backgroundNode, at: 0)
                    self.sourceNode.contentNode.insertSubnode(backgroundWallpaperNode, at: 0)
                    
                    self.backgroundWallpaperNode = backgroundWallpaperNode
                    self.backgroundNode = backgroundNode
                    
                    transition.updateAlpha(node: backgroundNode, alpha: 1.0)
                    transition.updateAlpha(node: backgroundWallpaperNode, alpha: 1.0)
                    
                    backgroundNode.setType(type: type, highlighted: false, graphics: currentParams.graphics, maskMode: true, hasWallpaper: currentParams.presentationData.theme.wallpaper.hasWallpaper, transition: .immediate, backgroundNode: currentParams.presentationContext.backgroundNode)
                    backgroundWallpaperNode.setType(type: type, theme: currentParams.presentationData.theme, essentialGraphics: currentParams.graphics, maskMode: true, backgroundNode: currentParams.presentationContext.backgroundNode)
                }
                
                if let currentParams = self.currentParams {
                    let backgroundFrame = CGRect(x: currentParams.contentOrigin.x + offset, y: 0.0, width: currentParams.size.width + inset, height: currentParams.size.height)
                    self.backgroundNode?.updateLayout(size: backgroundFrame.size, transition: .immediate)
                    self.backgroundNode?.frame = backgroundFrame
                    self.backgroundWallpaperNode?.frame = backgroundFrame
                    
                    if let (rect, containerSize) = self.absoluteRect {
                        let mappedRect = CGRect(origin: CGPoint(x: rect.minX + backgroundFrame.minX, y: rect.minY + backgroundFrame.minY), size: rect.size)
                        self.backgroundWallpaperNode?.update(rect: mappedRect, within: containerSize)
                    }
                }
            } else {
                if let backgroundNode = self.backgroundNode {
                    self.backgroundNode = nil
                    transition.updateAlpha(node: backgroundNode, alpha: 0.0, completion: { [weak backgroundNode] _ in
                        backgroundNode?.removeFromSupernode()
                    })
                }
                if let backgroundWallpaperNode = self.backgroundWallpaperNode {
                    self.backgroundWallpaperNode = nil
                    transition.updateAlpha(node: backgroundWallpaperNode, alpha: 0.0, completion: { [weak backgroundWallpaperNode] _ in
                        backgroundWallpaperNode?.removeFromSupernode()
                    })
                }
            }
        }
        
        fileprivate func isExtractedToContextPreviewUpdated(_ isExtractedToContextPreview: Bool) {
        }
        
        fileprivate func update(size: CGSize, contentOrigin: CGPoint, selectionInsets: UIEdgeInsets, index: Int, presentationData: ChatPresentationData, graphics: PrincipalThemeEssentialGraphics, backgroundType: ChatMessageBackgroundType, presentationContext: ChatPresentationContext, mediaBox: MediaBox, messageSelection: Bool?) {
            self.currentParams = (size, contentOrigin, presentationData, graphics, backgroundType, presentationContext, mediaBox, messageSelection, selectionInsets)
            let bounds = CGRect(origin: CGPoint(), size: size)
            
            var incoming: Bool = false
            if case .incoming = backgroundType {
                incoming = true
            }
            
            let messageTheme = incoming ? presentationData.theme.theme.chat.message.incoming : presentationData.theme.theme.chat.message.outgoing
            
            if let messageSelection = messageSelection, messageSelection {
                if let _ = self.selectionBackgroundNode {
                } else {
                    let selectionBackgroundNode = ASDisplayNode()
                    self.containerNode.insertSubnode(selectionBackgroundNode, at: 0)
                    self.selectionBackgroundNode = selectionBackgroundNode
                }
                
                var selectionBackgroundFrame = bounds.offsetBy(dx: contentOrigin.x, dy: 0.0)
                if index == 0 && contentOrigin.y > 0.0 {
                    selectionBackgroundFrame.origin.y -= contentOrigin.y
                    selectionBackgroundFrame.size.height += contentOrigin.y
                }
                selectionBackgroundFrame = selectionBackgroundFrame.inset(by: selectionInsets)
                
                let bubbleColor = graphics.hasWallpaper ? messageTheme.bubble.withWallpaper.fill : messageTheme.bubble.withoutWallpaper.fill
                let selectionColor = bubbleColor[0].withAlphaComponent(1.0).mixedWith(messageTheme.accentTextColor.withAlphaComponent(1.0), alpha: 0.08)
                
                self.selectionBackgroundNode?.backgroundColor = selectionColor
                self.selectionBackgroundNode?.frame = selectionBackgroundFrame
            } else if let selectionBackgroundNode = self.selectionBackgroundNode {
                self.selectionBackgroundNode = nil
                selectionBackgroundNode.removeFromSupernode()
            }
        }
    }
     
    public let mainContextSourceNode: ContextExtractedContentContainingNode
    private let mainContainerNode: ContextControllerSourceNode
    private let backgroundWallpaperNode: ChatMessageBubbleBackdrop
    private let backgroundNode: ChatMessageBackground
    private var backgroundHighlightNode: ChatMessageBackground?
    private let shadowNode: ChatMessageShadowNode
    private var clippingNode: ChatMessageBubbleClippingNode
    
    override public var extractedBackgroundNode: ASDisplayNode? {
        return self.shadowNode
    }
    
    private var selectionNode: ChatMessageSelectionNode?
    private var deliveryFailedNode: ChatMessageDeliveryFailedNode?
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var nameAvatarNode: AvatarNode?
    private var nameNode: TextNode?
    private var nameButtonNode: HighlightTrackingButtonNode?
    private var nameHighlightNode: ASImageNode?
    private var viaMeasureNode: TextNode?
    private var nameNavigateButton: NameNavigateButton?
    
    private var adminBadgeNode: TextNode?
    private var credibilityIconView: ComponentHostView<Empty>?
    private var credibilityIconComponent: EmojiStatusComponent?
    private var credibilityIconContent: EmojiStatusComponent.Content?
    private var credibilityButtonNode: HighlightTrackingButtonNode?
    private var credibilityHighlightNode: ASImageNode?
    
    private var boostBadgeNode: TextNode?
    private var boostIconNode: UIImageView?
    private var boostCount: Int = 0
    
    private var boostButtonNode: HighlightTrackingButtonNode?
    private var boostHighlightNode: ASImageNode?
    
    private var closeButtonNode: HighlightTrackingButtonNode?
    private var closeIconNode: ASImageNode?
    
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    public var forwardInfoReferenceNode: ASDisplayNode? {
        return self.forwardInfoNode
    }
    
    private var threadInfoNode: ChatMessageThreadInfoNode?
    private var replyInfoNode: ChatMessageReplyInfoNode?
    
    private var contentContainersWrapperNode: ASDisplayNode
    private var contentContainers: [ContentContainer] = []
    public private(set) var contentNodes: [ChatMessageBubbleContentNode] = []
    private var mosaicStatusNode: ChatMessageDateAndStatusNode?
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    private var reactionButtonsNode: ChatMessageReactionButtonsNode?
    
    private var unlockButtonNode: ChatMessageUnlockMediaNode?
    private var mediaInfoNode: ChatMessageStarsMediaInfoNode?
    
    private var shareButtonNode: ChatMessageShareButton?
    
    private let messageAccessibilityArea: AccessibilityAreaNode

    private var backgroundType: ChatMessageBackgroundType?
    
    private struct HighlightedState: Equatable {
        var quote: ChatInterfaceHighlightedState.Quote?
    }
    private var highlightedState: HighlightedState?
    
    private var backgroundFrameTransition: (CGRect, CGRect)?
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    private var appliedItem: ChatMessageItem?
    private var appliedForwardInfo: (Peer?, String?)?
    private var disablesComments = true
    
    private var wasPending: Bool = false
    private var didChangeFromPendingToSent: Bool = false
    
    private var authorNameColor: UIColor?
    
    private var tapRecognizer: TapLongTapOrDoubleTapGestureRecognizer?
    
    private var replyRecognizer: ChatSwipeToReplyRecognizer?
    private var currentSwipeAction: ChatControllerInteractionSwipeAction?
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if self.visibility != oldValue {
                self.visibilityStatus = self.visibility != .none
                
                self.updateVisibility()
            }
        }
    }
    
    private var visibilityStatus: Bool = false {
        didSet {
            if self.visibilityStatus != oldValue {
                if let credibilityIconView = self.credibilityIconView, let credibilityIconComponent = self.credibilityIconComponent {
                    let _ = credibilityIconView.update(
                        transition: .immediate,
                        component: AnyComponent(credibilityIconComponent.withVisibleForAnimations(self.visibilityStatus)),
                        environment: {},
                        containerSize: credibilityIconView.bounds.size
                    )
                }
            }
        }
    }
    
    private var forceStopAnimations: Bool = false
    
    typealias Params = (item: ChatMessageItem, params: ListViewItemLayoutParams, mergedTop: ChatMessageMerge, mergedBottom: ChatMessageMerge, dateHeaderAtBottom: ChatMessageHeaderSpec)
    private var currentInputParams: Params?
    private var currentApplyParams: ListViewItemApply?
    
    required public init(rotated: Bool) {
        self.mainContextSourceNode = ContextExtractedContentContainingNode()
        self.mainContainerNode = ContextControllerSourceNode()
        self.backgroundWallpaperNode = ChatMessageBubbleBackdrop()
        self.contentContainersWrapperNode = ASDisplayNode()
        
        self.backgroundNode = ChatMessageBackground()
        self.backgroundNode.backdropNode = self.backgroundWallpaperNode
        self.shadowNode = ChatMessageShadowNode()

        self.clippingNode = ChatMessageBubbleClippingNode()
        self.clippingNode.clipsToBounds = false

        self.messageAccessibilityArea = AccessibilityAreaNode()
        
        //self.debugNode = ASDisplayNode()
        //self.debugNode.backgroundColor = .blue
        
        super.init(rotated: rotated)
        
        //self.addSubnode(self.debugNode)
        
        self.mainContainerNode.shouldBeginWithCustomActivationProcess = { [weak self] location in
            guard let strongSelf = self else {
                return .none
            }
            if !strongSelf.backgroundNode.frame.contains(location) {
                return .none
            }
            if strongSelf.selectionNode != nil {
                return .none
            }
            if let action = strongSelf.gestureRecognized(gesture: .tap, location: location, recognizer: nil) {
                if case let .action(action) = action, !action.contextMenuOnLongPress {
                    return .none
                }
            }
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: location, recognizer: nil) {
                switch action {
                case .action:
                    return .none
                case .optionalAction:
                    return .none
                case let .openContextMenu(openContextMenu):
                    if openContextMenu.selectAll || strongSelf.contentContainers.count < 2 {
                        if openContextMenu.disableDefaultPressAnimation {
                            return .customActivationProcess
                        } else {
                            return .default
                        }
                    } else {
                        return .none
                    }
                }
            }
            return .default
        }
        
        self.mainContainerNode.activated = { [weak self] gesture, location in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: location, recognizer: nil) {
                switch action {
                case .action, .optionalAction:
                    break
                case let .openContextMenu(openContextMenu):
                    var tapMessage = openContextMenu.tapMessage
                    if openContextMenu.selectAll, case let .group(messages) = item.content, tapMessage.text.isEmpty {
                        for message in messages {
                            if !message.0.text.isEmpty {
                                tapMessage = message.0
                                break
                            }
                        }
                    }
                    item.controllerInteraction.openMessageContextMenu(tapMessage, openContextMenu.selectAll, strongSelf, openContextMenu.subFrame, gesture, nil)
                }
            }
        }
        
        self.mainContainerNode.addSubnode(self.mainContextSourceNode)
        self.mainContainerNode.targetNodeForActivationProgress = self.mainContextSourceNode.contentNode
        self.addSubnode(self.mainContainerNode)
        
        self.mainContextSourceNode.contentNode.addSubnode(self.backgroundWallpaperNode)
        self.mainContextSourceNode.contentNode.addSubnode(self.backgroundNode)
        self.mainContextSourceNode.contentNode.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.contentContainersWrapperNode)
        self.addSubnode(self.messageAccessibilityArea)
        
        self.messageAccessibilityArea.activate = { [weak self] in
            guard let strongSelf = self, let accessibilityData = strongSelf.accessibilityData else {
                return false
            }
            
            for node in strongSelf.contentNodes {
                if node.accessibilityActivate() {
                    return true
                }
            }
            
            if let singleUrl = accessibilityData.singleUrl {
                strongSelf.item?.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: singleUrl, concealed: false, external: false, message: strongSelf.item?.content.firstMessage))
                return true
            }
            
            return false
        }
        
        self.messageAccessibilityArea.focused = { [weak self] in
            self?.accessibilityElementDidBecomeFocused()
        }
        
        self.mainContextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtractedToContextPreview, _ in
            guard let self, let _ = self.item else {
                return
            }
            for contentNode in self.contentNodes {
                contentNode.willUpdateIsExtractedToContextPreview(isExtractedToContextPreview)
            }
        }
        self.mainContextSourceNode.isExtractedToContextPreviewUpdated = { [weak self] isExtractedToContextPreview in
            guard let self else {
                return
            }
            self.backgroundWallpaperNode.setMaskMode(self.backgroundMaskMode)
            self.backgroundNode.setMaskMode(self.backgroundMaskMode)
            if !isExtractedToContextPreview, let (rect, size) = self.absoluteRect {
                self.updateAbsoluteRect(rect, within: size)
            }
              
            for contentNode in self.contentNodes {
                contentNode.updateIsExtractedToContextPreview(isExtractedToContextPreview)
            }
            
            if !isExtractedToContextPreview {
                if let item = self.item {
                    item.controllerInteraction.forceUpdateWarpContents()
                }
            }
        }
        
        self.mainContextSourceNode.updateAbsoluteRect = { [weak self] rect, size in
            guard let strongSelf = self, strongSelf.mainContextSourceNode.isExtractedToContextPreview else {
                return
            }
            strongSelf.updateAbsoluteRectInternal(rect, within: size)
        }
        self.mainContextSourceNode.applyAbsoluteOffset = { [weak self] value, animationCurve, duration in
            guard let strongSelf = self, strongSelf.mainContextSourceNode.isExtractedToContextPreview else {
                return
            }
            strongSelf.applyAbsoluteOffsetInternal(value: value, animationCurve: animationCurve, duration: duration)
        }
        self.mainContextSourceNode.applyAbsoluteOffsetSpring = { [weak self] value, duration, damping in
            guard let strongSelf = self, strongSelf.mainContextSourceNode.isExtractedToContextPreview else {
                return
            }
            strongSelf.applyAbsoluteOffsetSpringInternal(value: value, duration: duration, damping: damping)
        }
    }
        
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }

    override public func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        if height.isLessThanOrEqualTo(0.0) {
            transition.updateFrame(node: self.mainContainerNode, frame: CGRect(origin: CGPoint(), size: self.mainContainerNode.bounds.size))
        } else {
            transition.updateFrame(node: self.mainContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -floorToScreenPixels(height / 2.0)), size: self.mainContainerNode.bounds.size))
        }
    }
    
    override public func cancelInsertionAnimations() {
        self.shadowNode.layer.removeAllAnimations()

        func process(node: ASDisplayNode) {
            if node === self.accessoryItemNode {
                return
            }

            if node !== self {
                switch node {
                case let node as ContextExtractedContentContainingNode:
                    process(node: node.contentNode)
                    return
                case _ as ContextControllerSourceNode, _ as ContextExtractedContentNode:
                    break
                default:
                    node.layer.removeAllAnimations()
                    node.layer.allowsGroupOpacity = false
                    return
                }
            }

            guard let subnodes = node.subnodes else {
                return
            }

            for subnode in subnodes {
                process(node: subnode)
            }
        }

        process(node: self)
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        super.animateInsertion(currentTimestamp, duration: duration, options: options)
        
        self.shadowNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        func process(node: ASDisplayNode) {
            if node === self.accessoryItemNode {
                return
            }
            
            if node !== self {
                switch node {
                case _ as ContextExtractedContentContainingNode, _ as ContextControllerSourceNode, _ as ContextExtractedContentNode:
                    break
                default:
                    node.layer.allowsGroupOpacity = true
                    node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak node] _ in
                        node?.layer.allowsGroupOpacity = false
                    })
                    return
                }
            }
            
            guard let subnodes = node.subnodes else {
                return
            }
            
            for subnode in subnodes {
                process(node: subnode)
            }
        }
        
        process(node: self)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.allowsGroupOpacity = true
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak self] _ in
            self?.allowsGroupOpacity = false
        })
        self.shadowNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
        self.layer.animateScale(from: 1.0, to: 0.1, duration: 0.15, removeOnCompletion: false)
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: self.bounds.width / 2.0 - self.backgroundNode.frame.midX, y: self.backgroundNode.frame.midY), duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                let layer = subnode.layer
                layer.allowsGroupOpacity = true
                layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak layer] _ in
                    layer?.allowsGroupOpacity = false
                })
            }
        }
    }
    
    public func animateFromLoadingPlaceholder(delay: Double, transition: ContainedViewLayoutTransition) {
        guard let item = self.item else {
            return
        }
                        
        let incoming = item.message.effectivelyIncoming(item.context.account.peerId)
        transition.animatePositionAdditive(node: self, offset: CGPoint(x: incoming ? 30.0 : -30.0, y: -30.0), delay: delay)
        transition.animateTransformScale(node: self, from: CGPoint(x: 0.85, y: 0.85), delay: delay)
    }
    
    public final class AnimationTransitionTextInput {
        let backgroundView: UIView
        let contentView: UIView
        let sourceRect: CGRect
        let scrollOffset: CGFloat

        public init(backgroundView: UIView, contentView: UIView, sourceRect: CGRect, scrollOffset: CGFloat) {
            self.backgroundView = backgroundView
            self.contentView = contentView
            self.sourceRect = sourceRect
            self.scrollOffset = scrollOffset
        }
    }

    public func animateContentFromTextInputField(textInput: AnimationTransitionTextInput, transition: CombinedTransition) {
        let widthDifference = self.backgroundNode.frame.width - textInput.backgroundView.frame.width
        let heightDifference = self.backgroundNode.frame.height - textInput.backgroundView.frame.height

        if let type = self.backgroundNode.type {
            if case .none = type {
            } else {
                self.clippingNode.clipsToBounds = true
            }
        }
        transition.animateFrame(layer: self.clippingNode.layer, from: CGRect(origin: CGPoint(x: self.clippingNode.frame.minX, y: textInput.backgroundView.frame.minY), size: textInput.backgroundView.frame.size), completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.clippingNode.clipsToBounds = false
        })

        transition.vertical.animateOffsetAdditive(layer: self.clippingNode.layer, offset: textInput.backgroundView.frame.minY - self.clippingNode.frame.minY)

        self.backgroundWallpaperNode.animateFrom(sourceView: textInput.backgroundView, transition: transition)
        self.backgroundNode.animateFrom(sourceView: textInput.backgroundView, transition: transition)

        for contentNode in self.contentNodes {
            if let contentNode = contentNode as? ChatMessageTextBubbleContentNode {
                let localSourceContentFrame = self.mainContextSourceNode.contentNode.view.convert(textInput.contentView.frame.offsetBy(dx: self.mainContextSourceNode.contentRect.minX, dy: self.mainContextSourceNode.contentRect.minY), to: contentNode.view)
                textInput.contentView.frame = localSourceContentFrame
                contentNode.animateFrom(sourceView: textInput.contentView, scrollOffset: textInput.scrollOffset, widthDifference: widthDifference, transition: transition)
            } else if let contentNode = contentNode as? ChatMessageWebpageBubbleContentNode {
                transition.vertical.animatePositionAdditive(node: contentNode, offset: CGPoint(x: 0.0, y: heightDifference))
            }
        }
    }
    
    public final class AnimationTransitionReplyPanel {
        public let titleNode: ASDisplayNode
        public let textNode: ASDisplayNode
        public let lineNode: ASDisplayNode
        public let imageNode: ASDisplayNode
        public let relativeSourceRect: CGRect
        public let relativeTargetRect: CGRect

        public init(titleNode: ASDisplayNode, textNode: ASDisplayNode, lineNode: ASDisplayNode, imageNode: ASDisplayNode, relativeSourceRect: CGRect, relativeTargetRect: CGRect) {
            self.titleNode = titleNode
            self.textNode = textNode
            self.lineNode = lineNode
            self.imageNode = imageNode
            self.relativeSourceRect = relativeSourceRect
            self.relativeTargetRect = relativeTargetRect
        }
    }

    public func animateReplyPanel(sourceReplyPanel: AnimationTransitionReplyPanel, transition: CombinedTransition) {
        if let replyInfoNode = self.replyInfoNode {
            let localRect = self.mainContextSourceNode.contentNode.view.convert(sourceReplyPanel.relativeSourceRect, to: replyInfoNode.view)
            let mappedPanel = ChatMessageReplyInfoNode.TransitionReplyPanel(
                titleNode: sourceReplyPanel.titleNode,
                textNode: sourceReplyPanel.textNode,
                lineNode: sourceReplyPanel.lineNode,
                imageNode: sourceReplyPanel.imageNode,
                relativeSourceRect: sourceReplyPanel.relativeSourceRect,
                relativeTargetRect: sourceReplyPanel.relativeTargetRect
            )
            let _ = replyInfoNode.animateFromInputPanel(sourceReplyPanel: mappedPanel, unclippedTransitionNode: self.mainContextSourceNode.contentNode, localRect: localRect, transition: transition)
        }
    }

    public func animateFromMicInput(micInputNode: UIView, transition: CombinedTransition) -> ContextExtractedContentContainingNode? {
        for contentNode in self.contentNodes {
            if let contentNode = contentNode as? ChatMessageFileBubbleContentNode {
                let statusContainerNode = contentNode.interactiveFileNode.statusContainerNode
                let scale = statusContainerNode.contentRect.height / 100.0
                micInputNode.transform = CGAffineTransform(scaleX: scale, y: scale)
                micInputNode.center = CGPoint(x: statusContainerNode.contentRect.midX, y: statusContainerNode.contentRect.midY)
                statusContainerNode.contentNode.view.addSubview(micInputNode)

                transition.horizontal.updateAlpha(layer: micInputNode.layer, alpha: 0.0, completion: { [weak micInputNode] _ in
                    micInputNode?.removeFromSuperview()
                })

                transition.horizontal.animateTransformScale(node: statusContainerNode.contentNode, from: 1.0 / scale)
                
                contentNode.interactiveFileNode.animateSent()

                return statusContainerNode
            }
        }
        return nil
    }

    public func animateContentFromMediaInput(snapshotView: UIView, transition: CombinedTransition) {
        self.mainContextSourceNode.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
    }
    
    public func animateContentFromGroupedMediaInput(transition: CombinedTransition) -> [CGRect] {
        self.mainContextSourceNode.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        
        var rects: [CGRect] = []
        for contentNode in self.contentNodes {
            if let contentNode = contentNode as? ChatMessageMediaBubbleContentNode {
                rects.append(contentNode.frame.offsetBy(dx: -self.clippingNode.frame.minX, dy: 0.0))
            }
        }
        return rects
    }
    
    public func animateInstantVideoFromSnapshot(snapshotView: UIView, transition: CombinedTransition) {
        for contentNode in self.contentNodes {
            if let contentNode = contentNode as? ChatMessageInstantVideoBubbleContentNode {
                snapshotView.frame = contentNode.interactiveVideoNode.view.convert(snapshotView.frame, from: self.view)
                contentNode.interactiveVideoNode.animateFromSnapshot(snapshotView: snapshotView, transition: transition)
                return
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let item = strongSelf.item, let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject {
                    if case let .link(link) = info {
                        let options = Atomic<ChatControllerSubject.LinkOptions?>(value: nil)
                        link.options.start(next: { value in
                            let _ = options.swap(value)
                        }).dispose()
                        guard let options = options.with({ $0 }) else {
                            return .fail
                        }
                        if !options.hasAlternativeLinks {
                            return .fail
                        }
                        
                        for contentNode in strongSelf.contentNodes {
                            let contentNodePoint = strongSelf.view.convert(point, to: contentNode.view)
                            let tapAction = contentNode.tapActionAtPoint(contentNodePoint, gesture: .tap, isEstimating: true)
                            switch tapAction.content {
                            case .none:
                                break
                            case .ignore:
                                return .fail
                            case .url:
                                return .waitForSingleTap
                            default:
                                break
                            }
                        }
                    }
                    
                    return .fail
                }

                if let closeButtonNode = strongSelf.closeButtonNode {
                    if let _ = closeButtonNode.hitTest(strongSelf.view.convert(point, to: closeButtonNode.view), with: nil) {
                        return .fail
                    }
                }
                
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
                }
                
                if let actionButtonsNode = strongSelf.actionButtonsNode {
                    if let _ = actionButtonsNode.hitTest(strongSelf.view.convert(point, to: actionButtonsNode.view), with: nil) {
                        return .fail
                    }
                }
                
                if let reactionButtonsNode = strongSelf.reactionButtonsNode {
                    if let _ = reactionButtonsNode.hitTest(strongSelf.view.convert(point, to: reactionButtonsNode.view), with: nil) {
                        return .fail
                    }
                }
                
                if let nameButtonNode = strongSelf.nameButtonNode, nameButtonNode.frame.contains(point) {
                    return .fail
                }
                
                if let credibilityButtonNode = strongSelf.credibilityButtonNode, credibilityButtonNode.frame.contains(point) {
                    return .fail
                }
                
                if let boostButtonNode = strongSelf.boostButtonNode, boostButtonNode.frame.contains(point) {
                    return .fail
                }
                                                
                if let nameNode = strongSelf.nameNode, nameNode.frame.contains(point) {
                    if let item = strongSelf.item {
                        for attribute in item.message.attributes {
                            if let _ = attribute as? InlineBotMessageAttribute {
                                return .waitForSingleTap
                            }
                        }
                    }
                }
                if let threadInfoNode = strongSelf.threadInfoNode, threadInfoNode.frame.contains(point) {
                    if let _ = threadInfoNode.hitTest(strongSelf.view.convert(point, to: threadInfoNode.view), with: nil) {
                        return .fail
                    }
                }
                if let replyInfoNode = strongSelf.replyInfoNode, replyInfoNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                if let unlockButtonNode = strongSelf.unlockButtonNode, unlockButtonNode.frame.contains(point) {
                    if let _ = unlockButtonNode.hitTest(strongSelf.view.convert(point, to: unlockButtonNode.view), with: nil) {
                        return .fail
                    }
                }
                if let forwardInfoNode = strongSelf.forwardInfoNode, forwardInfoNode.frame.contains(point) {
                    if forwardInfoNode.hasAction(at: strongSelf.view.convert(point, to: forwardInfoNode.view)) {
                        return .fail
                    } else {
                        return .waitForSingleTap
                    }
                }
                for contentNode in strongSelf.contentNodes {
                    let contentNodePoint = strongSelf.view.convert(point, to: contentNode.view)
                    let tapAction = contentNode.tapActionAtPoint(contentNodePoint, gesture: .tap, isEstimating: true)
                    switch tapAction.content {
                    case .none:
                        if let _ = strongSelf.item?.controllerInteraction.tapMessage {
                            return .waitForSingleTap
                        }
                        break
                    case .ignore:
                        return .fail
                    case .url, .phone, .peerMention, .textMention, .botCommand, .hashtag, .instantPage, .wallpaper, .theme, .call, .conferenceCall, .openMessage, .timecode, .bankCard, .tooltip, .openPollResults, .copy, .largeEmoji, .customEmoji, .custom:
                        return .waitForSingleTap
                    }
                }
                
                if !strongSelf.backgroundNode.frame.contains(point) {
                    return .waitForDoubleTap
                }
                
                if strongSelf.currentMessageEffect() != nil {
                    return .waitForDoubleTap
                }
            }
            
            return .waitForDoubleTap
        }
        recognizer.longTap = { [weak self] point, recognizer in
            guard let strongSelf = self else {
                return
            }

            if let action = strongSelf.gestureRecognized(gesture: .longTap, location: point, recognizer: recognizer) {
                switch action {
                case let .action(f):
                    f.action()
                    recognizer.cancel()
                case let .optionalAction(f):
                    f()
                    recognizer.cancel()
                case .openContextMenu:
                    break
                }
            }
        }
        recognizer.secondaryTap = { [weak self] point, recognizer in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }

            if let action = strongSelf.gestureRecognized(gesture: .secondaryTap, location: point, recognizer: recognizer) {
                switch action {
                case .action, .optionalAction:
                    break
                case let .openContextMenu(openContextMenu):
                    item.controllerInteraction.openMessageContextMenu(openContextMenu.tapMessage, openContextMenu.selectAll, strongSelf, openContextMenu.subFrame, nil, point)
                }
            }
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self, strongSelf.selectionNode == nil {
                if let replyInfoNode = strongSelf.replyInfoNode {
                    var translatedPoint: CGPoint?
                    let convertedNodeFrame = replyInfoNode.view.convert(replyInfoNode.bounds, to: strongSelf.view)
                    if let point = point, convertedNodeFrame.insetBy(dx: -4.0, dy: -4.0).contains(point) {
                        translatedPoint = strongSelf.view.convert(point, to: replyInfoNode.view)
                    }
                    replyInfoNode.updateTouchesAtPoint(translatedPoint)
                }
                if let forwardInfoNode = strongSelf.forwardInfoNode {
                    var translatedPoint: CGPoint?
                    let convertedNodeFrame = forwardInfoNode.view.convert(forwardInfoNode.bounds, to: strongSelf.view)
                    if let point = point, convertedNodeFrame.insetBy(dx: -4.0, dy: -4.0).contains(point) {
                        translatedPoint = strongSelf.view.convert(point, to: forwardInfoNode.view)
                    }
                    forwardInfoNode.updateTouchesAtPoint(translatedPoint)
                }
                for contentNode in strongSelf.contentNodes {
                    var translatedPoint: CGPoint?
                    let convertedNodeFrame = contentNode.view.convert(contentNode.bounds, to: strongSelf.view)
                    if let point = point, convertedNodeFrame.insetBy(dx: -4.0, dy: -4.0).contains(point) {
                        translatedPoint = strongSelf.view.convert(point, to: contentNode.view)
                    }
                    contentNode.updateTouchesAtPoint(translatedPoint)
                }
            }
        }
        self.tapRecognizer = recognizer
        self.view.addGestureRecognizer(recognizer)
        self.view.isExclusiveTouch = true

        let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
        if let item = self.item {
            let _ = item
            replyRecognizer.allowBothDirections = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
            self.view.disablesInteractiveTransitionGestureRecognizer = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        }
        replyRecognizer.shouldBegin = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if strongSelf.selectionNode != nil {
                    return false
                }
                for media in item.content.firstMessage.media {
                    if let _ = media as? TelegramMediaExpiredContent {
                        return false
                    }
                    else if let media = media as? TelegramMediaAction {
                        if case .phoneCall = media.action {
                        } else if case .conferenceCall = media.action {
                        } else {
                            return false
                        }
                    }
                }
                
                if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.isChannelPost, replyThreadMessage.peerId != item.content.firstMessage.id.peerId {
                    return false
                }
                
                let action = item.controllerInteraction.canSetupReply(item.message)
                strongSelf.currentSwipeAction = action
                if case .none = action {
                    return false
                } else {
                    return true
                }
            }
            return false
        }
        self.replyRecognizer = replyRecognizer
        self.view.addGestureRecognizer(replyRecognizer)
        
        if let item = self.item, let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject {
            if case .link = info {
            } else {
                self.tapRecognizer?.isEnabled = false
            }
            self.replyRecognizer?.isEnabled = false
        }
    }
    
    private func internalUpdateLayout() {
        if let inputParams = self.currentInputParams, let currentApplyParams = self.currentApplyParams {
            let (_, applyLayout) = self.asyncLayout()(inputParams.item, inputParams.params, inputParams.mergedTop, inputParams.mergedBottom, inputParams.dateHeaderAtBottom)
            applyLayout(.None, ListViewItemApply(isOnScreen: currentApplyParams.isOnScreen, timestamp: nil), false)
        }
    }
    
    override public func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: ChatMessageHeaderSpec) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
        var currentContentClassesPropertiesAndLayouts: [(Message, AnyClass, Bool, Int?, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))))] = []
        for contentNode in self.contentNodes {
            if let message = contentNode.item?.message {
                currentContentClassesPropertiesAndLayouts.append((message, type(of: contentNode) as AnyClass, contentNode.supportsMosaic, contentNode.index, contentNode.asyncLayoutContent()))
            } else {
                assertionFailure()
            }
        }
        
        let authorNameLayout = TextNode.asyncLayout(self.nameNode)
        let viaMeasureLayout = TextNode.asyncLayout(self.viaMeasureNode)
        let adminBadgeLayout = TextNode.asyncLayout(self.adminBadgeNode)
        let boostBadgeLayout = TextNode.asyncLayout(self.boostBadgeNode)
        let threadInfoLayout = ChatMessageThreadInfoNode.asyncLayout(self.threadInfoNode)
        let forwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let replyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        let reactionButtonsLayout = ChatMessageReactionButtonsNode.asyncLayout(self.reactionButtonsNode)
        let unlockButtonLayout = ChatMessageUnlockMediaNode.asyncLayout(self.unlockButtonNode)
        let mediaInfoLayout = ChatMessageStarsMediaInfoNode.asyncLayout(self.mediaInfoNode)
        
        let mosaicStatusLayout = ChatMessageDateAndStatusNode.asyncLayout(self.mosaicStatusNode)
        
        let layoutConstants = self.layoutConstants
        
        let currentItem = self.appliedItem
        let currentForwardInfo = self.appliedForwardInfo
        
        let isSelected = self.selectionNode?.selected
        
        let weakSelf = Weak(self)
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let layoutConstants = chatMessageItemLayoutConstants(layoutConstants, params: params, presentationData: item.presentationData)
            return ChatMessageBubbleItemNode.beginLayout(
                selfReference: weakSelf,
                item: item,
                params: params,
                mergedTop: mergedTop,
                mergedBottom: mergedBottom,
                dateHeaderAtBottom: dateHeaderAtBottom,
                currentContentClassesPropertiesAndLayouts: currentContentClassesPropertiesAndLayouts,
                authorNameLayout: authorNameLayout,
                viaMeasureLayout: viaMeasureLayout,
                adminBadgeLayout: adminBadgeLayout,
                boostBadgeLayout: boostBadgeLayout,
                threadInfoLayout: threadInfoLayout,
                forwardInfoLayout: forwardInfoLayout,
                replyInfoLayout: replyInfoLayout,
                actionButtonsLayout: actionButtonsLayout,
                reactionButtonsLayout: reactionButtonsLayout,
                unlockButtonLayout: unlockButtonLayout,
                mediaInfoLayout: mediaInfoLayout,
                mosaicStatusLayout: mosaicStatusLayout,
                layoutConstants: layoutConstants,
                currentItem: currentItem,
                currentForwardInfo: currentForwardInfo,
                isSelected: isSelected
            )
        }
    }
    
    private static func beginLayout(
        selfReference: Weak<ChatMessageBubbleItemNode>,
        item: ChatMessageItem,
        params: ListViewItemLayoutParams,
        mergedTop: ChatMessageMerge,
        mergedBottom: ChatMessageMerge,
        dateHeaderAtBottom: ChatMessageHeaderSpec,
        currentContentClassesPropertiesAndLayouts: [(Message, AnyClass, Bool, Int?, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))))],
        authorNameLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode),
        viaMeasureLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode),
        adminBadgeLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode),
        boostBadgeLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode),
        threadInfoLayout: (ChatMessageThreadInfoNode.Arguments) -> (CGSize, (Bool) -> ChatMessageThreadInfoNode),
        forwardInfoLayout: (AccountContext, ChatPresentationData, PresentationStrings, ChatMessageForwardInfoType, Peer?, String?, String?, ChatMessageForwardInfoNode.StoryData?, CGSize) -> (CGSize, (CGFloat) -> ChatMessageForwardInfoNode),
        replyInfoLayout: (ChatMessageReplyInfoNode.Arguments) -> (CGSize, (CGSize, Bool, ListViewItemUpdateAnimation) -> ChatMessageReplyInfoNode),
        actionButtonsLayout: (AccountContext, ChatPresentationThemeData, PresentationChatBubbleCorners, PresentationStrings, WallpaperBackgroundNode?, ReplyMarkupMessageAttribute, Message, CGFloat) -> (minWidth: CGFloat, layout: (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode)),
        reactionButtonsLayout: (ChatMessageReactionButtonsNode.Arguments) -> (minWidth: CGFloat, layout: (CGFloat) -> (size: CGSize, apply: (ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode)),
        unlockButtonLayout: (ChatMessageUnlockMediaNode.Arguments) -> (CGSize, (Bool) -> ChatMessageUnlockMediaNode),
        mediaInfoLayout: (ChatMessageStarsMediaInfoNode.Arguments) -> (CGSize, (Bool) -> ChatMessageStarsMediaInfoNode),
        mosaicStatusLayout: (ChatMessageDateAndStatusNode.Arguments) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageDateAndStatusNode)),
        layoutConstants: ChatMessageItemLayoutConstants,
        currentItem: ChatMessageItem?,
        currentForwardInfo: (Peer?, String?)?,
        isSelected: Bool?
    ) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
        let isPreview = item.presentationData.isPreview
        let accessibilityData = ChatMessageAccessibilityData(item: item, isSelected: isSelected)
        let isSidePanelOpen = item.controllerInteraction.isSidePanelOpen
        
        let fontSize = floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
        let nameFont = Font.semibold(fontSize)

        let inlineBotPrefixFont = Font.regular(fontSize - 1.0)
        let boostBadgeFont = Font.regular(fontSize - 1.0)
        
        let baseWidth = params.width - params.leftInset - params.rightInset
        
        let content = item.content
        let firstMessage = content.firstMessage
        let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
        
        let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
        
        var sourceReference: SourceReferenceMessageAttribute?
        for attribute in item.content.firstMessage.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                sourceReference = attribute
                break
            }
        }
        let sourceAuthorInfo = item.content.firstMessage.sourceAuthorInfo
        
        var isCrosspostFromChannel = false
        if let _ = sourceReference {
            if !firstMessage.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                isCrosspostFromChannel = true
            }
        }
        
        var effectiveAuthor: Peer?
        var overrideEffectiveAuthor = false
        var ignoreForward = false
        var displayAuthorInfo: Bool
        var ignoreNameHiding = false
        
        var avatarInset: CGFloat
        var hasAvatar = false
        
        var allowFullWidth = false
        let chatLocationPeerId: PeerId = item.chatLocation.peerId ?? item.content.firstMessage.id.peerId
                
        do {
            let peerId = chatLocationPeerId
            
            if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
                displayAuthorInfo = false
            } else if item.message.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                if let forwardInfo = item.content.firstMessage.forwardInfo {
                    effectiveAuthor = forwardInfo.author
                    
                    if let sourceAuthorInfo, let originalAuthorId = sourceAuthorInfo.originalAuthor, let peer = item.message.peers[originalAuthorId] {
                        effectiveAuthor = peer
                    } else if let sourceAuthorInfo, let originalAuthorName = sourceAuthorInfo.originalAuthorName {
                        effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(originalAuthorName.persistentHashValue % 32))), accessHash: nil, firstName: originalAuthorName, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                    } else {
                        ignoreForward = true
                        if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature {
                            effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                        }
                    }
                }
                displayAuthorInfo = !mergedTop.merged && incoming && effectiveAuthor != nil
            } else if isCrosspostFromChannel, let sourceReference = sourceReference, let source = firstMessage.peers[sourceReference.messageId.peerId] {
                if firstMessage.forwardInfo?.author?.id == source.id {
                    ignoreForward = true
                }
                effectiveAuthor = source
                displayAuthorInfo = !mergedTop.merged && incoming && effectiveAuthor != nil
            } else if let forwardInfo = item.content.firstMessage.forwardInfo, forwardInfo.flags.contains(.isImported), let author = forwardInfo.author {
                ignoreForward = true
                effectiveAuthor = author
                displayAuthorInfo = !mergedTop.merged && incoming
            } else if let forwardInfo = item.content.firstMessage.forwardInfo, forwardInfo.flags.contains(.isImported), let authorSignature = forwardInfo.authorSignature {
                ignoreForward = true
                effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                displayAuthorInfo = !mergedTop.merged && incoming
            } else if let _ = item.content.firstMessage.adAttribute, let author = item.content.firstMessage.author {
                ignoreForward = true
                effectiveAuthor = author
                displayAuthorInfo = !mergedTop.merged && incoming
            } else {
                effectiveAuthor = firstMessage.author
                
                var allowAuthor = incoming
                
                if let author = firstMessage.author, author is TelegramChannel, !incoming || item.presentationData.isPreview {
                    allowAuthor = true
                    ignoreNameHiding = true
                }
                
                if let subject = item.associatedData.subject, case let .customChatContents(contents) = subject, case .hashTagSearch = contents.kind {
                    ignoreNameHiding = true
                }
                
                displayAuthorInfo = !mergedTop.merged && allowAuthor && peerId.isGroupOrChannel && effectiveAuthor != nil
                if let forwardInfo = firstMessage.forwardInfo, forwardInfo.psaType != nil {
                    displayAuthorInfo = false
                }
                
                var isMonoForum = false
                if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel {
                    if peer.isMonoForum {
                        isMonoForum = true
                    }
                }
                if isMonoForum {
                    if case let .replyThread(replyThreadMessage) = item.chatLocation, firstMessage.effectivelyIncoming(item.context.account.peerId), item.effectiveAuthorId == PeerId(replyThreadMessage.threadId) {
                        displayAuthorInfo = false
                    }
                }
            }
            
            if let channel = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info {
                if info.flags.contains(.messagesShouldHaveProfiles) && !item.presentationData.isPreview {
                    var allowAuthor = incoming
                    overrideEffectiveAuthor = true
                    
                    if let author = firstMessage.author, author is TelegramChannel, !incoming {
                        allowAuthor = true
                        ignoreNameHiding = true
                    }
                    
                    if let subject = item.associatedData.subject, case let .customChatContents(contents) = subject, case .hashTagSearch = contents.kind {
                        ignoreNameHiding = true
                    }
                    
                    displayAuthorInfo = !mergedTop.merged && allowAuthor && peerId.isGroupOrChannel && effectiveAuthor != nil
                    if let forwardInfo = firstMessage.forwardInfo, forwardInfo.psaType != nil {
                        displayAuthorInfo = false
                    }
                }
            }
        
            if !peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                if peerId.isGroupOrChannel && effectiveAuthor != nil {
                    var isBroadcastChannel = false
                    var isMonoForum = false
                    if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel {
                        if case .broadcast = peer.info {
                            isBroadcastChannel = true
                            allowFullWidth = true
                        } else if peer.isMonoForum {
                            isMonoForum = true
                        }
                    }
                    
                    if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.isChannelPost, replyThreadMessage.effectiveTopId == firstMessage.id {
                        isBroadcastChannel = true
                    }
                    
                    if !isBroadcastChannel {
                        hasAvatar = incoming
                    } else if case .customChatContents = item.chatLocation {
                        hasAvatar = false
                    } else if overrideEffectiveAuthor {
                        hasAvatar = true
                    }
                    
                    if isMonoForum {
                        if case .replyThread = item.chatLocation {
                            hasAvatar = false
                        }
                    }
                }
            } else if incoming {
                hasAvatar = true
            }
            
            if let subject = item.associatedData.subject, case let .customChatContents(contents) = subject, case .hashTagSearch = contents.kind {
                hasAvatar = true
            }
        }
        
        if isPreview, let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramUser, peer.firstName == nil {
            hasAvatar = false
            effectiveAuthor = nil
        }
        
        var isInstantVideo = false
        if let forwardInfo = item.content.firstMessage.forwardInfo, forwardInfo.source == nil, forwardInfo.author?.id.namespace == Namespaces.Peer.CloudUser {
            for media in item.content.firstMessage.media {
                if let file = media as? TelegramMediaFile {
                    if file.isMusic {
                        ignoreForward = true
                    } else if file.isInstantVideo {
                        isInstantVideo = true
                    }
                    break
                }
            }
        }
        
        avatarInset = hasAvatar ? layoutConstants.avatarDiameter : 0.0
        if isSidePanelOpen {
            avatarInset = 0.0
        }
        
        let isFailed = item.content.firstMessage.effectivelyFailed(timestamp: item.context.account.network.getApproximateRemoteTimestamp())
        
        var needsShareButton = false
    
        if incoming, case let .customChatContents(contents) = item.associatedData.subject, case .hashTagSearch = contents.kind {
            needsShareButton = true
        } else if case .pinnedMessages = item.associatedData.subject {
            needsShareButton = true
            for media in item.message.media {
                if let _ = media as? TelegramMediaExpiredContent {
                    needsShareButton = false
                    break
                }
            }
        } else if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.effectiveTopId == item.message.id {
            needsShareButton = false
            allowFullWidth = true
        } else if isFailed || Namespaces.Message.allNonRegular.contains(item.message.id.namespace) {
            needsShareButton = false
        } else if item.message.id.peerId == item.context.account.peerId {
            if let _ = sourceReference {
                needsShareButton = true
            }
        } else if item.message.id.peerId.isRepliesOrVerificationCodes {
            needsShareButton = false
        } else if incoming {
            if let _ = sourceReference {
                needsShareButton = true
            }
            
            if let peer = item.message.peers[item.message.id.peerId] {
                if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        needsShareButton = true
                    }
                }
            }
            
            if let info = item.message.forwardInfo {
                if let author = info.author as? TelegramUser, let _ = author.botInfo, !item.message.media.isEmpty && !(item.message.media.first is TelegramMediaAction) {
                    needsShareButton = true
                } else if let author = info.author as? TelegramChannel, case .broadcast = author.info {
                    needsShareButton = true
                }
            }
            
            if !needsShareButton, let author = item.message.author as? TelegramUser, let _ = author.botInfo {
                if !item.message.media.isEmpty && !(item.message.media.first is TelegramMediaAction) {
                    needsShareButton = true
                } else if author.id == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(92386307)) || author.id == PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(6435149744)) {
                    needsShareButton = true
                }
            }
            var mayHaveSeparateCommentsButton = false
            if !needsShareButton {
                loop: for media in item.message.media {
                    if media is TelegramMediaGame || media is TelegramMediaInvoice {
                        needsShareButton = true
                        break loop
                    } else if let media = media as? TelegramMediaWebpage, case .Loaded = media.content {
                        needsShareButton = true
                        break loop
                    }
                }
            } else {
                loop: for media in item.message.media {
                    if media is TelegramMediaAction {
                        needsShareButton = false
                        break loop
                    } else if let media = media as? TelegramMediaFile, media.isInstantVideo {
                        mayHaveSeparateCommentsButton = true
                        break loop
                    }
                }
            }
            
            if (item.associatedData.isCopyProtectionEnabled || item.message.isCopyProtected()) {
                if mayHaveSeparateCommentsButton && hasCommentButton(item: item) {
                } else {
                    needsShareButton = false
                }
            }
        }
        
        if isPreview {
            needsShareButton = false
        }
        let isAd = item.content.firstMessage.adAttribute != nil
        if isAd {
            needsShareButton = true
        }
        for attribute in item.content.firstMessage.attributes {
            if let attribute = attribute as? RestrictedContentMessageAttribute, attribute.platformText(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) != nil {
                needsShareButton = false
            }
        }
        
        if let subject = item.associatedData.subject, case .messageOptions = subject {
            needsShareButton = false
        }
                
        var tmpWidth: CGFloat
        if allowFullWidth {
            tmpWidth = baseWidth
            if (needsShareButton && !isSidePanelOpen) || isAd {
                tmpWidth -= 45.0
            } else {
                tmpWidth -= 4.0
            }
        } else {
            tmpWidth = layoutConstants.bubble.maximumWidthFill.widthFor(baseWidth)
            if ((needsShareButton && !isSidePanelOpen) || isAd) && tmpWidth + 32.0 > baseWidth {
                tmpWidth = baseWidth - 32.0
            }
        }
        
        var deliveryFailedInset: CGFloat = 0.0
        if isFailed {
            deliveryFailedInset += 24.0
        }
        
        tmpWidth -= deliveryFailedInset
        
        let (contentNodeMessagesAndClasses, needSeparateContainers, needReactions) = contentNodeMessagesAndClassesForItem(item)
        
        var maximumContentWidth = floor(tmpWidth - layoutConstants.bubble.edgeInset * 3.0 - layoutConstants.bubble.contentInsets.left - layoutConstants.bubble.contentInsets.right - avatarInset)
        if (needsShareButton && !isSidePanelOpen) {
            maximumContentWidth -= 10.0
        }
        
        var hasInstantVideo = false
        for contentNodeItemValue in contentNodeMessagesAndClasses {
            let contentNodeItem = contentNodeItemValue as (message: Message, type: AnyClass, attributes: ChatMessageEntryAttributes, bubbleAttributes: BubbleItemAttributes)
            if contentNodeItem.type == ChatMessageJoinedChannelBubbleContentNode.self {
                maximumContentWidth = baseWidth
                break
            }
            if contentNodeItem.type == ChatMessageGiveawayBubbleContentNode.self {
                maximumContentWidth = min(305.0, maximumContentWidth)
                break
            }
            if contentNodeItem.type == ChatMessageInstantVideoBubbleContentNode.self, !contentNodeItem.bubbleAttributes.isAttachment {
                maximumContentWidth = baseWidth - 20.0
                hasInstantVideo = true
                break
            }
        }
        maximumContentWidth = max(0.0, maximumContentWidth)
        
        var contentPropertiesAndPrepareLayouts: [(Message, Bool, ChatMessageEntryAttributes, BubbleItemAttributes, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))))] = []
        var addedContentNodes: [(Message, Bool, ChatMessageBubbleContentNode, Int?)]?
        for contentNodeItemValue in contentNodeMessagesAndClasses {
            let contentNodeItem = contentNodeItemValue as (message: Message, type: AnyClass, attributes: ChatMessageEntryAttributes, bubbleAttributes: BubbleItemAttributes)
            
            var found = false
            for currentNodeItemValue in currentContentClassesPropertiesAndLayouts {
                let currentNodeItem = currentNodeItemValue as (message: Message, type: AnyClass, supportsMosaic: Bool, index: Int?, currentLayout: (ChatMessageBubbleContentItem, ChatMessageItemLayoutConstants, ChatMessageBubblePreparePosition, Bool?, CGSize, CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))))

                if currentNodeItem.type == contentNodeItem.type && currentNodeItem.index == contentNodeItem.bubbleAttributes.index && currentNodeItem.message.stableId == contentNodeItem.message.stableId {
                    contentPropertiesAndPrepareLayouts.append((contentNodeItem.message, currentNodeItem.supportsMosaic, contentNodeItem.attributes, contentNodeItem.bubbleAttributes, currentNodeItem.currentLayout))
                    found = true
                    break
                }
            }
            if !found {
                let contentNode = (contentNodeItem.type as! ChatMessageBubbleContentNode.Type).init()                
                contentNode.index = contentNodeItem.bubbleAttributes.index
                contentPropertiesAndPrepareLayouts.append((contentNodeItem.message, contentNode.supportsMosaic, contentNodeItem.attributes, contentNodeItem.bubbleAttributes, contentNode.asyncLayoutContent()))
                if addedContentNodes == nil {
                    addedContentNodes = []
                }
                addedContentNodes!.append((contentNodeItem.message, contentNodeItem.bubbleAttributes.isAttachment, contentNode, contentNodeItem.bubbleAttributes.index))
            }
        }
        
        var authorNameString: String?
        var authorRank: CachedChannelAdminRank?
        var authorIsChannel: Bool = false
        switch content {
            case let .message(message, _, _, attributes, _):
                if let peer = message.peers[message.id.peerId] as? TelegramChannel {
                    if case .broadcast = peer.info {
                    } else {
                        if isCrosspostFromChannel, let sourceReference = sourceReference, let _ = firstMessage.peers[sourceReference.messageId.peerId] as? TelegramChannel {
                            authorIsChannel = true
                            authorRank = attributes.rank
                        } else {
                            authorRank = attributes.rank
                            if authorRank == nil && message.author?.id == peer.id {
                                authorRank = .admin
                            }
                        }
                    }
                } else {
                    if isCrosspostFromChannel, let _ = firstMessage.forwardInfo?.source as? TelegramChannel {
                        authorIsChannel = true
                    }
                    authorRank = attributes.rank
                }
            
                var enableAutoRank = false
                if case .admin = authorRank {
                } else if case .owner = authorRank {
                } else if authorRank == nil {
                    if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.peerId == item.context.account.peerId {
                    } else {
                        enableAutoRank = true
                    }
                }
                if enableAutoRank {
                    if let topicAuthorId = item.associatedData.topicAuthorId, topicAuthorId == message.author?.id {
                        authorRank = .custom(item.presentationData.strings.Chat_Message_TopicAuthorBadge)
                    }
                }
            case .group:
                break
        }
        
        var inlineBotNameString: String?
        var replyMessage: Message?
        var replyForward: QuotedReplyMessageAttribute?
        var replyQuote: (quote: EngineMessageReplyQuote, isQuote: Bool)?
        var replyStory: StoryId?
        var replyMarkup: ReplyMarkupMessageAttribute?
        var authorNameColor: UIColor?
        
        for attribute in firstMessage.attributes {
            if let attribute = attribute as? InlineBotMessageAttribute {
                if let peerId = attribute.peerId, let bot = firstMessage.peers[peerId] as? TelegramUser {
                    inlineBotNameString = bot.addressName
                } else {
                    inlineBotNameString = attribute.title
                }
            } else if let attribute = attribute as? ReplyMessageAttribute {
                if let threadId = firstMessage.threadId, Int32(clamping: threadId) == attribute.messageId.id, let channel = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, channel.isForumOrMonoForum {
                } else {
                    replyMessage = firstMessage.associatedMessages[attribute.messageId]
                }
                replyQuote = attribute.quote.flatMap { ($0, attribute.isQuote) }
            } else if let attribute = attribute as? QuotedReplyMessageAttribute {
                replyForward = attribute
            } else if let attribute = attribute as? ReplyStoryAttribute {
                replyStory = attribute.storyId
            } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty && !isPreview {
                var isExtendedMedia = false
                for media in firstMessage.media {
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
                        replyMarkup = ReplyMarkupMessageAttribute(rows: updatedRows, flags: attribute.flags, placeholder: attribute.placeholder)
                    }
                } else {
                    replyMarkup = attribute
                }
            } else if let attribute = attribute as? AuthorSignatureMessageAttribute {
                if let chatPeer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case .group = chatPeer.info, firstMessage.author is TelegramChannel, !attribute.signature.isEmpty {
                    authorRank = .custom(attribute.signature)
                }
            }
        }
        
        if firstMessage.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
            replyMarkup = nil
        }
        
        if let forwardInfo = firstMessage.forwardInfo, forwardInfo.psaType != nil {
            inlineBotNameString = nil
        }
        
        var contentPropertiesAndLayouts: [(CGSize?, ChatMessageBubbleContentProperties, ChatMessageBubblePreparePosition, BubbleItemAttributes, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void)), UInt32?, Bool?)] = []
        
        var backgroundHiding: ChatMessageBubbleContentBackgroundHiding?
        var hasSolidWallpaper = false
        switch item.presentationData.theme.wallpaper {
        case .color:
            hasSolidWallpaper = true
        case let .gradient(gradient):
            hasSolidWallpaper = gradient.colors.count <= 2
        default:
            break
        }
        var alignment: ChatMessageBubbleContentAlignment = .none
        
        var maximumNodeWidth = maximumContentWidth
        
        let contentNodeCount = contentPropertiesAndPrepareLayouts.count
        
        let read: Bool
        var isItemPinned = false
        var isItemEdited = false
        
        switch item.content {
            case let .message(message, value, _, attributes, _):
                read = value
                isItemPinned = message.tags.contains(.pinned)
                if attributes.isCentered {
                    alignment = .center
                }
            case let .group(messages):
                read = messages[0].1
                for message in messages {
                    if message.0.tags.contains(.pinned) {
                        isItemPinned = true
                    }
                    for attribute in message.0.attributes {
                        if let attribute = attribute as? EditedMessageAttribute {
                            isItemEdited = !attribute.isHidden
                            break
                        }
                    }
                }
        }
        
        if case .replyThread = item.chatLocation {
            isItemPinned = false
        }
        
        var mosaicStartIndex: Int?
        var mosaicRange: Range<Int>?
        for i in 0 ..< contentPropertiesAndPrepareLayouts.count {
            if contentPropertiesAndPrepareLayouts[i].1 {
                if mosaicStartIndex == nil {
                    mosaicStartIndex = i
                }
            } else if let mosaicStartIndexValue = mosaicStartIndex {
                if mosaicStartIndexValue < i - 1 {
                    mosaicRange = mosaicStartIndexValue ..< i
                }
                mosaicStartIndex = nil
            }
        }
        if let mosaicStartIndex = mosaicStartIndex {
            if mosaicStartIndex < contentPropertiesAndPrepareLayouts.count - 1 {
                mosaicRange = mosaicStartIndex ..< contentPropertiesAndPrepareLayouts.count
            }
        }
        
        var hidesHeaders = false
        var shareButtonOffset: CGPoint?
        var avatarOffset: CGFloat?
        var index = 0
        for (message, _, attributes, bubbleAttributes, prepareLayout) in contentPropertiesAndPrepareLayouts {
            let topPosition: ChatMessageBubbleRelativePosition
            let bottomPosition: ChatMessageBubbleRelativePosition
            
            var topBubbleAttributes = BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)
            var bottomBubbleAttributes = BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)
            if index != 0 {
                topBubbleAttributes = contentPropertiesAndPrepareLayouts[index - 1].3
            }
            if index != contentPropertiesAndPrepareLayouts.count - 1 {
                bottomBubbleAttributes = contentPropertiesAndPrepareLayouts[index + 1].3
            }
            
            topPosition = .Neighbour(topBubbleAttributes.isAttachment, topBubbleAttributes.neighborType, topBubbleAttributes.neighborSpacing)
            bottomPosition = .Neighbour(bottomBubbleAttributes.isAttachment, bottomBubbleAttributes.neighborType, bottomBubbleAttributes.neighborSpacing)
            
            let prepareContentPosition: ChatMessageBubblePreparePosition
            if let mosaicRange = mosaicRange, mosaicRange.contains(index) {
                let mosaicIndex = index - mosaicRange.lowerBound
                prepareContentPosition = .mosaic(top: .None(.None(.Incoming)), bottom: index == (mosaicRange.upperBound - 1) ? bottomPosition : .None(.None(.Incoming)), index: mosaicIndex)
            } else {
                let refinedBottomPosition: ChatMessageBubbleRelativePosition
                if index == contentPropertiesAndPrepareLayouts.count - 1 {
                    refinedBottomPosition = .None(.Left)
                } else if index == contentPropertiesAndPrepareLayouts.count - 2 && contentPropertiesAndPrepareLayouts[contentPropertiesAndPrepareLayouts.count - 1].3.isAttachment {
                    refinedBottomPosition = .None(.Left)
                } else {
                    refinedBottomPosition = bottomPosition
                }
                prepareContentPosition = .linear(top: topPosition, bottom: refinedBottomPosition)
            }
            
            let contentItem = ChatMessageBubbleContentItem(context: item.context, controllerInteraction: item.controllerInteraction, message: message, topMessage: item.content.firstMessage, content: item.content, read: read, chatLocation: item.chatLocation, presentationData: item.presentationData, associatedData: item.associatedData, attributes: attributes, isItemPinned: isItemPinned, isItemEdited: isItemEdited)
            
            var itemSelection: Bool?
            switch content {
                case .message:
                    break
                case let .group(messages):
                    for (m, _, selection, _, _) in messages {
                        if m.id == message.id {
                            switch selection {
                                case .none:
                                    break
                                case let .selectable(selected):
                                    itemSelection = selected
                            }
                            break
                        }
                    }
            }
            
            let (properties, unboundSize, maxNodeWidth, nodeLayout) = prepareLayout(contentItem, layoutConstants, prepareContentPosition, itemSelection, CGSize(width: maximumContentWidth, height: CGFloat.greatestFiniteMagnitude), avatarInset)
            maximumNodeWidth = min(maximumNodeWidth, maxNodeWidth)
            
            if let offset = properties.shareButtonOffset {
                shareButtonOffset = offset
            }
            if properties.hidesHeaders {
                hidesHeaders = true
            }
            if let offset = properties.avatarOffset {
                avatarOffset = offset
                if !offset.isZero {
                    avatarInset = 0.0
                }
            }
            
            contentPropertiesAndLayouts.append((unboundSize, properties, prepareContentPosition, bubbleAttributes, nodeLayout, needSeparateContainers && !bubbleAttributes.isAttachment ? message.stableId : nil, itemSelection))
            
            if !properties.isDetached {
                switch properties.hidesBackground {
                    case .never:
                        backgroundHiding = .never
                    case .emptyWallpaper:
                        if backgroundHiding == nil {
                            backgroundHiding = properties.hidesBackground
                        }
                    case .always:
                        backgroundHiding = .always
                }
            
                switch properties.forceAlignment {
                case .none:
                    break
                case .center:
                    alignment = .center
                }
            }
            
            index += 1
        }
        
        let topNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedTop.merged ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
        var bottomNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedBottom.merged ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
        
        let bubbleReactions: ReactionsMessageAttribute
        if needReactions {
            bubbleReactions = mergedMessageReactions(attributes: item.message.attributes, isTags: item.message.areReactionsTags(accountPeerId: item.context.account.peerId)) ?? ReactionsMessageAttribute(canViewList: false, isTags: false, reactions: [], recentPeers: [], topPeers: [])
        } else {
            bubbleReactions = ReactionsMessageAttribute(canViewList: false, isTags: false, reactions: [], recentPeers: [], topPeers: [])
        }
        if !bubbleReactions.reactions.isEmpty && !item.presentationData.isPreview {
            bottomNodeMergeStatus = .Both
        }
        
        var currentCredibilityIcon: (EmojiStatusComponent.Content, UIColor?)?
        
        var initialDisplayHeader = true
        if hidesHeaders || item.message.adAttribute != nil {
            initialDisplayHeader = false
        } else if let backgroundHiding, case .always = backgroundHiding {
            initialDisplayHeader = false
        } else {
            var hasForwardLikeContent = false
            if firstMessage.forwardInfo != nil {
                hasForwardLikeContent = true
            } else if firstMessage.media.contains(where: { $0 is TelegramMediaStory }) {
                hasForwardLikeContent = true
            }
            
            if inlineBotNameString == nil && (ignoreForward || !hasForwardLikeContent) && replyMessage == nil && replyForward == nil && replyStory == nil {
                if let first = contentPropertiesAndLayouts.first, first.1.hidesSimpleAuthorHeader && !ignoreNameHiding {
                    if let author = firstMessage.author as? TelegramChannel, case .group = author.info, author.id == firstMessage.id.peerId, !incoming {
                    } else {
                        initialDisplayHeader = false
                    }
                }
            }
        }
        
        if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case .broadcast = peer.info, item.content.firstMessage.adAttribute == nil {
            let peer = (peer as Peer)
            let nameColors = peer.nameColor.flatMap { item.context.peerNameColors.get($0, dark: item.presentationData.theme.theme.overallDarkAppearance) }
            authorNameColor = nameColors?.main
        } else if let effectiveAuthor = effectiveAuthor {
            let nameColor = effectiveAuthor.nameColor ?? .blue
            let nameColors = item.context.peerNameColors.get(nameColor, dark: item.presentationData.theme.theme.overallDarkAppearance)
            let color: UIColor
            if incoming {
                color = nameColors.main
            } else {
                color = item.presentationData.theme.theme.chat.message.outgoing.accentTextColor
            }
            authorNameColor = color
        }
                
        if initialDisplayHeader && displayAuthorInfo {
            if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case .broadcast = peer.info, item.content.firstMessage.adAttribute == nil, !overrideEffectiveAuthor {
                authorNameString = EnginePeer(peer).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                
                let peer = (peer as Peer)
                let nameColors = peer.nameColor.flatMap { item.context.peerNameColors.get($0, dark: item.presentationData.theme.theme.overallDarkAppearance) }
                authorNameColor = nameColors?.main
            } else if let effectiveAuthor = effectiveAuthor {
                authorNameString = EnginePeer(effectiveAuthor).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                
                let nameColor = effectiveAuthor.nameColor ?? .blue
                let nameColors = item.context.peerNameColors.get(nameColor, dark: item.presentationData.theme.theme.overallDarkAppearance)
                let color: UIColor
                if incoming {
                    color = nameColors.main
                } else {
                    color = item.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                }
                authorNameColor = color

                if case let .peer(peerId) = item.chatLocation, let authorPeerId = item.message.author?.id, authorPeerId == peerId {
                    if effectiveAuthor is TelegramChannel, let emojiStatus = effectiveAuthor.emojiStatus {
                        currentCredibilityIcon = (.animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 20.0, height: 20.0), placeholderColor: incoming ? item.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : item.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor, themeColor: color.withMultipliedAlpha(0.4), loopMode: .count(2)), nil)
                    }
                } else if effectiveAuthor.isScam {
                    currentCredibilityIcon = (.text(color: incoming ? item.presentationData.theme.theme.chat.message.incoming.scamColor : item.presentationData.theme.theme.chat.message.outgoing.scamColor, string: item.presentationData.strings.Message_ScamAccount.uppercased()), nil)
                } else if effectiveAuthor.isFake {
                    currentCredibilityIcon = (.text(color: incoming ? item.presentationData.theme.theme.chat.message.incoming.scamColor : item.presentationData.theme.theme.chat.message.outgoing.scamColor, string: item.presentationData.strings.Message_FakeAccount.uppercased()), nil)
                } else if let emojiStatus = effectiveAuthor.emojiStatus {
                    currentCredibilityIcon = (.animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 20.0, height: 20.0), placeholderColor: incoming ? item.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : item.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor, themeColor: color.withMultipliedAlpha(0.4), loopMode: .count(2)), emojiStatus.color.flatMap { UIColor(rgb: UInt32(bitPattern: $0)) })
                } else if effectiveAuthor.isVerified {
                    currentCredibilityIcon = (.verified(fillColor: item.presentationData.theme.theme.list.itemCheckColors.fillColor, foregroundColor: item.presentationData.theme.theme.list.itemCheckColors.foregroundColor, sizeType: .compact), nil)
                } else if effectiveAuthor.isPremium {
                    currentCredibilityIcon = (.premium(color: color.withMultipliedAlpha(0.4)), nil)
                }
            }
            if let rawAuthorNameColor = authorNameColor {
                var dimColors = false
                switch item.presentationData.theme.theme.name {
                    case .builtin(.nightAccent), .builtin(.night):
                        dimColors = true
                    default:
                        break
                }
                if dimColors {
                    var hue: CGFloat = 0.0
                    var saturation: CGFloat = 0.0
                    var brightness: CGFloat = 0.0
                    rawAuthorNameColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                    authorNameColor = UIColor(hue: hue, saturation: saturation * 0.7, brightness: min(1.0, brightness * 1.2), alpha: 1.0)
                }
            }
        }
        
        var displayHeader = false
        if initialDisplayHeader {
            if authorNameString != nil {
                displayHeader = true
            }
            if inlineBotNameString != nil {
                displayHeader = true
            }
            if firstMessage.forwardInfo != nil {
                displayHeader = true
            }
            if firstMessage.media.contains(where: { $0 is TelegramMediaStory }) {
                displayHeader = true
            }
            if replyMessage != nil || replyForward != nil || replyStory != nil {
                displayHeader = true
            }
            if !displayHeader, case .peer = item.chatLocation, let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, channel.isForumOrMonoForum, item.message.associatedThreadInfo != nil {
                displayHeader = true
            }
            if case let .customChatContents(contents) = item.associatedData.subject, case .hashTagSearch = contents.kind, let peer = item.message.peers[item.message.id.peerId] {
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    
                } else {
                    displayHeader = true
                }
            }
        }
        
        let firstNodeTopPosition: ChatMessageBubbleRelativePosition
        if displayHeader {
            firstNodeTopPosition = .Neighbour(false, .header, .default)
        } else {
            firstNodeTopPosition = .None(topNodeMergeStatus)
        }
        var lastNodeTopPosition: ChatMessageBubbleRelativePosition = .None(bottomNodeMergeStatus)
        
        var calculatedGroupFramesAndSize: ([(CGRect, MosaicItemPosition)], CGSize)?
        var mosaicStatusSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageDateAndStatusNode)?
        
        if let mosaicRange = mosaicRange {
            let maxSize = layoutConstants.image.maxDimensions.fittedToWidthOrSmaller(maximumContentWidth - layoutConstants.image.bubbleInsets.left - layoutConstants.image.bubbleInsets.right)
            let (innerFramesAndPositions, innerSize) = chatMessageBubbleMosaicLayout(maxSize: maxSize, itemSizes: contentPropertiesAndLayouts[mosaicRange].map { item in
                guard let size = item.0, size.width > 0.0, size.height > 0 else {
                    return CGSize(width: 256.0, height: 256.0)
                }
                return size
            })
            
            let framesAndPositions = innerFramesAndPositions.map { ($0.0.offsetBy(dx: layoutConstants.image.bubbleInsets.left, dy: layoutConstants.image.bubbleInsets.top), $0.1) }
            
            let size = CGSize(width: innerSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, height: innerSize.height + layoutConstants.image.bubbleInsets.top + layoutConstants.image.bubbleInsets.bottom)
            
            calculatedGroupFramesAndSize = (framesAndPositions, size)
            
            maximumNodeWidth = size.width
            
            var hasText = false
            for contentItem in contentNodeMessagesAndClasses {
                if let _ = contentItem.1 as? ChatMessageTextBubbleContentNode.Type {
                    hasText = true
                }
            }
                        
            if case .customChatContents = item.associatedData.subject {
            } else if (mosaicRange.upperBound == contentPropertiesAndLayouts.count || contentPropertiesAndLayouts[contentPropertiesAndLayouts.count - 1].3.isAttachment) && (!hasText || item.message.invertMedia) {
                let message = item.content.firstMessage
                
                var edited = false
                if item.content.firstMessageAttributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var starsCount: Int64?
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: message)
                if message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                for attribute in message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    } else if let attribute = attribute as? PaidStarsMessageAttribute, item.message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        var messageCount: Int = 1
                        if case let .group(messages) = item.content {
                            messageCount = messages.count
                        }
                        starsCount = attribute.stars.value * Int64(messageCount)
                    }
                }
                
                let dateFormat: MessageTimestampStatusFormat
                if item.presentationData.isPreview {
                    dateFormat = .full
                } else if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
                    dateFormat = .minimal
                } else {
                    dateFormat = .regular
                }
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType
                if incoming {
                    statusType = .ImageIncoming
                } else {
                    if isFailed {
                        statusType = .ImageOutgoing(.Failed)
                    } else if (message.flags.isSending && !message.isSentOrAcknowledged) || item.content.firstMessageAttributes.updatingMedia != nil {
                        statusType = .ImageOutgoing(.Sending)
                    } else {
                        statusType = .ImageOutgoing(.Sent(read: item.read))
                    }
                }
                
                var isReplyThread = false
                if case .replyThread = item.chatLocation {
                    isReplyThread = true
                }
                
                let statusSuggestedWidthAndContinue = mosaicStatusLayout(ChatMessageDateAndStatusNode.Arguments(
                    context: item.context,
                    presentationData: item.presentationData,
                    edited: edited && !item.presentationData.isPreview,
                    impressionCount: !item.presentationData.isPreview ? viewCount : nil,
                    dateText: dateText,
                    type: statusType,
                    layoutInput: .standalone(reactionSettings: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.StandaloneReactionSettings() : nil),
                    constrainedSize: CGSize(width: 200.0, height: CGFloat.greatestFiniteMagnitude),
                    availableReactions: item.associatedData.availableReactions,
                    savedMessageTags: item.associatedData.savedMessageTags,
                    reactions: dateReactionsAndPeers.reactions,
                    reactionPeers: dateReactionsAndPeers.peers,
                    displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                    areReactionsTags: item.message.areReactionsTags(accountPeerId: item.context.account.peerId),
                    messageEffect: item.message.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                    replyCount: dateReplies,
                    starsCount: starsCount,
                    isPinned: message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                    hasAutoremove: message.isSelfExpiring,
                    canViewReactionList: canViewMessageReactionList(message: message),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                ))
                
                mosaicStatusSizeAndApply = statusSuggestedWidthAndContinue.1(statusSuggestedWidthAndContinue.0)
            }
        }
        
        var headerSize = CGSize()
        
        var nameNodeOriginY: CGFloat = 0.0
        var nameNodeSizeApply: (CGSize, () -> TextNode?) = (CGSize(), { nil })
        var adminNodeSizeApply: (CGSize, () -> TextNode?) = (CGSize(), { nil })
        var boostNodeSizeApply: (CGSize, () -> TextNode?) = (CGSize(), { nil })
        var viaWidth: CGFloat = 0.0

        let threadInfoOriginY: CGFloat = 0.0
        let threadInfoSizeApply: (CGSize, (Bool) -> ChatMessageThreadInfoNode?) = (CGSize(), {  _ in nil })
        
        var replyInfoOriginY: CGFloat = 0.0
        var replyInfoSizeApply: (CGSize, (CGSize, Bool, ListViewItemUpdateAnimation) -> ChatMessageReplyInfoNode?) = (CGSize(), { _, _, _ in nil })
        
        var forwardInfoOriginY: CGFloat = 0.0
        var forwardInfoSizeApply: (CGSize, (CGFloat) -> ChatMessageForwardInfoNode?) = (CGSize(), { _ in nil })
        
        var forwardSource: Peer?
        var forwardAuthorSignature: String?
        
        var unlockButtonSizeApply: (CGSize, (Bool) -> ChatMessageUnlockMediaNode?) = (CGSize(), {  _ in nil })
        var mediaInfoSizeApply: (CGSize, (Bool) -> ChatMessageStarsMediaInfoNode?) = (CGSize(), {  _ in nil })
        
        var hasTitleAvatar = false
        var hasTitleTopicNavigation = false
        
        if displayHeader {
            let bubbleWidthInsets: CGFloat = mosaicRange == nil ? layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right : 0.0
            if authorNameString != nil || inlineBotNameString != nil {
                if headerSize.height.isZero {
                    headerSize.height += 7.0
                }
                
                if isSidePanelOpen && incoming {
                    hasTitleAvatar = true
                    hasTitleTopicNavigation = item.chatLocation.threadId == nil
                }
                
                let inlineBotNameColor = messageTheme.accentTextColor
                
                let attributedString: NSAttributedString
                var adminBadgeString: NSAttributedString?
                var boostBadgeString: NSAttributedString?
                if incoming {
                    if let authorRank = authorRank {
                        let string: String
                        switch authorRank {
                        case .owner:
                            string = item.presentationData.strings.Conversation_Owner
                        case .admin:
                            string = item.presentationData.strings.Conversation_Admin
                        case let .custom(rank):
                            string = rank.trimmingEmojis
                        }
                        adminBadgeString = NSAttributedString(string: " \(string)", font: inlineBotPrefixFont, textColor: messageTheme.secondaryTextColor)
                    } else if authorIsChannel, case .peer = item.chatLocation {
                        adminBadgeString = NSAttributedString(string: " \(item.presentationData.strings.Channel_Status)", font: inlineBotPrefixFont, textColor: messageTheme.secondaryTextColor)
                    }
                }
                
                var viaSuffix: NSAttributedString?
                if let authorNameString = authorNameString, let authorNameColor = authorNameColor, let inlineBotNameString = inlineBotNameString {
                    let mutableString = NSMutableAttributedString(string: "\(authorNameString) ", attributes: [NSAttributedString.Key.font: nameFont, NSAttributedString.Key.foregroundColor: authorNameColor])
                    let bodyAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                    let boldAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                    let botString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)")._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    mutableString.append(botString)
                    attributedString = mutableString
                    viaSuffix = botString
                } else if let authorNameString = authorNameString, let authorNameColor = authorNameColor {
                    attributedString = NSAttributedString(string: authorNameString, font: nameFont, textColor: authorNameColor)
                } else if let inlineBotNameString = inlineBotNameString {
                    let bodyAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                    let boldAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                    attributedString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)")._tuple, body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    viaSuffix = attributedString
                } else {
                    attributedString = NSAttributedString(string: "", font: nameFont, textColor: inlineBotNameColor)
                }
                
                var credibilityIconWidth: CGFloat = 0.0
                if let (currentCredibilityIcon, _) = currentCredibilityIcon {
                    credibilityIconWidth += 4.0
                    switch currentCredibilityIcon {
                    case let .text(_, string):
                        let textString = NSAttributedString(string: string, font: Font.bold(10.0), textColor: .black, paragraphAlignment: .center)
                        let stringRect = textString.boundingRect(with: CGSize(width: 100.0, height: 16.0), options: .usesLineFragmentOrigin, context: nil)
                        credibilityIconWidth += floor(stringRect.width) + 11.0
                    default:
                        credibilityIconWidth += 20.0
                    }
                }
                
                let adminBadgeSizeAndApply = adminBadgeLayout(TextNodeLayoutArguments(attributedString: adminBadgeString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                if adminBadgeSizeAndApply.0.size.width > 0.0 {
                    adminNodeSizeApply = (adminBadgeSizeAndApply.0.size, {
                        return adminBadgeSizeAndApply.1()
                    })
                }
                
                var boostCount: Int = 0
                if incoming {
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? BoostCountMessageAttribute {
                            boostCount = attribute.count
                        }
                    }
                }
 
                if boostCount > 1, let authorNameColor = authorNameColor {
                    boostBadgeString = NSAttributedString(string: "\(boostCount)", font: boostBadgeFont, textColor: authorNameColor)
                }
                
                var boostBadgeWidth: CGFloat = 0.0
                let boostBadgeSizeAndApply = boostBadgeLayout(TextNodeLayoutArguments(attributedString: boostBadgeString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                if boostBadgeSizeAndApply.0.size.width > 0.0 {
                    boostNodeSizeApply = (boostBadgeSizeAndApply.0.size, {
                        return boostBadgeSizeAndApply.1()
                    })
                    boostBadgeWidth += boostBadgeSizeAndApply.0.size.width + 19.0
                } else if boostCount == 1 {
                    boostBadgeWidth = 14.0
                }
                
                let closeButtonWidth: CGFloat = item.message.adAttribute != nil ? 18.0 : 0.0
                
                let sizeAndApply = authorNameLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right - credibilityIconWidth - adminBadgeSizeAndApply.0.size.width - closeButtonWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                nameNodeSizeApply = (sizeAndApply.0.size, {
                    return sizeAndApply.1()
                })

                if let viaSuffix {
                    let (viaLayout, _) = viaMeasureLayout(TextNodeLayoutArguments(attributedString: viaSuffix, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0, maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right - credibilityIconWidth - adminBadgeSizeAndApply.0.size.width - closeButtonWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    viaWidth = viaLayout.size.width + 3.0
                }
                
                nameNodeOriginY = headerSize.height
                
                var nameAvatarSpaceWidth: CGFloat = 0.0
                if hasTitleAvatar {
                    headerSize.height += 12.0
                    nameAvatarSpaceWidth += 26.0 + 5.0
                    if hasTitleTopicNavigation {
                        nameAvatarSpaceWidth += 4.0 + 26.0
                    }
                    nameNodeOriginY += 5.0
                }
                                
                headerSize.width = max(headerSize.width, nameAvatarSpaceWidth + nameNodeSizeApply.0.width + 8.0 + adminBadgeSizeAndApply.0.size.width + credibilityIconWidth + boostBadgeWidth + closeButtonWidth + bubbleWidthInsets)
                headerSize.height += nameNodeSizeApply.0.height
            }

            if !ignoreForward && !isInstantVideo, let forwardInfo = firstMessage.forwardInfo {
                if headerSize.height.isZero {
                    headerSize.height += 5.0
                }
                
                let forwardPsaType: String? = forwardInfo.psaType
                
                if let source = forwardInfo.source {
                    forwardSource = source
                    if let authorSignature = forwardInfo.authorSignature {
                        forwardAuthorSignature = authorSignature
                    } else if let forwardInfoAuthor = forwardInfo.author, forwardInfoAuthor.id != source.id {
                        forwardAuthorSignature = EnginePeer(forwardInfoAuthor).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardAuthorSignature = nil
                    }
                } else {
                    if let currentForwardInfo = currentForwardInfo, forwardInfo.author == nil && currentForwardInfo.0 != nil {
                        forwardSource = nil
                        forwardAuthorSignature = currentForwardInfo.0.flatMap(EnginePeer.init)?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        forwardSource = forwardInfo.author
                        forwardAuthorSignature = forwardInfo.authorSignature
                    }
                }
                let sizeAndApply = forwardInfoLayout(item.context, item.presentationData, item.presentationData.strings, .bubble(incoming: incoming), forwardSource, forwardAuthorSignature, forwardPsaType, nil, CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude))
                forwardInfoSizeApply = (sizeAndApply.0, { width in sizeAndApply.1(width) })
                
                headerSize.height += 2.0
                forwardInfoOriginY = headerSize.height
                headerSize.width = max(headerSize.width, forwardInfoSizeApply.0.width + bubbleWidthInsets)
                headerSize.height += forwardInfoSizeApply.0.height
            } else if let storyMedia = firstMessage.media.first(where: { $0 is TelegramMediaStory }) as? TelegramMediaStory {
                let _ = storyMedia
                if headerSize.height.isZero {
                    headerSize.height += 5.0
                }
                
                forwardSource = firstMessage.peers[storyMedia.storyId.peerId]
                
                var storyType: ChatMessageForwardInfoNode.StoryType = .regular
                if let storyItem = firstMessage.associatedStories[storyMedia.storyId], storyItem.data.isEmpty {
                    storyType = .expired
                }
                if let peer = firstMessage.peers[storyMedia.storyId.peerId] as? TelegramChannel, peer.username == nil, peer.usernames.isEmpty {
                    switch peer.participationStatus {
                    case .member:
                        break
                    case .kicked, .left:
                        storyType = .unavailable
                    }
                }
                
                let sizeAndApply = forwardInfoLayout(item.context, item.presentationData, item.presentationData.strings, .bubble(incoming: incoming), forwardSource, nil, nil, ChatMessageForwardInfoNode.StoryData(storyType: storyType), CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude))
                forwardInfoSizeApply = (sizeAndApply.0, { width in sizeAndApply.1(width) })
                
                if storyType != .regular {
                    headerSize.height += 6.0
                } else {
                    headerSize.height += 2.0
                }
                
                forwardInfoOriginY = headerSize.height
                headerSize.width = max(headerSize.width, forwardInfoSizeApply.0.width + bubbleWidthInsets)
                headerSize.height += forwardInfoSizeApply.0.height
                
                if storyType != .regular {
                    headerSize.height += 16.0
                } else {
                    headerSize.height += 2.0
                }
            }
            
            let hasThreadInfo = !"".isEmpty
            /*if case let .peer(peerId) = item.chatLocation, (peerId == replyMessage?.id.peerId || item.message.threadId == 1 || item.associatedData.isRecentActions), let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, channel.isForum, item.message.associatedThreadInfo != nil {
                hasThreadInfo = true
            } else if case let .customChatContents(contents) = item.associatedData.subject, case .hashTagSearch = contents.kind {
                if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                    
                } else {
                    hasThreadInfo = true
                }
            }*/
                        
            var hasReply = replyMessage != nil || replyForward != nil || replyStory != nil
            if !isInstantVideo, hasThreadInfo {
                if let threadId = item.message.threadId, let replyMessage = replyMessage, Int64(replyMessage.id.id) == threadId {
                    hasReply = false
                }
                    
                /*if !mergedTop.merged {
                    if headerSize.height.isZero {
                        headerSize.height += 14.0
                    } else {
                        headerSize.height += 5.0
                    }
                    let sizeAndApply = threadInfoLayout(ChatMessageThreadInfoNode.Arguments(
                        presentationData: item.presentationData,
                        strings: item.presentationData.strings,
                        context: item.context,
                        controllerInteraction: item.controllerInteraction,
                        type: .bubble(incoming: incoming),
                        peer: item.message.peers[item.message.id.peerId].flatMap(EnginePeer.init),
                        threadId: item.message.threadId ?? 1,
                        parentMessage: item.message,
                        constrainedSize: CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                    threadInfoSizeApply = (sizeAndApply.0, { synchronousLoads in sizeAndApply.1(synchronousLoads) })
                    
                    threadInfoOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, threadInfoSizeApply.0.width + bubbleWidthInsets)
                    headerSize.height += threadInfoSizeApply.0.height + 5.0
                }*/
            }
            
            if !isInstantVideo, hasReply, (replyMessage != nil || replyForward != nil || replyStory != nil) {
                if headerSize.height.isZero {
                    headerSize.height += 11.0
                } else {
                    headerSize.height += 2.0
                }
                let sizeAndApply = replyInfoLayout(ChatMessageReplyInfoNode.Arguments(
                    presentationData: item.presentationData,
                    strings: item.presentationData.strings,
                    context: item.context,
                    type: .bubble(incoming: incoming),
                    message: replyMessage,
                    replyForward: replyForward,
                    quote: replyQuote,
                    story: replyStory,
                    parentMessage: item.message,
                    constrainedSize: CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right - 6.0, height: CGFloat.greatestFiniteMagnitude),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer,
                    associatedData: item.associatedData
                ))
                replyInfoSizeApply = (sizeAndApply.0, { realSize, synchronousLoads, animation in sizeAndApply.1(realSize, synchronousLoads, animation) })
                
                replyInfoOriginY = headerSize.height
                headerSize.width = max(headerSize.width, replyInfoSizeApply.0.width + bubbleWidthInsets)
                headerSize.height += replyInfoSizeApply.0.height + 7.0
                
                if !headerSize.height.isZero {
                    headerSize.height -= 7.0
                }
            } else {
                if !headerSize.height.isZero {
                    headerSize.height -= 5.0
                }
            }
        }
        
        let hideBackground: Bool
        if let backgroundHiding {
            switch backgroundHiding {
                case .never:
                    hideBackground = false
                case .emptyWallpaper:
                    hideBackground = hasSolidWallpaper && !displayHeader
                case .always:
                    hideBackground = true
            }
        } else {
            hideBackground = false
        }
        
        var removedContentNodeIndices: [Int]?
        findRemoved: for i in 0 ..< currentContentClassesPropertiesAndLayouts.count {
            let currentMessage = currentContentClassesPropertiesAndLayouts[i].0
            let currentClass: AnyClass = currentContentClassesPropertiesAndLayouts[i].1
            for contentItemValue in contentNodeMessagesAndClasses {
                let contentItem = contentItemValue as (message: Message, type: AnyClass, ChatMessageEntryAttributes, BubbleItemAttributes)

                if currentClass == contentItem.type && currentMessage.stableId == contentItem.message.stableId {
                    continue findRemoved
                }
            }
            if removedContentNodeIndices == nil {
                removedContentNodeIndices = [i]
            } else {
                removedContentNodeIndices!.append(i)
            }
        }
        
        var updatedContentNodeOrder = false
        if currentContentClassesPropertiesAndLayouts.count == contentNodeMessagesAndClasses.count {
            for i in 0 ..< currentContentClassesPropertiesAndLayouts.count {
                let currentClass: AnyClass = currentContentClassesPropertiesAndLayouts[i].1
                let contentItem = contentNodeMessagesAndClasses[i] as (message: Message, type: AnyClass, ChatMessageEntryAttributes, BubbleItemAttributes)
                if currentClass != contentItem.type {
                    updatedContentNodeOrder = true
                    break
                }
            }
        }
        
        var contentNodePropertiesAndFinalize: [(ChatMessageBubbleContentProperties, ChatMessageBubbleContentPosition?, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void), UInt32?, Bool?)] = []
        
        var maxContentWidth: CGFloat = headerSize.width
        
        var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animation: ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode))?
        if let additionalContent = item.additionalContent, case let .eventLogGroupedMessages(messages, hasButton) = additionalContent, hasButton {
            let (minWidth, buttonsLayout) = actionButtonsLayout(
                item.context,
                item.presentationData.theme,
                item.presentationData.chatBubbleCorners,
                item.presentationData.strings,
                item.controllerInteraction.presentationContext.backgroundNode,
                ReplyMarkupMessageAttribute(
                    rows: [
                        ReplyMarkupRow(
                            buttons: [ReplyMarkupButton(title: item.presentationData.strings.Channel_AdminLog_ShowMoreMessages(Int32(messages.count - 1)), titleWhenForwarded: nil, action: .callback(requiresPassword: false, data: MemoryBuffer(data: Data())))]
                        )
                    ],
                    flags: [],
                    placeholder: nil
            ), item.message, maximumNodeWidth)
            maxContentWidth = max(maxContentWidth, minWidth)
            actionButtonsFinalize = buttonsLayout
            
            lastNodeTopPosition = .None(.Both)
        } else if let replyMarkup = replyMarkup, !item.presentationData.isPreview {
            let (minWidth, buttonsLayout) = actionButtonsLayout(item.context, item.presentationData.theme, item.presentationData.chatBubbleCorners, item.presentationData.strings, item.controllerInteraction.presentationContext.backgroundNode, replyMarkup, item.message, maximumNodeWidth)
            maxContentWidth = max(maxContentWidth, minWidth)
            actionButtonsFinalize = buttonsLayout
        }
        
        var reactionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animation: ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode))?
        if !bubbleReactions.reactions.isEmpty && !item.presentationData.isPreview {
            var centerAligned = false
            for media in item.message.media {
                if let action = media as? TelegramMediaAction {
                    switch action.action {
                    case .phoneCall:
                        break
                    case .conferenceCall:
                        break
                    default:
                        centerAligned = true
                    }
                } else if let _ = media as? TelegramMediaExpiredContent {
                    centerAligned = true
                }
                break
            }
            
            var maximumNodeWidth = maximumNodeWidth
            if hasInstantVideo {
                maximumNodeWidth = min(309.0, baseWidth - 84.0)
            }
            let (minWidth, buttonsLayout) = reactionButtonsLayout(ChatMessageReactionButtonsNode.Arguments(
                context: item.context,
                presentationData: item.presentationData,
                presentationContext: item.controllerInteraction.presentationContext,
                availableReactions: item.associatedData.availableReactions,
                savedMessageTags: item.associatedData.savedMessageTags,
                reactions: bubbleReactions,
                message: item.message,
                associatedData: item.associatedData,
                accountPeer: item.associatedData.accountPeer,
                isIncoming: incoming,
                constrainedWidth: maximumNodeWidth,
                centerAligned: centerAligned
            ))
            maxContentWidth = max(maxContentWidth, minWidth)
            reactionButtonsFinalize = buttonsLayout
        }
        
        for i in 0 ..< contentPropertiesAndLayouts.count {
            let (_, contentNodeProperties, preparePosition, _, contentNodeLayout, contentGroupId, itemSelection) = contentPropertiesAndLayouts[i]
            
            if let mosaicRange = mosaicRange, mosaicRange.contains(i), let (framesAndPositions, size) = calculatedGroupFramesAndSize {
                let mosaicIndex = i - mosaicRange.lowerBound
                
                let position = framesAndPositions[mosaicIndex].1
                
                let topLeft: ChatMessageBubbleContentMosaicNeighbor
                let topRight: ChatMessageBubbleContentMosaicNeighbor
                let bottomLeft: ChatMessageBubbleContentMosaicNeighbor
                let bottomRight: ChatMessageBubbleContentMosaicNeighbor
                
                switch firstNodeTopPosition {
                    case .Neighbour:
                        topLeft = .merged
                        topRight = .merged
                    case .BubbleNeighbour:
                        topLeft = .mergedBubble
                        topRight = .mergedBubble
                    case let .None(status):
                        if position.contains(.top) && position.contains(.left) {
                            switch status {
                            case .Left, .Both:
                                topLeft = .mergedBubble
                            case .Right:
                                topLeft = .none(tail: false)
                            case .None:
                                topLeft = .none(tail: false)
                            }
                        } else {
                            topLeft = .merged
                        }
                        
                        if position.contains(.top) && position.contains(.right) {
                            switch status {
                            case .Left:
                                topRight = .none(tail: false)
                            case .Right, .Both:
                                topRight = .mergedBubble
                            case .None:
                                topRight = .none(tail: false)
                            }
                        } else {
                            topRight = .merged
                        }
                }
                
                let lastMosaicBottomPosition: ChatMessageBubbleRelativePosition
                if mosaicRange.upperBound - 1 == contentNodeCount - 1 {
                    lastMosaicBottomPosition = lastNodeTopPosition
                } else {
                    lastMosaicBottomPosition = .Neighbour(false, .text, .default)
                }
                
                if position.contains(.bottom), case .Neighbour = lastMosaicBottomPosition {
                    bottomLeft = .merged
                    bottomRight = .merged
                } else {
                    var switchValue = lastNodeTopPosition
                    if !"".isEmpty {
                        switchValue = .BubbleNeighbour
                    }

                    switch switchValue {
                        case .Neighbour:
                            bottomLeft = .merged
                            bottomRight = .merged
                        case .BubbleNeighbour:
                            bottomLeft = .mergedBubble
                            bottomRight = .mergedBubble
                        case let .None(status):
                            if position.contains(.bottom) && position.contains(.left) {
                                switch status {
                                case .Left, .Both:
                                    bottomLeft = .mergedBubble
                                case .Right:
                                    bottomLeft = .none(tail: false)
                                case let .None(tailStatus):
                                    if case .Incoming = tailStatus {
                                        bottomLeft = .none(tail: true)
                                    } else {
                                        bottomLeft = .none(tail: false)
                                    }
                                }
                            } else {
                                bottomLeft = .merged
                            }
                            
                            if position.contains(.bottom) && position.contains(.right) {
                                switch status {
                                case .Left:
                                    bottomRight = .none(tail: false)
                                case .Right, .Both:
                                    bottomRight = .mergedBubble
                                case let .None(tailStatus):
                                    if case .Outgoing = tailStatus {
                                        bottomRight = .none(tail: true)
                                    } else {
                                        bottomRight = .none(tail: false)
                                    }
                                }
                            } else {
                                bottomRight = .merged
                            }
                    }
                }
                
                let (_, contentNodeFinalize) = contentNodeLayout(framesAndPositions[mosaicIndex].0.size, .mosaic(position: ChatMessageBubbleContentMosaicPosition(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight), wide: position.isWide))
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, nil, contentNodeFinalize, contentGroupId, itemSelection))
                
                maxContentWidth = max(maxContentWidth, size.width)
            } else {
                let contentPosition: ChatMessageBubbleContentPosition
                switch preparePosition {
                    case .linear:
                        let topPosition: ChatMessageBubbleRelativePosition
                        let bottomPosition: ChatMessageBubbleRelativePosition
                        
                        var topBubbleAttributes = BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)
                        var bottomBubbleAttributes = BubbleItemAttributes(isAttachment: false, neighborType: .text, neighborSpacing: .default)
                        if i != 0 {
                            topBubbleAttributes = contentPropertiesAndLayouts[i - 1].3
                        }
                        if i != contentPropertiesAndLayouts.count - 1 {
                            bottomBubbleAttributes = contentPropertiesAndLayouts[i + 1].3
                        }

                        if i == 0 || (i == 1 && contentPropertiesAndLayouts[0].1.isDetached) {
                            topPosition = firstNodeTopPosition
                        } else {
                            topPosition = .Neighbour(topBubbleAttributes.isAttachment, topBubbleAttributes.neighborType, topBubbleAttributes.neighborSpacing)
                        }
                        
                        if i == contentNodeCount - 1 {
                            bottomPosition = lastNodeTopPosition
                        } else {
                            bottomPosition = .Neighbour(bottomBubbleAttributes.isAttachment, bottomBubbleAttributes.neighborType, bottomBubbleAttributes.neighborSpacing)
                        }
                    
                        contentPosition = .linear(top: topPosition, bottom: bottomPosition)
                    case .mosaic:
                        assertionFailure()
                        contentPosition = .linear(top: .Neighbour(false, .text, .default), bottom: .Neighbour(false, .text, .default))
                }
                let (contentNodeWidth, contentNodeFinalize) = contentNodeLayout(CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude), contentPosition)
                #if DEBUG
                if contentNodeWidth > maximumNodeWidth {
                    print("contentNodeWidth \(contentNodeWidth) > \(maximumNodeWidth)")
                }
                #endif
                
                if contentNodeProperties.isDetached {
                    
                } else {
                    maxContentWidth = max(maxContentWidth, contentNodeWidth)
                }
                
                contentNodePropertiesAndFinalize.append((contentNodeProperties, contentPosition, contentNodeFinalize, contentGroupId, itemSelection))
            }
        }
        
        var contentSize = CGSize(width: maxContentWidth, height: 0.0)
        var contentNodeFramesPropertiesAndApply: [(CGRect, ChatMessageBubbleContentProperties, Bool, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void)] = []
        var contentContainerNodeFrames: [(UInt32, CGRect, Bool?, CGFloat)] = []
        var currentContainerGroupId: UInt32?
        var currentItemSelection: Bool?
        
        var contentNodesHeight: CGFloat = 0.0
        var totalContentNodesHeight: CGFloat = 0.0
        var currentContainerGroupOverlap: CGFloat = 0.0
        var detachedContentNodesHeight: CGFloat = 0.0
        let additionalTopHeight: CGFloat = 0.0
        
        var mosaicStatusOrigin: CGPoint?
        var unlockButtonPosition: CGPoint?
        var mediaInfoOrigin: CGPoint?
        for i in 0 ..< contentNodePropertiesAndFinalize.count {
            let (properties, position, finalize, contentGroupId, itemSelection) = contentNodePropertiesAndFinalize[i]
                
            if let position = position, case let .linear(top, bottom) = position {
                if case let .Neighbour(_, _, spacing) = top, case let .overlap(overlap) = spacing {
                    currentContainerGroupOverlap = overlap
                }
                if case let .Neighbour(_, _, spacing) = bottom, case let .overlap(overlap) = spacing {
                    currentContainerGroupOverlap = overlap
                }
            }
            
            if let mosaicRange = mosaicRange, mosaicRange.contains(i), let (framesAndPositions, size) = calculatedGroupFramesAndSize {
                let mosaicIndex = i - mosaicRange.lowerBound
                
                if mosaicIndex == 0 && (i == 0 || (i == 1 && detachedContentNodesHeight > 0)) {
                    if !headerSize.height.isZero {
                        contentNodesHeight += 7.0
                        totalContentNodesHeight += 7.0
                    }
                }
                
                var contentNodeOriginY = contentNodesHeight
                if detachedContentNodesHeight > 0 {
                    contentNodeOriginY -= detachedContentNodesHeight - 4.0
                }
                
                let (_, apply) = finalize(maxContentWidth)
                let contentNodeFrame = framesAndPositions[mosaicIndex].0.offsetBy(dx: 0.0, dy: contentNodeOriginY)
                contentNodeFramesPropertiesAndApply.append((contentNodeFrame, properties, true, apply))
                
                if i == mosaicRange.upperBound - 1 {
                    unlockButtonPosition = CGPoint(x: size.width / 2.0, y: contentNodesHeight + size.height / 2.0)
                    mediaInfoOrigin = CGPoint(x: size.width, y: contentNodesHeight)
                    
                    contentNodesHeight += size.height
                    totalContentNodesHeight += size.height
                    
                    mosaicStatusOrigin = contentNodeFrame.bottomRight
                }
            } else {
                let contentProperties = contentPropertiesAndLayouts[i].3
                
                if (i == 0 || (i == 1 && detachedContentNodesHeight > 0)) && !headerSize.height.isZero {
                    if contentGroupId == nil {
                        contentNodesHeight += properties.headerSpacing
                    }
                    totalContentNodesHeight += properties.headerSpacing
                }
                                
                if currentContainerGroupId != contentGroupId {
                    if let containerGroupId = currentContainerGroupId {
                        var overlapOffset: CGFloat = 0.0
                        if !contentContainerNodeFrames.isEmpty {
                            overlapOffset = currentContainerGroupOverlap
                        }
                        var containerContentNodesOrigin = contentNodesHeight
                        var containerContentNodesHeight = contentNodesHeight
                        if detachedContentNodesHeight > 0 {
                            if contentContainerNodeFrames.isEmpty {
                                containerContentNodesHeight -= detachedContentNodesHeight - 4.0
                                containerContentNodesOrigin -= detachedContentNodesHeight - 4.0
                            }
                        }
                        let containerFrame = CGRect(x: 0.0, y: headerSize.height + totalContentNodesHeight - containerContentNodesOrigin - overlapOffset, width: maxContentWidth, height: containerContentNodesHeight)
                        contentContainerNodeFrames.append((containerGroupId, containerFrame, currentItemSelection, currentContainerGroupOverlap))
                                                
                        if !overlapOffset.isZero {
                            totalContentNodesHeight -= currentContainerGroupOverlap
                        }
                        if contentGroupId == nil {
                            totalContentNodesHeight += 3.0
                        }
                    }
                    contentNodesHeight = contentGroupId == nil ? totalContentNodesHeight : 0.0
                    currentContainerGroupId = contentGroupId
                    currentItemSelection = itemSelection
                }
                
                var contentNodeOriginY = contentNodesHeight
                if detachedContentNodesHeight > 0, contentContainerNodeFrames.isEmpty {
                    contentNodeOriginY -= detachedContentNodesHeight - 4.0
                }
                
                let (size, apply) = finalize(maxContentWidth)
                let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: contentNodeOriginY), size: size)
                contentNodeFramesPropertiesAndApply.append((containerFrame, properties, contentGroupId == nil, apply))
                
                if contentProperties.neighborType == .media && unlockButtonPosition == nil {
                    unlockButtonPosition = containerFrame.center
                    mediaInfoOrigin = CGPoint(x: containerFrame.width, y: containerFrame.minY)
                }
                
                contentNodesHeight += size.height
                totalContentNodesHeight += size.height
                
                if properties.isDetached {
                    detachedContentNodesHeight += size.height + 4.0
                    totalContentNodesHeight += 4.0
                }
            }
        }
        
        if let containerGroupId = currentContainerGroupId {
            var overlapOffset: CGFloat = 0.0
            if !contentContainerNodeFrames.isEmpty {
                overlapOffset = currentContainerGroupOverlap
            }
            var containerContentNodesOrigin = contentNodesHeight
            var containerContentNodesHeight = contentNodesHeight
            if detachedContentNodesHeight > 0 {
                if contentContainerNodeFrames.isEmpty {
                    containerContentNodesHeight -= detachedContentNodesHeight - 4.0
                    containerContentNodesOrigin -= detachedContentNodesHeight - 4.0
                }
            }
            contentContainerNodeFrames.append((containerGroupId, CGRect(x: 0.0, y: headerSize.height + totalContentNodesHeight - containerContentNodesOrigin - overlapOffset, width: maxContentWidth, height: containerContentNodesHeight), currentItemSelection, currentContainerGroupOverlap))
            if !overlapOffset.isZero {
                totalContentNodesHeight -= currentContainerGroupOverlap
            }
        }
        
        contentSize.height += totalContentNodesHeight
        
        if let paidContent = item.message.media.first(where: { $0 is TelegramMediaPaidContent }) as? TelegramMediaPaidContent, let media = paidContent.extendedMedia.first {
            var isLocked = false
            if case .preview = media {
                isLocked = true
            } else if item.presentationData.isPreview {
                isLocked = true
            }
            if isLocked {
                let sizeAndApply = unlockButtonLayout(ChatMessageUnlockMediaNode.Arguments(
                    presentationData: item.presentationData,
                    strings: item.presentationData.strings,
                    context: item.context,
                    controllerInteraction: item.controllerInteraction,
                    message: item.message,
                    media: paidContent,
                    constrainedSize: CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                ))
                unlockButtonSizeApply = (sizeAndApply.0, { synchronousLoads in sizeAndApply.1(synchronousLoads) })
            } else {
                let sizeAndApply = mediaInfoLayout(ChatMessageStarsMediaInfoNode.Arguments(
                    presentationData: item.presentationData,
                    context: item.context,
                    message: item.message,
                    media: paidContent,
                    constrainedSize: CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude),
                    animationCache: item.controllerInteraction.presentationContext.animationCache,
                    animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                ))
                mediaInfoSizeApply = (sizeAndApply.0, { synchronousLoads in sizeAndApply.1(synchronousLoads) })
            }
        }
        
        var actionButtonsSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode)?
        if let actionButtonsFinalize = actionButtonsFinalize {
            actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
        }
        
        var reactionButtonsSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode)?
        if let reactionButtonsFinalize = reactionButtonsFinalize {
            var maxContentWidth = maxContentWidth
            if hasInstantVideo {
                maxContentWidth = min(310.0, baseWidth - 84.0)
            }
            reactionButtonsSizeAndApply = reactionButtonsFinalize(maxContentWidth)
        }
                
        let minimalContentSize: CGSize
        if hideBackground {
            minimalContentSize = CGSize(width: 1.0, height: 1.0)
        } else {
            minimalContentSize = layoutConstants.bubble.minimumSize
        }
        let calculatedBubbleHeight = headerSize.height + contentSize.height + layoutConstants.bubble.contentInsets.top + layoutConstants.bubble.contentInsets.bottom
        let layoutBubbleSize = CGSize(width: max(contentSize.width, headerSize.width) + layoutConstants.bubble.contentInsets.left + layoutConstants.bubble.contentInsets.right, height: max(minimalContentSize.height, calculatedBubbleHeight - detachedContentNodesHeight))
        var contentVerticalOffset: CGFloat = 0.0
        if minimalContentSize.height > calculatedBubbleHeight + 2.0 {
            contentVerticalOffset = floorToScreenPixels((minimalContentSize.height - calculatedBubbleHeight) / 2.0)
        }
        
        let availableWidth = params.width - params.leftInset - params.rightInset
        let backgroundFrame: CGRect
        let contentOrigin: CGPoint
        let contentUpperRightCorner: CGPoint
        switch alignment {
            case .none:
                backgroundFrame = CGRect(origin: CGPoint(x: incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset) : (params.width - params.rightInset - layoutBubbleSize.width - layoutConstants.bubble.edgeInset - deliveryFailedInset), y: detachedContentNodesHeight + additionalTopHeight), size: layoutBubbleSize)
                contentOrigin = CGPoint(x: backgroundFrame.origin.x + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height + contentVerticalOffset)
                contentUpperRightCorner = CGPoint(x: backgroundFrame.maxX - (incoming ? layoutConstants.bubble.contentInsets.right : layoutConstants.bubble.contentInsets.left), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height)
            case .center:
                backgroundFrame = CGRect(origin: CGPoint(x: params.leftInset + floor((availableWidth - layoutBubbleSize.width) / 2.0), y: detachedContentNodesHeight), size: layoutBubbleSize)
                let contentOriginX: CGFloat
                if !hideBackground {
                    contentOriginX = (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right)
                } else {
                    contentOriginX = floor(layoutConstants.bubble.contentInsets.right + layoutConstants.bubble.contentInsets.left) / 2.0
                }
                contentOrigin = CGPoint(x: backgroundFrame.minX + contentOriginX, y: backgroundFrame.minY + layoutConstants.bubble.contentInsets.top + headerSize.height + contentVerticalOffset)
                contentUpperRightCorner = CGPoint(x: backgroundFrame.maxX - (incoming ? layoutConstants.bubble.contentInsets.right : layoutConstants.bubble.contentInsets.left), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height)
        }
        
        let bubbleContentWidth = maxContentWidth - layoutConstants.bubble.edgeInset * 2.0 - (layoutConstants.bubble.contentInsets.right + layoutConstants.bubble.contentInsets.left)

        var layoutSize = CGSize(width: params.width, height: layoutBubbleSize.height + detachedContentNodesHeight + additionalTopHeight)
        
        if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
            layoutSize.height += 4.0 + reactionButtonsSizeAndApply.0.height + 2.0
        }
        if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
            layoutSize.height += 1.0 + actionButtonsSizeAndApply.0.height
        }
        
        var layoutInsets = UIEdgeInsets(top: mergedTop.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
        if dateHeaderAtBottom.hasDate && dateHeaderAtBottom.hasTopic {
            layoutInsets.top += layoutConstants.timestampDateAndTopicHeaderHeight
        } else {
            if dateHeaderAtBottom.hasDate {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            if dateHeaderAtBottom.hasTopic {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            if isAd {
                layoutInsets.top += 4.0
            }
        }
        
        let layout = ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets)
        
        let graphics = PresentationResourcesChat.principalGraphics(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
        
        var updatedMergedTop = mergedBottom
        var updatedMergedBottom = mergedTop
        if mosaicRange == nil {
            if contentNodePropertiesAndFinalize.first?.0.forceFullCorners ?? false {
                updatedMergedTop = .semanticallyMerged
            }
            if headerSize.height.isZero && contentNodePropertiesAndFinalize.first?.0.forceFullCorners ?? false {
                updatedMergedBottom = .none
            }
            if actionButtonsSizeAndApply != nil || reactionButtonsSizeAndApply != nil {
                updatedMergedTop = .fullyMerged
            }
        }
        
        let disablesComments = !hasInstantVideo
        
        return (layout, { animation, applyInfo, synchronousLoads in
            return ChatMessageBubbleItemNode.applyLayout(selfReference: selfReference, animation, synchronousLoads,
                inputParams: (item, params, mergedTop, mergedBottom, dateHeaderAtBottom),
                params: params,
                applyInfo: applyInfo,
                layout: layout,
                item: item,
                forwardSource: forwardSource,
                forwardAuthorSignature: forwardAuthorSignature,
                accessibilityData: accessibilityData,
                actionButtonsSizeAndApply: actionButtonsSizeAndApply,
                reactionButtonsSizeAndApply: reactionButtonsSizeAndApply,
                updatedMergedTop: updatedMergedTop,
                updatedMergedBottom: updatedMergedBottom,
                hideBackground: hideBackground,
                incoming: incoming,
                graphics: graphics,
                presentationContext: item.controllerInteraction.presentationContext,
                bubbleContentWidth: bubbleContentWidth,
                backgroundFrame: backgroundFrame,
                deliveryFailedInset: deliveryFailedInset,
                nameNodeSizeApply: nameNodeSizeApply,
                viaWidth: viaWidth,
                contentOrigin: contentOrigin,
                nameNodeOriginY: nameNodeOriginY + detachedContentNodesHeight + additionalTopHeight,
                hasTitleAvatar: hasTitleAvatar,
                hasTitleTopicNavigation: hasTitleTopicNavigation,
                authorNameColor: authorNameColor,
                layoutConstants: layoutConstants,
                currentCredibilityIcon: currentCredibilityIcon,
                adminNodeSizeApply: adminNodeSizeApply,
                boostNodeSizeApply: boostNodeSizeApply,
                contentUpperRightCorner: contentUpperRightCorner,
                threadInfoSizeApply: threadInfoSizeApply,
                threadInfoOriginY: threadInfoOriginY + detachedContentNodesHeight + additionalTopHeight,
                forwardInfoSizeApply: forwardInfoSizeApply,
                forwardInfoOriginY: forwardInfoOriginY + detachedContentNodesHeight + additionalTopHeight,
                replyInfoSizeApply: replyInfoSizeApply,
                replyInfoOriginY: replyInfoOriginY + detachedContentNodesHeight + additionalTopHeight,
                removedContentNodeIndices: removedContentNodeIndices,
                updatedContentNodeOrder: updatedContentNodeOrder,
                addedContentNodes: addedContentNodes,
                contentNodeMessagesAndClasses: contentNodeMessagesAndClasses,
                contentNodeFramesPropertiesAndApply: contentNodeFramesPropertiesAndApply,
                contentContainerNodeFrames: contentContainerNodeFrames,
                mosaicStatusOrigin: mosaicStatusOrigin,
                mosaicStatusSizeAndApply: mosaicStatusSizeAndApply,
                unlockButtonPosition: unlockButtonPosition,
                unlockButtonSizeAndApply: unlockButtonSizeApply,
                mediaInfoOrigin: mediaInfoOrigin,
                mediaInfoSizeAndApply: mediaInfoSizeApply,
                needsShareButton: needsShareButton,
                shareButtonOffset: shareButtonOffset,
                avatarOffset: avatarOffset,
                hidesHeaders: hidesHeaders,
                disablesComments: disablesComments,
                alignment: alignment,
                isSidePanelOpen: isSidePanelOpen
            )
        })
    }
    
    private static func applyLayout(selfReference: Weak<ChatMessageBubbleItemNode>,
        _ animation: ListViewItemUpdateAnimation,
        _ synchronousLoads: Bool,
        inputParams: Params,
        params: ListViewItemLayoutParams,
        applyInfo: ListViewItemApply,
        layout: ListViewItemNodeLayout,
        item: ChatMessageItem,
        forwardSource: Peer?,
        forwardAuthorSignature: String?,
        accessibilityData: ChatMessageAccessibilityData,
        actionButtonsSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageActionButtonsNode)?,
        reactionButtonsSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode)?,
        updatedMergedTop: ChatMessageMerge,
        updatedMergedBottom: ChatMessageMerge,
        hideBackground: Bool,
        incoming: Bool,
        graphics: PrincipalThemeEssentialGraphics,
        presentationContext: ChatPresentationContext,
        bubbleContentWidth: CGFloat,
        backgroundFrame: CGRect,
        deliveryFailedInset: CGFloat,
        nameNodeSizeApply: (CGSize, () -> TextNode?),
        viaWidth: CGFloat,
        contentOrigin: CGPoint,
        nameNodeOriginY: CGFloat,
        hasTitleAvatar: Bool,
        hasTitleTopicNavigation: Bool,
        authorNameColor: UIColor?,
        layoutConstants: ChatMessageItemLayoutConstants,
        currentCredibilityIcon: (EmojiStatusComponent.Content, UIColor?)?,
        adminNodeSizeApply: (CGSize, () -> TextNode?),
        boostNodeSizeApply: (CGSize, () -> TextNode?),
        contentUpperRightCorner: CGPoint,
        threadInfoSizeApply: (CGSize, (Bool) -> ChatMessageThreadInfoNode?),
        threadInfoOriginY: CGFloat,
        forwardInfoSizeApply: (CGSize, (CGFloat) -> ChatMessageForwardInfoNode?),
        forwardInfoOriginY: CGFloat,
        replyInfoSizeApply: (CGSize, (CGSize, Bool, ListViewItemUpdateAnimation) -> ChatMessageReplyInfoNode?),
        replyInfoOriginY: CGFloat,
        removedContentNodeIndices: [Int]?,
        updatedContentNodeOrder: Bool,
        addedContentNodes: [(Message, Bool, ChatMessageBubbleContentNode, Int?)]?,
        contentNodeMessagesAndClasses: [(Message, AnyClass, ChatMessageEntryAttributes, BubbleItemAttributes)],
        contentNodeFramesPropertiesAndApply: [(CGRect, ChatMessageBubbleContentProperties, Bool, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void)],
        contentContainerNodeFrames: [(UInt32, CGRect, Bool?, CGFloat)],
        mosaicStatusOrigin: CGPoint?,
        mosaicStatusSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageDateAndStatusNode)?,
        unlockButtonPosition: CGPoint?,
        unlockButtonSizeAndApply: (CGSize, (Bool) -> ChatMessageUnlockMediaNode?),
        mediaInfoOrigin: CGPoint?,
        mediaInfoSizeAndApply: (CGSize, (Bool) -> ChatMessageStarsMediaInfoNode?),
        needsShareButton: Bool,
        shareButtonOffset: CGPoint?,
        avatarOffset: CGFloat?,
        hidesHeaders: Bool,
        disablesComments: Bool,
        alignment: ChatMessageBubbleContentAlignment,
        isSidePanelOpen: Bool
    ) -> Void {
        guard let strongSelf = selfReference.value else {
            return
        }
        
        strongSelf.currentInputParams = inputParams
        strongSelf.currentApplyParams = applyInfo
        
        if item.message.id.namespace == Namespaces.Message.Local || item.message.id.namespace == Namespaces.Message.ScheduledLocal || item.message.id.namespace == Namespaces.Message.QuickReplyLocal {
            strongSelf.wasPending = true
        }
        if strongSelf.wasPending && (item.message.id.namespace != Namespaces.Message.Local && item.message.id.namespace != Namespaces.Message.ScheduledLocal && item.message.id.namespace != Namespaces.Message.QuickReplyLocal) {
            strongSelf.didChangeFromPendingToSent = true
        }
        
        if case let .messageOptions(_, _, info) = item.associatedData.subject, case let .link(link) = info, link.isCentered {
            strongSelf.wantsTrailingItemSpaceUpdates = true
        } else {
            strongSelf.wantsTrailingItemSpaceUpdates = false
        }
        
        let themeUpdated = strongSelf.appliedItem?.presentationData.theme.theme !== item.presentationData.theme.theme
        let previousContextFrame = strongSelf.mainContainerNode.frame
        strongSelf.mainContainerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
        strongSelf.mainContextSourceNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
        strongSelf.mainContextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
        strongSelf.contentContainersWrapperNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
        
        strongSelf.appliedItem = item
        strongSelf.appliedForwardInfo = (forwardSource, forwardAuthorSignature)
        strongSelf.updateAccessibilityData(accessibilityData)
        strongSelf.disablesComments = disablesComments
        
        strongSelf.authorNameColor = authorNameColor
        
        strongSelf.replyRecognizer?.allowBothDirections = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        strongSelf.view.disablesInteractiveTransitionGestureRecognizer = false//!item.context.sharedContext.immediateExperimentalUISettings.unidirectionalSwipeToReply
        
        var animation = animation
        if strongSelf.mainContextSourceNode.isExtractedToContextPreview {
            animation = .System(duration: 0.25, transition: ControlledTransition(duration: 0.25, curve: .easeInOut, interactive: false))
        }
        
        var legacyTransition: ContainedViewLayoutTransition = .immediate
        if case let .System(duration, _) = animation {
            legacyTransition = .animated(duration: duration, curve: .spring)
        }
        
        var forceBackgroundSide = false
        if actionButtonsSizeAndApply != nil || reactionButtonsSizeAndApply != nil {
            forceBackgroundSide = true
        } else if case .semanticallyMerged = updatedMergedTop {
            forceBackgroundSide = true
        }
        let mergeType = ChatMessageBackgroundMergeType(top: updatedMergedTop == .fullyMerged, bottom: updatedMergedBottom == .fullyMerged, side: forceBackgroundSide)
        let backgroundType: ChatMessageBackgroundType
        if hideBackground {
            backgroundType = .none
        } else if !incoming {
            backgroundType = .outgoing(mergeType)
        } else {
            if case let .messageOptions(_, _, info) = item.associatedData.subject, case let .link(link) = info, link.isCentered {
                backgroundType = .incoming(.Extracted)
            } else if !item.presentationData.chatBubbleCorners.hasTails {
                backgroundType = .incoming(.Extracted)
            } else {
                backgroundType = .incoming(mergeType)
            }
        }
        let hasWallpaper = item.presentationData.theme.wallpaper.hasWallpaper
        if item.presentationData.theme.theme.forceSync {
            legacyTransition = .immediate
        }
        strongSelf.backgroundNode.setType(type: backgroundType, highlighted: false, graphics: graphics, maskMode: strongSelf.backgroundMaskMode, hasWallpaper: hasWallpaper, transition: legacyTransition, backgroundNode: presentationContext.backgroundNode)
        strongSelf.backgroundWallpaperNode.setType(type: backgroundType, theme: item.presentationData.theme, essentialGraphics: graphics, maskMode: strongSelf.backgroundMaskMode, backgroundNode: presentationContext.backgroundNode)
        strongSelf.shadowNode.setType(type: backgroundType, hasWallpaper: hasWallpaper, graphics: graphics)
        
        strongSelf.backgroundType = backgroundType
        
        strongSelf.backgroundNode.backgroundFrame = backgroundFrame
        
        if let avatarOffset {
            strongSelf.updateAttachedAvatarNodeOffset(offset: avatarOffset, transition: .animated(duration: 0.3, curve: .spring))
        }
        strongSelf.updateAttachedAvatarNodeIsHidden(isHidden: isSidePanelOpen, transition: animation.transition)
        strongSelf.updateAttachedDateHeader(hasDate: inputParams.dateHeaderAtBottom.hasDate, hasPeer: inputParams.dateHeaderAtBottom.hasTopic)
        
        let isFailed = item.content.firstMessage.effectivelyFailed(timestamp: item.context.account.network.getApproximateRemoteTimestamp())
        if isFailed {
            let deliveryFailedNode: ChatMessageDeliveryFailedNode
            var isAppearing = false
            if let current = strongSelf.deliveryFailedNode {
                deliveryFailedNode = current
            } else {
                isAppearing = true
                deliveryFailedNode = ChatMessageDeliveryFailedNode(tapped: { [weak strongSelf] in
                    if let item = strongSelf?.item {
                        item.controllerInteraction.requestRedeliveryOfFailedMessages(item.content.firstMessage.id)
                    }
                })
                strongSelf.deliveryFailedNode = deliveryFailedNode
                strongSelf.insertSubnode(deliveryFailedNode, belowSubnode: strongSelf.messageAccessibilityArea)
            }
            let deliveryFailedSize = deliveryFailedNode.updateLayout(theme: item.presentationData.theme.theme)
            let deliveryFailedFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX + deliveryFailedInset - deliveryFailedSize.width, y: backgroundFrame.maxY - deliveryFailedSize.height), size: deliveryFailedSize)
            if isAppearing {
                deliveryFailedNode.frame = deliveryFailedFrame
                legacyTransition.animatePositionAdditive(node: deliveryFailedNode, offset: CGPoint(x: deliveryFailedInset, y: 0.0))
            } else {
                animation.animator.updateFrame(layer: deliveryFailedNode.layer, frame: deliveryFailedFrame, completion: nil)
            }
        } else if let deliveryFailedNode = strongSelf.deliveryFailedNode {
            strongSelf.deliveryFailedNode = nil
            animation.animator.updateAlpha(layer: deliveryFailedNode.layer, alpha: 0.0, completion: nil)
            animation.animator.updateFrame(layer: deliveryFailedNode.layer, frame: deliveryFailedNode.frame.offsetBy(dx: 24.0, dy: 0.0), completion: { [weak deliveryFailedNode] _ in
                deliveryFailedNode?.removeFromSupernode()
            })
        }
        
        if let nameNode = nameNodeSizeApply.1() {
            strongSelf.nameNode = nameNode
            nameNode.displaysAsynchronously = !item.presentationData.isPreview && !item.presentationData.theme.theme.forceSync
            
            let previousNameNodeFrame = nameNode.frame
            
            var nameNodeFrame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY), size: nameNodeSizeApply.0)
            
            var nameNavigateButtonOffset: CGFloat = currentCredibilityIcon == nil ? 4.0 : 28.0
            nameNavigateButtonOffset += 34.0
            
            if hasTitleAvatar {
                let nameAvatarNode: AvatarNode
                var animateNameAvatar = true
                if let current = strongSelf.nameAvatarNode {
                    nameAvatarNode = current
                } else {
                    animateNameAvatar = false
                    nameAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                    strongSelf.nameAvatarNode = nameAvatarNode
                    strongSelf.clippingNode.addSubnode(nameAvatarNode)
                }
                
                let nameAvatarFrame = CGRect(origin: CGPoint(x: nameNodeFrame.minX, y: nameNodeFrame.minY - 4.0), size: CGSize(width: 26.0, height: 26.0))
                let nameNavigateFrame = CGRect(origin: CGPoint(x: nameNodeFrame.maxX + 4.0 + nameNavigateButtonOffset, y: nameNodeFrame.minY - 4.0), size: CGSize(width: 26.0, height: 26.0))
                
                if let peer = item.content.firstMessage.author, peer.smallProfileImage != nil {
                    nameAvatarNode.setPeerV2(context: item.context, theme: item.presentationData.theme.theme, peer: EnginePeer(peer), displayDimensions: nameAvatarFrame.size)
                } else {
                    nameAvatarNode.setPeer(context: item.context, theme: item.presentationData.theme.theme, peer: item.content.firstMessage.author.flatMap(EnginePeer.init), displayDimensions: nameAvatarFrame.size)
                }
                nameAvatarNode.updateSize(size: nameAvatarFrame.size)
                
                if hasTitleTopicNavigation {
                    let nameNavigateButton: NameNavigateButton
                    if let current = strongSelf.nameNavigateButton {
                        nameNavigateButton = current
                    } else {
                        nameNavigateButton = NameNavigateButton(frame: CGRect())
                        strongSelf.nameNavigateButton = nameNavigateButton
                        strongSelf.clippingNode.view.addSubview(nameNavigateButton)
                        nameNavigateButton.action = { [weak strongSelf] in
                            guard let strongSelf, let item = strongSelf.item else {
                                return
                            }
                            item.controllerInteraction.updateChatLocationThread(item.content.firstMessage.threadId, nil)
                        }
                    }
                    nameNavigateButton.update(size: nameNavigateFrame.size, color: authorNameColor ?? item.presentationData.theme.theme.chat.message.incoming.accentTextColor)
                } else {
                    if let nameNavigateButton = strongSelf.nameNavigateButton {
                        strongSelf.nameNavigateButton = nil
                        nameNavigateButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak nameNavigateButton] _ in
                            nameNavigateButton?.removeFromSuperview()
                        })
                        animation.animator.updateFrame(layer: nameNavigateButton.layer, frame: CGRect(origin: CGPoint(x: nameNodeFrame.maxX + nameNavigateButtonOffset - 26.0 * 0.5, y: nameNodeFrame.minY - 4.0), size: CGSize(width: 26.0, height: 26.0)), completion: nil)
                        animation.transition.updateTransformScale(layer: nameNavigateButton.layer, scale: CGPoint(x: 0.001, y: 0.001))
                    }
                }
                
                if animateNameAvatar {
                    animation.animator.updateFrame(layer: nameAvatarNode.layer, frame: nameAvatarFrame, completion: nil)
                    if let nameNavigateButton = strongSelf.nameNavigateButton {
                        animation.animator.updateFrame(layer: nameNavigateButton.layer, frame: nameNavigateFrame, completion: nil)
                    }
                } else {
                    nameAvatarNode.frame = CGRect(origin: CGPoint(x: previousNameNodeFrame.minX - 26.0 * 0.5, y: previousNameNodeFrame.minY - 4.0), size: CGSize(width: 26.0, height: 26.0))
                    animation.animator.updateFrame(layer: nameAvatarNode.layer, frame: nameAvatarFrame, completion: nil)
                    if animation.isAnimated {
                        animation.transition.animateTransformScale(view: nameAvatarNode.view, from: 0.001)
                        nameAvatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                    }
                    
                    if let nameNavigateButton = strongSelf.nameNavigateButton {
                        nameNavigateButton.frame = CGRect(origin: CGPoint(x: previousNameNodeFrame.maxX + nameNavigateButtonOffset - 26.0 * 0.5, y: previousNameNodeFrame.minY - 4.0), size: CGSize(width: 26.0, height: 26.0))
                        animation.animator.updateFrame(layer: nameNavigateButton.layer, frame: nameNavigateFrame, completion: nil)
                        if animation.isAnimated {
                            animation.transition.animateTransformScale(view: nameNavigateButton, from: 0.001)
                            nameNavigateButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                        }
                    }
                }
                
                nameNodeFrame.origin.x += 26.0 + 5.0
            } else {
                if let nameAvatarNode = strongSelf.nameAvatarNode {
                    strongSelf.nameAvatarNode = nil
                    nameAvatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak nameAvatarNode] _ in
                        nameAvatarNode?.removeFromSupernode()
                    })
                    animation.animator.updateFrame(layer: nameAvatarNode.layer, frame: CGRect(origin: CGPoint(x: nameNodeFrame.minX - 26.0 * 0.5, y: nameNodeFrame.minY - 4.0), size: CGSize(width: 26.0, height: 26.0)), completion: nil)
                    animation.transition.updateTransformScale(node: nameAvatarNode, scale: CGPoint(x: 0.001, y: 0.001))
                }
                if let nameNavigateButton = strongSelf.nameNavigateButton {
                    strongSelf.nameNavigateButton = nil
                    nameNavigateButton.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak nameNavigateButton] _ in
                        nameNavigateButton?.removeFromSuperview()
                    })
                    animation.animator.updateFrame(layer: nameNavigateButton.layer, frame: CGRect(origin: CGPoint(x: nameNodeFrame.maxX + nameNavigateButtonOffset - 26.0 * 0.5, y: nameNodeFrame.minY - 4.0), size: CGSize(width: 26.0, height: 26.0)), completion: nil)
                    animation.transition.updateTransformScale(layer: nameNavigateButton.layer, scale: CGPoint(x: 0.001, y: 0.001))
                }
            }
            
            if nameNode.supernode == nil {
                if !nameNode.isNodeLoaded {
                    nameNode.isUserInteractionEnabled = false
                }
                strongSelf.clippingNode.addSubnode(nameNode)
                nameNode.frame = nameNodeFrame
                
                if animation.isAnimated {
                    nameNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            } else {
                animation.animator.updateFrame(layer: nameNode.layer, frame: nameNodeFrame, completion: nil)
            }
            
            let nameButtonNode: HighlightTrackingButtonNode
            let nameHighlightNode: ASImageNode
            if let currentButton = strongSelf.nameButtonNode, let currentHighlight = strongSelf.nameHighlightNode {
                nameButtonNode = currentButton
                nameHighlightNode = currentHighlight
            } else {
                nameHighlightNode = ASImageNode()
                nameHighlightNode.alpha = 0.0
                nameHighlightNode.displaysAsynchronously = false
                nameHighlightNode.isUserInteractionEnabled = false
                strongSelf.clippingNode.addSubnode(nameHighlightNode)
                strongSelf.nameHighlightNode = nameHighlightNode
                
                nameButtonNode = HighlightTrackingButtonNode()
                nameButtonNode.highligthedChanged = { [weak nameHighlightNode] highlighted in
                    guard let nameHighlightNode else {
                        return
                    }
                    if highlighted {
                        nameHighlightNode.layer.removeAnimation(forKey: "opacity")
                        nameHighlightNode.alpha = 1.0
                    } else {
                        nameHighlightNode.alpha = 0.0
                        nameHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
                nameButtonNode.addTarget(strongSelf, action: #selector(strongSelf.nameButtonPressed), forControlEvents: .touchUpInside)
                strongSelf.clippingNode.addSubnode(nameButtonNode)
                strongSelf.nameButtonNode = nameButtonNode
            }
            var nameHiglightFrame = nameNodeFrame
            nameHiglightFrame.size.width -= viaWidth
            nameHighlightNode.frame = nameHiglightFrame.insetBy(dx: -2.0, dy: -1.0)
            nameButtonNode.frame = nameHiglightFrame.insetBy(dx: -2.0, dy: -3.0)
            
            let nameColor = authorNameColor ?? item.presentationData.theme.theme.chat.message.outgoing.accentTextColor
            if themeUpdated {
                nameHighlightNode.image = generateFilledRoundedRectImage(size: CGSize(width: 8.0, height: 8.0), cornerRadius: 4.0, color: nameColor.withAlphaComponent(0.1))?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 4)
            }
            
            if let (currentCredibilityIcon, currentParticleColor) = currentCredibilityIcon {
                let credibilityIconView: ComponentHostView<Empty>
                var animateCredibilityIconFrame = true
                if let current = strongSelf.credibilityIconView {
                    credibilityIconView = current
                } else {
                    animateCredibilityIconFrame = false
                    credibilityIconView = ComponentHostView<Empty>()
                    credibilityIconView.isUserInteractionEnabled = false
                    strongSelf.credibilityIconView = credibilityIconView
                    strongSelf.clippingNode.view.addSubview(credibilityIconView)
                    
                    if animation.isAnimated {
                        credibilityIconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                
                let credibilityIconComponent = EmojiStatusComponent(
                    context: item.context,
                    animationCache: item.context.animationCache,
                    animationRenderer: item.context.animationRenderer,
                    content: currentCredibilityIcon,
                    particleColor: currentParticleColor,
                    isVisibleForAnimations: strongSelf.visibilityStatus,
                    action: nil
                )
                strongSelf.credibilityIconComponent = credibilityIconComponent
                strongSelf.credibilityIconContent = currentCredibilityIcon
                
                let credibilityIconSize = credibilityIconView.update(
                    transition: .immediate,
                    component: AnyComponent(credibilityIconComponent),
                    environment: {},
                    containerSize: CGSize(width: 20.0, height: 20.0)
                )
                
                let credibilityIconFrame = CGRect(origin: CGPoint(x: nameNode.frame.maxX + 3.0, y: nameNode.frame.minY + floor((nameNode.bounds.height - credibilityIconSize.height) / 2.0)), size: credibilityIconSize)
                if !animateCredibilityIconFrame {
                    credibilityIconView.frame = CGRect(origin: CGPoint(x: previousNameNodeFrame.maxX + 3.0, y: previousNameNodeFrame.minY + floor((previousNameNodeFrame.height - credibilityIconSize.height) / 2.0)), size: credibilityIconSize)
                }
                animation.animator.updateFrame(layer: credibilityIconView.layer, frame: credibilityIconFrame, completion: nil)
                
                let credibilityButtonNode: HighlightTrackingButtonNode
                let credibilityHighlightNode: ASImageNode
                if let currentButton = strongSelf.credibilityButtonNode, let currentHighlight = strongSelf.credibilityHighlightNode {
                    credibilityButtonNode = currentButton
                    credibilityHighlightNode = currentHighlight
                } else {
                    credibilityHighlightNode = ASImageNode()
                    credibilityHighlightNode.alpha = 0.0
                    credibilityHighlightNode.displaysAsynchronously = false
                    credibilityHighlightNode.isUserInteractionEnabled = false
                    strongSelf.clippingNode.addSubnode(credibilityHighlightNode)
                    strongSelf.credibilityHighlightNode = credibilityHighlightNode
                    
                    credibilityButtonNode = HighlightTrackingButtonNode()
                    credibilityButtonNode.highligthedChanged = { [weak credibilityHighlightNode] highlighted in
                        guard let credibilityHighlightNode else {
                            return
                        }
                        if highlighted {
                            credibilityHighlightNode.layer.removeAnimation(forKey: "opacity")
                            credibilityHighlightNode.alpha = 1.0
                        } else {
                            credibilityHighlightNode.alpha = 0.0
                            credibilityHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                        }
                    }
                    credibilityButtonNode.addTarget(strongSelf, action: #selector(strongSelf.credibilityButtonPressed), forControlEvents: .touchUpInside)
                    strongSelf.clippingNode.addSubnode(credibilityButtonNode)
                    strongSelf.credibilityButtonNode = credibilityButtonNode
                }
                credibilityHighlightNode.frame = credibilityIconFrame.insetBy(dx: -1.0, dy: -1.0)
                credibilityButtonNode.frame = credibilityIconFrame.insetBy(dx: -2.0, dy: -3.0)
                
                if themeUpdated || credibilityHighlightNode.image == nil {
                    credibilityHighlightNode.image = generateFilledRoundedRectImage(size: CGSize(width: 8.0, height: 8.0), cornerRadius: 4.0, color: nameColor.withAlphaComponent(0.1))?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 4)
                }
            } else {
                strongSelf.credibilityIconView?.removeFromSuperview()
                strongSelf.credibilityIconView = nil
                strongSelf.credibilityIconContent = nil
                strongSelf.credibilityButtonNode?.removeFromSupernode()
                strongSelf.credibilityButtonNode = nil
                strongSelf.credibilityHighlightNode?.removeFromSupernode()
                strongSelf.credibilityHighlightNode = nil
            }
            
            var boostCount: Int = 0
            if incoming {
                for attribute in item.message.attributes {
                    if let attribute = attribute as? BoostCountMessageAttribute {
                        boostCount = attribute.count
                    }
                }
            }
            
            var rightContentOffset: CGFloat = 0.0
            if let boostBadgeNode = boostNodeSizeApply.1() {
                boostBadgeNode.alpha = 0.75
                strongSelf.boostBadgeNode = boostBadgeNode
                let boostBadgeFrame = CGRect(origin: CGPoint(x: contentUpperRightCorner.x - layoutConstants.text.bubbleInsets.left - boostNodeSizeApply.0.width, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY + 1.0 - UIScreenPixel), size: boostNodeSizeApply.0)
                if boostBadgeNode.supernode == nil {
                    if !boostBadgeNode.isNodeLoaded {
                        boostBadgeNode.isUserInteractionEnabled = false
                    }
                    strongSelf.clippingNode.addSubnode(boostBadgeNode)
                    boostBadgeNode.frame = boostBadgeFrame
                    
                    if animation.isAnimated {
                        boostBadgeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                } else {
                    animation.animator.updateFrame(layer: boostBadgeNode.layer, frame: boostBadgeFrame, completion: nil)
                }
            } else {
                strongSelf.boostBadgeNode?.removeFromSupernode()
                strongSelf.boostBadgeNode = nil
            }
            
            if boostCount > 0 {
                var boostTotalWidth: CGFloat = 22.0
                if boostNodeSizeApply.0.width > 0.0 {
                    boostTotalWidth += boostNodeSizeApply.0.width
                    rightContentOffset += boostTotalWidth
                } else {
                    boostTotalWidth -= 6.0
                    rightContentOffset += boostTotalWidth - 2.0
                }
                
                
                let boostIconFrame = CGRect(origin: CGPoint(x: contentUpperRightCorner.x - layoutConstants.text.bubbleInsets.left - boostTotalWidth + 4.0, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY + 1.0 - UIScreenPixel - 3.0), size: CGSize(width: boostTotalWidth, height: 22.0))

                let previousBoostCount = strongSelf.boostCount
                
                let boostIconNode: UIImageView
                let boostButtonNode: HighlightTrackingButtonNode
                let boostHighlightNode: ASImageNode
                if let currentIcon = strongSelf.boostIconNode, let currentButton = strongSelf.boostButtonNode, let currentHighlight = strongSelf.boostHighlightNode {
                    boostIconNode = currentIcon
                    boostButtonNode = currentButton
                    boostHighlightNode = currentHighlight
                } else {
                    boostIconNode = UIImageView()
                    boostIconNode.alpha = 0.75
                    
                    strongSelf.clippingNode.view.addSubview(boostIconNode)
                    strongSelf.boostIconNode = boostIconNode
                    
                    boostHighlightNode = ASImageNode()
                    boostHighlightNode.alpha = 0.0
                    boostHighlightNode.displaysAsynchronously = false
                    boostHighlightNode.isUserInteractionEnabled = false
                    strongSelf.clippingNode.addSubnode(boostHighlightNode)
                    strongSelf.boostHighlightNode = boostHighlightNode
                    
                    boostButtonNode = HighlightTrackingButtonNode()
                    boostButtonNode.highligthedChanged = { [weak boostHighlightNode] highlighted in
                        guard let boostHighlightNode else {
                            return
                        }
                        if highlighted {
                            boostHighlightNode.layer.removeAnimation(forKey: "opacity")
                            boostHighlightNode.alpha = 1.0
                        } else {
                            boostHighlightNode.alpha = 0.0
                            boostHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                        }
                    }
                    boostButtonNode.addTarget(strongSelf, action: #selector(strongSelf.boostButtonPressed), forControlEvents: .touchUpInside)
                    strongSelf.clippingNode.addSubnode(boostButtonNode)
                    strongSelf.boostButtonNode = boostButtonNode
                }
                
                if boostCount != previousBoostCount {
                    boostIconNode.image = UIImage(bundleImageName: boostCount == 1 ? "Chat/Message/Boost" : "Chat/Message/Boosts")?.withRenderingMode(.alwaysTemplate)
                }
                
                boostIconNode.tintColor = nameColor
                
                if let iconSize = boostIconNode.image?.size {
                    boostIconNode.frame = CGRect(origin: CGPoint(x: boostTotalWidth > 22.0 ? boostIconFrame.minX + 3.0 : boostIconFrame.midX - iconSize.width / 2.0, y: boostIconFrame.midY - iconSize.height / 2.0), size: iconSize)
                }
                
                boostHighlightNode.frame = boostIconFrame
                boostButtonNode.frame = boostIconFrame.insetBy(dx: -2.0, dy: -3.0)
                
                if themeUpdated || boostHighlightNode.image == nil {
                    boostHighlightNode.image = generateFilledRoundedRectImage(size: CGSize(width: 8.0, height: 8.0), cornerRadius: 4.0, color: nameColor.withAlphaComponent(0.1))?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 4)
                }
            } else {
                strongSelf.boostButtonNode?.removeFromSupernode()
                strongSelf.boostButtonNode = nil
                strongSelf.boostHighlightNode?.removeFromSupernode()
                strongSelf.boostHighlightNode = nil
                strongSelf.boostIconNode?.removeFromSuperview()
                strongSelf.boostIconNode = nil
            }
            strongSelf.boostCount = boostCount
            
            if let adminBadgeNode = adminNodeSizeApply.1() {
                strongSelf.adminBadgeNode = adminBadgeNode
                let adminBadgeFrame = CGRect(origin: CGPoint(x: contentUpperRightCorner.x - layoutConstants.text.bubbleInsets.left - rightContentOffset - adminNodeSizeApply.0.width, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY + 1.0 - UIScreenPixel), size: adminNodeSizeApply.0)
                if adminBadgeNode.supernode == nil {
                    if !adminBadgeNode.isNodeLoaded {
                        adminBadgeNode.isUserInteractionEnabled = false
                    }
                    strongSelf.clippingNode.addSubnode(adminBadgeNode)
                    adminBadgeNode.frame = adminBadgeFrame
                    
                    if animation.isAnimated {
                        adminBadgeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                } else {
                    animation.animator.updateFrame(layer: adminBadgeNode.layer, frame: adminBadgeFrame, completion: nil)
                }
            } else {
                strongSelf.adminBadgeNode?.removeFromSupernode()
                strongSelf.adminBadgeNode = nil
            }
            
            if let _ = item.message.adAttribute {
                let buttonNode: HighlightTrackingButtonNode
                let iconNode: ASImageNode
                if let currentButton = strongSelf.closeButtonNode, let currentIcon = strongSelf.closeIconNode {
                    buttonNode = currentButton
                    iconNode = currentIcon
                } else {
                    buttonNode = HighlightTrackingButtonNode()
                    iconNode = ASImageNode()
                    iconNode.displaysAsynchronously = false
                    iconNode.isUserInteractionEnabled = false
                    
                    buttonNode.addTarget(strongSelf, action: #selector(strongSelf.closeButtonPressed), forControlEvents: .touchUpInside)
                    buttonNode.highligthedChanged = { [weak iconNode] highlighted in
                        guard let iconNode else {
                            return
                        }
                        if highlighted {
                            iconNode.layer.removeAnimation(forKey: "opacity")
                            iconNode.alpha = 0.4
                        } else {
                            iconNode.alpha = 1.0
                            iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                        }
                    }
                    
                    strongSelf.clippingNode.addSubnode(buttonNode)
                    strongSelf.clippingNode.addSubnode(iconNode)
                    
                    strongSelf.closeButtonNode = buttonNode
                    strongSelf.closeIconNode = iconNode
                }
                               
                iconNode.image = PresentationResourcesChat.chatBubbleCloseIcon(item.presentationData.theme.theme)
                
                let closeButtonSize = CGSize(width: 32.0, height: 32.0)
                let closeIconSize = CGSize(width: 12.0, height: 12.0)
                let closeButtonFrame = CGRect(origin: CGPoint(x: contentUpperRightCorner.x - closeButtonSize.width, y: layoutConstants.bubble.contentInsets.top), size: closeButtonSize)
                let closeButtonIconFrame = CGRect(origin: CGPoint(x: contentUpperRightCorner.x - layoutConstants.text.bubbleInsets.left - closeIconSize.width + 1.0, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY + 2.0), size: closeIconSize)
                
                animation.animator.updateFrame(layer: buttonNode.layer, frame: closeButtonFrame, completion: nil)
                animation.animator.updateFrame(layer: iconNode.layer, frame: closeButtonIconFrame, completion: nil)
            } else {
                strongSelf.closeButtonNode?.removeFromSupernode()
                strongSelf.closeButtonNode = nil
                strongSelf.closeIconNode?.removeFromSupernode()
                strongSelf.closeIconNode = nil
            }
        } else {
            if animation.isAnimated {
                if let nameAvatarNode = strongSelf.nameAvatarNode {
                    strongSelf.nameAvatarNode = nil
                    nameAvatarNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak nameAvatarNode] _ in
                        nameAvatarNode?.removeFromSupernode()
                    })
                }
                if let nameNode = strongSelf.nameNode {
                    strongSelf.nameNode = nil
                    nameNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak nameNode] _ in
                        nameNode?.removeFromSupernode()
                    })
                }
                if let adminBadgeNode = strongSelf.adminBadgeNode {
                    strongSelf.adminBadgeNode = nil
                    adminBadgeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak adminBadgeNode] _ in
                        adminBadgeNode?.removeFromSupernode()
                    })
                }
                if let credibilityIconView = strongSelf.credibilityIconView {
                    strongSelf.credibilityIconView = nil
                    credibilityIconView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak credibilityIconView] _ in
                        credibilityIconView?.removeFromSuperview()
                    })
                }
                if let boostBadgeNode = strongSelf.boostBadgeNode {
                    strongSelf.boostBadgeNode = nil
                    boostBadgeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak boostBadgeNode] _ in
                        boostBadgeNode?.removeFromSupernode()
                    })
                }
                if let boostIconNode = strongSelf.boostIconNode {
                    strongSelf.boostIconNode = nil
                    boostIconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak boostIconNode] _ in
                        boostIconNode?.removeFromSuperview()
                    })
                }
            } else {
                strongSelf.nameAvatarNode?.removeFromSupernode()
                strongSelf.nameAvatarNode = nil
                strongSelf.nameNavigateButton?.removeFromSuperview()
                strongSelf.nameNavigateButton = nil
                strongSelf.nameNode?.removeFromSupernode()
                strongSelf.nameNode = nil
                strongSelf.adminBadgeNode?.removeFromSupernode()
                strongSelf.adminBadgeNode = nil
                strongSelf.credibilityIconView?.removeFromSuperview()
                strongSelf.credibilityIconView = nil
                strongSelf.boostBadgeNode?.removeFromSupernode()
                strongSelf.boostBadgeNode = nil
                strongSelf.boostIconNode?.removeFromSuperview()
                strongSelf.boostIconNode = nil
            }
            strongSelf.nameButtonNode?.removeFromSupernode()
            strongSelf.nameButtonNode = nil
            strongSelf.nameHighlightNode?.removeFromSupernode()
            strongSelf.nameHighlightNode = nil
            strongSelf.credibilityButtonNode?.removeFromSupernode()
            strongSelf.credibilityButtonNode = nil
            strongSelf.credibilityHighlightNode?.removeFromSupernode()
            strongSelf.credibilityHighlightNode = nil
            strongSelf.boostButtonNode?.removeFromSupernode()
            strongSelf.boostButtonNode = nil
            strongSelf.boostHighlightNode?.removeFromSupernode()
            strongSelf.boostHighlightNode = nil
        }
            
        let timingFunction = kCAMediaTimingFunctionSpring        
        if let forwardInfoNode = forwardInfoSizeApply.1(bubbleContentWidth) {
            strongSelf.forwardInfoNode = forwardInfoNode
            var animateFrame = true
            if forwardInfoNode.supernode == nil {
                strongSelf.clippingNode.addSubnode(forwardInfoNode)
                animateFrame = false
                forwardInfoNode.openPsa = { [weak strongSelf] type, sourceNode in
                    guard let strongSelf = strongSelf, let item = strongSelf.item else {
                        return
                    }
                    item.controllerInteraction.displayPsa(type, sourceNode)
                }
                
                if animation.isAnimated {
                    forwardInfoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            let previousForwardInfoNodeFrame = forwardInfoNode.frame
            let forwardInfoFrame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + forwardInfoOriginY), size: CGSize(width: bubbleContentWidth, height: forwardInfoSizeApply.0.height))
            if case let .System(duration, _) = animation {
                if animateFrame {
                    forwardInfoNode.frame = forwardInfoFrame
                    forwardInfoNode.layer.animateFrame(from: previousForwardInfoNodeFrame, to: forwardInfoFrame, duration: duration, timingFunction: timingFunction)
                } else {
                    forwardInfoNode.frame = forwardInfoFrame
                }
            } else {
                forwardInfoNode.frame = forwardInfoFrame
            }
        } else {
            if animation.isAnimated {
                if let forwardInfoNode = strongSelf.forwardInfoNode {
                    strongSelf.forwardInfoNode = nil
                    forwardInfoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak forwardInfoNode] _ in
                        forwardInfoNode?.removeFromSupernode()
                    })
                }
            } else {
                strongSelf.forwardInfoNode?.removeFromSupernode()
                strongSelf.forwardInfoNode = nil
            }
        }
        
        if let threadInfoNode = threadInfoSizeApply.1(synchronousLoads) {
            strongSelf.threadInfoNode = threadInfoNode
            var animateFrame = true
            if threadInfoNode.supernode == nil {
                strongSelf.clippingNode.addSubnode(threadInfoNode)
                animateFrame = false
                
                threadInfoNode.visibility = strongSelf.visibility != .none
                
                if animation.isAnimated {
                    threadInfoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            let previousThreadInfoNodeFrame = threadInfoNode.frame
            threadInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + threadInfoOriginY), size: threadInfoSizeApply.0)
            if case let .System(duration, _) = animation {
                if animateFrame {
                    threadInfoNode.layer.animateFrame(from: previousThreadInfoNodeFrame, to: threadInfoNode.frame, duration: duration, timingFunction: timingFunction)
                }
            }
        } else {
            if animation.isAnimated {
                if let threadInfoNode = strongSelf.threadInfoNode {
                    strongSelf.threadInfoNode = nil
                    threadInfoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak threadInfoNode] _ in
                        threadInfoNode?.removeFromSupernode()
                    })
                }
            } else {
                strongSelf.threadInfoNode?.removeFromSupernode()
                strongSelf.threadInfoNode = nil
            }
        }
        
        let replyInfoFrame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + replyInfoOriginY), size: CGSize(width: backgroundFrame.width - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right - 6.0, height: replyInfoSizeApply.0.height))
        if let replyInfoNode = replyInfoSizeApply.1(replyInfoFrame.size, synchronousLoads, animation) {
            strongSelf.replyInfoNode = replyInfoNode
            var animateFrame = true
            if replyInfoNode.supernode == nil {
                strongSelf.clippingNode.addSubnode(replyInfoNode)
                animateFrame = false
                
                replyInfoNode.visibility = strongSelf.visibility != .none
                
                if animation.isAnimated {
                    replyInfoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            let previousReplyInfoNodeFrame = replyInfoNode.frame
            replyInfoNode.frame = replyInfoFrame
            if case let .System(duration, _) = animation {
                if animateFrame {
                    replyInfoNode.layer.animateFrame(from: previousReplyInfoNodeFrame, to: replyInfoNode.frame, duration: duration, timingFunction: timingFunction)
                }
            }
        } else {
            if animation.isAnimated {
                if let replyInfoNode = strongSelf.replyInfoNode {
                    strongSelf.replyInfoNode = nil
                    replyInfoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak replyInfoNode] _ in
                        replyInfoNode?.removeFromSupernode()
                    })
                }
            } else {
                strongSelf.replyInfoNode?.removeFromSupernode()
                strongSelf.replyInfoNode = nil
            }
        }
        
        var incomingOffset: CGFloat = 0.0
        switch backgroundType {
        case .incoming:
            incomingOffset = 5.0
        default:
            break
        }
        
        var index = 0
        var hasSelection = false
        for (stableId, relativeFrame, itemSelection, groupOverlap) in contentContainerNodeFrames {
            if let itemSelection = itemSelection, itemSelection {
                hasSelection = true
            }
            var contentContainer: ContentContainer? = strongSelf.contentContainers.first(where: { $0.contentMessageStableId == stableId })
            
            let previousContextFrame = contentContainer?.containerNode.frame
            let previousContextContentFrame = contentContainer?.sourceNode.contentRect
            
            if contentContainer == nil {
                let container = ContentContainer(contentMessageStableId: stableId)
                let contextSourceNode = container.sourceNode
                let containerNode = container.containerNode
                
                container.containerNode.shouldBegin = { [weak strongSelf, weak containerNode] location in
                    guard let strongSelf = strongSelf, let strongContainerNode = containerNode else {
                        return false
                    }
                    
                    if strongSelf.contentContainers.count < 2 {
                        return false
                    }
                    
                    let location = location.offsetBy(dx: 0.0, dy: strongContainerNode.frame.minY)
                    if !strongSelf.backgroundNode.frame.contains(location) {
                        return false
                    }
                    if strongSelf.selectionNode != nil {
                        return false
                    }
                    if let action = strongSelf.gestureRecognized(gesture: .tap, location: location, recognizer: nil) {
                        if case .action = action {
                            return false
                        }
                    }
                    if let action = strongSelf.gestureRecognized(gesture: .longTap, location: location, recognizer: nil) {
                        switch action {
                        case .action, .optionalAction:
                            return false
                        case let .openContextMenu(openContextMenu):
                            return !openContextMenu.selectAll
                        }
                    }
                    return true
                }
                containerNode.activated = { [weak strongSelf, weak containerNode] gesture, location in
                    guard let strongSelf = strongSelf, let strongContainerNode = containerNode else {
                        return
                    }
                    
                    let location = location.offsetBy(dx: 0.0, dy: strongContainerNode.frame.minY)
                    strongSelf.mainContainerNode.activated?(gesture, location)
                }
            
                containerNode.addSubnode(contextSourceNode)
                containerNode.targetNodeForActivationProgress = contextSourceNode.contentNode
                strongSelf.contentContainersWrapperNode.addSubnode(containerNode)
                
                contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak strongSelf, weak container, weak contextSourceNode] isExtractedToContextPreview, transition in
                    guard let strongSelf = strongSelf, let strongContextSourceNode = contextSourceNode else {
                        return
                    }
                    container?.willUpdateIsExtractedToContextPreview(isExtractedToContextPreview: isExtractedToContextPreview, transition: transition)
                    for contentNode in strongSelf.contentNodes {
                        if contentNode.supernode === strongContextSourceNode.contentNode {
                            contentNode.willUpdateIsExtractedToContextPreview(isExtractedToContextPreview)
                        }
                    }
                }
                contextSourceNode.isExtractedToContextPreviewUpdated = { [weak strongSelf, weak container, weak contextSourceNode] isExtractedToContextPreview in
                    guard let strongSelf = strongSelf, let strongContextSourceNode = contextSourceNode else {
                        return
                    }
                    
                    container?.isExtractedToContextPreviewUpdated(isExtractedToContextPreview)

                    if !isExtractedToContextPreview, let (rect, size) = container?.absoluteRect {
                        container?.updateAbsoluteRect(rect, within: size)
                    }
                    
                    for contentNode in strongSelf.contentNodes {
                        if contentNode.supernode === strongContextSourceNode.contentNode {
                            contentNode.updateIsExtractedToContextPreview(isExtractedToContextPreview)
                        }
                    }
                }
                
                contextSourceNode.updateAbsoluteRect = { [weak strongSelf, weak container, weak contextSourceNode] rect, size in
                    guard let _ = strongSelf, let strongContextSourceNode = contextSourceNode, strongContextSourceNode.isExtractedToContextPreview else {
                        return
                    }
                    container?.updateAbsoluteRect(relativeFrame.offsetBy(dx: rect.minX, dy: rect.minY), within: size)
                }
                contextSourceNode.applyAbsoluteOffset = { [weak strongSelf, weak container, weak contextSourceNode] value, animationCurve, duration in
                    guard let _ = strongSelf, let strongContextSourceNode = contextSourceNode, strongContextSourceNode.isExtractedToContextPreview else {
                        return
                    }
                    container?.applyAbsoluteOffset(value: value, animationCurve: animationCurve, duration: duration)
                }
                contextSourceNode.applyAbsoluteOffsetSpring = { [weak strongSelf, weak container, weak contextSourceNode] value, duration, damping in
                    guard let _ = strongSelf, let strongContextSourceNode = contextSourceNode, strongContextSourceNode.isExtractedToContextPreview else {
                        return
                    }
                    container?.applyAbsoluteOffsetSpring(value: value, duration: duration, damping: damping)
                }
                
                strongSelf.contentContainers.append(container)
                contentContainer = container
            }
            
            let containerFrame = CGRect(origin: relativeFrame.origin, size: CGSize(width: params.width, height: relativeFrame.size.height))
            contentContainer?.sourceNode.frame = CGRect(origin: CGPoint(), size: containerFrame.size)
            contentContainer?.sourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: containerFrame.size)
            
            contentContainer?.containerNode.frame = containerFrame
            
            contentContainer?.sourceNode.contentRect = CGRect(origin: CGPoint(x: backgroundFrame.minX + incomingOffset, y: 0.0), size: relativeFrame.size)
            contentContainer?.containerNode.targetNodeForActivationProgressContentRect = CGRect(origin: CGPoint(x: backgroundFrame.minX + incomingOffset, y: 0.0), size: relativeFrame.size)
            
            if previousContextFrame?.size != contentContainer?.containerNode.bounds.size || previousContextContentFrame != contentContainer?.sourceNode.contentRect {
                contentContainer?.sourceNode.layoutUpdated?(relativeFrame.size, animation)
            }
            
            var selectionInsets = UIEdgeInsets()
            if index == 0 {
                selectionInsets.bottom = groupOverlap / 2.0
            } else if index == contentContainerNodeFrames.count - 1 {
                selectionInsets.top = groupOverlap / 2.0
            } else {
                selectionInsets.top = groupOverlap / 2.0
                selectionInsets.bottom = groupOverlap / 2.0
            }
            
            contentContainer?.update(size: relativeFrame.size, contentOrigin: contentOrigin, selectionInsets: selectionInsets, index: index, presentationData: item.presentationData, graphics: graphics, backgroundType: backgroundType, presentationContext: item.controllerInteraction.presentationContext, mediaBox: item.context.account.postbox.mediaBox, messageSelection: itemSelection)
                        
            index += 1
        }
        
        if hasSelection {
            var currentMaskView: UIImageView?
            if let maskView = strongSelf.contentContainersWrapperNode.view.mask as? UIImageView {
                currentMaskView = maskView
            } else {
                currentMaskView = UIImageView()
                strongSelf.contentContainersWrapperNode.view.mask = currentMaskView
            }
            
            currentMaskView?.frame = CGRect(origin: CGPoint(x: backgroundFrame.minX, y: 0.0), size: backgroundFrame.size).insetBy(dx: -1.0, dy: -1.0)
            currentMaskView?.image = bubbleMaskForType(backgroundType, graphics: graphics)
        } else {
            strongSelf.contentContainersWrapperNode.view.mask = nil
        }
        
        var animateTextAndWebpagePositionSwap: Bool?
        var bottomStatusNodeAnimationSourcePosition: CGPoint?
        
        if removedContentNodeIndices?.count ?? 0 != 0 || addedContentNodes?.count ?? 0 != 0 || updatedContentNodeOrder {
            var updatedContentNodes = strongSelf.contentNodes
            
            if let removedContentNodeIndices = removedContentNodeIndices {
                for index in removedContentNodeIndices.reversed() {
                    if index >= 0 && index < updatedContentNodes.count {
                        let node = updatedContentNodes[index]
                        if animation.isAnimated {
                            node.animateRemovalFromBubble(0.2, completion: { [weak node] in
                                node?.removeFromSupernode()
                            })
                        } else {
                            node.removeFromSupernode()
                        }
                        let _ = updatedContentNodes.remove(at: index)
                    }
                }
            }
            
            if let addedContentNodes = addedContentNodes {
                for (contentNodeMessage, isAttachment, contentNode, _) in addedContentNodes {
                    let index = updatedContentNodes.count
                    updatedContentNodes.append(contentNode)
                    
                    if index < contentNodeFramesPropertiesAndApply.count && contentNodeFramesPropertiesAndApply[index].1.isDetached {
                        strongSelf.addSubnode(contentNode)
                    } else {
                        let contextSourceNode: ContextExtractedContentContainingNode
                        let containerSupernode: ASDisplayNode
                        if isAttachment {
                            contextSourceNode = strongSelf.mainContextSourceNode
                            containerSupernode = strongSelf.clippingNode
                        } else {
                            contextSourceNode = strongSelf.contentContainers.first(where: { $0.contentMessageStableId == contentNodeMessage.stableId })?.sourceNode ?? strongSelf.mainContextSourceNode
                            containerSupernode = strongSelf.contentContainers.first(where: { $0.contentMessageStableId == contentNodeMessage.stableId })?.sourceNode.contentNode ?? strongSelf.clippingNode
                        }
                        containerSupernode.addSubnode(contentNode)
                        contentNode.updateIsTextSelectionActive = { [weak contextSourceNode] value in
                            contextSourceNode?.updateDistractionFreeMode?(value)
                        }
                        contentNode.updateIsExtractedToContextPreview(contextSourceNode.isExtractedToContextPreview)
                    }
                    
                    contentNode.itemNode = strongSelf
                    contentNode.bubbleBackgroundNode = strongSelf.backgroundNode
                    contentNode.bubbleBackdropNode = strongSelf.backgroundWallpaperNode

                    contentNode.requestInlineUpdate = { [weak strongSelf] in
                        guard let strongSelf else {
                            return
                        }
                        
                        strongSelf.internalUpdateLayout()
                    }
                }
            }
            
            var sortedContentNodes: [ChatMessageBubbleContentNode] = []
            outer: for contentItemValue in contentNodeMessagesAndClasses {
                let contentItem = contentItemValue as (message: Message, type: AnyClass, ChatMessageEntryAttributes, attributes: BubbleItemAttributes)
                if let addedContentNodes = addedContentNodes {
                    for (contentNodeMessage, _, contentNode, index) in addedContentNodes {
                        if type(of: contentNode) == contentItem.type && index == contentItem.attributes.index && contentNodeMessage.stableId == contentItem.message.stableId {
                            sortedContentNodes.append(contentNode)
                            continue outer
                        }
                    }
                }
                for contentNode in updatedContentNodes {
                    if type(of: contentNode) == contentItem.type && contentNode.index == contentItem.attributes.index && contentNode.item?.message.stableId == contentItem.message.stableId {
                        sortedContentNodes.append(contentNode)
                        continue outer
                    }
                }
            }
            
            assert(sortedContentNodes.count == updatedContentNodes.count)
            
            if animation.isAnimated, let fromTextIndex = strongSelf.contentNodes.firstIndex(where: { $0 is ChatMessageTextBubbleContentNode }), let fromWebpageIndex = strongSelf.contentNodes.firstIndex(where: { $0 is ChatMessageWebpageBubbleContentNode }) {
                if let toTextIndex = sortedContentNodes.firstIndex(where: { $0 is ChatMessageTextBubbleContentNode }), let toWebpageIndex = sortedContentNodes.firstIndex(where: { $0 is ChatMessageWebpageBubbleContentNode }) {
                    if fromTextIndex == toWebpageIndex && fromWebpageIndex == toTextIndex {
                        animateTextAndWebpagePositionSwap = fromTextIndex < toTextIndex
                        
                        if let textNode = strongSelf.contentNodes[fromTextIndex] as? ChatMessageTextBubbleContentNode, let webpageNode = strongSelf.contentNodes[fromWebpageIndex] as? ChatMessageWebpageBubbleContentNode {
                            if fromTextIndex > toTextIndex {
                                if let statusNode = textNode.statusNode, let contentSuperview = textNode.view.superview, statusNode.view.isDescendant(of: contentSuperview) {
                                    bottomStatusNodeAnimationSourcePosition = statusNode.view.convert(CGPoint(x: statusNode.bounds.width, y: statusNode.bounds.height), to: contentSuperview)
                                }
                            } else {
                                if let statusNode = webpageNode.contentNode.statusNode, let contentSuperview = webpageNode.view.superview, statusNode.view.isDescendant(of: contentSuperview) {
                                    bottomStatusNodeAnimationSourcePosition = statusNode.view.convert(CGPoint(x: statusNode.bounds.width, y: statusNode.bounds.height), to: contentSuperview)
                                }
                            }
                        }
                    }
                }
            }
            
            strongSelf.contentNodes = sortedContentNodes
        }
        
        var shouldClipOnTransitions = true
        var contentNodeIndex = 0
        for (relativeFrame, properties, useContentOrigin, apply) in contentNodeFramesPropertiesAndApply {
            apply(animation, synchronousLoads, applyInfo)
            
            if contentNodeIndex >= strongSelf.contentNodes.count {
                break
            }
            
            let contentNode = strongSelf.contentNodes[contentNodeIndex]
            
            if contentNode.disablesClipping {
                shouldClipOnTransitions = false
            }
            
            var effectiveContentOriginX = contentOrigin.x
            var effectiveContentOriginY = useContentOrigin ? contentOrigin.y : 0.0
            if properties.isDetached {
                effectiveContentOriginX = floorToScreenPixels((layout.size.width - relativeFrame.width) / 2.0)
                effectiveContentOriginY = 0.0
            }
            
            let contentNodeFrame = relativeFrame.offsetBy(dx: effectiveContentOriginX, dy: effectiveContentOriginY)
            
            if case let .System(duration, _) = animation {
                var animateFrame = false
                var animateAlpha = false
                if let addedContentNodes = addedContentNodes {
                    if !addedContentNodes.contains(where: { $0.2 === contentNode }) {
                        animateFrame = true
                    } else {
                        animateAlpha = true
                    }
                } else {
                    animateFrame = true
                }
                
                if animateFrame {
                    var useExpensiveSnapshot = false
                    if case .messageOptions = item.associatedData.subject {
                        useExpensiveSnapshot = true
                    }
                    
                    if let animateTextAndWebpagePositionSwap, let contentNode = contentNode as? ChatMessageTextBubbleContentNode, let snapshotView = useExpensiveSnapshot ? contentNode.view.snapshotView(afterScreenUpdates: false) :  contentNode.layer.snapshotContentTreeAsView() {
                        let clippingView = UIView()
                        clippingView.clipsToBounds = true
                        clippingView.frame = contentNode.frame
                        
                        clippingView.addSubview(snapshotView)
                        snapshotView.frame = CGRect(origin: CGPoint(), size: contentNode.bounds.size)
                        
                        contentNode.view.superview?.insertSubview(clippingView, belowSubview: contentNode.view)
                        
                        animation.animator.updateAlpha(layer: clippingView.layer, alpha: 0.0, completion: { [weak clippingView] _ in
                            clippingView?.removeFromSuperview()
                        })
                        
                        let positionOffset: CGFloat = animateTextAndWebpagePositionSwap ? -1.0 : 1.0
                        
                        animation.animator.updatePosition(layer: snapshotView.layer, position: CGPoint(x: snapshotView.center.x, y: snapshotView.center.y + positionOffset * contentNode.frame.height), completion: nil)
                        
                        contentNode.frame = contentNodeFrame
                        
                        if let statusNode = contentNode.statusNode, let contentSuperview = contentNode.view.superview, statusNode.view.isDescendant(of: contentSuperview), let bottomStatusNodeAnimationSourcePosition {
                            let localSourcePosition = statusNode.view.convert(bottomStatusNodeAnimationSourcePosition, from: contentSuperview)
                            let offset = CGPoint(x: statusNode.bounds.width - localSourcePosition.x, y: statusNode.bounds.height - localSourcePosition.y)
                            animation.animator.animatePosition(layer: statusNode.layer, from: statusNode.layer.position.offsetBy(dx: -offset.x, dy: -offset.y), to: statusNode.layer.position, completion: nil)
                        }
                        
                        contentNode.animateClippingTransition(offset: positionOffset * contentNodeFrame.height, animation: animation)
                        
                        contentNode.alpha = 0.0
                        animation.animator.updateAlpha(layer: contentNode.layer, alpha: 1.0, completion: nil)
                    } else if animateTextAndWebpagePositionSwap != nil, let contentNode = contentNode as? ChatMessageWebpageBubbleContentNode {
                        if let statusNode = contentNode.contentNode.statusNode, let contentSuperview = contentNode.view.superview, statusNode.view.isDescendant(of: contentSuperview), let bottomStatusNodeAnimationSourcePosition {
                            let localSourcePosition = statusNode.view.convert(bottomStatusNodeAnimationSourcePosition, from: contentSuperview)
                            let offset = CGPoint(x: statusNode.bounds.width - localSourcePosition.x, y: statusNode.bounds.height - localSourcePosition.y)
                            animation.animator.animatePosition(layer: statusNode.layer, from: statusNode.layer.position.offsetBy(dx: -offset.x, dy: -offset.y), to: statusNode.layer.position, completion: nil)
                        }
                        
                        animation.animator.updateFrame(layer: contentNode.layer, frame: contentNodeFrame, completion: nil)
                    } else {
                        animation.animator.updateFrame(layer: contentNode.layer, frame: contentNodeFrame, completion: nil)
                    }
                } else if animateAlpha {
                    contentNode.frame = contentNodeFrame
                    contentNode.animateInsertionIntoBubble(duration)
                    var previousAlignedContentNodeFrame = contentNodeFrame
                    previousAlignedContentNodeFrame.origin.x += backgroundFrame.size.width - strongSelf.backgroundNode.frame.size.width
                    contentNode.layer.animateFrame(from: previousAlignedContentNodeFrame, to: contentNodeFrame, duration: duration, timingFunction: timingFunction)
                } else {
                    contentNode.frame = contentNodeFrame
                }
            } else {
                contentNode.frame = contentNodeFrame
            }
            
            contentNode.visibility = mapVisibility(strongSelf.visibility, boundsSize: layout.contentSize, insets: strongSelf.insets, to: contentNode)
            
            contentNodeIndex += 1
        }
        
        if let mosaicStatusOrigin = mosaicStatusOrigin, let (size, apply) = mosaicStatusSizeAndApply {
            var statusNodeAnimation = animation
            if strongSelf.mosaicStatusNode == nil {
                statusNodeAnimation = .None
            }
            let mosaicStatusNode = apply(statusNodeAnimation)
            if mosaicStatusNode !== strongSelf.mosaicStatusNode {
                strongSelf.mosaicStatusNode?.removeFromSupernode()
                strongSelf.mosaicStatusNode = mosaicStatusNode
                strongSelf.clippingNode.addSubnode(mosaicStatusNode)
            }
            let absoluteOrigin = mosaicStatusOrigin.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)
            statusNodeAnimation.animator.updateFrame(layer: mosaicStatusNode.layer, frame: CGRect(origin: CGPoint(x: absoluteOrigin.x - layoutConstants.image.statusInsets.right - size.width, y: absoluteOrigin.y - layoutConstants.image.statusInsets.bottom - size.height), size: size), completion: nil)
            
            if item.message.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects) != nil {
                mosaicStatusNode.pressed = { [weak strongSelf] in
                    guard let strongSelf, let item = strongSelf.item else {
                        return
                    }
                    item.controllerInteraction.playMessageEffect(item.message)
                }
            } else {
                mosaicStatusNode.pressed = nil
            }
        } else if let mosaicStatusNode = strongSelf.mosaicStatusNode {
            strongSelf.mosaicStatusNode = nil
            mosaicStatusNode.removeFromSupernode()
        }
        
        if let unlockButtonPosition {
            let (size, apply) = unlockButtonSizeAndApply
            var unlockButtonNodeAnimation = animation
            if strongSelf.unlockButtonNode == nil {
                unlockButtonNodeAnimation = .None
            }
            let unlockButtonNode = apply(strongSelf.unlockButtonNode != nil)
            if unlockButtonNode !== strongSelf.unlockButtonNode {
                strongSelf.unlockButtonNode?.removeFromSupernode()
                strongSelf.unlockButtonNode = unlockButtonNode
                if let unlockButtonNode {
                    strongSelf.clippingNode.addSubnode(unlockButtonNode)
                }
            }
            let absoluteOrigin = unlockButtonPosition.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)
            if let unlockButtonNode {
                unlockButtonNodeAnimation.animator.updateFrame(layer: unlockButtonNode.layer, frame: CGRect(origin: CGPoint(x: floor(absoluteOrigin.x - size.width / 2.0), y: floor(absoluteOrigin.y - size.height / 2.0)), size: size), completion: nil)
            }
        } else if let unlockButtonNode = strongSelf.unlockButtonNode {
            strongSelf.unlockButtonNode = nil
            unlockButtonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                unlockButtonNode.removeFromSupernode()
            })
        }
        
        if let mediaInfoOrigin {
            let (size, apply) = mediaInfoSizeAndApply
            var unlockButtonNodeAnimation = animation
            if strongSelf.unlockButtonNode == nil {
                unlockButtonNodeAnimation = .None
            }
            let mediaInfoNode = apply(strongSelf.mediaInfoNode != nil)
            if mediaInfoNode !== strongSelf.mediaInfoNode {
                strongSelf.mediaInfoNode?.removeFromSupernode()
                strongSelf.mediaInfoNode = mediaInfoNode
                if let mediaInfoNode {
                    strongSelf.clippingNode.addSubnode(mediaInfoNode)
                }
            }
            let absoluteOrigin = mediaInfoOrigin.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)
            if let mediaInfoNode {
                unlockButtonNodeAnimation.animator.updateFrame(layer: mediaInfoNode.layer, frame: CGRect(origin: CGPoint(x: absoluteOrigin.x - size.width - 8.0, y: absoluteOrigin.y + 8.0), size: size), completion: nil)
            }
        } else if let mediaInfoNode = strongSelf.mediaInfoNode {
            strongSelf.mediaInfoNode = nil
            mediaInfoNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                mediaInfoNode.removeFromSupernode()
            })
        }

        if needsShareButton {
            if strongSelf.shareButtonNode == nil {
                let shareButtonNode = ChatMessageShareButton()
                strongSelf.shareButtonNode = shareButtonNode
                strongSelf.insertSubnode(shareButtonNode, belowSubnode: strongSelf.messageAccessibilityArea)
                shareButtonNode.pressed = { [weak strongSelf] in
                    strongSelf?.shareButtonPressed()
                }
                shareButtonNode.morePressed = { [weak strongSelf] in
                    strongSelf?.openMessageContextMenu()
                }
                shareButtonNode.longPressAction = { [weak strongSelf] node, gesture in
                    strongSelf?.openQuickShare(node: node, gesture: gesture)
                }
            }
        } else if let shareButtonNode = strongSelf.shareButtonNode {
            strongSelf.shareButtonNode = nil
            shareButtonNode.removeFromSupernode()
        }
        
        let offset: CGFloat = params.leftInset + (incoming ? 42.0 : 0.0)
        let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: params.width, height: layout.contentSize.height))
        strongSelf.selectionNode?.frame = selectionFrame
        strongSelf.selectionNode?.updateLayout(size: selectionFrame.size, leftInset: params.leftInset)
        
        var reactionButtonsOffset: CGFloat = 0.0
        
        if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
            let actionButtonsNode = actionButtonsSizeAndApply.1(animation)
            let actionButtonsFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.maxY), size: actionButtonsSizeAndApply.0)
            if actionButtonsNode !== strongSelf.actionButtonsNode {
                strongSelf.actionButtonsNode = actionButtonsNode
                actionButtonsNode.buttonPressed = { [weak strongSelf] button in
                    if let strongSelf = strongSelf {
                        strongSelf.performMessageButtonAction(button: button)
                    }
                }
                actionButtonsNode.buttonLongTapped = { [weak strongSelf] button in
                    if let strongSelf = strongSelf {
                        strongSelf.presentMessageButtonContextMenu(button: button)
                    }
                }
                strongSelf.insertSubnode(actionButtonsNode, belowSubnode: strongSelf.messageAccessibilityArea)
                actionButtonsNode.frame = actionButtonsFrame
                
                if animation.isAnimated {
                    actionButtonsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            } else {
                animation.animator.updateFrame(layer: actionButtonsNode.layer, frame: actionButtonsFrame, completion: nil)
            }
            
            reactionButtonsOffset += actionButtonsSizeAndApply.0.height
        } else if let actionButtonsNode = strongSelf.actionButtonsNode {
            strongSelf.actionButtonsNode = nil
            if animation.isAnimated {
                actionButtonsNode.layer.animateAlpha(from: actionButtonsNode.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    actionButtonsNode.removeFromSupernode()
                })
            } else {
                actionButtonsNode.removeFromSupernode()
            }
        }
        
        if let reactionButtonsSizeAndApply = reactionButtonsSizeAndApply {
            let reactionButtonsNode = reactionButtonsSizeAndApply.1(animation)
            
            var reactionButtonsOriginX: CGFloat
            if case .center = alignment {
                reactionButtonsOriginX = backgroundFrame.minX + 3.0
            } else {
                reactionButtonsOriginX = backgroundFrame.minX + (incoming ? (layoutConstants.bubble.contentInsets.left + 2.0) : (layoutConstants.bubble.contentInsets.right - 2.0))
            }
            var reactionButtonsFrame = CGRect(origin: CGPoint(x: reactionButtonsOriginX, y: backgroundFrame.maxY + reactionButtonsOffset + 4.0), size: reactionButtonsSizeAndApply.0)
            if !disablesComments && !incoming {
                reactionButtonsFrame.origin.x = backgroundFrame.maxX - reactionButtonsSizeAndApply.0.width - layoutConstants.bubble.contentInsets.left
            }
            
            if reactionButtonsNode !== strongSelf.reactionButtonsNode {
                strongSelf.reactionButtonsNode = reactionButtonsNode
                reactionButtonsNode.reactionSelected = { [weak strongSelf] value, sourceView in
                    guard let strongSelf = strongSelf, let item = strongSelf.item else {
                        return
                    }
                    item.controllerInteraction.updateMessageReaction(item.message, .reaction(value), false, sourceView)
                }
                reactionButtonsNode.openReactionPreview = { [weak strongSelf] gesture, sourceNode, value in
                    guard let strongSelf = strongSelf, let item = strongSelf.item else {
                        gesture?.cancel()
                        return
                    }
                    
                    item.controllerInteraction.openMessageReactionContextMenu(item.message, sourceNode, gesture, value)
                }
                reactionButtonsNode.frame = reactionButtonsFrame
                strongSelf.addSubnode(reactionButtonsNode)
                if animation.isAnimated {
                    reactionButtonsNode.animateIn(animation: animation)
                }
                
                if let (rect, containerSize) = strongSelf.absoluteRect {
                    var rect = rect
                    rect.origin.y = containerSize.height - rect.maxY + strongSelf.insets.top
                    
                    var reactionButtonsNodeFrame = reactionButtonsFrame
                    reactionButtonsNodeFrame.origin.x += rect.minX
                    reactionButtonsNodeFrame.origin.y += rect.minY
                    
                    reactionButtonsNode.update(rect: rect, within: containerSize, transition: .immediate)
                }
            } else {
                animation.animator.updateFrame(layer: reactionButtonsNode.layer, frame: reactionButtonsFrame, completion: nil)
                
                if let (rect, containerSize) = strongSelf.absoluteRect {
                    var rect = rect
                    rect.origin.y = containerSize.height - rect.maxY + strongSelf.insets.top
                    
                    var reactionButtonsNodeFrame = reactionButtonsFrame
                    reactionButtonsNodeFrame.origin.x += rect.minX
                    reactionButtonsNodeFrame.origin.y += rect.minY
                    
                    reactionButtonsNode.update(rect: rect, within: containerSize, transition: animation.transition)
                }
            }
        } else if let reactionButtonsNode = strongSelf.reactionButtonsNode {
            strongSelf.reactionButtonsNode = nil
            if animation.isAnimated {
                reactionButtonsNode.animateOut(animation: animation, completion: { [weak reactionButtonsNode] in
                    reactionButtonsNode?.removeFromSupernode()
                })
            } else {
                reactionButtonsNode.removeFromSupernode()
            }
        }
        
        var isCurrentlyPlayingMedia = false
        if item.associatedData.currentlyPlayingMessageId == item.message.index, let file = item.message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile, file.isInstantVideo {
            isCurrentlyPlayingMedia = true
        }
        
        if case .System = animation/*, !strongSelf.mainContextSourceNode.isExtractedToContextPreview*/ {
            if !strongSelf.backgroundNode.frame.equalTo(backgroundFrame) {
                animation.animator.updateFrame(layer: strongSelf.backgroundNode.layer, frame: backgroundFrame, completion: nil)
                if let backgroundHighlightNode = strongSelf.backgroundHighlightNode {
                    animation.animator.updateFrame(layer: backgroundHighlightNode.layer, frame: backgroundFrame, completion: nil)
                    backgroundHighlightNode.updateLayout(size: backgroundFrame.size, transition: animation)
                }
                animation.animator.updatePosition(layer: strongSelf.clippingNode.layer, position: backgroundFrame.center, completion: nil)
                strongSelf.clippingNode.clipsToBounds = shouldClipOnTransitions
                animation.animator.updateBounds(layer: strongSelf.clippingNode.layer, bounds: CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY), size: backgroundFrame.size), completion: { [weak strongSelf] _ in
                    strongSelf?.clippingNode.clipsToBounds = false
                })

                strongSelf.backgroundNode.updateLayout(size: backgroundFrame.size, transition: animation)
                animation.animator.updateFrame(layer: strongSelf.backgroundWallpaperNode.layer, frame: backgroundFrame, completion: nil)
                strongSelf.shadowNode.updateLayout(backgroundFrame: backgroundFrame, animator: animation.animator)
                strongSelf.backgroundWallpaperNode.updateFrame(backgroundFrame, animator: animation.animator)
                
                if let _ = strongSelf.backgroundNode.type {
                    if !strongSelf.mainContextSourceNode.isExtractedToContextPreview {
                        if let (rect, size) = strongSelf.absoluteRect {
                            strongSelf.updateAbsoluteRect(rect, within: size)
                        }
                    }
                }
                strongSelf.messageAccessibilityArea.frame = backgroundFrame
            }
            if let shareButtonNode = strongSelf.shareButtonNode {
                let buttonSize = shareButtonNode.update(presentationData: item.presentationData, controllerInteraction: item.controllerInteraction, chatLocation: item.chatLocation, subject: item.associatedData.subject, message: item.message, account: item.context.account, disableComments: disablesComments)
                
                var buttonFrame = CGRect(origin: CGPoint(x: !incoming ? backgroundFrame.minX - buttonSize.width - 8.0 : backgroundFrame.maxX + 8.0, y: backgroundFrame.maxY - buttonSize.width - 1.0), size: buttonSize)
                
                if item.message.adAttribute != nil {
                    buttonFrame.origin.y = backgroundFrame.minY + 1.0
                }
                
                if let shareButtonOffset = shareButtonOffset {
                    if incoming {
                        buttonFrame.origin.x = shareButtonOffset.x
                    }
                    buttonFrame.origin.y = buttonFrame.origin.y + shareButtonOffset.y - (buttonSize.height - 30.0)
                } else if !disablesComments {
                    buttonFrame.origin.y = buttonFrame.origin.y - (buttonSize.height - 30.0)
                }
                
                if isSidePanelOpen {
                    buttonFrame.origin.x -= buttonFrame.width * 0.5
                    buttonFrame.origin.y += buttonFrame.height * 0.5
                }
                
                animation.animator.updatePosition(layer: shareButtonNode.layer, position: buttonFrame.center, completion: nil)
                animation.animator.updateBounds(layer: shareButtonNode.layer, bounds: CGRect(origin: CGPoint(), size: buttonFrame.size), completion: nil)
                animation.animator.updateAlpha(layer: shareButtonNode.layer, alpha: (isCurrentlyPlayingMedia || isSidePanelOpen) ? 0.0 : 1.0, completion: nil)
                animation.animator.updateScale(layer: shareButtonNode.layer, scale: (isCurrentlyPlayingMedia || isSidePanelOpen) ? 0.001 : 1.0, completion: nil)
            }
        } else {
            /*if let _ = strongSelf.backgroundFrameTransition {
                strongSelf.animateFrameTransition(1.0, backgroundFrame.size.height)
                strongSelf.backgroundFrameTransition = nil
            }*/
            strongSelf.messageAccessibilityArea.frame = backgroundFrame
            if let shareButtonNode = strongSelf.shareButtonNode {
                let buttonSize = shareButtonNode.update(presentationData: item.presentationData, controllerInteraction: item.controllerInteraction, chatLocation: item.chatLocation, subject: item.associatedData.subject, message: item.message, account: item.context.account, disableComments: disablesComments)
                
                var buttonFrame = CGRect(origin: CGPoint(x: !incoming ? backgroundFrame.minX - buttonSize.width - 8.0 : backgroundFrame.maxX + 8.0, y: backgroundFrame.maxY - buttonSize.width - 1.0), size: buttonSize)
                
                if item.message.adAttribute != nil {
                    buttonFrame.origin.y = backgroundFrame.minY + 1.0
                }
                
                if let shareButtonOffset = shareButtonOffset {
                    if incoming {
                        buttonFrame.origin.x = shareButtonOffset.x
                    }
                    buttonFrame.origin.y = buttonFrame.origin.y + shareButtonOffset.y - (buttonSize.height - 30.0)
                } else if !disablesComments {
                    buttonFrame.origin.y = buttonFrame.origin.y - (buttonSize.height - 30.0)
                }
                
                if isSidePanelOpen {
                    buttonFrame.origin.x -= buttonFrame.width * 0.5
                    buttonFrame.origin.y += buttonFrame.height * 0.5
                }
                
                animation.animator.updatePosition(layer: shareButtonNode.layer, position: buttonFrame.center, completion: nil)
                animation.animator.updateBounds(layer: shareButtonNode.layer, bounds: CGRect(origin: CGPoint(), size: buttonFrame.size), completion: nil)
                animation.animator.updateAlpha(layer: shareButtonNode.layer, alpha: (isCurrentlyPlayingMedia || isSidePanelOpen) ? 0.0 : 1.0, completion: nil)
                animation.animator.updateScale(layer: shareButtonNode.layer, scale: (isCurrentlyPlayingMedia || isSidePanelOpen) ? 0.001 : 1.0, completion: nil)
            }
            
            if case .System = animation, strongSelf.mainContextSourceNode.isExtractedToContextPreview {
                legacyTransition.updateFrame(node: strongSelf.backgroundNode, frame: backgroundFrame)
                if let backgroundHighlightNode = strongSelf.backgroundHighlightNode {
                    legacyTransition.updateFrame(node: backgroundHighlightNode, frame: backgroundFrame, completion: nil)
                    backgroundHighlightNode.updateLayout(size: backgroundFrame.size, transition: legacyTransition)
                }

                legacyTransition.updateFrame(node: strongSelf.clippingNode, frame: backgroundFrame)
                legacyTransition.updateBounds(node: strongSelf.clippingNode, bounds: CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY), size: backgroundFrame.size))

                strongSelf.backgroundNode.updateLayout(size: backgroundFrame.size, transition: legacyTransition)
                strongSelf.backgroundWallpaperNode.updateFrame(backgroundFrame, transition: legacyTransition)
                strongSelf.shadowNode.updateLayout(backgroundFrame: backgroundFrame, transition: legacyTransition)
            } else {
                strongSelf.backgroundNode.frame = backgroundFrame
                if let backgroundHighlightNode = strongSelf.backgroundHighlightNode {
                    backgroundHighlightNode.frame = backgroundFrame
                    backgroundHighlightNode.updateLayout(size: backgroundFrame.size, transition: .immediate)
                }
                
                strongSelf.clippingNode.frame = backgroundFrame
                strongSelf.clippingNode.bounds = CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY), size: backgroundFrame.size)
                strongSelf.backgroundNode.updateLayout(size: backgroundFrame.size, transition: .immediate)
                strongSelf.backgroundWallpaperNode.frame = backgroundFrame
                strongSelf.shadowNode.updateLayout(backgroundFrame: backgroundFrame, transition: .immediate)
            }
            if let (rect, size) = strongSelf.absoluteRect {
                strongSelf.updateAbsoluteRect(rect, within: size)
            }
        }
        
        let previousContextContentFrame = strongSelf.mainContextSourceNode.contentRect
        strongSelf.mainContextSourceNode.contentRect = backgroundFrame.offsetBy(dx: incomingOffset, dy: 0.0)
        strongSelf.mainContainerNode.targetNodeForActivationProgressContentRect = strongSelf.mainContextSourceNode.contentRect
        
        if previousContextFrame.size != strongSelf.mainContextSourceNode.bounds.size || previousContextContentFrame != strongSelf.mainContextSourceNode.contentRect {
            strongSelf.mainContextSourceNode.layoutUpdated?(strongSelf.mainContextSourceNode.bounds.size, animation)
        }
        
        var hasMenuGesture = true
        if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject {
            if case .link = info {
            } else {
                strongSelf.tapRecognizer?.isEnabled = false
            }
            strongSelf.replyRecognizer?.isEnabled = false
            hasMenuGesture = false
        }
        for media in item.message.media {
            if let action = media as? TelegramMediaAction {
                if case .joinedChannel = action.action {
                    hasMenuGesture = false
                    break
                }
            }
        }
        if item.message.timestamp < 10 {
            hasMenuGesture = false
        }
        strongSelf.mainContainerNode.isGestureEnabled = hasMenuGesture
        for contentContainer in strongSelf.contentContainers {
            contentContainer.containerNode.isGestureEnabled = hasMenuGesture
        }
        
        strongSelf.updateSearchTextHighlightState()
        
        strongSelf.updateVisibility()
        
        if let (_, f) = strongSelf.awaitingAppliedReaction {
            strongSelf.awaitingAppliedReaction = nil
            
            f()
        }
    }
    
    override public func updateAccessibilityData(_ accessibilityData: ChatMessageAccessibilityData) {
        super.updateAccessibilityData(accessibilityData)
        
        self.messageAccessibilityArea.accessibilityLabel = accessibilityData.label
        self.messageAccessibilityArea.accessibilityValue = accessibilityData.value
        self.messageAccessibilityArea.accessibilityHint = accessibilityData.hint
        self.messageAccessibilityArea.accessibilityTraits = accessibilityData.traits
        if let customActions = accessibilityData.customActions {
            self.messageAccessibilityArea.accessibilityCustomActions = customActions.map({ action -> UIAccessibilityCustomAction in
                return ChatMessageAccessibilityCustomAction(name: action.name, target: self, selector: #selector(self.performLocalAccessibilityCustomAction(_:)), action: action.action)
            })
        } else {
            self.messageAccessibilityArea.accessibilityCustomActions = nil
        }
    }
    
    @objc private func performLocalAccessibilityCustomAction(_ action: UIAccessibilityCustomAction) {
        if let action = action as? ChatMessageAccessibilityCustomAction {
            switch action.action {
                case .reply:
                    if let item = self.item {
                        item.controllerInteraction.setupReply(item.message.id)
                    }
                case .options:
                    if let item = self.item {
                        var subFrame = self.backgroundNode.frame
                        if case .group = item.content {
                            for contentNode in self.contentNodes {
                                if contentNode.item?.message.stableId == item.message.stableId {
                                    subFrame = contentNode.frame.insetBy(dx: 0.0, dy: -4.0)
                                    break
                                }
                            }
                        }
                        item.controllerInteraction.openMessageContextMenu(item.message, false, self, subFrame, nil, nil)
                    }
            }
        }
    }
    
    override public func shouldAnimateHorizontalFrameTransition() -> Bool {
        return false
    }
    
    override public func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation, let item = self.item {
                if let action = self.gestureRecognized(gesture: gesture, location: location, recognizer: nil) {
                    if case .doubleTap = gesture {
                        self.mainContainerNode.cancelGesture()
                    }
                    switch action {
                    case let .action(f):
                        f.action()
                    case let .optionalAction(f):
                        f()
                    case let .openContextMenu(openContextMenu):
                        if canAddMessageReactions(message: openContextMenu.tapMessage) {
                            item.controllerInteraction.updateMessageReaction(openContextMenu.tapMessage, .default, false, nil)
                        } else {
                            item.controllerInteraction.openMessageContextMenu(openContextMenu.tapMessage, openContextMenu.selectAll, self, openContextMenu.subFrame, nil, nil)
                        }
                    }
                } else if case .tap = gesture {
                    item.controllerInteraction.clickThroughMessage(self.view, location)
                } else if case .doubleTap = gesture {
                    if canAddMessageReactions(message: item.message) {
                        item.controllerInteraction.updateMessageReaction(item.message, .default, false, nil)
                    }
                }
            }
        default:
            break
        }
    }
    
    private func gestureRecognized(gesture: TapLongTapOrDoubleTapGesture, location: CGPoint, recognizer: TapLongTapOrDoubleTapGestureRecognizer?) -> InternalBubbleTapAction? {
        var mediaMessage: Message?
        var forceOpen = false
        if let item = self.item {
            if case .group = item.content {
                var message: Message? = item.content.firstMessage
                loop: for contentNode in self.contentNodes {
                    if !(contentNode is ChatMessageTextBubbleContentNode) {
                        continue loop
                    }
                    let convertedNodeFrame = contentNode.view.convert(contentNode.bounds, to: self.view).insetBy(dx: 0.0, dy: -10.0)
                    if !convertedNodeFrame.contains(location) {
                        continue loop
                    }
                    if contentNode is ChatMessageEventLogPreviousMessageContentNode {
                    } else {
                        message = contentNode.item?.message
                    }
                }
                if let message {
                    for media in message.media {
                        if let file = media as? TelegramMediaFile, file.duration != nil {
                            mediaMessage = message
                        }
                    }
                }
            } else {
                for media in item.message.media {
                    if let file = media as? TelegramMediaFile, file.duration != nil {
                        mediaMessage = item.message
                    }
                }
            }
            if mediaMessage == nil {
                for attribute in item.message.attributes {
                    if let attribute = attribute as? ReplyMessageAttribute {
                        if let replyMessage = item.message.associatedMessages[attribute.messageId] {
                            for media in replyMessage.media {
                                if let file = media as? TelegramMediaFile, file.duration != nil {
                                    mediaMessage = replyMessage
                                    forceOpen = true
                                    break
                                }
                                if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, webEmbedType(content: content).supportsSeeking {
                                    mediaMessage = replyMessage
                                    forceOpen = true
                                    break
                                }
                            }
                        }
                    }
                }
            }
            if mediaMessage == nil {
                mediaMessage = item.message
            }
        }
        
        switch gesture {
            case .tap:
                if let nameNode = self.nameNode, nameNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? InlineBotMessageAttribute {
                                var botAddressName: String?
                                if let peerId = attribute.peerId, let botPeer = item.message.peers[peerId], let addressName = botPeer.addressName {
                                    botAddressName = addressName
                                } else {
                                    botAddressName = attribute.title
                                }
                                
                                if let peerId = attribute.peerId {
                                    if let botPeer = item.message.peers[peerId] as? TelegramUser, let inlinePlaceholder = botPeer.botInfo?.inlinePlaceholder, !inlinePlaceholder.isEmpty {
                                        return .optionalAction({
                                            if let botAddressName = botAddressName {
                                                item.controllerInteraction.updateInputState { textInputState in
                                                    return ChatTextInputState(inputText: NSAttributedString(string: "@" + botAddressName + " "))
                                                }
                                                item.controllerInteraction.updateInputMode { _ in
                                                    return .text
                                                }
                                            }
                                        })
                                    } else {
                                        return .optionalAction({
                                            if let peer = item.message.peers[peerId] {
                                                item.controllerInteraction.openPeer(EnginePeer(peer), .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
                                            }
                                        })
                                    }
                                }
                            }
                        }
                    }
                } else if let replyInfoNode = self.replyInfoNode, self.item?.controllerInteraction.tapMessage == nil, replyInfoNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute {
                                if let threadId = item.message.threadId, Int32(clamping: threadId) == attribute.messageId.id, let quotedReply = item.message.attributes.first(where: { $0 is QuotedReplyMessageAttribute }) as? QuotedReplyMessageAttribute {
                                    let _ = quotedReply
                                    
                                    return .action(InternalBubbleTapAction.Action({ [weak self, weak replyInfoNode] in
                                        guard let self, let item = self.item, let replyInfoNode else {
                                            return
                                        }
                                        if attribute.isQuote, !replyInfoNode.isQuoteExpanded {
                                            replyInfoNode.isQuoteExpanded = true
                                            item.controllerInteraction.requestMessageUpdate(item.message.id, false)
                                            return
                                        }
                                        var progress: Promise<Bool>?
                                        if let replyInfoNode = self.replyInfoNode {
                                            progress = replyInfoNode.makeProgress()
                                        }
                                        item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: attribute.isQuote ? attribute.quote.flatMap { quote in NavigateToMessageParams.Quote(string: quote.text, offset: quote.offset) } : nil, progress: progress))
                                    }, contextMenuOnLongPress: true))
                                }
                                
                                return .action(InternalBubbleTapAction.Action({ [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    var progress: Promise<Bool>?
                                    if let replyInfoNode = self.replyInfoNode {
                                        progress = replyInfoNode.makeProgress()
                                    }
                                    item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: attribute.isQuote ? attribute.quote.flatMap { quote in NavigateToMessageParams.Quote(string: quote.text, offset: quote.offset) } : nil, progress: progress))
                                }, contextMenuOnLongPress: true))
                            } else if let attribute = attribute as? ReplyStoryAttribute {
                                return .action(InternalBubbleTapAction.Action({
                                    item.controllerInteraction.navigateToStory(item.message, attribute.storyId)
                                }, contextMenuOnLongPress: true))
                            } else if let attribute = attribute as? QuotedReplyMessageAttribute {
                                return .action(InternalBubbleTapAction.Action({ [weak self, weak replyInfoNode] in
                                    guard let self, let item = self.item, let replyInfoNode else {
                                        return
                                    }
                                    if attribute.isQuote, !replyInfoNode.isQuoteExpanded {
                                        replyInfoNode.isQuoteExpanded = true
                                        item.controllerInteraction.requestMessageUpdate(item.message.id, false)
                                        return
                                    }
                                    
                                    item.controllerInteraction.attemptedNavigationToPrivateQuote(attribute.peerId.flatMap { item.message.peers[$0] })
                                }, contextMenuOnLongPress: true))
                            }
                        }
                    }
                } else if let threadInfoNode = self.threadInfoNode, self.item?.controllerInteraction.tapMessage == nil, threadInfoNode.frame.contains(location) {
                    if let item = self.item {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? ReplyMessageAttribute, let threadId = attribute.threadMessageId {
                                return .optionalAction({
                                    item.controllerInteraction.navigateToThreadMessage(item.message.id.peerId, Int64(clamping: threadId.id), item.message.id)
                                })
                            }
                        }
                    }
                }
                if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                    if let item = self.item, let forwardInfo = item.message.forwardInfo {
                        let performAction: () -> Void = { [weak forwardInfoNode] in
                            if let sourceMessageId = forwardInfo.sourceMessageId {
                                if let channel = forwardInfo.author as? TelegramChannel, channel.addressName == nil {
                                    if case let .broadcast(info) = channel.info, info.flags.contains(.hasDiscussionGroup) {
                                    } else if case .member = channel.participationStatus {
                                    } else if !item.message.id.peerId.isReplies {
                                        if let forwardInfoNode {
                                            item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_PrivateChannelTooltip, false, forwardInfoNode, nil)
                                        }
                                        return
                                    }
                                }
                                if let forwardInfoNode {
                                    item.controllerInteraction.navigateToMessage(item.message.id, sourceMessageId, NavigateToMessageParams(timestamp: nil, quote: nil, progress: forwardInfoNode.makeActivate()?()))
                                }
                            } else if let peer = forwardInfo.source ?? forwardInfo.author {
                                item.controllerInteraction.openPeer(EnginePeer(peer), peer is TelegramUser ? .info(nil) : .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
                            } else if let _ = forwardInfo.authorSignature {
                                if let forwardInfoNode {
                                    var subRect: CGRect?
                                    if let textNode = forwardInfoNode.nameNode {
                                        subRect = textNode.frame
                                    }
                                    item.controllerInteraction.displayMessageTooltip(item.message.id, item.presentationData.strings.Conversation_ForwardAuthorHiddenTooltip, false, forwardInfoNode, subRect)
                                }
                            }
                        }
                        
                        if forwardInfoNode.hasAction(at: self.view.convert(location, to: forwardInfoNode.view)) {
                            return .action(InternalBubbleTapAction.Action {})
                        } else {
                            return .optionalAction(performAction)
                        }
                    } else if let item = self.item, let story = item.message.media.first(where: { $0 is TelegramMediaStory }) as? TelegramMediaStory {
                        if let storyItem = item.message.associatedStories[story.storyId] {
                            if storyItem.data.isEmpty {
                                return .action(InternalBubbleTapAction.Action {
                                    item.controllerInteraction.navigateToStory(item.message, story.storyId)
                                })
                            } else {
                                if let peer = item.message.peers[story.storyId.peerId] {
                                    return .action(InternalBubbleTapAction.Action {
                                        item.controllerInteraction.openPeer(EnginePeer(peer), peer is TelegramUser ? .info(nil) : .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
                                    })
                                }
                            }
                        }
                    }
                }
                loop: for contentNode in self.contentNodes {
                    let convertedLocation = self.view.convert(location, to: contentNode.view)

                    let tapAction = contentNode.tapActionAtPoint(convertedLocation, gesture: gesture, isEstimating: false)
                    var rects: [CGRect] = []
                    if let actionRects = tapAction.rects {
                        for rect in actionRects {
                            rects.append(rect.offsetBy(dx: contentNode.frame.minX, dy: contentNode.frame.minY))
                        }
                    }
                    
                    switch tapAction.content {
                    case .none:
                        if let item = self.item, self.backgroundNode.frame.contains(CGPoint(x: self.frame.width - location.x, y: location.y)), let tapMessage = self.item?.controllerInteraction.tapMessage {
                            return .action(InternalBubbleTapAction.Action {
                                tapMessage(item.message)
                            })
                        }
                    case .ignore:
                        if let item = self.item, self.backgroundNode.frame.contains(CGPoint(x: self.frame.width - location.x, y: location.y)), let tapMessage = self.item?.controllerInteraction.tapMessage {
                            return .action(InternalBubbleTapAction.Action {
                                tapMessage(item.message)
                            })
                        } else {
                            return .action(InternalBubbleTapAction.Action {
                            })
                        }
                    case let .custom(action):
                        return .action(InternalBubbleTapAction.Action({
                            action()
                        }, contextMenuOnLongPress: !tapAction.hasLongTapAction))
                    case let .url(url):
                        if case .longTap = gesture, !tapAction.hasLongTapAction, let item = self.item {
                            let tapMessage = item.content.firstMessage
                            var subFrame = self.backgroundNode.frame
                            if case .group = item.content {
                                for contentNode in self.contentNodes {
                                    if contentNode.item?.message.stableId == tapMessage.stableId {
                                        subFrame = contentNode.frame.insetBy(dx: 0.0, dy: -4.0)
                                        break
                                    }
                                }
                            }
                            return .openContextMenu(InternalBubbleTapAction.OpenContextMenu(tapMessage: tapMessage, selectAll: false, subFrame: subFrame, disableDefaultPressAnimation: true))
                        } else {
                            return .action(InternalBubbleTapAction.Action({ [weak self] in
                                guard let self, let item = self.item else {
                                    return
                                }
                                item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url.url, concealed: url.concealed, message: item.content.firstMessage, allowInlineWebpageResolution: url.allowInlineWebpageResolution, progress: tapAction.activate?()))
                            }, contextMenuOnLongPress: !tapAction.hasLongTapAction))
                        }
                    case let .phone(number):
                        return .action(InternalBubbleTapAction.Action({ [weak self] in
                            guard let self, let item = self.item, let contentNode = self.contextContentNodeForLink(number, rects: rects) else {
                                return
                            }
                                                        
                            item.controllerInteraction.longTap(.phone(number), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                        }, contextMenuOnLongPress: !tapAction.hasLongTapAction))
                    case let .peerMention(peerId, _, openProfile):
                        return .action(InternalBubbleTapAction.Action { [weak self] in
                            if let item = self?.item {
                                let _ = (item.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                |> deliverOnMainQueue).startStandalone(next: { peer in
                                    if let self = self, let item = self.item, let peer = peer {
                                        item.controllerInteraction.openPeer(peer, openProfile ? .info(nil) : .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
                                    }
                                })
                            }
                        })
                    case let .textMention(name):
                        return .action(InternalBubbleTapAction.Action {
                            self.item?.controllerInteraction.openPeerMention(name, tapAction.activate?())
                        })
                    case let .botCommand(command):
                        if let item = self.item {
                            return .action(InternalBubbleTapAction.Action {
                                item.controllerInteraction.sendBotCommand(item.message.id, command)
                            })
                        }
                    case let .hashtag(peerName, hashtag):
                        return .action(InternalBubbleTapAction.Action {
                            self.item?.controllerInteraction.openHashtag(peerName, hashtag)
                        })
                    case .instantPage:
                        if let item = self.item {
                            return .optionalAction({
                                item.controllerInteraction.openInstantPage(item.message, item.associatedData)
                            })
                        }
                    case .wallpaper:
                        if let item = self.item {
                            return .action(InternalBubbleTapAction.Action {
                                item.controllerInteraction.openWallpaper(item.message)
                            })
                        }
                    case .theme:
                        if let item = self.item {
                            return .action(InternalBubbleTapAction.Action {
                                item.controllerInteraction.openTheme(item.message)
                            })
                        }
                    case let .call(peerId, isVideo):
                        return .optionalAction({
                            self.item?.controllerInteraction.callPeer(peerId, isVideo)
                        })
                    case let .conferenceCall(message):
                        return .optionalAction({
                            self.item?.controllerInteraction.openConferenceCall(message)
                        })
                    case .openMessage:
                        if let item = self.item {
                            if let type = self.backgroundNode.type, case .none = type {
                                return .optionalAction({
                                    let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
                                })
                            } else {
                                return .action(InternalBubbleTapAction.Action {
                                    let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
                                })
                            }
                        }
                    case let .timecode(timecode, _):
                        if let item = self.item, let mediaMessage = mediaMessage {
                            return .action(InternalBubbleTapAction.Action {
                                item.controllerInteraction.seekToTimecode(mediaMessage, timecode, forceOpen)
                            })
                        }
                    case let .bankCard(number):
                        if let item = self.item {
                            return .action(InternalBubbleTapAction.Action { [weak self] in
                                guard let self, let contentNode = self.contextContentNodeForLink(number, rects: rects) else {
                                    return
                                }
                                item.controllerInteraction.longTap(.bankCard(number), ChatControllerInteraction.LongTapParams(message: item.message, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                            })
                        }
                    case let .tooltip(text, node, rect):
                        if let item = self.item {
                            return .optionalAction({
                                let _ = item.controllerInteraction.displayMessageTooltip(item.message.id, text, false, node, rect)
                            })
                        }
                    case let .openPollResults(option):
                        if let item = self.item {
                            return .optionalAction({
                                item.controllerInteraction.openMessagePollResults(item.message.id, option)
                            })
                        }
                    case let .copy(text):
                        if let item = self.item {
                            return .optionalAction({
                                item.controllerInteraction.copyText(text)
                            })
                        }
                    case let .largeEmoji(emoji, fitz, file):
                        if let item = self.item {
                            return .optionalAction({
                                item.controllerInteraction.openLargeEmojiInfo(emoji, fitz, file)
                            })
                        }
                    case let .customEmoji(file):
                        if let item = self.item {
                            return .optionalAction({
                                item.controllerInteraction.displayEmojiPackTooltip(file, item.message)
                            })
                        }
                    }
                }
                if self.currentMessageEffect() != nil {
                    if self.backgroundNode.frame.contains(location) {
                        return .action(InternalBubbleTapAction.Action({ [weak self] in
                            guard let self else {
                                return
                            }
                            self.playMessageEffect(force: true)
                        }, contextMenuOnLongPress: true))
                    }
                }
                return nil
            case .longTap, .doubleTap, .secondaryTap:
                if let item = self.item, self.backgroundNode.frame.contains(location) {
                    if let threadInfoNode = self.threadInfoNode, self.item?.controllerInteraction.tapMessage == nil, threadInfoNode.frame.contains(location) {
                        return .action(InternalBubbleTapAction.Action {})
                    }
                    if let replyInfoNode = self.replyInfoNode, self.item?.controllerInteraction.tapMessage == nil, replyInfoNode.frame.contains(location) {
                        if self.selectionNode != nil, let attribute = item.message.attributes.first(where: { $0 is ReplyMessageAttribute }) as? ReplyMessageAttribute {
                            return .action(InternalBubbleTapAction.Action({ [weak self] in
                                guard let self else {
                                    return
                                }
                                var progress: Promise<Bool>?
                                if let replyInfoNode = self.replyInfoNode {
                                    progress = replyInfoNode.makeProgress()
                                }
                                item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: attribute.isQuote ? attribute.quote.flatMap { quote in NavigateToMessageParams.Quote(string: quote.text, offset: quote.offset) } : nil, progress: progress))
                            }, contextMenuOnLongPress: true))
                        } else {
                            return .openContextMenu(InternalBubbleTapAction.OpenContextMenu(tapMessage: item.content.firstMessage, selectAll: false, subFrame: self.backgroundNode.frame, disableDefaultPressAnimation: true))
                        }
                    }
                    
                    var tapMessage: Message? = item.content.firstMessage
                    var selectAll = true
                    var hasFiles = false
                    var disableDefaultPressAnimation = false
                    loop: for contentNode in self.contentNodes {
                        let convertedLocation = self.view.convert(location, to: contentNode.view)
                        
                        if contentNode is ChatMessageFileBubbleContentNode {
                            hasFiles = true
                        }
                        
                        let convertedNodeFrame = contentNode.view.convert(contentNode.bounds, to: self.view)
                        if !convertedNodeFrame.contains(location) {
                            continue loop
                        } else if contentNode is ChatMessageMediaBubbleContentNode {
                            selectAll = false
                        } else if contentNode is ChatMessageFileBubbleContentNode {
                            selectAll = false
                        } else if contentNode is ChatMessageTextBubbleContentNode, hasFiles {
                            selectAll = false
                        }
                        if contentNode is ChatMessageEventLogPreviousMessageContentNode {
                        } else {
                            tapMessage = contentNode.item?.message
                        }
                        let tapAction = contentNode.tapActionAtPoint(convertedLocation, gesture: gesture, isEstimating: false)
                        var rects: [CGRect] = []
                        if let actionRects = tapAction.rects {
                            for rect in actionRects {
                                rects.append(rect.offsetBy(dx: contentNode.frame.minX, dy: contentNode.frame.minY))
                            }
                        }
                        
                        switch tapAction.content {
                        case .none, .ignore:
                            break
                        case let .url(url):
                            if tapAction.hasLongTapAction {
                                return .action(InternalBubbleTapAction.Action({ [weak self] in
                                    let cleanUrl = url.url.replacingOccurrences(of: "mailto:", with: "")
                                    guard let self, let contentNode = self.contextContentNodeForLink(cleanUrl, rects: rects) else {
                                        return
                                    }
                                    item.controllerInteraction.longTap(.url(url.url), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                                }, contextMenuOnLongPress: false))
                            } else {
                                disableDefaultPressAnimation = true
                            }
                        case let .phone(number):
                            return .action(InternalBubbleTapAction.Action({ [weak self] in
                                guard let self, let contentNode = self.contextContentNodeForLink(number, rects: rects) else {
                                    return
                                }
                                item.controllerInteraction.longTap(.phone(number), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                            }, contextMenuOnLongPress: !tapAction.hasLongTapAction))
                        case let .peerMention(peerId, mention, _):
                            return .action(InternalBubbleTapAction.Action { [weak self] in
                                guard let self, let contentNode = self.contextContentNodeForLink(mention, rects: rects) else {
                                    return
                                }
                                item.controllerInteraction.longTap(.peerMention(peerId, mention), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                            })
                        case let .textMention(name):
                            return .action(InternalBubbleTapAction.Action { [weak self] in
                                guard let self, let contentNode = self.contextContentNodeForLink(name, rects: rects) else {
                                    return
                                }
                                item.controllerInteraction.longTap(.mention(name), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                            })
                        case let .botCommand(command):
                            return .action(InternalBubbleTapAction.Action { [weak self] in
                                guard let self, let contentNode = self.contextContentNodeForLink(command, rects: rects) else {
                                    return
                                }
                                item.controllerInteraction.longTap(.command(command), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                            })
                        case let .hashtag(peerName, hashtag):
                            var fullHashtag = hashtag
                            if let peerName {
                                fullHashtag += "@\(peerName)"
                            }
                            return .action(InternalBubbleTapAction.Action { [weak self] in
                                guard let self, let contentNode = self.contextContentNodeForLink(fullHashtag, rects: rects) else {
                                    return
                                }
                                item.controllerInteraction.longTap(.hashtag(fullHashtag), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                            })
                        case .instantPage:
                            break
                        case .wallpaper:
                            break
                        case .theme:
                            break
                        case .call:
                            break
                        case .conferenceCall:
                            break
                        case .openMessage:
                            break
                        case let .timecode(timecode, text):
                            if let mediaMessage = mediaMessage {
                                return .action(InternalBubbleTapAction.Action { [weak self] in
                                    guard let self, let contentNode = self.contextContentNodeForLink(text, rects: rects) else {
                                        return
                                    }
                                    item.controllerInteraction.longTap(.timecode(timecode, text), ChatControllerInteraction.LongTapParams(message: mediaMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                                })
                            }
                        case let .bankCard(number):
                            return .action(InternalBubbleTapAction.Action { [weak self] in
                                guard let self, let contentNode = self.contextContentNodeForLink(number, rects: rects) else {
                                    return
                                }
                                item.controllerInteraction.longTap(.bankCard(number), ChatControllerInteraction.LongTapParams(message: item.content.firstMessage, contentNode: contentNode, messageNode: self, progress: tapAction.activate?()))
                            })
                        case .tooltip:
                            break
                        case .openPollResults:
                            break
                        case .copy:
                            break
                        case .largeEmoji:
                            break
                        case .customEmoji:
                            break
                        case .custom:
                            break
                        }
                    }
                    if let tapMessage = tapMessage {
                        var subFrame = self.backgroundNode.frame
                        if case .group = item.content {
                            for contentNode in self.contentNodes {
                                if contentNode.item?.message.stableId == tapMessage.stableId {
                                    subFrame = contentNode.frame.insetBy(dx: 0.0, dy: -4.0)
                                    break
                                }
                            }
                        }
                        return .openContextMenu(InternalBubbleTapAction.OpenContextMenu(tapMessage: tapMessage, selectAll: selectAll, subFrame: subFrame, disableDefaultPressAnimation: disableDefaultPressAnimation))
                    }
                }
            default:
                break
        }
        return nil
    }
    
    private func contextContentNodeForLink(_ link: String, rects: [CGRect]?) -> ContextExtractedContentContainingNode? {
        guard let item = self.item else {
            return nil
        }
        let containingNode = ContextExtractedContentContainingNode()
        
        let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
        
        let textNode = ImmediateTextNode()
        textNode.maximumNumberOfLines = 2
        textNode.attributedText = NSAttributedString(string: link, font: Font.regular(item.presentationData.fontSize.baseDisplaySize), textColor: incoming ? item.presentationData.theme.theme.chat.message.incoming.linkTextColor : item.presentationData.theme.theme.chat.message.outgoing.linkTextColor)
        let textSize = textNode.updateLayout(CGSize(width: self.bounds.width - 32.0, height: 100.0))
        
        let backgroundNode = ASDisplayNode()
        backgroundNode.backgroundColor = (incoming ? item.presentationData.theme.theme.chat.message.incoming.bubble.withoutWallpaper.fill : item.presentationData.theme.theme.chat.message.outgoing.bubble.withoutWallpaper.fill).first ?? .black
        backgroundNode.clipsToBounds = true
        backgroundNode.cornerRadius = 10.0
        
        let insets = UIEdgeInsets(top: 5.0, left: 8.0, bottom: 5.0, right: 8.0)
        let backgroundSize = CGSize(width: textSize.width + insets.left + insets.right, height: textSize.height + insets.top + insets.bottom)
        backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backgroundSize)
        textNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: textSize)
        backgroundNode.addSubnode(textNode)
        
        var origin = CGPoint(x: self.backgroundNode.frame.minX + 3.0, y: 1.0)
        if let rect = rects?.first {
            origin = rect.origin
        }
        
        containingNode.frame = CGRect(origin: origin, size: CGSize(width: backgroundSize.width, height: backgroundSize.height + 20.0))
        containingNode.contentNode.frame = CGRect(origin: .zero, size: backgroundSize)
        containingNode.contentRect = CGRect(origin: .zero, size: backgroundSize)
        containingNode.contentNode.addSubnode(backgroundNode)
        
        containingNode.contentNode.alpha = 0.0
        
        self.addSubnode(containingNode)
        
        return containingNode
    }
    
    private func traceSelectionNodes(parent: ASDisplayNode, point: CGPoint) -> ASDisplayNode? {
        if let parent = parent as? FileMessageSelectionNode, parent.bounds.contains(point) {
            return parent
        } else if let parent = parent as? GridMessageSelectionNode, parent.bounds.contains(point) {
            return parent
        } else if let parentSubnodes = parent.subnodes {
            for subnode in parentSubnodes {
                if let result = traceSelectionNodes(parent: subnode, point: point.offsetBy(dx: -subnode.frame.minX + subnode.bounds.minX, dy: -subnode.frame.minY + subnode.bounds.minY)) {
                    return result
                }
            }
        }
        return nil
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if self.mainContextSourceNode.isExtractedToContextPreview {
            if let result = super.hitTest(point, with: event) as? TextSelectionNodeView {
                return result
            }
            return nil
        }

        if let threadInfoNode = self.threadInfoNode, let result = threadInfoNode.hitTest(self.view.convert(point, to: threadInfoNode.view), with: event) {
            return result
        }
        
        if let nameButtonNode = self.nameButtonNode, nameButtonNode.frame.contains(point) {
            return nameButtonNode.view
        }
        
        if let credibilityButtonNode = self.credibilityButtonNode, credibilityButtonNode.frame.contains(point) {
            return credibilityButtonNode.view
        }
        
        if let boostButtonNode = self.boostButtonNode, boostButtonNode.frame.contains(point) {
            return boostButtonNode.view
        }
        
        if let shareButtonNode = self.shareButtonNode, shareButtonNode.frame.contains(point) {
            return shareButtonNode.view.hitTest(self.view.convert(point, to: shareButtonNode.view), with: event)
        }
        
        if let selectionNode = self.selectionNode {
            if let result = self.traceSelectionNodes(parent: self, point: point.offsetBy(dx: -42.0, dy: 0.0)) {
                return result.view
            }
            
            var selectionNodeFrame = selectionNode.frame
            selectionNodeFrame.origin.x -= 42.0
            selectionNodeFrame.size.width += 42.0 * 2.0
            if selectionNodeFrame.contains(point) {
                return selectionNode.view
            } else {
                return nil
            }
        }
        
        if !self.backgroundNode.frame.contains(point) {
            if let actionButtonsNode = self.actionButtonsNode, let result = actionButtonsNode.hitTest(self.view.convert(point, to: actionButtonsNode.view), with: event) {
                return result
            }
        }
        
        if let mosaicStatusNode = self.mosaicStatusNode {
            if let result = mosaicStatusNode.hitTest(self.view.convert(point, to: mosaicStatusNode.view), with: event) {
                return result
            }
        }
        
        for contentNode in self.contentNodes {
            if let result = contentNode.hitTest(self.view.convert(point, to: contentNode.view), with: event) {
                return result
            }
        }
                
        return super.hitTest(point, with: event)
    }
    
    override public func transitionNode(id: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        for contentNode in self.contentNodes {
            if let result = contentNode.transitionNode(messageId: id, media: media, adjustRect: adjustRect) {
                if self.contentNodes.count == 1 && self.contentNodes.first is ChatMessageMediaBubbleContentNode && self.nameNode == nil && self.adminBadgeNode == nil && self.forwardInfoNode == nil && self.replyInfoNode == nil {
                    return (result.0, result.1, { [weak self] in
                        guard let strongSelf = self, let resultView = result.2().0 else {
                            return (nil, nil)
                        }
                        if strongSelf.backgroundNode.supernode != nil, let backgroundView = strongSelf.backgroundNode.view.snapshotContentTree(unhide: true) {
                            let backgroundContainer = UIView()
                            
                            let backdropView = strongSelf.backgroundWallpaperNode.view.snapshotContentTree(unhide: true)
                            if let backdropView = backdropView {
                                let backdropFrame = strongSelf.backgroundWallpaperNode.layer.convert(strongSelf.backgroundWallpaperNode.bounds, to: strongSelf.backgroundNode.layer)
                                backdropView.frame = backdropFrame
                            }
                            
                            if let backdropView = backdropView {
                                backgroundContainer.addSubview(backdropView)
                            }
                            
                            backgroundContainer.addSubview(backgroundView)
                            
                            let backgroundFrame = strongSelf.backgroundNode.layer.convert(strongSelf.backgroundNode.bounds, to: result.0.layer)
                            backgroundView.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
                            backgroundContainer.frame = backgroundFrame
                            let viewWithBackground = UIView()
                            viewWithBackground.addSubview(backgroundContainer)
                            viewWithBackground.frame = resultView.frame
                            resultView.frame = CGRect(origin: CGPoint(), size: resultView.frame.size)
                            viewWithBackground.addSubview(resultView)
                            return (viewWithBackground, backgroundContainer)
                        }
                        return (resultView, nil)
                    })
                }
                return result
            }
        }
        return nil
    }
    
    override public func updateHiddenMedia() {
        var hasHiddenMediaInfo = false
        var hasHiddenMosaicStatus = false
        var hasHiddenBackground = false
        if let item = self.item {
            for contentNode in self.contentNodes {
                if let contentItem = contentNode.item {
                    if contentNode.updateHiddenMedia(item.controllerInteraction.hiddenMedia[contentItem.message.id]) {
                        if self.contentNodes.count == 1 && self.contentNodes.first is ChatMessageMediaBubbleContentNode && self.nameNode == nil && self.adminBadgeNode == nil && self.forwardInfoNode == nil && self.replyInfoNode == nil {
                            hasHiddenBackground = true
                        }
                        if let mosaicStatusNode = self.mosaicStatusNode, mosaicStatusNode.frame.intersects(contentNode.frame) {
                            hasHiddenMosaicStatus = true
                        }
                        if let mediaInfoNode = self.mediaInfoNode, mediaInfoNode.frame.intersects(contentNode.frame) {
                            hasHiddenMediaInfo = true
                        }
                    }
                }
            }
        }
        
        if let mosaicStatusNode = self.mosaicStatusNode {
            if mosaicStatusNode.alpha.isZero != hasHiddenMosaicStatus {
                if hasHiddenMosaicStatus {
                    mosaicStatusNode.alpha = 0.0
                } else {
                    mosaicStatusNode.alpha = 1.0
                    mosaicStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
        
        if let mediaInfoNode = self.mediaInfoNode {
            if mediaInfoNode.alpha.isZero != hasHiddenMediaInfo {
                if hasHiddenMediaInfo {
                    mediaInfoNode.alpha = 0.0
                } else {
                    mediaInfoNode.alpha = 1.0
                    mediaInfoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.backgroundNode.isHidden = hasHiddenBackground
        self.backgroundWallpaperNode.isHidden = hasHiddenBackground
    }
    
    override public func updateAutomaticMediaDownloadSettings() {
        if let item = self.item {
            for contentNode in self.contentNodes {
                contentNode.updateAutomaticMediaDownloadSettings(item.controllerInteraction.automaticMediaDownloadSettings)
            }
        }
    }
    
    override public func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        for contentNode in self.contentNodes {
            if let playMediaWithSound = contentNode.playMediaWithSound() {
                return playMediaWithSound
            }
        }
        return nil
    }
    
    override public func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        let wasSelected = self.selectionNode?.selected
        
        var canHaveSelection = true
        switch item.content {
            case let .message(message, _, _, _, _):
                for media in message.media {
                    if let action = media as? TelegramMediaAction {
                        if case .phoneCall = action.action {
                        } else if case .conferenceCall = action.action {
                        } else {
                            canHaveSelection = false
                            break
                        }
                    } else if media is TelegramMediaExpiredContent {
                        canHaveSelection = false
                    }
                }
                if message.adAttribute != nil {
                    canHaveSelection = false
                }
            default:
                break
        }
        if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.effectiveTopId == item.message.id {
            canHaveSelection = false
        }
        
        if let selectionState = item.controllerInteraction.selectionState, canHaveSelection {
            var selected = false
            let incoming = item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData)
            
            switch item.content {
                case let .message(message, _, _, _, _):
                    selected = selectionState.selectedIds.contains(message.id)
                case let .group(messages: messages):
                    var allSelected = !messages.isEmpty
                    for (message, _, _, _, _) in messages {
                        if !selectionState.selectedIds.contains(message.id) {
                            allSelected = false
                            break
                        }
                    }
                    selected = allSelected
            }
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: animated)
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentSize.width, height: self.contentSize.height))
                
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size, leftInset: self.safeInsets.left)
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(wallpaper: item.presentationData.theme.wallpaper, theme: item.presentationData.theme.theme, toggle: { [weak self] value in
                    if let strongSelf = self, let item = strongSelf.item {
                        switch item.content {
                        case let .message(message, _, _, _, _):
                            item.controllerInteraction.toggleMessagesSelection([message.id], value)
                        case let .group(messages):
                            item.controllerInteraction.toggleMessagesSelection(messages.map { $0.0.id }, value)
                        }
                    }
                })
                
                let selectionFrame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentSize.width, height: self.contentSize.height))
                selectionNode.frame = selectionFrame
                selectionNode.updateLayout(size: selectionFrame.size, leftInset: self.safeInsets.left)
                self.insertSubnode(selectionNode, belowSubnode: self.messageAccessibilityArea)
                self.selectionNode = selectionNode
                selectionNode.updateSelected(selected, animated: false)
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
                if animated {
                    selectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2)
                    
                    if !incoming {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: CGPoint(x: position.x - 42.0, y: position.y), to: position, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                    }
                }
            }
        } else {
            if let selectionNode = self.selectionNode {
                self.selectionNode = nil
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DIdentity
                if animated {
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.2, completion: { [weak selectionNode]_ in
                        selectionNode?.removeFromSupernode()
                    })
                    selectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                    if CGFloat(0.0).isLessThanOrEqualTo(selectionNode.frame.origin.x) {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: position, to: CGPoint(x: position.x - 42.0, y: position.y), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                    }
                } else {
                    selectionNode.removeFromSupernode()
                }
            }
        }
        
        let isSelected = self.selectionNode?.selected
        if wasSelected != isSelected {
            self.updateAccessibilityData(ChatMessageAccessibilityData(item: item, isSelected: isSelected))
        }
    }
    
    override public func updateSearchTextHighlightState() {
        for contentNode in self.contentNodes {
            contentNode.updateSearchTextHighlightState(text: self.item?.controllerInteraction.searchTextHighightState?.0, messages: self.item?.controllerInteraction.searchTextHighightState?.1)
        }
    }
    
    override public func updateHighlightedState(animated: Bool) {
        super.updateHighlightedState(animated: animated)
        
        guard let item = self.item, let _ = self.backgroundType else {
            return
        }
        
        var highlightedState: HighlightedState?
        
        for contentNode in self.contentNodes {
            let _ = contentNode.updateHighlightedState(animated: animated)
        }
        
        if let highlightedStateValue = item.controllerInteraction.highlightedState {
            for (message, _) in item.content {
                if highlightedStateValue.messageStableId == message.stableId {
                    highlightedState = HighlightedState(quote: highlightedStateValue.quote)
                    break
                }
            }
        }
        
        if self.highlightedState != highlightedState {
            self.highlightedState = highlightedState
            
            for contentNode in self.contentNodes {
                if let contentNode = contentNode as? ChatMessageTextBubbleContentNode {
                    contentNode.updateQuoteTextHighlightState(text: nil, offset: nil, color: .clear, animated: true)
                }
            }
            
            if let backgroundType = self.backgroundType {
                let graphics = PresentationResourcesChat.principalGraphics(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, bubbleCorners: item.presentationData.chatBubbleCorners)
                
                if self.highlightedState != nil, !(self.backgroundNode.layer.mask is SimpleLayer) {
                    let backgroundHighlightNode: ChatMessageBackground
                    if let current = self.backgroundHighlightNode {
                        backgroundHighlightNode = current
                    } else {
                        backgroundHighlightNode = ChatMessageBackground()
                        self.mainContextSourceNode.contentNode.insertSubnode(backgroundHighlightNode, aboveSubnode: self.backgroundNode)
                        self.backgroundHighlightNode = backgroundHighlightNode
                        
                        let hasWallpaper = item.presentationData.theme.wallpaper.hasWallpaper
                        let incoming: PresentationThemeBubbleColorComponents = !hasWallpaper ? item.presentationData.theme.theme.chat.message.incoming.bubble.withoutWallpaper : item.presentationData.theme.theme.chat.message.incoming.bubble.withWallpaper
                        let outgoing: PresentationThemeBubbleColorComponents = !hasWallpaper ? item.presentationData.theme.theme.chat.message.outgoing.bubble.withoutWallpaper : item.presentationData.theme.theme.chat.message.outgoing.bubble.withWallpaper
                        
                        let highlightColor: UIColor
                        if item.message.effectivelyIncoming(item.context.account.peerId) {
                            if let authorNameColor = self.authorNameColor {
                                highlightColor = authorNameColor.withMultipliedAlpha(0.2)
                            } else {
                                highlightColor = incoming.highlightedFill
                            }
                        } else {
                            if let authorNameColor = self.authorNameColor {
                                highlightColor = authorNameColor.withMultipliedAlpha(0.2)
                            } else {
                                highlightColor = outgoing.highlightedFill
                            }
                        }
                        
                        backgroundHighlightNode.customHighlightColor = highlightColor
                        backgroundHighlightNode.setType(type: backgroundType, highlighted: true, graphics: graphics, maskMode: true, hasWallpaper: true, transition: .immediate, backgroundNode: nil)
                        
                        backgroundHighlightNode.frame = self.backgroundNode.frame
                        backgroundHighlightNode.updateLayout(size: backgroundHighlightNode.frame.size, transition: .immediate)
                        
                        if highlightedState?.quote != nil {
                            Queue.mainQueue().after(0.3, { [weak self] in
                                guard let self, let item = self.item, let backgroundHighlightNode = self.backgroundHighlightNode else {
                                    return
                                }
                                
                                if let highlightedState = self.highlightedState, let quote = highlightedState.quote {
                                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
                                    
                                    var quoteFrame: CGRect?
                                    for contentNode in self.contentNodes {
                                        if let contentNode = contentNode as? ChatMessageTextBubbleContentNode {
                                            contentNode.updateQuoteTextHighlightState(text: quote.string, offset: quote.offset, color: highlightColor, animated: false)
                                            var sourceFrame = backgroundHighlightNode.view.convert(backgroundHighlightNode.bounds, to: contentNode.view)
                                            if item.message.effectivelyIncoming(item.context.account.peerId) {
                                                sourceFrame.origin.x += 6.0
                                                sourceFrame.size.width -= 6.0
                                            } else {
                                                sourceFrame.size.width -= 6.0
                                            }
                                            
                                            if let localFrame = contentNode.animateQuoteTextHighlightIn(sourceFrame: sourceFrame, transition: transition) {
                                                if self.contentNodes[0] !== contentNode && self.contentNodes[0].supernode === contentNode.supernode {
                                                    contentNode.supernode?.insertSubnode(contentNode, belowSubnode: self.contentNodes[0])
                                                }
                                                
                                                quoteFrame = contentNode.view.convert(localFrame, to: backgroundHighlightNode.view.superview)
                                            }
                                            break
                                        }
                                    }
                                    
                                    if let quoteFrame {
                                        self.backgroundHighlightNode = nil
                                        
                                        backgroundHighlightNode.updateLayout(size: quoteFrame.size, transition: transition)
                                        transition.updateFrame(node: backgroundHighlightNode, frame: quoteFrame)
                                        backgroundHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, delay: 0.05, removeOnCompletion: false, completion: { [weak backgroundHighlightNode] _ in
                                            backgroundHighlightNode?.removeFromSupernode()
                                        })
                                    }
                                }
                            })
                        }
                    }
                } else {
                    if let backgroundHighlightNode = self.backgroundHighlightNode {
                        self.backgroundHighlightNode = nil
                        if animated {
                            backgroundHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak backgroundHighlightNode] _ in
                                backgroundHighlightNode?.removeFromSupernode()
                            })
                        } else {
                            backgroundHighlightNode.removeFromSupernode()
                        }
                    }
                }
            }
        }
    }
    
    @objc private func shareButtonPressed() {
        if let item = self.item {
            if item.message.adAttribute != nil {
                item.controllerInteraction.openNoAdsDemo()
            } else if case let .customChatContents(contents) = item.associatedData.subject, case .hashTagSearch = contents.kind {
                item.controllerInteraction.navigateToMessage(item.content.firstMessage.id, item.content.firstMessage.id, NavigateToMessageParams(timestamp: nil, quote: nil, forceNew: true))
            } else if case .pinnedMessages = item.associatedData.subject {
                item.controllerInteraction.navigateToMessageStandalone(item.content.firstMessage.id)
            } else if item.content.firstMessage.id.peerId.isRepliesOrSavedMessages(accountPeerId: item.context.account.peerId) {
                for attribute in item.content.firstMessage.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        item.controllerInteraction.navigateToMessage(item.content.firstMessage.id, attribute.messageId, NavigateToMessageParams(timestamp: nil, quote: nil))
                        break
                    }
                }
            } else if let channel = item.message.peers[item.message.id.peerId], channel.isMonoForum, case .peer = item.chatLocation {
                item.controllerInteraction.updateChatLocationThread(item.message.threadId, nil)
            } else {
                if !self.disablesComments {
                    if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                        for attribute in item.message.attributes {
                            if let _ = attribute as? ReplyThreadMessageAttribute {
                                item.controllerInteraction.openMessageReplies(item.message.id, true, false)
                                return
                            }
                        }
                    }
                }
                item.controllerInteraction.openMessageShareMenu(item.message.id)
            }
        }
    }
                                               
    private func openQuickShare(node: ASDisplayNode, gesture: ContextGesture) {
        if let item = self.item {
            item.controllerInteraction.displayQuickShare(item.message.id, node, gesture)
        }
    }
    
    @objc private func closeButtonPressed() {
        if let item = self.item {
            item.controllerInteraction.openNoAdsDemo()
        }
    }
    
    @objc private func nameButtonPressed() {
        if let item = self.item, let peer = item.message.author {
            let messageReference = MessageReference(item.message)
            if peer.id.isVerificationCodes, let forwardAuthor = item.content.firstMessage.forwardInfo?.author {
                if let channel = forwardAuthor as? TelegramChannel, case .broadcast = channel.info {
                    item.controllerInteraction.openPeer(EnginePeer(channel), .chat(textInputState: nil, subject: nil, peekData: nil), messageReference, .default)
                } else {
                    item.controllerInteraction.openPeer(EnginePeer(forwardAuthor), .info(nil), messageReference, .default)
                }
            } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                item.controllerInteraction.openPeer(EnginePeer(peer), .chat(textInputState: nil, subject: nil, peekData: nil), messageReference, .default)
            } else {
                item.controllerInteraction.openPeer(EnginePeer(peer), .info(nil), messageReference, .groupParticipant(storyStats: nil, avatarHeaderNode: nil))
            }
        }
    }
    
    @objc private func credibilityButtonPressed() {
        if let item = self.item, let credibilityIconView = self.credibilityIconView, let iconContent = self.credibilityIconContent, let peer = item.message.author {
            if case let .starGift(_, _, _, slug, _, _, _, _, _) = peer.emojiStatus?.content {
                item.controllerInteraction.openUniqueGift(slug)
            } else {
                var emojiFileId: Int64?
                switch iconContent {
                case let .animation(content, _, _, _, _):
                    emojiFileId = content.fileId.id
                case .premium:
                    break
                default:
                    return
                }
                item.controllerInteraction.openPremiumStatusInfo(peer.id, credibilityIconView, emojiFileId, peer.nameColor ?? .blue)
            }
        }
    }
    
    @objc private func boostButtonPressed() {
        guard let item = self.item, let peer = item.message.author else {
            return
        }
        
        var boostCount: Int = 0
        for attribute in item.message.attributes {
            if let attribute = attribute as? BoostCountMessageAttribute {
                boostCount = attribute.count
            }
        }
        
        item.controllerInteraction.openGroupBoostInfo(peer.id, boostCount)
    }
    
    private var playedSwipeToReplyHaptic = false
    @objc private func swipeToReplyGesture(_ recognizer: ChatSwipeToReplyRecognizer) {
        var offset: CGFloat = 0.0
        var leftOffset: CGFloat = 0.0
        var swipeOffset: CGFloat = 45.0
        if let item = self.item, item.content.effectivelyIncoming(item.context.account.peerId, associatedData: item.associatedData) {
            offset = -24.0
            leftOffset = -10.0
        } else {
            offset = 10.0
            leftOffset = -10.0
            swipeOffset = 60.0
        }
        
        switch recognizer.state {
            case .began:
                self.playedSwipeToReplyHaptic = false
                self.currentSwipeToReplyTranslation = 0.0
                if self.swipeToReplyFeedback == nil {
                    self.swipeToReplyFeedback = HapticFeedback()
                    self.swipeToReplyFeedback?.prepareImpact()
                }
                self.item?.controllerInteraction.cancelInteractiveKeyboardGestures()
            case .changed:
                var translation = recognizer.translation(in: self.view)
                func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                    let bandedOffset = offset - bandingStart
                    if offset < bandingStart {
                        return offset
                    }
                    let range: CGFloat = 100.0
                    let coefficient: CGFloat = 0.4
                    return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                }
            
                if translation.x < 0.0 {
                    translation.x = max(-180.0, min(0.0, -rubberBandingOffset(offset: abs(translation.x), bandingStart: swipeOffset)))
                } else {
                    if recognizer.allowBothDirections {
                        translation.x = -max(-180.0, min(0.0, -rubberBandingOffset(offset: abs(translation.x), bandingStart: swipeOffset)))
                    } else {
                        translation.x = 0.0
                    }
                }
            
                if let item = self.item, self.swipeToReplyNode == nil {
                    let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), foregroundColor: bubbleVariableColor(variableColor: item.presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: item.presentationData.theme.wallpaper), backgroundNode: item.controllerInteraction.presentationContext.backgroundNode, action: ChatMessageSwipeToReplyNode.Action(self.currentSwipeAction))
                    self.swipeToReplyNode = swipeToReplyNode
                    self.insertSubnode(swipeToReplyNode, at: 0)
                }
            
                self.currentSwipeToReplyTranslation = translation.x
                var bounds = self.bounds
                bounds.origin.x = -translation.x
                self.bounds = bounds
                var shadowBounds = self.shadowNode.bounds
                shadowBounds.origin.x = -translation.x
                self.shadowNode.bounds = shadowBounds

                self.updateAttachedAvatarNodeOffset(offset: translation.x, transition: .immediate)
            
                if let swipeToReplyNode = self.swipeToReplyNode {
                    if translation.x < 0.0 {
                        swipeToReplyNode.bounds = CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0))
                        swipeToReplyNode.position = CGPoint(x: bounds.size.width + offset + 33.0 * 0.5, y: self.contentSize.height / 2.0)
                    } else {
                        swipeToReplyNode.bounds = CGRect(origin: .zero, size: CGSize(width: 33.0, height: 33.0))
                        swipeToReplyNode.position = CGPoint(x: leftOffset - 33.0 * 0.5, y: self.contentSize.height / 2.0)
                    }

                    if let (rect, containerSize) = self.absoluteRect {
                        let mappedRect = CGRect(origin: CGPoint(x: rect.minX + swipeToReplyNode.frame.minX, y: rect.minY + swipeToReplyNode.frame.minY), size: swipeToReplyNode.frame.size)
                        swipeToReplyNode.updateAbsoluteRect(mappedRect, within: containerSize)
                    }
                    
                    let progress = abs(translation.x) / swipeOffset
                    swipeToReplyNode.updateProgress(progress)
                    
                    if progress > 1.0 - .ulpOfOne && !self.playedSwipeToReplyHaptic {
                        self.playedSwipeToReplyHaptic = true
                        self.swipeToReplyFeedback?.impact(.heavy)
                    }
                }
            case .cancelled, .ended:
                self.swipeToReplyFeedback = nil
                
                let translation = recognizer.translation(in: self.view)
                let gestureRecognized: Bool
                if recognizer.allowBothDirections {
                    gestureRecognized = abs(translation.x) > swipeOffset
                } else {
                    gestureRecognized = translation.x < -swipeOffset
                }
                if case .ended = recognizer.state, gestureRecognized {
                    if let item = self.item {
                        if let currentSwipeAction = currentSwipeAction {
                            switch currentSwipeAction {
                            case .none:
                                break
                            case .reply:
                                item.controllerInteraction.setupReply(item.message.id)
                            }
                        }
                    }
                }
                var bounds = self.bounds
                let previousBounds = bounds
                bounds.origin.x = 0.0
                self.bounds = bounds
                var shadowBounds = self.shadowNode.bounds
                let previousShadowBounds = shadowBounds
                shadowBounds.origin.x = 0.0
                self.shadowNode.bounds = shadowBounds
                self.layer.animateBounds(from: previousBounds, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)

                self.updateAttachedAvatarNodeOffset(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))

                self.shadowNode.layer.animateBounds(from: previousShadowBounds, to: shadowBounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
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
    
    private var absoluteRect: (CGRect, CGSize)?
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        guard !self.mainContextSourceNode.isExtractedToContextPreview else {
            return
        }
        var rect = rect
        rect.origin.y = containerSize.height - rect.maxY + self.insets.top
        self.updateAbsoluteRectInternal(rect, within: containerSize)
    }
    
    private func updateAbsoluteRectInternal(_ rect: CGRect, within containerSize: CGSize) {
        var backgroundWallpaperFrame = self.backgroundWallpaperNode.frame
        backgroundWallpaperFrame.origin.x += rect.minX
        backgroundWallpaperFrame.origin.y += rect.minY
        self.backgroundWallpaperNode.update(rect: backgroundWallpaperFrame, within: containerSize)
        for contentNode in self.contentNodes {
            contentNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: rect.minX + contentNode.frame.minX, y: rect.minY + contentNode.frame.minY), size: rect.size), within: containerSize)
        }
        
        for container in self.contentContainers {
            var containerFrame = self.mainContainerNode.frame
            containerFrame.origin.x += rect.minX
            containerFrame.origin.y += rect.minY
            container.updateAbsoluteRect(containerFrame, within: containerSize)
        }
        
        if let shareButtonNode = self.shareButtonNode {
            var shareButtonNodeFrame = shareButtonNode.frame
            shareButtonNodeFrame.origin.x += rect.minX
            shareButtonNodeFrame.origin.y += rect.minY
            
            shareButtonNode.updateAbsoluteRect(shareButtonNodeFrame, within: containerSize)
        }
        
        if let actionButtonsNode = self.actionButtonsNode {
            var actionButtonsNodeFrame = actionButtonsNode.frame
            actionButtonsNodeFrame.origin.x += rect.minX
            actionButtonsNodeFrame.origin.y += rect.minY
            
            actionButtonsNode.updateAbsoluteRect(actionButtonsNodeFrame, within: containerSize)
        }
        
        if let reactionButtonsNode = self.reactionButtonsNode {
            var reactionButtonsNodeFrame = reactionButtonsNode.frame
            reactionButtonsNodeFrame.origin.x += rect.minX
            reactionButtonsNodeFrame.origin.y += rect.minY
            
            reactionButtonsNode.update(rect: rect, within: containerSize, transition: .immediate)
        }
    }
    
    override public func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if !self.mainContextSourceNode.isExtractedToContextPreview {
            self.applyAbsoluteOffsetInternal(value: CGPoint(x: -value.x, y: -value.y), animationCurve: animationCurve, duration: duration)
        }
    }
    
    private func applyAbsoluteOffsetInternal(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        self.backgroundWallpaperNode.offset(value: value, animationCurve: animationCurve, duration: duration)

        for contentNode in self.contentNodes {
            contentNode.applyAbsoluteOffset(value: value, animationCurve: animationCurve, duration: duration)
        }
        
        if let reactionButtonsNode = self.reactionButtonsNode {
            reactionButtonsNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }
    
    private func applyAbsoluteOffsetSpringInternal(value: CGFloat, duration: Double, damping: CGFloat) {
        self.backgroundWallpaperNode.offsetSpring(value: value, duration: duration, damping: damping)

        for contentNode in self.contentNodes {
            contentNode.applyAbsoluteOffsetSpring(value: value, duration: duration, damping: damping)
        }
        
        if let reactionButtonsNode = self.reactionButtonsNode {
            reactionButtonsNode.offsetSpring(value: value, duration: duration, damping: damping)
        }
    }
    
    override public func getMessageContextSourceNode(stableId: UInt32?) -> ContextExtractedContentContainingNode? {
        if self.contentContainers.count > 1 {
            return self.contentContainers.first(where: { $0.contentMessageStableId == stableId })?.sourceNode ?? self.mainContextSourceNode
        } else {
            return self.mainContextSourceNode
        }
    }
    
    override public func addAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        self.mainContextSourceNode.contentNode.addSubnode(accessoryItemNode)
    }
    
    private var backgroundMaskMode: Bool {
        let hasWallpaper = self.item?.presentationData.theme.wallpaper.hasWallpaper ?? false
        let isPreview = self.item?.presentationData.isPreview ?? false
        return self.mainContextSourceNode.isExtractedToContextPreview || hasWallpaper || isPreview || !self.disablesComments
    }
    
    override public func openMessageContextMenu() {
        guard let item = self.item else {
            return
        }
        let subFrame = self.backgroundNode.frame
        item.controllerInteraction.openMessageContextMenu(item.message, true, self, subFrame, nil, nil)
    }
    
    override public func makeProgress() -> Promise<Bool>? {
        if let unlockButtonNode = self.unlockButtonNode {
            return unlockButtonNode.makeProgress()
        } else {
            for contentNode in self.contentNodes {
                if let webpageContentNode = contentNode as? ChatMessageWebpageBubbleContentNode {
                    return webpageContentNode.contentNode.makeProgress()
                }
            }
        }
        return nil
    }
    
    override public func targetReactionView(value: MessageReaction.Reaction) -> UIView? {
        if let result = self.reactionButtonsNode?.reactionTargetView(value: value) {
            return result
        }
        for contentNode in self.contentNodes {
            if let result = contentNode.reactionTargetView(value: value) {
                return result
            }
        }
        if let mosaicStatusNode = self.mosaicStatusNode, let result = mosaicStatusNode.reactionView(value: value) {
            return result
        }
        return nil
    }
    
    override public func targetForStoryTransition(id: StoryId) -> UIView? {
        guard let item = self.item else {
            return nil
        }
        for contentNode in self.contentNodes {
            if let value = contentNode.targetForStoryTransition(id: id) {
                return value
            }
        }
        for attribute in item.message.attributes {
            if let attribute = attribute as? ReplyStoryAttribute {
                if attribute.storyId == id {
                    if let replyInfoNode = self.replyInfoNode {
                        return replyInfoNode.mediaTransitionView()
                    }
                }
            }
        }
        return nil
    }
    
    override public func unreadMessageRangeUpdated() {
        for contentNode in self.contentNodes {
            contentNode.unreadMessageRangeUpdated()
        }
        
        self.updateVisibility()
    }
    
    public func animateQuizInvalidOptionSelected() {
        if let supernode = self.supernode, let subnodes = supernode.subnodes {
            for i in 0 ..< subnodes.count {
                if subnodes[i] === self {
                    break
                }
            }
        }
        
        let duration: Double = 0.5
        let minScale: CGFloat = -0.03
        let scaleAnimation0 = self.layer.makeAnimation(from: 0.0 as NSNumber, to: minScale as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration / 2.0, removeOnCompletion: false, additive: true, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            let scaleAnimation1 = strongSelf.layer.makeAnimation(from: minScale as NSNumber, to: 0.0 as NSNumber, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: duration / 2.0, additive: true)
            strongSelf.layer.add(scaleAnimation1, forKey: "quizInvalidScale")
        })
        self.layer.add(scaleAnimation0, forKey: "quizInvalidScale")
        
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        
        let count = 4
                
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        var values: [CGFloat] = []
        values.append(0.0)
        let rotationAmplitude: CGFloat = CGFloat.pi / 180.0 * 3.0
        for i in 0 ..< count {
            let sign: CGFloat = (i % 2 == 0) ? 1.0 : -1.0
            let amplitude: CGFloat = rotationAmplitude
            values.append(amplitude * sign)
        }
        values.append(0.0)
        animation.values = values.map { ($0 as NSNumber) as AnyObject }
        var keyTimes: [NSNumber] = []
        for i in 0 ..< values.count {
            if i == 0 {
                keyTimes.append(0.0)
            } else if i == values.count - 1 {
                keyTimes.append(1.0)
            } else {
                keyTimes.append((Double(i) / Double(values.count - 1)) as NSNumber)
            }
        }
        animation.keyTimes = keyTimes
        animation.speed = speed
        animation.duration = duration
        animation.isAdditive = true
        
        self.layer.add(animation, forKey: "quizInvalidRotation")
    }
    
    public func updatePsaTooltipMessageState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        if let forwardInfoNode = self.forwardInfoNode {
            forwardInfoNode.updatePsaButtonDisplay(isVisible: item.controllerInteraction.currentPsaMessageWithTooltip != item.message.id, animated: animated)
        }
    }
    
    override public func getStatusNode() -> ASDisplayNode? {
        if let statusNode = self.mosaicStatusNode {
            return statusNode
        }
        for contentNode in self.contentNodes {
            if let statusNode = contentNode.getStatusNode() {
                return statusNode
            }
        }
        return nil
    }
    
    public func getQuoteRect(quote: String, offset: Int?) -> CGRect? {
        for contentNode in self.contentNodes {
            if let contentNode = contentNode as? ChatMessageTextBubbleContentNode {
                if let result = contentNode.getQuoteRect(quote: quote, offset: offset) {
                    return contentNode.view.convert(result, to: self.view)
                }
            }
        }
        return nil
    }
    
    public func hasExpandedAudioTranscription() -> Bool {
        for contentNode in self.contentNodes {
            if let contentNode = contentNode as? ChatMessageFileBubbleContentNode {
                return contentNode.interactiveFileNode.hasExpandedAudioTranscription
            } else if let contentNode = contentNode as? ChatMessageInstantVideoBubbleContentNode {
                return contentNode.hasExpandedAudioTranscription
            }
        }
        return false
    }
    
    override public func contentFrame() -> CGRect {
        return self.backgroundNode.frame
    }
    
    override public func makeContentSnapshot() -> (UIImage, CGRect)? {
        UIGraphicsBeginImageContextWithOptions(self.backgroundNode.view.bounds.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()!
        
        context.translateBy(x: -self.backgroundNode.frame.minX, y: -self.backgroundNode.frame.minY)
        
        context.translateBy(x: -self.mainContextSourceNode.contentNode.view.frame.minX, y: -self.mainContextSourceNode.contentNode.view.frame.minY)
        for subview in self.mainContextSourceNode.contentNode.view.subviews {
            if subview.isHidden || subview.alpha == 0.0 {
                continue
            }
            if subview === self.backgroundWallpaperNode.view {
                var targetPortalView: UIView?
                for backgroundSubview0 in subview.subviews {
                    for backgroundSubview1 in backgroundSubview0.subviews {
                        if isViewPortalView(backgroundSubview1) {
                            targetPortalView = backgroundSubview1
                            break
                        }
                    }
                }
                
                if let targetPortalView, let sourceView = getPortalViewSourceView(targetPortalView) {
                    context.saveGState()
                    context.translateBy(x: subview.frame.minX, y: subview.frame.minY)
                    
                    if let mask = subview.mask {
                        let maskImage = generateImage(subview.bounds.size, rotatedContext: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            UIGraphicsPushContext(context)
                            mask.drawHierarchy(in: mask.frame, afterScreenUpdates: false)
                            UIGraphicsPopContext()
                        })
                        if let cgImage = maskImage?.cgImage {
                            context.translateBy(x: subview.frame.midX, y: subview.frame.midY)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -subview.frame.midX, y: -subview.frame.midY)
                            
                            context.clip(to: subview.bounds, mask: cgImage)
                            
                            context.translateBy(x: subview.frame.midX, y: subview.frame.midY)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -subview.frame.midX, y: -subview.frame.midY)
                        }
                    }
                    
                    let sourceLocalFrame = sourceView.convert(sourceView.bounds, to: subview)
                    for sourceSubview in sourceView.subviews {
                        sourceSubview.drawHierarchy(in: CGRect(origin: sourceLocalFrame.origin, size: sourceSubview.bounds.size), afterScreenUpdates: false)
                    }
                    
                    context.resetClip()
                    context.restoreGState()
                } else {
                    subview.drawHierarchy(in: subview.frame, afterScreenUpdates: false)
                }
            } else {
                subview.drawHierarchy(in: subview.frame, afterScreenUpdates: false)
            }
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let image else {
            return nil
        }
        
        return (image, self.backgroundNode.frame)
    }
    
    public func isServiceLikeMessage() -> Bool {
        for contentNode in self.contentNodes {
            if contentNode is ChatMessageActionBubbleContentNode {
                return true
            }
        }
        return false
    }
    
    override public func updateStickerSettings(forceStopAnimations: Bool) {
        self.forceStopAnimations = forceStopAnimations
        self.updateVisibility()
    }
    
    private func updateVisibility() {
        guard let item = self.item else {
            return
        }
        
        let effectiveMediaVisibility = self.visibility
        
        var isPlaying = true
        if !item.controllerInteraction.canReadHistory {
            isPlaying = false
        }
        
        if self.forceStopAnimations {
            isPlaying = false
        }
        
        if !isPlaying {
            self.removeEffectAnimations()
        }
        
        var effectiveVisibility = self.visibility
        if !isPlaying {
            effectiveVisibility = .none
        }
        
        for contentNode in self.contentNodes {
            if contentNode is ChatMessageMediaBubbleContentNode || contentNode is ChatMessageGiftBubbleContentNode || contentNode is ChatMessageWebpageBubbleContentNode || contentNode is ChatMessageInvoiceBubbleContentNode || contentNode is ChatMessageGameBubbleContentNode || contentNode is ChatMessageInstantVideoBubbleContentNode {
                contentNode.visibility = mapVisibility(effectiveMediaVisibility, boundsSize: self.bounds.size, insets: self.insets, to: contentNode)
            } else {
                contentNode.visibility = mapVisibility(effectiveVisibility, boundsSize: self.bounds.size, insets: self.insets, to: contentNode)
            }
        }
        
        if case let .visible(_, subRect) = self.visibility {
            if subRect.minY > 32.0 {
                isPlaying = false
            }
        } else {
            isPlaying = false
        }
        
        if let threadInfoNode = self.threadInfoNode {
            threadInfoNode.visibility = effectiveVisibility != .none
        }
        
        if let replyInfoNode = self.replyInfoNode {
            replyInfoNode.visibility = effectiveVisibility != .none
        }
        
        if let unlockButtonNode = self.unlockButtonNode {
            unlockButtonNode.visibility = effectiveVisibility != .none
        }
        
        if isPlaying {
            var alreadySeen = true
            if item.message.flags.contains(.Incoming) {
                if let unreadRange = item.controllerInteraction.unreadMessageRange[UnreadMessageRangeKey(peerId: item.message.id.peerId, namespace: item.message.id.namespace)] {
                    if unreadRange.contains(item.message.id.id) {
                        if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                            alreadySeen = false
                        }
                    }
                }
            } else {
                if self.didChangeFromPendingToSent {
                    if !item.controllerInteraction.seenOneTimeAnimatedMedia.contains(item.message.id) {
                        alreadySeen = false
                    }
                }
            }
            
            if !alreadySeen {
                item.controllerInteraction.seenOneTimeAnimatedMedia.insert(item.message.id)
                
                self.playMessageEffect(force: false)
            }
        }
    }
    
    override public func messageEffectTargetView() -> UIView? {
        for contentNode in self.contentNodes {
            if let result = contentNode.messageEffectTargetView() {
                return result
            }
        }
        if let mosaicStatusNode = self.mosaicStatusNode, let result = mosaicStatusNode.messageEffectTargetView() {
            return result
        }
        
        return nil
    }
}

private func generateNameNavigateButtonImage() -> UIImage {
    return generateImage(CGSize(width: 26.0, height: 26.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor(white: 1.0, alpha: 0.1).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        let arrowRect = CGSize(width: 4.0, height: 8.0).centered(in: CGRect(origin: CGPoint(), size: size)).offsetBy(dx: 1.0, dy: 0.0)
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()
        context.move(to: arrowRect.origin)
        context.addLine(to: CGPoint(x: arrowRect.maxX, y: arrowRect.midY))
        context.addLine(to: CGPoint(x: arrowRect.minX, y: arrowRect.maxY))
        context.strokePath()
        
    })!.withRenderingMode(.alwaysTemplate)
}

public final class NameNavigateButton: HighlightableButton {
    private static let sharedImage: UIImage = generateNameNavigateButtonImage()
    
    private let backgroundView: UIImageView
    public var action: (() -> Void)?
    
    override public init(frame: CGRect) {
        self.backgroundView = UIImageView(image: NameNavigateButton.sharedImage)
        
        super.init(frame: frame)
        
        self.addSubview(self.backgroundView)
        
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func pressed() {
        self.action?()
    }
    
    public func update(size: CGSize, color: UIColor) {
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundView.tintColor = color
    }
}
