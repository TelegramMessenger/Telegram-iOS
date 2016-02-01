import Foundation
import SwiftSignalKit
import sqlcipher

public final class Modifier {
    private weak var postbox: Postbox?
    
    private init(postbox: Postbox) {
        self.postbox = postbox
    }
    
    public func addMessages(messages: [StoreMessage], location: AddMessagesLocation) {
        self.postbox?.addMessages(messages, location: location)
    }
    
    public func initializeHole(peerId: PeerId, namespace: MessageId.Namespace) {
        self.postbox?.addHole(MessageId(peerId: peerId, namespace: namespace, id: 1))
    }
    
    public func fillHole(hole: MessageHistoryHole, fillType: HoleFillType, messages: [StoreMessage]) {
        self.postbox?.fillHole(hole, fillType: fillType, messages: messages)
    }
    
    public func deleteMessages(messageIds: [MessageId]) {
        self.postbox?.deleteMessages(messageIds)
    }
    
    public func deleteMessagesWithGlobalIds(ids: [Int32]) {
        if let postbox = self.postbox {
            let messageIds = postbox.messageIdsForGlobalIds(ids)
            postbox.deleteMessages(messageIds)
        }
    }
    
    public func getState() -> Coding? {
        return self.postbox?.getState()
    }
    
    public func setState(state: Coding) {
        self.postbox?.setState(state)
    }
    
    public func updatePeers(peers: [Peer], update: (Peer, Peer) -> Peer?) {
        self.postbox?.updatePeers(peers, update: update)
    }
    
    public func knownPeerIds(ids: Set<PeerId>) -> Set<PeerId> {
        return self.postbox?.knownPeerIds(ids) ?? Set()
    }
}

public final class Postbox {
    private let basePath: String
    private let globalMessageIdsNamespace: MessageId.Namespace
    
    private let queue = Queue(name: "org.telegram.postbox.Postbox")
    private var valueBox: ValueBox!
    
    private var viewTracker: ViewTracker!
    
    private var peerPipes: [PeerId: Pipe<Peer>] = [:]
    
    private var currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
    private var currentFilledHolesByPeerId = Set<PeerId>()
    private var currentUpdatedPeers: [PeerId: Peer] = [:]
    
    private var statePipe: Pipe<Coding> = Pipe()
    
    private let fetchMessageHistoryHoleImpl = Promise<MessageHistoryHole -> Signal<Void, NoError>>()
    public func setFetchMessageHistoryHole(fetch: MessageHistoryHole -> Signal<Void, NoError>) {
        self.fetchMessageHistoryHoleImpl.set(single(fetch, NoError.self))
    }
    
    public let mediaBox: MediaBox
    
    var metadataTable: MetadataTable!
    var keychainTable: KeychainTable!
    var peerTable: PeerTable!
    var globalMessageIdsTable: GlobalMessageIdsTable!
    var messageHistoryIndexTable: MessageHistoryIndexTable!
    var messageHistoryTable: MessageHistoryTable!
    var mediaTable: MessageMediaTable!
    var mediaCleanupTable: MediaCleanupTable!
    var chatListIndexTable: ChatListIndexTable!
    var chatListTable: ChatListTable!
    
    public init(basePath: String, globalMessageIdsNamespace: MessageId.Namespace) {
        self.basePath = basePath
        self.globalMessageIdsNamespace = globalMessageIdsNamespace
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
            self.metadataTable = MetadataTable(valueBox: self.valueBox, tableId: 0)
            
            let userVersion: Int32? = self.metadataTable.userVersion()
            let currentUserVersion: Int32 = 5
            
            if userVersion != currentUserVersion {
                self.valueBox.drop()
                self.metadataTable.setUserVersion(currentUserVersion)
            }
            
            self.keychainTable = KeychainTable(valueBox: self.valueBox, tableId: 1)
            self.peerTable = PeerTable(valueBox: self.valueBox, tableId: 2)
            self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox, tableId: 3, namespace: self.globalMessageIdsNamespace)
            self.messageHistoryIndexTable = MessageHistoryIndexTable(valueBox: self.valueBox, tableId: 4, globalMessageIdsTable: self.globalMessageIdsTable)
            self.mediaCleanupTable = MediaCleanupTable(valueBox: self.valueBox, tableId: 5)
            self.mediaTable = MessageMediaTable(valueBox: self.valueBox, tableId: 6, mediaCleanupTable: self.mediaCleanupTable)
            self.messageHistoryTable = MessageHistoryTable(valueBox: self.valueBox, tableId: 7, messageHistoryIndexTable: self.messageHistoryIndexTable, messageMediaTable: self.mediaTable)
            self.chatListIndexTable = ChatListIndexTable(valueBox: self.valueBox, tableId: 8)
            self.chatListTable = ChatListTable(valueBox: self.valueBox, tableId: 9, indexTable: self.chatListIndexTable)
            
            self.viewTracker = ViewTracker(queue: self.queue, fetchEarlierHistoryEntries: self.fetchEarlierHistoryEntries, fetchLaterHistoryEntries: self.fetchLaterHistoryEntries, fetchEarlierChatEntries: self.fetchEarlierChatEntries, fetchLaterChatEntries: self.fetchLaterChatEntries, renderMessage: self.renderIntermediateMessage, fetchMessageHistoryHole: self.fetchMessageHistoryHoleWrapper)
            
            print("(Postbox initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
    }
    
    private var cachedState: Coding?
    
    private func setState(state: Coding) {
        self.queue.dispatch {
            self.cachedState = state
            
            self.metadataTable.setState(state)
            
            self.statePipe.putNext(state)
        }
    }
    
    private func getState() -> Coding? {
        if let cachedState = self.cachedState {
            return cachedState
        } else {
            if let state = self.metadataTable.state() {
                self.cachedState = state
                return state
            }
            
            return nil
        }
    }
    
    public func state() -> Signal<Coding?, NoError> {
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
        return self.keychainTable.get(key)
    }
    
    public func setKeychainEntryForKey(key: String, value: NSData) {
        self.keychainTable.set(key, value: value)
    }
    
    public func removeKeychainEntryForKey(key: String) {
        self.keychainTable.remove(key)
    }
    
    private func addMessages(messages: [StoreMessage], location: AddMessagesLocation) {
        self.messageHistoryTable.addMessages(messages, location: location, operationsByPeerId: &self.currentOperationsByPeerId)
    }
    
    private func addHole(id: MessageId) {
        self.messageHistoryTable.addHoles([id], operationsByPeerId: &self.currentOperationsByPeerId)
    }
    
    private func fillHole(hole: MessageHistoryHole, fillType: HoleFillType, messages: [StoreMessage]) {
        self.messageHistoryTable.fillHole(hole.id, fillType: fillType, messages: messages, operationsByPeerId: &self.currentOperationsByPeerId)
        self.currentFilledHolesByPeerId.insert(hole.id.peerId)
    }
    
    private func deleteMessages(messageIds: [MessageId]) {
        self.messageHistoryTable.removeMessages(messageIds, operationsByPeerId: &self.currentOperationsByPeerId)
    }
    
    private func knownPeerIds(ids: Set<PeerId>) -> Set<PeerId> {
        var result = Set<PeerId>()
        
        for id in ids {
            if let _ = self.peerTable.get(id) {
                result.insert(id)
            }
        }
        
        return result
    }
    
    private func fetchEarlierHistoryEntries(peerId: PeerId, index: MessageIndex?, count: Int) -> [MutableMessageHistoryEntry] {
        let intermediateEntries = self.messageHistoryTable.earlierEntries(peerId, index: index, count: count)
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message))
                case let .Hole(index):
                    entries.append(.HoleEntry(index))
            }
        }
        return entries
    }
    
    private func fetchAroundHistoryEntries(index: MessageIndex, count: Int) -> [MutableMessageHistoryEntry] {
        let intermediateEntries = self.messageHistoryTable.entriesAround(index, count: count)
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
            case let .Message(message):
                entries.append(.IntermediateMessageEntry(message))
            case let .Hole(index):
                entries.append(.HoleEntry(index))
            }
        }
        return entries
    }
    
    private func fetchLaterHistoryEntries(peerId: PeerId, index: MessageIndex?, count: Int) -> [MutableMessageHistoryEntry] {
        let intermediateEntries = self.messageHistoryTable.laterEntries(peerId, index: index, count: count)
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
            case let .Message(message):
                entries.append(.IntermediateMessageEntry(message))
            case let .Hole(index):
                entries.append(.HoleEntry(index))
            }
        }
        return entries
    }
    
    private func fetchEarlierChatEntries(index: MessageIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.earlierEntries(index, messageHistoryTable: self.messageHistoryTable, count: count)
        var entries: [MutableChatListEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message))
                case let .Nothing(index):
                    entries.append(.Nothing(index))
            }
        }
        return entries
    }
    
    private func fetchLaterChatEntries(index: MessageIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.laterEntries(index, messageHistoryTable: self.messageHistoryTable, count: count)
        var entries: [MutableChatListEntry] = []
        for entry in intermediateEntries {
            switch entry {
            case let .Message(message):
                entries.append(.IntermediateMessageEntry(message))
            case let .Nothing(index):
                entries.append(.Nothing(index))
            }
        }
        return entries
    }
    
    private func renderIntermediateMessage(message: IntermediateMessage) -> Message {
        return self.messageHistoryTable.renderMessage(message, peerTable: self.peerTable)
    }
    
    private func fetchMessageHistoryHoleWrapper(hole: MessageHistoryHole) -> Disposable {
        return (self.fetchMessageHistoryHoleImpl.get() |> mapToSignal { fetch in
            return fetch(hole)
        }).start()
    }
    
    private func beforeCommit() {
        var chatListOperations: [ChatListOperation] = []
        self.chatListTable.replay(self.currentOperationsByPeerId, messageHistoryTable: self.messageHistoryTable, operations: &chatListOperations)
        
        self.viewTracker.updateViews(currentOperationsByPeerId: self.currentOperationsByPeerId, peerIdsWithFilledHoles: self.currentFilledHolesByPeerId, chatListOperations: chatListOperations, currentUpdatedPeers: self.currentUpdatedPeers)
        
        self.currentOperationsByPeerId.removeAll()
        self.currentFilledHolesByPeerId.removeAll()
        self.currentUpdatedPeers.removeAll()
    }
    
    private func messageIdsForGlobalIds(ids: [Int32]) -> [MessageId] {
        var result: [MessageId] = []
        for globalId in ids {
            if let id = self.globalMessageIdsTable.get(globalId) {
                result.append(id)
            }
        }
        return result
    }
    
    private func updatePeers(peers: [Peer], update: (Peer, Peer) -> Peer?) {
        for peer in peers {
            if let currentPeer = self.peerTable.get(peer.id) {
                if let updatedPeer = update(currentPeer, peer) {
                    self.peerTable.set(updatedPeer)
                    self.currentUpdatedPeers[updatedPeer.id] = updatedPeer
                }
            } else {
                self.peerTable.set(peer)
            }
        }
    }
    
    public func modify<T>(f: Modifier -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.dispatch {
                //self.valueBox.beginStats()
                self.valueBox.begin()
                let result = f(Modifier(postbox: self))
                self.beforeCommit()
                self.valueBox.commit()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    public func tailMessageHistoryViewForPeerId(peerId: PeerId, count: Int) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return self.aroundMessageHistoryViewForPeerId(peerId, index: MessageIndex.upperBound(peerId), count: count)
    }
    
    public func aroundMessageHistoryViewForPeerId(peerId: PeerId, index: MessageIndex, count: Int) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                let list = self.fetchAroundHistoryEntries(index, count: count + 2)
                
                var entries: [MutableMessageHistoryEntry] = []
                var earlier: MutableMessageHistoryEntry?
                var later: MutableMessageHistoryEntry?
                
                if list.count >= count + 2 {
                    earlier = list[0]
                    for i in 1 ..< count + 1 {
                        entries.append(list[i])
                    }
                    later = list[count + 1]
                } else if list.count >= count + 1 {
                    for i in 0 ..< count {
                        entries.append(list[i])
                    }
                    later = list[count]
                } else {
                    entries = list
                }
                
                let mutableView = MutableMessageHistoryView(earlier: earlier, entries: entries, later: later, count: count)
                mutableView.render(self.renderIntermediateMessage)
                subscriber.putNext((MessageHistoryView(mutableView), .Generic))
                
                let (index, signal) = self.viewTracker.addMessageHistoryView(peerId, view: mutableView)
                    
                let pipeDisposable = signal.start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            strongSelf.viewTracker.removeMessageHistoryView(peerId, index: index)
                        }
                    }
                    return
                })
            }
            
            return disposable
        }
    }
    
    public func tailChatListView(count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                let tail = self.fetchEarlierChatEntries(nil, count: count + 1).reverse()
                var entries: [MutableChatListEntry] = []
                var earlier: MutableChatListEntry?
                
                var i = 0
                for entry in tail {
                    if i < count {
                        entries.append(entry)
                    } else if i < count + 1 {
                        earlier = entry
                    } else {
                        break
                    }
                    i++
                }
                
                let mutableView = MutableChatListView(earlier: earlier, entries: entries, later: nil, count: count)
                mutableView.render(self.renderIntermediateMessage)
                subscriber.putNext((ChatListView(mutableView), .Generic))
                
                let (index, signal) = self.viewTracker.addChatListView(mutableView)
                
                let pipeDisposable = signal.start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            strongSelf.viewTracker.removeChatListView(index)
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
                if let peer: Peer = self.peerTable.get(id) {
                    subscriber.putNext(peer)
                }
            }
            return disposable
        }
    }
}
