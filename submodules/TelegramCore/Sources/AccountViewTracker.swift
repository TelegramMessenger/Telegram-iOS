import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

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
                    case let .messagesSlice(_, _, _, messages: apiMessages, chats: apiChats, users: apiUsers):
                        messages = apiMessages
                        chats = apiChats
                        users = apiUsers
                    case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
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
                    var peerPresences: [PeerId: PeerPresence] = [:]
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            peers.append(groupOrChannel)
                        }
                    }
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        if let presence = TelegramUserPresence(apiUser: user) {
                            peerPresences[telegramUser.id] = presence
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

private func wrappedHistoryViewAdditionalData(chatLocation: ChatLocation, additionalData: [AdditionalMessageHistoryViewData]) -> [AdditionalMessageHistoryViewData] {
    var result = additionalData
    switch chatLocation {
        case let .peer(peerId):
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                if result.firstIndex(where: { if case .peerChatState = $0 { return true } else { return false } }) == nil {
                    result.append(.peerChatState(peerId))
                }
            }
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
    
    deinit {
        self.disposable.dispose()
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
    
    private var updatedViewCountMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextUpdatedViewCountDisposableId: Int32 = 0
    private var updatedViewCountDisposables = DisposableDict<Int32>()
    
    private var updatedSeenLiveLocationMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextSeenLiveLocationDisposableId: Int32 = 0
    private var seenLiveLocationDisposables = DisposableDict<Int32>()
    
    private var updatedUnsupportedMediaMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextUpdatedUnsupportedMediaDisposableId: Int32 = 0
    private var updatedUnsupportedMediaDisposables = DisposableDict<Int32>()
    
    private var updatedSeenPersonalMessageIds = Set<MessageId>()
    
    private var cachedDataContexts: [PeerId: PeerCachedDataContext] = [:]
    private var cachedChannelParticipantsContexts: [PeerId: CachedChannelParticipantsContext] = [:]
    
    private var channelPollingContexts: [PeerId: ChannelPollingContext] = [:]
    private var featuredStickerPacksContext: FeaturedStickerPacksContext?
    
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
                                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: media))
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
    
    public func updateViewCountForMessageIds(messageIds: Set<MessageId>) {
        self.queue.async {
            var addedMessageIds: [MessageId] = []
            let timestamp = Int32(CFAbsoluteTimeGetCurrent())
            for messageId in messageIds {
                let messageTimestamp = self.updatedViewCountMessageIdsAndTimestamps[messageId]
                if messageTimestamp == nil || messageTimestamp! < timestamp - 5 * 60 {
                    self.updatedViewCountMessageIdsAndTimestamps[messageId] = timestamp
                    addedMessageIds.append(messageId)
                }
            }
            if !addedMessageIds.isEmpty {
                for (peerId, messageIds) in messagesIdsGroupedByPeerId(Set(addedMessageIds)) {
                    let disposableId = self.nextUpdatedViewCountDisposableId
                    self.nextUpdatedViewCountDisposableId += 1
                    
                    if let account = self.account {
                        let signal = (account.postbox.transaction { transaction -> Signal<Void, NoError> in
                            if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                                return account.network.request(Api.functions.messages.getMessagesViews(peer: inputPeer, id: messageIds.map { $0.id }, increment: .boolTrue))
                                    |> map(Optional.init)
                                    |> `catch` { _ -> Signal<[Int32]?, NoError> in
                                        return .single(nil)
                                    }
                                    |> mapToSignal { viewCounts -> Signal<Void, NoError> in
                                        if let viewCounts = viewCounts {
                                            return account.postbox.transaction { transaction -> Void in
                                                for i in 0 ..< messageIds.count {
                                                    if i < viewCounts.count {
                                                        transaction.updateMessage(messageIds[i], update: { currentMessage in
                                                            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                                            var attributes = currentMessage.attributes
                                                            loop: for j in 0 ..< attributes.count {
                                                                if let attribute = attributes[j] as? ViewCountMessageAttribute {
                                                                    if attribute.count >= Int(viewCounts[i]) {
                                                                        return .skip
                                                                    }
                                                                    attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(viewCounts[i])))
                                                                    break loop
                                                                }
                                                            }
                                                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                                                        })
                                                    }
                                                }
                                            }
                                        } else {
                                            return .complete()
                                        }
                                    }
                            } else {
                                return .complete()
                            }
                        } |> switchToLatest)
                        |> afterDisposed { [weak self] in
                            self?.queue.async {
                                self?.updatedViewCountDisposables.set(nil, forKey: disposableId)
                            }
                        }
                        self.updatedViewCountDisposables.set(signal.start(), forKey: disposableId)
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
                                    case let .messagesSlice(_, _, _, messages, chats, users):
                                        return (messages, chats, users)
                                    case let .channelMessages(_, _, _, messages, chats, users):
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
                                    var peerPresences: [PeerId: PeerPresence] = [:]
                                    
                                    for chat in chats {
                                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                            peers.append(groupOrChannel)
                                        }
                                    }
                                    for user in users {
                                        let telegramUser = TelegramUser(user: user)
                                        peers.append(telegramUser)
                                        if let presence = TelegramUserPresence(apiUser: user) {
                                            peerPresences[telegramUser.id] = presence
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
    
    public func updateMarkAllMentionsSeen(peerId: PeerId) {
        self.queue.async {
            guard let account = self.account else {
                return
            }
            let _ = (account.postbox.transaction { transaction -> Set<MessageId> in
                let ids = Set(transaction.getMessageIndicesWithTag(peerId: peerId, namespace: Namespaces.Message.Cloud, tag: .unseenPersonalMessage).map({ $0.id }))
                if let summary = transaction.getMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud), summary.count > 0 {
                    var maxId: Int32 = summary.range.maxId
                    if let index = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                        maxId = index.id.id
                    }
                    
                    transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: 0, maxId: maxId)
                    addSynchronizeMarkAllUnseenPersonalMessagesOperation(transaction: transaction, peerId: peerId, maxId: summary.range.maxId)
                }
                
                return ids
            }
            |> deliverOn(self.queue)).start(next: { [weak self] messageIds in
                //self?.updateMarkMentionsSeenForMessageIds(messageIds: messageIds)
            })
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
                                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
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
            context.disposable.set(combineLatest(fetchAndUpdateSupplementalCachedPeerData(peerId: peerId, network: account.network, postbox: account.postbox), fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)).start(next: { [weak self] supplementalStatus, cachedStatus in
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
    
    private func updateCachedPeerData(peerId: PeerId, viewId: Int32, hasCachedData: Bool) {
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
                context.disposable.set(combineLatest(fetchAndUpdateSupplementalCachedPeerData(peerId: peerId, network: account.network, postbox: account.postbox), fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: peerId, network: account.network, postbox: account.postbox)).start(next: { [weak self] supplementalStatus, cachedStatus in
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
    
    func polledChannel(peerId: PeerId) -> Signal<Void, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                let context: ChannelPollingContext
                if let current = self.channelPollingContexts[peerId] {
                    context = current
                } else {
                    context = ChannelPollingContext()
                    self.channelPollingContexts[peerId] = context
                }
                
                if context.subscribers.isEmpty {
                    if let account = self.account {
                        context.disposable.set(keepPollingChannel(postbox: account.postbox, network: account.network, peerId: peerId, stateManager: account.stateManager).start())
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
    
    func wrappedMessageHistorySignal(chatLocation: ChatLocation, signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>, addHoleIfNeeded: Bool) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
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
                    if case let .peer(peerId) = chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel {
                        strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: next.0)
                    }
                }
            }
        }, disposed: { [weak self] viewId in
            if let strongSelf = self {
                strongSelf.queue.async {
                    strongSelf.updatePendingWebpages(viewId: viewId, messageIds: [], localWebpages: [:])
                    strongSelf.updatePolls(viewId: viewId, messageIds: [], messages: [:])
                    switch chatLocation {
                        case let .peer(peerId):
                            if peerId.namespace == Namespaces.Peer.CloudChannel {
                                strongSelf.historyViewStateValidationContexts.updateView(id: viewId, view: nil)
                            }
                    }
                }
            }
        })
        
        if case let .peer(peerId) = chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel {
            return Signal { subscriber in
                let combinedDisposable = MetaDisposable()
                self.queue.async {
                    var addHole = false
                    if let context = self.channelPollingContexts[peerId] {
                        if context.subscribers.isEmpty {
                            addHole = true
                        }
                    } else {
                        addHole = true
                    }
                    if addHole {
                        let _ = self.account?.postbox.transaction({ transaction -> Void in
                            if transaction.getPeerChatListIndex(peerId) == nil {
                                if let message = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                                    transaction.addHole(peerId: peerId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: message.id + 1 ... (Int32.max - 1))
                                }
                            }
                        }).start()
                    }
                    let disposable = history.start(next: { next in
                        subscriber.putNext(next)
                    }, error: { error in
                        subscriber.putError(error)
                    }, completed: {
                        subscriber.putCompletion()
                    })
                    let polled = self.polledChannel(peerId: peerId).start()
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
    
    public func scheduledMessagesViewForLocation(_ chatLocation: ChatLocation, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundMessageHistoryViewForLocation(chatLocation, anchor: .upperBound, count: 200, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: nil, namespaces: .just(Namespaces.Message.allScheduled), orderStatistics: [], additionalData: additionalData)
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
    
    public func aroundMessageOfInterestHistoryViewForLocation(_ chatLocation: ChatLocation, count: Int, tagMask: MessageTags? = nil, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundMessageOfInterestHistoryViewForChatLocation(chatLocation, count: count, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: orderStatistics, additionalData: wrappedHistoryViewAdditionalData(chatLocation: chatLocation, additionalData: additionalData))
            return wrappedMessageHistorySignal(chatLocation: chatLocation, signal: signal, addHoleIfNeeded: true)
        } else {
            return .never()
        }
    }
    
    public func aroundIdMessageHistoryViewForLocation(_ chatLocation: ChatLocation, count: Int, messageId: MessageId, tagMask: MessageTags? = nil, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundIdMessageHistoryViewForLocation(chatLocation, count: count, messageId: messageId, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: orderStatistics, additionalData: wrappedHistoryViewAdditionalData(chatLocation: chatLocation, additionalData: additionalData))
            return wrappedMessageHistorySignal(chatLocation: chatLocation, signal: signal, addHoleIfNeeded: false)
        } else {
            return .never()
        }
    }
    
    public func aroundMessageHistoryViewForLocation(_ chatLocation: ChatLocation, index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int, clipHoles: Bool = true, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags? = nil, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
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
            let signal = account.postbox.aroundMessageHistoryViewForLocation(chatLocation, anchor: inputAnchor, count: count, clipHoles: clipHoles, fixedCombinedReadStates: fixedCombinedReadStates, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, namespaces: .not(Namespaces.Message.allScheduled), orderStatistics: orderStatistics, additionalData: wrappedHistoryViewAdditionalData(chatLocation: chatLocation, additionalData: additionalData))
            return wrappedMessageHistorySignal(chatLocation: chatLocation, signal: signal, addHoleIfNeeded: false)
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
            if let strongSelf = self {
                strongSelf.updateCachedPeerData(peerId: peerId, viewId: viewId, hasCachedData: next.cachedData != nil)
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
                        subscriber.putNext(view.items.map { $0.contents as! FeaturedStickerPackItem })
                    } else {
                        subscriber.putNext([])
                    }
                }, error: { error in
                    subscriber.putError(error)
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
                        context.disposable.set(updatedFeaturedStickerPacks(network: account.network, postbox: account.postbox).start())
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
                var lhsMissed = false
                var lhsOther = false
                inner: for media in lhs.media {
                    if let action = media as? TelegramMediaAction {
                        if case let .phoneCall(_, discardReason, _) = action.action {
                            if lhs.flags.contains(.Incoming), let discardReason = discardReason, case .missed = discardReason {
                                lhsMissed = true
                            } else {
                                lhsOther = true
                            }
                            break inner
                        }
                    }
                }
                var rhsMissed = false
                var rhsOther = false
                inner: for media in rhs.media {
                    if let action = media as? TelegramMediaAction {
                        if case let .phoneCall(_, discardReason, _) = action.action {
                            if rhs.flags.contains(.Incoming), let discardReason = discardReason, case .missed = discardReason {
                                rhsMissed = true
                            } else {
                                rhsOther = true
                            }
                            break inner
                        }
                    }
                }
                if lhsMissed != rhsMissed || lhsOther != rhsOther {
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
                            case let .hole(index):
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
    
    public func unseenPersonalMessagesCount(peerId: PeerId) -> Signal<Int32, NoError> {
        if let account = self.account {
            let pendingKey: PostboxViewKey = .pendingMessageActionsSummary(type: .consumeUnseenPersonalMessage, peerId: peerId, namespace: Namespaces.Message.Cloud)
            let summaryKey: PostboxViewKey = .historyTagSummaryView(tag: .unseenPersonalMessage, peerId: peerId, namespace: Namespaces.Message.Cloud)
            return account.postbox.combinedView(keys: [pendingKey, summaryKey])
            |> map { views -> Int32 in
                var count: Int32 = 0
                if let view = views.views[pendingKey] as? PendingMessageActionsSummaryView {
                    count -= view.count
                }
                if let view = views.views[summaryKey] as? MessageHistoryTagSummaryView {
                    if let unseenCount = view.count {
                        count += unseenCount
                    }
                }
                return max(0, count)
            } |> distinctUntilChanged
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
            return self.wrappedChatListView(signal: account.postbox.tailChatListView(groupId: groupId, filterPredicate: filterPredicate, count: count, summaryComponents: ChatListEntrySummaryComponents(tagSummary: ChatListEntryMessageTagSummaryComponent(tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud), actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(type: PendingMessageActionType.consumeUnseenPersonalMessage, namespace: Namespaces.Message.Cloud))))
        } else {
            return .never()
        }
    }
    
    public func aroundChatListView(groupId: PeerGroupId, filterPredicate: ChatListFilterPredicate? = nil, index: ChatListIndex, count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        if let account = self.account {
            return self.wrappedChatListView(signal: account.postbox.aroundChatListView(groupId: groupId, filterPredicate: filterPredicate, index: index, count: count, summaryComponents: ChatListEntrySummaryComponents(tagSummary: ChatListEntryMessageTagSummaryComponent(tag: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud), actionsSummary: ChatListEntryPendingMessageActionsSummaryComponent(type: PendingMessageActionType.consumeUnseenPersonalMessage, namespace: Namespaces.Message.Cloud))))
        } else {
            return .never()
        }
    }
}
