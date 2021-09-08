import Postbox
import SwiftSignalKit

public struct ChannelAdminEventLogEntry: Comparable {
    public let stableId: UInt32
    public let event: AdminLogEvent
    public let peers: [PeerId: Peer]
    
    public static func ==(lhs: ChannelAdminEventLogEntry, rhs: ChannelAdminEventLogEntry) -> Bool {
        return lhs.event == rhs.event
    }
    
    public static func <(lhs: ChannelAdminEventLogEntry, rhs: ChannelAdminEventLogEntry) -> Bool {
        return lhs.event < rhs.event
    }
}

public enum ChannelAdminEventLogUpdateType {
    case initial
    case generic
    case load
}

public struct ChannelAdminEventLogFilter: Equatable {
    public let query: String?
    public let events: AdminLogEventsFlags
    public let adminPeerIds: [PeerId]?
    
    public init(query: String? = nil, events: AdminLogEventsFlags = .all, adminPeerIds: [PeerId]? = nil) {
        self.query = query
        self.events = events
        self.adminPeerIds = adminPeerIds
    }
    
    public static func ==(lhs: ChannelAdminEventLogFilter, rhs: ChannelAdminEventLogFilter) -> Bool {
        if lhs.query != rhs.query {
            return false
        }
        if lhs.events != rhs.events {
            return false
        }
        if let lhsAdminPeerIds = lhs.adminPeerIds, let rhsAdminPeerIds = rhs.adminPeerIds {
            if lhsAdminPeerIds != rhsAdminPeerIds {
                return false
            }
        } else if (lhs.adminPeerIds != nil) != (rhs.adminPeerIds != nil) {
            return false
        }
        return true
    }
    
    public var isEmpty: Bool {
        if self.query != nil {
            return false
        }
        if self.events != .all {
            return false
        }
        if self.adminPeerIds != nil {
            return false
        }
        return true
    }
    
    public func withQuery(_ query: String?) -> ChannelAdminEventLogFilter {
        return ChannelAdminEventLogFilter(query: query, events: self.events, adminPeerIds: self.adminPeerIds)
    }
    
    public func withEvents(_ events: AdminLogEventsFlags) -> ChannelAdminEventLogFilter {
        return ChannelAdminEventLogFilter(query: self.query, events: events, adminPeerIds: self.adminPeerIds)
    }
    
    public func withAdminPeerIds(_ adminPeerIds: [PeerId]?) -> ChannelAdminEventLogFilter {
        return ChannelAdminEventLogFilter(query: self.query, events: self.events, adminPeerIds: adminPeerIds)
    }
}

public final class ChannelAdminEventLogContext {
    private let queue: Queue = Queue.mainQueue()
    
    private let postbox: Postbox
    private let network: Network
    private let peerId: PeerId
    
    private var filter: ChannelAdminEventLogFilter = ChannelAdminEventLogFilter()
    
    private var nextStableId: UInt32 = 1
    private var stableIds: [AdminLogEventId: UInt32] = [:]
    
    private var entries: ([ChannelAdminEventLogEntry], ChannelAdminEventLogFilter) = ([], ChannelAdminEventLogFilter())
    private var hasEntries: Bool = false
    private var hasEarlier: Bool = true
    private var loadingMoreEarlier: Bool = false
    
    private var subscribers = Bag<([ChannelAdminEventLogEntry], Bool, ChannelAdminEventLogUpdateType, Bool) -> Void>()
    
    private let loadMoreDisposable = MetaDisposable()
    
    init(postbox: Postbox, network: Network, peerId: PeerId) {
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
    }
    
    deinit {
        self.loadMoreDisposable.dispose()
    }
    
    public func get() -> Signal<([ChannelAdminEventLogEntry], Bool, ChannelAdminEventLogUpdateType, Bool), NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext((strongSelf.entries.0, strongSelf.hasEarlier, .initial, strongSelf.hasEntries))
                
                let index = strongSelf.subscribers.add({ entries, hasEarlier, type, hasEntries in
                    subscriber.putNext((entries, hasEarlier, type, hasEntries))
                })
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.subscribers.remove(index)
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(queue)
    }
    
    public func setFilter(_ filter: ChannelAdminEventLogFilter) {
        if self.filter != filter {
            self.filter = filter
            self.loadingMoreEarlier = false
            self.hasEarlier = false
            self.hasEntries = false
            
            for subscriber in self.subscribers.copyItems() {
                subscriber(self.entries.0, self.hasEarlier, .load, self.hasEntries)
            }
            
            self.loadMoreEntries()
        }
    }
    
    public func reload() {
        self.entries = ([], self.filter)
        self.loadMoreEntries()
    }
    
    public func loadMoreEntries() {
        assert(self.queue.isCurrent())
        
        if self.loadingMoreEarlier {
            return
        }
        
        let maxId: AdminLogEventId
        if self.entries.1 == self.filter, let first = self.entries.0.first {
            maxId = first.event.id
        } else {
            maxId = AdminLogEventId.max
        }
        
        self.loadingMoreEarlier = true
        self.loadMoreDisposable.set((channelAdminLogEvents(postbox: self.postbox, network: self.network, peerId: self.peerId, maxId: maxId, minId: AdminLogEventId.min, limit: 100, query: self.filter.query, filter: self.filter.events, admins: self.filter.adminPeerIds)
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            if let strongSelf = self {
                var events = result.events.sorted()
                if strongSelf.entries.1 == strongSelf.filter {
                    if let first = strongSelf.entries.0.first {
                        var clipIndex = events.count
                        for i in (0 ..< events.count).reversed() {
                            if events[i] >= first.event {
                                clipIndex = i - 1
                            }
                        }
                        if clipIndex < events.count {
                            events.removeSubrange(clipIndex ..< events.count)
                        }
                    }
                    
                    var entries: [ChannelAdminEventLogEntry] = events.map { event in
                        return ChannelAdminEventLogEntry(stableId: strongSelf.stableIdForEventId(event.id), event: event, peers: result.peers)
                    }
                    entries.append(contentsOf: strongSelf.entries.0)
                    strongSelf.entries = (entries, strongSelf.filter)
                } else {
                    let entries: [ChannelAdminEventLogEntry] = events.map { event in
                        return ChannelAdminEventLogEntry(stableId: strongSelf.stableIdForEventId(event.id), event: event, peers: result.peers)
                    }
                    strongSelf.entries = (entries, strongSelf.filter)
                }
                
                strongSelf.hasEarlier = !events.isEmpty
                strongSelf.loadingMoreEarlier = false
                strongSelf.hasEntries = true
                
                for subscriber in strongSelf.subscribers.copyItems() {
                    subscriber(strongSelf.entries.0, strongSelf.hasEarlier, .load, strongSelf.hasEntries)
                }
            }
        }))
    }
    
    private func stableIdForEventId(_ id: AdminLogEventId) -> UInt32 {
        if let value = self.stableIds[id] {
            return value
        } else {
            let value = self.nextStableId
            self.nextStableId += 1
            self.stableIds[id] = value
            return value
        }
    }
}
