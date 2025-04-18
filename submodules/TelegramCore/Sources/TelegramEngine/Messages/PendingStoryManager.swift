import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public extension Stories {
    enum PendingTarget: Codable {
        private enum CodingKeys: String, CodingKey {
            case discriminator = "tt"
            case peerId = "peerId"
            case language = "language"
        }
        
        case myStories
        case peer(PeerId)
        case botPreview(id: PeerId, language: String?)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            switch try container.decode(Int32.self, forKey: .discriminator) {
            case 0:
                self = .myStories
            case 1:
                self = .peer(try container.decode(PeerId.self, forKey: .peerId))
            case 2:
                self = .botPreview(id: try container.decode(PeerId.self, forKey: .peerId), language: try container.decodeIfPresent(String.self, forKey: .language))
            default:
                self = .myStories
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .myStories:
                try container.encode(0 as Int32, forKey: .discriminator)
            case let .peer(peerId):
                try container.encode(1 as Int32, forKey: .discriminator)
                try container.encode(peerId, forKey: .peerId)
            case let .botPreview(peerId, language):
                try container.encode(2 as Int32, forKey: .discriminator)
                try container.encode(peerId, forKey: .peerId)
                try container.encodeIfPresent(language, forKey: .language)
            }
        }
    }
    
    struct PendingForwardInfo: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case peerId = "peerId"
            case storyId = "storyId"
            case isModified = "isModified"
        }
        
        public let peerId: EnginePeer.Id
        public let storyId: Int32
        public let isModified: Bool
        
        public init(peerId: EnginePeer.Id, storyId: Int32, isModified: Bool) {
            self.peerId = peerId
            self.storyId = storyId
            self.isModified = isModified
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.peerId = EnginePeer.Id(try container.decode(Int64.self, forKey: .peerId))
            self.storyId = try container.decode(Int32.self, forKey: .storyId)
            self.isModified = try container.decodeIfPresent(Bool.self, forKey: .isModified) ?? false
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.peerId.toInt64(), forKey: .peerId)
            try container.encode(self.storyId, forKey: .storyId)
            try container.encode(self.isModified, forKey: .isModified)
        }
    }
    
    final class PendingItem: Equatable, Codable {
        private enum CodingKeys: CodingKey {
            case target
            case stableId
            case timestamp
            case media
            case mediaAreas
            case text
            case entities
            case embeddedStickers
            case pin
            case privacy
            case isForwardingDisabled
            case period
            case randomId
            case forwardInfo
        }
        
        public let target: PendingTarget
        public let stableId: Int32
        public let timestamp: Int32
        public let media: Media
        public let mediaAreas: [MediaArea]
        public let text: String
        public let entities: [MessageTextEntity]
        public let embeddedStickers: [TelegramMediaFile]
        public let pin: Bool
        public let privacy: EngineStoryPrivacy
        public let isForwardingDisabled: Bool
        public let period: Int32
        public let randomId: Int64
        public let forwardInfo: PendingForwardInfo?
        
        public init(
            target: PendingTarget,
            stableId: Int32,
            timestamp: Int32,
            media: Media,
            mediaAreas: [MediaArea],
            text: String,
            entities: [MessageTextEntity],
            embeddedStickers: [TelegramMediaFile],
            pin: Bool,
            privacy: EngineStoryPrivacy,
            isForwardingDisabled: Bool,
            period: Int32,
            randomId: Int64,
            forwardInfo: PendingForwardInfo?
        ) {
            self.target = target
            self.stableId = stableId
            self.timestamp = timestamp
            self.media = media
            self.mediaAreas = mediaAreas
            self.text = text
            self.entities = entities
            self.embeddedStickers = embeddedStickers
            self.pin = pin
            self.privacy = privacy
            self.isForwardingDisabled = isForwardingDisabled
            self.period = period
            self.randomId = randomId
            self.forwardInfo = forwardInfo
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.target = try container.decodeIfPresent(PendingTarget.self, forKey: .target) ?? .myStories
            self.stableId = try container.decode(Int32.self, forKey: .stableId)
            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            
            let mediaData = try container.decode(Data.self, forKey: .media)
            self.media = PostboxDecoder(buffer: MemoryBuffer(data: mediaData)).decodeRootObject() as! Media
            self.mediaAreas = try container.decodeIfPresent([MediaArea].self, forKey: .mediaAreas) ?? []
            
            self.text = try container.decode(String.self, forKey: .text)
            self.entities = try container.decode([MessageTextEntity].self, forKey: .entities)
            
            let stickersData = try container.decode(Data.self, forKey: .embeddedStickers)
            let stickersDecoder = PostboxDecoder(buffer: MemoryBuffer(data: stickersData))
            self.embeddedStickers = (try? stickersDecoder.decodeObjectArrayWithCustomDecoderForKey("stickers", decoder: { TelegramMediaFile(decoder: $0) })) ?? []
            
            self.pin = try container.decode(Bool.self, forKey: .pin)
            self.privacy = try container.decode(EngineStoryPrivacy.self, forKey: .privacy)
            self.isForwardingDisabled = try container.decodeIfPresent(Bool.self, forKey: .isForwardingDisabled) ?? false
            self.period = try container.decode(Int32.self, forKey: .period)
            self.randomId = try container.decode(Int64.self, forKey: .randomId)
            
            self.forwardInfo = try container.decodeIfPresent(PendingForwardInfo.self, forKey: .forwardInfo)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.target, forKey: .target)
            
            try container.encode(self.stableId, forKey: .stableId)
            try container.encode(self.timestamp, forKey: .timestamp)
            
            let mediaEncoder = PostboxEncoder()
            mediaEncoder.encodeRootObject(self.media)
            try container.encode(mediaEncoder.makeData(), forKey: .media)
            try container.encode(self.mediaAreas, forKey: .mediaAreas)
            
            try container.encode(self.text, forKey: .text)
            try container.encode(self.entities, forKey: .entities)
            
            let stickersEncoder = PostboxEncoder()
            stickersEncoder.encodeObjectArray(self.embeddedStickers, forKey: "stickers")
            try container.encode(stickersEncoder.makeData(), forKey: .embeddedStickers)
            
            try container.encode(self.pin, forKey: .pin)
            try container.encode(self.privacy, forKey: .privacy)
            try container.encode(self.isForwardingDisabled, forKey: .isForwardingDisabled)
            try container.encode(self.period, forKey: .period)
            try container.encode(self.randomId, forKey: .randomId)
            try container.encodeIfPresent(self.forwardInfo, forKey: .forwardInfo)
        }
        
        public static func ==(lhs: PendingItem, rhs: PendingItem) -> Bool {
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            if lhs.stableId != rhs.stableId {
                return false
            }
            if !lhs.media.isEqual(to: rhs.media) {
                return false
            }
            if lhs.mediaAreas != rhs.mediaAreas {
                return false
            }
            if lhs.text != rhs.text {
                return false
            }
            if lhs.entities != rhs.entities {
                return false
            }
            if lhs.pin != rhs.pin {
                return false
            }
            if lhs.privacy != rhs.privacy {
                return false
            }
            if lhs.isForwardingDisabled != rhs.isForwardingDisabled {
                return false
            }
            if lhs.period != rhs.period {
                return false
            }
            if lhs.randomId != rhs.randomId {
                return false
            }
            if lhs.forwardInfo != rhs.forwardInfo {
                return false
            }
            return true
        }
    }
    
    struct LocalState: Equatable, Codable {
        public var items: [PendingItem]
        
        public init(
            items: [PendingItem]
        ) {
            self.items = items
        }
    }
}

final class PendingStoryManager {
    private final class PendingItemContext {
        let queue: Queue
        let item: Stories.PendingItem
        let updated: () -> Void
        
        var progress: Float = 0.0
        var disposable: Disposable?
        
        init(queue: Queue, item: Stories.PendingItem, updated: @escaping () -> Void) {
            self.queue = queue
            self.item = item
            self.updated = updated
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private final class Impl {
        let queue: Queue
        let postbox: Postbox
        let network: Network
        let accountPeerId: PeerId
        let stateManager: AccountStateManager
        let messageMediaPreuploadManager: MessageMediaPreuploadManager
        let revalidationContext: MediaReferenceRevalidationContext
        let auxiliaryMethods: AccountAuxiliaryMethods
        
        var itemsDisposable: Disposable?
        var currentPendingItemContext: PendingItemContext?
        var queuedPendingItems = Set<PeerId>()
        
        var storyObserverContexts: [Int32: Bag<(Float) -> Void>] = [:]
        
        private let allStoriesEventsPipe = ValuePipe<(Int32, Int32)>()
        var allStoriesUploadEvents: Signal<(Int32, Int32), NoError> {
            return self.allStoriesEventsPipe.signal()
        }
        
        private let allStoriesUploadProgressPromise = Promise<[PeerId: Float]>([:])
        private var allStoriesUploadProgressValue: [PeerId: Float] = [:]
        var allStoriesUploadProgress: Signal<[PeerId: Float], NoError> {
            return self.allStoriesUploadProgressPromise.get()
        }
        
        private let hasPendingPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
        var hasPending: Signal<Bool, NoError> {
            return self.hasPendingPromise.get()
        }
        
        func storyUploadProgress(stableId: Int32, next: @escaping (Float) -> Void) -> Disposable {
            let bag: Bag<(Float) -> Void>
            if let current = self.storyObserverContexts[stableId] {
                bag = current
            } else {
                bag = Bag()
                self.storyObserverContexts[stableId] = bag
            }
            
            let index = bag.add(next)
            if let currentPendingItemContext = self.currentPendingItemContext, currentPendingItemContext.item.stableId == stableId {
                next(currentPendingItemContext.progress)
            } else {
                next(0.0)
            }
            
            let queue = self.queue
            return ActionDisposable { [weak self, weak bag] in
                queue.async {
                    guard let `self` = self else {
                        return
                    }
                    if let bag = bag, let listBag = self.storyObserverContexts[stableId], listBag === bag {
                        bag.remove(index)
                        if bag.isEmpty {
                            self.storyObserverContexts.removeValue(forKey: stableId)
                        }
                    }
                }
            }
        }

        init(queue: Queue, postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, revalidationContext: MediaReferenceRevalidationContext, auxiliaryMethods: AccountAuxiliaryMethods) {
            self.queue = queue
            self.postbox = postbox
            self.network = network
            self.accountPeerId = accountPeerId
            self.stateManager = stateManager
            self.messageMediaPreuploadManager = messageMediaPreuploadManager
            self.revalidationContext = revalidationContext
            self.auxiliaryMethods = auxiliaryMethods
            
            self.itemsDisposable = (postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .local)])
            |> deliverOn(self.queue)).start(next: { [weak self] views in
                guard let `self` = self else {
                    return
                }
                guard let view = views.views[PostboxViewKey.storiesState(key: .local)] as? StoryStatesView else {
                    return
                }
                let localState: Stories.LocalState
                if let value = view.value?.get(Stories.LocalState.self) {
                    localState = value
                } else {
                    localState = Stories.LocalState(items: [])
                }
                self.update(localState: localState)
            })
        }

        deinit {
            self.itemsDisposable?.dispose()
        }
        
        private func update(localState: Stories.LocalState) {
            if let currentPendingItemContext = self.currentPendingItemContext, !localState.items.contains(where: { $0.randomId == currentPendingItemContext.item.randomId }) {
                self.currentPendingItemContext = nil
                self.queue.after(0.1, {
                    let _ = currentPendingItemContext
                    print(currentPendingItemContext)
                })
            }
            self.queuedPendingItems = Set(localState.items.compactMap { item -> PeerId? in
                switch item.target {
                case .myStories:
                    return self.accountPeerId
                case let .peer(id):
                    return id
                case .botPreview:
                    return nil
                }
            })
            
            if self.currentPendingItemContext == nil, let firstItem = localState.items.first {
                let queue = self.queue
                let itemStableId = firstItem.stableId
                let pendingItemContext = PendingItemContext(queue: queue, item: firstItem, updated: { [weak self] in
                    queue.async {
                        guard let `self` = self else {
                            return
                        }
                        self.processContextsUpdated()
                        if let pendingItemContext = self.currentPendingItemContext, pendingItemContext.item.stableId == itemStableId, let bag = self.storyObserverContexts[itemStableId] {
                            for f in bag.copyItems() {
                                f(pendingItemContext.progress)
                            }
                        }
                    }
                })
                self.currentPendingItemContext = pendingItemContext
                
                let toPeerId: PeerId
                var isBotPreview = false
                var botPreviewLanguage: String?
                switch firstItem.target {
                case .myStories:
                    toPeerId = self.accountPeerId
                case let .peer(peerId):
                    toPeerId = peerId
                case let .botPreview(peerId, language):
                    toPeerId = peerId
                    botPreviewLanguage = language
                    isBotPreview = true
                }
                                
                let stableId = firstItem.stableId
                if isBotPreview {
                    pendingItemContext.disposable = (_internal_uploadBotPreviewImpl(
                        postbox: self.postbox,
                        network: self.network,
                        accountPeerId: self.accountPeerId,
                        stateManager: self.stateManager,
                        messageMediaPreuploadManager: self.messageMediaPreuploadManager,
                        revalidationContext: self.revalidationContext,
                        auxiliaryMethods: self.auxiliaryMethods,
                        toPeerId: toPeerId,
                        language: botPreviewLanguage,
                        stableId: stableId,
                        media: firstItem.media,
                        mediaAreas: firstItem.mediaAreas,
                        text: firstItem.text,
                        entities: firstItem.entities,
                        embeddedStickers: firstItem.embeddedStickers,
                        randomId: firstItem.randomId
                    )
                    |> deliverOn(self.queue)).start(next: { [weak self] event in
                        guard let self else {
                            return
                        }
                        switch event {
                        case let .progress(progress):
                            if let currentPendingItemContext = self.currentPendingItemContext, currentPendingItemContext.item.stableId == stableId {
                                currentPendingItemContext.progress = progress
                                currentPendingItemContext.updated()
                            }
                        case let .completed(id):
                            if let id = id {
                                self.allStoriesEventsPipe.putNext((stableId, id))
                            }
                            // wait for the local state to change via Postbox
                            break
                        }
                    })
                } else {
                    pendingItemContext.disposable = (_internal_uploadStoryImpl(postbox: self.postbox, network: self.network, accountPeerId: self.accountPeerId, stateManager: self.stateManager, messageMediaPreuploadManager: self.messageMediaPreuploadManager, revalidationContext: self.revalidationContext, auxiliaryMethods: self.auxiliaryMethods, toPeerId: toPeerId, stableId: stableId, media: firstItem.media, mediaAreas: firstItem.mediaAreas, text: firstItem.text, entities: firstItem.entities, embeddedStickers: firstItem.embeddedStickers, pin: firstItem.pin, privacy: firstItem.privacy, isForwardingDisabled: firstItem.isForwardingDisabled, period: Int(firstItem.period), randomId: firstItem.randomId, forwardInfo: firstItem.forwardInfo)
                    |> deliverOn(self.queue)).start(next: { [weak self] event in
                        guard let `self` = self else {
                            return
                        }
                        switch event {
                        case let .progress(progress):
                            if let currentPendingItemContext = self.currentPendingItemContext, currentPendingItemContext.item.stableId == stableId {
                                currentPendingItemContext.progress = progress
                                currentPendingItemContext.updated()
                            }
                        case let .completed(id):
                            if let id = id {
                                self.allStoriesEventsPipe.putNext((stableId, id))
                            }
                            // wait for the local state to change via Postbox
                            break
                        }
                    })
                }
            }
            
            self.processContextsUpdated()
        }
        
        private func processContextsUpdated() {
            var currentProgress: [PeerId: Float] = [:]
            for peerId in self.queuedPendingItems {
                currentProgress[peerId] = 0.0
            }
            if let currentPendingItemContext = self.currentPendingItemContext {
                switch currentPendingItemContext.item.target {
                case .myStories:
                    currentProgress[self.accountPeerId] = currentPendingItemContext.progress
                case let .peer(id):
                    currentProgress[id] = currentPendingItemContext.progress
                case .botPreview:
                    break
                }
            }
            
            if self.allStoriesUploadProgressValue != currentProgress {
                let previousProgress = self.allStoriesUploadProgressValue
                self.allStoriesUploadProgressValue = currentProgress
                
                if !previousProgress.isEmpty && currentProgress.isEmpty {
                    // Hack: the UI is updated after 2 Postbox queries
                    let signal: Signal<[PeerId: Float], NoError> = Signal { subscriber in
                        Postbox.sharedQueue.justDispatch {
                            Postbox.sharedQueue.justDispatch {
                                subscriber.putNext([:])
                            }
                        }
                        return EmptyDisposable
                    }
                    |> deliverOnMainQueue
                    
                    self.allStoriesUploadProgressPromise.set(signal)
                } else {
                    self.allStoriesUploadProgressPromise.set(.single(currentProgress))
                }
            }
            
            self.hasPendingPromise.set(self.currentPendingItemContext != nil)
        }
    }

    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    private let accountPeerId: PeerId
    
    public var allStoriesUploadProgress: Signal<[PeerId: Float], NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.allStoriesUploadProgress.start(next: subscriber.putNext)
        }
    }
    
    public var hasPending: Signal<Bool, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.hasPending.start(next: subscriber.putNext)
        }
    }
    
    public func storyUploadProgress(stableId: Int32) -> Signal<Float, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.storyUploadProgress(stableId: stableId, next: subscriber.putNext)
        }
    }
    
    public func allStoriesUploadEvents() -> Signal<(Int32, Int32), NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.allStoriesUploadEvents.start(next: subscriber.putNext)
        }
    }

    init(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, revalidationContext: MediaReferenceRevalidationContext, auxiliaryMethods: AccountAuxiliaryMethods) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.accountPeerId = accountPeerId
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, postbox: postbox, network: network, accountPeerId: accountPeerId, stateManager: stateManager, messageMediaPreuploadManager: messageMediaPreuploadManager, revalidationContext: revalidationContext, auxiliaryMethods: auxiliaryMethods)
        })
    }
    
    func lookUpPendingStoryIdMapping(peerId: PeerId, stableId: Int32) -> Int32? {
        return _internal_lookUpPendingStoryIdMapping(peerId: peerId, stableId: stableId)
    }
}
