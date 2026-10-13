import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import Emoji
import PersistentStringHash
import ChatControllerInteraction
import ChatHistoryEntry
import ChatMessageItem
import ChatMessageItemCommon
import ChatMessageItemView
import ChatMessageStickerItemNode
import ChatMessageAnimatedStickerItemNode
import ChatMessageBubbleItemNode

public final class ChatMessageItemImpl: ChatMessageItem, CustomStringConvertible {
    public let presentationData: ChatPresentationData
    public let context: AccountContext
    public let chatLocation: ChatLocation
    public let associatedData: ChatMessageItemAssociatedData
    public let controllerInteraction: ChatControllerInteraction
    public let content: ChatMessageItemContent
    public let disableDate: Bool
    public let effectiveAuthorId: EnginePeer.Id?
    public let additionalContent: ChatMessageItemAdditionalContent?
    
    let dateHeader: ChatMessageDateHeader
    let topicHeader: ChatMessageDateHeader?
    let avatarHeader: ChatMessageAvatarHeader?

    public let headers: [ListViewItemHeader]

    /// Computed, not stored: evaluated only when an adjacent item is laid out or diffed, and it
    /// costs the same media/attribute walk the merge computation already did per layout. Items are
    /// created for every entry in the filtered view, most of which never reach layout, so storing
    /// it would pay that cost for all of them.
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(ChatHistoryItemNeighbor.message(
            dateHeaderId: self.dateHeader.id,
            topicHeaderId: self.topicHeader?.id,
            merge: ChatMessageMergeFingerprint(message: self.message,
                                               accountPeerId: self.context.account.peerId)
        ))
    }

    public var message: EngineRawMessage {
        switch self.content {
            case let .message(message, _, _, _, _):
                return message
            case let .group(messages):
                return messages[0].0
        }
    }
    
    public var read: Bool {
        switch self.content {
            case let .message(_, read, _, _, _):
                return read
            case let .group(messages):
                return messages[0].1
        }
    }
    
    public var unsent: Bool {
        switch self.content {
            case let .message(message, _, _, _, _):
                return message.flags.contains(.Unsent)
            case let .group(messages):
                return messages[0].0.flags.contains(.Unsent)
        }
    }
    
    public var sending: Bool {
        switch self.content {
            case let .message(message, _, _, _, _):
                return message.flags.contains(.Sending)
            case let .group(messages):
                return messages[0].0.flags.contains(.Sending)
        }
    }
    
    public var failed: Bool {
        switch self.content {
        case let .message(message, _, _, _, _):
            return message.flags.contains(.Failed)
        case let .group(messages):
            return messages[0].0.flags.contains(.Failed)
        }
    }
    
    public var pinToEdgeWithInset: Bool {
        switch self.content {
        case let .message(_, _, _, attributes, _):
            return attributes.pinToTop
        case let .group(messages):
            return messages[0].3.pinToTop
        }
    }
    
    public init(presentationData: ChatPresentationData, context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, content: ChatMessageItemContent, disableDate: Bool = false, additionalContent: ChatMessageItemAdditionalContent? = nil) {
        self.presentationData = presentationData
        self.context = context
        self.chatLocation = chatLocation
        self.associatedData = associatedData
        self.controllerInteraction = controllerInteraction
        self.content = content
        self.disableDate = disableDate || !controllerInteraction.chatIsRotated
        self.additionalContent = additionalContent
        
        var avatarHeader: ChatMessageAvatarHeader?
        let incoming = content.effectivelyIncoming(self.context.account.peerId)
        let isEphemeralMessage = Namespaces.Message.allEphemeral.contains(content.firstMessage.id.namespace) || Namespaces.Message.allWelcomeMessages.contains(content.firstMessage.id.namespace)
        let isEphemeralBroadcastMessage: Bool
        if isEphemeralMessage, let channel = content.firstMessage.peers[content.firstMessage.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            isEphemeralBroadcastMessage = true
        } else {
            isEphemeralBroadcastMessage = false
        }
        
        var effectiveAuthor: EngineRawPeer?
        var displayAuthorInfo: Bool
        
        let messagePeerId: EnginePeer.Id = chatLocation.peerId ?? content.firstMessage.id.peerId
        var headerSeparableThreadId: Int64?
        var headerDisplayPeer: ChatMessageDateHeader.HeaderData?
        
        do {
            let peerId = messagePeerId
            if peerId.isRepliesOrSavedMessages(accountPeerId: context.account.peerId) {
                if let forwardInfo = content.firstMessage.forwardInfo {
                    effectiveAuthor = forwardInfo.author
                    if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature  {
                        effectiveAuthor = TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.Empty, id: EnginePeer.Id.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                    }
                }
                if let sourceAuthorInfo = content.firstMessage.sourceAuthorInfo {
                    if let originalAuthor = sourceAuthorInfo.originalAuthor, let peer = content.firstMessage.peers[originalAuthor] {
                        effectiveAuthor = peer
                    } else if let authorSignature = sourceAuthorInfo.originalAuthorName {
                        effectiveAuthor = TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.Empty, id: EnginePeer.Id.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                    }
                }
                if peerId.isVerificationCodes && effectiveAuthor == nil {
                    effectiveAuthor = content.firstMessage.author
                }
                displayAuthorInfo = incoming && effectiveAuthor != nil
            } else {
                effectiveAuthor = content.firstMessage.author
                for attribute in content.firstMessage.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        effectiveAuthor = content.firstMessage.peers[attribute.messageId.peerId]
                        break
                    }
                }
                displayAuthorInfo = incoming && peerId.isGroupOrChannel && effectiveAuthor != nil
                
                if let _ = content.firstMessage.guestChatAttribute {
                    displayAuthorInfo = true
                }
                
                if let chatPeer = content.firstMessage.peers[content.firstMessage.id.peerId], chatPeer.isForumOrMonoForum {
                    if case .replyThread = chatLocation {
                        if chatPeer.isMonoForum && chatLocation.threadId != context.account.peerId.toInt64() {
                            displayAuthorInfo = false
                        }
                    } else {
                        if chatPeer.isMonoForum {
                            if let chatPeer = chatPeer as? TelegramChannel, let linkedMonoforumId = chatPeer.linkedMonoforumId, let mainChannel = content.firstMessage.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                headerSeparableThreadId = content.firstMessage.threadId
                                
                                if let threadId = content.firstMessage.threadId, let peer = content.firstMessage.peers[EnginePeer.Id(threadId)] {
                                    headerDisplayPeer = ChatMessageDateHeader.HeaderData(contents: .peer(EnginePeer(peer)))
                                }
                            }
                        } else if let threadId = content.firstMessage.threadId {
                            if let threadInfo = content.firstMessage.associatedThreadInfo {
                                headerSeparableThreadId = content.firstMessage.threadId
                                headerDisplayPeer = ChatMessageDateHeader.HeaderData(contents: .thread(id: threadId, info: threadInfo))
                            } else if content.firstMessage.threadId == EngineMessage.newTopicThreadId {
                                headerSeparableThreadId = content.firstMessage.threadId
                                headerDisplayPeer = ChatMessageDateHeader.HeaderData(contents: .thread(id: threadId, info: EngineRawMessage.AssociatedThreadInfo(
                                    title: presentationData.strings.Chat_MessageHeaderBotNewThread,
                                    icon: nil,
                                    iconColor: 0,
                                    isClosed: false
                                )))
                            }
                        }
                    }
                }
            }
        }
        
        self.effectiveAuthorId = effectiveAuthor?.id
        
        var isScheduledMessages = false
        if case .scheduledMessages = associatedData.subject {
            isScheduledMessages = true
        }
        
        self.dateHeader = ChatMessageDateHeader(timestamp: content.index.timestamp, separableThreadId: nil, scheduled: isScheduledMessages, displayHeader: nil, presentationData: presentationData, controllerInteraction: controllerInteraction, context: context, action: { timestamp, alreadyThere in
            var calendar = NSCalendar.current
            calendar.timeZone = TimeZone(abbreviation: "UTC")!
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let components = calendar.dateComponents([.year, .month, .day], from: date)

            if let date = calendar.date(from: components) {
                controllerInteraction.navigateToFirstDateMessage(Int32(date.timeIntervalSince1970), alreadyThere)
            }
        })
        
        if let headerSeparableThreadId, let headerDisplayPeer, !(associatedData.subject?.isService ?? false) {
            self.topicHeader = ChatMessageDateHeader(timestamp: content.index.timestamp, separableThreadId: headerSeparableThreadId, scheduled: false, displayHeader: headerDisplayPeer, presentationData: presentationData, controllerInteraction: controllerInteraction, context: context, action: { _, _ in
                controllerInteraction.updateChatLocationThread(headerSeparableThreadId, nil)
            })
        } else {
            self.topicHeader = nil
        }
        
        if displayAuthorInfo {
            let message = content.firstMessage
            var hasActionMedia = false
            for media in message.media {
                if media is TelegramMediaAction {
                    hasActionMedia = true
                    break
                }
            }
            var isBroadcastChannel = false
            if case .peer = chatLocation {
                if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                    isBroadcastChannel = true
                }
            } else if case let .replyThread(replyThreadMessage) = chatLocation, replyThreadMessage.isChannelPost, replyThreadMessage.effectiveTopId == message.id {
                isBroadcastChannel = true
            }
            
            var hasAvatar = false
            if !hasActionMedia && !isEphemeralBroadcastMessage {
                if !isBroadcastChannel {
                    if let channel = message.peers[message.id.peerId] as? TelegramChannel, channel.isMonoForum, chatLocation.threadId != nil {
                    } else {
                        hasAvatar = true
                    }
                } else if let channel = message.peers[message.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info {
                    if info.flags.contains(.messagesShouldHaveProfiles) {
                        hasAvatar = true
                        effectiveAuthor = message.author
                    }
                }
            }
            
            if hasAvatar {
                if let effectiveAuthor = effectiveAuthor {
                    var storyStats: EnginePeerStoryStats?
                    if case .peer(id: context.account.peerId) = chatLocation {
                    } else {
                        switch content {
                        case let .message(_, _, _, attributes, _):
                            storyStats = attributes.authorStoryStats
                        case let .group(messages):
                            storyStats = messages.first?.3.authorStoryStats
                        }
                    }
                    
                    avatarHeader = ChatMessageAvatarHeader(timestamp: content.index.timestamp, peerId: effectiveAuthor.id, peer: effectiveAuthor, messageReference: MessageReference(message), message: message, presentationData: presentationData, context: context, controllerInteraction: controllerInteraction, storyStats: storyStats)
                }
            }
        }
        self.avatarHeader = avatarHeader
        
        var headers: [ListViewItemHeader] = []
        if !self.disableDate {
            headers.append(self.dateHeader)
            if let topicHeader = self.topicHeader {
                headers.append(topicHeader)
            }
        }
        if case .messageOptions = associatedData.subject {
            headers = []
        }
        if !controllerInteraction.chatIsRotated {
            headers = []
        }
        if let avatarHeader = self.avatarHeader {
            headers.append(avatarHeader)
        }
        self.headers = headers
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        var viewClassName: AnyClass = ChatMessageBubbleItemNode.self
        
        loop: for media in self.message.media {
            if let telegramFile = media as? TelegramMediaFile {
                if telegramFile.isVideoSticker {
                    viewClassName = ChatMessageAnimatedStickerItemNode.self
                    break loop
                }
                if telegramFile.isAnimatedSticker, let size = telegramFile.size, size > 0 && size <= 128 * 1024 {
                    if self.message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                        if telegramFile.fileId.namespace == Namespaces.Media.CloudFile {
                            var isValidated = false
                            for attribute in telegramFile.attributes {
                                if case .hintIsValidated = attribute {
                                    isValidated = true
                                    break
                                }
                            }
                            
                            inner: for attribute in telegramFile.attributes {
                                if case let .Sticker(_, packReference, _) = attribute {
                                    if case .name = packReference {
                                        viewClassName = ChatMessageAnimatedStickerItemNode.self
                                    } else if isValidated {
                                        viewClassName = ChatMessageAnimatedStickerItemNode.self
                                    }
                                    break inner
                                }
                            }
                        }
                    } else {
                        viewClassName = ChatMessageAnimatedStickerItemNode.self
                    }
                    break loop
                }
                for attribute in telegramFile.attributes {
                    switch attribute {
                        case .Sticker:
                            if let size = telegramFile.size, size > 0 && size <= 512 * 1024 {
                                viewClassName = ChatMessageStickerItemNode.self
                            }
                            break loop
                        case let .Video(_, _, flags, _, _, _):
                            if flags.contains(.instantRoundVideo) {
                                viewClassName = ChatMessageBubbleItemNode.self
                                break loop
                            }
                        default:
                            break
                    }
                }
            } else if media is TelegramMediaAction {
                viewClassName = ChatMessageBubbleItemNode.self
            } else if media is TelegramMediaExpiredContent {
                viewClassName = ChatMessageBubbleItemNode.self
            } else if media is TelegramMediaDice {
                viewClassName = ChatMessageAnimatedStickerItemNode.self
            }
        }
        
        if viewClassName == ChatMessageBubbleItemNode.self && self.presentationData.largeEmoji && self.message.media.isEmpty && !self.message.attributes.contains(where: { $0 is TypingDraftMessageAttribute }) {
            if case let .message(_, _, _, attributes, _) = self.content {
                switch attributes.contentTypeHint {
                    case .largeEmoji:
                        viewClassName = ChatMessageStickerItemNode.self
                    case .animatedEmoji:
                        viewClassName = ChatMessageAnimatedStickerItemNode.self
                    default:
                        break
                }
            }
        }
        
        let configure = {
            let node = (viewClassName as! ChatMessageItemView.Type).init(rotated: self.controllerInteraction.chatIsRotated)
            node.setupItem(self, synchronousLoad: synchronousLoads)
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom, dateAtBottom) = self.merged(with: ChatHistoryItemNeighbors(neighbors), isRotated: self.controllerInteraction.chatIsRotated)
            
            var disableDate = self.disableDate
            if let subject = self.associatedData.subject, case let .messageOptions(_, _, info) = subject {
                switch info {
                case .reply, .link:
                    disableDate = true
                default:
                    break
                }
            }
            
            let (layout, apply) = nodeLayout(self, params, top, bottom, disableDate ? ChatMessageHeaderSpec(hasDate: false, hasTopic: false) : dateAtBottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            node.safeInsets = UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset)
            
            node.updateSelectionState(animated: false)
            node.updateHighlightedState(animated: false)
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { info in
                        apply(.None, info, synchronousLoads)
                    })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func merged(with neighbors: ChatHistoryItemNeighbors, isRotated: Bool) -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: ChatMessageHeaderSpec) {
        var top = neighbors.previous
        var bottom = neighbors.next
        if !isRotated {
            let previousTop = top
            top = bottom
            bottom = previousTop
        }

        let selfFingerprint = ChatMessageMergeFingerprint(message: self.message,
                                                          accountPeerId: self.context.account.peerId)
        let isWelcomeMessage = Namespaces.Message.allWelcomeMessages.contains(self.message.id.namespace)

        var mergedTop: ChatMessageMerge = .none
        var mergedBottom: ChatMessageMerge = .none
        var dateAtBottom = ChatMessageHeaderSpec(hasDate: false, hasTopic: false)

        if case let .message(topDateHeaderId, _, topMerge) = top {
            if topDateHeaderId != self.dateHeader.id && !isWelcomeMessage {
                mergedBottom = .none
            } else {
                mergedBottom = chatMessageMerge(upper: selfFingerprint, lower: topMerge)
            }
        }

        switch bottom {
        case let .message(bottomDateHeaderId, bottomTopicHeaderId, bottomMerge):
            if bottomDateHeaderId != self.dateHeader.id && !isWelcomeMessage {
                mergedTop = .none
                dateAtBottom.hasDate = true
            }
            if let topicHeader = self.topicHeader, bottomTopicHeaderId != topicHeader.id {
                mergedTop = .none
                dateAtBottom.hasTopic = true
            }

            if !(dateAtBottom.hasDate || dateAtBottom.hasTopic) {
                mergedTop = chatMessageMerge(upper: bottomMerge, lower: selfFingerprint)
            }
        case let .unread(bottomDateHeaderId), let .replyCount(bottomDateHeaderId):
            if bottomDateHeaderId != self.dateHeader.id {
                dateAtBottom.hasDate = true
            }
            if self.topicHeader != nil {
                dateAtBottom.hasTopic = true
            }
        case nil:
            dateAtBottom.hasDate = true
            if self.topicHeader != nil {
                dateAtBottom.hasTopic = true
            }
        }

        return (mergedTop, mergedBottom, dateAtBottom)
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatMessageItemView {
                nodeValue.setupItem(self, synchronousLoad: false)
                
                let nodeLayout = nodeValue.asyncLayout()
                
                let isRotated = self.controllerInteraction.chatIsRotated
                
                async {
                    let (top, bottom, dateAtBottom) = self.merged(with: ChatHistoryItemNeighbors(neighbors), isRotated: isRotated)
                    
                    var disableDate = self.disableDate
                    if let subject = self.associatedData.subject, case let .messageOptions(_, _, info) = subject {
                        switch info {
                        case .reply, .link:
                            disableDate = true
                        default:
                            break
                        }
                    }
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom, disableDate ? ChatMessageHeaderSpec(hasDate: false, hasTopic: false) : dateAtBottom)
                    Queue.mainQueue().async {
                        completion(layout, { info in
                            apply(animation, info, false)
                            if let nodeValue = node() as? ChatMessageItemView {
                                nodeValue.safeInsets = UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset)
                                nodeValue.updateSelectionState(animated: false)
                                nodeValue.updateHighlightedState(animated: false)
                            }
                        })
                    }
                }
            }
        }
    }
    
    public var description: String {
        return "(ChatMessageItem id: \(self.message.id), text: \"\(self.message.text)\")"
    }
}
