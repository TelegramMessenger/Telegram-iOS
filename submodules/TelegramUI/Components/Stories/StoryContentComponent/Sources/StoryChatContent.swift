import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import Postbox
import StoryContainerScreen

private struct StoryKey: Hashable {
    var peerId: EnginePeer.Id
    var id: Int32
}

public final class StoryContentContextImpl: StoryContentContext {
    private final class PeerContext {
        private let context: AccountContext
        private let peerId: EnginePeer.Id
        
        private(set) var sliceValue: StoryContentContextState.FocusedSlice?
        fileprivate var nextItems: [EngineStoryItem] = []
        
        let updated = Promise<Void>()
        
        private(set) var isReady: Bool = false
        
        private var disposable: Disposable?
        private var loadDisposable: Disposable?
        
        private let currentFocusedIdUpdatedPromise = Promise<Void>()
        private var storedFocusedId: Int32?
        private var currentMappedItems: [EngineStoryItem]?
        var currentFocusedId: Int32? {
            didSet {
                if self.currentFocusedId != self.storedFocusedId {
                    self.storedFocusedId = self.currentFocusedId
                    self.currentFocusedIdUpdatedPromise.set(.single(Void()))
                }
            }
        }
        
        init(context: AccountContext, peerId: EnginePeer.Id, focusedId initialFocusedId: Int32?, loadIds: @escaping ([StoryKey]) -> Void) {
            self.context = context
            self.peerId = peerId
            
            self.currentFocusedId = initialFocusedId
            self.currentFocusedIdUpdatedPromise.set(.single(Void()))
            
            var inputKeys: [PostboxViewKey] = [
                PostboxViewKey.basicPeer(peerId),
                PostboxViewKey.cachedPeerData(peerId: peerId),
                PostboxViewKey.storiesState(key: .peer(peerId)),
                PostboxViewKey.storyItems(peerId: peerId),
            ]
            if peerId == context.account.peerId {
                inputKeys.append(PostboxViewKey.storiesState(key: .local))
            }
            self.disposable = (combineLatest(queue: .mainQueue(),
                self.currentFocusedIdUpdatedPromise.get(),
                context.account.postbox.combinedView(
                    keys: inputKeys
                ),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global())
            )
            |> mapToSignal { _, views, globalNotificationSettings -> Signal<(CombinedView, [PeerId: Peer], EngineGlobalNotificationSettings), NoError> in
                return context.account.postbox.transaction { transaction -> (CombinedView, [PeerId: Peer], EngineGlobalNotificationSettings) in
                    var peers: [PeerId: Peer] = [:]
                    if let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView {
                        for item in itemsView.items {
                            if let item = item.value.get(Stories.StoredItem.self), case let .item(itemValue) = item {
                                if let views = itemValue.views {
                                    for peerId in views.seenPeerIds {
                                        if let peer = transaction.getPeer(peerId) {
                                            peers[peer.id] = peer
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return (views, peers, globalNotificationSettings)
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] views, peers, globalNotificationSettings in
                guard let self else {
                    return
                }
                guard let peerView = views.views[PostboxViewKey.basicPeer(peerId)] as? BasicPeerView else {
                    return
                }
                guard let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                    return
                }
                guard let peerStoryItemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                    return
                }
                guard let peer = peerView.peer.flatMap(EnginePeer.init) else {
                    return
                }
                let additionalPeerData: StoryContentContextState.AdditionalPeerData
                if let cachedPeerDataView = views.views[PostboxViewKey.cachedPeerData(peerId: peerId)] as? CachedPeerDataView, let cachedUserData = cachedPeerDataView.cachedPeerData as? CachedUserData {
                    var isMuted = false
                    if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings, let storiesMuted = notificationSettings.storiesMuted {
                        isMuted = storiesMuted
                    } else {
                        isMuted = globalNotificationSettings.privateChats.storiesMuted
                    }
                    additionalPeerData = StoryContentContextState.AdditionalPeerData(isMuted: isMuted, areVoiceMessagesAvailable: cachedUserData.voiceMessagesAvailable)
                } else {
                    additionalPeerData = StoryContentContextState.AdditionalPeerData(isMuted: true, areVoiceMessagesAvailable: true)
                }
                let state = stateView.value?.get(Stories.PeerState.self)
                
                var mappedItems: [EngineStoryItem] = peerStoryItemsView.items.compactMap { item -> EngineStoryItem? in
                    guard case let .item(item) = item.value.get(Stories.StoredItem.self) else {
                        return nil
                    }
                    guard let media = item.media else {
                        return nil
                    }
                    return EngineStoryItem(
                        id: item.id,
                        timestamp: item.timestamp,
                        expirationTimestamp: item.expirationTimestamp,
                        media: EngineMedia(media),
                        text: item.text,
                        entities: item.entities,
                        views: item.views.flatMap { views in
                            return EngineStoryItem.Views(
                                seenCount: views.seenCount,
                                seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                    return peers[id].flatMap(EnginePeer.init)
                                }
                            )
                        },
                        privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                        isPinned: item.isPinned,
                        isExpired: item.isExpired,
                        isPublic: item.isPublic,
                        isPending: false
                    )
                }
                if peerId == context.account.peerId, let stateView = views.views[PostboxViewKey.storiesState(key: .local)] as? StoryStatesView, let localState = stateView.value?.get(Stories.LocalState.self) {
                    for item in localState.items {
                        mappedItems.append(EngineStoryItem(
                            id: item.stableId,
                            timestamp: item.timestamp,
                            expirationTimestamp: Int32.max,
                            media: EngineMedia(item.media),
                            text: item.text,
                            entities: item.entities,
                            views: nil,
                            privacy: item.privacy,
                            isPinned: item.pin,
                            isExpired: false,
                            isPublic: false,
                            isPending: true
                        ))
                    }
                }
                
                let currentFocusedId = self.storedFocusedId
                
                var focusedIndex: Int?
                if let currentFocusedId {
                    focusedIndex = mappedItems.firstIndex(where: { $0.id == currentFocusedId })
                    if focusedIndex == nil {
                        if let currentMappedItems = self.currentMappedItems {
                            if let previousIndex = currentMappedItems.firstIndex(where: { $0.id == currentFocusedId }) {
                                if currentMappedItems[previousIndex].isPending {
                                    if let updatedId = context.engine.messages.lookUpPendingStoryIdMapping(stableId: currentFocusedId) {
                                        if let index = mappedItems.firstIndex(where: { $0.id == updatedId }) {
                                            focusedIndex = index
                                        }
                                    }
                                }
                                
                                if focusedIndex == nil && previousIndex != 0 {
                                    for index in (0 ..< previousIndex).reversed() {
                                        if let value = mappedItems.firstIndex(where: { $0.id == currentMappedItems[index].id }) {
                                            focusedIndex = value
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if focusedIndex == nil, let state {
                    if let storedFocusedId = self.storedFocusedId {
                        focusedIndex = mappedItems.firstIndex(where: { $0.id >= storedFocusedId })
                    } else if let index = mappedItems.firstIndex(where: { $0.isPending }) {
                        focusedIndex = index
                    } else {
                        focusedIndex = mappedItems.firstIndex(where: { $0.id > state.maxReadId })
                    }
                }
                if focusedIndex == nil {
                    if !mappedItems.isEmpty {
                        focusedIndex = 0
                    }
                }
                
                self.currentMappedItems = mappedItems
                
                if let focusedIndex {
                    self.storedFocusedId = mappedItems[focusedIndex].id
                    
                    var previousItemId: Int32?
                    var nextItemId: Int32?
                    
                    if focusedIndex != 0 {
                        previousItemId = mappedItems[focusedIndex - 1].id
                    }
                    if focusedIndex != mappedItems.count - 1 {
                        nextItemId = mappedItems[focusedIndex + 1].id
                    }
                    
                    var loadKeys: [StoryKey] = []
                    if let mappedFocusedIndex = peerStoryItemsView.items.firstIndex(where: { $0.id == mappedItems[focusedIndex].id }) {
                        for index in (mappedFocusedIndex - 2) ... (mappedFocusedIndex + 2) {
                            if index >= 0 && index < peerStoryItemsView.items.count {
                                if let item = peerStoryItemsView.items[index].value.get(Stories.StoredItem.self), case .placeholder = item {
                                    loadKeys.append(StoryKey(peerId: peerId, id: item.id))
                                }
                            }
                        }
                        if !loadKeys.isEmpty {
                            loadIds(loadKeys)
                        }
                    }
                    
                    do {
                        let mappedItem = mappedItems[focusedIndex]
                        
                        var nextItems: [EngineStoryItem] = []
                        for i in (focusedIndex + 1) ..< min(focusedIndex + 4, mappedItems.count) {
                            do {
                                let item = mappedItems[i]
                                nextItems.append(item)
                            }
                        }
                        
                        self.nextItems = nextItems
                        self.sliceValue = StoryContentContextState.FocusedSlice(
                            peer: peer,
                            additionalPeerData: additionalPeerData,
                            item: StoryContentItem(
                                id: AnyHashable(mappedItem.id),
                                position: focusedIndex,
                                component: AnyComponent(StoryItemContentComponent(
                                    context: context,
                                    peer: peer,
                                    item: mappedItem
                                )),
                                centerInfoComponent: AnyComponent(StoryAuthorInfoComponent(
                                    context: context,
                                    peer: peer,
                                    timestamp: mappedItem.timestamp
                                )),
                                rightInfoComponent: AnyComponent(StoryAvatarInfoComponent(
                                    context: context,
                                    peer: peer
                                )),
                                peerId: peer.id,
                                storyItem: mappedItem,
                                isMy: peerId == context.account.peerId
                            ),
                            totalCount: mappedItems.count,
                            previousItemId: previousItemId,
                            nextItemId: nextItemId
                        )
                        self.isReady = true
                        self.updated.set(.single(Void()))
                    }
                } else {
                    self.isReady = true
                    self.updated.set(.single(Void()))
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.loadDisposable?.dispose()
        }
    }
    
    private final class StateContext {
        let centralPeerContext: PeerContext
        let previousPeerContext: PeerContext?
        let nextPeerContext: PeerContext?
        
        let updated = Promise<Void>()
        
        var isReady: Bool {
            if !self.centralPeerContext.isReady {
                return false
            }
            return true
        }
        
        private var centralDisposable: Disposable?
        private var previousDisposable: Disposable?
        private var nextDisposable: Disposable?
        
        init(
            centralPeerContext: PeerContext,
            previousPeerContext: PeerContext?,
            nextPeerContext: PeerContext?
        ) {
            self.centralPeerContext = centralPeerContext
            self.previousPeerContext = previousPeerContext
            self.nextPeerContext = nextPeerContext
            
            self.centralDisposable = (centralPeerContext.updated.get()
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                self.updated.set(.single(Void()))
            })
            
            if let previousPeerContext {
                self.previousDisposable = (previousPeerContext.updated.get()
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updated.set(.single(Void()))
                })
            }
            
            if let nextPeerContext {
                self.nextDisposable = (nextPeerContext.updated.get()
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updated.set(.single(Void()))
                })
            }
        }
        
        deinit {
            self.centralDisposable?.dispose()
            self.previousDisposable?.dispose()
            self.nextDisposable?.dispose()
        }
        
        func findPeerContext(id: EnginePeer.Id) -> PeerContext? {
            if self.centralPeerContext.sliceValue?.peer.id == id {
                return self.centralPeerContext
            }
            if let previousPeerContext = self.previousPeerContext, previousPeerContext.sliceValue?.peer.id == id {
                return previousPeerContext
            }
            if let nextPeerContext = self.nextPeerContext, nextPeerContext.sliceValue?.peer.id == id {
                return nextPeerContext
            }
            return nil
        }
    }
    
    private let context: AccountContext
    private let isHidden: Bool
    
    public private(set) var stateValue: StoryContentContextState?
    public var state: Signal<StoryContentContextState, NoError> {
        return self.statePromise.get()
    }
    private let statePromise = Promise<StoryContentContextState>()
    
    private let updatedPromise = Promise<Void>()
    public var updated: Signal<Void, NoError> {
        return self.updatedPromise.get()
    }
    
    private var focusedItem: (peerId: EnginePeer.Id, storyId: Int32?)?
    
    private var currentState: StateContext?
    private var currentStateUpdatedDisposable: Disposable?
    
    private var pendingState: StateContext?
    private var pendingStateReadyDisposable: Disposable?
    
    private var storySubscriptions: EngineStorySubscriptions?
    private var fixedSubscriptionOrder: [EnginePeer.Id] = []
    private var startedWithUnseen: Bool?
    private var storySubscriptionsDisposable: Disposable?
    
    private var requestedStoryKeys = Set<StoryKey>()
    private var requestStoryDisposables = DisposableSet()
    
    private var preloadStoryResourceDisposables: [MediaResourceId: Disposable] = [:]
    private var pollStoryMetadataDisposables = DisposableSet()
    
    private var singlePeerListContext: PeerExpiringStoryListContext?
    
    public init(
        context: AccountContext,
        isHidden: Bool,
        focusedPeerId: EnginePeer.Id?,
        singlePeer: Bool
    ) {
        self.context = context
        self.isHidden = isHidden
        if let focusedPeerId {
            self.focusedItem = (focusedPeerId, nil)
        }
        
        if singlePeer {
            guard let focusedPeerId else {
                assertionFailure()
                return
            }
            let singlePeerListContext = PeerExpiringStoryListContext(account: context.account, peerId: focusedPeerId)
            self.singlePeerListContext = singlePeerListContext
            self.storySubscriptionsDisposable = (combineLatest(
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: focusedPeerId)),
                singlePeerListContext.state
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer, state in
                guard let self, let peer else {
                    return
                }
                
                let storySubscriptions = EngineStorySubscriptions(
                    accountItem: nil,
                    items: [EngineStorySubscriptions.Item(
                        peer: peer,
                        hasUnseen: state.hasUnseen,
                        storyCount: state.items.count,
                        unseenCount: 0,
                        lastTimestamp: state.items.last?.timestamp ?? 0
                    )],
                    hasMoreToken: nil
                )
                
                let startedWithUnseen: Bool
                if let current = self.startedWithUnseen {
                    startedWithUnseen = current
                } else {
                    var startedWithUnseenValue = false
                    
                    if let (focusedPeerId, _) = self.focusedItem, focusedPeerId == self.context.account.peerId {
                    } else {
                        var centralIndex: Int?
                        if let (focusedPeerId, _) = self.focusedItem {
                            if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == focusedPeerId }) {
                                centralIndex = index
                            }
                        }
                        if centralIndex == nil {
                            if let index = storySubscriptions.items.firstIndex(where: { $0.hasUnseen }) {
                                centralIndex = index
                            }
                        }
                        if centralIndex == nil {
                            if !storySubscriptions.items.isEmpty {
                                centralIndex = 0
                            }
                        }
                        
                        if let centralIndex {
                            if storySubscriptions.items[centralIndex].hasUnseen {
                                startedWithUnseenValue = true
                            }
                        }
                    }
                    
                    self.startedWithUnseen = startedWithUnseenValue
                    startedWithUnseen = startedWithUnseenValue
                }
                
                var sortedItems: [EngineStorySubscriptions.Item] = []
                for peerId in self.fixedSubscriptionOrder {
                    if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == peerId }) {
                        sortedItems.append(storySubscriptions.items[index])
                    }
                }
                for item in storySubscriptions.items {
                    if !sortedItems.contains(where: { $0.peer.id == item.peer.id }) {
                        if startedWithUnseen {
                            if !item.hasUnseen {
                                continue
                            }
                        }
                        sortedItems.append(item)
                    }
                }
                self.fixedSubscriptionOrder = sortedItems.map(\.peer.id)
                
                self.storySubscriptions = EngineStorySubscriptions(
                    accountItem: storySubscriptions.accountItem,
                    items: sortedItems,
                    hasMoreToken: storySubscriptions.hasMoreToken
                )
                self.updatePeerContexts()
            })
        } else {
            self.storySubscriptionsDisposable = (context.engine.messages.storySubscriptions(isHidden: isHidden)
            |> deliverOnMainQueue).start(next: { [weak self] storySubscriptions in
                guard let self else {
                    return
                }
                
                let startedWithUnseen: Bool
                if let current = self.startedWithUnseen {
                    startedWithUnseen = current
                } else {
                    var startedWithUnseenValue = false
                    
                    if let (focusedPeerId, _) = self.focusedItem, focusedPeerId == self.context.account.peerId {
                    } else {
                        var centralIndex: Int?
                        if let (focusedPeerId, _) = self.focusedItem {
                            if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == focusedPeerId }) {
                                centralIndex = index
                            }
                        }
                        if centralIndex == nil {
                            if let index = storySubscriptions.items.firstIndex(where: { $0.hasUnseen }) {
                                centralIndex = index
                            }
                        }
                        if centralIndex == nil {
                            if !storySubscriptions.items.isEmpty {
                                centralIndex = 0
                            }
                        }
                        
                        if let centralIndex {
                            if storySubscriptions.items[centralIndex].hasUnseen {
                                startedWithUnseenValue = true
                            }
                        }
                    }
                    
                    self.startedWithUnseen = startedWithUnseenValue
                    startedWithUnseen = startedWithUnseenValue
                }
                
                var sortedItems: [EngineStorySubscriptions.Item] = []
                if !startedWithUnseen, let accountItem = storySubscriptions.accountItem, accountItem.storyCount != 0 {
                    sortedItems.append(accountItem)
                }
                for peerId in self.fixedSubscriptionOrder {
                    if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == peerId }) {
                        sortedItems.append(storySubscriptions.items[index])
                    }
                }
                for item in storySubscriptions.items {
                    if !sortedItems.contains(where: { $0.peer.id == item.peer.id }) {
                        if startedWithUnseen {
                            if !item.hasUnseen {
                                continue
                            }
                        }
                        sortedItems.append(item)
                    }
                }
                self.fixedSubscriptionOrder = sortedItems.map(\.peer.id)
                
                self.storySubscriptions = EngineStorySubscriptions(
                    accountItem: storySubscriptions.accountItem,
                    items: sortedItems,
                    hasMoreToken: storySubscriptions.hasMoreToken
                )
                self.updatePeerContexts()
            })
        }
    }
    
    deinit {
        self.storySubscriptionsDisposable?.dispose()
        self.requestStoryDisposables.dispose()
        for (_, disposable) in self.preloadStoryResourceDisposables {
            disposable.dispose()
        }
        self.pollStoryMetadataDisposables.dispose()
        self.storySubscriptionsDisposable?.dispose()
    }
    
    private func updatePeerContexts() {
        if let currentState = self.currentState {
            let _ = currentState
        } else {
            self.switchToFocusedPeerId()
        }
    }
    
    private func switchToFocusedPeerId() {
        if let currentStorySubscriptions = self.storySubscriptions {
            let subscriptionItems = currentStorySubscriptions.items
            
            if self.pendingState == nil {
                let loadIds: ([StoryKey]) -> Void = { [weak self] keys in
                    guard let self else {
                        return
                    }
                    let missingKeys = Set(keys).subtracting(self.requestedStoryKeys)
                    if !missingKeys.isEmpty {
                        var idsByPeerId: [EnginePeer.Id: [Int32]] = [:]
                        for key in missingKeys {
                            if idsByPeerId[key.peerId] == nil {
                                idsByPeerId[key.peerId] = [key.id]
                            } else {
                                idsByPeerId[key.peerId]?.append(key.id)
                            }
                        }
                        for (peerId, ids) in idsByPeerId {
                            self.requestStoryDisposables.add(self.context.engine.messages.refreshStories(peerId: peerId, ids: ids).start())
                        }
                    }
                }
                
                var centralIndex: Int?
                if let (focusedPeerId, _) = self.focusedItem {
                    if let index = subscriptionItems.firstIndex(where: { $0.peer.id == focusedPeerId }) {
                        centralIndex = index
                    }
                }
                if centralIndex == nil {
                    if !subscriptionItems.isEmpty {
                        centralIndex = 0
                    }
                }
                
                if let centralIndex {
                    let centralPeerContext: PeerContext
                    if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: subscriptionItems[centralIndex].peer.id) {
                        centralPeerContext = existingContext
                    } else {
                        centralPeerContext = PeerContext(context: self.context, peerId: subscriptionItems[centralIndex].peer.id, focusedId: nil, loadIds: loadIds)
                    }
                    
                    var previousPeerContext: PeerContext?
                    if centralIndex != 0 {
                        if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: subscriptionItems[centralIndex - 1].peer.id) {
                            previousPeerContext = existingContext
                        } else {
                            previousPeerContext = PeerContext(context: self.context, peerId: subscriptionItems[centralIndex - 1].peer.id, focusedId: nil, loadIds: loadIds)
                        }
                    }
                    
                    var nextPeerContext: PeerContext?
                    if centralIndex != subscriptionItems.count - 1 {
                        if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: subscriptionItems[centralIndex + 1].peer.id) {
                            nextPeerContext = existingContext
                        } else {
                            nextPeerContext = PeerContext(context: self.context, peerId: subscriptionItems[centralIndex + 1].peer.id, focusedId: nil, loadIds: loadIds)
                        }
                    }
                    
                    let pendingState = StateContext(
                        centralPeerContext: centralPeerContext,
                        previousPeerContext: previousPeerContext,
                        nextPeerContext: nextPeerContext
                    )
                    self.pendingState = pendingState
                    self.pendingStateReadyDisposable = (pendingState.updated.get()
                    |> deliverOnMainQueue).start(next: { [weak self, weak pendingState] _ in
                        guard let self, let pendingState, self.pendingState === pendingState, pendingState.isReady else {
                            return
                        }
                        self.pendingState = nil
                        self.pendingStateReadyDisposable?.dispose()
                        self.pendingStateReadyDisposable = nil
                        
                        self.currentState = pendingState
                        
                        self.updateState()
                        
                        self.currentStateUpdatedDisposable?.dispose()
                        self.currentStateUpdatedDisposable = (pendingState.updated.get()
                        |> deliverOnMainQueue).start(next: { [weak self, weak pendingState] _ in
                            guard let self, let pendingState, self.currentState === pendingState else {
                                return
                            }
                            self.updateState()
                        })
                    })
                }
            }
        }
    }
    
    private func updateState() {
        guard let currentState = self.currentState else {
            return
        }
        let stateValue = StoryContentContextState(
            slice: currentState.centralPeerContext.sliceValue,
            previousSlice: currentState.previousPeerContext?.sliceValue,
            nextSlice: currentState.nextPeerContext?.sliceValue
        )
        self.stateValue = stateValue
        self.statePromise.set(.single(stateValue))
        
        self.updatedPromise.set(.single(Void()))
        
        var possibleItems: [(EnginePeer, EngineStoryItem)] = []
        var pollItems: [StoryKey] = []
        if let slice = currentState.centralPeerContext.sliceValue {
            if slice.peer.id == self.context.account.peerId {
                pollItems.append(StoryKey(peerId: slice.peer.id, id: slice.item.storyItem.id))
            }
            
            for item in currentState.centralPeerContext.nextItems {
                possibleItems.append((slice.peer, item))
                
                if slice.peer.id == self.context.account.peerId {
                    pollItems.append(StoryKey(peerId: slice.peer.id, id: item.id))
                }
            }
        }
        if let nextPeerContext = currentState.nextPeerContext, let slice = nextPeerContext.sliceValue {
            possibleItems.append((slice.peer, slice.item.storyItem))
            for item in nextPeerContext.nextItems {
                possibleItems.append((slice.peer, item))
            }
        }
        
        var nextPriority = 0
        var resultResources: [EngineMediaResource.Id: StoryPreloadInfo] = [:]
        for i in 0 ..< min(possibleItems.count, 3) {
            let peer = possibleItems[i].0
            let item = possibleItems[i].1
            if let peerReference = PeerReference(peer._asPeer()) {
                if let image = item.media._asMedia() as? TelegramMediaImage, let resource = image.representations.last?.resource {
                    let resource = MediaResourceReference.media(media: .story(peer: peerReference, id: item.id, media: image), resource: resource)
                    resultResources[EngineMediaResource.Id(resource.resource.id)] = StoryPreloadInfo(
                        resource: resource,
                        size: nil,
                        priority: .top(position: nextPriority)
                    )
                    nextPriority += 1
                } else if let file = item.media._asMedia() as? TelegramMediaFile {
                    if let preview = file.previewRepresentations.last {
                        let resource = MediaResourceReference.media(media: .story(peer: peerReference, id: item.id, media: file), resource: preview.resource)
                        resultResources[EngineMediaResource.Id(resource.resource.id)] = StoryPreloadInfo(
                            resource: resource,
                            size: nil,
                            priority: .top(position: nextPriority)
                        )
                        nextPriority += 1
                    }
                    
                    let resource = MediaResourceReference.media(media: .story(peer: peerReference, id: item.id, media: file), resource: file.resource)
                    resultResources[EngineMediaResource.Id(resource.resource.id)] = StoryPreloadInfo(
                        resource: resource,
                        size: file.preloadSize,
                        priority: .top(position: nextPriority)
                    )
                    nextPriority += 1
                }
            }
        }
        
        var validIds: [MediaResourceId] = []
        for (_, info) in resultResources.sorted(by: { $0.value.priority < $1.value.priority }) {
            let resource = info.resource
            validIds.append(resource.resource.id)
            if self.preloadStoryResourceDisposables[resource.resource.id] == nil {
                var fetchRange: (Range<Int64>, MediaBoxFetchPriority)?
                if let size = info.size {
                    fetchRange = (0 ..< Int64(size), .default)
                }
                self.preloadStoryResourceDisposables[resource.resource.id] = fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: resource, range: fetchRange).start()
            }
        }
        
        var removeIds: [MediaResourceId] = []
        for (id, disposable) in self.preloadStoryResourceDisposables {
            if !validIds.contains(id) {
                removeIds.append(id)
                disposable.dispose()
            }
        }
        for id in removeIds {
            self.preloadStoryResourceDisposables.removeValue(forKey: id)
        }
        
        var pollIdByPeerId: [EnginePeer.Id: [Int32]] = [:]
        for storyKey in pollItems.prefix(3) {
            if pollIdByPeerId[storyKey.peerId] == nil {
                pollIdByPeerId[storyKey.peerId] = [storyKey.id]
            } else {
                pollIdByPeerId[storyKey.peerId]?.append(storyKey.id)
            }
        }
        for (peerId, ids) in pollIdByPeerId {
            self.pollStoryMetadataDisposables.add(self.context.engine.messages.refreshStoryViews(peerId: peerId, ids: ids).start())
        }
    }
    
    public func resetSideStates() {
        guard let currentState = self.currentState else {
            return
        }
        if let previousPeerContext = currentState.previousPeerContext {
            previousPeerContext.currentFocusedId = nil
        }
        if let nextPeerContext = currentState.nextPeerContext {
            nextPeerContext.currentFocusedId = nil
        }
    }
    
    public func navigate(navigation: StoryContentContextNavigation) {
        guard let currentState = self.currentState else {
            return
        }
        
        switch navigation {
        case let .peer(direction):
            switch direction {
            case .previous:
                if let previousPeerContext = currentState.previousPeerContext, let previousSlice = previousPeerContext.sliceValue {
                    self.pendingStateReadyDisposable?.dispose()
                    self.pendingState = nil
                    self.focusedItem = (previousSlice.peer.id, nil)
                    self.switchToFocusedPeerId()
                }
            case .next:
                if let nextPeerContext = currentState.nextPeerContext, let nextSlice = nextPeerContext.sliceValue {
                    self.pendingStateReadyDisposable?.dispose()
                    self.pendingState = nil
                    self.focusedItem = (nextSlice.peer.id, nil)
                    self.switchToFocusedPeerId()
                }
            }
        case let .item(direction):
            if let slice = currentState.centralPeerContext.sliceValue {
                switch direction {
                case .previous:
                    if let previousItemId = slice.previousItemId {
                        currentState.centralPeerContext.currentFocusedId = previousItemId
                    }
                case .next:
                    if let nextItemId = slice.nextItemId {
                        currentState.centralPeerContext.currentFocusedId = nextItemId
                    }
                }
            }
        }
    }
    
    public func markAsSeen(id: StoryId) {
        let _ = self.context.engine.messages.markStoryAsSeen(peerId: id.peerId, id: id.id, asPinned: false).start()
    }
}

public final class SingleStoryContentContextImpl: StoryContentContext {
    private let context: AccountContext
    
    public private(set) var stateValue: StoryContentContextState?
    public var state: Signal<StoryContentContextState, NoError> {
        return self.statePromise.get()
    }
    private let statePromise = Promise<StoryContentContextState>()
    
    private let updatedPromise = Promise<Void>()
    public var updated: Signal<Void, NoError> {
        return self.updatedPromise.get()
    }
    
    private var storyDisposable: Disposable?
    
    private var requestedStoryKeys = Set<StoryKey>()
    private var requestStoryDisposables = DisposableSet()
    
    public init(
        context: AccountContext,
        storyId: StoryId
    ) {
        self.context = context
        
        self.storyDisposable = (combineLatest(queue: .mainQueue(),
            context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: storyId.peerId),
                TelegramEngine.EngineData.Item.Peer.AreVoiceMessagesAvailable(id: storyId.peerId),
                TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: storyId.peerId),
                TelegramEngine.EngineData.Item.NotificationSettings.Global()
            ),
            context.account.postbox.transaction { transaction -> (Stories.StoredItem?, [PeerId: Peer]) in
                guard let item = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self) else {
                    return (nil, [:])
                }
                var peers: [PeerId: Peer] = [:]
                if case let .item(item) = item {
                    if let views = item.views {
                        for id in views.seenPeerIds {
                            if let peer = transaction.getPeer(id) {
                                peers[peer.id] = peer
                            }
                        }
                    }
                }
                return (item, peers)
            }
        )
        |> deliverOnMainQueue).start(next: { [weak self] data, itemAndPeers in
            guard let self else {
                return
            }
            
            let (peer, areVoiceMessagesAvailable, notificationSettings, globalNotificationSettings) = data
            let (item, peers) = itemAndPeers
            
            var isMuted = false
            if let storiesMuted = notificationSettings.storiesMuted {
                isMuted = storiesMuted
            } else {
                isMuted = globalNotificationSettings.privateChats.storiesMuted
            }
            
            let additionalPeerData = StoryContentContextState.AdditionalPeerData(
                isMuted: isMuted,
                areVoiceMessagesAvailable: areVoiceMessagesAvailable
            )
            
            if item == nil {
                let storyKey = StoryKey(peerId: storyId.peerId, id: storyId.id)
                if !self.requestedStoryKeys.contains(storyKey) {
                    self.requestedStoryKeys.insert(storyKey)
                    
                    self.requestStoryDisposables.add(self.context.engine.messages.refreshStories(peerId: storyId.peerId, ids: [storyId.id]).start())
                }
            }
            
            if let item, case let .item(itemValue) = item, let media = itemValue.media, let peer {
                let mappedItem = EngineStoryItem(
                    id: itemValue.id,
                    timestamp: itemValue.timestamp,
                    expirationTimestamp: itemValue.expirationTimestamp,
                    media: EngineMedia(media),
                    text: itemValue.text,
                    entities: itemValue.entities,
                    views: itemValue.views.flatMap { views in
                        return EngineStoryItem.Views(
                            seenCount: views.seenCount,
                            seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                return peers[id].flatMap(EnginePeer.init)
                            }
                        )
                    },
                    privacy: itemValue.privacy.flatMap(EngineStoryPrivacy.init),
                    isPinned: itemValue.isPinned,
                    isExpired: itemValue.isExpired,
                    isPublic: itemValue.isPublic,
                    isPending: false
                )
                
                let stateValue = StoryContentContextState(
                    slice: StoryContentContextState.FocusedSlice(
                        peer: peer,
                        additionalPeerData: additionalPeerData,
                        item: StoryContentItem(
                            id: AnyHashable(item.id),
                            position: 0,
                            component: AnyComponent(StoryItemContentComponent(
                                context: context,
                                peer: peer,
                                item: mappedItem
                            )),
                            centerInfoComponent: AnyComponent(StoryAuthorInfoComponent(
                                context: context,
                                peer: peer,
                                timestamp: item.timestamp
                            )),
                            rightInfoComponent: AnyComponent(StoryAvatarInfoComponent(
                                context: context,
                                peer: peer
                            )),
                            peerId: peer.id,
                            storyItem: mappedItem,
                            isMy: peer.id == context.account.peerId
                        ),
                        totalCount: 1,
                        previousItemId: nil,
                        nextItemId: nil
                    ),
                    previousSlice: nil,
                    nextSlice: nil
                )
                
                if self.stateValue == nil || self.stateValue?.slice != stateValue.slice {
                    self.stateValue = stateValue
                    self.statePromise.set(.single(stateValue))
                    self.updatedPromise.set(.single(Void()))
                }
            } else {
                let stateValue = StoryContentContextState(
                    slice: nil,
                    previousSlice: nil,
                    nextSlice: nil
                )
                
                if self.stateValue == nil || self.stateValue?.slice != stateValue.slice {
                    self.stateValue = stateValue
                    self.statePromise.set(.single(stateValue))
                    self.updatedPromise.set(.single(Void()))
                }
            }
        })
    }
    
    deinit {
        self.storyDisposable?.dispose()
        self.requestStoryDisposables.dispose()
    }
    
    public func resetSideStates() {
    }
    
    public func navigate(navigation: StoryContentContextNavigation) {
    }
    
    public func markAsSeen(id: StoryId) {
    }
}

public final class PeerStoryListContentContextImpl: StoryContentContext {
    private let context: AccountContext
    
    public private(set) var stateValue: StoryContentContextState?
    public var state: Signal<StoryContentContextState, NoError> {
        return self.statePromise.get()
    }
    private let statePromise = Promise<StoryContentContextState>()
    
    private let updatedPromise = Promise<Void>()
    public var updated: Signal<Void, NoError> {
        return self.updatedPromise.get()
    }
    
    private var storyDisposable: Disposable?
    
    private var requestedStoryKeys = Set<StoryKey>()
    private var requestStoryDisposables = DisposableSet()
    
    private var listState: PeerStoryListContext.State?
    
    private var focusedId: Int32?
    private var focusedIdUpdated = Promise<Void>(Void())
    
    private var preloadStoryResourceDisposables: [MediaResourceId: Disposable] = [:]
    private var pollStoryMetadataDisposables = DisposableSet()
    
    public init(context: AccountContext, peerId: EnginePeer.Id, listContext: PeerStoryListContext, initialId: Int32?) {
        self.context = context
        
        self.storyDisposable = (combineLatest(queue: .mainQueue(),
            context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.AreVoiceMessagesAvailable(id: peerId),
                TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId),
                TelegramEngine.EngineData.Item.NotificationSettings.Global()
            ),
            listContext.state,
            self.focusedIdUpdated.get()
        )
        //|> delay(0.4, queue: .mainQueue())
        |> deliverOnMainQueue).start(next: { [weak self] data, state, _ in
            guard let self else {
                return
            }
            
            let (peer, areVoiceMessagesAvailable, notificationSettings, globalNotificationSettings) = data
            
            var isMuted = false
            if let storiesMuted = notificationSettings.storiesMuted {
                isMuted = storiesMuted
            } else {
                isMuted = globalNotificationSettings.privateChats.storiesMuted
            }
            
            let additionalPeerData = StoryContentContextState.AdditionalPeerData(
                isMuted: isMuted,
                areVoiceMessagesAvailable: areVoiceMessagesAvailable
            )
            
            self.listState = state
            
            let focusedIndex: Int?
            if let current = self.focusedId {
                if let index = state.items.firstIndex(where: { $0.id == current }) {
                    focusedIndex = index
                } else if let index = state.items.firstIndex(where: { $0.id >= current }) {
                    focusedIndex = index
                } else if !state.items.isEmpty {
                    focusedIndex = 0
                } else {
                    focusedIndex = nil
                }
            } else if let initialId = initialId {
                if let index = state.items.firstIndex(where: { $0.id == initialId }) {
                    focusedIndex = index
                } else if let index = state.items.firstIndex(where: { $0.id >= initialId }) {
                    focusedIndex = index
                } else {
                    focusedIndex = nil
                }
            } else {
                if !state.items.isEmpty {
                    focusedIndex = 0
                } else {
                    focusedIndex = nil
                }
            }
            
            let stateValue: StoryContentContextState
            if let focusedIndex = focusedIndex, let peer = peer {
                let item = state.items[focusedIndex]
                self.focusedId = item.id
                
                stateValue = StoryContentContextState(
                    slice: StoryContentContextState.FocusedSlice(
                        peer: peer,
                        additionalPeerData: additionalPeerData,
                        item: StoryContentItem(
                            id: AnyHashable(item.id),
                            position: nil,
                            component: AnyComponent(StoryItemContentComponent(
                                context: context,
                                peer: peer,
                                item: item
                            )),
                            centerInfoComponent: AnyComponent(StoryPositionInfoComponent(
                                context: context,
                                position: focusedIndex,
                                totalCount: state.totalCount
                            )),
                            rightInfoComponent: AnyComponent(StoryAvatarInfoComponent(
                                context: context,
                                peer: peer
                            )),
                            peerId: peer.id,
                            storyItem: item,
                            isMy: peerId == self.context.account.peerId
                        ),
                        totalCount: state.totalCount,
                        previousItemId: focusedIndex == 0 ? nil : state.items[focusedIndex - 1].id,
                        nextItemId: (focusedIndex == state.items.count - 1) ? nil : state.items[focusedIndex + 1].id
                    ),
                    previousSlice: nil,
                    nextSlice: nil
                )
            } else {
                self.focusedId = nil
                
                stateValue = StoryContentContextState(
                    slice: nil,
                    previousSlice: nil,
                    nextSlice: nil
                )
            }
            
            if self.stateValue == nil || self.stateValue?.slice != stateValue.slice {
                self.stateValue = stateValue
                self.statePromise.set(.single(stateValue))
                self.updatedPromise.set(.single(Void()))
                
                var resultResources: [EngineMediaResource.Id: StoryPreloadInfo] = [:]
                var pollItems: [StoryKey] = []
                
                if let peer, let focusedIndex, let slice = stateValue.slice {
                    var possibleItems: [(EnginePeer, EngineStoryItem)] = []
                    if peer.id == self.context.account.peerId {
                        pollItems.append(StoryKey(peerId: peer.id, id: slice.item.storyItem.id))
                    }
                    
                    for i in focusedIndex ..< min(focusedIndex + 4, state.items.count) {
                        if i != focusedIndex {
                            possibleItems.append((slice.peer, state.items[i]))
                        }
                        
                        if slice.peer.id == self.context.account.peerId {
                            pollItems.append(StoryKey(peerId: slice.peer.id, id: state.items[i].id))
                        }
                    }
                    
                    var nextPriority = 0
                    for i in 0 ..< min(possibleItems.count, 3) {
                        let peer = possibleItems[i].0
                        let item = possibleItems[i].1
                        if let peerReference = PeerReference(peer._asPeer()) {
                            if let image = item.media._asMedia() as? TelegramMediaImage, let resource = image.representations.last?.resource {
                                let resource = MediaResourceReference.media(media: .story(peer: peerReference, id: item.id, media: image), resource: resource)
                                resultResources[EngineMediaResource.Id(resource.resource.id)] = StoryPreloadInfo(
                                    resource: resource,
                                    size: nil,
                                    priority: .top(position: nextPriority)
                                )
                                nextPriority += 1
                            } else if let file = item.media._asMedia() as? TelegramMediaFile {
                                if let preview = file.previewRepresentations.last {
                                    let resource = MediaResourceReference.media(media: .story(peer: peerReference, id: item.id, media: file), resource: preview.resource)
                                    resultResources[EngineMediaResource.Id(resource.resource.id)] = StoryPreloadInfo(
                                        resource: resource,
                                        size: nil,
                                        priority: .top(position: nextPriority)
                                    )
                                    nextPriority += 1
                                }
                                
                                let resource = MediaResourceReference.media(media: .story(peer: peerReference, id: item.id, media: file), resource: file.resource)
                                resultResources[EngineMediaResource.Id(resource.resource.id)] = StoryPreloadInfo(
                                    resource: resource,
                                    size: file.preloadSize,
                                    priority: .top(position: nextPriority)
                                )
                                nextPriority += 1
                            }
                        }
                    }
                }
                
                var validIds: [MediaResourceId] = []
                for (_, info) in resultResources.sorted(by: { $0.value.priority < $1.value.priority }) {
                    let resource = info.resource
                    validIds.append(resource.resource.id)
                    if self.preloadStoryResourceDisposables[resource.resource.id] == nil {
                        var fetchRange: (Range<Int64>, MediaBoxFetchPriority)?
                        if let size = info.size {
                            fetchRange = (0 ..< Int64(size), .default)
                        }
                        self.preloadStoryResourceDisposables[resource.resource.id] = fetchedMediaResource(mediaBox: self.context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: resource, range: fetchRange).start()
                    }
                }
                
                var removeIds: [MediaResourceId] = []
                for (id, disposable) in self.preloadStoryResourceDisposables {
                    if !validIds.contains(id) {
                        removeIds.append(id)
                        disposable.dispose()
                    }
                }
                for id in removeIds {
                    self.preloadStoryResourceDisposables.removeValue(forKey: id)
                }
                
                var pollIdByPeerId: [EnginePeer.Id: [Int32]] = [:]
                for storyKey in pollItems.prefix(3) {
                    if pollIdByPeerId[storyKey.peerId] == nil {
                        pollIdByPeerId[storyKey.peerId] = [storyKey.id]
                    } else {
                        pollIdByPeerId[storyKey.peerId]?.append(storyKey.id)
                    }
                }
                for (peerId, ids) in pollIdByPeerId {
                    self.pollStoryMetadataDisposables.add(self.context.engine.messages.refreshStoryViews(peerId: peerId, ids: ids).start())
                }
            }
        })
    }
    
    deinit {
        self.storyDisposable?.dispose()
        self.requestStoryDisposables.dispose()
        
        for (_, disposable) in self.preloadStoryResourceDisposables {
            disposable.dispose()
        }
        self.pollStoryMetadataDisposables.dispose()
    }
    
    public func resetSideStates() {
    }
    
    public func navigate(navigation: StoryContentContextNavigation) {
        switch navigation {
        case .peer:
            break
        case let .item(direction):
            let indexDifference: Int
            switch direction {
            case .next:
                indexDifference = 1
            case .previous:
                indexDifference = -1
            }
            
            if let listState = self.listState, let focusedId = self.focusedId {
                if let index = listState.items.firstIndex(where: { $0.id == focusedId }) {
                    var nextIndex = index + indexDifference
                    if nextIndex < 0 {
                        nextIndex = 0
                    }
                    if nextIndex > listState.items.count - 1 {
                        nextIndex = listState.items.count - 1
                    }
                    if nextIndex != index {
                        self.focusedId = listState.items[nextIndex].id
                        self.focusedIdUpdated.set(.single(Void()))
                    }
                }
            }
        }
    }
    
    public func markAsSeen(id: StoryId) {
        let _ = self.context.engine.messages.markStoryAsSeen(peerId: id.peerId, id: id.id, asPinned: true).start()
    }
}
