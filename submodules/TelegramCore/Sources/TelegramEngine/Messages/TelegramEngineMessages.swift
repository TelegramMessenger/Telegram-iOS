import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Messages {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func clearCloudDraftsInteractively() -> Signal<Void, NoError> {
        	return _internal_clearCloudDraftsInteractively(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId)
        }

        public func applyMaxReadIndexInteractively(index: MessageIndex) -> Signal<Void, NoError> {
            return _internal_applyMaxReadIndexInteractively(postbox: self.account.postbox, stateManager: self.account.stateManager, index: index)
        }

        public func sendScheduledMessageNowInteractively(messageId: MessageId) -> Signal<Never, NoError> {
            return _internal_sendScheduledMessageNowInteractively(postbox: self.account.postbox, messageId: messageId)
        }

        public func requestMessageActionCallbackPasswordCheck(messageId: MessageId, isGame: Bool, data: MemoryBuffer?) -> Signal<Never, MessageActionCallbackError> {
            return _internal_requestMessageActionCallbackPasswordCheck(account: self.account, messageId: messageId, isGame: isGame, data: data)
        }

        public func requestMessageActionCallback(messageId: MessageId, isGame: Bool, password: String?, data: MemoryBuffer?) -> Signal<MessageActionCallbackResult, MessageActionCallbackError> {
            return _internal_requestMessageActionCallback(account: self.account, messageId: messageId, isGame: isGame, password: password, data: data)
        }

        public func requestMessageActionUrlAuth(subject: MessageActionUrlSubject) -> Signal<MessageActionUrlAuthResult, NoError> {
            _internal_requestMessageActionUrlAuth(account: self.account, subject: subject)
        }

        public func acceptMessageActionUrlAuth(subject: MessageActionUrlSubject, allowWriteAccess: Bool) -> Signal<MessageActionUrlAuthResult, NoError> {
            return _internal_acceptMessageActionUrlAuth(account: self.account, subject: subject, allowWriteAccess: allowWriteAccess)
        }

        public func searchMessages(location: SearchMessagesLocation, query: String, state: SearchMessagesState?, limit: Int32 = 100) -> Signal<(SearchMessagesResult, SearchMessagesState), NoError> {
            return _internal_searchMessages(account: self.account, location: location, query: query, state: state, limit: limit)
        }

        public func downloadMessage(messageId: MessageId) -> Signal<Message?, NoError> {
            return _internal_downloadMessage(postbox: self.account.postbox, network: self.account.network, messageId: messageId)
        }

        public func searchMessageIdByTimestamp(peerId: PeerId, threadId: Int64?, timestamp: Int32) -> Signal<MessageId?, NoError> {
            return _internal_searchMessageIdByTimestamp(account: self.account, peerId: peerId, threadId: threadId, timestamp: timestamp)
        }

        public func deleteMessages(transaction: Transaction, ids: [MessageId], deleteMedia: Bool = true, manualAddMessageThreadStatsDifference: ((MessageId, Int, Int) -> Void)? = nil) {
            return _internal_deleteMessages(transaction: transaction, mediaBox: self.account.postbox.mediaBox, ids: ids, deleteMedia: deleteMedia, manualAddMessageThreadStatsDifference: manualAddMessageThreadStatsDifference)
        }

        public func deleteAllMessagesWithAuthor(transaction: Transaction, peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) {
            return _internal_deleteAllMessagesWithAuthor(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, authorId: authorId, namespace: namespace)
        }

        public func deleteAllMessagesWithForwardAuthor(transaction: Transaction, peerId: PeerId, forwardAuthorId: PeerId, namespace: MessageId.Namespace) {
            return _internal_deleteAllMessagesWithForwardAuthor(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, forwardAuthorId: forwardAuthorId, namespace: namespace)
        }

        public func clearCallHistory(forEveryone: Bool) -> Signal<Never, ClearCallHistoryError> {
            return _internal_clearCallHistory(account: self.account, forEveryone: forEveryone)
        }

        public func deleteMessagesInteractively(messageIds: [MessageId], type: InteractiveMessagesDeletionType, deleteAllInGroup: Bool = false) -> Signal<Void, NoError> {
            return _internal_deleteMessagesInteractively(account: self.account, messageIds: messageIds, type: type, deleteAllInGroup: deleteAllInGroup)
        }

        public func clearHistoryInteractively(peerId: PeerId, type: InteractiveHistoryClearingType) -> Signal<Void, NoError> {
            return _internal_clearHistoryInteractively(postbox: self.account.postbox, peerId: peerId, type: type)
        }

        public func clearAuthorHistory(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
            return _internal_clearAuthorHistory(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func requestEditMessage(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute? = nil, disableUrlPreview: Bool = false, scheduleTime: Int32? = nil) -> Signal<RequestEditMessageResult, RequestEditMessageError> {
            return _internal_requestEditMessage(account: self.account, messageId: messageId, text: text, media: media, entities: entities, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime)
        }

        public func requestEditLiveLocation(messageId: MessageId, stop: Bool, coordinate: (latitude: Double, longitude: Double, accuracyRadius: Int32?)?, heading: Int32?, proximityNotificationRadius: Int32?) -> Signal<Void, NoError> {
            return _internal_requestEditLiveLocation(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, messageId: messageId, stop: stop, coordinate: coordinate, heading: heading, proximityNotificationRadius: proximityNotificationRadius)
        }

        public func addSecretChatMessageScreenshot(peerId: PeerId) -> Signal<Never, NoError> {
            return _internal_addSecretChatMessageScreenshot(account: self.account, peerId: peerId)
            |> ignoreValues
        }

        public func forwardGameWithScore(messageId: MessageId, to peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_forwardGameWithScore(account: self.account, messageId: messageId, to: peerId)
        }

        public func requestUpdatePinnedMessage(peerId: PeerId, update: PinnedMessageUpdate) -> Signal<Void, UpdatePinnedMessageError> {
            return _internal_requestUpdatePinnedMessage(account: self.account, peerId: peerId, update: update)
        }

        public func requestUnpinAllMessages(peerId: PeerId) -> Signal<Never, UpdatePinnedMessageError> {
            return _internal_requestUnpinAllMessages(account: self.account, peerId: peerId)
        }

        public func fetchChannelReplyThreadMessage(messageId: MessageId, atMessageId: MessageId?) -> Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError> {
            return _internal_fetchChannelReplyThreadMessage(account: self.account, messageId: messageId, atMessageId: atMessageId)
        }

        public func requestStartBot(botPeerId: PeerId, payload: String?) -> Signal<Void, NoError> {
            return _internal_requestStartBot(account: self.account, botPeerId: botPeerId, payload: payload)
        }

        public func requestStartBotInGroup(botPeerId: PeerId, groupPeerId: PeerId, payload: String?) -> Signal<StartBotInGroupResult, RequestStartBotInGroupError> {
            return _internal_requestStartBotInGroup(account: self.account, botPeerId: botPeerId, groupPeerId: groupPeerId, payload: payload)
        }

        public func markAllChatsAsRead() -> Signal<Void, NoError> {
            return _internal_markAllChatsAsRead(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager)
        }

        public func getMessagesLoadIfNecessary(_ messageIds: [MessageId], strategy: GetMessagesStrategy = .cloud) -> Signal <[Message], NoError> {
            return _internal_getMessagesLoadIfNecessary(messageIds, postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, strategy: strategy)
        }

        public func markMessageContentAsConsumedInteractively(messageId: MessageId) -> Signal<Void, NoError> {
            return _internal_markMessageContentAsConsumedInteractively(postbox: self.account.postbox, messageId: messageId)
        }

        public func installInteractiveReadMessagesAction(peerId: PeerId) -> Disposable {
            return _internal_installInteractiveReadMessagesAction(postbox: self.account.postbox, stateManager: self.account.stateManager, peerId: peerId)
        }

        public func requestMessageSelectPollOption(messageId: MessageId, opaqueIdentifiers: [Data]) -> Signal<TelegramMediaPoll?, RequestMessageSelectPollOptionError> {
            return _internal_requestMessageSelectPollOption(account: self.account, messageId: messageId, opaqueIdentifiers: opaqueIdentifiers)
        }

        public func requestClosePoll(messageId: MessageId) -> Signal<Void, NoError> {
            return _internal_requestClosePoll(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, messageId: messageId)
        }

        public func pollResults(messageId: MessageId, poll: TelegramMediaPoll) -> PollResultsContext {
            return PollResultsContext(account: self.account, messageId: messageId, poll: poll)
        }

        public func earliestUnseenPersonalMentionMessage(peerId: PeerId) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
            return _internal_earliestUnseenPersonalMentionMessage(account: self.account, peerId: peerId)
        }

        public func exportMessageLink(peerId: PeerId, messageId: MessageId, isThread: Bool = false) -> Signal<String?, NoError> {
            return _internal_exportMessageLink(account: self.account, peerId: peerId, messageId: messageId, isThread: isThread)
        }

        public func enqueueOutgoingMessageWithChatContextResult(to peerId: PeerId, results: ChatContextResultCollection, result: ChatContextResult, replyToMessageId: MessageId? = nil, hideVia: Bool = false, silentPosting: Bool = false, scheduleTime: Int32? = nil, correlationId: Int64? = nil) -> Bool {
            return _internal_enqueueOutgoingMessageWithChatContextResult(account: self.account, to: peerId, results: results, result: result, replyToMessageId: replyToMessageId, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime, correlationId: correlationId)
        }

        public func requestChatContextResults(botId: PeerId, peerId: PeerId, query: String, location: Signal<(Double, Double)?, NoError> = .single(nil), offset: String, incompleteResults: Bool = false, staleCachedResults: Bool = false) -> Signal<RequestChatContextResultsResult?, RequestChatContextResultsError> {
            return _internal_requestChatContextResults(account: self.account, botId: botId, peerId: peerId, query: query, location: location, offset: offset, incompleteResults: incompleteResults, staleCachedResults: staleCachedResults)
        }

        public func removeRecentlyUsedHashtag(string: String) -> Signal<Void, NoError> {
            return _internal_removeRecentlyUsedHashtag(postbox: self.account.postbox, string: string)
        }

        public func recentlyUsedHashtags() -> Signal<[String], NoError> {
            return _internal_recentlyUsedHashtags(postbox: self.account.postbox)
        }

        public func topPeerActiveLiveLocationMessages(peerId: PeerId) -> Signal<(Peer?, [Message]), NoError> {
            return _internal_topPeerActiveLiveLocationMessages(viewTracker: self.account.viewTracker, accountPeerId: self.account.peerId, peerId: peerId)
        }

        public func chatList(group: EngineChatList.Group, count: Int) -> Signal<EngineChatList, NoError> {
            return self.account.postbox.tailChatListView(groupId: group._asGroup(), count: count, summaryComponents: ChatListEntrySummaryComponents())
            |> map { view -> EngineChatList in
                return EngineChatList(view.0)
            }
        }

        public func callList(scope: EngineCallList.Scope, index: EngineMessage.Index, itemCount: Int) -> Signal<EngineCallList, NoError> {
            return self.account.viewTracker.callListView(
                type: scope == .all ? .all : .missed,
                index: index,
                count: itemCount
            )
            |> map { view -> EngineCallList in
                return EngineCallList(
                    items: view.entries.map { entry -> EngineCallList.Item in
                        switch entry {
                        case let .message(message, group):
                            return .message(message: EngineMessage(message), group: group.map(EngineMessage.init))
                        case let .hole(index):
                            return .hole(index)
                        }
                    },
                    hasEarlier: view.earlier != nil,
                    hasLater: view.later != nil
                )
            }
        }

        public func adMessages(peerId: PeerId) -> AdMessagesHistoryContext {
            return AdMessagesHistoryContext(account: self.account, peerId: peerId)
        }

        public func messageReadStats(id: MessageId) -> Signal<MessageReadStats?, NoError> {
            return _internal_messageReadStats(account: self.account, id: id)
        }
    }
}
