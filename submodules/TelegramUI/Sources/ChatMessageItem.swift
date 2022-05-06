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

public enum ChatMessageItemContent: Sequence {
    case message(message: Message, read: Bool, selection: ChatHistoryMessageSelection, attributes: ChatMessageEntryAttributes, location: MessageHistoryEntryLocation?)
    case group(messages: [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes, MessageHistoryEntryLocation?)])
    
    func effectivelyIncoming(_ accountPeerId: PeerId, associatedData: ChatMessageItemAssociatedData? = nil) -> Bool {
        if let subject = associatedData?.subject, case .forwardedMessages = subject {
            return false
        }
        switch self {
            case let .message(message, _, _, _, _):
                return message.effectivelyIncoming(accountPeerId)
            case let .group(messages):
                return messages[0].0.effectivelyIncoming(accountPeerId)
        }
    }
    
    var index: MessageIndex {
        switch self {
            case let .message(message, _, _, _, _):
                return message.index
            case let .group(messages):
                return messages[0].0.index
        }
    }
    
    var firstMessage: Message {
        switch self {
            case let .message(message, _, _, _, _):
                return message
            case let .group(messages):
                return messages[0].0
        }
    }
    
    var firstMessageAttributes: ChatMessageEntryAttributes {
        switch self {
            case let .message(_, _, _, attributes, _):
                return attributes
            case let .group(messages):
                return messages[0].3
        }
    }
    
    public func makeIterator() -> AnyIterator<(Message, ChatMessageEntryAttributes)> {
        var index = 0
        return AnyIterator { () -> (Message, ChatMessageEntryAttributes)? in
            switch self {
                case let .message(message, _, _, attributes, _):
                    if index == 0 {
                        index += 1
                        return (message, attributes)
                    } else {
                        index += 1
                        return nil
                    }
                case let .group(messages):
                    if index < messages.count {
                        let currentIndex = index
                        index += 1
                        return (messages[currentIndex].0, messages[currentIndex].3)
                    } else {
                        return nil
                    }
            }
        }
    }
}

private func mediaMergeableStyle(_ media: Media) -> ChatMessageMerge {
    if let file = media as? TelegramMediaFile {
        for attribute in file.attributes {
            switch attribute {
                case .Sticker:
                    return .semanticallyMerged
                case let .Video(_, _, flags):
                    if flags.contains(.instantRoundVideo) {
                        return .semanticallyMerged
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
    for attribute in rhs.attributes {
        if let attribute = attribute as? SourceReferenceMessageAttribute {
            rhsEffectiveAuthor = rhs.peers[attribute.messageId.peerId]
            break
        }
    }
    
    var sameAuthor = false
    if lhsEffectiveAuthor?.id == rhsEffectiveAuthor?.id && lhs.effectivelyIncoming(accountPeerId) == rhs.effectivelyIncoming(accountPeerId) {
        sameAuthor = true
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
    
    if abs(lhsEffectiveTimestamp - rhsEffectiveTimestamp) < Int32(10 * 60) && sameAuthor {
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
                    upperStyle = ChatMessageMerge.semanticallyMerged.rawValue
                }
                break
            }
        }
        
        let style = min(upperStyle, lowerStyle)
        return ChatMessageMerge(rawValue: style)!
    }
    
    return .none
}

func chatItemsHaveCommonDateHeader(_ lhs: ListViewItem, _ rhs: ListViewItem?)  -> Bool{
    let lhsHeader: ChatMessageDateHeader?
    let rhsHeader: ChatMessageDateHeader?
    if let lhs = lhs as? ChatMessageItem {
        lhsHeader = lhs.dateHeader
    } else if let _ = lhs as? ChatHoleItem {
        lhsHeader = nil
    } else if let lhs = lhs as? ChatUnreadItem {
        lhsHeader = lhs.header
    } else if let lhs = lhs as? ChatReplyCountItem {
        lhsHeader = lhs.header
    } else {
        lhsHeader = nil
    }
    if let rhs = rhs {
        if let rhs = rhs as? ChatMessageItem {
            rhsHeader = rhs.dateHeader
        } else if let _ = rhs as? ChatHoleItem {
            //rhsHeader = rhs.header
            rhsHeader = nil
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

public enum ChatMessageItemAdditionalContent {
    case eventLogPreviousMessage(Message)
    case eventLogPreviousDescription(Message)
    case eventLogPreviousLink(Message)
}

enum ChatMessageMerge: Int32 {
    case none = 0
    case fullyMerged = 1
    case semanticallyMerged = 2
    
    var merged: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
}

public final class ChatMessageItem: ListViewItem, CustomStringConvertible {
    let presentationData: ChatPresentationData
    let context: AccountContext
    let chatLocation: ChatLocation
    let associatedData: ChatMessageItemAssociatedData
    let controllerInteraction: ChatControllerInteraction
    let content: ChatMessageItemContent
    let disableDate: Bool
    let effectiveAuthorId: PeerId?
    let additionalContent: ChatMessageItemAdditionalContent?
    
    let dateHeader: ChatMessageDateHeader
    let avatarHeader: ChatMessageAvatarHeader?

    let headers: [ListViewItemHeader]
    
    var message: Message {
        switch self.content {
            case let .message(message, _, _, _, _):
                return message
            case let .group(messages):
                return messages[0].0
        }
    }
    
    var read: Bool {
        switch self.content {
            case let .message(_, read, _, _, _):
                return read
            case let .group(messages):
                return messages[0].1
        }
    }
    
    public init(presentationData: ChatPresentationData, context: AccountContext, chatLocation: ChatLocation, associatedData: ChatMessageItemAssociatedData, controllerInteraction: ChatControllerInteraction, content: ChatMessageItemContent, disableDate: Bool = false, additionalContent: ChatMessageItemAdditionalContent? = nil) {
        self.presentationData = presentationData
        self.context = context
        self.chatLocation = chatLocation
        self.associatedData = associatedData
        self.controllerInteraction = controllerInteraction
        self.content = content
        self.disableDate = disableDate
        self.additionalContent = additionalContent
        
        var avatarHeader: ChatMessageAvatarHeader?
        let incoming = content.effectivelyIncoming(self.context.account.peerId)
        
        var effectiveAuthor: Peer?
        let displayAuthorInfo: Bool
        
        let messagePeerId: PeerId = chatLocation.peerId ?? content.firstMessage.id.peerId
        
        do {
            let peerId = messagePeerId
            if peerId.isRepliesOrSavedMessages(accountPeerId: context.account.peerId) {
                if let forwardInfo = content.firstMessage.forwardInfo {
                    effectiveAuthor = forwardInfo.author
                    if effectiveAuthor == nil, let authorSignature = forwardInfo.authorSignature  {
                        effectiveAuthor = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: UserInfoFlags())
                    }
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
            }
        }
        
        self.effectiveAuthorId = effectiveAuthor?.id
        
        var isScheduledMessages = false
        if case .scheduledMessages = associatedData.subject {
            isScheduledMessages = true
        }
        
        self.dateHeader = ChatMessageDateHeader(timestamp: content.index.timestamp, scheduled: isScheduledMessages, presentationData: presentationData, context: context, action: { timestamp, alreadyThere in
            var calendar = NSCalendar.current
            calendar.timeZone = TimeZone(abbreviation: "UTC")!
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let components = calendar.dateComponents([.year, .month, .day], from: date)

            if let date = calendar.date(from: components) {
                controllerInteraction.navigateToFirstDateMessage(Int32(date.timeIntervalSince1970), alreadyThere)
            }
        })
        
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
            if !hasActionMedia && !isBroadcastChannel {
                if let effectiveAuthor = effectiveAuthor {
                    avatarHeader = ChatMessageAvatarHeader(timestamp: content.index.timestamp, peerId: effectiveAuthor.id, peer: effectiveAuthor, messageReference: MessageReference(message), message: message, presentationData: presentationData, context: context, controllerInteraction: controllerInteraction)
                }
            }
        }
        self.avatarHeader = avatarHeader
        
        var headers: [ListViewItemHeader] = [self.dateHeader]
        if case .forwardedMessages = associatedData.subject {
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
                        case let .Video(_, _, flags):
                            if flags.contains(.instantRoundVideo) {
                                viewClassName = ChatMessageInstantVideoItemNode.self
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
            let node = (viewClassName as! ChatMessageItemView.Type).init()
            node.setupItem(self, synchronousLoad: synchronousLoads)
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom, dateAtBottom) = self.mergedWithItems(top: previousItem, bottom: nextItem)
            let (layout, apply) = nodeLayout(self, params, top, bottom, dateAtBottom && !self.disableDate)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            node.safeInsets = UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset)
            
            node.updateSelectionState(animated: false)
            node.updateHighlightedState(animated: false)
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None, ListViewItemApply(isOnScreen: false), synchronousLoads) })
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
    
    final func mergedWithItems(top: ListViewItem?, bottom: ListViewItem?) -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: Bool) {
        var mergedTop: ChatMessageMerge = .none
        var mergedBottom: ChatMessageMerge = .none
        var dateAtBottom = false
        if let top = top as? ChatMessageItem {
            if top.dateHeader.id != self.dateHeader.id {
                mergedBottom = .none
            } else {
                mergedBottom = messagesShouldBeMerged(accountPeerId: self.context.account.peerId, message, top.message)
            }
        }
        if let bottom = bottom as? ChatMessageItem {
            if bottom.dateHeader.id != self.dateHeader.id {
                mergedTop = .none
                dateAtBottom = true
            } else {
                mergedTop = messagesShouldBeMerged(accountPeerId: self.context.account.peerId, bottom.message, message)
            }
        } else if let bottom = bottom as? ChatUnreadItem {
            if bottom.header.id != self.dateHeader.id {
                dateAtBottom = true
            }
        } else if let bottom = bottom as? ChatReplyCountItem {
            if bottom.header.id != self.dateHeader.id {
                dateAtBottom = true
            }
        } else if let _ = bottom as? ChatHoleItem {
            dateAtBottom = true
        } else {
            dateAtBottom = true
        }
        
        return (mergedTop, mergedBottom, dateAtBottom)
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatMessageItemView {
                nodeValue.setupItem(self, synchronousLoad: false)
                
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom, dateAtBottom) = self.mergedWithItems(top: previousItem, bottom: nextItem)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom, dateAtBottom && !self.disableDate)
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
