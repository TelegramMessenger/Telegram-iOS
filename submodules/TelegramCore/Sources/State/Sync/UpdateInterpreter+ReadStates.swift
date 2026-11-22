import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Read states: inboxes and outboxes, threads, unread marks, read message contents and the feed.
extension UpdateInterpreter {
    mutating func applyReadChannelInbox(_ updateReadChannelInboxData: Api.Update.Cons_updateReadChannelInbox) {
        let (folderId, channelId, maxId, stillUnreadCount, pts) = (updateReadChannelInboxData.folderId, updateReadChannelInboxData.channelId, updateReadChannelInboxData.maxId, updateReadChannelInboxData.stillUnreadCount, updateReadChannelInboxData.pts)
        updatedState.resetIncomingReadState(groupId: PeerGroupId(rawValue: folderId ?? 0), peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, maxIncomingReadId: maxId, count: stillUnreadCount, pts: pts)
    }
    
    mutating func applyReadChannelOutbox(_ updateReadChannelOutboxData: Api.Update.Cons_updateReadChannelOutbox) {
        updatedState.readOutbox(MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(updateReadChannelOutboxData.channelId)), namespace: Namespaces.Message.Cloud, id: updateReadChannelOutboxData.maxId), timestamp: nil)
    }
    
    mutating func applyReadHistoryInbox(_ updateReadHistoryInboxData: Api.Update.Cons_updateReadHistoryInbox) {
        let (folderId, peer, topMsgId, maxId, stillUnreadCount, pts) = (updateReadHistoryInboxData.folderId, updateReadHistoryInboxData.peer, updateReadHistoryInboxData.topMsgId, updateReadHistoryInboxData.maxId, updateReadHistoryInboxData.stillUnreadCount, updateReadHistoryInboxData.pts)
        if let topMsgId {
            updatedState.readThread(peerId: peer.peerId, threadId: Int64(topMsgId), readMaxId: maxId, isIncoming: true, mainChannelMessage: nil)
        } else {
            updatedState.resetIncomingReadState(groupId: PeerGroupId(rawValue: folderId ?? 0), peerId: peer.peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: maxId, count: stillUnreadCount, pts: pts)
        }
    }
    
    mutating func applyReadHistoryOutbox(_ updateReadHistoryOutboxData: Api.Update.Cons_updateReadHistoryOutbox) {
        updatedState.readOutbox(MessageId(peerId: updateReadHistoryOutboxData.peer.peerId, namespace: Namespaces.Message.Cloud, id: updateReadHistoryOutboxData.maxId), timestamp: updatesDate)
    }
    
    mutating func applyReadChannelDiscussionInbox(_ updateReadChannelDiscussionInboxData: Api.Update.Cons_updateReadChannelDiscussionInbox) {
        let (channelId, topMsgId, readMaxId, mainChannelId, mainChannelPost) = (updateReadChannelDiscussionInboxData.channelId, updateReadChannelDiscussionInboxData.topMsgId, updateReadChannelDiscussionInboxData.readMaxId, updateReadChannelDiscussionInboxData.broadcastId, updateReadChannelDiscussionInboxData.broadcastPost)
        var mainChannelMessage: MessageId?
        if let mainChannelId = mainChannelId, let mainChannelPost = mainChannelPost {
            mainChannelMessage = MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(mainChannelId)), namespace: Namespaces.Message.Cloud, id: mainChannelPost)
        }
        updatedState.readThread(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), threadId: Int64(topMsgId), readMaxId: readMaxId, isIncoming: true, mainChannelMessage: mainChannelMessage)
    }
    
    mutating func applyReadChannelDiscussionOutbox(_ updateReadChannelDiscussionOutboxData: Api.Update.Cons_updateReadChannelDiscussionOutbox) {
        let (channelId, topMsgId, readMaxId) = (updateReadChannelDiscussionOutboxData.channelId, updateReadChannelDiscussionOutboxData.topMsgId, updateReadChannelDiscussionOutboxData.readMaxId)
        updatedState.readThread(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), threadId: Int64(topMsgId), readMaxId: readMaxId, isIncoming: false, mainChannelMessage: nil)
    }
    
    mutating func applyReadMonoForumInbox(_ updateReadMonoForumInboxData: Api.Update.Cons_updateReadMonoForumInbox) {
        let (channelId, savedPeerId, readMaxId) = (updateReadMonoForumInboxData.channelId, updateReadMonoForumInboxData.savedPeerId, updateReadMonoForumInboxData.readMaxId)
        updatedState.readThread(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), threadId: savedPeerId.peerId.toInt64(), readMaxId: readMaxId, isIncoming: true, mainChannelMessage: nil)
    }
    
    mutating func applyReadMonoForumOutbox(_ updateReadMonoForumOutboxData: Api.Update.Cons_updateReadMonoForumOutbox) {
        let (channelId, savedPeerId, readMaxId) = (updateReadMonoForumOutboxData.channelId, updateReadMonoForumOutboxData.savedPeerId, updateReadMonoForumOutboxData.readMaxId)
        updatedState.readThread(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), threadId: savedPeerId.peerId.toInt64(), readMaxId: readMaxId, isIncoming: false, mainChannelMessage: nil)
    }
    
    mutating func applyDialogUnreadMark(_ updateDialogUnreadMarkData: Api.Update.Cons_updateDialogUnreadMark) {
        let (flags, peer, savedPeerId) = (updateDialogUnreadMarkData.flags, updateDialogUnreadMarkData.peer, updateDialogUnreadMarkData.savedPeerId)
        switch peer {
        case let .dialogPeer(dialogPeerData):
            let peer = dialogPeerData.peer
            let peerId = peer.peerId
            if let savedPeerId {
                updatedState.updatePeerChatUnreadMark(peerId, threadId: savedPeerId.peerId.toInt64(), namespace: Namespaces.Message.Cloud, value: (flags & (1 << 0)) != 0)
                let _ = savedPeerId
            } else {
                updatedState.updatePeerChatUnreadMark(peerId, threadId: nil, namespace: Namespaces.Message.Cloud, value: (flags & (1 << 0)) != 0)
            }
        case .dialogPeerCommunity:
            break
        case .dialogPeerFolder:
            break
        }
    }
    
    mutating func applyEncryptedMessagesRead(_ updateEncryptedMessagesReadData: Api.Update.Cons_updateEncryptedMessagesRead) {
        let (chatId, maxDate, date) = (updateEncryptedMessagesReadData.chatId, updateEncryptedMessagesReadData.maxDate, updateEncryptedMessagesReadData.date)
        updatedState.readSecretOutbox(peerId: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(chatId))), timestamp: maxDate, actionTimestamp: date)
    }
    
    mutating func applyReadMessagesContents(_ updateReadMessagesContentsData: Api.Update.Cons_updateReadMessagesContents) {
        updatedState.addReadMessagesContents((nil, nil, updateReadMessagesContentsData.messages), date: updateReadMessagesContentsData.date)
    }
    
    mutating func applyChannelReadMessagesContents(_ updateChannelReadMessagesContentsData: Api.Update.Cons_updateChannelReadMessagesContents) {
        let (channelId, topMsgId, savedPeerId, messages) = (updateChannelReadMessagesContentsData.channelId, updateChannelReadMessagesContentsData.topMsgId, updateChannelReadMessagesContentsData.savedPeerId, updateChannelReadMessagesContentsData.messages)
        var threadId: Int64?
        if let savedPeerId {
            threadId = savedPeerId.peerId.toInt64()
        } else if let topMsgId {
            threadId = Int64(topMsgId)
        }
        updatedState.addReadMessagesContents((PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), threadId, messages), date: nil)
    }

#if TELEGRAM_NEWS_FEED_API
    mutating func applyReadFeed(_ updateReadFeedData: Api.Update.Cons_updateReadFeed) {
        updatedState.updateReadFeed(filterId: updateReadFeedData.filterId, maxPosition: EngineFeedPosition(apiPosition: updateReadFeedData.maxPosition))
    }
#endif
}
