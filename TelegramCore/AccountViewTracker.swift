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

private func pendingWebpages(entries: [MessageHistoryEntry]) -> Set<MessageId> {
    var messageIds = Set<MessageId>()
    for case let .MessageEntry(message, _, _, _) in entries {
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
    private var pendingWebpageMessageIds: [MessageId: Int] = [:]
    private var webpageDisposables: [MessageId: Disposable] = [:]
    
    private var viewVisibleCallListHoleIds: [Int32: Set<MessageIndex>] = [:]
    private var visibleCallListHoleIds: [MessageIndex: Int] = [:]
    private var visibleCallListHoleDisposables: [MessageIndex: Disposable] = [:]
    
    private var updatedViewCountMessageIdsAndTimestamps: [MessageId: Int32] = [:]
    private var nextUpdatedViewCountDisposableId: Int32 = 0
    private var updatedViewCountDisposables = DisposableDict<Int32>()
    
    private var cachedDataContexts: [PeerId: PeerCachedDataContext] = [:]
    private var cachedChannelParticipantsContexts: [PeerId: CachedChannelParticipantsContext] = [:]
    
    private var channelPollingContexts: [PeerId: ChannelPollingContext] = [:]
    private var featuredStickerPacksContext: FeaturedStickerPacksContext?
    
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
                        self.visibleCallListHoleDisposables[holeId] = fetchCallListHole(network: account.network, postbox: account.postbox, holeIndex: holeId).start(completed: { [weak self] in
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
                                                                    if attribute.count >= Int(viewCounts[i]) {
                                                                        return .skip
                                                                    }
                                                                    attributes[j] = ViewCountMessageAttribute(count: max(attribute.count, Int(viewCounts[i])))
                                                                    break loop
                                                                }
                                                            }
                                                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
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
                if context.timestamp == nil || abs(CFAbsoluteTimeGetCurrent() - context.timestamp!) > 60.0 * 5 {
                    dataUpdated = true
                }
            } else {
                context = PeerCachedDataContext()
                context.referenceData = referenceData
                self.cachedDataContexts[peerId] = context
                if context.referenceData == nil || context.timestamp == nil || abs(CFAbsoluteTimeGetCurrent() - context.timestamp!) > 60.0 * 5 {
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
    
    private func polledChannel(peerId: PeerId) -> Signal<Void, NoError> {
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
                        context.disposable.set(keepPollingChannel(account: account, peerId: peerId, stateManager: account.stateManager).start())
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
    
    func wrappedMessageHistorySignal(peerId: PeerId, signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        let history = withState(signal, { [weak self] () -> Int32 in
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
        
        if peerId.namespace == Namespaces.Peer.CloudChannel {
            return Signal { subscriber in
                let disposable = history.start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                })
                let polled = self.polledChannel(peerId: peerId).start()
                return ActionDisposable {
                    disposable.dispose()
                    polled.dispose()
                }
            }
        } else {
            return history
        }
    }
    
    public func aroundUnreadMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, tagMask: MessageTags? = nil, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundUnreadMessageHistoryViewForPeerId(peerId, count: count, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            return wrappedMessageHistorySignal(peerId: peerId, signal: signal)
        } else {
            return .never()
        }
    }
    
    public func aroundIdMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, messageId: MessageId, tagMask: MessageTags? = nil, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundIdMessageHistoryViewForPeerId(peerId, count: count, messageId: messageId, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            return wrappedMessageHistorySignal(peerId: peerId, signal: signal)
        } else {
            return .never()
        }
    }
    
    public func aroundMessageHistoryViewForPeerId(_ peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageIndex, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags? = nil, orderStatistics: MessageHistoryViewOrderStatistics = [], additionalData: [AdditionalMessageHistoryViewData] = []) -> Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError> {
        if let account = self.account {
            let signal = account.postbox.aroundMessageHistoryViewForPeerId(peerId, index: index, count: count, anchorIndex: anchorIndex, fixedCombinedReadState: fixedCombinedReadState, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            return wrappedMessageHistorySignal(peerId: peerId, signal: signal)
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
            
            let key = PostboxViewKey.globalMessageTags(globalTag: type == .all ? GlobalMessageTags.Calls : GlobalMessageTags.MissedCalls, position: index, count: 200, groupingPredicate: groupingPredicate)
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
}
