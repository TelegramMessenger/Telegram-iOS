#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public struct ChannelAdminEventLogEntry: Comparable {
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

public final class ChannelAdminEventLogContext {
    private let queue: Queue = Queue.mainQueue()
    
    private let postbox: Postbox
    private let network: Network
    private let peerId: PeerId
    
    private var entries: [ChannelAdminEventLogEntry] = []
    private var hasEarlier: Bool = true
    private var loadingMoreEarlier: Bool = false
    
    private var subscribers = Bag<([ChannelAdminEventLogEntry], Bool, ChannelAdminEventLogUpdateType) -> Void>()
    
    private let loadMoreDisposable = MetaDisposable()
    
    public init(postbox: Postbox, network: Network, peerId: PeerId) {
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
    }
    
    deinit {
        self.loadMoreDisposable.dispose()
    }
    
    public func get() -> Signal<([ChannelAdminEventLogEntry], Bool, ChannelAdminEventLogUpdateType), NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                subscriber.putNext((strongSelf.entries, strongSelf.hasEarlier, .initial))
                
                let index = strongSelf.subscribers.add({ entries, hasEarlier, type in
                    subscriber.putNext((strongSelf.entries, strongSelf.hasEarlier, type))
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
    
    public func loadMoreEntries() {
        assert(self.queue.isCurrent())
        
        if self.loadingMoreEarlier {
            return
        }
        
        let maxId: AdminLogEventId
        if let last = self.entries.last {
            maxId = last.event.id
        } else {
            maxId = AdminLogEventId.max
        }
        
        self.loadingMoreEarlier = true
        self.loadMoreDisposable.set((channelAdminLogEvents(postbox: self.postbox, network: self.network, peerId: self.peerId, maxId: maxId, minId: AdminLogEventId.min, limit: 10, query: nil, filter: nil, admins: nil)
        |> deliverOn(self.queue)).start(next: { [weak self] result in
            if let strongSelf = self {
                var events = result.events.sorted()
                if let first = strongSelf.entries.first {
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
                
                strongSelf.hasEarlier = !events.isEmpty
                
                var entries: [ChannelAdminEventLogEntry] = events.map { event in
                    return ChannelAdminEventLogEntry(event: event, peers: result.peers)
                    
                }
                entries.append(contentsOf: strongSelf.entries)
                strongSelf.entries = entries
                
                strongSelf.loadingMoreEarlier = false
                
                for subscriber in strongSelf.subscribers.copyItems() {
                    subscriber(strongSelf.entries, strongSelf.hasEarlier, .load)
                }
            }
        }))
    }
}
