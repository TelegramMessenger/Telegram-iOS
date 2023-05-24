import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import AccountContext
import TelegramCore
import Postbox
import StoryContainerScreen

public final class StoryContentContextImpl: StoryContentContext {
    private struct StoryKey: Hashable {
        var peerId: EnginePeer.Id
        var id: Int32
    }
    
    private final class PeerContext {
        private let context: AccountContext
        private let peerId: EnginePeer.Id
        
        private(set) var sliceValue: StoryContentContextState.FocusedSlice?
        
        let updated = Promise<Void>()
        
        private(set) var isReady: Bool = false
        
        private var disposable: Disposable?
        private var loadDisposable: Disposable?
        
        private let currentFocusedIdPromise = Promise<Int32?>()
        private var storedFocusedId: Int32?
        var currentFocusedId: Int32? {
            didSet {
                if self.currentFocusedId != self.storedFocusedId {
                    self.storedFocusedId = self.currentFocusedId
                    self.currentFocusedIdPromise.set(.single(self.currentFocusedId))
                }
            }
        }
        
        init(context: AccountContext, peerId: EnginePeer.Id, focusedId initialFocusedId: Int32?, loadIds: @escaping ([StoryKey]) -> Void) {
            self.context = context
            self.peerId = peerId
            
            self.currentFocusedIdPromise.set(.single(initialFocusedId))
            
            self.disposable = (combineLatest(queue: .mainQueue(),
                self.currentFocusedIdPromise.get(),
                context.account.postbox.combinedView(
                    keys: [
                        PostboxViewKey.basicPeer(peerId),
                        PostboxViewKey.storiesState(key: .peer(peerId)),
                        PostboxViewKey.storyItems(peerId: peerId)
                    ]
                )
            )
            |> deliverOnMainQueue).start(next: { [weak self] currentFocusedId, views in
                guard let self else {
                    return
                }
                guard let peerView = views.views[PostboxViewKey.basicPeer(peerId)] as? BasicPeerView else {
                    return
                }
                guard let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                    return
                }
                guard let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                    return
                }
                guard let peer = peerView.peer.flatMap(EnginePeer.init) else {
                    return
                }
                let state = stateView.value?.get(Stories.PeerState.self)
                
                var focusedIndex: Int?
                if let currentFocusedId {
                    focusedIndex = itemsView.items.firstIndex(where: { $0.id == currentFocusedId })
                }
                if focusedIndex == nil, let state {
                    if let storedFocusedId = self.storedFocusedId {
                        focusedIndex = itemsView.items.firstIndex(where: { $0.id >= storedFocusedId })
                    } else {
                        focusedIndex = itemsView.items.firstIndex(where: { $0.id > state.maxReadId })
                    }
                }
                if focusedIndex == nil {
                    if !itemsView.items.isEmpty {
                        focusedIndex = 0
                    }
                }
                
                if let focusedIndex {
                    self.storedFocusedId = itemsView.items[focusedIndex].id
                    
                    var previousItemId: Int32?
                    var nextItemId: Int32?
                    
                    if focusedIndex != 0 {
                        previousItemId = itemsView.items[focusedIndex - 1].id
                    }
                    if focusedIndex != itemsView.items.count - 1 {
                        nextItemId = itemsView.items[focusedIndex + 1].id
                    }
                    
                    var loadKeys: [StoryKey] = []
                    for index in (focusedIndex - 2) ... (focusedIndex + 2) {
                        if index >= 0 && index < itemsView.items.count {
                            if let item = itemsView.items[focusedIndex].value.get(Stories.StoredItem.self), case .placeholder = item {
                                loadKeys.append(StoryKey(peerId: peerId, id: item.id))
                            }
                        }
                    }
                    
                    if let item = itemsView.items[focusedIndex].value.get(Stories.StoredItem.self), case let .item(item) = item, let media = item.media {
                        let mappedItem = StoryListContext.Item(
                            id: item.id,
                            timestamp: item.timestamp,
                            media: EngineMedia(media),
                            text: item.text,
                            entities: item.entities,
                            views: nil,
                            privacy: nil
                        )
                        
                        self.sliceValue = StoryContentContextState.FocusedSlice(
                            peer: peer,
                            item: StoryContentItem(
                                id: AnyHashable(item.id),
                                position: focusedIndex,
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
                                preload: nil,
                                delete: { [weak context] in
                                    guard let context else {
                                        return
                                    }
                                    let _ = context
                                },
                                markAsSeen: { [weak context] in
                                    guard let context else {
                                        return
                                    }
                                    let _ = context.engine.messages.markStoryAsSeen(peerId: peerId, id: item.id).start()
                                },
                                hasLike: false,
                                isMy: peerId == context.account.peerId
                            ),
                            totalCount: itemsView.items.count,
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
    private var storySubscriptionsDisposable: Disposable?
    
    private var requestedStoryKeys = Set<StoryKey>()
    private var requestStoryDisposables = DisposableSet()
    
    public init(
        context: AccountContext,
        focusedPeerId: EnginePeer.Id?
    ) {
        self.context = context
        if let focusedPeerId {
            self.focusedItem = (focusedPeerId, nil)
        }
        
        self.storySubscriptionsDisposable = (context.engine.messages.storySubscriptions()
        |> deliverOnMainQueue).start(next: { [weak self] storySubscriptions in
            guard let self else {
                return
            }
            self.storySubscriptions = storySubscriptions
            self.updatePeerContexts()
        })
    }
    
    deinit {
        self.storySubscriptionsDisposable?.dispose()
        self.requestStoryDisposables.dispose()
    }
    
    private func updatePeerContexts() {
        if let currentState = self.currentState {
            let _ = currentState
        } else {
            self.switchToFocusedPeerId()
        }
    }
    
    private func switchToFocusedPeerId() {
        if let storySubscriptions = self.storySubscriptions {
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
                
                if let (focusedPeerId, _) = self.focusedItem, focusedPeerId == self.context.account.peerId {
                    let centralPeerContext = PeerContext(context: self.context, peerId: self.context.account.peerId, focusedId: nil, loadIds: loadIds)
                    
                    let pendingState = StateContext(
                        centralPeerContext: centralPeerContext,
                        previousPeerContext: nil,
                        nextPeerContext: nil
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
                } else {
                    var centralIndex: Int?
                    if let (focusedPeerId, _) = self.focusedItem {
                        if let index = storySubscriptions.items.firstIndex(where: { $0.peer.id == focusedPeerId }) {
                            centralIndex = index
                        }
                    }
                    if centralIndex == nil {
                        if !storySubscriptions.items.isEmpty {
                            centralIndex = 0
                        }
                    }
                    
                    if let centralIndex {
                        let centralPeerContext: PeerContext
                        if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: storySubscriptions.items[centralIndex].peer.id) {
                            centralPeerContext = existingContext
                        } else {
                            centralPeerContext = PeerContext(context: self.context, peerId: storySubscriptions.items[centralIndex].peer.id, focusedId: nil, loadIds: loadIds)
                        }
                        
                        var previousPeerContext: PeerContext?
                        if centralIndex != 0 {
                            if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: storySubscriptions.items[centralIndex - 1].peer.id) {
                                previousPeerContext = existingContext
                            } else {
                                previousPeerContext = PeerContext(context: self.context, peerId: storySubscriptions.items[centralIndex - 1].peer.id, focusedId: nil, loadIds: loadIds)
                            }
                        }
                        
                        var nextPeerContext: PeerContext?
                        if centralIndex != storySubscriptions.items.count - 1 {
                            if let currentState = self.currentState, let existingContext = currentState.findPeerContext(id: storySubscriptions.items[centralIndex + 1].peer.id) {
                                nextPeerContext = existingContext
                            } else {
                                nextPeerContext = PeerContext(context: self.context, peerId: storySubscriptions.items[centralIndex + 1].peer.id, focusedId: nil, loadIds: loadIds)
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
}

public enum StoryChatContent {
    public static func peerStories(context: AccountContext, peerId: EnginePeer.Id, focusItem: Int32?) -> Signal<[StoryContentItemSlice], NoError> {
        let focusContext = context.engine.messages.peerStoryFocusContext(id: peerId, focusItemId: focusItem)
        return combineLatest(
            context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
            focusContext.state
        )
        |> mapToSignal { peer, state -> Signal<[StoryContentItemSlice], NoError> in
            let _ = focusContext
            
            if let peer, let item = state.item, let media = item.media {
                let mappedItem = StoryListContext.Item(
                    id: item.id,
                    timestamp: item.timestamp,
                    media: EngineMedia(media),
                    text: item.text,
                    entities: item.entities,
                    views: nil,
                    privacy: nil
                )
                
                let slice = StoryContentItemSlice(
                    id: AnyHashable(peerId),
                    focusedItemId: AnyHashable(item.id),
                    items: [
                        StoryContentItem(
                            id: AnyHashable(item.id),
                            position: state.position,
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
                            preload: nil,
                            delete: { [weak context] in
                                guard let context else {
                                    return
                                }
                                let _ = context
                            },
                            markAsSeen: { [weak context] in
                                guard let context else {
                                    return
                                }
                                let _ = context.engine.messages.markStoryAsSeen(peerId: peerId, id: item.id).start()
                            },
                            hasLike: false,
                            isMy: peerId == context.account.peerId
                        )
                    ],
                    totalCount: state.count,
                    previousItemId: state.previousId,
                    nextItemId: state.nextId,
                    update: { requestedItemSet, itemId in
                        var focusItem: Int32?
                        if let id = itemId.base as? Int32 {
                            focusItem = id
                        }
                        
                        return StoryChatContent.peerStories(context: context, peerId: peerId, focusItem: focusItem)
                        |> mapToSignal { result in
                            if let first = result.first {
                                return .single(first)
                            } else {
                                return .never()
                            }
                        }
                    }
                )
                return .single([slice])
            } else {
                return .single([])
            }
        }
    }
    
    public static func subscriptionsStories(context: AccountContext, peerId: EnginePeer.Id?) -> Signal<[StoryContentItemSlice], NoError> {
        return context.engine.messages.storySubscriptions()
        |> mapToSignal { subscriptions -> Signal<[StoryContentItemSlice], NoError> in
            var signals: [Signal<[StoryContentItemSlice], NoError>] = []
            for item in subscriptions.items {
                signals.append(peerStories(context: context, peerId: item.peer.id, focusItem: nil))
            }
            return combineLatest(queue: .mainQueue(), signals)
            |> map { peerItems -> [StoryContentItemSlice] in
                var result: [StoryContentItemSlice] = []
                
                for item in peerItems {
                    result.append(contentsOf: item)
                }
                
                return result
            }
        }
    }
    
    public static func stories(context: AccountContext, storyList: StoryListContext, focusItem: Int32?) -> Signal<[StoryContentItemSlice], NoError> {
        return storyList.state
        |> map { state -> [StoryContentItemSlice] in
            var itemSlices: [StoryContentItemSlice] = []
            
            for itemSet in state.itemSets {
                var items: [StoryContentItem] = []
                
                guard let peer = itemSet.peer else {
                    continue
                }
                let peerId = itemSet.peerId
                
                for item in itemSet.items {
                    items.append(StoryContentItem(
                        id: AnyHashable(item.id),
                        position: items.count,
                        component: AnyComponent(StoryItemContentComponent(
                            context: context,
                            peer: peer,
                            item: item
                        )),
                        centerInfoComponent: AnyComponent(StoryAuthorInfoComponent(
                            context: context,
                            peer: itemSet.peer,
                            timestamp: item.timestamp
                        )),
                        rightInfoComponent: itemSet.peer.flatMap { author -> AnyComponent<Empty> in
                            return AnyComponent(StoryAvatarInfoComponent(
                                context: context,
                                peer: author
                            ))
                        },
                        peerId: itemSet.peerId,
                        storyItem: item,
                        preload: nil,
                        delete: { [weak storyList] in
                            storyList?.delete(id: item.id)
                        },
                        markAsSeen: { [weak context] in
                            guard let context else {
                                return
                            }
                            let _ = context.engine.messages.markStoryAsSeen(peerId: peerId, id: item.id).start()
                        },
                        hasLike: false,
                        isMy: itemSet.peerId == context.account.peerId
                    ))
                }
                
                var sliceFocusedItemId: AnyHashable?
                if let focusItem, items.contains(where: { ($0.id.base as? Int32) == focusItem }) {
                    sliceFocusedItemId = AnyHashable(focusItem)
                } else {
                    if let id = itemSet.items.first(where: { $0.id > itemSet.maxReadId })?.id {
                        sliceFocusedItemId = AnyHashable(id)
                    }
                }
                
                itemSlices.append(StoryContentItemSlice(
                    id: AnyHashable(itemSet.peerId),
                    focusedItemId: sliceFocusedItemId,
                    items: items,
                    totalCount: items.count,
                    previousItemId: nil,
                    nextItemId: nil,
                    update: { requestedItemSet, itemId in
                        var focusItem: Int32?
                        if let id = itemId.base as? Int32 {
                            focusItem = id
                        }
                        return StoryChatContent.stories(context: context, storyList: storyList, focusItem: focusItem)
                        |> mapToSignal { result -> Signal<StoryContentItemSlice, NoError> in
                            if let foundItemSet = result.first(where: { $0.id == requestedItemSet.id }) {
                                return .single(foundItemSet)
                            } else {
                                return .never()
                            }
                        }
                    }
                ))
            }
            
            return itemSlices
        }
    }
}
