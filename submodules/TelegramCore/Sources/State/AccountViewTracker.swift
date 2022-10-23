import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum CallListViewType {
    case all
    case missed
}

public enum CallListViewEntry {
    case message(Message, [Message])
    case hole(MessageIndex)
}

public final class CallListView {
    public let entries: [CallListViewEntry]
    public let earlier: MessageIndex?
    public let later: MessageIndex?
    
    init(entries: [CallListViewEntry], earlier: MessageIndex?, later: MessageIndex?) {
        self.entries = entries
        self.earlier = earlier
        self.later = later
    }
}

private func pendingWebpages(entries: [MessageHistoryEntry]) -> (Set<MessageId>, [MessageId: (MediaId, String)]) {
    var messageIds = Set<MessageId>()
    var localWebpages: [MessageId: (MediaId, String)] = [:]
    for entry in entries {
        for media in entry.message.media {
            if let media = media as? TelegramMediaWebpage {
                if case let .Pending(_, url) = media.content {
                    messageIds.insert(entry.message.id)
                    if let url = url, media.webpageId.namespace == Namespaces.Media.LocalWebpage {
                        localWebpages[entry.message.id] = (media.webpageId, url)
                    }
                }
                break
            }
        }
    }
    return (messageIds, localWebpages)
}

private func pollMessages(entries: [MessageHistoryEntry]) -> (Set<MessageId>, [MessageId: Message]) {
    var messageIds = Set<MessageId>()
    var messages: [MessageId: Message] = [:]
    for entry in entries {
        for media in entry.message.media {
            if let poll = media as? TelegramMediaPoll, poll.pollId.namespace == Namespaces.Media.CloudPoll, entry.message.id.namespace == Namespaces.Message.Cloud, !poll.isClosed {
                messageIds.insert(entry.message.id)
                messages[entry.message.id] = entry.message
                break
            }
        }
    }
    return (messageIds, messages)
}

private func fetchWebpage(account: Account, messageId: MessageId) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> mapToSignal { peer in
        if let inputPeer = apiInputPeer(peer) {
            let isScheduledMessage = Namespaces.Message.allScheduled.contains(messageId.namespace)
            let messages: Signal<Api.messages.Messages, MTRpcError>
            if isScheduledMessage {
                messages = account.network.request(Api.functions.messages.getScheduledMessages(peer: inputPeer, id: [messageId.id]))
            } else {
                switch inputPeer {
                    case let .inputPeerChannel(channelId, accessHash):
                        messages = account.network.request(Api.functions.channels.getMessages(channel: Api.InputChannel.inputChannel(channelId: channelId, accessHash: accessHash), id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                    default:
                        messages = account.network.request(Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                }
            }
            return messages
            |> retryRequest
            |> mapToSignal { result in
                let messages: [Api.Message]
                let chats: [Api.Chat]
                let users: [Api.User]
                switch result {
                    case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                        messages = apiMessages
                        chats = apiChats
                        users = apiUsers
                    case let .messagesSlice(_, _, _, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                        messages = apiMessages
                        chats = apiChats
                        users = apiUsers
                    case let .channelMessages(_, _, _, _, apiMessages, apiChats, apiUsers):
                        messages = apiMessages
                        chats = apiChats
                        users = apiUsers
                    case .messagesNotModified:
                        messages = []
                        chats = []
                        users = []
                }
                
                return account.postbox.transaction { transaction -> Void in
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: Api.User] = [:]
                    for chat in chats {
                        if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                            peers.append(groupOrChannel)
                        }
                    }
                    for apiUser in users {
                        if let user = TelegramUser.merge(transaction.getPeer(apiUser.peerId) as? TelegramUser, rhs: apiUser) {
                            peers.append(user)
                            peerPresences[user.id] = apiUser
                        }
                    }
                    
                    for message in messages {
                        if let storeMessage = StoreMessage(apiMessage: message, namespace: isScheduledMessage ? Namespaces.Message.ScheduledCloud : Namespaces.Message.Cloud) {
                            var webpage: TelegramMediaWebpage?
                            for media in storeMessage.media {
                                if let media = media as? TelegramMediaWebpage {
                                    webpage = media
                                }
                            }
                            
                            if let webpage = webpage {
                                updateMessageMedia(transaction: transaction, id: webpage.webpageId, media: webpage)
                            } else {
                                if let previousMessage = transaction.getMessage(messageId) {
                                    for media in previousMessage.media {
                                        if let media = media as? TelegramMediaWebpage {
                                            updateMessageMedia(transaction: transaction, id: media.webpageId, media: nil)
                                            
                                            break
                                        }
                                    }
                                }
                            }
                            break
                        }
                    }
                    
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                }
            }
        } else {
            return .complete()
        }
    }
}

private func fetchPoll(account: Account, messageId: MessageId) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> mapToSignal { peer -> Signal<Void, NoError> in
        guard let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.getPollResults(peer: inputPeer, msgId: messageId.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Void, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }
}

private func wrappedHistoryViewAdditionalData(chatLocation: ChatLocationInput, additionalData: [AdditionalMessageHistoryViewData]) -> [AdditionalMessageHistoryViewData] {
    var result = additionalData
    switch chatLocation {
    case let .peer(peerId, _):
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            if result.firstIndex(where: { if case .peerChatState = $0 { return true } else { return false } }) == nil {
                result.append(.peerChatState(peerId))
            }
        }
    case let .thread(peerId, _, _):
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            if result.firstIndex(where: { if case .peerChatState = $0 { return true } else { return false } }) == nil {
                result.append(.peerChatState(peerId))
            }
        }
    case .feed:
        break
    }
    return result
}

private final class PeerCachedDataContext {
    var viewIds = Set<Int32>()
    var timestamp: Double?
    var hasCachedData: Bool = false
    let disposable = MetaDisposable()
    
    deinit {
        self.disposable.dispose()
    }
}

private final class CachedChannelParticipantsContext {
    var subscribers = Bag<Int32>()
    var timestamp: Double?
    let disposable = MetaDisposable()
    
    deinit {
        self.disposable.dispose()
    }
}

private final class ChannelPollingContext {
    var subscribers = Bag<Void>()
    let disposable = MetaDisposable()
    let isUpdated = Promise<Bool>(false)

    private(set) var isUpdatedValue: Bool = false
    private var isUpdatedDisposable: Disposable?

    init(queue: Queue) {
        self.isUpdatedDisposable = (self.isUpdated.get()
        |> deliverOn(queue)).start(next: { [weak self] value in
            self?.isUpdatedValue = value
        })
    }
    
    deinit {
        self.disposable.dispose()
        self.isUpdatedDisposable?.dispose()
    }
}

private final class FeaturedStickerPacksContext {
    var subscribers = Bag<Void>()
    let disposable = MetaDisposable()
    var timestamp: Double?
    
    deinit {
        self.disposable.dispose()
    }
}

private struct ViewCountContextState {
    struct ReplyInfo {
        var commentsPeerId: PeerId?
        var maxReadIncomingMessageId: MessageId?
        var maxMessageId: MessageId?
    }
    
    var timestamp: Int32
    var clientId: Int32
    var result: ReplyInfo?
    
    func isStillValidFor(_ other: ViewCountContextState) -> Bool {
        if other.timestamp > self.timestamp + 30 {
            return false
        }
        if other.clientId > self.clientId {
            return false
        }
        return true
    }
}

public final class AccountViewTracker {
    weak var account: Account?
    private let queue = Queue()
    private var nextViewId: Int32 = 0
    
    private var viewPendingWebpageMessageIds: [Int32: Set<MessageId>] = [:]
    private var viewPollMessageIds: [Int32: Set<MessageId>] = [:]
    private var pendingWebpageMessageIds: [MessageId: Int] = [:]
    private var pollMessageIds: [MessageId: Int] = [:]
    private var webpageDisposables: [MessageId: Disposable] = [:]
    private var pollDisposables: [MessageId: Disposable] = [:]
    
    private var viewVisibleCallListHoleIds: [Int32: Set<MessageIndex>] = [:]
    private var visibleCallListHoleIds: [MessageIndex: Int] = [:]
    private var visibleCallListHoleDisposables: [MessageIndex: Disposable] = [:]
    
    private var updatedViewCountMessageIdsAndTimestamps: [MessageId: ViewCountContextState] = [:]
    private var nextUpdatedViewCountDisposableId: Int32 = 0
    private var updatedViewCountDisposables = DisposableDict<Int32>()
    
    private var updatedReactionsMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextUpdatedReactionsDisposableId: Int32 = 0
    private var updatedReactionsDisposables = DisposableDict<Int32>()
    
    private var updatedSeenLiveLocationMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextSeenLiveLocationDisposableId: Int32 = 0
    private var seenLiveLocationDisposables = DisposableDict<Int32>()
    
    private var updatedExtendedMediaMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextUpdatedExtendedMediaDisposableId: Int32 = 0
    private var updatedExtendedMediaDisposables = DisposableDict<Int32>()
    
    private var updatedUnsupportedMediaMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var refreshSecretChatMediaMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextUpdatedUnsupportedMediaDisposableId: Int32 = 0
    private var updatedUnsupportedMediaDisposables = DisposableDict<Int32>()
    
    private var updatedSeenPersonalMessageIds = Set<MessageId>()
    private var updatedReactionsSeenForMessageIds = Set<MessageId>()
    
    private var cachedDataContexts: [PeerId: PeerCachedDataContext] = [:]
    private var cachedChannelParticipantsContexts: [PeerId: CachedChannelParticipantsContext] = [:]
    
    private var channelPollingContexts: [PeerId: ChannelPollingContext] = [:]
    private var featuredStickerPacksContext: FeaturedStickerPacksContext?
    private var featuredEmojiPacksContext: FeaturedStickerPacksContext?
    
    let chatHistoryPreloadManager: ChatHistoryPreloadManager
    
    private let historyViewStateValidationContexts: HistoryViewStateValidationContexts
    
    public var orderedPreloadMedia: Signal<[ChatHistoryPreloadMediaItem], NoError> {
        return self.chatHistoryPreloadManager.orderedMedia
    }
    
    private let externallyUpdatedPeerIdDisposable = MetaDisposable()
    
    public let chatListPreloadItems = Promise<[ChatHistoryPreloadItem]>([])
    
    init(account: Account) {
        self.account = account
        
        self.historyViewStateValidationContexts = HistoryViewStateValidationContexts(queue: self.queue, postbox: account.postbox, network: account.network, accountPeerId: account.peerId)
        
        self.chatHistoryPreloadManager = ChatHistoryPreloadManager(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, networkState: account.networkState, preloadItemsSignal: self.chatListPreloadItems.get() |> distinctUntilChanged)
        
        self.externallyUpdatedPeerIdDisposable.set((account.stateManager.externallyUpdatedPeerIds
        |> deliverOn(self.queue)).start(next: { [weak self] peerIds in
            guard let strongSelf = self else {
                return
            }
            for (peerId, _) in strongSelf.cachedDataContexts {
                if peerIds.contains(peerId) {
                    strongSelf.forceUpdateCachedPeerData(peerId: peerId)
                }
            }
        }))
    }
    
    deinit {
        self.updatedViewCountDisposables.dispose()
        self.updatedReactionsDisposables.dispose()
        self.externallyUpdatedPeerIdDisposable.dispose()
    }
    
    func reset() {
        self.queue.async {
            self.cachedDataContexts.removeAll()
        }
    }
    
    private func updatePendingWebpages(viewId: Int32, messageIds: Set<MessageId>, localWebpages: [MessageId: (MediaId, String)]) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            var removedMessageIds: [MessageId] = []
            
            let viewMessageIds: Set<MessageId> = self.viewPendingWebpageMessageIds[viewId] ?? Set()
            
            let viewAddedMessageIds = messageIds.subtracting(viewMessageIds)
            let viewRemovedMessageIds = viewMessageIds.subtracting(messageIds)
            for messageId in viewAddedMessageIds {
                if let count = self.pendingWebpageMessageIds[messageId] {
                    self.pendingWebpageMessageIds[messageId] = count + 1
                } else {
                    self.pendingWebpageMessageIds[messageId] = 1
                    addedMessageIds.append(messageId)
                }
            }
            for messageId in viewRemovedMessageIds {
                if let count = self.pendingWebpageMessageIds[messageId] {
                    if count == 1 {
                        self.pendingWebpageMessageIds.removeValue(forKey: messageId)
                        removedMessageIds.append(messageId)
                    } else {
                        self.pendingWebpageMessageIds[messageId] = count - 1
                    }
                } else {
                    assertionFailure()
                }
            }
            
            if messageIds.isEmpty {
                self.viewPendingWebpageMessageIds.removeValue(forKey: viewId)
            } else {
                self.viewPendingWebpageMessageIds[viewId] = messageIds
            }
            
            for messageId in removedMessageIds {
                if let disposable = self.webpageDisposables.removeValue(forKey: messageId) {
                    disposable.dispose()
                }
            }
            
            if let account = self.account {
                for messageId in addedMessageIds {
                    if self.webpageDisposables[messageId] == nil {
                        if let (_, url) = localWebpages[messageId] {
                            self.webpageDisposables[messageId] = (webpagePreview(account: account, url: url) |> mapToSignal { webpage -> Signal<Void, NoError> in
                                return account.postbox.transaction { transaction -> Void in
                                    if let webpage = webpage {
                                        transaction.updateMessage(messageId, update: { currentMessage in
                                            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                            var media = currentMessage.media
                                            for i in 0 ..< media.count {
                                                if let _ = media[i] as? TelegramMediaWebpage {
                                                    media[i] = webpage
                                                    break
                                                }
                                            }
                                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: media))
                                        })
                                    }
                                }
                            }).start(completed: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.queue.async {
                                        strongSelf.webpageDisposables.removeValue(forKey: messageId)
                                    }
                                }
                            })
                        } else if messageId.namespace == Namespaces.Message.Cloud {
                            self.webpageDisposables[messageId] = fetchWebpage(account: account, messageId: messageId).start(completed: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.queue.async {
                                        strongSelf.webpageDisposables.removeValue(forKey: messageId)
                                    }
                                }
                            })
                        }
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
    }
    
    private func updatePolls(viewId: Int32, messageIds: Set<MessageId>, messages: [MessageId: Message]) {
        let queue = self.queue
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            var removedMessageIds: [MessageId] = []
            
            let viewMessageIds: Set<MessageId> = self.viewPollMessageIds[viewId] ?? Set()
            
            let viewAddedMessageIds = messageIds.subtracting(viewMessageIds)
            let viewRemovedMessageIds = viewMessageIds.subtracting(messageIds)
            for messageId in viewAddedMessageIds {
                if let count = self.pollMessageIds[messageId] {
                    self.pollMessageIds[messageId] = count + 1
                } else {
                    self.pollMessageIds[messageId] = 1
                    addedMessageIds.append(messageId)
                }
            }
            for messageId in viewRemovedMessageIds {
                if let count = self.pollMessageIds[messageId] {
                    if count == 1 {
                        self.pollMessageIds.removeValue(forKey: messageId)
                        removedMessageIds.append(messageId)
                    } else {
                        self.pollMessageIds[messageId] = count - 1
                    }
                } else {
                    assertionFailure()
                }
            }
            
            if messageIds.isEmpty {
                self.viewPollMessageIds.removeValue(forKey: viewId)
            } else {
                self.viewPollMessageIds[viewId] = messageIds
            }
            
            for messageId in removedMessageIds {
                if let disposable = self.pollDisposables.removeValue(forKey: messageId) {
                    disposable.dispose()
                }
            }
            
            if let account = self.account {
                for messageId in addedMessageIds {
                    if self.pollDisposables[messageId] == nil {
                        var deadlineTimer: Signal<Bool, NoError> = .single(false)
                        
                        if let message = messages[messageId] {
                            for media in message.media {
                                if let poll = media as? TelegramMediaPoll {
                                    if let _ = poll.deadlineTimeout, message.id.namespace == Namespaces.Message.Cloud {
                                        let startDate: Int32
                                        if let forwardInfo = message.forwardInfo {
                                            startDate = forwardInfo.date
                                        } else {
                                            startDate = message.timestamp
                                        }
                                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                                        let remainingTime = timestamp - startDate - 1
                                        
                                        if remainingTime > 0 {
                                            deadlineTimer = .single(false)
                                            |> then(
                                                .single(true)
                                                |> suspendAwareDelay(Double(remainingTime), queue: queue)
                                            )
                                        } else {
                                            deadlineTimer = .single(true)
                                        }
                                    }
                                }
                            }
                        }
                        
                        let pollSignal: Signal<Never, NoError> = deadlineTimer
                        |> distinctUntilChanged
                        |> mapToSignal { reachedDeadline -> Signal<Never, NoError> in
                            if reachedDeadline {
                                var signal = fetchPoll(account: account, messageId: messageId)
                                |> ignoreValues
                                signal = (signal |> then(
                                    .complete()
                                    |> delay(0.5, queue: Queue.concurrentDefaultQueue())
                                ))
                                |> restart
                                return signal
                            } else {
                                var signal = fetchPoll(account: account, messageId: messageId)
                                |> ignoreValues
                                signal = (signal |> then(
                                    .complete()
                                    |> delay(30.0, queue: Queue.concurrentDefaultQueue())
                                ))
                                |> restart
                                return signal
                            }
                        }
                        self.pollDisposables[messageId] = pollSignal.start()
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
    }
    
    private func updateVisibleCallListHoles(viewId: Int32, holeIds: Set<MessageIndex>) {
        self.queue.async {
            var addedHoleIds: [MessageIndex] = []
            var removedHoleIds: [MessageIndex] = []
            
            let viewHoleIds: Set<MessageIndex> = self.viewVisibleCallListHoleIds[viewId] ?? Set()
            
            let viewAddedHoleIds = holeIds.subtracting(viewHoleIds)
            let viewRemovedHoleIds = viewHoleIds.subtracting(holeIds)
            for holeId in viewAddedHoleIds {
                if let count = self.visibleCallListHoleIds[holeId] {
                    self.visibleCallListHoleIds[holeId] = count + 1
                } else {
                    self.visibleCallListHoleIds[holeId] = 1
                    addedHoleIds.append(holeId)
                }
            }
            for holeId in viewRemovedHoleIds {
                if let count = self.visibleCallListHoleIds[holeId] {
                    if count == 1 {
                        self.visibleCallListHoleIds.removeValue(forKey: holeId)
                        removedHoleIds.append(holeId)
                    } else {
                        self.visibleCallListHoleIds[holeId] = count - 1
                    }
                } else {
                    assertionFailure()
                }
            }
            
            if holeIds.isEmpty {
                self.viewVisibleCallListHoleIds.removeValue(forKey: viewId)
            } else {
                self.viewVisibleCallListHoleIds[viewId] = holeIds
            }
            
            for holeId in removedHoleIds {
                if let disposable = self.visibleCallListHoleDisposables.removeValue(forKey: holeId) {
                    disposable.dispose()
                }
            }
            
            if let account = self.account {
                for holeId in addedHoleIds {
                    if self.visibleCallListHoleDisposables[holeId] == nil {
                        self.visibleCallListHoleDisposables[holeId] = fetchCallListHole(network: account.network, postbox: account.postbox, accountPeerId: account.peerId, holeIndex: holeId).start(completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.queue.async {
                                    strongSelf.visibleCallListHoleDisposables.removeValue(forKey: holeId)
                                }
                            }
                        })
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
    }
    
    public struct UpdatedMessageReplyInfo {
        var timestamp: Int32
        var commentsPeerId: PeerId
        var maxReadIncomingMessageId: MessageId?
        var maxMessageId: MessageId?
    }
    
    func applyMaxReadIncomingMessageIdForReplyInfo(id: MessageId, maxReadIncomingMessageId: MessageId) {
        self.queue.async {
            if var state = self.updatedViewCountMessageIdsAndTimestamps[id], var result = state.result {
                result.maxReadIncomingMessageId = maxReadIncomingMessageId
                state.result = result
                self.updatedViewCountMessageIdsAndTimestamps[id] = state
            }
        }
    }
    
    public func replyInfoForMessageId(_ id: MessageId) -> Signal<UpdatedMessageReplyInfo?, NoError> {
        return Signal { [weak self] subscriber in
            let state = self?.updatedViewCountMessageIdsAndTimestamps[id]
            let result = state?.result
            if let state = state, let result = result, let commentsPeerId = result.commentsPeerId {
                subscriber.putNext(UpdatedMessageReplyInfo(timestamp: state.timestamp, commentsPeerId: commentsPeerId, maxReadIncomingMessageId: result.maxReadIncomingMessageId, maxMessageId: result.maxMessageId))
            } else {
                subscriber.putNext(nil)
            }
            subscriber.putCompletion()
            return EmptyDisposable
        }
        |> runOn(self.queue)
    }
    
    public func updateReplyInfoForMessageId(_ id: MessageId, info: UpdatedMessageReplyInfo) {
        self.queue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            guard let current = strongSelf.updatedViewCountMessageIdsAndTimestamps[id] else {
                return
            }
            strongSelf.updatedViewCountMessageIdsAndTimestamps[id] = ViewCountContextState(timestamp: Int32(CFAbsoluteTimeGetCurrent()), clientId: current.clientId, result: ViewCountContextState.ReplyInfo(commentsPeerId: info.commentsPeerId, maxReadIncomingMessageId: info.maxReadIncomingMessageId, maxMessageId: info.maxMessageId))
        }
    }
    
    public func updateViewCountForMessageIds(messageIds: Set<MessageId>, clientId: Int32) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            let updatedState = ViewCountContextState(timestamp: Int32(CFAbsoluteTimeGetCurrent()), clientId: clientId, result: nil)
            for messageId in messageIds {
                let messageTimestamp = self.updatedViewCountMessageIdsAndTimestamps[messageId]
                if messageTimestamp == nil || !messageTimestamp!.isStillValidFor(updatedState) {
                    self.updatedViewCountMessageIdsAndTimestamps[messageId] = updatedState
                    addedMessageIds.append(messageId)
                }
            }
            if !addedMessageIds.isEmpty {
                for (peerId, messageIds) in messagesIdsGroupedByPeerId(Set(addedMessageIds)) {
                    let disposableId = self.nextUpdatedViewCountDisposableId
                    self.nextUpdatedViewCountDisposableId += 1
                    
                    if let account = self.account {
                        let signal: Signal<[MessageId: ViewCountContextState], NoError> = (account.postbox.transaction { transaction -> Signal<[MessageId: ViewCountContextState], NoError> in
                            guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                                return .complete()
                            }
                            return account.network.request(Api.functions.messages.getMessagesViews(peer: inputPeer, id: messageIds.map { $0.id }, increment: .boolTrue))
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<Api.messages.MessageViews?, NoError> in
                                return .single(nil)
                            }
                            |> mapToSignal { result -> Signal<[MessageId: ViewCountContextState], NoError> in
                                guard case let .messageViews(viewCounts, chats, users)? = result else {
                                    return .complete()
                                }
                                
                                return account.postbox.transaction { transaction -> [MessageId: ViewCountContextState] in
                                    var peers: [Peer] = []
                                    var peerPresences: [PeerId: Api.User] = [:]
                                    
                                    var resultStates: [MessageId: ViewCountContextState] = [:]
                                    
                                    for apiUser in users {
                                        if let user = TelegramUser.merge(transaction.getPeer(apiUser.peerId) as? TelegramUser, rhs: apiUser) {
                                            peers.append(user)
                                            peerPresences[user.id] = apiUser
                                        }
                                    }
                                    for chat in chats {
                                        if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                                            peers.append(groupOrChannel)
                                        }
                                    }
                                    
                                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                        return updated
                                    })
                                    
                                    updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                                    
                                    for i in 0 ..< messageIds.count {
                                        if i < viewCounts.count {
                                            if case let .messageViews(_, views, forwards, replies) = viewCounts[i] {
                                                transaction.updateMessage(messageIds[i], update: { currentMessage in
                                                    let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                                    var attributes = currentMessage.attributes
                                                    var foundReplies = false
                                                    var commentsChannelId: PeerId?
                                                    var recentRepliersPeerIds: [PeerId]?
                                                    var repliesCount: Int32?
                                                    var repliesMaxId: Int32?
                                                    var repliesReadMaxId: Int32?
                                                    if let replies = replies {
                                                        switch replies {
                                                        case let .messageReplies(_, repliesCountValue, _, recentRepliers, channelId, maxId, readMaxId):
                                                            if let channelId = channelId {
                                                                commentsChannelId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                                                            }
                                                            repliesCount = repliesCountValue
                                                            if let recentRepliers = recentRepliers {
                                                                recentRepliersPeerIds = recentRepliers.map { $0.peerId }
                                                            } else {
                                                                recentRepliersPeerIds = nil
                                                            }
                                                            repliesMaxId = maxId
                                                            repliesReadMaxId = readMaxId
                                                        }
                                                    }
                                                    var maxMessageId: MessageId?
                                                    if let commentsChannelId = commentsChannelId {
                                                        if let repliesMaxId = repliesMaxId {
                                                            maxMessageId = MessageId(peerId: commentsChannelId, namespace: Namespaces.Message.Cloud, id: repliesMaxId)
                                                        }
                                                    }
                                                    loop: for j in 0 ..< attributes.count {
                                                        if let attribute = attributes[j] as? ViewCountMessageAttribute {
                                                            if let views = views {
                                                                attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(views)))
                                                            }
                                                        } else if let _ = attributes[j] as? ForwardCountMessageAttribute {
                                                            if let forwards = forwards {
                                                                attributes[j] = ForwardCountMessageAttribute(count: Int(forwards))
                                                            }
                                                        } else if let attribute = attributes[j] as? ReplyThreadMessageAttribute {
                                                            foundReplies = true
                                                            if let repliesCount = repliesCount {
                                                                var resolvedMaxReadMessageId: MessageId.Id?
                                                                if let previousMaxReadMessageId = attribute.maxReadMessageId, let repliesReadMaxIdValue = repliesReadMaxId {
                                                                    resolvedMaxReadMessageId = max(previousMaxReadMessageId, repliesReadMaxIdValue)
                                                                    repliesReadMaxId = resolvedMaxReadMessageId
                                                                } else if let repliesReadMaxIdValue = repliesReadMaxId {
                                                                    resolvedMaxReadMessageId = repliesReadMaxIdValue
                                                                    repliesReadMaxId = resolvedMaxReadMessageId
                                                                } else {
                                                                    resolvedMaxReadMessageId = attribute.maxReadMessageId
                                                                }
                                                                attributes[j] = ReplyThreadMessageAttribute(count: repliesCount, latestUsers: recentRepliersPeerIds ?? [], commentsPeerId: commentsChannelId, maxMessageId: repliesMaxId, maxReadMessageId: resolvedMaxReadMessageId)
                                                            }
                                                        }
                                                    }
                                                    var maxReadIncomingMessageId: MessageId?
                                                    if let commentsChannelId = commentsChannelId {
                                                        if let repliesReadMaxId = repliesReadMaxId {
                                                            maxReadIncomingMessageId = MessageId(peerId: commentsChannelId, namespace: Namespaces.Message.Cloud, id: repliesReadMaxId)
                                                        }
                                                    }
                                                    resultStates[messageIds[i]] = ViewCountContextState(timestamp: Int32(CFAbsoluteTimeGetCurrent()), clientId: clientId, result: ViewCountContextState.ReplyInfo(commentsPeerId: commentsChannelId, maxReadIncomingMessageId: maxReadIncomingMessageId, maxMessageId: maxMessageId))
                                                    if !foundReplies, let repliesCount = repliesCount {
                                                        attributes.append(ReplyThreadMessageAttribute(count: repliesCount, latestUsers: recentRepliersPeerIds ?? [], commentsPeerId: commentsChannelId, maxMessageId: repliesMaxId, maxReadMessageId: repliesReadMaxId))
                                                    }
                                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                                })
                                            }
                                        }
                                    }
                                    return resultStates
                                }
                            }
                        }
                        |> switchToLatest)
                        |> afterDisposed { [weak self] in
                            self?.queue.async {
                                self?.updatedViewCountDisposables.set(nil, forKey: disposableId)
                            }
                        }
                        |> deliverOn(self.queue)
                        self.updatedViewCountDisposables.set(signal.start(next: { [weak self] updatedStates in
                            guard let strongSelf = self else {
                                return
                            }
                            for (id, state) in updatedStates {
                                strongSelf.updatedViewCountMessageIdsAndTimestamps[id] = state
                            }
                        }), forKey: disposableId)
                    }
                }
            }
        }
    }
    
    public func updateReactionsForMessageIds(messageIds: Set<MessageId>, force: Bool = false) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            for messageId in messageIds {
                let messageTimestamp = self.updatedReactionsMessageIdsAndTimestamps[messageId]
                if messageTimestamp == nil || messageTimestamp! < timestamp - 1 * 20 || force {
                    self.updatedReactionsMessageIdsAndTimestamps[messageId] = timestamp
                    addedMessageIds.append(messageId)
                }
            }
            if !addedMessageIds.isEmpty {
                for (peerId, messageIds) in messagesIdsGroupedByPeerId(Set(addedMessageIds)) {
                    let disposableId = self.nextUpdatedReactionsDisposableId
                    self.nextUpdatedReactionsDisposableId += 1
                    
                    if let account = self.account {
                        let signal = (account.postbox.transaction { transaction -> Signal<Void, NoError> in
                            if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                                return account.network.request(Api.functions.messages.getMessagesReactions(peer: inputPeer, id: messageIds.map { $0.id }))
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { updates -> Signal<Void, NoError> in
                                    guard let updates = updates else {
                                        return .complete()
                                    }
                                    return account.postbox.transaction { transaction -> Void in
                                        let updateList: [Api.Update]
                                        switch updates {
                                        case let .updates(updates, _, _, _, _):
                                            updateList = updates
                                        case let .updatesCombined(updates, _, _, _, _, _):
                                            updateList = updates
                                        case let .updateShort(update, _):
                                            updateList = [update]
                                        default:
                                            updateList = []
                                        }
                                        for update in updateList {
                                            switch update {
                                            case let .updateMessageReactions(_, peer, msgId, _, reactions):
                                                transaction.updateMessage(MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: msgId), update: { currentMessage in
                                                    var updatedReactions = ReactionsMessageAttribute(apiReactions: reactions)
                                                    
                                                    let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                                    var added = false
                                                    var attributes = currentMessage.attributes
                                                    loop: for j in 0 ..< attributes.count {
                                                        if let attribute = attributes[j] as? ReactionsMessageAttribute {
                                                            added = true
                                                            updatedReactions = attribute.withUpdatedResults(reactions)
                                                            
                                                            if updatedReactions == attribute {
                                                                return .skip
                                                            }
                                                            attributes[j] = updatedReactions
                                                            break loop
                                                        }
                                                    }
                                                    if !added {
                                                        attributes.append(updatedReactions)
                                                    }
                                                    var tags = currentMessage.tags
                                                    if updatedReactions.hasUnseen {
                                                        tags.insert(.unseenReaction)
                                                    } else {
                                                        tags.remove(.unseenReaction)
                                                    }
                                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                                })
                                            default:
                                                break
                                            }
                                        }
                                    }
                                }
                            } else {
                                return .complete()
                            }
                        }
                        |> switchToLatest)
                        |> afterDisposed { [weak self] in
                            self?.queue.async {
                                self?.updatedReactionsDisposables.set(nil, forKey: disposableId)
                            }
                        }
                        self.updatedReactionsDisposables.set(signal.start(), forKey: disposableId)
                    }
                }
            }
        }
    }
    
    public func updateSeenLiveLocationForMessageIds(messageIds: Set<MessageId>) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            for messageId in messageIds {
                let messageTimestamp = self.updatedSeenLiveLocationMessageIdsAndTimestamps[messageId]
                if messageTimestamp == nil || messageTimestamp! < timestamp - 1 * 60 {
                    self.updatedSeenLiveLocationMessageIdsAndTimestamps[messageId] = timestamp
                    addedMessageIds.append(messageId)
                }
            }
            if !addedMessageIds.isEmpty {
                for (peerId, messageIds) in messagesIdsGroupedByPeerId(Set(addedMessageIds)) {
                    let disposableId = self.nextSeenLiveLocationDisposableId
                    self.nextSeenLiveLocationDisposableId += 1
                    
                    if let account = self.account {
                        let signal = (account.postbox.transaction { transaction -> Signal<Void, NoError> in
                            if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                                let request: Signal<Bool, MTRpcError>
                                switch inputPeer {
                                case .inputPeerChat, .inputPeerSelf, .inputPeerUser:
                                    request = account.network.request(Api.functions.messages.readMessageContents(id: messageIds.map { $0.id }))
                                    |> map { _ in true }
                                case let .inputPeerChannel(channelId, accessHash):
                                    request = account.network.request(Api.functions.channels.readMessageContents(channel: .inputChannel(channelId: channelId, accessHash: accessHash), id: messageIds.map { $0.id }))
                                    |> map { _ in true }
                                default:
                                    return .complete()
                                }
                                
                                return request
                                |> `catch` { _ -> Signal<Bool, NoError> in
                                    return .single(false)
                                }
                                |> mapToSignal { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }
                            } else {
                                return .complete()
                            }
                        }
                        |> switchToLatest)
                        |> afterDisposed { [weak self] in
                            self?.queue.async {
                                self?.seenLiveLocationDisposables.set(nil, forKey: disposableId)
                            }
                        }
                        self.seenLiveLocationDisposables.set(signal.start(), forKey: disposableId)
                    }
                }
            }
        }
    }
    
    public func updatedExtendedMediaForMessageIds(messageIds: Set<MessageId>) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            for messageId in messageIds {
                let messageTimestamp = self.updatedExtendedMediaMessageIdsAndTimestamps[messageId]
                if messageTimestamp == nil || messageTimestamp! < timestamp - 30 {
                    self.updatedExtendedMediaMessageIdsAndTimestamps[messageId] = timestamp
                    addedMessageIds.append(messageId)
                }
            }
            
            if !addedMessageIds.isEmpty {
                for (peerId, messageIds) in messagesIdsGroupedByPeerId(Set(addedMessageIds)) {
                    let disposableId = self.nextUpdatedExtendedMediaDisposableId
                    self.nextUpdatedExtendedMediaDisposableId += 1
                    
                    if let account = self.account {
                        let signal = account.postbox.transaction { transaction -> Peer? in
                            if let peer = transaction.getPeer(peerId) {
                                return peer
                            } else {
                                return nil
                            }
                        }
                        |> mapToSignal { peer -> Signal<Void, NoError> in
                            guard let peer = peer, let inputPeer = apiInputPeer(peer) else {
                                return .complete()
                            }
                            return account.network.request(Api.functions.messages.getExtendedMedia(peer: inputPeer, id: messageIds.map { $0.id }))
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                                return .single(nil)
                            }
                            |> mapToSignal { updates -> Signal<Void, NoError> in
                                if let updates = updates {
                                    account.stateManager.addUpdates(updates)
                                }
                                return .complete()
                            }
                        }
                        |> afterDisposed { [weak self] in
                            self?.queue.async {
                                self?.updatedExtendedMediaDisposables.set(nil, forKey: disposableId)
                            }
                        }
                        self.updatedExtendedMediaDisposables.set(signal.start(), forKey: disposableId)
                    }
                }
            }
        }
    }
    
    public func updateUnsupportedMediaForMessageIds(messageIds: Set<MessageId>) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            for messageId in messageIds {
                let messageTimestamp = self.updatedUnsupportedMediaMessageIdsAndTimestamps[messageId]
                if messageTimestamp == nil || messageTimestamp! < timestamp - 10 * 60 * 60 {
                    self.updatedUnsupportedMediaMessageIdsAndTimestamps[messageId] = timestamp
                    addedMessageIds.append(messageId)
                }
            }
            if !addedMessageIds.isEmpty {
                for (peerId, messageIds) in messagesIdsGroupedByPeerId(Set(addedMessageIds)) {
                    let disposableId = self.nextUpdatedUnsupportedMediaDisposableId
                    self.nextUpdatedUnsupportedMediaDisposableId += 1
                    
                    if let account = self.account {
                        let signal = account.postbox.transaction { transaction -> Peer? in
                            if let peer = transaction.getPeer(peerId) {
                                return peer
                            } else {
                                return nil
                            }
                        }
                        |> mapToSignal { peer -> Signal<Void, NoError> in
                            guard let peer = peer else {
                                return .complete()
                            }
                            var fetchSignal: Signal<Api.messages.Messages, MTRpcError>?
                            if let messageId = messageIds.first, messageId.namespace == Namespaces.Message.ScheduledCloud {
                                if let inputPeer = apiInputPeer(peer) {
                                    fetchSignal = account.network.request(Api.functions.messages.getScheduledMessages(peer: inputPeer, id: messageIds.map { $0.id }))
                                }
                            } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                                fetchSignal = account.network.request(Api.functions.messages.getMessages(id: messageIds.map { Api.InputMessage.inputMessageID(id: $0.id) }))
                            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                                if let inputChannel = apiInputChannel(peer) {
                                    fetchSignal = account.network.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map { Api.InputMessage.inputMessageID(id: $0.id) }))
                                }
                            }
                            guard let signal = fetchSignal else {
                                return .complete()
                            }
                            
                            return signal
                            |> map { result -> ([Api.Message], [Api.Chat], [Api.User]) in
                                switch result {
                                    case let .messages(messages, chats, users):
                                        return (messages, chats, users)
                                    case let .messagesSlice(_, _, _, _, messages, chats, users):
                                        return (messages, chats, users)
                                    case let .channelMessages(_, _, _, _, messages, chats, users):
                                        return (messages, chats, users)
                                    case .messagesNotModified:
                                        return ([], [], [])
                                }
                            }
                            |> `catch` { _ in
                                return Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>.single(([], [], []))
                            }
                            |> mapToSignal { messages, chats, users -> Signal<Void, NoError> in
                                return account.postbox.transaction { transaction -> Void in
                                    var peers: [Peer] = []
                                    var peerPresences: [PeerId: Api.User] = [:]
                                    
                                    for chat in chats {
                                        if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                                            peers.append(groupOrChannel)
                                        }
                                    }
                                    for apiUser in users {
                                        if let user = TelegramUser.merge(transaction.getPeer(apiUser.peerId) as? TelegramUser, rhs: apiUser) {
                                            peers.append(user)
                                            peerPresences[user.id] = apiUser
                                        }
                                    }
                                    
                                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                        return updated
                                    })
                                    
                                    updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                                    
                                    for message in messages {
                                        guard let storeMessage = StoreMessage(apiMessage: message) else {
                                            continue
                                        }
                                        guard case let .Id(id) = storeMessage.id else {
                                            continue
                                        }
                                        transaction.updateMessage(id, update: { _ in
                                            return .update(storeMessage)
                                        })
                                    }
                                }
                            }
                        }
                        |> afterDisposed { [weak self] in
                            self?.queue.async {
                                self?.updatedUnsupportedMediaDisposables.set(nil, forKey: disposableId)
                            }
                        }
                        self.updatedUnsupportedMediaDisposables.set(signal.start(), forKey: disposableId)
                    }
                }
            }
        }
    }
    
    public func refreshSecretMediaMediaForMessageIds(messageIds: Set<MessageId>) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            for messageId in messageIds {
                let messageTimestamp = self.refreshSecretChatMediaMessageIdsAndTimestamps[messageId]
                if messageTimestamp == nil {
                    self.refreshSecretChatMediaMessageIdsAndTimestamps[messageId] = timestamp
                    addedMessageIds.append(messageId)
                }
            }
            if !addedMessageIds.isEmpty {
                for (_, messageIds) in messagesIdsGroupedByPeerId(Set(addedMessageIds)) {
                    let disposableId = self.nextUpdatedUnsupportedMediaDisposableId
                    self.nextUpdatedUnsupportedMediaDisposableId += 1
                    
                    if let account = self.account {
                        let signal = account.postbox.transaction { transaction -> [TelegramMediaFile] in
                            var result: [TelegramMediaFile] = []
                            for id in messageIds {
                                if let message = transaction.getMessage(id) {
                                    for media in message.media {
                                        if let file = media as? TelegramMediaFile, file.isAnimatedSticker {
                                            result.append(file)
                                        }
                                    }
                                }
                            }
                            return result
                        }
                        |> mapToSignal { files -> Signal<Void, NoError> in
                            guard !files.isEmpty else {
                                return .complete()
                            }
                            
                            var stickerPacks = Set<StickerPackReference>()
                            for file in files {
                                for attribute in file.attributes {
                                    if case let .Sticker(_, packReferenceValue, _) = attribute, let packReference = packReferenceValue {
                                        if case .id = packReference {
                                            stickerPacks.insert(packReference)
                                        }
                                    }
                                }
                            }
                            
                            var requests: [Signal<Api.messages.StickerSet?, NoError>] = []
                            for reference in stickerPacks {
                                if case let .id(id, accessHash) = reference {
                                    requests.append(account.network.request(Api.functions.messages.getStickerSet(stickerset: .inputStickerSetID(id: id, accessHash: accessHash), hash: 0))
                                    |> map(Optional.init)
                                    |> `catch` { _ -> Signal<Api.messages.StickerSet?, NoError> in
                                        return .single(nil)
                                    })
                                }
                            }
                            if requests.isEmpty {
                                return .complete()
                            }
                            
                            return combineLatest(requests)
                            |> mapToSignal { results -> Signal<Void, NoError> in
                                return account.postbox.transaction { transaction -> Void in
                                    for result in results {
                                        switch result {
                                        case let .stickerSet(_, _, _, documents)?:
                                            for document in documents {
                                                if let file = telegramMediaFileFromApiDocument(document) {
                                                    if transaction.getMedia(file.fileId) != nil {
                                                        let _ = transaction.updateMedia(file.fileId, update: file)
                                                    }
                                                }
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        |> afterDisposed { [weak self] in
                            self?.queue.async {
                                self?.updatedUnsupportedMediaDisposables.set(nil, forKey: disposableId)
                            }
                        }
                        self.updatedUnsupportedMediaDisposables.set(signal.start(), forKey: disposableId)
                    }
                }
            }
        }
    }
    
    public func updateMarkAllMentionsSeen(peerId: PeerId, threadId: Int64?) {
        self.queue.async {
            guard let account = self.account else {
                return
            }
            let _ = (account.postbox.transaction { transaction -> Set<MessageId> in
                let ids = Set(transaction.getMessageIndicesWithTag(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, tag: .unseenPersonalMessage).map({ $0.id }))
                
                for id in ids {
                    transaction.updateMessage(id, update: { currentMessage in
                        let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                        var attributes = currentMessage.attributes
                        for i in 0 ..< attributes.count {
                            if let attribute = attributes[i] as? ConsumablePersonalMentionMessageAttribute {
                                attributes[i] = ConsumablePersonalMentionMessageAttribute(consumed: true, pending: attribute.pending)
                                break
                            }
                        }
                        var tags = currentMessage.tags
                        tags.remove(.unseenPersonalMessage)
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                }
                
                if let summary = transaction.getMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud), summary.count > 0 {
                    var maxId: Int32 = summary.range.maxId
                    if let index = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                        maxId = index.id.id
                    }
                    
                    transaction.replaceMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: 0, maxId: maxId)
                    addSynchronizeMarkAllUnseenPersonalMessagesOperation(transaction: transaction, peerId: peerId, maxId: summary.range.maxId)
                }
                
                return ids
            }
            |> deliverOn(self.queue)).start()
        }
    }
    
    public func updateMarkMentionsSeenForMessageIds(messageIds: Set<MessageId>) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            for messageId in messageIds {
                if !self.updatedSeenPersonalMessageIds.contains(messageId) {
                    self.updatedSeenPersonalMessageIds.insert(messageId)
                    addedMessageIds.append(messageId)
                }
            }
            if !addedMessageIds.isEmpty {
                if let account = self.account {
                    let _ = (account.postbox.transaction { transaction -> Void in
                        for id in addedMessageIds {
                            if let message = transaction.getMessage(id) {
                                var consume = false
                                inner: for attribute in message.attributes {
                                    if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed, !attribute.pending {
                                        consume = true
                                        break inner
                                    }
                                }
                                if consume {
                                    transaction.updateMessage(id, update: { currentMessage in
                                        var attributes = currentMessage.attributes
                                        loop: for j in 0 ..< attributes.count {
                                            if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute {
                                                attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: attribute.consumed, pending: true)
                                                break loop
                                            }
                                        }
                                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                    })

                                    transaction.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: ConsumePersonalMessageAction())
                                }
                            }
                        }
                    }).start()
                }
            }
        }
    }
    
    public func updateMarkAllReactionsSeen(peerId: PeerId, threadId: Int64?) {
        self.queue.async {
            guard let account = self.account else {
                return
            }
            let _ = (account.postbox.transaction { transaction -> Set<MessageId> in
                let ids = Set(transaction.getMessageIndicesWithTag(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, tag: .unseenReaction).map({ $0.id }))
                
                for id in ids {
                    transaction.updateMessage(id, update: { currentMessage in
                        let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                        var attributes = currentMessage.attributes
                        for i in 0 ..< attributes.count {
                            if let attribute = attributes[i] as? ReactionsMessageAttribute {
                                attributes[i] = attribute.withAllSeen()
                                break
                            }
                        }
                        var tags = currentMessage.tags
                        tags.remove(.unseenReaction)
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                }
                
                if let summary = transaction.getMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud) {
                    var maxId: Int32 = summary.range.maxId
                    if let index = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                        maxId = index.id.id
                    }
                    
                    transaction.replaceMessageTagSummary(peerId: peerId, threadId: threadId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, count: 0, maxId: maxId)
                    addSynchronizeMarkAllUnseenReactionsOperation(transaction: transaction, peerId: peerId, maxId: summary.range.maxId)
                }
                
                return ids
            }
            |> deliverOn(self.queue)).start()
        }
    }
    
    public func updateMarkReactionsSeenForMessageIds(messageIds: Set<MessageId>) {
        self.queue.async {
            let addedMessageIds: [MessageId] = Array(messageIds)
            if !addedMessageIds.isEmpty {
                if let account = self.account {
                    let _ = (account.postbox.transaction { transaction -> Void in
                        for id in addedMessageIds {
                            if let _ = transaction.getMessage(id) {
                                transaction.updateMessage(id, update: { currentMessage in
                                    if !currentMessage.tags.contains(.unseenReaction) {
                                        return .skip
                                    }
                                    var attributes = currentMessage.attributes
                                    loop: for j in 0 ..< attributes.count {
                                        if let attribute = attributes[j] as? ReactionsMessageAttribute {
                                            attributes[j] = attribute.withAllSeen()
                                            break loop
                                        }
                                    }
                                    var tags = currentMessage.tags
                                    tags.remove(.unseenReaction)
                                    return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                })

                                if transaction.getPendingMessageAction(type: .readReaction, id: id) == nil {
                                    transaction.setPendingMessageAction(type: .readReaction, id: id, action: ReadReactionAction())
                                }
                            }
                        }
                    }).start()
                }
            }
        }
    }
    
    public func forceUpdateCachedPeerData(peerId: PeerId) {
        self.queue.async {
            let context: PeerCachedDataContext
            if let existingContext = self.cachedDataContexts[peerId] {
                context = existingContext
            } else {
                context = PeerCachedDataContext()
                self.cachedDataContexts[peerId] = context
            }
            context.timestamp = CFAbsoluteTimeGetCurrent()
            guard let account = self.account else {
                return
            }
            let queue = self.queue
            context.disposable.set(combineLatest(fetchAndUpdateSupplementalCachedPeerData(peerId: peerId, accountPeerId: account.peerId, network: account.network, postbox: account.postbox), _internal_fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)).start(next: { [weak self] supplementalStatus, cachedStatus in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    if !supplementalStatus || !cachedStatus {
                        if let existingContext = strongSelf.cachedDataContexts[peerId] {
                            existingContext.timestamp = nil
                        }
                    }
                }
            }))
        }
    }
    
    private func updateCachedPeerData(peerId: PeerId, accountPeerId: PeerId, viewId: Int32, hasCachedData: Bool) {
        self.queue.async {
            let context: PeerCachedDataContext
            var dataUpdated = false
            if let existingContext = self.cachedDataContexts[peerId] {
                context = existingContext
                context.hasCachedData = hasCachedData
                if context.timestamp == nil || abs(CFAbsoluteTimeGetCurrent() - context.timestamp!) > 60.0 * 5 {
                    context.timestamp = CFAbsoluteTimeGetCurrent()
                    dataUpdated = true
                }
            } else {
                context = PeerCachedDataContext()
                context.hasCachedData = hasCachedData
                self.cachedDataContexts[peerId] = context
                if !context.hasCachedData || context.timestamp == nil || abs(CFAbsoluteTimeGetCurrent() - context.timestamp!) > 60.0 * 5 {
                    context.timestamp = CFAbsoluteTimeGetCurrent()
                    dataUpdated = true
                }
            }
            context.viewIds.insert(viewId)
            
            if dataUpdated {
                guard let account = self.account else {
                    return
                }
                let queue = self.queue
                context.disposable.set(combineLatest(fetchAndUpdateSupplementalCachedPeerData(peerId: peerId, accountPeerId: accountPeerId, network: account.network, postbox: account.postbox), _internal_fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)).start(next: { [weak self] supplementalStatus, cachedStatus in
                    queue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        if !supplementalStatus || !cachedStatus {
                            if let existingContext = strongSelf.cachedDataContexts[peerId] {
                                existingContext.timestamp = nil
                            }
                        }
                    }
                }))
            }
        }
    }
    
    private func removePeerView(peerId: PeerId, id: Int32) {
        self.queue.async {
            if let context = self.cachedDataContexts[peerId] {
                context.viewIds.remove(id)
                if context.viewIds.isEmpty {
                    context.disposable.set(nil)
                    context.hasCachedData = false
                }
            }
        }
    }
    
    public func polledChannel(peerId: PeerId) -> Signal<Void, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                let context: ChannelPollingContext
                if let current = self.channelPollingContexts[peerId] {
                    context = current
                } else {
                    context = ChannelPollingContext(queue: self.queue)
                    self.channelPollingContexts[peerId] = context
                }
                
                if context.subscribers.isEmpty {
                    if let account = self.account {
                        let queue = self.queue
                        context.disposable.set(keepPollingChannel(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, peerId: peerId, stateManager: account.stateManager).start(next: { [weak context] isValidForTimeout in
                            queue.async {
                                guard let context = context else {
                                    return
                                }
                                context.isUpdated.set(
                                    .single(true)
                                    |> then(
                                        .single(false)
                                        |> delay(Double(isValidForTimeout), queue: queue)
                                    )
                                )
                            }
                        }))
                    }
                }
                
                let index = context.subscribers.add(Void())
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        if let context = self.channelPollingContexts[peerId] {
                            context.subscribers.remove(index)
                            if context.subscribers.isEmpty {
                                context.disposable.set(nil)
                            }
                        }
                    }
                })
            }
            
            return disposable
        }
    }
    
    func wrappedMessageHistorySignal(chatLocation: ChatLocationInput, signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>, fixedCombinedReadStates: MessageHistoryViewReadState?, addHoleIfNeeded: Bool) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        var signal = signal
        if let postbox = self.account?.postbox, let peerId = chatLocation.peerId, let threadId = chatLocation.threadId {
            let viewKey: PostboxViewKey = .messageHistoryThreadInfo(peerId: peerId, threadId: threadId)
            let fixedReadStates = Atomic<MessageHistoryViewReadState?>(value: nil)
            signal = combineLatest(signal, postbox.combinedView(keys: [viewKey]))
            |> map { view, additionalViews -> (MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?) in
                var view = view
                if let threadInfo = additionalViews.views[viewKey] as? MessageHistoryThreadInfoView, let data = threadInfo.info?.data.get(MessageHistoryThreadData.self) {
                    let readState = CombinedPeerReadState(states: [(Namespaces.Message.Cloud, .idBased(maxIncomingReadId: data.maxIncomingReadId, maxOutgoingReadId: data.maxOutgoingReadId, maxKnownId: data.maxKnownMessageId, count: data.incomingUnreadCount, markedUnread: false))])
                    
                    let fixed: MessageHistoryViewReadState?
                    if let fixedCombinedReadStates = fixedCombinedReadStates {
                        fixed = fixedCombinedReadStates
                    } else {
                        fixed = fixedReadStates.modify { current in
                            if let current = current {
                                return current
                            } else {
                                return .peer([peerId: readState])
                            }
                        }
                    }
                    
                    view.0 = MessageHistoryView(
                        base: view.0,
                        fixed: fixed,
                        transient: .peer([peerId: readState])
                    )
                }
                
                return view
            }
        }
        
        let history = withState(signal, { [weak self] () -> Int32 in
            if let strongSelf = self {
                return OSAtomicIncrement32(&strongSelf.nextViewId)
            } else {
                return -1
            }
        }, next: { [weak self] next, viewId in
            if let strongSelf = self {
                strongSelf.queue.async {
                    let (messageIds, localWebpages) = pendingWebpages(entries: next.0.entries)
                    strongSelf.updatePendingWebpages(viewId: viewId, messageIds: messageIds, localWebpages: localWebpages)
                    let (pollMessageIds, pollMessageDict) = pollMessages(entries: next.0.entries)
                    strongSelf.updatePolls(viewId: viewId, messageIds: pollMessageIds, messages: pollMessageDict)
                    if case let .peer(peerId, _) = chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel {
                        strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: next.0)
                    } else if case let .thread(peerId, _, _) = chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel {
                        strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: next.0, location: chatLocation)
                    }
                }
            }
        }, disposed: { [weak self] viewId in
            if let strongSelf = self {
                strongSelf.queue.async {
                    strongSelf.updatePendingWebpages(viewId: viewId, messageIds: [], localWebpages: [:])
                    strongSelf.updatePolls(viewId: viewId, messageIds: [], messages: [:])
                    switch chatLocation {
                    case let .peer(peerId, _):
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: nil)
                        }
                    case let .thread(peerId, _, _):
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: nil, location: chatLocation)
                        }
                    case .feed:
                        break
                    }
                }
            }
        })
        
        let peerId: PeerId?
        switch chatLocation {
        case let .peer(peerIdValue, _):
            peerId = peerIdValue
        case let .thread(peerIdValue, _, _):
            peerId = peerIdValue
        case .feed:
            peerId = nil
        }
        if let peerId = peerId, peerId.namespace == Namespaces.Peer.CloudChannel {
            return Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> { subscriber in
                let combinedDisposable = MetaDisposable()
                self.queue.async {
                    let polled = self.polledChannel(peerId: peerId).start()

                    var addHole = false
                    let pollingCompleted: Signal<Bool, NoError>
                    if let context = self.channelPollingContexts[peerId] {
                        if !context.isUpdatedValue {
                            addHole = true
                        }
                        pollingCompleted = context.isUpdated.get()
                    } else {
                        addHole = true
                        pollingCompleted = .single(true)
                    }
                    let isAutomaticallyTracked = self.account!.postbox.transaction { transaction -> Bool in
                        if transaction.getPeerChatListIndex(peerId) == nil {
                            if addHole {
                                transaction.addHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                            }
                            return false
                        } else {
                            return true
                        }
                    }

                    let historyIsValid = combineLatest(queue: self.queue,
                        pollingCompleted,
                        isAutomaticallyTracked
                    )
                    |> map { lhs, rhs -> Bool in
                        return lhs || rhs
                    }

                    var loaded = false
                    let validHistory = historyIsValid
                    |> distinctUntilChanged
                    |> take(until: { next in
                        if next {
                            return SignalTakeAction(passthrough: true, complete: true)
                        } else {
                            return SignalTakeAction(passthrough: true, complete: false)
                        }
                    })
                    |> mapToSignal { isValid -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> in
                        if isValid {
                            assert(!loaded)
                            loaded = true
                            return history
                        } else {
                            let view = MessageHistoryView(tagMask: nil, namespaces: .all, entries: [], holeEarlier: true, holeLater: true, isLoading: true)
                            return .single((view, .Initial, nil))
                        }
                    }

                    let disposable = validHistory.start(next: { next in
                        subscriber.putNext(next)
                    }, completed: {
                        subscriber.putCompletion()
                    })

                    combinedDisposable.set(ActionDisposable {
                        disposable.dispose()
                        polled.dispose()
                    })
                }
                return combinedDisposable
            }
        } else {
            return history
        }
    }
    
    public func scheduledMessagesViewForLocation(_ chatLocation: ChatLocationInput, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundMessageHistoryViewForLocation(chatLocation, anchor: .upperBound, ignoreMessagesInTimestampRange: nil, count: 200, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: nil, appendMessagesFromTheSameGroup: false, namespaces: .just(Namespaces.Message.allScheduled), orderStatistics: [], additionalData: additionalData)
            return withState(signal, { [weak self] () -> Int32 in
                if let strongSelf = self {
                    return OSAtomicIncrement32(&strongSelf.nextViewId)
                } else {
                    return -1
                }
            }, next: { [weak self] next, viewId in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        let (messageIds, localWebpages) = pendingWebpages(entries: next.0.entries)
                        strongSelf.updatePendingWebpages(viewId: viewId, messageIds: messageIds, localWebpages: localWebpages)
                        strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: next.0, location: chatLocation)
                    }
                }
            }, disposed: { [weak self] viewId in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.updatePendingWebpages(viewId: viewId, messageIds: [], localWebpages: [:])
                        strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: nil)
                    }
                }
            })
        } else {
            return .never()
        }
    }
    
    public func aroundMessageOfInterestHistoryViewForLocation(_ chatLocation: ChatLocationInput, ignoreMessagesInTimestampRange: ClosedRange<Int32>? = nil, count: Int, tagMask: MessageTags? = nil, appendMessagesFromTheSameGroup: Bool = false, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
            if let peerId = chatLocation.peerId, let threadId = chatLocation.threadId, tagMask == nil {
                signal = account.postbox.transaction { transaction -> MessageHistoryThreadData? in
                    return transaction.getMessageHistoryThreadInfo(peerId: peerId, threadId: threadId)?.data.get(MessageHistoryThreadData.self)
                }
                |> mapToSignal { threadInfo -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> in
                    if let threadInfo = threadInfo {
                        let anchor: HistoryViewInputAnchor
                        if threadInfo.incomingUnreadCount > 0 && tagMask == nil {
                            let customUnreadMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: threadInfo.maxIncomingReadId)
                            anchor = .message(customUnreadMessageId)
                        } else {
                            anchor = .upperBound
                        }
                        
                        return account.postbox.aroundMessageHistoryViewForLocation(
                            chatLocation,
                            anchor: anchor,
                            ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange,
                            count: count,
                            fixedCombinedReadStates: nil,
                            topTaggedMessageIdNamespaces: [],
                            tagMask: tagMask,
                            appendMessagesFromTheSameGroup: false,
                            namespaces: .not(Namespaces.Message.allScheduled),
                            orderStatistics: orderStatistics
                        )
                    }
                    
                    return account.postbox.aroundMessageOfInterestHistoryViewForChatLocation(chatLocation, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, count: count, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: orderStatistics, customUnreadMessageId: nil, additionalData: wrappedHistoryViewAdditionalData(chatLocation: chatLocation, additionalData: additionalData))
                }
            } else {
                signal = account.postbox.aroundMessageOfInterestHistoryViewForChatLocation(chatLocation, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, count: count, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: orderStatistics, customUnreadMessageId: nil, additionalData: wrappedHistoryViewAdditionalData(chatLocation: chatLocation, additionalData: additionalData))
            }
            return wrappedMessageHistorySignal(chatLocation: chatLocation, signal: signal, fixedCombinedReadStates: nil, addHoleIfNeeded: true)
        } else {
            return .never()
        }
    }
    
    public func aroundIdMessageHistoryViewForLocation(_ chatLocation: ChatLocationInput, ignoreMessagesInTimestampRange: ClosedRange<Int32>? = nil, count: Int, ignoreRelatedChats: Bool, messageId: MessageId, tagMask: MessageTags? = nil, appendMessagesFromTheSameGroup: Bool = false, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundIdMessageHistoryViewForLocation(chatLocation, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, count: count, ignoreRelatedChats: ignoreRelatedChats, messageId: messageId, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: orderStatistics, additionalData: wrappedHistoryViewAdditionalData(chatLocation: chatLocation, additionalData: additionalData))
            return wrappedMessageHistorySignal(chatLocation: chatLocation, signal: signal, fixedCombinedReadStates: nil, addHoleIfNeeded: false)
        } else {
            return .never()
        }
    }
    
    public func aroundMessageHistoryViewForLocation(_ chatLocation: ChatLocationInput, ignoreMessagesInTimestampRange: ClosedRange<Int32>? = nil, index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int, clipHoles: Bool = true, ignoreRelatedChats: Bool = false, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags? = nil, appendMessagesFromTheSameGroup: Bool = false, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let inputAnchor: HistoryViewInputAnchor
            switch index {
                case .upperBound:
                    inputAnchor = .upperBound
                case .lowerBound:
                    inputAnchor = .lowerBound
                case let .message(index):
                    inputAnchor = .index(index)
            }
            let signal = account.postbox.aroundMessageHistoryViewForLocation(chatLocation, anchor: inputAnchor, ignoreMessagesInTimestampRange: ignoreMessagesInTimestampRange, count: count, clipHoles: clipHoles, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: fixedCombinedReadStates, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, appendMessagesFromTheSameGroup: appendMessagesFromTheSameGroup, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: orderStatistics, additionalData: wrappedHistoryViewAdditionalData(chatLocation: chatLocation, additionalData: additionalData))
            return wrappedMessageHistorySignal(chatLocation: chatLocation, signal: signal, fixedCombinedReadStates: fixedCombinedReadStates, addHoleIfNeeded: false)
        } else {
            return .never()
        }
    }
    
    func wrappedPeerViewSignal(peerId: PeerId, signal: Signal<PeerView, NoError>, updateData: Bool) -> Signal<PeerView, NoError> {
        if updateData {
            self.queue.async {
                if let existingContext = self.cachedDataContexts[peerId] {
                    existingContext.timestamp = nil
                }
            }
        }
        
        return withState(signal, { [weak self] () -> Int32 in
            if let strongSelf = self {
                return OSAtomicIncrement32(&strongSelf.nextViewId)
            } else {
                return -1
            }
        }, next: { [weak self] next, viewId in
            if let strongSelf = self, let account = strongSelf.account {
                strongSelf.updateCachedPeerData(peerId: peerId, accountPeerId: account.peerId, viewId: viewId, hasCachedData: next.cachedData != nil)
            }
        }, disposed: { [weak self] viewId in
            if let strongSelf = self {
                strongSelf.removePeerView(peerId: peerId, id: viewId)
            }
        })
    }
    
    public func peerView(_ peerId: PeerId, updateData: Bool = false) -> Signal<PeerView, NoError> {
        if let account = self.account {
            return wrappedPeerViewSignal(peerId: peerId, signal: account.postbox.peerView(id: peerId), updateData: updateData)
        } else {
            return .never()
        }
    }
    
    public func featuredStickerPacks() -> Signal<[FeaturedStickerPackItem], NoError> {
        return Signal { subscriber in
            if let account = self.account {
                let view = account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)]).start(next: { next in
                    if let view = next.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)] as? OrderedItemListView {
                        subscriber.putNext(view.items.map { $0.contents.get(FeaturedStickerPackItem.self)! })
                    } else {
                        subscriber.putNext([])
                    }
                }, completed: {
                    subscriber.putCompletion()
                })
                let disposable = MetaDisposable()
                self.queue.async {
                    let context: FeaturedStickerPacksContext
                    if let current = self.featuredStickerPacksContext {
                        context = current
                    } else {
                        context = FeaturedStickerPacksContext()
                        self.featuredStickerPacksContext = context
                    }
                    
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    if context.timestamp == nil || abs(context.timestamp! - timestamp) > 60.0 * 60.0 {
                        context.timestamp = timestamp
                        context.disposable.set(updatedFeaturedStickerPacks(network: account.network, postbox: account.postbox, category: .stickerPacks).start())
                    }
                    
                    let index = context.subscribers.add(Void())
                    
                    disposable.set(ActionDisposable {
                        self.queue.async {
                            if let context = self.featuredStickerPacksContext {
                                context.subscribers.remove(index)
                            }
                        }
                    })
                }
                return ActionDisposable {
                    view.dispose()
                    disposable.dispose()
                }
            } else {
                subscriber.putNext([])
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
    }
    
    public func featuredEmojiPacks() -> Signal<[FeaturedStickerPackItem], NoError> {
        return Signal { subscriber in
            if let account = self.account {
                let view = account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)]).start(next: { next in
                    if let view = next.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)] as? OrderedItemListView {
                        subscriber.putNext(view.items.map { $0.contents.get(FeaturedStickerPackItem.self)! })
                    } else {
                        subscriber.putNext([])
                    }
                }, completed: {
                    subscriber.putCompletion()
                })
                let disposable = MetaDisposable()
                self.queue.async {
                    let context: FeaturedStickerPacksContext
                    if let current = self.featuredEmojiPacksContext {
                        context = current
                    } else {
                        context = FeaturedStickerPacksContext()
                        self.featuredEmojiPacksContext = context
                    }
                    
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    if context.timestamp == nil || abs(context.timestamp! - timestamp) > 60.0 * 60.0 {
                        context.timestamp = timestamp
                        context.disposable.set(updatedFeaturedStickerPacks(network: account.network, postbox: account.postbox, category: .emojiPacks).start())
                    }
                    
                    let index = context.subscribers.add(Void())
                    
                    disposable.set(ActionDisposable {
                        self.queue.async {
                            if let context = self.featuredEmojiPacksContext {
                                context.subscribers.remove(index)
                            }
                        }
                    })
                }
                return ActionDisposable {
                    view.dispose()
                    disposable.dispose()
                }
            } else {
                subscriber.putNext([])
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
    }
    
    public func callListView(type: CallListViewType, index: MessageIndex, count: Int) -> Signal<CallListView, NoError> {
        if let account = self.account {
            let granularity: Int32 = 60 * 60 * 24
            let timezoneOffset: Int32 = {
                let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                var now: time_t = time_t(nowTimestamp)
                var timeinfoNow: tm = tm()
                localtime_r(&now, &timeinfoNow)
                return Int32(timeinfoNow.tm_gmtoff)
            }()
            
            let groupingPredicate: (Message, Message) -> Bool = { lhs, rhs in
                if lhs.id.peerId != rhs.id.peerId {
                    return false
                }
                let lhsTimestamp = ((lhs.timestamp + timezoneOffset) / (granularity)) * (granularity)
                let rhsTimestamp = ((rhs.timestamp + timezoneOffset) / (granularity)) * (granularity)
                if lhsTimestamp != rhsTimestamp {
                    return false
                }
                var lhsVideo = false
                var lhsMissed = false
                var lhsOther = false
                inner: for media in lhs.media {
                    if let action = media as? TelegramMediaAction {
                        if case let .phoneCall(_, discardReason, _, video) = action.action {
                            lhsVideo = video
                            if lhs.flags.contains(.Incoming), let discardReason = discardReason, case .missed = discardReason {
                                lhsMissed = true
                            } else {
                                lhsOther = true
                            }
                            break inner
                        }
                    }
                }
                var rhsVideo = false
                var rhsMissed = false
                var rhsOther = false
                inner: for media in rhs.media {
                    if let action = media as? TelegramMediaAction {
                        if case let .phoneCall(_, discardReason, _, video) = action.action {
                            rhsVideo = video
                            if rhs.flags.contains(.Incoming), let discardReason = discardReason, case .missed = discardReason {
                                rhsMissed = true
                            } else {
                                rhsOther = true
                            }
                            break inner
                        }
                    }
                }
                if lhsMissed != rhsMissed || lhsOther != rhsOther || lhsVideo != rhsVideo {
                    return false
                }
                return true
            }
            
            let key = PostboxViewKey.globalMessageTags(globalTag: type == .all ? GlobalMessageTags.Calls : GlobalMessageTags.MissedCalls, position: index, count: count, groupingPredicate: groupingPredicate)
            let signal = account.postbox.combinedView(keys: [key]) |> map { view -> GlobalMessageTagsView in
                let messageView = view.views[key] as! GlobalMessageTagsView
                return messageView
            }
            
            let managed = withState(signal, { [weak self] () -> Int32 in
                if let strongSelf = self {
                    return OSAtomicIncrement32(&strongSelf.nextViewId)
                } else {
                    return -1
                }
            }, next: { [weak self] next, viewId in
                if let strongSelf = self {
                    var holes = Set<MessageIndex>()
                    for entry in next.entries {
                        if case let .hole(index) = entry {
                            holes.insert(index)
                        }
                    }
                    strongSelf.updateVisibleCallListHoles(viewId: viewId, holeIds: holes)
                }
            }, disposed: { [weak self] viewId in
                if let strongSelf = self {
                    strongSelf.updateVisibleCallListHoles(viewId: viewId, holeIds: Set())
                }
            })
            
            return managed
            |> map { view -> CallListView in
                var entries: [CallListViewEntry] = []
                if !view.entries.isEmpty {
                    var currentMessages: [Message] = []
                    for entry in view.entries {
                        switch entry {
                            case .hole:
                                if !currentMessages.isEmpty {
                                    entries.append(.message(currentMessages[currentMessages.count - 1], currentMessages))
                                    currentMessages.removeAll()
                                }
                                //entries.append(.hole(index))
                            case let .message(message):
                                if currentMessages.isEmpty || groupingPredicate(message, currentMessages[currentMessages.count - 1]) {
                                    currentMessages.append(message)
                                } else {
                                    if !currentMessages.isEmpty {
                                        entries.append(.message(currentMessages[currentMessages.count - 1], currentMessages))
                                        currentMessages.removeAll()
                                    }
                                    currentMessages.append(message)
                                }
                        }
                    }
                    if !currentMessages.isEmpty {
                        entries.append(.message(currentMessages[currentMessages.count - 1], currentMessages))
                        currentMessages.removeAll()
                    }
                }
                return CallListView(entries: entries, earlier: view.earlier, later: view.later)
            }
        } else {
            return .never()
        }
    }
    
    public func unseenPersonalMessagesAndReactionCount(peerId: PeerId, threadId: Int64?) -> Signal<(mentionCount: Int32, reactionCount: Int32), NoError> {
        if let account = self.account {
            let pendingMentionsKey: PostboxViewKey = .pendingMessageActionsSummary(type: .consumeUnseenPersonalMessage, peerId: peerId, namespace: Namespaces.Message.Cloud)
            let summaryMentionsKey: PostboxViewKey = .historyTagSummaryView(tag: .unseenPersonalMessage, peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud)
            
            let pendingReactionsKey: PostboxViewKey = .pendingMessageActionsSummary(type: .readReaction, peerId: peerId, namespace: Namespaces.Message.Cloud)
            let summaryReactionsKey: PostboxViewKey = .historyTagSummaryView(tag: .unseenReaction, peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud)
            
            return account.postbox.combinedView(keys: [pendingMentionsKey, summaryMentionsKey, pendingReactionsKey, summaryReactionsKey])
            |> map { views -> (mentionCount: Int32, reactionCount: Int32) in
                var mentionCount: Int32 = 0
                if let view = views.views[pendingMentionsKey] as? PendingMessageActionsSummaryView {
                    mentionCount -= view.count
                }
                if let view = views.views[summaryMentionsKey] as? MessageHistoryTagSummaryView {
                    if let unseenCount = view.count {
                        mentionCount += unseenCount
                    }
                }
                var reactionCount: Int32 = 0
                /*if let view = views.views[pendingReactionsKey] as? PendingMessageActionsSummaryView {
                    reactionCount -= view.count
                }*/
                if let view = views.views[summaryReactionsKey] as? MessageHistoryTagSummaryView {
                    if let unseenCount = view.count {
                        reactionCount += unseenCount
                    }
                }
                return (max(0, mentionCount), max(0, reactionCount))
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs.mentionCount != rhs.mentionCount {
                    return false
                }
                if lhs.reactionCount != rhs.reactionCount {
                    return false
                }
                return true
            })
        } else {
            return .never()
        }
    }
    
    private func wrappedChatListView(signal: Signal<(ChatListView, ViewUpdateType), NoError>) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return withState(signal, { [weak self] () -> Int32 in
            if let strongSelf = self {
                return OSAtomicIncrement32(&strongSelf.nextViewId)
            } else {
                return -1
            }
        }, next: { [weak self] next, viewId in
            if let strongSelf = self {
                strongSelf.queue.async {
                    
                }
            }
        }, disposed: { [weak self] viewId in
            if let strongSelf = self {
                strongSelf.queue.async {
                    
                }
            }
        })
    }
    
    public func tailChatListView(groupId: PeerGroupId, filterPredicate: ChatListFilterPredicate? = nil, count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        if let account = self.account {
            return self.wrappedChatListView(signal: account.postbox.tailChatListView(
                groupId: groupId,
                filterPredicate: filterPredicate,
                count: count,
                summaryComponents: ChatListEntrySummaryComponents(
                    components: [
                        ChatListEntryMessageTagSummaryKey(
                            tag: .unseenPersonalMessage,
                            actionType: PendingMessageActionType.consumeUnseenPersonalMessage
                        ): ChatListEntrySummaryComponents.Component(
                            tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                            actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                        ),
                        ChatListEntryMessageTagSummaryKey(
                            tag: .unseenReaction,
                            actionType: PendingMessageActionType.readReaction
                        ): ChatListEntrySummaryComponents.Component(
                            tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                            actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                        )
                    ]
                )
            ))
        } else {
            return .never()
        }
    }
    
    public func aroundChatListView(groupId: PeerGroupId, filterPredicate: ChatListFilterPredicate? = nil, index: ChatListIndex, count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        if let account = self.account {
            return self.wrappedChatListView(signal: account.postbox.aroundChatListView(
                groupId: groupId,
                filterPredicate: filterPredicate,
                index: index,
                count: count,
                summaryComponents: ChatListEntrySummaryComponents(
                    components: [
                        ChatListEntryMessageTagSummaryKey(
                            tag: .unseenPersonalMessage,
                            actionType: PendingMessageActionType.consumeUnseenPersonalMessage
                        ): ChatListEntrySummaryComponents.Component(
                            tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                            actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                        ),
                        ChatListEntryMessageTagSummaryKey(
                            tag: .unseenReaction,
                            actionType: PendingMessageActionType.readReaction
                        ): ChatListEntrySummaryComponents.Component(
                            tagSummary: ChatListEntryMessageTagSummaryComponent(namespace: Namespaces.Message.Cloud),
                            actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(namespace: Namespaces.Message.Cloud)
                        )
                    ]
                )
            ))
        } else {
            return .never()
        }
    }
}
