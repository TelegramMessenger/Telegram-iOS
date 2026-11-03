import Foundation
import UIKit
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
    case message(message: EngineRawMessage, read: Bool, selection: ChatHistoryMessageSelection, attributes: ChatMessageEntryAttributes, location: EngineMessageHistoryEntryLocation?)
    case group(messages: [(EngineRawMessage, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes, EngineMessageHistoryEntryLocation?)])

    public func effectivelyIncoming(_ accountPeerId: EnginePeer.Id, associatedData: ChatMessageItemAssociatedData? = nil) -> Bool {
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
    
    public var index: EngineMessage.Index {
        switch self {
            case let .message(message, _, _, _, _):
                return message.index
            case let .group(messages):
                return messages[0].0.index
        }
    }
    
    public var firstMessage: EngineRawMessage {
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
    
    public func makeIterator() -> AnyIterator<(EngineRawMessage, ChatMessageEntryAttributes)> {
        var index = 0
        return AnyIterator { () -> (EngineRawMessage, ChatMessageEntryAttributes)? in
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
    case eventLogPreviousMessage(EngineRawMessage)
    case eventLogPreviousDescription(EngineRawMessage)
    case eventLogPreviousLink(EngineRawMessage)
    case eventLogGroupedMessages([EngineRawMessage], Bool)
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

/// An item that publishes floating headers — a date separator, a gutter avatar.
///
/// `ListViewImpl` reads headers off the NODE (`ListViewItemNode.headers()`), which is enough when a
/// node exists by the time headers matter. `CoreListChatHistoryBackend` needs them from the ITEM:
/// CoreList computes attachment runs over the item collection, before any row view is built.
///
/// Every item BETWEEN messages must publish its headers, not just message items. An item that
/// publishes no key breaks the run, so an unread separator sitting mid-day would split that day into
/// two runs and float two pills for one date.
public protocol ChatHistoryItemWithHeaders {
    var headers: [ListViewItemHeader] { get }
}

public protocol ChatMessageItem: ListViewItem, ChatHistoryItemWithHeaders {
    var presentationData: ChatPresentationData { get }
    var context: AccountContext { get }
    var chatLocation: ChatLocation { get }
    var associatedData: ChatMessageItemAssociatedData { get }
    var controllerInteraction: ChatControllerInteraction { get }
    var content: ChatMessageItemContent { get }
    var disableDate: Bool { get }
    var effectiveAuthorId: EnginePeer.Id? { get }
    var additionalContent: ChatMessageItemAdditionalContent? { get }

    var message: EngineRawMessage { get }
    var read: Bool { get }
    var unsent: Bool { get }
    var sending: Bool { get }
    var failed: Bool { get }
    
    func merged(with neighbors: ChatHistoryItemNeighbors, isRotated: Bool) -> (top: ChatMessageMerge, bottom: ChatMessageMerge, dateAtBottom: ChatMessageHeaderSpec)
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
