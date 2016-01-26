import Foundation
import SwiftSignalKit
import sqlcipher

public protocol PostboxState: Coding {
    
}

public final class Modifier<State: PostboxState> {
    private weak var postbox: Postbox<State>?
    
    private init(postbox: Postbox<State>) {
        self.postbox = postbox
    }
    
    public func addMessages(messages: [Message], medias: [Media]) {
        self.postbox?.addMessages(messages, medias: medias)
    }
    
    public func deleteMessagesWithIds(ids: [MessageId]) {
        self.postbox?.deleteMessagesWithIds(ids)
    }
    
    public func deleteMessagesWithAbsoluteIndexedIds(ids: [Int32]) {
        if let postbox = self.postbox {
            let messageIds = postbox.messageIdsForAbsoluteIndexedIds(ids)
            postbox.deleteMessagesWithIds(messageIds)
        }
    }
    
    public func getState() -> State? {
        return self.postbox?.getState()
    }
    
    public func setState(state: State) {
        self.postbox?.setState(state)
    }
    
    public func updatePeers(peers: [Peer], update: (Peer, Peer) -> Peer) {
        self.postbox?.updatePeers(peers, update: update)
    }
    
    public func peersWithIds(ids: [PeerId]) -> [PeerId : Peer] {
        return self.postbox?.peersWithIds(ids) ?? [:]
    }
}

public final class Postbox<State: PostboxState> {
    private let basePath: String
    private let messageNamespaces: [MessageId.Namespace]
    private let absoluteIndexedMessageNamespace: MessageId.Namespace
    
    private let queue = Queue(name: "org.telegram.postbox.Postbox")
    private var valueBox: ValueBox!
    
    private var peerMessageHistoryViews: [PeerId : Bag<(MutableMessageHistoryView, Pipe<MessageHistoryView>)>] = [:]
    private var deferredMessageHistoryViewsToUpdate: [(MutableMessageHistoryView, Pipe<MessageHistoryView>)] = []
    private var peerViews: Bag<(MutablePeerView, Pipe<PeerView>)> = Bag()
    private var deferredPeerViewsToUpdate: [(MutablePeerView, Pipe<PeerView>)] = []
    private var peerPipes: [PeerId : Pipe<Peer>] = [:]
    
    private var statePipe: Pipe<State> = Pipe()
    
    public let mediaBox: MediaBox
    
    public init(basePath: String, messageNamespaces: [MessageId.Namespace], absoluteIndexedMessageNamespace: MessageId.Namespace?) {
        self.basePath = basePath
        self.messageNamespaces = messageNamespaces
        if let absoluteIndexedMessageNamespace = absoluteIndexedMessageNamespace {
            self.absoluteIndexedMessageNamespace = absoluteIndexedMessageNamespace
        } else {
            self.absoluteIndexedMessageNamespace = MessageId.Namespace.max
        }
        self.mediaBox = MediaBox(basePath: self.basePath + "/media")
        self.openDatabase()
    }
    
    private func openDatabase() {
        self.queue.dispatch {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(self.basePath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
            }
            
            self.valueBox = SqliteValueBox(basePath: self.basePath + "/db")
            //self.valueBox = LmdbValueBox(basePath: self.basePath + "/db")
            var userVersion: Int32 = 0
            let currentUserVersion: Int32 = 4
            
            if let value = self.valueBox.get(Table_Meta.id, key: Table_Meta.key()) {
                value.read(&userVersion, offset: 0, length: 4)
            }
            
            if userVersion != currentUserVersion {
                self.valueBox.drop()
                let buffer = WriteBuffer()
                var currentVersion: Int32 = currentUserVersion
                buffer.write(&currentVersion, offset: 0, length: 4)
                self.valueBox.set(Table_Meta.id, key: Table_Meta.key(), value: buffer)
            }
            
            print("(Postbox initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
    }
    
    private var cachedState: State?
    
    private func setState(state: State) {
        self.queue.dispatch {
            self.cachedState = state
            
            let encoder = Encoder()
            encoder.encodeRootObject(state)
            
            self.valueBox.set(Table_State.id, key: Table_State.key(), value: encoder.memoryBuffer())
            
            self.statePipe.putNext(state)
        }
    }
    
    private func getState() -> State? {
        if let cachedState = self.cachedState {
            return cachedState
        } else {
            if let value = self.valueBox.get(Table_State.id, key: Table_State.key()) {
                let decoder = Decoder(buffer: value)
                if let state = decoder.decodeRootObject() as? State {
                    self.cachedState = state
                    return state
                }
            }
            
            return nil
        }
    }
    
    public func state() -> Signal<State?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.dispatch {
                subscriber.putNext(self.getState())
                disposable.set(self.statePipe.signal().start(next: { next in
                    subscriber.putNext(next)
                }))
            }
            
            return disposable
        }
    }
    
    public func keychainEntryForKey(key: String) -> NSData? {
        if let value = self.valueBox.get(Table_Keychain.id, key: Table_Keychain.key(key)) {
            print("get \(key) -> \(value.length) bytes")
            return NSData(bytes: value.memory, length: value.length)
        }
        print("get \(key) -> nil")
        
        return nil
    }
    
    public func setKeychainEntryForKey(key: String, value: NSData) {
        print("set \(key) -> \(value.length) bytes")
        self.valueBox.set(Table_Keychain.id, key: Table_Keychain.key(key), value: MemoryBuffer(data: value))
    }
    
    public func removeKeychainEntryForKey(key: String) {
        self.valueBox.remove(Table_Keychain.id, key: Table_Keychain.key(key))
    }
    
    private func addMessages(messages: [Message], medias: [Media]) {
        
    }
    
    private func mediaWithIds(ids: [MediaId]) -> [MediaId : Media] {
        return [:]
    }
    
    var cachedPeers: [PeerId : Peer] = [:]
    
    private func peerWithId(peerId: PeerId) -> Peer? {
        if let cachedPeer = cachedPeers[peerId] {
            return cachedPeer
        } else {
            let peerKey = Table_Peer.emptyKey()
            if let value = self.valueBox.get(Table_Peer.id, key: Table_Peer.key(peerId, key: peerKey)) {
                let decoder = Decoder(buffer: value)
                if let peer = decoder.decodeRootObject() as? Peer {
                    cachedPeers[peer.id] = peer
                    return peer
                } else {
                    print("(PostBox: can't decode peer)")
                }
            }
            
            return nil
        }
    }
    
    private func peersWithIds(ids: [PeerId]) -> [PeerId : Peer] {
        if ids.count == 0 {
            return [:]
        } else {
            var peers: [PeerId : Peer] = [:]
            
            for id in ids {
                if let peer: Peer = self.peerWithId(id) {
                    peers[id] = peer
                }
            }
            
            return peers
        }
    }
    
    private func deferPeerViewUpdate(view: MutablePeerView, pipe: Pipe<PeerView>) {
        var i = 0
        var found = false
        while i < self.deferredPeerViewsToUpdate.count {
            if self.deferredPeerViewsToUpdate[i].1 === pipe {
                self.deferredPeerViewsToUpdate[i] = (view, pipe)
                found = true
                break
            }
            i++
        }
        if !found {
            self.deferredPeerViewsToUpdate.append((view, pipe))
        }
    }
    
    private func deferMessageHistoryViewUpdate(view: MutableMessageHistoryView, pipe: Pipe<MessageHistoryView>) {
        var i = 0
        var found = false
        while i < self.deferredMessageHistoryViewsToUpdate.count {
            if self.deferredMessageHistoryViewsToUpdate[i].1 === pipe {
                self.deferredMessageHistoryViewsToUpdate[i] = (view, pipe)
                found = true
                break
            }
            i++
        }
        if !found {
            self.deferredMessageHistoryViewsToUpdate.append((view, pipe))
        }
    }
    
    private func performDeferredUpdates() {
        let deferredPeerViewsToUpdate = self.deferredPeerViewsToUpdate
        self.deferredPeerViewsToUpdate.removeAll()
        
        for entry in deferredPeerViewsToUpdate {
            let viewRenderedMessages = self.renderedMessages(entry.0.incompleteMessages())
            if viewRenderedMessages.count != 0 {
                var viewRenderedMessagesDict: [MessageId : RenderedMessage] = [:]
                for message in viewRenderedMessages {
                    viewRenderedMessagesDict[message.message.id] = message
                }
                entry.0.completeMessages(viewRenderedMessagesDict)
            }
            
            entry.1.putNext(PeerView(entry.0))
        }
        
        let deferredMessageHistoryViewsToUpdate = self.deferredMessageHistoryViewsToUpdate
        self.deferredMessageHistoryViewsToUpdate.removeAll()
        
        for entry in deferredMessageHistoryViewsToUpdate {
            let viewRenderedMessages = self.renderedMessages(entry.0.incompleteMessages())
            if viewRenderedMessages.count != 0 {
                var viewRenderedMessagesDict: [MessageId : RenderedMessage] = [:]
                for message in viewRenderedMessages {
                    viewRenderedMessagesDict[message.message.id] = message
                }
                entry.0.completeMessages(viewRenderedMessagesDict)
            }
            
            entry.1.putNext(MessageHistoryView(entry.0))
        }
    }
    
    private func updatePeerEntry(peerId: PeerId, message: RenderedMessage?, replace: Bool = false) {
        var currentIndex: PeerViewEntryIndex?
        
        if let value = self.valueBox.get(Table_PeerEntry.id, key: Table_PeerEntry.key(peerId)) {
            currentIndex = Table_PeerEntry.get(peerId, value: value)
        }
        
        var updatedPeerMessage: RenderedMessage?
        
        if let currentIndex = currentIndex {
            if let message = message {
                let messageIndex = MessageIndex(message.message)
                if replace || currentIndex.messageIndex < messageIndex {
                    let updatedIndex = PeerViewEntryIndex(peerId: peerId, messageIndex: messageIndex)
                    updatedPeerMessage = message
                    
                    self.valueBox.remove(Table_PeerEntry_Sorted.id, key: Table_PeerEntry_Sorted.key(currentIndex))
                    self.valueBox.set(Table_PeerEntry_Sorted.id, key: Table_PeerEntry_Sorted.key(updatedIndex), value: MemoryBuffer())
                    self.valueBox.set(Table_PeerEntry.id, key: Table_PeerEntry.key(peerId), value: Table_PeerEntry.set(updatedIndex))
                }
            } else if replace {
                //TODO: remove?
            }
        } else if let message = message {
            updatedPeerMessage = message
            let updatedIndex = PeerViewEntryIndex(peerId: peerId, messageIndex: MessageIndex(message.message))

            self.valueBox.set(Table_PeerEntry_Sorted.id, key: Table_PeerEntry_Sorted.key(updatedIndex), value: MemoryBuffer())
            self.valueBox.set(Table_PeerEntry.id, key: Table_PeerEntry.key(peerId), value: Table_PeerEntry.set(updatedIndex))
        }
        
        if let updatedPeerMessage = updatedPeerMessage {
            var peer: Peer?
            for (view, pipe) in self.peerViews.copyItems() {
                if peer == nil {
                    for entry in view.entries {
                        if entry.peerId == peerId {
                            peer = entry.peer
                            break
                        }
                    }
                    
                    if peer == nil {
                        peer = self.peerWithId(peerId)
                    }
                }

                let entry: PeerViewEntry
                if let peer = peer {
                    entry = PeerViewEntry(peer: peer, message: updatedPeerMessage)
                } else {
                    entry = PeerViewEntry(peerId: peerId, message: updatedPeerMessage)
                }
                
                let context = view.removeEntry(nil, peerId: peerId)
                view.addEntry(entry)
                view.complete(context, fetchEarlier: self.fetchPeerEntriesRelative(true), fetchLater: self.fetchPeerEntriesRelative(false))
                
                self.deferPeerViewUpdate(view, pipe: pipe)
            }
        }
    }
    
    private func messageIdsForAbsoluteIndexedIds(ids: [Int32]) -> [MessageId] {
        if ids.count == 0 {
            return []
        }
        
        var result: [MessageId] = []
        
        let key = Table_GlobalMessageId.emptyKey()
        for id in ids {
            if let value = self.valueBox.get(Table_GlobalMessageId.id, key: Table_GlobalMessageId.key(id, key: key)) {
                result.append(Table_GlobalMessageId.get(id, value: value))
            }
        }
        
        return result
    }
    
    private func deleteMessagesWithIds(ids: [MessageId]) {
        
    }
    
    private func updatePeers(peers: [Peer], update: (Peer, Peer) -> Peer) {
        if peers.count == 0 {
            return
        }
        
        if peers.count == -1 {
            
        } else {
            var peerIds: [PeerId] = []
            for peer in peers {
                peerIds.append(peer.id)
            }
            
            let currentPeers = self.peersWithIds(peerIds)
            
            let encoder = Encoder()
            
            var updatedPeers: [PeerId : Peer] = [:]
            
            let peerKey = Table_Peer.emptyKey()
            for updatedPeer in peers {
                let currentPeer = currentPeers[updatedPeer.id]
                
                var finalPeer = updatedPeer
                if let currentPeer = currentPeer {
                    finalPeer = update(currentPeer, updatedPeer)
                }
                
                if currentPeer == nil || !finalPeer.equalsTo(currentPeer!) {
                    updatedPeers[finalPeer.id] = finalPeer
                    self.cachedPeers[finalPeer.id] = finalPeer
                    
                    encoder.reset()
                    encoder.encodeRootObject(finalPeer)
                    
                    peerKey.setInt64(0, value: updatedPeer.id.toInt64())
                    self.valueBox.set(Table_Peer.id, key: Table_Peer.key(finalPeer.id, key: peerKey), value: encoder.memoryBuffer())
                }
            }
            
            for record in self.peerViews.copyItems() {
                if record.0.updatePeers(updatedPeers) {
                    deferPeerViewUpdate(record.0, pipe: record.1)
                }
            }
        }
    }
    
    public func modify<T>(f: Modifier<State> -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.dispatch {
                //#if DEBUG
                    //let startTime = CFAbsoluteTimeGetCurrent()
                //#endif
                
                //self.valueBox.beginStats()
                self.valueBox.begin()
                let result = f(Modifier(postbox: self))
                //print("(Postbox modify took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms)")
                //#if DEBUG
                //startTime = CFAbsoluteTimeGetCurrent()
                //#endif
                self.valueBox.commit()
                
                //#if DEBUG
                    //print("(Postbox commit took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms)")
                //self.valueBox.endStats()
                //#endif
                
                self.performDeferredUpdates()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    private func fetchPeerEntryIndicesRelative(earlier: Bool)(index: PeerViewEntryIndex?, count: Int) -> [PeerViewEntryIndex] {
        var entries: [PeerViewEntryIndex] = []
        
        let lowerBound = Table_PeerEntry_Sorted.lowerBoundKey()
        let upperBound = Table_PeerEntry_Sorted.upperBoundKey()
        
        let bound: ValueBoxKey
        if let index = index {
            bound = Table_PeerEntry_Sorted.key(index)
        } else if earlier {
            bound = upperBound
        } else {
            bound = lowerBound
        }
        
        let keys: ValueBoxKey -> Bool = { key in
            entries.append(Table_PeerEntry_Sorted.get(key))
            
            return true
        }
        
        if earlier {
            self.valueBox.range(Table_PeerEntry_Sorted.id, start: bound, end: lowerBound, keys: keys, limit: count)
        } else {
            self.valueBox.range(Table_PeerEntry_Sorted.id, start: bound, end: upperBound, keys: keys, limit: count)
        }
        
        return entries
    }
    
    private func fetchPeerEntriesRelative(earlier: Bool)(index: PeerViewEntryIndex?, count: Int) -> [PeerViewEntry] {
        var entries: [PeerViewEntry] = []
        var peers: [PeerId : Peer] = [:]
        for entryIndex in self.fetchPeerEntryIndicesRelative(earlier)(index: index, count: count) {
            var peer: Peer?
            
            if let cachedPeer = peers[entryIndex.peerId] {
                peer = cachedPeer
            } else {
                if let fetchedPeer: Peer = self.peerWithId(entryIndex.peerId) {
                    peer = fetchedPeer
                    peers[fetchedPeer.id] = fetchedPeer
                }
            }
            
            var message: Message?
            if let value = self.valueBox.get(Table_Message.id, key: Table_Message.key(entryIndex.messageIndex)) {
                message = Table_Message.get(value)
            }
            
            if let message = message, renderedMessage = self.renderedMessages([message]).first {
                let entry: PeerViewEntry
                if let peer = peer {
                    entry = PeerViewEntry(peer: peer, message: renderedMessage)
                } else {
                    entry = PeerViewEntry(peerId: entryIndex.peerId, message: renderedMessage)
                }
                
                entries.append(entry)
            } else {
                let entry: PeerViewEntry
                if let peer = peer {
                    entry = PeerViewEntry(peer: peer, peerId: entryIndex.peerId, messageIndex: entryIndex.messageIndex)
                } else {
                    entry = PeerViewEntry(peer: nil, peerId: entryIndex.peerId, messageIndex: entryIndex.messageIndex)
                }
                
                entries.append(entry)
            }
        }
        
        //entries.sortInPlace()
        
        return entries.sort({ PeerViewEntryIndex($0) < PeerViewEntryIndex($1) })
    }
    
    private func renderedMessages(messages: [Message]) -> [RenderedMessage] {
        return []
    }
    
    public func tailMessageHistoryViewForPeerId(peerId: PeerId, count: Int) -> Signal<MessageHistoryView, NoError> {
        return Signal { subscriber in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                
                print("tailMessageHistoryViewForPeerId fetch: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                let mutableView = MutableMessageHistoryView(count: count, earlierMessage: nil, messages: [], laterMessage: nil)
                let record = (mutableView, Pipe<MessageHistoryView>())
                
                let index: Bag<(MutableMessageHistoryView, Pipe<MessageHistoryView>)>.Index
                if let bag = self.peerMessageHistoryViews[peerId] {
                    index = bag.add(record)
                } else {
                    let bag = Bag<(MutableMessageHistoryView, Pipe<MessageHistoryView>)>()
                    index = bag.add(record)
                    self.peerMessageHistoryViews[peerId] = bag
                }
                
                subscriber.putNext(MessageHistoryView(mutableView))
                
                let pipeDisposable = record.1.signal().start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            if let bag = strongSelf.peerMessageHistoryViews[peerId] {
                                bag.remove(index)
                            }
                        }
                    }
                    return
                })
            }
            
            return disposable
        }
    }
    
    public func aroundMessageHistoryViewForPeerId(peerId: PeerId, index: MessageIndex, count: Int) -> Signal<MessageHistoryView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                let mutableView: MutableMessageHistoryView
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                mutableView = MutableMessageHistoryView(count: count, earlierMessage: nil, messages: [], laterMessage: nil)
                
                print("aroundMessageViewForPeerId fetch: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                let record = (mutableView, Pipe<MessageHistoryView>())
                
                let index: Bag<(MutableMessageHistoryView, Pipe<MessageHistoryView>)>.Index
                if let bag = self.peerMessageHistoryViews[peerId] {
                    index = bag.add(record)
                } else {
                    let bag = Bag<(MutableMessageHistoryView, Pipe<MessageHistoryView>)>()
                    index = bag.add(record)
                    self.peerMessageHistoryViews[peerId] = bag
                }
                
                subscriber.putNext(MessageHistoryView(mutableView))
                
                let pipeDisposable = record.1.signal().start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            if let bag = strongSelf.peerMessageHistoryViews[peerId] {
                                bag.remove(index)
                            }
                        }
                    }
                    return
                })
            }
            
            return disposable
        }
    }
    
    public func tailPeerView(count: Int) -> Signal<PeerView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let tail = self.fetchPeerEntriesRelative(true)(index: nil, count: count + 1)
                
                print("(Postbox fetchPeerEntriesRelative took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms)")
                
                var entries: [PeerViewEntry] = []
                var i = tail.count - 1
                while i >= 0 && i >= tail.count - count {
                    entries.insert(tail[i], atIndex: 0)
                    i--
                }
                
                var earlier: PeerViewEntry?
                
                i = tail.count - count - 1
                while i >= 0 {
                    earlier = tail[i]
                    break
                }
                
                let mutableView = MutablePeerView(count: count, earlier: earlier, entries: entries, later: nil)
                let record = (mutableView, Pipe<PeerView>())
                
                let index = self.peerViews.add(record)
                
                subscriber.putNext(PeerView(mutableView))
                
                let pipeDisposable = record.1.signal().start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            strongSelf.peerViews.remove(index)
                        }
                    }
                    return
                })
            }
            
            return disposable
        }
    }
    
    public func peerWithId(id: PeerId) -> Signal<Peer, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.dispatch {
                if let peer: Peer = self.peerWithId(id) {
                    subscriber.putNext(peer)
                }
            }
            return disposable
        }
    }
}
