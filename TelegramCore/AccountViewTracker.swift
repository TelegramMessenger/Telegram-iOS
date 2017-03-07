import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private func pendingWebpages(entries: [MessageHistoryEntry]) -> Set<MessageId> {
    var messageIds = Set<MessageId>()
    for case let .MessageEntry(message, _, _) in entries {
        for media in message.media {
            if let media = media as? TelegramMediaWebpage {
                if case .Pending = media.content {
                    messageIds.insert(message.id)
                }
                break
            }
        }
    }
    return messageIds
}

private func fetchWebpage(account: Account, messageId: MessageId) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
        |> take(1)
        |> mapToSignal { peer in
            if let inputPeer = apiInputPeer(peer) {
                let messages: Signal<Api.messages.Messages, MTRpcError>
                switch inputPeer {
                    case let .inputPeerChannel(channelId, accessHash):
                        messages = account.network.request(Api.functions.channels.getMessages(channel: Api.InputChannel.inputChannel(channelId: channelId, accessHash: accessHash), id: [messageId.id]))
                    default:
                        messages = account.network.request(Api.functions.messages.getMessages(id: [messageId.id]))
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
                            case let .messagesSlice(_, messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                        }
                        
                        return account.postbox.modify { modifier -> Void in
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
                                if let storeMessage = StoreMessage(apiMessage: message) {
                                    var webpage: TelegramMediaWebpage?
                                    for media in storeMessage.media {
                                        if let media = media as? TelegramMediaWebpage {
                                            webpage = media
                                        }
                                    }
                                    
                                    if let webpage = webpage {
                                        modifier.updateMedia(webpage.webpageId, update: webpage)
                                    } else {
                                        if let previousMessage = modifier.getMessage(messageId) {
                                            for media in previousMessage.media {
                                                if let media = media as? TelegramMediaWebpage {
                                                    modifier.updateMedia(media.webpageId, update: nil)
                                                    
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    break
                                }
                            }
                            
                            updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                                return updated
                            })
                            modifier.updatePeerPresences(peerPresences)
                        }
                    }
            } else {
                return .complete()
            }
        }
}

private final class PeerCachedDataContext {
    var viewIds = Set<Int32>()
    var timestamp: Double?
    var referenceData: CachedPeerData?
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

public final class AccountViewTracker {
    weak var account: Account?
    private let queue = Queue()
    private var nextViewId: Int32 = 0
    
    private var viewPendingWebpageMessageIds: [Int32: Set<MessageId>] = [:]
    private var pendingWebpageMessageIds: [MessageId: Int] = [:]
    private var webpageDisposables: [MessageId: Disposable] = [:]
    
    private var updatedViewCountMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextUpdatedViewCountDisposableId: Int32 = 0
    private var updatedViewCountDisposables = DisposableDict<Int32>()
    
    private var cachedDataContexts: [PeerId: PeerCachedDataContext] = [:]
    private var cachedChannelParticipantsContexts: [PeerId: CachedChannelParticipantsContext] = [:]
    
    init(account: Account) {
        self.account = account
    }
    
    deinit {
        self.updatedViewCountDisposables.dispose()
    }
    
    private func updatePendingWebpages(viewId: Int32, messageIds: Set<MessageId>) {
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
                        self.webpageDisposables[messageId] = fetchWebpage(account: account, messageId: messageId).start(completed: { [weak self] in
                            if let strongSelf = self {
                                strongSelf.queue.async {
                                    strongSelf.webpageDisposables.removeValue(forKey: messageId)
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
    
    public func updatedViewCountMessageIds(messageIds: Set<MessageId>) {
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
                        let signal = (account.postbox.modify { modifier -> Signal<Void, NoError> in
                            if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                                return account.network.request(Api.functions.messages.getMessagesViews(peer: inputPeer, id: messageIds.map { $0.id }, increment: .boolTrue))
                                    |> map { Optional($0) }
                                    |> `catch` { _ -> Signal<[Int32]?, NoError> in
                                        return .single(nil)
                                    }
                                    |> mapToSignal { viewCounts -> Signal<Void, NoError> in
                                        if let viewCounts = viewCounts {
                                            return account.postbox.modify { modifier -> Void in
                                                for i in 0 ..< messageIds.count {
                                                    if i < viewCounts.count {
                                                        modifier.updateMessage(messageIds[i], update: { currentMessage in
                                                            var storeForwardInfo: StoreMessageForwardInfo?
                                                            if let forwardInfo = currentMessage.forwardInfo {
                                                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                                            }
                                                            var attributes = currentMessage.attributes
                                                            loop: for j in 0 ..< attributes.count {
                                                                if let attribute = attributes[j] as? ViewCountMessageAttribute {
                                                                    attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(viewCounts[i])))
                                                                    break loop
                                                                }
                                                            }
                                                            return StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media)
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
    
    private func updateCachedPeerData(peerId: PeerId, viewId: Int32, referenceData: CachedPeerData?) {
        self.queue.async {
            let context: PeerCachedDataContext
            var dataUpdated = false
            if let existingContext = self.cachedDataContexts[peerId] {
                context = existingContext
                context.referenceData = referenceData
                if context.timestamp == nil || abs(CFAbsoluteTimeGetCurrent() - context.timestamp!) > 60.0 * 60.0 {
                    dataUpdated = true
                }
            } else {
                context = PeerCachedDataContext()
                context.referenceData = referenceData
                self.cachedDataContexts[peerId] = context
                if context.referenceData == nil || context.timestamp == nil || abs(CFAbsoluteTimeGetCurrent() - context.timestamp!) > 60.0 * 60.0 {
                    context.timestamp = CFAbsoluteTimeGetCurrent()
                    dataUpdated = true
                }
            }
            context.viewIds.insert(viewId)
            
            if dataUpdated {
                if let account = self.account {
                    context.disposable.set(combineLatest(fetchAndUpdateSupplementalCachedPeerData(peerId: peerId, network: account.network, postbox: account.postbox), fetchAndUpdateCachedPeerData(peerId: peerId, network: account.network, postbox: account.postbox)).start())
                }
            }
        }
    }
    
    private func removePeerView(peerId: PeerId, id: Int32) {
        self.queue.async {
            if let context = self.cachedDataContexts[peerId] {
                context.viewIds.remove(id)
                if context.viewIds.isEmpty {
                    context.disposable.set(nil)
                    context.referenceData = nil
                }
            }
        }
    }
    
    func wrappedMessageHistorySignal(_ signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        return withState(signal, { [weak self] () -> Int32 in
            if let strongSelf = self {
                return OSAtomicIncrement32(&strongSelf.nextViewId)
            } else {
                return -1
            }
        }, next: { [weak self] next, viewId in
            if let strongSelf = self {
                let messageIds = pendingWebpages(entries: next.0.entries)
                strongSelf.updatePendingWebpages(viewId: viewId, messageIds: messageIds)
            }
        }, disposed: { [weak self] viewId in
            if let strongSelf = self {
                strongSelf.updatePendingWebpages(viewId: viewId, messageIds: [])
            }
        })
    }
    
    public func aroundUnreadMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, tagMask: MessageTags? = nil, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundUnreadMessageHistoryViewForPeerId(peerId, count: count, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, additionalData: additionalData)
            return wrappedMessageHistorySignal(signal)
        } else {
            return .never()
        }
    }
    
    public func aroundIdMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, messageId: MessageId, tagMask: MessageTags? = nil, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundIdMessageHistoryViewForPeerId(peerId, count: count, messageId: messageId, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, additionalData: additionalData)
            return wrappedMessageHistorySignal(signal)
        } else {
            return .never()
        }
    }
    
    public func aroundMessageHistoryViewForPeerId(_ peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageIndex, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags? = nil, additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundMessageHistoryViewForPeerId(peerId, index: index, count: count, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, additionalData: additionalData)
            return wrappedMessageHistorySignal(signal)
        } else {
            return .never()
        }
    }
    
    func wrappedPeerViewSignal(peerId: PeerId, signal: Signal<PeerView, NoError>) -> Signal<PeerView, NoError> {
        return withState(signal, { [weak self] () -> Int32 in
            if let strongSelf = self {
                return OSAtomicIncrement32(&strongSelf.nextViewId)
            } else {
                return -1
            }
        }, next: { [weak self] next, viewId in
            if let strongSelf = self {
                strongSelf.updateCachedPeerData(peerId: peerId, viewId: viewId, referenceData: next.cachedData)
            }
        }, disposed: { [weak self] viewId in
            if let strongSelf = self {
                strongSelf.removePeerView(peerId: peerId, id: viewId)
            }
        })
    }
    
    public func peerView(_ peerId: PeerId) -> Signal<PeerView, NoError> {
        if let account = self.account {
            return wrappedPeerViewSignal(peerId: peerId, signal: account.postbox.peerView(id: peerId))
        } else {
            return .never()
        }
    }
    
    public func updatedCachedChannelParticipants(_ peerId: PeerId, forceImmediateUpdate: Bool = false) -> Signal<Void, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            queue.async {
                if let strongSelf = self {
                    let context: CachedChannelParticipantsContext
                    if let currentContext = strongSelf.cachedChannelParticipantsContexts[peerId] {
                        context = currentContext
                    } else {
                        context = CachedChannelParticipantsContext()
                        strongSelf.cachedChannelParticipantsContexts[peerId] = context
                    }
                    
                    let viewId = OSAtomicIncrement32(&strongSelf.nextViewId)
                    let begin = forceImmediateUpdate || context.subscribers.isEmpty
                    let index = context.subscribers.add(viewId)
                    
                    if begin {
                        if let account = strongSelf.account {
                            let signal = (fetchAndUpdateCachedParticipants(peerId: peerId, network: account.network, postbox: account.postbox) |> then(Signal<Void, NoError>.complete() |> delay(10 * 60, queue: Queue.concurrentDefaultQueue()))) |> restart
                            context.disposable.set(signal.start())
                        }
                    }
                    
                    disposable.set(ActionDisposable {
                        if let strongSelf = self {
                            if let currentContext = strongSelf.cachedChannelParticipantsContexts[peerId] {
                                currentContext.subscribers.remove(index)
                                currentContext.disposable.dispose()
                                if currentContext.subscribers.isEmpty {
                                    strongSelf.cachedChannelParticipantsContexts.removeValue(forKey: peerId)
                                }
                            }
                        }
                    })
                }
            }
            return disposable
        }
    }
}
