import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public struct HistoryPreloadIndex: Comparable {
    public let index: ChatListIndex
    public let hasUnread: Bool
    public let isMuted: Bool
    
    public static func <(lhs: HistoryPreloadIndex, rhs: HistoryPreloadIndex) -> Bool {
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
        return lhs.index > rhs.index
    }
}

private struct HistoryPreloadHole: Hashable, Comparable {
    let preloadIndex: HistoryPreloadIndex
    let hole: MessageOfInterestHole
    
    static func ==(lhs: HistoryPreloadHole, rhs: HistoryPreloadHole) -> Bool {
        return lhs.preloadIndex == rhs.preloadIndex && lhs.hole == rhs.hole
    }
    
    static func <(lhs: HistoryPreloadHole, rhs: HistoryPreloadHole) -> Bool {
        return lhs.preloadIndex < rhs.preloadIndex
    }
    
    var hashValue: Int {
        return self.preloadIndex.index.hashValue &* 31 &+ self.hole.hashValue
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
            let signal: Signal<Never, NoError> = .complete()
            |> delay(0.3, queue: queue)
            |> then(
                download
                |> take(1)
                |> deliverOn(queue)
                |> mapToSignal { download -> Signal<Never, NoError> in
                    switch hole.hole {
                        case let .peer(peerHole):
                            let range: ClosedRange<MessageId.Id>
                            switch hole.direction {
                                case .AroundId, .AroundIndex:
                                    range = 1 ... Int32.max
                                case .LowerToUpper:
                                    range = 1 ... Int32(peerHole.indices[peerHole.indices.endIndex] - 1)
                                case .UpperToLower:
                                    range = Int32(peerHole.indices[peerHole.indices.startIndex]) ... Int32.max
                            }
                            return fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .download(download), postbox: postbox, peerId: peerHole.peerId, namespace: peerHole.namespace, range: range, direction: hole.direction, space: .everywhere, limit: 60)
                        /*case let .groupFeed(groupId, lowerIndex, upperIndex):
                            return fetchGroupFeedHole(source: .download(download), accountPeerId: accountPeerId, postbox: postbox, groupId: groupId, minIndex: lowerIndex, maxIndex: upperIndex, direction: hole.direction, limit: 60)*/
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
    var index: ChatListIndex
    var hasUnread: Bool
    var isMuted: Bool
    let disposable = MetaDisposable()
    var hole: MessageOfInterestHole?
    var media: [HolesViewMedia] = []
    
    var preloadIndex: HistoryPreloadIndex {
        return HistoryPreloadIndex(index: self.index, hasUnread: self.hasUnread, isMuted: self.isMuted)
    }
    
    var currentHole: HistoryPreloadHole? {
        if let hole = self.hole {
            return HistoryPreloadHole(preloadIndex: self.preloadIndex, hole: hole)
        } else {
            return nil
        }
    }
    
    init(index: ChatListIndex, hasUnread: Bool, isMuted: Bool) {
        self.index = index
        self.hasUnread = hasUnread
        self.isMuted = isMuted
    }
    
    deinit {
        disposable.dispose()
    }
}

private enum ChatHistoryPreloadEntity: Hashable {
    case peer(PeerId)
    //case group(PeerGroupId)
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

final class ChatHistoryPreloadManager {
    private let queue = Queue()
    
    private let postbox: Postbox
    private let accountPeerId: PeerId
    private let network: Network
    private let download = Promise<Download>()
    
    private var canPreloadHistoryDisposable: Disposable?
    private var canPreloadHistoryValue = false
    
    private var automaticChatListDisposable: Disposable?
    
    private var views: [ChatHistoryPreloadEntity: HistoryPreloadViewContext] = [:]
    
    private var entries: [HistoryPreloadEntry] = []
    
    private var orderedMediaValue: [ChatHistoryPreloadMediaItem] = []
    private let orderedMediaPromise = ValuePromise<[ChatHistoryPreloadMediaItem]>([])
    var orderedMedia: Signal<[ChatHistoryPreloadMediaItem], NoError> {
        return self.orderedMediaPromise.get()
    }
    
    init(postbox: Postbox, network: Network, accountPeerId: PeerId, networkState: Signal<AccountNetworkState, NoError>) {
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
        self.download.set(network.background())
        
        self.automaticChatListDisposable = (postbox.tailChatListView(groupId: nil, count: 20, summaryComponents: ChatListEntrySummaryComponents()) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                var indices: [(ChatHistoryPreloadIndex, Bool, Bool)] = []
                for entry in view.0.entries {
                    if case let .MessageEntry(index, _, readState, notificationSettings, _, _, _, _) = entry {
                        var hasUnread = false
                        if let readState = readState {
                            hasUnread = readState.count != 0
                        }
                        var isMuted = false
                        if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                            if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
                                isMuted = true
                            }
                        }
                        indices.append((ChatHistoryPreloadIndex(index: index, entity: .peer(index.messageIndex.id.peerId)), hasUnread, isMuted))
                    }/* else if case let .GroupReferenceEntry(groupId, index, _, _, counters) = entry {
                        let hasUnread = counters.unreadCount != 0 || counters.unreadMutedCount != 0
                        let isMuted = counters.unreadCount != 0
                        indices.append((ChatHistoryPreloadIndex(index: index, entity: .group(groupId)), hasUnread, isMuted))
                    }*/
                }
                
                strongSelf.update(indices: indices)
            }
        })
        
        self.canPreloadHistoryDisposable = (networkState |> map { state -> Bool in
            switch state {
                case .online:
                    return true
                default:
                    return false
                }
            } |> distinctUntilChanged |> deliverOn(self.queue)).start(next: { [weak self] value in
                if let strongSelf = self, strongSelf.canPreloadHistoryValue != value {
                    strongSelf.canPreloadHistoryValue = value
                    if value {
                        for i in 0 ..< min(3, strongSelf.entries.count) {
                            strongSelf.entries[i].startIfNeeded(postbox: strongSelf.postbox, accountPeerId: strongSelf.accountPeerId, download: strongSelf.download.get() |> take(1), queue: strongSelf.queue)
                        }
                    }
                }
            })
    }
    
    deinit {
        self.canPreloadHistoryDisposable?.dispose()
    }
    
    private func update(indices: [(ChatHistoryPreloadIndex, Bool, Bool)]) {
        self.queue.async {
            let validEntityIds = Set(indices.map { $0.0.entity })
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
            for (index, hasUnread, isMuted) in indices {
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
                    let view = HistoryPreloadViewContext(index: index.index, hasUnread: hasUnread, isMuted: isMuted)
                    self.views[index.entity] = view
                    let key: PostboxViewKey
                    switch index.entity {
                        case let .peer(peerId):
                            key = .messageOfInterestHole(location: .peer(peerId), namespace: Namespaces.Message.Cloud, count: 60)
                        /*case let .group(groupId):
                            key = .messageOfInterestHole(location: .group(groupId), namespace: Namespaces.Message.Cloud, count: 60)*/
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
        if previousHole == updatedHole {
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
            for i in 0 ..< min(3, self.entries.count) {
                self.entries[i].startIfNeeded(postbox: self.postbox, accountPeerId: self.accountPeerId, download: self.download.get() |> take(1), queue: self.queue)
            }
        }
    }
}
