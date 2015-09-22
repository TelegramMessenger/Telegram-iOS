import Foundation

func peerViewEntryIndexForBuffer(buffer: ReadBuffer) -> PeerViewEntryIndex {
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

func bufferForPeerViewEntryIndex(index: PeerViewEntryIndex) -> MemoryBuffer {
    let buffer = WriteBuffer()
    
    var timestamp = Int32(bigEndian: index.messageIndex.timestamp)
    buffer.write(&timestamp, offset: 0, length: 4)
    
    var namespace = Int32(bigEndian: index.messageIndex.id.namespace)
    buffer.write(&namespace, offset: 0, length: 4)
    
    var id = Int32(bigEndian: index.messageIndex.id.id)
    buffer.write(&id, offset: 0, length: 4)
    
    var peerIdRepresentation = Int64(bigEndian: index.peerId.toInt64())
    buffer.write(&peerIdRepresentation, offset: 0, length: 8)
    
    return buffer
}

func messageIdsGroupedByNamespace(ids: [MessageId]) -> [MessageId.Namespace : [MessageId]] {
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

func mediaIdsGroupedByNamespaceFromMediaArray(mediaArray: [Media]) -> [MediaId.Namespace : [MediaId]] {
    var grouped: [MediaId.Namespace : [MediaId]] = [:]
    var seenMediaIds = Set<MediaId>()
    
    for media in mediaArray {
        if let id = media.id {
            if !seenMediaIds.contains(id) {
                seenMediaIds.insert(id)
                if grouped[id.namespace] != nil {
                    grouped[id.namespace]!.append(id)
                } else {
                    grouped[id.namespace] = [id]
                }
            }
        }
    }
    
    return grouped
}

func mediaIdsGroupedByNamespaceFromSet(ids: Set<MediaId>) -> [MediaId.Namespace : [MediaId]] {
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

func mediaIdsGroupedByNamespaceFromDictionaryKeys<T>(dict: [MediaId : T]) -> [MediaId.Namespace : [MediaId]] {
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

func messagesGroupedByPeerId(messages: [Message]) -> [(PeerId, [Message])] {
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

func messageIdsGroupedByPeerId(messageIds: [MessageId]) -> [PeerId : [MessageId]] {
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

func blobForMediaIds(ids: [MediaId]) -> Blob {
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

func mediaIdsForBlob(blob: Blob) -> [MediaId] {
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

func memoryBufferForMessageIds(ids: [MessageId]) -> MemoryBuffer {
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
    
    return MemoryBuffer(data: data)
}

func messageIdsForMemoryBuffer(buffer: MemoryBuffer) -> [MessageId] {
    var ids: [MessageId] = []
    
    let readBuffer = ReadBuffer(memoryBufferNoCopy: buffer)
    
    var count: Int32 = 0
    readBuffer.read(&count, offset: 0, length: 4)
    
    var i = 0
    while i < Int(count) {
        var mPeerNamespace: Int32 = 0
        var mPeerId: Int32 = 0
        var mNamespace: Int32 = 0
        var mId: Int32 = 0
        readBuffer.read(&mPeerNamespace, offset: 0, length: 4)
        readBuffer.read(&mPeerId, offset: 0, length: 4)
        readBuffer.read(&mNamespace, offset: 0, length: 4)
        readBuffer.read(&mId, offset: 0, length: 4)
        ids.append(MessageId(peerId: PeerId(namespace: mPeerNamespace, id: mPeerId), namespace: mNamespace, id: mId))
        i++
    }
    
    return ids
}
