import Foundation
import SwiftSignalKit

public enum ViewUpdateType : Equatable {
    case Initial
    case InitialUnread(MessageIndex)
    case Generic
    case FillHole
    case UpdateVisible
}

final class ViewTracker {
    private let queue: Queue
    
    private var chatListViews = Bag<(MutableChatListView, ValuePipe<(ChatListView, ViewUpdateType)>)>()
    private var messageHistoryViews = Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>()
    private var contactPeerIdsViews = Bag<(MutableContactPeerIdsView, ValuePipe<ContactPeerIdsView>)>()
    
    private let messageHistoryHolesView = MutableMessageHistoryHolesView()
    private let messageHistoryHolesViewSubscribers = Bag<ValuePipe<MessageHistoryHolesView>>()
    
    private let externalMessageHistoryHolesView = MutableMessageHistoryExternalHolesView()
    private let externalMessageHistoryHolesViewSubscribers = Bag<ValuePipe<MessageHistoryExternalHolesView>>()
    
    private let chatListHolesView = MutableChatListHolesView()
    private let chatListHolesViewSubscribers = Bag<ValuePipe<ChatListHolesView>>()
    
    private let forumTopicListHolesView = MutableForumTopicListHolesView()
    private let forumTopicListHolesViewSubscribers = Bag<ValuePipe<ForumTopicListHolesView>>()
    
    private var unsentMessageView: UnsentMessageHistoryView
    private let unsendMessageIdsViewSubscribers = Bag<ValuePipe<UnsentMessageIdsView>>()
    
    private var synchronizeReadStatesView: MutableSynchronizePeerReadStatesView
    private let synchronizePeerReadStatesViewSubscribers = Bag<ValuePipe<SynchronizePeerReadStatesView>>()
    
    private var peerViews = Bag<(MutablePeerView, ValuePipe<PeerView>)>()
    
    private var unreadMessageCountsViews = Bag<(MutableUnreadMessageCountsView, ValuePipe<UnreadMessageCountsView>)>()
    private var peerMergedOperationLogViews = Bag<(MutablePeerMergedOperationLogView, ValuePipe<PeerMergedOperationLogView>)>()
    
    private var timestampBasedMessageAttributesViews = Bag<(MutableTimestampBasedMessageAttributesView, ValuePipe<TimestampBasedMessageAttributesView>)>()
    
    private var combinedViews = Bag<(CombinedMutableView, ValuePipe<CombinedView>)>()
    
    private var postboxStateViews = Bag<(MutablePostboxStateView, ValuePipe<PostboxStateView>)>()
    private var messageViews = Bag<(MutableMessageView, ValuePipe<MessageView>)>()
    private var preferencesViews = Bag<(MutablePreferencesView, ValuePipe<PreferencesView>)>()
    private var multiplePeersViews = Bag<(MutableMultiplePeersView, ValuePipe<MultiplePeersView>)>()
    private var itemCollectionsViews = Bag<(MutableItemCollectionsView, ValuePipe<ItemCollectionsView>)>()
    private var failedMessageIdsViews = Bag<(MutableFailedMessageIdsView, ValuePipe<FailedMessageIdsView>)>()
    
    init(
        queue: Queue,
        unsentMessageIds: [MessageId],
        synchronizePeerReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation]
    ) {
        self.queue = queue
        
        self.unsentMessageView = UnsentMessageHistoryView(ids: unsentMessageIds)
        self.synchronizeReadStatesView = MutableSynchronizePeerReadStatesView(operations: synchronizePeerReadStateOperations)
    }
    
    func addPostboxStateView(_ view: MutablePostboxStateView) -> (Bag<(MutablePostboxStateView, ValuePipe<PostboxStateView>)>.Index, Signal<PostboxStateView, NoError>) {
        let record = (view, ValuePipe<PostboxStateView>())
        let index = self.postboxStateViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removePostboxStateView(_ index: Bag<(MutablePostboxStateView, ValuePipe<PostboxStateView>)>.Index) {
        self.postboxStateViews.remove(index)
    }
    
    func addMessageHistoryView(_ view: MutableMessageHistoryView) -> (Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index, Signal<(MessageHistoryView, ViewUpdateType), NoError>) {
        let record = (view, ValuePipe<(MessageHistoryView, ViewUpdateType)>())
        
        let index: Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index
        index = self.messageHistoryViews.add(record)
        
        self.updateTrackedHoles()
        
        return (index, record.1.signal())
    }
    
    func removeMessageHistoryView(index: Bag<(MutableMessageHistoryView, ValuePipe<(MessageHistoryView, ViewUpdateType)>)>.Index) {
        self.messageHistoryViews.remove(index)
        
        self.updateTrackedHoles()
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
        self.unreadMessageCountsViews.remove(index)
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
    
    func addItemCollectionView(_ view: MutableItemCollectionsView) -> (Bag<(MutableItemCollectionsView, ValuePipe<ItemCollectionsView>)>.Index, Signal<ItemCollectionsView, NoError>) {
        let record = (view, ValuePipe<ItemCollectionsView>())
        let index = self.itemCollectionsViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeItemCollectionView(_ index: Bag<(MutableItemCollectionsView, ValuePipe<ItemCollectionsView>)>.Index) {
        self.itemCollectionsViews.remove(index)
    }
    
    func addCombinedView(_ view: CombinedMutableView) -> (Bag<(CombinedMutableView, ValuePipe<CombinedView>)>.Index, Signal<CombinedView, NoError>) {
        let record = (view, ValuePipe<CombinedView>())
        let index = self.combinedViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeCombinedView(_ index: Bag<(CombinedMutableView, ValuePipe<CombinedView>)>.Index) {
        self.combinedViews.remove(index)
    }
    
    func refreshViewsDueToExternalTransaction(postbox: PostboxImpl, currentTransaction: Transaction, fetchUnsentMessageIds: () -> [MessageId], fetchSynchronizePeerReadStateOperations: () -> [PeerId: PeerReadStateSynchronizationOperation]) {
        var updateTrackedHoles = false
        
        for (mutableView, pipe) in self.messageHistoryViews.copyItems() {
            if mutableView.refreshDueToExternalTransaction(postbox: postbox) {
                pipe.putNext((MessageHistoryView(mutableView), .Generic))
                
                updateTrackedHoles = true
            }
        }
        
        for (mutableView, pipe) in self.chatListViews.copyItems() {
            if mutableView.refreshDueToExternalTransaction(postbox: postbox, currentTransaction: currentTransaction) {
                mutableView.render(postbox: postbox)
                pipe.putNext((ChatListView(mutableView), .Generic))
            }
        }
        
        if updateTrackedHoles {
            self.updateTrackedHoles()
        }
        
        if self.unsentMessageView.refreshDueToExternalTransaction(fetchUnsentMessageIds: fetchUnsentMessageIds) {
            self.unsentViewUpdated()
        }
        
        if self.synchronizeReadStatesView.refreshDueToExternalTransaction(fetchSynchronizePeerReadStateOperations: fetchSynchronizePeerReadStateOperations) {
            self.synchronizeReadStateViewUpdated()
        }
        
        for (mutableView, pipe) in self.peerViews.copyItems() {
            if mutableView.reset(postbox: postbox) {
                pipe.putNext(PeerView(mutableView))
            }
        }
    }
    
    func updateViews(postbox: PostboxImpl, currentTransaction: Transaction, transaction: PostboxTransaction) {
        var updateTrackedHoles = false
        
        if let currentUpdatedState = transaction.currentUpdatedState {
            for (mutableView, pipe) in self.postboxStateViews.copyItems() {
                if mutableView.replay(updatedState: currentUpdatedState) {
                    pipe.putNext(PostboxStateView(mutableView))
                }
            }
        }
        
        for (mutableView, pipe) in self.messageHistoryViews.copyItems() {
            var updated = false
            
            let previousPeerIds = mutableView.peerIds
        
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                updated = true
            }
            
            var updateType: ViewUpdateType = .Generic
            switch mutableView.peerIds {
                case let .single(peerId, threadId):
                    for key in transaction.currentPeerHoleOperations.keys {
                        if key.peerId == peerId && key.threadId == threadId {
                            updateType = .FillHole
                            break
                        }
                    }
                case .associated:
                    var ids = Set<PeerId>()
                    switch mutableView.peerIds {
                        case .single, .external:
                            assertionFailure()
                        case let .associated(mainPeerId, associatedId):
                            ids.insert(mainPeerId)
                            if let associatedId = associatedId {
                                ids.insert(associatedId.peerId)
                            }
                    }
                    
                    if !ids.isEmpty {
                        for key in transaction.currentPeerHoleOperations.keys {
                            if ids.contains(key.peerId) {
                                updateType = .FillHole
                                break
                            }
                        }
                    }
                case .external:
                    break
            }
            
            mutableView.updatePeerIds(transaction: transaction)
            if mutableView.peerIds != previousPeerIds {
                updateType = .UpdateVisible
                
                let _ = mutableView.refreshDueToExternalTransaction(postbox: postbox)
                updated = true
            }
        
            if updated {
                updateTrackedHoles = true
                pipe.putNext((MessageHistoryView(mutableView), updateType))
            }
        }
        
        for (mutableView, pipe) in self.messageViews.copyItems() {
            let operations = transaction.currentOperationsByPeerId[mutableView.messageId.peerId]
            if operations != nil || !transaction.updatedMedia.isEmpty || !transaction.currentUpdatedCachedPeerData.isEmpty {
                if mutableView.replay(postbox: postbox, operations: operations ?? [], updatedMedia: transaction.updatedMedia) {
                    pipe.putNext(MessageView(mutableView))
                }
            }
        }
        
        for (mutableView, pipe) in self.chatListViews.copyItems() {
            let context = MutableChatListViewReplayContext()
            if mutableView.replay(postbox: postbox, currentTransaction: currentTransaction, operations: transaction.chatListOperations, updatedPeerNotificationSettings: transaction.currentUpdatedPeerNotificationSettings, updatedPeers: transaction.currentUpdatedPeers, updatedPeerPresences: transaction.currentUpdatedPeerPresences, transaction: transaction, context: context) {
                mutableView.complete(postbox: postbox, context: context)
                mutableView.render(postbox: postbox)
                pipe.putNext((ChatListView(mutableView), .Generic))
            }
        }
        
        self.updateTrackedChatListHoles()
        
        if updateTrackedHoles {
            self.updateTrackedHoles()
        }
        
        if self.unsentMessageView.replay(transaction.unsentMessageOperations) {
            self.unsentViewUpdated()
        }
        
        if self.synchronizeReadStatesView.replay(transaction.updatedSynchronizePeerReadStateOperations) {
            self.synchronizeReadStateViewUpdated()
        }
        
        for (view, pipe) in self.unreadMessageCountsViews.copyItems() {
            if view.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(UnreadMessageCountsView(view))
            }
        }
        
        if let replaceContactPeerIds = transaction.replaceContactPeerIds {
            for (mutableView, pipe) in self.contactPeerIdsViews.copyItems() {
                if mutableView.replay(updateRemoteTotalCount: transaction.replaceRemoteContactCount, replace: replaceContactPeerIds) {
                    pipe.putNext(ContactPeerIdsView(mutableView))
                }
            }
        }
        
        for (mutableView, pipe) in self.peerViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(PeerView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.peerMergedOperationLogViews.copyItems() {
            if mutableView.replay(postbox: postbox, operations: transaction.currentPeerMergedOperationLogOperations) {
                pipe.putNext(PeerMergedOperationLogView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.timestampBasedMessageAttributesViews.copyItems() {
            if mutableView.replay(postbox: postbox, operations: transaction.currentTimestampBasedMessageAttributesOperations) {
                pipe.putNext(TimestampBasedMessageAttributesView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.preferencesViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(PreferencesView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.multiplePeersViews.copyItems() {
            if mutableView.replay(updatedPeers: transaction.currentUpdatedPeers, updatedPeerPresences: transaction.currentUpdatedPeerPresences) {
                pipe.putNext(MultiplePeersView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.itemCollectionsViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(ItemCollectionsView(mutableView))
            }
        }
        
        for (mutableView, pipe) in self.combinedViews.copyItems() {
            if mutableView.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(mutableView.immutableView())
            }
        }
        
        for (view, pipe) in self.failedMessageIdsViews.copyItems() {
            if view.replay(postbox: postbox, transaction: transaction) {
                pipe.putNext(view.immutableView())
            }
        }
        
        self.updateTrackedForumTopicListHoles()
    }
    
    private func updateTrackedChatListHoles() {
        var firstHoles = Set<ChatListHolesEntry>()
        
        for (view, _) in self.chatListViews.copyItems() {
            if let hole = view.firstHole() {
                firstHoles.insert(ChatListHolesEntry(groupId: hole.0, hole: hole.1))
            }
        }
    
        if self.chatListHolesView.update(holes: firstHoles) {
            for pipe in self.chatListHolesViewSubscribers.copyItems() {
                pipe.putNext(ChatListHolesView(self.chatListHolesView))
            }
        }
    }
    
    private func updateTrackedForumTopicListHoles() {
        var firstHoles = Set<ForumTopicListHolesEntry>()
        
        for (views) in self.combinedViews.copyItems() {
            for (key, view) in views.0.views {
                if case .messageHistoryThreadIndex = key, let view = view as? MutableMessageHistoryThreadIndexView {
                    if let hole = view.topHole() {
                        firstHoles.insert(hole)
                    }
                }
            }
        }
    
        if self.forumTopicListHolesView.update(holes: firstHoles) {
            for pipe in self.forumTopicListHolesViewSubscribers.copyItems() {
                pipe.putNext(ForumTopicListHolesView(self.forumTopicListHolesView))
            }
        }
    }
    
    private func updateTrackedHoles() {
        var firstHolesAndTags = Set<MessageHistoryHolesViewEntry>()
        for (view, _) in self.messageHistoryViews.copyItems() {
            if let (hole, direction, count, userId) = view.firstHole() {
                let space: MessageHistoryHoleSpace
                if let tag = view.tag {
                    space = .tag(tag)
                } else {
                    space = .everywhere
                }
                firstHolesAndTags.insert(MessageHistoryHolesViewEntry(hole: hole, direction: direction, space: space, count: count, userId: userId))
            }
        }
        
        if self.messageHistoryHolesView.update(firstHolesAndTags) {
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
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.messageHistoryHolesViewSubscribers.remove(index)
                    }
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
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.chatListHolesViewSubscribers.remove(index)
                    }
                })
            }
            return disposable
        }
    }
    
    func forumTopicListHolesViewSignal() -> Signal<ForumTopicListHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                subscriber.putNext(ForumTopicListHolesView(self.forumTopicListHolesView))
                
                let pipe = ValuePipe<ForumTopicListHolesView>()
                let index = self.forumTopicListHolesViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.forumTopicListHolesViewSubscribers.remove(index)
                    }
                })
            }
            return disposable
        }
    }
    
    func unsentMessageIdsViewSignal() -> Signal<UnsentMessageIdsView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                postboxLog("unsentMessageIdsViewSignal started with \(self.unsentMessageView.ids)")
                subscriber.putNext(UnsentMessageIdsView(self.unsentMessageView.ids))
                
                let pipe = ValuePipe<UnsentMessageIdsView>()
                let index = self.unsendMessageIdsViewSubscribers.add(pipe)
                
                let pipeDisposable = pipe.signal().start(next: { view in
                    subscriber.putNext(view)
                })
                
                disposable.set(ActionDisposable {
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.unsendMessageIdsViewSubscribers.remove(index)
                    }
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
                    self.queue.async {
                        pipeDisposable.dispose()
                        self.synchronizePeerReadStatesViewSubscribers.remove(index)
                    }
                })
            }
            return disposable
        }
    }
    
    func addFailedMessageIdsView(_ view: MutableFailedMessageIdsView) -> (Bag<(MutableFailedMessageIdsView, ValuePipe<FailedMessageIdsView>)>.Index, Signal<FailedMessageIdsView, NoError>) {
        let record = (view, ValuePipe<FailedMessageIdsView>())
        let index = self.failedMessageIdsViews.add(record)
        
        return (index, record.1.signal())
    }
    
    func removeFailedMessageIdsView(_ index: Bag<(MutableFailedMessageIdsView, ValuePipe<PeerId?>)>.Index) {
        self.failedMessageIdsViews.remove(index)
    }
    
    
}
