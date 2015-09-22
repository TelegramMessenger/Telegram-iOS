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
    private let absoluteIndexedMessageNamespaces: [MessageId.Namespace]
    
    private let queue = Queue(name: "org.telegram.postbox.Postbox")
    private var valueBox: ValueBox!
    
    private var peerMessageViews: [PeerId : Bag<(MutableMessageView, Pipe<MessageView>)>] = [:]
    private var deferredMessageViewsToUpdate: [(MutableMessageView, Pipe<MessageView>)] = []
    private var peerViews: Bag<(MutablePeerView, Pipe<PeerView>)> = Bag()
    private var deferredPeerViewsToUpdate: [(MutablePeerView, Pipe<PeerView>)] = []
    private var peerPipes: [PeerId : Pipe<Peer>] = [:]
    
    private var statePipe: Pipe<State> = Pipe()
    
    public let mediaBox: MediaBox
    
    public init(basePath: String, messageNamespaces: [MessageId.Namespace], absoluteIndexedMessageNamespaces: [MessageId.Namespace]) {
        self.basePath = basePath
        self.messageNamespaces = messageNamespaces
        self.absoluteIndexedMessageNamespaces = absoluteIndexedMessageNamespaces
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
            let currentUserVersion: Int32 = 3
            
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
        let encoder = Encoder()
        
        for (peerId, peerMessages) in messagesGroupedByPeerId(messages) {
            var maxMessage: (MessageIndex, Message)?
            
            var messageIds: [MessageId] = []
            var seenMessageIds = Set<MessageId>()
            for message in peerMessages {
                if !seenMessageIds.contains(message.id) {
                    seenMessageIds.insert(message.id)
                    messageIds.append(message.id)
                }
            }
            
            var existingMessageIds = Set<MessageId>()
            
            let existingMessageKey = Table_Message.emptyKey()
            existingMessageKey.setInt64(0, value: peerId.toInt64())
            for id in messageIds {
                if self.valueBox.exists(Table_Message.id, key: Table_Message.key(id, key: existingMessageKey)) {
                    existingMessageIds.insert(id)
                }
            }
            
            var addedMessages: [Message] = []
            
            let mediaMessageIdKey = Table_Media_MessageIds.emptyKey()
            for message in peerMessages {
                if existingMessageIds.contains(message.id) {
                    continue
                }
                existingMessageIds.insert(message.id)
                addedMessages.append(message)
                
                let index = MessageIndex(message)
                if maxMessage == nil || index > maxMessage!.0 {
                    maxMessage = (index, message)
                }
                
                encoder.reset()
                encoder.encodeRootObject(message)
                
                for id in message.mediaIds {
                    self.valueBox.set(Table_Media_MessageIds.id, key: Table_Media_MessageIds.key(id, messageId: message.id, key: mediaMessageIdKey), value: MemoryBuffer())
                }
                
                self.valueBox.set(Table_Message.id, key: Table_Message.key(message.id), value: Table_Message.set(message))
                
                let absoluteKey = Table_AbsoluteMessageId.emptyKey()
                if self.absoluteIndexedMessageNamespaces.contains(message.id.namespace) {
                    self.valueBox.set(Table_AbsoluteMessageId.id, key: Table_AbsoluteMessageId.key(message.id.id, key: absoluteKey), value: Table_AbsoluteMessageId.set(message.id))
                }
            }
            
            if let relatedViews = self.peerMessageViews[peerId] {
                for record in relatedViews.copyItems() {
                    var updated = false
                    for message in addedMessages {
                        if record.0.add(RenderedMessage(message: message)) {
                            updated = true
                        }
                    }
                    
                    if updated {
                        self.deferMessageViewUpdate(record.0, pipe: record.1)
                    }
                }
            }
            
            if let maxMessage = maxMessage {
                self.updatePeerEntry(peerId, message: RenderedMessage(message: maxMessage.1))
            }
        }
        
        var existingMediaIds = Set<MediaId>()
        
        let existingMediaKey = Table_Media.emptyKey()
        for media in medias {
            if let id = media.id {
                if self.valueBox.exists(Table_Media.id, key: Table_Media.key(id, key: existingMediaKey)) {
                    existingMediaIds.insert(id)
                }
            }
        }
        
        let mediaKey = Table_Media.emptyKey()
        for media in medias {
            if let id = media.id {
                if existingMediaIds.contains(id) {
                    continue
                }
                existingMediaIds.insert(id)

                self.valueBox.set(Table_Media.id, key: Table_Media.key(id, key: mediaKey), value: Table_Media.set(media))
            }
        }
    }
    
    private func mediaWithIds(ids: [MediaId]) -> [MediaId : Media] {
        if ids.count == 0 {
            return [:]
        } else {
            var result: [MediaId : Media] = [:]
            
            let mediaKey = Table_Media.emptyKey()
            for id in ids {
                if let value = self.valueBox.get(Table_Media.id, key: Table_Media.key(id, key: mediaKey)) {
                    if let media = Table_Media.get(value) {
                        result[id] = media
                    } else {
                        print("can't parse media")
                    }
                }
            }
            
            return result
        }
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
    
    private func deferMessageViewUpdate(view: MutableMessageView, pipe: Pipe<MessageView>) {
        var i = 0
        var found = false
        while i < self.deferredMessageViewsToUpdate.count {
            if self.deferredMessageViewsToUpdate[i].1 === pipe {
                self.deferredMessageViewsToUpdate[i] = (view, pipe)
                found = true
                break
            }
            i++
        }
        if !found {
            self.deferredMessageViewsToUpdate.append((view, pipe))
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
        
        let deferredMessageViewsToUpdate = self.deferredMessageViewsToUpdate
        self.deferredMessageViewsToUpdate.removeAll()
        
        for entry in deferredMessageViewsToUpdate {
            let viewRenderedMessages = self.renderedMessages(entry.0.incompleteMessages())
            if viewRenderedMessages.count != 0 {
                var viewRenderedMessagesDict: [MessageId : RenderedMessage] = [:]
                for message in viewRenderedMessages {
                    viewRenderedMessagesDict[message.message.id] = message
                }
                entry.0.completeMessages(viewRenderedMessagesDict)
            }
            
            entry.1.putNext(MessageView(entry.0))
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
        
        let key = Table_AbsoluteMessageId.emptyKey()
        for id in ids {
            if let value = self.valueBox.get(Table_AbsoluteMessageId.id, key: Table_AbsoluteMessageId.key(id, key: key)) {
                result.append(Table_AbsoluteMessageId.get(id, value: value))
            }
        }
        
        return result
    }
    
    private func deleteMessagesWithIds(ids: [MessageId]) {
        for (peerId, messageIds) in messageIdsGroupedByPeerId(ids) {
            if let relatedViews = self.peerMessageViews[peerId] {
                for (view, pipe) in relatedViews.copyItems() {
                    let context = view.remove(Set<MessageId>(messageIds))
                    if !context.empty() {
                        view.complete(context, fetchEarlier: self.fetchMessagesRelative(peerId, earlier: true), fetchLater: self.fetchMessagesRelative(peerId, earlier: false))
                        self.deferMessageViewUpdate(view, pipe: pipe)
                    }
                }
            }
        }
        
        var touchedMediaIds = Set<MediaId>()
        
        let removeMediaMessageIdKey = Table_Media_MessageIds.emptyKey()
        for (peerId, messageIds) in messageIdsGroupedByPeerId(ids) {
            let messageKey = Table_Message.emptyKey()
            for id in messageIds {
                if let value = self.valueBox.get(Table_Message.id, key: Table_Message.key(id, key: messageKey)) {
                    if let message = Table_Message.get(value) {
                        for mediaId in message.mediaIds {
                            touchedMediaIds.insert(mediaId)
                            self.valueBox.remove(Table_Media_MessageIds.id, key: Table_Media_MessageIds.key(mediaId, messageId: message.id, key: removeMediaMessageIdKey))
                        }
                    }
                }
            }

            for id in messageIds {
                self.valueBox.remove(Table_Message.id, key: Table_Message.key(id, key: messageKey))
            }
            
            for mediaId in touchedMediaIds {
                var referenced = false
                self.valueBox.range(Table_Media_MessageIds.id, start: Table_Media_MessageIds.lowerBoundKey(mediaId), end: Table_Media_MessageIds.upperBoundKey(mediaId), keys: { key in
                    referenced = true
                    return false
                }, limit: 1)
                
                if !referenced {
                    //TODO write to cleanup queue
                    self.valueBox.remove(Table_Media.id, key: Table_Media.key(mediaId))
                }
            }
            
            let tail = self.fetchMessagesTail(peerId, count: 1)
            
            self.updatePeerEntry(peerId, message: tail.first, replace: true)
        }
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
                    let startTime = CFAbsoluteTimeGetCurrent()
                //#endif
                
                self.valueBox.begin()
                let result = f(Modifier(postbox: self))
                    //print("(Postbox modify took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms)")
                //#if DEBUG
                //startTime = CFAbsoluteTimeGetCurrent()
                //#endif
                self.valueBox.commit()
                
                //#if DEBUG
                    print("(Postbox commit took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms)")
                //#endif
                
                self.performDeferredUpdates()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    private func findAdjacentMessageIds(peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex) -> (MessageId.Id?, MessageId.Id?) {
        /*var minId: MessageId.Id?
        var maxId: MessageId.Id?
        
        let lowerBoundKey = ValueBoxKey(length: 8 + 4)
        lowerBoundKey.setInt64(0, value: peerId.toInt64())
        lowerBoundKey.setInt32(8, value: namespace)
        
        let upperBoundKey = ValueBoxKey(length: 8 + 4)
        upperBoundKey.setInt64(0, value: peerId.toInt64())
        upperBoundKey.setInt32(8, value: namespace)
        
        self.valueBox.range("peer_messages", start: lowerBoundKey, end: upperBoundKey.successor, keys: { key in
            
        }, limit: 1)
        
        for row in self.database.prepareCached("SELECT MIN(id), MAX(id) FROM peer_messages WHERE peerId = ? AND namespace = ?").run(peerId.toInt64(), Int64(namespace)) {
            minId = MessageId.Id(row[0] as! Int64)
            maxId = MessageId.Id(row[1] as! Int64)
        }
        
        if let minId = minId, maxId = maxId {
            var minTimestamp: Int32!
            var maxTimestamp: Int32!
            for row in self.database.prepareCached("SELECT id, timestamp FROM peer_messages WHERE peerId = ? AND namespace = ? AND id IN (?, ?)").run(peerId.toInt64(), Int64(namespace), Int64(minId), Int64(maxId)) {
                let id = Int32(row[0] as! Int64)
                let timestamp = Int32(row[1] as! Int64)
                if id == minId {
                    minTimestamp = timestamp
                } else {
                    maxTimestamp = timestamp
                }
            }
            
            let earlierMidStatement = self.database.prepareCached("SELECT id, timestamp FROM peer_messages WHERE peerId = ? AND namespace = ? AND id <= ? LIMIT 1")
            let laterMidStatement = self.database.prepareCached("SELECT id, timestamp FROM peer_messages WHERE peerId = ? AND namespace = ? AND id >= ? LIMIT 1")
            
            func lowerBound(timestamp: Int32) -> MessageId.Id? {
                var leftId = minId
                var leftTimestamp = minTimestamp
                var rightId = maxId
                var rightTimestamp = maxTimestamp
                
                while leftTimestamp <= timestamp && rightTimestamp >= timestamp {
                    let approximateMiddleId = leftId + (rightId - leftId) / 2
                    if approximateMiddleId == leftId {
                        return rightId
                    }
                    var middleId: MessageId.Id?
                    var middleTimestamp: Int32?
                    for row in earlierMidStatement.run(peerId.toInt64(), Int64(namespace), Int64(approximateMiddleId)) {
                        middleId = MessageId.Id(row[0] as! Int64)
                        middleTimestamp = Int32(row[1] as! Int64)
                        break
                    }
                    if middleId == leftId {
                        return rightId
                    }
                    
                    if let middleId = middleId, middleTimestamp = middleTimestamp {
                        if middleTimestamp >= timestamp {
                            rightId = middleId
                            rightTimestamp = middleTimestamp
                        } else {
                            leftId = middleId
                            leftTimestamp = middleTimestamp
                        }
                    } else {
                        return nil
                    }
                }
                
                return leftId
            }
            
            func upperBound(timestamp: Int32) -> MessageId.Id? {
                var leftId = minId
                var leftTimestamp = minTimestamp
                var rightId = maxId
                var rightTimestamp = maxTimestamp
                
                while leftTimestamp <= timestamp && rightTimestamp >= timestamp {
                    let approximateMiddleId = leftId + (rightId - leftId) / 2
                    if approximateMiddleId == leftId {
                        return leftId
                    }
                    var middleId: MessageId.Id?
                    var middleTimestamp: Int32?
                    for row in earlierMidStatement.run(peerId.toInt64(), Int64(namespace), Int64(approximateMiddleId)) {
                        middleId = MessageId.Id(row[0] as! Int64)
                        middleTimestamp = Int32(row[1] as! Int64)
                        break
                    }
                    if middleId == leftId {
                        return leftId
                    }
                    
                    if let middleId = middleId, middleTimestamp = middleTimestamp {
                        if middleTimestamp <= timestamp {
                            rightId = middleId
                            rightTimestamp = middleTimestamp
                        } else {
                            leftId = middleId
                            leftTimestamp = middleTimestamp
                        }
                    } else {
                        return nil
                    }
                }
                
                return rightTimestamp
            }
            
            if index.id.namespace < namespace {
                let left = upperBound(index.timestamp - 1)
                let right = lowerBound(index.timestamp)
                return (left, right)
            } else {
                let left = upperBound(index.timestamp)
                let right = lowerBound(index.timestamp + 1)
                return (left, right)
            }
        } else {
            return (nil, nil)
        }*/
        
        return (nil, nil)
    }
    
    private func fetchMessagesAround(peerId: PeerId, anchorId: MessageId, count: Int) -> ([RenderedMessage], [MessageId.Namespace : RenderedMessage], [MessageId.Namespace : RenderedMessage]) {
        var messages: [RenderedMessage] = []
        
        messages += self.fetchMessagesRelative(peerId, earlier: true)(namespace: anchorId.namespace, id: anchorId.id, count: count + 1)
        messages += self.fetchMessagesRelative(peerId, earlier: false)(namespace: anchorId.namespace, id: anchorId.id - 1, count: count + 1)
        
        messages.sortInPlace({ MessageIndex($0.message) < MessageIndex($1.message) })
        var i = messages.count - 1
        while i >= 1 {
            if messages[i].message.id == messages[i - 1].message.id {
                messages.removeAtIndex(i)
            }
            i--
        }
        
        if messages.count == 0 {
            return ([], [:], [:])
        } else {
            var index: MessageIndex!
            for message in messages {
                if message.message.id == anchorId {
                    index = MessageIndex(message.message)
                    break
                }
            }
            if index == nil {
                var closestId: MessageId.Id = messages[0].message.id.id
                var closestDistance = abs(closestId - anchorId.id)
                let closestTimestamp: Int32 = messages[0].message.timestamp
                for message in messages {
                    if abs(message.message.id.id - anchorId.id) < closestDistance {
                        closestId = message.message.id.id
                        closestDistance = abs(message.message.id.id - anchorId.id)
                    }
                }
                index = MessageIndex(id: MessageId(peerId: peerId, namespace: anchorId.namespace, id: closestId), timestamp: closestTimestamp)
            }
            
            for namespace in self.messageNamespaces {
                if namespace != anchorId.namespace {
                    let (left, right) = self.findAdjacentMessageIds(peerId, namespace: namespace, index: index)
                    if let left = left {
                        messages += self.fetchMessagesRelative(peerId, earlier: true)(namespace: namespace, id: left + 1, count: count + 1)
                    }
                    if let right = right {
                        messages += self.fetchMessagesRelative(peerId, earlier: false)(namespace: namespace, id: right - 1, count: count + 1)
                    }
                }
            }
            
            messages.sortInPlace({ MessageIndex($0.message) < MessageIndex($1.message) })
            var i = messages.count - 1
            while i >= 1 {
                if messages[i].message.id == messages[i - 1].message.id {
                    messages.removeAtIndex(i)
                }
                i--
            }
            
            var anchorIndex = messages.count / 2
            i = 0
            while i < messages.count {
                if messages[i].message.id == index.id {
                    anchorIndex = i
                    break
                }
                i++
            }
            
            var filteredMessages: [RenderedMessage] = []
            var earlier: [MessageId.Namespace : RenderedMessage] = [:]
            var later: [MessageId.Namespace : RenderedMessage] = [:]
            
            i = anchorIndex
            var j = anchorIndex - 1
            var leftIndex = j
            var rightIndex = i
            
            while i < messages.count || j >= 0 {
                if i < messages.count && filteredMessages.count < count {
                    filteredMessages.append(messages[i])
                    rightIndex = i
                }
                if j >= 0 && filteredMessages.count < count {
                    filteredMessages.append(messages[j])
                    leftIndex = j
                }
                
                i++
                j--
            }
            
            i = leftIndex - 1
            while i >= 0 {
                if earlier[messages[i].message.id.namespace] == nil {
                    earlier[messages[i].message.id.namespace] = messages[i]
                }
                i--
            }
            
            i = rightIndex + 1
            while i < messages.count {
                if later[messages[i].message.id.namespace] == nil {
                    later[messages[i].message.id.namespace] = messages[i]
                }
                i++
            }
            
            filteredMessages.sortInPlace({ MessageIndex($0.message) < MessageIndex($1.message) })
            
            return (filteredMessages, earlier, later)
        }
    }
    
    private func fetchMessagesRelative(peerId: PeerId, earlier: Bool)(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [RenderedMessage] {
        var messages: [Message] = []
        
        let lowerBound = Table_Message.lowerBoundKey(peerId, namespace: namespace)
        let upperBound = Table_Message.upperBoundKey(peerId, namespace: namespace)
        
        let bound: ValueBoxKey
        if let id = id {
            bound = Table_Message.key(MessageId(peerId: peerId, namespace: namespace, id: id))
        } else if earlier {
            bound = upperBound
        } else {
            bound = lowerBound
        }
        
        let values: (ValueBoxKey, ReadBuffer) -> Bool = { _, value in
            if let message = Table_Message.get(value) {
                messages.append(message)
            } else {
                print("can't parse message")
            }
            return true
        }
        
        if earlier {
            self.valueBox.range(Table_Message.id, start: bound, end: lowerBound, values: values, limit: count)
        } else {
            self.valueBox.range(Table_Message.id, start: bound, end: upperBound, values: values, limit: count)
        }
        
        return self.renderedMessages(messages)
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
            if let value = self.valueBox.get(Table_Message.id, key: Table_Message.key(entryIndex.messageIndex.id)) {
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
        
        entries.sortInPlace({ PeerViewEntryIndex($0) < PeerViewEntryIndex($1) })
        
        return entries
    }
    
    private func renderedMessages(messages: [Message]) -> [RenderedMessage] {
        if messages.count == 0 {
            return []
        }
        
        var peerIds = Set<PeerId>()
        var mediaIds = Set<MediaId>()
        
        for message in messages {
            for peerId in message.peerIds {
                peerIds.insert(peerId)
            }
            for mediaId in message.mediaIds {
                mediaIds.insert(mediaId)
            }
        }
        
        var arrayPeerIds: [PeerId] = []
        for id in peerIds {
            arrayPeerIds.append(id)
        }
        let peers = self.peersWithIds(arrayPeerIds)
        
        var arrayMediaIds: [MediaId] = []
        for id in mediaIds {
            arrayMediaIds.append(id)
        }
        let medias = self.mediaWithIds(arrayMediaIds)
        
        var result: [RenderedMessage] = []
        
        for message in messages {
            if message.peerIds.count == 0 && message.mediaIds.count == 0 {
                result.append(RenderedMessage(message: message, peers: [], media: []))
            } else {
                var messagePeers: [Peer] = []
                for id in message.peerIds {
                    if let peer = peers[id] {
                        messagePeers.append(peer)
                    }
                }
                
                var messageMedia: [Media] = []
                for id in message.mediaIds {
                    if let media = medias[id] {
                        messageMedia.append(media)
                    }
                }
                
                result.append(RenderedMessage(message: message, peers: messagePeers, media: messageMedia))
            }
        }
        
        return result
    }
    
    private func fetchMessagesTail(peerId: PeerId, count: Int) -> [RenderedMessage] {
        var messages: [RenderedMessage] = []
        
        for namespace in self.messageNamespaces {
            messages += self.fetchMessagesRelative(peerId, earlier: true)(namespace: namespace, id: nil, count: count)
        }
        
        messages.sortInPlace({ MessageIndex($0.message) < MessageIndex($1.message)})
        
        return messages
    }
    
    public func tailMessageViewForPeerId(peerId: PeerId, count: Int) -> Signal<MessageView, NoError> {
        return Signal { subscriber in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                let tail = self.fetchMessagesTail(peerId, count: count + 1)
                
                print("tailMessageViewForPeerId fetch: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                var messages: [RenderedMessage] = []
                var i = tail.count - 1
                while i >= 0 && i >= tail.count - count {
                    messages.insert(tail[i], atIndex: 0)
                    i--
                }
                
                var earlier: [MessageId.Namespace : RenderedMessage] = [:]
                
                for namespace in self.messageNamespaces {
                    var i = tail.count - count - 1
                    while i >= 0 {
                        if tail[i].message.id.namespace == namespace {
                            earlier[namespace] = tail[i]
                            break
                        }
                        i--
                    }
                }
                
                let mutableView = MutableMessageView(namespaces: self.messageNamespaces, count: count, earlier: earlier, messages: messages, later: [:])
                let record = (mutableView, Pipe<MessageView>())
                
                let index: Bag<(MutableMessageView, Pipe<MessageView>)>.Index
                if let bag = self.peerMessageViews[peerId] {
                    index = bag.add(record)
                } else {
                    let bag = Bag<(MutableMessageView, Pipe<MessageView>)>()
                    index = bag.add(record)
                    self.peerMessageViews[peerId] = bag
                }
                
                subscriber.putNext(MessageView(mutableView))
                
                let pipeDisposable = record.1.signal().start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            if let bag = strongSelf.peerMessageViews[peerId] {
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
    
    public func aroundMessageViewForPeerId(peerId: PeerId, id: MessageId, count: Int) -> Signal<MessageView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                let mutableView: MutableMessageView
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let around = self.fetchMessagesAround(peerId, anchorId: id, count: count)
                if around.0.count == 0 {
                    let tail = self.fetchMessagesTail(peerId, count: count + 1)
                    
                    var messages: [RenderedMessage] = []
                    var i = tail.count - 1
                    while i >= 0 && i >= tail.count - count {
                        messages.insert(tail[i], atIndex: 0)
                        i--
                    }
                    
                    var earlier: [MessageId.Namespace : RenderedMessage] = [:]
                    
                    for namespace in self.messageNamespaces {
                        var i = tail.count - count - 1
                        while i >= 0 {
                            if tail[i].message.id.namespace == namespace {
                                earlier[namespace] = tail[i]
                                break
                            }
                            i--
                        }
                    }
                    
                    mutableView = MutableMessageView(namespaces: self.messageNamespaces, count: count, earlier: earlier, messages: messages, later: [:])
                } else {
                    mutableView = MutableMessageView(namespaces: self.messageNamespaces, count: count, earlier: around.1, messages: around.0, later: around.2)
                }
                
                print("aroundMessageViewForPeerId fetch: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                let record = (mutableView, Pipe<MessageView>())
                
                let index: Bag<(MutableMessageView, Pipe<MessageView>)>.Index
                if let bag = self.peerMessageViews[peerId] {
                    index = bag.add(record)
                } else {
                    let bag = Bag<(MutableMessageView, Pipe<MessageView>)>()
                    index = bag.add(record)
                    self.peerMessageViews[peerId] = bag
                }
                
                subscriber.putNext(MessageView(mutableView))
                
                let pipeDisposable = record.1.signal().start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            if let bag = strongSelf.peerMessageViews[peerId] {
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
