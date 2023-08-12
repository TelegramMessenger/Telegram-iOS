import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import Postbox
import MediaResources
import RangeSet

private struct StoryKey: Hashable {
    var peerId: EnginePeer.Id
    var id: Int32
}

public final class StoryContentContextImpl: StoryContentContext {
    private final class PeerContext {
        private let context: AccountContext
        let peerId: EnginePeer.Id
        
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
                PostboxViewKey.peerPresences(peerIds: Set([peerId]))
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
            |> mapToSignal { _, views, globalNotificationSettings -> Signal<(CombinedView, [PeerId: Peer], EngineGlobalNotificationSettings, [MediaId: TelegramMediaFile]), NoError> in
                return context.account.postbox.transaction { transaction -> (CombinedView, [PeerId: Peer], EngineGlobalNotificationSettings, [MediaId: TelegramMediaFile]) in
                    var peers: [PeerId: Peer] = [:]
                    var allEntityFiles: [MediaId: TelegramMediaFile] = [:]
                    
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
                                for entity in itemValue.entities {
                                    if case let .CustomEmoji(_, fileId) = entity.type {
                                        let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                        if allEntityFiles[mediaId] == nil {
                                            if let file = transaction.getMedia(mediaId) as? TelegramMediaFile {
                                                allEntityFiles[file.fileId] = file
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    return (views, peers, globalNotificationSettings, allEntityFiles)
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] views, peers, globalNotificationSettings, allEntityFiles in
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
                var peerPresence: PeerPresence?
                if let presencesView = views.views[PostboxViewKey.peerPresences(peerIds: Set([peerId]))] as? PeerPresencesView {
                    peerPresence = presencesView.presences[peerId]
                }
                
                if let cachedPeerDataView = views.views[PostboxViewKey.cachedPeerData(peerId: peerId)] as? CachedPeerDataView, let cachedUserData = cachedPeerDataView.cachedPeerData as? CachedUserData {
                    var isMuted = false
                    if let notificationSettings = peerView.notificationSettings as? TelegramPeerNotificationSettings {
                        isMuted = resolvedAreStoriesMuted(globalSettings: globalNotificationSettings._asGlobalNotificationSettings(), peer: peer._asPeer(), peerSettings: notificationSettings, topSearchPeers: [])
                    } else {
                        isMuted = resolvedAreStoriesMuted(globalSettings: globalNotificationSettings._asGlobalNotificationSettings(), peer: peer._asPeer(), peerSettings: nil, topSearchPeers: [])
                    }
                    additionalPeerData = StoryContentContextState.AdditionalPeerData(
                        isMuted: isMuted,
                        areVoiceMessagesAvailable: cachedUserData.voiceMessagesAvailable,
                        presence: peerPresence.flatMap { EnginePeer.Presence($0) }
                    )
                } else {
                    additionalPeerData = StoryContentContextState.AdditionalPeerData(
                        isMuted: true,
                        areVoiceMessagesAvailable: true,
                        presence: peerPresence.flatMap { EnginePeer.Presence($0) }
                    )
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
                        mediaAreas: item.mediaAreas,
                        text: item.text,
                        entities: item.entities,
                        views: item.views.flatMap { views in
                            return EngineStoryItem.Views(
                                seenCount: views.seenCount,
                                reactedCount: views.reactedCount,
                                seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                    return peers[id].flatMap(EnginePeer.init)
                                },
                                hasList: views.hasList
                            )
                        },
                        privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                        isPinned: item.isPinned,
                        isExpired: item.isExpired,
                        isPublic: item.isPublic,
                        isPending: false,
                        isCloseFriends: item.isCloseFriends,
                        isContacts: item.isContacts,
                        isSelectedContacts: item.isSelectedContacts,
                        isForwardingDisabled: item.isForwardingDisabled,
                        isEdited: item.isEdited,
                        myReaction: item.myReaction
                    )
                }
                var totalCount = peerStoryItemsView.items.count
                if peerId == context.account.peerId, let stateView = views.views[PostboxViewKey.storiesState(key: .local)] as? StoryStatesView, let localState = stateView.value?.get(Stories.LocalState.self) {
                    for item in localState.items {
                        mappedItems.append(EngineStoryItem(
                            id: item.stableId,
                            timestamp: item.timestamp,
                            expirationTimestamp: Int32.max,
                            media: EngineMedia(item.media),
                            mediaAreas: item.mediaAreas,
                            text: item.text,
                            entities: item.entities,
                            views: nil,
                            privacy: item.privacy,
                            isPinned: item.pin,
                            isExpired: false,
                            isPublic: item.privacy.base == .everyone,
                            isPending: true,
                            isCloseFriends: item.privacy.base == .closeFriends,
                            isContacts: item.privacy.base == .contacts,
                            isSelectedContacts: item.privacy.base == .nobody,
                            isForwardingDisabled: false,
                            isEdited: false,
                            myReaction: nil
                        ))
                        totalCount += 1
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
                    
                    let mappedFocusedIndex = peerStoryItemsView.items.firstIndex(where: { $0.id == mappedItems[focusedIndex].id })
                    
                    var loadKeys: [StoryKey] = []
                    if let mappedFocusedIndex {
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
                        
                        let allItems = mappedItems.map { item in
                            return StoryContentItem(
                                position: nil,
                                dayCounters: nil,
                                peerId: peer.id,
                                storyItem: item,
                                entityFiles: extractItemEntityFiles(item: item, allEntityFiles: allEntityFiles)
                            )
                        }
                        
                        self.nextItems = nextItems
                        self.sliceValue = StoryContentContextState.FocusedSlice(
                            peer: peer,
                            additionalPeerData: additionalPeerData,
                            item: StoryContentItem(
                                position: mappedFocusedIndex ?? focusedIndex,
                                dayCounters: nil,
                                peerId: peer.id,
                                storyItem: mappedItem,
                                entityFiles: extractItemEntityFiles(item: mappedItem, allEntityFiles: allEntityFiles)
                            ),
                            totalCount: totalCount,
                            previousItemId: previousItemId,
                            nextItemId: nextItemId,
                            allItems: allItems
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
    
    private var preloadStoryResourceDisposables: [MediaId: Disposable] = [:]
    private var pollStoryMetadataDisposables: [StoryId: Disposable] = [:]
    
    private var singlePeerListContext: PeerExpiringStoryListContext?
    
    public init(
        context: AccountContext,
        isHidden: Bool,
        focusedPeerId: EnginePeer.Id?,
        singlePeer: Bool,
        fixedOrder: [EnginePeer.Id] = []
    ) {
        self.context = context
        self.isHidden = isHidden
        if let focusedPeerId {
            self.focusedItem = (focusedPeerId, nil)
        }
        self.fixedSubscriptionOrder = fixedOrder
        
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
                
                if state.isLoading {
                    return
                }
                
                let storySubscriptions = EngineStorySubscriptions(
                    accountItem: nil,
                    items: [EngineStorySubscriptions.Item(
                        peer: peer,
                        hasUnseen: state.hasUnseen,
                        hasUnseenCloseFriends: state.hasUnseenCloseFriends,
                        hasPending: false,
                        storyCount: state.items.count,
                        unseenCount: 0,
                        lastTimestamp: state.items.last?.timestamp ?? 0
                    )],
                    hasMoreToken: nil
                )
                
                var preFilterOrder = false
                
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
                    preFilterOrder = true
                }
                
                var sortedItems: [EngineStorySubscriptions.Item] = []
                for peerId in self.fixedSubscriptionOrder {
                    if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == peerId }) {
                        if preFilterOrder {
                            if startedWithUnseen && !storySubscriptions.items[index].hasUnseen {
                                continue
                            }
                        }
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
            self.storySubscriptionsDisposable = (context.engine.messages.storySubscriptions(isHidden: isHidden, tempKeepNewlyArchived: true)
            |> deliverOnMainQueue).start(next: { [weak self] storySubscriptions in
                guard let self else {
                    return
                }
                
                var preFilterOrder = false
                
                let startedWithUnseen: Bool
                if let current = self.startedWithUnseen {
                    startedWithUnseen = current
                } else {
                    var startedWithUnseenValue = false
                    
                    if let (focusedPeerId, _) = self.focusedItem, focusedPeerId == self.context.account.peerId, let accountItem = storySubscriptions.accountItem {
                        startedWithUnseenValue = accountItem.hasUnseen || accountItem.hasPending
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
                    preFilterOrder = true
                }
                
                var sortedItems: [EngineStorySubscriptions.Item] = []
                if !isHidden, let accountItem = storySubscriptions.accountItem {
                    if self.fixedSubscriptionOrder.contains(context.account.peerId) {
                        sortedItems.append(accountItem)
                    } else {
                        if startedWithUnseen {
                            if accountItem.hasUnseen || accountItem.hasPending {
                                sortedItems.append(accountItem)
                            }
                        } else {
                            sortedItems.append(accountItem)
                        }
                    }
                }
                for peerId in self.fixedSubscriptionOrder {
                    if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == peerId }) {
                        if preFilterOrder {
                            if startedWithUnseen && !storySubscriptions.items[index].hasUnseen {
                                continue
                            }
                        }
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
        for (_, disposable) in self.pollStoryMetadataDisposables {
            disposable.dispose()
        }
        self.storySubscriptionsDisposable?.dispose()
    }
    
    private func updatePeerContexts() {
        if let currentState = self.currentState, let storySubscriptions = self.storySubscriptions, !storySubscriptions.items.contains(where: { $0.peer.id == currentState.centralPeerContext.peerId }) {
            self.currentState = nil
        }
        
        if self.currentState == nil {
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
        } else {
            self.updateState()
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
        var resultResources: [EngineMedia.Id: StoryPreloadInfo] = [:]
        for i in 0 ..< min(possibleItems.count, 3) {
            let peer = possibleItems[i].0
            let item = possibleItems[i].1
            if let peerReference = PeerReference(peer._asPeer()), let mediaId = item.media.id {
                resultResources[mediaId] = StoryPreloadInfo(
                    peer: peerReference,
                    storyId: item.id,
                    media: item.media,
                    priority: .top(position: nextPriority)
                )
                nextPriority += 1
            }
        }
        
        var validIds: [EngineMedia.Id] = []
        for (id, info) in resultResources.sorted(by: { $0.value.priority < $1.value.priority }) {
            validIds.append(id)
            if self.preloadStoryResourceDisposables[id] == nil {
                self.preloadStoryResourceDisposables[id] = preloadStoryMedia(context: context, peer: info.peer, storyId: info.storyId, media: info.media).start()
            }
        }
        
        var removeIds: [EngineMedia.Id] = []
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
            for id in ids {
                if self.pollStoryMetadataDisposables[StoryId(peerId: peerId, id: id)] == nil {
                    self.pollStoryMetadataDisposables[StoryId(peerId: peerId, id: id)] = self.context.engine.messages.refreshStoryViews(peerId: peerId, ids: ids).start()
                }
            }
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
                case let .id(id):
                    if slice.allItems.contains(where: { $0.storyItem.id == id }) {
                        currentState.centralPeerContext.currentFocusedId = id
                    }
                }
            }
        }
    }
    
    public func markAsSeen(id: StoryId) {
        if !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
            let _ = self.context.engine.messages.markStoryAsSeen(peerId: id.peerId, id: id.id, asPinned: false).start()
        }
    }
}

public final class SingleStoryContentContextImpl: StoryContentContext {
    private let context: AccountContext
    private let readGlobally: Bool
    
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
        storyId: StoryId,
        readGlobally: Bool
    ) {
        self.context = context
        self.readGlobally = readGlobally
        
        self.storyDisposable = (combineLatest(queue: .mainQueue(),
            context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: storyId.peerId),
                TelegramEngine.EngineData.Item.Peer.Presence(id: storyId.peerId),
                TelegramEngine.EngineData.Item.Peer.AreVoiceMessagesAvailable(id: storyId.peerId),
                TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: storyId.peerId),
                TelegramEngine.EngineData.Item.NotificationSettings.Global()
            ),
            context.account.postbox.combinedView(keys: [PostboxViewKey.story(id: storyId)]) |> mapToSignal { views -> Signal<(Stories.StoredItem?, [PeerId: Peer], [MediaId: TelegramMediaFile]), NoError> in
                let item = (views.views[PostboxViewKey.story(id: storyId)] as? StoryView)?.item?.get(Stories.StoredItem.self)
            
                return context.account.postbox.transaction { transaction -> (Stories.StoredItem?, [PeerId: Peer], [MediaId: TelegramMediaFile]) in
                    guard let item else {
                        return (nil, [:], [:])
                    }
                    var peers: [PeerId: Peer] = [:]
                    var allEntityFiles: [MediaId: TelegramMediaFile] = [:]
                    if case let .item(item) = item {
                        if let views = item.views {
                            for id in views.seenPeerIds {
                                if let peer = transaction.getPeer(id) {
                                    peers[peer.id] = peer
                                }
                            }
                        }
                        for entity in item.entities {
                            if case let .CustomEmoji(_, fileId) = entity.type {
                                let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                if allEntityFiles[mediaId] == nil {
                                    if let file = transaction.getMedia(mediaId) as? TelegramMediaFile {
                                        allEntityFiles[file.fileId] = file
                                    }
                                }
                            }
                        }
                    }
                    return (item, peers, allEntityFiles)
                }
            }
        )
        |> deliverOnMainQueue).start(next: { [weak self] data, itemAndPeers in
            guard let self else {
                return
            }
            
            let (peer, presence, areVoiceMessagesAvailable, notificationSettings, globalNotificationSettings) = data
            let (item, peers, allEntityFiles) = itemAndPeers
            
            guard let peer else {
                return
            }

            let isMuted = resolvedAreStoriesMuted(globalSettings: globalNotificationSettings._asGlobalNotificationSettings(), peer: peer._asPeer(), peerSettings: notificationSettings._asNotificationSettings(), topSearchPeers: [])
            
            let additionalPeerData = StoryContentContextState.AdditionalPeerData(
                isMuted: isMuted,
                areVoiceMessagesAvailable: areVoiceMessagesAvailable,
                presence: presence
            )
            
            if item == nil {
                let storyKey = StoryKey(peerId: storyId.peerId, id: storyId.id)
                if !self.requestedStoryKeys.contains(storyKey) {
                    self.requestedStoryKeys.insert(storyKey)
                    
                    self.requestStoryDisposables.add(self.context.engine.messages.refreshStories(peerId: storyId.peerId, ids: [storyId.id]).start())
                }
            }
            
            if let item, case let .item(itemValue) = item, let media = itemValue.media {
                let mappedItem = EngineStoryItem(
                    id: itemValue.id,
                    timestamp: itemValue.timestamp,
                    expirationTimestamp: itemValue.expirationTimestamp,
                    media: EngineMedia(media),
                    mediaAreas: itemValue.mediaAreas,
                    text: itemValue.text,
                    entities: itemValue.entities,
                    views: itemValue.views.flatMap { views in
                        return EngineStoryItem.Views(
                            seenCount: views.seenCount,
                            reactedCount: views.reactedCount,
                            seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                return peers[id].flatMap(EnginePeer.init)
                            },
                            hasList: views.hasList
                        )
                    },
                    privacy: itemValue.privacy.flatMap(EngineStoryPrivacy.init),
                    isPinned: itemValue.isPinned,
                    isExpired: itemValue.isExpired,
                    isPublic: itemValue.isPublic,
                    isPending: false,
                    isCloseFriends: itemValue.isCloseFriends,
                    isContacts: itemValue.isContacts,
                    isSelectedContacts: itemValue.isSelectedContacts,
                    isForwardingDisabled: itemValue.isForwardingDisabled,
                    isEdited: itemValue.isEdited,
                    myReaction: itemValue.myReaction
                )
                
                let mainItem = StoryContentItem(
                    position: 0,
                    dayCounters: nil,
                    peerId: peer.id,
                    storyItem: mappedItem,
                    entityFiles: extractItemEntityFiles(item: mappedItem, allEntityFiles: allEntityFiles)
                )
                let stateValue = StoryContentContextState(
                    slice: StoryContentContextState.FocusedSlice(
                        peer: peer,
                        additionalPeerData: additionalPeerData,
                        item: mainItem,
                        totalCount: 1,
                        previousItemId: nil,
                        nextItemId: nil,
                        allItems: [mainItem]
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
        if self.readGlobally {
            if !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
                let _ = self.context.engine.messages.markStoryAsSeen(peerId: id.peerId, id: id.id, asPinned: false).start()
            }
        }
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
    
    private var preloadStoryResourceDisposables: [EngineMedia.Id: Disposable] = [:]
    private var pollStoryMetadataDisposables = DisposableSet()
    
    public init(context: AccountContext, peerId: EnginePeer.Id, listContext: PeerStoryListContext, initialId: Int32?) {
        self.context = context
        
        self.storyDisposable = (combineLatest(queue: .mainQueue(),
            context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.Presence(id: peerId),
                TelegramEngine.EngineData.Item.Peer.AreVoiceMessagesAvailable(id: peerId),
                TelegramEngine.EngineData.Item.Peer.NotificationSettings(id: peerId),
                TelegramEngine.EngineData.Item.NotificationSettings.Global()
            ),
            listContext.state,
            self.focusedIdUpdated.get()
        )
        |> deliverOnMainQueue).start(next: { [weak self] data, state, _ in
            guard let self else {
                return
            }
            
            let (peer, presence, areVoiceMessagesAvailable, notificationSettings, globalNotificationSettings) = data
            
            guard let peer else {
                return
            }
            
            let isMuted = resolvedAreStoriesMuted(globalSettings: globalNotificationSettings._asGlobalNotificationSettings(), peer: peer._asPeer(), peerSettings: notificationSettings._asNotificationSettings(), topSearchPeers: [])
            
            let additionalPeerData = StoryContentContextState.AdditionalPeerData(
                isMuted: isMuted,
                areVoiceMessagesAvailable: areVoiceMessagesAvailable,
                presence: presence
            )
            
            self.listState = state
            
            let focusedIndex: Int?
            if let current = self.focusedId {
                if let index = state.items.firstIndex(where: { $0.id == current }) {
                    focusedIndex = index
                } else if let index = state.items.firstIndex(where: { $0.id <= current }) {
                    focusedIndex = index
                } else if !state.items.isEmpty {
                    focusedIndex = 0
                } else {
                    focusedIndex = nil
                }
            } else if let initialId = initialId {
                if let index = state.items.firstIndex(where: { $0.id == initialId }) {
                    focusedIndex = index
                } else if let index = state.items.firstIndex(where: { $0.id <= initialId }) {
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
            
            struct DayIndex: Hashable {
                var year: Int32
                var day: Int32
                
                init(timestamp: Int32) {
                    var time: time_t = time_t(timestamp)
                    var timeinfo: tm = tm()
                    localtime_r(&time, &timeinfo)

                    self.year = timeinfo.tm_year
                    self.day = timeinfo.tm_yday
                }
            }
            
            let stateValue: StoryContentContextState
            if let focusedIndex = focusedIndex {
                let item = state.items[focusedIndex]
                self.focusedId = item.id
                
                var allItems: [StoryContentItem] = []
                
                var dayCounts: [DayIndex: Int] = [:]
                var itemDayIndices: [Int32: (Int, DayIndex)] = [:]
                
                for i in 0 ..< state.items.count {
                    let stateItem = state.items[i]
                    allItems.append(StoryContentItem(
                        position: i,
                        dayCounters: nil,
                        peerId: peer.id,
                        storyItem: stateItem,
                        entityFiles: extractItemEntityFiles(item: stateItem, allEntityFiles: state.allEntityFiles)
                    ))
                    
                    let day = DayIndex(timestamp: stateItem.timestamp)
                    let dayCount: Int
                    if let current = dayCounts[day] {
                        dayCount = current + 1
                        dayCounts[day] = dayCount
                    } else {
                        dayCount = 1
                        dayCounts[day] = dayCount
                    }
                    itemDayIndices[stateItem.id] = (dayCount - 1, day)
                }
                
                var dayCounters: StoryContentItem.DayCounters?
                if let (offset, day) = itemDayIndices[item.id], let dayCount = dayCounts[day] {
                    dayCounters = StoryContentItem.DayCounters(
                        position: offset,
                        totalCount: dayCount
                    )
                }
                
                stateValue = StoryContentContextState(
                    slice: StoryContentContextState.FocusedSlice(
                        peer: peer,
                        additionalPeerData: additionalPeerData,
                        item: StoryContentItem(
                            position: focusedIndex,
                            dayCounters: dayCounters,
                            peerId: peer.id,
                            storyItem: item,
                            entityFiles: extractItemEntityFiles(item: item, allEntityFiles: state.allEntityFiles)
                        ),
                        totalCount: state.totalCount,
                        previousItemId: focusedIndex == 0 ? nil : state.items[focusedIndex - 1].id,
                        nextItemId: (focusedIndex == state.items.count - 1) ? nil : state.items[focusedIndex + 1].id,
                        allItems: allItems
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
                
                var resultResources: [EngineMedia.Id: StoryPreloadInfo] = [:]
                var pollItems: [StoryKey] = []
                
                if let focusedIndex, let slice = stateValue.slice {
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
                        if let peerReference = PeerReference(peer._asPeer()), let mediaId = item.media.id {
                            resultResources[mediaId] = StoryPreloadInfo(
                                peer: peerReference,
                                storyId: item.id,
                                media: item.media,
                                priority: .top(position: nextPriority)
                            )
                            nextPriority += 1
                        }
                    }
                }
                
                var validIds: [EngineMedia.Id] = []
                for (_, info) in resultResources.sorted(by: { $0.value.priority < $1.value.priority }) {
                    if let mediaId = info.media.id {
                        validIds.append(mediaId)
                        if self.preloadStoryResourceDisposables[mediaId] == nil {
                            self.preloadStoryResourceDisposables[mediaId] = preloadStoryMedia(context: context, peer: info.peer, storyId: info.storyId, media: info.media).start()
                        }
                    }
                }
                
                var removeIds: [EngineMedia.Id] = []
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
            var indexDifference: Int?
            switch direction {
            case .next:
                indexDifference = 1
            case .previous:
                indexDifference = -1
            case let .id(id):
                if let listState = self.listState, let focusedId = self.focusedId, let index = listState.items.firstIndex(where: { $0.id == focusedId }), let nextIndex = listState.items.firstIndex(where: { $0.id == id }) {
                    indexDifference = nextIndex - index
                }
            }
            
            if let indexDifference, let listState = self.listState, let focusedId = self.focusedId {
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
        if !self.context.sharedContext.immediateExperimentalUISettings.skipReadHistory {
            let _ = self.context.engine.messages.markStoryAsSeen(peerId: id.peerId, id: id.id, asPinned: true).start()
        }
    }
}

public func preloadStoryMedia(context: AccountContext, peer: PeerReference, storyId: Int32, media: EngineMedia) -> Signal<Never, NoError> {
    var signals: [Signal<Never, NoError>] = []
    
    switch media {
    case let .image(image):
        if let representation = largestImageRepresentation(image.representations) {
            signals.append(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .story, reference: .media(media: .story(peer: peer, id: storyId, media: media._asMedia()), resource: representation.resource), range: nil)
            |> ignoreValues
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            })
        }
    case let .file(file):
        var fetchRange: (Range<Int64>, MediaBoxFetchPriority)?
        for attribute in file.attributes {
            if case let .Video(_, _, _, preloadSize) = attribute {
                if let preloadSize {
                    fetchRange = (0 ..< Int64(preloadSize), .default)
                }
                break
            }
        }
        
        signals.append(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .story, reference: .media(media: .story(peer: peer, id: storyId, media: media._asMedia()), resource: file.resource), range: fetchRange)
        |> ignoreValues
        |> `catch` { _ -> Signal<Never, NoError> in
            return .complete()
        })
        signals.append(context.account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedVideoFirstFrameRepresentation(), complete: true, fetch: true, attemptSynchronously: false)
        |> ignoreValues)
    default:
        break
    }
    
    return combineLatest(signals) |> ignoreValues
}

public func waitUntilStoryMediaPreloaded(context: AccountContext, peerId: EnginePeer.Id, storyItem: EngineStoryItem) -> Signal<Never, NoError> {
    return context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
    )
    |> mapToSignal { peerValue -> Signal<Never, NoError> in
        guard let peerValue else {
            return .complete()
        }
        guard let peer = PeerReference(peerValue._asPeer()) else {
            return .complete()
        }
        
        var statusSignals: [Signal<Never, NoError>] = []
        var loadSignals: [Signal<Never, NoError>] = []
        var fetchPriorityDisposable: Disposable?
        
        var fetchPriorityResourceId: String?
        switch storyItem.media {
        case let .image(image):
            if let representation = largestImageRepresentation(image.representations) {
                fetchPriorityResourceId = representation.resource.id.stringRepresentation
            }
        case let .file(file):
            fetchPriorityResourceId = file.resource.id.stringRepresentation
        default:
            break
        }
        
        if let fetchPriorityResourceId {
            fetchPriorityDisposable = context.engine.resources.pushPriorityDownload(resourceId: fetchPriorityResourceId, priority: 2)
        }
        
        switch storyItem.media {
        case let .image(image):
            if let representation = largestImageRepresentation(image.representations) {
                statusSignals.append(
                    context.account.postbox.mediaBox.resourceData(representation.resource)
                    |> filter { data in
                        return data.complete
                    }
                    |> take(1)
                    |> ignoreValues
                )
                
                loadSignals.append(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .story, reference: .media(media: .story(peer: peer, id: storyItem.id, media: storyItem.media._asMedia()), resource: representation.resource), range: nil)
                |> ignoreValues
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                })
            }
        case let .file(file):
            var fetchRange: (Range<Int64>, MediaBoxFetchPriority)?
            for attribute in file.attributes {
                if case let .Video(_, _, _, preloadSize) = attribute {
                    if let preloadSize {
                        fetchRange = (0 ..< Int64(preloadSize), .default)
                    }
                    break
                }
            }
            
            statusSignals.append(
                context.account.postbox.mediaBox.resourceRangesStatus(file.resource)
                |> filter { ranges in
                    if let fetchRange {
                        return ranges.isSuperset(of: RangeSet(fetchRange.0))
                    } else {
                        return true
                    }
                }
                |> take(1)
                |> ignoreValues
            )
            
            loadSignals.append(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .story, reference: .media(media: .story(peer: peer, id: storyItem.id, media: storyItem.media._asMedia()), resource: file.resource), range: fetchRange)
            |> ignoreValues
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            })
            loadSignals.append(context.account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedVideoFirstFrameRepresentation(), complete: true, fetch: true, attemptSynchronously: false)
            |> ignoreValues)
        default:
            break
        }
        
        return Signal { subscriber in
            let statusDisposable = combineLatest(statusSignals).start(completed: {
                subscriber.putCompletion()
            })
            let loadDisposable = combineLatest(loadSignals).start()
            
            return ActionDisposable {
                statusDisposable.dispose()
                loadDisposable.dispose()
                fetchPriorityDisposable?.dispose()
            }
        }
    }
}

func extractItemEntityFiles(item: EngineStoryItem, allEntityFiles: [MediaId: TelegramMediaFile]) -> [MediaId: TelegramMediaFile] {
    var result: [MediaId: TelegramMediaFile] = [:]
    for entity in item.entities {
        if case let .CustomEmoji(_, fileId) = entity.type {
            let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
            if let file = allEntityFiles[mediaId] {
                result[file.fileId] = file
            }
        }
    }
    return result
}
