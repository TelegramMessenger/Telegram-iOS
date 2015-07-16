import Foundation

import SwiftSignalKit

public protocol PostboxState: Coding {
    
}

public class Modifier<State: PostboxState> {
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
    
    public func setState(state: State) {
        self.postbox?.setState(state)
    }
}

public final class Postbox<State: PostboxState> {
    private let basePath: String
    private let messageNamespaces: [MessageId.Namespace]
    
    private let queue = SwiftSignalKit.Queue()
    private var database: Database!
    
    private var peerMessageViews: [PeerId : Bag<(MutableMessageView, Pipe<MessageView>)>] = [:]
    private var peerViews: Bag<(MutablePeerView, Pipe<PeerView>)> = Bag()
    private var statePipe: Pipe<State> = Pipe()
    
    public init(basePath: String, messageNamespaces: [MessageId.Namespace]) {
        self.basePath = basePath
        self.messageNamespaces = messageNamespaces
        self.openDatabase()
    }
    
    private func openDatabase() {
        NSFileManager.defaultManager().createDirectoryAtPath(basePath, withIntermediateDirectories: true, attributes: nil, error: nil)
        self.database = Database(basePath.stringByAppendingPathComponent("db"))
        
        self.queue.dispatch {
            let result = self.database.userVersion
            if result == 1 {
                println("(Postbox schema version \(result))")
            } else {
                println("(Postbox creating schema)")
                self.createSchema()
            }
        }
    }
    
    private func createSchema() {
        //state
        self.database.execute("CREATE TABLE state (id INTEGER, data BLOB)")
        
        //keychain
        self.database.execute("CREATE TABLE keychain (key BLOB, data BLOB)")
        
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
        self.database.execute("CREATE TABLE peers (peerId INTEGER PRIMARY KEY, data BLOB)")
    }
    
    private class func peerViewEntryIndexForBlob(blob: Blob) -> PeerViewEntryIndex {
        let buffer = ReadBuffer(memory: UnsafeMutablePointer(blob.data.bytes), length: blob.data.length, freeWhenDone: false)
        var offset: Int = 0
        
        var timestamp: Int32 = 0
        buffer.read(&timestamp, offset: offset, length: 4)
        timestamp = Int32(bigEndian: timestamp)
        offset += 4
        
        var namespace: Int32 = 0
        buffer.read(&namespace, offset: offset, length: 4)
        namespace = Int32(bigEndian: namespace)
        offset += 4
        
        var id: Int32 = 0
        buffer.read(&id, offset: offset, length: 4)
        id = Int32(bigEndian: id)
        offset += 4
        
        var peerIdRepresentation: Int64 = 0
        buffer.read(&peerIdRepresentation, offset: offset, length: 8)
        peerIdRepresentation = Int64(bigEndian: peerIdRepresentation)
        offset += 8
        
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
            if var groupedIds = grouped[id.namespace] {
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
    
    private class func messagesGroupedByPeerId(messages: [Message]) -> [PeerId : [Message]] {
        var grouped: [PeerId : [Message]] = [:]
        
        for message in messages {
            if grouped[message.id.peerId] != nil {
                grouped[message.id.peerId]!.append(message)
            } else {
                grouped[message.id.peerId] = [message]
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
    
    private func setState(state: State) {
        self.queue.dispatch {
            let encoder = Encoder()
            encoder.encodeRootObject(state)
            let blob = Blob(data: encoder.makeData())
            self.database.prepareCached("INSERT OR REPLACE INTO state (id, data) VALUES (?, ?)").run(Int64(0), blob)
            
            self.statePipe.putNext(state)
        }
    }
    
    public func state() -> Signal<State?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.dispatch {
                var found = false
                for row in self.database.prepareCached("SELECT data FROM state WHERE id = ?").run(Int64(0)) {
                    let data = (row[0] as! Blob).data
                    let buffer = ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false)
                    let decoder = Decoder(buffer: buffer)
                    if let state = decoder.decodeRootObject() as? State {
                        found = true
                        subscriber.putNext(state)
                    }
                    break
                }
                if !found {
                    subscriber.putNext(nil)
                }
                disposable.set(self.statePipe.signal().start(next: { next in
                    subscriber.putNext(next)
                }))
            }
            return disposable
        }
    }
    
    public func keychainEntryForKey(key: String) -> NSData? {
        //TODO: load keychain on first request then sync to disk
        
        var result: NSData?
        self.queue.sync {
            let blob = Blob(data: key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
            var buffer: ReadBuffer?
            for row in self.database.prepareCached("SELECT data FROM keychain WHERE key = ?").run(blob) {
                result = (row[0] as! Blob).data
                break
            }
        }
        return result
    }
    
    public func setKeychainEntryForKey(key: String, value: NSData) {
        self.queue.dispatch {
            let keyBlob = Blob(data: key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
            self.database.prepareCached("INSERT OR REPLACE INTO keychain (key, data) VALUES (?, ?)").run(keyBlob, Blob(data: value))
        }
    }
    
    public func removeKeychainEntryForKey(key: String) {
        self.queue.dispatch {
            let keyBlob = Blob(data: key.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
            self.database.prepareCached("DELETE FROM keychain WHERE key = ?").run(keyBlob)
        }
    }
    
    private func addMessages(messages: [Message], medias: [Media]) {
        let messageInsertStatement = self.database.prepare("INSERT INTO peer_messages (peerId, namespace, id, data, associatedMediaIds, timestamp) VALUES (?, ?, ?, ?, ?, ?)")
        let peerMediaInsertStatement = self.database.prepare("INSERT INTO peer_media (peerId, mediaNamespace, messageNamespace, messageId) VALUES (?, ?, ?, ?)")
        let mediaInsertStatement = self.database.prepare("INSERT INTO media (namespace, id, data, associatedMessageIds) VALUES (?, ?, ?, ?)")
        let referencedMessageIdsStatement = self.database.prepare("SELECT associatedMessageIds FROM media WHERE namespace = ? AND id = ?")
        let updateReferencedMessageIdsStatement = self.database.prepare("UPDATE media SET associatedMessageIds = ? WHERE namespace = ? AND id = ?")
        
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
            
            var relatedViews = self.peerMessageViews[peerId] ?? Bag()
            
            for message in peerMessages {
                if existingMessageIds.contains(message.id) {
                    continue
                }
                existingMessageIds.insert(message.id)
                
                for record in relatedViews.copyItems() {
                    record.0.add(message)
                }
                
                let index = MessageIndex(message)
                if maxMessage == nil || index > maxMessage!.0 {
                    maxMessage = (index, message)
                }
                
                encoder.reset()
                encoder.encodeRootObject(message)
                let messageBlob = Blob(data: encoder.makeData())
                
                let referencedMediaIdsMediaIdsBlob = Postbox.blobForMediaIds(message.referencedMediaIds)
                for id in message.referencedMediaIds {
                    if messageIdsByMediaId[id] != nil {
                        messageIdsByMediaId[id]!.append(message.id)
                    } else {
                        messageIdsByMediaId[id] = [message.id]
                    }
                }
                
                messageInsertStatement.run(peerId.toInt64(), Int64(message.id.namespace), Int64(message.id.id), messageBlob, referencedMediaIdsMediaIdsBlob, Int64(message.timestamp))
                
                for id in message.referencedMediaIds {
                    peerMediaInsertStatement.run(peerId.toInt64(), Int64(id.namespace), Int64(message.id.namespace), Int64(message.id.id))
                }
            }
            
            for record in relatedViews.copyItems() {
                record.1.putNext(MessageView(record.0))
            }
            
            if let maxMessage = maxMessage {
                self.updatePeerEntry(peerId, message: maxMessage.1)
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
    
    private func peerWithId(peerId: PeerId) -> Peer? {
        for row in self.database.prepare("SELECT data FROM peers WHERE peerId = ?").run(peerId.toInt64()) {
            let data = (row[0] as! Blob).data
            let decoder = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false))
            if let peer = decoder.decodeRootObject() as? Peer {
                return peer
            } else {
                println("(PostBox: can't decode peer)")
            }
            
            break
        }
        
        return nil
    }
    
    private func updatePeerEntry(peerId: PeerId, message: Message?, replace: Bool = false) {
        var currentIndex: PeerViewEntryIndex?
        for row in self.database.prepare("SELECT entry FROM peer_entries WHERE peerId = ?").run(peerId.toInt64()) {
            currentIndex = Postbox.peerViewEntryIndexForBlob(row[0] as! Blob)
            break
        }
        
        var updatedPeerMessage: Message?
        
        if let currentIndex = currentIndex {
            if let message = message {
                let messageIndex = MessageIndex(message)
                if replace || currentIndex.messageIndex < messageIndex {
                    let updatedIndex = PeerViewEntryIndex(peerId: peerId, messageIndex: messageIndex)
                    updatedPeerMessage = message
                    let updatedBlob = Postbox.blobForPeerViewEntryIndex(updatedIndex)
                    self.database.prepare("UPDATE peer_entries SET entry = ? WHERE peerId = ?").run(updatedBlob, peerId.toInt64())
                }
            } else if replace {
                //TODO: remove?
            }
        } else if let message = message {
            updatedPeerMessage = message
            let updatedIndex = PeerViewEntryIndex(peerId: peerId, messageIndex: MessageIndex(message))
            let updatedBlob = Postbox.blobForPeerViewEntryIndex(updatedIndex)
            self.database.prepare("INSERT INTO peer_entries (peerId, entry) VALUES (?, ?)").run(peerId.toInt64(), updatedBlob)
        }
        
        if let updatedPeerMessage = updatedPeerMessage {
            var peer: Peer?
            for (view, sink) in self.peerViews.copyItems() {
                
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
                
                sink.putNext(PeerView(view))
            }
        }
    }
    
    private func deleteMessagesWithIds(ids: [MessageId]) {
        for (peerId, messageIds) in Postbox.messageIdsGroupedByPeerId(ids) {
            let messageIdsByNamespace = Postbox.messageIdsGroupedByNamespace(messageIds)
            let messageIdsByMediaId = self.loadMessageIdsByMediaIdForPeerId(peerId, idsByNamespace: messageIdsByNamespace)
            
            for (peerId, messageIds) in Postbox.messageIdsGroupedByPeerId(ids) {
                if let relatedViews = self.peerMessageViews[peerId] {
                    for (view, sink) in relatedViews.copyItems() {
                        let context = view.remove(Set<MessageId>(messageIds))
                        if !context.empty() {
                            view.complete(context, fetchEarlier: self.fetchMessagesRelative(peerId, earlier: true), fetchLater: self.fetchMessagesRelative(peerId, earlier: false))
                            sink.putNext(MessageView(view))
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
                            !contains(removedMessageIds, $0)
                        }
                        updatedMessageIdsByMediaId[mediaId] = messageIds
                        
                        if messageIds.count == 0 {
                            self.database.prepare("INSERT OR IGNORE INTO media_cleanup (namespace, id, data) VALUES (?, ?, ?)").run(Int64(namespace), mediaId.id, row[1] as! Blob)
                        }
                    }
                }
                
                for (mediaId, messageIds) in updatedMessageIdsByMediaId {
                    if messageIds.count == 0 {
                        self.database.prepare("DELETE FROM media WHERE namespace = ? AND id = ?").run(Int64(mediaId.namespace), mediaId.id)
                    } else {
                        self.database.prepare("UPDATE media SET associatedMessageIds = ? WHERE namespace = ? AND id = ?").run(Postbox.blobForMessageIds(messageIds), Int64(mediaId.namespace), mediaId.id)
                    }
                }
            }
            
            let tail = self.fetchMessagesTail(peerId, count: 1)
            
            self.updatePeerEntry(peerId, message: tail.first, replace: true)
        }
    }
    
    public func modify<T>(f: Modifier<State> -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.dispatch {
                self.database.transaction()
                let result = f(Modifier(postbox: self))
                self.database.commit()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    private func findAdjacentMessageIds(peerId: PeerId, namespace: MessageId.Namespace, index: MessageIndex) -> (MessageId.Id?, MessageId.Id?) {
        var minId: MessageId.Id?
        var maxId: MessageId.Id?
        for row in self.database.prepare("SELECT MIN(id), MAX(id) FROM peer_messages WHERE peerId = ? AND namespace = ?").run(peerId.toInt64(), Int64(namespace)) {
            minId = MessageId.Id(row[0] as! Int64)
            maxId = MessageId.Id(row[1] as! Int64)
        }
        
        if let minId = minId, maxId = maxId {
            var minTimestamp: Int32!
            var maxTimestamp: Int32!
            for row in self.database.prepare("SELECT id, timestamp FROM peer_messages WHERE peerId = ? AND namespace = ? AND id IN (?, ?)").run(peerId.toInt64(), Int64(namespace), Int64(minId), Int64(maxId)) {
                let id = Int32(row[0] as! Int64)
                let timestamp = Int32(row[1] as! Int64)
                if id == minId {
                    minTimestamp = timestamp
                } else {
                    maxTimestamp = timestamp
                }
            }
            
            let earlierMidStatement = self.database.prepare("SELECT id, timestamp FROM peer_messages WHERE peerId = ? AND namespace = ? AND id <= ? LIMIT 1")
            let laterMidStatement = self.database.prepare("SELECT id, timestamp FROM peer_messages WHERE peerId = ? AND namespace = ? AND id >= ? LIMIT 1")
            
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
    
    private func fetchMessagesAround(peerId: PeerId, anchorId: MessageId, count: Int) -> ([Message], [MessageId.Namespace : Message], [MessageId.Namespace : Message]) {
        var messages: [Message] = []
        
        messages += self.fetchMessagesRelative(peerId, earlier: true)(namespace: anchorId.namespace, id: anchorId.id, count: count + 1)
        messages += self.fetchMessagesRelative(peerId, earlier: false)(namespace: anchorId.namespace, id: anchorId.id - 1, count: count + 1)
        
        messages.sort({ MessageIndex($0) < MessageIndex($1) })
        var i = messages.count - 1
        while i >= 1 {
            if messages[i].id == messages[i - 1].id {
                messages.removeAtIndex(i)
            }
            i--
        }
        
        if messages.count == 0 {
            return ([], [:], [:])
        } else {
            var index: MessageIndex!
            for message in messages {
                if message.id == anchorId {
                    index = MessageIndex(message)
                    break
                }
            }
            if index == nil {
                var closestId: MessageId.Id = messages[0].id.id
                var closestDistance = abs(closestId - anchorId.id)
                var closestTimestamp: Int32 = messages[0].timestamp
                for message in messages {
                    if abs(message.id.id - anchorId.id) < closestDistance {
                        closestId = message.id.id
                        closestDistance = abs(message.id.id - anchorId.id)
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
            
            messages.sort({ MessageIndex($0) < MessageIndex($1) })
            var i = messages.count - 1
            while i >= 1 {
                if messages[i].id == messages[i - 1].id {
                    messages.removeAtIndex(i)
                }
                i--
            }
            
            var anchorIndex = messages.count / 2
            i = 0
            while i < messages.count {
                if messages[i].id == index.id {
                    anchorIndex = i
                    break
                }
                i++
            }
            
            var filteredMessages: [Message] = []
            var earlier: [MessageId.Namespace : Message] = [:]
            var later: [MessageId.Namespace : Message] = [:]
            
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
                if earlier[messages[i].id.namespace] == nil {
                    earlier[messages[i].id.namespace] = messages[i]
                }
                i--
            }
            
            i = rightIndex + 1
            while i < messages.count {
                if later[messages[i].id.namespace] == nil {
                    later[messages[i].id.namespace] = messages[i]
                }
                i++
            }
            
            filteredMessages.sort({ MessageIndex($0) < MessageIndex($1) })
            
            return (filteredMessages, earlier, later)
        }
    }
    
    private func fetchMessagesRelative(peerId: PeerId, earlier: Bool)(namespace: MessageId.Namespace, id: MessageId.Id?, count: Int) -> [Message] {
        var messages: [Message] = []
        
        let sign = earlier ? "<" : ">"
        let order = earlier ? "DESC" : "ASC"
        let statement = self.database.prepare("SELECT data, associatedMediaIds FROM peer_messages WHERE peerId = ? AND namespace = ? AND id \(sign) ? ORDER BY id \(order) LIMIT \(count)")
        let bound: Int64
        if let id = id {
            bound = Int64(id)
        } else if earlier {
            bound = Int64(Int32.max)
        } else {
            bound = Int64(Int32.min)
        }
        
        for row in statement.run(Int64(peerId.toInt64()), Int64(namespace), bound) {
            let data = (row[0] as! Blob).data
            let decoder = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false))
            if let message = decoder.decodeRootObject() as? Message {
                messages.append(message)
            } else {
                println("(PostBox: can't decode message)")
            }
        }
        
        return messages
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
        
        return entries
    }
    
    private func messageForPeer(peerId: PeerId, id: MessageId) -> Message? {
        for row in self.database.prepareCached("SELECT data, associatedMediaIds FROM peer_messages WHERE peerId = ? AND namespace = ? AND id = ?").run(peerId.toInt64(), Int64(id.namespace), Int64(id.id)) {
            let data = (row[0] as! Blob).data
            let decoder = Decoder(buffer: ReadBuffer(memory: UnsafeMutablePointer(data.bytes), length: data.length, freeWhenDone: false))
            if let message = decoder.decodeRootObject() as? Message {
                return message
            } else {
                println("(PostBox: can't decode message)")
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
            } else {
                println("(PostBox: missing message for peer entry)")
            }
        }
        
        return entries
    }
    
    private func fetchMessagesTail(peerId: PeerId, count: Int) -> [Message] {
        var messages: [Message] = []
        
        for namespace in self.messageNamespaces {
            messages += self.fetchMessagesRelative(peerId, earlier: true)(namespace: namespace, id: nil, count: count)
        }
        
        messages.sort({ MessageIndex($0) < MessageIndex($1)})
        
        return messages
    }
    
    public func tailMessageViewForPeerId(peerId: PeerId, count: Int) -> Signal<MessageView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.dispatch {
                let tail = self.fetchMessagesTail(peerId, count: count + 1)
                
                var messages: [Message] = []
                var i = tail.count - 1
                while i >= 0 && i >= tail.count - count {
                    messages.insert(tail[i], atIndex: 0)
                    i--
                }
                
                var earlier: [MessageId.Namespace : Message] = [:]
                
                for namespace in self.messageNamespaces {
                    var i = tail.count - count - 1
                    while i >= 0 {
                        if tail[i].id.namespace == namespace {
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
                    
                    var messages: [Message] = []
                    var i = tail.count - 1
                    while i >= 0 && i >= tail.count - count {
                        messages.insert(tail[i], atIndex: 0)
                        i--
                    }
                    
                    var earlier: [MessageId.Namespace : Message] = [:]
                    
                    for namespace in self.messageNamespaces {
                        var i = tail.count - count - 1
                        while i >= 0 {
                            if tail[i].id.namespace == namespace {
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
                let tail = self.fetchPeerEntriesRelative(true)(index: nil, count: count + 1)
                
                var entries: [PeerViewEntry] = []
                var i = tail.count - 1
                while i >= 0 && i >= tail.count - count {
                    entries.insert(tail[i], atIndex: 0)
                    i--
                }
                
                var earlier: PeerViewEntry?
                
                for namespace in self.messageNamespaces {
                    var i = tail.count - count - 1
                    while i >= 0 {
                        earlier = tail[i]
                        break
                    }
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
        println(string)
    }
    
    public func _dumpTables() {
        println("\n------------")
        println("peer_messages")
        println("-------------")
        for row in self.database.prepare("SELECT peerId, namespace, id, timestamp, associatedMediaIds FROM peer_messages").run() {
            println("peer(\(PeerId(row[0] as! Int64))) id(\(MessageId(peerId: PeerId(row[0] as! Int64), namespace: Int32(row[1] as! Int64), id:(Int32(row[2] as! Int64))))) timestamp(\(row[3] as! Int64)) media(\(Postbox.mediaIdsForBlob(row[4] as! Blob)))")
        }
        
        println("\n---------")
        println("peer_media")
        println("----------")
        for row in self.database.prepare("SELECT peerId, mediaNamespace, messageNamespace, messageId FROM peer_media").run() {
            println("peer(\(PeerId(row[0] as! Int64))) namespace(\(row[1] as! Int64)) id(\(MessageId(peerId: PeerId(row[0] as! Int64), namespace: Int32(row[2] as! Int64), id:Int32(row[3] as! Int64))))")
        }
        
        println("\n----")
        println("media")
        println("-----")
        for row in self.database.prepare("SELECT namespace, id, associatedMessageIds FROM media").run() {
            println("id(\(MediaId(namespace: Int32(row[0] as! Int64), id:(row[1] as! Int64)))) messages(\(Postbox.messageIdsForBlob(row[2] as! Blob)))")
        }
        
        println("\n------------")
        println("media_cleanup")
        println("-------------")
        for row in self.database.prepare("SELECT namespace, id FROM media_cleanup").run() {
            println("id(\(MediaId(namespace: Int32(row[0] as! Int64), id:(row[1] as! Int64))))")
        }
    }
    
    public func _sync() {
        self.queue.sync {
        }
    }
}
