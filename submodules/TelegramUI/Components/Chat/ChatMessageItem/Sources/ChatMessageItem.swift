import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import ChatHistoryEntry
import ChatControllerInteraction
import TelegramPresentationData
import ChatMessageItemCommon

public enum ChatMessageItemContent: Sequence {
    case message(message: Message, read: Bool, selection: ChatHistoryMessageSelection, attributes: ChatMessageEntryAttributes, location: MessageHistoryEntryLocation?)
    case group(messages: [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes, MessageHistoryEntryLocation?)])
    
    public func effectivelyIncoming(_ accountPeerId: PeerId, associatedData: ChatMessageItemAssociatedData? = nil) -> Bool {
        if let subject = associatedData?.subject, case let .messageOptions(_, _, info) = subject {
            if case .forward = info {
                return false
            } else if case let .link(link) = info {
                return link.isCentered
            }
        }
        switch self {
            case let .message(message, _, _, _, _):
                return message.effectivelyIncoming(accountPeerId)
            case let .group(messages):
                return messages[0].0.effectivelyIncoming(accountPeerId)
        }
    }
    
    public var index: MessageIndex {
        switch self {
            case let .message(message, _, _, _, _):
                return message.index
            case let .group(messages):
                return messages[0].0.index
        }
    }
    
    public var firstMessage: Message {
        switch self {
            case let .message(message, _, _, _, _):
                return message
            case let .group(messages):
                return messages[0].0
        }
    }
    
    public var firstMessageAttributes: ChatMessageEntryAttributes {
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

public enum ChatMessageItemAdditionalContent {
    case eventLogPreviousMessage(Message)
    case eventLogPreviousDescription(Message)
    case eventLogPreviousLink(Message)
    case eventLogGroupedMessages([Message], Bool)
}

public enum ChatMessageMerge: Int32 {
    case none = 0
    case fullyMerged = 1
    case semanticallyMerged = 2
    
    public var merged: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
}

public struct ChatMessageHeaderSpec: Equatable {
    public var hasDate: Bool
    public var hasTopic: Bool
    
    public init(hasDate: Bool, hasTopic: Bool) {
        self.hasDate = hasDate
        self.hasTopic = hasTopic
    }
}

public protocol ChatMessageDateHeaderNode: ListViewItemHeaderNode {
    func updateItem(hasDate: Bool, hasPeer: Bool)
}

public protocol ChatMessageAvatarHeaderNode: ListViewItemHeaderNode {
    func updateSelectionState(animated: Bool)
    func updateAvatarIsHidden(isHidden: Bool, transition: ContainedViewLayoutTransition)
}

public protocol ChatMessageItem: ListViewItem {
    var presentationData: ChatPresentationData { get }
    var context: AccountContext { get }
    var chatLocation: ChatLocation { get }
    var associatedData: ChatMessageItemAssociatedData { get }
    var controllerInteraction: ChatControllerInteraction { get }
    var content: ChatMessageItemContent { get }
    var disableDate: Bool { get }
    var effectiveAuthorId: PeerId? { get }
    var additionalContent: ChatMessageItemAdditionalContent? { get }

    var headers: [ListViewItemHeader] { get }
    
    var message: Message { get }
    var read: Bool { get }
    var unsent: Bool { get }
    var sending: Bool { get }
    var failed: Bool { get }
    
    func mergedWithItems(top: ListViewItem?, bottom: ListViewItem?, isRotated: Bool) -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: ChatMessageHeaderSpec)
}

public func hasCommentButton(item: ChatMessageItem) -> Bool {
    let firstMessage = item.content.firstMessage
    
    var hasDiscussion = false
    if let channel = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case let .broadcast(info) = channel.info, info.flags.contains(.hasDiscussionGroup) {
        hasDiscussion = true
    }
    if case let .replyThread(replyThreadMessage) = item.chatLocation, replyThreadMessage.effectiveTopId == firstMessage.id {
        hasDiscussion = false
    }

    if firstMessage.adAttribute != nil {
        hasDiscussion = false
    }
    
    if hasDiscussion {
        var canComment = false
        if case .pinnedMessages = item.associatedData.subject {
            canComment = false
        } else if firstMessage.id.namespace == Namespaces.Message.Local {
            canComment = true
        } else {
            for attribute in firstMessage.attributes {
                if let attribute = attribute as? ReplyThreadMessageAttribute, let commentsPeerId = attribute.commentsPeerId {
                    switch item.associatedData.channelDiscussionGroup {
                    case .unknown:
                        canComment = true
                    case let .known(groupId):
                        canComment = groupId == commentsPeerId
                    }
                    break
                }
            }
        }
        
        if canComment {
            return true
        }
    } else if firstMessage.id.peerId.isReplies {
        return true
    }
    return false
}
