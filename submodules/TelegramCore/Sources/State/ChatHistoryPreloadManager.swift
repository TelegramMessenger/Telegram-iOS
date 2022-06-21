import Foundation
import Postbox
import SwiftSignalKit


public struct HistoryPreloadIndex: Hashable, Comparable, CustomStringConvertible {
    public let index: ChatListIndex?
    public let hasUnread: Bool
    public let isMuted: Bool
    public let isPriority: Bool
    
    public init(index: ChatListIndex?, hasUnread: Bool, isMuted: Bool, isPriority: Bool) {
        self.index = index
        self.hasUnread = hasUnread
        self.isMuted = isMuted
        self.isPriority = isPriority
    }
    
    public static func <(lhs: HistoryPreloadIndex, rhs: HistoryPreloadIndex) -> Bool {
        if lhs.isPriority != rhs.isPriority {
            if lhs.isPriority {
                return true
            } else {
                return false
            }
        }
        if lhs.isMuted != rhs.isMuted {
            if lhs.isMuted {
                return false
            } else {
                return true
            }
        }
        if lhs.hasUnread != rhs.hasUnread {
            if lhs.hasUnread {
                return true
            } else {
                return false
            }
        }
        if let lhsIndex = lhs.index, let rhsIndex = rhs.index {
            return lhsIndex > rhsIndex
        } else if lhs.index != nil {
            return true
        } else if rhs.index != nil {
            return false
        } else {
            return true
        }
    }
    
    public var description: String {
        return "index: \(String(describing: self.index)), hasUnread: \(self.hasUnread), isMuted: \(self.isMuted), isPriority: \(self.isPriority)"
    }
}

private struct HistoryPreloadHole: Hashable, Comparable, CustomStringConvertible {
    let preloadIndex: HistoryPreloadIndex
    let hole: MessageOfInterestHole
    
    static func <(lhs: HistoryPreloadHole, rhs: HistoryPreloadHole) -> Bool {
        return lhs.preloadIndex < rhs.preloadIndex
    }
    
    var description: String {
        return "(preloadIndex: \(self.preloadIndex), hole: \(self.hole))"
    }
}

private final class HistoryPreloadEntry: Comparable {
    var hole: HistoryPreloadHole
    private var isStarted = false
    private let disposable = MetaDisposable()
    
    init(hole: HistoryPreloadHole) {
        self.hole = hole
    }
    
    static func ==(lhs: HistoryPreloadEntry, rhs: HistoryPreloadEntry) -> Bool {
        return lhs.hole == rhs.hole
    }
    
    static func <(lhs: HistoryPreloadEntry, rhs: HistoryPreloadEntry) -> Bool {
        return lhs.hole < rhs.hole
    }
    
    func startIfNeeded(postbox: Postbox, accountPeerId: PeerId, download: Signal<Download, NoError>, queue: Queue) {
        if !self.isStarted {
            self.isStarted = true
            
            let hole = self.hole.hole
            
            Logger.shared.log("HistoryPreload", "start hole \(hole)")
            
            let signal: Signal<Never, NoError> = .complete()
            |> delay(0.3, queue: queue)
            |> then(
                download
                |> take(1)
                |> deliverOn(queue)
                |> mapToSignal { download -> Signal<Never, NoError> in
                    switch hole.hole {
                    case let .peer(peerHole):
                        return fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .download(download), postbox: postbox, peerInput: .direct(peerId: peerHole.peerId, threadId: nil), namespace: peerHole.namespace, direction: hole.direction, space: .everywhere, count: 60)
                        |> ignoreValues
                    }
                }
            )
            self.disposable.set(signal.start())
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
}

private final class HistoryPreloadViewContext {
    var index: ChatListIndex?
    var hasUnread: Bool?
    var isMuted: Bool?
    var isPriority: Bool
    let disposable = MetaDisposable()
    var hole: MessageOfInterestHole?
    var media: [HolesViewMedia] = []
    
    var preloadIndex: HistoryPreloadIndex {
        return HistoryPreloadIndex(index: self.index, hasUnread: self.hasUnread ?? false, isMuted: self.isMuted ?? true, isPriority: self.isPriority)
    }
    
    var currentHole: HistoryPreloadHole? {
        if let hole = self.hole {
            return HistoryPreloadHole(preloadIndex: self.preloadIndex, hole: hole)
        } else {
            return nil
        }
    }
    
    init(index: ChatListIndex?, hasUnread: Bool?, isMuted: Bool?, isPriority: Bool) {
        self.index = index
        self.hasUnread = hasUnread
        self.isMuted = isMuted
        self.isPriority = isPriority
    }
    
    deinit {
        disposable.dispose()
    }
}

private enum ChatHistoryPreloadEntity: Hashable {
    case peer(PeerId)
}

private struct ChatHistoryPreloadIndex {
    let index: ChatListIndex
    let entity: ChatHistoryPreloadEntity
}

public final class ChatHistoryPreloadMediaItem: Comparable {
    public let preloadIndex: HistoryPreloadIndex
    public let media: HolesViewMedia
    
    init(preloadIndex: HistoryPreloadIndex, media: HolesViewMedia) {
        self.preloadIndex = preloadIndex
        self.media = media
    }
    
    public static func ==(lhs: ChatHistoryPreloadMediaItem, rhs: ChatHistoryPreloadMediaItem) -> Bool {
        if lhs.preloadIndex != rhs.preloadIndex {
            return false
        }
        if lhs.media != rhs.media {
            return false
        }
        return true
    }
    
    public static func <(lhs: ChatHistoryPreloadMediaItem, rhs: ChatHistoryPreloadMediaItem) -> Bool {
        if lhs.preloadIndex != rhs.preloadIndex {
            return lhs.preloadIndex > rhs.preloadIndex
        }
        return lhs.media.index < rhs.media.index
    }
}

private final class AdditionalPreloadPeerIdsContext {
    private let queue: Queue
    
    private var subscribers: [PeerId: Bag<Void>] = [:]
    private var additionalPeerIdsValue = ValuePromise<Set<PeerId>>(Set(), ignoreRepeated: true)
    
    var additionalPeerIds: Signal<Set<PeerId>, NoError> {
        return self.additionalPeerIdsValue.get()
    }
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    func add(peerId: PeerId) -> Disposable {
        let bag: Bag<Void>
        if let current = self.subscribers[peerId] {
            bag = current
        } else {
            bag = Bag()
            self.subscribers[peerId] = bag
        }
        let wasEmpty = bag.isEmpty
        let index = bag.add(Void())
        
        if wasEmpty {
            self.additionalPeerIdsValue.set(Set(self.subscribers.keys))
        }
        let queue = self.queue
        return ActionDisposable { [weak self, weak bag] in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                if let current = strongSelf.subscribers[peerId], let bag = bag, current === bag {
                    current.remove(index)
                    if current.isEmpty {
                        strongSelf.subscribers.removeValue(forKey: peerId)
                        strongSelf.additionalPeerIdsValue.set(Set(strongSelf.subscribers.keys))
                    }
                }
            }
        }
    }
}

public struct ChatHistoryPreloadItem : Equatable {
    public let index: ChatListIndex
    public let isMuted: Bool
    public let hasUnread: Bool
    
    public init(index: ChatListIndex, isMuted: Bool, hasUnread: Bool) {
        self.index = index
        self.isMuted = isMuted
        self.hasUnread = hasUnread
    }
}

final class ChatHistoryPreloadManager {
    private let queue = Queue()
    
    private let postbox: Postbox
    private let accountPeerId: PeerId
    private let network: Network
    private let download = Promise<Download>()
    
    private var canPreloadHistoryDisposable: Disposable?
    private var canPreloadHistoryValue = false
    
    private let automaticChatListDisposable = MetaDisposable()
    
    private var views: [ChatHistoryPreloadEntity: HistoryPreloadViewContext] = [:]
    
    private var entries: [HistoryPreloadEntry] = []
    
    private var orderedMediaValue: [ChatHistoryPreloadMediaItem] = []
    private let orderedMediaPromise = ValuePromise<[ChatHistoryPreloadMediaItem]>([])
    var orderedMedia: Signal<[ChatHistoryPreloadMediaItem], NoError> {
        return self.orderedMediaPromise.get()
    }
    
    private let additionalPreloadPeerIdsContext:  QueueLocalObject<AdditionalPreloadPeerIdsContext>
    private let preloadItemsSignal: Signal<[ChatHistoryPreloadItem], NoError>
    
    init(postbox: Postbox, network: Network, accountPeerId: PeerId, networkState: Signal<AccountNetworkState, NoError>, preloadItemsSignal: Signal<[ChatHistoryPreloadItem], NoError>) {
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
        self.download.set(network.background())
        self.preloadItemsSignal = preloadItemsSignal
        
        let queue = Queue.mainQueue()
        self.additionalPreloadPeerIdsContext = QueueLocalObject(queue: queue, generate: {
            AdditionalPreloadPeerIdsContext(queue: queue)
        })
        
        self.canPreloadHistoryDisposable = (networkState
        |> map { state -> Bool in
            switch state {
                case .online:
                    return true
                default:
                    return false
            }
        }
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            guard let strongSelf = self, strongSelf.canPreloadHistoryValue != value else {
                return
            }
            strongSelf.canPreloadHistoryValue = value
            if value {
                for i in 0 ..< min(3, strongSelf.entries.count) {
                    strongSelf.entries[i].startIfNeeded(postbox: strongSelf.postbox, accountPeerId: strongSelf.accountPeerId, download: strongSelf.download.get() |> take(1), queue: strongSelf.queue)
                }
            }
        })
    }
    
    deinit {
        self.canPreloadHistoryDisposable?.dispose()
    }
    
    func addAdditionalPeerId(peerId: PeerId) -> Disposable {
        let disposable = MetaDisposable()
        self.additionalPreloadPeerIdsContext.with { context in
            disposable.set(context.add(peerId: peerId))
        }
        return disposable
    }
    
    func start() {
        let additionalPreloadPeerIdsContext = self.additionalPreloadPeerIdsContext
        let additionalPeerIds = Signal<Set<PeerId>, NoError> { subscriber in
            let disposable = MetaDisposable()
            additionalPreloadPeerIdsContext.with { context in
                disposable.set(context.additionalPeerIds.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
        
        /*let signal = self.postbox.tailChatListView(groupId: .root, count: 20, summaryComponents: ChatListEntrySummaryComponents())
        |> map { view -> [ChatHistoryPreloadItem] in
            var result: [ChatHistoryPreloadItem] = []
            for entry in view.0.entries {
                if case let .MessageEntry(index, _, readState, isMuted, _, _, _, _, _, _) = entry {
                    var hasUnread = false
                    if let readState = readState {
                        hasUnread = readState.count != 0
                    }
                    result.append(ChatHistoryPreloadItem(index: index, isMuted: isMuted, hasUnread: hasUnread))
                }
            }
            return result
        }*/
        
        self.automaticChatListDisposable.set((combineLatest(queue: .mainQueue(), self.preloadItemsSignal, additionalPeerIds)
        |> delay(1.0, queue: .mainQueue())
        |> deliverOnMainQueue).start(next: { [weak self] loadItems, additionalPeerIds in
            guard let strongSelf = self else {
                return
            }
            #if DEBUG
            //return
            #endif
            
            var indices: [(ChatHistoryPreloadIndex, Bool, Bool)] = []
            for item in loadItems {
                indices.append((ChatHistoryPreloadIndex(index: item.index, entity: .peer(item.index.messageIndex.id.peerId)), item.hasUnread, item.isMuted))
            }
            
            strongSelf.update(indices: indices, additionalPeerIds: additionalPeerIds)
        }))
    }
    
    private func update(indices: [(ChatHistoryPreloadIndex, Bool, Bool)], additionalPeerIds: Set<PeerId>) {
        self.queue.async {
            var validEntityIds = Set(indices.map { $0.0.entity })
            for peerId in additionalPeerIds {
                validEntityIds.insert(.peer(peerId))
            }
            
            var removedEntityIds: [ChatHistoryPreloadEntity] = []
            for (entityId, view) in self.views {
                if !validEntityIds.contains(entityId) {
                    removedEntityIds.append(entityId)
                    if let hole = view.currentHole {
                        self.update(from: hole, to: nil)
                    }
                }
            }
            for entityId in removedEntityIds {
                self.views.removeValue(forKey: entityId)
            }
            
            var combinedIndices: [(ChatHistoryPreloadIndex, Bool, Bool, Bool)] = []
            var existingPeerIds = Set<PeerId>()
            for (index, hasUnread, isMuted) in indices {
                existingPeerIds.insert(index.index.messageIndex.id.peerId)
                combinedIndices.append((index, hasUnread, isMuted, additionalPeerIds.contains(index.index.messageIndex.id.peerId)))
            }
            for peerId in additionalPeerIds {
                if !existingPeerIds.contains(peerId) {
                    combinedIndices.append((ChatHistoryPreloadIndex(index: ChatListIndex.absoluteLowerBound, entity: .peer(peerId)), false, true, true))
                }
            }
            
            for (index, hasUnread, isMuted, isPriority) in combinedIndices {
                if let view = self.views[index.entity] {
                    if view.index != index.index || view.hasUnread != hasUnread || view.isMuted != isMuted {
                        let previousHole = view.currentHole
                        view.index = index.index
                        view.hasUnread = hasUnread
                        view.isMuted = isMuted
                        
                        let updatedHole = view.currentHole
                        if previousHole != updatedHole {
                            self.update(from: previousHole, to: updatedHole)
                        }
                    }
                } else {
                    let view = HistoryPreloadViewContext(index: index.index, hasUnread: hasUnread, isMuted: isMuted, isPriority: isPriority)
                    self.views[index.entity] = view
                    let key: PostboxViewKey
                    switch index.entity {
                        case let .peer(peerId):
                            key = .messageOfInterestHole(location: .peer(peerId), namespace: Namespaces.Message.Cloud, count: 70)
                    }
                    view.disposable.set((self.postbox.combinedView(keys: [key])
                    |> deliverOn(self.queue)).start(next: { [weak self] next in
                        if let strongSelf = self, let value = next.views[key] as? MessageOfInterestHolesView {
                            if let view = strongSelf.views[index.entity] {
                                let previousHole = view.currentHole
                                view.hole = value.closestHole
                                
                                var mediaUpdated = false
                                if view.media.count != value.closestLaterMedia.count {
                                    mediaUpdated = true
                                } else {
                                    for i in 0 ..< view.media.count {
                                        if view.media[i] != value.closestLaterMedia[i] {
                                            mediaUpdated = true
                                            break
                                        }
                                    }
                                }
                                if mediaUpdated {
                                    view.media = value.closestLaterMedia
                                    strongSelf.updateMedia()
                                }
                                
                                let updatedHole = view.currentHole
                                
                                let holeIsUpdated = previousHole != updatedHole
                                
                                switch index.entity {
                                case let .peer(peerId):
                                    Logger.shared.log("HistoryPreload", "view \(peerId) hole \(String(describing: updatedHole)) isUpdated: \(holeIsUpdated)")
                                }
                                
                                if previousHole != updatedHole {
                                    strongSelf.update(from: previousHole, to: updatedHole)
                                }
                            }
                        }
                    }))
                }
            }
        }
    }
    
    private func updateMedia() {
        var result: [ChatHistoryPreloadMediaItem] = []
        for (_, view) in self.views {
            for media in view.media {
                result.append(ChatHistoryPreloadMediaItem(preloadIndex: view.preloadIndex, media: media))
            }
        }
        result.sort()
        if result != self.orderedMediaValue {
            self.orderedMediaValue = result
            self.orderedMediaPromise.set(result)
        }
    }
    
    private func update(from previousHole: HistoryPreloadHole?, to updatedHole: HistoryPreloadHole?) {
        assert(self.queue.isCurrent())
        let isHoleUpdated = previousHole != updatedHole
        
        Logger.shared.log("HistoryPreload", "update from \(String(describing: previousHole)) to \(String(describing: updatedHole)), isUpdated: \(isHoleUpdated)")
        
        if !isHoleUpdated {
            return
        }
        
        var skipUpdated = false
        if let previousHole = previousHole {
            for i in (0 ..< self.entries.count).reversed() {
                if self.entries[i].hole == previousHole {
                    if let updatedHole = updatedHole, updatedHole.hole == self.entries[i].hole.hole {
                        self.entries[i].hole = updatedHole
                        skipUpdated = true
                    } else {
                        self.entries.remove(at: i)
                    }
                    break
                }
            }
        }
        
        if let updatedHole = updatedHole, !skipUpdated {
            var found = false
            for i in 0 ..< self.entries.count {
                if self.entries[i].hole == updatedHole {
                    found = true
                    break
                }
            }
            if !found {
                self.entries.append(HistoryPreloadEntry(hole: updatedHole))
                self.entries.sort()
            }
        }
        
        if self.canPreloadHistoryValue {
            Logger.shared.log("HistoryPreload", "will start")
            for i in 0 ..< min(3, self.entries.count) {
                self.entries[i].startIfNeeded(postbox: self.postbox, accountPeerId: self.accountPeerId, download: self.download.get() |> take(1), queue: self.queue)
            }
        } else {
            Logger.shared.log("HistoryPreload", "will not start, canPreloadHistoryValue = false")
        }
    }
}
