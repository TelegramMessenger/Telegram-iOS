import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public enum ViewUpdateType {
    case InitialUnread(MessageIndex)
    case Generic
    case FillHole(insertions: [MessageIndex: HoleFillDirection], deletions: [MessageIndex: HoleFillDirection])
    case UpdateVisible
}

final class ViewTracker {
    private let queue: Queue
    private let fetchEarlierHistoryEntries: (PeerId, MessageIndex?, Int, MessageTags?) -> [MutableMessageHistoryEntry]
    private let fetchLaterHistoryEntries: (PeerId, MessageIndex?, Int, MessageTags?) -> [MutableMessageHistoryEntry]
    private let fetchEarlierChatEntries: (ChatListIndex?, Int) -> [MutableChatListEntry]
    private let fetchLaterChatEntries: (ChatListIndex?, Int) -> [MutableChatListEntry]
    private let fetchAnchorIndex: (MessageId) -> MessageHistoryAnchorIndex?
    private let renderMessage: (IntermediateMessage) -> Message
    private let getPeer: (PeerId) -> Peer?
    private let getPeerNotificationSettings: (PeerId) -> PeerNotificationSettings?
    private let getCachedPeerData: (PeerId) -> CachedPeerData?
    private let getPeerPresence: (PeerId) -> PeerPresence?
    private let getTotalUnreadCount: () -> Int32
    private let getPeerReadState: (PeerId) -> CombinedPeerReadState?
    private let operationLogGetOperations: (PeerOperationLogTag, Int32, Int) -> [PeerMergedOperationLogEntry]
    private let operationLogGetTailIndex: (PeerOperationLogTag) -> Int32?
    private let getPreferencesEntry: (ValueBoxKey) -> PreferencesEntry?
    
    private var chatListViews = Bag<(MutableChatListView, ValuePipe<(ChatListView, ViewUpdateType)>)>()
    private var messageHistoryViews: [PeerId: Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>] = [:]
    private var contactPeerIdsViews = Bag<(MutableContactPeerIdsView, ValuePipe<ContactPeerIdsView>)>()
    private var contactPeersViews = Bag<(MutableContactPeersView, ValuePipe<ContactPeersView>)>()
    
    private let messageHistoryHolesView = MutableMessageHistoryHolesView()
    private let messageHistoryHolesViewSubscribers = Bag<ValuePipe<MessageHistoryHolesView>>()
    
    private let chatListHolesView = MutableChatListHolesView()
    private let chatListHolesViewSubscribers = Bag<ValuePipe<ChatListHolesView>>()
    
    private var unsentMessageView: UnsentMessageHistoryView
    private let unsendMessageIdsViewSubscribers = Bag<ValuePipe<UnsentMessageIdsView>>()
    
    private var synchronizeReadStatesView: MutableSynchronizePeerReadStatesView
    private let synchronizePeerReadStatesViewSubscribers = Bag<ValuePipe<SynchronizePeerReadStatesView>>()
    
    private var peerViews = Bag<(MutablePeerView, ValuePipe<PeerView>)>()
    
    private var unreadMessageCountsViews = Bag<(MutableUnreadMessageCountsView, ValuePipe<UnreadMessageCountsView>)>()
    private var peerMergedOperationLogViews = Bag<(MutablePeerMergedOperationLogView, ValuePipe<PeerMergedOperationLogView>)>()
    
    private let getTimestampBasedMessageAttributesHead: (UInt16) -> TimestampBasedMessageAttributesEntry?
    private var timestampBasedMessageAttributesViews = Bag<(MutableTimestampBasedMessageAttributesView, ValuePipe<TimestampBasedMessageAttributesView>)>()
    
    private var messageViews = Bag<(MutableMessageView, ValuePipe<MessageView>)>()
    private var preferencesViews = Bag<(MutablePreferencesView, ValuePipe<PreferencesView>)>()
    private var multiplePeersViews = Bag<(MutableMultiplePeersView, ValuePipe<MultiplePeersView>)>()
    
    init(queue: Queue, fetchEarlierHistoryEntries: @escaping (PeerId, MessageIndex?, Int, MessageTags?) -> [MutableMessageHistoryEntry], fetchLaterHistoryEntries: @escaping (PeerId, MessageIndex?, Int, MessageTags?) -> [MutableMessageHistoryEntry], fetchEarlierChatEntries: @escaping (ChatListIndex?, Int) -> [MutableChatListEntry], fetchLaterChatEntries: @escaping (ChatListIndex?, Int) -> [MutableChatListEntry], fetchAnchorIndex: @escaping (MessageId) -> MessageHistoryAnchorIndex?, renderMessage: @escaping (IntermediateMessage) -> Message, getPeer: @escaping (PeerId) -> Peer?, getPeerNotificationSettings: @escaping (PeerId) -> PeerNotificationSettings?, getCachedPeerData: @escaping (PeerId) -> CachedPeerData?, getPeerPresence: @escaping (PeerId) -> PeerPresence?, getTotalUnreadCount: @escaping () -> Int32, getPeerReadState: @escaping (PeerId) -> CombinedPeerReadState?, operationLogGetOperations: @escaping (PeerOperationLogTag, Int32, Int) -> [PeerMergedOperationLogEntry], operationLogGetTailIndex: @escaping (PeerOperationLogTag) -> Int32?, getTimestampBasedMessageAttributesHead: @escaping (UInt16) -> TimestampBasedMessageAttributesEntry?, getPreferencesEntry: @escaping (ValueBoxKey) -> PreferencesEntry?, unsentMessageIds: [MessageId], synchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation]) {
        self.queue = queue
        self.fetchEarlierHistoryEntries = fetchEarlierHistoryEntries
        self.fetchLaterHistoryEntries = fetchLaterHistoryEntries
        self.fetchEarlierChatEntries = fetchEarlierChatEntries
        self.fetchLaterChatEntries = fetchLaterChatEntries
        self.fetchAnchorIndex = fetchAnchorIndex
        self.renderMessage = renderMessage
        self.getPeer = getPeer
        self.getPeerNotificationSettings = getPeerNotificationSettings
        self.getCachedPeerData = getCachedPeerData
        self.getPeerPresence = getPeerPresence
        self.getTotalUnreadCount = getTotalUnreadCount
        self.getPeerReadState = getPeerReadState
        self.operationLogGetOperations = operationLogGetOperations
        self.operationLogGetTailIndex = operationLogGetTailIndex
        self.getTimestampBasedMessageAttributesHead = getTimestampBasedMessageAttributesHead
        self.getPreferencesEntry = getPreferencesEntry
        
        self.unsentMessageView = UnsentMessageHistoryView(ids: unsentMessageIds)
        self.synchronizeReadStatesView = MutableSynchronizePeerReadStatesView(operations: synchronizePeerReadStateOperations)
    }
    
    func addMessageHistoryView(_ peerId: PeerId, view: MutableMessageHistoryView) -> (Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index, Signal<(MessageHistoryView, ViewUpdateType), NoError>) {
        let record = (view, ValuePipe<(MessageHistoryView, ViewUpdateType)>())
        
        let index: Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index
        if let bag = self.messageHistoryViews[peerId] {
            index = bag.add(record)
        } else {
            let bag = Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>()
            index = bag.add(record)
            self.messageHistoryViews[peerId] = bag
        }
        
        self.updateTrackedHoles(peerId)
        
        return (index, record.1.signal())
    }
    
    func removeMessageHistoryView(_ peerId: PeerId, index: Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index) {
        if let bag = self.messageHistoryViews[peerId] {
            bag.remove(index)
            
            self.updateTrackedHoles(peerId)
        }
    }
    
    func addChatListView(_ view: MutableChatListView) -> (Bag<(MutableChatListView, ValuePipe<(ChatListView, ViewUpdateType)>)>.Index, Signal<(ChatListView, ViewUpdateType), NoError>) {
        let record = (view, ValuePipe<(ChatListView, ViewUpdateType)>())
        let index = self.chatListViews.add(record)
        
        self.updateTrackedChatListHoles()
        
        return (index, record.1.signal())
    }
    
    func removeChatListView(_ index: Bag<(MutableChatListView, ValuePipe<ChatListView>)>.Index) {
        self.chatListViews.remove(index)
        self.updateTrackedChatListHoles()
    }
    
    func addContactPeerIdsView(_ view: MutableContactPeerIdsView) -> (Bag<(MutableContactPeerIdsView, ValuePipe<ContactPeerIdsView>)>.Index, Signal<ContactPeerIdsView, NoError>) {
        let record = (view, ValuePipe<ContactPeerIdsView>())
        let index = self.contactPeerIdsViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeContactPeerIdsView(_ index: Bag<(MutableContactPeerIdsView, ValuePipe<ContactPeerIdsView>)>.Index) {
        self.contactPeerIdsViews.remove(index)
    }
    
    func addContactPeersView(_ view: MutableContactPeersView) -> (Bag<(MutableContactPeersView, ValuePipe<ContactPeersView>)>.Index, Signal<ContactPeersView, NoError>) {
        let record = (view, ValuePipe<ContactPeersView>())
        let index = self.contactPeersViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeContactPeersView(_ index: Bag<(MutableContactPeersView, ValuePipe<ContactPeersView>)>.Index) {
        self.contactPeersViews.remove(index)
    }
    
    func updateMessageHistoryViewVisibleRange(_ id: MessageHistoryViewId, earliestVisibleIndex: MessageIndex, latestVisibleIndex: MessageIndex) {
        if let bag = self.messageHistoryViews[id.peerId] {
            for (mutableView, pipe) in bag.copyItems() {
                if mutableView.id == id {
                    let context = MutableMessageHistoryViewReplayContext()
                    var updated = false
                    
                    let updateType: ViewUpdateType = .UpdateVisible
                    
                    if mutableView.updateVisibleRange(earliestVisibleIndex: earliestVisibleIndex, latestVisibleIndex: latestVisibleIndex, context: context) {
                        mutableView.complete(context: context, fetchEarlier: { index, count in
                            return self.fetchEarlierHistoryEntries(id.peerId, index, count, mutableView.tagMask)
                        }, fetchLater: { index, count in
                            return self.fetchLaterHistoryEntries(id.peerId, index, count, mutableView.tagMask)
                        })
                        mutableView.incrementVersion()
                        updated = true
                    }
                    
                    if updated {
                        mutableView.render(self.renderMessage)
                        pipe.putNext((MessageHistoryView(mutableView), updateType))
                        
                        self.updateTrackedHoles(id.peerId)
                    }
                    
                    break
                }
            }
        }
    }
    
    func addPeerView(_ view: MutablePeerView) -> (Bag<(MutablePeerView, ValuePipe<PeerView>)>.Index, Signal<PeerView, NoError>) {
        let record = (view, ValuePipe<PeerView>())
        let index = self.peerViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePeerView(_ index: Bag<(MutablePeerView, ValuePipe<Peer?>)>.Index) {
        self.peerViews.remove(index)
    }
    
    func addUnreadMessageCountsView(_ view: MutableUnreadMessageCountsView) -> (Bag<(MutableUnreadMessageCountsView, ValuePipe<UnreadMessageCountsView>)>.Index, Signal<UnreadMessageCountsView, NoError>) {
        let record = (view, ValuePipe<UnreadMessageCountsView>())
        let index = self.unreadMessageCountsViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeUnreadMessageCountsView(_ index: Bag<(MutableUnreadMessageCountsView, ValuePipe<UnreadMessageCountsView>)>.Index) {
        self.peerViews.remove(index)
    }
    
    func addPeerMergedOperationLogView(_ view: MutablePeerMergedOperationLogView) -> (Bag<(MutablePeerMergedOperationLogView, ValuePipe<PeerMergedOperationLogView>)>.Index, Signal<PeerMergedOperationLogView, NoError>) {
        let record = (view, ValuePipe<PeerMergedOperationLogView>())
        let index = self.peerMergedOperationLogViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePeerMergedOperationLogView(_ index: Bag<(MutablePeerMergedOperationLogView, ValuePipe<PeerMergedOperationLogView>)>.Index) {
        self.peerMergedOperationLogViews.remove(index)
    }
    
    func addTimestampBasedMessageAttributesView(_ view: MutableTimestampBasedMessageAttributesView) -> (Bag<(MutableTimestampBasedMessageAttributesView, ValuePipe<TimestampBasedMessageAttributesView>)>.Index, Signal<TimestampBasedMessageAttributesView, NoError>) {
        let record = (view, ValuePipe<TimestampBasedMessageAttributesView>())
        let index = self.timestampBasedMessageAttributesViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeTimestampBasedMessageAttributesView(_ index: Bag<(MutableTimestampBasedMessageAttributesView, ValuePipe<TimestampBasedMessageAttributesView>)>.Index) {
        self.timestampBasedMessageAttributesViews.remove(index)
    }
    
    func addMessageView(_ view: MutableMessageView) -> (Bag<(MutableMessageView, ValuePipe<MessageView>)>.Index, Signal<MessageView, NoError>) {
        let record = (view, ValuePipe<MessageView>())
        let index = self.messageViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeMessageView(_ index: Bag<(MutableMessageView, ValuePipe<MessageView>)>.Index) {
        self.messageViews.remove(index)
    }
    
    func addPreferencesView(_ view: MutablePreferencesView) -> (Bag<(MutablePreferencesView, ValuePipe<PreferencesView>)>.Index, Signal<PreferencesView, NoError>) {
        let record = (view, ValuePipe<PreferencesView>())
        let index = self.preferencesViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePreferencesView(_ index: Bag<(MutablePreferencesView, ValuePipe<PreferencesView>)>.Index) {
        self.preferencesViews.remove(index)
    }
    
    func addMultiplePeersView(_ view: MutableMultiplePeersView) -> (Bag<(MutableMultiplePeersView, ValuePipe<MultiplePeersView>)>.Index, Signal<MultiplePeersView, NoError>) {
        let record = (view, ValuePipe<MultiplePeersView>())
        let index = self.multiplePeersViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeMultiplePeersView(_ index: Bag<(MutableMultiplePeersView, ValuePipe<MultiplePeersView>)>.Index) {
        self.multiplePeersViews.remove(index)
    }
    
    func refreshViewsDueToExternalTransaction(fetchAroundChatEntries: (_ index: ChatListIndex, _ count: Int) -> (entries: [MutableChatListEntry], earlier: MutableChatListEntry?, later: MutableChatListEntry?), fetchAroundHistoryEntries: (_ index: MessageIndex, _ count: Int, _ tagMask: MessageTags?) -> (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?), fetchUnsentMessageIds: () -> [MessageId], fetchSynchronizePeerReadStateOperations: () -> [PeerId: PeerReadStateSynchronizationOperation]) {
        var updateTrackedHolesPeerIds: [PeerId] = []
        
        for (peerId, bag) in self.messageHistoryViews {
            for (mutableView, pipe) in bag.copyItems() {
                if mutableView.refreshDueToExternalTransaction(fetchAroundHistoryEntries: fetchAroundHistoryEntries) {
                    mutableView.incrementVersion()
                    
                    mutableView.render(self.renderMessage)
                    pipe.putNext((MessageHistoryView(mutableView), .Generic))
                    
                    updateTrackedHolesPeerIds.append(peerId)
                }
            }
        }
        
        for (mutableView, pipe) in self.chatListViews.copyItems() {
            if mutableView.refreshDueToExternalTransaction(fetchAroundChatEntries: fetchAroundChatEntries) {
                mutableView.render(self.renderMessage, getPeer: { id in
                    return self.getPeer(id)
                }, getPeerNotificationSettings: self.getPeerNotificationSettings)
                pipe.putNext((ChatListView(mutableView), .Generic))
            }
        }
        
        for peerId in updateTrackedHolesPeerIds {
            self.updateTrackedHoles(peerId)
        }
        
        if self.unsentMessageView.refreshDueToExternalTransaction(fetchUnsentMessageIds: fetchUnsentMessageIds) {
            self.unsentViewUpdated()
        }
        
        if self.synchronizeReadStatesView.refreshDueToExternalTransaction(fetchSynchronizePeerReadStateOperations: fetchSynchronizePeerReadStateOperations) {
            self.synchronizeReadStateViewUpdated()
        }
        
        for (mutableView, pipe) in self.peerViews.copyItems() {
            var updatedPeers: [PeerId: Peer] = [:]
            var updatedPeerPresences: [PeerId: PeerPresence] = [:]
            var updatedNotificationSettings: [PeerId: PeerNotificationSettings] = [:]
            var updatedCachedPeerData: [PeerId: CachedPeerData] = [:]
            
            let peerId = mutableView.peerId
            
            if let peer = self.getPeer(peerId) {
                updatedPeers[peerId] = peer
            }
            if let presence = self.getPeerPresence(peerId) {
                updatedPeerPresences[peerId] = presence
            }
            if let notificationSettings = self.getPeerNotificationSettings(peerId) {
                updatedNotificationSettings[peerId] = notificationSettings
            }
            if let cachedPeerData = self.getCachedPeerData(peerId) {
                updatedCachedPeerData[peerId] = cachedPeerData
                for cachedPeerId in cachedPeerData.peerIds {
                    if let peer = self.getPeer(cachedPeerId) {
                        updatedPeers[cachedPeerId] = peer
                    }
                    if let presence = self.getPeerPresence(cachedPeerId) {
                        updatedPeerPresences[cachedPeerId] = presence
                    }
                }
            }
            
            if mutableView.replay(updatedPeers: updatedPeers, updatedNotificationSettings: updatedNotificationSettings, updatedCachedPeerData: updatedCachedPeerData, updatedPeerPresences: updatedPeerPresences, replaceContactPeerIds: nil, getPeer: self.getPeer, getPeerPresence: self.getPeerPresence) {
                pipe.putNext(PeerView(mutableView))
            }
        }
    }
    
    func updateViews(transaction: PostboxTransaction) {
        var updateTrackedHolesPeerIds: [PeerId] = []
        
        for (peerId, bag) in self.messageHistoryViews {
            var updateHoles = false
            let operations = transaction.currentOperationsByPeerId[peerId]
            if operations != nil || !transaction.updatedMedia.isEmpty || !transaction.currentUpdatedCachedPeerData.isEmpty {
                updateHoles = true
                for (mutableView, pipe) in bag.copyItems() {
                    let context = MutableMessageHistoryViewReplayContext()
                    var updated = false
                    
                    let updateType: ViewUpdateType
                    if let filledIndices = transaction.peerIdsWithFilledHoles[peerId] {
                        updateType = .FillHole(insertions: filledIndices, deletions: transaction.removedHolesByPeerId[peerId] ?? [:])
                    } else {
                        updateType = .Generic
                    }
                    
                    if mutableView.replay(operations ?? [], holeFillDirections: transaction.peerIdsWithFilledHoles[peerId] ?? [:], updatedMedia: transaction.updatedMedia, updatedCachedPeerData: transaction.currentUpdatedCachedPeerData, context: context, renderIntermediateMessage: self.renderMessage) {
                        mutableView.complete(context: context, fetchEarlier: { index, count in
                            return self.fetchEarlierHistoryEntries(peerId, index, count, mutableView.tagMask)
                        }, fetchLater: { index, count in
                            return self.fetchLaterHistoryEntries(peerId, index, count, mutableView.tagMask)
                        })
                        mutableView.incrementVersion()
                        updated = true
                    }
                    
                    if mutableView.updateAnchorIndex(self.fetchAnchorIndex) {
                        updated = true
                    }
                    
                    if mutableView.updatePeers(transaction.currentUpdatedPeers) {
                        updated = true
                    }
                    
                    if updated {
                        mutableView.render(self.renderMessage)
                        
                        pipe.putNext((MessageHistoryView(mutableView), updateType))
                    }
                }
            }
            
            if updateHoles {
                updateTrackedHolesPeerIds.append(peerId)
            }
        }
        
        for (mutableView, pipe) in self.messageViews.copyItems() {
            let operations = transaction.currentOperationsByPeerId[mutableView.messageId.peerId]
            if operations != nil || !transaction.updatedMedia.isEmpty || !transaction.currentUpdatedCachedPeerData.isEmpty {
                if mutableView.replay(operations ?? [], updatedMedia: transaction.updatedMedia, renderIntermediateMessage: self.renderMessage) {
                    pipe.putNext(MessageView(mutableView))
                }
            }
        }
        
        if !transaction.chatListOperations.isEmpty || !transaction.currentUpdatedPeerNotificationSettings.isEmpty {
            for (mutableView, pipe) in self.chatListViews.copyItems() {
                let context = MutableChatListViewReplayContext()
                if mutableView.replay(transaction.chatListOperations, updatedPeerNotificationSettings: transaction.currentUpdatedPeerNotificationSettings, context: context) {
                    mutableView.complete(context: context, fetchEarlier: self.fetchEarlierChatEntries, fetchLater: self.fetchLaterChatEntries)
                    mutableView.render(self.renderMessage, getPeer: { id in
                        return self.getPeer(id)
                    }, getPeerNotificationSettings: self.getPeerNotificationSettings)
                    //var updateType: ViewUpdateType = .Generic
                    for operation in transaction.chatListOperations {
                        if case .RemoveHoles = operation {
                            //updateType = .UpdateVisible
                            break
                        }
                    }
                    pipe.putNext((ChatListView(mutableView), .Generic))
                }
            }
            
            self.updateTrackedChatListHoles()
        }
        
        for peerId in updateTrackedHolesPeerIds {
            self.updateTrackedHoles(peerId)
        }
        
        if self.unsentMessageView.replay(transaction.unsentMessageOperations) {
            self.unsentViewUpdated()
        }
        
        if self.synchronizeReadStatesView.replay(transaction.updatedSynchronizePeerReadStateOperations) {
            self.synchronizeReadStateViewUpdated()
        }
        
        for (view, pipe) in self.unreadMessageCountsViews.copyItems() {
            if view.replay(peerIdsWithUpdatedUnreadCounts: transaction.peerIdsWithUpdatedUnreadCounts, getTotalUnreadCount: self.getTotalUnreadCount, getPeerReadState: self.getPeerReadState) {
                pipe.putNext(UnreadMessageCountsView(view))
            }
        }
        
        if let replaceContactPeerIds = transaction.replaceContactPeerIds {
            for (mutableView, pipe) in self.contactPeerIdsViews.copyItems() {
                if mutableView.replay(replace: replaceContactPeerIds) {
                    pipe.putNext(ContactPeerIdsView(mutableView))
                }
            }
        }
        
        for (mutableView, pipe) in self.contactPeersViews.copyItems() {
            if mutableView.replay(replacePeerIds: transaction.replaceContactPeerIds, updatedPeerPresences: transaction.currentUpdatedPeerPresences, getPeer: self.getPeer, getPeerPresence: self.getPeerPresence) {
                pipe.putNext(ContactPeersView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.peerViews.copyItems() {
            if mutableView.replay(updatedPeers: transaction.currentUpdatedPeers, updatedNotificationSettings: transaction.currentUpdatedPeerNotificationSettings, updatedCachedPeerData: transaction.currentUpdatedCachedPeerData, updatedPeerPresences: transaction.currentUpdatedPeerPresences, replaceContactPeerIds: transaction.replaceContactPeerIds, getPeer: self.getPeer, getPeerPresence: self.getPeerPresence) {
                pipe.putNext(PeerView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.peerMergedOperationLogViews.copyItems() {
            if mutableView.replay(operations: transaction.currentPeerMergedOperationLogOperations, getOperations: self.operationLogGetOperations, getTailIndex: self.operationLogGetTailIndex) {
                pipe.putNext(PeerMergedOperationLogView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.timestampBasedMessageAttributesViews.copyItems() {
            if mutableView.replay(operations: transaction.currentTimestampBasedMessageAttributesOperations, getHead: self.getTimestampBasedMessageAttributesHead) {
                pipe.putNext(TimestampBasedMessageAttributesView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.preferencesViews.copyItems() {
            if mutableView.replay(operations: transaction.currentPreferencesOperations, get: self.getPreferencesEntry) {
                pipe.putNext(PreferencesView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.multiplePeersViews.copyItems() {
            if mutableView.replay(updatedPeers: transaction.currentUpdatedPeers, updatedPeerPresences: transaction.currentUpdatedPeerPresences) {
                pipe.putNext(MultiplePeersView(mutableView))
            }
        }
    }
    
    private func updateTrackedChatListHoles() {
        var firstHoles = Set<ChatListHole>()
        
        for (view, _) in self.chatListViews.copyItems() {
            if let hole = view.firstHole() {
                firstHoles.insert(hole)
            }
        }
    
        if self.chatListHolesView.update(holes: firstHoles) {
            for pipe in self.chatListHolesViewSubscribers.copyItems() {
                pipe.putNext(ChatListHolesView(self.chatListHolesView))
            }
        }
    }
    
    private func updateTrackedHoles(_ peerId: PeerId) {
        var firstHolesAndTags = Set<MessageHistoryHolesViewEntry>()
        if let bag = self.messageHistoryViews[peerId]  {
            for (view, _) in bag.copyItems() {
                if let (hole, direction) = view.firstHole() {
                    firstHolesAndTags.insert(MessageHistoryHolesViewEntry(hole: hole, direction: direction, tags: view.tagMask))
                }
            }
        }
        
        if self.messageHistoryHolesView.update(peerId: peerId, holes: firstHolesAndTags) {
            for subscriber in self.messageHistoryHolesViewSubscribers.copyItems() {
                subscriber.putNext(MessageHistoryHolesView(self.messageHistoryHolesView))
            }
        }
    }
    
    private func unsentViewUpdated() {
        for subscriber in self.unsendMessageIdsViewSubscribers.copyItems() {
            subscriber.putNext(UnsentMessageIdsView(self.unsentMessageView.ids))
        }
    }
    
    private func synchronizeReadStateViewUpdated() {
        for subscriber in self.synchronizePeerReadStatesViewSubscribers.copyItems() {
            subscriber.putNext(SynchronizePeerReadStatesView(self.synchronizeReadStatesView))
        }
    }
    
    func messageHistoryHolesViewSignal() -> Signal<MessageHistoryHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(MessageHistoryHolesView(self.messageHistoryHolesView))
                
                let pipe = ValuePipe<MessageHistoryHolesView>()
                let index = self.messageHistoryHolesViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    pipeDisposable.dispose()
                    self.messageHistoryHolesViewSubscribers.remove(index)
                })
            }
            return disposable
        }
    }
    
    func chatListHolesViewSignal() -> Signal<ChatListHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(ChatListHolesView(self.chatListHolesView))
                
                let pipe = ValuePipe<ChatListHolesView>()
                let index = self.chatListHolesViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    pipeDisposable.dispose()
                    self.chatListHolesViewSubscribers.remove(index)
                })
            }
            return disposable
        }
    }
    
    func unsentMessageIdsViewSignal() -> Signal<UnsentMessageIdsView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(UnsentMessageIdsView(self.unsentMessageView.ids))
                
                let pipe = ValuePipe<UnsentMessageIdsView>()
                let index = self.unsendMessageIdsViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    pipeDisposable.dispose()
                    self.unsendMessageIdsViewSubscribers.remove(index)
                })
            }
            return disposable
        }
    }
    
    func synchronizePeerReadStatesViewSignal() -> Signal<SynchronizePeerReadStatesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(SynchronizePeerReadStatesView(self.synchronizeReadStatesView))
                
                let pipe = ValuePipe<SynchronizePeerReadStatesView>()
                let index = self.synchronizePeerReadStatesViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    pipeDisposable.dispose()
                    self.synchronizePeerReadStatesViewSubscribers.remove(index)
                })
            }
            return disposable
        }
    }
}
