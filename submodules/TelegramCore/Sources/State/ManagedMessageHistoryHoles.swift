import Foundation
import Postbox
import SwiftSignalKit

private final class ManagedMessageHistoryHolesContext {
    private struct LocationKey: Equatable {
        var peerId: PeerId
        var threadId: Int64?
        var space: MessageHistoryHoleSpace
        
        init(peerId: PeerId, threadId: Int64?, space: MessageHistoryHoleSpace) {
            self.peerId = peerId
            self.threadId = threadId
            self.space = space
        }
    }
    
    private struct PendingEntry: CustomStringConvertible {
        var id: Int
        var key: LocationKey
        var entry: MessageHistoryHolesViewEntry
        var disposable: MetaDisposable
        
        init(id: Int, key: LocationKey, entry: MessageHistoryHolesViewEntry, disposable: MetaDisposable) {
            self.id = id
            self.key = key
            self.entry = entry
            self.disposable = disposable
        }
        
        var description: String {
            return "entry: \(self.entry)"
        }
    }
    
    private struct DiscardedEntry {
        var entry: PendingEntry
        var timestamp: Double
        
        init(entry: PendingEntry, timestamp: Double) {
            self.entry = entry
            self.timestamp = timestamp
        }
    }
    
    private let queue: Queue
    private let accountPeerId: PeerId
    private let postbox: Postbox
    private let network: Network
    
    private var nextEntryId: Int = 0
    private var pendingEntries: [PendingEntry] = []
    private var discardedEntries: [DiscardedEntry] = []
    
    private var oldEntriesTimer: SwiftSignalKit.Timer?
    
    private var currentEntries: Set<MessageHistoryHolesViewEntry> = Set()
    private var currentEntriesDisposable: Disposable?
    
    private var completedEntries: [MessageHistoryHolesViewEntry: Double] = [:]
    
    init(
        queue: Queue,
        accountPeerId: PeerId,
        postbox: Postbox,
        network: Network,
        entries: Signal<Set<MessageHistoryHolesViewEntry>, NoError>
    ) {
        self.queue = queue
        self.accountPeerId = accountPeerId
        self.postbox = postbox
        self.network = network
        
        self.currentEntriesDisposable = (entries |> deliverOn(self.queue)).start(next: { [weak self] entries in
            guard let self = self else {
                return
            }
            self.update(entries: entries)
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.oldEntriesTimer?.invalidate()
        self.currentEntriesDisposable?.dispose()
    }
    
    func clearDisposables() -> [Disposable] {
        var disposables = Array(self.pendingEntries.map(\.disposable))
        disposables.append(contentsOf: self.discardedEntries.map(\.entry.disposable))
        self.pendingEntries.removeAll()
        self.discardedEntries.removeAll()
        return disposables
    }
    
    private func updateNeedsTimer() {
        let needsTimer = !self.discardedEntries.isEmpty
        if needsTimer {
            if self.oldEntriesTimer == nil {
                self.oldEntriesTimer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: { [weak self] in
                    guard let self = self else {
                        return
                    }
                    let disposables = self.discardOldEntries()
                    for disposable in disposables {
                        disposable.dispose()
                    }
                }, queue: self.queue)
                self.oldEntriesTimer?.start()
            }
        } else if let oldEntriesTimer = self.oldEntriesTimer {
            self.oldEntriesTimer = nil
            oldEntriesTimer.invalidate()
        }
    }
    
    private func discardOldEntries() -> [Disposable] {
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        var result: [Disposable] = []
        for i in (0 ..< self.discardedEntries.count).reversed() {
            if self.discardedEntries[i].timestamp < timestamp - 0.5 {
                result.append(self.discardedEntries[i].entry.disposable)
                Logger.shared.log("ManagedMessageHistoryHoles", "Removing discarded entry \(self.discardedEntries[i].entry)")
                self.discardedEntries.remove(at: i)
            }
        }
        
        return result
    }
    
    func update(entries: Set<MessageHistoryHolesViewEntry>) {
        //let removed: [Disposable] = []
        var added: [PendingEntry] = []
        
        let timestamp = CFAbsoluteTimeGetCurrent()
        let _ = timestamp
        
        /*for i in (0 ..< self.pendingEntries.count).reversed() {
         if !entries.contains(self.pendingEntries[i].entry) {
         Logger.shared.log("ManagedMessageHistoryHoles", "Stashing entry \(self.pendingEntries[i])")
         self.discardedEntries.append(DiscardedEntry(entry: self.pendingEntries[i], timestamp: timestamp))
         self.pendingEntries.remove(at: i)
         }
         }*/
        
        for entry in entries {
            if self.completedEntries[entry] != nil {
                continue
            }
            
            switch entry.hole {
            case let .peer(peerHole):
                let key = LocationKey(peerId: peerHole.peerId, threadId: peerHole.threadId, space: entry.space)
                if !self.pendingEntries.contains(where: { $0.key == key }) {
                    if let discardedIndex = self.discardedEntries.firstIndex(where: { $0.entry.entry == entry }) {
                        let discardedEntry = self.discardedEntries.remove(at: discardedIndex)
                        Logger.shared.log("ManagedMessageHistoryHoles", "Taking discarded entry \(discardedEntry.entry)")
                        self.pendingEntries.append(discardedEntry.entry)
                    } else {
                        let disposable = MetaDisposable()
                        let id = self.nextEntryId
                        self.nextEntryId += 1
                        let pendingEntry = PendingEntry(id: id, key: key, entry: entry, disposable: disposable)
                        self.pendingEntries.append(pendingEntry)
                        Logger.shared.log("ManagedMessageHistoryHoles", "Adding pending entry \(pendingEntry), discarded entries: \(self.discardedEntries.map(\.entry))")
                        added.append(pendingEntry)
                    }
                }
            }
        }
        
        self.updateNeedsTimer()
        
        for pendingEntry in added {
            let id = pendingEntry.id
            let entry = pendingEntry.entry
            switch pendingEntry.entry.hole {
            case let .peer(hole):
                pendingEntry.disposable.set((fetchMessageHistoryHole(
                    accountPeerId: self.accountPeerId,
                    source: .network(self.network),
                    postbox: self.postbox,
                    peerInput: .direct(peerId: hole.peerId, threadId: hole.threadId), namespace: hole.namespace, direction: pendingEntry.entry.direction, space: pendingEntry.entry.space, count: pendingEntry.entry.count)
                |> deliverOn(self.queue)).start(completed: { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.pendingEntries.removeAll(where: { $0.id == id })
                    self.completedEntries[entry] = CFAbsoluteTimeGetCurrent()
                    self.update(entries: self.currentEntries)
                }))
            }
        }
    }
}

func managedMessageHistoryHoles(accountPeerId: PeerId, network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    let sharedQueue = Queue()
    
    return Signal { _ in
        var context: QueueLocalObject<ManagedMessageHistoryHolesContext>? = QueueLocalObject<ManagedMessageHistoryHolesContext>(queue: sharedQueue, generate: {
            return ManagedMessageHistoryHolesContext(
                queue: sharedQueue,
                accountPeerId: accountPeerId,
                postbox: postbox,
                network: network,
                entries: postbox.messageHistoryHolesView() |> map { view in
                    return view.entries
                }
            )
        })
        
        /*var performWorkImpl: ((@escaping (ManagedMessageHistoryHolesState) -> Void) -> Void)?
        let state = Atomic(value: ManagedMessageHistoryHolesState(performWork: { f in
            performWorkImpl?(f)
        }))
        performWorkImpl = { [weak state] f in
            state?.with { state in
                f(state)
            }
        }
        
        let disposable = (postbox.messageHistoryHolesView()
        |> deliverOn(sharedQueue)).start(next: { view in
            let (removed, added, _) = state.with { state in
                return state.update(entries: view.entries)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (entry, disposable) in added {
                switch entry.hole {
                case let .peer(hole):
                    disposable.set((fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .network(network), postbox: postbox, peerInput: .direct(peerId: hole.peerId, threadId: hole.threadId), namespace: hole.namespace, direction: entry.direction, space: entry.space, count: entry.count)
                    |> afterDisposed {
                        sharedQueue.async {
                            state.with { state in
                                let _ = state
                                //state.removeCompletedEntry(entry: entry)
                            }
                        }
                    }).start())
                }
            }
        })*/
        
        return ActionDisposable {
            if context != nil {
                context = nil
            }
            /*disposable.dispose()
            for disposable in state.with({ state -> [Disposable] in
                state.clearDisposables()
            }) {
                disposable.dispose()
            }*/
        }
    }
    |> runOn(sharedQueue)
}
