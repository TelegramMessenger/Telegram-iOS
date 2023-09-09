import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum EngineOutgoingMessageContent {
    case text(String, [MessageTextEntity])
    case file(FileMediaReference)
    case contextResult(ChatContextResultCollection, ChatContextResult)
}

public final class StoryPreloadInfo {
    public enum Priority: Comparable {
        case top(position: Int)
        case next(position: Int)
    }
    
    public let peer: PeerReference
    public let storyId: Int32
    public let media: EngineMedia
    public let priority: Priority
    
    public init(
        peer: PeerReference,
        storyId: Int32,
        media: EngineMedia,
        priority: Priority
    ) {
        self.peer = peer
        self.storyId = storyId
        self.media = media
        self.priority = priority
    }
}

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

        public func deleteMessages(transaction: Transaction, ids: [MessageId]) {
            return _internal_deleteMessages(transaction: transaction, mediaBox: self.account.postbox.mediaBox, ids: ids, deleteMedia: true, manualAddMessageThreadStatsDifference: nil)
        }

        public func deleteAllMessagesWithAuthor(peerId: PeerId, authorId: PeerId, namespace: MessageId.Namespace) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_deleteAllMessagesWithAuthor(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, authorId: authorId, namespace: namespace)
            }
            |> ignoreValues
        }

        public func deleteAllMessagesWithForwardAuthor(peerId: EnginePeer.Id, forwardAuthorId: EnginePeer.Id, namespace: MessageId.Namespace) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_deleteAllMessagesWithForwardAuthor(transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, forwardAuthorId: forwardAuthorId, namespace: namespace)
            }
            |> ignoreValues
        }

        public func clearCallHistory(forEveryone: Bool) -> Signal<Never, ClearCallHistoryError> {
            return _internal_clearCallHistory(account: self.account, forEveryone: forEveryone)
        }

        public func deleteMessagesInteractively(messageIds: [MessageId], type: InteractiveMessagesDeletionType, deleteAllInGroup: Bool = false) -> Signal<Void, NoError> {
            return _internal_deleteMessagesInteractively(account: self.account, messageIds: messageIds, type: type, deleteAllInGroup: deleteAllInGroup)
        }

        public func clearHistoryInteractively(peerId: PeerId, threadId: Int64?, type: InteractiveHistoryClearingType) -> Signal<Void, NoError> {
            return _internal_clearHistoryInteractively(postbox: self.account.postbox, peerId: peerId, threadId: threadId, type: type)
        }

        public func clearAuthorHistory(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
            return _internal_clearAuthorHistory(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func requestEditMessage(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, inlineStickers: [MediaId: Media], disableUrlPreview: Bool = false, scheduleTime: Int32? = nil) -> Signal<RequestEditMessageResult, RequestEditMessageError> {
            return _internal_requestEditMessage(account: self.account, messageId: messageId, text: text, media: media, entities: entities, inlineStickers: inlineStickers, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime)
        }

        public func requestEditLiveLocation(messageId: MessageId, stop: Bool, coordinate: (latitude: Double, longitude: Double, accuracyRadius: Int32?)?, heading: Int32?, proximityNotificationRadius: Int32?) -> Signal<Void, NoError> {
            return _internal_requestEditLiveLocation(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, messageId: messageId, stop: stop, coordinate: coordinate, heading: heading, proximityNotificationRadius: proximityNotificationRadius)
        }

        public func addSecretChatMessageScreenshot(peerId: PeerId) -> Signal<Never, NoError> {
            return _internal_addSecretChatMessageScreenshot(account: self.account, peerId: peerId)
            |> ignoreValues
        }

        public func forwardGameWithScore(messageId: MessageId, to peerId: PeerId, threadId: Int64?, as senderPeerId: PeerId?) -> Signal<Void, NoError> {
            return _internal_forwardGameWithScore(account: self.account, messageId: messageId, to: peerId, threadId: threadId, as: senderPeerId)
        }

        public func requestUpdatePinnedMessage(peerId: PeerId, update: PinnedMessageUpdate) -> Signal<Void, UpdatePinnedMessageError> {
            return _internal_requestUpdatePinnedMessage(account: self.account, peerId: peerId, update: update)
        }

        public func requestUnpinAllMessages(peerId: PeerId, threadId: Int64?) -> Signal<Never, UpdatePinnedMessageError> {
            return _internal_requestUnpinAllMessages(account: self.account, peerId: peerId, threadId: threadId)
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

        public func getMessagesLoadIfNecessary(_ messageIds: [MessageId], strategy: GetMessagesStrategy = .cloud(skipLocal: false)) -> Signal <[Message], NoError> {
            return _internal_getMessagesLoadIfNecessary(messageIds, postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, strategy: strategy)
        }

        public func markMessageContentAsConsumedInteractively(messageId: MessageId) -> Signal<Void, NoError> {
            return _internal_markMessageContentAsConsumedInteractively(postbox: self.account.postbox, messageId: messageId)
        }

        public func installInteractiveReadMessagesAction(peerId: PeerId) -> Disposable {
            return _internal_installInteractiveReadMessagesAction(postbox: self.account.postbox, stateManager: self.account.stateManager, peerId: peerId)
        }
        
        public func installInteractiveReadReactionsAction(peerId: PeerId, getVisibleRange: @escaping () -> VisibleMessageRange?, didReadReactionsInMessages: @escaping ([MessageId: [ReactionsMessageAttribute.RecentPeer]]) -> Void) -> Disposable {
            return _internal_installInteractiveReadReactionsAction(postbox: self.account.postbox, stateManager: self.account.stateManager, peerId: peerId, getVisibleRange: getVisibleRange, didReadReactionsInMessages: didReadReactionsInMessages)
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

        public func earliestUnseenPersonalMentionMessage(peerId: PeerId, threadId: Int64?) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
            let account = self.account
            return _internal_earliestUnseenPersonalMentionMessage(account: self.account, peerId: peerId, threadId: threadId)
            |> mapToSignal { result -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
                switch result {
                case .loading:
                    return .single(result)
                case let .result(messageId):
                    if messageId == nil {
                        let _ = clearPeerUnseenPersonalMessagesInteractively(account: account, peerId: peerId, threadId: threadId).start()
                    }
                    return .single(result)
                }
            }
        }
        
        public func earliestUnseenPersonalReactionMessage(peerId: PeerId, threadId: Int64?) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
            let account = self.account
            return _internal_earliestUnseenPersonalReactionMessage(account: self.account, peerId: peerId, threadId: threadId)
            |> mapToSignal { result -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
                switch result {
                case .loading:
                    return .single(result)
                case let .result(messageId):
                    if messageId == nil {
                        let _ = clearPeerUnseenReactionsInteractively(account: account, peerId: peerId, threadId: threadId).start()
                    }
                    return .single(result)
                }
            }
        }

        public func exportMessageLink(peerId: PeerId, messageId: MessageId, isThread: Bool = false) -> Signal<String?, NoError> {
            return _internal_exportMessageLink(account: self.account, peerId: peerId, messageId: messageId, isThread: isThread)
        }
        
        public func enqueueOutgoingMessage(
            to peerId: EnginePeer.Id,
            replyTo replyToMessageId: EngineMessage.Id?,
            storyId: StoryId? = nil,
            content: EngineOutgoingMessageContent,
            silentPosting: Bool = false,
            scheduleTime: Int32? = nil
        ) -> Signal<[MessageId?], NoError> {
            var message: EnqueueMessage?
            if case let .contextResult(results, result) = content {
                message = self.outgoingMessageWithChatContextResult(to: peerId, threadId: nil, botId: results.botId, result: result, replyToMessageId: replyToMessageId, replyToStoryId: storyId, hideVia: true, silentPosting: silentPosting, scheduleTime: scheduleTime, correlationId: nil)
            } else {
                var attributes: [MessageAttribute] = []
                if silentPosting {
                    attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                }
                if let scheduleTime = scheduleTime {
                     attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime))
                }
                
                var text: String = ""
                var mediaReference: AnyMediaReference?
                switch content {
                case let .text(textValue, entities):
                    if !entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                    }
                    text = textValue
                case let .file(fileReference):
                    mediaReference = fileReference.abstract
                default:
                    fatalError()
                }
                message = .message(
                    text: text,
                    attributes: attributes,
                    inlineStickers: [:],
                    mediaReference: mediaReference,
                    replyToMessageId: replyToMessageId,
                    replyToStoryId: storyId,
                    localGroupingKey: nil,
                    correlationId: nil,
                    bubbleUpEmojiOrStickersets: []
                )
            }
            
            
            
            guard let message = message else {
                return .complete()
            }
         
            return enqueueMessages(
                account: self.account,
                peerId: peerId,
                messages: [message]
            )
        }

        public func enqueueOutgoingMessageWithChatContextResult(to peerId: PeerId, threadId: Int64?, botId: PeerId, result: ChatContextResult, replyToMessageId: MessageId? = nil, replyToStoryId: StoryId? = nil, hideVia: Bool = false, silentPosting: Bool = false, scheduleTime: Int32? = nil, correlationId: Int64? = nil) -> Bool {
            return _internal_enqueueOutgoingMessageWithChatContextResult(account: self.account, to: peerId, threadId: threadId, botId: botId, result: result, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime, correlationId: correlationId)
        }
        
        public func outgoingMessageWithChatContextResult(to peerId: PeerId, threadId: Int64?, botId: PeerId, result: ChatContextResult, replyToMessageId: MessageId?, replyToStoryId: StoryId?, hideVia: Bool, silentPosting: Bool, scheduleTime: Int32?, correlationId: Int64?) -> EnqueueMessage? {
            return _internal_outgoingMessageWithChatContextResult(to: peerId, threadId: threadId, botId: botId, result: result, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime, correlationId: correlationId)
        }
        
        public func setMessageReactions(
            id: EngineMessage.Id,
            reactions: [UpdateMessageReaction]
        ) {
            let _ = updateMessageReactionsInteractively(
                account: self.account,
                messageId: id,
                reactions: reactions,
                isLarge: false,
                storeAsRecentlyUsed: false
            ).start()
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

        public func requestCancelLiveLocation(ids: [MessageId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for id in ids {
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        var updatedMedia = currentMessage.media
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        for i in 0 ..< updatedMedia.count {
                            if let media = updatedMedia[i] as? TelegramMediaMap, let _ = media.liveBroadcastingTimeout {
                                updatedMedia[i] = TelegramMediaMap(latitude: media.latitude, longitude: media.longitude, heading: media.heading, accuracyRadius: media.accuracyRadius, geoPlace: media.geoPlace, venue: media.venue, liveBroadcastingTimeout: max(0, timestamp - currentMessage.timestamp - 1), liveProximityNotificationRadius: nil)
                            }
                        }
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: updatedMedia))
                    })
                }
            }
            |> ignoreValues
        }

        public func activeLiveLocationMessages() -> Signal<[EngineMessage], NoError> {
            let viewKey: PostboxViewKey = .localMessageTag(.OutgoingLiveLocation)
            return self.account.postbox.combinedView(keys: [viewKey])
            |> map { view in
                if let view = view.views[viewKey] as? LocalMessageTagsView {
                    return view.messages.values.map(EngineMessage.init)
                } else {
                    return []
                }
            }
        }

        public func sparseMessageList(peerId: EnginePeer.Id, threadId: Int64?, tag: EngineMessage.Tags) -> SparseMessageList {
            return SparseMessageList(account: self.account, peerId: peerId, threadId: threadId, messageTag: tag)
        }

        public func sparseMessageCalendar(peerId: EnginePeer.Id, threadId: Int64?, tag: EngineMessage.Tags) -> SparseMessageCalendar {
            return SparseMessageCalendar(account: self.account, peerId: peerId, threadId: threadId, messageTag: tag)
        }

        /*public func sparseMessageScrollingContext(peerId: EnginePeer.Id) -> SparseMessageScrollingContext {
            return SparseMessageScrollingContext(account: self.account, peerId: peerId)
        }*/

        public func refreshMessageTagStats(peerId: EnginePeer.Id, threadId: Int64?, tags: [EngineMessage.Tags]) -> Signal<Never, NoError> {
            let account = self.account
            return self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<Never, NoError> in
                guard let inputPeer = inputPeer else {
                    return .complete()
                }
                var signals: [Signal<(count: Int32?, topId: Int32?), NoError>] = []
                for tag in tags {
                    guard let filter = messageFilterForTagMask(tag) else {
                        signals.append(.single((nil, nil)))
                        continue
                    }
                    
                    var flags: Int32 = 0
                    var topMsgId: Int32?
                    if let threadId = threadId {
                        flags |= (1 << 1)
                        topMsgId = Int32(clamping: threadId)
                    }
                    
                    signals.append(self.account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: "", fromId: nil, topMsgId: topMsgId, filter: filter, minDate: 0, maxDate: 0, offsetId: 0, addOffset: 0, limit: 1, maxId: 0, minId: 0, hash: 0))
                    |> map { result -> (count: Int32?, topId: Int32?) in
                        switch result {
                        case let .messagesSlice(_, count, _, _, messages, _, _):
                            return (count, messages.first?.id(namespace: Namespaces.Message.Cloud)?.id)
                        case let .channelMessages(_, _, count, _, messages, _, _, _):
                            return (count, messages.first?.id(namespace: Namespaces.Message.Cloud)?.id)
                        case let .messages(messages, _, _):
                            return (Int32(messages.count), messages.first?.id(namespace: Namespaces.Message.Cloud)?.id)
                        case .messagesNotModified:
                            return (nil, nil)
                        }
                    }
                    |> `catch` { _ -> Signal<(count: Int32?, topId: Int32?), NoError> in
                        return .single((nil, nil))
                    })
                }
                return combineLatest(signals)
                |> mapToSignal { counts -> Signal<Never, NoError> in
                    return account.postbox.transaction { transaction in
                        for i in 0 ..< tags.count {
                            let (count, maxId) = counts[i]
                            if let count = count {
                                transaction.replaceMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: tags[i], namespace: Namespaces.Message.Cloud, count: count, maxId: maxId ?? 1)
                            }
                        }
                    }
                    |> ignoreValues
                }
            }
        }
        
        public func messageReactionList(message: EngineMessage, readStats: MessageReadStats?, reaction: MessageReaction.Reaction?) -> EngineMessageReactionListContext {
            return EngineMessageReactionListContext(account: self.account, message: message, readStats: readStats, reaction: reaction)
        }
        
        public func translate(text: String, toLang: String) -> Signal<String?, TranslationError> {
            return _internal_translate(network: self.account.network, text: text, toLang: toLang)
        }
        
        public func translateMessages(messageIds: [EngineMessage.Id], toLang: String) -> Signal<Void, TranslationError> {
            return _internal_translateMessages(account: self.account, messageIds: messageIds, toLang: toLang)
        }
        
        public func togglePeerMessagesTranslationHidden(peerId: EnginePeer.Id, hidden: Bool) -> Signal<Never, NoError> {
            return _internal_togglePeerMessagesTranslationHidden(account: self.account, peerId: peerId, hidden: hidden)
        }
        
        public func transcribeAudio(messageId: MessageId) -> Signal<EngineAudioTranscriptionResult, NoError> {
            return _internal_transcribeAudio(postbox: self.account.postbox, network: self.account.network, messageId: messageId)
        }
        
        public func storeLocallyTranscribedAudio(messageId: MessageId, text: String, isFinal: Bool, error: AudioTranscriptionMessageAttribute.TranscriptionError?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.updateMessage(messageId, update: { currentMessage in
                    let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                    var attributes = currentMessage.attributes.filter { !($0 is AudioTranscriptionMessageAttribute) }
                    
                    attributes.append(AudioTranscriptionMessageAttribute(id: 0, text: text, isPending: !isFinal, didRate: false, error: error))
                    
                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            }
            |> ignoreValues
        }
        
        public func rateAudioTranscription(messageId: MessageId, id: Int64, isGood: Bool) -> Signal<Never, NoError> {
            return _internal_rateAudioTranscription(postbox: self.account.postbox, network: self.account.network, messageId: messageId, id: id, isGood: isGood)
        }
        
        public func requestWebView(peerId: PeerId, botId: PeerId, url: String?, payload: String?, themeParams: [String: Any]?, fromMenu: Bool, replyToMessageId: MessageId?, threadId: Int64?) -> Signal<RequestWebViewResult, RequestWebViewError> {
            return _internal_requestWebView(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, peerId: peerId, botId: botId, url: url, payload: payload, themeParams: themeParams, fromMenu: fromMenu, replyToMessageId: replyToMessageId, threadId: threadId)
        }
        
        public func requestSimpleWebView(botId: PeerId, url: String?, source: RequestSimpleWebViewSource, themeParams: [String: Any]?) -> Signal<String, RequestSimpleWebViewError> {
            return _internal_requestSimpleWebView(postbox: self.account.postbox, network: self.account.network, botId: botId, url: url, source: source, themeParams: themeParams)
        }
        
        public func requestAppWebView(peerId: PeerId, appReference: BotAppReference, payload: String?, themeParams: [String: Any]?, allowWrite: Bool) -> Signal<String, RequestAppWebViewError> {
            return _internal_requestAppWebView(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, peerId: peerId, appReference: appReference, payload: payload, themeParams: themeParams, allowWrite: allowWrite)
        }
                
        public func sendWebViewData(botId: PeerId, buttonText: String, data: String) -> Signal<Never, SendWebViewDataError> {
            return _internal_sendWebViewData(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, botId: botId, buttonText: buttonText, data: data)
        }
        
        public func canBotSendMessages(botId: PeerId) -> Signal<Bool, NoError> {
            return _internal_canBotSendMessages(postbox: self.account.postbox, network: self.account.network, botId: botId)
        }

        public func allowBotSendMessages(botId: PeerId) -> Signal<Never, NoError> {
            return _internal_allowBotSendMessages(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, botId: botId)
        }

        public func invokeBotCustomMethod(botId: PeerId, method: String, params: String) -> Signal<String, InvokeBotCustomMethodError> {
            return _internal_invokeBotCustomMethod(postbox: self.account.postbox, network: self.account.network, botId: botId, method: method, params: params)
        }
                
        public func addBotToAttachMenu(botId: PeerId, allowWrite: Bool) -> Signal<Bool, AddBotToAttachMenuError> {
            return _internal_addBotToAttachMenu(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, botId: botId, allowWrite: allowWrite)
        }
        
        public func removeBotFromAttachMenu(botId: PeerId) -> Signal<Bool, NoError> {
            return _internal_removeBotFromAttachMenu(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, botId: botId)
        }
        
        public func acceptAttachMenuBotDisclaimer(botId: PeerId) -> Signal<Never, NoError> {
            return _internal_acceptAttachMenuBotDisclaimer(postbox: self.account.postbox, botId: botId)
        }
        
        public func getAttachMenuBot(botId: PeerId, cached: Bool = false) -> Signal<AttachMenuBot, GetAttachMenuBotError> {
            return _internal_getAttachMenuBot(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, botId: botId, cached: cached)
        }
        
        public func attachMenuBots() -> Signal<[AttachMenuBot], NoError> {
            return _internal_attachMenuBots(postbox: self.account.postbox)
        }
        
        public func getBotApp(botId: PeerId, shortName: String, cached: Bool = false) -> Signal<BotApp, GetBotAppError> {
            return _internal_getBotApp(account: self.account, reference: .shortName(peerId: botId, shortName: shortName))
        }
        
        public func ensureMessagesAreLocallyAvailable(messages: [EngineMessage]) {
            let _ = self.account.postbox.transaction({ transaction in
                for message in messages {
                    _internal_storeMessageFromSearch(transaction: transaction, message: message._asMessage())
                }
            }).start()
        }
        
        public func findRandomMessage(peerId: EnginePeer.Id, namespace: EngineMessage.Id.Namespace, tag: EngineMessage.Tags, ignoreIds: ([EngineMessage.Id], Set<EngineMessage.Id>)) -> Signal<EngineMessage.Index?, NoError> {
            return self.account.postbox.transaction { transaction -> EngineMessage.Index? in
                return transaction.findRandomMessage(peerId: peerId, namespace: namespace, tag: tag, ignoreIds: ignoreIds)
            }
        }
        
        public func failedMessageGroup(id: EngineMessage.Id) -> Signal<[EngineMessage], NoError> {
            return self.account.postbox.transaction { transaction -> [EngineMessage] in
                return transaction.getMessageFailedGroup(id)?.map(EngineMessage.init) ?? []
            }
        }
        
        public func unreadChatListPeerIds(groupId: EngineChatList.Group, filterPredicate: ChatListFilterPredicate?) -> Signal<[EnginePeer.Id], NoError> {
            return self.account.postbox.transaction { transaction -> [EnginePeer.Id] in
                return transaction.getUnreadChatListPeerIds(groupId: groupId._asGroup(), filterPredicate: filterPredicate, additionalFilter: nil, stopOnFirstMatch: false)
            }
        }
        
        public func markAllChatsAsReadInteractively(items: [(groupId: EngineChatList.Group, filterPredicate: ChatListFilterPredicate?)]) -> Signal<Never, NoError> {
            let account = self.account
            return self.account.postbox.transaction { transaction -> Void in
                for (groupId, filterPredicate) in items {
                    _internal_markAllChatsAsReadInteractively(transaction: transaction, network: self.account.network, viewTracker: account.viewTracker, groupId: groupId._asGroup(), filterPredicate: filterPredicate)
                }
            }
            |> ignoreValues
        }
        
        public func getRelativeUnreadChatListIndex(filtered: Bool, position: EngineChatList.RelativePosition, groupId: EngineChatList.Group) -> Signal<EngineChatList.Item.Index?, NoError> {
            guard let position = position._asPosition() else {
                return .single(nil)
            }
            return self.account.postbox.transaction { transaction -> EngineChatList.Item.Index? in
                return transaction.getRelativeUnreadChatListIndex(filtered: filtered, position: position, groupId: groupId._asGroup()).flatMap(EngineChatList.Item.Index.chatList)
            }
        }
        
        public func togglePeersUnreadMarkInteractively(peerIds: [EnginePeer.Id], setToValue: Bool?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_togglePeerUnreadMarkInteractively(transaction: transaction, network: self.account.network, viewTracker: self.account.viewTracker, peerId: peerId, setToValue: setToValue)
                }
            }
            |> ignoreValues
        }
        
        public func markForumThreadAsRead(peerId: EnginePeer.Id, threadId: Int64) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_markForumThreadAsReadInteractively(transaction: transaction, network: self.account.network, viewTracker: self.account.viewTracker, peerId: peerId, threadId: threadId)
            }
            |> ignoreValues
        }
        
        public func markForumThreadsAsRead(peerId: EnginePeer.Id, threadIds: [Int64]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for threadId in threadIds {
                    _internal_markForumThreadAsReadInteractively(transaction: transaction, network: self.account.network, viewTracker: self.account.viewTracker, peerId: peerId, threadId: threadId)
                }
            }
            |> ignoreValues
        }
        
        public func debugAddHoles() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.addHolesEverywhere(peerNamespaces: [Namespaces.Peer.CloudUser, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudChannel], holeNamespace: Namespaces.Message.Cloud)
            }
            |> ignoreValues
        }
        
        public func debugReindexUnreadCounters() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.reindexUnreadCounters()
            }
            |> ignoreValues
        }
        
        public func keepMessageCountersSyncrhonized(peerId: EnginePeer.Id, threadId: Int64) -> Signal<Never, NoError> {
            return managedSynchronizeMessageHistoryTagSummaries(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, peerId: peerId, threadId: threadId)
            |> ignoreValues
        }
        
        public func getSynchronizeAutosaveItemOperations() -> Signal<[(index: Int32, message: Message, mediaId: MediaId)], NoError> {
            return self.account.postbox.transaction { transaction -> [(index: Int32, message: Message, mediaId: MediaId)] in
                return _internal_getSynchronizeAutosaveItemOperations(transaction: transaction)
            }
        }

        func removeSyncrhonizeAutosaveItemOperations(indices: [Int32]) {
            let _ = (self.account.postbox.transaction { transaction -> Void in
                _internal_removeSyncrhonizeAutosaveItemOperations(transaction: transaction, indices: indices)
            }).start()
        }
        
        public func peerStoriesAreReady(id: EnginePeer.Id, minId: Int32) -> Signal<Bool, NoError> {
            return self.account.postbox.combinedView(keys: [
                PostboxViewKey.storyItems(peerId: id)
            ])
            |> map { views -> Bool in
                guard let view = views.views[PostboxViewKey.storyItems(peerId: id)] as? StoryItemsView else {
                    return false
                }
                return view.items.contains(where: { item in
                    return item.id >= minId
                })
            }
        }
        
        public func storySubscriptions(isHidden: Bool, tempKeepNewlyArchived: Bool = false) -> Signal<EngineStorySubscriptions, NoError> {
            return `deferred` { () -> Signal<EngineStorySubscriptions, NoError> in
                let debugTimerSignal: Signal<Bool, NoError>
#if DEBUG && false
                debugTimerSignal = Signal<Bool, NoError>.single(true)
                |> then(
                    Signal<Bool, NoError>.single(true)
                    |> delay(1.0, queue: .mainQueue())
                    |> then(
                        Signal<Bool, NoError>.single(false)
                        |> delay(1.0, queue: .mainQueue())
                    )
                    |> restart
                )
#else
                debugTimerSignal = .single(true)
#endif
                
                let previousIdList = Atomic<Set<PeerId>>(value: Set())
                
                let subscriptionsKey: PostboxStorySubscriptionsKey = isHidden ? .hidden : .filtered
                
                let basicPeerKey = PostboxViewKey.basicPeer(self.account.peerId)
                let storySubscriptionsKey = PostboxViewKey.storySubscriptions(key: subscriptionsKey)
                return combineLatest(debugTimerSignal |> distinctUntilChanged,
                self.account.postbox.combinedView(keys: [
                    basicPeerKey,
                    storySubscriptionsKey,
                    PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))
                ]))
                |> mapToSignal { debugTimer, views -> Signal<EngineStorySubscriptions, NoError> in
                    guard let basicPeerView = views.views[basicPeerKey] as? BasicPeerView, let accountPeer = basicPeerView.peer else {
                        return .single(EngineStorySubscriptions(accountItem: nil, items: [], hasMoreToken: nil))
                    }
                    guard let storySubscriptionsView = views.views[storySubscriptionsKey] as? StorySubscriptionsView else {
                        return .single(EngineStorySubscriptions(accountItem: nil, items: [], hasMoreToken: nil))
                    }
                    guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))] as? StoryStatesView else {
                        return .single(EngineStorySubscriptions(accountItem: nil, items: [], hasMoreToken: nil))
                    }
                    
                    var additionalDataKeys: [PostboxViewKey] = []
                    
                    additionalDataKeys.append(PostboxViewKey.storyItems(peerId: self.account.peerId))
                    additionalDataKeys.append(PostboxViewKey.storiesState(key: .peer(self.account.peerId)))
                    additionalDataKeys.append(PostboxViewKey.storiesState(key: .local))
                    
                    var subscriptionPeerIds = storySubscriptionsView.peerIds.filter { $0 != self.account.peerId }
                    if !debugTimer {
                        subscriptionPeerIds.removeAll()
                    }
                    
                    if tempKeepNewlyArchived {
                        let updatedList = previousIdList.modify { list in
                            var list = list
                            list.formUnion(subscriptionPeerIds)
                            return list
                        }
                        for id in updatedList {
                            if !subscriptionPeerIds.contains(id) {
                                subscriptionPeerIds.append(id)
                            }
                        }
                    }
                    
                    additionalDataKeys.append(contentsOf: subscriptionPeerIds.map { peerId -> PostboxViewKey in
                        return PostboxViewKey.storyItems(peerId: peerId)
                    })
                    additionalDataKeys.append(contentsOf: subscriptionPeerIds.map { peerId -> PostboxViewKey in
                        return PostboxViewKey.storiesState(key: .peer(peerId))
                    })
                    additionalDataKeys.append(contentsOf: subscriptionPeerIds.map { peerId -> PostboxViewKey in
                        return PostboxViewKey.basicPeer(peerId)
                    })
                    
                    return self.account.postbox.combinedView(keys: additionalDataKeys)
                    |> map { views -> EngineStorySubscriptions in
                        let _ = accountPeer
                        
                        var hasMoreToken: String?
                        if let subscriptionsState = storiesStateView.value?.get(Stories.SubscriptionsState.self) {
                            if subscriptionsState.hasMore {
                                hasMoreToken = subscriptionsState.opaqueState + "_\(subscriptionsState.refreshId)"
                            } else {
                                hasMoreToken = nil
                            }
                        } else {
                            hasMoreToken = ""
                        }
                        
                        var accountPendingItemCount = 0
                        if let view = views.views[PostboxViewKey.storiesState(key: .local)] as? StoryStatesView, let localState = view.value?.get(Stories.LocalState.self) {
                            accountPendingItemCount = localState.items.count
                        }
                        
                        var accountItem: EngineStorySubscriptions.Item = EngineStorySubscriptions.Item(
                            peer: EnginePeer(accountPeer),
                            hasUnseen: false,
                            hasUnseenCloseFriends: false,
                            hasPending: accountPendingItemCount != 0,
                            storyCount: accountPendingItemCount,
                            unseenCount: 0,
                            lastTimestamp: 0
                        )
                        
                        var items: [EngineStorySubscriptions.Item] = []
                        
                        do {
                            let peerId = self.account.peerId
                            
                            if let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView, let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView {
                                if let lastEntry = itemsView.items.last?.value.get(Stories.StoredItem.self) {
                                    let peerState: Stories.PeerState? = stateView.value?.get(Stories.PeerState.self)
                                    var hasUnseen = false
                                    var hasUnseenCloseFriends = false
                                    var unseenCount = 0
                                    if let peerState = peerState {
                                        hasUnseen = peerState.maxReadId < lastEntry.id
                                        
                                        for item in itemsView.items {
                                            if item.id > peerState.maxReadId {
                                                unseenCount += 1
                                            }
                                            
                                            if case let .item(item) = item.value.get(Stories.StoredItem.self) {
                                                if item.id > peerState.maxReadId {
                                                    if item.isCloseFriends {
                                                        hasUnseenCloseFriends = true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    let item = EngineStorySubscriptions.Item(
                                        peer: EnginePeer(accountPeer),
                                        hasUnseen: hasUnseen,
                                        hasUnseenCloseFriends: hasUnseenCloseFriends,
                                        hasPending: accountPendingItemCount != 0,
                                        storyCount: itemsView.items.count + accountPendingItemCount,
                                        unseenCount: unseenCount,
                                        lastTimestamp: lastEntry.timestamp
                                    )
                                    accountItem = item
                                }
                            }
                        }
                        
                        for peerId in subscriptionPeerIds {
                            guard let peerView = views.views[PostboxViewKey.basicPeer(peerId)] as? BasicPeerView else {
                                continue
                            }
                            guard let peer = peerView.peer else {
                                continue
                            }
                            guard let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                                continue
                            }
                            guard let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                                continue
                            }
                            guard let lastEntry = itemsView.items.last?.value.get(Stories.StoredItem.self) else {
                                continue
                            }
                            
                            let peerState: Stories.PeerState? = stateView.value?.get(Stories.PeerState.self)
                            var hasUnseen = false
                            var hasUnseenCloseFriends = false
                            var unseenCount = 0
                            if let peerState = peerState {
                                hasUnseen = peerState.maxReadId < lastEntry.id
                                
                                for item in itemsView.items {
                                    if item.id > peerState.maxReadId {
                                        unseenCount += 1
                                        
                                        if case let .item(item) = item.value.get(Stories.StoredItem.self) {
                                            if item.isCloseFriends {
                                                hasUnseenCloseFriends = true
                                            }
                                        }
                                    }
                                }
                            }
                            
                            let item = EngineStorySubscriptions.Item(
                                peer: EnginePeer(peer),
                                hasUnseen: hasUnseen,
                                hasUnseenCloseFriends: hasUnseenCloseFriends,
                                hasPending: false,
                                storyCount: itemsView.items.count,
                                unseenCount: unseenCount,
                                lastTimestamp: lastEntry.timestamp
                            )
                            
                            if peerId == accountPeer.id {
                                accountItem = item
                            } else {
                                items.append(item)
                            }
                        }
                        
                        items.sort(by: { lhs, rhs in
                            if lhs.hasUnseen != rhs.hasUnseen {
                                if lhs.hasUnseen {
                                    return true
                                } else {
                                    return false
                                }
                            }
                            if lhs.peer.isService != rhs.peer.isService {
                                if lhs.peer.isService {
                                    return true
                                } else {
                                    return false
                                }
                            }
                            if lhs.peer.isPremium != rhs.peer.isPremium {
                                if lhs.peer.isPremium {
                                    return true
                                } else {
                                    return false
                                }
                            }
                            if lhs.lastTimestamp != rhs.lastTimestamp {
                                return lhs.lastTimestamp > rhs.lastTimestamp
                            }
                            return lhs.peer.id < rhs.peer.id
                        })
                        
                        return EngineStorySubscriptions(accountItem: accountItem, items: items, hasMoreToken: hasMoreToken)
                    }
                }
            }
        }
        
        public func preloadStorySubscriptions(isHidden: Bool) -> Signal<[EngineMedia.Id: StoryPreloadInfo], NoError> {
            let basicPeerKey = PostboxViewKey.basicPeer(self.account.peerId)
            let subscriptionsKey: PostboxStorySubscriptionsKey = isHidden ? .hidden : .filtered
            let storySubscriptionsKey = PostboxViewKey.storySubscriptions(key: subscriptionsKey)
            return self.account.postbox.combinedView(keys: [
                basicPeerKey,
                storySubscriptionsKey,
                PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))
            ])
            |> mapToSignal { views -> Signal<[EngineMedia.Id: StoryPreloadInfo], NoError> in
                guard let basicPeerView = views.views[basicPeerKey] as? BasicPeerView, let accountPeer = basicPeerView.peer else {
                    return .single([:])
                }
                guard let storySubscriptionsView = views.views[storySubscriptionsKey] as? StorySubscriptionsView else {
                    return .single([:])
                }
                guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))] as? StoryStatesView else {
                    return .single([:])
                }
                
                var additionalDataKeys: [PostboxViewKey] = []
                additionalDataKeys.append(contentsOf: storySubscriptionsView.peerIds.map { peerId -> PostboxViewKey in
                    return PostboxViewKey.storyItems(peerId: peerId)
                })
                additionalDataKeys.append(contentsOf: storySubscriptionsView.peerIds.map { peerId -> PostboxViewKey in
                    return PostboxViewKey.storiesState(key: .peer(peerId))
                })
                additionalDataKeys.append(contentsOf: storySubscriptionsView.peerIds.map { peerId -> PostboxViewKey in
                    return PostboxViewKey.basicPeer(peerId)
                })
                
                return self.account.postbox.combinedView(keys: additionalDataKeys)
                |> map { views -> [EngineMedia.Id: StoryPreloadInfo] in
                    let _ = accountPeer
                    let _ = storiesStateView
                    
                    var sortedItems: [(peer: Peer, item: Stories.Item, hasUnseen: Bool, lastTimestamp: Int32)] = []
                    
                    for peerId in storySubscriptionsView.peerIds {
                        guard let peerView = views.views[PostboxViewKey.basicPeer(peerId)] as? BasicPeerView else {
                            continue
                        }
                        guard let peer = peerView.peer else {
                            continue
                        }
                        guard let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                            continue
                        }
                        guard let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                            continue
                        }
                        
                        var nextItem: Stories.StoredItem? = itemsView.items.first?.value.get(Stories.StoredItem.self)
                        let lastTimestamp = itemsView.items.last?.value.get(Stories.StoredItem.self)?.timestamp
                        
                        let peerState: Stories.PeerState? = stateView.value?.get(Stories.PeerState.self)
                        var hasUnseen = false
                        if let peerState = peerState {
                            if let item = itemsView.items.first(where: { $0.id > peerState.maxReadId }) {
                                hasUnseen = true
                                nextItem = item.value.get(Stories.StoredItem.self)
                            }
                        }
                        
                        if let nextItem = nextItem, case let .item(item) = nextItem, let lastTimestamp = lastTimestamp {
                            sortedItems.append((peer, item, hasUnseen, lastTimestamp))
                        }
                    }
                    
                    sortedItems.sort(by: { lhs, rhs in
                        if lhs.hasUnseen != rhs.hasUnseen {
                            if lhs.hasUnseen {
                                return true
                            } else {
                                return false
                            }
                        }
                        if EnginePeer(lhs.peer).isService != EnginePeer(rhs.peer).isService {
                            if EnginePeer(lhs.peer).isService {
                                return true
                            } else {
                                return false
                            }
                        }
                        if lhs.peer.isPremium != rhs.peer.isPremium {
                            if lhs.peer.isPremium {
                                return true
                            } else {
                                return false
                            }
                        }
                        if lhs.lastTimestamp != rhs.lastTimestamp {
                            return lhs.lastTimestamp > rhs.lastTimestamp
                        }
                        return lhs.peer.id < rhs.peer.id
                    })
                    
                    var nextPriority: Int = 0
                    var resultResources: [EngineMedia.Id: StoryPreloadInfo] = [:]
                    
                    for itemAndPeer in sortedItems.prefix(10) {
                        guard let peerReference = PeerReference(itemAndPeer.peer) else {
                            continue
                        }
                        guard let media = itemAndPeer.item.media, let mediaId = media.id else {
                            continue
                        }
                        
                        resultResources[mediaId] = StoryPreloadInfo(
                            peer: peerReference,
                            storyId: itemAndPeer.item.id,
                            media: EngineMedia(media),
                            priority: .top(position: nextPriority)
                        )
                        nextPriority += 1
                    }
                    
                    return resultResources
                }
            }
        }
        
        public func refreshStories(peerId: EnginePeer.Id, ids: [Int32]) -> Signal<Never, NoError> {
            return _internal_refreshStories(account: self.account, peerId: peerId, ids: ids)
        }
        
        public func refreshStoryViews(peerId: EnginePeer.Id, ids: [Int32]) -> Signal<Never, NoError> {
            if peerId != self.account.peerId {
                return .complete()
            }
            
            return _internal_getStoryViews(account: self.account, ids: ids)
            |> mapToSignal { views -> Signal<Never, NoError> in
                return self.account.postbox.transaction { transaction -> Void in
                    var currentItems = transaction.getStoryItems(peerId: peerId)
                    for i in 0 ..< currentItems.count {
                        if ids.contains(currentItems[i].id) {
                            if case let .item(item) = currentItems[i].value.get(Stories.StoredItem.self) {
                                let updatedItem: Stories.StoredItem = .item(Stories.Item(
                                    id: item.id,
                                    timestamp: item.timestamp,
                                    expirationTimestamp: item.expirationTimestamp,
                                    media: item.media,
                                    mediaAreas: item.mediaAreas,
                                    text: item.text,
                                    entities: item.entities,
                                    views: views[currentItems[i].id],
                                    privacy: item.privacy,
                                    isPinned: item.isPinned,
                                    isExpired: item.isExpired,
                                    isPublic: item.isPublic,
                                    isCloseFriends: item.isCloseFriends,
                                    isContacts: item.isContacts,
                                    isSelectedContacts: item.isSelectedContacts,
                                    isForwardingDisabled: item.isForwardingDisabled,
                                    isEdited: item.isEdited,
                                    myReaction: item.myReaction
                                ))
                                if let entry = CodableEntry(updatedItem) {
                                    currentItems[i] = StoryItemsTableEntry(value: entry, id: updatedItem.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
                                }
                            }
                        }
                    }
                    transaction.setStoryItems(peerId: peerId, items: currentItems)
                }
                |> ignoreValues
            }
        }
        
        public func uploadStory(media: EngineStoryInputMedia, mediaAreas: [MediaArea], text: String, entities: [MessageTextEntity], pin: Bool, privacy: EngineStoryPrivacy, isForwardingDisabled: Bool, period: Int, randomId: Int64) -> Signal<Int32, NoError> {
            return _internal_uploadStory(account: self.account, media: media, mediaAreas: mediaAreas, text: text, entities: entities, pin: pin, privacy: privacy, isForwardingDisabled: isForwardingDisabled, period: period, randomId: randomId)
        }
        
        public func allStoriesUploadEvents() -> Signal<(Int32, Int32), NoError> {
            guard let pendingStoryManager = self.account.pendingStoryManager else {
                return .complete()
            }
            return pendingStoryManager.allStoriesUploadEvents()
        }
        
        public func lookUpPendingStoryIdMapping(stableId: Int32) -> Int32? {
            return self.account.pendingStoryManager?.lookUpPendingStoryIdMapping(stableId: stableId)
        }
        
        public func allStoriesUploadProgress() -> Signal<Float?, NoError> {
            guard let pendingStoryManager = self.account.pendingStoryManager else {
                return .single(nil)
            }
            return pendingStoryManager.allStoriesUploadProgress
        }
        
        public func storyUploadProgress(stableId: Int32) -> Signal<Float, NoError> {
            guard let pendingStoryManager = self.account.pendingStoryManager else {
                return .single(0.0)
            }
            return pendingStoryManager.storyUploadProgress(stableId: stableId)
        }
        
        public func cancelStoryUpload(stableId: Int32) {
            _internal_cancelStoryUpload(account: self.account, stableId: stableId)
        }
        
        public func editStory(id: Int32, media: EngineStoryInputMedia?, mediaAreas: [MediaArea]?, text: String?, entities: [MessageTextEntity]?, privacy: EngineStoryPrivacy?) -> Signal<StoryUploadResult, NoError> {
            return _internal_editStory(account: self.account, id: id, media: media, mediaAreas: mediaAreas, text: text, entities: entities, privacy: privacy)
        }
        
        public func editStoryPrivacy(id: Int32, privacy: EngineStoryPrivacy) -> Signal<Never, NoError> {
            return _internal_editStoryPrivacy(account: self.account, id: id, privacy: privacy)
        }
        
        public func checkStoriesUploadAvailability() -> Signal<StoriesUploadAvailability, NoError> {
            return _internal_checkStoriesUploadAvailability(account: self.account)
        }
        
        public func deleteStories(ids: [Int32]) -> Signal<Never, NoError> {
            return _internal_deleteStories(account: self.account, ids: ids)
        }
        
        public func markStoryAsSeen(peerId: EnginePeer.Id, id: Int32, asPinned: Bool) -> Signal<Never, NoError> {
            return _internal_markStoryAsSeen(account: self.account, peerId: peerId, id: id, asPinned: asPinned)
        }
        
        public func updateStoriesArePinned(ids: [Int32: EngineStoryItem], isPinned: Bool) -> Signal<Never, NoError> {
            return _internal_updateStoriesArePinned(account: self.account, ids: ids, isPinned: isPinned)
        }
        
        public func storyViewList(id: Int32, views: EngineStoryItem.Views, listMode: EngineStoryViewListContext.ListMode, sortMode: EngineStoryViewListContext.SortMode, searchQuery: String? = nil, parentSource: EngineStoryViewListContext? = nil) -> EngineStoryViewListContext {
            return EngineStoryViewListContext(account: self.account, storyId: id, views: views, listMode: listMode, sortMode: sortMode, searchQuery: searchQuery, parentSource: parentSource)
        }
        
        public func exportStoryLink(peerId: EnginePeer.Id, id: Int32) -> Signal<String?, NoError> {
            return _internal_exportStoryLink(account: self.account, peerId: peerId, id: id)
        }
        
        public func enableStoryStealthMode() -> Signal<Never, NoError> {
            return _internal_enableStoryStealthMode(account: self.account)
        }
        
        public func setStoryReaction(peerId: EnginePeer.Id, id: Int32, reaction: MessageReaction.Reaction?) -> Signal<Never, NoError> {
            return _internal_setStoryReaction(account: self.account, peerId: peerId, id: id, reaction: reaction)
        }
    }
}
