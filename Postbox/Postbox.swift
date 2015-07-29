import Foundation

import SwiftSignalKit

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
    
    public func getState() -> State? {
        return self.postbox?.getState()
    }
    
    public func setState(state: State) {
        self.postbox?.setState(state)
    }
    
    public func updatePeers(peers: [Peer], update: (Peer, Peer) -> Peer) {
        self.postbox?.updatePeers(peers, update: update)
    }
}

public final class Postbox<State: PostboxState> {
    private let basePath: String
    private let messageNamespaces: [MessageId.Namespace]
    
    private let queue = SwiftSignalKit.Queue()
    private var database: Database!
    
    private var peerMessageViews: [PeerId : Bag<(MutableMessageView, Pipe<MessageView>)>] = [:]
    private var deferredMessageViewsToUpdate: [(MutableMessageView, Pipe<MessageView>)] = []
    private var peerViews: Bag<(MutablePeerView, Pipe<PeerView>)> = Bag()
    private var deferredPeerViewsToUpdate: [(MutablePeerView, Pipe<PeerView>)] = []
    
    private var statePipe: Pipe<State> = Pipe()
    
    public init(basePath: String, messageNamespaces: [MessageId.Namespace]) {
        self.basePath = basePath
        self.messageNamespaces = messageNamespaces
        self.openDatabase()
    }
    
    private func openDatabase() {
        self.queue.dispatch {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(self.basePath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
            }
            self.database = Database(self.basePath.stringByAppendingPathComponent("db"))
            
            let result = self.database.scalar("PRAGMA user_version") as! Int64
            let version: Int64 = 7
            if result == version {
                print("(Postbox schema version \(result))")
            } else {
                if result != 0 {
                    print("(Postbox migrating to version \(version))")
                    do {
                        try NSFileManager.defaultManager().removeItemAtPath(self.basePath)
                        try NSFileManager.defaultManager().createDirectoryAtPath(self.basePath, withIntermediateDirectories: true, attributes: nil)
                    } catch (_) {
                    }
                    
                    self.database = Database(self.basePath.stringByAppendingPathComponent("db"))
                }
                print("(Postbox creating schema)")
                self.createSchema()
                self.database.execute("PRAGMA user_version = \(version)")
            }
            
            self.database.adjustChunkSize()
            self.database.execute("PRAGMA page_size=1024")
            self.database.execute("PRAGMA cache_size=-2097152")
            self.database.execute("PRAGMA synchronous=NORMAL")
            self.database.execute("PRAGMA journal_mode=truncate")
            self.database.execute("PRAGMA temp_store=MEMORY")
            //self.database.execute("PRAGMA wal_autocheckpoint=32")
            //self.database.execute("PRAGMA journal_size_limit=1536")
            
            print("(Postbox initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
    }
    
    private func createSchema() {
        //state
        self.database.execute("CREATE TABLE state (id INTEGER PRIMARY KEY, data BLOB)")
        
        //keychain
        self.database.execute("CREATE TABLE keychain (key BLOB, data BLOB)")
        self.database.execute("CREATE INDEX keychain_key ON keychain (key)")
        
        //peer_messages
        self.database.execute("CREATE TABLE peer_messages (peerId INTEGER, namespace INTEGER, id INTEGER, data BLOB, associatedMediaIds BLOB, timestamp INTEGER, PRIMARY KEY(peerId, namespace, id))")
        
        //peer_media
        self.database.execute("CREATE TABLE peer_media (peerId INTEGER, mediaNamespace INTEGER, messageNamespace INTEGER, messageId INTEGER, PRIMARY KEY (peerId, mediaNamespace, messageNamespace, messageId))")
        self.database.execute("CREATE INDEX peer_media_peerId_messageNamespace_messageId ON peer_media (peerId, messageNamespace, messageId)")
        
        //media
        self.database.execute("CREATE TABLE media (namespace INTEGER, id INTEGER, data BLOB, associatedMessageIds BLOB, PRIMARY KEY (namespace, id))")
        
        //media_cleanup
        self.database.execute("CREATE TABLE media_cleanup (namespace INTEGER, id INTEGER, data BLOB, PRIMARY KEY(namespace, id))")
        
        //peer_entries
        self.database.execute("CREATE TABLE peer_entries (peerId INTEGER PRIMARY KEY, entry BLOB)")
        self.database.execute("CREATE INDEX peer_entries_entry on peer_entries (entry)")
        
        //peers
        self.database.execute("CREATE TABLE peers (id INTEGER PRIMARY KEY, data BLOB)")
    }
    
    private class func peerViewEntryIndexForBlob(blob: Blob) -> PeerViewEntryIndex {
        let buffer = ReadBuffer(memory: UnsafeMutablePointer(blob.data.bytes), length: blob.data.length, freeWhenDone: false)

        var timestamp: Int32 = 0
        buffer.read(&timestamp, offset: 0, length: 4)
        timestamp = Int32(bigEndian: timestamp)
        
        var namespace: Int32 = 0
        buffer.read(&namespace, offset: 0, length: 4)
        namespace = Int32(bigEndian: namespace)
        
        var id: Int32 = 0
        buffer.read(&id, offset: 0, length: 4)
        id = Int32(bigEndian: id)
        
        var peerIdRepresentation: Int64 = 0
        buffer.read(&peerIdRepresentation, offset: 0, length: 8)
        peerIdRepresentation = Int64(bigEndian: peerIdRepresentation)
        
        let peerId = PeerId(peerIdRepresentation)
        
        return PeerViewEntryIndex(peerId: peerId, messageIndex: MessageIndex(id: MessageId(peerId:peerId, namespace: namespace, id: id), timestamp: timestamp))
    }
    
    private class func blobForPeerViewEntryIndex(index: PeerViewEntryIndex) -> Blob {
        let buffer = WriteBuffer()
        
        var timestamp = Int32(bigEndian: index.messageIndex.timestamp)
        buffer.write(&timestamp, offset: 0, length: 4)
        
        var namespace = Int32(bigEndian: index.messageIndex.id.namespace)
        buffer.write(&namespace, offset: 0, length: 4)
        
        var id = Int32(bigEndian: index.messageIndex.id.id)
        buffer.write(&id, offset: 0, length: 4)
        
        var peerIdRepresentation = Int64(bigEndian: index.peerId.toInt64())
        buffer.write(&peerIdRepresentation, offset: 0, length: 8)
        
        return Blob(data: buffer.makeData())
    }
    
    private class func messageIdsGroupedByNamespace(ids: [MessageId]) -> [MessageId.Namespace : [MessageId]] {
        var grouped: [MessageId.Namespace : [MessageId]] = [:]
        
        for id in ids {
            if grouped[id.namespace] != nil {
                grouped[id.namespace]!.append(id)
            } else {
                grouped[id.namespace] = [id]
            }
        }
        
        return grouped
    }
    
    private class func mediaIdsGroupedByNamespaceFromMediaArray(mediaArray: [Media]) -> [MediaId.Namespace : [MediaId]] {
        var grouped: [MediaId.Namespace : [MediaId]] = [:]
        var seenMediaIds = Set<MediaId>()
        
        for media in mediaArray {
            if !seenMediaIds.contains(media.id) {
                seenMediaIds.insert(media.id)
                if grouped[media.id.namespace] != nil {
                    grouped[media.id.namespace]!.append(media.id)
                } else {
                    grouped[media.id.namespace] = [media.id]
                }
            }
        }
    
        return grouped
    }
    
    private class func mediaIdsGroupedByNamespaceFromSet(ids: Set<MediaId>) -> [MediaId.Namespace : [MediaId]] {
        var grouped: [MediaId.Namespace : [MediaId]] = [:]
        
        for id in ids {
            if let _ = grouped[id.namespace] {
                grouped[id.namespace]!.append(id)
            } else {
                grouped[id.namespace] = [id]
            }
        }
        
        return grouped
    }
    
    private class func mediaIdsGroupedByNamespaceFromDictionaryKeys<T>(dict: [MediaId : T]) -> [MediaId.Namespace : [MediaId]] {
        var grouped: [MediaId.Namespace : [MediaId]] = [:]
        
        for (id, _) in dict {
            if grouped[id.namespace] != nil {
                grouped[id.namespace]!.append(id)
            } else {
                grouped[id.namespace] = [id]
            }
        }
        
        return grouped
    }
    
    private class func messagesGroupedByPeerId(messages: [Message]) -> [(PeerId, [Message])] {
        var grouped: [(PeerId, [Message])] = []
        
        for message in messages {
            var i = 0
            let count = grouped.count
            var found = false
            while i < count {
                if grouped[i].0 == message.id.peerId {
                    grouped[i].1.append(message)
                    found = true
                    break
                }
                i++
            }
            if !found {
                grouped.append((message.id.peerId, [message]))
            }
        }
        
        return grouped
    }
    
    private class func messageIdsGroupedByPeerId(messageIds: [MessageId]) -> [PeerId : [MessageId]] {
        var grouped: [PeerId : [MessageId]] = [:]
        
        for id in messageIds {
            if grouped[id.peerId] != nil {
                grouped[id.peerId]!.append(id)
            } else {
                grouped[id.peerId] = [id]
            }
        }
        
        return grouped
    }
    
    private class func blobForMediaIds(ids: [MediaId]) -> Blob {
        let data = NSMutableData()
        var version: Int8 = 1
        data.appendBytes(&version, length: 1)

        var count = Int32(ids.count)
        data.appendBytes(&count, length:4)
        
        for id in ids {
            var mNamespace = id.namespace
            var mId = id.id
            data.appendBytes(&mNamespace, length: 4)
            data.appendBytes(&mId, length: 8)
        }
        
        return Blob(data: data)
    }
    
    private static func mediaIdsForBlob(blob: Blob) -> [MediaId] {
        var ids: [MediaId] = []
        
        var offset: Int = 0
        var version = 0
        blob.data.getBytes(&version, range: NSMakeRange(offset, 1))
        offset += 1
        
        if version == 1 {
            var count: Int32 = 0
            blob.data.getBytes(&count, range: NSMakeRange(offset, 4))
            offset += 4
            
            var i = 0
            while i < Int(count) {
                var mNamespace: Int32 = 0
                var mId: Int64 = 0
                blob.data.getBytes(&mNamespace, range: NSMakeRange(offset, 4))
                blob.data.getBytes(&mId, range: NSMakeRange(offset + 4, 8))
                ids.append(MediaId(namespace: mNamespace, id: mId))
                offset += 12
                i++
            }
        }
        
        return ids
    }
    
    private class func blobForMessageIds(ids: [MessageId]) -> Blob {
        let data = NSMutableData()
        var version: Int8 = 1
        data.appendBytes(&version, length: 1)
        
        var count = Int32(ids.count)
        data.appendBytes(&count, length:4)
        
        for id in ids {
            var mPeerNamespace = id.peerId.namespace
            var mPeerId = id.peerId.id
            var mNamespace = id.namespace
            var mId = id.id
            data.appendBytes(&mPeerNamespace, length: 4)
            data.appendBytes(&mPeerId, length: 4)
            data.appendBytes(&mNamespace, length: 4)
            data.appendBytes(&mId, length: 4)
        }
        
        return Blob(data: data)
    }
    
    private static func messageIdsForBlob(blob: Blob) -> [MessageId] {
        var ids: [MessageId] = []
        
        var offset: Int = 0
        var version = 0
        blob.data.getBytes(&version, range: NSMakeRange(offset, 1))
        offset += 1
        
        if version == 1 {
            var count: Int32 = 0
            blob.data.getBytes(&count, range: NSMakeRange(offset, 4))
            offset += 4
            
            var i = 0
            while i < Int(count) {
                var mPeerNamespace: Int32 = 0
                var mPeerId: Int32 = 0
                var mNamespace: Int32 = 0
                var mId: Int32 = 0
                blob.data.getBytes(&mPeerNamespace, range: NSMakeRange(offset, 4))
                blob.data.getBytes(&mPeerId, range: NSMakeRange(offset + 4, 4))
                blob.data.getBytes(&mNamespace, range: NSMakeRange(offset + 8, 4))
                blob.data.getBytes(&mId, range: NSMakeRange(offset + 12, 4))
                ids.append(MessageId(peerId: PeerId(namespace: mPeerNamespace, id: mPeerId), namespace: mNamespace, id: mId))
                offset += 16
                i++
            }
        }
        
        return ids
    }
    
    private var cachedState: State?
    
    private func setState(state: State) {
        self.queue.dispatch {
            self.cachedState = state
            
            let encoder = Encoder()
            encoder.encodeRootObject(state)
            let blob = Blob(data: encoder.makeData())
            self.database.prepareCached("INSERT OR REPLACE INTO state (id, data) VALUES (?, ?)").run(Int64(0), blob)
            
            self.statePipe.putNext(state)
        }
    }
    
    private func getState() -> State? {
        if let cachedState = self.cachedState {
            return cachedState
        } else {
            for row in self.database.prepareCached("SELECT data FROM state WHERE id = ?").run(Int64(0)) {
                let data = (row[0] as! Blob).data
                let buffer = ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false)
                let decoder = Decoder(buffer: buffer)
                if let state = decoder.decodeRootObject() as? State {
                    self.cachedState = state
                    return state
                }
                break
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
        //TODO: load keychain on first request then sync to disk
        
        let blob = Blob(data: key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
        for row in self.database.prepareCached("SELECT data FROM keychain WHERE key = ?").run(blob) {
            return (row[0] as! Blob).data
        }
        return nil
    }
    
    public func setKeychainEntryForKey(key: String, value: NSData) {
        let keyBlob = Blob(data: key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
        var rowId: Int64?
        for row in self.database.prepareCached("SELECT rowid FROM keychain WHERE key = ? LIMIT 1").run(keyBlob) {
            rowId = row[0] as? Int64
            break
        }
        if let rowId = rowId {
            self.database.prepareCached("UPDATE keychain SET data = ? WHERE rowid = ?").run(Blob(data: value), rowId)
        } else {
            self.database.prepareCached("INSERT INTO keychain (key, data) VALUES (?, ?)").run(keyBlob, Blob(data: value))
        }
    }
    
    public func removeKeychainEntryForKey(key: String) {
        self.queue.dispatch {
            let keyBlob = Blob(data: key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
            self.database.prepareCached("DELETE FROM keychain WHERE key = ?").run(keyBlob)
        }
    }
    
    private func addMessages(messages: [Message], medias: [Media]) {
        let messageInsertStatement = self.database.prepareCached("INSERT INTO peer_messages (peerId, namespace, id, data, associatedMediaIds, timestamp) VALUES (?, ?, ?, ?, ?, ?)")
        let peerMediaInsertStatement = self.database.prepareCached("INSERT INTO peer_media (peerId, mediaNamespace, messageNamespace, messageId) VALUES (?, ?, ?, ?)")
        let mediaInsertStatement = self.database.prepareCached("INSERT INTO media (namespace, id, data, associatedMessageIds) VALUES (?, ?, ?, ?)")
        let referencedMessageIdsStatement = self.database.prepareCached("SELECT associatedMessageIds FROM media WHERE namespace = ? AND id = ?")
        let updateReferencedMessageIdsStatement = self.database.prepareCached("UPDATE media SET associatedMessageIds = ? WHERE namespace = ? AND id = ?")
        
        let encoder = Encoder()
        
        var messageIdsByMediaId: [MediaId : [MessageId]] = [:]
        for (peerId, peerMessages) in Postbox.messagesGroupedByPeerId(messages) {
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
            
            let messageIdsByNamespace = Postbox.messageIdsGroupedByNamespace(messageIds)
            for (namespace, ids) in messageIdsByNamespace {
                var queryString = "SELECT id FROM peer_messages WHERE peerId = ? AND namespace = ? AND id IN ("
                var first = true
                for id in ids {
                    if first {
                        first = false
                    } else {
                        queryString += ","
                    }
                    queryString += "\(id.id)"
                }
                queryString += ")"
                
                let statement = self.database.prepare(queryString)
                for row in statement.run(peerId.toInt64(), Int64(namespace)) {
                    existingMessageIds.insert(MessageId(peerId: peerId, namespace: namespace, id: Int32(row[0] as! Int64)))
                }
            }
            
            for message in peerMessages {
                if existingMessageIds.contains(message.id) {
                    continue
                }
                existingMessageIds.insert(message.id)
                
                let index = MessageIndex(message)
                if maxMessage == nil || index > maxMessage!.0 {
                    maxMessage = (index, message)
                }
                
                encoder.reset()
                encoder.encodeRootObject(message)
                let messageBlob = Blob(data: encoder.makeData())
                
                let referencedMediaIdsMediaIdsBlob = Postbox.blobForMediaIds(message.mediaIds)
                for id in message.mediaIds {
                    if messageIdsByMediaId[id] != nil {
                        messageIdsByMediaId[id]!.append(message.id)
                    } else {
                        messageIdsByMediaId[id] = [message.id]
                    }
                }
                
                messageInsertStatement.run(peerId.toInt64(), Int64(message.id.namespace), Int64(message.id.id), messageBlob, referencedMediaIdsMediaIdsBlob, Int64(message.timestamp))
                
                for id in message.mediaIds {
                    peerMediaInsertStatement.run(peerId.toInt64(), Int64(id.namespace), Int64(message.id.namespace), Int64(message.id.id))
                }
            }
            
            if let relatedViews = self.peerMessageViews[peerId] {
                for record in relatedViews.copyItems() {
                    var updated = false
                    for message in peerMessages {
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
        
        for (namespace, ids) in Postbox.mediaIdsGroupedByNamespaceFromMediaArray(medias) {
            var queryString = "SELECT id FROM media WHERE namespace = ? AND id IN (";
            var first = true
            for id in ids {
                if first {
                    first = false
                } else {
                    queryString += ","
                }
                queryString += "\(id.id)"
            }
            queryString += ")"
            for row in self.database.prepare(queryString).run(Int64(namespace)) {
                existingMediaIds.insert(MediaId(namespace: namespace, id: row[0] as! Int64))
            }
        }
        
        var processedMediaIdsForMessageIds = Set<MediaId>()
        for media in medias {
            if existingMediaIds.contains(media.id) {
                continue
            }
            existingMediaIds.insert(media.id)
            
            encoder.reset()
            encoder.encodeRootObject(media)
            let mediaBlob = Blob(data: encoder.makeData())
            
            processedMediaIdsForMessageIds.insert(media.id)
            if let messageIds = messageIdsByMediaId[media.id] {
                let referencedMessageIdsBlob = Postbox.blobForMessageIds(messageIds)
                mediaInsertStatement.run(Int64(media.id.namespace), media.id.id, mediaBlob, referencedMessageIdsBlob)
            }
        }
        
        var updatedMessageIdsBlobByMediaId: [MediaId : Blob] = [:]
        for (mediaId, messageIds) in messageIdsByMediaId {
            if !processedMediaIdsForMessageIds.contains(mediaId) {
                for row in referencedMessageIdsStatement.run(Int64(mediaId.namespace), mediaId.id) {
                    var currentMessageIds = Postbox.messageIdsForBlob(row[0] as! Blob)
                    currentMessageIds += messageIds
                    updatedMessageIdsBlobByMediaId[mediaId] = Postbox.blobForMessageIds(currentMessageIds)
                }
            }
        }
        
        for (mediaId, messageIds) in updatedMessageIdsBlobByMediaId {
            updateReferencedMessageIdsStatement.run(messageIds, Int64(mediaId.namespace), mediaId.id)
        }
    }
    
    private func loadMessageIdsByMediaIdForPeerId(peerId: PeerId, idsByNamespace: [MessageId.Namespace : [MessageId]]) -> [MediaId : [MessageId]] {
        var grouped: [MediaId : [MessageId]] = [:]
        
        for (namespace, ids) in idsByNamespace {
            var messageIdByNamespaceAndIdQuery = "SELECT messageId FROM peer_media WHERE peerId = ? AND messageNamespace = ? AND messageId IN ("
            var first = true
            for id in ids {
                if first {
                    first = false
                } else {
                    messageIdByNamespaceAndIdQuery += ","
                }
                messageIdByNamespaceAndIdQuery += "\(id.id)"
            }
            messageIdByNamespaceAndIdQuery += ")"
            
            var messageIdsWithMedia: [MessageId] = []
            for row in self.database.prepare(messageIdByNamespaceAndIdQuery).run(peerId.toInt64(), Int64(namespace)) {
                messageIdsWithMedia.append(MessageId(peerId: peerId, namespace: namespace, id:Int32(row[0] as! Int64)))
            }
            
            var associatedMediaIdsQueryString = "SELECT id, associatedMediaIds FROM peer_messages WHERE peerId = ? AND namespace = ? AND id IN ("
            first = true
            for id in messageIdsWithMedia {
                if first {
                    first = false
                } else {
                    associatedMediaIdsQueryString += ","
                }
                associatedMediaIdsQueryString += "\(id.id)"
            }
            associatedMediaIdsQueryString += ")"
            
            for row in self.database.prepare(associatedMediaIdsQueryString).run(peerId.toInt64(), Int64(namespace)) {
                let id = MessageId(peerId: peerId, namespace: namespace, id: Int32(row[0] as! Int64))
                let referencedMediaIds = Postbox.mediaIdsForBlob(row[1] as! Blob)
                for mediaId in referencedMediaIds {
                    if grouped[mediaId] != nil {
                        grouped[mediaId]!.append(id)
                    } else {
                        grouped[mediaId] = [id]
                    }
                }
            }
        }
        
        return grouped
    }
    
    private func mediaWithIds(ids: [MediaId]) -> [MediaId : Media] {
        if ids.count == 0 {
            return [:]
        } else {
            let select = self.database.prepareCached("SELECT data FROM media WHERE namespace = ? AND id = ?")
            var result: [MediaId : Media] = [:]
            
            for id in ids {
                for row in select.run(Int64(id.namespace), id.id) {
                    let blob = row[0] as! Blob
                    if let media = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer<Void>(blob.data.bytes), length: blob.data.length, freeWhenDone: false)) as? Media {
                        result[media.id] = media
                    }
                    break
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
            for row in self.database.prepareCached("SELECT data FROM peers WHERE id = ?").run(peerId.toInt64()) {
                let data = (row[0] as! Blob).data
                let decoder = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false))
                if let peer = decoder.decodeRootObject() as? Peer {
                    cachedPeers[peer.id] = peer
                    return peer
                } else {
                    print("(PostBox: can't decode peer)")
                }
                
                break
            }
            
            return nil
        }
    }
    
    private func peersWithIds(ids: [PeerId]) -> [PeerId : Peer] {
        if ids.count == 0 {
            return [:]
        } else {
            var remainingIds: [PeerId] = []
            
            var peers: [PeerId : Peer] = [:]
            
            for id in ids {
                if let cachedPeer = cachedPeers[id] {
                    peers[id] = cachedPeer
                } else {
                    remainingIds.append(id)
                }
            }
            
            if remainingIds.count != 0 {
                let rows: Statement
                if ids.count == 1 {
                    rows = self.database.prepareCached("SELECT data FROM peers WHERE id = ?").run(ids[0].toInt64())
                } else if ids.count == 2 {
                    rows = self.database.prepareCached("SELECT data FROM peers WHERE id IN (?, ?)").run(ids[0].toInt64(), ids[1].toInt64())
                } else {
                    var query = "SELECT data FROM peers WHERE id IN ("
                    var first = true
                    for id in ids {
                        if first {
                            first = false
                            query += "\(id.toInt64())"
                        } else {
                            query += ",\(id.toInt64())"
                        }
                    }
                    query += ")"
                    rows = self.database.prepare(query).run()
                }
                
                for row in rows {
                    let blob = row[0] as! Blob
                    if let peer = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer<Void>(blob.data.bytes), length: blob.data.length, freeWhenDone: false)).decodeRootObject() as? Peer {
                        self.cachedPeers[peer.id] = peer
                        peers[peer.id] = peer
                    }
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
        while i < self.deferredPeerViewsToUpdate.count {
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
        for row in self.database.prepareCached("SELECT entry FROM peer_entries WHERE peerId = ?").run(peerId.toInt64()) {
            currentIndex = Postbox.peerViewEntryIndexForBlob(row[0] as! Blob)
            break
        }
        
        var updatedPeerMessage: RenderedMessage?
        
        if let currentIndex = currentIndex {
            if let message = message {
                let messageIndex = MessageIndex(message.message)
                if replace || currentIndex.messageIndex < messageIndex {
                    let updatedIndex = PeerViewEntryIndex(peerId: peerId, messageIndex: messageIndex)
                    updatedPeerMessage = message
                    let updatedBlob = Postbox.blobForPeerViewEntryIndex(updatedIndex)
                    self.database.prepareCached("UPDATE peer_entries SET entry = ? WHERE peerId = ?").run(updatedBlob, peerId.toInt64())
                }
            } else if replace {
                //TODO: remove?
            }
        } else if let message = message {
            updatedPeerMessage = message
            let updatedIndex = PeerViewEntryIndex(peerId: peerId, messageIndex: MessageIndex(message.message))
            let updatedBlob = Postbox.blobForPeerViewEntryIndex(updatedIndex)
            self.database.prepareCached("INSERT INTO peer_entries (peerId, entry) VALUES (?, ?)").run(peerId.toInt64(), updatedBlob)
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
    
    private func deleteMessagesWithIds(ids: [MessageId]) {
        for (peerId, messageIds) in Postbox.messageIdsGroupedByPeerId(ids) {
            let messageIdsByNamespace = Postbox.messageIdsGroupedByNamespace(messageIds)
            let messageIdsByMediaId = self.loadMessageIdsByMediaIdForPeerId(peerId, idsByNamespace: messageIdsByNamespace)
            
            for (peerId, messageIds) in Postbox.messageIdsGroupedByPeerId(ids) {
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
            
            for (namespace, messageIds) in messageIdsByNamespace {
                var queryString = "DELETE FROM peer_messages WHERE peerId = ? AND namespace = ? AND id IN ("
                var first = true
                for id in messageIds {
                    if first {
                        first = false
                    } else {
                        queryString += ","
                    }
                    queryString += "\(id.id)"
                }
                queryString += ")"
                self.database.prepare(queryString).run(peerId.toInt64(), Int64(namespace))
            }
            
            for (namespace, messageIds) in messageIdsByNamespace {
                var queryString = "DELETE FROM peer_media WHERE peerId = ? AND messageNamespace = ? AND messageId IN ("
                var first = true
                for id in messageIds {
                    if first {
                        first = false
                    } else {
                        queryString += ","
                    }
                    queryString += "\(id.id)"
                }
                queryString += ")"
                self.database.prepare(queryString).run(peerId.toInt64(), Int64(namespace))
            }
            
            let mediaIdsByNamespace = Postbox.mediaIdsGroupedByNamespaceFromDictionaryKeys(messageIdsByMediaId)
            var updatedMessageIdsByMediaId: [MediaId : [MessageId]] = [:]
            
            for (namespace, mediaIds) in mediaIdsByNamespace {
                var queryString = "SELECT id, data, associatedMessageIds FROM media WHERE namespace = ? AND id in ("
                var first = true
                for id in mediaIds {
                    if first {
                        first = false
                    } else {
                        queryString += ","
                    }
                    queryString += "\(id.id)"
                }
                queryString += ")"
                for row in self.database.prepare(queryString).run(Int64(namespace)) {
                    let mediaId = MediaId(namespace: namespace, id: row[0] as! Int64)
                    if let removedMessageIds = messageIdsByMediaId[mediaId] {
                        var messageIds = Postbox.messageIdsForBlob(row[2] as! Blob).filter {
                            !removedMessageIds.contains($0)
                        }
                        updatedMessageIdsByMediaId[mediaId] = messageIds
                        
                        if messageIds.count == 0 {
                            self.database.prepareCached("INSERT OR IGNORE INTO media_cleanup (namespace, id, data) VALUES (?, ?, ?)").run(Int64(namespace), mediaId.id, row[1] as! Blob)
                        }
                    }
                }
                
                for (mediaId, messageIds) in updatedMessageIdsByMediaId {
                    if messageIds.count == 0 {
                        self.database.prepareCached("DELETE FROM media WHERE namespace = ? AND id = ?").run(Int64(mediaId.namespace), mediaId.id)
                    } else {
                        self.database.prepareCached("UPDATE media SET associatedMessageIds = ? WHERE namespace = ? AND id = ?").run(Postbox.blobForMessageIds(messageIds), Int64(mediaId.namespace), mediaId.id)
                    }
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
            
            let updatePeer = self.database.prepareCached("UPDATE peers SET data = ? WHERE id = ?")
            let insertPeer = self.database.prepareCached("INSERT INTO peers (id, data) VALUES (?, ?)")
            let encoder = Encoder()
            
            var updatedPeers: [PeerId : Peer] = [:]
            
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
                    
                    if currentPeer != nil {
                        updatePeer.run(Blob(data: encoder.makeData()), finalPeer.id.toInt64())
                    } else {
                        insertPeer.run(finalPeer.id.toInt64(), Blob(data: encoder.makeData()))
                    }
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
                
                self.database.transaction()
                let result = f(Modifier(postbox: self))
                    //print("(Postbox modify took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms)")
                //#if DEBUG
                //startTime = CFAbsoluteTimeGetCurrent()
                //#endif
                self.database.commit()
                
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
        var minId: MessageId.Id?
        var maxId: MessageId.Id?
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
        }
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
        
        let sign = earlier ? "<" : ">"
        let order = earlier ? "DESC" : "ASC"
        let statement = self.database.prepareCached("SELECT data, associatedMediaIds FROM peer_messages WHERE peerId = ? AND namespace = ? AND id \(sign) ? ORDER BY id \(order) LIMIT ?")
        let bound: Int64
        if let id = id {
            bound = Int64(id)
        } else if earlier {
            bound = Int64(Int32.max)
        } else {
            bound = Int64(Int32.min)
        }
        
        for row in statement.run(Int64(peerId.toInt64()), Int64(namespace), bound, Int64(count)) {
            let data = (row[0] as! Blob).data
            let decoder = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false))
            if let message = decoder.decodeRootObject() as? Message {
                messages.append(message)
            } else {
                print("(PostBox: can't decode message)")
            }
        }
        
        return self.renderedMessages(messages)
    }
    
    private func fetchPeerEntryIndicesRelative(earlier: Bool)(index: PeerViewEntryIndex?, count: Int) -> [PeerViewEntryIndex] {
        var entries: [PeerViewEntryIndex] = []
        
        let rows: Statement
        
        if let index = index {
            let bound = Postbox.blobForPeerViewEntryIndex(index)
            let sign = earlier ? "<" : ">"
            let order = earlier ? "DESC" : "ASC"
            let statement = self.database.prepareCached("SELECT entry FROM peer_entries WHERE entry \(sign) ? ORDER BY entry \(order) LIMIT ?")
            rows = statement.run(bound, Int64(count))
        } else {
            let order = earlier ? "DESC" : "ASC"
            let statement = self.database.prepareCached("SELECT entry FROM peer_entries ORDER BY entry \(order) LIMIT ?")
            rows = statement.run(Int64(count))
        }
        
        for row in rows {
            entries.append(Postbox.peerViewEntryIndexForBlob(row[0] as! Blob))
        }
        
        return entries
    }
    
    private func messageForPeer(peerId: PeerId, id: MessageId) -> RenderedMessage? {
        for row in self.database.prepareCached("SELECT data, associatedMediaIds FROM peer_messages WHERE peerId = ? AND namespace = ? AND id = ?").run(peerId.toInt64(), Int64(id.namespace), Int64(id.id)) {
            let data = (row[0] as! Blob).data
            let decoder = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false))
            if let message = decoder.decodeRootObject() as? Message {
                return self.renderedMessages([message]).first
            } else {
                print("(PostBox: can't decode message)")
            }
            break
        }
        
        return nil
    }
    
    private func fetchPeerEntriesRelative(earlier: Bool)(index: PeerViewEntryIndex?, count: Int) -> [PeerViewEntry] {
        var entries: [PeerViewEntry] = []
        var peers: [PeerId : Peer] = [:]
        for entryIndex in self.fetchPeerEntryIndicesRelative(earlier)(index: index, count: count) {
            var peer: Peer?
            
            if let cachedPeer = peers[entryIndex.peerId] {
                peer = cachedPeer
            } else {
                if let fetchedPeer = self.peerWithId(entryIndex.peerId) {
                    peer = fetchedPeer
                    peers[fetchedPeer.id] = fetchedPeer
                }
            }
            
            if let message = self.messageForPeer(entryIndex.peerId, id: entryIndex.messageIndex.id) {
                let entry: PeerViewEntry
                if let peer = peer {
                    entry = PeerViewEntry(peer: peer, message: message)
                } else {
                    entry = PeerViewEntry(peerId: entryIndex.peerId, message: message)
                }
                
                entries.append(entry)
            } else {
                print("(PostBox: missing message for peer entry)")
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
                self.fetchPeerEntriesRelative(true)(index: nil, count: count + 1)
                
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
    
    func printMessages(messages: [Message]) {
        var string = ""
        string += "["
        var first = true
        for message in messages {
            if first {
                first = false
            } else {
                string += ", "
            }
            string += "\(message.id.namespace): \(message.id.id)—\(message.timestamp)"
        }
        string += "]"
        print(string)
    }
    
    public func _dumpTables() {
        print("\n------------")
        print("peer_messages")
        print("-------------")
        for row in self.database.prepare("SELECT peerId, namespace, id, timestamp, associatedMediaIds FROM peer_messages").run() {
            print("peer(\(PeerId(row[0] as! Int64))) id(\(MessageId(peerId: PeerId(row[0] as! Int64), namespace: Int32(row[1] as! Int64), id:(Int32(row[2] as! Int64))))) timestamp(\(row[3] as! Int64)) media(\(Postbox.mediaIdsForBlob(row[4] as! Blob)))")
        }
        
        print("\n---------")
        print("peer_media")
        print("----------")
        for row in self.database.prepare("SELECT peerId, mediaNamespace, messageNamespace, messageId FROM peer_media").run() {
            print("peer(\(PeerId(row[0] as! Int64))) namespace(\(row[1] as! Int64)) id(\(MessageId(peerId: PeerId(row[0] as! Int64), namespace: Int32(row[2] as! Int64), id:Int32(row[3] as! Int64))))")
        }
        
        print("\n----")
        print("media")
        print("-----")
        for row in self.database.prepare("SELECT namespace, id, associatedMessageIds FROM media").run() {
            print("id(\(MediaId(namespace: Int32(row[0] as! Int64), id:(row[1] as! Int64)))) messages(\(Postbox.messageIdsForBlob(row[2] as! Blob)))")
        }
        
        print("\n------------")
        print("media_cleanup")
        print("-------------")
        for row in self.database.prepare("SELECT namespace, id FROM media_cleanup").run() {
            print("id(\(MediaId(namespace: Int32(row[0] as! Int64), id:(row[1] as! Int64))))")
        }
    }
    
    public func _sync() {
        self.queue.sync {
        }
    }
}
