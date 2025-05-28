import Foundation
import UIKit
import Postbox
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
import ChatMessageItemView
import ChatMessageStickerItemNode
import ChatMessageAnimatedStickerItemNode
import ChatMessageBubbleItemNode

private func mediaMergeableStyle(_ media: Media) -> ChatMessageMerge {
    if let story = media as? TelegramMediaStory, story.isMention {
        return .none
    }
    if let file = media as? TelegramMediaFile {
        for attribute in file.attributes {
            switch attribute {
                case .Sticker:
                    return .semanticallyMerged
                case let .Video(_, _, flags, _, _, _):
                    if flags.contains(.instantRoundVideo) {
                        return .none
                    }
                default:
                    break
            }
        }
        return .fullyMerged
    }
    if let _ = media as? TelegramMediaAction {
        return .none
    }
    if let _ = media as? TelegramMediaExpiredContent {
        return .none
    }
    
    return .fullyMerged
}

private func messagesShouldBeMerged(accountPeerId: PeerId, _ lhs: Message, _ rhs: Message) -> ChatMessageMerge {
    var lhsEffectiveAuthor: Peer? = lhs.author
    var rhsEffectiveAuthor: Peer? = rhs.author
    for attribute in lhs.attributes {
        if let attribute = attribute as? SourceReferenceMessageAttribute {
            lhsEffectiveAuthor = lhs.peers[attribute.messageId.peerId]
            break
        }
    }
    let lhsSourceAuthorInfo = lhs.sourceAuthorInfo
    if let sourceAuthorInfo = lhsSourceAuthorInfo {
        if let originalAuthor = sourceAuthorInfo.originalAuthor {
            lhsEffectiveAuthor = lhs.peers[originalAuthor]
        }
    }
    for attribute in rhs.attributes {
        if let attribute = attribute as? SourceReferenceMessageAttribute {
            rhsEffectiveAuthor = rhs.peers[attribute.messageId.peerId]
            break
        }
    }
    let rhsSourceAuthorInfo = rhs.sourceAuthorInfo
    if let sourceAuthorInfo = rhsSourceAuthorInfo {
        if let originalAuthor = sourceAuthorInfo.originalAuthor {
            rhsEffectiveAuthor = rhs.peers[originalAuthor]
        }
    }
    
    if let channel = lhs.peers[lhs.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info {
        if info.flags.contains(.messagesShouldHaveProfiles) {
            lhsEffectiveAuthor = lhs.author
            rhsEffectiveAuthor = rhs.author
        }
    }
    
    var sameChat = true
    if lhs.id.peerId != rhs.id.peerId {
        sameChat = false
    }
    
    var isPaid = false
    if let _ = lhs.paidStarsAttribute, let _ = rhs.paidStarsAttribute {
        isPaid = true
    }
    
    let sameThread = true
    /*if let lhsPeer = lhs.peers[lhs.id.peerId], let rhsPeer = rhs.peers[rhs.id.peerId], arePeersEqual(lhsPeer, rhsPeer), let channel = lhsPeer as? TelegramChannel, channel.isForumOrMonoForum, lhs.threadId != rhs.threadId {
        sameThread = false
    }*/
        
    var sameAuthor = false
    if lhsEffectiveAuthor?.id == rhsEffectiveAuthor?.id && lhs.effectivelyIncoming(accountPeerId) == rhs.effectivelyIncoming(accountPeerId) {
        sameAuthor = true
    }
    
    if let lhsSourceAuthorInfo, let rhsSourceAuthorInfo {
        if lhsSourceAuthorInfo.originalAuthor != rhsSourceAuthorInfo.originalAuthor {
            sameAuthor = false
        } else if lhsSourceAuthorInfo.originalAuthorName != rhsSourceAuthorInfo.originalAuthorName {
            sameAuthor = false
        }
    } else if (lhsSourceAuthorInfo == nil) != (rhsSourceAuthorInfo == nil) {
        sameAuthor = false
    }
    
    var lhsEffectiveTimestamp = lhs.timestamp
    var rhsEffectiveTimestamp = rhs.timestamp
    
    if let lhsForwardInfo = lhs.forwardInfo, lhsForwardInfo.flags.contains(.isImported), let rhsForwardInfo = rhs.forwardInfo, rhsForwardInfo.flags.contains(.isImported) {
        lhsEffectiveTimestamp = lhsForwardInfo.date
        rhsEffectiveTimestamp = rhsForwardInfo.date
        
        if (lhsForwardInfo.author?.id != nil) == (rhsForwardInfo.author?.id != nil) && (lhsForwardInfo.authorSignature != nil) == (rhsForwardInfo.authorSignature != nil) {
            if let lhsAuthorId = lhsForwardInfo.author?.id, let rhsAuthorId = rhsForwardInfo.author?.id {
                sameAuthor = lhsAuthorId == rhsAuthorId
            } else if let lhsAuthorSignature = lhsForwardInfo.authorSignature, let rhsAuthorSignature = rhsForwardInfo.authorSignature {
                sameAuthor = lhsAuthorSignature == rhsAuthorSignature
            }
        } else {
            sameAuthor = false
        }
    }
    
    if lhs.id.peerId.isRepliesOrSavedMessages(accountPeerId: accountPeerId) {
        if let forwardInfo = lhs.forwardInfo {
            lhsEffectiveAuthor = forwardInfo.author
        }
    }
    if rhs.id.peerId.isRepliesOrSavedMessages(accountPeerId: accountPeerId) {
        if let forwardInfo = rhs.forwardInfo {
            rhsEffectiveAuthor = forwardInfo.author
        }
    }
    
    var isNonMergeablePaid = isPaid
    if isNonMergeablePaid {
        if let channel = lhs.peers[lhs.id.peerId] as? TelegramChannel, channel.flags.contains(.isMonoforum) {
            isNonMergeablePaid = false
        }
    }
    
    if abs(lhsEffectiveTimestamp - rhsEffectiveTimestamp) < Int32(10 * 60) && sameChat && sameAuthor && sameThread && !isNonMergeablePaid {
        if let channel = lhs.peers[lhs.id.peerId] as? TelegramChannel, case .group = channel.info, lhsEffectiveAuthor?.id == channel.id, !lhs.effectivelyIncoming(accountPeerId) {
            return .none
        }
        
        var upperStyle: Int32 = ChatMessageMerge.fullyMerged.rawValue
        var lowerStyle: Int32 = ChatMessageMerge.fullyMerged.rawValue
        for media in lhs.media {
            let style = mediaMergeableStyle(media).rawValue
            if style < upperStyle {
                upperStyle = style
            }
        }
        for media in rhs.media {
            let style = mediaMergeableStyle(media).rawValue
            if style < lowerStyle {
                lowerStyle = style
            }
        }
        for attribute in lhs.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if attribute.flags.contains(.inline) && !attribute.rows.isEmpty {
                    upperStyle = ChatMessageMerge.none.rawValue
                }
                break
            }
        }
        
        let style = min(upperStyle, lowerStyle)
        return ChatMessageMerge(rawValue: style)!
    }
    
    return .none
}

public func chatItemsHaveCommonDateHeader(_ lhs: ListViewItem, _ rhs: ListViewItem?)  -> Bool{
    let lhsHeader: ChatMessageDateHeader?
    let rhsHeader: ChatMessageDateHeader?
    if let lhs = lhs as? ChatMessageItemImpl {
        lhsHeader = lhs.dateHeader
    } else if let lhs = lhs as? ChatUnreadItem {
        lhsHeader = lhs.header
    } else if let lhs = lhs as? ChatReplyCountItem {
        lhsHeader = lhs.header
    } else {
        lhsHeader = nil
    }
    if let rhs = rhs {
        if let rhs = rhs as? ChatMessageItemImpl {
            rhsHeader = rhs.dateHeader
        } else if let rhs = rhs as? ChatUnreadItem {
            rhsHeader = rhs.header
        } else if let rhs = rhs as? ChatReplyCountItem {
            rhsHeader = rhs.header
        } else {
            rhsHeader = nil
        }
    } else {
        rhsHeader = nil
    }
    if let lhsHeader = lhsHeader, let rhsHeader = rhsHeader {
        return lhsHeader.id == rhsHeader.id
    } else {
        return false
    }
}

public final class ChatMessageItemImpl: ChatMessageItem, CustomStringConvertible {
    public let presentationData: ChatPresentationData
    public let context: AccountContext
    public let chatLocation: ChatLocation
    public let associatedData: ChatMessageItemAssociatedData
    public let controllerInteraction: ChatControllerInteraction
    public let content: ChatMessageItemContent
    public let disableDate: Bool
    public let effectiveAuthorId: PeerId?
    public let additionalContent: ChatMessageItemAdditionalContent?
    
    let dateHeader: ChatMessageDateHeader
    let topicHeader: ChatMessageDateHeader?
    let avatarHeader: ChatMessageAvatarHeader?

    public let headers: [ListViewItemHeader]
    
    public var message: Message {
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
        
        var effectiveAuthor: Peer?
        var displayAuthorInfo: Bool
        
        let messagePeerId: PeerId = chatLocation.peerId ?? content.firstMessage.id.peerId
        var headerSeparableThreadId: Int64?
        var headerDisplayPeer: ChatMessageDateHeader.HeaderData?
        
        do {
            let peerId = messagePeerId
            if peerId.isRepliesOrSavedMessages(accountPeerId: context.account.peerId) {
                if let forwardInfo = content.firstMessage.forwardInfo {
                    effectiveAuthor = forwardInfo.author
                    if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature  {
                        effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
                    }
                }
                if let sourceAuthorInfo = content.firstMessage.sourceAuthorInfo {
                    if let originalAuthor = sourceAuthorInfo.originalAuthor, let peer = content.firstMessage.peers[originalAuthor] {
                        effectiveAuthor = peer
                    } else if let authorSignature = sourceAuthorInfo.originalAuthorName {
                        effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
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
                
                if let channel = content.firstMessage.peers[content.firstMessage.id.peerId] as? TelegramChannel, channel.isForumOrMonoForum {
                    if case .replyThread = chatLocation {
                        if channel.isMonoForum && chatLocation.threadId != context.account.peerId.toInt64() {
                            displayAuthorInfo = false
                        }
                    } else {
                        if channel.isMonoForum {
                            if let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = content.firstMessage.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.sendSomething) {
                                headerSeparableThreadId = content.firstMessage.threadId
                                
                                if let threadId = content.firstMessage.threadId, let peer = content.firstMessage.peers[EnginePeer.Id(threadId)] {
                                    headerDisplayPeer = ChatMessageDateHeader.HeaderData(contents: .peer(EnginePeer(peer)))
                                }
                            }
                        } else if let threadId = content.firstMessage.threadId {
                            if let threadInfo = content.firstMessage.associatedThreadInfo {
                                headerSeparableThreadId = content.firstMessage.threadId
                                headerDisplayPeer = ChatMessageDateHeader.HeaderData(contents: .thread(id: threadId, info: threadInfo))
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
        
        if let headerSeparableThreadId, let headerDisplayPeer {
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
            if !hasActionMedia {
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
                    var storyStats: PeerStoryStats?
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
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
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
        
        if viewClassName == ChatMessageBubbleItemNode.self && self.presentationData.largeEmoji && self.message.media.isEmpty {
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
            let (top, bottom, dateAtBottom) = self.mergedWithItems(top: previousItem, bottom: nextItem, isRotated:  self.controllerInteraction.chatIsRotated)
            
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
                        info.setIsOffscreen()
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
    
    public func mergedWithItems(top: ListViewItem?, bottom: ListViewItem?, isRotated: Bool) -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: ChatMessageHeaderSpec) {
        var top = top
        var bottom = bottom
        if !isRotated {
            let previousTop = top
            top = bottom
            bottom = previousTop
        }
        
        var mergedTop: ChatMessageMerge = .none
        var mergedBottom: ChatMessageMerge = .none
        var dateAtBottom = ChatMessageHeaderSpec(hasDate: false, hasTopic: false)
        if let top = top as? ChatMessageItemImpl {
            if top.dateHeader.id != self.dateHeader.id {
                mergedBottom = .none
            } else {
                mergedBottom = messagesShouldBeMerged(accountPeerId: self.context.account.peerId, message, top.message)
            }
        }
        if let bottom = bottom as? ChatMessageItemImpl {
            if bottom.dateHeader.id != self.dateHeader.id {
                mergedTop = .none
                dateAtBottom.hasDate = true
            }
            if let topicHeader = self.topicHeader, bottom.topicHeader?.id != topicHeader.id {
                mergedTop = .none
                dateAtBottom.hasTopic = true
            }
            
            if !(dateAtBottom.hasDate || dateAtBottom.hasTopic) {
                mergedTop = messagesShouldBeMerged(accountPeerId: self.context.account.peerId, bottom.message, message)
            }
        } else if let bottom = bottom as? ChatUnreadItem {
            if bottom.header.id != self.dateHeader.id {
                dateAtBottom.hasDate = true
            }
            if self.topicHeader != nil {
                dateAtBottom.hasTopic = true
            }
        } else if let bottom = bottom as? ChatReplyCountItem {
            if bottom.header.id != self.dateHeader.id {
                dateAtBottom.hasDate = true
            }
            if self.topicHeader != nil {
                dateAtBottom.hasTopic = true
            }
        } else {
            dateAtBottom.hasDate = true
            if self.topicHeader != nil {
                dateAtBottom.hasTopic = true
            }
        }
        
        return (mergedTop, mergedBottom, dateAtBottom)
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatMessageItemView {
                nodeValue.setupItem(self, synchronousLoad: false)
                
                let nodeLayout = nodeValue.asyncLayout()
                
                let isRotated = self.controllerInteraction.chatIsRotated
                
                async {
                    let (top, bottom, dateAtBottom) = self.mergedWithItems(top: previousItem, bottom: nextItem, isRotated: isRotated)
                    
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
